#!/usr/bin/env python3
"""
syncClusterUtils.py

Synchronizes files and directories from a source directory to the same location on multiple Cohesity cluster nodes.
- Only copies files if they are new or have changed (using SHA256 checksum comparison).
- Handles nested directories and empty folders.
- Runs in parallel across nodes for speed.
- Shows a progress bar and prints a summary report.
- Logs all actions and errors to syncClusterUtils.log.

Key adjustable variables:
- user: SSH username for remote nodes (default: "support")
- max_workers: Number of parallel threads for node sync (default: 4)
- status_width: Width for status message alignment (default: 28)
- Logging: Log file is "syncClusterUtils.log" in the current directory

Requires:
- Python 3.6+
- tqdm (`pip install tqdm`)
- SSH key-based authentication to all nodes

Author: [Your Name]
Date: [Date]
"""

import subprocess
import os
import sys
import logging
from pathlib import Path
import hashlib
from concurrent.futures import ThreadPoolExecutor, as_completed

# ASCI Color Values for terminal output
red_bg = "\033[41m"
yellow_bg = "\033[43m"
green_bg = "\033[42m"
reset_color = "\033[0m"

# --- Logging Setup ---
logging.basicConfig(
    filename="syncClusterUtils.log",
    level=logging.INFO,
    format="%(asctime)s %(levelname)s: %(message)s"
)

def get_host_ips():
    try:
        output = subprocess.check_output("hostips", shell=True).decode().strip()
        return [ip for ip in output.split() if ip]
    except Exception as e:
        logging.error(f"Error running hostips: {e}")
        print(f"Error running hostips: {e}")
        sys.exit(1)

def sha256sum(filename):
    h = hashlib.sha256()
    with open(filename, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def remote_sha256sum(ip, user, remote_path):
    cmd = [
        "ssh", "-q", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
        f"{user}@{ip}", f"sha256sum {remote_path} 2>/dev/null | awk '{{print $1}}'"
    ]
    try:
        result = subprocess.check_output(cmd, timeout=10).decode().strip()
        return result if result else None
    except subprocess.CalledProcessError:
        return None
    except Exception as e:
        logging.error(f"Error checking remote file on {ip}: {e}")
        print(f"  Error checking remote file on {ip}: {e}")
        return None

def sync_to_node(ip, src_dir, dest_dir, user, files, all_dirs, status_width=28):
    summary = {"copied": 0, "skipped": 0, "updated": 0, "failed": 0}
    try:
        local_ip = subprocess.check_output("hostname -I", shell=True).decode().split()[0]
    except Exception:
        local_ip = None

    if ip == local_ip:
        print(f"{yellow_bg}Skipping local node {ip}{reset_color}")
        return ip, summary

    print(f"{red_bg}Pushing files to {ip} as {user}...{reset_color}")
    logging.info(f"Pushing files to {ip} as {user}")

    check_root_cmd = [
        "ssh", "-q", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
        f"{user}@{ip}", f"test -d '{dest_dir}'"
    ]
    try:
        subprocess.run(check_root_cmd, check=True)
        logging.info(f"{ip}: Root directory {dest_dir} already exists")
    except subprocess.CalledProcessError:
        mkdir_root_cmd = [
            "ssh", "-q", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
            f"{user}@{ip}", f"mkdir -p '{dest_dir}'"
        ]
        try:
            subprocess.run(mkdir_root_cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
            logging.info(f"{ip}: Created root directory {dest_dir}")
        except subprocess.CalledProcessError as e:
            print(f"{red_bg}  Failed to create root directory {dest_dir} on {ip}: {e}{reset_color}")
            logging.error(f"Failed to create root directory {dest_dir} on {ip}: {e}")
            summary["failed"] += 1
            return ip, summary

    for dir_path in all_dirs:
        rel_dir = dir_path.relative_to(src_dir)
        remote_dir = os.path.join(dest_dir, str(rel_dir))
        mkdir_cmd = [
            "ssh", "-q", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
            f"{user}@{ip}", f"mkdir -p '{remote_dir}'"
        ]
        try:
            subprocess.run(mkdir_cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        except subprocess.CalledProcessError as e:
            print(f"{red_bg}  Failed to create directory {remote_dir} on {ip}: {e}{reset_color}")
            logging.error(f"Failed to create directory {remote_dir} on {ip}: {e}")
            summary["failed"] += 1

    total_files = len(files)
    for idx, file_path in enumerate(files, 1):
        rel_path = file_path.relative_to(src_dir)
        remote_file = os.path.join(dest_dir, str(rel_path))

        percents = round(100.0 * idx / float(total_files), 1)
        bar_length = 40
        filled_length = int(round(bar_length * idx / float(total_files)))
        bar = '=' * filled_length + '-' * (bar_length - filled_length)

        if not file_path.exists():
            status = f"{red_bg}✖ Local file missing{reset_color}"
            print(f"Sync to {ip} [{bar}] {idx}/{total_files} ({percents}%) | {str(rel_path):<50} {status}")
            logging.error(f"{ip}: Local file missing: {file_path}")
            summary["failed"] += 1
            continue

        local_sum = sha256sum(file_path)
        remote_sum = remote_sha256sum(ip, user, remote_file)

        if remote_sum == local_sum:
            status = f"{yellow_bg}➜ Skipped (identical){reset_color}"
            logging.info(f"{ip}: {rel_path} skipped (identical)")
            summary["skipped"] += 1
            print(f"Sync to {ip} [{bar}] {idx}/{total_files} ({percents}%) | {str(rel_path):<50} {status}")
            continue
        elif remote_sum is not None:
            status = f"{yellow_bg}↻ Updating (delta found){reset_color}"
            logging.info(f"{ip}: {rel_path} updating (delta found)")
        else:
            status = f"{yellow_bg}+ Copying (new file){reset_color}"
            logging.info(f"{ip}: {rel_path} copying (new file)")

        scp_cmd = [
            "scp", "-q", "-o", "LogLevel=Error", "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            str(file_path), f"{user}@{ip}:{remote_file}"
        ]
        try:
            subprocess.run(scp_cmd, check=True)
            final_status = f"{green_bg}✔ Copied{reset_color}" if remote_sum is None else f"{green_bg}✔ Updated{reset_color}"
            print(f"Sync to {ip} [{bar}] {idx}/{total_files} ({percents}%) | {str(rel_path):<50} {final_status}")
            logging.info(f"{ip}: {rel_path} updated/copied")
            if remote_sum is not None:
                summary["updated"] += 1
            else:
                summary["copied"] += 1
        except subprocess.CalledProcessError as e:
            status = f"{red_bg}✖ Failed{reset_color}"
            print(f"Sync to {ip} [{bar}] {idx}/{total_files} ({percents}%) | {str(rel_path):<50} {status}")
            logging.error(f"{ip}: {rel_path} failed: {e}")
            summary["failed"] += 1

    return ip, summary

def push_files_to_nodes(src_dir, dest_dir, user="support", max_workers=4):
    ips = get_host_ips()
    src_dir = Path(src_dir).resolve()
    all_dirs = [p for p in src_dir.rglob("*") if p.is_dir()]
    files = [p for p in src_dir.rglob("*") if p.is_file()]
    if not files and not all_dirs:
        print(f"No files or directories found in {src_dir}")
        logging.warning(f"No files or directories found in {src_dir}")
        return

    summary_report = {}
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(sync_to_node, ip, src_dir, dest_dir, user, files, all_dirs): ip
            for ip in ips
        }
        for future in as_completed(futures):
            ip, summary = future.result()
            summary_report[ip] = summary

    print(f"\n{green_bg}Sync Summary Report{reset_color}")
    for ip, summary in summary_report.items():
        print(f"\nNode: {ip}")
        print(f"  Copied:  {summary['copied']}")
        print(f"  Updated: {summary['updated']}")
        print(f"  Skipped: {summary['skipped']}")
        print(f"  Failed:  {summary['failed']}")
    logging.info(f"Sync Summary: {summary_report}")

if __name__ == "__main__":
    if len(sys.argv) < 3 or len(sys.argv) > 5:
        print("Usage: push_to_cluster.py <source_directory> <destination_directory> [user] [max_workers]")
        sys.exit(1)
    src_dir = sys.argv[1]
    dest_dir = sys.argv[2]
    user = sys.argv[3] if len(sys.argv) >= 4 else "support"
    max_workers = int(sys.argv[4]) if len(sys.argv) == 5 else 4
    push_files_to_nodes(src_dir, dest_dir, user, max_workers)
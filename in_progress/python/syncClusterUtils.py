#!/usr/bin/env python3
import subprocess
import os
import sys
from pathlib import Path
import hashlib

def get_host_ips():
    """Get list of host IPs from the hostips command."""
    try:
        output = subprocess.check_output("hostips", shell=True).decode().strip()
        return [ip for ip in output.split() if ip]
    except Exception as e:
        print(f"Error running hostips: {e}")
        sys.exit(1)

def sha256sum(filename):
    """Compute SHA256 checksum of a file."""
    h = hashlib.sha256()
    with open(filename, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def remote_sha256sum(ip, user, remote_path):
    """Get SHA256 checksum of a remote file via ssh. Returns None if file does not exist."""
    cmd = [
        "ssh",
        f"{user}@{ip}",
        f"sha256sum {remote_path} 2>/dev/null | awk '{{print $1}}'"
    ]
    try:
        result = subprocess.check_output(cmd, timeout=10).decode().strip()
        return result if result else None
    except subprocess.CalledProcessError:
        return None
    except Exception as e:
        print(f"  Error checking remote file on {ip}: {e}")
        return None

def push_files_to_nodes(src_dir, dest_dir, user="support"):
    """Push all files in src_dir to dest_dir on each node in the cluster, only if different."""
    ips = get_host_ips()
    try:
        local_ip = subprocess.check_output("hostname -I", shell=True).decode().split()[0]
    except Exception:
        local_ip = None
    files = list(Path(src_dir).glob("*"))
    if not files:
        print(f"No files found in {src_dir}")
        return

    for ip in ips:
        if ip == local_ip:
            print(f"Skipping local node {ip}")
            continue
        print(f"Pushing files to {ip} as {user}...")
        for file_path in files:
            local_sum = sha256sum(file_path)
            remote_file = os.path.join(dest_dir, file_path.name)
            remote_sum = remote_sha256sum(ip, user, remote_file)
            if remote_sum == local_sum:
                print(f"  {file_path.name} is up to date on {ip}, skipping.")
                continue
            cmd = [
                "scp",
                str(file_path),
                f"{user}@{ip}:{dest_dir}/"
            ]
            try:
                subprocess.run(cmd, check=True)
                print(f"  {file_path.name} -> {ip}:{dest_dir}/ (updated)")
            except subprocess.CalledProcessError as e:
                print(f"  Failed to copy {file_path.name} to {ip}: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print("Usage: push_to_cluster.py <source_directory> <destination_directory> [user]")
        sys.exit(1)
    src_dir = sys.argv[1]
    dest_dir = sys.argv[2]
    user = sys.argv[3] if len(sys.argv) == 4 else "support"
    push_files_to_nodes(src_dir, dest_dir, user)
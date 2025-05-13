#!/usr/bin/env python3
# Author: Doug Austin
# Date: 08/05/2023
# Summary: This script pulls file system information, Service PIDs, Service Versions, Hardware Firmware versions, Fatal Log Entries
# to be given to cohesity support.

import subprocess
import os
import sys
import re
from datetime import datetime
from contextlib import contextmanager

# ANSI escape sequences for colors and formatting
RED_BACKGROUND = '\033[41m'
BOLD = '\033[1m'
RESET = '\033[0m'
GREEN = '\033[032m'
RED = '\033[031m'

# Unicode symbols
CHECKMARK = "\N{check mark}"
CROSSMARK = "\N{cross mark}"

def get_log_filepath():
    """Return the path to the log file based on current date."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    log_filename = f"healthcheck_{datetime.now().strftime('%Y%m%d')}.log"
    return os.path.join(script_dir, log_filename)

def log_message(message, log_filepath=None):
    """
    Log a message to both console and log file.
   
    Args:
        message: The message to log
        log_filepath: Path to the log file (if None, uses default path)
    """
    if log_filepath is None:
        log_filepath = get_log_filepath()
       
    print(message)
    with open(log_filepath, "a") as log_file:
        log_file.write(f"{message}\n")

@contextmanager
def section_header(title):
    """
    Context manager to print a section header with the given title.
   
    Args:
        title: The title of the section
    """
    log_message(f"------------- {RED_BACKGROUND} {title} {RESET} ---------------")
    yield
    log_message("")

def get_node_uptime():
    """Get and log the current date and server uptime."""
    try:
        result = subprocess.run(
            ["uptime"], capture_output=True, text=True, check=True
        )
        uptime_output = result.stdout.strip()
       
        result = subprocess.run(
            ["date"], capture_output=True, text=True, check=True
        )
        date_output = result.stdout.strip()
       
        log_message(f"Current Date: {date_output}")
        log_message(f"Server Uptime: {uptime_output}")
    except subprocess.SubprocessError as e:
        log_message(f"Error getting uptime information: {e}")

def get_partitions():
    """
    Get a list of filesystem partitions, separated into normal and Cohesity partitions.
   
    Returns:
        tuple: (normal_partitions, cohesity_partitions)
    """
    try:
        result = subprocess.run(
            ['df', '-h'], capture_output=True, text=True, check=True
        )
        lines = result.stdout.split('\n')
        partitions = [line.split()[5] for line in lines[1:] if line]
       
        normal_partitions = [p for p in partitions if not re.match(
            r'tmpfs|devtmpfs|/boot|/home_cohesity_data|/home/cohesity', p)]
        cohesity_partitions = [p for p in partitions if p.startswith('/home_cohesity')]
       
        return normal_partitions, cohesity_partitions
    except (subprocess.SubprocessError, IndexError) as e:
        log_message(f"Error getting partitions: {e}")
        return [], []

def get_usage(partition):
    """
    Get the used percentage of a partition.
   
    Args:
        partition: The partition to check
       
    Returns:
        int: Usage percentage
    """
    try:
        result = subprocess.run(
            ['df', '-h', partition], capture_output=True, text=True, check=True
        )
        line = result.stdout.split('\n')[1]
        usage = int(line.split()[4].rstrip('%'))
        return usage
    except (subprocess.SubprocessError, IndexError) as e:
        log_message(f"Error getting usage for {partition}: {e}")
        return 0

def print_partitions(partitions, threshold, label):
    """
    Print partition usage information with color-coding.
   
    Args:
        partitions: List of partitions to print
        threshold: Threshold percentage for warning coloration
        label: Label for this group of partitions
    """
    log_message(f"\n{label}")
    log_message(f"{'Partition':<15}  {'Used Percentage':>85}")
    log_message("-" * 107)
   
    for partition in partitions:
        usage = get_usage(partition)
        color = RED if usage > threshold else GREEN
        log_message(f"{partition:<85} | {color}{usage}%{RESET}")

def check_filesystem():
    """Check and report on filesystem usage."""
    try:
        normal_partitions, cohesity_partitions = get_partitions()
        print_partitions(normal_partitions, 60, "OS Partitions")
        print_partitions(cohesity_partitions, 80, "Cohesity Partitions")
    except Exception as e:
        log_message(f"Error checking filesystem: {e}")

def check_processes():
    """Check and report on the status of important processes."""
    processes = [
        'aegis', 'alerts', 'apollo', 'athena', 'atom', 'bifrost', 'bifrost_broker',
        'bridge', 'bridge_proxy', 'compass', 'eagle_agent', 'elrond', 'etl_server',
        'gandalf', 'groot', 'heimdall', 'icebox', 'iris', 'iris_proxy', 'janus',
        'keychain', 'librarian', 'logwatcher', 'magneto', 'newscribe', 'nexus',
        'nexus_proxy', 'nfs_proxy', 'node_exporter', 'patch', 'pushclient', 'rtclient',
        'smb2_proxy', 'smb_proxy', 'spire_agent', 'spire_server', 'stats',
        'statscollector', 'storage_proxy', 'throttler', 'vault_proxy', 'yoda'
    ]
   
    log_message(f"{'Process':<15}  {'State':<10}  {'Status':<10}  {'PID':<5}")
   
    for process in processes:
        try:
            result = subprocess.run(
                ['pgrep', '-c', process],
                capture_output=True, text=True, check=True
            )
            count = int(result.stdout.strip())
           
            if count > 0:
                # Get the PID of one instance (second if multiple)
                pid_result = subprocess.run(
                    ['pgrep', process],
                    capture_output=True, text=True, check=True
                )
                pids = pid_result.stdout.strip().split('\n')
                pid = p

log_message(f"------------- {RED_BACKGROUND} Firmware Check {RESET} ---------------")
chassis_fw_cmd = "product_helper -op=LIST_FIRMWARE_VERSION"
COFW = subprocess.getoutput(chassis_fw_cmd)
log_message(f"Firmware: {COFW}\n")
log_message("")

log_message(f"------------- {RED_BACKGROUND} Cluster Info {RESET} ---------------")
def fetch_cluster_info():
    try:
        process = subprocess.Popen(["bash", "/home/cohesity/bin/cluster_config.sh", "fetch"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        process.wait()
        if process.returncode == 0:
            stdout, stderr = process.communicate()
            cat_output = subprocess.getoutput("cat /tmp/cluster_config | egrep 'cluster_id|cluster_incarnation|cluster_name' | head -3")
            log_message(cat_output)
        else:
            log_message("No Output from Cluster Config")
    except subprocess.CalledProcessError as e:
        log_message(f"Error: {e}")
fetch_cluster_info()
log_message("")

log_message(f"------------- {RED_BACKGROUND} Node Information {RESET} ---------------")
cohesity_node_cmd = "product_helper --op=GET_PRODUCT_BRIEF"
CHSERIAL = subprocess.getoutput(cohesity_node_cmd)
log_message(f"{CHSERIAL}\n")
log_message("")

log_message(f"------------- {RED_BACKGROUND} Node IP Info {RESET} ---------------")
log_message('{:<15s}  {:<13s}  {:<25s}'.format('Interface', 'State', 'IPs'))
output = subprocess.getoutput("ip -4 -brief address show")
log_message(output)
log_message("")

log_message(f"------------- {RED_BACKGROUND} Software Version History {RESET} ---------------")
software_version_file = "/home/cohesity/data/nexus/software_version_history.json"
if os.path.exists(software_version_file):
    software_version_history = subprocess.getoutput(f"cat {software_version_file}")
    log_message(software_version_history)
else:
    log_message("File Not Found.")
log_message("")

log_message(f"------------- {RED_BACKGROUND} Service Version Check {RESET} ---------------")
def get_version(service):
    try:
        result = subprocess.run([service, '--version'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            return f"Error: {result.stderr.decode('utf-8').strip()}"
        output = result.stdout.decode('utf-8')
        return output.split('\n')[0].split()[2]
    except IndexError:
        return "Version not found"
    except FileNotFoundError:
        return "Service not found"
    except Exception as e:
        return f"Error: {str(e)}"

def check_service_versions():
    services = [
        "aegis_exec", "alerts_exec", "apollo_exec", "athena_exec", "athena_proxy_exec",
        "atom_exec", "bifrost_exec", "bridge_exec", "compass_exec", "eagle_agent_exec",
        "elrond_exec", "etl_server_exec", "heimdall_exec", "iris_exec", "janus_exec",
        "keychain_exec", "librarian_exec", "logwatcher_exec", "magneto_exec", "nexus_exec",
        "nfs_proxy_exec", "patch_exec", "rtclient_exec", "smb_proxy_exec", "stats_exec",
        "storage_proxy_exec", "vault_proxy_exec", "yoda_exec"
    ]
    log_message(f"{datetime.now()}\nChecking versions of the following: {', '.join(services)}\n")
    log_message(f"{'Service Name:':<30} {'Version'}")
    log_message("------------- --------------------------------------------------------")
    versions = {service: get_version(service) for service in services}
    sorted_services = sorted(versions.keys())
    for service in sorted_services:
        version = versions[service]
        log_message(f"{service:<30} {version}")

check_service_versions()
log_message("")

log_message(f"------------- {RED_BACKGROUND} Latest Fatals On Node {RESET} ---------------")
log_message("")
for log_file in ["bridge_exec", "bridge_proxy_exec", "magneto_exec", "yoda_exec", "apollo_exec", "groot_exec", "nexus_exec", "nexus_proxy_exec"]:
    log_message(f"========= {RED_BACKGROUND}{log_file.upper()} FATAL Log{RESET} =========")
    fatal_log = subprocess.getoutput(f"cat /home/cohesity/logs/{log_file}.*FATAL | head")
    log_message(fatal_log + "\n")


#!/usr/bin/env python3
import subprocess
import os
import sys
import re
import logging
from datetime import datetime

# ANSI escape sequences
RED_BACKGROUND = '\033[41m'
BOLD = '\033[1m'
GREEN = '\033[32m'
RED = '\033[31m'
RESET = '\033[0m'

# Logging setup
script_dir = os.path.dirname(os.path.abspath(__file__))
log_file = os.path.join(script_dir, "health_check.log")
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def print_header(title):
    print(f"------------- {RED_BACKGROUND} {title} {RESET} ---------------")

def get_node_uptime():
    try:
        output = subprocess.check_output("uptime", shell=True).decode().strip()
        dateo = subprocess.check_output("date", shell=True).decode().strip()
        print(f"Current Date: {dateo}")
        print(f"Server Uptime: {output}")
        logging.info(f"\n{dateo}\n{output}\n{'-'*40}")
    except Exception as e:
        print(f"Error getting uptime: {e}")

def get_partitions():
    result = subprocess.run(['df', '-h'], stdout=subprocess.PIPE)
    lines = result.stdout.decode('utf-8').split('\n')
    partitions = [line.split()[5] for line in lines[1:] if line and len(line.split()) > 5]
    normal_partitions = [p for p in partitions if not re.match(r'tmpfs|devtmpfs|/boot|/home_cohesity_data|/home/cohesity', p)]
    cohesity_partitions = [p for p in partitions if p.startswith('/home_cohesity')]
    return normal_partitions, cohesity_partitions

def get_usage(partition):
    try:
        result = subprocess.run(['df', '-h', partition], stdout=subprocess.PIPE)
        line = result.stdout.decode('utf-8').split('\n')[1]
        usage = int(line.split()[4].rstrip('%'))
        return usage
    except Exception:
        return -1

def print_partitions(partitions, threshold):
    print(f"\n{'Partition':<30} {'Used Percentage':>20}")
    print("-" * 55)
    for partition in partitions:
        usage = get_usage(partition)
        if usage == -1:
            print(f"{partition:<30} {RED}Error{RESET}")
            continue
        color = RED if usage > threshold else GREEN
        print(f"{partition:<30} {color}{usage}%{RESET}")

def check_processes(processes):
    CHECKMARK = "\N{check mark}"
    CROSSMARK = "\N{cross mark}"
    print('{:<20s} {:<10s} {:<10s} {:<5s}'.format('Process', 'State', 'Status', 'PID'))
    for process in processes:
        try:
            count = int(subprocess.check_output(['pgrep', '-c', process]))
            pid = subprocess.check_output(f"pgrep {process} | head -1", shell=True).decode().strip()
            if count > 0:
                print(f"{process:<20} Running    {CHECKMARK}      {pid}")
            else:
                print(f"{process:<20} Not Running {CROSSMARK}")
        except subprocess.CalledProcessError:
            print(f"{process:<20} Not Found   {CROSSMARK}")

def get_firmware():
    try:
        output = subprocess.check_output("product_helper -op=LIST_FIRMWARE_VERSION", shell=True).decode().strip()
        print(f"Firmware: {output}\n")
    except Exception as e:
        print(f"Error fetching firmware: {e}")

def fetch_cluster_info():
    try:
        process = subprocess.Popen(
            ["bash", "/home/cohesity/bin/cluster_config.sh", "fetch"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        process.wait()
        if process.returncode == 0:
            cat_output = subprocess.check_output(
                "cat /tmp/cluster_config | egrep 'cluster_id|cluster_incarnation|cluster_name' | head -3",
                shell=True
            ).decode('utf-8')
            print(cat_output)
        else:
            print("No Output from Cluster Config")
    except Exception as e:
        print(f"Error fetching cluster info: {e}")

def get_node_info():
    try:
        output = subprocess.check_output("product_helper --op=GET_PRODUCT_BRIEF", shell=True).decode().strip()
        print(output)
    except Exception as e:
        print(f"Error fetching node info: {e}")

def get_ip_info():
    try:
        output = subprocess.check_output(['ip', '-4', '-brief', 'address', 'show']).decode('utf-8')
        print('{:<15s}  {:<13s}  {:<25s}'.format('Interface', 'State', 'IPs'))
        for line in output.split('\n'):
            if line.startswith('br0'):
                print(line)
    except Exception as e:
        print(f"Error fetching IP info: {e}")

def print_software_version_history():
    try:
        subprocess.call(['cat', "/home/cohesity/data/nexus/software_version_history.json"])
    except FileNotFoundError:
        print("File Not found.")

def get_version(service):
    try:
        result = subprocess.run([service, '--version'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            return f"Error: {result.stderr.decode('utf-8').strip()}"
        output = result.stdout.decode('utf-8')
        return output.split('\n')[0].split()[2]
    except Exception:
        return "Version not found"

def check_service_versions(services):
    print(f"{datetime.now()}\nChecking versions of the following: {', '.join(services)}\n")
    print(f"{'Service Name:':<30} {'Version'}")
    print("------------- --------------------------------------------------------")
    for service in sorted(services):
        version = get_version(service)
        print(f"{service:<30} {version}")

def print_fatal_logs(services):
    for service in services:
        log_path = f"/home/cohesity/logs/{service}.*FATAL"
        print(f"\n========= {RED_BACKGROUND}{service.replace('_exec', '').capitalize()} FATAL Log{RESET} =========")
        os.system(f"cat {log_path} | head")

def main():
    print_header("Node Uptime")
    get_node_uptime()
    print_header("FileSystem Check")
    normal_partitions, cohesity_partitions = get_partitions()
    print_partitions(normal_partitions, 60)
    print_partitions(cohesity_partitions, 80)
    print_header("Process Check")
    processes = [
        'aegis', 'alerts', 'apollo', 'athena', 'atom', 'bifrost', 'bifrost_broker', 'bridge', 'bridge_proxy',
        'compass', 'eagle_agent', 'elrond', 'etl_server', 'gandalf', 'groot', 'heimdall', 'icebox', 'iris',
        'iris_proxy', 'janus', 'keychain', 'librarian', 'logwatcher', 'magneto', 'newscribe', 'nexus',
        'nexus_proxy', 'nfs_proxy', 'node_exporter', 'patch', 'pushclient', 'rtclient', 'smb2_proxy',
        'smb_proxy', 'spire_agent', 'spire_server', 'stats', 'statscollector', 'storage_proxy', 'throttler',
        'vault_proxy', 'yoda'
    ]
    check_processes(processes)
    print_header("Firmware Check")
    get_firmware()
    print_header("Cluster Info")
    fetch_cluster_info()
    print_header("Node Information")
    get_node_info()
    print_header("Node Ip Info")
    get_ip_info()
    print_header("Software Version History")
    print_software_version_history()
    print_header("Service Version Check")
    services = [
        "aegis_exec", "alerts_exec", "apollo_exec", "athena_exec", "athena_proxy_exec",
        "athena_watchdog_exec", "atom_exec", "axon_config_helper_exec", "bashlogger_exec",
        "bifrost_broker_exec", "bifrost_exec", "bridge_exec", "bridge_proxy_exec",
        "compass_exec", "core_helper_exec", "eagle_agent_exec", "elrond_exec",
        "firmware_helper_exec", "flexvol_exec", "groot_exec", "heimdall_exec",
        "input_logger_exec", "iris_exec", "iris_proxy_exec", "keychain_exec",
        "librarian_exec", "logwatcher_exec", "magneto_exec", "newscribe_exec",
        "nexus_exec", "nexus_proxy_exec", "nfs_proxy_exec", "patch_exec", "rtclient_exec",
        "siren_server_exec", "smb2_proxy_exec", "smb_proxy_exec", "snmp_subagent_exec",
        "statscollector_exec", "stats_exec", "throttler_exec", "vault_proxy_exec",
        "workqueue_server_exec", "yoda_agent_exec", "yoda_exec"
    ]
    check_service_versions(services)
    print_header("Latest Fatals On Node")
    fatal_services = [
        "bridge_exec", "bridge_proxy_exec", "magneto_exec", "yoda_exec", "apollo_exec", "groot_exec", "nexus_exec", "nexus_proxy_exec"
    ]
    print_fatal_logs(fatal_services)

if __name__ == "__main__":
    main()
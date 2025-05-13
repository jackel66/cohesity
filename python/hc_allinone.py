#!/usr/bin/env python3
# Author: Doug Austin
# Date: 08/05/2023
# Summary: This script pulls file system information, Service PIDs, Service Versions, Hardware Firmware versions, Fatal Log Entries
# to be given to cohesity support.

import subprocess
import socket
import fcntl
import struct
import os
import shutil
import sys
import re
import logging
from datetime import datetime

# ANSI escape sequences for red color and bold text
RED_BACKGROUND = '\033[41m'
BOLD = '\033[1m'
# ANSI escape sequence to reset text formatting
RESET = '\033[0m'
script_dir = os.path.dirname(os.path.abspath(__file__))
log_file = os.path.join(script_dir, "health_check.log")
logging.basicConfig(filename=log_file, level=logging.INFO,
                    format='%asctime)s - %(levelname)s - %(message)s')

# Check OS Information
print(f"------------- {RED_BACKGROUND} Node Uptime {RESET} ---------------")
def get_node_uptime():
    uptime_command = "uptime | grep days | awk  -F ',' '{print $1}'"                                                    
    output = os.popen(uptime_command).read().strip()
    dateo = os.popen('date').read().strip()
    print(f"Current Date: {dateo}")
    print(f"Server Uptime: {output}")
get_node_uptime()
logging.info("\n" + {dateo} + "\n" + {output} +"-"*40)
print("")

print(f"------------- {RED_BACKGROUND} FileSystem Check {RESET} ---------------")
def get_partitions():
    result = subprocess.run(['df', '-h'], stdout=subprocess.PIPE)
    lines = result.stdout.decode('utf-8').split('\n')
    partitions = [line.split()[5] for line in lines[1:] if line]
    normal_partitions = [p for p in partitions if not re.match(r'tmpfs|devtmpfs|/boot|/home_cohesity_data|/home/cohesity', p)]
    cohesity_partitions = [p for p in partitions if p.startswith('/home_cohesity')]
    return normal_partitions, cohesity_partitions
def get_usage(partition):
    result = subprocess.run(['df', '-h', partition], stdout=subprocess.PIPE)
    line = result.stdout.decode('utf-8').split('\n')[1]
    usage = int(line.split()[4].rstrip('%'))
    return usage
def print_partitions(partitions, threshold, label):
    print(f"\n{'Partition':<15}  {'Used Percentage':>85}")
    print("-" * 107)
    for partition in partitions:
        usage = get_usage(partition)
        color = '\033[031m' if usage > threshold else '\033[032m'
        print(f"{partition:<85} | {color}{usage}%\033[0m")
def main():
    normal_partitions, cohesity_partitions = get_partitions()
    print_partitions(normal_partitions, 60, "OS Partitions")
    print_partitions(cohesity_partitions, 80, "Cohesity Partitions")
if __name__ == "__main__":
    main()
print("")

print(f"------------- {RED_BACKGROUND} Process Check {RESET} ---------------")
# Processes to check
processes = ['aegis', 'alerts', 'apollo', 'athena', 'atom', 'bifrost', 'bifrost_broker', 'bridge', 'bridge_proxy', 'compass', 'eagle_agent', 'elrond', 'etl_server', 'gandalf', 'groot', 'heimdall', 'icebox', 'iris', 'iris_proxy', 'janus', 'keychain', 'librarian', 'logwatcher', 'magneto', 'newscribe', 'nexus', 'nexus_proxy', 'nfs_proxy', 'node_exporter', 'patch', 'pushclient', 'rtclient', 'smb2_proxy', 'smb_proxy', 'spire_agent', 'spire_server', 'stats', 'statscollector', 'storage_proxy', 'throttler', 'vault_proxy', 'yoda']
# Unicode Marks
CHECKMARK = "\N{check mark}"
CROSSMARK = "\N{cross mark}"
# Header for Output
print('{:<15s}  {:<10s}  {:<10s}  {:<5s}'.format('Process', 'State', 'Status', 'PID'))
# Main section of Code to check for a running Process
for process in processes:
    try:
        count = int(subprocess.check_output(['pgrep', '-c', process]))
        cmd = f"pgrep {process} | head -2 | tail -1"
        id = (subprocess.check_output(cmd, shell=True).decode().strip())
        if count > 0:
            print(f"{process}{' ' * (15 - len(process))} Running       {CHECKMARK}          {id}")
        else:
            print(f"{process}{' ' * (15 - len(process))} Not Running         {CROSSMARK}")
    except subprocess.CalledProcessError:
        print(f"{process}{' ' * (15 - len(process))} Not Found         {CROSSMARK}")
print("")

print(f"------------- {RED_BACKGROUND} Firmware Check {RESET} ---------------")
# Product Helper Section
chassis_fw_cmd = f"product_helper  -op=LIST_FIRMWARE_VERSION"
COFW = (subprocess.check_output(chassis_fw_cmd, shell=True).decode().strip())
print(f"Firmware: {COFW}\n")
print("")

# Get Cluster Information
print(f"------------- {RED_BACKGROUND} Cluster Info {RESET} ---------------")
def fetch_cluster_info():
    try:
        process = subprocess.Popen(  # Process to get Cluster ID and Incarnation ID
            ["bash","/home/cohesity/bin/cluster_config.sh", "fetch"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        process.wait()
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")  
    if process.returncode == 0:
        stdout, stderr = process.communicate()
        stdout = stdout.decode('utf8')
        stderr = stderr.decode('utf8')
        try:
            cat_output = subprocess.check_output("cat /tmp/cluster_config | egrep 'cluster_id|cluster_incarnation|cluster_name' | head -3", shell=True)
            cat_output = cat_output.decode('utf-8')
            print(cat_output)
        except subprocess.CalledProcessError as e:
            print(f"Error running cat: {e}")
    else:
        print("No Output from Cluster Config")
fetch_cluster_info()
print("")

# Product Helper Section
print(f"------------- {RED_BACKGROUND} Node Information {RESET} ---------------")
cohesity_node_cmd = f"product_helper --op=GET_PRODUCT_BRIEF"
CHSERIAL = (subprocess.check_output(cohesity_node_cmd, shell=True).decode().strip())
print(f"{CHSERIAL}")
print ("")

print(f"------------- {RED_BACKGROUND} Node Ip Info {RESET} ---------------")
print('{:<15s}  {:<13s}  {:<25s}'.format('Interface', 'State', 'IPs'))
# Get Interface information
output = subprocess.check_output(['ip', '-4', '-brief', 'address', 'show'])
output = output.decode('utf-8')  # Convert bytes to string
# Filter output to only show lines that start with "br0"
output_lines = output.split('\n')
br0_lines = [line for line in output_lines if line.startswith('br0')]
# Extract the desired fields from each line
result = []
for line in br0_lines:
    fields = line.split('@')
    if len(fields) > 1:
        result.append((fields[0], fields[1]))
    else:
        result.append((fields[0], ''))
# Print the final result
for interface, ip_address in result:
    print(f'{interface} {ip_address}')
print("")

# Get Software upgrade history
print(f"------------- {RED_BACKGROUND} Software Version History {RESET} ---------------")
try:
    subprocess.call(['cat', "/home/cohesity/data/nexus/software_version_history.json"])
except FileNotFoundError:
    print("File Not found.")
print("")

print(f"------------- {RED_BACKGROUND} Service Version Check {RESET} ---------------")
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
def main():
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
    # Print current date and list of services
    print(f"{datetime.now()}\nChecking versions of the following: {', '.join(services)}\n")
    print(f"{'Service Name:':<30} {'Version'}")
    print("------------- --------------------------------------------------------")
    # Store versions in a dictionary
    versions = {service: get_version(service) for service in services}
    # Sort the services by name
    sorted_services = sorted(versions.keys())
    # Print sorted records
    for service in sorted_services:
        version = versions[service]
        print(f"{service:<30} {version}")
if __name__ == "__main__":
    main()
print("")

# Get Log FATALs
print(f"------------- {RED_BACKGROUND} Latest Fatals On Node {RESET} ---------------")
print("")
print(f"========= {RED_BACKGROUND}Bridge FATAL Log{RESET} =========")
os.system("cat /home/cohesity/logs/bridge_exec.*FATAL | head")
print("")
print(f"========= {RED_BACKGROUND}Bridge_proxy FATAL Log{RESET} =========")
os.system("cat /home/cohesity/logs/bridge_proxy_exec.*FATAL | head")
print("")
print(f"========= {RED_BACKGROUND}Magneto FATAL Log{RESET} =========")
os.system("cat /home/cohesity/logs/magneto_exec.*FATAL | head")
print("")
print(f"========= {RED_BACKGROUND} Yoda FATAL Log {RESET} =========")
os.system("cat /home/cohesity/logs/yoda_exec.*FATAL | head")
print("")
print(f"========= {RED_BACKGROUND} Apollo FATAL Log {RESET} =========")
os.system("cat /home/cohesity/logs/apollo_exec.*FATAL | head")
print("")
print(f"========= {RED_BACKGROUND} Groot FATAL Log {RESET} =========")
os.system("cat /home/cohesity/logs/groot_exec.*FATAL | head")
print("")
print(f"========= {RED_BACKGROUND} Nexus FATAL Log {RESET} =========")
os.system("cat /home/cohesity/logs/nexus_exec.*FATAL | head")
print("")
print(f"========= {RED_BACKGROUND}Nexus Proxy FATAL Log{RESET} =========")
os.system("cat /home/cohesity/logs/nexus_proxy_exec.*FATAL | head")
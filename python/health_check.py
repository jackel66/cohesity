#!/usr/bin/env python3

import subprocess
import socket
import fcntl
import struct
import os
import shutil

# ANSI escape sequences for red color and bold text
RED_BACKGROUND = '\033[41m'
BOLD = '\033[1m'
# ANSI escape sequence to reset text formatting
RESET = '\033[0m'

# Check OS Information

uptime = "uptime | grep days | awk  -F ',' '{print $1}'"                                                     
output = os.popen(uptime).read().strip()
dateo = os.popen('date').read().strip()
print(f"Current Date: {dateo}")
print(f"Server Uptime: {output}")

subprocess.call(["sh","/home/support/utils/fs_check.sh"])
print("")

# Processes to check
processes = ['aegis', 'alerts', 'apollo', 'athena', 'atom', 'bifrost', 'bifrost_broker', 'bridge', 'bridge_proxy', 'compass', 'eagle_agent', 'elrond', 'etl_server', 'gandalf', 'groot', 'heimdall', 'icebox', 'iris', 'iris_proxy', 'janus', 'keychain', 'librarian', 'logwatcher', 'magneto', 'newscribe', 'nexus', 'nexus_proxy', 'nfs_proxy', 'node_exporter', 'patch', 'pushclient', 'rtclient', 'smb2_proxy', 'smb_proxy', 'spire_agent', 'spire_server', 'stats', 'statscollector', 'storage_proxy', 'throttler', 'vault_proxy', 'yoda']

# Unicode Marks
CHECKMARK = "\N{check mark}"
CROSSMARK = "\N{cross mark}"

# Header for Output
print('{:<15s}  {:<10s}  {:<10s}  {:<5s}'.format('Process', 'State', 'Status', 'PID'))
print('----------------------------------------------------------------')

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
print("-------------------------------")

print("")
# Product Helper Section
chassis_fw_cmd = f"product_helper  -op=LIST_FIRMWARE_VERSION"

COFW = (subprocess.check_output(chassis_fw_cmd, shell=True).decode().strip())

print(f"Firmware: {COFW}\n")

print("")
print("-------------------------------")

# Product Helper Section
print("Node Information")
print("-------------------------------")
cohesity_node_cmd = f"product_helper --op=GET_PRODUCT_BRIEF"
CHSERIAL = (subprocess.check_output(cohesity_node_cmd, shell=True).decode().strip())

print(f"{CHSERIAL}")
print ("")

print("Node IP Configs")
print("-------------------")
print('{:<15s}  {:<13s}  {:<25s}'.format('Interface', 'State', 'IPs'))
print("---------------------------------------------------------------------------")
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

# Adding Space between checks
print("")

# Get Services Versions
subprocess.call(["sh","/home/support/utils/service_check.sh"])

print("")
# Get Log FATALs
print("")
print(f"========={RED_BACKGROUND}Bridge FATAL Log{RESET}=========")
os.system("cat /home/cohesity/logs/bridge_exec.*FATAL | head")
print("")
print(f"========={RED_BACKGROUND}Bridge_proxy FATAL Log{RESET}=========")
os.system("cat /home/cohesity/logs/bridge_proxy_exec.*FATAL | head")
print("")
print(f"========={RED_BACKGROUND}Magneto FATAL Log{RESET}=========")
os.system("cat /home/cohesity/logs/magneto_exec.*FATAL | head")
print("")
print(f"========={RED_BACKGROUND}Yoda FATAL Log{RESET}=========")
os.system("cat /home/cohesity/logs/yoda_exec.*FATAL | head")
print("")
print(f"========={RED_BACKGROUND}Apollo FATAL Log{RESET}=========")
os.system("cat /home/cohesity/logs/apollo_exec.*FATAL | head")
print("")
print(f"========={RED_BACKGROUND}Groot FATAL Log{RESET}=========")
os.system("cat /home/cohesity/logs/groot_exec.*FATAL | head")
print("")
print(f"========={RED_BACKGROUND}Nexus FATAL Log{RESET}=========")
os.system("cat /home/cohesity/logs/nexus_exec.*FATAL | head")
print("")
print(f"========={RED_BACKGROUND}Nexus Proxy FATAL Log{RESET}=========")
os.system("cat /home/cohesity/logs/nexus_proxy_exec.*FATAL | head")
#!/usr/bin/env python3
#
# Authort: Doug Austin
# Date: 8/23/2023


import os
import socket
import logger_config
import send_syslog

def get_interfaces_with_ip():
    interfaces = []
    with open('/proc/net/dev', 'r') as f:
        lines = f.readlines()[2:]
        for line in lines:
            interface = line.split(':')[0].strip()
            if check_interface_ip(interface):
                interfaces.append(interface)
    return interfaces

def check_interface_ip(interface):
    with open('/sys/class/net/{}/operstate'.format(interface), 'r') as f:
        status = f.read().strip()

    if status != 'up':
        return False

    output = os.popen('ip addr show {}'.format(interface)).read()
    if 'inet ' in output:
        return True
    else:
        return False

# Get interfaces with assigned IP addresses
interfaces = get_interfaces_with_ip()

# Print interface details and status
for interface in interfaces:
    status = check_interface_ip(interface)
    state = 'UP' if status else 'DOWN'
    logger_config.logging.info(f"Interface: {interface}, State: {state}")

    if state == 'DOWN':
        logger_config.logger.error(f"Interface: {interface}, State: {state}")
        from send_syslog import send_syslog_message, syslog_host, syslog_port
        failed_nic_text = f'"Interface down: {(interface)}"'
        cluster_name = f'"{(send_syslog.value)}"'
        attributes = {
            '"ClusterName"': cluster_name,
            '"AlertCode"': '"CH00000002"',
            '"AlertName"': '"NetworkInterfaceDown"',
            '"AlertSeverity"': '"WARNING"',
            '"AlertDescription"': failed_nic_text,
            '"AlertCause"': '"Network Interface is Down."',
        }    
        send_syslog_message(syslog_host, syslog_port, attributes)

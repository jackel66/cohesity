#!/usr/bin/env python3
#
# Authort: Doug Austin
# Date: 8/23/2023

import logger_config
import subprocess
import send_syslog

def check_reachability(ip):
    try:
        # Use the ping command to check ip reachability
        subprocess.check_output(["sudo", "ping", "-c", "1", "-W", "2", ip], stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False

def main():
    # Get the IPs configured on the host
    ip_output = subprocess.check_output("ip -4 addr show", shell=True)

    ip_output = ip_output.decode("utf-8")

    ips = []
    interfaces = set()
    for line in ip_output.splitlines():
        if "inet" in line:
            split_line = line.split()
            if len(split_line) >= 7:
                ip = split_line[1].split("/")[0]
                interface = split_line[6]
                if interface.startswith("br0") and ip.startswith("10") and interface not in interfaces:
                    interfaces.add(interface)
                    ips.append((interface, ip))
                    
    # Loop through ips and check for reachability.. alert when something is not reachable
    for interface, ip in ips:
        if check_reachability(ip):
            logger_config.logging.info(f"IP {ip} is reachable on Interface: {interface}")
        else:
            logger_config.logging.error(f"IP {ip} is not reachable on Interface {interface}")
            from send_syslog import send_syslog_message, syslog_host, syslog_port
            failed_ip_text = f'"IP {ip} is not reachable on Interface {(interface)}"'
            cluster_name = f'"{(send_syslog.value)}"'
            attributes = {
                '"ClusterName"': cluster_name,
                '"AlertCode"': '"CH00000004"',
                '"AlertName"': '"IPNotReachable"',
                '"AlertSeverity"': '"CRITICAL"',
                '"AlertDescription"': failed_ip_text,
                '"AlertCause"': '"There is an IP that is not reachable, check the node and ensure connectivity"',
            }    
            send_syslog_message(syslog_host, syslog_port, attributes)
            
if __name__ == "__main__":
    main()

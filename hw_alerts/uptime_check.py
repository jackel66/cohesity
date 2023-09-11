#!/usr/bin/env python3
#
# Authort: Doug Austin
# Date: 8/23/2023

import logger_config
import send_syslog
import socket
import subprocess


def get_linux_uptime():
    output = subprocess.check_output(["sudo", "uptime", "-p"]).decode("utf-8").strip()
    return output

def main():
    uptime = get_linux_uptime()

    # Extract the number of hours from the uptime string
    uptime_hours = int(uptime.split()[3].split()[0]) 
    if uptime_hours < 1:
        logger_config.logger.error(f"Server has been online less than 1 hours")
        from send_syslog import send_syslog_message, syslog_host, syslog_port
        uptime_text = f'"Server Uptime: {(uptime_hours)} hours"'
        cluster_name = f'"{(send_syslog.value)}"'
        attributes = {
            '"ClusterName"': cluster_name,
            '"AlertCode"': '"CH00000003"',
            '"AlertName"': '"ServerRebooted"',
            '"AlertSeverity"': '"CRITICAL"',
            '"AlertDescription"': uptime_text ,
            '"AlertCause"': '"Server Rebooted less than 1 hours ago."'
        }    
        send_syslog_message(syslog_host, syslog_port, attributes)
    else:
        logger_config.logging.info(f"Server has been online for 1 hour or longer")
        #print(send_syslog.value)

if __name__ == "__main__":
    main()


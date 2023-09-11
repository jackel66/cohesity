#!/usr/bin/env python3
#
#
import logger_config
import socket
import subprocess


def get_linux_uptime():
    output = subprocess.check_output(["sudo", "uptime", "-s"]).decode("utf-8").strip()
    return output

def main():
    uptime = get_linux_uptime()

    # Extract the number of hours from the uptime string
    uptime_hours = int(uptime.split()[1].split(":")[0]) 

    if uptime_hours < 1:
        logger_config.logger.error(f"Server has been online less than 1 hours")
        from send_syslog import send_syslog_message, syslog_host, syslog_port
        uptime_text = f'"Server Uptime: {(uptime_hours)}"'
        attributes = {
            "AlertCode": '"CH0000003"',
            "AlertName": '"Server Rebooted"',
            "AlertSeverity": '"CRITICAL"',
            "AlertDescription": uptime_text ,
            "AlertCause": '"Server Rebooted less than 1 hours ago."',
            "HostName": socket.gethostname()
        }    
        send_syslog_message(syslog_host, syslog_port, attributes)
    else:
        logger_config.logging.info(f"Server has been online for 1 hour or longer")

if __name__ == "__main__":
    main()

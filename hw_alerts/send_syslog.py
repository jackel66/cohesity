#!/usr/bin/env python3
#
# Authort: Doug Austin
# Date: 8/23/2023
# Script to connect to Splunk and send a message
# Set syslog server and port in this script


import socket
import logger_config

# Syslog Server and Port information
syslog_host = 'syslogvip.capgroup.com'  # <<< Change to syslog server name
syslog_port = 514                       # <<< Change to syslog server port

# Get Cluster name from alerting system
hostname = socket.gethostname()
parts = hostname.split("-")
value = "-".join(parts[:2])

def send_syslog_message(syslog_host, syslog_port, attributes=None):
    # Create a TCP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    try:
        # Connect to the syslog server
        sock.connect((syslog_host, syslog_port))
        original_host = socket.gethostname()
        formatted_message = f"{original_host} cohesity_alerts: "

        # Add structured data attributes
        if attributes is not None:
            attribute_list = []
            for key, value in attributes.items():
                if key == "original_host":
                    attribute_list.append(f'{key}: "{value}"')
                else:
                    attribute_list.append(f'{key}: {value}')
            formatted_message += "{" + ", ".join(attribute_list) + "}"
            

        # Send the syslog message
        sock.sendall(formatted_message.encode())
        logger_config.logging.info(f"Splunk alert sent successfully.")
        
    except socket.error as e:
        logger_config.logging.error(f"Failed to send message to splunk")
    finally:
        sock.close()



 

#!/usr/bin/env python3
#
# Script to connect to Splunk and send a message
# Set syslog server and port in this script


import socket
import logger_config

# Syslog Server and Port information
syslog_host = 'syslogvip.capgroup.com'
syslog_port = 514


def send_syslog_message(syslog_host, syslog_port, attributes):
    # Create a TCP socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    try:
        # Connect to the syslog server
        sock.connect((syslog_host, syslog_port))
        original_host = socket.gethostname()
        formatted_message = f"cohesity_alerts:"

        attributes['original_host'] = original_host

        # Add structured data attributes
        for key, value in attributes.items():
            formatted_message += f" {key}={value}"

        # Send the syslog message
        sock.sendall(formatted_message.encode())
        #print("Sender_syslog.py - Syslog message sent successfully.")
        logger_config.logging.info(f"Splunk alert sent successfully.")
        
    except socket.error as e:
        #print("Failed to send syslog message:", e)
        logger_config.logging.error(f"Failed to send message to splunk")
    finally:
        sock.close()



 
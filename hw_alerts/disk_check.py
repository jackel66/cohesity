#!/usr/bin/env python3
#
#
import subprocess
import socket
import logger_config


# Run lsblk command and capture the output
lsblk_output = subprocess.check_output(['lsblk', '-o', 'KNAME,TYPE,SIZE,MODEL']).decode()

# Find all disks in the output
disks = []
for line in lsblk_output.splitlines():
    if 'disk' in line:
        disk = line.split()[0]
        disks.append(disk)

# Place to store disk assessments
disk_assessments = {}

# Iterate over each disk
for disk in disks:
    # Run smartctl command and capture the output
    smartctl_output = subprocess.check_output(['sudo', 'smartctl', '-H', '/dev/' + disk]).decode()

    # Find the assessment value in the output
    assessment = None
    for line in smartctl_output.splitlines():
        if 'assessment' in line:
            assessment = line.split()[5]
            break

    # Store the assessment in the dictionary
    disk_assessments[disk] = assessment

    # Evaluate Log Disk Failures and paste log info
    if assessment != 'PASSED':
        logger_config.logger.error(f"Disk {disk} - SMART Test: {assessment}")
    if assessment == 'PASSED':
        logger_config.logging.info(f"Disk: {disk} - SMART Test: {assessment}")


failed_disks = [disk for disk, assessment in disk_assessments.items() if assessment != 'PASSED']
if len(failed_disks) > 0:
    from send_syslog import send_syslog_message, syslog_host, syslog_port
    failed_disks_text = f'"Disks that Failed Self-Test: {", ".join(failed_disks)}"'
    attributes = {
            "AlertCode": '"CH0000001"',
            "AlertName": '"Disk SMART Test Failed"',
            "AlertSeverity": '"CRITICAL"',
            "AlertDescription": failed_disks_text,
            "AlertCause": '"SMART Tests have failed on one or more disks."',
            "HostName": socket.gethostname()
    }    
    send_syslog_message(syslog_host, syslog_port, attributes)






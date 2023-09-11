#!/usr/bin/env python3
#
# Authort: Doug Austin
# Date: 8/23/2023
#
# Desc: This is the primary execution script for all hardware alerts. 

import subprocess
import logger_config


# Path to each test/alert script
script_paths = [
    '/home/support/alerts/net_check.py',
    '/home/support/alerts/ip_reach_check.py',
    '/home/support/alerts/disk_check.py',
    '/home/support/alerts/uptime_check.py',
    '/home/support/alerts/magneto_memory_alerts.py',
    '/home/support/alerts/memory_test.py'
]
# Executing the Scripts as Sudo
for script in script_paths:
    try:
        subprocess.run(["sudo", "python3", script])
    except subprocess.CalledProcessError as e:
        logger_config.logger.error(f"Sciprt {script}: {e}")




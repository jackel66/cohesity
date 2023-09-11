#!/usr/bin/env python3
#
#
import subprocess
import logger_config

script_paths = [
    '/home/support/utils/alerts/net_check.py',
    '/home/support/utils/alerts/ip_reach_check.py',
    '/home/support/utils/alerts/disk_check.py',
    '/home/support/utils/alerts/uptime_check.py'
]

for script in script_paths:
    try:
        subprocess.run(["sudo", "python3", script])
    except subprocess.CalledProcessError as e:
        logger_config.logger.error(f"Sciprt {script}: {e}")




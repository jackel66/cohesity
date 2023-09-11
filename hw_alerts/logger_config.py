#!/usr/bin/env python3
#
#
import logging

# Log File location and basic logging inforamtion
logging.basicConfig(filename='/var/log/healthcheck.log', level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s', filemode='a')

# Additional Logger information to set an ERROR level
error_handler = logging.FileHandler('/var/log/healthcheck.ERROR.log')
error_handler.setLevel(logging.ERROR)
error_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
error_handler.setFormatter(error_formatter)
logger = logging.getLogger()
logger.addHandler(error_handler)

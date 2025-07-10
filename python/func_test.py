#!/usr/bin/env python3
# Author: Doug Austin
# Date: 08/05/2023
# Summary: This script pulls file system information, Service PIDs, Service Versions, Hardware Firmware versions, Fatal Log Entries
# to be given to cohesity support. 

import subprocess
import socket
import fcntl
import struct
import os
import shutil
import sys
sys.path.append('/home/support/utils/functions/')
from my_functions import get_node_uptime, fetch_cluster_info

# Begin Executing Checks

# Grab Node uptime
get_node_uptime()

# Grab Cluster Info from cluster_dump
fetch_cluster_info()


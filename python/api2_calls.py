#!/usr/bin/env python3
# 
# Author: Doug Austin
# Date: 8/14/23
#
# Description: This script will look at all Magneto and Bridge_proxy Log files in the provided time interval
#              it will extract the values for API calls and perform some calculations to produce the total,   
#              refresh and throttled calls made to O365. 
#
# Original Script: Sahil Dhull (sahil.dhull@cohesity.com)
#
# Usage: ./api-calls.py 
# Note: Run as sudo or cohesity user. 
#
import subprocess
from datetime import datetime, timedelta

# Set initial values
overall_total_calls = 0
total_refresh_calls = 0
total_backup_calls = 0
total_throttled_calls = 0

# Get the current date and time
current_date = datetime.now()

# Change this option to process logs for the last hour or every 4 hours
process_interval = "hour"  # Change to "4hours" to process every 4 hours

if process_interval == "hour":
    start_date = current_date - timedelta(hours=1)  # Start from one hour ago
    interval = timedelta(hours=1)
elif process_interval == "4hours":
    start_date = current_date - timedelta(hours=4)  # Start from 4 hours ago
    interval = timedelta(hours=4)
else:
    raise ValueError("Invalid process_interval option")

hour = start_date.strftime("%H")
mmdd = start_date.strftime("%m%d")

# Construct the find command to locate relevant log files modified in the interval
find_command_magneto = f"find /home/cohesity/logs/ -name 'magneto_exec.*INFO*' -newermt '{start_date.strftime('%Y-%m-%d %H:%M:%S')}'"
find_command_bridge_proxy = f"find /home/cohesity/logs/ -name 'bridge_proxy_exec.*INFO*' -newermt '{start_date.strftime('%Y-%m-%d %H:%M:%S')}'"

# Execute the find command to get the list of relevant log files
magneto_log_files = subprocess.check_output(find_command_magneto, shell=True, universal_newlines=True).splitlines()
bridge_proxy_log_files = subprocess.check_output(find_command_bridge_proxy, shell=True, universal_newlines=True).splitlines()

log_output = []  # To store log lines

for magneto_log_file in magneto_log_files:

    # Construct the zgrep commands
    magneto_single_calls_one_hour_cmd = (
        f"zgrep 'I{mmdd} {hour}.*graph_base_op.cc.*Refreshing the token. Attempt number' {magneto_log_file} | wc -l"
    )
    magneto_batch_calls_one_hour_cmd = (
        f"zgrep 'I{mmdd} {hour}.*generic_batch_request_op.cc.*Making a batch request of size' {magneto_log_file} | wc -l"
    )
    refresh_single_calls_one_hour_cmd = (
        f"zgrep 'I{mmdd} {hour}.*graph_base_op.cc.*Task id -1: Refreshing the token. Attempt number' {magneto_log_file} | wc -l"
    )
    refresh_batch_calls_one_hour_cmd = (
        f"zgrep 'I{mmdd} {hour}.*generic_batch_request_op.cc.*Task id -1: Making a batch request of size' {magneto_log_file} | wc -l"
    )
    magneto_throttled_calls_one_hour_cmd = (
        f"zgrep 'I{mmdd} {hour}.*graph_base_op.cc.*Received error in MS Graph Response.*The request has been throttled' {magneto_log_file} | wc -l"
    )

    # Execute the zgrep commands and get the counts
    magneto_single_calls_one_hour = int(subprocess.check_output(magneto_single_calls_one_hour_cmd, shell=True))
    magneto_batch_calls_one_hour = int(subprocess.check_output(magneto_batch_calls_one_hour_cmd, shell=True))
    refresh_single_calls_one_hour = int(subprocess.check_output(refresh_single_calls_one_hour_cmd, shell=True))
    refresh_batch_calls_one_hour = int(subprocess.check_output(refresh_batch_calls_one_hour_cmd, shell=True))
    magneto_throttled_calls_one_hour = int(subprocess.check_output(magneto_throttled_calls_one_hour_cmd, shell=True))
 

    # Perform calculations based on extracted data
    total_magneto_calls_one_hour = (
        magneto_single_calls_one_hour +
        magneto_batch_calls_one_hour * 19
    )
    refresh_total_calls_one_hour = (
        refresh_single_calls_one_hour +
        refresh_batch_calls_one_hour * 19
    )
    total_refresh_calls += refresh_total_calls_one_hour
    overall_total_calls += total_magneto_calls_one_hour
    total_throttled_calls += magneto_throttled_calls_one_hour

for bridge_proxy_log_file in bridge_proxy_log_files:

    bridge_proxy_single_calls_one_hour_cmd = (
        f"zgrep 'I{mmdd} {hour}.*graph_base_op.cc.*Refreshing the token. Attempt number' {bridge_proxy_log_file} | wc -l"
    )
    bridge_proxy_batch_calls_one_hour_cmd = (
        f"zgrep 'I{mmdd} {hour}.*generic_batch_request_op.cc.*Making a batch request of size' {bridge_proxy_log_file} | wc -l"
    )
    bridge_proxy_throttled_calls_one_hour_cmd = (
        f"zgrep 'I{mmdd} {hour}.*graph_base_op.cc.*Received error in MS Graph Response.*The request has been throttled' {bridge_proxy_log_file} | wc -l"
    )

    # Execute the zgrep commands and get the counts
    bridge_proxy_single_calls_one_hour = int(subprocess.check_output(bridge_proxy_single_calls_one_hour_cmd, shell=True))
    bridge_proxy_batch_calls_one_hour = int(subprocess.check_output(bridge_proxy_batch_calls_one_hour_cmd, shell=True))
    bridge_proxy_throttled_calls_one_hour = int(subprocess.check_output(bridge_proxy_throttled_calls_one_hour_cmd, shell=True))

    # Perform calculations based on extracted data
    total_bridge_proxy_calls_one_hour = (
        bridge_proxy_single_calls_one_hour +
        bridge_proxy_batch_calls_one_hour * 19
    )
    overall_total_calls += total_bridge_proxy_calls_one_hour
    total_throttled_calls +=  bridge_proxy_throttled_calls_one_hour

total_backup_calls = overall_total_calls - total_refresh_calls

# Print the final metrics to be written to log file
final_metrics = [
    f"Timestamp:            {current_date.strftime('%m-%d-%Y %H:%M:%S')}",
    f"Total calls:          {overall_total_calls:20}",
    f"Total refresh calls:  {total_refresh_calls:20}",
    f"Total backup calls:   {total_backup_calls:20}",
    f"Total throttled calls: {total_throttled_calls:19}"
]

# Combine log lines and final metrics
log_output.extend(final_metrics)
#log_output.append(' '.join(final_metrics))

# Write the log to a file
log_file_path = "/home/support/utils/apicalls.out"
with open(log_file_path, "a") as log_file:
    for line in log_output:
        log_file.write(line + "\n")
    log_file.write("\n")

# Print the final metrics to the console

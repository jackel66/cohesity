#!/usr/bin/env python3
#
# Authort: Doug Austin
# Date: 8/23/2023

import os
import logger_config
import subprocess
import send_syslog

# Setup to get Threashold configured on cluster
command1 = "elinks -dump-width 1024 \"`links http:localhost:20000 | awk '/master/{print $2}' |sed 's/master//'`flagz\" > /tmp/flagz.txt"
subprocess.run(command1, shell=True)
# Execute commands against temp file to get set threasold
command2 = "cat /tmp/flagz.txt | grep memory_usage_checker_additional | awk -F '=' '{print $2}' | awk '{print $1}'"
result = subprocess.check_output(command2, shell=True)
# Cleanup temp file created in command1
command3 = "sudo rm -f /tmp/flagz.txt"
subprocess.run(command3, shell=True)

# Define Threashold and calculate 80% 
Threashold = int(result)
eighty_percent_threashold = int(Threashold * 0.8)
percentage = int(Threashold * 0.8)
calc_percent = (percentage / Threashold) * 100


def main():
    # Execute the magneto_mem_check.sh script using subprocess
    result = subprocess.run(['/home/support/alerts/magneto_mem_check.py'], stdout=subprocess.PIPE, shell=True)
    output_lines = result.stdout.decode('utf-8').split('\n')
    
    # Remove any empty lines from the output_lines list
    output_lines = [line.strip() for line in output_lines if line.strip()]

    if len(output_lines) >= 1:
        third_line = output_lines[0]  # Assuming the value is in the first line
        extracted_value = extract_value(third_line)

        if extracted_value is not None:
            if extracted_value > eighty_percent_threashold:
                # Perform an action when the value is over the value Threashold
                logger_config.logger.error(f"Magneto memory is approaching 80% of max threashold: {eighty_percent_threashold} MB, Sending Alert")
                from send_syslog import send_syslog_message, syslog_host, syslog_port
                failed_mem_text = f'"Magneto memory is has reached {extracted_value} MB, above the 80% threashold of {eighty_percent_threashold} MB"'
                cluster_name = f'"{(send_syslog.value)}"'
                attributes = {
                    '"ClusterName"': cluster_name,
                    '"AlertCode"': '"CH00000005"',
                    '"AlertName"': '"MagnetoOutOfMemory"',
                    '"AlertSeverity"': '"WARNING"',
                    '"AlertDescription"': failed_mem_text,
                    '"AlertCause"': '"Magneto is consuming too much memory, Service Crash likely soon, open support case with Cohesity"',
                }    
                send_syslog_message(syslog_host, syslog_port, attributes)   
                
            else:
                # Write the current output to a log file
                logger_config.logger.info(f"Current Magneto Memory Allocated: {extracted_value} MB, below the 80% threashold of {eighty_percent_threashold} MB")
        else:
            print("Value extraction failed")
    else:
        print("Not enough lines in the output")

def extract_value(line):
    # Extract the value from a line of the format "magneto (PID): VALUE MB"
    value_start = line.find(':') + 2  # Find the position after the colon and space
    value_end = line.find(' MB', value_start)  # Find the position before " MB"
    
    if value_start != -1 and value_end != -1:
        value_part = line[value_start:value_end]
        try:
            extracted_value = int(value_part)
            return extracted_value
        except ValueError:
            return None
    else:
        return None

if __name__ == "__main__":
    main()








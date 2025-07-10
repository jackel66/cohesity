#!/usr/bin/env python3
#
# Authort: Doug Austin
# Date: 8/23/2023

import subprocess
from datetime import datetime

# Define the command to retrieve the URL with 'links'
links_command = 'links http://localhost:20000'


# Get Current Date/Time
current_datetime = datetime.now().strftime("%m-%d-%Y %H:%M:%S")

# Execute the 'links' command and capture its output
try:
    links_output = subprocess.check_output(links_command, shell=True, universal_newlines=True)
except subprocess.CalledProcessError as e:
    print("Error executing the 'links' command:", e)
    exit(1)

# Extract the URL using 'awk'
url_extraction_command = "awk '/master/{print $2}' | sed 's/master//'"
url = subprocess.check_output(f'echo "{links_output}" | {url_extraction_command}', shell=True, universal_newlines=True).strip()

# Build the final 'elinks' command
elinks_command = f'elinks -dump-width 1024 "{url}o365z" > /tmp/o365z.txt'

# Execute the 'elinks' command
try:
    subprocess.run(elinks_command, shell=True, check=True, executable='/bin/bash')
    #print("Command executed successfully.")
except subprocess.CalledProcessError as e:
    print("Error executing the 'elinks' command:", e)


# Define the file path
file_path = '/tmp/o365z.txt'

# Read the data from the file
try:
    with open(file_path, 'r') as file:
        lines = file.readlines()
except FileNotFoundError:
    print(f"File '{file_path}' not found.")

# Initialize Values
start_printing = False
remaining_sum = 0
completed_sum = 0
failed_sum = 0
job_descriptions = {}

# Define the headers
headers = ["Job Id", "Job Description", "Local", "Running", "Running", "Completed", "Failed"]

print(f"Time: {current_datetime}\n")

# Display the data in a formatted table
for line in lines:
    if line.strip() == "" and not start_printing:
        continue
    elif "Job Id" in line and not start_printing:
        start_printing = True
        print("{:<6} {:<25} {:<5} {:<10} {:<7} {:<2} {:<2}".format(*headers))
    elif "SJX1_Prod" in line:
        columns = line.split()
        print(line.strip())
        
        # Checks to see if the job is running, if Yes then sum the Remaining, Completed, Failed
        if columns[3] == "Yes":
            remaining_sum += int(columns[-5])
            completed_sum += int(columns[-3])
            failed_sum += int(columns[-1])
        elif columns[3] == "No":   
           job_descriptions[columns[0]] = columns[1]


print()
print("Total Running Objects:", remaining_sum)
print("Total Completed Objects:", completed_sum)
print("Total Failed Objects:", failed_sum)
print()
print("------------------------------------------------------------------------------")

# Template activity from get_powershell tasks.py
print("Total Template Backups Pending/Active")
print("Job Name               Count")
try:
    subprocess.run(["sudo", "python3", "get_powershelltasks.py"], check=True)
except subprocess.CalledProcessError as e:
    print("Failed to execute get_powershelltasks.py script")

print()
print("Active Template Tasks This Node")
try:
    subprocess.run(["bash", "ps_tasks.sh"], check=True)
except subprocess.CalledProcessError as e:
    print("Failed to execute ps_tasks.sh script")
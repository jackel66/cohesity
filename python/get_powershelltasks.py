#!/usr/bin/env python3
#
# Authort: Doug Austin
import subprocess
from datetime import datetime


## This section gets all the info from Siren for calculations##
#---------------------------------------------------------------------#
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
elinks_command = f'elinks -dump-width 1024 "{url}backup_job" > /tmp/backup_job.txt'

# Execute the 'elinks' command
try:
    subprocess.run(elinks_command, shell=True, check=True, executable='/bin/bash')
    #print("Command executed successfully.")
except subprocess.CalledProcessError as e:
    print("Error executing the 'elinks' command:", e)

cleanup_backup_jobs = ["cat", "/tmp/backup_job.txt", "|", "grep", "SJX1_Prod", "|", "awk", "'{print $1, $2}'", "|", "awk", "-F ':'", "'{print $3}'", ">", "/tmp/jobs.txt"]
slave_list = ["elinks", "-dump", "'http://<IP of Cluster>20000/tracez?component=MagnetoSlave&bucket=0#tracebanner'", ">", "/tmp/slavetrace.txt"] # Add IP{ of Cluster
try:
    subprocess.run(" ".join(cleanup_backup_jobs), shell=True, check=True)
    subprocess.run(" ".join(slave_list), shell=True, check=True)
except subprocess.CalledProcessError as e:
    print("Failed to execute commands")
#---------------------------------------------------------------------#

# Start calulations for Template backups in progress
count = {}
job_id_lookup = {}
job_name_count = {}

# Reads the lookup file to match job ids to Protection Group Names
with open('/tmp/jobs.txt', 'r') as lookup_file:
    for line in lookup_file:
        key, value = line.strip().split()
        job_id_lookup[key] = value

# Reads the output from the Slave page
with open('/tmp/slavetrace.txt', 'r') as file:
    for line in file:
        if 'SharepointTemplatePowershellBackupOp' in line:
            words = line.split()
            
            modified_line = []

            for i, word in enumerate(words):
                if word.startswith('job_id='):
                    job_id = word.split('=')[1]
                    if job_id in job_id_lookup:
                        job_name = job_id_lookup[job_id]
                        words[i] = f'job_name={job_id_lookup[job_id]}'

                        if job_name in job_name_count:
                            job_name_count[job_name] += 1
                        else:
                            job_name_count[job_name] = 1
            
            modified_line = ' '.join(words)

            if modified_line in count:
                count[modified_line] += 1
            else:
                count[modified_line] = 1

# Print the results to temrinal
for job_name, job_count in job_name_count.items():
    print(f'{job_name}', job_count)
                                     

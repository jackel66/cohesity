#!/usr/bin/env python3

import subprocess
from datetime import datetime
import re

# Get Current Date/Time
current_datetime = datetime.now().strftime("%m-%d-%Y %H:%M:%S")

# Execute the 'links' command and capture its output
try:
    links_output = subprocess.check_output(
        ['links', 'http://localhost:20000'],
        universal_newlines=True
    )
except subprocess.CalledProcessError as e:
    print("Error executing the 'links' command:", e)
    exit(1)

# Extract the URL containing 'master'
url = ""
for line in links_output.splitlines():
    if 'master' in line:
        parts = line.split()
        if len(parts) > 1:
            url = parts[1].replace('master', '')
            break

if not url:
    print("No URL containing 'master' found.")
    exit(1)

# Build and execute the 'elinks' command
elinks_command = [
    'elinks', '-dump-width', '1024', f"{url}o365z"
]
try:
    with open('/tmp/o365z.txt', 'w') as outfile:
        subprocess.run(elinks_command, stdout=outfile, check=True)
except subprocess.CalledProcessError as e:
    print("Error executing the 'elinks' command:", e)
    exit(1)

# Read the data from the file
file_path = '/tmp/o365z.txt'
try:
    with open(file_path, 'r') as file:
        lines = file.readlines()
except FileNotFoundError:
    print(f"File '{file_path}' not found.")
    exit(1)

# Initialize Values
start_printing = False
remaining_sum = 0
completed_sum = 0
failed_sum = 0
job_descriptions = {}

# Define improved headers and column widths
headers = [
    "Job Id", "Job Description", "Local", "Running",
    "Remaining", "Completed", "Failed"
]
col_widths = [10, 60, 8, 8, 10, 10, 8]

header_fmt = (
    f"{{:<{col_widths[0]}}} {{:<{col_widths[1]}}} {{:<{col_widths[2]}}} "
    f"{{:<{col_widths[3]}}} {{:>{col_widths[4]}}} {{:>{col_widths[5]}}} {{:>{col_widths[6]}}}"
)
row_fmt = header_fmt

print(f"Time: {current_datetime}\n")
print(header_fmt.format(*headers))
print("-" * sum(col_widths))

for line in lines:
    if not start_printing:
        if "Job Id" in line:
            start_printing = True
        continue
    if "SJX1_Prod" in line:
        # Find the position of " Yes " or " No " (with spaces to avoid partial matches)
        if " Yes " in line:
            running_val = "Yes"
            parts = line.split(" Yes ", 1)
        elif " No " in line:
            running_val = "No"
            parts = line.split(" No ", 1)
        else:
            continue  # Skip lines that don't match

        # Left of running: job id, job desc, local, maybe more
        left = parts[0].strip().split()
        if len(left) < 3:
            continue  # Not enough columns

        job_id = left[0]
        local = left[-1]
        job_desc = " ".join(left[1:-1])

        # Right of running: remaining / completed / failed (or dashes)
        remaining = completed = failed = "-"
        if running_val == "Yes":
            right = parts[1].strip()
            # Try to split by '/' first, then by whitespace
            if "/" in right:
                right_parts = [x.strip() for x in right.split("/")]
            else:
                right_parts = right.split()
            # Only assign if we have at least 3 values
            if len(right_parts) >= 3:
                remaining, completed, failed = right_parts[:3]
                try:
                    remaining_sum += int(remaining)
                    completed_sum += int(completed)
                    failed_sum += int(failed)
                except Exception:
                    pass

        print(row_fmt.format(
            job_id, job_desc, local, running_val, remaining, completed, failed
        ))

print("-" * sum(col_widths))
print(f"{'Total Running Objects:':<{sum(col_widths)-10}}{remaining_sum:>10}")
print(f"{'Total Completed Objects:':<{sum(col_widths)-10}}{completed_sum:>10}")
print(f"{'Total Failed Objects:':<{sum(col_widths)-10}}{failed_sum:>10}")
print()

print("------------------------------------------------------------------------------")

# Template activity from get_powershell tasks.py
print("Total Template Backups Pending/Active")
print("Job Name               Count")
try:
    subprocess.run(["sudo", "python3", "get_powershelltasks.py"], check=True)
except subprocess.CalledProcessError:
    print("Failed to execute get_powershelltasks.py script")

print()
print("Active Template Tasks This Node")
try:
    subprocess.run(["bash", "ps_tasks.sh"], check=True)
except subprocess.CalledProcessError:
    print("Failed to execute ps_tasks.sh script")
#!/usr/bin/env python3

import subprocess
import sys
import os

LOGS_DIRECTORY = '/home/cohesity/logs/'

# ANSI escape sequences for red color and bold text
RED_BACKGROUND = '\033[41m'
BOLD = '\033[1m'
# ANSI escape sequence to reset text formatting
RESET = '\033[0m'

def run_tail_command(log_file, num_lines):
    command = ['tail', '-n', str(num_lines), log_file]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode == 0:
        return result.stdout.decode('utf-8')
    else:
        return result.stderr.decode('utf-8')

def run_head_command(log_file):
    command = ['head', log_file]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode == 0:
        return result.stdout.decode('utf-8')
    else:
        return result.stderr.decode('utf-8')

def main():
    if len(sys.argv) < 3:
        print("Usage: python script.py <service name> [-t[num_lines] | -h] [log level]")
        return

    service_name = sys.argv[1]
    option = sys.argv[2]
    num_lines = None
    log_level = "FATAL"  # Default log level if not specified

    if len(sys.argv) >= 3:
        if option.startswith('-t'):
            try:
                num_lines = int(option[2:])
                if len(sys.argv) >= 4:
                    log_level = sys.argv[3]
            except ValueError:
                log_level = sys.argv[3]
        else:
            log_level = sys.argv [3]

    log_file = os.path.join(LOGS_DIRECTORY, f"{service_name}_exec.{log_level}")

    if option.startswith("-t"):
        if num_lines is None:
            num_lines = 10 # Default lines to tail
        print(f"Tailing {num_lines} lines of log file: {RED_BACKGROUND}{BOLD}{log_file}{RESET}")
        output = run_tail_command(log_file, num_lines)
        print(output)
    elif option == "-h":
        print(f"Heading log file: {RED_BACKGROUND}{BOLD}{log_file}{RESET}")
        output = run_head_command(log_file)
        print(output)
    else:
        print("Invalid option. Usage: python script.py <service name> [-t[num_lines] | -h] [log level]")

    print('-' * 40)

if __name__ == '__main__':
    main()


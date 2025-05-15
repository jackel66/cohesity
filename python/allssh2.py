#!/usr/bin/env python3
#
# Author: Doug Austin
# Date: 6/20/23
# New version of Allssh.py that can be used with python
# More Efficient than allssh.sh and provides clearer responses from other nodes
# Verified with Cohesity 7.1.2 U3

# Required Libraries
import argparse
import subprocess
import sys

# Execution of Cmds 
def execute_command(ip, command):
    red_bg = "\033[41m"
    reset_color = "\033[0m"
    print(f"=========== {red_bg}{ip}{reset_color} ============")
    ssh_command = f'ssh -q -o StrictHostKeyChecking=no {ip} "{command}"'
    try:
        output = subprocess.check_output(ssh_command, shell=True, stderr=subprocess.STDOUT).decode('utf-8')
        print(output.strip())
        
    except subprocess.CalledProcessError as e:
        print(e.output.decode().strip())
        

# Run through all Nodes for Execution
def main():
    parser = argparse.ArgumentParser(description='SSH script to execute command on a remote host')
    parser.add_argument('command', type=str, help='Command to execute on remote host in quotes EX. allssh2.py "df -hl"')
    args = parser.parse_args()

    try:
        ips = subprocess.check_output(['hostips']).decode().strip().split()
    except FileNotFoundError:
        print('The "hostips" command is not found.')
        return
    
    try:
        for ip in ips:
            execute_command(ip, args.command)
    except KeyboardInterrupt:
        print('\nExecution killed by User')
        sys.exit(0)


if __name__ == '__main__':
    main()


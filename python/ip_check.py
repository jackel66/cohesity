#!/usr/bin/env python3

import subprocess
import re
import sys
#import logger_config

def check_ip_reachability(ip):
    command = ['ping', '-c', '1', ip]
    result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0


def get_ip_list(file_path):
    with open(file_path, 'r') as file:
        ip_list = file.read().splitlines()
    return ip_list

def main():
    if len(sys.argv) < 2:
        print("please provide the file name as ip_check.py <filename>.")
        return
    
    file_path = sys.argv[1]
    ip_list = get_ip_list(file_path)
    
    for ip in ip_list:
        if check_ip_reachability(ip):
            print(f'{ip} is reachable')
        else:
            print(f'{ip} is not reachable')


if __name__ == '__main__':
    main()

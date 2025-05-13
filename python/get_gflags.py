#!/usr/bin/env python3 
#
# Author: Doug Austin
# Date: 3/9/2023
# Updated: 3/20/2023 - Added formatting for options list
#
#
# Script will Pull all the non-default gflags set on this cluster per service
#
import sys
import subprocess
# Set Colors for Services
red_bg = "\033[41m"
reset_color = "\033[0m"


# Check for user provided input
if len(sys.argv) == 2:
    Service = sys.argv[1]
else:
# User Select Service to check
    print('{:<3s}  {:<15s}  {}'.format('OP', 'Service', 'Port'))
    print('-----------------------------------------------')
    print('{:<2s} - {:<15s}  {}'.format('1', 'Magneto', '20000'))
    print('{:<2s} - {:<15s}  {}'.format('2', 'Bridge', '11111'))
    print('{:<2s} - {:<15s}  {}'.format('3', 'Bridge Proxy', '11116'))
    print('{:<2s} - {:<15s}  {}'.format('4', 'Stats', '25566'))
    print('{:<2s} - {:<15s}  {}'.format('5', 'Yoda', '25999'))
    print('{:<2s} - {:<15s}  {}'.format('6', 'Apollo', '24680'))
    print('{:<2s} - {:<15s}  {}'.format('7', 'Groot', '26999'))
    print('{:<2s} - {:<15s}  {}'.format('8', 'Gandalf', '22222'))
    print('{:<2s} - {:<15s}  {}'.format('9', 'KeyChain', '22000'))
    print('{:<2s} - {:<15s}  {}'.format('9', 'IceBox', '29999'))
    print('')

    Service = input('Enter a Number(OP) from the list: ')
    print ('')

if Service not in ['1','2','3','4','5','6','7','8','9','10']:
    print('\n' + 'Error: Invalid Service Selected')
    sys.exit(1)

service_mapping = {
    '1': ('Magneto', '20000'),
    '2': ('Bridge', '11111'),
    '3': ('Bridge Proxy', '11116'),
    '4': ('Stat', '25566'),
    '5': ('Yoda', '25999'),
    '6': ('Apollo', '25999'),
    '7': ('Groot', '24680'),
    '8': ('Gandlaf', '22222'),
    '9': ('KeyChain', '22000'),
    '10': ('IceBox', '29999')
}
SN, Port = service_mapping[Service]

print(f"Getting Non-Default Flags set on Cluster for service: {red_bg}{SN}{reset_color}")
print("")

cmd = f"links -dump-width 1024 http:0:{Port}/flagz | grep '\[default='"
up = subprocess.check_output(cmd, shell=True).decode().strip()
print(f"{up}")

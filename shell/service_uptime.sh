#!/usr/bin/env python3
#
# Author: Doug Austin
# Date: 3/9/2023
# Updated: 3/20/2023 - Added formatting for options list
#
#
# Script will provide the user the uptime of the selected service from all Cohesity Nodes.
#

import subprocess

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
print('')

Service = input('Enter a Number(OP) from the list: ')
print ('')
if Service == '1':
    Svc = '20000'
    SN = 'Magneto'
elif Service == '2':
    Svc = '11111'
    SN = 'Bridge'
elif Service == '3':
    Svc = '11116'
    SN = 'Bridge Proxy'
elif Service == '4':
    Svc = '25566'
    SN = 'Stats'
elif Service == '5':
    Svc = '25999'
    SN = 'Yoda'
elif Service == '6':
    Svc = '24680'
    SN = 'Apollo'
elif Service == '7':
    Svc = '26999'
    SN = 'Groot'
elif Service == '8':
    Svc = '22222'
    SN = 'Gandalf'
elif Service == '9':
    Svc = '22000'
    SN = 'KeyChain'
else:
    print('\n' + 'Error: No Service Selected')
    exit(1)

# Print Service name Info
print('Checking uptime of --', SN, 'on port', Svc, '-- on all nodes..')
print('')

# Execute Uptime Check on all Nodes
if Service == '1':

    ips = subprocess.check_output(['hostips']).decode().strip().split()
    for ip in ips:
        cmd = f"links {ip}:{Svc} | grep -i  Constituent | tail -1 | awk '{{print $2,$3,$4,$5,$6,$7}}'"
        up = subprocess.check_output(cmd, shell=True).decode().strip()
        print(f"{ip} --- {up}")


elif Service in ('6', '7', '8', '9'):

    ips = subprocess.check_output(['hostips']).decode().strip().split()
    for ip in ips:
        cmd = f"links {ip}:{Svc} | grep -i -B1 uptime | tail -1 | awk '{{print $3,$4,$5,$6,$7,$8,$9,$10}}'"
        up = subprocess.check_output(cmd, shell=True).decode().strip()
        print(f"{ip} --- {up}")

elif Service == '3':

    ips = subprocess.check_output(['hostips']).decode().strip().split()
    for ip in ips:
        cmd = f"links {ip}:{Svc} | grep -i -B1 uptime | tail -1 | awk '{{print $3,$4,$5,$6,$7,$8}}'"
        up = subprocess.check_output(cmd, shell=True).decode().strip()
        print(f"{ip} --- {up}")

elif Service in ('4', '5'):

    ips = subprocess.check_output(['hostips']).decode().strip().split()
    for ip in ips:
        cmd = f"links {ip}:{Svc} | grep -i -B1 uptime | tail -1 | awk '{{print $3,$4,$5,$6,$7,$8,$9,$10}}'"
        up = subprocess.check_output(cmd, shell=True).decode().strip()
        print(f"{ip} --- {up}")

elif Service == '2':

    ips = subprocess.check_output(['hostips']).decode().strip().split()
    for ip in ips:
        cmd = f"links {ip}:{Svc} | grep -i -B1 uptime | grep Con | awk '{{print $3,$4,$5,$6,$7,$8,$9}}'"
        up = subprocess.check_output(cmd, shell=True).decode().strip()
        print(f"{ip} --- {up}")

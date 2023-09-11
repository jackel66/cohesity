import subprocess

# Run the "hostips" command and capture its output
hostips_output = subprocess.check_output(['hostips'])

# Split the output into a list of IP addresses
ips = hostips_output.decode().split()

print('')
print('{:<13s}  {:<15s}  {} {:<1s}'.format('IP', 'Cohesity Node Serial', 'Chassis Node Serial', ' Throttle Count'))
print('----------------------------------------------------------------------------')

# Loop through each IP address and execute the desired commands
for ip in ips:
    # Run the "dmesg" command on the current IP and count the number of lines containing "thrott"
    dmesg_command = f'ssh {ip} "dmesg | grep -i thrott | grep -i \'cpu clock throttled\' | wc -l"'
    thrott_count = subprocess.check_output(dmesg_command, shell=True).decode().strip()

    prod_helper_serial = f'ssh -o StrictHostKeyChecking=no -q {ip} "dmesg | grep -i \'cpu clock throttled\' | wc -l"'
    node_serial = subprocess.check_output(dmesg_command, shell=True).decode().strip()

    # Run the "product_helper" command on the current IP to get the serial number
    product_helper_command = f'ssh {ip} "product_helper -op=GET_COHESITY_NODE_SERIAL"'
    serial_number = subprocess.check_output(product_helper_command, shell=True).decode().strip()

    print(f'{ip}    {serial_number}           {node_serial}         {thrott_count}')

  
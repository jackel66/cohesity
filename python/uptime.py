#!/usr/bin/env python3
# Author: Doug Austin
# Date: 01/08/2024


import subprocess

def get_uptime_info():
    # Ask the user for input
    services_input = input("Which services would you like to check? (Enter any combination of Bridge, Magneto, Scribe): ")
    services = services_input.split()  # Split the input into a list of services

    # Convert to lowercase for case-insensitive comparison
    services = [service.lower() for service in services]

    # Get the host IPs
    hostips_output = subprocess.check_output("/home/cohesity/software/crux/bin/hostips", shell=True)
    hosts = hostips_output.decode().splitlines()

    for host in hosts:
        print(host)  # Print the host

        if 'bridge' in services:
            # Fetch and print Bridge uptime
            bridge_cmd = f"elinks -dump-width 200 http://{host}:11111 | grep 'Constituent.Uptime' | sed 's/^[ \t]*//; s/Constituent //'"
            bridge_uptime = subprocess.check_output(bridge_cmd, shell=True).decode().strip()
            print("\033[0;31m +++ Bridge +++\033[0m\t\t" + bridge_uptime)

        if 'scribe' in services:
            # Fetch and print Scribe uptime
            scribe_cmd = f"elinks -dump-width 200 http://{host}:12222 | grep 'e.Uptime' | sed 's/.*Node //'"
            scribe_uptime = subprocess.check_output(scribe_cmd, shell=True).decode().strip()
            print("\033[0;35m +++ Scribe +++\033[0m\t\t" + scribe_uptime)

        if 'magneto' in services:
            # Fetch and print Magneto uptime
            magneto_cmd = "elinks -dump-width 200 http://0:20000 | egrep 'Uptime' | sed 's/.*Constituent //'"
            magneto_uptime = subprocess.check_output(magneto_cmd, shell=True).decode().strip()
            print("\033[1;34m +++ Magneto +++\033[0m\t" + magneto_uptime)

# Call the function
get_uptime_info()
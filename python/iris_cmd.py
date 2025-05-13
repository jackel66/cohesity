#!/usr/bin/env python3
#

import subprocess
import os

IRIS_USERNAME = "username"
IRIS_PASSWORD = "password"

def set_environment_variables():
    username = os.environ.get('IRIS_USERNAME')
    password = os.environ.get('IRIS_PASSWORD')

    if not username:
        username = input("Enter the username: ")
        os.environ['IRIS_USERNAME'] = username

    if not password:
        password = input("Enter the password: ")
        os.environ['IRIS_PASSWORD'] = password

    return username, password

def execute_iris_cli(command):
    # Retrieve the username and password from environment variables or prompt the user
    username, password = set_environment_variables()

    # Create the iris_cli command with username and password
    command = input("Enter the command to execute: ")
    iris_cli_command = f'iris_cli -U {username} -P {password} {command}'

    # Execute the iris_cli command
    process = subprocess.Popen(
        iris_cli_command,
        shell=True,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    # Wait for the command prompt and input the username
    process.stdin.write((username + '\n').encode())
    process.stdin.flush()

    # Wait for the password prompt and input the password
    process.stdin.write((password + '\n').encode())
    process.stdin.flush()

    # Optional: Wait for additional user input if needed
    # process.stdin.write('additional_input\n'.encode())
    # process.stdin.flush()

    # Read the output from iris_cli
    output, error = process.communicate()

    # Print the output
    print(output.decode())

    # Print any error messages
    if error:
        print(error.decode())


execute_iris_cli()

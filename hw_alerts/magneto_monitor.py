#!/usr/bin/env python3
import subprocess
import time
from datetime import datetime
import logging

def is_process_running(process_name):
    try:
        subprocess.check_output(["pgrep", process_name])
        return True
    except subprocess_CalledProcessError:
        return False

def log_message(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    formatted_message = f"[{timestamp}] {message}"

    with open ("process_monitor.log", "a") as log_file:
        log_file.write(formatted_message +"\n")

def perform_restart_action():
    try:
        subprocess.run(["/home/support/utils/tc_init.sh"])
    except subprocess.CalledProcessError:
        log_message("Failed to execute timeCapsule")

def monitor_process(process_name):
    previous_status = None
    was_running = False


    while True:
        current_status = "running" if is_process_running(process_name) else "stopped"

        if current_status != previous_status:
            if current_status == "running":
                log_message(f"{process_name} is running.")
                if was_running:
                    log_message(f"{process_name} restarted.")
                    perform_rr
                was_running = True
            else:
                log_message(f"{process_name} has stopped.")
                was_running = False

            previous_status = current_status
        
        time.sleep(5) # edittime to check here

if __name__ == "__main__":
    process_name_to_monitor = "magneto"
    monitor_process(process_name_to_monitor)

#!/usr/bin/env python3
#
# Authort: Doug Austin
# Date: 8/23/2023

import os
import logger_config
import send_syslog
import socket

# Error Count Threshold
THRESHOLD = 5

def read_ue_count(mc_number):
    ue_count_file_path = f"/sys/devices/system/edac/mc/mc{mc_number}/ue_count"

    if os.path.exists(ue_count_file_path):
        with open(ue_count_file_path, 'r') as ue_count_file:
            return int(ue_count_file.read().strip())
    else:
        return -1

def main():
    mc_count = 0
    while True:
        ue_count = read_ue_count(mc_count)
        if ue_count == -1:
            break
        
        if ue_count > THRESHOLD:
            logger_config.logger.error(f"DIMM Module: {mc_count}, Error Count: {ue_count}")
            from send_syslog import send_syslog_message, syslog_host, syslog_port
            failed_dimm_text = f'"DIMM {(mc_count)} showing excessive uncorrectable errors."'
            cluster_name = f'"{(send_syslog.value)}"'
            attributes = {
            '"ClusterName"': cluster_name,
            '"AlertCode"': '"CH00000006"',
            '"AlertName"': '"DimmMemoryError"',
            '"AlertSeverity"': '"WARNING"',
            '"AlertDescription"': failed_dimm_text,
            '"AlertCause"': '"Likely caused by a DIMM starting to fail."',
            }    
            send_syslog_message(syslog_host, syslog_port, attributes)   
        else: 
            logger_config.logger.info(f"DIMM Error Count (MC{mc_count}): {ue_count}")
        mc_count += 1

if __name__ == "__main__":
    main()

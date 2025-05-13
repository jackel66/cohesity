#!/bin/bash
# Author: Doug Austin
# Check Services Version for all core services
# Updated: 5/5/23 - Added bridge_proxy service
#
#
# Define a function to get the version of a service
get_version() {
    "$1" --version | awk 'NR==1{print $3}'
}

# List of core services to check
services=("aegis_exec"	"alerts_exec"	"apollo_exec"	"athena_exec"	"athena_proxy_exec"	"athena_watchdog_exec"	"atom_exec"	"axon_config_helper_exec"	"bashlogger_exec"	"bifrost_broker_exec"	"bifrost_exec"	"bridge_exec"	"bridge_proxy_exec"	"compass_exec"	"core_helper_exec"	"eagle_agent_exec"	"elrond_exec" "firmware_helper_exec"	"flexvol_exec"	"groot_exec" "heimdall_exec" "input_logger_exec"	"iris_exec"	"iris_proxy_exec" "keychain_exec"	"librarian_exec"	"logwatcher_exec"	"magneto_exec"	"newscribe_exec"	"nexus_exec"	"nexus_proxy_exec"	"nfs_proxy_exec"	"patch_exec"	"rtclient_exec"	"siren_server_exec"	"smb2_proxy_exec"	"smb_proxy_exec"	"snmp_subagent_exec"	"statscollector_exec"	"stats_exec" "throttler_exec"	"vault_proxy_exec"	"workqueue_server_exec"	"yoda_agent_exec"	"yoda_exec" )

# Print the current date and list of services being checked
printf "$(date)\nChecking versions of the following: %s\n\n" "${services[*]}"

# Print the version of each service
printf "%-30s %s\n" "Service Name:" "Version"

echo "------------- --------------------------------------------------------"

# Sort output into array
declare -A versions

# Get Version and Service information for the array
for service in "${services[@]}"; do
    version=$(get_version "$service")
    printf "%-30s %s\n" "$service:" "$version"
done

# Sort the version information
sorted_services=($(
    for service in "${!versions[@]}"; do
        echo "$service ${versions[$service]}"
    done | sort -k2,2 -n | awk '{print $1}'
))

# print sorted records
for service in "${sorted_services[@]}"; do
    version="${versions[$service]}"
    printf "%-30s %s\n" "$service:" "$version"
done
#!/bin/bash
# Author: Doug Austin
# Filesystem Log check
# Updated: 6/1/2023
#

partitions=$(df -h | awk 'NR>1{print $6}' | grep -v -E 'tmpfs|devtmpfs|/boot|/home_cohesity_data|/home/cohesity')
cohesity_partitions=$(df -h | awk 'NR>1{print $6}' | grep '^/home_cohesity')
# Header for log
echo ""
printf "%-15s  %85s\n" "Partition" "Used Percetnage"
echo "------------------------------------------------------------------------------------------------------------"

for partition in $partitions; do
    usage=$(df -h $partition | awk 'NR==2{print $5}' | tr -d '%')
    if [[ $usage -gt 60 ]]; then
        printf "%-85s | \033[031m%3s%%\033[0m\n" "$partition" "$usage"
    else
        printf "%-85s | \033[032m%3s%%\033[0m\n" "$partition" "$usage"
    fi
done
echo ""
echo "------------------------------------------------------------------------------------------------------------"
echo ""
printf "%-15s  %85s\n" "Partition" "Used Percetnage"
for cohesity_partition in $cohesity_partitions; do 
    usage2=$(df -h $cohesity_partition | awk 'NR==2{print $5}' | tr -d '%')
    if [[ $usage -gt 80 ]]; then
        printf "%-85s | \033[031m%3s%%\033[0m\n" "$cohesity_partition" "$usage2"
    else    
        printf "%-85s | \033[032m%3s%%\033[0m\n" "$cohesity_partition" "$usage2"
    fi
done
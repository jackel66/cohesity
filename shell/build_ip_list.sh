#!/usr/bin/bash


# build Ip list for review
HOST=`hostname | awk -F "-" '{print $1}'`

for hostname in $HOST; 
    do
        nslookup $hostname-az | grep "Address: " | awk '{print $2}' >> all_ips.out
        nslookup $hostname-oz | grep "Address: " | awk '{print $2}' >> all_ips.out
        nslookup $hostname-snp | grep "Address: " | awk '{print $2}' >> all_ips.out
        nslookup $hostname-cpz | grep "Address: " | awk '{print $2}' >> all_ips.out
done


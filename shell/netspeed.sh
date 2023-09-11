#!/bin/bash

NIC=`sudo cat /proc/net/bonding/bond0  | grep "Slave Interface" -A 1`
HELP=`netstat -i |  awk 'BEGIN { FS =  ":" }; {print $1}' | egrep "br0\.|bond0" | awk '{print $1}' | sort | uniq`


INTERVAL="1"  # update in seconds

if [[ "$1" = "bond" ]]; then
        echo 
        echo $NIC
        echo 
        exit 0
elif [[ "$1" = "help" ]]; then
        echo
        echo "Available Interfaces:" 
        echo $HELP
        echo
        exit 0
elif [[ -z "$1" ]]; then
        echo
        echo usage: $0 [network-interface]
        echo
        echo usage: $0 [help] for available interfaces
        echo
        echo e.g. $0 br0.15
        echo e.g $0 help
        echo 
        exit 1
fi

if=$1
while true
do
        R1=`cat /sys/class/net/$1/statistics/rx_bytes`
        T1=`cat /sys/class/net/$1/statistics/tx_bytes`
        sleep $INTERVAL
        R2=`cat /sys/class/net/$1/statistics/rx_bytes`
        T2=`cat /sys/class/net/$1/statistics/tx_bytes`
        TBPS=`expr $T2 - $T1`
        RBPS=`expr $R2 - $R1`
        TKBPS=`expr $TBPS / 1024`
        RKBPS=`expr $RBPS / 1024`
        echo "TX $1: $TKBPS kB/s RX $1: $RKBPS kB/s"
done

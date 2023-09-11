#!/bin/bash
# Owner: Sahil Dhull (sahil.dhull@cohesity.com)
#
# Usage:
# allssh.sh "./calls.sh <mmdd> <hh> <duration>"
#
#
# Output will be something like this:
#
# Using date as 0729 and hour as 0
# Total calls:          2150
# Total refresh calls:  0
# Total backup calls:   2150


mmdd=$(date -d "-$1 hour" '+%m%d')
hour=$(date -d "-$1 hour" '+%H')
duration=$1

echo "For date $mmdd, hour $hour, and duration of $duration hour(s)"

overall_total_calls=0
total_refresh_calls=0
total_backup_calls=0
total_throttled_calls=0

for (( i=1; i<=$duration; i++ ))
    do
    magneto_single_calls_one_hour=$(zgrep "I$mmdd $hour.*graph_base_op.cc.*Refreshing the token. Attempt number" logs/magneto_exec.*INFO* | wc -l)

    magneto_batch_calls_one_hour=$(zgrep "I$mmdd $hour.*generic_batch_request_op.cc.*Making a batch request of size" logs/magneto_exec.*INFO* | wc -l)

    bridge_proxy_single_calls_one_hour=$(zgrep "I$mmdd $hour.*graph_base_op.cc.*Refreshing the token. Attempt number" logs/bridge_proxy_exec.*INFO* | wc -l)

    bridge_proxy_batch_calls_one_hour=$(zgrep "I$mmdd $hour.*generic_batch_request_op.cc.*Making a batch request of size" logs/bridge_proxy_exec.*INFO* | wc -l)

    refresh_single_calls_one_hour=$(zgrep "I$mmdd $hour.*graph_base_op.cc.*Task id -1: Refreshing the token. Attempt number" logs/magneto_exec.*INFO* | wc -l)

    refresh_batch_calls_one_hour=$(zgrep "I$mmdd $hour.*generic_batch_request_op.cc.*Task id -1: Making a batch request of size" logs/magneto_exec.*INFO* | wc -l)

    magneto_throttled_calls_one_hour=$(zgrep "I$mmdd $hour.*graph_base_op.cc.*Received error in MS Graph Response.*The request has been throttled" logs/magneto_exec.*INFO* | wc -l)

    bridge_proxy_throttled_calls_one_hour=$(zgrep "I$mmdd $hour.*graph_base_op.cc.*Received error in MS Graph Response.*The request has been throttled" logs/bridge_proxy_exec.*INFO* | wc -l)

    total_calls_one_hour=$(( $magneto_single_calls_one_hour + $magneto_batch_calls_one_hour * 19 + $bridge_proxy_single_calls_one_hour + $bridge_proxy_batch_calls_one_hour * 19 ))

    refresh_total_calls_one_hour=$(( $refresh_single_calls_one_hour + $refresh_batch_calls_one_hour * 19 ))

    total_refresh_calls=$(( $total_refresh_calls + $refresh_total_calls_one_hour ))

    overall_total_calls=$(( $overall_total_calls + $total_calls_one_hour ))

    total_backup_calls=$(( $overall_total_calls - $total_refresh_calls ))

    total_throttled_calls=$(( $total_throttled_calls + $magneto_throttled_calls_one_hour + $bridge_proxy_throttled_calls_one_hour))

    hour=$(date -d "$hour +1 hour" +"%H")

done

echo "Total calls:          $overall_total_calls"
echo "Total refresh calls:  $total_refresh_calls"
echo "Total backup calls:   $total_backup_calls"
echo "Total throttled calls: $total_throttled_calls"

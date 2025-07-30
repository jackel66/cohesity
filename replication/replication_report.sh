#!/bin/bash
# Author: Doug Austin
# Date: 7/30/2025
# Purpose: Generate a Cohesity replication status report
# Description: This script fetches replication data from a Cohesity cluster and generates a report summarizing the status of replications, including running and queued tasks, their ages, and logs the information to a file.

# Configuration
LOG_FILE="/home/support/replication_status.log"
 
# Fetch replication data (must be first operation)
date; elinks -dump-width 1024 "`links http:localhost:20000 | awk '/master/{print $2}' |sed 's/master//'`replicationz" > /tmp/replicaitons.txt
 
# Function to print separator line
print_separator() {
    echo "=================================================================="
}
 
print_header() {
    echo ""
    print_separator
    echo "  $1"
    print_separator
}
 
# Get overall statistics
total_running=$(awk '/Replication SubTasks/,/Replication Tasks/ {if(/kAccepted/) print $5}' /tmp/replicaitons.txt | sort | uniq | wc -l)
total_queued=$(awk '/Replication SubTasks/,/Replication Tasks/ {if(/kStarted/) print $5}' /tmp/replicaitons.txt | sort | uniq | wc -l)
targets=$(awk '/Target Cluster Name/{getline; while(getline && $0 !~ /^$/ && $0 !~ /References/) print $2}' /tmp/replicaitons.txt | sort | uniq)
 
# Initialize log file
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Date|Target|Running|Queued|Running Age|Oldest_Queued" > "$LOG_FILE"
fi
 
# timestamp for log entries
current_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
 
print_header "COHESITY REPLICATION DASHBOARD - $(date '+%Y-%m-%d %H:%M:%S')"
 
echo ""
echo "  📊 OVERALL SUMMARY"
echo "  ─────────────────────────────────────────────────────────────────"
printf "  %-25s: %s\n" "Running Replications" "$total_running"
printf "  %-25s: %s\n" "Queued Replications" "$total_queued"
printf "  %-25s: %s\n" "Total Active" "$((total_running + total_queued))"
 
print_header "TARGET CLUSTER BREAKDOWN"
 
# Process each target cluster
for target in $targets; do
    if [[ -n "$target" && "$target" != "Target" ]]; then
        echo ""
        echo "  🎯 $target"
        echo "  ─────────────────────────────────────────────────────────────────"
        
        # Count running and queued for this target (unique Task UIDs only from SubTasks section)
        running_count=$(awk '/Replication SubTasks/,/Replication Tasks/ {if(/kAccepted/ && /'$target'/) print $5}' /tmp/replicaitons.txt | sort | uniq | wc -l)
        queued_count=$(awk '/Replication SubTasks/,/Replication Tasks/ {if(/kStarted/ && /'$target'/) print $5}' /tmp/replicaitons.txt | sort | uniq | wc -l)
        
        printf "  %-20s: %s\n" "Running" "$running_count"
        printf "  %-20s: %s\n" "Queued" "$queued_count"
        
        # Get oldest running replication for this target (unique tasks only from SubTasks section)
        oldest_running=$(awk '/Replication SubTasks/,/Replication Tasks/ {if(/kAccepted/ && /'$target'/) print $5, $7, $8, $9, $10}' /tmp/replicaitons.txt | sort | uniq | sort -k2,2r -k1,1n -k3,3n | tail -1 | cut -d' ' -f2-)
        
        # Get oldest queued replication for this target (unique tasks only from SubTasks section)
        oldest_queued=$(awk '/Replication SubTasks/,/Replication Tasks/ {if(/kStarted/ && /'$target'/) print $5, $7, $8, $9, $10}' /tmp/replicaitons.txt | sort | uniq | sort -k2,2r -k1,1n -k3,3n | tail -1 | cut -d' ' -f2-)
        
        # Clean up oldest values for logging (remove extra spaces and handle empty values)
        oldest_running_clean=$(echo "$oldest_running" | sed 's/^ *//;s/ *$//' | tr -d '\n')
        oldest_queued_clean=$(echo "$oldest_queued" | sed 's/^ *//;s/ *$//' | tr -d '\n')
        [[ -z "$oldest_running_clean" ]] && oldest_running_clean="None"
        [[ -z "$oldest_queued_clean" ]] && oldest_queued_clean="None"
        
        # Log entry for this target
        echo "$current_timestamp|$target|$running_count|$queued_count|$oldest_running_clean|$oldest_queued_clean" >> "$LOG_FILE"
        
        if [[ -n "$oldest_running" ]]; then
            printf "  %-20s: %s\n" "Running Age" "$oldest_running"
        else
            printf "  %-20s: %s\n" "Running Age" "None"
        fi
        
        if [[ -n "$oldest_queued" ]]; then
            printf "  %-20s: %s\n" "Oldest Queued" "$oldest_queued"
        else
            printf "  %-20s: %s\n" "Oldest Queued" "None"
        fi
    fi
done
 
print_header "CLUSTER-WIDE OLDEST REPLICATIONS"
 
# Get overall oldest running and queued (unique tasks only from SubTasks section)
oldest_running_global=$(awk '/Replication SubTasks/,/Replication Tasks/ {if(/kAccepted/) print $5, $7, $8, $9, $10}' /tmp/replicaitons.txt | sort | uniq | sort -k2,2r -k1,1n -k3,3n | tail -1 | cut -d' ' -f2-)
oldest_queued_global=$(awk '/Replication SubTasks/,/Replication Tasks/ {if(/kStarted/) print $5, $7, $8, $9, $10}' /tmp/replicaitons.txt | sort | uniq | sort -k2,2r -k1,1n -k3,3n | tail -1 | cut -d' ' -f2-)
 
echo ""
if [[ -n "$oldest_running_global" ]]; then
    printf "  %-27s: %s\n" "🔄 Running Age" "$oldest_running_global"
else
    printf "  %-27s: %s\n" "🔄 Running Age" "None"
fi
 
if [[ -n "$oldest_queued_global" ]]; then
    printf "  %-26s: %s\n" "⏳ Oldest Queued" "$oldest_queued_global"
else
    printf "  %-26s: %s\n" "⏳ Oldest Queued" "None"
fi
 
print_separator
echo ""
 
# Display log file information
echo "📝 Log file updated: $LOG_FILE"
echo ""
echo "   Recent Log Entries (formatted):"
echo "   ┌─────────────────────┬─────────────────┬─────────┬─────────┬─────────────────┬─────────────────┐"
echo "   │ Date                │ Target          │ Running │ Queued  │ Running Age     │ Age Oldest Queue│"
echo "   ├─────────────────────┼─────────────────┼─────────┼─────────┼─────────────────┼─────────────────┤"
 
# Process log entries - show only the most recent timestamp entries
latest_timestamp=$(tail -10 "$LOG_FILE" | grep -v "^Date|" | tail -1 | cut -d'|' -f1)
temp_entries=$(grep "^$latest_timestamp|" "$LOG_FILE" 2>/dev/null || echo "")
 
if [[ -n "$temp_entries" ]]; then
    echo "$temp_entries" | while IFS='|' read -r date target running queued oldest_running oldest_queued; do
        printf "   │ %-20s │ %-15s │ %-7s │ %-7s │ %-15s │ %-15s │\n" \
               "$date" "$target" "$running" "$queued" "$oldest_running" "$oldest_queued"
    done
else
    echo "   │ No entries found                                                                              │"
fi
 
echo "   └─────────────────────┴─────────────────┴─────────┴─────────┴─────────────────┴─────────────────┘"
echo ""
 
# Also show the raw log file location for reference
echo "   Raw log file location: $LOG_FILE"
echo "   (Use 'cat $LOG_FILE' to view all entries)"
echo ""

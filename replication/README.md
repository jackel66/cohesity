# Cohesity Replication Status Report Script

This script generates a status report for Cohesity cluster replications, summarizing running and queued replication tasks, their ages, and logging the information for auditing and troubleshooting.

## Features
- Fetches replication data from a Cohesity cluster
- Summarizes running and queued replication tasks
- Breaks down replication status by target cluster
- Displays oldest running and queued replications (per cluster and globally)
- Logs results to a file for historical tracking

## Usage
Run the script on a system with access to the Cohesity cluster:

```sh
bash replication_report.sh
```

## Requirements
- Bash shell
- `elinks` and `links` command-line browsers
- Access to Cohesity cluster's local web interface

## Output
- Console summary of replication status
- Log file: `/home/support/replication_status.log` (can be changed in the script)

## Log File Format
Each entry in the log file contains:
- Date
- Target cluster
- Number of running replications
- Number of queued replications
- Age of oldest running replication
- Age of oldest queued replication

## License
GNU General Public License v3.0

## Author
Doug Austin

## Notes
- The script expects the Cohesity cluster web interface to be available locally.
- For troubleshooting, check the log file and ensure required tools are installed.

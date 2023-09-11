#!/bin/bash

# Add Values to logrotate.conf
# edits /etc/lograte.conf and appends the following lines
# Create Backup of Logrotate.conf
cp /etc/logrotate.conf /tmp/logrotate.conf
echo "Created Copy of logrotate.conf in /tmp"

echo "Adding Entries for Logrotate"
echo "# Rotate for Custom Healthcheck Log" >> /etc/logrotate.conf
echo "" >> /etc/logrotate.conf
echo "/var/log/healthcheck.log {" >> /etc/logrotate.conf
echo "  rotate 10" >> /etc/logrotate.conf
echo "  maxsize 3M" >> /etc/logrotate.conf
echo "  missingok" >> /etc/logrotate.conf
echo "  notifempy" >> /etc/logrotate.conf
echo "  copytruncate" >> /etc/logrotate.conf
echo "  create" >> /etc/logrotate.conf
echo "  nodateext" >> /etc/logrotate.conf
echo "  delaycompress" >> /etc/logrotate.conf
echo "}" >> /etc/logrotate.conf
echo "Entries into Logrotate completed."

# Add cron entry to root crontab
# Adds a check every 10 minutes to crontab for root
echo "Adding Cron Entry for Root"
echo "*/10 * * * * /home/support/utils/alerts/alerts.py" >> /var/spool/cron/root
echo "Completed Cron Entry for Root"

echo "Creating Empty log file in /var/log"
# Create logfile in /var/log
touch /var/log/healthcheck.log
chmod 777 /var/log/healthcheck.log
echo "Completed creating log file in /var/log"

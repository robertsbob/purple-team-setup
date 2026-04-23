#!/bin/bash
# Cleanup old temp files and logs
# runs as root via cron every 5 mins
# gary: added this after the disk filled up that one time

find /tmp -name "*.csv" -mtime +1 -delete
find /var/www/grizzy/public/uploads -name "*.tmp" -delete
truncate -s 0 /var/log/nginx/access.log 2>/dev/null

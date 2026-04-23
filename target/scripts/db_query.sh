#!/bin/bash
# Generic DB query helper
# gary: handy for cron jobs and scripts, don't need to rewrite mysql config everywhere
# Usage: db_query.sh <table> <id>

TABLE=$1
ID=$2

mysql -u grizzy_app -pgrizzy2024! grizzy_db -sN -e \
  "SELECT id, status, delivery_date, address FROM ${TABLE} WHERE id = ${ID}" 2>/dev/null

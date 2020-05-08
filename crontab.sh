#!/usr/bin/env bash

# Ensure the log file exists
touch /iot_home/crontab.log

# Added cronjobs in a new crontab
# Run periodically
echo '0 23 * * 5 python pg_admin.py scripts/sql/db_cleanup_packet.sql >> /iot_home/crontab.log 2>$1' > /etc/crontab
echo '15 * * * * python pg_admin.py scripts/sql/db_health_status.sql >> /iot_home/crontab.log 2>$1' >> /etc/crontab
echo '*/5 * * * * python pg_admin.py scripts/sql/db_sp_populate_stats_counters.sql >> /iot_home/crontab.log 2>$1' >> /etc/crontab
echo '15,45 * * * * python pg_admin.py scripts/sql/db_resolve_quarantine_timeout.sql >> /iot_home/crontab.log 2>$1' >> /etc/crontab

# Registering the new crontab
crontab /etc/crontab

# Starting the cron
/usr/sbin/service cron start

# Displaying logs
tail -F /iot_home/crontab.log
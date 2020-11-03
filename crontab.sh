#!/usr/bin/env bash

# Ensure the log file exists
touch /iot_home/crontab.log

echo "DB_HOST=$DB_HOST" > /etc/crontab
echo "DB_PORT=$DB_PORT" >> /etc/crontab
echo "DB_NAME=$DB_NAME" >> /etc/crontab
echo "DB_USERNAME=$DB_USERNAME" >> /etc/crontab
echo "DB_PASSWORD=$DB_PASSWORD" >> /etc/crontab

# Added cronjobs in a new crontab
# Run periodically
echo '0 23 * * * /usr/local/bin/python /iot_home/pg_admin.py /iot_home/scripts/sql/db_cleanup_packet.sql >> /iot_home/crontab.log' >> /etc/crontab
echo '15 * * * * /usr/local/bin/python /iot_home/pg_admin.py /iot_home/scripts/sql/db_health_status.sql >> /iot_home/crontab.log' >> /etc/crontab
echo '*/2 * * * * /usr/local/bin/python /iot_home/pg_admin.py /iot_home/scripts/sql/db_sp_populate_stats_counters.sql >> /iot_home/crontab.log' >> /etc/crontab
echo '15,45 * * * * /usr/local/bin/python /iot_home/pg_admin.py /iot_home/scripts/sql/db_resolve_quarantine.sql >> /iot_home/crontab.log' >> /etc/crontab
echo '*/5 * * * * /usr/local/bin/python /iot_home/pg_admin.py /iot_home/scripts/sql/db_check_assets_connection.sql >> /iot_home/crontab.log' >> /etc/crontab

crontab -u root /etc/crontab
# Starting the cron
service cron start

# Displaying logs
tail -F /iot_home/crontab.log
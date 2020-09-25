select c.oid::regclass as packet,
pg_size_pretty(pg_table_size(c.oid)) as table_size
from pg_class c
left join pg_class t on c.reltoastrelid = t.oid
where c.relkind = 'r' and c.relname = 'packet';

select to_char(min(date), 'YYYY-MM-DD HH12:MI:SS') as delete_from, to_char(max(date), 'YYYY-MM-DD HH12:MI:SS') as delete_to, cast(count(1) as varchar(12)) as rows
from packet
where date < current_date - interval '15 day'
and id not in (select packet_id from alert);

delete
from packet
where date < current_date - interval '15 day'
and id not in (select packet_id from alert);

set maintenance_work_mem='4 GB';

show maintenance_work_mem;

SET lock_timeout TO '60min';

vacuum (verbose, full) packet;

select c.oid::regclass as packet,
pg_size_pretty(pg_table_size(c.oid)) as table_size
from pg_class c
left join pg_class t on c.reltoastrelid = t.oid
where c.relkind = 'r' and c.relname = 'packet';
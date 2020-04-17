select c.oid::regclass as table_name,
pg_size_pretty(pg_table_size(c.oid)) as table_size
from pg_class c
left join pg_class t on c.reltoastrelid = t.oid
where c.relkind = 'r' and c.relname = 'TABLE_NAME';

select to_char(min(date), 'YYYY-MM-DD HH12:MI:SS') as delete_from, to_char(max(date), 'YYYY-MM-DD HH12:MI:SS') as delete_to, cast(count(1) as varchar(12)) as rows
from TABLE_NAME
where date < current_date - interval '60 day';

delete
from TABLE_NAME
where date < current_date - interval '60 day';

set maintenance_work_mem='2 GB';

show maintenance_work_mem;

vacuum (verbose, full) TABLE_NAME;

select c.oid::regclass as table_name,
pg_size_pretty(pg_table_size(c.oid)) as table_size
from pg_class c
left join pg_class t on c.reltoastrelid = t.oid
where c.relkind = 'r' and c.relname = 'TABLE_NAME';

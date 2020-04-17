select cast(client_addr as varchar(18)) as client_addr, application_name, cast(pid as varchar(7)) as pid, cast(query_start as varchar(19)) as query_start, cast(query as varchar(50)) as query
from pg_stat_activity 
where state = 'active';

select cast(pid as varchar(5)) as pid, cast(pg_blocking_pids(pid) as varchar(7)) as blocked_by, cast(query as varchar(50)) as blocked_query
from pg_stat_activity
where pg_blocking_pids(pid)::text != '{}';

SELECT cast(c.oid::regclass as varchar(40)) as table_name,
cast(pg_size_pretty(pg_table_size(c.oid)) as varchar(10)) as table_size
from pg_class c
left join pg_class t on c.reltoastrelid = t.oid
where c.relkind = 'r'
order by pg_table_size(c.oid) desc
limit 10;


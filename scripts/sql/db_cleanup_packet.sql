select c.oid::regclass as packet,
pg_size_pretty(pg_table_size(c.oid)) as table_size
from pg_class c
left join pg_class t on c.reltoastrelid = t.oid
where c.relkind = 'r' and c.relname = 'packet';


delete from data_collector_log_event dcle
where dcle.id in (
	select dcle.id from data_collector_log_event dcle
	where dcle.created_at < current_date - interval '30 day'
	limit 10000000
);

delete from packet p
where p.id in (
	select packet.id from packet
	where date < current_date - interval '30 day'
	limit 3600000
);

delete from device_session ds
where ds.id in (
	select ds.id from device_session ds
	where current_date - ds.last_activity > interval '60' day
	limit 200
);

select c.oid::regclass as packet,
pg_size_pretty(pg_table_size(c.oid)) as table_size
from pg_class c
left join pg_class t on c.reltoastrelid = t.oid
where c.relkind = 'r' and c.relname = 'packet';
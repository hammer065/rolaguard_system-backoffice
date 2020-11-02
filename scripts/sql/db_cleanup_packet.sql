select c.oid::regclass as packet,
pg_size_pretty(pg_table_size(c.oid)) as table_size
from pg_class c
left join pg_class t on c.reltoastrelid = t.oid
where c.relkind = 'r' and c.relname = 'packet';

select to_char(min(date), 'YYYY-MM-DD HH12:MI:SS') as delete_from, to_char(max(date), 'YYYY-MM-DD HH12:MI:SS') as delete_to, cast(count(1) as varchar(12)) as rows
from packet
                                                                                                                                                      
where date < current_date - interval '30 day'

delete
from packet p
where p.id in (
	select packet.id from packet
	where date < current_date - interval '30 day'
	limit 3600000
);


select c.oid::regclass as packet,
pg_size_pretty(pg_table_size(c.oid)) as table_size
from pg_class c
left join pg_class t on c.reltoastrelid = t.oid
where c.relkind = 'r' and c.relname = 'packet';
-- To ensure that these table names are not in use
drop table if exists unq_to_remove, unq_alerts_to_remove;

-- Get quarantine rows that must be resolved
select q.id as id
into unq_to_remove
from quarantine q
  join alert a on q.alert_id = a.id
  join alert_type atype on a.type = atype.code
  join device d on a.device_id = d.id
where 
	q.resolved_at is null and
	((
		atype.quarantine_npackets_timeout > 0 and
		atype.for_asset_type = 'DEVICE' and
		d.activity_freq is not null and
		q.last_checked + atype.quarantine_npackets_timeout * (d.activity_freq + 2 * d.activity_freq_variance) * interval '1 second' < current_timestamp
	) or (
		atype.quarantine_timeout > 0 and
		q.last_checked + atype.quarantine_timeout * interval '1 second' < current_timestamp
	));

-- Resolve the quarantines
update quarantine
set resolved_at = current_timestamp,
    resolution_reason_id = 2,
    resolution_comment = 'Alert timed out'
where id in (select id from unq_to_remove);

-- Get the corresponding alerts 
with alerts_id as (
	select q.alert_id as id from quarantine q
	where q.id in (select id from unq_to_remove))
select *
into unq_alerts_to_remove
from alert a
where a.id in (select id from alerts_id);

-- Remove 'packet_data' from parameters
UPDATE unq_alerts_to_remove SET parameters = (parameters::jsonb - 'packet_data')::varchar;

-- Modify some fields of the copy of the alerts
update unq_alerts_to_remove atr
set type = 'LAF-600',
	created_at = current_timestamp,
	resolved_at = null,
	resolved_by_id = null,
	resolution_comment = null,
	parameters = (jsonb_build_object(
					'alert_solved_type', at.code,
					'alert_solved', at.name,
					'resolution_reason', 'A considerable amount of time passed without this problem being detected again'
					) ||
				  atr.parameters::jsonb)::varchar,
	show = true
from alert_type at
where atr.type = at.code;

-- Insert the modified alert in the alerts table (to emit the alerts)
insert into alert (type, created_at, packet_id, device_id, device_session_id, gateway_id, device_auth_id,
				   data_collector_id, parameters, resolved_at, resolved_by_id, resolution_comment, show)
	select type, created_at, packet_id, device_id, device_session_id, gateway_id, device_auth_id,
				   data_collector_id, parameters, resolved_at, resolved_by_id, resolution_comment, show
	from unq_alerts_to_remove;

-- Clean temp tables
drop table if exists unq_to_remove, unq_alerts_to_remove;
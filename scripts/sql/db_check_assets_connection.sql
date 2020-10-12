-- To ensure that these table names are not in use
drop table if exists gw_to_disconnect, dv_to_disconnect, gw_created_alerts, dv_created_alerts;

-- A gateway is considered disconnected if both of these conditions are met:
--    * It hasn't sent a package for more than 30 minutes
--    * It hasn't sent a package for more than (1/disconnection_sensitivity) times it's 
--      usual period, where disconnection_sensitivity is a configurable policy parameter
-- 1) Get gateways to disconnect and the data needed to create the corresponding alerts
SELECT
    DISTINCT ON (g.id, dc.id)
    g.id as gateway_id,
    g.organization_id as organization_id,
    dc.id as data_collector_id,
    pitem.alert_type_code as alert_type,
    (pitem.enabled and dc.deleted_at is null and dc.status = 'CONNECTED'::datacollectorstatus) as should_create_alert,
    true as show,
    now() as created_at,
    g.last_packet_id as packet_id,
    json_build_object(
        'packet_id', g.last_packet_id,
        'packet_date', to_char(pck.date, 'YYYY-MM-DD HH24:MI:SS TZ'),
        'packet_data', row_to_json(pck),
        'created_at', now(),
        'dev_eui', null,
        'dev_name', null,
        'dev_vendor', null,
        'dev_addr', null,
        'gateway', g.gw_hex_id,
        'gw_name', g.name,
        'gw_vendor', g.vendor,
        'last_activity', g.last_activity,
        'activity_freq', g.activity_freq,
        'policy_name', p.name,
        'disconnection_sensitivity_value', pitem.parameters::json->'disconnection_sensitivity'
    ) as parameters
INTO gw_to_disconnect
FROM gateway g
    JOIN data_collector dc on g.data_collector_id = dc.id
    JOIN policy_item pitem on pitem.alert_type_code = 'LAF-403' and dc.policy_id = pitem.policy_id
    JOIN policy p on p.id = pitem.policy_id
    JOIN packet pck on pck.id = g.last_packet_id
    JOIN row_processed rp on rp.analyzer = 'packet_analyzer'
    JOIN packet proc_pck on proc_pck.id = rp.last_row
WHERE g.connected and 
    pitem.parameters::jsonb ? 'disconnection_sensitivity' and
    pitem.parameters::jsonb ? 'min_activity_period' and
    (g.last_activity + CONCAT(
        GREATEST(
            (pitem.parameters::json->>'min_activity_period')::numeric,
            COALESCE(g.activity_freq,0)/((pitem.parameters::json->>'disconnection_sensitivity')::numeric))
                ::text,
        ' seconds')
            ::interval)
    < proc_pck.date

-- 2) Add an alert for every gateway that will be disconnected if corresponds
with gw_created_alerts as (
    INSERT INTO alert (type, created_at, packet_id, gateway_id, data_collector_id, parameters, show)
    SELECT alert_type, created_at, packet_id, gateway_id, data_collector_id, parameters, show
    FROM gw_to_disconnect
    WHERE should_create_alert
    RETURNING *
)
-- Add an issue for every alert created
INSERT INTO quarantine (alert_id, since, organization_id, last_checked)
SELECT DISTINCT ON (gwca.id) gwca.id, gwca.created_at, gtd.organization_id, gwca.created_at
FROM gw_created_alerts gwca
    JOIN gw_to_disconnect gtd on gwca.gateway_id = gtd.gateway_id

-- 3) Disconnect the corresponding gateways
UPDATE gateway
SET connected = false
WHERE id in (select gateway_id from gw_to_disconnect)

-- A device is considered disconnected if both of these conditions are met:
--    * It hasn't sent a package for more than 30 minutes
--    * It hasn't sent a package for more than (1/disconnection_sensitivity) times it's 
--      usual period, where disconnection_sensitivity is a configurable policy parameter
-- 1) Get devices to disconnect and the data needed to create the corresponding alerts
SELECT
    DISTINCT ON (d.id, dc.id)
    g.id as gateway_id,
    d.id as device_id,
    d.organization_id as organization_id,
    dc.id as data_collector_id,
    pitem.alert_type_code as alert_type,
    (pitem.enabled and
        dc.deleted_at is null and 
        dc.status = 'CONNECTED'::datacollectorstatus and
        pitem.parameters::jsonb ? 'deviation_tolerance' and
        d.activity_freq is not NULL and
        d.activity_freq != 0 and
        sqrt(d.activity_freq_variance)/d.activity_freq <= (pitem.parameters::json->>'deviation_tolerance')::numeric
    ) as should_create_alert,
    true as show,
    now() as created_at,
    d.last_packet_id as packet_id,
    json_build_object(
        'packet_id', d.last_packet_id,
        'packet_date', to_char(pck.date, 'YYYY-MM-DD HH24:MI:SS TZ'),
        'packet_data', row_to_json(pck),
        'created_at', now(),
        'dev_eui', d.dev_eui,
        'dev_name', d.name,
        'dev_vendor', d.vendor,
        'dev_addr', null,
        'gateway', g.gw_hex_id,
        'gw_name', g.name,
        'gw_vendor', g.vendor,
        'last_activity', d.last_activity,
        'activity_freq', d.activity_freq,
        'policy_name', p.name,
        'disconnection_sensitivity_value', pitem.parameters::json->'disconnection_sensitivity'
    ) as parameters
INTO dv_to_disconnect
FROM device d
    JOIN data_collector dc on d.data_collector_id = dc.id
    JOIN policy_item pitem on pitem.alert_type_code = 'LAF-401' and dc.policy_id = pitem.policy_id
    JOIN policy p on p.id = pitem.policy_id
    JOIN packet pck on pck.id = d.last_packet_id
    JOIN gateway g on g.data_collector_id = dc.id and g.gw_hex_id = pck.gateway
    JOIN row_processed rp on rp.analyzer = 'packet_analyzer'
    JOIN packet proc_pck on proc_pck.id = rp.last_row
WHERE d.connected and
    pitem.parameters::jsonb ? 'disconnection_sensitivity' and
    pitem.parameters::jsonb ? 'min_activity_period' and
    (
        (   -- For regular devices, consider only the median between packets
            (not (pitem.parameters::jsonb ? 'deviation_tolerance') or
                d.activity_freq is NULL or
                d.activity_freq = 0 or
                sqrt(d.activity_freq_variance)/d.activity_freq <= (pitem.parameters::json->>'deviation_tolerance')::numeric) and
            (d.last_activity + CONCAT(
                GREATEST(
                    (pitem.parameters::json->>'min_activity_period')::numeric,
                    COALESCE(d.activity_freq, 0)/((pitem.parameters::json->>'disconnection_sensitivity')::numeric)
                )::text,' seconds'
            )::interval) < proc_pck.date
        )
        or
        (   --For irregular devices, consider median + deviation
            pitem.parameters::jsonb ? 'deviation_tolerance' and
            d.activity_freq is not NULL and
            d.activity_freq != 0 and
            sqrt(d.activity_freq_variance)/d.activity_freq > (pitem.parameters::json->>'deviation_tolerance')::numeric and
            (d.last_activity + CONCAT(
                GREATEST(
                    (pitem.parameters::json->>'min_activity_period')::numeric,
                    (sqrt(d.activity_freq_variance)+d.activity_freq)/((pitem.parameters::json->>'disconnection_sensitivity')::numeric)
                )::text,' seconds'
            )::interval) < proc_pck.date
        )
    )

-- 2) Add an alert for every device that will be disconnected if corresponds
with dv_created_alerts as (
    INSERT INTO alert (type, created_at, packet_id, device_id, gateway_id, data_collector_id, parameters, show)
    SELECT alert_type, created_at, packet_id, device_id, gateway_id, data_collector_id, parameters, show
    FROM dv_to_disconnect
    WHERE should_create_alert
    RETURNING *
)
-- Add an issue for every alert created
INSERT INTO quarantine (device_id, alert_id, since, organization_id, last_checked)
SELECT DISTINCT ON (dvca.id) dtd.device_id, dvca.id, dvca.created_at, dtd.organization_id, dvca.created_at
FROM dv_created_alerts dvca
    JOIN dv_to_disconnect dtd on dvca.device_id = dtd.device_id

-- 3) Disconnect the corresponding devices
UPDATE device
SET connected = false
WHERE id in (select device_id from dv_to_disconnect)

-- Clean temp tables
drop table if exists gw_to_disconnect, dv_to_disconnect, gw_created_alerts, dv_created_alerts;
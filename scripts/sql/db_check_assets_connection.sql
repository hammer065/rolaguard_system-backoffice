-- To ensure that these table names are not in use
drop table if exists gw_to_disconnect, dv_to_disconnect, created_alerts;

-- A gateway is considered disconnected if both of these conditions are met:
--    * It hasn't sent a package for more than 3 minutes
--    * It hasn't sent a package for more than (1/disconnection_sensitivity) times it's 
--      usual period, where disconnection_sensitivity is a configurable policy parameter
-- 1) Get gateways to disconnect and the data needed to create the corresponding alerts
SELECT
    DISTINCT ON (g.id, dc.id)
    g.id as gateway_id,
    dc.id as data_collector_id,
    pitem.alert_type_code as alert_type,
    (pitem.enabled and dc.deleted_at is null and dc.status = 'CONNECTED'::datacollectorstatus) as should_create_alert,
    true as show,
    now() as created_at,
    -1 as packet_id,
    json_build_object(
        'gw_hex_id', g.gw_hex_id,
        'gw_name', g.name,
        'gw_vendor', g.vendor,
        'last_activity', g.last_activity,
        'activity_freq', g.activity_freq,
        'policy_name', p.name,
        'disconnection_sensitivity_value', pitem.parameters::json->'disconnection_sensitivity'
    ) as parameters
INTO gw_to_disconnect
FROM gateway g
    JOIN data_collector dc on g.organization_id = dc.organization_id
    JOIN policy_item pitem on pitem.alert_type_code = 'LAF-403' and dc.policy_id = pitem.policy_id
    JOIN policy p on p.id = pitem.policy_id
WHERE g.connected and pitem.parameters::jsonb ? 'disconnection_sensitivity' and
    (g.last_activity + CONCAT(GREATEST(180, COALESCE(g.activity_freq, 0)/((pitem.parameters::json->>'disconnection_sensitivity')::numeric))::text, ' seconds')::interval) < now()

-- 2) Add an alert for every gateway that will be disconnected if corresponds
INSERT INTO alert (type, created_at, packet_id, gateway_id, data_collector_id, parameters, show)
SELECT alert_type, created_at, packet_id, gateway_id, data_collector_id, parameters, show
FROM gw_to_disconnect
WHERE should_create_alert

-- 3) Disconnect the corresponding gateways
UPDATE gateway
SET connected = false
WHERE id in (select gateway_id from gw_to_disconnect)

-- A device is considered disconnected if both of these conditions are met:
--    * It hasn't sent a package for more than 5 minutes
--    * It hasn't sent a package for more than (1/disconnection_sensitivity) times it's 
--      usual period, where disconnection_sensitivity is a configurable policy parameter
-- 1) Get devices to disconnect and the data needed to create the corresponding alerts
SELECT
    DISTINCT ON (d.id, dc.id)
    d.id as device_id,
    d.organization_id as organization_id,
    dc.id as data_collector_id,
    pitem.alert_type_code as alert_type,
    (pitem.enabled and dc.deleted_at is null and dc.status = 'CONNECTED'::datacollectorstatus) as should_create_alert,
    true as show,
    now() as created_at,
    d.last_packet_id as packet_id,
    json_build_object(
        'dev_eui', d.dev_eui,
        'dev_name', d.name,
        'dev_vendor', d.vendor,
        'last_activity', d.last_activity,
        'activity_freq', d.activity_freq,
        'policy_name', p.name,
        'disconnection_sensitivity_value', pitem.parameters::json->'disconnection_sensitivity'
    ) as parameters
INTO dv_to_disconnect
FROM device d
    JOIN data_collector dc on d.organization_id = dc.organization_id
    JOIN policy_item pitem on pitem.alert_type_code = 'LAF-401' and dc.policy_id = pitem.policy_id
    JOIN policy p on p.id = pitem.policy_id
WHERE d.connected and pitem.parameters::jsonb ? 'disconnection_sensitivity' and
    (d.last_activity + CONCAT(GREATEST(300, COALESCE(d.activity_freq, 0)/((pitem.parameters::json->>'disconnection_sensitivity')::numeric))::text, ' seconds')::interval) < now()

-- 2) Add an alert for every device that will be disconnected if corresponds
with created_alerts as (
    INSERT INTO alert (type, created_at, packet_id, device_id, data_collector_id, parameters, show)
    SELECT alert_type, created_at, packet_id, device_id, data_collector_id, parameters, show
    FROM dv_to_disconnect
    WHERE should_create_alert
    RETURNING *
)
-- Add an issue for every alert created
INSERT INTO quarantine (device_id, alert_id, since, organization_id, last_checked)
SELECT DISTINCT ON (ca.id) dtd.device_id, ca.id, ca.created_at, dtd.organization_id, ca.created_at
FROM created_alerts ca
    JOIN dv_to_disconnect dtd on ca.device_id = dtd.device_id

-- 3) Disconnect the corresponding devices
UPDATE device
SET connected = false
WHERE id in (select device_id from dv_to_disconnect)

-- Clean temp tables
drop table if exists gw_to_disconnect, dv_to_disconnect, created_alerts;
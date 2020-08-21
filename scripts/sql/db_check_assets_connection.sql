-- A gateway is considered disconnected if both of these conditions are met:
--    * It hasn't sent a package for more than 2 minutes
--    * It hasn't sent a package for more than 10 times it's usual frequency
UPDATE public.gateway
SET connected = false
WHERE connected AND (last_activity + CONCAT(GREATEST(120, COALESCE(activity_freq, 0)*10)::text, ' seconds')::interval) < now()

-- A device is considered disconnected if both of these conditions are met:
--    * It hasn't sent a package for more than 5 minutes
--    * It hasn't sent a package for more than 20 times it's usual frequency
UPDATE public.device
SET connected = false, npackets_lost = 0
WHERE connected AND (last_activity + CONCAT(GREATEST(300, COALESCE(activity_freq, 0)*20)::text, ' seconds')::interval) < now()
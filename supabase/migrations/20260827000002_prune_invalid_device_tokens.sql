-- supabase/migrations/20260827000002_prune_invalid_device_tokens.sql
-- A real APNs device token is 32 bytes hex-encoded (64 chars). Simulator remote-push
-- tokens are non-deliverable placeholders in a different length and were being upserted
-- alongside real tokens with no distinction — every push attempt to one silently failed
-- (APNs BadDeviceToken), consuming a slot in the loop with no visible symptom to the user.
DELETE FROM device_tokens
WHERE platform = 'ios' AND length(token) != 64;

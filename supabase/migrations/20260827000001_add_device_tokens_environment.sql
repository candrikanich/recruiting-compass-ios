-- supabase/migrations/20260827000001_add_device_tokens_environment.sql
-- Sandbox-built and production-built apps get APNs tokens minted under different
-- APNs hosts (api.sandbox.push.apple.com vs api.push.apple.com); a push sent to the
-- wrong host is rejected with BadDeviceToken. Stamp which host each token belongs to
-- so the push-delivery edge function can route correctly.
ALTER TABLE device_tokens
  ADD COLUMN IF NOT EXISTS environment text NOT NULL DEFAULT 'sandbox'
    CHECK (environment IN ('sandbox', 'production'));

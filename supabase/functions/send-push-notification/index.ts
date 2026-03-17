// supabase/functions/send-push-notification/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://esm.sh/jose@5";

const APNS_HOST = Deno.env.get("APNS_ENVIRONMENT") === "production"
  ? "https://api.push.apple.com"
  : "https://api.sandbox.push.apple.com";

interface NotificationRow {
  id: string;
  user_id: string;
  type: string;
  title: string;
  message: string;
  related_entity_type?: string;
  related_entity_id?: string;
}

Deno.serve(async (req) => {
  try {
    const notification: NotificationRow = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 1. Check push preference (no row = send by default)
    const { data: pref } = await supabase
      .from("notification_preferences")
      .select("push_enabled")
      .eq("user_id", notification.user_id)
      .eq("notification_type", notification.type)
      .maybeSingle();

    if (pref?.push_enabled === false) {
      return new Response("push disabled for type", { status: 200 });
    }

    // 2. Fetch device tokens
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", notification.user_id)
      .eq("platform", "ios");

    if (!tokens?.length) {
      return new Response("no device tokens", { status: 200 });
    }

    // 3. Unread badge count
    const { count: badgeCount } = await supabase
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("user_id", notification.user_id)
      .is("read_at", null);

    // 4. Build APNs JWT
    const apnsJwt = await buildApnsJwt();

    // 5. Send to each device token
    let atLeastOneSuccess = false;
    const staleTokens: string[] = [];

    for (const { token } of tokens) {
      const result = await sendApnsPush({
        deviceToken: token,
        jwt: apnsJwt,
        title: notification.title,
        body: notification.message,
        badge: badgeCount ?? 0,
        data: {
          notification_id: notification.id,
          related_entity_type: notification.related_entity_type,
          related_entity_id: notification.related_entity_id,
        },
      });

      if (result.status === 200) {
        atLeastOneSuccess = true;
      } else if (result.status === 410) {
        staleTokens.push(token);
      } else {
        console.error(`APNs error ${result.status} for token ${token.slice(0, 8)}...`);
      }
    }

    // 6. Clean up stale tokens
    if (staleTokens.length) {
      await supabase
        .from("device_tokens")
        .delete()
        .eq("user_id", notification.user_id)
        .in("token", staleTokens);
    }

    // 7. Mark sent_at if at least one delivery succeeded
    if (atLeastOneSuccess) {
      await supabase
        .from("notifications")
        .update({ sent_at: new Date().toISOString() })
        .eq("id", notification.id);
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error("send-push-notification error:", err);
    return new Response("internal error", { status: 500 });
  }
});

// MARK: - APNs Helpers

async function buildApnsJwt(): Promise<string> {
  const keyId   = Deno.env.get("APNS_KEY_ID")!;
  const teamId  = Deno.env.get("APNS_TEAM_ID")!;
  const rawKey  = Deno.env.get("APNS_PRIVATE_KEY")!;

  const privateKey = await importPKCS8(rawKey, "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(privateKey);
}

async function sendApnsPush(opts: {
  deviceToken: string;
  jwt: string;
  title: string;
  body: string;
  badge: number;
  data: Record<string, string | undefined>;
}): Promise<Response> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;
  const url = `${APNS_HOST}/3/device/${opts.deviceToken}`;

  const payload = {
    aps: {
      alert: { title: opts.title, body: opts.body },
      badge: opts.badge,
      sound: "default",
    },
    ...opts.data,
  };

  return fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${opts.jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
}

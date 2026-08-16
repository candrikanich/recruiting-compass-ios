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
  priority?: string;
  action_url?: string;
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

    // Per-type delivery preferences (no row = deliver by default on both channels).
    const { data: pref } = await supabase
      .from("notification_preferences")
      .select("push_enabled, email_enabled")
      .eq("user_id", notification.user_id)
      .eq("notification_type", notification.type)
      .maybeSingle();

    // Email is independent of push: send it even when the user has no iOS device.
    if (pref?.email_enabled !== false) {
      await sendEmail(supabase, notification);
    }

    if (pref?.push_enabled === false) {
      return new Response("push disabled for type", { status: 200 });
    }

    // Fetch device tokens
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", notification.user_id)
      .eq("platform", "ios");

    if (!tokens?.length) {
      return new Response("no device tokens", { status: 200 });
    }

    // Unread badge count
    const { count: badgeCount } = await supabase
      .from("notifications")
      .select("id", { count: "exact", head: true })
      .eq("user_id", notification.user_id)
      .is("read_at", null);

    const apnsJwt = await buildApnsJwt();

    let atLeastOneSuccess = false;
    const staleTokens: string[] = [];

    console.log(`send-push: host=${APNS_HOST} tokens=${tokens.length} type=${notification.type}`);

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
        console.log(`APNs 200 for token ${token.slice(0, 8)}...`);
      } else if (result.status === 410) {
        staleTokens.push(token);
      } else {
        const reason = await result.text().catch(() => "");
        console.error(`APNs error ${result.status} for token ${token.slice(0, 8)}... reason=${reason}`);
      }
    }

    // Clean up stale tokens
    if (staleTokens.length) {
      await supabase
        .from("device_tokens")
        .delete()
        .eq("user_id", notification.user_id)
        .in("token", staleTokens);
    }

    // Mark sent_at if at least one delivery succeeded
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

// MARK: - Email

// deno-lint-ignore no-explicit-any
async function sendEmail(supabase: any, notification: NotificationRow): Promise<void> {
  try {
    const webBase = Deno.env.get("WEB_BASE_URL");
    const cronSecret = Deno.env.get("CRON_SECRET");
    if (!webBase || !cronSecret) {
      console.log("email skipped: WEB_BASE_URL or CRON_SECRET not configured");
      return;
    }

    const { data: user } = await supabase
      .from("users")
      .select("email")
      .eq("id", notification.user_id)
      .maybeSingle();

    if (!user?.email) return;

    const actionUrl = notification.action_url &&
        /^https?:\/\//.test(notification.action_url)
      ? notification.action_url
      : undefined;

    const resp = await fetch(`${webBase}/api/notifications/email`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${cronSecret}`,
      },
      body: JSON.stringify({
        to: user.email,
        subject: notification.title,
        title: notification.title,
        message: notification.message,
        priority: notification.priority ?? "normal",
        ...(actionUrl ? { actionUrl } : {}),
        idempotencyKey: `notif-${notification.id}`,
      }),
    });

    if (resp.ok) {
      await supabase
        .from("notifications")
        .update({ email_sent: true, email_sent_at: new Date().toISOString() })
        .eq("id", notification.id);
    } else {
      console.error(`email send failed ${resp.status}: ${await resp.text().catch(() => "")}`);
    }
  } catch (err) {
    console.error("email step error:", err);
  }
}

// MARK: - APNs Helpers

// Reconstruct a clean PKCS#8 PEM even if the stored secret had its base64
// newlines replaced by spaces, escaped as \n, or wrapped in quotes.
function normalizePkcs8(raw: string): string {
  let s = raw.replace(/\\n/g, "\n").replace(/^["']|["']$/g, "").trim();
  const m = s.match(/-----BEGIN PRIVATE KEY-----([\s\S]*?)-----END PRIVATE KEY-----/);
  if (m) {
    const b64 = m[1].replace(/\s+/g, "");
    const wrapped = b64.match(/.{1,64}/g)?.join("\n") ?? b64;
    s = `-----BEGIN PRIVATE KEY-----\n${wrapped}\n-----END PRIVATE KEY-----`;
  }
  return s;
}

async function buildApnsJwt(): Promise<string> {
  const keyId   = Deno.env.get("APNS_KEY_ID")!;
  const teamId  = Deno.env.get("APNS_TEAM_ID")!;
  const rawKey  = Deno.env.get("APNS_PRIVATE_KEY")!;

  const privateKey = await importPKCS8(normalizePkcs8(rawKey), "ES256");
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

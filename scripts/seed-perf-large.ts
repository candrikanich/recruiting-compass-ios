import { createClient } from "@supabase/supabase-js";

// Layers a large account on top of `seed-demo-screenshots.ts` (run that first) so the performance
// baseline scrolls real volume: 60 extra schools with a coach each, 240 interactions, 120
// notifications and 30 events. LOCAL Supabase only; everything is fictional. Idempotent.

const SUPABASE_URL = process.env.SUPABASE_URL ?? "http://127.0.0.1:54321";
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SERVICE_ROLE_KEY) {
  console.error("SUPABASE_SERVICE_ROLE_KEY is required (`supabase status -o env`)");
  process.exit(1);
}
const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);
const isLoopback = (raw: string): boolean => {
  try {
    return LOOPBACK_HOSTS.has(new URL(raw).hostname);
  } catch {
    return false;
  }
};
if (!isLoopback(SUPABASE_URL)) {
  console.error(`Refusing non-local target: ${SUPABASE_URL}`);
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const SCHOOL_COUNT = 60;
const INTERACTIONS_PER_SCHOOL = 4;
const NOTIFICATION_COUNT = 120;
const EVENT_COUNT = 30;
// Every row this script owns carries the marker, so reseeding removes exactly its own rows.
const MARKER = "Perf";

const dayOffset = (days: number): string => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
};
const isoOffset = (days: number, hour = 15): string => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(hour, 0, 0, 0);
  return d.toISOString();
};

function must<T>(label: string, result: { data: T | null; error: { message: string } | null }): T {
  if (result.error || result.data === null) {
    console.error(`${label} failed:`, result.error?.message);
    process.exit(1);
  }
  return result.data;
}

const pick = <T>(values: readonly T[], index: number): T => values[index % values.length];
const range = (count: number): number[] => Array.from({ length: count }, (_, i) => i);
const padded = (i: number): string => String(i + 1).padStart(3, "0");

const STATES = ["NC", "SC", "VA", "GA", "TN", "FL", "TX", "CA", "OH", "PA"] as const;
const DIVISIONS = ["D1", "D1", "D3"] as const;
const STATUSES = ["researching", "contacted", "interested", "camp_invite", "visiting"] as const;
const FIT_TIERS = ["reach", "match", "safety"] as const;
const INTERACTION_TYPES = ["email", "phone_call", "text", "dm", "virtual_meeting"] as const;
const DIRECTIONS = ["inbound", "outbound"] as const;
const SENTIMENTS = ["very_positive", "positive", "neutral"] as const;

async function userIdFor(email: string): Promise<string> {
  const row = must(`user ${email}`, await supabase.from("users").select("id").eq("email", email).single());
  return row.id as string;
}

async function wipeOwnRows(parentId: string, playerId: string, familyId: string) {
  await supabase.from("interactions").delete().eq("family_unit_id", familyId).like("subject", `${MARKER} %`);
  await supabase.from("events").delete().eq("user_id", playerId).like("name", `${MARKER} %`);
  await supabase.from("notifications").delete().eq("user_id", playerId).like("title", `${MARKER} %`);
  await supabase.from("coaches").delete().eq("user_id", parentId).like("last_name", `${MARKER}%`);
  await supabase.from("schools").delete().eq("user_id", parentId).like("name", `${MARKER} %`);
}

async function seedSchoolsAndCoaches(parentId: string, familyId: string) {
  const schools = must("perf schools", await supabase.from("schools").insert(
    range(SCHOOL_COUNT).map((i) => {
      const state = pick(STATES, i);
      return {
        name: `${MARKER} State University ${padded(i)}`,
        city: `Springfield ${padded(i)}`, state, location: `Springfield ${padded(i)}, ${state}`,
        division: pick(DIVISIONS, i), conference: "Independent",
        status: pick(STATUSES, i), fit_tier: pick(FIT_TIERS, i), is_favorite: i % 7 === 0,
        website: `https://perf${padded(i)}.example.edu`,
        pros: ["Strong academics", "Development-first staff"], cons: ["Far from home"],
        why_program: "Added while building out the full target list.",
        fit_reason: "Fits the academic and roster profile.",
        user_id: parentId, family_unit_id: familyId,
      };
    })
  ).select("id, name"));

  const coaches = must("perf coaches", await supabase.from("coaches").insert(
    schools.map((school, i) => ({
      school_id: school.id, user_id: parentId, family_unit_id: familyId,
      role: i % 2 === 0 ? "head" : "recruiting",
      first_name: "Casey", last_name: `${MARKER}coach${padded(i)}`,
      email: `casey.coach${padded(i)}@example.edu`, last_contact_date: dayOffset(-(i % 30)),
    }))
  ).select("id, school_id"));

  return schools.map((school) => ({
    schoolId: school.id as string,
    coachId: coaches.find((coach) => coach.school_id === school.id)!.id as string,
  }));
}

async function seedInteractions(playerId: string, familyId: string, pairs: { schoolId: string; coachId: string }[]) {
  const rows = pairs.flatMap((pair, schoolIndex) =>
    range(INTERACTIONS_PER_SCHOOL).map((n) => {
      const i = schoolIndex * INTERACTIONS_PER_SCHOOL + n;
      return {
        school_id: pair.schoolId, coach_id: pair.coachId,
        type: pick(INTERACTION_TYPES, i), direction: pick(DIRECTIONS, i), sentiment: pick(SENTIMENTS, i),
        subject: `${MARKER} check-in ${padded(i)}`,
        content: "Shared the updated schedule and asked about roster needs for the class.",
        occurred_at: isoOffset(-(i % 180) - 1, 9 + (i % 9)),
        logged_by: playerId, family_unit_id: familyId,
      };
    })
  );
  must("perf interactions", await supabase.from("interactions").insert(rows).select("id"));
}

async function seedNotifications(playerId: string) {
  must("perf notifications", await supabase.from("notifications").insert(
    range(NOTIFICATION_COUNT).map((i) => ({
      user_id: playerId,
      type: i % 3 === 0 ? "deadline_alert" : "follow_up_reminder",
      title: `${MARKER} reminder ${padded(i)}`,
      message: "Follow up with the coaching staff and log the conversation.",
      priority: i % 5 === 0 ? "high" : "normal",
      scheduled_for: isoOffset(-(i % 60), 8 + (i % 10)),
    }))
  ).select("id"));
}

async function seedEvents(playerId: string, familyId: string, pairs: { schoolId: string }[]) {
  must("perf events", await supabase.from("events").insert(
    range(EVENT_COUNT).map((i) => ({
      user_id: playerId, family_unit_id: familyId, school_id: pick(pairs, i).schoolId,
      name: `${MARKER} prospect camp ${padded(i)}`, type: "camp",
      city: `Springfield ${padded(i)}`, state: pick(STATES, i), location: `Springfield ${padded(i)}, ${pick(STATES, i)}`,
      start_date: dayOffset(i * 5 - 40), registered: i % 2 === 0, attended: i * 5 - 40 < 0,
    }))
  ).select("id"));
}

async function main() {
  const parentId = await userIdFor("dana@example.com");
  const playerId = await userIdFor("jordan@example.com");
  const member = must("family", await supabase.from("family_members")
    .select("family_unit_id").eq("user_id", playerId).single());
  const familyId = member.family_unit_id as string;

  await wipeOwnRows(parentId, playerId, familyId);
  const pairs = await seedSchoolsAndCoaches(parentId, familyId);
  await seedInteractions(playerId, familyId, pairs);
  await seedNotifications(playerId);
  await seedEvents(playerId, familyId, pairs);

  console.log(
    `Large account seeded: +${SCHOOL_COUNT} schools, +${SCHOOL_COUNT * INTERACTIONS_PER_SCHOOL} interactions, ` +
      `+${NOTIFICATION_COUNT} notifications, +${EVENT_COUNT} events.`
  );
}

main();

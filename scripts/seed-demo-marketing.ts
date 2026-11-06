import { createClient } from "@supabase/supabase-js";

// Layers marketing-video extras on top of `seed-demo-screenshots.ts` (run that first): a longer
// school list, second coaches, a richer interaction log, family deadlines and two forwarded
// coach-email drafts. LOCAL Supabase only; all people are fictional. Idempotent.

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

async function userIdFor(email: string): Promise<string> {
  const row = must(`user ${email}`, await supabase.from("users").select("id").eq("email", email).single());
  return row.id as string;
}

type ExtraSchool = {
  name: string; city: string; state: string; division: string; conference: string;
  status: string; fit_tier: string; website: string; why_program: string;
  pros: string[]; cons: string[];
  coach: { first: string; last: string; role: "head" | "recruiting" | "assistant" };
};

const EXTRA_SCHOOLS: ExtraSchool[] = [
  { name: "Clemson University", city: "Clemson", state: "SC", division: "D1", conference: "ACC", status: "interested", fit_tier: "reach", website: "https://clemsontigers.com", why_program: "Big-time atmosphere two hours from home.", pros: ["Elite facilities", "Close to home"], cons: ["Huge roster"], coach: { first: "Brent", last: "Castellano", role: "recruiting" } },
  { name: "Elon University", city: "Elon", state: "NC", division: "D1", conference: "CAA", status: "camp_invite", fit_tier: "safety", website: "https://elonphoenix.com", why_program: "Beautiful campus and early playing time.", pros: ["Camp invite", "Small classes"], cons: ["Smaller budget"], coach: { first: "Nate", last: "Pruitt", role: "head" } },
  { name: "College of Charleston", city: "Charleston", state: "SC", division: "D1", conference: "CAA", status: "contacted", fit_tier: "safety", website: "https://cofcsports.com", why_program: "Great city and a program that develops pitchers.", pros: ["Pitching development", "Great city"], cons: ["Mid-major exposure"], coach: { first: "Luis", last: "Arroyo", role: "recruiting" } },
];

const SECOND_COACHES: { school: string; first: string; last: string; role: "head" | "recruiting" | "assistant" }[] = [
  { school: "Stanford University", first: "Derek", last: "Moreau", role: "recruiting" },
  { school: "Vanderbilt University", first: "Alan", last: "Fitzgerald", role: "head" },
  { school: "University of Virginia", first: "Chris", last: "Nakamura", role: "assistant" },
];

const email = (first: string, last: string) => `${first.toLowerCase()}.${last.toLowerCase()}@example.edu`;

async function seedExtraSchoolsAndCoaches(parentId: string, familyId: string) {
  const schools = must("extra schools", await supabase.from("schools").insert(
    EXTRA_SCHOOLS.map(({ coach: _coach, ...s }) => ({
      ...s, user_id: parentId, family_unit_id: familyId, location: `${s.city}, ${s.state}`,
      fit_reason: "Added after the summer showcase circuit.",
    }))
  ).select("id, name"));

  const all = must("schools", await supabase.from("schools").select("id, name").eq("family_unit_id", familyId));
  const schoolId = (name: string) => all.find((s) => s.name === name)!.id as string;

  must("extra coaches", await supabase.from("coaches").insert([
    ...EXTRA_SCHOOLS.map((s) => ({
      school_id: schools.find((row) => row.name === s.name)!.id, user_id: parentId, family_unit_id: familyId,
      role: s.coach.role, first_name: s.coach.first, last_name: s.coach.last,
      email: email(s.coach.first, s.coach.last), last_contact_date: dayOffset(-5),
    })),
    ...SECOND_COACHES.map((c) => ({
      school_id: schoolId(c.school), user_id: parentId, family_unit_id: familyId,
      role: c.role, first_name: c.first, last_name: c.last, email: email(c.first, c.last),
      last_contact_date: dayOffset(-10),
    })),
  ]).select("id"));

  const coaches = must("coaches", await supabase.from("coaches")
    .select("id, first_name, last_name, school_id").eq("family_unit_id", familyId));
  const coachId = (last: string) => coaches.find((c) => c.last_name === last)!.id as string;
  return { schoolId, coachId };
}

type Ids = Awaited<ReturnType<typeof seedExtraSchoolsAndCoaches>>;

// Deepens Coach Hale's log (the coach-detail shot) and gives the new schools some history.
async function seedExtraInteractions(playerId: string, familyId: string, ids: Ids) {
  const rows = [
    ["Stanford University", "Hale", "text", "inbound", "Looking forward to the visit", "Coach Hale confirmed the official visit itinerary.", "positive", -1],
    ["Stanford University", "Hale", "virtual_meeting", "outbound", "Zoom with Coach Hale and family", "Walked through academics, housing and the offer timeline.", "very_positive", -12],
    ["Stanford University", "Hale", "showcase", "inbound", "Saw Jordan at the PG Showcase", "Coach Hale watched two bullpen sessions and asked for updated grades.", "positive", -40],
    ["Stanford University", "Moreau", "email", "inbound", "Official visit logistics", "Flight and hotel details for the visit weekend.", "positive", -4],
    ["Vanderbilt University", "Fitzgerald", "phone_call", "inbound", "Call from Coach Fitzgerald", "Head coach called to talk about the pitching staff plan.", "very_positive", -5],
    ["Clemson University", "Castellano", "camp", "outbound", "Clemson prospect camp", "Threw a clean inning; staff asked for video.", "positive", -25],
    ["Elon University", "Pruitt", "email", "inbound", "Camp invitation", "Invited to the fall prospect camp.", "positive", -7],
    ["College of Charleston", "Arroyo", "email", "outbound", "Intro + highlight video", "Sent the fall schedule and new bullpen video.", "neutral", -16],
  ] as const;
  must("extra interactions", await supabase.from("interactions").insert(
    rows.map(([school, coach, type, direction, subject, content, sentiment, days]) => ({
      school_id: ids.schoolId(school), coach_id: ids.coachId(coach),
      type, direction, subject, content, sentiment,
      occurred_at: isoOffset(days), logged_by: playerId, family_unit_id: familyId,
    }))
  ).select("id"));
}

async function seedDeadlines(playerId: string, familyId: string, ids: Ids) {
  await supabase.from("user_deadlines").delete().eq("family_unit_id", familyId);
  must("deadlines", await supabase.from("user_deadlines").insert([
    { label: "Stanford offer decision", category: "decision", deadline_date: dayOffset(35), school_id: ids.schoolId("Stanford University") },
    { label: "Vanderbilt early action application", category: "application", deadline_date: dayOffset(32), school_id: ids.schoolId("Vanderbilt University") },
    { label: "Submit FAFSA", category: "financial_aid", deadline_date: dayOffset(18), school_id: null },
    { label: "Elon prospect camp registration", category: "visit", deadline_date: dayOffset(9), school_id: ids.schoolId("Elon University") },
    { label: "Send UVA questionnaire", category: "custom", deadline_date: dayOffset(4), school_id: ids.schoolId("University of Virginia") },
  ].map((d) => ({ ...d, user_id: playerId, family_unit_id: familyId }))).select("id"));
}

// Pending forwarded coach emails, pre-matched to a coach/school the way the inbound webhook does.
async function seedInboundDrafts(familyId: string, ids: Ids) {
  await supabase.from("inbound_email_drafts").delete().eq("family_unit_id", familyId);
  must("inbound drafts", await supabase.from("inbound_email_drafts").insert([
    {
      family_unit_id: familyId,
      matched_coach_id: ids.coachId("Whitaker"), matched_school_id: ids.schoolId("University of Virginia"),
      sender_name: "Tom Whitaker", sender_email: email("Tom", "Whitaker"),
      subject: "Great to see you at the Fall Classic",
      body_text: "Jordan, our staff enjoyed watching you pitch this weekend. Your fastball command stood out. We'd like to get you on campus for an unofficial visit this fall. Let me know some dates that work for your family.\n\nCoach Whitaker",
      occurred_at: isoOffset(-1, 10),
    },
    {
      family_unit_id: familyId,
      matched_coach_id: ids.coachId("Delgado"), matched_school_id: ids.schoolId("Wake Forest University"),
      sender_name: "Ryan Delgado", sender_email: email("Ryan", "Delgado"),
      subject: "Re: Jordan Rivera - LHP, Class of 2028",
      body_text: "Thanks for reaching out and sending the video. We're finalizing our pitching board for the class. Please send your fall showcase schedule and we'll try to get out to see you.\n\nCoach Delgado",
      occurred_at: isoOffset(-2, 18),
    },
  ]).select("id"));
}

async function main() {
  const parentId = await userIdFor("dana@example.com");
  const playerId = await userIdFor("jordan@example.com");
  const member = must("family", await supabase.from("family_members")
    .select("family_unit_id").eq("user_id", playerId).single());
  const familyId = member.family_unit_id as string;

  // The base seed's wipe() clears schools/coaches/interactions; this only removes its own extras first.
  const extraNames = EXTRA_SCHOOLS.map((s) => s.name);
  await supabase.from("schools").delete().eq("family_unit_id", familyId).in("name", extraNames);
  await supabase.from("coaches").delete().eq("family_unit_id", familyId).in("last_name", SECOND_COACHES.map((c) => c.last));

  const ids = await seedExtraSchoolsAndCoaches(parentId, familyId);
  await seedExtraInteractions(playerId, familyId, ids);
  await seedDeadlines(playerId, familyId, ids);
  await seedInboundDrafts(familyId, ids);
  console.log("Marketing extras seeded (11 schools, 2 pending forwarded-email drafts, 5 deadlines).");
}

main();

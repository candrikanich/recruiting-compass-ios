import { createClient } from "@supabase/supabase-js";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Seeds a realistic, entirely fictional family into the LOCAL Supabase stack so
// App Store screenshots show a populated app. Idempotent: reseeding wipes and
// recreates the demo family's rows.

const SUPABASE_URL = process.env.SUPABASE_URL ?? "http://127.0.0.1:54321";
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SERVICE_ROLE_KEY) {
  console.error("SUPABASE_SERVICE_ROLE_KEY is required (`supabase status -o env`)");
  process.exit(1);
}
// The seed wipes tables with the service-role key, so require a loopback host. A substring match
// would accept e.g. https://localhost.example.com.
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

const PARENT = { email: "dana@example.com", name: "Dana Rivera", role: "parent" } as const;
const PLAYER = { email: "jordan@example.com", name: "Jordan Rivera", role: "player" } as const;
const PASSWORD = "DemoPassword1";
const BASEBALL_SPORT_ID = "d1aacf0c-4dfe-4ded-bca2-0e151c83cc25";

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

async function ensureAuthUser(email: string, name: string, role: string): Promise<string> {
  const created = await supabase.auth.admin.createUser({
    email,
    password: PASSWORD,
    email_confirm: true,
    user_metadata: { display_name: name, role },
  });
  if (created.data.user) return created.data.user.id;

  const { data } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1000 });
  const existing = data?.users.find((u) => u.email === email);
  if (!existing) {
    console.error(`Cannot create or find ${email}:`, created.error?.message);
    process.exit(1);
  }
  // A leftover account may have a different password; the capture test signs in with PASSWORD.
  must("reset demo credentials", await supabase.auth.admin.updateUserById(existing.id, {
    password: PASSWORD,
    email_confirm: true,
    user_metadata: { display_name: name, role },
  }));
  return existing.id;
}

async function upsertUserRow(id: string, email: string, name: string, role: string, extra: object = {}) {
  must("users upsert", await supabase
    .from("users")
    .upsert({ id, email, full_name: name, role, onboarding_completed: true, ...extra }, { onConflict: "id" })
    .select("id"));
}

async function ensureFamily(parentId: string, playerId: string): Promise<string> {
  const { data: member } = await supabase
    .from("family_members").select("family_unit_id").eq("user_id", parentId).maybeSingle();
  let familyId = member?.family_unit_id as string | undefined;

  if (!familyId) {
    const unit = must("family_units", await supabase
      .from("family_units").insert({ family_name: "Rivera Family", created_by_user_id: parentId })
      .select("id").single());
    familyId = unit.id as string;
    must("parent member", await supabase.from("family_members")
      .insert({ family_unit_id: familyId, user_id: parentId, role: "parent" }).select("id"));
  }

  // Checked separately: the parent may already belong to a family that lacks the player.
  const { data: playerMember } = await supabase
    .from("family_members").select("id").eq("user_id", playerId).eq("family_unit_id", familyId).maybeSingle();
  if (!playerMember) {
    must("player member", await supabase.from("family_members")
      .insert({ family_unit_id: familyId, user_id: playerId, role: "player" }).select("id"));
  }

  const { data: profile } = await supabase
    .from("player_profiles").select("id").eq("user_id", playerId).maybeSingle();
  if (!profile) {
    must("player_profile", await supabase.from("player_profiles").insert({
      user_id: playerId,
      family_unit_id: familyId,
      hash_slug: "jrdn26",
      bio: "Left-handed pitcher and outfielder. Team captain, honor roll.",
      looking_for: "D1 and D2 programs with strong academics and a development-first culture.",
    }).select("id"));
  }
  return familyId;
}

async function wipe(parentId: string, playerId: string) {
  await supabase.from("interactions").delete().in("logged_by", [parentId, playerId]);
  await supabase.from("performance_metrics").delete().eq("user_id", playerId);
  await supabase.from("offers").delete().eq("user_id", playerId);
  await supabase.from("events").delete().eq("user_id", playerId);
  await supabase.from("notifications").delete().in("user_id", [parentId, playerId]);
  await supabase.from("coaches").delete().eq("user_id", parentId);
  await supabase.from("schools").delete().eq("user_id", parentId);
}

type SchoolSeed = {
  name: string; city: string; state: string; division: string; conference: string;
  status: string; fit_tier: string; is_favorite?: boolean; website: string;
  coach: { first: string; last: string; role: "head" | "recruiting"; };
};

const SCHOOLS: SchoolSeed[] = [
  { name: "Stanford University", city: "Stanford", state: "CA", division: "D1", conference: "ACC", status: "offer_received", fit_tier: "reach", is_favorite: true, website: "https://gostanford.com", coach: { first: "Marcus", last: "Hale", role: "head" } },
  { name: "Vanderbilt University", city: "Nashville", state: "TN", division: "D1", conference: "SEC", status: "visiting", fit_tier: "reach", is_favorite: true, website: "https://vucommodores.com", coach: { first: "Eric", last: "Sandoval", role: "recruiting" } },
  { name: "University of Virginia", city: "Charlottesville", state: "VA", division: "D1", conference: "ACC", status: "contacted", fit_tier: "match", website: "https://virginiasports.com", coach: { first: "Tom", last: "Whitaker", role: "head" } },
  { name: "Wake Forest University", city: "Winston-Salem", state: "NC", division: "D1", conference: "ACC", status: "contacted", fit_tier: "match", website: "https://godeacs.com", coach: { first: "Ryan", last: "Delgado", role: "recruiting" } },
  { name: "Rice University", city: "Houston", state: "TX", division: "D1", conference: "AAC", status: "researching", fit_tier: "match", website: "https://riceowls.com", coach: { first: "Kevin", last: "Brandt", role: "head" } },
  { name: "Davidson College", city: "Davidson", state: "NC", division: "D1", conference: "A-10", status: "researching", fit_tier: "safety", website: "https://davidsonwildcats.com", coach: { first: "Paul", last: "Ostrander", role: "head" } },
  { name: "Emory University", city: "Atlanta", state: "GA", division: "D3", conference: "UAA", status: "contacted", fit_tier: "safety", website: "https://emoryathletics.com", coach: { first: "Greg", last: "Lindqvist", role: "head" } },
  { name: "Tulane University", city: "New Orleans", state: "LA", division: "D1", conference: "AAC", status: "researching", fit_tier: "match", website: "https://tulanegreenwave.com", coach: { first: "Sam", last: "Okafor", role: "recruiting" } },
];

const SCORECARD_FIELDS = [
  "school.school_url", "school.address", "latest.student.size", "latest.admissions.admission_rate.overall",
  "latest.cost.tuition.in_state", "latest.cost.tuition.out_of_state", "location.lat", "location.lon",
  "latest.admissions.sat_scores.25th_percentile.overall", "latest.admissions.sat_scores.75th_percentile.overall",
  "latest.admissions.act_scores.25th_percentile.cumulative", "latest.admissions.act_scores.75th_percentile.cumulative",
];

type ScorecardRow = Record<string, string | number | null>;

// The same College Scorecard data the app's "Lookup college data" button stores in schools.academic_info,
// so School Detail renders the map, College Data and Academic Fit sections instead of empty states.
// DEMO_KEY allows only 30 requests/hour, so successful lookups are cached on disk (outside the repo).
const CACHE_PATH = process.env.SCORECARD_CACHE ?? join(tmpdir(), "rc-scorecard-cache.json");
const cache: Record<string, ScorecardRow> = existsSync(CACHE_PATH)
  ? (JSON.parse(readFileSync(CACHE_PATH, "utf8")) as Record<string, ScorecardRow>)
  : {};
const cacheKey = (school: SchoolSeed) => `${school.name}|${school.state}`;

async function lookupScorecard(school: SchoolSeed): Promise<ScorecardRow | null> {
  const cached = cache[cacheKey(school)];
  if (cached) return cached;

  const key = process.env.COLLEGE_SCORECARD_API_KEY ?? "DEMO_KEY";
  const params = new URLSearchParams({
    api_key: key, "school.name": school.name, "school.state": school.state,
    fields: SCORECARD_FIELDS.join(","), per_page: "1",
  });
  try {
    const res = await fetch(`https://api.data.gov/ed/collegescorecard/v1/schools.json?${params}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = (await res.json()) as { results: ScorecardRow[] };
    const row = body.results[0] ?? null;
    if (row) {
      cache[cacheKey(school)] = row;
      writeFileSync(CACHE_PATH, JSON.stringify(cache));
    }
    return row;
  } catch (error) {
    console.warn(`Scorecard lookup failed for ${school.name}:`, (error as Error).message);
    return null;
  }
}

// Runs before anything is wiped: a rate-limited lookup must not leave schools seeded without data.
async function requireScorecardData() {
  const missing: string[] = [];
  for (const school of SCHOOLS) {
    if (!(await lookupScorecard(school))) missing.push(school.name);
  }
  if (missing.length > 0) {
    console.error(`No Scorecard data for: ${missing.join(", ")}. Nothing was changed; retry later (cached lookups are kept).`);
    process.exit(1);
  }
}

const compact = <T extends Record<string, unknown>>(obj: T) =>
  Object.fromEntries(Object.entries(obj).filter(([, v]) => v !== null && v !== undefined));

async function enrichSchool(school: SchoolSeed) {
  const row = await lookupScorecard(school);
  if (!row) return {};
  const domain = String(row["school.school_url"] ?? "").replace(/^https?:\/\//, "").replace(/\/.*$/, "").replace(/^www\./, "");
  return {
    favicon_url: domain ? `https://www.google.com/s2/favicons?domain=${domain}&sz=128` : null,
    academic_info: compact({
      address: row["school.address"], city: school.city, state: school.state,
      latitude: row["location.lat"], longitude: row["location.lon"],
      student_size: row["latest.student.size"],
      admission_rate: row["latest.admissions.admission_rate.overall"],
      tuition_in_state: row["latest.cost.tuition.in_state"],
      tuition_out_of_state: row["latest.cost.tuition.out_of_state"],
      sat_25th: row["latest.admissions.sat_scores.25th_percentile.overall"],
      sat_75th: row["latest.admissions.sat_scores.75th_percentile.overall"],
      act_25th: row["latest.admissions.act_scores.25th_percentile.cumulative"],
      act_75th: row["latest.admissions.act_scores.75th_percentile.cumulative"],
    }),
  };
}

// The family's own research notes, so School Detail shows filled Pros/Cons and Why sections.
type FamilyNotes = { pros: string[]; cons: string[]; why_program: string; fit_reason: string };
const FAMILY_NOTES: Record<string, FamilyNotes> = {
  "Stanford University": {
    pros: ["Written offer in hand", "Top-tier academics", "Strong pitching development"],
    cons: ["Far from home", "Very competitive admissions"],
    why_program: "Elite academics with a real shot at playing early. Jordan loved the coaching staff on the call.",
    fit_reason: "Offer received; official visit is scheduled.",
  },
  "Vanderbilt University": {
    pros: ["Great campus and facilities", "SEC competition", "Enthusiastic recruiting coordinator"],
    cons: ["High cost of attendance", "Roster is deep at pitcher"],
    why_program: "Loved the official visit: the ballpark, the players, and how the staff talked about development.",
    fit_reason: "Mid-size campus and top academics match Jordan's list.",
  },
  "University of Virginia": {
    pros: ["Strong academics", "ACC schedule", "Camp invite received"],
    cons: ["Large campus"],
    why_program: "Great balance of academics and baseball. Waiting to hear back on the questionnaire.",
    fit_reason: "Sending highlight video after the fall season.",
  },
  "Wake Forest University": {
    pros: ["Close to home", "Smaller classes"],
    cons: ["No response from staff yet"],
    why_program: "Close to home with a strong academic reputation. Good ACC exposure.",
    fit_reason: "DM sent to the recruiting coordinator; following up next week.",
  },
  "Rice University": {
    pros: ["Excellent academics", "Small campus"],
    cons: ["Long travel from Charlotte"],
    why_program: "Top academics and a small, close-knit program.",
    fit_reason: "Still researching; adding to the fall showcase list.",
  },
  "Davidson College": {
    pros: ["Close to home", "Small classes", "Chance to play right away"],
    cons: ["Smaller baseball program"],
    why_program: "Local school with a great reputation and a real path to playing time.",
    fit_reason: "A strong safety option with excellent academics.",
  },
  "Emory University": {
    pros: ["Top academics", "Great location in Atlanta"],
    cons: ["D3: no athletic scholarship"],
    why_program: "Strong pre-med path; Jordan is interested in the sports-medicine program.",
    fit_reason: "Emailed the head coach about roster needs.",
  },
  "Tulane University": {
    pros: ["Great city", "Competitive AAC schedule"],
    cons: ["Far from home"],
    why_program: "Fun campus and a competitive baseball program.",
    fit_reason: "Just getting started; need to review the questionnaire.",
  },
};

async function seedSchoolsAndCoaches(parentId: string, familyId: string) {
  const rows = await Promise.all(SCHOOLS.map(async ({ coach: _c, ...s }) => ({
    ...s, user_id: parentId, family_unit_id: familyId, location: `${s.city}, ${s.state}`,
    ...FAMILY_NOTES[s.name], ...(await enrichSchool({ ...s, coach: _c })),
  })));
  const schools = must("schools", await supabase.from("schools").insert(rows).select("id, name"));
  const schoolId = (name: string) => schools.find((s) => s.name === name)!.id as string;

  const coaches = must("coaches", await supabase.from("coaches").insert(
    SCHOOLS.map((s) => ({
      school_id: schoolId(s.name),
      user_id: parentId,
      family_unit_id: familyId,
      role: s.coach.role,
      first_name: s.coach.first,
      last_name: s.coach.last,
      email: `${s.coach.first.toLowerCase()}.${s.coach.last.toLowerCase()}@example.edu`,
      last_contact_date: dayOffset(-3),
    }))
  ).select("id, first_name, last_name, school_id"));
  return { schoolId, coachFor: (name: string) => coaches.find((c) => c.school_id === schoolId(name))!.id as string };
}

async function seedInteractions(
  loggedById: string, familyId: string,
  ids: Awaited<ReturnType<typeof seedSchoolsAndCoaches>>
) {
  const rows = [
    ["Stanford University", "email", "inbound", "Offer details and next steps", "Coach Hale sent the written offer and timeline for a decision.", "very_positive", -2],
    ["Stanford University", "phone_call", "outbound", "Follow-up call with Coach Hale", "Discussed roster spot, academics, and the visit weekend.", "positive", -6],
    ["Stanford University", "email", "outbound", "Intro email + highlight video", "Sent skills video and fall schedule.", "neutral", -30],
    ["Vanderbilt University", "official_visit", "outbound", "Official visit — campus and facilities tour", "Met the staff, toured the ballpark, dinner with current players.", "very_positive", -9],
    ["Vanderbilt University", "text", "inbound", "Great meeting you this weekend", "Coach Sandoval texted to follow up after the visit.", "positive", -8],
    ["University of Virginia", "email", "inbound", "Thanks for your interest in Virginia", "Received questionnaire link and camp invite.", "positive", -14],
    ["Wake Forest University", "dm", "outbound", "DM to Coach Delgado", "Introduced Jordan and linked film.", "neutral", -11],
    ["Emory University", "email", "outbound", "Interest in Emory baseball", "Asked about academic fit and roster needs.", "neutral", -20],
  ] as const;
  must("interactions", await supabase.from("interactions").insert(
    rows.map(([school, type, direction, subject, content, sentiment, days]) => ({
      school_id: ids.schoolId(school),
      coach_id: ids.coachFor(school),
      type, direction, subject, content, sentiment,
      occurred_at: isoOffset(days),
      logged_by: loggedById,
      family_unit_id: familyId,
    }))
  ).select("id"));
}

async function seedAthleteData(playerId: string, familyId: string, ids: Awaited<ReturnType<typeof seedSchoolsAndCoaches>>) {
  const own = { user_id: playerId, family_unit_id: familyId };

  const events = must("events", await supabase.from("events").insert([
    { ...own, name: "Perfect Game National Showcase", type: "showcase", city: "Fort Myers", state: "FL", location: "Fort Myers, FL", start_date: dayOffset(21), end_date: dayOffset(24), registered: true, attended: false },
    { ...own, name: "Vanderbilt Elite Camp", type: "camp", school_id: ids.schoolId("Vanderbilt University"), city: "Nashville", state: "TN", location: "Nashville, TN", start_date: dayOffset(45), registered: true, attended: false },
    { ...own, name: "Stanford Official Visit", type: "official_visit", school_id: ids.schoolId("Stanford University"), city: "Stanford", state: "CA", location: "Stanford, CA", start_date: dayOffset(12), registered: true, attended: false },
  ]).select("id, name"));

  must("offers", await supabase.from("offers").insert([
    { ...own, school_id: ids.schoolId("Stanford University"), offer_type: "scholarship", scholarship_percentage: 75, offer_date: dayOffset(-2), deadline_date: dayOffset(35), status: "pending", notes: "Written offer received. Decision deadline set after the official visit." },
  ]).select("id"));

  const showcaseId = events.find((e) => e.name === "Perfect Game National Showcase")!.id as string;
  const metric = (metric_type: string, value: number, unit: string, days: number, verified = false, event_id: string | null = null) =>
    ({ ...own, metric_type, value, unit, recorded_date: dayOffset(days), verified, event_id });
  must("metrics", await supabase.from("performance_metrics").insert([
    metric("velocity", 84.0, "mph", -180), metric("velocity", 86.5, "mph", -120),
    metric("velocity", 88.0, "mph", -60, false), metric("velocity", 90.5, "mph", -40, true, showcaseId),
    metric("exit_velo", 91.0, "mph", -150), metric("exit_velo", 94.0, "mph", -90, true),
    metric("exit_velo", 97.5, "mph", -35, true, showcaseId),
    metric("sixty_time", 7.1, "sec", -150), metric("sixty_time", 6.9, "sec", -70), metric("sixty_time", 6.7, "sec", -35, true, showcaseId),
  ]).select("id"));
}

async function seedNotifications(userId: string) {
  must("notifications", await supabase.from("notifications").insert([
    { user_id: userId, type: "follow_up_reminder", title: "Follow up with Vanderbilt", message: "It's been 8 days since your official visit. Send a thank-you note to Coach Sandoval.", priority: "normal", scheduled_for: isoOffset(0) },
    { user_id: userId, type: "deadline_alert", title: "Stanford offer deadline in 35 days", message: "Review the written offer with your family before the deadline.", priority: "high", scheduled_for: isoOffset(1) },
  ]).select("id"));
}

// The app gates players on a `player` preferences row with a primary sport.
async function seedPlayerPreferences(playerId: string) {
  await supabase.from("user_preferences").delete().eq("user_id", playerId).eq("category", "player");
  must("user_preferences", await supabase.from("user_preferences").insert({
    user_id: playerId,
    category: "player",
    data: {
      graduation_year: new Date().getFullYear() + 2,
      high_school: "Lincoln High School",
      club_team: "Carolina Aces 17U",
      primary_sport: "Baseball",
      primary_position: "LHP",
      height_inches: 74,
      weight_lbs: 185,
      gpa: 3.9,
      sat_score: 1420,
      act_score: 34,
      school_state: "NC",
      campus_size_preference: "medium",
      cost_sensitivity: "medium",
      gender: "male",
    },
  }).select("id"));

  // Home location powers distance labels, the distance filter and the map's "Distance from Home".
  await supabase.from("user_preferences").delete().eq("user_id", playerId).eq("category", "location");
  must("home location", await supabase.from("user_preferences").insert({
    user_id: playerId,
    category: "location",
    data: { city: "Charlotte", state: "NC", zip: "28277", latitude: 35.0527, longitude: -80.8431 },
  }).select("id"));
}

// Timeline "status" scores completed required tasks for the athlete's grade level.
async function seedTasks(playerId: string) {
  await supabase.from("athlete_task").delete().eq("athlete_id", playerId);
  const tasks = must("tasks", await supabase.from("task").select("id, required").eq("grade_level", 11));
  const required = tasks.filter((t) => t.required).map((t) => t.id as string);
  const done = required.slice(0, 9).map((task_id) => ({
    athlete_id: playerId, task_id, status: "completed", completed_at: isoOffset(-14),
  }));
  const inProgress = required.slice(9, 11).map((task_id) => ({ athlete_id: playerId, task_id, status: "in_progress" }));
  must("athlete_task", await supabase.from("athlete_task").insert([...done, ...inProgress]).select("id"));
}

async function main() {
  await requireScorecardData();
  const parentId = await ensureAuthUser(PARENT.email, PARENT.name, PARENT.role);
  const playerId = await ensureAuthUser(PLAYER.email, PLAYER.name, PLAYER.role);
  await upsertUserRow(parentId, PARENT.email, PARENT.name, PARENT.role);
  await upsertUserRow(playerId, PLAYER.email, PLAYER.name, PLAYER.role, {
    graduation_year: new Date().getFullYear() + 2,
    primary_sport_id: BASEBALL_SPORT_ID,
    primary_position_custom: "LHP / OF",
    gpa: 3.9, high_school: "Lincoln High School", club_team: "Carolina Aces 17U",
    hometown_city: "Charlotte", hometown_state: "NC", height_inches: 74, weight_lbs: 185,
    jersey_number: "22", dominant_side: "left", profile_completeness: 92,
    phase_milestone_data: { onboarding_complete: true },
    // Explicit: web's get_athlete_status maps a null phase to grade 12, which would score the
    // seeded grade-11 tasks against the senior-year denominator.
    current_phase: "junior",
  });
  const familyId = await ensureFamily(parentId, playerId);

  await seedPlayerPreferences(playerId);
  await wipe(parentId, playerId);
  const ids = await seedSchoolsAndCoaches(parentId, familyId);
  await seedInteractions(playerId, familyId, ids);
  await seedAthleteData(playerId, familyId, ids);
  await seedNotifications(playerId);
  await seedTasks(playerId);

  console.log(`Demo seed complete. Login: ${PLAYER.email} / ${PASSWORD}`);
}

main();

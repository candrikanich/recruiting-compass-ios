import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "fs";
import { resolve } from "path";

// ---------------------------------------------------------------------------
// Env loading — reads .env.test for local dev; CI uses process.env directly
// ---------------------------------------------------------------------------
try {
  const envPath = resolve(import.meta.dirname, ".env.test");
  const raw = readFileSync(envPath, "utf8");
  for (const line of raw.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eqIdx = trimmed.indexOf("=");
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    if (key && !process.env[key]) {
      process.env[key] = value;
    }
  }
} catch {
  // CI uses process.env directly — no .env.test needed
}

// ---------------------------------------------------------------------------
// Supabase admin client
// ---------------------------------------------------------------------------
const SUPABASE_URL = process.env.SUPABASE_URL ?? process.env.TEST_SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL) {
  console.error("SUPABASE_URL (or TEST_SUPABASE_URL) is required");
  process.exit(1);
}
if (!SERVICE_ROLE_KEY) {
  console.error("SUPABASE_SERVICE_ROLE_KEY is required");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const TEST_EMAIL = "test@example.com";
const TEST_PASSWORD = "TestPassword1";
const TEST_DISPLAY_NAME = "Test Parent";

const PLAYER_EMAIL = "player@example.com";
const PLAYER_PASSWORD = "TestPassword1";
const PLAYER_DISPLAY_NAME = "Test Player";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function futureDate(daysFromNow: number): string {
  const d = new Date();
  d.setDate(d.getDate() + daysFromNow);
  return d.toISOString().slice(0, 10); // yyyy-MM-dd
}

function nowIso(): string {
  return new Date().toISOString();
}

// ---------------------------------------------------------------------------
// Step 1 — Create / find test user
// ---------------------------------------------------------------------------
async function resolveTestUser(): Promise<string> {
  const { data: createData, error: createError } =
    await supabase.auth.admin.createUser({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      email_confirm: true,
      user_metadata: { display_name: TEST_DISPLAY_NAME, role: "parent" },
    });

  if (!createError) {
    console.log("Created test user:", TEST_EMAIL);
    return createData.user.id;
  }

  const msg = createError.message ?? "";
  if (
    msg.includes("already been registered") ||
    msg.includes("already registered")
  ) {
    const { data: listData } = await supabase.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    const existing = listData?.users?.find((u) => u.email === TEST_EMAIL);
    if (!existing) {
      console.error("User exists but could not be found via listUsers");
      process.exit(1);
    }
    console.log("Test user already exists:", TEST_EMAIL);
    return existing.id;
  }

  console.error("Failed to create test user:", createError.message);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Step 2 — Upsert public.users row.
// Prod creates this via an auth.users trigger; the local stack has no such
// trigger, so we insert it explicitly (id, email, role are NOT NULL). Upsert
// on the primary key keeps reseeding idempotent.
// ---------------------------------------------------------------------------
async function patchUsersRow(
  userId: string,
  email: string,
  fullName: string,
  role: "parent" | "player"
): Promise<void> {
  const { error } = await supabase
    .from("users")
    .upsert(
      {
        id: userId,
        email,
        full_name: fullName,
        role,
        onboarding_completed: true,
      },
      { onConflict: "id" }
    );

  if (error) {
    console.error("Failed to upsert users row:", error.message);
    process.exit(1);
  }
  console.log(`Upserted users row: role=${role}, onboarding_completed=true`);
}

// ---------------------------------------------------------------------------
// Player (athlete) — auth user + public.users + family membership + profile.
// The app is athlete-centric: a parent's dashboard renders the SELECTED
// athlete's data. Offers/events/metrics/documents are owned by the athlete's
// user_id (with family_unit_id for RLS visibility); schools/coaches/
// interactions are family-owned. Without a linked player the parent sees the
// onboarding banner and tabs are gated.
// ---------------------------------------------------------------------------
async function resolvePlayerUser(): Promise<string> {
  const { data: createData, error: createError } =
    await supabase.auth.admin.createUser({
      email: PLAYER_EMAIL,
      password: PLAYER_PASSWORD,
      email_confirm: true,
      user_metadata: { display_name: PLAYER_DISPLAY_NAME, role: "player" },
    });

  if (!createError) {
    console.log("Created player user:", PLAYER_EMAIL);
    return createData.user.id;
  }

  const msg = createError.message ?? "";
  if (
    msg.includes("already been registered") ||
    msg.includes("already registered")
  ) {
    const { data: listData } = await supabase.auth.admin.listUsers({
      page: 1,
      perPage: 1000,
    });
    const existing = listData?.users?.find((u) => u.email === PLAYER_EMAIL);
    if (!existing) {
      console.error("Player exists but could not be found via listUsers");
      process.exit(1);
    }
    console.log("Player user already exists:", PLAYER_EMAIL);
    return existing.id;
  }

  console.error("Failed to create player user:", createError.message);
  process.exit(1);
}

async function linkPlayerToFamily(
  playerUserId: string,
  familyUnitId: string
): Promise<void> {
  // family_members membership (role must be 'player' per check constraint)
  const { data: existingMember } = await supabase
    .from("family_members")
    .select("id")
    .eq("user_id", playerUserId)
    .eq("family_unit_id", familyUnitId)
    .maybeSingle();

  if (!existingMember) {
    const { error: memberError } = await supabase
      .from("family_members")
      .insert({
        family_unit_id: familyUnitId,
        user_id: playerUserId,
        role: "player",
      });
    if (memberError) {
      console.error("Failed to add player family_member:", memberError.message);
      process.exit(1);
    }
  }

  // player_profiles (NOT NULL: user_id, family_unit_id, hash_slug)
  const { data: existingProfile } = await supabase
    .from("player_profiles")
    .select("id")
    .eq("user_id", playerUserId)
    .maybeSingle();

  if (!existingProfile) {
    const { error: profileError } = await supabase
      .from("player_profiles")
      .insert({
        user_id: playerUserId,
        family_unit_id: familyUnitId,
        hash_slug: "e2epl1",
      });
    if (profileError) {
      console.error("Failed to create player_profile:", profileError.message);
      process.exit(1);
    }
  }

  console.log("Linked player to family:", familyUnitId);
}

// ---------------------------------------------------------------------------
// Step 3 — Create / find family unit + membership
// ---------------------------------------------------------------------------
async function resolveFamily(userId: string): Promise<string> {
  // Check for existing membership first (idempotent)
  const { data: existing } = await supabase
    .from("family_members")
    .select("family_unit_id")
    .eq("user_id", userId)
    .maybeSingle();

  if (existing) {
    console.log("Family unit already exists:", existing.family_unit_id);
    return existing.family_unit_id as string;
  }

  const { data: unit, error: unitError } = await supabase
    .from("family_units")
    .insert({ family_name: "E2E Test Family", created_by_user_id: userId })
    .select()
    .single();

  if (unitError || !unit) {
    console.error("Failed to create family_unit:", unitError?.message);
    process.exit(1);
  }

  const { error: memberError } = await supabase
    .from("family_members")
    .insert({ family_unit_id: unit.id, user_id: userId, role: "parent" });

  if (memberError) {
    console.error("Failed to add family_member:", memberError.message);
    process.exit(1);
  }

  console.log("Created family unit:", unit.id);
  return unit.id as string;
}

// ---------------------------------------------------------------------------
// Cleanup — delete prior E2E rows so reseeding is idempotent.
// None of these tables have a unique constraint matching a natural key, so
// upsert(onConflict) fails ("no unique constraint matching ON CONFLICT").
// Delete-then-insert is constraint-independent. Order: children -> parents
// to satisfy foreign keys. Family unit/membership is preserved (resolveFamily
// is idempotent and the app's onboarding gate depends on it).
// ---------------------------------------------------------------------------
async function cleanupTestData(
  parentUserId: string,
  playerUserId: string
): Promise<void> {
  // Athlete-owned data lives under the player's user_id.
  await supabase.from("interactions").delete().eq("logged_by", parentUserId);
  await supabase.from("performance_metrics").delete().eq("user_id", playerUserId);
  await supabase.from("offers").delete().eq("user_id", playerUserId);
  await supabase.from("documents").delete().eq("user_id", playerUserId);
  await supabase.from("notifications").delete().eq("user_id", parentUserId);
  await supabase.from("events").delete().eq("user_id", playerUserId);
  await supabase.from("coaches").delete().eq("user_id", parentUserId);
  await supabase.from("schools").delete().eq("user_id", parentUserId);
  console.log("Cleaned prior E2E data for parent + player");
}

// ---------------------------------------------------------------------------
// Step 4 — Schools (2: one normal + one duplicate-name for duplicate detection)
// ---------------------------------------------------------------------------
async function seedSchools(
  userId: string,
  familyUnitId: string
): Promise<[string, string]> {
  const schools = [
    {
      user_id: userId,
      family_unit_id: familyUnitId,
      name: "Duke University",
      location: "Durham, NC",
      city: "Durham",
      state: "NC",
      division: "D1",
      conference: "ACC",
      status: "researching",
    },
    {
      user_id: userId,
      family_unit_id: familyUnitId,
      // Same name as first to trigger duplicate detection test
      name: "Duke University",
      location: "Durham, NC",
      city: "Durham",
      state: "NC",
      division: "D1",
      conference: "ACC",
      status: "interested",
    },
  ];

  const { data, error } = await supabase
    .from("schools")
    .insert(schools)
    .select("id, name");

  if (error) {
    console.warn("Schools seed error:", error.message);
  }

  const ids = (data ?? []).map((r) => r.id as string);
  console.log(`Schools: ${ids.length} created`);
  return [ids[0] ?? "", ids[1] ?? ids[0] ?? ""];
}

// ---------------------------------------------------------------------------
// Step 5 — Coaches (2 coaches on first school)
// ---------------------------------------------------------------------------
async function seedCoaches(
  schoolId: string,
  userId: string,
  familyUnitId: string
): Promise<string> {
  const coaches = [
    {
      school_id: schoolId,
      user_id: userId,
      family_unit_id: familyUnitId,
      role: "head",
      first_name: "John",
      last_name: "Smith",
      email: "jsmith@duke.edu",
    },
    {
      school_id: schoolId,
      user_id: userId,
      family_unit_id: familyUnitId,
      role: "recruiting",
      first_name: "Mike",
      last_name: "Johnson",
      email: "mjohnson@duke.edu",
    },
  ];

  const { data, error } = await supabase
    .from("coaches")
    .insert(coaches)
    .select("id");

  if (error) {
    console.warn("Coaches seed error:", error.message);
  }

  const { data: fetched } = await supabase
    .from("coaches")
    .select("id")
    .eq("school_id", schoolId)
    .eq("user_id", userId)
    .limit(1);

  const coachId = fetched?.[0]?.id as string ?? "";
  console.log(`Coaches: seeded for school ${schoolId}`);
  return coachId;
}

// ---------------------------------------------------------------------------
// Step 6 — Interactions (school + coach + user)
// ---------------------------------------------------------------------------
async function seedInteractions(
  schoolId: string,
  coachId: string,
  userId: string,
  familyUnitId: string
): Promise<void> {
  const interactions = [
    {
      type: "email",
      direction: "outbound",
      school_id: schoolId,
      coach_id: coachId,
      subject: "E2E Test — Initial Contact",
      content: "Introduced myself and expressed interest.",
      sentiment: "positive",
      occurred_at: nowIso(),
      logged_by: userId,
      family_unit_id: familyUnitId,
    },
    {
      type: "phone_call",
      direction: "inbound",
      school_id: schoolId,
      coach_id: coachId,
      subject: "E2E Test — Follow-up Call",
      content: "Discussed recruiting timeline.",
      sentiment: "very_positive",
      occurred_at: nowIso(),
      logged_by: userId,
      family_unit_id: familyUnitId,
    },
  ];

  const { error } = await supabase
    .from("interactions")
    .insert(interactions);

  if (error) {
    console.warn("Interactions seed error:", error.message);
  } else {
    console.log("Interactions seeded");
  }
}

// ---------------------------------------------------------------------------
// Step 7 — Events (1 future event)
// ---------------------------------------------------------------------------
async function seedEvents(
  schoolId: string,
  userId: string,
  familyUnitId: string
): Promise<string> {
  const event = {
    user_id: userId,
    family_unit_id: familyUnitId,
    name: "E2E Test — Summer Showcase",
    type: "showcase",
    school_id: schoolId,
    location: "Durham, NC",
    city: "Durham",
    state: "NC",
    start_date: futureDate(30),
    registered: false,
    attended: false,
  };

  const { data, error } = await supabase
    .from("events")
    .insert([event])
    .select("id");

  if (error) {
    console.warn("Events seed error:", error.message);
  }

  const eventId = (data?.[0]?.id as string) ?? "";
  console.log("Event seeded:", eventId);
  return eventId;
}

// ---------------------------------------------------------------------------
// Step 8 — Offers (2, different percentages)
// ---------------------------------------------------------------------------
async function seedOffers(
  schoolId: string,
  userId: string,
  familyUnitId: string
): Promise<void> {
  const offers = [
    {
      user_id: userId,
      family_unit_id: familyUnitId,
      school_id: schoolId,
      offer_type: "partial",
      scholarship_percentage: 50,
      offer_date: futureDate(-10),
      status: "pending",
      notes: "E2E Test — 50% partial scholarship",
    },
    {
      user_id: userId,
      family_unit_id: familyUnitId,
      school_id: schoolId,
      offer_type: "scholarship",
      scholarship_percentage: 75,
      offer_date: futureDate(-5),
      status: "pending",
      notes: "E2E Test — 75% scholarship",
    },
  ];

  const { error } = await supabase
    .from("offers")
    .insert(offers);

  if (error) {
    console.warn("Offers seed error:", error.message);
  } else {
    console.log("Offers seeded");
  }
}

// ---------------------------------------------------------------------------
// Step 9 — Performance metrics (3, different types + dates)
// ---------------------------------------------------------------------------
async function seedPerformanceMetrics(
  userId: string,
  eventId: string,
  familyUnitId: string
): Promise<void> {
  const metrics = [
    {
      user_id: userId,
      family_unit_id: familyUnitId,
      metric_type: "velocity",
      value: 88.5,
      unit: "mph",
      recorded_date: futureDate(-20),
      event_id: eventId || null,
      verified: false,
      notes: "E2E Test — fastball velocity",
    },
    {
      user_id: userId,
      family_unit_id: familyUnitId,
      metric_type: "exit_velo",
      value: 95.0,
      unit: "mph",
      recorded_date: futureDate(-15),
      event_id: null,
      verified: true,
      notes: "E2E Test — exit velocity",
    },
    {
      user_id: userId,
      family_unit_id: familyUnitId,
      metric_type: "sixty_time",
      value: 6.8,
      unit: "sec",
      recorded_date: futureDate(-10),
      event_id: null,
      verified: false,
      notes: "E2E Test — 60-yard dash",
    },
  ];

  const { error } = await supabase
    .from("performance_metrics")
    .insert(metrics);

  if (error) {
    console.warn("Performance metrics seed error:", error.message);
  } else {
    console.log("Performance metrics seeded");
  }
}

// ---------------------------------------------------------------------------
// Step 10 — Notifications (2, different types)
// ---------------------------------------------------------------------------
async function seedNotifications(userId: string): Promise<void> {
  const notifications = [
    {
      user_id: userId,
      type: "follow_up_reminder",
      title: "E2E Test — Follow-up Reminder",
      message: "Time to follow up with Duke University coaches.",
      priority: "normal",
      scheduled_for: nowIso(),
    },
    {
      user_id: userId,
      type: "deadline_alert",
      title: "E2E Test — Deadline Alert",
      message: "Offer deadline approaching in 30 days.",
      priority: "high",
      scheduled_for: futureDate(1),
    },
  ];

  const { error } = await supabase.from("notifications").insert(notifications);

  if (error) {
    console.warn("Notifications seed error:", error.message);
  } else {
    console.log("Notifications seeded");
  }
}

// ---------------------------------------------------------------------------
// Step 11 — Documents (1 document)
// ---------------------------------------------------------------------------
async function seedDocuments(
  userId: string,
  familyUnitId: string
): Promise<void> {
  const document = {
    user_id: userId,
    family_unit_id: familyUnitId,
    type: "resume",
    title: "E2E Test — Athlete Resume",
    description: "Sample athlete resume for E2E testing",
    file_url: "https://example.com/e2e-test-resume.pdf",
    file_type: "application/pdf",
    version: 1,
    is_current: true,
    shared_with_schools: [],
    uploaded_by: userId,
  };

  const { error } = await supabase
    .from("documents")
    .insert([document]);

  if (error) {
    console.warn("Documents seed error:", error.message);
  } else {
    console.log("Document seeded");
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main(): Promise<void> {
  console.log("Seeding iOS E2E test data...");

  const userId = await resolveTestUser();
  await patchUsersRow(userId, TEST_EMAIL, TEST_DISPLAY_NAME, "parent");
  const familyUnitId = await resolveFamily(userId);

  const playerUserId = await resolvePlayerUser();
  await patchUsersRow(playerUserId, PLAYER_EMAIL, PLAYER_DISPLAY_NAME, "player");
  await linkPlayerToFamily(playerUserId, familyUnitId);

  await cleanupTestData(userId, playerUserId);

  // Family-owned (visible to all members via family_unit_id): schools, coaches,
  // interactions are created under the parent. Athlete-owned (filtered by the
  // selected athlete's user_id): offers, events, metrics, documents go to the
  // player, with family_unit_id set so the parent's session can read them.
  const [schoolId] = await seedSchools(userId, familyUnitId);
  const coachId = await seedCoaches(schoolId, userId, familyUnitId);
  await seedInteractions(schoolId, coachId, userId, familyUnitId);
  const eventId = await seedEvents(schoolId, playerUserId, familyUnitId);
  await seedOffers(schoolId, playerUserId, familyUnitId);
  await seedPerformanceMetrics(playerUserId, eventId, familyUnitId);
  await seedNotifications(userId);
  await seedDocuments(playerUserId, familyUnitId);

  console.log("iOS E2E seed complete.");
}

main();

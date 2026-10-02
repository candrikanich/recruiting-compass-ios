// Exports the web app's recruiting-calendar dataset to the JSON fixture that
// RecruitingCalendarWebParityTests compares RecruitingCalendarData.swift against.
// Web is the source of truth (see web docs/recruiting-calendar-refresh.md), so
// re-run this whenever web's utils/recruitingCalendar/calendarData.ts or
// utils/ncaaRecruitingCalendar.ts changes, then port until the test is green.
//
// Usage (from scripts/):  npm run export:calendar-fixture -- [path-to-web-repo]
import { writeFileSync } from "fs";
import { resolve } from "path";
import { pathToFileURL } from "url";

const webRepo = resolve(
  process.argv[2] ?? resolve(import.meta.dirname, "../../recruiting-compass-web"),
);
const fixturePath = resolve(
  import.meta.dirname,
  "../TheRecruitingCompass/TheRecruitingCompassTests/Core/Utilities/Fixtures/web-recruiting-calendar.json",
);

const importFromWeb = (relativePath: string) =>
  import(pathToFileURL(resolve(webRepo, relativePath)).href);

const data = await importFromWeb("utils/recruitingCalendar/calendarData.ts");
const generic = await importFromWeb("utils/ncaaRecruitingCalendar.ts");

const fixture = {
  season: data.SEASON,
  seasonEnd: (data.SEASON_END as Date).toISOString().slice(0, 10),
  d1Calendars: data.D1_CALENDARS,
  d2AllSports: data.D2_ALL_SPORTS,
  d3Fallback: data.D3_FALLBACK,
  // Same lists, same order, as resolver.ts's GENERIC_MILESTONES.
  genericMilestones: [
    ...generic.SAT_TEST_DATES_2026,
    ...generic.ACT_TEST_DATES_2026,
    ...generic.NCAA_DEADLINES_2026,
    ...generic.NAIA_DEADLINES_2026,
    ...generic.COLLEGE_APPLICATION_DEADLINES_2026,
  ],
};

writeFileSync(fixturePath, `${JSON.stringify(fixture, null, 2)}\n`);
console.log(`Wrote ${fixturePath}`);

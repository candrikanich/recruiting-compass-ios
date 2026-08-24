import Foundation

/// NCAA 2026-27 recruiting-calendar dataset — Swift mirror of web
/// `utils/recruitingCalendar/calendarData.ts`, transcribed byte-identically
/// (same period type/start/end/description/confidence, same source URLs,
/// same `verifiedOn`). See that file for the NCAA S3 PDF citations this was
/// transcribed from.
enum RecruitingCalendarData {
    static let season = "2026-27"
    /// Last day of the 2026-27 NCAA recruiting season. Past this date the
    /// dataset is stale and the widget shows the L6b staleness banner.
    static let seasonEnd = "2027-07-31"
    private static let verifiedOn = "2026-08-23"
    private static let bucket = "https://ncaaorg.s3.amazonaws.com/compliance/recruiting/calendar/\(season)"

    // The "Other" bundle PDF's filename uses an EN DASH (U+2013) in "2026–27",
    // not a hyphen — verified as the real working NCAA URL; a hyphenated form
    // 404s. Kept as its own token, deliberately NOT derived from `season`, so
    // nothing ever silently ASCII-ifies it.
    private static let otherSeasonEnDash = "2026\u{2013}27"

    // MARK: - MBA — Division I Baseball

    private static let mba = SportCalendar(
        periods: [
            RecruitingPeriod(type: .contact, start: "2026-08-01", end: "2026-08-16",
                description: "Contact period opens for rising juniors (Class of 2028) — in-person/off-campus contact, calls, texts, emails, official visits permitted",
                confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-08-17", end: "2026-09-10",
                description: "Quiet period — in-person contact only on campus", confidence: .MEDIUM),
            RecruitingPeriod(type: .contact, start: "2026-09-11", end: "2026-10-11",
                description: "Contact period", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2026-10-12", end: "2027-02-28",
                description: "Quiet period (long fall/early-year window; interrupted by the Nov dead period and two Recruiting Shutdowns)",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead period spanning the D1/D2 early signing period open (Nov 11, 2026)", confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-11-24", end: "2026-11-29",
                description: "Thanksgiving recruiting shutdown — no contacts, evaluations, visits, or correspondence",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-12-22", end: "2026-12-27",
                description: "Winter-holiday recruiting shutdown", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2027-01-07", end: "2027-01-10",
                description: "Dead period", confidence: .MEDIUM),
            RecruitingPeriod(type: .contact, start: "2027-03-01", end: "2027-07-31",
                description: "Contact period (spring/summer, season-long — interrupted by 3 dead periods)", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-05-31", end: "2027-06-07",
                description: "Dead period (around College World Series selection/travel window)", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2027-06-19", end: "2027-06-21",
                description: "Dead period", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2027-07-03", end: "2027-07-05",
                description: "Dead period (July 4th)", confidence: .HIGH),
        ],
        milestones: [
            CalendarMilestone(date: "2026-11-11", title: "D1/D2 Early Signing Period Opens", type: .signing,
                description: "Athletes sign a Written Offer of Athletics Aid (replaced the NLI in Oct 2024) — Class of 2027"),
        ],
        source: "\(bucket)/\(season)D1Rec_MBARecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - WSB — Division I Softball

    private static let wsb = SportCalendar(
        periods: [
            RecruitingPeriod(type: .contact, start: "2026-08-01", end: "2026-08-09", description: "Contact Period", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2026-08-10", end: "2026-11-22",
                description: "Evaluation Period (scholastic practice/competition only); contains a carved-out Dead Period Aug 28–Sep 3 and a denser evaluation window Oct 17–Nov 22",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-08-28", end: "2026-09-03",
                description: "Dead Period (carved out of the Aug 10–Nov 22 evaluation window)", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2026-10-17", end: "2026-11-22",
                description: "Evaluation Period (scholastic AND nonscholastic practice/competition); active only Oct 17–18, 24–25, Oct 31–Nov 1, Nov 7–8, 14–15, 21–22 — nested inside the broader Aug10–Nov22 evaluation period",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period (carved out of the Oct17–Nov22 evaluation window)", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-11-23", end: "2027-01-02",
                description: "Quiet Period; contains carved-out Recruiting Shutdown Nov 25–29, Dead Period Dec 9–12, Recruiting Shutdown Dec 22–26, Recruiting Shutdown Dec 31–Jan 2",
                confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-11-25", end: "2026-11-29",
                description: "Recruiting Shutdown", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-12-09", end: "2026-12-12", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-12-22", end: "2026-12-26",
                description: "Recruiting Shutdown", confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-12-31", end: "2027-01-02",
                description: "Recruiting Shutdown", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-01-03", end: "2027-05-31",
                description: "Evaluation Period (scholastic practice/competition only; evaluations also permitted during HS regional/state championship competition not falling in a dead period)",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-06-01", end: "2027-06-11",
                description: "Dead Period (WCWS-anchored; dates shift with WCWS schedule)", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2027-06-12", end: "2027-07-31",
                description: "Contact Period (WCWS-anchored; begins the day after the dead period)", confidence: .HIGH),
        ],
        milestones: [],
        source: "\(bucket)/\(season)D1Rec_WSBRecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - MBB — Division I Men's Basketball

    private static let mbb = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-08-01", end: "2026-08-19", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-08-20", end: "2026-09-08", description: "Quiet Period", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2026-09-09", end: "2027-04-30",
                description: "Recruiting Period (legend term for in-person off-campus contacts+evaluations; mapped to contact); contains 3 carved-out Dead Periods (Nov 9–12, Dec 24–26, Apr 1–8)",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period (carved out of the Sep9–Apr30 recruiting period)", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-12-24", end: "2026-12-26",
                description: "Dead Period (carved out of the Sep9–Apr30 recruiting period)", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-04-01", end: "2027-04-08",
                description: "Dead Period (carved out of the Sep9–Apr30 recruiting period)", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2027-05-01", end: "2027-06-30",
                description: "Quiet Period; contains a dense cluster of nested Evaluation/Dead sub-windows tied to specific camps/combines",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-05-09", end: "2027-05-09", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-05-14", end: "2027-05-16",
                description: "Evaluation Period — NCAA certified events only and regularly scheduled international scholastic/nonscholastic team practice and competition; begins Friday 8 AM, ends Sunday 4 PM",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-05-26", end: "2027-06-06", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-06-11", end: "2027-06-13",
                description: "Evaluation Period — for approved NCAA, NFHS and applicable two-year college governing body scholastic events",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-06-19", end: "2027-06-20", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-06-25", end: "2027-06-27",
                description: "Evaluation Period — for approved NCAA, NFHS and applicable two-year college governing body scholastic events",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-07-01", end: "2027-07-31",
                description: "Dead Period (a PSA may not make an unofficial visit in July unless already signed/deposited); contains a carved-out Evaluation sub-window Jul 8–11, 15–18",
                confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-07-08", end: "2027-07-18",
                description: "Evaluation Period (active only Jul 8–11 and Jul 15–18, carved out of the Jul1–31 dead period) — NCAA certified events, institutional camps, permissible governing body events, and regularly scheduled international scholastic/nonscholastic team practice and competition; begins Thursday 8 AM, ends Sunday 6 PM",
                confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2027-07-19", end: "2027-07-25", description: "Quiet Period", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-08-01", end: "2027-08-18", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2027-08-19", end: "2027-08-31", description: "Quiet Period", confidence: .HIGH),
        ],
        milestones: [],
        source: "\(bucket)/\(season)D1Rec_MBBRecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - WBB — Division I Women's Basketball

    private static let wbb = SportCalendar(
        periods: [
            RecruitingPeriod(type: .quiet, start: "2026-08-01", end: "2026-08-31",
                description: "Quiet Period; contains a carved-out Recruiting Shutdown Aug 10–16", confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-08-10", end: "2026-08-16",
                description: "Recruiting Shutdown", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2026-09-01", end: "2026-09-30",
                description: "Contact Period — for seniors and two-year college PSAs only; evaluation period for other PSAs for scholastic activities only",
                confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2026-10-01", end: "2027-02-28",
                description: "Evaluation Period — scholastic activities only; contains a carved-out Dead Period Dec 24–26", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-12-24", end: "2026-12-26",
                description: "Dead Period (carved out of the Oct1–Feb28 evaluation period)", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2027-03-01", end: "2027-03-31",
                description: "Contact Period — for seniors and two-year college PSAs only; evaluation period for other PSAs for scholastic activities only",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-04-01", end: "2027-04-05", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2027-04-06", end: "2027-07-31",
                description: "Quiet Period; contains a dense cluster of nested Dead/Evaluation/Recruiting-Shutdown sub-windows",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-04-22", end: "2027-04-22",
                description: "Dead Period — for high school and two-year college PSAs only", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-04-23", end: "2027-04-25",
                description: "Evaluation Period — certified nonscholastic events only", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-04-26", end: "2027-04-26",
                description: "Dead Period — for high school and two-year college PSAs only", confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2027-05-03", end: "2027-05-09",
                description: "Recruiting Shutdown", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-05-13", end: "2027-05-13", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-05-14", end: "2027-05-16",
                description: "Evaluation Period — certified nonscholastic events only", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-05-17", end: "2027-05-17", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-06-16", end: "2027-06-16",
                description: "Dead Period (separate single-day window from May 17, same legend row grouping)", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-06-17", end: "2027-06-19",
                description: "Evaluation Period (begins Jun 17 @ noon, ends Jun 19 @ 6 PM) — for scholastic events approved by the NCAA and NFHS and intercollegiate events approved by applicable two-year college governing body only",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-06-20", end: "2027-06-20", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-07-08", end: "2027-07-08",
                description: "Dead Period (separate single-day window from Jun 20, same legend row grouping)", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-07-09", end: "2027-07-12", description: "Evaluation Period", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-07-13", end: "2027-07-13", description: "Dead Period", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-07-22", end: "2027-07-22",
                description: "Dead Period (separate single-day window from Jul 13, same legend row grouping)", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2027-07-23", end: "2027-07-26", description: "Evaluation Period", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-07-27", end: "2027-07-27", description: "Dead Period", confidence: .HIGH),
        ],
        milestones: [],
        source: "\(bucket)/\(season)D1Rec_WBBRecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - FBS — Division I Football Bowl Subdivision

    private static let fbs = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-08-01", end: "2026-08-31",
                description: "Dead Period — full month of August", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-08-01", end: "2026-09-02",
                description: "Quiet Period (sub-window): 48 hours before a home contest occurring in August or on Sept. 1–2, through 48 hours after the contest ends",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .evaluation, start: "2026-09-01", end: "2026-11-29",
                description: "Evaluation Period — 33 (42 for U.S. service academies) evaluation days within this window", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-30", end: "2026-12-31",
                description: "Dead Period (encompasses the Dec 2–4, 2026 early signing period)", confidence: .HIGH),
        ],
        milestones: [
            CalendarMilestone(date: "2026-12-02", title: "Early Signing Period Opens (Football)", type: .signing,
                description: "Early signing period, Dec 2–4, 2026 — falls inside the FBS Nov30–Dec31 Dead Period"),
            CalendarMilestone(date: "2027-02-03", title: "Regular (National) Signing Day (Football)", type: .signing,
                description: "First Wednesday of February; no NCAA-wide end date — varies by institution's own scholarship-award policy"),
        ],
        source: "\(bucket)/\(season)D1Rec_FBSRecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - FCS — Division I Football Championship Subdivision

    private static let fcs = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-08-01", end: "2026-08-31",
                description: "Dead Period — full month of August", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-08-01", end: "2026-09-02",
                description: "Quiet Period (sub-window): 48 hours before a home contest occurring in August or on Sept. 1–2, through 48 hours after the contest ends",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .evaluation, start: "2026-09-01", end: "2026-11-29",
                description: "Evaluation Period — 33 (42 for U.S. service academies) evaluation days within this window", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-30", end: "2026-12-03",
                description: "Dead Period (immediately precedes/covers start of early signing period)", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2026-12-04", end: "2026-12-18",
                description: "Contact Period (opens the day after early signing starts, in-person off-campus contact permitted)", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-12-18", end: "2026-12-20",
                description: "Quiet Period (short transition window before year-end dead period)", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-12-21", end: "2026-12-31", description: "Dead Period (year-end)", confidence: .HIGH),
        ],
        milestones: [
            CalendarMilestone(date: "2026-12-02", title: "Early Signing Period Opens (Football)", type: .signing,
                description: "Early signing period, Dec 2–4, 2026 — the Dec 4 FCS Contact-period start lines up exactly with the signing period's last day"),
            CalendarMilestone(date: "2027-02-03", title: "Regular (National) Signing Day (Football)", type: .signing,
                description: "First Wednesday of February; no NCAA-wide end date"),
        ],
        source: "\(bucket)/\(season)D1Rec_FCSRecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - XCTF — Division I Cross Country / Track & Field (combined)

    private static let xctf = SportCalendar(
        periods: [
            RecruitingPeriod(type: .contact, start: "2026-08-01", end: "2026-12-13",
                description: "Contact Period — long fall contact window, interrupted by two short dead-period carve-outs", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period (carve-out within the Aug1–Dec13 Contact window; likely NCAA XC Championships week)", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-21", end: "2026-11-21",
                description: "Dead Period, single day (carve-out within the same Contact window)", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-12-14", end: "2026-12-26",
                description: "Dead Period — holiday dead period, between the two long Contact windows", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2026-12-27", end: "2027-07-31",
                description: "Contact Period — long winter/spring/summer contact window, interrupted by two short dead-period carve-outs",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-03-12", end: "2027-03-13",
                description: "Dead Period (carve-out; likely NCAA Indoor T&F Championships week)", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-06-09", end: "2027-06-12",
                description: "Dead Period (carve-out; likely NCAA Outdoor T&F Championships week)", confidence: .HIGH),
        ],
        milestones: [],
        source: "\(bucket)/\(season)D1Rec_XCTFRecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - WVB — Division I Women's Volleyball

    private static let wvb = SportCalendar(
        periods: [
            RecruitingPeriod(type: .quiet, start: "2026-08-01", end: "2026-08-31",
                description: "Quiet Period — in-person contact only on campus", confidence: .MEDIUM),
            RecruitingPeriod(type: .contact, start: "2026-09-01", end: "2026-11-30",
                description: "Contact Period — off-campus in-person contact/evaluation permitted", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — no contact/evaluation/visits, nested inside the Sep–Nov contact window", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-12-01", end: "2027-01-14",
                description: "Quiet Period — AVCA awards-banquet incidental contact with honorees is permitted (no recruiting conversation)",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2026-12-17", end: "2027-01-01",
                description: "Dead Period — Thursday of the NCAA D1 WVB Championship through the Sunday immediately following; 1-day/1-event evaluation exception within 30-mile radius of championship site",
                confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2027-01-15", end: "2027-07-31",
                description: "Contact Period — off-campus in-person contact/evaluation permitted, minus 6 quiet-period carve-outs", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2027-03-01", end: "2027-03-04",
                description: "Quiet Period (carve-out within the Jan–Jul contact window)", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2027-03-08", end: "2027-03-11", description: "Quiet Period (carve-out)", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2027-03-15", end: "2027-03-18", description: "Quiet Period (carve-out)", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2027-03-22", end: "2027-03-25", description: "Quiet Period (carve-out)", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2027-03-29", end: "2027-04-01", description: "Quiet Period (carve-out)", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2027-04-05", end: "2027-04-08", description: "Quiet Period (carve-out)", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2027-05-01", end: "2027-06-03",
                description: "Quiet Period (carve-out; final one of the year)", confidence: .MEDIUM),
        ],
        milestones: [],
        source: "\(bucket)/\(season)D1Rec_WVBRecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - MGO — Division I Men's Golf

    private static let mgo = SportCalendar(
        periods: [
            RecruitingPeriod(type: .contact, start: "2026-08-01", end: "2026-11-25", description: "Contact Period", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period nested inside the Aug–Nov contact window", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-26", end: "2026-11-29",
                description: "Dead Period — Thanksgiving week", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-11-30", end: "2026-12-22",
                description: "Quiet Period except for Dec 8–10 (dead-period carve-out); the Dec 8–10 dead period remains in effect until 12:01 AM on December 11",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2026-12-08", end: "2026-12-10",
                description: "Dead Period carve-out inside the Nov 30–Dec 22 quiet window, for the Golf Coaches Association of America (GCAA) National Convention; legally extends until 12:01 AM Dec 11; showcase/combine evaluation events tied to the convention may still be worked",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-12-23", end: "2027-01-01",
                description: "Dead Period — Christmas/New Year window", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2027-01-02", end: "2027-07-31",
                description: "Contact Period — remainder of the year, uninterrupted", confidence: .MEDIUM),
        ],
        milestones: [],
        source: "\(bucket)/\(season)D1Rec_MGORecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - MLA — Division I Men's Lacrosse

    private static let mla = SportCalendar(
        periods: [
            RecruitingPeriod(type: .contact, start: "2026-08-01", end: "2026-08-03", description: "Contact Period", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2026-08-04", end: "2026-08-10", description: "Quiet Period", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2026-08-11", end: "2026-08-31", description: "Dead Period", confidence: .MEDIUM),
            RecruitingPeriod(type: .contact, start: "2026-09-01", end: "2026-10-31",
                description: "Contact Period — footnoted \"No lacrosse evaluations\" for the entire month range", confidence: .MEDIUM),
            RecruitingPeriod(type: .contact, start: "2026-11-01", end: "2026-11-22",
                description: "Contact Period — footnoted \"No lacrosse evaluations\" (continues Sep/Oct's carve-out), minus the Nov 9–12 dead-period carve-out",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period nested inside the Nov 1–22 contact window", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-23", end: "2026-11-29", description: "Dead Period — Thanksgiving week", confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-11-30", end: "2026-12-23",
                description: "Quiet Period, minus the Dec 9–13 dead-period carve-out", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2026-12-09", end: "2026-12-13",
                description: "Dead Period — the first official day of the IMLCA Convention to 12:01 AM on the day after the adjournment of the convention; a coach may still evaluate at the convention's showcase/tournament events",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-12-24", end: "2027-01-03",
                description: "Dead Period — Christmas/New Year window", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2027-01-04", end: "2027-01-18",
                description: "Contact Period — footnoted \"No lacrosse evaluations\"", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2027-01-19", end: "2027-02-28", description: "Quiet Period", confidence: .MEDIUM),
            RecruitingPeriod(type: .contact, start: "2027-03-01", end: "2027-05-27",
                description: "Contact Period (no evaluation-blocking footnote — full evaluation allowed, unlike the fall/Jan contact windows)",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2027-05-28", end: "2027-06-01",
                description: "Dead Period — \"MAY 28 – JUN 1 @ NOON\" (effective noon)", confidence: .MEDIUM),
            RecruitingPeriod(type: .contact, start: "2027-06-01", end: "2027-07-31",
                description: "Contact Period — \"JUN 1 @ NOON – JUL 31\" (effective noon), minus the Jul 1–10 dead-period carve-out", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2027-07-01", end: "2027-07-10",
                description: "Dead Period — a coach may evaluate at the showcase/tournament events held alongside the IMLCA July summer meeting",
                confidence: .MEDIUM),
        ],
        milestones: [],
        source: "\(bucket)/\(season)D1Rec_MLARecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - WLA — Division I Women's Lacrosse

    private static let wla = SportCalendar(
        periods: [
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-08-01", end: "2026-08-14",
                description: "Recruiting Shutdown — no contacts, evaluations, visits, correspondence, or calls permitted", confidence: .MEDIUM),
            RecruitingPeriod(type: .quiet, start: "2026-08-15", end: "2026-08-27", description: "Quiet Period", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2026-08-28", end: "2026-09-03", description: "Dead Period", confidence: .MEDIUM),
            RecruitingPeriod(type: .contact, start: "2026-09-04", end: "2026-11-30",
                description: "Contact Period — subject to Bylaw 13.1.7.3.1 (evaluations during contact periods limited to regularly scheduled HS/prep/2-yr-college contests and regular scholastic activities), minus 3 carve-outs",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .evaluation, start: "2026-11-06", end: "2026-11-08",
                description: "Evaluation Period — first of three pre-Thanksgiving weekends, 5 PM Friday – Sunday", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period nested between the first and second pre-Thanksgiving evaluation weekends", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2026-11-13", end: "2026-11-15",
                description: "Evaluation Period — second pre-Thanksgiving weekend, 5 PM Friday – Sunday", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-18", end: "2026-11-20",
                description: "Dead Period — ends on the 20th when IWLCA Convention adjourns", confidence: .HIGH),
            RecruitingPeriod(type: .evaluation, start: "2026-11-20", end: "2026-11-22",
                description: "Evaluation Period — third pre-Thanksgiving weekend; a coach may evaluate ONLY at showcase/tournament events held with the IWLCA (narrower than the first two weekends)",
                confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-11-24", end: "2026-11-29",
                description: "Recruiting Shutdown — Thanksgiving week", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2026-12-01", end: "2026-12-30",
                description: "Contact Period — subject to Bylaw 13.1.7.3.1, minus the Dec 22–26 shutdown carve-out", confidence: .MEDIUM),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-12-22", end: "2026-12-26",
                description: "Recruiting Shutdown — Christmas window, nested inside the Dec 1–30 contact period", confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-12-31", end: "2027-01-02",
                description: "Recruiting Shutdown — New Year window", confidence: .HIGH),
            RecruitingPeriod(type: .contact, start: "2027-01-03", end: "2027-05-27",
                description: "Contact Period — subject to Bylaw 13.1.7.3.1", confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2027-05-28", end: "2027-05-30", description: "Dead Period", confidence: .MEDIUM),
            RecruitingPeriod(type: .contact, start: "2027-05-31", end: "2027-06-10",
                description: "Contact Period — subject to Bylaw 13.1.7.3.1", confidence: .MEDIUM),
            RecruitingPeriod(type: .evaluation, start: "2027-06-11", end: "2027-07-31",
                description: "Evaluation Period, minus the Jul 2–6 dead-period carve-out; includes an exception allowing one championship-weekend evaluation event within a 100-mile radius of the WLA championship site (with a no-attendance blackout window around the semifinal/final games)",
                confidence: .MEDIUM),
            RecruitingPeriod(type: .dead, start: "2027-07-02", end: "2027-07-06",
                description: "Dead Period carve-out inside the Jun 11–Jul 31 evaluation window", confidence: .MEDIUM),
        ],
        milestones: [],
        source: "\(bucket)/\(season)D1Rec_WLARecruitingCalendar.pdf",
        verifiedOn: verifiedOn
    )

    // MARK: - OTHER_SOURCE — shared source PDF for the generic OTHER default and every OTHER_* sub-calendar

    private static let otherSource = "\(bucket)/\(otherSeasonEnDash)D1Rec_OtherRecruitingCalendar.pdf"

    // MARK: - Other — Division I "All Other Sports" generic default

    private static let other = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — Monday through Thursday of the initial week for the fall signing date for athletics aid agreements",
                confidence: .HIGH),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    // MARK: - OTHER_* — per-sport sub-calendars enumerated within the D1 "Other" bundle PDF

    private static let otherMSoccer = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — Monday through Thursday of the initial week for the fall signing date for athletics aid agreements",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-12-11", end: "2026-12-14",
                description: "Dead Period — Friday through Monday of the NCAA Division I Men's Soccer Championship. A coaching staff member may attend an event conducted in conjunction with and in the host city of the championship.",
                confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2026-12-23", end: "2026-12-25",
                description: "Quiet Period, Dec 23–25 (label only)", confidence: .HIGH),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    private static let otherWSoccer = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-08-01", end: "2026-08-11",
                description: "Dead Period, Aug 1–11 (label only)", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — Monday through Thursday of the initial week for the fall signing date for athletics aid agreements",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-12-16", end: "2027-01-06",
                description: "Dead Period, Dec 16–Jan 6, 2027 (label only)", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-07-28", end: "2027-07-31",
                description: "For four-year prospective student-athletes, three (3) consecutive weeks starting 21 days following the final date to provide notification of transfer",
                confidence: .MEDIUM),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    private static let otherSwim = SportCalendar(
        periods: [
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-08-17", end: "2026-08-23",
                description: "Recruiting Shutdown — the third Monday in August through the following Sunday", confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — Monday through Thursday of the initial week for the fall signing date for athletics aid agreements",
                confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-12-18", end: "2027-01-07",
                description: "Recruiting Shutdown, Dec 18–Jan 7, 2027 (label only)", confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2027-02-07", end: "2027-02-20",
                description: "Recruiting Shutdown — 14 consecutive days beginning with the Sunday that is 38 days before the first day of the NCAA Division I Women's Swimming Championship",
                confidence: .HIGH),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    private static let otherMIceHockey = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — Monday through Thursday of the initial week for the fall signing date for athletics aid agreements",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-04-07", end: "2027-04-11",
                description: "Dead Period — Wednesday before the NCAA Division I Men's Ice Hockey Championship to the Sunday after the championship game (effective noon)",
                confidence: .HIGH),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    private static let otherWIceHockey = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — Monday through Thursday of the initial week for the fall signing date for athletics aid agreements",
                confidence: .HIGH),
            RecruitingPeriod(type: .dead, start: "2027-03-18", end: "2027-03-22",
                description: "Dead Period — the day prior to the National Collegiate Women's Ice Hockey Championship to the day after the game (effective noon)",
                confidence: .HIGH),
            RecruitingPeriod(type: .quiet, start: "2027-04-26", end: "2027-05-31",
                description: "Quiet Period — the Monday prior to the American Hockey Coaches Association Convention through May 31",
                confidence: .HIGH),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    private static let otherRowing = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — Monday through Thursday of the initial week for the fall signing date for athletics aid agreements",
                confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-12-22", end: "2027-01-02",
                description: "Recruiting Shutdown, Dec 22–Jan 2, 2027", confidence: .HIGH),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    private static let otherFieldHockey = SportCalendar(
        periods: [
            RecruitingPeriod(type: .quiet, start: "2026-12-20", end: "2026-12-23",
                description: "Quiet Period (label only; no detail text on source card)", confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-12-24", end: "2027-01-01",
                description: "Recruiting Shutdown (label only; no detail text on source card)", confidence: .HIGH),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    private static let otherMWrestling = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — Monday through Thursday of the initial week for the fall signing date for athletics aid agreements",
                confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2026-12-24", end: "2026-12-26",
                description: "Recruiting Shutdown, Dec 24–26 (label only)", confidence: .HIGH),
            RecruitingPeriod(type: .recruitingShutdown, start: "2027-03-16", end: "2027-03-21",
                description: "Recruiting Shutdown — Tuesday through Sunday of the NCAA Division I Wrestling Championships", confidence: .HIGH),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    private static let otherWWrestling = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-12",
                description: "Dead Period — Monday through Thursday of the initial week for the fall signing date for athletics aid agreements",
                confidence: .HIGH),
            // Fragment dates this 2026 but flags the year as ambiguous ("could be
            // read as generic annual recurrence"); rolled to 2027 for consistency
            // with every other July period in this file (WLA, MLA, OTHER_WSOCCER)
            // and because the 2026-27 season calendar runs Aug 2026 -> Jul 2027.
            RecruitingPeriod(type: .dead, start: "2027-07-26", end: "2027-08-01",
                description: "Dead Period — Monday before the National Wrestling Coaches Association Convention through the day of adjournment of the convention",
                confidence: .MEDIUM),
        ],
        milestones: [],
        source: otherSource,
        verifiedOn: verifiedOn
    )

    static let d1Calendars: [NcaaCalendarKey: SportCalendar] = [
        .MBA: mba, .WSB: wsb, .MBB: mbb, .WBB: wbb, .FBS: fbs, .FCS: fcs, .XCTF: xctf,
        .WVB: wvb, .MGO: mgo, .MLA: mla, .WLA: wla, .other: other,
        .OTHER_MSOCCER: otherMSoccer, .OTHER_WSOCCER: otherWSoccer, .OTHER_SWIM: otherSwim,
        .OTHER_MICEHOCKEY: otherMIceHockey, .OTHER_WICEHOCKEY: otherWIceHockey,
        .OTHER_ROWING: otherRowing, .OTHER_FIELDHOCKEY: otherFieldHockey,
        .OTHER_MWRESTLING: otherMWrestling, .OTHER_WWRESTLING: otherWWrestling,
    ]

    // MARK: - D2 — "All Other Sports" track

    static let d2AllSports = SportCalendar(
        periods: [
            RecruitingPeriod(type: .dead, start: "2026-11-09", end: "2026-11-11",
                description: "Signing Date Dead Period, Nov 9 @ 7 AM – Nov 11 @ 7 AM (effective noon-agnostic, rounded to the day). For all other high school prospective student-athletes",
                confidence: .HIGH),
        ],
        milestones: [],
        source: "\(bucket)/\(season)D2Rec_RecruitingCalendar_AllSports.pdf",
        verifiedOn: verifiedOn
    )

    // D3 has no published NCAA recruiting calendar — fall back to D1's "Other"
    // default track (same source data as d1Calendars[.Other]; documented choice
    // per the plan, since D3 recruiting rules are the least restrictive/most
    // generic of the three divisions and "Other" is this dataset's own generic
    // default).
    static let d3Fallback = other

    // MARK: - Generic (sport-agnostic) milestones

    /// SAT/ACT test dates, NCAA/NAIA eligibility deadlines, and college
    /// application deadlines — Swift mirror of web `utils/ncaaRecruitingCalendar.ts`
    /// (`SAT_TEST_DATES_2026` + `ACT_TEST_DATES_2026` + `NCAA_DEADLINES_2026` +
    /// `NAIA_DEADLINES_2026` + `COLLEGE_APPLICATION_DEADLINES_2026`), merged
    /// sport-agnostically the same way web's `GENERIC_MILESTONES` is merged in
    /// `resolver.ts`'s `getUpcomingMilestones`. Web's `division` field (all
    /// "ALL", "D1", or "NAIA") has no iOS `CalendarMilestone` equivalent and is
    /// dropped — these apply to every sport/division on iOS.
    // swiftlint:disable:next line_length
    static let genericMilestones: [CalendarMilestone] = [
        // SAT_TEST_DATES_2026 (8)
        CalendarMilestone(date: "2026-03-14", title: "SAT Test Date", type: .test,
            url: "https://collegereadiness.collegeboard.org/sat/register/dates-deadlines"),
        CalendarMilestone(date: "2026-05-02", title: "SAT Test Date", type: .test),
        CalendarMilestone(date: "2026-06-06", title: "SAT Test Date", type: .test),
        CalendarMilestone(date: "2026-08-29", title: "SAT Test Date", type: .test),
        CalendarMilestone(date: "2026-10-03", title: "SAT Test Date", type: .test),
        CalendarMilestone(date: "2026-11-07", title: "SAT Test Date", type: .test),
        CalendarMilestone(date: "2027-01-23", title: "SAT Test Date", type: .test),
        CalendarMilestone(date: "2027-03-13", title: "SAT Test Date", type: .test),

        // ACT_TEST_DATES_2026 (7)
        CalendarMilestone(date: "2026-02-07", title: "ACT Test Date", type: .test,
            url: "https://www.act.org/content/act/en/students/register-for-the-act.html"),
        CalendarMilestone(date: "2026-04-11", title: "ACT Test Date", type: .test),
        CalendarMilestone(date: "2026-06-13", title: "ACT Test Date", type: .test),
        CalendarMilestone(date: "2026-07-18", title: "ACT Test Date", type: .test),
        CalendarMilestone(date: "2026-09-12", title: "ACT Test Date", type: .test),
        CalendarMilestone(date: "2026-10-10", title: "ACT Test Date", type: .test),
        CalendarMilestone(date: "2027-02-06", title: "ACT Test Date", type: .test),

        // NCAA_DEADLINES_2026 (1)
        CalendarMilestone(date: "2026-04-01", title: "NCAA Eligibility Center Registration - Juniors", type: .deadline,
            url: "https://www.eligibilitycenter.org/",
            description: "Register with NCAA to begin eligibility evaluation"),

        // NAIA_DEADLINES_2026 (1)
        CalendarMilestone(date: "2026-09-01", title: "NAIA Eligibility Center Registration", type: .deadline,
            url: "https://www.playnaia.org/", description: "Register with NAIA eligibility center"),

        // COLLEGE_APPLICATION_DEADLINES_2026 (6, incl. FAFSA Opens)
        CalendarMilestone(date: "2026-10-01", title: "FAFSA Opens", type: .application,
            url: "https://studentaid.gov/h/apply-for-aid/fafsa",
            description: "Free Application for Federal Student Aid opens for 2027-28 school year"),
        CalendarMilestone(date: "2026-11-01", title: "Early Decision Deadline (Early)", type: .application,
            description: "Most early decision deadlines for senior fall"),
        CalendarMilestone(date: "2026-11-15", title: "Early Action Deadline", type: .application,
            description: "Most early action deadlines"),
        CalendarMilestone(date: "2027-01-01", title: "Regular Decision Deadline (Most Selective)", type: .application,
            description: "Most selective schools' regular decision deadline"),
        CalendarMilestone(date: "2027-01-15", title: "Regular Decision Deadline (Typical)", type: .application,
            description: "Most schools' regular decision deadline"),
        CalendarMilestone(date: "2027-02-01", title: "Regular Decision Deadline (Latest)", type: .application,
            description: "Latest regular decision deadlines for selective schools"),
    ]
}

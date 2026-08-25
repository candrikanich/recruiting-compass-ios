import Foundation

/// NCAA recruiting-calendar key. Each key identifies one NCAA sport calendar
/// (contact-period rules differ per sport/gender/subdivision). `.Other` covers
/// app sports that have no published NCAA recruiting calendar. Swift mirror of
/// web `utils/recruitingCalendar/types.ts` `NcaaCalendarKey` — byte-identical
/// 22-key set.
enum NcaaCalendarKey: String, CaseIterable {
    case MBA, WSB, MBB, WBB, FBS, FCS, XCTF, WVB, MGO, MLA, WLA
    case other = "Other"
    case OTHER_MSOCCER, OTHER_WSOCCER, OTHER_SWIM, OTHER_MICEHOCKEY, OTHER_WICEHOCKEY
    case OTHER_ROWING, OTHER_FIELDHOCKEY, OTHER_MWRESTLING, OTHER_WWRESTLING
    case otherWGYM = "OTHER_WGYM"
}

/// One NCAA recruiting-period window. 5-type taxonomy (spike finding): baseball
/// uses `recruitingShutdown` (stricter than `dead` — no calls/texts/
/// correspondence at all) and has no `evaluation`; basketball/football use
/// `evaluation`. Each sport's calendar uses only its real subset.
/// `description` preserves the source legend's exact term.
enum PeriodType: String {
    case dead, quiet, contact, evaluation
    case recruitingShutdown = "recruiting_shutdown"
}

enum PeriodConfidence: String {
    case HIGH, MEDIUM, LOW
}

struct RecruitingPeriod {
    let type: PeriodType
    let start: String // ISO date "YYYY-MM-DD"
    let end: String // ISO date "YYYY-MM-DD"
    let description: String
    let confidence: PeriodConfidence
}

enum MilestoneType: String {
    case test, deadline
    case ncaaPeriod = "ncaa-period"
    case application, signing
}

/// Signing dates, test dates, application/eligibility deadlines.
struct CalendarMilestone {
    let date: String // ISO date "YYYY-MM-DD"
    let title: String
    let type: MilestoneType
    let url: String?
    let description: String?
    /// Division this milestone applies to, or `nil` for "applies to every division"
    /// (web's `"ALL"`/unscoped). Sport-calendar milestones are always division-scoped
    /// by calendar selection already, so they leave this `nil`. Swift mirror of web
    /// `Milestone.division` ("ALL" | "D1" | "D2" | "D3" | "NAIA").
    let division: String?

    init(
        date: String, title: String, type: MilestoneType, url: String? = nil,
        description: String? = nil, division: String? = nil
    ) {
        self.date = date
        self.title = title
        self.type = type
        self.url = url
        self.description = description
        self.division = division
    }
}

/// One NCAA calendar key's full period + milestone set, with its citation.
struct SportCalendar {
    let periods: [RecruitingPeriod]
    let milestones: [CalendarMilestone]
    let source: String // exact NCAA PDF URL this calendar was transcribed from (Layer 1)
    let verifiedOn: String // ISO date a human last verified against the source (Layer 1 CI guard)
}

/// Sport-aware NCAA recruiting-calendar registry + resolver. Swift mirror of
/// web `utils/recruitingCalendar/{calendarData,resolver}.ts` — byte-identical
/// 21 calendars, resolver semantics, and query functions. Registry pattern
/// mirrors `CanonicalPositions`/`MetricRegistry`: enum namespace + static data
/// + thin static query functions.
enum RecruitingCalendar {
    /// Sports with a single NCAA recruiting calendar (no gender split).
    /// Includes three "Other"-bundle sports whose PDF enumerates real
    /// dead/quiet/recruiting_shutdown windows with no men's/women's split:
    /// Swimming (combined "Swimming and Diving" table) and the two NCAA
    /// women's-only sports Rowing and Field Hockey.
    private static let singleCalendarSports: [String: NcaaCalendarKey] = [
        "Baseball": .MBA,
        "Softball": .WSB,
        "Volleyball": .WVB,
        "Track & Field": .XCTF,
        "Cross Country": .XCTF,
        "Swimming": .OTHER_SWIM,
        "Rowing": .OTHER_ROWING,
        "Field Hockey": .OTHER_FIELDHOCKEY,
    ]

    /// Sports with distinct men's/women's NCAA calendars. Soccer, Ice Hockey,
    /// and Wrestling are "Other"-bundle sports whose PDF enumerates separate
    /// men's/women's windows.
    static let genderSplitSports: [String: (men: NcaaCalendarKey, women: NcaaCalendarKey)] = [
        "Basketball": (.MBB, .WBB),
        "Lacrosse": (.MLA, .WLA),
        "Soccer": (.OTHER_MSOCCER, .OTHER_WSOCCER),
        "Ice Hockey": (.OTHER_MICEHOCKEY, .OTHER_WICEHOCKEY),
        "Wrestling": (.OTHER_MWRESTLING, .OTHER_WWRESTLING),
        // Only women's gymnastics has a distinct table in the "Other" bundle PDF;
        // men's gymnastics is folded into the generic "All Other Sports" default.
        "Gymnastics": (men: .other, women: .otherWGYM),
    ]

    /// The codebase's neutral sport fallback for any caller not yet wired to
    /// pass the athlete's real sport. "Tennis" has no published NCAA
    /// recruiting calendar of its own, so it resolves to the generic
    /// ``NcaaCalendarKey/Other`` track — the least-restrictive, lowest-surprise
    /// default (matches the D2/D3 fallback calendars' own choice).
    static let noSportFallback = "Tennis"

    private static func isMen(_ gender: String?) -> Bool {
        (gender ?? "").lowercased() != "female"
    }

    /// Maps an app sport (plus optional gender/football-subdivision context)
    /// to the NCAA recruiting-calendar key that governs its contact-period
    /// rules. Gender defaults to men's whenever the sport is gender-split and
    /// gender is nil/unspecified. No baseball fallback — unknown/nil sport
    /// resolves to `.Other`.
    static func resolveKey(
        sport: String?,
        gender: String? = nil,
        footballSubdivision: String? = nil
    ) -> NcaaCalendarKey {
        guard let sport else { return .other }

        if sport == "Football" {
            if footballSubdivision == "FCS" { return .FCS }
            return .FBS
        }

        if sport == "Golf" {
            return isMen(gender) ? .MGO : .other
        }

        if let split = genderSplitSports[sport] {
            return isMen(gender) ? split.men : split.women
        }

        if let single = singleCalendarSports[sport] {
            return single
        }

        // Any remaining sport (currently: Tennis, Water Polo, Beach Volleyball,
        // and anything unrecognized) has no published NCAA recruiting calendar
        // and no sport-specific windows in the "Other" bundle — falls to the
        // generic Other default.
        return .other
    }

    static func calendarFor(key: NcaaCalendarKey) -> SportCalendar {
        RecruitingCalendarData.d1Calendars[key]!
    }

    /// Resolves the `SportCalendar` that governs a sport's recruiting rules
    /// for a division. D2 and D3 use one shared calendar regardless of sport
    /// (per the NCAA's own "All Other Sports" tracks); D1 resolves per-sport
    /// via `resolveKey`.
    static func calendar(
        sport: String?,
        division: String,
        gender: String? = nil,
        footballSubdivision: String? = nil
    ) -> SportCalendar {
        if division == "D2" { return RecruitingCalendarData.d2AllSports }
        if division == "D3" { return RecruitingCalendarData.d3Fallback }

        let key = resolveKey(sport: sport, gender: gender, footballSubdivision: footballSubdivision)
        return calendarFor(key: key)
    }

    /// `dead` and `recruiting_shutdown` periods both mean "no contact
    /// permitted" (recruiting_shutdown is the stricter of the two — no
    /// calls/texts/correspondence either — but both block contact, which is
    /// what `isDeadPeriod` answers).
    private static let blockingTypes: Set<PeriodType> = [.dead, .recruitingShutdown]

    private static func isWithin(_ dateISO: String, _ period: RecruitingPeriod) -> Bool {
        dateISO >= period.start && dateISO <= period.end
    }

    /// True if `dateISO` falls within a dead (or recruiting-shutdown) period
    /// for `sport`/`division`.
    static func isDeadPeriod(
        _ dateISO: String,
        sport: String?,
        division: String,
        gender: String? = nil,
        footballSubdivision: String? = nil
    ) -> Bool {
        let cal = calendar(sport: sport, division: division, gender: gender, footballSubdivision: footballSubdivision)
        return cal.periods.contains { blockingTypes.contains($0.type) && isWithin(dateISO, $0) }
    }

    /// True if `dateISO` falls within a quiet period for `sport`/`division`.
    static func isQuietPeriod(
        _ dateISO: String,
        sport: String?,
        division: String,
        gender: String? = nil,
        footballSubdivision: String? = nil
    ) -> Bool {
        let cal = calendar(sport: sport, division: division, gender: gender, footballSubdivision: footballSubdivision)
        return cal.periods.contains { $0.type == .quiet && isWithin(dateISO, $0) }
    }

    /// Message describing the dead/shutdown period `dateISO` falls within, or
    /// `nil` if `dateISO` is not in one.
    static func deadPeriodMessage(
        _ dateISO: String,
        sport: String?,
        division: String,
        gender: String? = nil,
        footballSubdivision: String? = nil
    ) -> String? {
        let cal = calendar(sport: sport, division: division, gender: gender, footballSubdivision: footballSubdivision)
        guard let period = cal.periods.first(where: { blockingTypes.contains($0.type) && isWithin(dateISO, $0) }) else {
            return nil
        }
        return "Dead period - no recruiting contact permitted per NCAA rules (\(period.description))"
    }

    /// The next dead/recruiting-shutdown period starting on or after
    /// `dateISO`, or `nil` if none remain.
    static func nextDeadPeriod(
        _ dateISO: String,
        sport: String?,
        division: String,
        gender: String? = nil,
        footballSubdivision: String? = nil
    ) -> RecruitingPeriod? {
        let cal = calendar(sport: sport, division: division, gender: gender, footballSubdivision: footballSubdivision)
        return cal.periods
            .filter { blockingTypes.contains($0.type) && $0.start >= dateISO }
            .sorted { $0.start < $1.start }
            .first
    }

    /// Same division-scoping web's `matchesDivision` uses: unscoped/"ALL" always
    /// matches; otherwise the milestone's `division` must equal the athlete's.
    private static func matchesDivision(_ milestone: CalendarMilestone, _ division: String) -> Bool {
        milestone.division == nil || milestone.division == division || milestone.division == "ALL"
    }

    /// Upcoming milestones for `sport`/`division`, filtered by future date
    /// (`>= dateISO`) and by `graduationYear`'s grad-year bucket (when provided —
    /// see ``milestoneTypes(forGraduationYear:currentYear:)``), sorted ascending.
    /// Generic milestones (SAT/ACT/FAFSA/application) are capped at `limit`
    /// (default 5); sport-calendar milestones always surface, so an athlete's
    /// signing / NCAA-period dates aren't starved out by nearer generic dates.
    static func upcomingMilestones(
        _ dateISO: String,
        sport: String?,
        division: String,
        gender: String? = nil,
        footballSubdivision: String? = nil,
        graduationYear: Int? = nil,
        limit: Int = 5
    ) -> [CalendarMilestone] {
        let cal = calendar(sport: sport, division: division, gender: gender, footballSubdivision: footballSubdivision)
        let genericForDivision = RecruitingCalendarData.genericMilestones.filter { matchesDivision($0, division) }

        let allowedTypes: Set<MilestoneType>? = {
            guard let graduationYear, let currentYear = Int(dateISO.prefix(4)) else { return nil }
            return milestoneTypes(forGraduationYear: graduationYear, currentYear: currentYear)
        }()

        func passes(_ milestone: CalendarMilestone) -> Bool {
            guard milestone.date >= dateISO else { return false }
            if let allowedTypes { return allowedTypes.contains(milestone.type) }
            return true
        }

        // Generic milestones (SAT/ACT/FAFSA/application) are capped at `limit`;
        // sport-calendar milestones always surface so an athlete's signing / NCAA-period
        // dates aren't starved out by nearer generic dates.
        let cappedGeneric = genericForDivision.filter(passes).sorted { $0.date < $1.date }.prefix(limit)
        let sportMilestones = cal.milestones.filter(passes)

        // Dedup coincident entries (date+title) so a sport milestone that happens to
        // match a generic one on the same day can't double. Generics come first, so
        // they win the tie. Mirrors the web resolver's dedup key.
        var seen = Set<String>()
        return (Array(cappedGeneric) + sportMilestones)
            .filter { seen.insert("\($0.date)|\($0.title)").inserted }
            .sorted { $0.date < $1.date }
    }

    /// Grad-year milestone bucket rule. Swift mirror of web
    /// `resolver.ts`'s `getUpcomingMilestones` phase buckets — byte-identical
    /// cutoffs: senior year (`graduationYear == currentYear + 3`) sees
    /// test/application/signing/ncaa-period milestones; junior year
    /// (`currentYear + 2`) sees test/deadline/ncaa-period/application; any
    /// other grad year (freshman/sophomore, or anything outside those two
    /// windows) sees only test/ncaa-period — signing dates are withheld from
    /// underclassmen.
    static func milestoneTypes(forGraduationYear graduationYear: Int, currentYear: Int) -> Set<MilestoneType> {
        if graduationYear == currentYear + 3 {
            return [.test, .application, .signing, .ncaaPeriod]
        } else if graduationYear == currentYear + 2 {
            return [.test, .deadline, .ncaaPeriod, .application]
        } else {
            return [.test, .ncaaPeriod]
        }
    }
}

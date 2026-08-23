import Foundation

/// NCAA recruiting-calendar key. Each key identifies one NCAA sport calendar
/// (contact-period rules differ per sport/gender/subdivision). `.Other` covers
/// app sports that have no published NCAA recruiting calendar. Swift mirror of
/// web `utils/recruitingCalendar/types.ts` `NcaaCalendarKey` — byte-identical
/// 21-key set.
enum NcaaCalendarKey: String, CaseIterable {
    case MBA, WSB, MBB, WBB, FBS, FCS, XCTF, WVB, MGO, MLA, WLA, Other
    case OTHER_MSOCCER, OTHER_WSOCCER, OTHER_SWIM, OTHER_MICEHOCKEY, OTHER_WICEHOCKEY
    case OTHER_ROWING, OTHER_FIELDHOCKEY, OTHER_MWRESTLING, OTHER_WWRESTLING
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

    init(date: String, title: String, type: MilestoneType, url: String? = nil, description: String? = nil) {
        self.date = date
        self.title = title
        self.type = type
        self.url = url
        self.description = description
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
        guard let sport else { return .Other }

        if sport == "Football" {
            if footballSubdivision == "FCS" { return .FCS }
            return .FBS
        }

        if sport == "Golf" {
            return isMen(gender) ? .MGO : .Other
        }

        if let split = genderSplitSports[sport] {
            return isMen(gender) ? split.men : split.women
        }

        if let single = singleCalendarSports[sport] {
            return single
        }

        // Any remaining sport (currently: Tennis, Water Polo, and anything
        // unrecognized) has no published NCAA recruiting calendar and no
        // sport-specific windows in the "Other" bundle — falls to the
        // generic Other default.
        return .Other
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

    /// Upcoming milestones for `sport`/`division` from the resolved
    /// `SportCalendar`'s own milestone list, filtered by future date
    /// (`>= dateISO`), by `graduationYear`'s grad-year bucket (when provided —
    /// see ``milestoneTypes(forGraduationYear:currentYear:)``), sorted
    /// ascending, and capped at `limit` (default 5).
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
        var combined = cal.milestones.filter { $0.date >= dateISO }

        if let graduationYear, let currentYear = Int(dateISO.prefix(4)) {
            let allowedTypes = milestoneTypes(forGraduationYear: graduationYear, currentYear: currentYear)
            combined = combined.filter { allowedTypes.contains($0.type) }
        }

        return combined
            .sorted { $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
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

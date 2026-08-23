import Foundation

/// Builders for external recruiting-database profile links.
///
/// Prep Baseball Report profile URLs are slug-based, not ID-based:
///   https://www.prepbaseballreport.com/profiles/{STATE}/{name-slug}
/// e.g. https://www.prepbaseballreport.com/profiles/OH/owen-andrikanich
///
/// Swift mirror of web `utils/recruitingLinks.ts` — the SAME state table and the
/// SAME slugify rules, so both platforms emit BYTE-IDENTICAL URLs. See
/// `planning/2026-08-22-phase3-registry-contract.md`, "PBR link addendum".
enum RecruitingLinks {
    private static let prepBaseballBase = "https://www.prepbaseballreport.com/profiles"

    /// name -> 2-letter code, plus every code mapped to itself for pass-through.
    static let stateNameToCode: [String: String] = [
        "alabama": "AL",
        "alaska": "AK",
        "arizona": "AZ",
        "arkansas": "AR",
        "california": "CA",
        "colorado": "CO",
        "connecticut": "CT",
        "delaware": "DE",
        "district of columbia": "DC",
        "florida": "FL",
        "georgia": "GA",
        "hawaii": "HI",
        "idaho": "ID",
        "illinois": "IL",
        "indiana": "IN",
        "iowa": "IA",
        "kansas": "KS",
        "kentucky": "KY",
        "louisiana": "LA",
        "maine": "ME",
        "maryland": "MD",
        "massachusetts": "MA",
        "michigan": "MI",
        "minnesota": "MN",
        "mississippi": "MS",
        "missouri": "MO",
        "montana": "MT",
        "nebraska": "NE",
        "nevada": "NV",
        "new hampshire": "NH",
        "new jersey": "NJ",
        "new mexico": "NM",
        "new york": "NY",
        "north carolina": "NC",
        "north dakota": "ND",
        "ohio": "OH",
        "oklahoma": "OK",
        "oregon": "OR",
        "pennsylvania": "PA",
        "rhode island": "RI",
        "south carolina": "SC",
        "south dakota": "SD",
        "tennessee": "TN",
        "texas": "TX",
        "utah": "UT",
        "vermont": "VT",
        "virginia": "VA",
        "washington": "WA",
        "west virginia": "WV",
        "wisconsin": "WI",
        "wyoming": "WY"
    ]

    /// Valid 2-letter USPS codes (the values of `stateNameToCode`).
    static let stateCodes: Set<String> = Set(stateNameToCode.values)

    /// Kebab-case a player name for use as a PBR profile slug. Mirrors web:
    /// lowercase; drop `['".]`; any run of other non-alphanumerics -> single `-`;
    /// trim leading/trailing `-`.
    static func slugifyPlayerName(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "" }
        // drop apostrophes/quotes/periods entirely (O'Brien -> obrien)
        let dropped = name.lowercased().filter { $0 != "'" && $0 != "\"" && $0 != "." }
        var slug = ""
        var lastWasDash = false
        for ch in dropped {
            if ("a"..."z").contains(ch) || ("0"..."9").contains(ch) {
                slug.append(ch)
                lastWasDash = false
            } else if !lastWasDash {
                slug.append("-")
                lastWasDash = true
            }
        }
        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Normalize a state name or code to a valid 2-letter USPS code, or nil.
    static func normalizeStateCode(_ input: String?) -> String? {
        guard let input else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let upper = trimmed.uppercased()
        if stateCodes.contains(upper) { return upper }
        return stateNameToCode[trimmed.lowercased()]
    }

    /// Build a Prep Baseball Report profile URL from a state and player name.
    /// Returns nil unless both a valid state and a non-empty slug are present.
    static func buildPrepBaseballURL(state: String?, name: String?) -> String? {
        guard let code = normalizeStateCode(state) else { return nil }
        let slug = slugifyPlayerName(name)
        if slug.isEmpty { return nil }
        return "\(prepBaseballBase)/\(code)/\(slug)"
    }
}

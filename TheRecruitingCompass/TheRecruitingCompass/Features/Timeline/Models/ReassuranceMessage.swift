import Foundation

/// "What NOT to Stress About" reassurance messages, keyed by recruiting phase.
/// Ported verbatim from `recruiting-compass-web/utils/parentReassurance.ts` — do not
/// paraphrase strings; edit the web source first and re-port to keep parity.
struct ReassuranceMessage: Identifiable {
    let id: String
    let title: String
    let message: String
    let phases: [TimelinePhase]
    let icon: String

    // swiftlint:disable line_length
    static let all: [ReassuranceMessage] = [
        ReassuranceMessage(
            id: "freshman-foundation",
            title: String(localized: "Freshman Year is About Foundation"),
            message: String(localized: "Your athlete doesn't need scholarship offers in 9th grade. This is the time to develop skills, build confidence, and enjoy the game. Recruiting will catch up naturally."),
            phases: [.freshman],
            icon: "🏗️"
        ),
        ReassuranceMessage(
            id: "sophomore-normal-timeline",
            title: String(localized: "Normal Recruiting Timing"),
            message: String(localized: "Most athletes see serious recruiting activity start in junior year. If your athlete hasn't heard from coaches yet, they're right on schedule. This is completely normal."),
            phases: [.sophomore],
            icon: "📅"
        ),
        ReassuranceMessage(
            id: "junior-late-bloomers",
            title: String(localized: "Late Bloomers Are Very Common"),
            message: String(localized: "Athletes develop at different rates. Many elite players weren't heavily recruited until late junior or even senior year. Your athlete still has plenty of time."),
            phases: [.junior],
            icon: "🌱"
        ),
        ReassuranceMessage(
            id: "junior-silence-ok",
            title: String(localized: "Silence From Coaches is Normal"),
            message: String(localized: "Coaches evaluate during specific periods and manage many recruits. A quiet month doesn't mean lack of interest. Stay engaged and keep communicating."),
            phases: [.junior],
            icon: "🤐"
        ),
        ReassuranceMessage(
            id: "senior-late-offers",
            title: String(localized: "Many Offers Come Senior Year"),
            message: String(localized: "Senior year offers are common. Some programs actively recruit into the spring. If your athlete hasn't committed yet, opportunities still exist at all levels."),
            phases: [.senior],
            icon: "✉️"
        ),
        ReassuranceMessage(
            id: "senior-walkon-path",
            title: String(localized: "Walk-On is a Legitimate Path"),
            message: String(localized: "Walk-ons become key contributors and future pros. It's a valid way to play in college, even at top programs. Don't view it as a fallback."),
            phases: [.senior],
            icon: "🚪"
        ),
        ReassuranceMessage(
            id: "all-social-media-lie",
            title: String(localized: "Social Media Isn't the Full Picture"),
            message: String(localized: "Recruiting highlight reels show the exceptions, not the norm. Most athletes have quiet recruiting processes. Your athlete's journey is unique and valid."),
            phases: [.freshman, .sophomore, .junior, .senior],
            icon: "📱"
        ),
        ReassuranceMessage(
            id: "all-divisions-excellent",
            title: String(localized: "All Divisions Are Excellent Options"),
            message: String(localized: "D1, D2, D3, NAIA, and JUCO all offer great opportunities. Fit matters more than prestige. A smaller program with better academics might be perfect for your athlete."),
            phases: [.freshman, .sophomore, .junior, .senior],
            icon: "🎓"
        )
    ]
    // swiftlint:enable line_length

    static func forPhase(_ phase: TimelinePhase) -> [ReassuranceMessage] {
        let target: TimelinePhase = (phase == .committed) ? .senior : phase
        return all.filter { $0.phases.contains(target) }
    }
}

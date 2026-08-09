import Foundation

/// Static "Learn More" help copy for a suggestion, keyed by rule type.
/// Ported from web `components/Suggestion/SuggestionHelpModal.vue` helpContentMap.
struct SuggestionHelpContent {
  let title: String
  let whyItMatters: String
  let howToComplete: [String]
  let coachesExpect: [String]
  let timeline: String

  static func content(for ruleType: String) -> SuggestionHelpContent {
    map[ruleType] ?? fallback
  }

  private static let fallback = SuggestionHelpContent(
    title: String(localized: "Learn More"),
    whyItMatters: String(localized: "This action is important for your recruiting success. Follow the steps below to make progress."),
    howToComplete: [String(localized: "Focus on the suggested action above.")],
    coachesExpect: [String(localized: "Demonstrated effort and commitment to recruiting.")],
    timeline: String(localized: "Start as soon as possible.")
  )

  private static let map: [String: SuggestionHelpContent] = [
    "school-list-building": SuggestionHelpContent(
      title: String(localized: "Build Your Target School List"),
      whyItMatters: String(localized: "A comprehensive list of 20-30 target schools ensures you have options and reduces the risk of being left without a scholarship. Coaches also notice when athletes have done their research and have a genuine interest in their program."),
      howToComplete: [
        String(localized: "Research Division I, II, and III programs that fit your athletic and academic profile"),
        String(localized: "Use academic SAT/ACT standards and athletic rankings as filters"),
        String(localized: "Consider location, team culture, coaching style, and academics"),
        String(localized: "Aim for a balanced list: 5-7 reach schools, 10-15 match schools, 5-8 safety schools"),
        String(localized: "Add each school to your list in the app with priority ratings")
      ],
      coachesExpect: [
        String(localized: "Evidence that you've researched their program specifically (mention details in emails)"),
        String(localized: "A list that shows self-awareness about academic and athletic fit"),
        String(localized: "Regular updates as you narrow your choices")
      ],
      timeline: String(localized: "Complete by end of sophomore year. Refine throughout junior year.")
    ),
    "showcase-attendance": SuggestionHelpContent(
      title: String(localized: "Attend Summer Showcases"),
      whyItMatters: String(localized: "Showcases are primary recruiting events where coaches evaluate players in person. Attending 2-3 quality showcases per summer significantly increases your exposure and gives coaches the chance to see you play against top competition."),
      howToComplete: [
        String(localized: "Research showcase dates and locations for summer (April-August)"),
        String(localized: "Prioritize showcases where your target schools have coaches attending"),
        String(localized: "Register and pay fees early for better placement"),
        String(localized: "Perform well and log the event in your recruiting timeline"),
        String(localized: "Follow up with any coaches you connected with at the showcase")
      ],
      coachesExpect: [
        String(localized: "Attendance at 2-3 quality showcases per summer minimum"),
        String(localized: "Strong performance against elite competition"),
        String(localized: "Follow-up communication after the showcase")
      ],
      timeline: String(localized: "Plan and attend during summer between sophomore and junior year.")
    ),
    "ncaa-registration": SuggestionHelpContent(
      title: String(localized: "Register with NCAA Eligibility Center"),
      whyItMatters: String(localized: "NCAA registration is mandatory for Division I and II recruiting. It establishes your official academic transcript with the NCAA and confirms your eligibility. Without it, schools cannot proceed with recruiting or financial aid."),
      howToComplete: [
        String(localized: "Visit the NCAA Eligibility Center website (ncaa.org/eligibility-center)"),
        String(localized: "Create your account and register as a student-athlete"),
        String(localized: "Request your high school transcript be sent directly to the NCAA"),
        String(localized: "Report your SAT/ACT scores (they'll also receive official scores)"),
        String(localized: "Keep your registration active and updated throughout junior and senior year")
      ],
      coachesExpect: [
        String(localized: "Registration completed by junior year (ideally early)"),
        String(localized: "Official transcripts on file with the NCAA"),
        String(localized: "Test scores submitted before scholarship offers")
      ],
      timeline: String(localized: "Register during junior year. Begin process early to avoid delays.")
    ),
    "formal-outreach": SuggestionHelpContent(
      title: String(localized: "Begin Formal Coach Outreach"),
      whyItMatters: String(localized: "Coaches expect consistent communication from interested athletes. Monthly touchpoints keep you on their radar and demonstrate genuine interest. The more they hear from you, the more likely they'll remain engaged in recruiting you."),
      howToComplete: [
        String(localized: "Identify 10-15 priority schools (A and B tier)"),
        String(localized: "Write a professional recruiting email introducing yourself (one template, personalized for each coach)"),
        String(localized: "Send initial contact emails to coaches with game film link"),
        String(localized: "Log each interaction (email, call, conversation at event) in your timeline"),
        String(localized: "Aim for one touchpoint per month with each priority school"),
        String(localized: "Include updates about recent games, academic progress, or highlights")
      ],
      coachesExpect: [
        String(localized: "Initial contact with personalized message and film"),
        String(localized: "Regular updates (monthly or every 4-6 weeks minimum)"),
        String(localized: "Respectful, professional communication"),
        String(localized: "Demonstrated knowledge of their program")
      ],
      timeline: String(localized: "Begin in junior year spring. Maintain through senior year.")
    ),
    "official-visit": SuggestionHelpContent(
      title: String(localized: "Schedule Official Visits"),
      // swiftlint:disable:next line_length
      whyItMatters: String(localized: "Official visits are critical for late-stage recruiting (junior/senior year). They give coaches the chance to evaluate you academically and athletically at their campus, and they give you the chance to assess whether the school is truly a fit. Many scholarship decisions happen during or after official visits."),
      howToComplete: [
        String(localized: "Identify your top 3-5 schools based on fit and genuine interest"),
        String(localized: "Contact the coach to express interest in visiting"),
        String(localized: "Coordinate visit date (usually includes practice, meeting coaches, campus tour, academics meeting)"),
        String(localized: "Prepare questions about program, expectations, and culture"),
        String(localized: "Log the visit details and any conversations that occur"),
        String(localized: "Send a thank-you note to coaches after the visit")
      ],
      coachesExpect: [
        String(localized: "Genuine interest in the program (not just free trip)"),
        String(localized: "Preparation and thoughtful questions"),
        String(localized: "Follow-up communication and feedback after visit"),
        String(localized: "Commitment timeline (if asked)")
      ],
      timeline: String(localized: "Schedule during junior or senior year. Plan 2-3 visits per year.")
    ),
    "missing-video": SuggestionHelpContent(
      title: String(localized: "Create a Highlight Video"),
      whyItMatters: String(localized: "A highlight video is your #1 recruiting tool. Coaches use video to evaluate your skills, athleticism, and football intelligence. Without film, you severely limit your recruiting opportunities even if scouts see you in person."),
      howToComplete: [
        String(localized: "Compile 30-40 plays showcasing your best performances"),
        String(localized: "Include game film (not just highlights) to show consistency"),
        String(localized: "Add title card with your name, position, grade, and contact info"),
        String(localized: "Include both good and neutral plays (coaches want reality, not just highlights)"),
        String(localized: "Upload to YouTube, Vimeo, or dedicated recruiting platforms"),
        String(localized: "Update video annually with new highlights")
      ],
      coachesExpect: [
        String(localized: "Clean, well-edited video that's easy to watch"),
        String(localized: "Consistent performance across multiple plays"),
        String(localized: "Updated film each year")
      ],
      timeline: String(localized: "Complete by sophomore year. Update annually or after major competitions.")
    ),
    "interaction-gap": SuggestionHelpContent(
      title: String(localized: "Stay in Touch with Priority Schools"),
      whyItMatters: String(localized: "Out of sight, out of mind. Priority coaches have many athletes competing for their attention. Regular contact keeps you visible and shows coaches you're genuinely interested. Coaches notice athletes who maintain consistent communication."),
      howToComplete: [
        String(localized: "Identify which priority schools you haven't contacted in 3+ weeks"),
        String(localized: "Send an email update (game results, recent accomplishments, or just a check-in)"),
        String(localized: "Consider a phone call if you have a direct coach's number"),
        String(localized: "Attend their camps or showcases to connect in person"),
        String(localized: "Log each interaction in your timeline with the date")
      ],
      coachesExpect: [
        String(localized: "Consistent communication every 3-4 weeks minimum"),
        String(localized: "Personalized messages (not mass emails)"),
        String(localized: "Genuine updates about your season and progress")
      ],
      timeline: String(localized: "Maintain throughout junior and senior recruiting season.")
    )
  ]
}

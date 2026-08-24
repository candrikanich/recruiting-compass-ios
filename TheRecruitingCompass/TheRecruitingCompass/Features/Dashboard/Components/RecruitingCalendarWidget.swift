import SwiftUI

/// Dashboard widget showing the athlete's sport-specific NCAA recruiting
/// calendar: the current (most-restrictive) period, upcoming milestones, a
/// Men's/Women's toggle for gender-split sports with unresolved gender, an
/// FBS/FCS toggle for Football, the source-citation disclaimer (L6a), and a
/// staleness banner once the dataset's season has ended (L6b).
struct RecruitingCalendarWidget: View {
  let sport: String?
  let gender: String?
  var division: String = "D1"
  /// Target athlete's graduation year — gates which milestone `type`s surface
  /// (e.g. signing dates are withheld from underclassmen). `nil` shows the
  /// unfiltered milestone list.
  var graduationYear: Int?
  /// Injectable "now" for the current-period / staleness / upcoming-milestone
  /// paths — defaults to the real clock. Lets tests exercise the view-level
  /// computed properties against a fixed date (mirrors the web widget's `now`).
  var now: Date = Date()
  /// Suppress the internal "Recruiting Calendar" title row when an outer
  /// container (e.g. `CollapsibleSection`) already renders that title.
  var showHeader: Bool = true

  /// Men's/Women's toggle for gender-split sports with unresolved gender.
  /// Defaults to men's, matching `RecruitingCalendar.resolveKey`'s own default.
  @State private var showsWomens = false
  /// FBS/FCS toggle for Football. Defaults to FBS, matching
  /// `RecruitingCalendar.resolveKey`'s own default.
  @State private var showsFCS = false

  private static let todayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  private var todayISO: String {
    Self.todayFormatter.string(from: now)
  }

  private var isGenderSplitSport: Bool {
    guard let sport else { return false }
    return RecruitingCalendar.genderSplitSports[sport] != nil
  }

  /// Gender is "unresolved" for the purposes of showing a toggle when it's
  /// nil or anything other than the two values the resolver treats as
  /// authoritative ("male"/"female").
  private var isGenderUnresolved: Bool {
    guard let gender else { return true }
    let normalized = gender.lowercased()
    return normalized != "male" && normalized != "female"
  }

  private var showsGenderToggle: Bool {
    isGenderSplitSport && isGenderUnresolved
  }

  private var isFootball: Bool {
    sport == "Football"
  }

  private var effectiveGender: String? {
    if showsGenderToggle {
      return showsWomens ? "female" : "male"
    }
    return gender
  }

  private var effectiveFootballSubdivision: String? {
    isFootball ? (showsFCS ? "FCS" : "FBS") : nil
  }

  private var calendar: SportCalendar {
    RecruitingCalendar.calendar(
      sport: sport,
      division: division,
      gender: effectiveGender,
      footballSubdivision: effectiveFootballSubdivision
    )
  }

  private var current: RecruitingPeriod? {
    Self.currentPeriod(in: calendar.periods, todayISO: todayISO)
  }

  private var upcomingMilestones: [CalendarMilestone] {
    RecruitingCalendar.upcomingMilestones(
      todayISO,
      sport: sport,
      division: division,
      gender: effectiveGender,
      footballSubdivision: effectiveFootballSubdivision,
      graduationYear: graduationYear
    )
  }

  private var isDatasetStale: Bool {
    Self.isStale(todayISO: todayISO)
  }

  /// Selects the current period covering `todayISO`: the *most restrictive*
  /// period when multiple overlap (severity `recruitingShutdown > dead >
  /// evaluation > quiet > contact`), tie-broken by shortest span. Pure/static
  /// so it's directly testable without standing up the view.
  static func currentPeriod(
    in periods: [RecruitingPeriod],
    todayISO: String
  ) -> RecruitingPeriod? {
    let severity: [PeriodType: Int] = [
      .recruitingShutdown: 4,
      .dead: 3,
      .evaluation: 2,
      .quiet: 1,
      .contact: 0,
    ]
    let covering = periods.filter { todayISO >= $0.start && todayISO <= $0.end }
    return covering.max { lhs, rhs in
      let lhsSeverity = severity[lhs.type] ?? 0
      let rhsSeverity = severity[rhs.type] ?? 0
      if lhsSeverity != rhsSeverity { return lhsSeverity < rhsSeverity }
      // Tie-break: shortest span wins (is "more current"/most-specific).
      let lhsSpan = span(of: lhs)
      let rhsSpan = span(of: rhs)
      return lhsSpan > rhsSpan
    }
  }

  private static func span(of period: RecruitingPeriod) -> Int {
    guard
      let start = todayFormatter.date(from: period.start),
      let end = todayFormatter.date(from: period.end)
    else { return .max }
    return Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: end).day ?? .max
  }

  /// True once `todayISO` is past the dataset's season end — the widget
  /// shows the L6b staleness banner in this state.
  static func isStale(todayISO: String) -> Bool {
    todayISO > RecruitingCalendarData.seasonEnd
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if showHeader {
        Text("Recruiting Calendar")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
      }

      Divider()

      if showsGenderToggle {
        Picker(String(localized: "Team"), selection: $showsWomens) {
          Text("Men's").tag(false)
          Text("Women's").tag(true)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "Men's or Women's calendar"))
      }

      if isFootball {
        Picker(String(localized: "Subdivision"), selection: $showsFCS) {
          Text("FBS").tag(false)
          Text("FCS").tag(true)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "FBS or FCS calendar"))
      }

      if isDatasetStale {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(Color.orange)
            .accessibilityHidden(true)
          Text("This calendar is for the \(RecruitingCalendarData.season) season, which has ended. Dates for the next season have not been verified yet.")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
        .padding(.vertical, 4)
      }

      if let current {
        VStack(alignment: .leading, spacing: 4) {
          Text("Right now")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
          Text(periodLabel(for: current.type))
            .font(.subheadline.weight(.semibold))
          Text(current.description)
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
      } else {
        Text("No recruiting-period data available for today")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
          .padding(.vertical)
      }

      if !upcomingMilestones.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Upcoming")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
          ForEach(upcomingMilestones, id: \.date) { milestone in
            HStack {
              Text(milestone.title)
                .font(.caption)
              Spacer()
              Text(milestone.date)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
            }
          }
        }
      }

      Divider()

      VStack(alignment: .leading, spacing: 4) {
        Text("Based on NCAA \(RecruitingCalendarData.season), verified \(calendar.verifiedOn) — confirm with your compliance office")
          .font(.caption2)
          .foregroundStyle(Color.secondaryText)
        if let sourceURL = URL(string: calendar.source) {
          Link(String(localized: "View source"), destination: sourceURL)
            .font(.caption2)
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    // Reset the self-select toggles if the athlete's sport/gender changes under
    // a live instance, so a stale Women's/FCS selection can't carry over to a
    // sport where it no longer applies.
    .onChange(of: sport) {
      showsWomens = false
      showsFCS = false
    }
    .onChange(of: gender) {
      showsWomens = false
    }
  }

  private func periodLabel(for type: PeriodType) -> String {
    switch type {
    case .recruitingShutdown: return String(localized: "Recruiting Shutdown")
    case .dead: return String(localized: "Dead Period")
    case .evaluation: return String(localized: "Evaluation Period")
    case .quiet: return String(localized: "Quiet Period")
    case .contact: return String(localized: "Contact Period")
    }
  }
}

#Preview {
  RecruitingCalendarWidget(sport: "Baseball", gender: "male")
    .padding()
}

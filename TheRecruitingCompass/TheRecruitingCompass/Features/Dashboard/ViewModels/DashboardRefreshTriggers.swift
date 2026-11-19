/// What the Home screen re-reads for each event that can change the first-run state (a coach, a conversation or
/// a favorite school), decided here so a test can pin every trigger; the view only forwards the event.
@MainActor
struct DashboardRefreshTriggers {
  let fetchDashboardData: () async -> Void
  let refreshDashboard: () async -> Void
  let refreshFirstRunSignals: () async -> Void
  let refreshFirstRunSignalsIfIdle: () async -> Void

  init(dashboard: DashboardViewModel, timeline: TimelineViewModel) {
    self.init(
      fetchDashboardData: { await dashboard.fetchDashboardData() },
      refreshDashboard: { await dashboard.refresh() },
      refreshFirstRunSignals: { await timeline.refreshFirstRunSignals() },
      refreshFirstRunSignalsIfIdle: { await timeline.refreshFirstRunSignalsIfIdle() }
    )
  }

  init(
    fetchDashboardData: @escaping () async -> Void,
    refreshDashboard: @escaping () async -> Void,
    refreshFirstRunSignals: @escaping () async -> Void,
    refreshFirstRunSignalsIfIdle: @escaping () async -> Void
  ) {
    self.fetchDashboardData = fetchDashboardData
    self.refreshDashboard = refreshDashboard
    self.refreshFirstRunSignals = refreshFirstRunSignals
    self.refreshFirstRunSignalsIfIdle = refreshFirstRunSignalsIfIdle
  }

  /// Returning from another tab: something may have changed meanwhile.
  func screenAppeared() async { await refreshFirstRunSignalsIfIdle() }

  func addSchoolSheetDismissed() async { await afterFetching(fetchDashboardData) }

  func coachContacted() async { await afterFetching(fetchDashboardData) }

  func actionCompleted() async { await afterFetching(fetchDashboardData) }

  func realtimeEventReceived() async { await afterFetching(refreshDashboard) }

  /// The two reads are independent, so they run together; the signals request is the newest-wins one.
  private func afterFetching(_ dashboardRead: () async -> Void) async {
    async let signals: Void = refreshFirstRunSignals()
    await dashboardRead()
    await signals
  }
}

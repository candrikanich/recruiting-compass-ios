import XCTest
@testable import TheRecruitingCompass

/// Shipped builds can't be updated remotely, so a server-added enum value must degrade to `.unknown`
/// instead of failing the whole response.
@MainActor
final class TolerantEnumDecodingTests: XCTestCase {
  nonisolated deinit {}

  private func decode<T: Decodable>(_ type: T.Type, _ raw: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data("\"\(raw)\"".utf8))
  }

  private func decodeList<T: Decodable>(_ type: T.Type, _ raws: [String]) throws -> [T] {
    let json = "[" + raws.map { "\"\($0)\"" }.joined(separator: ",") + "]"
    return try JSONDecoder().decode([T].self, from: Data(json.utf8))
  }

  // MARK: - Unknown raw value decodes to .unknown

  func testDirection_unknownRawValue() throws {
    XCTAssertEqual(try decode(Direction.self, "sideways"), .unknown)
  }

  func testSentiment_unknownRawValue() throws {
    XCTAssertEqual(try decode(Sentiment.self, "ecstatic"), .unknown)
  }

  func testTaskStatus_unknownRawValue() throws {
    XCTAssertEqual(try decode(TaskStatus.self, "blocked"), .unknown)
  }

  func testDeadlineCategory_unknownRawValue() throws {
    XCTAssertEqual(try decode(DeadlineCategory.self, "scholarship"), .unknown)
  }

  func testTimelinePhase_unknownRawValue() throws {
    XCTAssertEqual(try decode(TimelinePhase.self, "graduate"), .unknown)
  }

  func testStatusLabel_unknownRawValue() throws {
    XCTAssertEqual(try decode(StatusLabel.self, "ahead"), .unknown)
  }

  func testUrgencyLevel_unknownRawValue() throws {
    XCTAssertEqual(try decode(Suggestion.UrgencyLevel.self, "critical"), .unknown)
  }

  func testCommitmentStatus_unknownRawValue() throws {
    XCTAssertEqual(try decode(CommitmentStatus.self, "transferred"), .unknown)
  }

  // MARK: - Known values round-trip

  func testKnownValuesRoundTrip() throws {
    func roundTrip<T: Codable & Equatable>(_ value: T) throws {
      let data = try JSONEncoder().encode([value])
      XCTAssertEqual(try JSONDecoder().decode([T].self, from: data), [value])
    }
    try roundTrip(Direction.inbound)
    try roundTrip(Sentiment.veryPositive)
    try roundTrip(TaskStatus.inProgress)
    try roundTrip(DeadlineCategory.financial_aid)
    try roundTrip(TimelinePhase.committed)
    try roundTrip(StatusLabel.atRisk)
    try roundTrip(Suggestion.UrgencyLevel.medium)
    try roundTrip(CommitmentStatus.committed)
  }

  func testKnownRawValuesStillDecode() throws {
    XCTAssertEqual(try decode(Sentiment.self, "very_positive"), .veryPositive)
    XCTAssertEqual(try decode(TaskStatus.self, "not_started"), .notStarted)
    XCTAssertEqual(try decode(StatusLabel.self, "slightly_behind"), .slightlyBehind)
  }

  // MARK: - One bad row doesn't sink the list

  func testListWithUnknownValueDecodesEveryRow() throws {
    XCTAssertEqual(
      try decodeList(Direction.self, ["inbound", "bogus", "outbound"]),
      [.inbound, .unknown, .outbound])
    XCTAssertEqual(try decodeList(TaskStatus.self, ["completed", "bogus"]), [.completed, .unknown])
  }

  func testSuggestionListWithUnknownUrgencyDecodesEveryRow() throws {
    func row(_ id: String, _ urgency: String) -> String {
      """
      {"id":"\(id)","rule_type":"r","message":"m","urgency":"\(urgency)","dismissed":false,"completed":false}
      """
    }
    let json = "[\(row("1", "high")),\(row("2", "critical"))]"
    let list = try JSONDecoder().decode([Suggestion].self, from: Data(json.utf8))
    XCTAssertEqual(list.map(\.urgency), [.high, .unknown])
  }

  // MARK: - Pickers and filters never offer .unknown

  func testSelectableCasesExcludeUnknown() {
    XCTAssertFalse(Direction.selectableCases.contains(.unknown))
    XCTAssertFalse(Sentiment.selectableCases.contains(.unknown))
    XCTAssertFalse(TaskStatus.selectableCases.contains(.unknown))
    XCTAssertFalse(DeadlineCategory.selectableCases.contains(.unknown))
    XCTAssertFalse(TimelinePhase.selectableCases.contains(.unknown))
    XCTAssertFalse(CommitmentStatus.selectableCases.contains(.unknown))
  }

  func testSelectableCasesKeepEveryKnownValue() {
    XCTAssertEqual(Direction.selectableCases.count, Direction.allCases.count - 1)
    XCTAssertEqual(Sentiment.selectableCases.count, Sentiment.allCases.count - 1)
    XCTAssertEqual(TaskStatus.selectableCases.count, TaskStatus.allCases.count - 1)
    XCTAssertEqual(DeadlineCategory.selectableCases.count, DeadlineCategory.allCases.count - 1)
    XCTAssertEqual(TimelinePhase.selectableCases.count, TimelinePhase.allCases.count - 1)
    XCTAssertEqual(CommitmentStatus.selectableCases.count, CommitmentStatus.allCases.count - 1)
  }

  // MARK: - Neutral rendering

  func testUnknownRendersNeutralLabel() {
    XCTAssertEqual(Direction.unknown.displayName, "Unknown")
    XCTAssertEqual(Direction.unknown.subtitle, "")
    XCTAssertEqual(Sentiment.unknown.displayName, "Unknown")
    XCTAssertFalse(Sentiment.unknown.isPositive)
    XCTAssertEqual(TaskStatus.unknown.displayName, "Unknown")
    XCTAssertEqual(DeadlineCategory.unknown.displayName, "Unknown")
    XCTAssertEqual(TimelinePhase.unknown.displayLabel, "Unknown")
    XCTAssertEqual(TimelinePhase.unknown.gradeLabel, "Unknown")
    XCTAssertEqual(Suggestion.UrgencyLevel.unknown.displayName, "Unknown")
    XCTAssertEqual(CommitmentStatus.unknown.label, "Unknown")
  }
}

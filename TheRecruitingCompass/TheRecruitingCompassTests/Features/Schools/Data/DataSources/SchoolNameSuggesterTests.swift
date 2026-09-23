//
//  SchoolNameSuggesterTests.swift
//  TheRecruitingCompassTests
//
//  Typo-tolerant school name suggestions (issue #140)
//

import XCTest
@testable import TheRecruitingCompass

@MainActor
final class SchoolNameSuggesterTests: XCTestCase {
  nonisolated deinit {}

  private let names = [
    "University of Michigan",
    "Michigan State University",
    "Stanford University",
    "Vanderbilt University",
    "Florida Southern College",
    "Johns Hopkins University",
    "MIT"
  ]

  func testSuggestions_missingLetter_findsSchool() {
    let result = SchoolNameSuggester.suggestions(for: "Michgan", from: names)
    XCTAssertTrue(result.contains("University of Michigan"))
  }

  func testSuggestions_transposedLetters_findsSchool() {
    let result = SchoolNameSuggester.suggestions(for: "Stanfrod", from: names)
    XCTAssertEqual(result.first, "Stanford University")
  }

  func testSuggestions_multiWordTypo_findsSchool() {
    let result = SchoolNameSuggester.suggestions(for: "vanderbilt univrsity", from: names)
    XCTAssertEqual(result.first, "Vanderbilt University")
  }

  func testSuggestions_isCaseAndPunctuationInsensitive() {
    let result = SchoolNameSuggester.suggestions(for: "JOHNS HOPKINS,", from: names)
    XCTAssertEqual(result.first, "Johns Hopkins University")
  }

  func testSuggestions_nonsense_returnsEmpty() {
    XCTAssertTrue(SchoolNameSuggester.suggestions(for: "zzzzqqq", from: names).isEmpty)
  }

  func testSuggestions_genericWordsAlone_doNotMatchEverything() {
    XCTAssertTrue(SchoolNameSuggester.suggestions(for: "university", from: names).isEmpty)
  }

  func testSuggestions_shortTokensRequireExactMatch() {
    XCTAssertTrue(SchoolNameSuggester.suggestions(for: "mat", from: names).isEmpty)
  }

  func testSuggestions_ranksClosestFirst() {
    let result = SchoolNameSuggester.suggestions(for: "Michigen", from: names)
    XCTAssertEqual(result.first, "University of Michigan")
    XCTAssertEqual(result.count, 2)
  }

  func testSuggestions_respectsLimit() {
    let result = SchoolNameSuggester.suggestions(for: "Michgan", from: names, limit: 1)
    XCTAssertEqual(result.count, 1)
  }

  func testSuggestions_emptyQuery_returnsEmpty() {
    XCTAssertTrue(SchoolNameSuggester.suggestions(for: "  ", from: names).isEmpty)
  }
}

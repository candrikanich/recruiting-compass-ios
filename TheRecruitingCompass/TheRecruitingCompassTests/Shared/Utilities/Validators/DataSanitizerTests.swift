//
//  DataSanitizerTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-10
//  Phase 7: Testing - Unit tests for DataSanitizer
//

import XCTest
@testable import TheRecruitingCompass

final class DataSanitizerTests: XCTestCase {

  // MARK: - nilIfEmpty Tests

  func testNilIfEmpty_whenEmpty_returnsNil() {
    // When
    let result = DataSanitizer.nilIfEmpty("")

    // Then
    XCTAssertNil(result)
  }

  func testNilIfEmpty_whenWhitespaceOnly_returnsNil() {
    // When
    let result = DataSanitizer.nilIfEmpty("   ")

    // Then
    XCTAssertNil(result)
  }

  func testNilIfEmpty_whenNotEmpty_returnsValue() {
    // When
    let result = DataSanitizer.nilIfEmpty("test")

    // Then
    XCTAssertEqual(result, "test")
  }

  func testNilIfEmpty_trimsWhitespace() {
    // When
    let result = DataSanitizer.nilIfEmpty("  test  ")

    // Then
    XCTAssertEqual(result, "test")
  }

  // MARK: - stripAtSign Tests

  func testStripAtSign_whenNoAtSign_returnsOriginal() {
    // When
    let result = DataSanitizer.stripAtSign("johndoe")

    // Then
    XCTAssertEqual(result, "johndoe")
  }

  func testStripAtSign_whenStartsWithAtSign_returnsWithoutAt() {
    // When
    let result = DataSanitizer.stripAtSign("@johndoe")

    // Then
    XCTAssertEqual(result, "johndoe")
  }

  func testStripAtSign_whenEmpty_returnsEmpty() {
    // When
    let result = DataSanitizer.stripAtSign("")

    // Then
    XCTAssertEqual(result, "")
  }

  func testStripAtSign_whenOnlyAtSign_returnsEmpty() {
    // When
    let result = DataSanitizer.stripAtSign("@")

    // Then
    XCTAssertEqual(result, "")
  }

  func testStripAtSign_trimsWhitespace() {
    // When
    let result = DataSanitizer.stripAtSign("  @johndoe  ")

    // Then
    XCTAssertEqual(result, "johndoe")
  }

  func testStripAtSign_onlyStripsLeading() {
    // When
    let result = DataSanitizer.stripAtSign("@john@doe")

    // Then
    XCTAssertEqual(result, "john@doe")
  }

  // MARK: - stripHtmlTags Tests

  func testStripHtmlTags_whenNoTags_returnsOriginal() {
    // When
    let result = DataSanitizer.stripHtmlTags("This is plain text")

    // Then
    XCTAssertEqual(result, "This is plain text")
  }

  func testStripHtmlTags_whenSimpleTags_removesTags() {
    // When
    let result = DataSanitizer.stripHtmlTags("<p>Hello</p>")

    // Then
    XCTAssertEqual(result, "Hello")
  }

  func testStripHtmlTags_whenMultipleTags_removesAllTags() {
    // When
    let result = DataSanitizer.stripHtmlTags("<b>Bold</b> and <i>italic</i>")

    // Then
    XCTAssertEqual(result, "Bold and italic")
  }

  func testStripHtmlTags_whenNestedTags_removesAllTags() {
    // When
    let result = DataSanitizer.stripHtmlTags("<div><p>Nested</p></div>")

    // Then
    XCTAssertEqual(result, "Nested")
  }

  func testStripHtmlTags_whenEmpty_returnsEmpty() {
    // When
    let result = DataSanitizer.stripHtmlTags("")

    // Then
    XCTAssertEqual(result, "")
  }

  func testStripHtmlTags_whenTagsWithAttributes_removesTags() {
    // When
    let result = DataSanitizer.stripHtmlTags("<a href='test'>Link</a>")

    // Then
    XCTAssertEqual(result, "Link")
  }

  func testStripHtmlTags_whenSelfClosingTags_removesTags() {
    // When
    let result = DataSanitizer.stripHtmlTags("Text<br/>More text")

    // Then
    XCTAssertEqual(result, "TextMore text")
  }
}

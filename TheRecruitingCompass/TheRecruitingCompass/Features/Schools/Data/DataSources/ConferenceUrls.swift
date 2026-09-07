//
//  ConferenceUrls.swift
//  TheRecruitingCompass
//
//  Auto-resolved (non-editable) conference website lookup — client-side
//  static data, no DB table (see web's utils/conferenceUrls.ts and
//  docs/superpowers/specs/2026-09-02-school-data-enrichment-design.md).
//  Exact match against School.conference, same source data as web's
//  data/conferenceUrls.json.
//

import Foundation
import OSLog

nonisolated private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ConferenceUrls"
)

nonisolated enum ConferenceUrls {
  /// Loaded once at first access and cached for the app session.
  static let map: [String: String] = loadMap()

  static func url(for conference: String?) -> URL? {
    guard let conference, let urlString = map[conference] else { return nil }
    return URL(string: urlString)
  }

  private static func loadMap() -> [String: String] {
    let url = Bundle.main.url(forResource: "conferenceUrls", withExtension: "json")
      ?? Bundle.main.url(forResource: "conferenceUrls", withExtension: "json", subdirectory: "Resources")

    guard let url else {
      logger.error("conferenceUrls.json not found anywhere in bundle — conference links will not resolve")
      return [:]
    }

    do {
      let data = try Data(contentsOf: url)
      let map = try JSONDecoder().decode([String: String].self, from: data)
      logger.debug("Loaded \(map.count) conference URLs from \(url.path)")
      return map
    } catch {
      logger.error("Failed to decode conferenceUrls.json: \(error.localizedDescription)")
      return [:]
    }
  }
}

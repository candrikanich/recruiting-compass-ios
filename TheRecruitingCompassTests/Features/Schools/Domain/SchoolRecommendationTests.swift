import Testing
@testable import TheRecruitingCompass

@Suite("SchoolRecommendation decoding")
struct SchoolRecommendationTests {
  @Test("decodes web API's camelCase JSON (no catalog_key snake_case)")
  func decodesCamelCaseJSON() throws {
    let json = """
    {
      "catalogKey": "ohio-state",
      "name": "Ohio State University",
      "division": "D1",
      "conference": "Big Ten",
      "state": "OH",
      "website": "https://osu.edu",
      "athleticsUrl": "https://ohiostatebuckeyes.com",
      "score": 0.85,
      "reasons": ["Strong baseball program"]
    }
    """.data(using: .utf8)!

    let rec = try JSONDecoder().decode(SchoolRecommendation.self, from: json)

    #expect(rec.catalogKey == "ohio-state")
    #expect(rec.website == "https://osu.edu")
    #expect(rec.athleticsUrl == "https://ohiostatebuckeyes.com")
  }

  @Test("decodes with optional fields absent")
  func decodesWithoutOptionalFields() throws {
    let json = """
    {
      "catalogKey": "duke",
      "name": "Duke University",
      "division": null,
      "conference": null,
      "state": null,
      "website": null,
      "athleticsUrl": null,
      "score": 0.78,
      "reasons": []
    }
    """.data(using: .utf8)!

    let rec = try JSONDecoder().decode(SchoolRecommendation.self, from: json)

    #expect(rec.division == nil)
    #expect(rec.website == nil)
  }
}

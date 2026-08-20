import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CommunicationTemplatesViewModelTypeCountsTests: XCTestCase {
  nonisolated deinit {}

  private func template(id: String, type: TemplateType) -> CommunicationTemplate {
    CommunicationTemplate(id: id, userId: "u", name: "n", type: type, body: "b",
                          variables: nil, createdAt: "", updatedAt: "")
  }

  func test_typeCountsCoverSelectableOnly() {
    let vm = CommunicationTemplatesViewModel()
    vm.templates = [
      template(id: "1", type: .email),
      template(id: "2", type: .message),
      template(id: "3", type: .social),
      template(id: "4", type: .unknown)
    ]
    XCTAssertEqual(vm.typeCounts[.email], 1)
    XCTAssertEqual(vm.typeCounts[.message], 1)
    XCTAssertEqual(vm.typeCounts[.social], 1)
    XCTAssertNil(vm.typeCounts[.unknown], "unknown must not get a filter pill")
    XCTAssertEqual(vm.typeCounts[nil], 4, "All-count includes every template")
  }
}

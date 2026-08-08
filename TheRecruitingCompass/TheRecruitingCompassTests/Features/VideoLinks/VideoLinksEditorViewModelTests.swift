import XCTest
@testable import TheRecruitingCompass

@MainActor
final class VideoLinksEditorViewModelTests: XCTestCase {
  nonisolated deinit {}

  private func makeVM(readOnly: Bool = false, seed: [VideoLink] = []) -> (VideoLinksEditorViewModel, MockVideoLinksService) {
    let mock = MockVideoLinksService(); mock.links = seed
    let vm = VideoLinksEditorViewModel(service: mock, athleteUserId: "u1",
                                       familyUnitId: "f1", isReadOnly: readOnly)
    return (vm, mock)
  }
  private func link(_ id: String, _ pos: Int) -> VideoLink {
    VideoLink(id: id, userId: "u1", familyUnitId: "f1", platform: .hudl,
      url: "https://hudl.com/\(id)", title: nil, position: pos,
      healthStatus: .unknown, lastHealthCheck: nil, createdAt: nil, updatedAt: nil)
  }

  func test_loadPopulatesLinks() async {
    let (vm, _) = makeVM(seed: [link("a", 0), link("b", 1)])
    await vm.load()
    XCTAssertEqual(vm.links.count, 2)
    XCTAssertFalse(vm.isLoading)
  }

  func test_addAppendsAndDefaultsPositionToCount() async {
    let (vm, _) = makeVM(seed: [link("a", 0)])
    await vm.load()
    let ok = await vm.addLink(platform: .youtube, url: "https://youtu.be/x", title: "New")
    XCTAssertTrue(ok)
    XCTAssertEqual(vm.links.count, 2)
    XCTAssertEqual(vm.links.last?.position, 1)
  }

  func test_addBlockedAtMaxFive() async {
    let (vm, _) = makeVM(seed: (0..<5).map { link("l\($0)", $0) })
    await vm.load()
    XCTAssertFalse(vm.canAddLink)
    let ok = await vm.addLink(platform: .hudl, url: "https://hudl.com/six", title: nil)
    XCTAssertFalse(ok)
    XCTAssertEqual(vm.links.count, 5)
    XCTAssertNotNil(vm.errorMessage)
  }

  func test_readOnlyParentCannotAddOrDelete() async {
    let (vm, _) = makeVM(readOnly: true, seed: [link("a", 0)])
    await vm.load()
    XCTAssertFalse(vm.canAddLink)
    let added = await vm.addLink(platform: .hudl, url: "https://x", title: nil)
    XCTAssertFalse(added)
    let deleted = await vm.deleteLink(id: "a")
    XCTAssertFalse(deleted)
    XCTAssertEqual(vm.links.count, 1)
  }

  func test_deleteRemoves() async {
    let (vm, _) = makeVM(seed: [link("a", 0), link("b", 1)])
    await vm.load()
    let ok = await vm.deleteLink(id: "a")
    XCTAssertTrue(ok)
    XCTAssertEqual(vm.links.map(\.id), ["b"])
  }
}

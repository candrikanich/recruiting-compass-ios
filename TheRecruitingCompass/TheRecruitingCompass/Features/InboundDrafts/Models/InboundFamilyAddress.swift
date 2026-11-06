import Foundation

struct InboundFamilyAddress: Codable, Sendable, Equatable, Identifiable {
  let familyUnitId: String
  let familyName: String
  /// Server-resolved "<Player>'s Family"; absent from API versions that predate web#1265.
  let familyLabel: String?
  let address: String

  var displayLabel: String { FamilyLabel.display(label: familyLabel, legacyName: familyName) ?? familyName }

  init(familyUnitId: String, familyName: String, familyLabel: String? = nil, address: String) {
    self.familyUnitId = familyUnitId
    self.familyName = familyName
    self.familyLabel = familyLabel
    self.address = address
  }

  var id: String { familyUnitId }
}

struct InboundAddressResponse: Codable, Sendable {
  let addresses: [InboundFamilyAddress]
}

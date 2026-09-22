import Foundation

struct InboundFamilyAddress: Codable, Sendable, Equatable, Identifiable {
  let familyUnitId: String
  let familyName: String
  let address: String

  var id: String { familyUnitId }
}

struct InboundAddressResponse: Codable, Sendable {
  let addresses: [InboundFamilyAddress]
}

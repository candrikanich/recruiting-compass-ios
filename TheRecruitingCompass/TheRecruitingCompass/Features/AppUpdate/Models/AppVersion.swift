import Foundation

/// A `major.minor.patch` app version. Missing trailing components count as 0, so "1.0" == "1.0.0".
struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
  let major: Int
  let minor: Int
  let patch: Int

  init(major: Int, minor: Int, patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  init?(_ string: String) {
    let parts = string.trimmingCharacters(in: .whitespacesAndNewlines)
      .split(separator: ".", omittingEmptySubsequences: false)
    guard (1...3).contains(parts.count) else { return nil }

    var numbers: [Int] = []
    for part in parts {
      guard !part.isEmpty, part.allSatisfy(\.isASCII), part.allSatisfy(\.isNumber), let number = Int(part) else {
        return nil
      }
      numbers.append(number)
    }
    let padded = numbers + Array(repeating: 0, count: 3 - numbers.count)
    self.init(major: padded[0], minor: padded[1], patch: padded[2])
  }

  var description: String { "\(major).\(minor).\(patch)" }

  static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
    (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
  }
}

/// Server-controlled version thresholds from `get_ios_version_policy()`. NULL = no threshold.
struct AppVersionPolicy: Decodable, Equatable, Sendable {
  let minimumVersion: String?
  let recommendedVersion: String?

  enum CodingKeys: String, CodingKey {
    case minimumVersion = "minimum_version"
    case recommendedVersion = "recommended_version"
  }
}

enum AppUpdateStatus: Equatable, Sendable {
  case upToDate
  case updateAvailable(AppVersion)
  case updateRequired(AppVersion)

  /// Unparseable thresholds are ignored: a typo in the config row must never lock users out.
  static func evaluate(current: AppVersion, policy: AppVersionPolicy) -> AppUpdateStatus {
    if let minimum = policy.minimumVersion.flatMap(AppVersion.init), current < minimum {
      return .updateRequired(minimum)
    }
    if let recommended = policy.recommendedVersion.flatMap(AppVersion.init), current < recommended {
      return .updateAvailable(recommended)
    }
    return .upToDate
  }
}

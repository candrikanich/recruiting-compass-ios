import Foundation

/// Resolves the APNs environment (sandbox vs production) a device token was minted under,
/// so the backend push sender can route to the matching APNs host. The `aps-environment`
/// entitlement value in Xcode's checked-in file is always "development" — Xcode/App Store
/// Connect flip it to "production" only at distribution signing, so the true value must be
/// read from the embedded provisioning profile at runtime, not the source entitlements file.
enum APNsEnvironment {
    /// "sandbox" or "production" — matches `device_tokens.environment` allowed values.
    static var current: String {
        guard let entitlement = entitlementFromEmbeddedProvisioningProfile() else {
            // Simulator builds carry no embedded provisioning profile at all.
            #if DEBUG
            return "sandbox"
            #else
            return "production"
            #endif
        }
        return entitlement == "development" ? "sandbox" : "production"
    }

    /// Reads `aps-environment` out of the app's embedded provisioning profile, if present.
    static func entitlementFromEmbeddedProvisioningProfile(
        data: Data? = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision")
            .flatMap { try? Data(contentsOf: URL(fileURLWithPath: $0)) }
    ) -> String? {
        guard let data, let profileString = String(data: data, encoding: .isoLatin1) else { return nil }
        return parseApsEnvironment(fromProfileString: profileString)
    }

    /// Extracted for direct unit testing — provisioning profiles are a CMS-signed blob with
    /// an embedded plist; this pulls just that plist substring out and reads one key.
    static func parseApsEnvironment(fromProfileString profileString: String) -> String? {
        guard let plistStart = profileString.range(of: "<?xml"),
              let plistEnd = profileString.range(of: "</plist>") else { return nil }
        let plistSubstring = profileString[plistStart.lowerBound..<plistEnd.upperBound]
        guard let plistData = String(plistSubstring).data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else { return nil }
        return entitlements["aps-environment"] as? String
    }
}

import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("APNsEnvironment")
struct APNsEnvironmentTests {

    @Test func parsesDevelopmentApsEnvironment() {
        let profile = fakeProvisioningProfile(apsEnvironment: "development")
        #expect(APNsEnvironment.parseApsEnvironment(fromProfileString: profile) == "development")
    }

    @Test func parsesProductionApsEnvironment() {
        let profile = fakeProvisioningProfile(apsEnvironment: "production")
        #expect(APNsEnvironment.parseApsEnvironment(fromProfileString: profile) == "production")
    }

    @Test func returnsNilWhenNoApsEnvironmentKey() {
        let profile = fakeProvisioningProfile(apsEnvironment: nil)
        #expect(APNsEnvironment.parseApsEnvironment(fromProfileString: profile) == nil)
    }

    @Test func returnsNilForGarbageInput() {
        #expect(APNsEnvironment.parseApsEnvironment(fromProfileString: "not a provisioning profile") == nil)
    }

    @Test func entitlementFromEmbeddedProvisioningProfileReturnsNilWhenNoData() {
        #expect(APNsEnvironment.entitlementFromEmbeddedProvisioningProfile(data: nil) == nil)
    }

    @Test func entitlementFromEmbeddedProvisioningProfileParsesRealData() {
        let profile = fakeProvisioningProfile(apsEnvironment: "production")
        let data = profile.data(using: .isoLatin1)
        #expect(APNsEnvironment.entitlementFromEmbeddedProvisioningProfile(data: data) == "production")
    }

    // MARK: - Helpers

    /// Real provisioning profiles are a CMS-signed blob wrapping this plist; the parser only
    /// cares about locating the `<?xml`…`</plist>` substring, so this fixture skips the CMS
    /// wrapper entirely and adds surrounding binary-looking noise to mimic it.
    private func fakeProvisioningProfile(apsEnvironment: String?) -> String {
        let entitlementsXML = apsEnvironment.map {
            "<key>aps-environment</key><string>\($0)</string>"
        } ?? ""
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">
        <dict>
            <key>Entitlements</key>
            <dict>
                \(entitlementsXML)
                <key>application-identifier</key>
                <string>G374A783RH.com.chrisandrikanich.TheRecruitingCompass</string>
            </dict>
        </dict>
        </plist>
        """
        return "\u{0001}\u{0002}garbage-cms-header\(plist)trailing-cms-signature\u{0003}"
    }
}

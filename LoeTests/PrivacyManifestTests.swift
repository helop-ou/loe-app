import Foundation
import Testing
@testable import Loe

struct PrivacyManifestTests {
    /// What in the code calls each of the required-reason APIs on Apple's list.
    private static let callers = [
        "NSPrivacyAccessedAPICategoryUserDefaults": ["UserDefaults", "@AppStorage"],
        "NSPrivacyAccessedAPICategoryFileTimestamp": [".modificationDate", ".creationDate", "ModificationDateKey", "CreationDateKey"],
        "NSPrivacyAccessedAPICategorySystemBootTime": ["systemUptime", "mach_absolute_time"],
        "NSPrivacyAccessedAPICategoryDiskSpace": ["AvailableCapacity", "volumeTotalCapacity", "systemFreeSize", "systemSize"],
        "NSPrivacyAccessedAPICategoryActiveKeyboards": ["activeInputModes"],
    ]

    private static let sources = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Loe")

    private func manifest() throws -> [String: Any] {
        let url = try #require(Bundle(for: CatalogueStore.self).url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let list = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(list as? [String: Any])
    }

    private func declared() throws -> [String: [String]] {
        let types = try #require(try manifest()["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        return Dictionary(uniqueKeysWithValues: try types.map { type in
            (try #require(type["NSPrivacyAccessedAPIType"] as? String), try #require(type["NSPrivacyAccessedAPITypeReasons"] as? [String]))
        })
    }

    @Test func itDeclaresTheRequiredReasonAPIsTheCodeCallsAndNoOthers() throws {
        var called: Set<String> = []
        var files = 0
        let enumerator = try #require(FileManager.default.enumerator(at: Self.sources, includingPropertiesForKeys: nil))
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            files += 1
            let text = try String(contentsOf: file, encoding: .utf8)
            for (category, names) in Self.callers where names.contains(where: text.contains) {
                called.insert(category)
            }
        }
        #expect(files > 50)
        #expect(Set(try declared().keys) == called)
    }

    @Test func eachDeclarationGivesItsReason() throws {
        #expect(try declared() == [
            "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1"],
            "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1"],
        ])
    }

    @Test func itDeclaresNoTrackingAndNoCollectedData() throws {
        let manifest = try manifest()
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
    }
}

import SwiftUI
import Testing
@testable import Loe

@MainActor
struct SettingsSnapshotTests {
    private static let statuses: [CloudSync.Status] = [
        .checking, .on(lastSynced: nil), .off, .restricted, .unavailable, .full, .offline, .failed,
    ]

    @Test(arguments: Snapshot.Look.all)
    func everyICloudStatus(look: Snapshot.Look) throws {
        let rows = VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(Self.statuses.enumerated()), id: \.offset) { _, status in
                CloudSyncRow(status: status)
            }
        }
        .padding(20)
        try Snapshot.verify(rows, named: "icloud-status", look: look)
    }

    @Test(arguments: Snapshot.Look.all)
    func theAboutHeader(look: Snapshot.Look) throws {
        try Snapshot.verify(AboutHeader(version: "0.1.0", build: "78").padding(20), named: "about-header", look: look)
    }

    @Test(arguments: Snapshot.Look.all)
    func privacy(look: Snapshot.Look) throws {
        try Snapshot.verify(PrivacyContent().padding(20), named: "privacy", look: look)
    }
}

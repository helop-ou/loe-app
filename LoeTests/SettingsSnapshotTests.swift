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
}

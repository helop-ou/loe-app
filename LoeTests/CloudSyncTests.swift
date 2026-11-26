import CloudKit
import Foundation
import Synchronization
import Testing
@testable import Loe

struct CloudSyncTests {
    private static let synced = Date(timeIntervalSince1970: 1_800_000_000)

    private static func failed(_ code: CKError.Code?) -> CloudSync.Event {
        CloudSync.Event(succeeded: false, error: code, endDate: synced.addingTimeInterval(60))
    }

    @Test func theAccountComesFirst() {
        #expect(CloudSync.status(account: nil, lastEvent: nil, lastSynced: nil) == .checking)
        #expect(CloudSync.status(account: .noAccount, lastEvent: nil, lastSynced: nil) == .off)
        #expect(CloudSync.status(account: .restricted, lastEvent: nil, lastSynced: nil) == .restricted)
        #expect(CloudSync.status(account: .temporarilyUnavailable, lastEvent: nil, lastSynced: nil) == .unavailable)
        #expect(CloudSync.status(account: .couldNotDetermine, lastEvent: nil, lastSynced: nil) == .unavailable)
        // A full iCloud matters less than having none.
        #expect(CloudSync.status(account: .noAccount, lastEvent: Self.failed(.quotaExceeded), lastSynced: nil) == .off)
    }

    @Test func withAnAccountTheLastSyncSaysHowItGoes() {
        #expect(CloudSync.status(account: .available, lastEvent: nil, lastSynced: nil) == .on(lastSynced: nil))
        let success = CloudSync.Event(succeeded: true, error: nil, endDate: Self.synced)
        #expect(CloudSync.status(account: .available, lastEvent: success, lastSynced: Self.synced) == .on(lastSynced: Self.synced))
        #expect(CloudSync.status(account: .available, lastEvent: Self.failed(.quotaExceeded), lastSynced: Self.synced) == .full)
        #expect(CloudSync.status(account: .available, lastEvent: Self.failed(.networkUnavailable), lastSynced: nil) == .offline)
        #expect(CloudSync.status(account: .available, lastEvent: Self.failed(.networkFailure), lastSynced: nil) == .offline)
        #expect(CloudSync.status(account: .available, lastEvent: Self.failed(.notAuthenticated), lastSynced: nil) == .unavailable)
        #expect(CloudSync.status(account: .available, lastEvent: Self.failed(.serverRejectedRequest), lastSynced: nil) == .failed)
        #expect(CloudSync.status(account: .available, lastEvent: Self.failed(nil), lastSynced: nil) == .failed)
    }

    @Test func aSuccessAfterAFailureClearsIt() async {
        let sync = CloudSync { .available }
        await sync.refreshAccount()
        sync.record(Self.failed(.quotaExceeded))
        #expect(sync.status == .full)

        let later = Self.synced.addingTimeInterval(600)
        sync.record(CloudSync.Event(succeeded: true, error: nil, endDate: later))
        #expect(sync.status == .on(lastSynced: later))

        // A later failure keeps the time of the last sync that worked.
        sync.record(Self.failed(.networkUnavailable))
        #expect(sync.status == .offline)
        sync.record(CloudSync.Event(succeeded: true, error: nil, endDate: later.addingTimeInterval(60)))
        #expect(sync.status == .on(lastSynced: later.addingTimeInterval(60)))
    }

    /// The reader signs in to iCloud while Loe runs: iCloud says the account
    /// changed, and Loe asks again.
    @Test func theAccountIsAskedAgainWhenItChanges() async throws {
        let account = Mutex(CKAccountStatus.noAccount)
        let sync = CloudSync { account.withLock { $0 } }
        #expect(sync.status == .checking)
        await sync.start()
        #expect(sync.status == .off)

        account.withLock { $0 = .available }
        NotificationCenter.default.post(name: .CKAccountChanged, object: nil)
        let deadline = ContinuousClock.now + .seconds(5)
        while sync.status == .off, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(sync.status == .on(lastSynced: nil))
    }

    @Test func anAccountThatNeverAnswersStopsBeingChecked() async {
        let silent = await CloudSync.answer(within: .milliseconds(50)) {
            try? await Task.sleep(for: .seconds(30))
            return .available
        }
        #expect(silent == .couldNotDetermine)
        let quick = await CloudSync.answer(within: .seconds(5)) { .noAccount }
        #expect(quick == .noAccount)
    }

    @Test func aFullICloudIsFoundInsideWhatCoreDataReports() {
        let quota = CKError(.quotaExceeded) as NSError
        let other = CKError(.serverRecordChanged) as NSError
        let partial = NSError(domain: CKError.errorDomain, code: CKError.Code.partialFailure.rawValue, userInfo: [
            CKPartialErrorsByItemIDKey: ["a": other, "b": quota] as [AnyHashable: any Error],
        ])
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134_400, userInfo: [NSUnderlyingErrorKey: partial])

        #expect(CloudSync.cloudKitCode(of: wrapped) == .quotaExceeded)
        #expect(CloudSync.cloudKitCode(of: CKError(.networkUnavailable)) == .networkUnavailable)
        #expect(CloudSync.cloudKitCode(of: NSError(domain: NSCocoaErrorDomain, code: 1)) == nil)
        #expect(CloudSync.cloudKitCode(of: nil) == nil)
    }
}

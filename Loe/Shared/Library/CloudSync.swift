import CloudKit
import CoreData
import Observation
import Synchronization

/// Whether the shelves are reaching the reader's iCloud, worked out from their
/// account and the last sync SwiftData reported. Loe has no account of its own,
/// so this is all there is to sign in to.
@Observable
final class CloudSync {
    enum Status: Equatable {
        case checking
        case on(lastSynced: Date?)
        case off
        case restricted
        case unavailable
        case full
        case offline
        case failed
    }

    /// How one import or export ended, as far as the status needs it.
    nonisolated struct Event: Equatable, Sendable {
        var succeeded: Bool
        var error: CKError.Code?
        var endDate: Date
    }

    private(set) var account: CKAccountStatus?
    private(set) var lastEvent: Event?
    private(set) var lastSynced: Date?
    private let accountStatus: @Sendable () async -> CKAccountStatus
    private var observers: [any NSObjectProtocol] = []

    var status: Status {
        Self.status(account: account, lastEvent: lastEvent, lastSynced: lastSynced)
    }

    init(accountStatus: @escaping @Sendable () async -> CKAccountStatus = CloudSync.liveAccountStatus) {
        self.accountStatus = accountStatus
    }

    /// Listens for account changes and finished syncs for as long as the app runs.
    func start() async {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { _ in
            Task { @MainActor in await self.refreshAccount() }
        })
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { notification in
            guard let event = Self.event(from: notification) else { return }
            MainActor.assumeIsolated { self.record(event) }
        })
        await refreshAccount()
    }

    func refreshAccount() async {
        account = await accountStatus()
    }

    func record(_ event: Event) {
        lastEvent = event
        if event.succeeded { lastSynced = event.endDate }
    }

    nonisolated static func status(account: CKAccountStatus?, lastEvent: Event?, lastSynced: Date?) -> Status {
        switch account {
        case nil: return .checking
        case .noAccount: return .off
        case .restricted: return .restricted
        case .available: break
        default: return .unavailable
        }
        guard let lastEvent, !lastEvent.succeeded else { return .on(lastSynced: lastSynced) }
        switch lastEvent.error {
        case .quotaExceeded: return .full
        case .networkUnavailable, .networkFailure: return .offline
        case .notAuthenticated: return .unavailable
        default: return .failed
        }
    }

    /// The CloudKit reason behind a sync error. Core Data wraps it, and a batch
    /// reports each record's own reason, where a full iCloud is what the reader
    /// can act on.
    nonisolated static func cloudKitCode(of error: (any Error)?) -> CKError.Code? {
        guard let error else { return nil }
        let nsError = error as NSError
        guard nsError.domain == CKError.errorDomain else {
            return cloudKitCode(of: nsError.userInfo[NSUnderlyingErrorKey] as? any Error)
        }
        let code = CKError.Code(rawValue: nsError.code)
        if code == .partialFailure, let partial = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: any Error] {
            let codes = partial.values.compactMap { cloudKitCode(of: $0) }
            return codes.first { $0 == .quotaExceeded } ?? codes.first ?? code
        }
        return code
    }

    nonisolated private static func event(from notification: Notification) -> Event? {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event,
            let endDate = event.endDate
        else { return nil }
        return Event(succeeded: event.succeeded, error: cloudKitCode(of: event.error), endDate: endDate)
    }

    nonisolated static let liveAccountStatus: @Sendable () async -> CKAccountStatus = {
        await answer(within: .seconds(5)) {
            (try? await CKContainer(identifier: LibraryStore.cloudKitContainer).accountStatus()) ?? .couldNotDetermine
        }
    }

    /// The account's status, or "could not determine" once `limit` passes. iCloud
    /// can leave the question unanswered, and Settings must not say "Checking"
    /// for ever. A late answer is dropped, and the next refresh asks again.
    nonisolated static func answer(
        within limit: Duration,
        _ ask: @escaping @Sendable () async -> CKAccountStatus
    ) async -> CKAccountStatus {
        await withCheckedContinuation { continuation in
            let answered = Mutex(false)
            let finish: @Sendable (CKAccountStatus) -> Void = { status in
                let first = answered.withLock { done in
                    defer { done = true }
                    return !done
                }
                if first { continuation.resume(returning: status) }
            }
            Task { finish(await ask()) }
            Task {
                try? await Task.sleep(for: limit)
                finish(.couldNotDetermine)
            }
        }
    }
}

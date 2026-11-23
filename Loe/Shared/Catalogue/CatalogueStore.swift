import Foundation
import Observation

/// Whether the catalogue is on this phone, the open catalogue when it is, and
/// downloading, updating or removing it.
@Observable
final class CatalogueStore {
    enum State {
        case missing
        case ready(Catalogue)
        case unreadable
    }

    enum Download: Equatable {
        case inProgress(Double)
        case failed
    }

    /// What came of the reader asking for a new edition in Settings.
    enum Check: Equatable {
        case checking
        case upToDate
        case updated
        case needsNewerLoe
        case failed
    }

    private(set) var state: State = .missing
    private(set) var download: Download?
    private(set) var check: Check?
    private var updatingQuietly = false
    let url: URL
    private let downloader: CatalogueDownloader
    private let defaults: UserDefaults

    private static let versionKey = "catalogueVersion"
    private static let checkedKey = "catalogueCheckedForUpdate"
    nonisolated private static let updateInterval: TimeInterval = 7 * 24 * 60 * 60

    nonisolated static var defaultURL: URL {
        #if DEBUG
        // Lets a journey search a small catalogue of its own. See docs/catalogue.md.
        if let file = UserDefaults.standard.string(forKey: "catalogueFile") {
            return URL(filePath: file)
        }
        #endif
        return URL.applicationSupportDirectory.appending(path: "Catalogue/catalogue.sqlite")
    }

    init(url: URL = defaultURL, downloader: CatalogueDownloader = .live, defaults: UserDefaults = .standard) {
        self.url = url
        self.downloader = downloader
        self.defaults = defaults
        reload()
    }

    var installedVersion: String? {
        defaults.string(forKey: Self.versionKey)
    }

    /// When Loe last heard which edition is the newest.
    var lastChecked: Date? {
        defaults.object(forKey: Self.checkedKey) as? Date
    }

    /// The catalogue's size on the phone, unpacked. Read from the file each time,
    /// as a URL keeps the size it first saw.
    var sizeOnDisk: Int? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int
    }

    /// Something is downloading or replacing the file, so it must not be removed.
    var isBusy: Bool {
        if case .inProgress = download { return true }
        return check == .checking || updatingQuietly
    }

    func reload() {
        guard FileManager.default.fileExists(atPath: url.path) else {
            state = .missing
            return
        }
        do {
            state = .ready(try Catalogue(url: url))
        } catch {
            state = .unreadable
        }
    }

    /// The first download, which the reader starts, so it may use mobile data.
    func downloadCatalogue() async {
        guard !isBusy else { return }
        download = .inProgress(0)
        do {
            let manifest = try await downloader.manifest()
            try await downloader.install(manifest, at: url) { fraction in
                Task { @MainActor in
                    if case .inProgress = self.download { self.download = .inProgress(fraction) }
                }
            }
            defaults.set(manifest.version, forKey: Self.versionKey)
            download = nil
            reload()
        } catch {
            download = .failed
        }
    }

    /// Looks for a newer catalogue at most once a week, and fetches it quietly over
    /// Wi-Fi. The catalogue in use stays until the new one is checked and in place.
    func updateIfDue(now: Date = .now) async {
        guard case .ready = state, !isBusy, Self.isUpdateCheckDue(lastChecked: lastChecked, now: now) else { return }
        updatingQuietly = true
        defer { updatingQuietly = false }
        // Offline, the check counts for nothing and the next launch asks again.
        guard let manifest = try? await downloader.manifest() else { return }
        defaults.set(now, forKey: Self.checkedKey)
        guard manifest.version != installedVersion, manifest.schemaVersion == Catalogue.schemaVersion else { return }
        do {
            try await downloader.install(manifest, at: url, allowsCellular: false)
            defaults.set(manifest.version, forKey: Self.versionKey)
            reload()
        } catch {
            // The next check tries again. The reader keeps the catalogue they have.
        }
    }

    /// The reader asked for a new edition, so it may use mobile data, and says what
    /// came of it.
    func checkNow(now: Date = .now) async {
        guard case .ready = state, !isBusy else { return }
        check = .checking
        do {
            let manifest = try await downloader.manifest()
            defaults.set(now, forKey: Self.checkedKey)
            guard manifest.schemaVersion == Catalogue.schemaVersion else {
                check = .needsNewerLoe
                return
            }
            guard manifest.version != installedVersion else {
                check = .upToDate
                return
            }
            download = .inProgress(0)
            try await downloader.install(manifest, at: url) { fraction in
                Task { @MainActor in
                    if case .inProgress = self.download { self.download = .inProgress(fraction) }
                }
            }
            defaults.set(manifest.version, forKey: Self.versionKey)
            download = nil
            reload()
            check = .updated
        } catch {
            download = nil
            check = .failed
        }
    }

    /// Frees the space. Search asks to download it again, and the shelves keep
    /// everything they need.
    func remove() throws {
        guard !isBusy else { return }
        state = .missing
        check = nil
        download = nil
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        defaults.removeObject(forKey: Self.versionKey)
        defaults.removeObject(forKey: Self.checkedKey)
    }

    nonisolated static func isUpdateCheckDue(lastChecked: Date?, now: Date) -> Bool {
        guard let lastChecked else { return true }
        return now.timeIntervalSince(lastChecked) >= updateInterval
    }
}

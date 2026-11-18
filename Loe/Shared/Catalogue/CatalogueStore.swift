import Foundation
import Observation

/// Whether the catalogue is on this phone, the open catalogue when it is, and
/// downloading or updating it.
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

    private(set) var state: State = .missing
    private(set) var download: Download?
    let url: URL
    private let downloader: CatalogueDownloader
    private let defaults: UserDefaults

    private static let versionKey = "catalogueVersion"
    private static let checkedKey = "catalogueCheckedForUpdate"
    nonisolated private static let updateInterval: TimeInterval = 7 * 24 * 60 * 60

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Catalogue/catalogue.sqlite")
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
        if case .inProgress = download { return }
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
        guard case .ready = state, download == nil,
              Self.isUpdateCheckDue(lastChecked: defaults.object(forKey: Self.checkedKey) as? Date, now: now)
        else { return }
        defaults.set(now, forKey: Self.checkedKey)
        guard let manifest = try? await downloader.manifest(),
              manifest.version != installedVersion,
              manifest.schemaVersion == Catalogue.schemaVersion
        else { return }
        do {
            try await downloader.install(manifest, at: url, allowsCellular: false)
            defaults.set(manifest.version, forKey: Self.versionKey)
            reload()
        } catch {
            // The next check tries again. The reader keeps the catalogue they have.
        }
    }

    nonisolated static func isUpdateCheckDue(lastChecked: Date?, now: Date) -> Bool {
        guard let lastChecked else { return true }
        return now.timeIntervalSince(lastChecked) >= updateInterval
    }
}

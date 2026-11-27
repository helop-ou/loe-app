import Foundation
import Observation

/// Whether the catalogue is on this phone, the open catalogue when it is, and
/// fetching it and keeping it up to date.
@Observable
final class CatalogueStore {
    enum State {
        case missing
        case ready(Catalogue)
        case unreadable
    }

    enum Download: Equatable {
        case inProgress(Double)
        /// The download nobody asked for found only mobile data or Low Data Mode,
        /// which it leaves alone until the reader says otherwise.
        case waitingForWiFi
        case failed
        /// Every catalogue there is needs a newer Loe than this one.
        case needsNewerLoe
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
    /// False once a manifest has turned off everything Loe asks ESTER.
    private(set) var asksESTER: Bool
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
        asksESTER = ESTERSwitch.isOn(in: defaults)
        CatalogueDownloader.removeLeftovers(beside: url)
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

    /// Something is downloading or replacing the file, so nothing else may start.
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

    /// Every manifest that is read says whether ESTER may be asked, and the last
    /// word is kept for the launches until the next one.
    private func heard(_ manifest: CatalogueManifest) {
        defaults.set(manifest.asksESTER, forKey: ESTERSwitch.key)
        asksESTER = ESTERSwitch.isOn(in: defaults)
    }

    /// What a launch does, and coming back to the front. A phone with no catalogue
    /// it can read fetches one without being asked, quietly, and tries again each
    /// time until it has it. A phone that has one looks for a newer edition.
    func keepUp(now: Date = .now) async {
        if case .ready = state {
            await updateIfDue(now: now)
        } else {
            await download(quietly: true)
        }
    }

    /// The reader asked for the catalogue, so it may use mobile data and Low Data Mode.
    func downloadCatalogue() async {
        await download(quietly: false)
    }

    private func download(quietly: Bool) async {
        guard !isBusy else { return }
        download = .inProgress(0)
        do {
            let manifest = try await downloader.manifest()
            heard(manifest)
            guard let published = manifest.catalogue(forSchema: Catalogue.schemaVersion) else {
                download = manifest.hasCatalogue(newerThanSchema: Catalogue.schemaVersion) ? .needsNewerLoe : .failed
                return
            }
            try await downloader.install(published, at: url, quietly: quietly) { fraction in
                Task { @MainActor in
                    if case .inProgress = self.download { self.download = .inProgress(fraction) }
                }
            }
            defaults.set(published.version, forKey: Self.versionKey)
            download = nil
            reload()
        } catch {
            download = quietly && CatalogueDownloader.waitsForWiFi(error) ? .waitingForWiFi : .failed
        }
    }

    /// Reads the manifest at most once a week, with or without a catalogue on the
    /// phone, since it also says whether ESTER may be asked. When there is a newer
    /// catalogue of the schema this build reads, it is fetched quietly, and the
    /// catalogue in use stays until the new one is checked and in place. A check
    /// counts once there is nothing left to fetch, so a catalogue that could not be
    /// fetched is tried again at the next launch and not a week later.
    func updateIfDue(now: Date = .now) async {
        guard !isBusy, Self.isUpdateCheckDue(lastChecked: lastChecked, now: now) else { return }
        updatingQuietly = true
        defer { updatingQuietly = false }
        // Offline, the check counts for nothing and the next launch asks again.
        guard let manifest = try? await downloader.manifest() else { return }
        heard(manifest)
        if case .ready = state,
           let published = manifest.catalogue(forSchema: Catalogue.schemaVersion), published.version != installedVersion {
            do {
                try await downloader.install(published, at: url, quietly: true)
                defaults.set(published.version, forKey: Self.versionKey)
                reload()
            } catch where CatalogueDownloader.couldNotFetch(error) {
                // No network it may use, or one that dropped: not counted.
                return
            } catch {
                // The file itself is wrong, and will be until the manifest changes,
                // so it waits the week. The reader keeps the catalogue they have.
            }
        }
        defaults.set(now, forKey: Self.checkedKey)
    }

    /// The reader asked for a new edition, so it may use mobile data, and says what
    /// came of it. A catalogue for a newer Loe is said so, whether or not this build
    /// found a newer one of its own.
    func checkNow(now: Date = .now) async {
        guard case .ready = state, !isBusy else { return }
        check = .checking
        do {
            let manifest = try await downloader.manifest()
            defaults.set(now, forKey: Self.checkedKey)
            heard(manifest)
            let needsNewerLoe = manifest.hasCatalogue(newerThanSchema: Catalogue.schemaVersion)
            guard let published = manifest.catalogue(forSchema: Catalogue.schemaVersion), published.version != installedVersion else {
                check = needsNewerLoe ? .needsNewerLoe : .upToDate
                return
            }
            download = .inProgress(0)
            try await downloader.install(published, at: url) { fraction in
                Task { @MainActor in
                    if case .inProgress = self.download { self.download = .inProgress(fraction) }
                }
            }
            defaults.set(published.version, forKey: Self.versionKey)
            download = nil
            reload()
            check = needsNewerLoe ? .needsNewerLoe : .updated
        } catch {
            download = nil
            check = .failed
        }
    }

    nonisolated static func isUpdateCheckDue(lastChecked: Date?, now: Date) -> Bool {
        guard let lastChecked else { return true }
        return now.timeIntervalSince(lastChecked) >= updateInterval
    }
}

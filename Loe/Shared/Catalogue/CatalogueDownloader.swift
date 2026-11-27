import Compression
import CryptoKit
import Foundation
import Synchronization

/// Fetches the manifest, then downloads, checks and unpacks a catalogue it names.
nonisolated struct CatalogueDownloader: Sendable {
    enum Failure: Error, Equatable {
        case badResponse(Int)
        case unsupportedSchema(Int)
        case checksumMismatch
    }

    static let manifestURL = URL(string: "https://raw.githubusercontent.com/helop-ou/loe-app/main/tools/catalogue/manifest.json")!

    let manifestURL: URL
    let session: URLSession

    private static let liveSession = PrivateSession.make(timeout: 60)

    static var live: CatalogueDownloader {
        var url = manifestURL
        #if DEBUG
        // Lets a simulator fetch a catalogue served from the Mac. See docs/catalogue.md.
        if let override = UserDefaults.standard.string(forKey: "catalogueManifestURL"), let local = URL(string: override) {
            url = local
        }
        #endif
        return CatalogueDownloader(manifestURL: url, session: liveSession)
    }

    func manifest() async throws -> CatalogueManifest {
        let request = URLRequest(url: manifestURL, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await session.data(for: request)
        try Self.check(response)
        return try JSONDecoder().decode(CatalogueManifest.self, from: data)
    }

    /// Replaces the file at `destination` only once the new catalogue has passed its
    /// checksum and opened, so a failed download never costs the reader the old one.
    func install(
        _ published: PublishedCatalogue,
        at destination: URL,
        allowsCellular: Bool = true,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws {
        guard published.schemaVersion == Catalogue.schemaVersion else {
            throw Failure.unsupportedSchema(published.schemaVersion)
        }
        var request = URLRequest(url: published.url)
        request.allowsExpensiveNetworkAccess = allowsCellular
        let (downloaded, response) = try await session.download(for: request, delegate: ProgressRelay(progress))
        defer { try? FileManager.default.removeItem(at: downloaded) }
        try Self.check(response)
        guard try Self.sha256(of: downloaded) == published.sha256 else {
            throw Failure.checksumMismatch
        }

        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let unpacked = folder.appending(path: "\(UUID().uuidString).partial")
        defer { try? FileManager.default.removeItem(at: unpacked) }
        try Self.unpack(downloaded, to: unpacked)
        _ = try Catalogue(url: unpacked)

        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: unpacked)
        } else {
            try FileManager.default.moveItem(at: unpacked, to: destination)
        }
        // It can be downloaded again, so it stays out of the reader's iCloud backup.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var installed = destination
        try installed.setResourceValues(values)
    }

    /// Whether an install failed before the file arrived: no network it may use,
    /// one that dropped, or a server that did not serve it. Such a download is
    /// worth trying again soon. A file that arrived and is wrong is not.
    static func couldNotFetch(_ error: any Error) -> Bool {
        if case Failure.badResponse = error { return true }
        return error is URLError
    }

    private static func check(_ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure.badResponse(status) }
    }

    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Unpacks an xz file, streaming, so the 120 MB catalogue never sits in memory.
    static func unpack(_ source: URL, to destination: URL) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        let filter = try OutputFilter(.decompress, using: .lzma) { data in
            if let data { try output.write(contentsOf: data) }
        }
        while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
            try filter.write(chunk)
        }
        try filter.finalize()
    }
}

/// Reports a download's progress, which the async download API does not surface itself.
private nonisolated final class ProgressRelay: NSObject, URLSessionTaskDelegate, Sendable {
    private let report: @Sendable (Double) -> Void
    private let observation = Mutex<NSKeyValueObservation?>(nil)

    init(_ report: @escaping @Sendable (Double) -> Void) {
        self.report = report
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let report = report
        let observing = task.progress.observe(\.fractionCompleted) { progress, _ in
            report(progress.fractionCompleted)
        }
        observation.withLock { $0 = observing }
    }
}

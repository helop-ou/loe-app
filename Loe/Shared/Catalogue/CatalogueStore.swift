import Foundation
import Observation

/// Whether the catalogue is on this phone, and the open catalogue when it is.
@Observable
final class CatalogueStore {
    enum State {
        case missing
        case ready(Catalogue)
        case unreadable
    }

    private(set) var state: State = .missing
    let url: URL

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Catalogue/catalogue.sqlite")
    }

    init(url: URL = defaultURL) {
        self.url = url
        reload()
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
}

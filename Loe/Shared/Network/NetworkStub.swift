#if DEBUG
import Foundation

/// Debug builds launched with `-networkStub YES` never reach the network, so a
/// journey or a test sees the same answers every time. Open Library, its covers
/// and ESTER answer from what their clients keep for it, and every other request
/// fails as it does with no network. See docs/standards.md, "Review and verification".
nonisolated enum NetworkStub {
    static var isOn: Bool {
        UserDefaults.standard.bool(forKey: "networkStub")
    }

    /// Fails every request of a session that is given it.
    nonisolated final class Unreachable: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        }

        override func stopLoading() {}
    }
}
#endif

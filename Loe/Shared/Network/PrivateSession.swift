import Foundation

/// The session every client asks through. It keeps no cookies, cache or
/// credentials, and its headers say which app is asking and nothing about the
/// reader. See docs/release.md, "Privacy".
nonisolated enum PrivateSession {
    /// Sites ask apps to name themselves and give a contact.
    static let userAgent = "Loe/\(LoeProject.version) (\(LoeProject.repository.absoluteString); \(LoeProject.contact))"

    static func configuration(timeout: TimeInterval) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = timeout
        // Otherwise the system sends the reader's own preferred languages.
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent, "Accept-Language": "en"]
        return configuration
    }

    static func make(timeout: TimeInterval) -> URLSession {
        let configuration = configuration(timeout: timeout)
        #if DEBUG
        if NetworkStub.isOn { configuration.protocolClasses = [NetworkStub.Unreachable.self] }
        #endif
        return URLSession(configuration: configuration)
    }
}

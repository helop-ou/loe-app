import Foundation
import Testing
@testable import Loe

struct PrivateSessionTests {
    @Test func itKeepsNoCookiesCacheOrCredentials() {
        let configuration = PrivateSession.configuration(timeout: 10)
        #expect(configuration.httpCookieAcceptPolicy == .never)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.urlCache == nil)
        #expect(configuration.urlCredentialStorage == nil)
    }

    @Test func itNamesTheAppAndNothingAboutTheReader() throws {
        let headers = try #require(PrivateSession.configuration(timeout: 10).httpAdditionalHeaders as? [String: String])
        #expect(headers.count == 2)
        let agent = try #require(headers["User-Agent"])
        #expect(agent.hasPrefix("Loe/"))
        #expect(agent.contains("https://github.com/helop-ou/loe-app"))
        #expect(agent.contains("kontakt@helop.ee"))
        #expect(headers["Accept-Language"] == "en")
    }

    @Test func itKeepsTheTimeoutItIsGiven() {
        #expect(PrivateSession.configuration(timeout: 15).timeoutIntervalForRequest == 15)
        #expect(PrivateSession.make(timeout: 15).configuration.timeoutIntervalForRequest == 15)
    }

    @Test func everyClientAsksThroughIt() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = root.appending(path: "Loe")
        let enumerator = try #require(FileManager.default.enumerator(at: source, includingPropertiesForKeys: nil))
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(files.count > 50)
        for file in files where !file.path.hasSuffix("/Shared/Network/PrivateSession.swift") {
            let text = try String(contentsOf: file, encoding: .utf8)
            for forbidden in ["URLSession.shared", "session: .shared", "URLSession(", "URLSessionConfiguration"] {
                #expect(!text.contains(forbidden), "\(file.path) builds its own session with \(forbidden)")
            }
        }
    }
}

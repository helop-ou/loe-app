import Foundation
import Testing
@testable import Loe

struct NetworkStubTests {
    @Test func aSessionGivenItFailsEveryRequestAsWithNoNetwork() async {
        let configuration = PrivateSession.configuration(timeout: 5)
        configuration.protocolClasses = [NetworkStub.Unreachable.self]
        let session = URLSession(configuration: configuration)
        // A name that never resolves, so nothing is reached even when this fails.
        let error = await #expect(throws: URLError.self) {
            _ = try await session.data(from: URL(string: "https://loe.invalid/search.json?q=halo")!)
        }
        #expect(error?.code == .notConnectedToInternet)
    }
}

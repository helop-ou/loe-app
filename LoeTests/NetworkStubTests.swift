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

    /// The scheme passes `-networkStub YES` to the app that hosts these tests.
    @Test func theAppThatHostsTheTestsIsOffTheNetwork() async {
        #expect(NetworkStub.isOn)
        let error = await #expect(throws: URLError.self) {
            _ = try await PrivateSession.make(timeout: 5).data(from: URL(string: "https://loe.invalid/")!)
        }
        #expect(error?.code == .notConnectedToInternet)
    }

    /// The journeys count on each of the app's own clients answering for itself.
    @Test func theAppsOwnClientsAnswerWithoutAskingAnyone() async throws {
        try #require(NetworkStub.isOn)
        let halo = try await OpenLibrary.live.search("halo")
        #expect(halo.map(\.title) == ["Halo: The Fall of Reach"])
        // One book from abroad says what it is about and one, as on Open Library, doesn't.
        let hailMary = try await OpenLibrary.live.description(of: OpenLibraryRecord(workKey: "/works/OL21745884W"))
        #expect(hailMary?.hasPrefix("A teacher wakes up alone") == true)
        #expect(hailMary?.contains("Also contained in") == false)
        #expect(hailMary.map { $0.count > BookDescription.short } == true)
        #expect(try await OpenLibrary.live.description(of: try #require(halo.first).record) == nil)
        #expect(await Covers.live.cover(.id(210551)) != nil)
        #expect(await Covers.live.cover(.isbn("9780345451323")) == nil)
        // ESTER has a cover and a summary of its own for one book, and nothing for the rest.
        let aveMaria = CoverArt.ester(["b5469156", "b5454324"], title: "Ave Maria")
        #expect(await Covers.live.cover(aveMaria) != nil)
        #expect(await Covers.live.description(for: aveMaria)?.hasPrefix("Õpetaja ärkab üksi") == true)
        #expect(await Covers.live.cover(.ester(["b1054421"], title: "Keisri hull")) == nil)
        #expect(await Covers.live.description(for: .ester(["b1054421"], title: "Keisri hull")) == nil)
        let edition = CatalogueEdition(id: 1, erbID: "b10544215", title: "Keisri hull")
        let copies = await AvailabilityChecker.live.copies(of: [edition])
        #expect(copies?["b10544215"]?.map(\.state) == [.onShelf])
    }
}

import Foundation
import SwiftData
import Testing
@testable import Loe

@MainActor
struct TasteTests {
    private let context: ModelContext
    private let monday = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        let container = try ModelContainer(
            for: ShelvedBook.self, Taste.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }

    private func all() throws -> [Taste] {
        try context.fetch(FetchDescriptor<Taste>())
    }

    @Test func settingTastesAddsAndRemovesRecords() throws {
        try Taste.set([.crime, .fantasy], in: context, now: monday)
        #expect(Taste.genres(try all()) == [.crime, .fantasy])
        try Taste.set([.fantasy, .poetry], in: context, now: monday)
        #expect(Taste.genres(try all()) == [.fantasy, .poetry])
        #expect(try all().count == 2)
    }

    @Test func aGenreKeepsTheRecordItAlreadyHad() throws {
        try Taste.set([.crime], in: context, now: monday)
        try Taste.set([.crime, .horror], in: context, now: monday.addingTimeInterval(60))
        let crime = try #require(try all().first { $0.genre == .crime })
        #expect(crime.addedAt == monday)
    }

    @Test func aSecondRecordOfAGenreFromAnotherDeviceGoes() throws {
        context.insert(Taste(genre: .crime, now: monday))
        context.insert(Taste(genre: .crime, now: monday.addingTimeInterval(60)))
        try Taste.set([.crime], in: context)
        let left = try all()
        #expect(left.count == 1)
        #expect(left.first?.addedAt == monday)
    }

    @Test func aGenreFromANewerVersionIsKept() throws {
        let future = Taste(genre: .crime)
        future.genreName = "cosyMysteries"
        context.insert(future)
        try Taste.set([], in: context)
        #expect(try all().map(\.genreName) == ["cosyMysteries"])
        #expect(Taste.genres(try all()).isEmpty)
    }

    @Test func genresComeInTheQuizsOrder() {
        let tastes = [Taste(genre: .youngAdult), Taste(genre: .crime), Taste(genre: .romance)]
        #expect(Taste.genres(tastes) == [.crime, .romance, .youngAdult])
    }
}

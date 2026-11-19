import Foundation
import SwiftData
import Testing
@testable import Loe

@MainActor
struct ChosenPlaceTests {
    private let context: ModelContext
    private let kannukuke = Place.withID("ester.tlnrk.kannukuke")!
    private let karlova = Place.withID("ester.tartulr.karlova")!

    init() throws {
        let container = try ModelContainer(
            for: ShelvedBook.self, Taste.self, ChosenPlace.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }

    private func places() throws -> [Place] {
        ChosenPlace.places(try context.fetch(FetchDescriptor<ChosenPlace>()))
    }

    @Test func addedPlacesGoAtTheEndOnceEach() throws {
        try ChosenPlace.add(kannukuke, in: context)
        try ChosenPlace.add(.apollo, in: context)
        try ChosenPlace.add(kannukuke, in: context)
        #expect(try places() == [kannukuke, .apollo])
        #expect(try context.fetch(FetchDescriptor<ChosenPlace>()).count == 2)
    }

    @Test func reorderingKeepsTheReadersOrder() throws {
        try ChosenPlace.add(kannukuke, in: context)
        try ChosenPlace.add(.apollo, in: context)
        try ChosenPlace.add(karlova, in: context)
        try ChosenPlace.reorder([karlova, kannukuke, .apollo], in: context)
        #expect(try places() == [karlova, kannukuke, .apollo])
    }

    @Test func removingTakesEveryCopyFromOtherDevices() throws {
        context.insert(ChosenPlace(place: kannukuke, position: 1))
        context.insert(ChosenPlace(place: kannukuke, position: 2))
        try ChosenPlace.add(.apollo, in: context)
        try ChosenPlace.remove(kannukuke, in: context)
        #expect(try places() == [.apollo])
    }

    @Test func twoDevicesAddingTheSamePlaceShowItOnce() throws {
        context.insert(ChosenPlace(place: kannukuke, position: 1))
        context.insert(ChosenPlace(place: kannukuke, position: 1))
        #expect(try places() == [kannukuke])
    }

    @Test func aPlaceFromANewerVersionIsKeptButNotShown() throws {
        let future = ChosenPlace(place: kannukuke, position: 1)
        future.placeID = "ester.someday"
        context.insert(future)
        try ChosenPlace.add(.apollo, in: context)
        try ChosenPlace.reorder([.apollo], in: context)
        #expect(try places() == [.apollo])
        #expect(future.position == 1)
        #expect(try context.fetch(FetchDescriptor<ChosenPlace>()).count == 2)
    }
}

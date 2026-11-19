import Foundation
import SwiftData

/// A library or bookshop the reader picked for "Where to get it", in their order.
/// One record per place, so two devices cannot clash over a list. Every property
/// has a default, as CloudKit sync requires.
@Model
final class ChosenPlace {
    /// `Place.id`. Read `place`.
    var placeID: String = ""
    /// Smaller comes first.
    var position: Double = 0
    var addedAt: Date = Date.now

    init(place: Place, position: Double, now: Date = .now) {
        placeID = place.id
        self.position = position
        addedAt = now
    }

    /// Nil for a place this version of Loe does not know.
    var place: Place? {
        Place.withID(placeID)
    }
}

extension ChosenPlace {
    /// The reader's places in their order, once each, leaving out unknown ones.
    static func places(_ chosen: [ChosenPlace]) -> [Place] {
        var seen: Set<String> = []
        return chosen
            .sorted { ($0.position, $0.addedAt) < ($1.position, $1.addedAt) }
            .compactMap { seen.insert($0.placeID).inserted ? $0.place : nil }
    }

    /// Adds a place at the end, unless it is already chosen.
    static func add(_ place: Place, in context: ModelContext, now: Date = .now) throws {
        let chosen = try context.fetch(FetchDescriptor<ChosenPlace>())
        guard !chosen.contains(where: { $0.placeID == place.id }) else { return }
        context.insert(ChosenPlace(place: place, position: (chosen.map(\.position).max() ?? 0) + 1, now: now))
    }

    /// Removes every record of a place, including copies from another device.
    static func remove(_ place: Place, in context: ModelContext) throws {
        let id = place.id
        for chosen in try context.fetch(FetchDescriptor<ChosenPlace>(predicate: #Predicate { $0.placeID == id })) {
            context.delete(chosen)
        }
    }

    /// Puts the reader's places in this order. Records for places this version does
    /// not know keep their positions.
    static func reorder(_ places: [Place], in context: ModelContext) throws {
        let chosen = try context.fetch(FetchDescriptor<ChosenPlace>())
        for (index, place) in places.enumerated() {
            for record in chosen where record.placeID == place.id {
                record.position = Double(index + 1)
            }
        }
    }
}

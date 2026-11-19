import Foundation
import SwiftData

/// A kind of book the reader likes, from the quiz or Settings. One record per genre,
/// so two devices that add the same genre while offline cannot clash. Every property
/// has a default, as CloudKit sync requires.
@Model
final class Taste {
    /// Stored by name. Read `genre`.
    var genreName: String = ""
    var addedAt: Date = Date.now

    init(genre: Genre, now: Date = .now) {
        genreName = genre.rawValue
        addedAt = now
    }

    /// Nil for a genre a newer version of Loe added.
    var genre: Genre? {
        Genre(rawValue: genreName)
    }
}

extension Taste {
    /// The genres the reader likes, once each, in the quiz's order.
    static func genres(_ tastes: [Taste]) -> [Genre] {
        let liked = Set(tastes.compactMap(\.genre))
        return Genre.allCases.filter(liked.contains)
    }

    /// Makes the reader's tastes these genres, adding and removing records as needed.
    static func set(_ genres: Set<Genre>, in context: ModelContext, now: Date = .now) throws {
        var kept: Set<Genre> = []
        for taste in try context.fetch(FetchDescriptor<Taste>(sortBy: [SortDescriptor(\.addedAt)])) {
            guard let genre = taste.genre else { continue }
            // A genre no longer liked goes, and so does a second record of one from another device.
            if !genres.contains(genre) || !kept.insert(genre).inserted {
                context.delete(taste)
            }
        }
        for genre in Genre.allCases where genres.contains(genre) && !kept.contains(genre) {
            context.insert(Taste(genre: genre, now: now))
        }
    }
}

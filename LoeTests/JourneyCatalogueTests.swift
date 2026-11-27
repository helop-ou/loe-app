import Foundation
import Testing
@testable import Loe

/// What each journey needs from the catalogue in LoeUITests/Fixtures. A change to
/// its records, to the schema or to how books are matched fails here first, and
/// says which book went missing.
struct JourneyCatalogueTests {
    private let catalogue: Catalogue

    init() throws {
        catalogue = try Catalogue(url: CatalogueFixture.journeys())
    }

    private func found(_ text: String) async throws -> CatalogueWork {
        try #require(try await catalogue.search(text).first, "Nothing found for \(text)")
    }

    @Test func keisriHullIsFoundWithItsRecordItsTranslationAndOthersByItsAuthor() async throws {
        let work = try await found("keisri hull")
        #expect(work.title == "Keisri hull")
        #expect(work.authors == "Jaan Kross")
        let details = try await catalogue.details(for: work)
        #expect(details.translations.contains { $0.title == "The czar's madman" })
        #expect(!details.sameAuthor.isEmpty)
        // The record the duplicates journey shelves, which ESTER can be asked about.
        #expect(details.editions.contains { $0.erbID == "b10544215" })
        #expect(details.editions.contains { ESTERHoldings.url(erbID: $0.erbID) != nil })
    }

    /// The search journey reads these on the book's page, by their English names.
    @Test func keisriHullHasItsGenresAsTags() async throws {
        let details = try await catalogue.details(for: found("keisri hull"))
        #expect(Set(details.tags) == ["ajaloolised romaanid", "biograafilised romaanid"])
    }

    /// The shelves journey types the page count itself, into an empty field.
    @Test func keisriHullsNewestEditionHasNoPageCount() async throws {
        let details = try await catalogue.details(for: found("keisri hull"))
        let newest = try #require(details.editions.first)
        #expect(newest.year == 2017)
        #expect(newest.pages == nil)
    }

    @Test func kevadeHasSimilarSchoolStories() async throws {
        let details = try await catalogue.details(for: found("kevade luts"))
        #expect(details.similar.count >= 3)
        #expect(details.similar.allSatisfy { $0.reason == "koolijutud" })
    }

    /// Read next keeps one suggestion for later and still has another to show.
    @Test func kevadeLeadsToSeveralBooks() async throws {
        let details = try await catalogue.details(for: found("kevade luts"))
        #expect(details.sameAuthor.count >= 2)
        #expect(details.sameAuthor.count + details.similar.count >= 4)
    }

    @Test func theTastesTheQuizJourneyPicksFindBooksInEstonian() async throws {
        for genre in [Genre.crime, .fantasy] {
            let works = try await catalogue.works(withHeadings: genre.headings, language: "est", limit: 10)
            #expect(works.count >= 2, "\(genre)")
        }
    }

    /// The stubbed Open Library answers "hail mary" with this book.
    @Test func projectHailMaryFromOpenLibraryHasItsEstonianTranslation() async throws {
        let book = OpenLibraryBook(
            record: OpenLibraryRecord(workKey: "/works/OL21745884W"), title: "Project Hail Mary", authors: ["Andy Weir"]
        )
        let details = try await catalogue.details(for: book.work)
        let translation = try #require(details.translations.first)
        #expect(translation.title == "Ave Maria")
        #expect(translation.editions.contains { ESTERHoldings.url(erbID: $0.erbID) != nil })
        // And the author's other books in Estonian, without the translation itself.
        #expect(Set(details.sameAuthor.map(\.title)) == ["Marslane", "Artemis"])
        #expect(details.sameAuthorIsInEstonian)
    }

    @Test func itHoldsTheISBNTheSearchJourneyTypes() async throws {
        #expect(try await !catalogue.search("978-9949-633-28-9").isEmpty)
    }

    /// Each of these is a search a journey expects the catalogue to have no answer
    /// for: the missing ISBNs, the book added by hand, and the books from abroad.
    @Test(arguments: [
        "0-306-40615-2", "9780306406157", "9780345451323", "qqxxzzqq", "Recipes from Grandma Tiiu",
        "Halo: The Fall of Reach", "offline reading",
    ])
    func itHasNoAnswerWhereAJourneyExpectsNone(text: String) async throws {
        #expect(try await catalogue.search(text).isEmpty)
    }
}

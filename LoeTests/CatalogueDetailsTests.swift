import Foundation
import Testing
@testable import Loe

struct CatalogueDetailsTests {
    private static let books = """
        (1, 'b1', 'Keisri hull', 'Jaan Kross', 1978, 1, 0, NULL, 'est', NULL, NULL),
        (2, 'b2', 'Keisri hull', 'Jaan Kross', 2017, 1, 0, NULL, 'est', NULL, NULL),
        (3, 'b3', 'The czar''s madman', 'Jaan Kross', 1992, 1, 0, 'Keisri hull', 'eng', 'est', NULL),
        (4, 'b4', 'Der Verrückte des Zaren', 'Jaan Kross', 1994, 1, 0, 'Keisri hull', 'ger', 'est', NULL),
        (5, 'b5', 'Kolme katku vahel', 'Jaan Kross', 1970, 1, 0, NULL, 'est', NULL, NULL),
        (6, 'b6', 'Keisri hull', 'Someone Else', 2001, 0, 0, NULL, 'est', NULL, NULL),
        (7, 'b7', 'Professor Martensi ärasõit', 'Jaan Kross', 1984, 1, 0, NULL, 'est', NULL, NULL),
        (8, 'b8', 'Treading air', 'Jaan Kross', 2003, 1, 0, 'Paigallend', 'eng', 'est', NULL)
        """

    private func work(_ query: String, by author: String = "Jaan Kross") async throws -> (Catalogue, CatalogueWork) {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.books))
        let work = try #require(try await catalogue.search(query).first { $0.authors == author })
        return (catalogue, work)
    }

    @Test func listsEveryEditionOfTheWorkNewestFirst() async throws {
        let (catalogue, work) = try await work("keisri hull")
        let details = try await catalogue.details(for: work)
        #expect(details.editions.map(\.year) == [2017, 1978])
    }

    @Test func anOriginalListsItsTranslations() async throws {
        let (catalogue, work) = try await work("keisri hull")
        let details = try await catalogue.details(for: work)
        #expect(Set(details.translations.map(\.title)) == ["The czar's madman", "Der Verrückte des Zaren"])
        #expect(details.original == nil)
    }

    @Test func aTranslationLinksToItsOriginal() async throws {
        let (catalogue, work) = try await work("czar's madman")
        let details = try await catalogue.details(for: work)
        #expect(details.original?.title == "Keisri hull")
        #expect(details.original?.authors == "Jaan Kross")
        #expect(details.original?.editions.count == 2)
    }

    @Test func otherBooksByTheAuthorAreInTheSameLanguage() async throws {
        let (catalogue, work) = try await work("keisri hull")
        let estonian = try await catalogue.details(for: work).sameAuthor.map(\.title)
        #expect(Set(estonian) == ["Kolme katku vahel", "Professor Martensi ärasõit"])

        let (_, english) = try await self.work("czar's madman")
        let inEnglish = try await catalogue.details(for: english).sameAuthor.map(\.title)
        #expect(inEnglish == ["Treading air"])
    }

    @Test func aBookOpenedFromAShelfListsTheAuthorsOtherBooks() async throws {
        // A shelf keeps the title and authors, not the language or the catalogue id.
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.books))
        let edition = CatalogueEdition(id: 0, erbID: "b1", title: "Keisri hull", authors: "Jaan Kross")
        let work = CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
        let sameAuthor = try await catalogue.details(for: work).sameAuthor.map(\.title)
        #expect(Set(sameAuthor) == ["Kolme katku vahel", "Professor Martensi ärasõit"])
    }

    @Test func theSameTitleByAnotherAuthorStaysApart() async throws {
        let (catalogue, work) = try await work("keisri hull", by: "Someone Else")
        let details = try await catalogue.details(for: work)
        #expect(details.editions.map(\.year) == [2001])
        #expect(details.translations.isEmpty)
        #expect(details.sameAuthor.isEmpty)
    }
}

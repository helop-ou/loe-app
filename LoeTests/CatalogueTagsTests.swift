import Foundation
import Testing
@testable import Loe

struct CatalogueTagsTests {
    // A novel in three editions, one of them catalogued as non-fiction, a handbook,
    // and other books under the same headings so that some are rarer than others.
    private static let books = """
        (1, 'b1', 'Keisri hull', 'Jaan Kross', 1978, 1, 0, NULL, 'est', NULL, NULL),
        (2, 'b2', 'Keisri hull', 'Jaan Kross', 1999, 0, 0, NULL, 'est', NULL, NULL),
        (3, 'b3', 'Keisri hull', 'Jaan Kross', 2017, 1, 1, NULL, 'est', NULL, NULL),
        (4, 'b4', 'Aatomharjumused', 'James Clear', 2019, 0, 0, 'Atomic habits', 'est', 'eng', NULL),
        (5, 'b5', 'Kolme katku vahel', 'Jaan Kross', 1970, 1, 0, NULL, 'est', NULL, NULL),
        (6, 'b6', 'Wikmani poisid', 'Jaan Kross', 1988, 1, 0, NULL, 'est', NULL, NULL),
        (7, 'b7', 'Harjumuse jõud', 'Charles Duhigg', 2013, 0, 0, NULL, 'est', NULL, NULL)
        """

    private static let headings = """
        INSERT INTO heading (id, kind, name) VALUES
          (1, 2, 'ajaloolised romaanid'), (2, 2, 'biograafilised romaanid'), (3, 2, 'ilukirjandus'), (4, 2, 'e-raamatud'),
          (5, 2, 'romaanid'), (6, 1, 'eesti'), (7, 1, 'harjumused'), (8, 1, 'eneseabi'), (9, 2, 'käsiraamatud');
        INSERT INTO edition_heading VALUES
          (1, 1), (1, 2), (1, 3), (1, 6), (2, 1), (2, 2), (2, 5), (2, 6), (3, 1), (3, 3), (3, 4), (3, 6),
          (4, 7), (4, 8), (4, 9), (5, 1), (6, 1), (6, 5), (7, 8), (7, 9), (5, 9), (6, 9);
        """

    private func tags(of query: String) async throws -> [String] {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.books, headings: Self.headings))
        let work = try #require(try await catalogue.search(query).first)
        return try await catalogue.details(for: work).tags
    }

    @Test func aNovelShowsTheGenresMostOfItsEditionsCarryTheRarestFirst() async throws {
        // Two of three editions are biographical novels, and fewer books are. One
        // edition alone is a plain novel or an e-book, and its nationality is a subject.
        #expect(try await tags(of: "keisri hull") == ["biograafilised romaanid", "ajaloolised romaanid"])
    }

    @Test func aHandbookShowsItsKindAndWhatItIsAbout() async throws {
        #expect(try await tags(of: "aatomharjumused") == ["käsiraamatud", "harjumused", "eneseabi"])
    }

    @Test func aBookTheCatalogueDoesNotHoldHasNoTags() async throws {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.books, headings: Self.headings))
        let abroad = OpenLibraryBook(record: .init(workKey: "/works/OL1W"), title: "Piranesi", authors: ["Susanna Clarke"], language: "eng")
        #expect(try await catalogue.details(for: abroad.work).tags.isEmpty)
        let entered = CatalogueEdition(id: 0, erbID: "", title: "Minu raamat", authors: "Keegi Teine")
        let work = CatalogueWork(id: CatalogueWork.key(for: entered), editions: [entered])
        #expect(try await catalogue.details(for: work).tags.isEmpty)
    }
}

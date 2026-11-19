import Foundation
import Testing
@testable import Loe

struct CatalogueSimilarTests {
    // Kevade is a school story. So are three books by others, one of them published
    // twice. A book by Luts himself, one in English and one that isn't fiction share
    // the heading too, and must not be suggested.
    private static let books = """
        (1, 'b1', 'Kevade', 'Oskar Luts', 1912, 1, 0, NULL, 'est', NULL, NULL),
        (2, 'b2', 'Kevade', 'Oskar Luts', 2012, 1, 0, NULL, 'est', NULL, 'Eesti lugu'),
        (3, 'b3', 'Agu Sihvka annab aru', 'Jaan Rannap', 1977, 1, 0, NULL, 'est', NULL, NULL),
        (4, 'b4', 'Agu Sihvka annab aru', 'Jaan Rannap', 2005, 1, 0, NULL, 'est', NULL, NULL),
        (5, 'b5', 'Wikmani poisid', 'Jaan Kross', 1988, 1, 0, NULL, 'est', NULL, NULL),
        (6, 'b6', 'Kooliraamat', 'Indrek Koff', 2010, 1, 0, NULL, 'est', NULL, NULL),
        (7, 'b7', 'Suvi', 'Oskar Luts', 1918, 1, 0, NULL, 'est', NULL, NULL),
        (8, 'b8', 'Spring', 'Someone', 2001, 1, 0, NULL, 'eng', NULL, NULL),
        (9, 'b9', 'Kooli ajalugu', 'Ajaloolane', 1999, 0, 0, NULL, 'est', NULL, NULL),
        (10, 'b10', 'Seitsmes rahukevad', 'Viivi Luik', 1985, 1, 0, NULL, 'est', NULL, 'Eesti lugu'),
        (11, 'b11', 'Tasuja', 'Eduard Bornhöhe', 1880, 1, 0, NULL, 'est', NULL, 'Eesti lugu'),
        (12, 'b12', 'Mahtra sõda', 'Eduard Vilde', 1902, 1, 0, NULL, 'est', NULL, 'Eesti lugu')
        """

    // 1 is koolijutud (school stories), 2 eesti (generic), 3 dramatiseeringud, which
    // only one edition of Kevade carries.
    private static let headings = """
        INSERT INTO heading (id, kind, name) VALUES (1, 2, 'koolijutud'), (2, 1, 'eesti'), (3, 2, 'dramatiseeringud');
        INSERT INTO edition_heading VALUES
          (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1),
          (1, 2), (2, 2), (10, 2), (11, 2), (12, 2),
          (2, 3), (11, 3), (12, 3);
        """

    // Thresholds for a catalogue of twelve books. The series is left out unless a
    // test turns it on.
    private let lenient = Catalogue.SimilarityLimits(
        maximumHeadingEditions: 20, seriesEditions: 50...60, minimumScore: 0, minimumWorks: 1, limit: 10
    )

    private func kevade() async throws -> (Catalogue, CatalogueWork) {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.books, headings: Self.headings))
        let work = try #require(try await catalogue.search("kevade").first { $0.authors == "Oskar Luts" })
        return (catalogue, work)
    }

    @Test func suggestsBooksSharingASpecificHeadingWithTheReason() async throws {
        let (catalogue, work) = try await kevade()
        let similar = try await catalogue.similar(to: work, limits: lenient)
        let byTitle = Dictionary(uniqueKeysWithValues: similar.map { ($0.work.title, $0.reason) })
        #expect(byTitle["Agu Sihvka annab aru"] == "koolijutud")
        #expect(byTitle["Wikmani poisid"] == "koolijutud")
        #expect(byTitle["Kooliraamat"] == "koolijutud")
    }

    @Test func leavesOutTheAuthorOtherLanguagesAndNonFiction() async throws {
        let (catalogue, work) = try await kevade()
        let titles = try await catalogue.similar(to: work, limits: lenient).map(\.work.title)
        #expect(!titles.contains("Suvi"))
        #expect(!titles.contains("Spring"))
        #expect(!titles.contains("Kooli ajalugu"))
        #expect(!titles.contains("Kevade"))
    }

    @Test func aBookPublishedMoreOftenComesFirst() async throws {
        let (catalogue, work) = try await kevade()
        let similar = try await catalogue.similar(to: work, limits: lenient)
        #expect(similar.first?.work.title == "Agu Sihvka annab aru")
    }

    @Test func beingPublishedOftenOutweighsASlightlyCloserMatch() async throws {
        // One Kevade-like book matches on two headings but was published once. The
        // other matches on one and was published three times. Filler books, not
        // fiction, make the second heading common enough to weigh little.
        let filler = (7...20).map { "(\($0), 'b\($0)', 'Muu \($0)', 'Keegi \($0)', 2000, 0, 0, NULL, 'est', NULL, NULL)" }
        let books = """
            (1, 'b1', 'Kevade', 'Oskar Luts', 1912, 1, 0, NULL, 'est', NULL, NULL),
            (2, 'b2', 'Kevade', 'Oskar Luts', 2012, 1, 0, NULL, 'est', NULL, NULL),
            (3, 'b3', 'Once', 'One Author', 2001, 1, 0, NULL, 'est', NULL, NULL),
            (4, 'b4', 'Often', 'Other Author', 1990, 1, 0, NULL, 'est', NULL, NULL),
            (5, 'b5', 'Often', 'Other Author', 2000, 1, 0, NULL, 'est', NULL, NULL),
            (6, 'b6', 'Often', 'Other Author', 2010, 1, 0, NULL, 'est', NULL, NULL),
            """ + filler.joined(separator: ",\n")
        let headings = """
            INSERT INTO heading (id, kind, name) VALUES (1, 2, 'koolijutud'), (2, 1, 'sõprus');
            INSERT INTO edition_heading VALUES (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1),
              (1, 2), (2, 2), (3, 2), (7, 2), (8, 2), (9, 2), (10, 2);
            """
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: books, headings: headings))
        let work = try #require(try await catalogue.search("kevade").first)
        let titles = try await catalogue.similar(to: work, limits: lenient).map(\.work.title)
        #expect(titles == ["Often", "Once"])
    }

    @Test func genericHeadingsAndOddEditionsSuggestNothing() async throws {
        let (catalogue, work) = try await kevade()
        let titles = try await catalogue.similar(to: work, limits: lenient).map(\.work.title)
        // Seitsmes rahukevad shares only "eesti". Tasuja and Mahtra sõda share the
        // dramatisation heading that only one of Kevade's two editions carries.
        #expect(!titles.contains("Seitsmes rahukevad"))
        #expect(!titles.contains("Tasuja"))
        #expect(!titles.contains("Mahtra sõda"))
    }

    @Test func aNarrowSeriesIsASignalToo() async throws {
        let (catalogue, work) = try await kevade()
        var limits = lenient
        limits.seriesEditions = 2...10
        let similar = try await catalogue.similar(to: work, limits: limits)
        #expect(similar.first { $0.work.title == "Seitsmes rahukevad" }?.reason == "Eesti lugu")
    }

    @Test func equalMatchesAreChosenTheSameWayEveryTime() async throws {
        // Two thousand books tie, more than the 400 kept for ranking. The earliest in
        // the catalogue are kept, not whichever the dictionary happens to list first.
        let tied = (100..<2100).map { "(\($0), 'b\($0)', 'Raamat \($0)', 'Autor \($0)', 2000, 1, 0, NULL, 'est', NULL, NULL)" }
        let books = """
            (1, 'b1', 'Kevade', 'Oskar Luts', 1912, 1, 0, NULL, 'est', NULL, NULL),
            """ + tied.joined(separator: ",\n")
        let headings = """
            INSERT INTO heading (id, kind, name) VALUES (1, 2, 'koolijutud');
            INSERT INTO edition_heading SELECT id, 1 FROM edition;
            """
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: books, headings: headings))
        let work = try #require(try await catalogue.search("kevade").first)
        var limits = lenient
        limits.maximumHeadingEditions = 5000
        let titles = try await catalogue.similar(to: work, limits: limits).map(\.work.title)
        #expect(Set(titles) == Set((100..<110).map { "Raamat \($0)" }))
    }

    @Test func tooFewGoodMatchesShowNone() async throws {
        let (catalogue, work) = try await kevade()
        var limits = lenient
        limits.minimumWorks = 10
        #expect(try await catalogue.similar(to: work, limits: limits).isEmpty)
    }

    @Test func aHeadingOnTooManyBooksSaysTooLittle() async throws {
        let (catalogue, work) = try await kevade()
        var limits = lenient
        limits.maximumHeadingEditions = 5
        #expect(try await catalogue.similar(to: work, limits: limits).isEmpty)
    }
}

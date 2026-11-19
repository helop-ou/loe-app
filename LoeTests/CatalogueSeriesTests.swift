import Foundation
import Testing
@testable import Loe

struct CatalogueSeriesTests {
    // Näljamängud is Collins's own numbered series, with an English book in it.
    // Eesti lugu is a publisher's series of many authors. Tõde ja õigus and Sõrmuste
    // Isand are published in parts, numbered in their titles.
    private static let books = """
        (1, 'b1', 'Näljamängud', 'Suzanne Collins', 2009, 1, 0, NULL, 'est', NULL, 'Näljamängud'),
        (2, 'b2', 'Lahvatab leek', 'Suzanne Collins', 2010, 1, 0, NULL, 'est', NULL, 'Näljamängud'),
        (3, 'b3', 'Lahvatab leek', 'Suzanne Collins', 2012, 1, 0, NULL, 'est', NULL, 'Näljamängud'),
        (4, 'b4', 'Pilapasknäär', 'Suzanne Collins', 2011, 1, 0, NULL, 'est', NULL, 'Näljamängud'),
        (5, 'b5', 'Mockingjay', 'Suzanne Collins', 2010, 1, 0, NULL, 'eng', NULL, 'Näljamängud'),
        (6, 'b6', 'Mockingjay', 'Suzanne Collins', 2014, 1, 0, NULL, 'eng', NULL, 'Näljamängud'),
        (10, 'b10', 'Kevade', 'Oskar Luts', 2009, 1, 0, NULL, 'est', NULL, 'Eesti lugu'),
        (11, 'b11', 'Suvi', 'Oskar Luts', 2009, 1, 0, NULL, 'est', NULL, 'Eesti lugu'),
        (12, 'b12', 'Tasuja', 'Eduard Bornhöhe', 2009, 1, 0, NULL, 'est', NULL, 'Eesti lugu'),
        (13, 'b13', 'Mahtra sõda', 'Eduard Vilde', 2009, 1, 0, NULL, 'est', NULL, 'Eesti lugu'),
        (20, 'b20', 'Tõde ja õigus. I jagu', 'A. H. Tammsaare', 1926, 1, 0, NULL, 'est', NULL, NULL),
        (21, 'b21', 'Tõde ja õigus. II jagu', 'A. H. Tammsaare', 1929, 1, 0, NULL, 'est', NULL, NULL),
        (22, 'b22', 'Tõde ja õigus. 2. jagu', 'A. H. Tammsaare', 1947, 1, 0, NULL, 'est', NULL, NULL),
        (23, 'b23', 'Tõde ja õigus. II jagu', 'A. H. Tammsaare', 1938, 1, 0, NULL, 'est', NULL, NULL),
        (24, 'b24', 'Tõde ja õigus. III jagu', 'A. H. Tammsaare', 1931, 1, 0, NULL, 'est', NULL, NULL),
        (25, 'b25', 'Tõde ja õigus. II jagu', 'Keegi Teine', 2000, 1, 0, NULL, 'est', NULL, NULL),
        (26, 'b26', 'Tõde ja õigus. II jagu', 'Keegi Teine', 2001, 1, 0, NULL, 'est', NULL, NULL),
        (27, 'b27', 'Tõde ja õigus. II jagu', 'Keegi Teine', 2002, 1, 0, NULL, 'est', NULL, NULL),
        (30, 'b30', 'Sõrmuste Isand. Esimene osa. Sõrmuse Vennaskond', 'J. R. R. Tolkien', 2007, 1, 0, NULL, 'est', NULL, NULL),
        (31, 'b31', 'Sõrmuste Isand. Teine osa. Kaks kantsi', 'J. R. R. Tolkien', 2008, 1, 0, NULL, 'est', NULL, NULL),
        (32, 'b32', 'Sõrmuste Isanda võlumaailmad', 'David Colbert', 2003, 0, 0, NULL, 'est', NULL, NULL)
        """

    private static let numbers = """
        UPDATE edition SET series_number = '1. raamat' WHERE id = 1;
        UPDATE edition SET series_number = '2. raamat' WHERE id IN (2, 3);
        UPDATE edition SET series_number = '3. raamat' WHERE id = 4;
        UPDATE edition SET series_number = '3' WHERE id IN (5, 6);
        UPDATE edition SET series_number = id + 39 WHERE id BETWEEN 10 AND 13;
        """

    private let catalogue: Catalogue

    init() throws {
        catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.books, headings: Self.numbers))
    }

    /// A work as a shelf keeps it: one edition with no catalogue id, then filled in
    /// from the catalogue the way Read next does.
    private func shelved(_ title: String, by author: String) async throws -> CatalogueWork {
        let edition = CatalogueEdition(id: 0, erbID: "", title: title, authors: author)
        let work = CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
        return CatalogueWork(id: work.id, editions: try await catalogue.editions(of: work))
    }

    @Test func aShelvedBookFindsEveryEditionNewestFirst() async throws {
        let work = try await shelved("Lahvatab leek", by: "Suzanne Collins")
        #expect(work.editions.map(\.year) == [2012, 2010])
        #expect(work.editions.allSatisfy { $0.id > 0 })
    }

    @Test func theNextNumberInTheAuthorsOwnSeries() async throws {
        let next = try #require(try await catalogue.nextInSeries(after: shelved("Näljamängud", by: "Suzanne Collins")))
        #expect(next.work.title == "Lahvatab leek")
        #expect(next.work.editions.count == 2)
        #expect(next.series == "Näljamängud")
    }

    @Test func theNextNumberIsInTheSameLanguage() async throws {
        // Number three is also published in English, and more often.
        let next = try await catalogue.nextInSeries(after: shelved("Lahvatab leek", by: "Suzanne Collins"))
        #expect(next?.work.title == "Pilapasknäär")
    }

    @Test func theLastBookHasNoNext() async throws {
        #expect(try await catalogue.nextInSeries(after: shelved("Pilapasknäär", by: "Suzanne Collins")) == nil)
    }

    @Test func aPublisherSeriesOfManyAuthorsIsNotASeries() async throws {
        #expect(try await catalogue.nextInSeries(after: shelved("Kevade", by: "Oskar Luts")) == nil)
    }

    @Test func theNextPartOfABookPublishedInPartsByTheSameAuthor() async throws {
        let next = try #require(try await catalogue.nextInSeries(after: shelved("Tõde ja õigus. I jagu", by: "A. H. Tammsaare")))
        // Part two is published as „II jagu“ twice and „2. jagu“ once. Keegi Teine's
        // book of the same name is published more often, but is not Tammsaare's.
        #expect(next.work.title == "Tõde ja õigus. II jagu")
        #expect(next.work.authors == "A. H. Tammsaare")
        #expect(next.series == "Tõde ja õigus")
    }

    @Test func partsNumberedInWords() async throws {
        let next = try await catalogue.nextInSeries(after: shelved("Sõrmuste Isand. Esimene osa. Sõrmuse Vennaskond", by: "J. R. R. Tolkien"))
        #expect(next?.work.title == "Sõrmuste Isand. Teine osa. Kaks kantsi")
    }

    @Test(arguments: [
        ("Tõde ja õigus. I jagu", "Tõde ja õigus", 1),
        ("Tõde ja õigus. IV jagu", "Tõde ja õigus", 4),
        ("Tõde ja õigus. 1. jagu. 2. anne", "Tõde ja õigus", 1),
        ("Sõrmuste Isand. 2. osa. Kaks kantsi", "Sõrmuste Isand", 2),
        ("Sõrmuste Isand. Kolmas osa", "Sõrmuste Isand", 3),
        ("Harry Potter ja tarkade kivi. 1. aasta", "Harry Potter ja tarkade kivi", 1),
        ("Troonide mäng. Üheksas raamat", "Troonide mäng", 9),
    ])
    func readsAPartNumberAfterTheFirstStop(title: String, base: String, number: Int) {
        let part = Catalogue.part(of: title)
        #expect(part?.base == base)
        #expect(part?.number == number)
    }

    @Test(arguments: ["Kevade", "Rehepapp, ehk, November", "Mina. Ise", "Kirjad. 1999 aastast", "Luuletused. Valik"])
    func aTitleWithoutAPartHasNone(title: String) {
        #expect(Catalogue.part(of: title) == nil)
    }

    @Test func aSeriesHoldsItsLaterBooks() async throws {
        let series = try #require(try await catalogue.nextInSeries(after: shelved("Tõde ja õigus. I jagu", by: "A. H. Tammsaare")))
        #expect(series.contains(try await shelved("Tõde ja õigus. III jagu", by: "A. H. Tammsaare")))
        #expect(!series.contains(try await shelved("Kevade", by: "Oskar Luts")))
        let numbered = try #require(try await catalogue.nextInSeries(after: shelved("Näljamängud", by: "Suzanne Collins")))
        #expect(numbered.contains(try await shelved("Pilapasknäär", by: "Suzanne Collins")))
    }
}

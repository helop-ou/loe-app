import Foundation
import Testing
@testable import Loe

struct GenreTests {
    // A crime novel in Estonian, published twice, and one once. A crime novel in
    // English, a non-fiction book under the crime heading, a fantasy novel, and a
    // novel with only the generic heading.
    private static let books = """
        (1, 'b1', 'Baskerville''ide koer', 'Arthur Conan Doyle', 1990, 1, 0, NULL, 'est', NULL, NULL),
        (2, 'b2', 'Baskerville''ide koer', 'Arthur Conan Doyle', 2010, 1, 0, NULL, 'est', NULL, NULL),
        (3, 'b3', 'Mõrv Idaekspressis', 'Agatha Christie', 2005, 1, 0, NULL, 'est', NULL, NULL),
        (4, 'b4', 'The hound of the Baskervilles', 'Arthur Conan Doyle', 2001, 1, 0, NULL, 'eng', NULL, NULL),
        (5, 'b5', 'Kuritegevuse ajalugu', 'Ajaloolane', 2012, 0, 0, NULL, 'est', NULL, NULL),
        (6, 'b6', 'Kääbik', 'J. R. R. Tolkien', 2002, 1, 0, NULL, 'est', NULL, NULL),
        (7, 'b7', 'Romaan', 'Kirjanik', 2020, 1, 0, NULL, 'est', NULL, NULL)
        """

    private static let headings = """
        INSERT INTO heading (id, kind, name) VALUES (1, 2, 'kriminaalromaanid'), (2, 2, 'fantaasiaromaanid'), (3, 2, 'romaanid'), (4, 1, 'kriminaaljutud');
        INSERT INTO edition_heading VALUES (1, 1), (2, 1), (3, 4), (4, 1), (5, 1), (6, 2), (7, 3);
        """

    private func catalogue() throws -> Catalogue {
        try Catalogue(url: CatalogueFixture.make(books: Self.books, headings: Self.headings))
    }

    @Test func aGenreFindsFictionUnderAnyOfItsHeadingsInOneLanguage() async throws {
        let works = try await catalogue().works(withHeadings: Genre.crime.headings, language: "est", limit: 10)
        #expect(works.map(\.title) == ["Baskerville'ide koer", "Mõrv Idaekspressis"])
        #expect(works.first?.editions.count == 2)
    }

    @Test func theLimitKeepsTheMostPublished() async throws {
        let works = try await catalogue().works(withHeadings: Genre.crime.headings, language: "est", limit: 1)
        #expect(works.map(\.title) == ["Baskerville'ide koer"])
    }

    @Test func otherLanguagesAreTheirOwn() async throws {
        let works = try await catalogue().works(withHeadings: Genre.crime.headings, language: "eng", limit: 10)
        #expect(works.map(\.title) == ["The hound of the Baskervilles"])
    }

    @Test func noHeadingsFindNothing() async throws {
        #expect(try await catalogue().works(withHeadings: [], language: "est", limit: 10).isEmpty)
    }

    @Test func noGenreMapsToAGenericHeadingOrSharesOne() {
        let all = Genre.allCases.flatMap(\.headings)
        #expect(Set(all).count == all.count)
        #expect(Set(all).isDisjoint(with: Catalogue.genericHeadings.union(["romaanid", "jutud", "e-raamatud"])))
    }

    /// Checks the table against the real catalogue where there is one: a misspelt
    /// heading would quietly find nothing.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: CatalogueStore.defaultURL.path)))
    func everyHeadingIsInTheInstalledCatalogueOnFiction() async throws {
        let catalogue = try Catalogue(url: CatalogueStore.defaultURL)
        for genre in Genre.allCases {
            for heading in genre.headings {
                let works = try await catalogue.works(withHeadings: [heading], language: "est", limit: 1)
                #expect(!works.isEmpty, "\(heading) for \(genre)")
            }
        }
    }
}

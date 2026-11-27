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

    @Test func aBookShelvedBeforeItsTitleAndAuthorWereCorrectedIsFoundByItsRecord() async throws {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.books))
        let edition = CatalogueEdition(id: 0, erbID: "b1", title: "Keisri hul", authors: "J. Kross")
        let work = CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
        let details = try await catalogue.details(for: work)
        #expect(details.editions.map(\.year) == [2017, 1978])
        #expect(Set(details.translations.map(\.title)) == ["The czar's madman", "Der Verrückte des Zaren"])
        #expect(Set(details.sameAuthor.map(\.title)) == ["Kolme katku vahel", "Professor Martensi ärasõit"])
        #expect(try await catalogue.editions(of: work).map(\.year) == [2017, 1978])
    }

    @Test func aBookTheCatalogueNoLongerHasShowsWhatTheShelfKept() async throws {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.books))
        let edition = CatalogueEdition(id: 0, erbID: "b999", title: "Kadunud raamat", authors: "Keegi Teine")
        let work = CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
        #expect(try await catalogue.details(for: work).editions == [edition])
        #expect(try await catalogue.editions(of: work) == [edition])
    }

    /// Translations as the bibliography records them: an original title with its
    /// subtitle in one edition and without it in the next, and a series whose books
    /// share the words before the colon.
    private static let translated = """
        (1, 'b1', 'Ave Maria', 'Andy Weir', 2021, 1, 0, 'Project Hail Mary', 'est', 'eng', NULL),
        (2, 'b2', 'Sapiens', 'Yuval Noah Harari', 2016, 0, 0, 'Sapiens', 'est', 'eng', NULL),
        (3, 'b3', 'Ajuvaba aju', 'Dean Burnett', 2016, 0, 0, 'The idiot brain: what your head is really up to', 'est', 'eng', NULL),
        (4, 'b4', 'Kesköö raamatukogu', 'Matt Haig', 2021, 1, 0, 'The midnight library', 'est', 'eng', NULL),
        (5, 'b5', 'Draakoni kolmnurk', 'Kay Wilkins', 2011, 1, 0, 'Ripley''s Bureau of Investigation: the dragon''s triangle', 'est', 'eng', NULL),
        (6, 'b6', 'Projekt', 'Someone Else', 2020, 1, 0, 'Project Hail Mary', 'est', 'eng', NULL)
        """

    private func translations(of title: String, by author: String) async throws -> [String] {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.translated))
        let abroad = OpenLibraryBook(record: .init(workKey: "/works/OL1W"), title: title, authors: [author], language: "eng")
        return try await catalogue.details(for: abroad.work).translations.map(\.title)
    }

    @Test func aBookFromAbroadListsItsEstonianTranslation() async throws {
        #expect(try await translations(of: "Project Hail Mary", by: "Andy Weir") == ["Ave Maria"])
        // Open Library drops an article and adds a middle initial where the bibliography doesn't.
        #expect(try await translations(of: "Midnight Library", by: "Matt J. Haig") == ["Kesköö raamatukogu"])
    }

    @Test func aBookFromAbroadWithNoTranslationListsNone() async throws {
        #expect(try await translations(of: "Piranesi", by: "Susanna Clarke").isEmpty)
        #expect(try await translations(of: "Project Hail Mary", by: "Susanna Clarke").isEmpty)
    }

    @Test func aSubtitleOnEitherSideDoesNotHideATranslation() async throws {
        #expect(try await translations(of: "Sapiens: A Brief History of Humankind", by: "Yuval Noah Harari") == ["Sapiens"])
        #expect(try await translations(of: "The Idiot Brain", by: "Dean Burnett") == ["Ajuvaba aju"])
        #expect(try await translations(of: "The Idiot Brain: What Your Head Is Really Up To", by: "Dean Burnett") == ["Ajuvaba aju"])
    }

    @Test func anotherBookOfTheSeriesIsNotItsTranslation() async throws {
        #expect(try await translations(of: "Ripley's Bureau of Investigation: A Scaly Tale", by: "Kay Wilkins").isEmpty)
        #expect(try await translations(of: "Ripley's Bureau of Investigation: The Dragon's Triangle", by: "Kay Wilkins") == ["Draakoni kolmnurk"])
    }

    /// An author the two sources write two ways, others who share his surname, and
    /// two people one spelling could be.
    private static let nylunds = """
        (1, 'b1', 'Halo: Reachi langemine', 'Eric Nylund', 2012, 1, 0, 'Halo: the fall of Reach', 'est', 'eng', NULL),
        (2, 'b2', 'Halo: esimene löök', 'Eric Nylund', 2013, 1, 0, 'Halo: first strike', 'est', 'eng', NULL),
        (3, 'b3', 'Halo: Onyxi kummitused', 'Eric Nylund', 2014, 1, 0, 'Halo: ghosts of Onyx', 'est', 'eng', NULL),
        (4, 'b4', 'Halo: the fall of Reach', 'Eric Nylund', 2001, 1, 0, NULL, 'eng', NULL, NULL),
        (5, 'b5', 'Signal to noise', 'Eric Nylund', 1998, 1, 0, NULL, 'eng', NULL, NULL),
        (6, 'b6', 'Aiapidaja käsiraamat', 'Anna Nylund', 2010, 0, 0, NULL, 'est', NULL, NULL),
        (7, 'b7', 'Põhjala lood', 'Eric Bertil Nylund', 1950, 1, 0, NULL, 'est', NULL, NULL),
        (8, 'b8', 'See', 'Stephen King', 2019, 1, 0, 'It', 'est', 'eng', NULL),
        (9, 'b9', 'Karu ja mesi', 'Stephen Michael King', 2015, 1, 0, 'Bear and honey', 'est', 'eng', NULL),
        (10, 'b10', 'Hobuste aasta', 'Hans H. Luik', 1990, 1, 0, NULL, 'est', NULL, NULL),
        (11, 'b11', 'Laevad merel', 'Hans Hendrik Luik', 1975, 1, 0, NULL, 'est', NULL, NULL),
        (12, 'b12', 'Kaks kirja', 'Eric Nylund; Anna Nylund', 2016, 1, 0, NULL, 'est', NULL, NULL)
        """

    private func abroad(_ title: String, by author: String, language: String? = "eng") -> CatalogueWork {
        OpenLibraryBook(record: .init(workKey: "/works/OL1W"), title: title, authors: [author], language: language).work
    }

    private func sameAuthor(as work: CatalogueWork) async throws -> (titles: Set<String>, inEstonian: Bool) {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.nylunds))
        let details = try await catalogue.details(for: work)
        return (Set(details.sameAuthor.map(\.title)), details.sameAuthorIsInEstonian)
    }

    // The catalogue has next to nothing in English by an author from abroad, so
    // the page of such a book lists what it has by them in Estonian, and says so.
    @Test func aBookFromAbroadListsItsAuthorsBooksInEstonian() async throws {
        let found = try await sameAuthor(as: abroad("Halo: The Fall of Reach", by: "Eric Nylund"))
        // Its own translation is under Translations, and the English editions are left out.
        #expect(found.titles == ["Halo: esimene löök", "Halo: Onyxi kummitused", "Kaks kirja"])
        #expect(found.inEstonian)
    }

    // Open Library adds a middle initial the bibliography leaves out.
    @Test func anAuthorWrittenAnotherWayIsFoundWhenOneSpellingFits() async throws {
        let found = try await sameAuthor(as: abroad("Halo: The Fall of Reach", by: "Eric S. Nylund"))
        #expect(found.titles == ["Halo: esimene löök", "Halo: Onyxi kummitused", "Kaks kirja"])
        #expect(found.inEstonian)
        // Another Nylund is another author, and so is one whose middle name contradicts.
        #expect(!found.titles.contains("Aiapidaja käsiraamat"))
        #expect(!found.titles.contains("Põhjala lood"))
    }

    @Test func theNameAsItIsWrittenComesFirst() async throws {
        // Stephen Michael King fits "Stephen King" too, and is somebody else.
        let king = try await sameAuthor(as: abroad("The Shining", by: "Stephen King"))
        #expect(king.titles == ["See"])
        let other = try await sameAuthor(as: abroad("Leaf", by: "Stephen Michael King"))
        #expect(other.titles == ["Karu ja mesi"])
    }

    @Test func twoSpellingsThatFitListNobodysBooks() async throws {
        let found = try await sameAuthor(as: abroad("A year of horses", by: "Hans Luik"))
        #expect(found.titles.isEmpty)
        #expect(!found.inEstonian)
    }

    @Test func anAuthorTheCatalogueDoesNotHaveListsNothing() async throws {
        let found = try await sameAuthor(as: abroad("Piranesi", by: "Susanna Clarke"))
        #expect(found.titles.isEmpty)
        #expect(!found.inEstonian)
        #expect(try await sameAuthor(as: abroad("Anonymous", by: "Nylund")).titles.isEmpty)
    }

    // A catalogue book's page is as it was: the author's books in its own language.
    @Test func aCatalogueBooksListStaysInItsOwnLanguage() async throws {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.nylunds))
        let english = try #require(try await catalogue.search("signal to noise").first)
        let details = try await catalogue.details(for: english)
        #expect(details.sameAuthor.map(\.title) == ["Halo: the fall of Reach"])
        #expect(!details.sameAuthorIsInEstonian)

        let estonian = try #require(try await catalogue.search("esimene löök").first)
        let inEstonian = try await catalogue.details(for: estonian)
        #expect(Set(inEstonian.sameAuthor.map(\.title)) == ["Halo: Reachi langemine", "Halo: Onyxi kummitused", "Kaks kirja"])
        #expect(!inEstonian.sameAuthorIsInEstonian)
    }

    // An Estonian book found on Open Library lists Estonian books, which is its
    // own language, so there is nothing to say about it.
    @Test func aBookFromAbroadInEstonianSaysNothingOfTheLanguage() async throws {
        let found = try await sameAuthor(as: abroad("Tundmatu raamat", by: "Eric Nylund", language: "est"))
        #expect(found.titles.count == 4)
        #expect(!found.inEstonian)
    }

    // The same book in the catalogue under the other spelling has another key.
    @Test func theBookItselfIsNotAmongItsAuthorsOtherBooks() async throws {
        let books = Self.nylunds + ",\n(13, 'b13', 'Halo: The Fall of Reach', 'Eric Nylund', 2011, 1, 0, NULL, 'est', NULL, NULL)"
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: books))
        let details = try await catalogue.details(for: abroad("Halo: The Fall of Reach", by: "Eric S. Nylund"))
        #expect(!details.sameAuthor.map(\.title).contains("Halo: The Fall of Reach"))
        #expect(details.sameAuthor.count == 3)
    }

    @Test func aBookWithNoAuthorOpenedFromAShelfShowsWhatTheShelfKept() async throws {
        let books = Self.books + ",\n(9, 'b9', 'Eesti muinasjutud', NULL, 1990, 0, 0, NULL, 'est', NULL, NULL)"
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: books))
        let edition = CatalogueEdition(id: 0, erbID: "b9", title: "Eesti muinasjutud")
        let work = CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
        #expect(try await catalogue.details(for: work).editions == [edition])
    }
}

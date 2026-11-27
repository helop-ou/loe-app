import Foundation
import SwiftData
import Testing
@testable import Loe

struct ReadNextTests {
    // Kevade is a school story, like three books by others. Luts also wrote Suvi.
    // Näljamängud is Collins's own numbered series. Tõde ja õigus is published in
    // parts, and Tammsaare also wrote Põrgupõhja. „Mees“ comes in two parts.
    private static let books = """
        (1, 'b1', 'Kevade', 'Oskar Luts', 1912, 1, 0, NULL, 'est', NULL, NULL),
        (2, 'b2', 'Kevade', 'Oskar Luts', 2012, 1, 0, NULL, 'est', NULL, NULL),
        (3, 'b3', 'Suvi', 'Oskar Luts', 1918, 1, 0, NULL, 'est', NULL, NULL),
        (4, 'b4', 'Agu Sihvka annab aru', 'Jaan Rannap', 1977, 1, 0, NULL, 'est', NULL, NULL),
        (5, 'b5', 'Agu Sihvka annab aru', 'Jaan Rannap', 2005, 1, 0, NULL, 'est', NULL, NULL),
        (6, 'b6', 'Kooliraamat', 'Indrek Koff', 2010, 1, 0, NULL, 'est', NULL, NULL),
        (10, 'b10', 'Näljamängud', 'Suzanne Collins', 2009, 1, 0, NULL, 'est', NULL, 'Näljamängud'),
        (11, 'b11', 'Lahvatab leek', 'Suzanne Collins', 2010, 1, 0, NULL, 'est', NULL, 'Näljamängud'),
        (12, 'b12', 'Pilapasknäär', 'Suzanne Collins', 2011, 1, 0, NULL, 'est', NULL, 'Näljamängud'),
        (20, 'b20', 'Tõde ja õigus. I jagu', 'A. H. Tammsaare', 1926, 1, 0, NULL, 'est', NULL, NULL),
        (21, 'b21', 'Tõde ja õigus. II jagu', 'A. H. Tammsaare', 1929, 1, 0, NULL, 'est', NULL, NULL),
        (22, 'b22', 'Tõde ja õigus. III jagu', 'A. H. Tammsaare', 1931, 1, 0, NULL, 'est', NULL, NULL),
        (23, 'b23', 'Põrgupõhja uus Vanapagan', 'A. H. Tammsaare', 1939, 1, 0, NULL, 'est', NULL, NULL),
        (30, 'b30', 'Mees. 1. osa', 'Keegi Kirjanik', 2001, 1, 0, NULL, 'est', NULL, NULL),
        (31, 'b31', 'Mees. 2. osa', 'Keegi Kirjanik', 2002, 1, 0, NULL, 'est', NULL, NULL),
        (90, 'b90', 'Marslane', 'Andy Weir', 2015, 1, 0, 'The martian', 'est', 'eng', NULL),
        (91, 'b91', 'Artemis', 'Andy Weir', 2018, 1, 0, 'Artemis', 'est', 'eng', NULL),
        (92, 'b92', 'Ave Maria', 'Andy Weir', 2021, 1, 0, 'Project Hail Mary', 'est', 'eng', NULL),
        (93, 'b93', 'Kosmose serval', 'Ulme Kirjanik', 2019, 1, 0, NULL, 'est', NULL, NULL),
        (94, 'b94', 'Tähtede taga', 'Teine Ulmik', 2020, 1, 0, NULL, 'est', NULL, NULL),
        (95, 'b95', 'Проект «Аве Мария»', 'Andy Weir', 2021, 1, 0, 'Project Hail Mary', 'rus', 'eng', NULL),
        (96, 'b96', 'Проект «Аве Мария»', 'Andy Weir', 2022, 1, 0, 'Project Hail Mary', 'rus', 'eng', NULL),
        (97, 'b97', 'A local novel', 'Local Writer', 2000, 1, 0, NULL, 'eng', NULL, NULL),
        (98, 'b98', 'Another local novel', 'Other Writer', 2001, 1, 0, NULL, 'eng', NULL, NULL),
        (99, 'b99', 'Kohalik romaan', 'Local Writer', 2005, 1, 0, 'A local novel', 'est', 'eng', NULL),
        (100, 'b100', 'Kesköö raamatukogu', 'Matt Haig', 2021, 1, 0, 'The midnight library', 'est', 'eng', NULL)
        """

    private static let extra = """
        UPDATE edition SET series_number = id - 9 WHERE id BETWEEN 10 AND 12;
        INSERT INTO heading (id, kind, name) VALUES (1, 2, 'koolijutud');
        INSERT INTO edition_heading VALUES (1, 1), (2, 1), (4, 1), (5, 1), (6, 1);
        UPDATE edition SET original_title = 'The hunger games', original_language = 'eng' WHERE id = 10;
        INSERT INTO heading (id, kind, name) VALUES (9, 2, 'ulmeromaanid');
        INSERT INTO edition_heading VALUES (92, 9), (93, 9), (94, 9), (99, 9), (100, 9);
        INSERT INTO heading (id, kind, name) VALUES (8, 2, 'külaromaanid');
        INSERT INTO edition_heading VALUES (97, 8), (98, 8);
        """

    private let catalogue: Catalogue
    // Thresholds for a catalogue of a few books.
    private let limits = ReadNext.Limits(
        similarity: Catalogue.SimilarityLimits(maximumHeadingEditions: 20, seriesEditions: 50...60, minimumScore: 0, minimumWorks: 1, limit: 10)
    )

    init() throws {
        catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.books, headings: Self.extra))
    }

    /// A book as a shelf keeps it: its title and authors, no catalogue id or language.
    private static func work(_ title: String, by author: String) -> CatalogueWork {
        let edition = CatalogueEdition(id: 0, erbID: "", title: title, authors: author)
        return CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
    }

    private static func source(_ title: String, by author: String, on shelf: Shelf = .read, rating: Int? = nil) -> ReadNext.Source {
        ReadNext.Source(work: work(title, by: author), shelf: shelf, rating: rating)
    }

    private static func shelved(_ title: String, by author: String) -> ReadNext.Shelved {
        ReadNext.Shelved(workKey: work(title, by: author).id, title: title, leadAuthor: author)
    }

    private static func book(_ title: String) -> ReadNextSuggestion.Book {
        ReadNextSuggestion.Book(title: title, language: "est")
    }

    private func suggestions(_ sources: [ReadNext.Source], shelved: [ReadNext.Shelved] = []) async throws -> [ReadNextSuggestion] {
        let onShelves = shelved + sources.map { ReadNext.Shelved(workKey: $0.work.id, title: $0.work.title, leadAuthor: $0.work.editions[0].leadAuthor) }
        return try await ReadNext.suggestions(from: sources, excluding: onShelves, in: catalogue, limits: limits)
    }

    private func reasons(_ suggestions: [ReadNextSuggestion]) -> [String: ReadNextSuggestion.Reason] {
        Dictionary(uniqueKeysWithValues: suggestions.map { ($0.work.title, $0.reason) })
    }

    // MARK: From the catalogue

    @Test func aFavouriteBringsTheAuthorsOtherBooksAndSimilarOnes() async throws {
        let found = reasons(try await suggestions([Self.source("Kevade", by: "Oskar Luts", rating: 5)]))
        #expect(found["Suvi"] == .sameAuthor(as: Self.book("Kevade")))
        #expect(found["Agu Sihvka annab aru"] == .similar(to: [Self.book("Kevade")]))
        #expect(found["Kooliraamat"] == .similar(to: [Self.book("Kevade")]))
        #expect(found["Kevade"] == nil)
    }

    // MARK: From abroad

    private static let hailMary = OpenLibraryBook(
        record: OpenLibraryRecord(workKey: "/works/OL21745884W"), title: "Project Hail Mary", authors: ["Andy Weir"], language: "eng"
    ).work

    // A book from abroad lists its author's books in Estonian on its page, and a
    // reader who reads mostly Estonian is suggested them.
    @Test func aFavouriteFromAbroadBringsItsAuthorsEstonianBooksToAReaderOfEstonian() async throws {
        let found = reasons(try await suggestions([
            ReadNext.Source(work: Self.hailMary, shelf: .read, rating: 5),
            Self.source("Kevade", by: "Oskar Luts", rating: 5),
            Self.source("Põrgupõhja uus Vanapagan", by: "A. H. Tammsaare", rating: 4),
        ]))
        let hailMary = ReadNextSuggestion.Book(title: "Project Hail Mary", language: "eng")
        #expect(found["Marslane"] == .sameAuthor(as: hailMary))
        #expect(found["Artemis"] == .sameAuthor(as: hailMary))
    }

    // Read next keeps to the language the reader reads most, so one who reads
    // English is not handed Estonian books for an English favourite.
    @Test func aReaderOfEnglishIsNotHandedEstonianBooks() async throws {
        let found = try await suggestions([ReadNext.Source(work: Self.hailMary, shelf: .read, rating: 5)])
        #expect(found.isEmpty)

        let mostly = try await suggestions([
            ReadNext.Source(work: Self.hailMary, shelf: .read, rating: 5),
            ReadNext.Source(
                work: OpenLibraryBook(record: OpenLibraryRecord(workKey: "/works/OL2W"), title: "Piranesi", authors: ["Susanna Clarke"], language: "eng").work,
                shelf: .read, rating: 5
            ),
            Self.source("Kevade", by: "Oskar Luts", rating: 5),
        ])
        #expect(!mostly.map(\.work.title).contains("Marslane"))
        // What Kevade brings is in Kevade's own language, as before.
        #expect(mostly.map(\.work.title).contains("Suvi"))
    }

    private static let hungerGames = OpenLibraryBook(
        record: OpenLibraryRecord(workKey: "/works/OL5735363W"), title: "The Hunger Games", authors: ["Suzanne Collins"], language: "eng"
    ).work

    private static let estonianFavourites = [
        source("Kevade", by: "Oskar Luts", rating: 5),
        source("Põrgupõhja uus Vanapagan", by: "A. H. Tammsaare", rating: 4),
    ]

    // The catalogue knows nothing of a book it does not hold. It holds „Ave Maria“
    // with its headings, so that stands in for Project Hail Mary.
    @Test func aFavouriteFromAbroadIsFollowedThroughItsTranslation() async throws {
        let found = reasons(try await suggestions([ReadNext.Source(work: Self.hailMary, shelf: .read, rating: 5)] + Self.estonianFavourites))
        // The reason names the book the reader shelved, not its translation.
        let hailMary = ReadNextSuggestion.Book(title: "Project Hail Mary", language: "eng")
        #expect(found["Kosmose serval"] == .similar(to: [hailMary]))
        #expect(found["Tähtede taga"] == .similar(to: [hailMary]))
    }

    @Test func aFavouriteFromAbroadWithNoTranslationBringsNothing() async throws {
        let piranesi = OpenLibraryBook(record: OpenLibraryRecord(workKey: "/works/OL2W"), title: "Piranesi", authors: ["Susanna Clarke"], language: "eng").work
        let found = try await suggestions([ReadNext.Source(work: piranesi, shelf: .read, rating: 5)] + Self.estonianFavourites)
        let piranesis = ReadNextSuggestion.Book(title: "Piranesi", language: "eng")
        #expect(!found.isEmpty)
        #expect(!found.contains { $0.reason == .similar(to: [piranesis]) || $0.reason == .sameAuthor(as: piranesis) || $0.reason == .nextInSeries(after: piranesis) })
    }

    // The reader has read the book, so its translation is not suggested to them,
    // whatever else is like it.
    @Test func theTranslationOfABookTheReaderHasReadIsNotSuggested() async throws {
        let found = reasons(try await suggestions([
            ReadNext.Source(work: Self.hailMary, shelf: .read, rating: 5),
            Self.source("Kosmose serval", by: "Ulme Kirjanik", rating: 5),
            Self.source("Kevade", by: "Oskar Luts", rating: 5),
        ]))
        #expect(found["Ave Maria"] == nil)
        #expect(found["Tähtede taga"] != nil)

        // Without the book from abroad on a shelf, „Ave Maria“ is like any other.
        let without = reasons(try await suggestions([Self.source("Kosmose serval", by: "Ulme Kirjanik", rating: 5)]))
        #expect(without["Ave Maria"] != nil)
    }

    // The Hunger Games from Open Library carries no series. „Näljamängud“ does.
    @Test(arguments: [(Shelf.reading, nil as Int?), (.read, 5)])
    func aSeriesFromAbroadContinuesFromItsTranslation(shelf: Shelf, rating: Int?) async throws {
        let found = reasons(try await suggestions([ReadNext.Source(work: Self.hungerGames, shelf: shelf, rating: rating)] + Self.estonianFavourites))
        #expect(found["Lahvatab leek"] == .nextInSeries(after: ReadNextSuggestion.Book(title: "The Hunger Games", language: "eng")))
        #expect(found["Pilapasknäär"] == nil)
        #expect(found["Näljamängud"] == nil)
    }

    // A book the catalogue holds has headings of its own, whatever translations
    // of it there are.
    @Test func aCatalogueBookIsFollowedByItsOwnHeadings() async throws {
        let found = reasons(try await suggestions([Self.source("A local novel", by: "Local Writer", rating: 5)]))
        #expect(found["Another local novel"] == .similar(to: [ReadNextSuggestion.Book(title: "A local novel", language: "eng")]))
        #expect(found["Kosmose serval"] == nil)
    }

    // The stand-in is Estonian, and Read next keeps to the language the reader
    // reads most.
    @Test func whatATranslationLeadsToIsNotHandedToAReaderOfEnglish() async throws {
        #expect(try await suggestions([ReadNext.Source(work: Self.hailMary, shelf: .read, rating: 5)]).isEmpty)
        #expect(try await suggestions([ReadNext.Source(work: Self.hungerGames, shelf: .reading, rating: nil)]).isEmpty)
        // An author with nothing else in Estonian: only the translation's own leads are held back.
        let midnightLibrary = OpenLibraryBook(
            record: OpenLibraryRecord(workKey: "/works/OL20893680W"), title: "The Midnight Library", authors: ["Matt Haig"], language: "eng"
        ).work
        #expect(try await suggestions([ReadNext.Source(work: midnightLibrary, shelf: .read, rating: 5)]).isEmpty)
        #expect(try await suggestions([ReadNext.Source(work: midnightLibrary, shelf: .read, rating: 5)] + Self.estonianFavourites).contains {
            $0.reason == .similar(to: [ReadNextSuggestion.Book(title: "The Midnight Library", language: "eng")])
        })
        #expect(try await suggestions([
            ReadNext.Source(work: Self.hungerGames, shelf: .read, rating: 5),
            ReadNext.Source(work: Self.hailMary, shelf: .read, rating: 5),
            Self.source("Kevade", by: "Oskar Luts", rating: 5),
        ]).map(\.work.title) == ["Suvi", "Agu Sihvka annab aru", "Kooliraamat"])
    }

    @Test func threeStarsIsNotAFavourite() async throws {
        let found = try await suggestions([Self.source("Kevade", by: "Oskar Luts", rating: 3)])
        #expect(found.isEmpty)
    }

    @Test func theNextBookInASeriesBeingReadComesFirst() async throws {
        let found = try await suggestions([
            Self.source("Kevade", by: "Oskar Luts", rating: 5),
            Self.source("Näljamängud", by: "Suzanne Collins", on: .reading),
        ])
        #expect(found.first?.work.title == "Lahvatab leek")
        #expect(found.first?.reason == .nextInSeries(after: Self.book("Näljamängud")))
        #expect(!found.contains { $0.work.title == "Pilapasknäär" })
    }

    @Test func aSeriesIsSuggestedFromItsNextBookOnly() async throws {
        let found = reasons(try await suggestions([Self.source("Tõde ja õigus. I jagu", by: "A. H. Tammsaare", rating: 5)]))
        #expect(found["Tõde ja õigus. II jagu"] == .nextInSeries(after: Self.book("Tõde ja õigus. I jagu")))
        #expect(found["Põrgupõhja uus Vanapagan"] == .sameAuthor(as: Self.book("Tõde ja õigus. I jagu")))
        #expect(found["Tõde ja õigus. III jagu"] == nil)
    }

    @Test(arguments: [(Shelf.read, 2), (.didNotFinish, nil), (.wantToRead, nil), (.setAside, nil)] as [(Shelf, Int?)])
    func aSeriesTheReaderDidNotTakeToIsNotContinued(shelf: Shelf, rating: Int?) async throws {
        let found = try await suggestions([Self.source("Mees. 1. osa", by: "Keegi Kirjanik", on: shelf, rating: rating)])
        #expect(found.isEmpty)
    }

    @Test func aSeriesTheReaderLikedWellEnoughIsContinued() async throws {
        let found = try await suggestions([Self.source("Mees. 1. osa", by: "Keegi Kirjanik", on: .read, rating: 3)])
        #expect(found.map(\.work.title) == ["Mees. 2. osa"])
    }

    @Test func booksOnAnyShelfAreLeftOut() async throws {
        let found = try await suggestions(
            [Self.source("Kevade", by: "Oskar Luts", rating: 5)],
            shelved: [Self.shelved("Agu Sihvka annab aru", by: "Jaan Rannap"), Self.shelved("Suvi", by: "Oskar Luts")]
        )
        #expect(found.map(\.work.title) == ["Kooliraamat"])
    }

    // MARK: Tastes

    private static let crimeBooks = Self.books + """
        ,
        (40, 'b40', 'Krimka', 'Krimikirjanik', 2010, 1, 0, NULL, 'est', NULL, NULL),
        (41, 'b41', 'Teine krimka', 'Teine Kirjanik', 2011, 1, 0, NULL, 'est', NULL, NULL),
        (44, 'b44', 'Teine krimka', 'Teine Kirjanik', 2015, 1, 0, NULL, 'est', NULL, NULL),
        (42, 'b42', 'A crime novel', 'Crime Writer', 2012, 1, 0, NULL, 'eng', NULL, NULL),
        (43, 'b43', 'A loved novel', 'Loved Writer', 2013, 1, 0, NULL, 'eng', NULL, NULL)
        """

    private static let crimeHeadings = Self.extra + """
        INSERT INTO heading (id, kind, name) VALUES (2, 2, 'kriminaalromaanid');
        INSERT INTO edition_heading VALUES (40, 2), (41, 2), (44, 2), (42, 2);
        """

    private func withTastes(
        _ sources: [ReadNext.Source], tastes: [Genre], shelved: [ReadNext.Shelved] = [], perTaste: Int = 4
    ) async throws -> [ReadNextSuggestion] {
        let catalogue = try Catalogue(url: CatalogueFixture.make(books: Self.crimeBooks, headings: Self.crimeHeadings))
        var limits = limits
        limits.perTaste = perTaste
        return try await ReadNext.suggestions(from: sources, tastes: tastes, excluding: shelved, in: catalogue, limits: limits)
    }

    @Test func aTasteBringsBooksUnderItsGenreLeavingOutShelvedOnes() async throws {
        let found = try await withTastes([], tastes: [.crime], shelved: [Self.shelved("Teine krimka", by: "Teine Kirjanik")])
        #expect(found.map(\.work.title) == ["Krimka"])
        #expect(found.first?.reason == .taste(.crime))
    }

    @Test func aShelvedBookDoesNotTakeAGenresPlace() async throws {
        // Teine krimka, published twice, would be crime's one book, but it is on a shelf.
        let found = try await withTastes([], tastes: [.crime], shelved: [Self.shelved("Teine krimka", by: "Teine Kirjanik")], perTaste: 1)
        #expect(found.map(\.work.title) == ["Krimka"])
    }

    @Test func tastesSuggestInTheLanguageTheReaderReads() async throws {
        let found = try await withTastes([Self.source("A loved novel", by: "Loved Writer", rating: 5)], tastes: [.crime])
        #expect(found.map(\.work.title) == ["A crime novel"])
    }

    @Test func aTasteWithNothingInTheCatalogueSuggestsNothing() async throws {
        #expect(try await withTastes([], tastes: [.horror]).isEmpty)
    }

    // MARK: Putting the kinds together

    private static func catalogueWork(_ title: String, by author: String = "Autor") -> CatalogueWork {
        let edition = CatalogueEdition(id: 1, erbID: "", title: title, authors: author)
        return CatalogueWork(id: CatalogueWork.key(for: edition), editions: [edition])
    }

    @Test func seriesFirstThenAuthorsAndSimilarBooksTakeTurns() {
        let kevade = Self.book("Kevade")
        let merged = ReadNext.merged(
            series: [ReadNextSuggestion(work: Self.catalogueWork("Lahvatab leek"), reason: .nextInSeries(after: Self.book("Näljamängud")))],
            byAuthor: [[(Self.catalogueWork("A1"), kevade), (Self.catalogueWork("A2"), kevade)]],
            similar: [[(Self.catalogueWork("S1"), kevade), (Self.catalogueWork("S2"), kevade), (Self.catalogueWork("S3"), kevade)]],
            excluding: [],
            limit: 10
        )
        #expect(merged.map(\.work.title) == ["Lahvatab leek", "A1", "S1", "A2", "S2", "S3"])
    }

    @Test func tastesTakeTheirTurnAfterAuthorsAndSimilarBooks() {
        let kevade = Self.book("Kevade")
        let merged = ReadNext.merged(
            series: [],
            byAuthor: [[(Self.catalogueWork("A1"), kevade), (Self.catalogueWork("A2"), kevade)]],
            similar: [[(Self.catalogueWork("S1"), kevade)]],
            byTaste: [[(Self.catalogueWork("C1"), .crime), (Self.catalogueWork("C2"), .crime)], [(Self.catalogueWork("F1"), .fantasy)]],
            excluding: [],
            limit: 10
        )
        #expect(merged.map(\.work.title) == ["A1", "S1", "C1", "A2", "F1", "C2"])
        #expect(merged[2].reason == .taste(.crime))
    }

    @Test func eachFavouriteAuthorTakesATurn() {
        let merged = ReadNext.merged(
            series: [],
            byAuthor: [
                [(Self.catalogueWork("Suvi"), Self.book("Kevade")), (Self.catalogueWork("Talve"), Self.book("Kevade"))],
                [(Self.catalogueWork("Liblikas"), Self.book("Rehepapp"))],
            ],
            similar: [],
            excluding: [],
            limit: 10
        )
        #expect(merged.map(\.work.title) == ["Suvi", "Liblikas", "Talve"])
    }

    @Test func aBookLikeSeveralFavouritesComesFirstAndNamesThem() {
        let merged = ReadNext.merged(
            series: [],
            byAuthor: [],
            similar: [
                [(Self.catalogueWork("Only Kevade"), Self.book("Kevade")), (Self.catalogueWork("Both"), Self.book("Kevade"))],
                [(Self.catalogueWork("Both"), Self.book("Suvi"))],
            ],
            excluding: [],
            limit: 10
        )
        #expect(merged.map(\.work.title) == ["Both", "Only Kevade"])
        #expect(merged.first?.reason == .similar(to: [Self.book("Kevade"), Self.book("Suvi")]))
    }

    @Test func aBookIsSuggestedOnceForItsFirstReasonAndTheListStopsAtTheLimit() {
        let kevade = Self.book("Kevade")
        let merged = ReadNext.merged(
            series: [ReadNextSuggestion(work: Self.catalogueWork("Same"), reason: .nextInSeries(after: kevade))],
            byAuthor: [[(Self.catalogueWork("Same"), kevade), (Self.catalogueWork("Same. 2. aasta"), kevade)]],
            similar: [[(Self.catalogueWork("S1"), kevade), (Self.catalogueWork("S2"), kevade), (Self.catalogueWork("S3"), kevade)]],
            excluding: [],
            limit: 3
        )
        #expect(merged.map(\.work.title) == ["Same", "S1", "S2"])
        #expect(merged.first?.reason == .nextInSeries(after: kevade))
    }

    @Test func anEditionWithAPartAfterItsTitleIsTheSameBookOnTheShelf() {
        let shelved = [ReadNext.Shelved(workKey: "other", title: "Harry Potter ja saladuste kamber. 2. aasta", leadAuthor: "J. K. Rowling")]
        #expect(ReadNext.isOnShelf(Self.catalogueWork("Harry Potter ja saladuste kamber", by: "J. K. Rowling"), shelved))
        #expect(!ReadNext.isOnShelf(Self.catalogueWork("Harry Potter ja saladuste kamber", by: "Keegi Teine"), shelved))

        let kevade = [ReadNext.Shelved(workKey: "kevade", title: "Kevade", leadAuthor: "Oskar Luts")]
        #expect(ReadNext.isOnShelf(Self.catalogueWork("Kevade. 2. osa", by: "Oskar Luts"), kevade))
        #expect(!ReadNext.isOnShelf(Self.catalogueWork("Kevade ja suvi", by: "Oskar Luts"), kevade))
    }

    @Test func aBookTheCatalogueRenamedIsStillOnTheShelf() {
        let shelved = [ReadNext.Shelved(workKey: "an older spelling", erbID: "b7", title: "Kevade. Pildikesi koolipõlvest", leadAuthor: "O. Luts")]
        let edition = CatalogueEdition(id: 7, erbID: "b7", title: "Kevade", authors: "Oskar Luts")
        let other = CatalogueEdition(id: 8, erbID: "b8", title: "Kevade", authors: "Oskar Luts")
        #expect(ReadNext.isOnShelf(CatalogueWork(id: CatalogueWork.key(for: edition), editions: [other, edition]), shelved))
        #expect(!ReadNext.isOnShelf(CatalogueWork(id: CatalogueWork.key(for: other), editions: [other]), shelved))
    }

    // MARK: From the shelves

    @Test @MainActor func favouritesAndSeriesBeingReadAreSourcesMostRecentFirst() throws {
        let container = try ModelContainer(
            for: ShelvedBook.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        let monday = Date(timeIntervalSince1970: 1_800_000_000)
        func shelve(_ title: String, on shelf: Shelf, rating: Int? = nil, day: Double) throws {
            let edition = CatalogueEdition(id: 1, erbID: title, title: title, authors: "Autor")
            let book = try ShelvedBook.shelve(Self.catalogueWork(title), edition: edition, on: shelf, in: context, now: monday)
            book.rate(rating, now: monday.addingTimeInterval(day * 86_400))
        }
        try shelve("Loved", on: .read, rating: 5, day: 1)
        try shelve("Reading", on: .reading, day: 3)
        try shelve("Liked", on: .read, rating: 3, day: 2)
        try shelve("Disliked", on: .read, rating: 2, day: 4)
        try shelve("Unrated", on: .read, day: 5)
        try shelve("Wanted", on: .wantToRead, day: 6)
        try shelve("Abandoned", on: .didNotFinish, rating: 4, day: 7)

        let sources = ReadNext.sources(from: try context.fetch(FetchDescriptor<ShelvedBook>()))
        #expect(sources.map(\.work.title) == ["Abandoned", "Unrated", "Reading", "Liked", "Loved"])
        #expect(sources.filter(\.isFavourite).map(\.work.title) == ["Abandoned", "Loved"])
        #expect(sources.filter(\.continuesSeries).map(\.work.title) == ["Unrated", "Reading", "Liked", "Loved"])
    }
}

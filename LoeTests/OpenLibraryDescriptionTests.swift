import Foundation
import Testing
@testable import Loe

/// Work records shaped as Open Library answers, with the text
/// replaced by Loe's own words: a publisher's blurb is not Loe's to keep here.
struct OpenLibraryDescriptionTests {
    private func text(_ json: String) -> String? {
        OpenLibraryDescription.text(inWork: Data(json.utf8))
    }

    @Test func aDescriptionIsReadFromAnObjectOrAString() {
        #expect(text(#"{"description": {"type": "/type/text", "value": "A fox outwits three farmers."}}"#) == "A fox outwits three farmers.")
        #expect(text(#"{"description": "A fox outwits three farmers."}"#) == "A fox outwits three farmers.")
    }

    @Test func aWorkWithNoneHasNone() {
        #expect(text(#"{"key": "/works/OL18626W", "title": "Halo"}"#) == nil)
        #expect(text(#"{"description": "  \r\n "}"#) == nil)
        #expect(text(#"{"description": 7}"#) == nil)
        #expect(text(#"{"description": {"type": "/type/text"}}"#) == nil)
        #expect(text("not json") == nil)
        #expect(text("[]") == nil)
    }

    @Test func paragraphsStayAndWindowsLineEndsGo() {
        let written = "He wakes up alone.\r\n\r\nPiece by piece he remembers.\r\n\r\n\r\n\r\nThen he is not alone."
        #expect(OpenLibraryDescription.plain(written) == "He wakes up alone.\n\nPiece by piece he remembers.\n\nThen he is not alone.")
    }

    @Test func openLibrarysOwnNotesUnderARuleAreLeftOut() {
        let contained = "A grim future.\r\n\r\n----------\t\t\r\nAlso contained in:\t\t\r\n[Novels](https://openlibrary.org/works/OL1W)\t\t\r\n[More novels](https://openlibrary.org/works/OL2W)"
        #expect(OpenLibraryDescription.plain(contained) == "A grim future.")
        let contains = "One ring.\r\n\r\n---\r\n\r\n**Contains**\r\n\r\n- [The first part](https://openlibrary.org/works/OL3W/The_first_part)"
        #expect(OpenLibraryDescription.plain(contains) == "One ring.")
        // Only notes: nothing to show.
        #expect(OpenLibraryDescription.plain("----------\r\nSee also:\r\n[Another](https://openlibrary.org/works/OL4W)") == nil)
    }

    @Test func markdownReadsAsPlainText() {
        #expect(OpenLibraryDescription.plain("*Project Hail Mary* is a tale to rival **The Martian**.") == "Project Hail Mary is a tale to rival The Martian.")
        #expect(OpenLibraryDescription.plain("See [the series](https://openlibrary.org/works/OL5W) and the part \\[1/9\\].") == "See the series and the part [1/9].")
        // A dash inside a sentence and a star on its own are text.
        #expect(OpenLibraryDescription.plain("Mordor--a dark realm. Rated 5 * by some.") == "Mordor--a dark realm. Rated 5 * by some.")
    }

    @Test func aSourceNoteAndItsAddressAreLeftOut() {
        let written = "A lion, an eagle, a badger and a snake. ([source][1])\r\n\r\n[1]: https://example.org/blurb"
        #expect(OpenLibraryDescription.plain(written) == "A lion, an eagle, a badger and a snake.")
    }

    @Test func aWorksRecordIsAskedByItsKeyAndNothingElse() {
        let record = OpenLibraryRecord(workKey: "/works/OL21745884W", isbn: "9780593135204", coverID: 11_200_092)
        #expect(OpenLibrary.workRequest(for: record)?.url?.absoluteString == "https://openlibrary.org/works/OL21745884W.json")
        for key in ["/authors/OL1A", "/works/OL1W/../../x", "/works/OL1W?x=1", "//example.org/works/OL1W", "", "works/OL1W"] {
            #expect(OpenLibrary.workRequest(for: OpenLibraryRecord(workKey: key)) == nil, "\(key)")
        }
    }

    /// Counts what was asked, and answers from a table.
    private actor Asked {
        private(set) var paths: [String] = []
        func note(_ path: String) { paths.append(path) }
    }

    @Test func aWorkIsAskedOnceASessionAndNoDescriptionIsRemembered() async throws {
        let asked = Asked()
        let openLibrary = OpenLibrary { request in
            let path = request.url?.path ?? ""
            await asked.note(path)
            return Data((path == "/works/OL1W.json" ? #"{"description": "A fox outwits three farmers."}"# : "{}").utf8)
        }
        let described = OpenLibraryRecord(workKey: "/works/OL1W")
        let bare = OpenLibraryRecord(workKey: "/works/OL2W")
        #expect(try await openLibrary.description(of: described) == "A fox outwits three farmers.")
        #expect(try await openLibrary.description(of: described) == "A fox outwits three farmers.")
        #expect(try await openLibrary.description(of: bare) == nil)
        #expect(try await openLibrary.description(of: bare) == nil)
        #expect(await asked.paths == ["/works/OL1W.json", "/works/OL2W.json"])
    }

    @Test func aFailureIsNotRememberedSoTheNextOpeningAsksAgain() async throws {
        let asked = Asked()
        let openLibrary = OpenLibrary { request in
            await asked.note(request.url?.path ?? "")
            if await asked.paths.count == 1 { throw URLError(.notConnectedToInternet) }
            return Data(#"{"description": "A fox outwits three farmers."}"#.utf8)
        }
        let record = OpenLibraryRecord(workKey: "/works/OL1W")
        await #expect(throws: URLError.self) { try await openLibrary.description(of: record) }
        #expect(try await openLibrary.description(of: record) == "A fox outwits three farmers.")
    }
}

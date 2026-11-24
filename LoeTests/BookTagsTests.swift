import Testing
@testable import Loe

struct BookTagsTests {
    private func genre(_ name: String, on editions: Int = 4, uses: Int = 100) -> BookTags.Heading {
        .init(name: name, isGenre: true, editions: editions, uses: uses)
    }

    private func subject(_ name: String, on editions: Int = 4, uses: Int = 100) -> BookTags.Heading {
        .init(name: name, isGenre: false, editions: editions, uses: uses)
    }

    @Test func aHeadingCountsWhenMoreThanHalfTheEditionsCarryIt() {
        let headings = [genre("näidendid", on: 3), genre("komöödiad", on: 2), genre("novellid", on: 1)]
        #expect(BookTags.chosen(from: headings, editions: 4, fiction: true) == ["näidendid"])
    }

    @Test func fictionShowsItsGenresAndNotItsSubjects() {
        let headings = [genre("fantaasiaromaanid"), subject("inglise"), subject("maagia")]
        #expect(BookTags.chosen(from: headings, editions: 4, fiction: true) == ["fantaasiaromaanid"])
    }

    @Test func nonFictionShowsItsGenresAndThenWhatItIsAbout() {
        let headings = [subject("harjumused", uses: 40), genre("käsiraamatud", uses: 9000), subject("eneseabi", uses: 300)]
        #expect(BookTags.chosen(from: headings, editions: 4, fiction: false) == ["käsiraamatud", "harjumused", "eneseabi"])
    }

    @Test func theRarestHeadingComesFirstAndTheNameSettlesATie() {
        let headings = [genre("lastekirjandus", uses: 15000), genre("koolijutud", uses: 300), genre("antoloogiad", uses: 300)]
        #expect(BookTags.chosen(from: headings, editions: 4, fiction: true) == ["antoloogiad", "koolijutud", "lastekirjandus"])
    }

    @Test func aBroaderGenreGivesWayToANarrowerOneThatEndsWithIt() {
        let novel = [genre("romaanid", uses: 13000), genre("ajaloolised romaanid", uses: 2400), genre("põnevusromaanid", uses: 3400)]
        #expect(BookTags.chosen(from: novel, editions: 4, fiction: true) == ["ajaloolised romaanid", "põnevusromaanid"])
        let tales = [genre("jutud", uses: 9000), genre("muinasjutud", uses: 3300)]
        #expect(BookTags.chosen(from: tales, editions: 4, fiction: true) == ["muinasjutud"])
        // On its own the broad one stays, and one that only fell short of the editions does not hide it.
        #expect(BookTags.chosen(from: [genre("romaanid")], editions: 4, fiction: true) == ["romaanid"])
        let rare = [genre("romaanid"), genre("sõjaromaanid", on: 1)]
        #expect(BookTags.chosen(from: rare, editions: 4, fiction: true) == ["romaanid"])
    }

    @Test func headingsAboutTheFormatAreLeftOut() {
        let headings = BookTags.leftOut.sorted().map { genre($0) } + [subject("ilukirjandus"), genre("novellid")]
        #expect(BookTags.chosen(from: headings, editions: 4, fiction: false) == ["novellid"])
        #expect(BookTags.leftOut.isSuperset(of: ["ilukirjandus", "e-raamatud", "suurtähtraamatud", "kogutud teosed"]))
    }

    @Test func noMoreThanSixAreShownAndGenresKeepTheirPlace() {
        let subjects = (1...8).map { subject("teema \($0)", uses: $0) }
        let chosen = BookTags.chosen(from: subjects + [genre("mälestused", uses: 9000)], editions: 4, fiction: false)
        #expect(chosen == ["mälestused", "teema 1", "teema 2", "teema 3", "teema 4", "teema 5"])
    }

    @Test func aBookWithNoHeadingsHasNoTags() {
        #expect(BookTags.chosen(from: [], editions: 3, fiction: true).isEmpty)
    }
}

import Testing
@testable import Loe

/// One author written two ways, and two authors written nearly alike.
/// See docs/catalogue.md, "In the app".
struct AuthorNameTests {
    @Test func aNameIsItsFirstNameWhatStandsBetweenAndItsSurname() {
        #expect(AuthorName.parts("Gerald Malcolm Durrell") == .init(first: "gerald", middle: ["malcolm"], surname: "durrell"))
        #expect(AuthorName.parts("Eric S. Nylund") == .init(first: "eric", middle: ["s"], surname: "nylund"))
        #expect(AuthorName.parts("Jaan Kross") == .init(first: "jaan", middle: [], surname: "kross"))
        #expect(AuthorName.parts("Lõhmus Ülle") == .init(first: "lohmus", middle: [], surname: "ulle"))
        #expect(AuthorName.parts("Montesquieu") == nil)
        #expect(AuthorName.parts("") == nil)
    }

    @Test(arguments: [
        ("Eric S. Nylund", "Eric Nylund"),
        ("Gerald Durrell", "Gerald Malcolm Durrell"),
        ("Deborah E. Harkness", "Deborah Harkness"),
        ("Ellen G. White", "Ellen Gould Harmon White"),
        ("Karl Martin Sinijärv", "Karl Sinijärv"),
        ("Ralf Parve", "Ralf R. Parve"),
        ("JAAN KROSS", "Jaan Kross"),
    ])
    func aMiddleNameOrInitialOneOfThemLeavesOutStillFits(one: String, other: String) {
        #expect(AuthorName.fits(one, other))
        #expect(AuthorName.fits(other, one))
    }

    // The bibliography uses a middle name to tell two people apart.
    @Test(arguments: [
        ("Aleksei Nikolajevitš Tolstoi", "Aleksei Konstantinovitš Tolstoi"),
        ("Mary Higgins Clark", "Mary Jane Clark"),
        ("Robert S. Kaplan", "Robert D. Kaplan"),
        ("Ellen G. White", "Ellen Harmon White"),
    ])
    func middleNamesThatContradictAreTwoPeople(one: String, other: String) {
        #expect(!AuthorName.fits(one, other))
        #expect(!AuthorName.fits(other, one))
    }

    @Test(arguments: [
        ("Eric Nylund", "Erik Nylund"),
        ("Eric Nylund", "Eric Nyland"),
        ("Eric Nylund", "Anna Nylund"),
        ("Eric Nylund", "Nylund"),
        ("Eric Nylund", ""),
    ])
    func anotherFirstNameOrSurnameIsAnotherPerson(one: String, other: String) {
        #expect(!AuthorName.fits(one, other))
        #expect(!AuthorName.fits(other, one))
    }

    // An initial for a first name says too little: for most such names the one
    // full-name author with that surname is somebody else.
    @Test(arguments: [("H. G. Wells", "Henrietta Wells"), ("P. D. James", "Peter James"), ("C. S. Lewis", "Clive Staples Lewis"), ("J. Kross", "J. Kross")])
    func anInitialForAFirstNameFitsNobody(one: String, other: String) {
        #expect(!AuthorName.fits(one, other))
        #expect(!AuthorName.fits(other, one))
    }

    @Test func theOneSpellingThatFitsIsTaken() {
        // The same spelling many times over, as a list of editions has it, is one spelling.
        #expect(AuthorName.onlySpelling(of: "Eric S. Nylund", among: ["Anna Nylund", "Eric Nylund", "Eric Nylund", "ERIC NYLUND"]) == "Eric Nylund")
        #expect(AuthorName.onlySpelling(of: "Eric S. Nylund", among: ["Anna Nylund"]) == nil)
        #expect(AuthorName.onlySpelling(of: "Eric S. Nylund", among: [String]()) == nil)
    }

    // Stephen King and Stephen Michael King are two people. A page that knows only
    // "Stephen E. King" cannot tell whose it is, so it lists neither's books.
    @Test func twoSpellingsThatFitMayBeTwoPeople() {
        #expect(AuthorName.onlySpelling(of: "Hans Luik", among: ["Hans H. Luik", "Hans Luik"]) == nil)
        #expect(AuthorName.onlySpelling(of: "Stephen King", among: ["Stephen Michael King", "Stephen Edwin King"]) == nil)
        #expect(AuthorName.onlySpelling(of: "Stephen E. King", among: ["Stephen Michael King", "Stephen King"]) == "Stephen King")
    }
}

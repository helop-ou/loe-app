import Testing
@testable import Loe

struct CatalogueQueryTests {
    @Test func everyWordMustMatchAndTheLastMayBeUnfinished() {
        #expect(CatalogueQuery.match(for: "tõde ja õig") == "\"tõde\" \"ja\" \"õig\"*")
        #expect(CatalogueQuery.match(for: "kross") == "\"kross\"*")
    }

    @Test func punctuationCannotBreakTheQuery() {
        #expect(CatalogueQuery.match(for: "Mees, kes \"teadis\"") == "\"Mees\" \"kes\" \"teadis\"*")
        #expect(CatalogueQuery.match(for: " ,.; ") == nil)
    }

    @Test(arguments: [
        ("978-9949-633-28-9", "9789949633289"),
        ("0-306-40615-2", "9780306406157"),
        ("544001361X", "9785440013612"),
        ("9789949633289", "9789949633289"),
    ])
    func readsAnISBNInAnyPunctuation(typed: String, isbn: String) {
        #expect(CatalogueQuery.isbn13(typed) == isbn)
    }

    @Test(arguments: ["9789949633288", "0306406153", "Keisri hull", "123", "1984 vol 978"])
    func rejectsWhatIsNotAnISBN(typed: String) {
        #expect(CatalogueQuery.isbn13(typed) == nil)
    }

    @Test func foldingIgnoresCaseDiacriticsAndPunctuation() {
        #expect(CatalogueQuery.folded("Tõde ja õigus. I") == "tode ja oigus i")
        #expect(CatalogueQuery.folded("Mees, kes teadis ussisõnu") == CatalogueQuery.folded("mees kes teadis ussisonu"))
    }
}

struct BarcodeTests {
    @Test(arguments: [
        ("9789949633289", "9789949633289"),
        ("9785440013612", "9785440013612"),
    ])
    func aBookBarcodeGivesItsISBN(payload: String, isbn: String) {
        #expect(CatalogueQuery.isbn13(fromBarcode: payload) == isbn)
    }

    @Test(arguments: [
        "4740001000017",  // a valid barcode, but for groceries
        "9789949633288",  // a book barcode misread by one digit
        "978994963328",   // twelve digits
        "97899496332890", // fourteen
        "978-9949633289",
    ])
    func anythingElseIsIgnored(payload: String) {
        #expect(CatalogueQuery.isbn13(fromBarcode: payload) == nil)
    }
}

import Foundation
import Testing
@testable import Loe

struct BookLinksTests {
    @Test func esterDropsTheCheckDigit() {
        #expect(BookLinks.ester("b10500820")?.absoluteString == "https://www.ester.ee/record=b1050082")
        #expect(BookLinks.ester("b1054421x")?.absoluteString == "https://www.ester.ee/record=b1054421")
    }

    @Test(arguments: ["", "b123", "x10500820", "b105008201"])
    func esterNeedsARecordNumber(_ id: String) {
        #expect(BookLinks.ester(id) == nil)
    }

    @Test func bookshopsAreSearchedForTheTitleAndAuthor() throws {
        let work = CatalogueWork(id: "k", editions: [CatalogueEdition(id: 1, erbID: "b1", title: "Tõde ja õigus", authors: "A. H. Tammsaare; Someone")])
        let query = BookLinks.query(for: work)
        #expect(query == "Tõde ja õigus A. H. Tammsaare")
        let url = try #require(BookLinks.rahvaRaamat(query))
        #expect(url.host() == "www.rahvaraamat.ee")
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == query)
        #expect(BookLinks.apollo(query)?.path() == "/catalogsearch/result/")
    }

    @Test func languagesAreNamedInTheAppsLanguage() {
        #expect(LanguageName.of("fre", in: Locale(identifier: "en")) == "French")
        #expect(LanguageName.of("fre", in: Locale(identifier: "et")) == "prantsuse")
        #expect(LanguageName.of("est", in: Locale(identifier: "en")) == "Estonian")
        #expect(LanguageName.of(nil, in: Locale(identifier: "en")) == nil)
    }
}

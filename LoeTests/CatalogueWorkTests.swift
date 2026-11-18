import Testing
@testable import Loe

struct CatalogueWorkTests {
    private func edition(_ id: Int, _ title: String, by authors: String?, in year: Int?) -> CatalogueEdition {
        CatalogueEdition(
            id: id, erbID: "b\(id)", title: title, subtitle: nil, authors: authors, year: year,
            publisher: nil, originalTitle: nil, series: nil, seriesNumber: nil, fiction: true
        )
    }

    @Test func editionsOfOneBookBecomeOneWorkNewestFirst() {
        let works = CatalogueWork.ranked([
            (edition(1, "Keisri hull", by: "Jaan Kross", in: 1978), -10),
            (edition(2, "Keisri hull", by: "Jaan Kross", in: 2017), -10),
            (edition(3, "Keisri hull", by: "Jaan Kross", in: 1995), -10),
        ], query: "keisri")
        #expect(works.count == 1)
        #expect(works[0].editions.map(\.year) == [2017, 1995, 1978])
        #expect(works[0].firstYear == 1978)
        #expect(works[0].latestYear == 2017)
    }

    @Test func theSameTitleByAnotherAuthorIsAnotherWork() {
        let works = CatalogueWork.ranked([
            (edition(1, "Kevade", by: "Oskar Luts", in: 1912), -10),
            (edition(2, "Kevade", by: "Someone Else", in: 2001), -10),
        ], query: "kevade")
        #expect(works.count == 2)
    }

    @Test func theTitleTypedExactlyComesFirst() {
        let works = CatalogueWork.ranked([
            (edition(1, "Õigus ja tõde", by: "Rohke Debelakk", in: 2010), -30),
            (edition(2, "Tõde ja õigus", by: "A. H. Tammsaare", in: 2019), -12),
        ], query: "tode ja oigus")
        #expect(works.map(\.title) == ["Tõde ja õigus", "Õigus ja tõde"])
    }

    @Test func aBookPublishedOftenOutranksAnEqualMatch() {
        let once = [(edition(1, "Rehepapp", by: "Writer A", in: 2000), -10.0)]
        let often = (2...9).map { (edition($0, "Rehepapp ehk November", by: "Andrus Kivirähk", in: 2000 + $0), -10.0) }
        let works = CatalogueWork.ranked(once + often, query: "rehep")
        #expect(works.first?.authors == "Andrus Kivirähk")
    }
}

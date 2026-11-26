import Foundation
import Testing
import UIKit
@testable import Loe

/// Answers shaped as EPIK gives them, with a cover drawn here and
/// words of Loe's own: a publisher's cover and blurb are not Loe's to keep.
struct EPIKTests {
    @Test func aRecordIsAnEditionsNumberWithoutItsCheckDigit() {
        #expect(EPIK.code(erbID: "b10544215") == "b1054421")
        #expect(EPIK.code(erbID: "b1210534x") == "b1210534")
        for notARecord in ["", "hand:6F1C", "b1", "10544215", "b10544215/..", "B10544215"] {
            #expect(EPIK.code(erbID: notARecord) == nil, "\(notARecord)")
        }
    }

    @Test func recordsAreAskedAboutTogetherInOnePost() throws {
        let request = try #require(EPIK.recordsRequest(for: ["b1054421", "b5454324"]))
        #expect(request.url?.absoluteString == "https://epik.ester.ee/api/data/getImagesByCodeList")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(try JSONDecoder().decode([String].self, from: try #require(request.httpBody)) == ["b1054421", "b5454324"])
        #expect(EPIK.recordsRequest(for: []) == nil)
    }

    @Test func detailsAreAskedByAnIdThatReadsAsOne() {
        let id = "2b404fef-442a-4713-8185-22281088904d"
        #expect(EPIK.detailsRequest(for: id)?.url?.absoluteString == "https://epik.ester.ee/api/data/getDetailsByIdUuid?idUuid=\(id)")
        for odd in ["", "1&x=2", "../../x", "2b404fef 442a", "https://example.org"] {
            #expect(EPIK.detailsRequest(for: odd) == nil, "\(odd)")
        }
    }

    @Test func eachRecordSaysWhatEPIKHasForIt() throws {
        let answer = #"""
            [{"code": "b1599969", "imageData": "/9j/4AAQ", "idUuid": "2b404fef-442a-4713-8185-22281088904d",
              "isContentPresent": false, "isContentDescriptionPresent": false},
             {"code": "b1055545", "imageData": null, "idUuid": "328a317b-941b-4909-87db-e76c0912cc46",
              "isContentPresent": false, "isContentDescriptionPresent": true},
             {"code": "b6038907", "imageData": null, "idUuid": null, "isContentPresent": false, "isContentDescriptionPresent": false},
             {"imageData": "/9j/", "idUuid": "x"}, 7]
            """#
        let records = try #require(EPIK.records(in: Data(answer.utf8)))
        #expect(records == [
            .init(code: "b1599969", id: "2b404fef-442a-4713-8185-22281088904d", hasCover: true, hasDescription: false),
            .init(code: "b1055545", id: "328a317b-941b-4909-87db-e76c0912cc46", hasCover: false, hasDescription: true),
            .init(code: "b6038907", id: nil, hasCover: false, hasDescription: false),
        ])
    }

    @Test func anAnswerThatIsNotAListIsNotTakenForNoCovers() {
        #expect(EPIK.records(in: Data("<html>Service unavailable</html>".utf8)) == nil)
        #expect(EPIK.records(in: Data(#"{"error": "busy"}"#.utf8)) == nil)
        #expect(EPIK.records(in: Data("[]".utf8)) == [])
    }

    nonisolated static func details(cover: Data?, description: String? = nil, source: String = "ESTER", title: String = "Keisri hull : romaan") -> Data {
        var record: [String: Any] = ["autor": "Kross, Jaan, 1920-2007", "pealkiri": title, "taiskomplekt": false]
        if let cover {
            record["pildiFailid"] = ["coverImages": ["large": ["data": cover.base64EncodedString(), "andmeallikas": "DIGAR"]]]
        }
        if let description {
            record["sisukirjeldus"] = ["kirjeSisu": description, "andmeallikas": source]
        }
        return try! JSONSerialization.data(withJSONObject: ["data": record, "labels": ["autor": ["est": "Autor", "eng": "Author"]]])
    }

    nonisolated static func picture(width: Int, height: Int, left: UIColor = .blue, right: UIColor = .blue) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).jpegData(withCompressionQuality: 0.9) { context in
            left.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            right.setFill()
            context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        }
    }

    @Test func detailsCarryTheCoverAndTheRecordsOwnSummary() {
        let cover = Self.picture(width: 160, height: 240)
        let details = EPIK.details(in: Self.details(cover: cover, description: "  Kroonik kirjutab üles oma õemehe loo.\n"))
        #expect(details.cover == cover)
        #expect(details.description == "Kroonik kirjutab üles oma õemehe loo.")
        #expect(details.title == "Keisri hull : romaan")
    }

    /// ESTER's cover service files some records under another book, and the
    /// title it gives with the cover is how to tell.
    @Test func aRecordsTitleHasToBeTheBooks() {
        #expect(EPIK.sameTitle("Keisri hull : romaan", "Keisri hull"))
        #expect(EPIK.sameTitle("Sapiens : inimkonna lühiajalugu", "Sapiens"))
        #expect(EPIK.sameTitle("KEISRI HULL", "Keisri hull"))
        #expect(EPIK.sameTitle("Tode ja oigus", "Tõde ja õigus"))
        #expect(EPIK.sameTitle("Kevade", "Kevade. Pildikesi koolipõlvest"))
        #expect(!EPIK.sameTitle("Betti, kibuvits õitseb : dialooge", "Saar"))
        #expect(!EPIK.sameTitle("Maestro", "Ärata surnud"))
        #expect(!EPIK.sameTitle("Saarepiiga", "Saar"))
        #expect(!EPIK.sameTitle(nil, "Saar"))
        #expect(!EPIK.sameTitle(" : ", "Saar"))
        #expect(!EPIK.sameTitle("Saar", ""))
    }

    @Test func aSummaryTakenFromElsewhereIsLeftOut() {
        // EPIK had a Dutch blurb for another book on one record, from LibraryThing.
        let borrowed = EPIK.details(in: Self.details(cover: nil, description: "De zestienjarige wordt gevonden.", source: "Library Things"))
        #expect(borrowed == EPIK.Details(title: "Keisri hull : romaan", cover: nil, description: nil))
        #expect(EPIK.details(in: Self.details(cover: nil, description: "   ")).description == nil)
    }

    @Test func anAnswerThatCannotBeReadHasNothing() {
        #expect(EPIK.details(in: Data("not json".utf8)) == EPIK.Details())
        #expect(EPIK.details(in: Data(#"{"data": {"pildiFailid": {"coverImages": {"large": {"data": 7}}}}}"#.utf8)) == EPIK.Details())
        #expect(EPIK.details(in: Data(#"{"labels": {}}"#.utf8)) == EPIK.Details())
    }
}

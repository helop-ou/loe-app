import Foundation

/// ESTER's cover service, EPIK, run by ELNET: it holds covers for the catalogue's
/// records, and the record's own summary where it has one. Asked in two steps, as
/// ESTER's own pages ask it: which of some records have what, then one record's
/// details. See docs/library.md, "Covers".
nonisolated enum EPIK {
    /// What EPIK has for one record.
    struct Record: Sendable, Equatable {
        /// The ESTER record number without its check digit, such as "b5206912".
        let code: String
        /// What to ask its details by. Nil when EPIK doesn't know the record.
        let id: String?
        let hasCover: Bool
        let hasDescription: Bool
    }

    struct Details: Sendable, Equatable {
        /// The title EPIK has the record under, with its subtitle.
        var title: String?
        /// A JPEG, 240 pixels tall, sometimes of the whole jacket.
        var cover: Data?
        /// The record's own summary. Text EPIK took from elsewhere is left out: it
        /// can be another book's.
        var description: String?
    }

    /// The most records one book's page asks about, newest first.
    static let most = 12
    /// How many of a book's records are asked for a cover before giving up.
    static let tries = 3

    /// Whether the title EPIK has a record under is this book's. EPIK files some
    /// records under another book, whose cover and summary it then gives, and it
    /// writes a title with its subtitle.
    static func sameTitle(_ theirs: String?, _ ours: String) -> Bool {
        let theirs = CatalogueQuery.folded(theirs ?? "")
        let ours = CatalogueQuery.folded(ours)
        guard !theirs.isEmpty, !ours.isEmpty else { return false }
        return theirs == ours || theirs.hasPrefix(ours + " ") || ours.hasPrefix(theirs + " ")
    }

    /// The record an edition's number names: "b10544215" is "b1054421". Nil for a
    /// book with no record.
    static func code(erbID: String) -> String? {
        guard erbID.wholeMatch(of: /b\d{6,9}[\dx]/) != nil else { return nil }
        return String(erbID.dropLast())
    }

    static func recordsRequest(for codes: [String]) -> URLRequest? {
        guard !codes.isEmpty, let body = try? JSONEncoder().encode(codes) else { return nil }
        var request = URLRequest(url: URL(string: "https://epik.ester.ee/api/data/getImagesByCodeList")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// Nil for an id that doesn't read as one, so nothing an answer carries can
    /// send the request elsewhere.
    static func detailsRequest(for id: String) -> URLRequest? {
        guard id.wholeMatch(of: /[0-9a-fA-F-]{8,64}/) != nil else { return nil }
        return URL(string: "https://epik.ester.ee/api/data/getDetailsByIdUuid?idUuid=\(id)").map { URLRequest(url: $0) }
    }

    /// Nil for an answer that is not EPIK's list, such as an error page, so an
    /// outage is not taken for books with no covers.
    static func records(in data: Data) -> [Record]? {
        guard let items = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        return items.compactMap { item in
            guard let item = item as? [String: Any], let code = item["code"] as? String else { return nil }
            let id = item["idUuid"] as? String
            return Record(
                code: code, id: id,
                hasCover: id != nil && (item["imageData"] as? String)?.isEmpty == false,
                hasDescription: id != nil && item["isContentDescriptionPresent"] as? Bool == true
            )
        }
    }

    static func details(in data: Data) -> Details {
        guard let answer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let record = answer["data"] as? [String: Any]
        else { return Details() }
        let images = (record["pildiFailid"] as? [String: Any])?["coverImages"] as? [String: Any]
        let large = (images?["large"] as? [String: Any])?["data"] as? String
        let written = record["sisukirjeldus"] as? [String: Any]
        let own = written?["andmeallikas"] as? String == "ESTER"
        let text = (written?["kirjeSisu"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Details(
            title: record["pealkiri"] as? String,
            cover: large.flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) },
            description: own && text?.isEmpty == false ? text : nil
        )
    }
}

#if DEBUG
nonisolated extension EPIK {
    /// What the journeys' EPIK answers: the print edition of „Ave Maria“ has a plain
    /// blue cover and a summary of its own, in Loe's words, and no other record
    /// has either.
    static func stubbedAnswer(to request: URLRequest, cover: Data) -> Data {
        if request.httpMethod == "POST" {
            let codes = (request.httpBody.flatMap { try? JSONDecoder().decode([String].self, from: $0) }) ?? []
            let items = codes.map { code -> [String: Any] in
                let known = code == "b5454324"
                return [
                    "code": code, "idUuid": known ? "00000000-0000-4000-8000-000000000001" : NSNull(),
                    "imageData": known ? "thumbnail" : NSNull(), "isContentPresent": false, "isContentDescriptionPresent": known,
                ]
            }
            return (try? JSONSerialization.data(withJSONObject: items)) ?? Data()
        }
        let details: [String: Any] = ["data": [
            "pealkiri": "Ave Maria",
            "pildiFailid": ["coverImages": ["large": ["data": cover.base64EncodedString(), "andmeallikas": "DIGAR"]]],
            "sisukirjeldus": [
                "kirjeSisu": "Õpetaja ärkab üksi kosmoselaevas ega mäleta, kuidas ta sinna sai. Tasapisi selgub, et ta saadeti Maad päästma.",
                "andmeallikas": "ESTER",
            ],
        ]]
        return (try? JSONSerialization.data(withJSONObject: details)) ?? Data()
    }
}
#endif

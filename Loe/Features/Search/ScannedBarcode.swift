import Vision

/// What a barcode on a book is: its ISBN, the library's sticker, or another code,
/// such as a price or a magazine's ISSN.
nonisolated enum ScannedBarcode: Equatable, Sendable {
    case isbn(String)
    case library
    case notABook

    /// The barcode types the scanner looks for: a book's EAN-13, and those library
    /// stickers and shops use, so they can be told apart rather than ignored.
    static let symbologies: [VNBarcodeSymbology] = [
        .ean13, .ean8, .upce,
        .code128, .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum,
        .code93, .code93i, .codabar, .itf14, .i2of5, .i2of5Checksum,
    ]

    private static let productSymbologies: Set<VNBarcodeSymbology> = [.ean13, .ean8, .upce]

    /// Nil for what is not worth mentioning: an unreadable payload, or an EAN-13
    /// that starts 978 or 979 but fails its check digit, which is an ISBN misread
    /// and is better read again than called the wrong barcode.
    init?(payload: String?, symbology: VNBarcodeSymbology) {
        guard let payload, !payload.isEmpty, Self.symbologies.contains(symbology) else { return nil }
        if symbology == .ean13, payload.hasPrefix("978") || payload.hasPrefix("979") {
            guard let isbn = CatalogueQuery.isbn13(fromBarcode: payload) else { return nil }
            self = .isbn(isbn)
        } else {
            self = Self.productSymbologies.contains(symbology) ? .notABook : .library
        }
    }

    /// An ISBN in view wins over anything else, since a library sticker often sits
    /// right beside it. Otherwise the first other code seen, or nil.
    static func best(of barcodes: [ScannedBarcode]) -> ScannedBarcode? {
        barcodes.first { if case .isbn = $0 { true } else { false } } ?? barcodes.first
    }
}

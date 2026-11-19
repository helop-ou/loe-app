import Testing
import Vision
@testable import Loe

struct ScannedBarcodeTests {
    @Test func aBooksEAN13IsItsISBN() {
        #expect(ScannedBarcode(payload: "9789949633289", symbology: .ean13) == .isbn("9789949633289"))
        #expect(ScannedBarcode(payload: "9791032305690", symbology: .ean13) == .isbn("9791032305690"))
    }

    @Test(arguments: [
        // Tallinn Central Library's sticker, as printed and as scanners read it.
        ("10823000808075", VNBarcodeSymbology.code128),
        ("1 0823 00080807 5", .code128),
        ("A10823000808075B", .codabar),
        ("10823000808075", .itf14),
        ("LIB000123", .code39),
    ])
    func aStickerInAnotherBarcodeTypeIsTheLibrarys(payload: String, symbology: VNBarcodeSymbology) {
        #expect(ScannedBarcode(payload: payload, symbology: symbology) == .library)
    }

    @Test(arguments: [
        ("4740098000124", VNBarcodeSymbology.ean13),
        ("9771234567003", .ean13),
        ("96385074", .ean8),
        ("01234565", .upce),
    ])
    func aShopsBarcodeThatIsNotAnISBNIsNotABook(payload: String, symbology: VNBarcodeSymbology) {
        #expect(ScannedBarcode(payload: payload, symbology: symbology) == .notABook)
    }

    @Test func aMisreadISBNIsReadAgainRatherThanCalledTheWrongBarcode() {
        #expect(ScannedBarcode(payload: "9789949633280", symbology: .ean13) == nil)
    }

    @Test func codesTheScannerDoesNotLookForAndEmptyReadsAreIgnored() {
        #expect(ScannedBarcode(payload: "https://example.com", symbology: .qr) == nil)
        #expect(ScannedBarcode(payload: nil, symbology: .code128) == nil)
        #expect(ScannedBarcode(payload: "", symbology: .ean13) == nil)
    }

    @Test func anISBNInViewWinsOverTheStickerBesideIt() {
        #expect(ScannedBarcode.best(of: [.library, .isbn("9789949633289"), .notABook]) == .isbn("9789949633289"))
        #expect(ScannedBarcode.best(of: [.notABook, .library]) == .notABook)
        #expect(ScannedBarcode.best(of: []) == nil)
    }
}

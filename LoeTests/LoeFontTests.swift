import CoreText
import Foundation
import Testing
@testable import Loe

struct LoeFontTests {
    @Test(arguments: [false, true])
    func newsreaderIsBundledAndRegistered(italic: Bool) {
        let font = LoeFont.ctFont(size: 22, weight: 600, italic: italic)
        let name = CTFontCopyPostScriptName(font) as String
        #expect(name.hasPrefix("Newsreader"), "resolved to \(name)")
    }

    @Test func headingsUseTheWeightAxis() throws {
        let font = LoeFont.ctFont(size: 36, weight: 600, italic: false)
        let variation = try #require(CTFontCopyVariation(font) as? [NSNumber: NSNumber])
        #expect(variation[0x7767_6874]?.doubleValue == 600)
    }
}

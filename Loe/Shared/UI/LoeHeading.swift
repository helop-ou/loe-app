import CoreText
import SwiftUI

/// Where Newsreader is used. Everything else is the system font.
enum LoeHeading: CaseIterable {
    case largeTitle
    case bookTitle
    case section
    case inline

    var size: CGFloat {
        switch self {
        case .largeTitle: 36
        case .bookTitle: 27
        case .section: 22
        case .inline: 19
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .bookTitle: .title
        case .section: .title2
        case .inline: .title3
        }
    }
}

enum LoeFont {
    static let roman = "Newsreader16pt-Regular"
    static let italic = "Newsreader16pt-Italic"

    /// `weight` is the font's own axis, 200 to 800. Headings use 600, italic titles 400.
    static func newsreader(size: CGFloat, weight: CGFloat = 600, italic: Bool = false) -> Font {
        Font(ctFont(size: size, weight: weight, italic: italic))
    }

    static func ctFont(size: CGFloat, weight: CGFloat, italic: Bool) -> CTFont {
        let variations: [NSNumber: NSNumber] = [
            0x7767_6874: NSNumber(value: Double(weight)), // 'wght'
            0x6F70_737A: NSNumber(value: Double(min(max(size, 6), 72))), // 'opsz'
        ]
        let attributes: [CFString: Any] = [
            kCTFontNameAttribute: italic ? Self.italic : Self.roman,
            kCTFontVariationAttribute: variations,
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }
}

private struct LoeHeadingModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let italic: Bool

    init(_ heading: LoeHeading, italic: Bool) {
        _size = ScaledMetric(wrappedValue: heading.size, relativeTo: heading.textStyle)
        self.italic = italic
    }

    func body(content: Content) -> some View {
        content.font(LoeFont.newsreader(size: size, weight: italic ? 400 : 600, italic: italic))
    }
}

extension View {
    /// Sets a heading in Newsreader, scaled with Dynamic Type.
    func loeHeading(_ heading: LoeHeading, italic: Bool = false) -> some View {
        modifier(LoeHeadingModifier(heading, italic: italic))
    }
}

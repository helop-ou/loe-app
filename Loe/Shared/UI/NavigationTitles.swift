import UIKit

/// Screen titles are Newsreader in the native navigation bar, so the bar keeps its
/// system behaviour and only the type is Loe's.
enum NavigationTitles {
    static func applyNewsreader() {
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = attributes(for: .largeTitle)
        appearance.titleTextAttributes = attributes(for: .inline)
    }

    private static func attributes(for heading: LoeHeading) -> [NSAttributedString.Key: Any] {
        let style: UIFont.TextStyle = heading == .largeTitle ? .largeTitle : .headline
        let base = LoeFont.ctFont(size: heading == .largeTitle ? heading.size : 17, weight: 600, italic: false)
        return [
            .font: UIFontMetrics(forTextStyle: style).scaledFont(for: base as UIFont),
            .foregroundColor: UIColor(resource: .loeInk),
        ]
    }
}

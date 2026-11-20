import SwiftUI
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

extension View {
    /// The screen's title, in the language Loe is showing. The navigation bar keeps
    /// a title in the language it first appeared in, so a screen that is up while
    /// the reader changes the language needs one that changes with it.
    func loeNavigationTitle(_ title: LocalizedStringResource) -> some View {
        modifier(FollowingTitle(title: title))
    }
}

private struct FollowingTitle: ViewModifier {
    let title: LocalizedStringResource

    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.navigationTitle(locale.localized(title))
    }
}

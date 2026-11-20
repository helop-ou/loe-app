import SwiftUI

/// What stays with the reader and exactly what Loe sends where, in plain words.
/// It says what docs/release.md, "Privacy", says, so change them together.
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            PrivacyContent()
                .padding(20)
        }
        .background(.loeBackground)
        .loeNavigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What stays with you")
                .loeHeading(.section)
            Text("Your shelves, ratings, pages, cover photos, tastes and libraries are kept on this phone and in your own iCloud. There's no Loe account and no Loe server.")
            Text("Loe has no ads, no analytics and no tracking.")

            Text("What Loe sends, and where")
                .loeHeading(.section)
                .padding(.top, 12)
            Sent(
                "The catalogue",
                "Downloading it, and looking once a week for a new edition, fetches files from GitHub. Nothing about you is sent."
            )
            Sent(
                "Libraries",
                "When you've chosen libraries, opening a book asks ESTER whether they have it. ESTER sees which book was asked about."
            )
            Sent(
                "Searching",
                "When you stop typing, Loe asks Open Library about what you typed. It asks about an ISBN, typed or scanned, only when the catalogue doesn't have the book. Open Library, run by the Internet Archive, sees what you searched for."
            )
            Sent(
                "Covers",
                "Covers of books from abroad come from Open Library and the Internet Archive, which see which of those books' covers were asked for. Loe keeps the covers on your phone."
            )
            Sent(
                "Links",
                "Links on a book's page open in your browser, like any other link."
            )
            Text("Each of these sees your phone's internet address, as any website would. Nothing Loe sends carries an account, cookies or your name, and Loe keeps no record of it.")
                .foregroundStyle(.loeSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.loeInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Sent: View {
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    init(_ title: LocalizedStringKey, _ text: LocalizedStringKey) {
        self.title = title
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(text)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        PrivacyView()
    }
}

import SwiftUI

/// What Loe is, what it sends where, whose work it is built on, its code, and how
/// to reach the developer.
struct AboutView: View {
    var body: some View {
        List {
            Section {
                AboutHeader(version: LoeProject.version, build: LoeProject.build)
                    .listRowBackground(Color.clear)
            }

            Section {
                NavigationLink {
                    PrivacyView()
                } label: {
                    TwoLineRow(title: "Privacy", detail: Text("What stays with you, and what Loe sends where"))
                }
            }
            .listRowBackground(Color.loeCard)

            Section {
                ForEach(Credit.all) { credit in
                    NavigationLink {
                        CreditView(credit: credit)
                    } label: {
                        TwoLineRow(title: credit.name, detail: Text(credit.role))
                    }
                }
            } header: {
                SettingsHeading("Credits")
            }
            .listRowBackground(Color.loeCard)

            Section {
                Text("Loe's code is open under the Mozilla Public License 2.0. The name Loe, its marks and its icon are not part of the licence.")
                    .foregroundStyle(.loeInk)
                Link("See the code on GitHub", destination: LoeProject.repository)
                    .tint(.loeAccent)
            } header: {
                SettingsHeading("Source code")
            }
            .listRowBackground(Color.loeCard)

            Section {
                Link(destination: URL(string: "mailto:\(LoeProject.contact)")!) {
                    TwoLineRow(title: "Write to us", detail: Text(verbatim: LoeProject.contact))
                }
                Link("Report a problem on GitHub", destination: LoeProject.issues)
                    .tint(.loeAccent)
            } header: {
                SettingsHeading("Feedback")
            }
            .listRowBackground(Color.loeCard)
        }
        .scrollContentBackground(.hidden)
        .background(.loeBackground)
        .loeNavigationTitle("About Loe")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The name as Loe sets it, its version, and what it is.
struct AboutHeader: View {
    let version: String
    let build: String

    var body: some View {
        VStack(spacing: 12) {
            Image(.loeTitle)
                .resizable()
                .scaledToFit()
                .frame(width: 160)
                .accessibilityLabel(Text(verbatim: "Loe"))
            Text("Version \(version) (\(build))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.loeSecondary)
            Text("A private reading tracker for Estonian and English books. No account, no ads, no tracking.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.loeInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct TwoLineRow: View {
    let title: LocalizedStringKey
    let detail: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(.loeInk)
            detail
                .font(.subheadline)
                .foregroundStyle(.loeSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

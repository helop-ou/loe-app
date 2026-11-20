import SwiftUI

/// One credit in full: what it gives Loe, a link to it, and its licence text when
/// Loe ships a copy of the work.
struct CreditView: View {
    let credit: Credit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Estonian names such as Rahvusraamatukogu would break at a larger size.
                Text(credit.name)
                    .loeHeading(.section)
                Text(credit.role)
                    .foregroundStyle(.loeSecondary)
                Text(credit.about)
                    .tint(.loeAccent)
                Link(destination: credit.link) {
                    Label {
                        Text(verbatim: credit.link.host() ?? credit.link.absoluteString)
                    } icon: {
                        Image(systemName: "arrow.up.right")
                    }
                }
                .foregroundStyle(.loeAccent)
                if let licence = credit.licence, let text = licence.text {
                    Text(verbatim: licence.name)
                        .loeHeading(.section)
                        .padding(.top, 16)
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(Credit.paragraphs(of: text).enumerated()), id: \.offset) { _, paragraph in
                            Text(verbatim: paragraph)
                                .font(.footnote)
                        }
                    }
                }
            }
            .foregroundStyle(.loeInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(.loeBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CreditView(credit: Credit.all[3])
    }
}

import SwiftUI

/// What is happening with the catalogue while the phone has none to search: Loe
/// is fetching it, is waiting for Wi-Fi, or could not fetch it. It is there to
/// reassure, so each state says what Loe is doing and what still works.
/// See docs/catalogue.md, "Download and updates".
struct CatalogueNotice: View {
    let download: CatalogueStore.Download?
    /// The reader asks for the catalogue now, on whatever network there is.
    let downloadNow: () -> Void

    @ScaledMetric(relativeTo: .title3) private var symbolWidth = 28

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.loeAccent)
                // One width for every symbol, so the words line up from notice to notice.
                .frame(width: symbolWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.loeInk)
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.loeSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let fraction {
                    ProgressView(value: fraction)
                        .tint(.loeAccent)
                        .padding(.top, 4)
                } else if download == .waitingForWiFi {
                    button("Download now")
                } else if download == .failed {
                    button("Try again")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.loeCard, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.loeHairline))
    }

    /// How far the download is. Before it has begun it is on its way, so that
    /// reads as a download too.
    private var fraction: Double? {
        switch download {
        case .inProgress(let fraction): fraction
        case nil: 0
        case .waitingForWiFi, .failed, .needsNewerLoe: nil
        }
    }

    private var symbol: String {
        switch download {
        case .inProgress, nil: "arrow.down.circle"
        case .waitingForWiFi: "wifi"
        case .failed: "wifi.exclamationmark"
        case .needsNewerLoe: "arrow.up.circle"
        }
    }

    private var title: LocalizedStringKey {
        switch download {
        case .inProgress, nil: "Downloading the catalogue"
        case .waitingForWiFi: "The catalogue is waiting for Wi-Fi"
        case .failed: "The download didn't finish"
        case .needsNewerLoe: "Loe needs an update"
        }
    }

    private var explanation: LocalizedStringKey {
        switch download {
        case .inProgress, nil:
            "Every book published in Estonia, about 30 MB. Until it's here, Search finds only books from abroad."
        case .waitingForWiFi:
            "It's about 30 MB, so Loe fetches it over mobile data or in Low Data Mode only when you ask. Until it's here, Search finds only books from abroad."
        case .failed:
            "Loe tries again the next time you open it. Until then, Search finds only books from abroad."
        case .needsNewerLoe:
            "The catalogue needs a newer version of Loe."
        }
    }

    private func button(_ title: LocalizedStringKey) -> some View {
        Button(title, action: downloadNow)
            .buttonStyle(.borderedProminent)
            .tint(.loeAccent)
            .foregroundStyle(.loeOnAccent)
            .padding(.top, 4)
    }
}

extension CatalogueNotice {
    /// The notice for a store, whose button asks it for the catalogue.
    init(_ store: CatalogueStore) {
        self.init(download: store.download) {
            Task { await store.downloadCatalogue() }
        }
    }
}

/// A screen with nothing on it yet, under the notice. Where the two don't fit, on
/// a small screen or at a large text size, they scroll together, so the notice
/// never crowds the screen out.
struct UnderCatalogueNotice<Content: View>: View {
    let catalogue: CatalogueStore
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            stacked
            ScrollView { stacked }
        }
        .background(.loeBackground)
    }

    private var stacked: some View {
        VStack(spacing: 0) {
            CatalogueNotice(catalogue)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            content
                .frame(minHeight: 300)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CatalogueNotice(download: .inProgress(0.4)) {}
        CatalogueNotice(download: .waitingForWiFi) {}
        CatalogueNotice(download: .failed) {}
        CatalogueNotice(download: .needsNewerLoe) {}
    }
    .padding(20)
    .background(.loeBackground)
}

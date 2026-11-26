import SwiftUI

/// Search before the catalogue is on the phone: the offer to download it, its
/// progress, a way to try again, and word that Loe is too old for it.
struct CatalogueDownloadView: View {
    @Environment(CatalogueStore.self) private var catalogue

    var body: some View {
        switch catalogue.download {
        case .inProgress(let fraction):
            EmptyState(
                title: "Downloading the catalogue",
                systemImage: "arrow.down.circle",
                description: "You can keep using Loe while it downloads."
            ) {
                VStack(spacing: 8) {
                    ProgressView(value: fraction)
                        .tint(.loeAccent)
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.loeSecondary)
                }
                .frame(width: 220)
            }
        case .failed:
            EmptyState(
                title: "The download didn't finish",
                systemImage: "wifi.exclamationmark",
                description: "Check your connection and try again."
            ) {
                downloadButton("Try again")
            }
        case .needsNewerLoe:
            EmptyState(
                title: "Loe needs an update",
                systemImage: "arrow.up.circle",
                description: "The catalogue needs a newer version of Loe."
            ) {
                downloadButton("Try again")
            }
        case nil:
            EmptyState(
                title: "The catalogue isn't here yet",
                systemImage: "books.vertical",
                description: "Loe keeps every Estonian book on your phone, so search works offline. It's one download of about 30 MB."
            ) {
                downloadButton("Download the catalogue")
            }
        }
    }

    private func downloadButton(_ title: LocalizedStringKey) -> some View {
        Button(title) {
            Task { await catalogue.downloadCatalogue() }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.loeAccent)
        .foregroundStyle(.loeOnAccent)
    }
}

import SwiftUI

/// The catalogue on this phone: which edition, how big, and when Loe last looked
/// for a newer one. Loe fetches the catalogue by itself, so there is no removing
/// it: it would only come back.
struct CatalogueSection: View {
    @Environment(CatalogueStore.self) private var catalogue
    @State private var editions: Int?

    var body: some View {
        Section {
            switch catalogue.state {
            case .ready(let open):
                details
                    .task(id: catalogue.installedVersion) { editions = try? await open.editionCount() }
                checkButton
            case .unreadable:
                Text("The catalogue can't be read")
                    .foregroundStyle(.loeInk)
                fetching("Download it again")
            case .missing:
                fetching("Download the catalogue")
            }
        } header: {
            SettingsHeading("Catalogue")
        } footer: {
            Text("Every book published in Estonia, from the National Library of Estonia, so search works offline.")
        }
        .listRowBackground(Color.loeCard)
    }

    /// How fetching the catalogue is going, with a way to ask for it now.
    @ViewBuilder
    private func fetching(_ ask: LocalizedStringKey) -> some View {
        if case .inProgress(let fraction) = catalogue.download {
            progress(fraction)
        } else {
            Text(missing)
                .foregroundStyle(.loeSecondary)
            downloadButton(ask)
        }
    }

    @ViewBuilder
    private var details: some View {
        LabeledContent("Edition") {
            if let version = catalogue.installedVersion {
                if let month = CatalogueManifest.month(ofVersion: version) {
                    Text(month, format: .dateTime.month(.wide).year())
                } else {
                    Text(verbatim: version)
                }
            } else {
                Text("Unknown")
            }
        }
        if let editions {
            LabeledContent("Books") { Text("\(editions) editions") }
        }
        if let size = catalogue.sizeOnDisk {
            LabeledContent("On this phone") { Text(Int64(size), format: .byteCount(style: .file)) }
        }
        LabeledContent("Checked for a new edition") {
            if let checked = catalogue.lastChecked {
                Text(checked, format: .relative(presentation: .named))
            } else {
                Text("Not yet")
            }
        }
    }

    @ViewBuilder
    private var checkButton: some View {
        if case .inProgress(let fraction) = catalogue.download {
            progress(fraction)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Button("Check for a new edition") {
                    Task { await catalogue.checkNow() }
                }
                .tint(.loeAccent)
                .disabled(catalogue.isBusy)
                if let outcome {
                    Text(outcome)
                        .font(.subheadline)
                        .foregroundStyle(.loeSecondary)
                }
            }
        }
    }

    private var missing: LocalizedStringKey {
        switch catalogue.download {
        case .waitingForWiFi: "Waiting for Wi-Fi"
        case .failed: "The download didn't finish"
        case .needsNewerLoe: "The catalogue needs a newer version of Loe."
        case .inProgress, nil: "Not on this phone"
        }
    }

    private var outcome: LocalizedStringKey? {
        switch catalogue.check {
        case nil: nil
        case .checking: "Checking…"
        case .upToDate: "This is the newest edition."
        case .updated: "Updated to the newest edition."
        case .needsNewerLoe: "The newest edition needs a newer version of Loe."
        case .failed: "Couldn't check. Check your connection and try again."
        }
    }

    private func downloadButton(_ title: LocalizedStringKey) -> some View {
        Button(title) {
            Task { await catalogue.downloadCatalogue() }
        }
        .tint(.loeAccent)
        .disabled(catalogue.isBusy)
    }

    private func progress(_ fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Downloading the catalogue")
                .foregroundStyle(.loeInk)
            ProgressView(value: fraction)
                .tint(.loeAccent)
        }
        .accessibilityElement(children: .combine)
    }
}

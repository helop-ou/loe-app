import SwiftUI

/// Whether the shelves are reaching the reader's iCloud, and what to do when not.
/// Nothing in Loe can turn iCloud on, so it points to the Settings app.
struct CloudSyncRow: View {
    let status: CloudSync.Status
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At the largest sizes the text needs the whole width, so the icon goes above it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 14))
        layout {
            Image(systemName: symbol)
                .foregroundStyle(isTrouble ? .loeAccent : .loeSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.loeInk)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.loeSecondary)
                }
                if case .on(let lastSynced?) = status {
                    Text("Last synced \(lastSynced, format: .relative(presentation: .named))")
                        .font(.subheadline)
                        .foregroundStyle(.loeSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var isTrouble: Bool {
        switch status {
        case .checking, .on: false
        default: true
        }
    }

    private var symbol: String {
        switch status {
        case .checking: "icloud"
        case .on: "checkmark.icloud"
        case .off, .restricted: "icloud.slash"
        case .unavailable, .full, .offline, .failed: "exclamationmark.icloud"
        }
    }

    private var title: LocalizedStringKey {
        switch status {
        case .checking: "Checking iCloud…"
        case .on: "Your shelves sync with iCloud"
        case .off: "iCloud is off"
        case .restricted: "iCloud isn't allowed on this phone"
        case .unavailable: "iCloud isn't available right now"
        case .full: "Your iCloud is full"
        case .offline: "Waiting for a connection"
        case .failed: "The last sync didn't finish"
        }
    }

    private var detail: LocalizedStringKey? {
        switch status {
        case .checking:
            nil
        case .on:
            "They're on every device signed in to your iCloud that has Loe."
        case .off:
            "Your shelves are only on this phone. To keep them safe and on your other devices, sign in to iCloud in the Settings app."
        case .restricted:
            "Your shelves are only on this phone. Screen Time or a profile on this phone keeps apps out of iCloud."
        case .unavailable:
            "Your shelves are safe on this phone. In the Settings app, check that you're signed in to your Apple Account."
        case .full:
            "New changes stay on this phone until there's room. Free up space or get more in the Settings app, under your name and iCloud."
        case .offline:
            "Your changes are safe on this phone and sync once it's online."
        case .failed:
            "Your shelves are safe on this phone. Loe tries again by itself."
        }
    }
}

#Preview {
    List {
        CloudSyncRow(status: .on(lastSynced: .now.addingTimeInterval(-300)))
        CloudSyncRow(status: .full)
        CloudSyncRow(status: .off)
    }
}

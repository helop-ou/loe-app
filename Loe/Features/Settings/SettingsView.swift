import SwiftData
import SwiftUI

/// The reader's own settings: for now, what they like to read.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var tastes: [Taste]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your tastes")
                    .loeHeading(.section)
                    .foregroundStyle(.loeInk)
                GenrePicker(selection: Binding {
                    Set(Taste.genres(tastes))
                } set: { genres in
                    try? Taste.set(genres, in: context)
                })
                Text("Read next suggests books from these. They stay on your phone and in your iCloud.")
                    .font(.footnote)
                    .foregroundStyle(.loeSecondary)
            }
            .padding(20)
        }
        .background(.loeBackground)
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [ShelvedBook.self, Taste.self], inMemory: true)
}

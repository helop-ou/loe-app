import SwiftData
import SwiftUI

/// The reader's own settings: what they like to read, where they get books, how
/// Loe looks, iCloud and the catalogue, with the About page at the end.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(CloudSync.self) private var cloudSync
    @AppStorage(LoeAppearance.storageKey) private var appearance = LoeAppearance.system
    @Query private var tastes: [Taste]
    @Query private var chosen: [ChosenPlace]
    @State private var choosingPlaces = false
    @State private var retakingQuiz = false
    // The system's Edit button and Delete action have no Estonian, as iOS has no
    // Estonian system language, so Loe brings its own.
    @State private var editMode = EditMode.inactive

    var body: some View {
        let places = ChosenPlace.places(chosen)
        List {
            // The chips fill the width, so the heading and note go in the row to line up with them.
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsHeading("Your tastes")
                        .padding(.horizontal, 4)
                    GenrePicker(selection: Binding {
                        Set(Taste.genres(tastes))
                    } set: { genres in
                        try? Taste.set(genres, in: context)
                    })
                    Text("Read next suggests books from these. They stay on your phone and in your iCloud.")
                        .font(.footnote)
                        .foregroundStyle(.loeSecondary)
                        .padding(.horizontal, 4)
                    Button("Take the quiz again") { retakingQuiz = true }
                        .tint(.loeAccent)
                        .padding(.horizontal, 4)
                }
                // The section still clips to a rounded card, so keep the text clear of its corners.
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(places) { place in
                    PlaceRow(place: place)
                        .swipeActions {
                            Button(role: .destructive) {
                                try? ChosenPlace.remove(place, in: context)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
                .onMove { from, to in
                    var reordered = places
                    reordered.move(fromOffsets: from, toOffset: to)
                    try? ChosenPlace.reorder(reordered, in: context)
                }
                .listRowBackground(Color.loeCard)
                Button("Add a library or bookshop") { choosingPlaces = true }
                    .tint(.loeAccent)
                    .listRowBackground(Color.loeCard)
            } header: {
                SettingsHeading("Where to get it")
            } footer: {
                Text("A book's page lists these, in this order. With none chosen, it shows ESTER, Rahva Raamat and Apollo.")
            }

            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(LoeAppearance.allCases, id: \.self) { choice in
                        Text(choice.name).tag(choice)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .tint(.loeAccent)
                .listRowBackground(Color.loeCard)
            } header: {
                SettingsHeading("Appearance")
            }

            Section {
                CloudSyncRow(status: cloudSync.status)
                    .listRowBackground(Color.loeCard)
            } header: {
                SettingsHeading("iCloud")
            } footer: {
                Text("There's no Loe account. Your shelves, ratings, tastes and libraries go to your own iCloud and nowhere else.")
            }

            CatalogueSection()

            Section {
                NavigationLink("About Loe") { AboutView() }
                    .foregroundStyle(.loeInk)
                    .listRowBackground(Color.loeCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(.loeBackground)
        .loeNavigationTitle("Settings")
        .environment(\.editMode, $editMode)
        .toolbar {
            if places.count > 1 || editMode.isEditing {
                Button(editMode.isEditing ? "Done" : "Edit") {
                    withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                }
            }
        }
        .sheet(isPresented: $choosingPlaces) {
            PlacePicker()
        }
        .sheet(isPresented: $retakingQuiz) {
            TasteQuiz()
        }
        .task { await cloudSync.refreshAccount() }
    }
}

/// A section's heading in Newsreader, as Settings and About set them.
struct SettingsHeading: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .loeHeading(.section)
            .foregroundStyle(.loeInk)
            .textCase(nil)
    }
}

/// A library or shop by name, with the library a branch belongs to.
struct PlaceRow: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name)
                .foregroundStyle(.loeInk)
            if let group = place.group {
                Text(group)
                    .font(.subheadline)
                    .foregroundStyle(.loeSecondary)
            } else if place.kind == .shop {
                Text("Bookshop")
                    .font(.subheadline)
                    .foregroundStyle(.loeSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(CatalogueStore())
    .environment(CloudSync())
    .modelContainer(for: [ShelvedBook.self, Taste.self, ChosenPlace.self], inMemory: true)
}

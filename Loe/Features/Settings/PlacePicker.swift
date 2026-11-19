import SwiftData
import SwiftUI

/// Every library in ESTER and the bookshops, to tick for "Where to get it".
struct PlacePicker: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var chosen: [ChosenPlace]
    @State private var search = ""

    var body: some View {
        let picked = Set(chosen.map(\.placeID))
        NavigationStack {
            List {
                section(Text(verbatim: Place.tallinn), Place.tallinnBranches, picked: picked)
                section(Text(verbatim: Place.tartu), Place.tartuBranches, picked: picked)
                section(Text("Other libraries in ESTER"), Place.otherLibraries, picked: picked)
                section(Text("Bookshops"), Place.shops, picked: picked)
            }
            .scrollContentBackground(.hidden)
            .background(.loeBackground)
            .searchable(text: $search, prompt: Text("Find a library"))
            .navigationTitle("Libraries and bookshops")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: Text, _ places: [Place], picked: Set<String>) -> some View {
        let shown = places.filter(matchesSearch)
        if !shown.isEmpty {
            Section {
                ForEach(shown) { place in
                    let isPicked = picked.contains(place.id)
                    Button {
                        if isPicked {
                            try? ChosenPlace.remove(place, in: context)
                        } else {
                            try? ChosenPlace.add(place, in: context)
                        }
                    } label: {
                        HStack {
                            Text(place.name)
                                .foregroundStyle(.loeInk)
                            Spacer()
                            if isPicked {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.loeAccent)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .accessibilityAddTraits(isPicked ? .isSelected : [])
                    .listRowBackground(Color.loeCard)
                }
            } header: {
                title
            }
        }
    }

    private func matchesSearch(_ place: Place) -> Bool {
        let words = CatalogueQuery.folded(search).split(separator: " ")
        let text = CatalogueQuery.folded([place.name, place.group ?? ""].joined(separator: " "))
        return words.allSatisfy { text.contains($0) }
    }
}

#Preview {
    PlacePicker()
        .modelContainer(for: [ShelvedBook.self, Taste.self, ChosenPlace.self], inMemory: true)
}

import SwiftUI

/// On a book's page: when the reader started the book and when they finished it,
/// with the way to change either.
struct ReadingDatesRow: View {
    let book: ShelvedBook

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var editing = false

    var body: some View {
        let lines = book.readingDates.lines(on: book.shelf, in: locale)
        let title: LocalizedStringKey = lines.isEmpty ? "Add dates" : "Change dates"
        // The button goes under the dates at the largest text sizes, where beside
        // them neither has room.
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        layout {
            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(lines, id: \.self) { line in
                        Text(verbatim: line)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.loeSecondary)
                if !stacked {
                    Spacer()
                }
            }
            Button(title) { editing = true }
                .font(.subheadline.weight(.semibold))
                .tint(.loeAccent)
        }
        .sheet(isPresented: $editing) {
            ReadingDatesSheet(book: book)
        }
    }
}

/// Sets or clears when a book was started and finished. The finish is offered
/// for a book that is on Read.
private struct ReadingDatesSheet: View {
    let book: ShelvedBook

    @Environment(\.dismiss) private var dismiss
    @State private var dates: ReadingDates

    init(book: ShelvedBook) {
        self.book = book
        _dates = State(initialValue: book.readingDates)
    }

    var body: some View {
        let today = Date.now
        let finishes = ReadingDates.showsFinish(on: book.shelf)
        NavigationStack {
            Form {
                Section {
                    day(
                        "Started", $dates.started, from: .distantPast, to: finishes ? dates.finished ?? today : today,
                        add: "Add a start date", remove: "Remove the start date"
                    )
                }
                if finishes {
                    Section {
                        day(
                            "Finished", $dates.finished, from: dates.started ?? .distantPast, to: today,
                            add: "Add a finish date", remove: "Remove the finish date"
                        )
                    }
                }
            }
            .tint(.loeAccent)
            .loeNavigationTitle("Reading dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        book.setReadingDates(dates)
                        dismiss()
                    }
                }
            }
        }
        // Half the screen holds both dates, and the whole of it at the largest text sizes.
        .presentationDetents([.medium, .large])
    }

    /// A date with the way to take it away, or the way to add one. A new date
    /// starts on the latest day it may be.
    @ViewBuilder
    private func day(
        _ label: LocalizedStringKey, _ date: Binding<Date?>, from earliest: Date, to latest: Date,
        add: LocalizedStringKey, remove: LocalizedStringKey
    ) -> some View {
        if let picked = date.wrappedValue {
            // Never a range that runs backwards, whatever the dates it was given.
            DatePicker(
                label, selection: Binding { picked } set: { date.wrappedValue = $0 },
                in: min(earliest, latest)...latest, displayedComponents: .date
            )
            Button(remove) { date.wrappedValue = nil }
        } else {
            Button(add) { date.wrappedValue = latest }
        }
    }
}

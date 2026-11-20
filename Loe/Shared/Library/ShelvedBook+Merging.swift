import Foundation
import SwiftData

extension ShelvedBook {
    /// Makes one record of each book that two devices shelved while they were
    /// apart, and answers how many records went. Every device works it out the
    /// same way, so they agree on which record stays. See docs/library.md, "Rules".
    @discardableResult
    static func mergeDuplicates(in context: ModelContext) throws -> Int {
        let groups = duplicates(among: try context.fetch(FetchDescriptor<ShelvedBook>()))
        guard !groups.isEmpty else { return 0 }
        for group in groups {
            group[0].absorb(group.dropFirst())
            group.dropFirst().forEach(context.delete)
        }
        try context.save()
        return groups.reduce(0) { $0 + $1.count - 1 }
    }

    /// Records that are one book, the first one shelved first: they share a
    /// catalogue record, an Open Library work or a work key. A book entered by
    /// hand is only ever itself.
    static func duplicates(among books: [ShelvedBook]) -> [[ShelvedBook]] {
        var groups: [[ShelvedBook]] = []
        var groupOf: [String: Int] = [:]
        for book in books.sorted(by: shelvedBefore) where book.source != .hand {
            let found = Set(book.marks.compactMap { groupOf[$0] }).sorted()
            let group = found.first ?? groups.count
            if found.isEmpty { groups.append([]) }
            // One record can show that two groups were the same book all along.
            for other in found.dropFirst() {
                groups[group] += groups[other]
                groups[other] = []
            }
            groups[group].append(book)
            for mark in groups[group].flatMap(\.marks) { groupOf[mark] = group }
        }
        return groups.filter { $0.count > 1 }.map { $0.sorted(by: shelvedBefore) }
    }

    /// Takes in what the reader did to the other records of this book. The latest
    /// change decides the shelf, the furthest page stays, and no rating, photo or
    /// date is dropped.
    func absorb(_ others: some Sequence<ShelvedBook>) {
        let all = ([self] + others).sorted {
            $0.updatedAt != $1.updatedAt ? $0.updatedAt > $1.updatedAt : Self.shelvedBefore($0, $1)
        }
        shelfName = all[0].shelfName
        rating = all.lazy.compactMap(\.rating).first
        var furthest: ShelvedBook?
        for book in all where (book.currentPage ?? -1) > (furthest?.currentPage ?? -1) {
            furthest = book
        }
        currentPage = furthest?.currentPage
        pageCount = furthest?.pageCount ?? pageCount ?? all.lazy.compactMap(\.pageCount).first
        startedAt = all.compactMap(\.startedAt).min()
        finishedAt = all.compactMap(\.finishedAt).max()
        if let photographed = all.first(where: { $0.coverPhoto != nil }) {
            coverPhoto = photographed.coverPhoto
            coverHue = photographed.coverHue
            coverSaturation = photographed.coverSaturation
        }
        updatedAt = all[0].updatedAt
    }

    /// What two records of one book have in common.
    private var marks: [String] {
        ["key:" + workKey]
            + (erbID.isEmpty ? [] : ["record:" + erbID])
            + (openLibraryRecord.map { ["work:" + $0.workKey] } ?? [])
    }

    /// The same order on every device: by when the book was shelved, then by what
    /// the record holds.
    private static func shelvedBefore(_ a: ShelvedBook, _ b: ShelvedBook) -> Bool {
        (a.addedAt, a.workKey, a.erbID, a.updatedAt) < (b.addedAt, b.workKey, b.erbID, b.updatedAt)
    }
}

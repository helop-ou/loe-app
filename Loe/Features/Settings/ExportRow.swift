import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// "Export my shelves" in Settings: the shelves as a CSV file, handed to the
/// system's share sheet. The file is written only once the reader shares it.
struct ExportRow: View {
    let books: [ShelvesExport.Book]

    var body: some View {
        // The sheet shows the file's own name, so the two cannot differ.
        let file = ShelvesFile(books: books)
        ShareLink(item: file, preview: SharePreview(Text(verbatim: file.name))) {
            Text("Export my shelves")
        }
        .tint(.loeAccent)
        .disabled(books.isEmpty)
    }
}

/// The export as a file for the share sheet.
nonisolated struct ShelvesFile: Transferable {
    let books: [ShelvesExport.Book]
    /// Named for the day it is made, unless told otherwise.
    var name = ShelvesExport.fileName()

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            SentTransferredFile(try ShelvesExport.write(file.books, named: file.name))
        }
    }
}

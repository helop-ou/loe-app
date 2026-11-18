import SwiftUI
import Vision
import VisionKit

/// The camera, reading the barcode on the back of a book. Reports the first ISBN
/// it sees, once.
struct BarcodeScanner: UIViewControllerRepresentable {
    let onISBN: (String) -> Void

    /// False on the simulator and on phones without the hardware, where Search
    /// leaves the scan button out.
    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onISBN: onISBN)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onISBN: (String) -> Void
        private var found = false

        init(onISBN: @escaping (String) -> Void) {
            self.onISBN = onISBN
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !found else { return }
            for item in items {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue,
                      let isbn = CatalogueQuery.isbn13(fromBarcode: payload)
                else { continue }
                found = true
                scanner.stopScanning()
                onISBN(isbn)
                return
            }
        }
    }
}

/// The scanner as a sheet, with a hint and a way out.
struct ScanSheet: View {
    let onISBN: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BarcodeScanner { isbn in
                dismiss()
                onISBN(isbn)
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Text("Point the camera at the barcode on the back of the book.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    .padding(24)
            }
            .navigationTitle("Scan a barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

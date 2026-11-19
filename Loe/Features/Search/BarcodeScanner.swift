import SwiftUI
import Vision
import VisionKit

/// The camera, reading the barcode on the back of a book. Reports the first ISBN
/// it sees, once, or that the camera cannot be used.
struct BarcodeScanner: UIViewControllerRepresentable {
    let onISBN: (String) -> Void
    let onUnavailable: () -> Void

    /// False on the simulator and on phones without the hardware, where Search
    /// leaves the scan button out.
    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    func makeUIViewController(context: Context) -> ScannerHost {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return ScannerHost(scanner: scanner, onUnavailable: onUnavailable)
    }

    func updateUIViewController(_ host: ScannerHost, context: Context) {}

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

/// Holds the scanner and starts it once it is on screen. Started any earlier, as
/// from SwiftUI's update pass, `startScanning()` fails and nothing scans.
final class ScannerHost: UIViewController {
    private let scanner: DataScannerViewController
    private let onUnavailable: () -> Void

    init(scanner: DataScannerViewController, onUnavailable: @escaping () -> Void) {
        self.scanner = scanner
        self.onUnavailable = onUnavailable
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        scanner.view.frame = view.bounds
        scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !scanner.isScanning else { return }
        do {
            try scanner.startScanning()
        } catch {
            onUnavailable()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner.stopScanning()
    }
}

/// The scanner as a sheet, with a hint and a way out.
struct ScanSheet: View {
    let onISBN: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var unavailable = false

    var body: some View {
        NavigationStack {
            Group {
                if unavailable {
                    EmptyState(
                        title: "The camera isn't available",
                        systemImage: "camera",
                        description: "Allow Loe to use the camera in Settings, or type the ISBN into Search."
                    ) {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.loeAccent)
                        .foregroundStyle(.loeOnAccent)
                    }
                } else {
                    BarcodeScanner { isbn in
                        dismiss()
                        onISBN(isbn)
                    } onUnavailable: {
                        unavailable = true
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
                }
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

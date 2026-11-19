import AVFoundation
import SwiftUI
import Vision
import VisionKit

/// The camera, reading the barcode on the back of a book. Reports the first ISBN
/// it sees, once, any other barcode in view so the reader can be told, or that the
/// camera cannot be used.
struct BarcodeScanner: UIViewControllerRepresentable {
    let onISBN: (String) -> Void
    /// The kind of the other barcode in view, or nil once it is gone.
    let onOther: (ScannedBarcode?) -> Void
    let onUnavailable: () -> Void

    /// False on the simulator and on phones without the hardware, where Search
    /// leaves the scan button out.
    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    func makeUIViewController(context: Context) -> ScannerHost {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: ScannedBarcode.symbologies)],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return ScannerHost(scanner: scanner, onUnavailable: onUnavailable)
    }

    func updateUIViewController(_ host: ScannerHost, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onISBN: onISBN, onOther: onOther, onUnavailable: onUnavailable)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onISBN: (String) -> Void
        private let onOther: (ScannedBarcode?) -> Void
        private let onUnavailable: () -> Void
        private var found = false
        private var other: ScannedBarcode?

        init(onISBN: @escaping (String) -> Void, onOther: @escaping (ScannedBarcode?) -> Void, onUnavailable: @escaping () -> Void) {
            self.onISBN = onISBN
            self.onOther = onOther
            self.onUnavailable = onUnavailable
        }

        func dataScanner(_ scanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            onUnavailable()
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            examine(allItems, in: scanner)
        }

        func dataScanner(_ scanner: DataScannerViewController, didUpdate items: [RecognizedItem], allItems: [RecognizedItem]) {
            examine(allItems, in: scanner)
        }

        func dataScanner(_ scanner: DataScannerViewController, didRemove items: [RecognizedItem], allItems: [RecognizedItem]) {
            examine(allItems, in: scanner)
        }

        private func examine(_ items: [RecognizedItem], in scanner: DataScannerViewController) {
            guard !found else { return }
            let barcodes = items.compactMap { item -> ScannedBarcode? in
                guard case .barcode(let barcode) = item else { return nil }
                return ScannedBarcode(payload: barcode.payloadStringValue, symbology: barcode.observation.symbology)
            }
            let best = ScannedBarcode.best(of: barcodes)
            if case .isbn(let isbn) = best {
                found = true
                scanner.stopScanning()
                onISBN(isbn)
            } else if best != other {
                other = best
                onOther(best)
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
        start(retrying: true)
    }

    /// The camera can still be settling just after it appears, so a failed start
    /// gets one more try before the reader is told.
    private func start(retrying: Bool) {
        guard !scanner.isScanning else { return }
        do {
            try scanner.startScanning()
        } catch where retrying {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                start(retrying: false)
            }
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
    @State private var cameraAllowed = false
    @State private var other: ScannedBarcode?

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
                } else if !cameraAllowed {
                    Color.black.ignoresSafeArea()
                } else {
                    BarcodeScanner { isbn in
                        dismiss()
                        onISBN(isbn)
                    } onOther: { barcode in
                        other = barcode
                    } onUnavailable: {
                        unavailable = true
                    }
                    .ignoresSafeArea()
                    .overlay(alignment: .bottom) {
                        ScanHint(other: other)
                            .padding(24)
                    }
                }
            }
            // The scanner can only start once the camera is allowed, so ask first
            // rather than let iOS ask while the scanner is already trying.
            .task {
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .authorized: cameraAllowed = true
                case .notDetermined: cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
                default: cameraAllowed = false
                }
                unavailable = !cameraAllowed || !DataScannerViewController.isAvailable
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

/// What the scanner is doing, or why the barcode in view does not open a book.
struct ScanHint: View {
    let other: ScannedBarcode?
    /// The icons differ in width, so the text starts in the same place for each.
    @ScaledMetric(relativeTo: .subheadline) private var iconWidth = 22.0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Group {
                switch other {
                case .library: Image(systemName: "building.columns")
                case .notABook: Image(systemName: "barcode")
                case .isbn, nil: Image(systemName: "barcode.viewfinder").symbolEffect(.pulse)
                }
            }
            .foregroundStyle(.loeAccent)
            .frame(width: iconWidth)
            .accessibilityHidden(true)
            Text(message)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .onChange(of: other) {
            AccessibilityNotification.Announcement(String(localized: message)).post()
        }
    }

    private var message: LocalizedStringResource {
        switch other {
        case .library: "That's the library's barcode. Look for the one that starts with 978."
        case .notABook: "That barcode isn't an ISBN. Look for the one that starts with 978 or 979."
        case .isbn, nil: "Point the camera at the barcode on the back of the book."
        }
    }
}

//
//  BarcodeScannerView.swift
//  Odysseus
//
//  Thin VisionKit wrapper — real camera only, doesn't work in Simulator.
//  DataScannerViewController has no macOS counterpart (no built-in camera
//  API in VisionKit there), so barcode scanning is iOS/iPadOS-only; the Mac
//  build falls back to manual entry in LogFoodSheet.
//

#if os(iOS)
import SwiftUI
import VisionKit

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didScan else { return }
            for item in addedItems {
                if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue {
                    didScan = true
                    onScan(payload)
                    return
                }
            }
        }
    }
}
#endif

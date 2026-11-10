import AVFoundation
import SwiftUI
import VisionKit

/// Full-screen camera that reads the PC's pairing QR code and hands back the link it holds.
/// Uses VisionKit's DataScanner where the device supports it, otherwise AVCaptureMetadataOutput.
struct QRScannerSheet: View {
    var onScan: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var denied = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            if denied {
                ContentUnavailableView {
                    Label("Camera Is Off", systemImage: "camera.slash")
                } description: {
                    Text("Allow Phone Use to use the camera in Settings, or paste the pairing link instead.")
                } actions: {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                .foregroundStyle(.white)
            } else if DataScannerViewController.isSupported {
                DataScannerView(onScan: found).ignoresSafeArea()
            } else {
                MetadataScannerView(onScan: found).ignoresSafeArea()
            }
            VStack(spacing: 16) {
                if !denied {
                    Text("Point the camera at the code on your computer.")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.black.opacity(0.55), in: Capsule())
                }
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.25))
                    .controlSize(.large)
                    .accessibilityIdentifier("cancelScan")
            }
            .padding(.bottom, 32)
        }
        .task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined: denied = !(await AVCaptureDevice.requestAccess(for: .video))
            case .denied, .restricted: denied = true
            default: break
            }
        }
    }

    private func found(_ text: String) {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme != nil else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScan(url)
    }
}

private struct DataScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                           qualityLevel: .balanced, isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) {
        vc.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var done = false
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for case let .barcode(code) in items {
                if !done, let text = code.payloadStringValue {
                    done = true
                    onScan(text)
                }
            }
        }
    }
}

private struct MetadataScannerView: UIViewRepresentable {
    var onScan: (String) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let session = context.coordinator.session
        if let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
                output.metadataObjectTypes = [.qr]
            }
        }
        view.preview.session = session
        view.preview.videoGravity = .resizeAspectFill
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    static func dismantleUIView(_ view: PreviewView, coordinator: Coordinator) {
        let session = coordinator.session
        DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let session = AVCaptureSession()
        let onScan: (String) -> Void
        private var done = false
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !done, let code = objects.first as? AVMetadataMachineReadableCodeObject,
                  let text = code.stringValue else { return }
            done = true
            onScan(text)
        }
    }
}

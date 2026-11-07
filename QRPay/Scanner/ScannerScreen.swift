import AVFoundation
import SwiftUI

struct ScannerScreen: View {
    var onFound: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            QRScannerView(onFound: onFound).ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Kapat")
                }
                .padding()
                Spacer()
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 260, height: 260)
                Spacer()
                Text("Karekodu çerçeveye hizala")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.bottom, 48)
            }
        }
        .background(.black)
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    var onFound: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onFound = onFound
        return vc
    }

    func updateUIViewController(_ vc: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var found = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                granted ? self?.configure() : self?.showDenied()
            }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func showDenied() {
        let label = UILabel()
        label.text = "Kamera izni yok.\nAyarlar → QR Öde → Kamera'yı açın."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.frame = view.bounds.insetBy(dx: 24, dy: 0)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(label)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !found,
              let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue
        else { return }
        found = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        session.stopRunning()
        onFound?(code)
    }
}

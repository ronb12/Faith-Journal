//
//  QRCodeScannerView.swift
//  Faith Journal
//
//  QR code scanner for scanning invitation codes
//

import SwiftUI
import AVFoundation

@available(iOS 17.0, *)
struct QRCodeScannerView: UIViewControllerRepresentable {
    @Binding var scannedCode: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QRCodeScannerDelegate {
        var parent: QRCodeScannerView
        
        init(_ parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func didScanCode(_ code: String) {
            DispatchQueue.main.async {
                self.parent.scannedCode = code
                self.parent.dismiss()
            }
        }
        
        func didFailWithError(_ error: Error) {
            print("QR Scanner Error: \(error.localizedDescription)")
        }
    }
}

// Protocol for scanner delegate
@available(iOS 17.0, *)
protocol QRCodeScannerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFailWithError(_ error: Error)
}

// Scanner view controller
@available(iOS 17.0, *)
class ScannerViewController: UIViewController {
    weak var delegate: QRCodeScannerDelegate?
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScanner()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
    
    private func setupScanner() {
        // Request camera permission
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else {
                DispatchQueue.main.async {
                    self?.showPermissionAlert()
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.setupCaptureSession()
            }
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        self.captureSession = session
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError(NSError(domain: "QRScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Camera not available"]))
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFailWithError(error)
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            delegate?.didFailWithError(NSError(domain: "QRScanner", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"]))
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            delegate?.didFailWithError(NSError(domain: "QRScanner", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add metadata output"]))
            return
        }
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        
        // Add overlay with scanning frame
        let overlayView = createOverlayView()
        view.addSubview(overlayView)
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Cancel", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        closeButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.7)
        closeButton.layer.cornerRadius = 25
        closeButton.frame = CGRect(x: 20, y: 50, width: 100, height: 50)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        session.startRunning()
    }
    
    private func createOverlayView() -> UIView {
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // Create transparent scanning frame
        let scanFrameSize: CGFloat = 250
        let scanFrame = UIView(frame: CGRect(
            x: (view.bounds.width - scanFrameSize) / 2,
            y: (view.bounds.height - scanFrameSize) / 2,
            width: scanFrameSize,
            height: scanFrameSize
        ))
        scanFrame.layer.borderColor = UIColor.systemPurple.cgColor
        scanFrame.layer.borderWidth = 2
        scanFrame.layer.cornerRadius = 20
        scanFrame.backgroundColor = .clear
        
        // Make the frame area transparent
        let maskLayer = CAShapeLayer()
        let path = UIBezierPath(rect: overlayView.bounds)
        let framePath = UIBezierPath(roundedRect: scanFrame.frame, cornerRadius: 20)
        path.append(framePath.reversing())
        maskLayer.path = path.cgPath
        overlayView.layer.mask = maskLayer
        
        overlayView.addSubview(scanFrame)
        
        // Add corner indicators
        let cornerLength: CGFloat = 30
        let cornerWidth: CGFloat = 3
        
        // Top-left corner
        let topLeft = createCornerIndicator(length: cornerLength, width: cornerWidth)
        topLeft.frame = CGRect(x: scanFrame.frame.minX, y: scanFrame.frame.minY, width: cornerLength, height: cornerLength)
        overlayView.addSubview(topLeft)
        
        // Top-right corner
        let topRight = createCornerIndicator(length: cornerLength, width: cornerWidth, position: .topRight)
        topRight.frame = CGRect(x: scanFrame.frame.maxX - cornerLength, y: scanFrame.frame.minY, width: cornerLength, height: cornerLength)
        overlayView.addSubview(topRight)
        
        // Bottom-left corner
        let bottomLeft = createCornerIndicator(length: cornerLength, width: cornerWidth, position: .bottomLeft)
        bottomLeft.frame = CGRect(x: scanFrame.frame.minX, y: scanFrame.frame.maxY - cornerLength, width: cornerLength, height: cornerLength)
        overlayView.addSubview(bottomLeft)
        
        // Bottom-right corner
        let bottomRight = createCornerIndicator(length: cornerLength, width: cornerWidth, position: .bottomRight)
        bottomRight.frame = CGRect(x: scanFrame.frame.maxX - cornerLength, y: scanFrame.frame.maxY - cornerLength, width: cornerLength, height: cornerLength)
        overlayView.addSubview(bottomRight)
        
        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Position the QR code within the frame"
        instructionLabel.textColor = .white
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.frame = CGRect(
            x: 20,
            y: scanFrame.frame.maxY + 20,
            width: view.bounds.width - 40,
            height: 30
        )
        overlayView.addSubview(instructionLabel)
        
        return overlayView
    }
    
    private func createCornerIndicator(length: CGFloat, width: CGFloat, position: CornerPosition = .topLeft) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        let shapeLayer = CAShapeLayer()
        let path = UIBezierPath()
        
        switch position {
        case .topLeft:
            path.move(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
        case .topRight:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: length, y: 0))
            path.addLine(to: CGPoint(x: length, y: length))
        case .bottomLeft:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: length))
            path.addLine(to: CGPoint(x: length, y: length))
        case .bottomRight:
            path.move(to: CGPoint(x: length, y: 0))
            path.addLine(to: CGPoint(x: length, y: length))
            path.addLine(to: CGPoint(x: 0, y: length))
        }
        
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.systemPurple.cgColor
        shapeLayer.lineWidth = width
        shapeLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(shapeLayer)
        
        return view
    }
    
    private enum CornerPosition {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    private func startScanning() {
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }
    
    private func stopScanning() {
        if let session = captureSession, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Permission Required",
            message: "Please enable camera access in Settings to scan QR codes.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

@available(iOS 17.0, *)
extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            // Play haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Stop scanning
            stopScanning()
            
            // Extract the code from different formats
            let extractedCode = extractInviteCode(from: stringValue)
            print("🔗 [QR SCANNER] Scanned: \(stringValue)")
            print("🔗 [QR SCANNER] Extracted code: \(extractedCode)")
            
            // Notify delegate with extracted code
            delegate?.didScanCode(extractedCode)
        }
    }
    
    /// Extracts the invitation code from various QR code formats
    private func extractInviteCode(from scannedValue: String) -> String {
        // Format 1: faithjournal://invite/CODE
        if scannedValue.hasPrefix("faithjournal://invite/") {
            let code = scannedValue.replacingOccurrences(of: "faithjournal://invite/", with: "")
            return code.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Format 2: https://faith-journal.web.app/invite/CODE
        else if scannedValue.hasPrefix("https://faith-journal.web.app/invite/") {
            let code = scannedValue.replacingOccurrences(of: "https://faith-journal.web.app/invite/", with: "")
            return code.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Format 3: Just the code itself (e.g., "ABC12345")
        else {
            // If it's just alphanumeric and looks like an invite code, return it
            let trimmed = scannedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            // Invite codes are typically 8 characters alphanumeric
            if trimmed.count <= 20 && trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) {
                return trimmed.uppercased()
            }
            // If it's a URL that might contain the code, try to extract it
            if let url = URL(string: scannedValue) {
                // Check if it's our deep link format
                if url.scheme == "faithjournal" && url.host == "invite" {
                    let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
                    if let code = pathComponents.first {
                        return code.uppercased()
                    }
                }
            }
            // Default: return as-is (might be just the code)
            return trimmed.uppercased()
        }
    }
}


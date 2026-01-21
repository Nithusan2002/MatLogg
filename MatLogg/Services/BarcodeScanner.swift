import Foundation
import Vision
import AVFoundation

class BarcodeScanner: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeDetected: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    func startScanning(in view: UIView) -> AVCaptureVideoPreviewLayer? {
        let captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            onError?("Kamera er ikke tilgjengelig")
            return nil
        }
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            onError?("Kunne ikke sette opp kamera")
            return nil
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            onError?("Kunne ikke legge til video input")
            return nil
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce]
        } else {
            onError?("Kunne ikke legge til metadata output")
            return nil
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async {
            captureSession.startRunning()
        }
        
        self.captureSession = captureSession
        self.previewLayer = previewLayer
        
        return previewLayer
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
    }
    
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject else {
            return
        }
        
        if let stringValue = readableObject.stringValue {
            onBarcodeDetected?(stringValue)
            stopScanning()
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onBarcodeDetected: (String) -> Void
    var onError: (String) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.onBarcodeDetected = onBarcodeDetected
        controller.onError = onError
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
}

class BarcodeScannerViewController: UIViewController {
    var onBarcodeDetected: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    private let scanner = BarcodeScanner()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        scanner.onBarcodeDetected = { [weak self] barcode in
            self?.onBarcodeDetected?(barcode)
        }
        
        scanner.onError = { [weak self] error in
            self?.onError?(error)
        }
        
        scanner.startScanning(in: view)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner.stopScanning()
    }
}

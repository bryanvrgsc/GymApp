//
//  StaffQRScannerView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI
import AVFoundation

/// Staff view for scanning member QR codes and processing check-in/out
struct StaffQRScannerView: View {
    @ObservedObject private var authState = AuthState.shared
    
    @State private var isScanning = true
    @State private var scannedUser: GymUser?
    @State private var validationError: String?
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var lastAction: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                if isScanning {
                    // Scanner view
                    scannerView
                } else if let user = scannedUser {
                    // User validated - show check-in/out options
                    userActionView(user: user)
                } else if let error = validationError {
                    // Error view
                    errorView(message: error)
                }
            }
            .navigationTitle("Check-In")
            .alert("¡Listo!", isPresented: $showSuccess) {
                Button("OK") {
                    resetScanner()
                }
            } message: {
                Text(successMessage)
            }
        }
    }
    
    // MARK: - Scanner View
    
    private var scannerView: some View {
        ZStack {
            // Camera scanner
            QRScannerRepresentable { code in
                handleScannedCode(code)
            }
            .ignoresSafeArea()
            
            // Overlay
            VStack {
                Spacer()
                
                // Scan frame
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 250, height: 250)
                    .background(Color.clear)
                
                Spacer()
                
                // Instructions
                VStack(spacing: 8) {
                    Text("Escanea el código QR del miembro")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Asegúrate de que el código esté dentro del marco")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.bottom, 50)
            }
        }
    }
    
    // MARK: - User Action View
    
    private func userActionView(user: GymUser) -> some View {
        VStack(spacing: 24) {
            // User info
            VStack(spacing: 16) {
                if let pic = user.picture, let url = URL(string: pic) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        default:
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.accentColor)
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.accentColor)
                }
                
                Text(user.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                if let email = user.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Membership status
                if let membership = user.membership {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Membresía \(membership.planType.displayName)")
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(membership.daysRemaining) días")
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            // Action buttons
            VStack(spacing: 16) {
                Button {
                    Task { await processCheckIn(user: user) }
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("CHECK-IN")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
                
                Button {
                    Task { await processCheckOut(user: user) }
                } label: {
                    HStack {
                        Image(systemName: "arrow.left.circle.fill")
                        Text("CHECK-OUT")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            }
            .padding(.horizontal, 32)
            
            if isProcessing {
                ProgressView("Procesando...")
            }
            
            // Cancel button
            Button {
                resetScanner()
            } label: {
                Text("Cancelar")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 16)
        }
        .padding()
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("Error de Validación")
                .font(.title)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                resetScanner()
            } label: {
                Text("Escanear de nuevo")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func handleScannedCode(_ code: String) {
        isScanning = false
        
        // Validate token
        let result = QRTokenService.shared.validateToken(code)
        
        switch result {
        case .valid(let userId):
            // Fetch user and verify membership
            Task {
                await fetchAndValidateUser(userId: userId)
            }
        case .invalid(let reason), .expired(let reason):
            validationError = reason
        }
    }
    
    private func fetchAndValidateUser(userId: String) async {
        do {
            guard let user = try await FirebaseService.shared.getUser(auth0UserId: userId) else {
                await MainActor.run {
                    validationError = "Usuario no encontrado"
                }
                return
            }
            
            // Check membership
            let isActive = user.membership?.isActive ?? user.isActive
            guard isActive else {
                await MainActor.run {
                    validationError = "Membresía inactiva o expirada"
                }
                return
            }
            
            await MainActor.run {
                scannedUser = user
            }
        } catch {
            await MainActor.run {
                validationError = "Error al verificar usuario"
            }
        }
    }
    
    private func processCheckIn(user: GymUser) async {
        isProcessing = true
        
        do {
            guard let staffId = authState.gymUser?.id else { return }
            
            try await FirebaseService.shared.recordCheckIn(
                userId: user.id,
                staffId: staffId,
                gymId: "default"
            )
            
            await MainActor.run {
                successMessage = "\(user.name) ha ingresado correctamente"
                showSuccess = true
                lastAction = "checkin"
            }
        } catch {
            await MainActor.run {
                validationError = "Error al registrar entrada"
                scannedUser = nil
            }
        }
        
        isProcessing = false
    }
    
    private func processCheckOut(user: GymUser) async {
        isProcessing = true
        
        do {
            guard let staffId = authState.gymUser?.id else { return }
            
            try await FirebaseService.shared.recordCheckOut(
                userId: user.id,
                staffId: staffId,
                gymId: "default"
            )
            
            await MainActor.run {
                successMessage = "\(user.name) ha salido correctamente"
                showSuccess = true
                lastAction = "checkout"
            }
        } catch {
            await MainActor.run {
                validationError = "Error al registrar salida"
                scannedUser = nil
            }
        }
        
        isProcessing = false
    }
    
    private func resetScanner() {
        isScanning = true
        scannedUser = nil
        validationError = nil
        isProcessing = false
    }
}

// MARK: - QR Scanner Representable

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

// MARK: - QR Scanner View Controller

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if captureSession?.canAddInput(videoInput) == true {
                captureSession?.addInput(videoInput)
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            
            if captureSession?.canAddOutput(metadataOutput) == true {
                captureSession?.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer?.frame = view.layer.bounds
            previewLayer?.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer!)
            
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        } catch {
            print("Camera error: \(error)")
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else { return }
        
        hasScanned = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        captureSession?.stopRunning()
        onCodeScanned?(stringValue)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

#Preview {
    StaffQRScannerView()
}

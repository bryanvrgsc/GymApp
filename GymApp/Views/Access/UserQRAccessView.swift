//
//  UserQRAccessView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

/// User view showing dynamic QR code for gym access
struct UserQRAccessView: View {
    @ObservedObject private var authState = AuthState.shared
    @StateObject private var qrService = QRTokenService.shared
    
    @State private var qrImage: UIImage?
    
    private var isMembershipActive: Bool {
        authState.gymUser?.membership?.isActive ?? authState.gymUser?.isActive ?? false
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if isMembershipActive {
                    // Active membership - show QR
                    activeQRView
                } else {
                    // Inactive membership - show error
                    inactiveView
                }
            }
            .padding()
            .navigationTitle("Acceso")
            .onAppear {
                if isMembershipActive, let userId = authState.gymUser?.id {
                    qrService.startGenerating(for: userId)
                }
            }
            .onDisappear {
                qrService.stopGenerating()
            }
            .onChange(of: qrService.currentToken) { _, newToken in
                if !newToken.isEmpty {
                    qrImage = generateQRCode(from: newToken)
                }
            }
        }
    }
    
    // MARK: - Active QR View
    
    private var activeQRView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Premium Access Card
            PremiumAccessCardView(
                userName: authState.gymUser?.name ?? "Usuario",
                badgeTier: currentBadge,
                qrImage: qrImage,
                memberSince: authState.gymUser?.createdAt,
                daysRemaining: authState.gymUser?.membership?.daysRemaining ?? 0,
                secondsUntilRefresh: qrService.secondsUntilRefresh
            )
            
            // Short instruction
            Text("Muestra este código al staff")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 16)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // Computed badge tier
    private var currentBadge: BadgeTier? {
        if let badge = authState.gymUser?.currentBadge {
            return badge
        }
        let months = authState.gymUser?.membership?.continuousMonths ?? authState.gymUser?.consecutiveMonths ?? 0
        return BadgeTier.forMonths(months)
    }
    
    // MARK: - Inactive View
    
    @State private var isRefreshing = false
    
    private var inactiveView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "xmark.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Membresía Inactiva")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Tu membresía ha expirado o no está activa. Contacta al staff para renovar.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let membership = authState.gymUser?.membership {
                VStack(spacing: 4) {
                    Text("Expiró el")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDate(membership.expirationDate))
                        .font(.headline)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Refresh button
            Button(action: {
                Task { await refreshMembership() }
            }) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isRefreshing ? "Actualizando..." : "Actualizar datos")
                }
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .cornerRadius(12)
            }
            .disabled(isRefreshing)
            .padding(.horizontal, 32)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
    
    private func refreshMembership() async {
        isRefreshing = true
        
        // Refresh from Firebase
        if let userId = authState.gymUser?.id {
            do {
                if let updatedUser = try await FirebaseService.shared.getUser(auth0UserId: userId) {
                    await MainActor.run {
                        authState.gymUser = updatedUser
                    }
                }
            } catch {
                print("[DEBUG] Error refreshing membership: \(error)")
            }
        }
        
        isRefreshing = false
    }
    
    // MARK: - QR Generation
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale up for better quality
        let scale: CGFloat = 10
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

#Preview {
    UserQRAccessView()
}

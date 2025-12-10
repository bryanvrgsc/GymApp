//
//  PremiumAccessCardView.swift
//  GymApp
//
//  Created by Bryan Vargas on 10/12/24.
//

import SwiftUI

/// Premium Access Card with Apple Wallet-style design
/// Features dynamic gradients based on badge tier and breathing QR animation
struct PremiumAccessCardView: View {
    let userName: String
    let badgeTier: BadgeTier?
    let qrImage: UIImage?
    let memberSince: Date?
    let daysRemaining: Int
    let secondsUntilRefresh: Int
    
    @State private var isBreathing = false
    @State private var gradientRotation: Double = 0
    
    private var currentTier: BadgeTier {
        badgeTier ?? .bronze
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Card container
            ZStack {
                // Dynamic gradient background
                cardBackground
                
                // Card content
                VStack(spacing: 16) {
                    // Header
                    cardHeader
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // QR Code with breathing animation
                    qrCodeSection
                    
                    // User info
                    userInfoSection
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Footer with timer
                    cardFooter
                }
                .padding(20)
            }
            .frame(maxWidth: 340)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: currentTier.gradientColors.first?.opacity(0.4) ?? .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            // Start breathing animation
            isBreathing = true
            // Start gradient rotation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
        }
    }
    
    // MARK: - Card Background
    
    private var cardBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: currentTier.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated overlay for premium effect
            AngularGradient(
                colors: [
                    .white.opacity(0.1),
                    .clear,
                    .white.opacity(0.15),
                    .clear,
                    .white.opacity(0.1)
                ],
                center: .center,
                angle: .degrees(gradientRotation)
            )
            .blendMode(.overlay)
            
            // Subtle pattern overlay
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    // Decorative curves
                    path.move(to: CGPoint(x: 0, y: height * 0.3))
                    path.addQuadCurve(
                        to: CGPoint(x: width, y: height * 0.5),
                        control: CGPoint(x: width * 0.5, y: height * 0.1)
                    )
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(Color.black.opacity(0.1))
            }
        }
    }
    
    // MARK: - Card Header
    
    private var cardHeader: some View {
        HStack {
            // App logo/name
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("GymApp")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Badge tier indicator
            HStack(spacing: 6) {
                Image(systemName: currentTier.iconName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text(currentTier.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - QR Code Section
    
    private var qrCodeSection: some View {
        ZStack {
            // QR background with subtle glow
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: isBreathing ? 12 : 6, x: 0, y: 4)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBreathing)
            
            // Outer breathing glow ring
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [currentTier.gradientColors.first ?? .blue, .white.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isBreathing ? 4 : 2
                )
                .scaleEffect(isBreathing ? 1.08 : 1.0)
                .opacity(isBreathing ? 0.6 : 0.2)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBreathing)
            
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
                    .scaleEffect(isBreathing ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBreathing)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.gray)
            }
        }
        .frame(width: 220, height: 220)
    }
    
    // MARK: - User Info Section
    
    private var userInfoSection: some View {
        VStack(spacing: 4) {
            Text(userName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if let since = memberSince {
                Text("Miembro desde \(formatYear(since))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    // MARK: - Card Footer
    
    private var cardFooter: some View {
        HStack {
            // Countdown timer
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                // Timer progress
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 80, height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 80 * CGFloat(secondsUntilRefresh) / 30, height: 6)
                        .animation(.linear(duration: 1), value: secondsUntilRefresh)
                }
                
                Text("\(secondsUntilRefresh)s")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Days remaining
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("\(daysRemaining) días")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.2))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Helpers
    
    private func formatYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        PremiumAccessCardView(
            userName: "Juan García Pérez",
            badgeTier: .gold,
            qrImage: nil,
            memberSince: Date(),
            daysRemaining: 15,
            secondsUntilRefresh: 25
        )
    }
}

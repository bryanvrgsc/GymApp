//
//  UserProfileView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// User profile view with badges and membership info from Firebase
struct UserProfileView: View {
    @ObservedObject private var authState = AuthState.shared
    @State private var isRefreshing = false
    @State private var refreshMessage: String?
    @State private var showRefreshToast = false
    
    private var user: GymUser? { authState.gymUser }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header
                    profileHeader
                    
                    // Badge section
                    if let badge = currentBadge {
                        badgeSection(badge: badge)
                    }
                    
                    // Membership info
                    membershipSection
                    
                    // Preferences section
                    if hasPreferences {
                        preferencesSection
                    }
                    
                    // Quick stats
                    statsSection
                    
                    // Refresh button
                    refreshButton
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Perfil")
        }
        .animation(.default, value: showRefreshToast)
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            if let pic = user?.picture ?? authState.userProfile?.picture,
               let url = URL(string: pic) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().frame(width: 100, height: 100)
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    case .failure:
                        profilePlaceholder
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                profilePlaceholder
            }
            
            // Name
            Text(user?.name ?? authState.userProfile?.name ?? "Usuario")
                .font(.title2)
                .fontWeight(.bold)
            
            // Email
            if let email = user?.email ?? authState.userProfile?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Membership status badge
            membershipStatusBadge
        }
        .padding()
    }
    
    private var membershipStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isActive ? "Membresía Activa" : "Membresía Expirada")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isActive ? .green : .red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background((isActive ? Color.green : Color.red).opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Badge Section
    
    private var currentBadge: BadgeTier? {
        if let badge = user?.currentBadge {
            return badge
        }
        // Calculate from consecutive months
        let months = user?.membership?.continuousMonths ?? user?.consecutiveMonths ?? 0
        return BadgeTier.forMonths(months)
    }
    
    private func badgeSection(badge: BadgeTier) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu Badge")
                .font(.headline)
            
            BadgeCardView(
                tier: badge,
                consecutiveMonths: user?.membership?.continuousMonths ?? user?.consecutiveMonths ?? 0
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Membership Section
    
    private var isActive: Bool {
        user?.membership?.isActive ?? user?.isActive ?? false
    }
    
    private var membershipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Membresía")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Plan type
                if let membership = user?.membership {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(.accentColor)
                        Text("Plan")
                        Spacer()
                        Text(membership.planType.displayName)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Expiration
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.accentColor)
                    Text("Expira")
                    Spacer()
                    if let exp = user?.membership?.expirationDate ?? user?.membershipExp {
                        Text(formatDate(exp))
                            .foregroundColor(.secondary)
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Days remaining
                if isActive, let days = user?.membership?.daysRemaining {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.accentColor)
                        Text("Días restantes")
                        Spacer()
                        Text("\(days) días")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                }
                
                // Member since
                if let createdAt = user?.createdAt {
                    HStack {
                        Image(systemName: "person.badge.clock")
                            .foregroundColor(.accentColor)
                        Text("Miembro desde")
                        Spacer()
                        Text(formatDate(createdAt))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Consecutive months
                HStack {
                    Image(systemName: "flame")
                        .foregroundColor(.orange)
                    Text("Meses consecutivos")
                    Spacer()
                    Text("\(user?.membership?.continuousMonths ?? user?.consecutiveMonths ?? 0) meses")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Preferences Section
    
    private var hasPreferences: Bool {
        !(user?.favoriteEquipment.isEmpty ?? true) || !(user?.favoriteActivities.isEmpty ?? true)
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferencias")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                if let equipment = user?.favoriteEquipment, !equipment.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Equipos favoritos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(equipment.prefix(5).joined(separator: ", "))
                            .font(.subheadline)
                    }
                }
                
                if let activities = user?.favoriteActivities, !activities.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Actividades favoritas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(activities.prefix(5).joined(separator: ", "))
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información")
                .font(.headline)
            
            HStack(spacing: 16) {
                ProfileStatCard(
                    title: "Meses",
                    value: "\(user?.membership?.continuousMonths ?? user?.consecutiveMonths ?? 0)",
                    icon: "flame.fill"
                )
                ProfileStatCard(
                    title: "Último acceso",
                    value: lastLoginShort,
                    icon: "clock"
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var lastLoginShort: String {
        guard let lastLogin = user?.lastLogin else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastLogin, relativeTo: Date())
    }
    
    // MARK: - Refresh Button
    
    private var refreshButton: some View {
        VStack {
            Button(action: {
                Task { await doRefresh() }
            }) {
                if isRefreshing {
                    ProgressView()
                } else {
                    Text("Actualizar datos")
                }
            }
            .buttonStyle(.bordered)
            .padding(.top)
            
            if showRefreshToast, let msg = refreshMessage {
                Text(msg)
                    .font(.caption)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var profilePlaceholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .frame(width: 100, height: 100)
            .foregroundColor(.accentColor)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func doRefresh() async {
        isRefreshing = true
        do {
            _ = try await authState.refreshSession()
            refreshMessage = "Datos actualizados"
        } catch {
            refreshMessage = "Error: \(error.localizedDescription)"
        }
        isRefreshing = false
        withAnimation { showRefreshToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { showRefreshToast = false }
        }
    }
}

// MARK: - Badge Card View

struct BadgeCardView: View {
    let tier: BadgeTier
    let consecutiveMonths: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Badge icon with gradient
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: tier.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 70, height: 70)
                
                Image(systemName: tier.iconName)
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("\(consecutiveMonths) meses consecutivos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let next = tier.nextTier, let monthsToNext = tier.monthsToNextTier(currentMonths: consecutiveMonths) {
                    HStack(spacing: 4) {
                        Text("Siguiente: \(next.displayName)")
                            .font(.caption)
                        Text("(\(monthsToNext) meses)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Profile Stat Card

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    UserProfileView()
}

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
    @State private var weeklyVisits: Int = 0
    @State private var weeklyStreak: Int = 0
    @State private var isLoadingStats = true
    
    private let weeklyGoal: Int = 4
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
                    
                    // Dashboard Grid (2x2)
                    dashboardSection
                    
                    // Preferences section
                    if hasPreferences {
                        preferencesSection
                    }
                    
                    // Refresh button
                    refreshButton
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Perfil")
            .task {
                await loadWeeklyStats()
            }
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
            
            // Email (truncated to avoid overflow)
            if let email = user?.email ?? authState.userProfile?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
    
    private var isActive: Bool {
        user?.membership?.isActive ?? user?.isActive ?? false
    }
    
    // MARK: - Dashboard Section (2x2 Grid)
    
    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dashboard")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Days Remaining
                DashboardStatCard(
                    title: "Días Restantes",
                    value: "\(user?.membership?.daysRemaining ?? 0)",
                    icon: "calendar",
                    color: (user?.membership?.daysRemaining ?? 0) > 7 ? .green : .orange,
                    isHighlight: true
                )
                
                // Weekly Streak
                DashboardStatCard(
                    title: "Racha Semanal",
                    value: "\(weeklyStreak)",
                    icon: "flame.fill",
                    color: .orange,
                    suffix: weeklyStreak == 1 ? "semana" : "semanas"
                )
                
                // Workouts this week
                DashboardStatCard(
                    title: "Esta Semana",
                    value: "\(weeklyVisits)/\(weeklyGoal)",
                    icon: "figure.run",
                    color: weeklyVisits >= weeklyGoal ? .green : .accentColor,
                    showProgress: true,
                    progress: Double(weeklyVisits) / Double(weeklyGoal)
                )
                
                // Current Plan
                DashboardStatCard(
                    title: "Plan Actual",
                    value: user?.membership?.planType.displayName ?? "—",
                    icon: "creditcard.fill",
                    color: .purple,
                    isSmallText: true
                )
            }
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
            
            VStack(alignment: .leading, spacing: 16) {
                if let equipment = user?.favoriteEquipment, !equipment.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Equipos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        PreferenceIconsGridView(
                            items: equipment.compactMap { id in
                                EquipmentItem.allItems.first { $0.id == id }
                            }.map { ($0.name, $0.iconName) }
                        )
                    }
                }
                
                if let activities = user?.favoriteActivities, !activities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Actividades")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        PreferenceIconsGridView(
                            items: activities.compactMap { id in
                                ActivityItem.allItems.first { $0.id == id }
                            }.map { ($0.name, $0.iconName) }
                        )
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
    
    private func loadWeeklyStats() async {
        guard let userId = user?.id else {
            isLoadingStats = false
            return
        }
        
        do {
            let checkins = try await FirebaseService.shared.getAllUserCheckins(userId: userId, limit: 200)
            
            let calendar = Calendar.current
            let now = Date()
            
            // Calculate current week visits
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let thisWeekCheckins = checkins.filter { checkin in
                checkin.type == .checkin && checkin.timestamp >= weekStart
            }
            
            // Calculate weekly streak (how many consecutive weeks with at least 1 visit)
            var streak = 0
            var checkWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            
            while true {
                guard let weekStartDate = calendar.date(from: checkWeek) else { break }
                let weekEndDate = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartDate) ?? weekStartDate
                
                let hasVisitThisWeek = checkins.contains { checkin in
                    checkin.type == .checkin && 
                    checkin.timestamp >= weekStartDate && 
                    checkin.timestamp < weekEndDate
                }
                
                if hasVisitThisWeek {
                    streak += 1
                    // Go back one week
                    if let prevWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStartDate) {
                        checkWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: prevWeek)
                    } else {
                        break
                    }
                } else {
                    break
                }
            }
            
            await MainActor.run {
                weeklyVisits = thisWeekCheckins.count
                weeklyStreak = streak
                isLoadingStats = false
            }
        } catch {
            #if DEBUG
            print("[UserProfileView] Error loading weekly stats: \(error)")
            #endif
            isLoadingStats = false
        }
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
    
    private var progressToNext: Double {
        guard let next = tier.nextTier else { return 1.0 }
        let currentTierMonths = tier.requiredMonths
        let nextTierMonths = next.requiredMonths
        let progress = Double(consecutiveMonths - currentTierMonths) / Double(nextTierMonths - currentTierMonths)
        return min(max(progress, 0), 1)
    }
    
    var body: some View {
        VStack(spacing: 12) {
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
                    
                    if let next = tier.nextTier {
                        Text("Siguiente: \(next.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("¡Máximo nivel alcanzado!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
            
            // Progress bar to next tier
            if tier.nextTier != nil {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progressToNext)
                        .tint(LinearGradient(
                            colors: tier.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .scaleEffect(y: 1.5)
                    
                    if let monthsToNext = tier.monthsToNextTier(currentMonths: consecutiveMonths) {
                        Text("\(monthsToNext) meses para el siguiente nivel")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Dashboard Stat Card

struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isHighlight: Bool = false
    var suffix: String? = nil
    var showProgress: Bool = false
    var progress: Double = 0
    var isSmallText: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            if isSmallText {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(value)
                    .font(isHighlight ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(isHighlight ? color : .primary)
            }
            
            if let suffix = suffix {
                Text(suffix)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if showProgress {
                ProgressView(value: min(progress, 1.0))
                    .tint(progress >= 1.0 ? .green : color)
                    .scaleEffect(y: 1.5)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    UserProfileView()
}

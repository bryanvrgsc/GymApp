//
//  AdminCheckInActivityView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// Admin view showing recent check-in/out activity with filters
struct AdminCheckInActivityView: View {
    @State private var checkins: [Checkin] = []
    @State private var filteredCheckins: [Checkin] = []
    @State private var isLoading = true
    @State private var selectedFilter: ActivityFilter = .all
    @State private var activeUsers: Int = 0
    @State private var selectedCheckin: Checkin?
    @State private var showDetail = false
    
    enum ActivityFilter: String, CaseIterable {
        case all = "Todos"
        case checkin = "Check-In"
        case checkout = "Check-Out"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Active users counter
                if activeUsers > 0 {
                    HStack {
                        Image(systemName: "person.fill.checkmark")
                            .foregroundColor(.green)
                        Text("\(activeUsers) usuario\(activeUsers == 1 ? "" : "s") en el gimnasio")
                            .fontWeight(.semibold)
                        Spacer()
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .opacity(0.8)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                }
                
                // Filter buttons
                Picker("Filtro", selection: $selectedFilter) {
                    ForEach(ActivityFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Activity list
                if isLoading {
                    Spacer()
                    ProgressView("Cargando actividad...")
                    Spacer()
                } else if filteredCheckins.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Sin actividad reciente")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredCheckins) { checkin in
                            ActivityRowView(checkin: checkin)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCheckin = checkin
                                    showDetail = true
                                }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadActivity()
                    }
                }
            }
            .navigationTitle("Check-In")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadActivity() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showDetail) {
                if let checkin = selectedCheckin {
                    CheckinDetailSheet(checkin: checkin)
                }
            }
            .onChange(of: selectedFilter) { _, _ in
                applyFilter()
            }
            .task {
                await loadActivity()
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadActivity() async {
        isLoading = true
        
        do {
            let allCheckins = try await FirebaseService.shared.getRecentCheckins(limit: 100)
            
            // Calculate active users
            let todayCheckins = allCheckins.filter { Calendar.current.isDateInToday($0.timestamp) }
            let todayCheckIns = Set(todayCheckins.filter { $0.type == .checkin }.map { $0.userId })
            let todayCheckOuts = Set(todayCheckins.filter { $0.type == .checkout }.map { $0.userId })
            let activeCount = todayCheckIns.subtracting(todayCheckOuts).count
            
            await MainActor.run {
                self.checkins = allCheckins
                self.activeUsers = activeCount
                applyFilter()
            }
        } catch {
            print("[AdminCheckInActivityView] Error loading activity: \(error)")
        }
        
        isLoading = false
    }
    
    private func applyFilter() {
        switch selectedFilter {
        case .all:
            filteredCheckins = checkins
        case .checkin:
            filteredCheckins = checkins.filter { $0.type == .checkin }
        case .checkout:
            filteredCheckins = checkins.filter { $0.type == .checkout }
        }
    }
}

// MARK: - Activity Row View

struct ActivityRowView: View {
    let checkin: Checkin
    @State private var userName: String = "Cargando..."
    @State private var userPicture: String?
    
    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            ZStack {
                Circle()
                    .fill(checkin.type == .checkin ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: checkin.type == .checkin ? "arrow.right.circle.fill" : "arrow.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(checkin.type == .checkin ? .green : .orange)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text(checkin.type == .checkin ? "Entrada" : "Salida")
                        .font(.caption)
                        .foregroundColor(checkin.type == .checkin ? .green : .orange)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(relativeTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Time and chevron
            HStack(spacing: 8) {
                Text(formatTime(checkin.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadUserInfo()
        }
    }
    
    private var relativeTime: String {
        let now = Date()
        let diff = now.timeIntervalSince(checkin.timestamp)
        
        if diff < 60 {
            return "Ahora"
        } else if diff < 3600 {
            let mins = Int(diff / 60)
            return "Hace \(mins) min"
        } else if diff < 86400 {
            let hours = Int(diff / 3600)
            return "Hace \(hours) h"
        } else {
            let days = Int(diff / 86400)
            return "Hace \(days) día\(days == 1 ? "" : "s")"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func loadUserInfo() async {
        do {
            if let user = try await FirebaseService.shared.getUser(auth0UserId: checkin.userId) {
                await MainActor.run {
                    self.userName = user.name
                    self.userPicture = user.picture
                }
            } else {
                await MainActor.run {
                    self.userName = "Usuario desconocido"
                }
            }
        } catch {
            await MainActor.run {
                self.userName = "Error"
            }
        }
    }
}

// MARK: - Checkin Detail Sheet

struct CheckinDetailSheet: View {
    let checkin: Checkin
    @Environment(\.dismiss) private var dismiss
    @State private var user: GymUser?
    @State private var processedByUser: GymUser?
    @State private var isLoading = true
    @State private var showUserDetail: GymUser?
    
    var body: some View {
        NavigationView {
            List {
                // Type header
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(checkin.type == .checkin ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: checkin.type == .checkin ? "arrow.right.circle.fill" : "arrow.left.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(checkin.type == .checkin ? .green : .orange)
                            }
                            
                            Text(checkin.type == .checkin ? "Check-In" : "Check-Out")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // User info - tappable
                Section("Usuario") {
                    Button {
                        if let u = user { showUserDetail = u }
                    } label: {
                        HStack {
                            if let pic = user?.picture, let url = URL(string: pic) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.accentColor)
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.accentColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user?.name ?? "Cargando...")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                if let email = user?.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(user == nil)
                }
                
                // Timestamp
                Section("Fecha y Hora") {
                    DetailRow(label: "Fecha", value: formatFullDate(checkin.timestamp))
                    DetailRow(label: "Hora", value: formatTime(checkin.timestamp))
                }
                
                // Location / Gym & Processed By
                Section("Información Adicional") {
                    DetailRow(label: "Gimnasio", value: checkin.gymId)
                    
                    // Processed by - tappable
                    if processedByUser != nil || !checkin.processedBy.isEmpty {
                        Button {
                            if let u = processedByUser { showUserDetail = u }
                        } label: {
                            HStack {
                                Text("Procesado por")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(processedByUser?.name ?? checkin.processedBy)
                                    .fontWeight(.medium)
                                    .foregroundColor(processedByUser != nil ? .accentColor : .primary)
                                if processedByUser != nil {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(processedByUser == nil)
                    }
                    
                    DetailRow(label: "ID Registro", value: checkin.id)
                }
            }
            .navigationTitle("Detalles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(item: $showUserDetail) { user in
                UserProfileSheet(user: user)
            }
            .task {
                await loadDetails()
            }
        }
    }
    
    private func loadDetails() async {
        // Load user
        if let fetchedUser = try? await FirebaseService.shared.getUser(auth0UserId: checkin.userId) {
            await MainActor.run { user = fetchedUser }
        }
        
        // Load processed by user
        if !checkin.processedBy.isEmpty {
            if let fetchedUser = try? await FirebaseService.shared.getUser(auth0UserId: checkin.processedBy) {
                await MainActor.run { processedByUser = fetchedUser }
            }
        }
        
        isLoading = false
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - User Profile Sheet

struct UserProfileSheet: View {
    let user: GymUser
    @Environment(\.dismiss) private var dismiss
    @State private var copiedToClipboard = false
    
    /// Extract provider name from user ID
    private var providerName: String {
        if user.id.hasPrefix("google-oauth2") { return "Google" }
        if user.id.hasPrefix("facebook") { return "Facebook" }
        if user.id.hasPrefix("apple") { return "Apple" }
        if user.id.hasPrefix("auth0") { return "Email/Password" }
        return "Auth0"
    }
    
    /// Provider icon
    private var providerIcon: String {
        if user.id.hasPrefix("google-oauth2") { return "g.circle" }
        if user.id.hasPrefix("facebook") { return "f.circle" }
        if user.id.hasPrefix("apple") { return "apple.logo" }
        return "envelope.circle"
    }
    
    var body: some View {
        NavigationView {
            List {
                // Profile section - matches AdminUserDetailSheet
                Section {
                    HStack {
                        if let pic = user.picture, let url = URL(string: pic) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                default:
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.accentColor)
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            if let email = user.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let nickname = user.nickname {
                                Text("@\(nickname)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Provider
                            HStack(spacing: 4) {
                                Image(systemName: providerIcon)
                                    .font(.caption)
                                Text(providerName)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Roles - matches AdminUserDetailSheet
                Section("Roles") {
                    HStack(spacing: 8) {
                        ForEach(user.roles, id: \.self) { role in
                            HStack(spacing: 4) {
                                Image(systemName: role.iconName)
                                Text(role.displayName)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(roleColor(role))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Membership - matches AdminUserDetailSheet
                Section("Membresía") {
                    if let membership = user.membership {
                        LabeledContent("Estado") {
                            HStack {
                                Circle()
                                    .fill(membership.isActive ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(membership.isActive ? "Activa" : "Expirada")
                                    .foregroundColor(membership.isActive ? .green : .red)
                            }
                        }
                        
                        LabeledContent("Plan") {
                            Text(membership.planType.displayName)
                        }
                        
                        LabeledContent("Expira") {
                            Text(formatDate(membership.expirationDate))
                        }
                        
                        if membership.isActive {
                            LabeledContent("Días restantes") {
                                Text("\(membership.daysRemaining)")
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        LabeledContent("Meses consecutivos") {
                            Text("\(membership.continuousMonths)")
                        }
                    } else {
                        Text("Sin membresía registrada")
                            .foregroundColor(.secondary)
                    }
                }
                
                // IDs - with copy to clipboard
                Section("Información Técnica") {
                    Button {
                        UIPasteboard.general.string = user.id
                        copiedToClipboard = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            copiedToClipboard = false
                        }
                    } label: {
                        HStack {
                            Text("ID Usuario")
                                .foregroundColor(.secondary)
                            Spacer()
                            if copiedToClipboard {
                                Text("¡Copiado!")
                                    .foregroundColor(.green)
                            } else {
                                Text(user.id)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundColor(.primary)
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    DetailRow(label: "Registrado", value: formatDate(user.createdAt))
                    DetailRow(label: "Último acceso", value: formatDate(user.lastLogin))
                }
            }
            .navigationTitle("Perfil de Usuario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .admin: return .orange
        case .staff: return .purple
        case .user: return .blue
        }
    }
}

#Preview {
    AdminCheckInActivityView()
}

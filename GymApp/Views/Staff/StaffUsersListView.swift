//
//  StaffUsersListView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// Staff view for managing users and memberships from Firebase
struct StaffUsersListView: View {
    @ObservedObject private var authState = AuthState.shared
    
    @State private var searchQuery = ""
    @State private var users: [GymUser] = []
    @State private var filteredUsers: [GymUser] = []
    @State private var isLoading = true
    @State private var selectedUser: GymUser?
    @State private var showRenewalForm = false
    @State private var showUserDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar por nombre o email...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                    
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Stats bar
                HStack(spacing: 16) {
                    StatPill(title: "Total", value: "\(users.count)", color: .blue)
                    StatPill(title: "Activos", value: "\(activeCount)", color: .green)
                    StatPill(title: "Expirados", value: "\(expiredCount)", color: .red)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // User list
                if isLoading {
                    Spacer()
                    ProgressView("Cargando usuarios...")
                    Spacer()
                } else if filteredUsers.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: searchQuery.isEmpty ? "person.3" : "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(searchQuery.isEmpty ? "No hay usuarios registrados" : "No se encontraron resultados")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredUsers) { user in
                            StaffUserRowView(user: user) {
                                selectedUser = user
                                showRenewalForm = true
                            } onViewDetail: {
                                selectedUser = user
                                showUserDetail = true
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadUsers()
                    }
                }
            }
            .navigationTitle("Usuarios")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadUsers() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showRenewalForm) {
                if let user = selectedUser {
                    RenewalFormView(user: user) {
                        showRenewalForm = false
                        Task { await loadUsers() }
                    }
                }
            }
            .sheet(isPresented: $showUserDetail) {
                if let user = selectedUser {
                    UserDetailSheet(user: user)
                }
            }
            .onChange(of: searchQuery) { query in
                filterUsers(query: query)
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    private var activeCount: Int {
        users.filter { $0.membership?.isActive == true || $0.isActive }.count
    }
    
    private var expiredCount: Int {
        users.count - activeCount
    }
    
    private func loadUsers() async {
        isLoading = true
        do {
            let fetchedUsers = try await FirebaseService.shared.getAllUsers(limit: 100)
            await MainActor.run {
                users = fetchedUsers
                filterUsers(query: searchQuery)
            }
        } catch {
            #if DEBUG
            print("[StaffUsersListView] Error loading users: \(error)")
            #endif
        }
        isLoading = false
    }
    
    private func filterUsers(query: String) {
        if query.isEmpty {
            filteredUsers = users
        } else {
            let lowercased = query.lowercased()
            filteredUsers = users.filter { user in
                user.name.lowercased().contains(lowercased) ||
                (user.email?.lowercased().contains(lowercased) ?? false) ||
                (user.nickname?.lowercased().contains(lowercased) ?? false)
            }
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - User Row

struct StaffUserRowView: View {
    let user: GymUser
    let onRenew: () -> Void
    let onViewDetail: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let pic = user.picture, let url = URL(string: pic) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    default:
                        defaultAvatar
                    }
                }
            } else {
                defaultAvatar
            }
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                
                if let email = user.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Membership status
                HStack(spacing: 6) {
                    if let membership = user.membership {
                        Circle()
                            .fill(membership.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        if membership.isActive {
                            Text("\(membership.daysRemaining) días")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Expirada")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(membership.planType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if user.isActive {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Activa (legacy)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Sin membresía")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // Actions - use buttonStyle to prevent tap propagation in List
            HStack(spacing: 16) {
                Button(action: onRenew) {
                    Image(systemName: "creditcard.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: onViewDetail) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 50))
            .foregroundColor(.accentColor)
    }
}

// MARK: - User Detail Sheet

struct UserDetailSheet: View {
    let user: GymUser
    @Environment(\.dismiss) private var dismiss
    
    @State private var renewalHistory: [MembershipRenewal] = []
    @State private var isLoadingHistory = true
    
    var body: some View {
        NavigationView {
            List {
                // Profile section
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
                            
                            // Provider (extracted from Auth0 userId)
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
                
                // Membership section
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
                        
                        if let method = membership.paymentMethod {
                            LabeledContent("Último pago") {
                                Text(method.displayName)
                            }
                        }
                    } else {
                        Text("Sin membresía registrada")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Preferences section
                Section("Preferencias") {
                    if user.favoriteEquipment.isEmpty && user.favoriteActivities.isEmpty {
                        Text("Sin preferencias registradas")
                            .foregroundColor(.secondary)
                    } else {
                        if !user.favoriteEquipment.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Equipos")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(user.favoriteEquipment.joined(separator: ", "))
                                    .font(.subheadline)
                            }
                        }
                        if !user.favoriteActivities.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Actividades")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(user.favoriteActivities.joined(separator: ", "))
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                
                // Renewal history
                Section("Historial de Renovaciones") {
                    if isLoadingHistory {
                        ProgressView()
                    } else if renewalHistory.isEmpty {
                        Text("Sin historial de renovaciones")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(renewalHistory) { renewal in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(renewal.planType.displayName)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("$\(Int(renewal.amount)) \(renewal.currency)")
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text(formatDate(renewal.periodStart))
                                    Text("→")
                                        .foregroundColor(.secondary)
                                    Text(formatDate(renewal.periodEnd))
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                Text("Por: \(renewal.staffName)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Detalles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadRenewalHistory()
            }
        }
    }
    
    private func loadRenewalHistory() async {
        isLoadingHistory = true
        do {
            let history = try await FirebaseService.shared.getRenewalHistory(userId: user.id)
            await MainActor.run {
                renewalHistory = history
            }
        } catch {
            #if DEBUG
            print("[UserDetailSheet] Error loading history: \(error)")
            #endif
        }
        isLoadingHistory = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Extract provider name from Auth0 userId (e.g. "google-oauth2|123" -> "Google")
    private var providerName: String {
        let parts = user.id.split(separator: "|")
        guard let provider = parts.first else { return "Desconocido" }
        
        switch String(provider) {
        case "google-oauth2": return "Google"
        case "facebook": return "Facebook"
        case "apple": return "Apple"
        case "twitter": return "Twitter"
        case "auth0": return "Email"
        case "email": return "Email"
        default: return String(provider).capitalized
        }
    }
    
    /// Get icon for provider
    private var providerIcon: String {
        let parts = user.id.split(separator: "|")
        guard let provider = parts.first else { return "person.circle" }
        
        switch String(provider) {
        case "google-oauth2": return "globe"
        case "facebook": return "f.circle"
        case "apple": return "apple.logo"
        case "twitter": return "at"
        case "auth0", "email": return "envelope"
        default: return "person.circle"
        }
    }
}

#Preview {
    StaffUsersListView()
}

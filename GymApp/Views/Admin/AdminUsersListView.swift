//
//  AdminUsersListView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// Admin view for managing users - includes role filtering and user editing
struct AdminUsersListView: View {
    @ObservedObject private var authState = AuthState.shared
    
    @State private var searchQuery = ""
    @State private var users: [GymUser] = []
    @State private var filteredUsers: [GymUser] = []
    @State private var isLoading = true
    @State private var selectedUser: GymUser?
    @State private var showRenewalForm = false
    @State private var showUserDetail = false
    @State private var selectedRoleFilter: RoleFilter = .all
    @State private var membershipFilter: MembershipStatusFilter = .all
    
    enum RoleFilter: String, CaseIterable {
        case all = "Todos"
        case user = "Usuarios"
        case staff = "Staff"
        case admin = "Admins"
        
        var role: UserRole? {
            switch self {
            case .all: return nil
            case .user: return .user
            case .staff: return .staff
            case .admin: return .admin
            }
        }
    }
    
    enum MembershipStatusFilter: String, CaseIterable {
        case all = "Todos"
        case active = "Activos"
        case inactive = "Inactivos"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Role filter
                Picker("Filtro", selection: $selectedRoleFilter) {
                    ForEach(RoleFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
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
                HStack(spacing: 12) {
                    AdminStatPill(title: "Total", value: "\(users.count)", color: .blue)
                    AdminStatPill(title: "Activos", value: "\(activeCount)", color: .green)
                    AdminStatPill(title: "Staff", value: "\(staffCount)", color: .purple)
                    AdminStatPill(title: "Admins", value: "\(adminCount)", color: .orange)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Membership status filter
                Picker("Membresía", selection: $membershipFilter) {
                    ForEach(MembershipStatusFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
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
                        Text(searchQuery.isEmpty ? "No hay usuarios" : "Sin resultados")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredUsers) { user in
                            AdminUserRow(user: user) {
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
                    AdminUserDetailSheet(user: user) {
                        showUserDetail = false
                        Task { await loadUsers() }
                    }
                }
            }
            .onChange(of: searchQuery) { _, _ in
                applyFilters()
            }
            .onChange(of: selectedRoleFilter) { _, _ in
                applyFilters()
            }
            .onChange(of: membershipFilter) { _, _ in
                applyFilters()
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    private var activeCount: Int {
        users.filter { $0.membership?.isActive == true || $0.isActive }.count
    }
    
    private var staffCount: Int {
        users.filter { $0.roles.contains(.staff) }.count
    }
    
    private var adminCount: Int {
        users.filter { $0.roles.contains(.admin) }.count
    }
    
    private func loadUsers() async {
        isLoading = true
        do {
            let fetchedUsers = try await FirebaseService.shared.getAllUsers(limit: 200)
            await MainActor.run {
                users = fetchedUsers
                applyFilters()
            }
        } catch {
            #if DEBUG
            print("[AdminUsersListView] Error loading users: \(error)")
            #endif
        }
        isLoading = false
    }
    
    private func applyFilters() {
        var result = users
        
        // Apply role filter
        if let role = selectedRoleFilter.role {
            result = result.filter { $0.roles.contains(role) }
        }
        
        // Apply membership filter
        switch membershipFilter {
        case .all:
            break
        case .active:
            result = result.filter { $0.membership?.isActive == true || $0.isActive }
        case .inactive:
            result = result.filter { $0.membership?.isActive != true && !$0.isActive }
        }
        
        // Apply search filter
        if !searchQuery.isEmpty {
            let lowercased = searchQuery.lowercased()
            result = result.filter { user in
                user.name.lowercased().contains(lowercased) ||
                (user.email?.lowercased().contains(lowercased) ?? false) ||
                (user.nickname?.lowercased().contains(lowercased) ?? false)
            }
        }
        
        filteredUsers = result
    }
}

// MARK: - Admin Stat Pill

struct AdminStatPill: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Admin User Row (Simplified)

struct AdminUserRow: View {
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
                        image.resizable()
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
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.headline)
                    
                    // Role badges (circles with initials)
                    ForEach(user.roles, id: \.self) { role in
                        Text(roleInitial(role))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(roleColor(role))
                            .clipShape(Circle())
                    }
                }
                
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
                        Text(membership.isActive ? "\(membership.daysRemaining) días" : "Expirada")
                            .font(.caption)
                            .foregroundColor(membership.isActive ? .green : .red)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(membership.planType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if user.isActive {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Activa").font(.caption).foregroundColor(.green)
                    } else {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("Sin membresía").font(.caption).foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // Actions - only 2 buttons
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
    
    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .admin: return .orange
        case .staff: return .purple
        case .user: return .blue
        }
    }
    
    private func roleInitial(_ role: UserRole) -> String {
        switch role {
        case .admin: return "A"
        case .staff: return "S"
        case .user: return "U"
        }
    }
}

// MARK: - Admin User Detail Sheet (with Edit button)

struct AdminUserDetailSheet: View {
    let user: GymUser
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing = false
    @State private var renewalHistory: [MembershipRenewal] = []
    @State private var isLoadingHistory = true
    
    // Editable fields
    @State private var editName: String = ""
    @State private var editEmail: String = ""
    @State private var hasStaffRole: Bool = false
    @State private var hasAdminRole: Bool = false
    @State private var notificationsEnabled: Bool = true
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                            if isEditing {
                                TextField("Nombre", text: $editName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                TextField("Email", text: $editEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            } else {
                                Text(user.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if let email = user.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
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
                
                // Roles section
                Section("Roles") {
                    if isEditing {
                        Toggle("Usuario", isOn: .constant(true))
                            .disabled(true)
                        Toggle("Staff", isOn: $hasStaffRole)
                        Toggle("Administrador", isOn: $hasAdminRole)
                    } else {
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
                }
                
                // Settings section (only in edit mode)
                if isEditing {
                    Section("Configuración") {
                        Toggle("Notificaciones", isOn: $notificationsEnabled)
                    }
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
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Equipos")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                PreferenceIconsGridView(
                                    items: user.favoriteEquipment.compactMap { id in
                                        EquipmentItem.allItems.first { $0.id == id }
                                    }.map { ($0.name, $0.iconName) }
                                )
                            }
                        }
                        if !user.favoriteActivities.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Actividades")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                PreferenceIconsGridView(
                                    items: user.favoriteActivities.compactMap { id in
                                        ActivityItem.allItems.first { $0.id == id }
                                    }.map { ($0.name, $0.iconName) }
                                )
                            }
                        }
                    }
                }
                
                // Renewal history (not in edit mode)
                if !isEditing {
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
                
                // Save button (only in edit mode)
                if isEditing {
                    Section {
                        Button {
                            Task { await saveChanges() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Guardar Cambios")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(isSaving)
                        .listRowBackground(Color.accentColor)
                        .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("Detalles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "Cancelar" : "Editar") {
                        if isEditing {
                            // Reset to original values
                            editName = user.name
                            editEmail = user.email ?? ""
                            hasStaffRole = user.roles.contains(.staff)
                            hasAdminRole = user.roles.contains(.admin)
                            notificationsEnabled = user.notificationsEnabled
                        }
                        isEditing.toggle()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                editName = user.name
                editEmail = user.email ?? ""
                hasStaffRole = user.roles.contains(.staff)
                hasAdminRole = user.roles.contains(.admin)
                notificationsEnabled = user.notificationsEnabled
            }
            .task {
                await loadRenewalHistory()
            }
            .alert("¡Guardado!", isPresented: $showSuccess) {
                Button("OK") {
                    isEditing = false
                    onComplete()
                }
            } message: {
                Text("Los cambios han sido guardados.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
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
            print("[AdminUserDetailSheet] Error loading history: \(error)")
            #endif
        }
        isLoadingHistory = false
    }
    
    private func saveChanges() async {
        isSaving = true
        
        var roles: [UserRole] = [.user]
        if hasStaffRole { roles.append(.staff) }
        if hasAdminRole { roles.append(.admin) }
        
        do {
            try await FirebaseService.shared.updateUserProfile(
                userId: user.id,
                name: editName,
                email: editEmail.isEmpty ? nil : editEmail,
                roles: roles,
                notificationsEnabled: notificationsEnabled
            )
            
            await MainActor.run {
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error: \(error.localizedDescription)"
                showError = true
            }
        }
        
        isSaving = false
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
    AdminUsersListView()
}

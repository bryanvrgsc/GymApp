//
//  AdminTabView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// Tab view for administrators
/// Tabs: Dashboard, Usuarios, Check-In/Out, Ocupación, Configuración, Ajustes
struct AdminTabView: View {
    @State private var selection: Int = 1
    
    var body: some View {
        TabView(selection: $selection) {
            AdminDashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("Dashboard")
                }
                .tag(1)
            
            AdminUsersView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Usuarios")
                }
                .tag(2)
            
            StaffCheckInView()  // Reuse staff check-in view
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Check-In")
                }
                .tag(3)
            
            AdminOccupancyView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Ocupación")
                }
                .tag(4)
            
            GymConfigurationView()
                .tabItem {
                    Image(systemName: "building.2")
                    Text("Gimnasio")
                }
                .tag(5)
            
            AdminSettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Ajustes")
                }
                .tag(6)
        }
    }
}

// MARK: - Admin Dashboard

struct AdminDashboardView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        DashboardCard(title: "Usuarios Activos", value: "1,234", change: "+5%", isPositive: true)
                        DashboardCard(title: "Visitas Hoy", value: "156", change: "+12%", isPositive: true)
                        DashboardCard(title: "Retención", value: "87%", change: "-2%", isPositive: false)
                        DashboardCard(title: "Nuevos este mes", value: "45", change: "+8%", isPositive: true)
                    }
                    .padding(.horizontal)
                    
                    // Occupancy chart placeholder
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ocupación por Hora")
                            .font(.headline)
                        
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(0..<12, id: \.self) { i in
                                let height = [30, 45, 60, 80, 95, 100, 85, 70, 90, 75, 50, 35][i]
                                VStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.accentColor.opacity(0.7))
                                        .frame(width: 20, height: CGFloat(height))
                                    Text("\(i + 6)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 130)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Popular equipment
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Equipos Más Usados")
                            .font(.headline)
                        
                        ForEach(["Caminadora", "Bicicleta", "Elíptica", "Pesas libres", "Cable crossover"], id: \.self) { equipment in
                            HStack {
                                Text(equipment)
                                Spacer()
                                ProgressView(value: Double.random(in: 0.4...1.0))
                                    .frame(width: 100)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Badge distribution
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Distribución de Badges")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            ForEach(BadgeTier.allCases.prefix(5), id: \.self) { tier in
                                VStack {
                                    Image(systemName: tier.iconName)
                                        .foregroundColor(tier.color)
                                        .font(.title2)
                                    Text("\(Int.random(in: 50...300))")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(tier.displayName)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

struct DashboardCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                Text(change)
                    .font(.caption)
            }
            .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Admin Users View

struct AdminUsersView: View {
    @State private var searchText = ""
    @State private var selectedRole: UserRole? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filters
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Buscar usuario...", text: $searchText)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Role filter
                    HStack(spacing: 8) {
                        RoleFilterChip(role: nil, selected: selectedRole == nil) {
                            selectedRole = nil
                        }
                        ForEach(UserRole.allCases, id: \.self) { role in
                            RoleFilterChip(role: role, selected: selectedRole == role) {
                                selectedRole = role
                            }
                        }
                    }
                }
                .padding()
                
                List {
                    AdminUserRow(name: "Juan Pérez", email: "juan@email.com", role: .user, badge: .gold)
                    AdminUserRow(name: "María García", email: "maria@email.com", role: .staff, badge: .silver)
                    AdminUserRow(name: "Carlos López", email: "carlos@email.com", role: .admin, badge: .platinum)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Usuarios")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct RoleFilterChip: View {
    let role: UserRole?
    let selected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(role?.displayName ?? "Todos")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(selected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct AdminUserRow: View {
    let name: String
    let email: String
    let role: UserRole
    let badge: BadgeTier
    
    var body: some View {
        NavigationLink(destination: AdminUserDetailView(name: name, email: email, role: role, badge: badge)) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: role.iconName)
                        .foregroundColor(.accentColor)
                    Image(systemName: badge.iconName)
                        .foregroundColor(badge.color)
                        .font(.caption)
                }
            }
        }
    }
}

struct AdminUserDetailView: View {
    let name: String
    let email: String
    let role: UserRole
    let badge: BadgeTier
    
    @State private var selectedRole: UserRole
    
    init(name: String, email: String, role: UserRole, badge: BadgeTier) {
        self.name = name
        self.email = email
        self.role = role
        self.badge = badge
        self._selectedRole = State(initialValue: role)
    }
    
    var body: some View {
        Form {
            Section("Información") {
                LabeledContent("Nombre", value: name)
                LabeledContent("Email", value: email)
                LabeledContent("Badge", value: badge.displayName)
            }
            
            Section("Rol") {
                Picker("Rol", selection: $selectedRole) {
                    ForEach(UserRole.allCases, id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Membresía") {
                LabeledContent("Estado", value: "Activa")
                LabeledContent("Expira", value: "15 Ene 2025")
                Button("Extender membresía") {}
            }
            
            Section("Historial") {
                NavigationLink("Ver asistencias", destination: Text("Historial de asistencias"))
                NavigationLink("Ver pagos", destination: Text("Historial de pagos"))
            }
        }
        .navigationTitle(name)
    }
}

// MARK: - Admin Occupancy View

struct AdminOccupancyView: View {
    @State private var selectedTimeRange = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current occupancy
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                            .frame(width: 180, height: 180)
                        
                        Circle()
                            .trim(from: 0, to: 0.45)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                        
                        VStack {
                            Text("45")
                                .font(.system(size: 44, weight: .bold))
                            Text("de 100")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Time range picker
                    Picker("Rango", selection: $selectedTimeRange) {
                        Text("Hoy").tag(0)
                        Text("Semana").tag(1)
                        Text("Mes").tag(2)
                        Text("Año").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        AdminOccupancyStat(title: "Pico", value: "89", subtitle: "6:00 PM")
                        AdminOccupancyStat(title: "Valle", value: "12", subtitle: "6:00 AM")
                        AdminOccupancyStat(title: "Promedio", value: "45", subtitle: "personas")
                    }
                    .padding(.horizontal)
                    
                    // Hourly breakdown placeholder
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Desglose por Hora")
                            .font(.headline)
                        
                        ForEach(["6 AM", "9 AM", "12 PM", "3 PM", "6 PM", "9 PM"], id: \.self) { hour in
                            HStack {
                                Text(hour)
                                    .font(.caption)
                                    .frame(width: 50, alignment: .leading)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.accentColor.opacity(0.7))
                                        .frame(width: geo.size.width * Double.random(in: 0.3...1.0))
                                }
                                .frame(height: 20)
                                Text("\(Int.random(in: 20...95))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Ocupación")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

struct AdminOccupancyStat: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Gym Configuration

struct GymConfigurationView: View {
    @State private var maxCapacity = "100"
    @State private var openingTime = Date()
    @State private var closingTime = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Capacidad") {
                    TextField("Capacidad máxima", text: $maxCapacity)
                        .keyboardType(.numberPad)
                }
                
                Section("Horarios") {
                    DatePicker("Apertura", selection: $openingTime, displayedComponents: .hourAndMinute)
                    DatePicker("Cierre", selection: $closingTime, displayedComponents: .hourAndMinute)
                }
                
                Section("Actividades") {
                    NavigationLink("Gestionar actividades", destination: Text("Lista de actividades"))
                    NavigationLink("Gestionar equipos", destination: Text("Lista de equipos"))
                }
                
                Section("Notificaciones") {
                    NavigationLink("Notificaciones automáticas", destination: Text("Configuración de notificaciones"))
                }
                
                Section("Reportes") {
                    Button("Exportar reporte mensual") {}
                    Button("Exportar datos de usuarios") {}
                }
            }
            .navigationTitle("Configuración")
        }
    }
}

// MARK: - Admin Settings

struct AdminSettingsView: View {
    @ObservedObject private var authState = AuthState.shared
    @State private var showLogoutConfirm = false
    @State private var showRoleManager = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink("Mi cuenta", destination: AccountView())
                    NavigationLink("Notificaciones", destination: Text("Configuración de notificaciones"))
                }
                
                // Show role switcher only if user has multiple roles
                if authState.canSwitchRoles {
                    Section {
                        Button {
                            showRoleManager = true
                        } label: {
                            HStack {
                                Image(systemName: authState.currentRole.iconName)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text("Cambiar de Rol")
                                        .foregroundColor(.primary)
                                    Text("Rol actual: \(authState.currentRole.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    NavigationLink("Soporte", destination: Text("Contacto y FAQ"))
                    NavigationLink("Acerca de", destination: Text("GymApp v1.0"))
                }
                
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "power")
                                .foregroundColor(.red)
                            Text("Cerrar sesión")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ajustes")
            .confirmationDialog("¿Cerrar sesión?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) {
                    authState.signOut()
                }
                Button("Cancelar", role: .cancel) {}
            }
            .sheet(isPresented: $showRoleManager) {
                RoleManagerView()
            }
        }
    }
}

#Preview {
    AdminTabView()
}

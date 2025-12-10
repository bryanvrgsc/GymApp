//
//  StaffTabView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// Tab view for staff members
/// Tabs: Check-In/Out, Usuarios, Ocupación, Ajustes
struct StaffTabView: View {
    @State private var selection: Int = 1
    
    var body: some View {
        TabView(selection: $selection) {
            StaffCheckInView()
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Check-In/Out")
                }
                .tag(1)
            
            StaffUsersListView()
                .tabItem {
                    Image(systemName: "person.2")
                    Text("Usuarios")
                }
                .tag(2)
            
            StaffOccupancyView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Ocupación")
                }
                .tag(3)
            
            StaffSettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Ajustes")
                }
                .tag(4)
        }
    }
}

// MARK: - Staff Views

struct StaffCheckInView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar usuario...", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Quick actions
                HStack(spacing: 16) {
                    StaffActionButton(
                        title: "Check-In",
                        icon: "arrow.right.circle.fill",
                        color: .green
                    ) {
                        // TODO: Implement check-in
                    }
                    
                    StaffActionButton(
                        title: "Check-Out",
                        icon: "arrow.left.circle.fill",
                        color: .red
                    ) {
                        // TODO: Implement check-out
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Recent activity
                Text("Actividad Reciente")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                List {
                    StaffActivityRow(name: "Juan Pérez", action: "Check-In", time: "Hace 5 min")
                    StaffActivityRow(name: "María García", action: "Check-Out", time: "Hace 12 min")
                    StaffActivityRow(name: "Carlos López", action: "Check-In", time: "Hace 20 min")
                }
                .listStyle(.plain)
            }
            .navigationTitle("Check-In / Check-Out")
        }
    }
}

struct StaffActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct StaffActivityRow: View {
    let name: String
    let action: String
    let time: String
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text(action)
                    .font(.subheadline)
                    .foregroundColor(action == "Check-In" ? .green : .red)
            }
            
            Spacer()
            
            Text(time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct StaffUsersView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar usuario por nombre o email...", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                List {
                    StaffUserRow(name: "Juan Pérez", badge: .gold, isActive: true)
                    StaffUserRow(name: "María García", badge: .silver, isActive: true)
                    StaffUserRow(name: "Carlos López", badge: .bronze, isActive: false)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Usuarios")
        }
    }
}

struct StaffUserRow: View {
    let name: String
    let badge: BadgeTier
    let isActive: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: badge.iconName)
                        .foregroundColor(badge.color)
                    Text(badge.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(isActive ? "Activo" : "Inactivo")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isActive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .foregroundColor(isActive ? .green : .red)
                .cornerRadius(8)
        }
    }
}

struct StaffOccupancyView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Current occupancy
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: 0.45)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("45")
                            .font(.system(size: 48, weight: .bold))
                        Text("de 100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("personas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Ocupación Moderada")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StaffStatCard(title: "Check-ins hoy", value: "87", icon: "arrow.right.circle")
                    StaffStatCard(title: "Check-outs hoy", value: "42", icon: "arrow.left.circle")
                    StaffStatCard(title: "Pico del día", value: "62", icon: "chart.line.uptrend.xyaxis")
                    StaffStatCard(title: "Promedio", value: "38", icon: "chart.bar")
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Ocupación")
        }
    }
}

struct StaffStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StaffSettingsView: View {
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
    StaffTabView()
}

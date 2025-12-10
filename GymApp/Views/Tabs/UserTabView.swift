//
//  UserTabView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// Tab view for regular users
/// Tabs: Acceso, Perfil, Asistencias, Ocupación, Ajustes
struct UserTabView: View {
    @State private var selection: Int = 1
    
    var body: some View {
        TabView(selection: $selection) {
            UserQRAccessView()
                .tabItem {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Acceso")
                }
                .tag(1)
            
            UserProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Perfil")
                }
                .tag(2)
            
            AttendanceCalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Asistencias")
                }
                .tag(3)
            
            OccupancyView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Ocupación")
                }
                .tag(4)
            
            UserSettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Ajustes")
                }
                .tag(5)
        }
    }
}

// MARK: - Placeholder Views

struct AttendanceView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Calendario de Asistencias")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Aquí podrás ver tu historial de visitas al gimnasio")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Asistencias")
        }
    }
}

struct OccupancyView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                        .frame(width: 150, height: 150)
                    
                    Circle()
                        .trim(from: 0, to: 0.45)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("45%")
                            .font(.system(size: 36, weight: .bold))
                        Text("Ocupación")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Volumen actual del gimnasio")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Moderado - Buen momento para entrenar")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Ocupación")
        }
    }
}

struct UserSettingsView: View {
    @ObservedObject private var authState = AuthState.shared
    @State private var showLogoutConfirm = false
    @State private var showRoleManager = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink("Preferencias", destination: PreferencesView())
                    NavigationLink("Notificaciones", destination: Text("Configuración de notificaciones"))
                    NavigationLink("Gestiona tu cuenta", destination: AccountView())
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
    UserTabView()
}

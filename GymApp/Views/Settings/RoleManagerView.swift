//
//  RoleManagerView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// View to switch between available user roles
/// Only accessible if user has multiple roles
struct RoleManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authState = AuthState.shared
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Tienes acceso a múltiples roles. Selecciona el rol que deseas usar.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section("Tus Roles") {
                    ForEach(availableRoles, id: \.self) { role in
                        Button {
                            authState.currentRole = role
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: role.iconName)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(role.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(roleDescription(for: role))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if authState.currentRole == role {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cambiar de Rol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// Get available roles from the current GymUser
    private var availableRoles: [UserRole] {
        authState.gymUser?.roles ?? [.user]
    }
    
    private func roleDescription(for role: UserRole) -> String {
        switch role {
        case .user:
            return "Acceso QR, perfil, asistencias, ocupación"
        case .staff:
            return "Check-in/out, buscar usuarios, ocupación"
        case .admin:
            return "Dashboard, estadísticas, configuración completa"
        }
    }
}

#Preview {
    RoleManagerView()
}

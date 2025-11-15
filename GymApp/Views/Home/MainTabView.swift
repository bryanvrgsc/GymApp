import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selection: Int = 3 // default to Services (3)

    var body: some View {
        TabView(selection: $selection) {
            QRAccessView()
                .tabItem {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Acceso")
                }
                .tag(1)
            ContentView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Servicios")
                }
                .tag(2)
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Perfil")
                }
                .tag(3)
            PromotionsView()
                .tabItem {
                    Image(systemName: "tag")
                    Text("Promociones")
                }
                .tag(4)
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Ajustes")
                }
                .tag(5)
        }
    }
}

// MARK: - Placeholder Subviews

struct ProfileView: View {
    @ObservedObject private var authState = AuthState.shared
    @State private var isRefreshing = false
    @State private var refreshMessage: String?
    @State private var showRefreshToast = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.accentColor)

                Text(authState.membershipStatus)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let expiryString = authState.membershipExpiryString {
                    Text("Expiración: \(expiryString)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Sin información de membresía")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    Task { await doRefresh() }
                }) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Text("Actualizar membresía")
                    }
                }
                .buttonStyle(.bordered)
                .padding(.top, 6)

                if showRefreshToast, let msg = refreshMessage {
                    Text(msg)
                        .font(.caption)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Perfil")
        }
        .animation(.default, value: showRefreshToast)
    }

    private func doRefresh() async {
        isRefreshing = true
        do {
            _ = try await authState.refreshSession()
            refreshMessage = "Membresía actualizada"
        } catch {
            refreshMessage = "Error al actualizar: \(error.localizedDescription)"
        }
        isRefreshing = false
        withAnimation { showRefreshToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { showRefreshToast = false }
        }
    }
}

struct QRAccessView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Acceso al gimnasio")
                    .font(.title2)

                // Placeholder QR box
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 220, height: 220)
                    .overlay(
                        Image(systemName: "qrcode")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.primary)
                    )

                Button(action: {
                    // Acción para mostrar/actualizar QR
                }) {
                    Text("Mostrar QR")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Acceso")
        }
    }
}

struct PromotionsView: View {
    var body: some View {
        NavigationView {
            List {
                Text("Promo 1 — 20% descuento")
                Text("Promo 2 — Clase gratis")
            }
            .navigationTitle("Promociones")
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var authState = AuthState.shared
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink("Soporte", destination: Text("Contacto y FAQ"))
                    NavigationLink("Gestiona tu cuenta", destination: AccountView())
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
            } message: {
                Text("Se cerrará tu sesión y tendrás que volver a iniciar sesión para acceder.")
            }
        }
    }
}

// MARK: - Account View (Cuenta)
struct AccountView: View {
    @ObservedObject private var authState = AuthState.shared
    @State private var userInfo: [String: Any] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let pic = userInfo["picture"] as? String, let url = URL(string: pic) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 120, height: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 120, height: 120)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                }

                // Name
                HStack {
                    Text("Nombre:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(userInfo["name"] as? String ?? "—")
                        .multilineTextAlignment(.trailing)
                }

                // Email + verified
                HStack {
                    Text("Email:")
                        .fontWeight(.semibold)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(userInfo["email"] as? String ?? "—")
                        HStack(spacing: 6) {
                            let verified = parseEmailVerified(userInfo["email_verified"])
                            Image(systemName: verified ? "checkmark.seal.fill" : "xmark.seal")
                                .foregroundColor(verified ? .green : .red)
                            Text(verified ? "Verificado" : "No verificado")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Provider (sub)
                HStack {
                    Text("Proveedor:")
                        .fontWeight(.semibold)
                    Spacer()
                    HStack(spacing: 8) {
                        providerLogoView(for: userInfo["sub"] as? String)
                        Text(providerName(from: userInfo["sub"] as? String))
                            .foregroundColor(.primary)
                    }
                }

                // Other fields
                if let nick = userInfo["nickname"] as? String {
                    HStack {
                        Text("Nickname:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(nick)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Gestiona tu cuenta")
        .onAppear {
            // Pre-fill from cached profile if available, then fetch fresh /userinfo
            if let profile = authState.userProfile {
                var cached: [String: Any] = [:]
                if let name = profile.name { cached["name"] = name }
                if let email = profile.email { cached["email"] = email }
                if let pic = profile.picture { cached["picture"] = pic }
                if let nick = profile.nickname { cached["nickname"] = nick }
                if let given = profile.givenName { cached["given_name"] = given }
                if let family = profile.familyName { cached["family_name"] = family }
                self.userInfo = cached
            }
            Task { await loadUserInfo() }
        }
        .overlay(alignment: .bottom) {
            if isLoading {
                ProgressView()
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(10)
                    .padding()
            }
        }
    }

    private func loadUserInfo() async {
        guard let access = authState.tokens?.accessToken else { return }
        isLoading = true
        do {
            let info = try await AuthService.shared.getUserInfo(accessToken: access)
            await MainActor.run {
                self.userInfo = info
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func parseEmailVerified(_ raw: Any?) -> Bool {
        if let b = raw as? Bool { return b }
        if let i = raw as? Int { return i != 0 }
        if let s = raw as? String { return (s as NSString).boolValue }
        return false
    }

    private func providerName(from sub: String?) -> String {
        guard let s = sub else { return "Desconocido" }
        let parts = s.split(separator: "|")
        if let p = parts.first {
            let str = String(p)
            if str.contains("google") { return "Google" }
            if str.contains("facebook") { return "Facebook" }
            return str
        }
        return "Desconocido"
    }

    @ViewBuilder
    private func providerLogoView(for sub: String?) -> some View {
        let name = providerName(from: sub)
        if name == "Google" {
            // simple stylized G circle using text
            ZStack {
                Circle().fill(Color.white).frame(width: 28, height: 28).shadow(radius: 1)
                Text("G").font(.headline).foregroundColor(.red)
            }
        } else if name == "Facebook" {
            Image(systemName: "f.circle")
        } else {
            Image(systemName: "person.crop.circle")
        }
    }
}

// MARK: - Preview

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}

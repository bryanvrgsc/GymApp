import SwiftUI
import UIKit

/// Main view that switches between different tab views based on user role
struct MainTabView: View {
    @ObservedObject private var authState = AuthState.shared
    
    var body: some View {
        Group {
            switch authState.currentRole {
            case .user:
                UserTabView()
            case .staff:
                StaffTabView()
            case .admin:
                AdminTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authState.currentRole)
    }
}

// MARK: - QR Access View (shared between roles)

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
                    // TODO: Show/update QR
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

// MARK: - Account View (shared)

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

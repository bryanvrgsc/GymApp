import SwiftUI
import AuthenticationServices
import UIKit

struct Plan: Identifiable {
    let id = UUID()
    let title: String
    let price: String
    let subtitle: String?
    let details: String
}

extension Plan {
    static let samplePlans: [Plan] = [
        Plan(title: "Mensual", price: "$29", subtitle: nil, details: "Acceso mensual ilimitado. Cancelable en cualquier momento."),
        Plan(title: "Anual", price: "$299", subtitle: "Más valor", details: "Pago anual — incluye descuentos y beneficios extra. No se factura suscripción automática aquí.")
    ]
}

struct OnboardingView: View {
    // Navigation / pages
    @State private var selection = 0
    @State private var showPlanDetail: Plan? = nil

    // Login states
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showToast: Bool = false
    private let presentationProvider = WebAuthPresentationProvider()

    private let plans = Plan.samplePlans

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background image - optional asset gym_background
                Image("gym_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.18))

                TabView(selection: $selection) {
                    pageOne.tag(0)
                    pageTwo.tag(1)
                    pageThree.tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                .animation(.easeInOut, value: selection)
                .padding(.horizontal, 16)
            }
        }
        // Toast overlay for login errors
        .overlay(alignment: .bottom) {
            if showToast, let msg = errorMessage {
                ToastView(message: msg)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }

    // MARK: - Pages

    private var pageOne: some View {
        VStack(spacing: 6) {
            Spacer()

            // Hero (unchanged)
            VStack(spacing: 3) {
                Text("Tu mejor versión")
                    .font(.system(size: 45, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("empieza hoy")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)

                Text("Accede a tus clases, membresía y QR de acceso")
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.top, 3)
            }
            .padding(.horizontal, 12)

            Spacer().frame(height: 20)

            // Benefits inside a MiniLiquidCard
            MiniLiquidCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Beneficios")
                        .font(.title).fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Área de pesas", systemImage: "dumbbell")
                            .font(.title3)
                        Label("Clases grupales", systemImage: "person.3")
                            .font(.title3)
                        Label("Entrenadores personales", systemImage: "figure.walk")
                            .font(.title3)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
            }
            .frame(minHeight: 160, maxHeight: 240)

            Spacer()
        }
        .padding(.vertical, 16)
    }

    private var pageTwo: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            // Heading
            VStack(spacing: 6) {
                Text("Planes")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))

                Text("Elige el plan que mejor se adapte a ti")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Responsive cards: HStack on wide, VStack on narrow
            GeometryReader { geo in
                let isWide = geo.size.width > 700

                Group {
                    if isWide {
                        HStack(spacing: 16) {
                            ForEach(plans) { plan in
                                PlanCard(plan: plan, isAnnual: plan.title.lowercased().contains("anual")) {
                                    showPlanDetail = plan
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 220)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(plans) { plan in
                                PlanCard(plan: plan, isAnnual: plan.title.lowercased().contains("anual")) {
                                    showPlanDetail = plan
                                }
                            }
                        }
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isWide)
                .padding(.horizontal)
            }
            .frame(minHeight: 140)

            // Promotions row
            HStack(spacing: 10) {
                PromotionChip(text: "Primer mes 20%")
                PromotionChip(text: "Lleva un amigo")
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.vertical, 20)
        .sheet(item: $showPlanDetail) { plan in
            PlanDetailView(plan: plan)
        }
    }

    // Compact Plan Card used by pageTwo
    private struct PlanCard: View {
        let plan: Plan
        let isAnnual: Bool
        let action: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title)
                            .font(.title2).fontWeight(.bold)
                        if let s = plan.subtitle {
                            Text(s).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if isAnnual {
                        Badge(text: "Más valor")
                    }
                }

                Text(plan.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                HStack(alignment: .center) {
                    Text(plan.price)
                        .font(.title3).fontWeight(.heavy)
                    Spacer()
                    Button(action: action) {
                        Text("Seleccionar")
                            .font(.subheadline).fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(isAnnual ? Color.accentColor : Color(.systemGray5))
                            .foregroundColor(isAnnual ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(16)
            .background(
                ZStack {
                    if isAnnual {
                        RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(0.12))
                        RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial).padding(6)
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                    }
                }
            )
            .overlay(RoundedRectangle(cornerRadius: isAnnual ? 16 : 12)
                        .stroke(isAnnual ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.04), lineWidth: isAnnual ? 2 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: isAnnual ? 16 : 12))
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
    }

    private struct Badge: View {
        let text: String
        var body: some View {
            Text(text)
                .font(.caption2).fontWeight(.semibold)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var pageThree: some View {
        VStack(spacing: 14) {
            Spacer()

            VStack(spacing: 10) {
                Text("¿Eres nuevo aquí?")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Iniciar sesión")
                    .font(.title)
                    .foregroundColor(.secondary)

                Button(action: { Task { await doLogin() } }) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Iniciar sesión")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)

                Divider().padding(.vertical, 8)

                Text("¿Aún no tienes membresía? Consulta en recepción")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: 680)

            Spacer()
        }
        .padding(.vertical, 32)
    }

    // MARK: - Login flow

    @MainActor
    private func doLogin() async {
        guard AuthService.shared.isConfigured() else {
            errorMessage = "Auth0 no está configurado. Reemplaza clientId y domain en AuthService.swift"
            await showTemporaryToast()
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            try await AuthState.shared.signIn(presentationProvider: presentationProvider)
            // AuthState handles updating authentication; On success the app will show MainTabView
        } catch {
            errorMessage = "Error de autenticación: \(error.localizedDescription)"
            await showTemporaryToast()
        }
        isLoading = false
    }

    @MainActor
    private func showTemporaryToast(duration: TimeInterval = 3.5) async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showToast = true }
        do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) } catch { }
        withAnimation(.easeInOut(duration: 0.25)) { showToast = false }
    }
}

// Helper: presentation provider for ASWebAuthenticationSession
private final class WebAuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let foreground = windowScenes.first(where: { $0.activationState == .foregroundActive }) {
            return foreground.windows.first { $0.isKeyWindow } ?? foreground.windows.first ?? UIWindow(windowScene: foreground)
        }
        if let any = windowScenes.compactMap({ $0.windows.first }).first { return any }
        fatalError("No UIWindowScene available to present authentication session")
    }
}

// MARK: - Liquid Card helper

private struct LiquidCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(.clear)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)

            content
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Mini Liquid Card (compact)
private struct MiniLiquidCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.035), lineWidth: 0.4))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)

            content
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Promotion Chip
private struct PromotionChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.035), lineWidth: 0.25))
    }
}

// MARK: - Plan Detail View

private struct PlanDetailView: View {
    let plan: Plan
    @Environment(\ .dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text(plan.title)
                        .font(.largeTitle).fontWeight(.bold)
                    Text(plan.details).foregroundColor(.secondary)

                    if plan.title == "Anual" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ventajas del plan anual:")
                                .font(.headline)
                            Text("- Descuento por pago anual\n- Acceso a contenido exclusivo\n- Soporte prioritario")
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Detalles")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}

// MARK: - Toast View

private struct ToastView: View {
    let message: String

    var body: some View {
        HStack {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 4)
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}

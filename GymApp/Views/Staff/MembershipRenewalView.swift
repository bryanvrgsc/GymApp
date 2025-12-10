//
//  MembershipRenewalView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// View for staff to renew user memberships
struct MembershipRenewalView: View {
    @ObservedObject private var authState = AuthState.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery = ""
    @State private var searchResults: [GymUser] = []
    @State private var isSearching = false
    @State private var selectedUser: GymUser?
    @State private var showRenewalForm = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar usuario por nombre...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .onSubmit {
                            Task { await searchUsers() }
                        }
                    
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Search results or empty state
                if searchResults.isEmpty && !searchQuery.isEmpty && !isSearching {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No se encontraron usuarios")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else if searchResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Busca un usuario para renovar su membresía")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    List(searchResults) { user in
                        UserSearchRow(user: user) {
                            selectedUser = user
                            showRenewalForm = true
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Renovar Membresía")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showRenewalForm) {
                if let user = selectedUser {
                    RenewalFormView(user: user) {
                        showRenewalForm = false
                        selectedUser = nil
                        // Refresh search results
                        Task { await searchUsers() }
                    }
                }
            }
            .onChange(of: searchQuery) { _, newValue in
                if newValue.count >= 2 {
                    Task { await searchUsers() }
                } else if newValue.isEmpty {
                    searchResults = []
                }
            }
        }
    }
    
    private func searchUsers() async {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        
        do {
            let results = try await FirebaseService.shared.searchUsers(query: searchQuery)
            await MainActor.run {
                searchResults = results
            }
        } catch {
            #if DEBUG
            print("[MembershipRenewalView] Search error: \(error)")
            #endif
        }
        
        isSearching = false
    }
}

// MARK: - User Search Row

struct UserSearchRow: View {
    let user: GymUser
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
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
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.accentColor)
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let email = user.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Membership status indicator
                VStack(alignment: .trailing, spacing: 4) {
                    if user.membership?.isActive == true {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Activa")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        if let days = user.membership?.daysRemaining {
                            Text("\(days) días")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Expirada")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Renewal Form View

struct RenewalFormView: View {
    let user: GymUser
    let onComplete: () -> Void
    
    @ObservedObject private var authState = AuthState.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlan: PlanType = .monthly
    @State private var selectedPaymentMethod: PaymentMethod = .cash
    @State private var amount: String = ""
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // User info section
                Section("Usuario") {
                    HStack {
                        if let pic = user.picture, let url = URL(string: pic) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                default:
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 60))
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name)
                                .font(.headline)
                            if let email = user.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Current membership status
                    if let membership = user.membership {
                        LabeledContent("Estado actual") {
                            Text(membership.isActive ? "Activa" : "Expirada")
                                .foregroundColor(membership.isActive ? .green : .red)
                        }
                        if membership.isActive {
                            LabeledContent("Expira") {
                                Text(formatDate(membership.expirationDate))
                            }
                        }
                        LabeledContent("Meses consecutivos") {
                            Text("\(membership.continuousMonths)")
                        }
                    } else {
                        Text("Sin membresía previa")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Plan selection
                Section("Plan") {
                    // Plan options with prices
                    ForEach(PlanType.allCases) { plan in
                        HStack {
                            Image(systemName: selectedPlan == plan ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedPlan == plan ? .accentColor : .secondary)
                            
                            Text(plan.displayName)
                                .fontWeight(selectedPlan == plan ? .semibold : .regular)
                            
                            Spacer()
                            
                            Text("$\(Int(plan.suggestedPrice)) MXN")
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPlan = plan
                            amount = String(Int(plan.suggestedPrice))
                        }
                    }
                }
                
                // Payment section
                Section("Pago") {
                    Picker("Método de pago", selection: $selectedPaymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Label(method.displayName, systemImage: method.iconName)
                                .tag(method)
                        }
                    }
                    
                    HStack {
                        Text("$")
                        TextField("Monto", text: $amount)
                            .keyboardType(.decimalPad)
                        Text("MXN")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Summary
                Section("Resumen") {
                    let startDate = user.membership?.isActive == true ? user.membership!.expirationDate : Date()
                    let endDate = calculateEndDate(from: startDate, plan: selectedPlan)
                    
                    LabeledContent("Inicio del periodo") {
                        Text(formatDate(startDate))
                    }
                    LabeledContent("Fin del periodo") {
                        Text(formatDate(endDate))
                    }
                    LabeledContent("Duración") {
                        Text(selectedPlan.durationMonths > 0 ? "\(selectedPlan.durationMonths) mes(es)" : "\(selectedPlan.durationDays) días")
                    }
                }
                
                // Action button
                Section {
                    Button {
                        Task { await processRenewal() }
                    } label: {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Confirmar Renovación")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isProcessing || amount.isEmpty)
                    .listRowBackground(Color.accentColor)
                    .foregroundColor(.white)
                }
            }
            .navigationTitle("Renovar Membresía")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                amount = String(Int(selectedPlan.suggestedPrice))
            }
            .alert("¡Renovación Exitosa!", isPresented: $showSuccess) {
                Button("OK") {
                    onComplete()
                    dismiss()
                }
            } message: {
                Text("La membresía de \(user.name) ha sido renovada correctamente.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func processRenewal() async {
        guard let staffUser = authState.gymUser,
              let amountValue = Double(amount) else {
            errorMessage = "Datos incompletos"
            showError = true
            return
        }
        
        isProcessing = true
        
        do {
            _ = try await FirebaseService.shared.renewMembership(
                userId: user.id,
                username: user.name,
                staffId: staffUser.id,
                staffName: staffUser.name,
                planType: selectedPlan,
                paymentMethod: selectedPaymentMethod,
                amount: amountValue
            )
            
            await MainActor.run {
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error al procesar: \(error.localizedDescription)"
                showError = true
            }
        }
        
        isProcessing = false
    }
    
    private func calculateEndDate(from start: Date, plan: PlanType) -> Date {
        let calendar = Calendar.current
        if plan.durationMonths > 0 {
            return calendar.date(byAdding: .month, value: plan.durationMonths, to: start) ?? start
        } else {
            return calendar.date(byAdding: .day, value: plan.durationDays, to: start) ?? start
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    MembershipRenewalView()
}

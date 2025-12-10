//
//  PreferencesView.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import SwiftUI

/// View for selecting favorite equipment and activities
struct PreferencesView: View {
    @ObservedObject private var authState = AuthState.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedEquipment: Set<String> = []
    @State private var selectedActivities: Set<String> = []
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var hasChanges = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Equipment Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Preferencias de Equipamiento")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Text("Selecciona el equipo que usas con mayor frecuencia o prefieres")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(EquipmentCategory.allCases) { category in
                        EquipmentCategorySection(
                            category: category,
                            selectedItems: $selectedEquipment,
                            onSelectionChange: { hasChanges = true }
                        )
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Activities Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Preferencias de Actividades")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Text("Selecciona las actividades o clases que te interesan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ActivitiesSection(
                        selectedActivities: $selectedActivities,
                        onSelectionChange: { hasChanges = true }
                    )
                }
                
                // Spacer to ensure content isn't hidden by save button
                Spacer(minLength: 80)
            }
            .padding(.top)
        }
        .navigationTitle("Preferencias")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await savePreferences() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Guardar")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving || !hasChanges)
            }
        }
        .overlay(alignment: .bottom) {
            // Floating save button for visibility
            if hasChanges {
                Button {
                    Task { await savePreferences() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Guardar Cambios")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .disabled(isSaving)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.clear, Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                )
            }
        }
        .overlay {
            if showSaveSuccess {
                SaveSuccessOverlay()
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            loadCurrentPreferences()
        }
        .animation(.easeInOut, value: hasChanges)
        .animation(.spring(), value: showSaveSuccess)
    }
    
    private func loadCurrentPreferences() {
        if let user = authState.gymUser {
            selectedEquipment = Set(user.favoriteEquipment)
            selectedActivities = Set(user.favoriteActivities)
        }
        hasChanges = false
    }
    
    private func savePreferences() async {
        guard let userId = authState.gymUser?.id else { return }
        
        isSaving = true
        
        do {
            try await FirebaseService.shared.updatePreferences(
                userId: userId,
                favoriteEquipment: Array(selectedEquipment),
                favoriteActivities: Array(selectedActivities)
            )
            
            // Update local gymUser
            if var user = authState.gymUser {
                user.favoriteEquipment = Array(selectedEquipment)
                user.favoriteActivities = Array(selectedActivities)
                await MainActor.run {
                    authState.gymUser = user
                    // Persist locally
                    if let data = try? JSONEncoder().encode(user) {
                        UserDefaults.standard.set(data, forKey: "gym_user")
                    }
                }
            }
            
            hasChanges = false
            
            // Show success feedback
            await MainActor.run {
                withAnimation {
                    showSaveSuccess = true
                }
            }
            
            try await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                withAnimation {
                    showSaveSuccess = false
                }
            }
            
        } catch {
            #if DEBUG
            print("[PreferencesView] Error saving preferences: \(error)")
            #endif
        }
        
        isSaving = false
    }
}

// MARK: - Equipment Category Section

struct EquipmentCategorySection: View {
    let category: EquipmentCategory
    @Binding var selectedItems: Set<String>
    let onSelectionChange: () -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: category.iconName)
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    
                    Text(category.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Selection count
                    let count = selectedCount
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal)
                .contentShape(Rectangle())
            }
            
            if isExpanded {
                // Equipment items grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(EquipmentItem.items(for: category)) { item in
                        SelectableItemView(
                            title: item.name,
                            iconName: item.iconName,
                            isSelected: selectedItems.contains(item.id)
                        ) {
                            toggleSelection(item.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var selectedCount: Int {
        let categoryItems = EquipmentItem.items(for: category).map { $0.id }
        return selectedItems.filter { categoryItems.contains($0) }.count
    }
    
    private func toggleSelection(_ id: String) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
        onSelectionChange()
    }
}

// MARK: - Activities Section

struct ActivitiesSection: View {
    @Binding var selectedActivities: Set<String>
    let onSelectionChange: () -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(ActivityItem.allItems) { item in
                SelectableItemView(
                    title: item.name,
                    iconName: item.iconName,
                    isSelected: selectedActivities.contains(item.id)
                ) {
                    toggleSelection(item.id)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func toggleSelection(_ id: String) {
        if selectedActivities.contains(id) {
            selectedActivities.remove(id)
        } else {
            selectedActivities.insert(id)
        }
        onSelectionChange()
    }
}

// MARK: - Selectable Item View

struct SelectableItemView: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.body)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Save Success Overlay

struct SaveSuccessOverlay: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("¡Guardado!")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

#Preview {
    NavigationView {
        PreferencesView()
    }
}

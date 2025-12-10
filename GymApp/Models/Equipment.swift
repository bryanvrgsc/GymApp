//
//  Equipment.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation

/// Equipment categories and items for preferences
enum EquipmentCategory: String, CaseIterable, Identifiable {
    case cardio = "Cardio"
    case strength = "Fuerza / Pesas"
    case functional = "Funcional"
    case other = "Otros"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .cardio: return "figure.run"
        case .strength: return "dumbbell.fill"
        case .functional: return "figure.strengthtraining.functional"
        case .other: return "square.grid.2x2"
        }
    }
}

/// Individual equipment items
struct EquipmentItem: Identifiable, Hashable {
    let id: String
    let name: String
    let category: EquipmentCategory
    let iconName: String
    
    static let allItems: [EquipmentItem] = [
        // Cardio
        EquipmentItem(id: "treadmill", name: "Cinta (Treadmill)", category: .cardio, iconName: "figure.run"),
        EquipmentItem(id: "bike", name: "Bicicleta", category: .cardio, iconName: "bicycle"),
        EquipmentItem(id: "elliptical", name: "Elíptica", category: .cardio, iconName: "figure.elliptical"),
        EquipmentItem(id: "stairmaster", name: "Escaladora", category: .cardio, iconName: "figure.stairs"),
        EquipmentItem(id: "rowing", name: "Rower", category: .cardio, iconName: "figure.rower"),
        
        // Fuerza / Pesas
        EquipmentItem(id: "olympic_bar", name: "Barra olímpica", category: .strength, iconName: "figure.strengthtraining.traditional"),
        EquipmentItem(id: "dumbbells", name: "Mancuernas", category: .strength, iconName: "dumbbell.fill"),
        EquipmentItem(id: "kettlebells", name: "Kettlebells", category: .strength, iconName: "figure.strengthtraining.functional"),
        EquipmentItem(id: "chest_machines", name: "Máquinas de pecho", category: .strength, iconName: "figure.arms.open"),
        EquipmentItem(id: "back_machines", name: "Máquinas de espalda", category: .strength, iconName: "figure.walk"),
        EquipmentItem(id: "leg_machines", name: "Máquinas de pierna", category: .strength, iconName: "figure.walk"),
        EquipmentItem(id: "hack_squat", name: "Hack Squat / Leg Press", category: .strength, iconName: "figure.strengthtraining.traditional"),
        EquipmentItem(id: "cable_machines", name: "Poleas / Cable Machines", category: .strength, iconName: "figure.mixed.cardio"),
        
        // Funcional
        EquipmentItem(id: "trx", name: "TRX", category: .functional, iconName: "figure.core.training"),
        EquipmentItem(id: "plyo_boxes", name: "Cajas pliométricas", category: .functional, iconName: "square.stack.3d.up"),
        EquipmentItem(id: "battle_ropes", name: "Battle ropes", category: .functional, iconName: "figure.highintensity.intervaltraining"),
        EquipmentItem(id: "sled", name: "Sled", category: .functional, iconName: "figure.cross.training"),
        EquipmentItem(id: "rings", name: "Anillas", category: .functional, iconName: "circle"),
        
        // Otros
        EquipmentItem(id: "yoga_mat", name: "Yoga mats", category: .other, iconName: "figure.yoga"),
        EquipmentItem(id: "smith_machine", name: "Máquina Smith", category: .other, iconName: "square.grid.3x3"),
        EquipmentItem(id: "bench", name: "Banco plano / inclinado", category: .other, iconName: "rectangle.fill")
    ]
    
    static func items(for category: EquipmentCategory) -> [EquipmentItem] {
        allItems.filter { $0.category == category }
    }
}

/// Activity/class items for preferences
struct ActivityItem: Identifiable, Hashable {
    let id: String
    let name: String
    let iconName: String
    
    static let allItems: [ActivityItem] = [
        ActivityItem(id: "yoga", name: "Yoga", iconName: "figure.yoga"),
        ActivityItem(id: "pilates", name: "Pilates", iconName: "figure.pilates"),
        ActivityItem(id: "spinning", name: "Spinning", iconName: "bicycle"),
        ActivityItem(id: "crossfit", name: "CrossFit / Funcional", iconName: "figure.cross.training"),
        ActivityItem(id: "boxing", name: "Box / Kickboxing", iconName: "figure.boxing"),
        ActivityItem(id: "zumba", name: "Zumba", iconName: "figure.dance"),
        ActivityItem(id: "hiit", name: "HIIT", iconName: "figure.highintensity.intervaltraining"),
        ActivityItem(id: "powerlifting", name: "Powerlifting", iconName: "figure.strengthtraining.traditional"),
        ActivityItem(id: "calisthenics", name: "Calistenia", iconName: "figure.gymnastics"),
        ActivityItem(id: "swimming", name: "Natación", iconName: "figure.pool.swim"),
        ActivityItem(id: "personal_training", name: "Entrenamiento personal", iconName: "person.2.fill")
    ]
}

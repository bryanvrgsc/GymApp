//
//  GymOccupancy.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation
import SwiftUI

/// Current gym occupancy status
struct GymOccupancy: Codable {
    var currentCount: Int
    var maxCapacity: Int
    var lastUpdated: Date
    
    init(currentCount: Int = 0, maxCapacity: Int = 100, lastUpdated: Date = Date()) {
        self.currentCount = currentCount
        self.maxCapacity = maxCapacity
        self.lastUpdated = lastUpdated
    }
    
    /// Initialize from Firestore document data
    init(from data: [String: Any]) {
        self.currentCount = data["count"] as? Int ?? 0
        self.maxCapacity = data["maxCapacity"] as? Int ?? 100
        
        if let timestamp = data["lastUpdated"] as? TimeInterval {
            self.lastUpdated = Date(timeIntervalSince1970: timestamp)
        } else {
            self.lastUpdated = Date()
        }
    }
    
    /// Occupancy percentage (0.0 - 1.0)
    var occupancyPercentage: Double {
        guard maxCapacity > 0 else { return 0 }
        return min(Double(currentCount) / Double(maxCapacity), 1.0)
    }
    
    /// Current occupancy level
    var level: OccupancyLevel {
        switch occupancyPercentage {
        case 0..<0.25: return .low
        case 0.25..<0.50: return .moderate
        case 0.50..<0.75: return .high
        case 0.75..<0.90: return .veryHigh
        default: return .full
        }
    }
}

/// Occupancy level enumeration
enum OccupancyLevel: String, Codable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "veryHigh"
    case full = "full"
    
    var displayName: String {
        switch self {
        case .low: return "Bajo"
        case .moderate: return "Moderado"
        case .high: return "Alto"
        case .veryHigh: return "Muy Alto"
        case .full: return "Lleno"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        case .full: return .purple
        }
    }
    
    var iconName: String {
        switch self {
        case .low: return "person"
        case .moderate: return "person.2"
        case .high: return "person.2.fill"
        case .veryHigh: return "person.3"
        case .full: return "person.3.fill"
        }
    }
}

/// Hourly volume data for predictions
struct HourlyVolume: Codable, Identifiable {
    var id: String { "\(dayOfWeek)-\(hour)" }
    let hour: Int  // 0-23
    let dayOfWeek: Int  // 1-7 (Sunday = 1)
    var averageCount: Double
    
    var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return formatter.string(from: date)
    }
}

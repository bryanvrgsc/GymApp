//
//  Checkin.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation
import FirebaseFirestore

/// Represents a single check-in or check-out event
struct Checkin: Identifiable, Codable {
    let id: String
    let userId: String
    let type: CheckinType
    let timestamp: Date
    let processedBy: String
    let gymId: String
    
    enum CheckinType: String, Codable {
        case checkin
        case checkout
    }
    
    /// Date string for grouping (YYYY-MM-DD)
    var dateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }
    
    init(id: String, userId: String, type: CheckinType, timestamp: Date, processedBy: String, gymId: String) {
        self.id = id
        self.userId = userId
        self.type = type
        self.timestamp = timestamp
        self.processedBy = processedBy
        self.gymId = gymId
    }
    
    init?(from data: [String: Any], id: String) {
        guard let userId = data["userId"] as? String,
              let typeString = data["type"] as? String,
              let type = CheckinType(rawValue: typeString) else {
            return nil
        }
        
        self.id = id
        self.userId = userId
        self.type = type
        self.processedBy = data["processedBy"] as? String ?? ""
        self.gymId = data["gymId"] as? String ?? "default"
        
        // Parse timestamp
        if let ts = data["timestamp"] as? Timestamp {
            self.timestamp = ts.dateValue()
        } else if let ts = data["timestamp"] as? Date {
            self.timestamp = ts
        } else {
            self.timestamp = Date()
        }
    }
}

/// Grouped attendance for a single day
struct DayAttendance: Identifiable {
    let id: String  // dateKey
    let date: Date
    let checkins: [Checkin]
    
    var checkInTime: Date? {
        checkins.first(where: { $0.type == .checkin })?.timestamp
    }
    
    var checkOutTime: Date? {
        checkins.first(where: { $0.type == .checkout })?.timestamp
    }
    
    var duration: TimeInterval? {
        guard let inTime = checkInTime, let outTime = checkOutTime else { return nil }
        return outTime.timeIntervalSince(inTime)
    }
    
    var durationString: String {
        guard let duration = duration else { return "—" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}

/// Attendance statistics
struct AttendanceStats {
    let totalVisits: Int
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    let mostFrequentDay: String?
    let visitsThisWeek: Int
    let visitsThisMonth: Int
    
    var totalDurationString: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    var averageDurationString: String {
        let hours = Int(averageDuration) / 3600
        let minutes = (Int(averageDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
    
    static let empty = AttendanceStats(
        totalVisits: 0,
        totalDuration: 0,
        averageDuration: 0,
        mostFrequentDay: nil,
        visitsThisWeek: 0,
        visitsThisMonth: 0
    )
}

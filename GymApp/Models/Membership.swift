//
//  Membership.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation
import FirebaseFirestore

/// Plan types for membership
enum PlanType: String, Codable, CaseIterable, Identifiable {
    case weekly = "semanal"
    case biweekly = "quincenal"
    case monthly = "mensual"
    case quarterly = "trimestral"
    case semiannual = "semestral"
    case annual = "anual"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .weekly: return "Semanal"
        case .biweekly: return "Quincenal"
        case .monthly: return "Mensual"
        case .quarterly: return "Trimestral"
        case .semiannual: return "Semestral"
        case .annual: return "Anual"
        }
    }
    
    var durationMonths: Int {
        switch self {
        case .weekly: return 0  // Special case: 7 days
        case .biweekly: return 0  // Special case: 15 days
        case .monthly: return 1
        case .quarterly: return 3
        case .semiannual: return 6
        case .annual: return 12
        }
    }
    
    var durationDays: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 15
        case .monthly: return 30
        case .quarterly: return 90
        case .semiannual: return 180
        case .annual: return 365
        }
    }
    
    /// Suggested price in MXN
    var suggestedPrice: Double {
        switch self {
        case .weekly: return 200
        case .biweekly: return 350
        case .monthly: return 550
        case .quarterly: return 1500
        case .semiannual: return 2800
        case .annual: return 5000
        }
    }
}

/// Payment method for membership
enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash = "efectivo"
    case card = "tarjeta"
    case transfer = "transferencia"
    case other = "otro"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cash: return "Efectivo"
        case .card: return "Tarjeta"
        case .transfer: return "Transferencia"
        case .other: return "Otro"
        }
    }
    
    var iconName: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .transfer: return "arrow.left.arrow.right"
        case .other: return "ellipsis.circle"
        }
    }
}

/// Membership data embedded in user document
struct Membership: Codable {
    var active: Bool
    var planType: PlanType
    var startDate: Date
    var expirationDate: Date
    var continuousMonths: Int
    var lastRenewalDate: Date?
    var lastRenewedBy: String?  // Staff user ID
    var paymentMethod: PaymentMethod?
    
    init(
        active: Bool = false,
        planType: PlanType = .monthly,
        startDate: Date = Date(),
        expirationDate: Date = Date(),
        continuousMonths: Int = 0,
        lastRenewalDate: Date? = nil,
        lastRenewedBy: String? = nil,
        paymentMethod: PaymentMethod? = nil
    ) {
        self.active = active
        self.planType = planType
        self.startDate = startDate
        self.expirationDate = expirationDate
        self.continuousMonths = continuousMonths
        self.lastRenewalDate = lastRenewalDate
        self.lastRenewedBy = lastRenewedBy
        self.paymentMethod = paymentMethod
    }
    
    /// Initialize from Firestore data
    init?(from data: [String: Any]) {
        guard let planRaw = data["planType"] as? String,
              let plan = PlanType(rawValue: planRaw) else {
            return nil
        }
        
        self.active = data["active"] as? Bool ?? false
        self.planType = plan
        
        if let startTs = data["startDate"] as? Timestamp {
            self.startDate = startTs.dateValue()
        } else {
            self.startDate = Date()
        }
        
        if let expTs = data["expirationDate"] as? Timestamp {
            self.expirationDate = expTs.dateValue()
        } else {
            self.expirationDate = Date()
        }
        
        self.continuousMonths = data["continuousMonths"] as? Int ?? 0
        
        if let renewalTs = data["lastRenewalDate"] as? Timestamp {
            self.lastRenewalDate = renewalTs.dateValue()
        }
        
        self.lastRenewedBy = data["lastRenewedBy"] as? String
        
        if let methodRaw = data["paymentMethod"] as? String {
            self.paymentMethod = PaymentMethod(rawValue: methodRaw)
        }
    }
    
    /// Convert to Firestore dictionary
    func asDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "active": active,
            "planType": planType.rawValue,
            "startDate": Timestamp(date: startDate),
            "expirationDate": Timestamp(date: expirationDate),
            "continuousMonths": continuousMonths
        ]
        
        if let renewal = lastRenewalDate {
            dict["lastRenewalDate"] = Timestamp(date: renewal)
        }
        if let staff = lastRenewedBy {
            dict["lastRenewedBy"] = staff
        }
        if let method = paymentMethod {
            dict["paymentMethod"] = method.rawValue
        }
        
        return dict
    }
    
    /// Check if membership is currently active
    var isActive: Bool {
        return active && expirationDate > Date()
    }
    
    /// Days remaining until expiration
    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expirationDate)
        return max(0, components.day ?? 0)
    }
}

/// Membership renewal record for audit trail
struct MembershipRenewal: Codable, Identifiable {
    let id: String  // renewalId (auto-generated)
    let userId: String
    let username: String
    let renewedBy: String  // Staff user ID
    let staffName: String
    
    let paymentMethod: PaymentMethod
    let amount: Double
    let currency: String
    
    let planType: PlanType
    let durationMonths: Int
    
    let periodStart: Date
    let periodEnd: Date
    
    let timestamp: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        username: String,
        renewedBy: String,
        staffName: String,
        paymentMethod: PaymentMethod,
        amount: Double,
        currency: String = "MXN",
        planType: PlanType,
        periodStart: Date,
        periodEnd: Date,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.renewedBy = renewedBy
        self.staffName = staffName
        self.paymentMethod = paymentMethod
        self.amount = amount
        self.currency = currency
        self.planType = planType
        self.durationMonths = planType.durationMonths
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.timestamp = timestamp
    }
    
    /// Initialize from Firestore document
    init?(from data: [String: Any], id: String) {
        self.id = id
        
        guard let userId = data["userId"] as? String,
              let username = data["username"] as? String,
              let renewedBy = data["renewedBy"] as? String,
              let staffName = data["staffName"] as? String,
              let methodRaw = data["paymentMethod"] as? String,
              let method = PaymentMethod(rawValue: methodRaw),
              let amount = data["amount"] as? Double,
              let planRaw = data["planType"] as? String,
              let plan = PlanType(rawValue: planRaw) else {
            return nil
        }
        
        self.userId = userId
        self.username = username
        self.renewedBy = renewedBy
        self.staffName = staffName
        self.paymentMethod = method
        self.amount = amount
        self.currency = data["currency"] as? String ?? "MXN"
        self.planType = plan
        self.durationMonths = data["durationMonths"] as? Int ?? plan.durationMonths
        
        if let startTs = data["periodStart"] as? Timestamp {
            self.periodStart = startTs.dateValue()
        } else {
            return nil
        }
        
        if let endTs = data["periodEnd"] as? Timestamp {
            self.periodEnd = endTs.dateValue()
        } else {
            return nil
        }
        
        if let ts = data["timestamp"] as? Timestamp {
            self.timestamp = ts.dateValue()
        } else {
            self.timestamp = Date()
        }
    }
    
    /// Convert to Firestore dictionary
    func asDictionary() -> [String: Any] {
        return [
            "userId": userId,
            "username": username,
            "staffId": renewedBy,  // Auth0 userId of staff member
            "renewedBy": renewedBy,  // Keep for compatibility
            "staffName": staffName,
            "paymentMethod": paymentMethod.rawValue,
            "amount": amount,
            "currency": currency,
            "planType": planType.rawValue,
            "durationMonths": durationMonths,
            "periodStart": Timestamp(date: periodStart),
            "periodEnd": Timestamp(date: periodEnd),
            "timestamp": Timestamp(date: timestamp)
        ]
    }
}

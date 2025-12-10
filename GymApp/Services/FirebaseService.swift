//
//  FirebaseService.swift
//  GymApp
//
//  Created by Bryan Vargas on 09/12/24.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

/// Singleton service for Firebase Firestore operations
final class FirebaseService {
    static let shared = FirebaseService()
    
    private(set) var db: Firestore!
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Call this once at app launch (in GymAppApp.swift init)
    func configure() {
        FirebaseApp.configure()
        db = Firestore.firestore()
        
        #if DEBUG
        print("[FirebaseService] Firebase configured successfully")
        #endif
    }
    
    // MARK: - User Operations
    
    /// Create new user in Firestore (called on account creation)
    /// Document ID is the Auth0 UserID
    func createUser(
        auth0UserId: String,
        name: String,
        email: String?,
        nickname: String?,
        picture: String?
    ) async throws -> GymUser {
        let now = Date()
        let newUser = GymUser(
            id: auth0UserId,
            name: name,
            email: email,
            nickname: nickname,
            picture: picture,
            roles: [.user],  // Default role is user only
            consecutiveMonths: 0,
            favoriteEquipment: [],
            favoriteActivities: [],
            notificationsEnabled: true,
            createdAt: now,
            lastLogin: now
        )
        
        let ref = db.collection("users").document(auth0UserId)
        try await ref.setData(newUser.asDictionary())
        
        #if DEBUG
        print("[FirebaseService] Created new user: \(auth0UserId)")
        #endif
        
        return newUser
    }
    
    /// Sync user data to Firestore (called on profile update)
    func syncUser(_ user: GymUser) async throws {
        let ref = db.collection("users").document(user.id)
        try await ref.setData(user.asDictionary(), merge: true)
        
        #if DEBUG
        print("[FirebaseService] User synced: \(user.id)")
        #endif
    }
    
    /// Update last login timestamp
    func updateLastLogin(userId: String) async throws {
        let ref = db.collection("users").document(userId)
        try await ref.updateData([
            "lastLogin": Timestamp(date: Date())
        ])
    }
    
    /// Fetch user from Firestore by Auth0 UserID
    func getUser(auth0UserId: String) async throws -> GymUser? {
        let doc = try await db.collection("users").document(auth0UserId).getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return GymUser(from: data, id: auth0UserId)
    }
    
    /// Check if user exists
    func userExists(auth0UserId: String) async throws -> Bool {
        let doc = try await db.collection("users").document(auth0UserId).getDocument()
        return doc.exists
    }
    
    /// Update user preferences
    func updatePreferences(
        userId: String,
        favoriteEquipment: [String],
        favoriteActivities: [String]
    ) async throws {
        let ref = db.collection("users").document(userId)
        try await ref.updateData([
            "favoriteEquipment": favoriteEquipment,
            "favoriteActivities": favoriteActivities
        ])
    }
    
    /// Update notification settings
    func updateNotifications(userId: String, enabled: Bool) async throws {
        let ref = db.collection("users").document(userId)
        try await ref.updateData([
            "notificationsEnabled": enabled
        ])
    }
    
    /// Update user profile (admin only)
    func updateUserProfile(
        userId: String,
        name: String,
        email: String?,
        roles: [UserRole],
        notificationsEnabled: Bool
    ) async throws {
        let ref = db.collection("users").document(userId)
        
        var data: [String: Any] = [
            "name": name,
            "roles": roles.map { $0.rawValue },
            "notificationsEnabled": notificationsEnabled
        ]
        
        if let email = email {
            data["email"] = email
        }
        
        try await ref.updateData(data)
        
        #if DEBUG
        print("[FirebaseService] Updated user profile: \(userId), roles: \(roles.map { $0.rawValue })")
        #endif
    }
    
    // MARK: - Attendance Operations
    
    /// Record check-in
    func checkIn(userId: String) async throws -> String {
        let data: [String: Any] = [
            "userId": userId,
            "checkInTime": FieldValue.serverTimestamp(),
            "checkOutTime": NSNull()
        ]
        let ref = try await db.collection("attendance").addDocument(data: data)
        
        // Update current occupancy
        try await incrementOccupancy()
        
        #if DEBUG
        print("[FirebaseService] Check-in recorded: \(ref.documentID)")
        #endif
        
        return ref.documentID
    }
    
    /// Record check-out
    func checkOut(attendanceId: String) async throws {
        let ref = db.collection("attendance").document(attendanceId)
        try await ref.updateData([
            "checkOutTime": FieldValue.serverTimestamp()
        ])
        
        // Update current occupancy
        try await decrementOccupancy()
        
        #if DEBUG
        print("[FirebaseService] Check-out recorded: \(attendanceId)")
        #endif
    }
    
    /// Record check-in from QR scanner (creates new document)
    func recordCheckIn(userId: String, staffId: String, gymId: String) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "type": "checkin",
            "timestamp": FieldValue.serverTimestamp(),
            "processedBy": staffId,
            "gymId": gymId
        ]
        
        let ref = try await db.collection("checkins").addDocument(data: data)
        
        // Update occupancy
        try await incrementOccupancy()
        
        #if DEBUG
        print("[FirebaseService] QR Check-in recorded: \(ref.documentID)")
        #endif
    }
    
    /// Record check-out from QR scanner (creates new document)
    func recordCheckOut(userId: String, staffId: String, gymId: String) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "type": "checkout",
            "timestamp": FieldValue.serverTimestamp(),
            "processedBy": staffId,
            "gymId": gymId
        ]
        
        let ref = try await db.collection("checkins").addDocument(data: data)
        
        // Update occupancy
        try await decrementOccupancy()
        
        #if DEBUG
        print("[FirebaseService] QR Check-out recorded: \(ref.documentID)")
        #endif
    }
    
    /// Get user's attendance history
    func getAttendanceHistory(userId: String, limit: Int = 30) async throws -> [AttendanceRecord] {
        let snapshot = try await db.collection("attendance")
            .whereField("userId", isEqualTo: userId)
            .order(by: "checkInTime", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            AttendanceRecord(from: doc.data(), id: doc.documentID)
        }
    }
    
    /// Get user's checkins for a month (from /checkins collection)
    /// Note: Fetches all user's checkins and filters locally to avoid composite index requirement
    func getUserCheckins(userId: String, startDate: Date, endDate: Date) async throws -> [Checkin] {
        #if DEBUG
        print("[FirebaseService] Fetching checkins for userId: \(userId)")
        print("[FirebaseService] Date range: \(startDate) to \(endDate)")
        #endif
        
        let snapshot = try await db.collection("checkins")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        #if DEBUG
        print("[FirebaseService] Found \(snapshot.documents.count) total checkins for user")
        #endif
        
        let allCheckins = snapshot.documents.compactMap { doc -> Checkin? in
            Checkin(from: doc.data(), id: doc.documentID)
        }
        
        // Filter by date range locally
        let filtered = allCheckins.filter { checkin in
            checkin.timestamp >= startDate && checkin.timestamp <= endDate
        }.sorted { $0.timestamp < $1.timestamp }
        
        #if DEBUG
        print("[FirebaseService] Filtered to \(filtered.count) checkins in date range")
        #endif
        
        return filtered
    }
    
    /// Get all checkins for a user (for stats calculation)
    func getAllUserCheckins(userId: String, limit: Int = 500) async throws -> [Checkin] {
        #if DEBUG
        print("[FirebaseService] Fetching all checkins for userId: \(userId)")
        #endif
        
        let snapshot = try await db.collection("checkins")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        let checkins = snapshot.documents.compactMap { doc in
            Checkin(from: doc.data(), id: doc.documentID)
        }.sorted { $0.timestamp > $1.timestamp }
        
        #if DEBUG
        print("[FirebaseService] Found \(checkins.count) total checkins")
        #endif
        
        return Array(checkins.prefix(limit))
    }
    
    /// Get recent checkins for admin activity view (all users)
    func getRecentCheckins(limit: Int = 100) async throws -> [Checkin] {
        let snapshot = try await db.collection("checkins")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            Checkin(from: doc.data(), id: doc.documentID)
        }
    }
    
    // MARK: - Occupancy Operations
    
    private func incrementOccupancy() async throws {
        let ref = db.collection("occupancy").document("current")
        try await ref.setData([
            "count": FieldValue.increment(Int64(1)),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    private func decrementOccupancy() async throws {
        let ref = db.collection("occupancy").document("current")
        try await ref.setData([
            "count": FieldValue.increment(Int64(-1)),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    /// Get current occupancy
    func getCurrentOccupancy() async throws -> GymOccupancy {
        let doc = try await db.collection("occupancy").document("current").getDocument()
        if let data = doc.data() {
            return GymOccupancy(from: data)
        }
        return GymOccupancy()
    }
    
    /// Get current occupancy with real-time listener
    func observeOccupancy() -> AsyncStream<GymOccupancy> {
        AsyncStream { continuation in
            let ref = db.collection("occupancy").document("current")
            let listener = ref.addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else { return }
                let occupancy = GymOccupancy(from: data)
                continuation.yield(occupancy)
            }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    // MARK: - Membership Operations
    
    /// Search users by name or email (for staff to find users)
    func searchUsers(query: String, limit: Int = 20) async throws -> [GymUser] {
        // Search by name (case-insensitive prefix matching)
        let snapshot = try await db.collection("users")
            .order(by: "name")
            .start(at: [query])
            .end(at: [query + "\u{f8ff}"])
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            GymUser(from: doc.data(), id: doc.documentID)
        }
    }
    
    /// Get all users (for staff list view)
    func getAllUsers(limit: Int = 50) async throws -> [GymUser] {
        let snapshot = try await db.collection("users")
            .order(by: "name")
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            GymUser(from: doc.data(), id: doc.documentID)
        }
    }
    
    /// Renew membership for a user (staff action)
    /// Creates renewal record and updates user membership
    func renewMembership(
        userId: String,
        username: String,
        staffId: String,
        staffName: String,
        planType: PlanType,
        paymentMethod: PaymentMethod,
        amount: Double,
        currency: String = "MXN"
    ) async throws -> MembershipRenewal {
        let now = Date()
        
        // Get current user to check existing membership
        let userRef = db.collection("users").document(userId)
        let userDoc = try await userRef.getDocument()
        
        var periodStart = now
        var continuousMonths = 0
        
        // If user has existing active membership, extend from expiration date
        if let userData = userDoc.data(),
           let membershipData = userData["membership"] as? [String: Any],
           let membership = Membership(from: membershipData),
           membership.isActive {
            periodStart = membership.expirationDate
            continuousMonths = membership.continuousMonths
        }
        
        // Calculate period end based on plan type
        let calendar = Calendar.current
        let periodEnd: Date
        if planType.durationMonths > 0 {
            periodEnd = calendar.date(byAdding: .month, value: planType.durationMonths, to: periodStart) ?? periodStart
        } else {
            periodEnd = calendar.date(byAdding: .day, value: planType.durationDays, to: periodStart) ?? periodStart
        }
        
        // Increment continuous months
        continuousMonths += max(1, planType.durationMonths)
        
        // Create renewal record
        let renewal = MembershipRenewal(
            userId: userId,
            username: username,
            renewedBy: staffId,
            staffName: staffName,
            paymentMethod: paymentMethod,
            amount: amount,
            currency: currency,
            planType: planType,
            periodStart: periodStart,
            periodEnd: periodEnd,
            timestamp: now
        )
        
        // Save renewal to membership_renewals collection
        let renewalRef = db.collection("membership_renewals").document(renewal.id)
        try await renewalRef.setData(renewal.asDictionary())
        
        // Update user's membership object
        let newMembership = Membership(
            active: true,
            planType: planType,
            startDate: periodStart == now ? now : (Membership(from: userDoc.data()?["membership"] as? [String: Any] ?? [:])?.startDate ?? now),
            expirationDate: periodEnd,
            continuousMonths: continuousMonths,
            lastRenewalDate: now,
            lastRenewedBy: staffId,
            paymentMethod: paymentMethod
        )
        
        try await userRef.updateData([
            "membership": newMembership.asDictionary(),
            "consecutiveMonths": continuousMonths
        ])
        
        #if DEBUG
        print("[FirebaseService] Membership renewed for user: \(userId), renewal ID: \(renewal.id)")
        #endif
        
        return renewal
    }
    
    /// Get membership renewal history for a user
    func getRenewalHistory(userId: String, limit: Int = 20) async throws -> [MembershipRenewal] {
        #if DEBUG
        print("[FirebaseService] Getting renewal history for user: \(userId)")
        #endif
        
        // Simple query without ordering (avoids composite index requirement)
        let snapshot = try await db.collection("membership_renewals")
            .whereField("userId", isEqualTo: userId)
            .limit(to: limit)
            .getDocuments()
        
        #if DEBUG
        print("[FirebaseService] Found \(snapshot.documents.count) renewals")
        #endif
        
        var renewals = snapshot.documents.compactMap { doc -> MembershipRenewal? in
            let data = doc.data()
            #if DEBUG
            print("[FirebaseService] Renewal doc: \(doc.documentID), data keys: \(data.keys)")
            #endif
            return MembershipRenewal(from: data, id: doc.documentID)
        }
        
        // Sort locally by timestamp descending
        renewals.sort { $0.timestamp > $1.timestamp }
        
        return renewals
    }
    
    /// Get all recent renewals (for admin dashboard)
    func getRecentRenewals(limit: Int = 50) async throws -> [MembershipRenewal] {
        let snapshot = try await db.collection("membership_renewals")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            MembershipRenewal(from: doc.data(), id: doc.documentID)
        }
    }
    
    /// Get user's current membership
    func getUserMembership(userId: String) async throws -> Membership? {
        let doc = try await db.collection("users").document(userId).getDocument()
        guard let data = doc.data(),
              let membershipData = data["membership"] as? [String: Any] else {
            return nil
        }
        return Membership(from: membershipData)
    }
}

// MARK: - Attendance Record Model

struct AttendanceRecord: Codable, Identifiable {
    let id: String
    let userId: String
    let checkInTime: Date
    var checkOutTime: Date?
    
    var duration: TimeInterval? {
        guard let checkOut = checkOutTime else { return nil }
        return checkOut.timeIntervalSince(checkInTime)
    }
    
    var durationString: String? {
        guard let duration = duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
    
    init?(from data: [String: Any], id: String) {
        self.id = id
        guard let userId = data["userId"] as? String else { return nil }
        self.userId = userId
        
        if let timestamp = data["checkInTime"] as? Timestamp {
            self.checkInTime = timestamp.dateValue()
        } else {
            return nil
        }
        
        if let timestamp = data["checkOutTime"] as? Timestamp {
            self.checkOutTime = timestamp.dateValue()
        }
    }
}

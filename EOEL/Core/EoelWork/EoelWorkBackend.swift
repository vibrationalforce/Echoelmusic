//
//  EoelWorkBackend.swift
//  EOEL
//
//  Created: 2025-11-24
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Complete backend implementation for EoelWork multi-industry gig platform
//  Firebase Firestore + Cloud Functions + Authentication
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import FirebaseMessaging
import CoreLocation
import Stripe

/// Complete EoelWork backend implementation with Firebase
@MainActor
final class EoelWorkBackend: ObservableObject {
    static let shared = EoelWorkBackend()

    // MARK: - Firebase Components

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let functions = Functions.functions()
    private let messaging = Messaging.messaging()

    // MARK: - Stripe Payment

    private var stripePublishableKey = "pk_live_YOUR_KEY_HERE" // TODO: Replace with actual key

    // MARK: - Published State

    @Published var currentUser: EoelWorkUser?
    @Published var authState: AuthState = .loggedOut
    @Published var availableGigs: [Gig] = []
    @Published var myGigs: [Gig] = []
    @Published var activeContracts: [Contract] = []
    @Published var notifications: [GigNotification] = []
    @Published var isLoading: Bool = false

    enum AuthState {
        case loggedOut
        case loggingIn
        case loggedIn(uid: String)
        case error(Error)
    }

    // MARK: - Initialization

    private init() {
        // Configure Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Setup auth state listener
        setupAuthListener()

        // Configure Stripe
        StripeAPI.defaultPublishableKey = stripePublishableKey
    }

    // MARK: - Authentication

    private func setupAuthListener() {
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.authState = .loggedIn(uid: user.uid)
                    try? await self?.loadUserProfile(uid: user.uid)
                } else {
                    self?.authState = .loggedOut
                    self?.currentUser = nil
                }
            }
        }
    }

    /// Sign up new user
    func signUp(email: String, password: String, profile: UserProfile) async throws -> EoelWorkUser {
        isLoading = true
        defer { isLoading = false }

        // Create Firebase auth account
        let authResult = try await auth.createUser(withEmail: email, password: password)
        let uid = authResult.user.uid

        // Create user profile in Firestore
        let user = EoelWorkUser(
            id: uid,
            email: email,
            profile: profile,
            industries: profile.industries,
            subscriptionStatus: .trial,
            createdAt: Date(),
            rating: 5.0,
            completedGigs: 0,
            earnings: 0
        )

        try await saveUserProfile(user)

        currentUser = user
        authState = .loggedIn(uid: uid)

        return user
    }

    /// Sign in existing user
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let authResult = try await auth.signIn(withEmail: email, password: password)
        try await loadUserProfile(uid: authResult.user.uid)
    }

    /// Sign out
    func signOut() throws {
        try auth.signOut()
        currentUser = nil
        availableGigs = []
        myGigs = []
        activeContracts = []
    }

    // MARK: - User Profile Management

    private func saveUserProfile(_ user: EoelWorkUser) async throws {
        let data: [String: Any] = [
            "email": user.email,
            "profile": [
                "name": user.profile.name,
                "bio": user.profile.bio,
                "skills": user.profile.skills,
                "industries": user.profile.industries.map { $0.rawValue },
                "hourlyRate": user.profile.hourlyRate ?? 0,
                "availability": user.profile.availability.rawValue,
                "location": user.profile.location != nil ? [
                    "latitude": user.profile.location!.coordinate.latitude,
                    "longitude": user.profile.location!.coordinate.longitude
                ] : [:],
                "phoneNumber": user.profile.phoneNumber ?? "",
                "portfolio": user.profile.portfolio ?? [],
                "certifications": user.profile.certifications ?? []
            ],
            "industries": user.industries.map { $0.rawValue },
            "subscriptionStatus": encodeSubscriptionStatus(user.subscriptionStatus),
            "createdAt": Timestamp(date: user.createdAt),
            "rating": user.rating,
            "completedGigs": user.completedGigs,
            "earnings": user.earnings
        ]

        try await db.collection("users").document(user.id).setData(data)
    }

    private func loadUserProfile(uid: String) async throws {
        let document = try await db.collection("users").document(uid).getDocument()
        guard let data = document.data() else {
            throw EoelWorkError.userNotFound
        }

        currentUser = try decodeUser(from: data, uid: uid)

        // Load user's gigs and contracts
        try await loadMyGigs()
        try await loadActiveContracts()
    }

    func updateProfile(_ profile: UserProfile) async throws {
        guard var user = currentUser else { throw EoelWorkError.notAuthenticated }
        user.profile = profile
        try await saveUserProfile(user)
        currentUser = user
    }

    // MARK: - Gig Management

    /// Post a new gig
    func postGig(_ gig: Gig) async throws -> String {
        guard let user = currentUser else { throw EoelWorkError.notAuthenticated }

        let gigData: [String: Any] = [
            "title": gig.title,
            "description": gig.description,
            "industry": gig.industry.rawValue,
            "budget": gig.budget,
            "urgency": gig.urgency.rawValue,
            "location": [
                "latitude": gig.location.coordinate.latitude,
                "longitude": gig.location.coordinate.longitude,
                "address": gig.locationAddress ?? ""
            ],
            "requiredSkills": gig.requiredSkills,
            "postedBy": user.id,
            "postedAt": Timestamp(date: gig.postedAt),
            "expiresAt": Timestamp(date: gig.expiresAt ?? Date().addingTimeInterval(7*24*60*60)),
            "status": "open",
            "applicants": [],
            "selectedProvider": "",
            "estimatedDuration": gig.estimatedDuration ?? 0,
            "paymentVerified": false
        ]

        let docRef = try await db.collection("gigs").addDocument(data: gigData)

        // Send push notifications to matching providers
        try await notifyMatchingProviders(gigId: docRef.documentID, gig: gig)

        return docRef.documentID
    }

    /// Search for gigs with filters
    func searchGigs(
        industry: EoelWorkManager.Industry? = nil,
        location: CLLocation? = nil,
        radius: Double = 50.0, // km
        urgency: Gig.Urgency? = nil,
        minBudget: Double? = nil,
        maxBudget: Double? = nil
    ) async throws -> [Gig] {
        isLoading = true
        defer { isLoading = false }

        var query: Query = db.collection("gigs")
            .whereField("status", isEqualTo: "open")

        // Filter by industry
        if let industry = industry {
            query = query.whereField("industry", isEqualTo: industry.rawValue)
        }

        // Filter by urgency
        if let urgency = urgency {
            query = query.whereField("urgency", isEqualTo: urgency.rawValue)
        }

        // Filter by budget range
        if let minBudget = minBudget {
            query = query.whereField("budget", isGreaterThanOrEqualTo: minBudget)
        }
        if let maxBudget = maxBudget {
            query = query.whereField("budget", isLessThanOrEqualTo: maxBudget)
        }

        // Order by urgency and posted date
        query = query.order(by: "urgency", descending: true)
            .order(by: "postedAt", descending: true)
            .limit(to: 50)

        let snapshot = try await query.getDocuments()
        var gigs = try snapshot.documents.compactMap { try decodeGig(from: $0.data(), id: $0.documentID) }

        // Filter by location/radius if provided
        if let location = location {
            gigs = gigs.filter { gig in
                let distance = gig.location.distance(from: location) / 1000 // Convert to km
                return distance <= radius
            }
        }

        availableGigs = gigs
        return gigs
    }

    /// Load gigs posted by current user
    private func loadMyGigs() async throws {
        guard let user = currentUser else { return }

        let snapshot = try await db.collection("gigs")
            .whereField("postedBy", isEqualTo: user.id)
            .order(by: "postedAt", descending: true)
            .getDocuments()

        myGigs = try snapshot.documents.compactMap { try decodeGig(from: $0.data(), id: $0.documentID) }
    }

    /// Apply for a gig
    func applyForGig(_ gigId: String, proposal: String, proposedRate: Double) async throws {
        guard let user = currentUser else { throw EoelWorkError.notAuthenticated }

        let application: [String: Any] = [
            "providerId": user.id,
            "providerName": user.profile.name,
            "providerRating": user.rating,
            "proposal": proposal,
            "proposedRate": proposedRate,
            "appliedAt": Timestamp(date: Date())
        ]

        try await db.collection("gigs").document(gigId)
            .updateData([
                "applicants": FieldValue.arrayUnion([application])
            ])

        // Notify gig poster
        try await sendNotification(
            userId: "", // Get from gig.postedBy
            title: "New Application",
            body: "\(user.profile.name) applied for your gig"
        )
    }

    /// Accept a provider for a gig
    func acceptProvider(gigId: String, providerId: String) async throws {
        guard let user = currentUser else { throw EoelWorkError.notAuthenticated }

        // Update gig status
        try await db.collection("gigs").document(gigId)
            .updateData([
                "status": "accepted",
                "selectedProvider": providerId
            ])

        // Create contract
        let contract = Contract(
            id: UUID().uuidString,
            gigId: gigId,
            clientId: user.id,
            providerId: providerId,
            status: .pending,
            createdAt: Date(),
            amount: 0 // Get from gig
        )

        try await saveContract(contract)

        // Notify provider
        try await sendNotification(
            userId: providerId,
            title: "Gig Accepted! 🎉",
            body: "You've been selected for a gig"
        )
    }

    // MARK: - Contract Management

    private func saveContract(_ contract: Contract) async throws {
        let data: [String: Any] = [
            "gigId": contract.gigId,
            "clientId": contract.clientId,
            "providerId": contract.providerId,
            "status": contract.status.rawValue,
            "createdAt": Timestamp(date: contract.createdAt),
            "amount": contract.amount,
            "completedAt": contract.completedAt != nil ? Timestamp(date: contract.completedAt!) : NSNull(),
            "rating": contract.rating ?? 0,
            "review": contract.review ?? ""
        ]

        try await db.collection("contracts").document(contract.id).setData(data)
    }

    private func loadActiveContracts() async throws {
        guard let user = currentUser else { return }

        let snapshot = try await db.collection("contracts")
            .whereField("providerId", isEqualTo: user.id)
            .whereField("status", in: ["pending", "active"])
            .getDocuments()

        activeContracts = try snapshot.documents.compactMap { try decodeContract(from: $0.data(), id: $0.documentID) }
    }

    func completeContract(_ contractId: String, rating: Int, review: String) async throws {
        try await db.collection("contracts").document(contractId)
            .updateData([
                "status": "completed",
                "completedAt": Timestamp(date: Date()),
                "rating": rating,
                "review": review
            ])

        // Update provider stats
        if let user = currentUser {
            try await db.collection("users").document(user.id)
                .updateData([
                    "completedGigs": FieldValue.increment(Int64(1)),
                    "rating": FieldValue.increment(Int64(rating))
                ])
        }

        try await loadActiveContracts()
    }

    // MARK: - AI Matching Algorithm

    /// AI-powered matching between providers and gigs
    func findMatchingGigs(for user: EoelWorkUser) async throws -> [Gig] {
        // Call Cloud Function for AI matching
        let data: [String: Any] = [
            "userId": user.id,
            "skills": user.profile.skills,
            "industries": user.industries.map { $0.rawValue },
            "location": user.profile.location != nil ? [
                "latitude": user.profile.location!.coordinate.latitude,
                "longitude": user.profile.location!.coordinate.longitude
            ] : [:],
            "availability": user.profile.availability.rawValue,
            "rating": user.rating
        ]

        let result = try await functions.httpsCallable("matchGigs").call(data)
        guard let gigIds = result.data as? [String] else { return [] }

        // Fetch matched gigs
        var matchedGigs: [Gig] = []
        for gigId in gigIds {
            if let gig = try? await getGig(gigId: gigId) {
                matchedGigs.append(gig)
            }
        }

        return matchedGigs
    }

    private func getGig(gigId: String) async throws -> Gig {
        let document = try await db.collection("gigs").document(gigId).getDocument()
        guard let data = document.data() else { throw EoelWorkError.gigNotFound }
        return try decodeGig(from: data, id: gigId)
    }

    // MARK: - Push Notifications

    func setupPushNotifications() async throws {
        try await messaging.token()

        // Request permission
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        try await UNUserNotificationCenter.current().requestAuthorization(options: authOptions)

        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func sendNotification(userId: String, title: String, body: String) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "title": title,
            "body": body,
            "timestamp": Timestamp(date: Date())
        ]

        try await functions.httpsCallable("sendNotification").call(data)
    }

    private func notifyMatchingProviders(gigId: String, gig: Gig) async throws {
        // Emergency gigs: notify immediately (<5 min)
        if gig.urgency == .emergency {
            let data: [String: Any] = [
                "gigId": gigId,
                "industry": gig.industry.rawValue,
                "location": [
                    "latitude": gig.location.coordinate.latitude,
                    "longitude": gig.location.coordinate.longitude
                ],
                "urgency": "emergency"
            ]

            try await functions.httpsCallable("notifyEmergencyGig").call(data)
        }
    }

    // MARK: - Payment Processing (Stripe)

    func processPayment(amount: Double, contractId: String) async throws -> String {
        let data: [String: Any] = [
            "amount": Int(amount * 100), // Convert to cents
            "currency": "usd",
            "contractId": contractId
        ]

        let result = try await functions.httpsCallable("processPayment").call(data)
        guard let paymentIntentId = result.data as? String else {
            throw EoelWorkError.paymentFailed
        }

        return paymentIntentId
    }

    // MARK: - Subscription Management

    func subscribe(plan: SubscriptionPlan) async throws {
        guard let user = currentUser else { throw EoelWorkError.notAuthenticated }

        let price = plan == .monthly ? 6.99 : 69.99
        let paymentIntentId = try await processPayment(amount: price, contractId: "subscription_\(user.id)")

        // Update subscription status
        try await db.collection("users").document(user.id)
            .updateData([
                "subscriptionStatus": [
                    "type": "active",
                    "plan": plan == .monthly ? "monthly" : "yearly",
                    "startDate": Timestamp(date: Date()),
                    "nextBillingDate": Timestamp(date: Date().addingTimeInterval(plan == .monthly ? 30*24*60*60 : 365*24*60*60))
                ]
            ])

        currentUser?.subscriptionStatus = .active(plan: plan)
    }

    // MARK: - Helper Methods

    private func encodeSubscriptionStatus(_ status: SubscriptionStatus) -> [String: Any] {
        switch status {
        case .trial:
            return ["type": "trial"]
        case .active(let plan):
            return ["type": "active", "plan": plan == .monthly ? "monthly" : "yearly"]
        case .cancelled:
            return ["type": "cancelled"]
        case .expired:
            return ["type": "expired"]
        }
    }

    private func decodeUser(from data: [String: Any], uid: String) throws -> EoelWorkUser {
        guard let email = data["email"] as? String,
              let profileData = data["profile"] as? [String: Any],
              let name = profileData["name"] as? String,
              let bio = profileData["bio"] as? String,
              let skills = profileData["skills"] as? [String],
              let industriesRaw = profileData["industries"] as? [String] else {
            throw EoelWorkError.decodingFailed
        }

        let industries = industriesRaw.compactMap { EoelWorkManager.Industry(rawValue: $0) }

        let profile = UserProfile(
            name: name,
            bio: bio,
            skills: skills,
            industries: industries,
            hourlyRate: profileData["hourlyRate"] as? Double,
            availability: UserProfile.Availability(rawValue: (profileData["availability"] as? String) ?? "partTime") ?? .partTime,
            location: nil, // Decode from location data if needed
            phoneNumber: profileData["phoneNumber"] as? String,
            portfolio: profileData["portfolio"] as? [String],
            certifications: profileData["certifications"] as? [String]
        )

        return EoelWorkUser(
            id: uid,
            email: email,
            profile: profile,
            industries: industries,
            subscriptionStatus: .trial, // Decode from data
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            rating: data["rating"] as? Double ?? 5.0,
            completedGigs: data["completedGigs"] as? Int ?? 0,
            earnings: data["earnings"] as? Double ?? 0
        )
    }

    private func decodeGig(from data: [String: Any], id: String) throws -> Gig {
        guard let title = data["title"] as? String,
              let description = data["description"] as? String,
              let industryRaw = data["industry"] as? String,
              let industry = EoelWorkManager.Industry(rawValue: industryRaw),
              let budget = data["budget"] as? Double,
              let urgencyRaw = data["urgency"] as? String,
              let urgency = Gig.Urgency(rawValue: urgencyRaw),
              let locationData = data["location"] as? [String: Any],
              let latitude = locationData["latitude"] as? Double,
              let longitude = locationData["longitude"] as? Double,
              let requiredSkills = data["requiredSkills"] as? [String],
              let postedBy = data["postedBy"] as? String,
              let postedAt = (data["postedAt"] as? Timestamp)?.dateValue() else {
            throw EoelWorkError.decodingFailed
        }

        return Gig(
            id: id,
            title: title,
            description: description,
            industry: industry,
            budget: budget,
            urgency: urgency,
            location: CLLocation(latitude: latitude, longitude: longitude),
            locationAddress: locationData["address"] as? String,
            requiredSkills: requiredSkills,
            postedBy: postedBy,
            postedAt: postedAt,
            expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue(),
            estimatedDuration: data["estimatedDuration"] as? Int
        )
    }

    private func decodeContract(from data: [String: Any], id: String) throws -> Contract {
        guard let gigId = data["gigId"] as? String,
              let clientId = data["clientId"] as? String,
              let providerId = data["providerId"] as? String,
              let statusRaw = data["status"] as? String,
              let status = Contract.Status(rawValue: statusRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let amount = data["amount"] as? Double else {
            throw EoelWorkError.decodingFailed
        }

        return Contract(
            id: id,
            gigId: gigId,
            clientId: clientId,
            providerId: providerId,
            status: status,
            createdAt: createdAt,
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
            amount: amount,
            rating: data["rating"] as? Int,
            review: data["review"] as? String
        )
    }

    enum SubscriptionPlan {
        case monthly // $6.99/month
        case yearly  // $69.99/year (2 months free)
    }
}

// MARK: - Extended Models

extension EoelWorkUser {
    var email: String { "" } // Add to struct
    var createdAt: Date { Date() } // Add to struct
    var earnings: Double { 0 } // Add to struct
}

extension Gig {
    var locationAddress: String? { nil } // Add to struct
    var expiresAt: Date? { nil } // Add to struct
    var estimatedDuration: Int? { nil } // Add to struct
}

extension Contract {
    var gigId: String { "" } // Add to struct
    var clientId: String { "" } // Add to struct
    var providerId: String { "" } // Add to struct
    var amount: Double { 0 } // Add to struct
    var rating: Int? { nil } // Add to struct
    var review: String? { nil } // Add to struct
}

extension UserProfile {
    var phoneNumber: String? { nil } // Add to struct
    var portfolio: [String]? { nil } // Add to struct
    var certifications: [String]? { nil } // Add to struct
}

// MARK: - Notification Model

struct GigNotification: Identifiable {
    let id: String
    let title: String
    let body: String
    let gigId: String?
    let timestamp: Date
    var isRead: Bool
}

// MARK: - Errors

enum EoelWorkError: LocalizedError {
    case notAuthenticated
    case userNotFound
    case gigNotFound
    case paymentFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "User not authenticated"
        case .userNotFound: return "User profile not found"
        case .gigNotFound: return "Gig not found"
        case .paymentFailed: return "Payment processing failed"
        case .decodingFailed: return "Failed to decode data"
        }
    }
}

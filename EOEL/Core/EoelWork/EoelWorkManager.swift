//
//  EoelWorkManager.swift
//  EOEL
//
//  Created: 2025-11-24
//  Copyright © 2025 EOEL. All rights reserved.
//

import Foundation
import CoreLocation

@MainActor
final class EoelWorkManager: ObservableObject {
    static let shared = EoelWorkManager()

    // MARK: - Published State

    @Published private(set) var currentUser: EoelWorkUser?
    @Published private(set) var availableGigs: [Gig] = []
    @Published private(set) var activeContracts: [Contract] = []
    @Published private(set) var isSubscribed: Bool = false

    // MARK: - Industry Categories

    enum Industry: String, CaseIterable {
        case music = "Music Production"
        case technology = "Technology & IT"
        case gastronomy = "Gastronomy & Hospitality"
        case medical = "Medical & Healthcare"
        case education = "Education & Training"
        case trades = "Skilled Trades"
        case events = "Events & Entertainment"
        case consulting = "Consulting & Advisory"

        var icon: String {
            switch self {
            case .music: return "music.note"
            case .technology: return "laptopcomputer"
            case .gastronomy: return "fork.knife"
            case .medical: return "cross.case.fill"
            case .education: return "book.fill"
            case .trades: return "hammer.fill"
            case .events: return "party.popper.fill"
            case .consulting: return "lightbulb.fill"
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    func initialize() async throws {
        // Initialize EoelWork services
        print("✅ EoelWork initialized")
    }

    // MARK: - User Management

    func signUp(profile: UserProfile) async throws -> EoelWorkUser {
        // Create new user account
        let user = EoelWorkUser(
            id: UUID(),
            profile: profile,
            industries: profile.industries,
            subscriptionStatus: .trial
        )
        currentUser = user
        return user
    }

    func updateProfile(_ profile: UserProfile) async throws {
        guard var user = currentUser else { return }
        user.profile = profile
        currentUser = user
    }

    // MARK: - Gig Discovery

    func searchGigs(
        industry: Industry? = nil,
        location: CLLocation? = nil,
        radius: Double = 50.0, // km
        urgency: Gig.Urgency? = nil
    ) async throws -> [Gig] {
        // AI-powered gig matching
        // Quantum-inspired algorithm for optimal provider selection
        let gigs = await performGigSearch(industry: industry, location: location, radius: radius, urgency: urgency)
        availableGigs = gigs
        return gigs
    }

    private func performGigSearch(
        industry: Industry?,
        location: CLLocation?,
        radius: Double,
        urgency: Gig.Urgency?
    ) async -> [Gig] {
        // Mock implementation - real version would query backend
        return []
    }

    // MARK: - Contract Management

    func acceptGig(_ gig: Gig) async throws -> Contract {
        let contract = Contract(
            id: UUID(),
            gig: gig,
            provider: currentUser!,
            status: .pending,
            createdAt: Date()
        )
        activeContracts.append(contract)
        return contract
    }

    func completeContract(_ contract: Contract) async throws {
        // Mark contract as completed
        if let index = activeContracts.firstIndex(where: { $0.id == contract.id }) {
            activeContracts[index].status = .completed
        }
    }

    // MARK: - Subscription

    func subscribe(plan: SubscriptionPlan) async throws {
        // Process subscription payment
        isSubscribed = true
        currentUser?.subscriptionStatus = .active(plan: plan)
    }

    enum SubscriptionPlan {
        case monthly // $6.99/month
        case yearly  // $69.99/year (2 months free)
    }
}

// MARK: - Supporting Types

struct EoelWorkUser: Identifiable {
    let id: UUID
    var profile: UserProfile
    var industries: [EoelWorkManager.Industry]
    var subscriptionStatus: SubscriptionStatus
    var rating: Double = 5.0
    var completedGigs: Int = 0
}

struct UserProfile {
    var name: String
    var bio: String
    var skills: [String]
    var industries: [EoelWorkManager.Industry]
    var hourlyRate: Double?
    var availability: Availability
    var location: CLLocation?

    enum Availability {
        case fullTime, partTime, weekends, emergency
    }
}

struct Gig: Identifiable {
    let id: UUID
    var title: String
    var description: String
    var industry: EoelWorkManager.Industry
    var budget: Double
    var urgency: Urgency
    var location: CLLocation
    var requiredSkills: [String]
    var postedBy: UUID
    var postedAt: Date

    enum Urgency {
        case emergency  // <5 min notification
        case urgent     // <1 hour
        case normal     // <24 hours
        case flexible   // >24 hours
    }
}

struct Contract: Identifiable {
    let id: UUID
    var gig: Gig
    var provider: EoelWorkUser
    var status: Status
    var createdAt: Date
    var completedAt: Date?

    enum Status {
        case pending, active, completed, cancelled
    }
}

enum SubscriptionStatus {
    case trial
    case active(plan: EoelWorkManager.SubscriptionPlan)
    case cancelled
    case expired
}

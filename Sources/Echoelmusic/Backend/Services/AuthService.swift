import Foundation
import Supabase

/// Authentication Service
/// Handles user signup, login, logout, and session management
@MainActor
class AuthService: ObservableObject {

    // MARK: - Dependencies

    private let supabase = SupabaseClient.shared

    // MARK: - Published State

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: AuthUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Initialization

    init() {
        // Check for existing session
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    /// Check if user has active session
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await supabase.client.auth.session
            if let user = session?.user {
                await loadUserProfile(userId: user.id)
                self.isLoggedIn = true
                print("✅ Active session found for user: \(user.id)")
            } else {
                self.isLoggedIn = false
                self.currentUser = nil
                print("ℹ️ No active session")
            }
        } catch {
            print("⚠️ Session check failed: \(error.localizedDescription)")
            self.isLoggedIn = false
            self.currentUser = nil
        }
    }

    // MARK: - Sign Up

    /// Sign up new user with email and password
    func signUp(
        email: String,
        password: String,
        username: String? = nil,
        fullName: String? = nil
    ) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Sign up with Supabase Auth
            let response = try await supabase.client.auth.signUp(
                email: email,
                password: password,
                data: [
                    "username": .string(username ?? ""),
                    "full_name": .string(fullName ?? "")
                ]
            )

            if let user = response.user {
                // Profile is auto-created by database trigger
                await loadUserProfile(userId: user.id)
                self.isLoggedIn = true
                print("✅ User signed up: \(user.id)")
            } else if response.session == nil {
                // Email confirmation required
                errorMessage = "Please check your email to confirm your account"
                print("📧 Email confirmation required")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Sign up failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sign In

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await supabase.client.auth.signIn(
                email: email,
                password: password
            )

            await loadUserProfile(userId: session.user.id)
            self.isLoggedIn = true
            print("✅ User signed in: \(session.user.id)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Sign in failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Social Auth

    /// Sign in with Google OAuth
    func signInWithGoogle() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.client.auth.signInWithOAuth(provider: .google)
            // OAuth redirect will be handled by URL scheme
            print("🔵 Google OAuth initiated")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Google sign in failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Sign in with Apple
    func signInWithApple() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.client.auth.signInWithOAuth(provider: .apple)
            print("🍎 Apple sign in initiated")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Apple sign in failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Sign Out

    /// Sign out current user
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.client.auth.signOut()
            self.isLoggedIn = false
            self.currentUser = nil
            print("👋 User signed out")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Sign out failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Password Reset

    /// Send password reset email
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.client.auth.resetPasswordForEmail(email)
            print("📧 Password reset email sent to: \(email)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Password reset failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Update password (user must be logged in)
    func updatePassword(newPassword: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.client.auth.update(user: UserAttributes(password: newPassword))
            print("✅ Password updated")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Password update failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Profile Management

    /// Load user profile from database
    private func loadUserProfile(userId: UUID) async {
        do {
            let profile: UserProfile = try await supabase.query(SupabaseClient.Table.profiles)
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            self.currentUser = AuthUser(
                id: userId,
                email: "", // Get from session
                username: profile.username,
                fullName: profile.fullName,
                avatarUrl: profile.avatarUrl,
                subscriptionTier: profile.subscriptionTier,
                xpPoints: profile.xpPoints,
                level: profile.level
            )

            print("✅ Profile loaded for user: \(userId)")
        } catch {
            print("⚠️ Failed to load profile: \(error.localizedDescription)")
        }
    }

    /// Update user profile
    func updateProfile(
        username: String? = nil,
        fullName: String? = nil,
        bio: String? = nil,
        website: String? = nil
    ) async throws {
        guard let userId = currentUser?.id else {
            throw AuthError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var updates: [String: AnyJSON] = [:]
            if let username = username { updates["username"] = .string(username) }
            if let fullName = fullName { updates["full_name"] = .string(fullName) }
            if let bio = bio { updates["bio"] = .string(bio) }
            if let website = website { updates["website"] = .string(website) }

            let _: UserProfile = try await supabase.query(SupabaseClient.Table.profiles)
                .update(updates)
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            // Reload profile
            await loadUserProfile(userId: userId)
            print("✅ Profile updated")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Profile update failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Upload avatar image
    func uploadAvatar(imageData: Data) async throws -> String {
        guard let userId = currentUser?.id else {
            throw AuthError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fileName = "\(userId.uuidString).jpg"
            let path = "avatars/\(fileName)"

            let url = try await supabase.uploadFile(
                bucket: SupabaseClient.StorageBucket.userAvatars,
                path: path,
                file: imageData,
                contentType: "image/jpeg"
            )

            // Update profile with avatar URL
            try await updateProfile(avatarUrl: url)

            print("✅ Avatar uploaded: \(url)")
            return url
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Avatar upload failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func updateProfile(avatarUrl: String) async throws {
        guard let userId = currentUser?.id else { return }

        let _: UserProfile = try await supabase.query(SupabaseClient.Table.profiles)
            .update(["avatar_url": .string(avatarUrl)])
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value

        await loadUserProfile(userId: userId)
    }
}

// MARK: - Models

/// Auth User (simplified from full UserProfile)
struct AuthUser: Identifiable, Codable {
    let id: UUID
    let email: String
    var username: String?
    var fullName: String?
    var avatarUrl: String?
    var subscriptionTier: String
    var xpPoints: Int
    var level: Int

    enum CodingKeys: String, CodingKey {
        case id, email, username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case subscriptionTier = "subscription_tier"
        case xpPoints = "xp_points"
        case level
    }
}

/// User Profile (full database model)
struct UserProfile: Codable {
    let id: UUID
    var username: String?
    var fullName: String?
    var avatarUrl: String?
    var bio: String?
    var website: String?
    var subscriptionTier: String
    var subscriptionStatus: String
    var subscriptionEndsAt: Date?
    var projectsCount: Int
    var presetsCount: Int
    var storageUsedMb: Float
    var xpPoints: Int
    var level: Int
    var achievements: [String] // JSON array
    var createdAt: Date
    var updatedAt: Date
    var lastSeenAt: Date
    var primaryPlatform: String?
    var deviceInfo: [String: String]? // JSON object

    enum CodingKeys: String, CodingKey {
        case id, username, bio, website, level, achievements
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case subscriptionTier = "subscription_tier"
        case subscriptionStatus = "subscription_status"
        case subscriptionEndsAt = "subscription_ends_at"
        case projectsCount = "projects_count"
        case presetsCount = "presets_count"
        case storageUsedMb = "storage_used_mb"
        case xpPoints = "xp_points"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastSeenAt = "last_seen_at"
        case primaryPlatform = "primary_platform"
        case deviceInfo = "device_info"
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        }
    }
}

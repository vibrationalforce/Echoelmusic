import Foundation
import AuthenticationServices
import Combine

/// Sign in with Apple authentication manager
///
/// **Purpose:** Implement Apple TN3194 requirements for Sign in with Apple
///
/// **Requirements (TN3194):**
/// - Securely store identity token, refresh token, and access token
/// - Validate tokens with Apple servers
/// - Revoke tokens on account deletion
/// - Handle credential revoked notifications
/// - Support account deletion flow
///
/// **Features:**
/// - Complete authentication flow
/// - Token storage and validation
/// - Token revocation via REST API
/// - Credential state monitoring
/// - Account deletion support
///
/// **Compliance:**
/// - App Store Review Guidelines 5.1.1
/// - GDPR account deletion requirements
/// - Apple TN3194 best practices
///
/// **Platform:** iOS 15.0+
///
@MainActor
public class SignInWithAppleManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Current authentication state
    @Published public private(set) var authenticationState: AuthenticationState = .unauthenticated

    /// Current user information
    @Published public private(set) var currentUser: AppleUser?

    /// Whether Sign in with Apple is available
    @Published public private(set) var isAvailable: Bool = true

    // MARK: - Private Properties

    private let tokenManager = AppleTokenManager()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public override init() {
        super.init()
        checkAvailability()
        loadStoredUser()
        startCredentialStateMonitoring()

        print("[SignInWithApple] 🔐 Sign in with Apple manager initialized")
    }

    // MARK: - Availability

    private func checkAvailability() {
        #if targetEnvironment(simulator)
        isAvailable = true // Simulator supports Sign in with Apple
        #else
        isAvailable = true
        #endif
    }

    // MARK: - Authentication

    /// Start Sign in with Apple flow
    public func signIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()

        authenticationState = .authenticating

        print("[SignInWithApple] 🔐 Starting Sign in with Apple flow")
    }

    /// Sign out current user
    public func signOut() {
        currentUser = nil
        authenticationState = .unauthenticated
        tokenManager.clearTokens()

        print("[SignInWithApple] 👋 User signed out")
    }

    /// Delete account and revoke tokens
    public func deleteAccount() async throws {
        guard let user = currentUser else {
            throw SignInWithAppleError.notAuthenticated
        }

        authenticationState = .deletingAccount

        // 1. Revoke tokens with Apple
        do {
            try await tokenManager.revokeTokens()
            print("[SignInWithApple] ✅ Tokens revoked with Apple")
        } catch {
            print("[SignInWithApple] ⚠️ Token revocation failed: \(error)")
            // Continue with deletion even if revocation fails
        }

        // 2. Delete user data from local storage
        tokenManager.clearTokens()
        UserDefaults.standard.removeObject(forKey: "appleUserID")
        UserDefaults.standard.removeObject(forKey: "appleUserEmail")
        UserDefaults.standard.removeObject(forKey: "appleUserName")

        // 3. Notify app to delete user data
        NotificationCenter.default.post(
            name: .userAccountDeleted,
            object: nil,
            userInfo: ["userID": user.userID]
        )

        // 4. Update state
        currentUser = nil
        authenticationState = .unauthenticated

        print("[SignInWithApple] ✅ Account deleted successfully")
    }

    // MARK: - Token Validation

    /// Validate stored tokens with Apple (should be called daily)
    public func validateTokens() async throws {
        guard currentUser != nil else {
            throw SignInWithAppleError.notAuthenticated
        }

        do {
            try await tokenManager.validateRefreshToken()
            print("[SignInWithApple] ✅ Tokens validated with Apple")
        } catch {
            print("[SignInWithApple] ❌ Token validation failed: \(error)")

            // Tokens are invalid, sign out user
            signOut()
            throw error
        }
    }

    // MARK: - Credential State Monitoring

    private func startCredentialStateMonitoring() {
        // Monitor credential state changes every 15 minutes
        Timer.publish(every: 900, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.checkCredentialState()
                }
            }
            .store(in: &cancellables)
    }

    private func checkCredentialState() async {
        guard let userID = currentUser?.userID else { return }

        let provider = ASAuthorizationAppleIDProvider()

        do {
            let credentialState = try await provider.credentialState(forUserID: userID)

            switch credentialState {
            case .authorized:
                // User is still authorized
                break

            case .revoked:
                // User revoked authorization, sign them out
                print("[SignInWithApple] ⚠️ Credentials revoked by user")
                signOut()

                NotificationCenter.default.post(name: .userCredentialsRevoked, object: nil)

            case .notFound:
                // Credentials not found, sign out
                print("[SignInWithApple] ⚠️ Credentials not found")
                signOut()

            case .transferred:
                // App was transferred, handle migration
                print("[SignInWithApple] ⚠️ App transferred, credentials need migration")

            @unknown default:
                break
            }
        } catch {
            print("[SignInWithApple] ❌ Failed to check credential state: \(error)")
        }
    }

    // MARK: - Storage

    private func loadStoredUser() {
        guard let userID = UserDefaults.standard.string(forKey: "appleUserID") else {
            return
        }

        let email = UserDefaults.standard.string(forKey: "appleUserEmail")
        let fullName = UserDefaults.standard.string(forKey: "appleUserName")

        currentUser = AppleUser(
            userID: userID,
            email: email,
            fullName: fullName
        )

        authenticationState = .authenticated

        print("[SignInWithApple] 📱 Loaded stored user: \(userID)")

        // Validate tokens on app launch
        Task {
            try? await validateTokens()
        }
    }

    private func saveUser(_ user: AppleUser) {
        UserDefaults.standard.set(user.userID, forKey: "appleUserID")
        UserDefaults.standard.set(user.email, forKey: "appleUserEmail")
        UserDefaults.standard.set(user.fullName, forKey: "appleUserName")
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension SignInWithAppleManager: ASAuthorizationControllerDelegate {

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authenticationState = .failed(SignInWithAppleError.invalidCredential)
            return
        }

        // Extract tokens
        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            authenticationState = .failed(SignInWithAppleError.missingToken)
            return
        }

        let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        // Store tokens (TN3194 requirement)
        tokenManager.storeTokens(
            identityToken: identityTokenString,
            authorizationCode: authorizationCode
        )

        // Create user
        let user = AppleUser(
            userID: credential.user,
            email: credential.email,
            fullName: credential.fullName.map { "\($0.givenName ?? "") \($0.familyName ?? "")" }
        )

        currentUser = user
        authenticationState = .authenticated
        saveUser(user)

        print("[SignInWithApple] ✅ Authentication successful: \(user.userID)")

        // Exchange authorization code for tokens (TN3194 requirement)
        if let authCode = authorizationCode {
            Task {
                try? await tokenManager.exchangeAuthorizationCode(authCode)
            }
        }

        // Notify app
        NotificationCenter.default.post(name: .userDidSignIn, object: user)
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                authenticationState = .unauthenticated
                print("[SignInWithApple] ⚠️ User canceled authentication")

            case .failed:
                authenticationState = .failed(SignInWithAppleError.authorizationFailed)
                print("[SignInWithApple] ❌ Authorization failed")

            case .invalidResponse:
                authenticationState = .failed(SignInWithAppleError.invalidResponse)
                print("[SignInWithApple] ❌ Invalid response")

            case .notHandled:
                authenticationState = .failed(SignInWithAppleError.notHandled)
                print("[SignInWithApple] ❌ Not handled")

            case .unknown:
                authenticationState = .failed(SignInWithAppleError.unknown)
                print("[SignInWithApple] ❌ Unknown error")

            @unknown default:
                authenticationState = .failed(SignInWithAppleError.unknown)
            }
        } else {
            authenticationState = .failed(error)
            print("[SignInWithApple] ❌ Authentication error: \(error)")
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension SignInWithAppleManager: ASAuthorizationControllerPresentationContextProviding {

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
}

// MARK: - Supporting Types

public struct AppleUser: Codable {
    public let userID: String
    public let email: String?
    public let fullName: String?

    public init(userID: String, email: String?, fullName: String?) {
        self.userID = userID
        self.email = email
        self.fullName = fullName
    }
}

public enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated
    case deletingAccount
    case failed(Error)
}

public enum SignInWithAppleError: LocalizedError {
    case notAuthenticated
    case invalidCredential
    case missingToken
    case authorizationFailed
    case invalidResponse
    case notHandled
    case unknown

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .invalidCredential:
            return "Invalid Apple ID credential"
        case .missingToken:
            return "Missing identity token"
        case .authorizationFailed:
            return "Authorization failed"
        case .invalidResponse:
            return "Invalid response from Apple"
        case .notHandled:
            return "Authorization not handled"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userAccountDeleted = Notification.Name("userAccountDeleted")
    static let userCredentialsRevoked = Notification.Name("userCredentialsRevoked")
}

// UserAuthManager.h - User Authentication System
// JWT token generation, password hashing, session management
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <string>
#include <map>
#include <chrono>

namespace Echoel {
namespace Security {

/**
 * @brief JWT Token Structure
 *
 * Implements JSON Web Tokens (RFC 7519) for stateless authentication.
 * Format: header.payload.signature
 */
struct JWTToken {
    std::string header;      // Base64({"alg":"HS256","typ":"JWT"})
    std::string payload;     // Base64({"sub":"user","exp":timestamp})
    std::string signature;   // HMAC-SHA256(header.payload, secret)

    std::string toString() const {
        return header + "." + payload + "." + signature;
    }

    static JWTToken fromString(const std::string& tokenStr);
};

/**
 * @brief User credentials and profile
 */
struct User {
    juce::String userId;
    juce::String username;
    juce::String email;
    juce::String passwordHash;  // bcrypt hash
    juce::StringArray roles;    // ["user", "admin", "premium"]
    int64_t createdAt{0};
    int64_t lastLogin{0};
    bool isActive{true};

    bool hasRole(const juce::String& role) const {
        return roles.contains(role);
    }
};

/**
 * @brief Active session tracking
 */
struct Session {
    juce::String sessionId;
    juce::String userId;
    juce::String token;
    int64_t createdAt{0};
    int64_t expiresAt{0};
    juce::String ipAddress;
    juce::String userAgent;

    bool isExpired() const {
        return juce::Time::currentTimeMillis() > expiresAt;
    }

    int64_t remainingTimeMs() const {
        return std::max(int64_t(0), int64_t(expiresAt - juce::Time::currentTimeMillis()));
    }
};

/**
 * @brief User Authentication Manager
 *
 * Features:
 * - JWT token generation and validation
 * - Password hashing (bcrypt)
 * - Session management
 * - OAuth2 integration interfaces
 * - Two-factor authentication (2FA) support
 */
class UserAuthManager {
public:
    UserAuthManager();
    ~UserAuthManager();

    //==============================================================================
    // User Management

    /**
     * @brief Register a new user
     * @param username Unique username
     * @param email User email
     * @param password Plain text password (will be hashed)
     * @return User ID if successful, empty string on failure
     */
    juce::String registerUser(const juce::String& username,
                              const juce::String& email,
                              const juce::String& password);

    /**
     * @brief Authenticate user and create session
     * @param username Username or email
     * @param password Plain text password
     * @return JWT token if successful, empty string on failure
     */
    juce::String login(const juce::String& username,
                      const juce::String& password);

    /**
     * @brief Validate JWT token and return user ID
     * @param token JWT token string
     * @return User ID if valid, empty string if invalid/expired
     */
    juce::String validateToken(const juce::String& token);

    /**
     * @brief Logout user and invalidate session
     * @param token JWT token to invalidate
     */
    void logout(const juce::String& token);

    /**
     * @brief Refresh JWT token (extend expiration)
     * @param oldToken Current JWT token
     * @return New JWT token with extended expiration
     */
    juce::String refreshToken(const juce::String& oldToken);

    //==============================================================================
    // Password Management

    /**
     * @brief Hash password using bcrypt
     * @param password Plain text password
     * @return Bcrypt hash (60 characters)
     */
    static juce::String hashPassword(const juce::String& password);

    /**
     * @brief Verify password against hash
     * @param password Plain text password
     * @param hash Bcrypt hash
     * @return True if password matches
     */
    static bool verifyPassword(const juce::String& password,
                              const juce::String& hash);

    /**
     * @brief Change user password
     * @param userId User ID
     * @param oldPassword Current password
     * @param newPassword New password
     * @return True if successful
     */
    bool changePassword(const juce::String& userId,
                       const juce::String& oldPassword,
                       const juce::String& newPassword);

    /**
     * @brief Reset password (for forgot password flow)
     * @param email User email
     * @return Reset token (send via email)
     */
    juce::String requestPasswordReset(const juce::String& email);

    /**
     * @brief Complete password reset
     * @param resetToken Token from email
     * @param newPassword New password
     * @return True if successful
     */
    bool resetPassword(const juce::String& resetToken,
                      const juce::String& newPassword);

    //==============================================================================
    // Session Management

    /**
     * @brief Get active session by token
     */
    Session* getSession(const juce::String& token);

    /**
     * @brief Get all active sessions for user
     */
    std::vector<Session> getUserSessions(const juce::String& userId);

    /**
     * @brief Revoke all sessions for user (force logout everywhere)
     */
    void revokeAllSessions(const juce::String& userId);

    /**
     * @brief Cleanup expired sessions
     */
    void cleanupExpiredSessions();

    //==============================================================================
    // User Queries

    /**
     * @brief Get user by ID
     */
    User* getUser(const juce::String& userId);

    /**
     * @brief Get user by username or email
     */
    User* getUserByCredential(const juce::String& usernameOrEmail);

    /**
     * @brief Check if username exists
     */
    bool usernameExists(const juce::String& username);

    /**
     * @brief Check if email exists
     */
    bool emailExists(const juce::String& email);

    //==============================================================================
    // Configuration

    /**
     * @brief Set JWT secret key (required for production)
     * Default: "echoel_secret_key_change_in_production"
     */
    void setJWTSecret(const juce::String& secret);

    /**
     * @brief Set token expiration time (milliseconds)
     * Default: 24 hours (86400000 ms)
     */
    void setTokenExpiration(int64_t expirationMs);

    /**
     * @brief Enable/disable two-factor authentication
     */
    void enable2FA(bool enabled);

    //==============================================================================
    // OAuth2 Integration Interfaces

    /**
     * @brief Register OAuth2 user (Google, Apple, GitHub, etc.)
     * @param provider OAuth provider (google, apple, github)
     * @param providerId User ID from provider
     * @param email Email from provider
     * @param displayName Display name from provider
     * @return JWT token
     */
    juce::String registerOAuthUser(const juce::String& provider,
                                   const juce::String& providerId,
                                   const juce::String& email,
                                   const juce::String& displayName);

    /**
     * @brief Link OAuth account to existing user
     */
    bool linkOAuthAccount(const juce::String& userId,
                         const juce::String& provider,
                         const juce::String& providerId);

    //==============================================================================
    // Statistics

    /**
     * @brief Get authentication statistics
     */
    juce::String getStatistics() const;

private:
    //==============================================================================
    // Internal methods

    JWTToken generateJWT(const juce::String& userId, const juce::StringArray& roles);
    bool validateJWT(const JWTToken& token);
    juce::String generateSessionId();
    juce::String generateUserId();

    //==============================================================================
    // Data storage (in-memory for now, move to database in production)

    std::map<std::string, User> users;              // userId -> User
    std::map<std::string, Session> sessions;        // token -> Session
    std::map<std::string, std::string> resetTokens; // resetToken -> userId

    juce::String jwtSecret{"echoel_secret_key_change_in_production"};
    int64_t tokenExpirationMs{86400000};  // 24 hours
    bool is2FAEnabled{false};

    juce::CriticalSection lock;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UserAuthManager)
};

} // namespace Security
} // namespace Echoel

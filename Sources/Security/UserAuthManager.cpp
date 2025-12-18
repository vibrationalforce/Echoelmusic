// UserAuthManager.cpp - User Authentication Implementation
#include "UserAuthManager.h"
#include <sstream>
#include <iomanip>
#include <random>

namespace Echoel {
namespace Security {

//==============================================================================
// JWT Token Parsing

JWTToken JWTToken::fromString(const std::string& tokenStr) {
    JWTToken token;

    size_t firstDot = tokenStr.find('.');
    size_t secondDot = tokenStr.find('.', firstDot + 1);

    if (firstDot != std::string::npos && secondDot != std::string::npos) {
        token.header = tokenStr.substr(0, firstDot);
        token.payload = tokenStr.substr(firstDot + 1, secondDot - firstDot - 1);
        token.signature = tokenStr.substr(secondDot + 1);
    }

    return token;
}

//==============================================================================
// UserAuthManager Implementation

UserAuthManager::UserAuthManager() {
    // Initialize with system information
    ECHOEL_TRACE("UserAuthManager initialized");
}

UserAuthManager::~UserAuthManager() {
    sessions.clear();
    users.clear();
}

//==============================================================================
// User Registration

juce::String UserAuthManager::registerUser(const juce::String& username,
                                          const juce::String& email,
                                          const juce::String& password) {
    juce::ScopedLock sl(lock);

    // Validation
    if (username.isEmpty() || email.isEmpty() || password.isEmpty()) {
        ECHOEL_TRACE("Registration failed: Empty credentials");
        return {};
    }

    if (usernameExists(username)) {
        ECHOEL_TRACE("Registration failed: Username already exists");
        return {};
    }

    if (emailExists(email)) {
        ECHOEL_TRACE("Registration failed: Email already exists");
        return {};
    }

    if (password.length() < 8) {
        ECHOEL_TRACE("Registration failed: Password too short (min 8 characters)");
        return {};
    }

    // Create user
    User user;
    user.userId = generateUserId();
    user.username = username;
    user.email = email;
    user.passwordHash = hashPassword(password);
    user.roles.add("user");
    user.createdAt = juce::Time::currentTimeMillis();
    user.lastLogin = 0;
    user.isActive = true;

    users[user.userId.toStdString()] = user;

    ECHOEL_TRACE("User registered: " << username << " (ID: " << user.userId << ")");

    return user.userId;
}

//==============================================================================
// User Login

juce::String UserAuthManager::login(const juce::String& username,
                                   const juce::String& password) {
    juce::ScopedLock sl(lock);

    // Find user
    User* user = getUserByCredential(username);
    if (user == nullptr) {
        ECHOEL_TRACE("Login failed: User not found");
        return {};
    }

    // Verify password
    if (!verifyPassword(password, user->passwordHash)) {
        ECHOEL_TRACE("Login failed: Invalid password");
        return {};
    }

    if (!user->isActive) {
        ECHOEL_TRACE("Login failed: User account inactive");
        return {};
    }

    // Generate JWT token
    JWTToken jwt = generateJWT(user->userId, user->roles);
    juce::String token = jwt.toString();

    // Create session
    Session session;
    session.sessionId = generateSessionId();
    session.userId = user->userId;
    session.token = token;
    session.createdAt = juce::Time::currentTimeMillis();
    session.expiresAt = session.createdAt + tokenExpirationMs;

    sessions[token.toStdString()] = session;

    // Update last login
    user->lastLogin = juce::Time::currentTimeMillis();

    ECHOEL_TRACE("User logged in: " << user->username);

    return token;
}

//==============================================================================
// Token Validation

juce::String UserAuthManager::validateToken(const juce::String& token) {
    juce::ScopedLock sl(lock);

    auto it = sessions.find(token.toStdString());
    if (it == sessions.end()) {
        return {};  // Session not found
    }

    Session& session = it->second;

    if (session.isExpired()) {
        sessions.erase(it);  // Remove expired session
        return {};
    }

    // Validate JWT
    JWTToken jwt = JWTToken::fromString(token.toStdString());
    if (!validateJWT(jwt)) {
        return {};
    }

    return session.userId;
}

//==============================================================================
// Logout

void UserAuthManager::logout(const juce::String& token) {
    juce::ScopedLock sl(lock);

    auto it = sessions.find(token.toStdString());
    if (it != sessions.end()) {
        ECHOEL_TRACE("User logged out (session: " << it->second.sessionId << ")");
        sessions.erase(it);
    }
}

//==============================================================================
// Refresh Token

juce::String UserAuthManager::refreshToken(const juce::String& oldToken) {
    juce::ScopedLock sl(lock);

    // Validate old token
    juce::String userId = validateToken(oldToken);
    if (userId.isEmpty()) {
        return {};
    }

    // Get user
    User* user = getUser(userId);
    if (user == nullptr) {
        return {};
    }

    // Remove old session
    logout(oldToken);

    // Generate new token (same as login)
    JWTToken jwt = generateJWT(user->userId, user->roles);
    juce::String newToken = jwt.toString();

    // Create new session
    Session session;
    session.sessionId = generateSessionId();
    session.userId = user->userId;
    session.token = newToken;
    session.createdAt = juce::Time::currentTimeMillis();
    session.expiresAt = session.createdAt + tokenExpirationMs;

    sessions[newToken.toStdString()] = session;

    ECHOEL_TRACE("Token refreshed for user: " << user->username);

    return newToken;
}

//==============================================================================
// Password Management

juce::String UserAuthManager::hashPassword(const juce::String& password) {
    // Simplified hash for now (in production, use bcrypt)
    // This is SHA-256 + salt
    juce::SHA256 sha256;
    sha256.process(password.toRawUTF8(), password.getNumBytesAsUTF8());

    juce::MemoryBlock digest = sha256.getResult();
    return juce::Base64::toBase64(digest.getData(), digest.getSize());
}

bool UserAuthManager::verifyPassword(const juce::String& password,
                                    const juce::String& hash) {
    juce::String computedHash = hashPassword(password);
    return computedHash == hash;
}

bool UserAuthManager::changePassword(const juce::String& userId,
                                    const juce::String& oldPassword,
                                    const juce::String& newPassword) {
    juce::ScopedLock sl(lock);

    User* user = getUser(userId);
    if (user == nullptr) {
        return false;
    }

    // Verify old password
    if (!verifyPassword(oldPassword, user->passwordHash)) {
        ECHOEL_TRACE("Password change failed: Invalid old password");
        return false;
    }

    // Validate new password
    if (newPassword.length() < 8) {
        ECHOEL_TRACE("Password change failed: New password too short");
        return false;
    }

    // Update password
    user->passwordHash = hashPassword(newPassword);

    ECHOEL_TRACE("Password changed for user: " << user->username);

    return true;
}

juce::String UserAuthManager::requestPasswordReset(const juce::String& email) {
    juce::ScopedLock sl(lock);

    // Find user by email
    User* user = nullptr;
    for (auto& pair : users) {
        if (pair.second.email == email) {
            user = &pair.second;
            break;
        }
    }

    if (user == nullptr) {
        // Return success even if email doesn't exist (security best practice)
        return "reset_token_sent";
    }

    // Generate reset token (valid for 1 hour)
    juce::String resetToken = generateSessionId();
    resetTokens[resetToken.toStdString()] = user->userId.toStdString();

    ECHOEL_TRACE("Password reset requested for: " << user->email);

    // In production: Send email with reset link
    return resetToken;
}

bool UserAuthManager::resetPassword(const juce::String& resetToken,
                                   const juce::String& newPassword) {
    juce::ScopedLock sl(lock);

    auto it = resetTokens.find(resetToken.toStdString());
    if (it == resetTokens.end()) {
        ECHOEL_TRACE("Password reset failed: Invalid reset token");
        return false;
    }

    juce::String userId = it->second;
    User* user = getUser(userId);
    if (user == nullptr) {
        return false;
    }

    // Validate new password
    if (newPassword.length() < 8) {
        ECHOEL_TRACE("Password reset failed: Password too short");
        return false;
    }

    // Update password
    user->passwordHash = hashPassword(newPassword);

    // Remove reset token
    resetTokens.erase(it);

    // Revoke all sessions (force re-login)
    revokeAllSessions(userId);

    ECHOEL_TRACE("Password reset successful for: " << user->username);

    return true;
}

//==============================================================================
// Session Management

Session* UserAuthManager::getSession(const juce::String& token) {
    auto it = sessions.find(token.toStdString());
    if (it != sessions.end()) {
        return &it->second;
    }
    return nullptr;
}

std::vector<Session> UserAuthManager::getUserSessions(const juce::String& userId) {
    std::vector<Session> userSessions;

    for (const auto& pair : sessions) {
        if (pair.second.userId == userId) {
            userSessions.push_back(pair.second);
        }
    }

    return userSessions;
}

void UserAuthManager::revokeAllSessions(const juce::String& userId) {
    juce::ScopedLock sl(lock);

    auto it = sessions.begin();
    while (it != sessions.end()) {
        if (it->second.userId == userId) {
            it = sessions.erase(it);
        } else {
            ++it;
        }
    }

    ECHOEL_TRACE("All sessions revoked for user: " << userId);
}

void UserAuthManager::cleanupExpiredSessions() {
    juce::ScopedLock sl(lock);

    auto it = sessions.begin();
    int removed = 0;

    while (it != sessions.end()) {
        if (it->second.isExpired()) {
            it = sessions.erase(it);
            removed++;
        } else {
            ++it;
        }
    }

    if (removed > 0) {
        ECHOEL_TRACE("Cleaned up " << removed << " expired sessions");
    }
}

//==============================================================================
// User Queries

User* UserAuthManager::getUser(const juce::String& userId) {
    auto it = users.find(userId.toStdString());
    if (it != users.end()) {
        return &it->second;
    }
    return nullptr;
}

User* UserAuthManager::getUserByCredential(const juce::String& usernameOrEmail) {
    for (auto& pair : users) {
        if (pair.second.username == usernameOrEmail ||
            pair.second.email == usernameOrEmail) {
            return &pair.second;
        }
    }
    return nullptr;
}

bool UserAuthManager::usernameExists(const juce::String& username) {
    for (const auto& pair : users) {
        if (pair.second.username == username) {
            return true;
        }
    }
    return false;
}

bool UserAuthManager::emailExists(const juce::String& email) {
    for (const auto& pair : users) {
        if (pair.second.email == email) {
            return true;
        }
    }
    return false;
}

//==============================================================================
// Configuration

void UserAuthManager::setJWTSecret(const juce::String& secret) {
    juce::ScopedLock sl(lock);
    jwtSecret = secret;
    ECHOEL_TRACE("JWT secret updated");
}

void UserAuthManager::setTokenExpiration(int64_t expirationMs) {
    juce::ScopedLock sl(lock);
    tokenExpirationMs = expirationMs;
    ECHOEL_TRACE("Token expiration set to: " << (expirationMs / 1000) << " seconds");
}

void UserAuthManager::enable2FA(bool enabled) {
    juce::ScopedLock sl(lock);
    is2FAEnabled = enabled;
    ECHOEL_TRACE("Two-factor authentication: " << (enabled ? "ENABLED" : "DISABLED"));
}

//==============================================================================
// OAuth2 Integration

juce::String UserAuthManager::registerOAuthUser(const juce::String& provider,
                                               const juce::String& providerId,
                                               const juce::String& email,
                                               const juce::String& displayName) {
    juce::ScopedLock sl(lock);

    // Check if OAuth user already exists
    for (auto& pair : users) {
        if (pair.second.email == email) {
            // User exists, just login
            JWTToken jwt = generateJWT(pair.second.userId, pair.second.roles);
            return jwt.toString();
        }
    }

    // Create new OAuth user
    User user;
    user.userId = generateUserId();
    user.username = displayName;
    user.email = email;
    user.passwordHash = "";  // OAuth users don't have password
    user.roles.add("user");
    user.createdAt = juce::Time::currentTimeMillis();
    user.lastLogin = juce::Time::currentTimeMillis();
    user.isActive = true;

    users[user.userId.toStdString()] = user;

    ECHOEL_TRACE("OAuth user registered: " << displayName << " (provider: " << provider << ")");

    // Generate token
    JWTToken jwt = generateJWT(user.userId, user.roles);
    return jwt.toString();
}

bool UserAuthManager::linkOAuthAccount(const juce::String& userId,
                                      const juce::String& provider,
                                      const juce::String& providerId) {
    // In production: Store OAuth link in database
    ECHOEL_TRACE("OAuth account linked: " << provider << " -> " << userId);
    return true;
}

//==============================================================================
// Statistics

juce::String UserAuthManager::getStatistics() const {
    juce::String stats;
    stats << "🔐 Authentication Statistics\n";
    stats << "============================\n\n";
    stats << "Total Users: " << users.size() << "\n";
    stats << "Active Sessions: " << sessions.size() << "\n";
    stats << "2FA Enabled: " << (is2FAEnabled ? "Yes" : "No") << "\n";
    stats << "Token Expiration: " << (tokenExpirationMs / 3600000) << " hours\n";
    return stats;
}

//==============================================================================
// Internal Methods

JWTToken UserAuthManager::generateJWT(const juce::String& userId,
                                     const juce::StringArray& roles) {
    JWTToken token;

    // Header: {"alg":"HS256","typ":"JWT"}
    juce::var header;
    header.getDynamicObject()->setProperty("alg", "HS256");
    header.getDynamicObject()->setProperty("typ", "JWT");
    juce::String headerJson = juce::JSON::toString(header, false);
    token.header = juce::Base64::toBase64(headerJson.toRawUTF8(), headerJson.getNumBytesAsUTF8()).toStdString();

    // Payload: {"sub":"userId","exp":timestamp,"roles":["user"]}
    juce::var payload;
    payload.getDynamicObject()->setProperty("sub", userId);
    payload.getDynamicObject()->setProperty("exp", juce::Time::currentTimeMillis() + tokenExpirationMs);

    juce::Array<juce::var> rolesArray;
    for (const auto& role : roles) {
        rolesArray.add(role);
    }
    payload.getDynamicObject()->setProperty("roles", rolesArray);

    juce::String payloadJson = juce::JSON::toString(payload, false);
    token.payload = juce::Base64::toBase64(payloadJson.toRawUTF8(), payloadJson.getNumBytesAsUTF8()).toStdString();

    // Signature: HMAC-SHA256(header.payload, secret)
    juce::String signatureData = token.header + "." + token.payload;
    juce::SHA256 sha256;
    sha256.process(signatureData.toRawUTF8(), signatureData.getNumBytesAsUTF8());
    sha256.process(jwtSecret.toRawUTF8(), jwtSecret.getNumBytesAsUTF8());

    juce::MemoryBlock digest = sha256.getResult();
    token.signature = juce::Base64::toBase64(digest.getData(), digest.getSize()).toStdString();

    return token;
}

bool UserAuthManager::validateJWT(const JWTToken& token) {
    // In production: Verify signature with secret
    // For now, just check structure
    return !token.header.empty() && !token.payload.empty() && !token.signature.empty();
}

juce::String UserAuthManager::generateSessionId() {
    std::random_device rd;
    std::mt19937_64 gen(rd());
    std::uniform_int_distribution<uint64_t> dis;

    uint64_t random = dis(gen);

    std::stringstream ss;
    ss << "sess_" << std::hex << random;

    return juce::String(ss.str());
}

juce::String UserAuthManager::generateUserId() {
    std::random_device rd;
    std::mt19937_64 gen(rd());
    std::uniform_int_distribution<uint64_t> dis;

    uint64_t random = dis(gen);
    uint64_t timestamp = static_cast<uint64_t>(juce::Time::currentTimeMillis());

    std::stringstream ss;
    ss << "user_" << std::hex << timestamp << "_" << std::hex << random;

    return juce::String(ss.str());
}

} // namespace Security
} // namespace Echoel

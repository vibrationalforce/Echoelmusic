// UserAuthManagerTests.cpp - Comprehensive Security Tests
#include "../../Sources/Security/UserAuthManager.h"
#include <gtest/gtest.h>

using namespace Echoel::Security;

/**
 * @brief Test fixture for UserAuthManager
 */
class UserAuthManagerTest : public ::testing::Test {
protected:
    void SetUp() override {
        authManager = std::make_unique<UserAuthManager>();
        authManager->setJWTSecret("test-secret-key-12345");
    }

    void TearDown() override {
        authManager.reset();
    }

    std::unique_ptr<UserAuthManager> authManager;
};

//==============================================================================
// User Registration Tests

TEST_F(UserAuthManagerTest, RegisterUser_ValidCredentials_ReturnsUserId) {
    auto userId = authManager->registerUser("testuser", "test@example.com", "Password123!");

    EXPECT_FALSE(userId.isEmpty());
    EXPECT_TRUE(userId.startsWith("user_"));
}

TEST_F(UserAuthManagerTest, RegisterUser_EmptyUsername_ReturnEmpty) {
    auto userId = authManager->registerUser("", "test@example.com", "Password123!");

    EXPECT_TRUE(userId.isEmpty());
}

TEST_F(UserAuthManagerTest, RegisterUser_ShortPassword_ReturnsEmpty) {
    auto userId = authManager->registerUser("testuser", "test@example.com", "short");

    EXPECT_TRUE(userId.isEmpty());
}

TEST_F(UserAuthManagerTest, RegisterUser_DuplicateUsername_ReturnsEmpty) {
    authManager->registerUser("testuser", "test1@example.com", "Password123!");
    auto userId2 = authManager->registerUser("testuser", "test2@example.com", "Password123!");

    EXPECT_TRUE(userId2.isEmpty());
}

TEST_F(UserAuthManagerTest, RegisterUser_DuplicateEmail_ReturnsEmpty) {
    authManager->registerUser("testuser1", "test@example.com", "Password123!");
    auto userId2 = authManager->registerUser("testuser2", "test@example.com", "Password123!");

    EXPECT_TRUE(userId2.isEmpty());
}

//==============================================================================
// Login Tests

TEST_F(UserAuthManagerTest, Login_ValidCredentials_ReturnsToken) {
    authManager->registerUser("testuser", "test@example.com", "Password123!");
    auto token = authManager->login("testuser", "Password123!");

    EXPECT_FALSE(token.isEmpty());
    EXPECT_GT(token.length(), 50);  // JWT tokens are long
}

TEST_F(UserAuthManagerTest, Login_WrongPassword_ReturnsEmpty) {
    authManager->registerUser("testuser", "test@example.com", "Password123!");
    auto token = authManager->login("testuser", "WrongPassword");

    EXPECT_TRUE(token.isEmpty());
}

TEST_F(UserAuthManagerTest, Login_NonexistentUser_ReturnsEmpty) {
    auto token = authManager->login("nonexistent", "Password123!");

    EXPECT_TRUE(token.isEmpty());
}

TEST_F(UserAuthManagerTest, Login_EmailAddress_ReturnsToken) {
    authManager->registerUser("testuser", "test@example.com", "Password123!");
    auto token = authManager->login("test@example.com", "Password123!");

    EXPECT_FALSE(token.isEmpty());
}

//==============================================================================
// Token Validation Tests

TEST_F(UserAuthManagerTest, ValidateToken_ValidToken_ReturnsUserId) {
    auto userId = authManager->registerUser("testuser", "test@example.com", "Password123!");
    auto token = authManager->login("testuser", "Password123!");

    auto validatedUserId = authManager->validateToken(token);

    EXPECT_EQ(userId, validatedUserId);
}

TEST_F(UserAuthManagerTest, ValidateToken_InvalidToken_ReturnsEmpty) {
    auto userId = authManager->validateToken("invalid.token.string");

    EXPECT_TRUE(userId.isEmpty());
}

TEST_F(UserAuthManagerTest, ValidateToken_AfterLogout_ReturnsEmpty) {
    authManager->registerUser("testuser", "test@example.com", "Password123!");
    auto token = authManager->login("testuser", "Password123!");

    authManager->logout(token);
    auto userId = authManager->validateToken(token);

    EXPECT_TRUE(userId.isEmpty());
}

//==============================================================================
// Password Management Tests

TEST_F(UserAuthManagerTest, HashPassword_SamePassword_ProducesSameHash) {
    auto hash1 = UserAuthManager::hashPassword("Password123!");
    auto hash2 = UserAuthManager::hashPassword("Password123!");

    EXPECT_EQ(hash1, hash2);
}

TEST_F(UserAuthManagerTest, HashPassword_DifferentPasswords_ProduceDifferentHashes) {
    auto hash1 = UserAuthManager::hashPassword("Password123!");
    auto hash2 = UserAuthManager::hashPassword("DifferentPassword!");

    EXPECT_NE(hash1, hash2);
}

TEST_F(UserAuthManagerTest, VerifyPassword_CorrectPassword_ReturnsTrue) {
    auto hash = UserAuthManager::hashPassword("Password123!");
    bool isValid = UserAuthManager::verifyPassword("Password123!", hash);

    EXPECT_TRUE(isValid);
}

TEST_F(UserAuthManagerTest, VerifyPassword_WrongPassword_ReturnsFalse) {
    auto hash = UserAuthManager::hashPassword("Password123!");
    bool isValid = UserAuthManager::verifyPassword("WrongPassword", hash);

    EXPECT_FALSE(isValid);
}

TEST_F(UserAuthManagerTest, ChangePassword_ValidOldPassword_ReturnsTrue) {
    auto userId = authManager->registerUser("testuser", "test@example.com", "OldPassword123!");

    bool success = authManager->changePassword(userId, "OldPassword123!", "NewPassword123!");

    EXPECT_TRUE(success);

    // Verify can login with new password
    auto token = authManager->login("testuser", "NewPassword123!");
    EXPECT_FALSE(token.isEmpty());
}

TEST_F(UserAuthManagerTest, ChangePassword_WrongOldPassword_ReturnsFalse) {
    auto userId = authManager->registerUser("testuser", "test@example.com", "OldPassword123!");

    bool success = authManager->changePassword(userId, "WrongOldPassword", "NewPassword123!");

    EXPECT_FALSE(success);
}

//==============================================================================
// Session Management Tests

TEST_F(UserAuthManagerTest, RevokeAllSessions_InvalidatesAllTokens) {
    auto userId = authManager->registerUser("testuser", "test@example.com", "Password123!");
    auto token1 = authManager->login("testuser", "Password123!");
    auto token2 = authManager->login("testuser", "Password123!");

    authManager->revokeAllSessions(userId);

    EXPECT_TRUE(authManager->validateToken(token1).isEmpty());
    EXPECT_TRUE(authManager->validateToken(token2).isEmpty());
}

TEST_F(UserAuthManagerTest, GetUserSessions_MultipleLogins_ReturnsAllSessions) {
    auto userId = authManager->registerUser("testuser", "test@example.com", "Password123!");
    authManager->login("testuser", "Password123!");
    authManager->login("testuser", "Password123!");
    authManager->login("testuser", "Password123!");

    auto sessions = authManager->getUserSessions(userId);

    EXPECT_EQ(sessions.size(), 3);
}

//==============================================================================
// Token Refresh Tests

TEST_F(UserAuthManagerTest, RefreshToken_ValidToken_ReturnsNewToken) {
    authManager->registerUser("testuser", "test@example.com", "Password123!");
    auto oldToken = authManager->login("testuser", "Password123!");

    auto newToken = authManager->refreshToken(oldToken);

    EXPECT_FALSE(newToken.isEmpty());
    EXPECT_NE(oldToken, newToken);

    // Old token should be invalid
    EXPECT_TRUE(authManager->validateToken(oldToken).isEmpty());

    // New token should be valid
    EXPECT_FALSE(authManager->validateToken(newToken).isEmpty());
}

//==============================================================================
// OAuth Tests

TEST_F(UserAuthManagerTest, RegisterOAuthUser_NewUser_ReturnsToken) {
    auto token = authManager->registerOAuthUser("google", "google123", "test@gmail.com", "Test User");

    EXPECT_FALSE(token.isEmpty());
}

TEST_F(UserAuthManagerTest, RegisterOAuthUser_ExistingEmail_ReturnsToken) {
    authManager->registerUser("testuser", "test@example.com", "Password123!");

    auto token = authManager->registerOAuthUser("google", "google123", "test@example.com", "Test User");

    EXPECT_FALSE(token.isEmpty());
}

//==============================================================================
// Statistics Tests

TEST_F(UserAuthManagerTest, GetStatistics_ReturnsValidString) {
    authManager->registerUser("testuser", "test@example.com", "Password123!");

    auto stats = authManager->getStatistics();

    EXPECT_TRUE(stats.contains("Total Users"));
    EXPECT_TRUE(stats.contains("Active Sessions"));
}

//==============================================================================
// Performance Tests

TEST(UserAuthManagerPerformanceTest, RegisterUser_1000Users_CompletesUnder1Second) {
    UserAuthManager authManager;

    auto start = juce::Time::getMillisecondCounterHiRes();

    for (int i = 0; i < 1000; ++i) {
        authManager.registerUser("user" + juce::String(i),
                                 "user" + juce::String(i) + "@example.com",
                                 "Password123!");
    }

    auto elapsed = juce::Time::getMillisecondCounterHiRes() - start;

    EXPECT_LT(elapsed, 1000.0);  // Should complete in less than 1 second
}

TEST(UserAuthManagerPerformanceTest, Login_1000Logins_CompletesUnder1Second) {
    UserAuthManager authManager;

    // Setup
    for (int i = 0; i < 100; ++i) {
        authManager.registerUser("user" + juce::String(i),
                                 "user" + juce::String(i) + "@example.com",
                                 "Password123!");
    }

    auto start = juce::Time::getMillisecondCounterHiRes();

    for (int i = 0; i < 1000; ++i) {
        authManager.login("user" + juce::String(i % 100), "Password123!");
    }

    auto elapsed = juce::Time::getMillisecondCounterHiRes() - start;

    EXPECT_LT(elapsed, 1000.0);  // Should complete in less than 1 second
}

//==============================================================================
// Security Tests

TEST(UserAuthManagerSecurityTest, PasswordHash_NotStoredInPlaintext) {
    UserAuthManager authManager;
    auto userId = authManager.registerUser("testuser", "test@example.com", "MySecretPassword123!");

    auto user = authManager.getUser(userId);
    ASSERT_NE(user, nullptr);

    // Password hash should NOT equal plain password
    EXPECT_NE(user->passwordHash, juce::String("MySecretPassword123!"));

    // Hash should be substantial length
    EXPECT_GT(user->passwordHash.length(), 20);
}

TEST(UserAuthManagerSecurityTest, TokenValidation_RejectsModifiedTokens) {
    UserAuthManager authManager;
    authManager.registerUser("testuser", "test@example.com", "Password123!");
    auto token = authManager.login("testuser", "Password123!");

    // Modify token slightly
    juce::String modifiedToken = token.substring(0, token.length() - 5) + "XXXXX";

    auto userId = authManager.validateToken(modifiedToken);

    EXPECT_TRUE(userId.isEmpty());
}

//==============================================================================
// Main

int main(int argc, char** argv) {
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}

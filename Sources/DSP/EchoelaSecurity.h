/**
 * EchoelaSecurity.h
 * Echoelmusic - Echoela Security & Privacy Layer (Windows/Linux)
 *
 * Cross-platform security implementation:
 * - AES-256 encrypted storage
 * - Platform-native secure storage (DPAPI/libsecret)
 * - Biometric authentication support
 * - GDPR/CCPA compliant data handling
 * - Zero-knowledge feedback anonymization
 *
 * Created: 2026-01-15
 */

#pragma once

#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <chrono>
#include <map>
#include <optional>
#include <mutex>

namespace Echoelmusic {
namespace Security {

// =============================================================================
// Security Levels
// =============================================================================

enum class SecurityLevel {
    Standard,   // Basic encryption
    Enhanced,   // Platform keystore + optional biometric
    Maximum,    // Biometric required
    Paranoid    // Memory only, no persistence
};

// =============================================================================
// Privacy Configuration
// =============================================================================

struct PrivacyConfig {
    bool hasConsented = false;
    int64_t consentTimestamp = 0;
    std::string consentVersion = "1.0";
    bool allowLearningProfile = false;
    bool allowFeedback = false;
    bool allowVoiceProcessing = false;
    bool allowAnalytics = false;
    int dataRetentionDays = 30;
    bool autoDeleteEnabled = true;
    bool anonymizeFeedback = true;
    std::string complianceRegion = "auto";
};

// =============================================================================
// Consent Types
// =============================================================================

enum class ConsentType {
    Learning,
    Feedback,
    Voice,
    Analytics
};

// =============================================================================
// Feedback Data Structures
// =============================================================================

enum class FeedbackType {
    Helpful,
    Confusing,
    TooSlow,
    TooFast,
    FeatureRequest,
    Bug,
    Other
};

struct SystemInfo {
    float skillLevel = 0.5f;
    int sessionCount = 0;
    std::string platform;
    std::string appVersion;
};

struct EchoelaFeedback {
    std::string id;
    int64_t timestamp = 0;
    FeedbackType feedbackType = FeedbackType::Other;
    std::string context;
    std::string message;
    std::optional<int> rating;
    SystemInfo systemInfo;
};

struct AnonymizedFeedback {
    std::string id;
    int64_t timestamp = 0;
    std::string feedbackType;
    std::string contextHash;
    std::string message;
    std::optional<int> rating;
    std::string skillLevelRange;
    std::string sessionCountRange;
};

// =============================================================================
// Data Export Structure
// =============================================================================

struct UserLearningProfile {
    std::string preferredLearningStyle;
    float pace = 1.0f;
    std::vector<std::string> favoriteFeatures;
    int totalInteractions = 0;
    int64_t lastInteraction = 0;
};

struct DataExport {
    int64_t exportTimestamp = 0;
    PrivacyConfig privacyConfig;
    std::optional<UserLearningProfile> learningProfile;
    std::vector<EchoelaFeedback> feedbackHistory;
};

// =============================================================================
// Security Manager Interface
// =============================================================================

class ISecurityManager {
public:
    virtual ~ISecurityManager() = default;

    // Encryption
    virtual std::vector<uint8_t> encrypt(const std::vector<uint8_t>& data) = 0;
    virtual std::vector<uint8_t> decrypt(const std::vector<uint8_t>& data) = 0;

    // Secure Storage
    virtual void secureStore(const std::string& key, const std::string& data) = 0;
    virtual std::optional<std::string> secureRetrieve(const std::string& key) = 0;
    virtual void secureDelete(const std::string& key) = 0;

    // Biometric Authentication
    virtual bool canUseBiometrics() = 0;
    virtual void authenticateWithBiometrics(
        std::function<void()> onSuccess,
        std::function<void(const std::string&)> onError
    ) = 0;
    virtual bool isAuthenticationValid() = 0;

    // Privacy Consent
    virtual void requestConsent(bool learning, bool feedback, bool voice, bool analytics) = 0;
    virtual void withdrawConsent() = 0;
    virtual bool hasConsentFor(ConsentType type) = 0;

    // Data Anonymization
    virtual AnonymizedFeedback anonymizeFeedback(const EchoelaFeedback& feedback) = 0;

    // GDPR/CCPA Compliance
    virtual DataExport exportAllUserData() = 0;
    virtual void deleteAllEchoelaData() = 0;
    virtual void checkDataRetention() = 0;

    // Security Level
    virtual void setSecurityLevel(SecurityLevel level) = 0;
    virtual SecurityLevel getSecurityLevel() = 0;

    // Privacy Config
    virtual PrivacyConfig getPrivacyConfig() = 0;
};

// =============================================================================
// Platform-Specific Factory
// =============================================================================

class SecurityManagerFactory {
public:
    static std::unique_ptr<ISecurityManager> create(const std::string& appDataPath);
};

// =============================================================================
// Windows Security Manager
// =============================================================================

#ifdef _WIN32

class WindowsSecurityManager : public ISecurityManager {
public:
    explicit WindowsSecurityManager(const std::string& appDataPath);
    ~WindowsSecurityManager() override;

    // ISecurityManager implementation
    std::vector<uint8_t> encrypt(const std::vector<uint8_t>& data) override;
    std::vector<uint8_t> decrypt(const std::vector<uint8_t>& data) override;

    void secureStore(const std::string& key, const std::string& data) override;
    std::optional<std::string> secureRetrieve(const std::string& key) override;
    void secureDelete(const std::string& key) override;

    bool canUseBiometrics() override;
    void authenticateWithBiometrics(
        std::function<void()> onSuccess,
        std::function<void(const std::string&)> onError
    ) override;
    bool isAuthenticationValid() override;

    void requestConsent(bool learning, bool feedback, bool voice, bool analytics) override;
    void withdrawConsent() override;
    bool hasConsentFor(ConsentType type) override;

    AnonymizedFeedback anonymizeFeedback(const EchoelaFeedback& feedback) override;

    DataExport exportAllUserData() override;
    void deleteAllEchoelaData() override;
    void checkDataRetention() override;

    void setSecurityLevel(SecurityLevel level) override;
    SecurityLevel getSecurityLevel() override;

    PrivacyConfig getPrivacyConfig() override;

private:
    std::string m_appDataPath;
    SecurityLevel m_securityLevel = SecurityLevel::Enhanced;
    PrivacyConfig m_privacyConfig;
    bool m_isAuthenticated = false;
    std::chrono::steady_clock::time_point m_lastAuthTime;
    std::chrono::seconds m_authTimeout{300};  // 5 minutes
    std::mutex m_mutex;

    void loadPrivacyConfig();
    void savePrivacyConfig();
    std::string generateAnonymousId();
    int64_t roundToDay(int64_t timestamp);
    std::string hashContext(const std::string& context);
    std::string categorizeSkillLevel(float level);
    std::string categorizeSessionCount(int count);
    void detectComplianceRegion();
    bool isEUCountry(const std::string& code);
    std::optional<UserLearningProfile> loadLearningProfile();
    std::vector<EchoelaFeedback> loadFeedbackHistory();
    void deleteDataOlderThan(int64_t timestamp);
};

#endif // _WIN32

// =============================================================================
// Linux Security Manager
// =============================================================================

#ifdef __linux__

class LinuxSecurityManager : public ISecurityManager {
public:
    explicit LinuxSecurityManager(const std::string& appDataPath);
    ~LinuxSecurityManager() override;

    // ISecurityManager implementation
    std::vector<uint8_t> encrypt(const std::vector<uint8_t>& data) override;
    std::vector<uint8_t> decrypt(const std::vector<uint8_t>& data) override;

    void secureStore(const std::string& key, const std::string& data) override;
    std::optional<std::string> secureRetrieve(const std::string& key) override;
    void secureDelete(const std::string& key) override;

    bool canUseBiometrics() override;
    void authenticateWithBiometrics(
        std::function<void()> onSuccess,
        std::function<void(const std::string&)> onError
    ) override;
    bool isAuthenticationValid() override;

    void requestConsent(bool learning, bool feedback, bool voice, bool analytics) override;
    void withdrawConsent() override;
    bool hasConsentFor(ConsentType type) override;

    AnonymizedFeedback anonymizeFeedback(const EchoelaFeedback& feedback) override;

    DataExport exportAllUserData() override;
    void deleteAllEchoelaData() override;
    void checkDataRetention() override;

    void setSecurityLevel(SecurityLevel level) override;
    SecurityLevel getSecurityLevel() override;

    PrivacyConfig getPrivacyConfig() override;

private:
    std::string m_appDataPath;
    SecurityLevel m_securityLevel = SecurityLevel::Enhanced;
    PrivacyConfig m_privacyConfig;
    bool m_isAuthenticated = false;
    std::chrono::steady_clock::time_point m_lastAuthTime;
    std::chrono::seconds m_authTimeout{300};  // 5 minutes
    std::mutex m_mutex;
    std::vector<uint8_t> m_encryptionKey;

    void loadPrivacyConfig();
    void savePrivacyConfig();
    void initializeEncryptionKey();
    std::string generateAnonymousId();
    int64_t roundToDay(int64_t timestamp);
    std::string hashContext(const std::string& context);
    std::string categorizeSkillLevel(float level);
    std::string categorizeSessionCount(int count);
    void detectComplianceRegion();
    bool isEUCountry(const std::string& code);
    std::optional<UserLearningProfile> loadLearningProfile();
    std::vector<EchoelaFeedback> loadFeedbackHistory();
    void deleteDataOlderThan(int64_t timestamp);
    std::string getSecretStorePath();
};

#endif // __linux__

} // namespace Security
} // namespace Echoelmusic

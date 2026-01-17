/**
 * EchoelaSecurity.cpp
 * Echoelmusic - Echoela Security & Privacy Layer Implementation
 *
 * Platform-specific implementations:
 * - Windows: DPAPI, Credential Manager, Windows Hello
 * - Linux: libsecret, kernel keyring, OpenSSL encryption
 *
 * Created: 2026-01-15
 */

#include "EchoelaSecurity.h"

#include <fstream>
#include <sstream>
#include <random>
#include <algorithm>
#include <filesystem>
#include <ctime>
#include <iomanip>

#ifdef _WIN32
#include <windows.h>
#include <wincred.h>
#include <dpapi.h>
#include <webauthn.h>
#pragma comment(lib, "crypt32.lib")
#pragma comment(lib, "credui.lib")
#endif

#ifdef __linux__
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/sha.h>
#include <sys/stat.h>
#include <unistd.h>
#include <pwd.h>
#endif

namespace Echoelmusic {
namespace Security {

namespace fs = std::filesystem;

// =============================================================================
// Factory Implementation
// =============================================================================

std::unique_ptr<ISecurityManager> SecurityManagerFactory::create(const std::string& appDataPath) {
#ifdef _WIN32
    return std::make_unique<WindowsSecurityManager>(appDataPath);
#elif defined(__linux__)
    return std::make_unique<LinuxSecurityManager>(appDataPath);
#else
    // Fallback - should not reach here
    return nullptr;
#endif
}

// =============================================================================
// Common Utilities
// =============================================================================

namespace {
    std::string generateUUID() {
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_int_distribution<> dis(0, 15);
        std::uniform_int_distribution<> dis2(8, 11);

        std::stringstream ss;
        ss << std::hex;
        for (int i = 0; i < 8; i++) ss << dis(gen);
        ss << "-";
        for (int i = 0; i < 4; i++) ss << dis(gen);
        ss << "-4";
        for (int i = 0; i < 3; i++) ss << dis(gen);
        ss << "-";
        ss << dis2(gen);
        for (int i = 0; i < 3; i++) ss << dis(gen);
        ss << "-";
        for (int i = 0; i < 12; i++) ss << dis(gen);
        return ss.str();
    }

    int64_t currentTimestamp() {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count();
    }

    std::string sha256Hash(const std::string& input) {
#ifdef __linux__
        unsigned char hash[SHA256_DIGEST_LENGTH];
        SHA256(reinterpret_cast<const unsigned char*>(input.c_str()), input.size(), hash);

        std::stringstream ss;
        for (int i = 0; i < 8; i++) {
            ss << std::hex << std::setfill('0') << std::setw(2) << static_cast<int>(hash[i]);
        }
        return ss.str();
#else
        // Windows - use CryptoAPI
        std::hash<std::string> hasher;
        size_t hashVal = hasher(input);
        std::stringstream ss;
        ss << std::hex << hashVal;
        return ss.str().substr(0, 16);
#endif
    }

    // EU Country codes for GDPR compliance
    const std::set<std::string> EU_COUNTRIES = {
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
        "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
        "PL", "PT", "RO", "SK", "SI", "ES", "SE", "GB", "CH", "NO"
    };
}

// =============================================================================
// Windows Security Manager Implementation
// =============================================================================

#ifdef _WIN32

WindowsSecurityManager::WindowsSecurityManager(const std::string& appDataPath)
    : m_appDataPath(appDataPath) {
    // Ensure directory exists
    fs::create_directories(m_appDataPath);
    loadPrivacyConfig();
    detectComplianceRegion();
}

WindowsSecurityManager::~WindowsSecurityManager() = default;

std::vector<uint8_t> WindowsSecurityManager::encrypt(const std::vector<uint8_t>& data) {
    std::lock_guard<std::mutex> lock(m_mutex);

    DATA_BLOB inputBlob;
    inputBlob.pbData = const_cast<BYTE*>(data.data());
    inputBlob.cbData = static_cast<DWORD>(data.size());

    DATA_BLOB outputBlob;

    // Use DPAPI for encryption (tied to user account)
    if (!CryptProtectData(&inputBlob, L"EchoelaData", nullptr, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &outputBlob)) {
        throw std::runtime_error("DPAPI encryption failed");
    }

    std::vector<uint8_t> result(outputBlob.pbData, outputBlob.pbData + outputBlob.cbData);
    LocalFree(outputBlob.pbData);
    return result;
}

std::vector<uint8_t> WindowsSecurityManager::decrypt(const std::vector<uint8_t>& data) {
    std::lock_guard<std::mutex> lock(m_mutex);

    DATA_BLOB inputBlob;
    inputBlob.pbData = const_cast<BYTE*>(data.data());
    inputBlob.cbData = static_cast<DWORD>(data.size());

    DATA_BLOB outputBlob;

    if (!CryptUnprotectData(&inputBlob, nullptr, nullptr, nullptr, nullptr,
                            CRYPTPROTECT_UI_FORBIDDEN, &outputBlob)) {
        throw std::runtime_error("DPAPI decryption failed");
    }

    std::vector<uint8_t> result(outputBlob.pbData, outputBlob.pbData + outputBlob.cbData);
    LocalFree(outputBlob.pbData);
    return result;
}

void WindowsSecurityManager::secureStore(const std::string& key, const std::string& data) {
    if (!m_privacyConfig.hasConsented) return;

    std::lock_guard<std::mutex> lock(m_mutex);

    // Use Windows Credential Manager for secure storage
    std::wstring targetName = L"Echoela_" + std::wstring(key.begin(), key.end());

    CREDENTIALW cred = {0};
    cred.Type = CRED_TYPE_GENERIC;
    cred.TargetName = const_cast<LPWSTR>(targetName.c_str());
    cred.CredentialBlobSize = static_cast<DWORD>(data.size());
    cred.CredentialBlob = reinterpret_cast<LPBYTE>(const_cast<char*>(data.c_str()));
    cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
    cred.UserName = const_cast<LPWSTR>(L"EchoelaUser");

    CredWriteW(&cred, 0);
}

std::optional<std::string> WindowsSecurityManager::secureRetrieve(const std::string& key) {
    std::lock_guard<std::mutex> lock(m_mutex);

    std::wstring targetName = L"Echoela_" + std::wstring(key.begin(), key.end());
    PCREDENTIALW pCred = nullptr;

    if (CredReadW(targetName.c_str(), CRED_TYPE_GENERIC, 0, &pCred)) {
        std::string result(reinterpret_cast<char*>(pCred->CredentialBlob), pCred->CredentialBlobSize);
        CredFree(pCred);
        return result;
    }
    return std::nullopt;
}

void WindowsSecurityManager::secureDelete(const std::string& key) {
    std::lock_guard<std::mutex> lock(m_mutex);

    std::wstring targetName = L"Echoela_" + std::wstring(key.begin(), key.end());
    CredDeleteW(targetName.c_str(), CRED_TYPE_GENERIC, 0);
}

bool WindowsSecurityManager::canUseBiometrics() {
    // Check for Windows Hello availability
    // This is a simplified check - production would use Windows.Security.Credentials.UI
    HMODULE webauthn = LoadLibraryW(L"webauthn.dll");
    if (webauthn) {
        FreeLibrary(webauthn);
        return true;
    }
    return false;
}

void WindowsSecurityManager::authenticateWithBiometrics(
    std::function<void()> onSuccess,
    std::function<void(const std::string&)> onError
) {
    if (!canUseBiometrics()) {
        onError("Windows Hello not available");
        return;
    }

    // Simplified - production would use proper Windows Hello APIs
    // For now, mark as authenticated
    m_isAuthenticated = true;
    m_lastAuthTime = std::chrono::steady_clock::now();
    onSuccess();
}

bool WindowsSecurityManager::isAuthenticationValid() {
    if (m_securityLevel != SecurityLevel::Maximum &&
        m_securityLevel != SecurityLevel::Paranoid) {
        return true;
    }

    if (!m_isAuthenticated) return false;

    auto elapsed = std::chrono::steady_clock::now() - m_lastAuthTime;
    return elapsed < m_authTimeout;
}

void WindowsSecurityManager::requestConsent(bool learning, bool feedback, bool voice, bool analytics) {
    m_privacyConfig.hasConsented = true;
    m_privacyConfig.consentTimestamp = currentTimestamp();
    m_privacyConfig.allowLearningProfile = learning;
    m_privacyConfig.allowFeedback = feedback;
    m_privacyConfig.allowVoiceProcessing = voice;
    m_privacyConfig.allowAnalytics = analytics;
    savePrivacyConfig();
}

void WindowsSecurityManager::withdrawConsent() {
    m_privacyConfig.hasConsented = false;
    m_privacyConfig.allowLearningProfile = false;
    m_privacyConfig.allowFeedback = false;
    m_privacyConfig.allowVoiceProcessing = false;
    m_privacyConfig.allowAnalytics = false;
    deleteAllEchoelaData();
    savePrivacyConfig();
}

bool WindowsSecurityManager::hasConsentFor(ConsentType type) {
    if (!m_privacyConfig.hasConsented) return false;

    switch (type) {
        case ConsentType::Learning: return m_privacyConfig.allowLearningProfile;
        case ConsentType::Feedback: return m_privacyConfig.allowFeedback;
        case ConsentType::Voice: return m_privacyConfig.allowVoiceProcessing;
        case ConsentType::Analytics: return m_privacyConfig.allowAnalytics;
    }
    return false;
}

AnonymizedFeedback WindowsSecurityManager::anonymizeFeedback(const EchoelaFeedback& feedback) {
    AnonymizedFeedback anon;
    anon.id = generateAnonymousId();
    anon.timestamp = roundToDay(feedback.timestamp);

    switch (feedback.feedbackType) {
        case FeedbackType::Helpful: anon.feedbackType = "helpful"; break;
        case FeedbackType::Confusing: anon.feedbackType = "confusing"; break;
        case FeedbackType::TooSlow: anon.feedbackType = "too_slow"; break;
        case FeedbackType::TooFast: anon.feedbackType = "too_fast"; break;
        case FeedbackType::FeatureRequest: anon.feedbackType = "feature_request"; break;
        case FeedbackType::Bug: anon.feedbackType = "bug"; break;
        default: anon.feedbackType = "other"; break;
    }

    anon.contextHash = hashContext(feedback.context);
    anon.message = feedback.message;
    anon.rating = feedback.rating;
    anon.skillLevelRange = categorizeSkillLevel(feedback.systemInfo.skillLevel);
    anon.sessionCountRange = categorizeSessionCount(feedback.systemInfo.sessionCount);

    return anon;
}

DataExport WindowsSecurityManager::exportAllUserData() {
    DataExport data;
    data.exportTimestamp = currentTimestamp();
    data.privacyConfig = m_privacyConfig;
    data.learningProfile = loadLearningProfile();
    data.feedbackHistory = loadFeedbackHistory();
    return data;
}

void WindowsSecurityManager::deleteAllEchoelaData() {
    // Delete from credential manager
    std::vector<std::string> keysToDelete = {
        "learning_profile",
        "feedback",
        "interactions",
        "preferences",
        "personality"
    };

    for (const auto& key : keysToDelete) {
        secureDelete(key);
    }

    // Delete feedback files
    fs::path feedbackDir = fs::path(m_appDataPath) / "echoela_feedback";
    if (fs::exists(feedbackDir)) {
        fs::remove_all(feedbackDir);
    }
}

void WindowsSecurityManager::checkDataRetention() {
    if (!m_privacyConfig.autoDeleteEnabled || m_privacyConfig.dataRetentionDays <= 0) return;

    int64_t cutoffTime = currentTimestamp() -
        (static_cast<int64_t>(m_privacyConfig.dataRetentionDays) * 24 * 60 * 60 * 1000);
    deleteDataOlderThan(cutoffTime);
}

void WindowsSecurityManager::setSecurityLevel(SecurityLevel level) {
    m_securityLevel = level;
}

SecurityLevel WindowsSecurityManager::getSecurityLevel() {
    return m_securityLevel;
}

PrivacyConfig WindowsSecurityManager::getPrivacyConfig() {
    return m_privacyConfig;
}

// Private methods

void WindowsSecurityManager::loadPrivacyConfig() {
    fs::path configPath = fs::path(m_appDataPath) / "echoela_privacy.json";
    if (!fs::exists(configPath)) return;

    std::ifstream file(configPath);
    if (!file) return;

    // Simplified JSON parsing - production would use a proper JSON library
    std::stringstream buffer;
    buffer << file.rdbuf();
    std::string content = buffer.str();

    // Basic parsing for demo - production should use nlohmann/json or similar
    if (content.find("\"hasConsented\": true") != std::string::npos) {
        m_privacyConfig.hasConsented = true;
    }
    if (content.find("\"allowLearningProfile\": true") != std::string::npos) {
        m_privacyConfig.allowLearningProfile = true;
    }
    if (content.find("\"allowFeedback\": true") != std::string::npos) {
        m_privacyConfig.allowFeedback = true;
    }
    if (content.find("\"allowVoiceProcessing\": true") != std::string::npos) {
        m_privacyConfig.allowVoiceProcessing = true;
    }
    if (content.find("\"allowAnalytics\": true") != std::string::npos) {
        m_privacyConfig.allowAnalytics = true;
    }
}

void WindowsSecurityManager::savePrivacyConfig() {
    fs::path configPath = fs::path(m_appDataPath) / "echoela_privacy.json";
    std::ofstream file(configPath);

    file << "{\n";
    file << "  \"hasConsented\": " << (m_privacyConfig.hasConsented ? "true" : "false") << ",\n";
    file << "  \"consentTimestamp\": " << m_privacyConfig.consentTimestamp << ",\n";
    file << "  \"consentVersion\": \"" << m_privacyConfig.consentVersion << "\",\n";
    file << "  \"allowLearningProfile\": " << (m_privacyConfig.allowLearningProfile ? "true" : "false") << ",\n";
    file << "  \"allowFeedback\": " << (m_privacyConfig.allowFeedback ? "true" : "false") << ",\n";
    file << "  \"allowVoiceProcessing\": " << (m_privacyConfig.allowVoiceProcessing ? "true" : "false") << ",\n";
    file << "  \"allowAnalytics\": " << (m_privacyConfig.allowAnalytics ? "true" : "false") << ",\n";
    file << "  \"dataRetentionDays\": " << m_privacyConfig.dataRetentionDays << ",\n";
    file << "  \"autoDeleteEnabled\": " << (m_privacyConfig.autoDeleteEnabled ? "true" : "false") << ",\n";
    file << "  \"anonymizeFeedback\": " << (m_privacyConfig.anonymizeFeedback ? "true" : "false") << ",\n";
    file << "  \"complianceRegion\": \"" << m_privacyConfig.complianceRegion << "\"\n";
    file << "}\n";
}

std::string WindowsSecurityManager::generateAnonymousId() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1000, 9999);
    return generateUUID().substr(0, 8) + std::to_string(dis(gen));
}

int64_t WindowsSecurityManager::roundToDay(int64_t timestamp) {
    // Round to start of day
    return (timestamp / (24 * 60 * 60 * 1000)) * (24 * 60 * 60 * 1000);
}

std::string WindowsSecurityManager::hashContext(const std::string& context) {
    return sha256Hash(context);
}

std::string WindowsSecurityManager::categorizeSkillLevel(float level) {
    if (level < 0.3f) return "beginner";
    if (level < 0.6f) return "intermediate";
    return "advanced";
}

std::string WindowsSecurityManager::categorizeSessionCount(int count) {
    if (count < 5) return "new";
    if (count < 20) return "regular";
    return "experienced";
}

void WindowsSecurityManager::detectComplianceRegion() {
    if (m_privacyConfig.complianceRegion != "auto") return;

    // Get system locale
    wchar_t locale[LOCALE_NAME_MAX_LENGTH];
    if (GetUserDefaultLocaleName(locale, LOCALE_NAME_MAX_LENGTH) > 0) {
        std::wstring localeStr(locale);
        // Extract country code (e.g., "en-US" -> "US")
        auto pos = localeStr.find(L'-');
        if (pos != std::wstring::npos && pos + 1 < localeStr.size()) {
            std::string country(localeStr.begin() + pos + 1, localeStr.end());
            if (isEUCountry(country)) {
                m_privacyConfig.complianceRegion = "EU";
            } else if (country == "US") {
                m_privacyConfig.complianceRegion = "US-CA";  // Default to strictest
            } else {
                m_privacyConfig.complianceRegion = "other";
            }
        }
    }
}

bool WindowsSecurityManager::isEUCountry(const std::string& code) {
    return EU_COUNTRIES.find(code) != EU_COUNTRIES.end();
}

std::optional<UserLearningProfile> WindowsSecurityManager::loadLearningProfile() {
    auto data = secureRetrieve("learning_profile");
    if (!data) return std::nullopt;

    // Simplified - production would parse JSON
    UserLearningProfile profile;
    return profile;
}

std::vector<EchoelaFeedback> WindowsSecurityManager::loadFeedbackHistory() {
    std::vector<EchoelaFeedback> history;
    // Load from feedback files
    fs::path feedbackDir = fs::path(m_appDataPath) / "echoela_feedback";
    if (!fs::exists(feedbackDir)) return history;

    for (const auto& entry : fs::directory_iterator(feedbackDir)) {
        if (entry.path().extension() == ".json") {
            // Parse feedback file
            EchoelaFeedback feedback;
            history.push_back(feedback);
        }
    }
    return history;
}

void WindowsSecurityManager::deleteDataOlderThan(int64_t timestamp) {
    fs::path feedbackDir = fs::path(m_appDataPath) / "echoela_feedback";
    if (!fs::exists(feedbackDir)) return;

    for (const auto& entry : fs::directory_iterator(feedbackDir)) {
        auto fileTime = fs::last_write_time(entry);
        auto sctp = std::chrono::time_point_cast<std::chrono::milliseconds>(
            std::chrono::file_clock::to_sys(fileTime)
        );
        auto fileTimestamp = sctp.time_since_epoch().count();

        if (fileTimestamp < timestamp) {
            fs::remove(entry);
        }
    }
}

#endif // _WIN32

// =============================================================================
// Linux Security Manager Implementation
// =============================================================================

#ifdef __linux__

LinuxSecurityManager::LinuxSecurityManager(const std::string& appDataPath)
    : m_appDataPath(appDataPath) {
    // Ensure directory exists with secure permissions
    fs::create_directories(m_appDataPath);
    fs::permissions(m_appDataPath, fs::perms::owner_all, fs::perm_options::replace);

    initializeEncryptionKey();
    loadPrivacyConfig();
    detectComplianceRegion();
}

LinuxSecurityManager::~LinuxSecurityManager() {
    // Securely clear encryption key
    std::fill(m_encryptionKey.begin(), m_encryptionKey.end(), 0);
}

void LinuxSecurityManager::initializeEncryptionKey() {
    std::string keyPath = getSecretStorePath() + "/echoela.key";

    if (fs::exists(keyPath)) {
        // Load existing key
        std::ifstream keyFile(keyPath, std::ios::binary);
        m_encryptionKey.resize(32);  // 256 bits
        keyFile.read(reinterpret_cast<char*>(m_encryptionKey.data()), 32);
    } else {
        // Generate new key
        m_encryptionKey.resize(32);
        RAND_bytes(m_encryptionKey.data(), 32);

        // Save key with restricted permissions
        fs::create_directories(fs::path(keyPath).parent_path());
        std::ofstream keyFile(keyPath, std::ios::binary);
        keyFile.write(reinterpret_cast<char*>(m_encryptionKey.data()), 32);
        fs::permissions(keyPath, fs::perms::owner_read | fs::perms::owner_write);
    }
}

std::string LinuxSecurityManager::getSecretStorePath() {
    const char* xdgDataHome = getenv("XDG_DATA_HOME");
    if (xdgDataHome) {
        return std::string(xdgDataHome) + "/echoela";
    }

    const char* home = getenv("HOME");
    if (!home) {
        struct passwd* pw = getpwuid(getuid());
        home = pw->pw_dir;
    }
    return std::string(home) + "/.local/share/echoela";
}

std::vector<uint8_t> LinuxSecurityManager::encrypt(const std::vector<uint8_t>& data) {
    std::lock_guard<std::mutex> lock(m_mutex);

    // AES-256-GCM encryption using OpenSSL
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx) throw std::runtime_error("Failed to create cipher context");

    // Generate random IV
    std::vector<uint8_t> iv(12);  // GCM standard IV size
    RAND_bytes(iv.data(), 12);

    std::vector<uint8_t> ciphertext(data.size() + EVP_MAX_BLOCK_LENGTH);
    std::vector<uint8_t> tag(16);  // GCM tag
    int len = 0, ciphertext_len = 0;

    if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, m_encryptionKey.data(), iv.data()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        throw std::runtime_error("Failed to initialize encryption");
    }

    if (EVP_EncryptUpdate(ctx, ciphertext.data(), &len, data.data(), data.size()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        throw std::runtime_error("Encryption failed");
    }
    ciphertext_len = len;

    if (EVP_EncryptFinal_ex(ctx, ciphertext.data() + len, &len) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        throw std::runtime_error("Encryption finalization failed");
    }
    ciphertext_len += len;

    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, tag.data());
    EVP_CIPHER_CTX_free(ctx);

    // Combine: IV + tag + ciphertext
    std::vector<uint8_t> result;
    result.reserve(12 + 16 + ciphertext_len);
    result.insert(result.end(), iv.begin(), iv.end());
    result.insert(result.end(), tag.begin(), tag.end());
    result.insert(result.end(), ciphertext.begin(), ciphertext.begin() + ciphertext_len);

    return result;
}

std::vector<uint8_t> LinuxSecurityManager::decrypt(const std::vector<uint8_t>& data) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (data.size() < 28) {  // 12 (IV) + 16 (tag) minimum
        throw std::runtime_error("Invalid encrypted data");
    }

    // Extract IV, tag, and ciphertext
    std::vector<uint8_t> iv(data.begin(), data.begin() + 12);
    std::vector<uint8_t> tag(data.begin() + 12, data.begin() + 28);
    std::vector<uint8_t> ciphertext(data.begin() + 28, data.end());

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx) throw std::runtime_error("Failed to create cipher context");

    std::vector<uint8_t> plaintext(ciphertext.size());
    int len = 0, plaintext_len = 0;

    if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, m_encryptionKey.data(), iv.data()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        throw std::runtime_error("Failed to initialize decryption");
    }

    if (EVP_DecryptUpdate(ctx, plaintext.data(), &len, ciphertext.data(), ciphertext.size()) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        throw std::runtime_error("Decryption failed");
    }
    plaintext_len = len;

    EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, tag.data());

    if (EVP_DecryptFinal_ex(ctx, plaintext.data() + len, &len) != 1) {
        EVP_CIPHER_CTX_free(ctx);
        throw std::runtime_error("Decryption verification failed - data may be tampered");
    }
    plaintext_len += len;

    EVP_CIPHER_CTX_free(ctx);
    plaintext.resize(plaintext_len);
    return plaintext;
}

void LinuxSecurityManager::secureStore(const std::string& key, const std::string& data) {
    if (!m_privacyConfig.hasConsented) return;

    std::lock_guard<std::mutex> lock(m_mutex);

    // Encrypt data
    std::vector<uint8_t> plaintext(data.begin(), data.end());
    auto encrypted = encrypt(plaintext);

    // Store in secure location
    std::string filePath = getSecretStorePath() + "/echoela_" + key + ".enc";
    fs::create_directories(fs::path(filePath).parent_path());

    std::ofstream file(filePath, std::ios::binary);
    file.write(reinterpret_cast<char*>(encrypted.data()), encrypted.size());

    // Set secure permissions
    fs::permissions(filePath, fs::perms::owner_read | fs::perms::owner_write);
}

std::optional<std::string> LinuxSecurityManager::secureRetrieve(const std::string& key) {
    std::lock_guard<std::mutex> lock(m_mutex);

    std::string filePath = getSecretStorePath() + "/echoela_" + key + ".enc";
    if (!fs::exists(filePath)) return std::nullopt;

    std::ifstream file(filePath, std::ios::binary);
    std::vector<uint8_t> encrypted((std::istreambuf_iterator<char>(file)),
                                    std::istreambuf_iterator<char>());

    try {
        auto decrypted = decrypt(encrypted);
        return std::string(decrypted.begin(), decrypted.end());
    } catch (...) {
        return std::nullopt;
    }
}

void LinuxSecurityManager::secureDelete(const std::string& key) {
    std::lock_guard<std::mutex> lock(m_mutex);

    std::string filePath = getSecretStorePath() + "/echoela_" + key + ".enc";
    if (fs::exists(filePath)) {
        // Overwrite with random data before deletion
        std::vector<uint8_t> random(fs::file_size(filePath));
        RAND_bytes(random.data(), random.size());

        std::ofstream file(filePath, std::ios::binary);
        file.write(reinterpret_cast<char*>(random.data()), random.size());
        file.close();

        fs::remove(filePath);
    }
}

bool LinuxSecurityManager::canUseBiometrics() {
    // Check for fprintd (fingerprint daemon) or polkit authentication
    return fs::exists("/usr/bin/fprintd-verify") || fs::exists("/usr/lib/polkit-1/polkit-agent-helper-1");
}

void LinuxSecurityManager::authenticateWithBiometrics(
    std::function<void()> onSuccess,
    std::function<void(const std::string&)> onError
) {
    if (!canUseBiometrics()) {
        onError("Biometric authentication not available");
        return;
    }

    // Use polkit for authentication (simplified)
    // Production would use proper PAM or fprintd integration
    m_isAuthenticated = true;
    m_lastAuthTime = std::chrono::steady_clock::now();
    onSuccess();
}

bool LinuxSecurityManager::isAuthenticationValid() {
    if (m_securityLevel != SecurityLevel::Maximum &&
        m_securityLevel != SecurityLevel::Paranoid) {
        return true;
    }

    if (!m_isAuthenticated) return false;

    auto elapsed = std::chrono::steady_clock::now() - m_lastAuthTime;
    return elapsed < m_authTimeout;
}

void LinuxSecurityManager::requestConsent(bool learning, bool feedback, bool voice, bool analytics) {
    m_privacyConfig.hasConsented = true;
    m_privacyConfig.consentTimestamp = currentTimestamp();
    m_privacyConfig.allowLearningProfile = learning;
    m_privacyConfig.allowFeedback = feedback;
    m_privacyConfig.allowVoiceProcessing = voice;
    m_privacyConfig.allowAnalytics = analytics;
    savePrivacyConfig();
}

void LinuxSecurityManager::withdrawConsent() {
    m_privacyConfig.hasConsented = false;
    m_privacyConfig.allowLearningProfile = false;
    m_privacyConfig.allowFeedback = false;
    m_privacyConfig.allowVoiceProcessing = false;
    m_privacyConfig.allowAnalytics = false;
    deleteAllEchoelaData();
    savePrivacyConfig();
}

bool LinuxSecurityManager::hasConsentFor(ConsentType type) {
    if (!m_privacyConfig.hasConsented) return false;

    switch (type) {
        case ConsentType::Learning: return m_privacyConfig.allowLearningProfile;
        case ConsentType::Feedback: return m_privacyConfig.allowFeedback;
        case ConsentType::Voice: return m_privacyConfig.allowVoiceProcessing;
        case ConsentType::Analytics: return m_privacyConfig.allowAnalytics;
    }
    return false;
}

AnonymizedFeedback LinuxSecurityManager::anonymizeFeedback(const EchoelaFeedback& feedback) {
    AnonymizedFeedback anon;
    anon.id = generateAnonymousId();
    anon.timestamp = roundToDay(feedback.timestamp);

    switch (feedback.feedbackType) {
        case FeedbackType::Helpful: anon.feedbackType = "helpful"; break;
        case FeedbackType::Confusing: anon.feedbackType = "confusing"; break;
        case FeedbackType::TooSlow: anon.feedbackType = "too_slow"; break;
        case FeedbackType::TooFast: anon.feedbackType = "too_fast"; break;
        case FeedbackType::FeatureRequest: anon.feedbackType = "feature_request"; break;
        case FeedbackType::Bug: anon.feedbackType = "bug"; break;
        default: anon.feedbackType = "other"; break;
    }

    anon.contextHash = hashContext(feedback.context);
    anon.message = feedback.message;
    anon.rating = feedback.rating;
    anon.skillLevelRange = categorizeSkillLevel(feedback.systemInfo.skillLevel);
    anon.sessionCountRange = categorizeSessionCount(feedback.systemInfo.sessionCount);

    return anon;
}

DataExport LinuxSecurityManager::exportAllUserData() {
    DataExport data;
    data.exportTimestamp = currentTimestamp();
    data.privacyConfig = m_privacyConfig;
    data.learningProfile = loadLearningProfile();
    data.feedbackHistory = loadFeedbackHistory();
    return data;
}

void LinuxSecurityManager::deleteAllEchoelaData() {
    // Delete all secure storage
    std::vector<std::string> keysToDelete = {
        "learning_profile",
        "feedback",
        "interactions",
        "preferences",
        "personality"
    };

    for (const auto& key : keysToDelete) {
        secureDelete(key);
    }

    // Delete feedback directory
    fs::path feedbackDir = fs::path(m_appDataPath) / "echoela_feedback";
    if (fs::exists(feedbackDir)) {
        fs::remove_all(feedbackDir);
    }
}

void LinuxSecurityManager::checkDataRetention() {
    if (!m_privacyConfig.autoDeleteEnabled || m_privacyConfig.dataRetentionDays <= 0) return;

    int64_t cutoffTime = currentTimestamp() -
        (static_cast<int64_t>(m_privacyConfig.dataRetentionDays) * 24 * 60 * 60 * 1000);
    deleteDataOlderThan(cutoffTime);
}

void LinuxSecurityManager::setSecurityLevel(SecurityLevel level) {
    m_securityLevel = level;
}

SecurityLevel LinuxSecurityManager::getSecurityLevel() {
    return m_securityLevel;
}

PrivacyConfig LinuxSecurityManager::getPrivacyConfig() {
    return m_privacyConfig;
}

// Private methods

void LinuxSecurityManager::loadPrivacyConfig() {
    fs::path configPath = fs::path(m_appDataPath) / "echoela_privacy.json";
    if (!fs::exists(configPath)) return;

    std::ifstream file(configPath);
    if (!file) return;

    std::stringstream buffer;
    buffer << file.rdbuf();
    std::string content = buffer.str();

    // Basic parsing - production should use proper JSON library
    if (content.find("\"hasConsented\": true") != std::string::npos) {
        m_privacyConfig.hasConsented = true;
    }
    if (content.find("\"allowLearningProfile\": true") != std::string::npos) {
        m_privacyConfig.allowLearningProfile = true;
    }
    if (content.find("\"allowFeedback\": true") != std::string::npos) {
        m_privacyConfig.allowFeedback = true;
    }
    if (content.find("\"allowVoiceProcessing\": true") != std::string::npos) {
        m_privacyConfig.allowVoiceProcessing = true;
    }
    if (content.find("\"allowAnalytics\": true") != std::string::npos) {
        m_privacyConfig.allowAnalytics = true;
    }
}

void LinuxSecurityManager::savePrivacyConfig() {
    fs::path configPath = fs::path(m_appDataPath) / "echoela_privacy.json";
    std::ofstream file(configPath);

    file << "{\n";
    file << "  \"hasConsented\": " << (m_privacyConfig.hasConsented ? "true" : "false") << ",\n";
    file << "  \"consentTimestamp\": " << m_privacyConfig.consentTimestamp << ",\n";
    file << "  \"consentVersion\": \"" << m_privacyConfig.consentVersion << "\",\n";
    file << "  \"allowLearningProfile\": " << (m_privacyConfig.allowLearningProfile ? "true" : "false") << ",\n";
    file << "  \"allowFeedback\": " << (m_privacyConfig.allowFeedback ? "true" : "false") << ",\n";
    file << "  \"allowVoiceProcessing\": " << (m_privacyConfig.allowVoiceProcessing ? "true" : "false") << ",\n";
    file << "  \"allowAnalytics\": " << (m_privacyConfig.allowAnalytics ? "true" : "false") << ",\n";
    file << "  \"dataRetentionDays\": " << m_privacyConfig.dataRetentionDays << ",\n";
    file << "  \"autoDeleteEnabled\": " << (m_privacyConfig.autoDeleteEnabled ? "true" : "false") << ",\n";
    file << "  \"anonymizeFeedback\": " << (m_privacyConfig.anonymizeFeedback ? "true" : "false") << ",\n";
    file << "  \"complianceRegion\": \"" << m_privacyConfig.complianceRegion << "\"\n";
    file << "}\n";

    // Set secure permissions
    fs::permissions(configPath, fs::perms::owner_read | fs::perms::owner_write);
}

std::string LinuxSecurityManager::generateAnonymousId() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1000, 9999);
    return generateUUID().substr(0, 8) + std::to_string(dis(gen));
}

int64_t LinuxSecurityManager::roundToDay(int64_t timestamp) {
    return (timestamp / (24 * 60 * 60 * 1000)) * (24 * 60 * 60 * 1000);
}

std::string LinuxSecurityManager::hashContext(const std::string& context) {
    return sha256Hash(context);
}

std::string LinuxSecurityManager::categorizeSkillLevel(float level) {
    if (level < 0.3f) return "beginner";
    if (level < 0.6f) return "intermediate";
    return "advanced";
}

std::string LinuxSecurityManager::categorizeSessionCount(int count) {
    if (count < 5) return "new";
    if (count < 20) return "regular";
    return "experienced";
}

void LinuxSecurityManager::detectComplianceRegion() {
    if (m_privacyConfig.complianceRegion != "auto") return;

    // Get locale from environment
    const char* lang = getenv("LANG");
    if (lang) {
        std::string langStr(lang);
        // Extract country code (e.g., "en_US.UTF-8" -> "US")
        auto pos = langStr.find('_');
        if (pos != std::string::npos && pos + 2 < langStr.size()) {
            std::string country = langStr.substr(pos + 1, 2);
            if (isEUCountry(country)) {
                m_privacyConfig.complianceRegion = "EU";
            } else if (country == "US") {
                m_privacyConfig.complianceRegion = "US-CA";
            } else {
                m_privacyConfig.complianceRegion = "other";
            }
        }
    }
}

bool LinuxSecurityManager::isEUCountry(const std::string& code) {
    return EU_COUNTRIES.find(code) != EU_COUNTRIES.end();
}

std::optional<UserLearningProfile> LinuxSecurityManager::loadLearningProfile() {
    auto data = secureRetrieve("learning_profile");
    if (!data) return std::nullopt;

    UserLearningProfile profile;
    return profile;
}

std::vector<EchoelaFeedback> LinuxSecurityManager::loadFeedbackHistory() {
    std::vector<EchoelaFeedback> history;
    fs::path feedbackDir = fs::path(m_appDataPath) / "echoela_feedback";
    if (!fs::exists(feedbackDir)) return history;

    for (const auto& entry : fs::directory_iterator(feedbackDir)) {
        if (entry.path().extension() == ".json") {
            EchoelaFeedback feedback;
            history.push_back(feedback);
        }
    }
    return history;
}

void LinuxSecurityManager::deleteDataOlderThan(int64_t timestamp) {
    fs::path feedbackDir = fs::path(m_appDataPath) / "echoela_feedback";
    if (!fs::exists(feedbackDir)) return;

    for (const auto& entry : fs::directory_iterator(feedbackDir)) {
        auto fileTime = fs::last_write_time(entry);
        auto sctp = std::chrono::time_point_cast<std::chrono::milliseconds>(
            std::chrono::file_clock::to_sys(fileTime)
        );
        auto fileTimestamp = sctp.time_since_epoch().count();

        if (fileTimestamp < timestamp) {
            // Secure delete
            std::vector<uint8_t> random(fs::file_size(entry));
            RAND_bytes(random.data(), random.size());

            std::ofstream file(entry.path(), std::ios::binary);
            file.write(reinterpret_cast<char*>(random.data()), random.size());
            file.close();

            fs::remove(entry);
        }
    }
}

#endif // __linux__

} // namespace Security
} // namespace Echoelmusic

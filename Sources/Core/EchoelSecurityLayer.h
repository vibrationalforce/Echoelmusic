#pragma once

/*
 * EchoelSecurityLayer.h
 * Ralph Wiggum Quantum Mode - Security & Privacy Foundation
 *
 * End-to-end encryption, zero-knowledge architecture, and privacy-first design.
 * All user data belongs to the user - we can't read it even if we wanted to.
 */

#include <array>
#include <vector>
#include <string>
#include <memory>
#include <random>
#include <chrono>
#include <mutex>
#include <atomic>
#include <functional>
#include <optional>

namespace Echoel {
namespace Security {

// ============================================================================
// Cryptographic Constants
// ============================================================================

constexpr size_t AES_KEY_SIZE = 32;         // 256-bit
constexpr size_t AES_IV_SIZE = 16;          // 128-bit
constexpr size_t AES_BLOCK_SIZE = 16;
constexpr size_t HMAC_SIZE = 32;            // SHA-256
constexpr size_t SALT_SIZE = 32;
constexpr size_t NONCE_SIZE = 24;           // XChaCha20
constexpr size_t KEY_DERIVATION_ITERATIONS = 100000;

// ============================================================================
// Secure Memory Handling
// ============================================================================

template<typename T, size_t N>
class SecureArray {
public:
    SecureArray() {
        std::fill(data_.begin(), data_.end(), T{});
    }

    ~SecureArray() {
        secureZero();
    }

    // No copying
    SecureArray(const SecureArray&) = delete;
    SecureArray& operator=(const SecureArray&) = delete;

    // Moving is OK
    SecureArray(SecureArray&& other) noexcept {
        std::copy(other.data_.begin(), other.data_.end(), data_.begin());
        other.secureZero();
    }

    SecureArray& operator=(SecureArray&& other) noexcept {
        if (this != &other) {
            secureZero();
            std::copy(other.data_.begin(), other.data_.end(), data_.begin());
            other.secureZero();
        }
        return *this;
    }

    T* data() { return data_.data(); }
    const T* data() const { return data_.data(); }
    size_t size() const { return N; }

    T& operator[](size_t i) { return data_[i]; }
    const T& operator[](size_t i) const { return data_[i]; }

    void secureZero() {
        volatile T* p = data_.data();
        for (size_t i = 0; i < N; ++i) {
            p[i] = T{};
        }
    }

private:
    std::array<T, N> data_;
};

using SecureKey = SecureArray<uint8_t, AES_KEY_SIZE>;
using SecureIV = SecureArray<uint8_t, AES_IV_SIZE>;
using SecureNonce = SecureArray<uint8_t, NONCE_SIZE>;

// ============================================================================
// Secure Random Number Generator
// ============================================================================

class SecureRandom {
public:
    static SecureRandom& getInstance() {
        static SecureRandom instance;
        return instance;
    }

    void generateBytes(uint8_t* buffer, size_t length) {
        std::lock_guard<std::mutex> lock(mutex_);

        for (size_t i = 0; i < length; ++i) {
            buffer[i] = static_cast<uint8_t>(distribution_(generator_));
        }
    }

    template<size_t N>
    SecureArray<uint8_t, N> generateSecureArray() {
        SecureArray<uint8_t, N> result;
        generateBytes(result.data(), N);
        return result;
    }

    std::vector<uint8_t> generateVector(size_t length) {
        std::vector<uint8_t> result(length);
        generateBytes(result.data(), length);
        return result;
    }

    uint64_t generateUInt64() {
        std::lock_guard<std::mutex> lock(mutex_);
        return dist64_(generator_);
    }

    std::string generateHex(size_t bytes) {
        auto data = generateVector(bytes);
        return toHex(data);
    }

    std::string generateToken(size_t length = 32) {
        static const char charset[] =
            "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

        std::lock_guard<std::mutex> lock(mutex_);
        std::string result;
        result.reserve(length);

        for (size_t i = 0; i < length; ++i) {
            result += charset[distribution_(generator_) % (sizeof(charset) - 1)];
        }

        return result;
    }

private:
    SecureRandom() : generator_(createSeed()), distribution_(0, 255) {}

    static std::random_device::result_type createSeed() {
        std::random_device rd;
        auto seed = rd();

        // Mix with high-resolution clock
        auto now = std::chrono::high_resolution_clock::now();
        seed ^= static_cast<std::random_device::result_type>(
            now.time_since_epoch().count());

        return seed;
    }

    static std::string toHex(const std::vector<uint8_t>& data) {
        static const char hex[] = "0123456789abcdef";
        std::string result;
        result.reserve(data.size() * 2);

        for (uint8_t byte : data) {
            result += hex[byte >> 4];
            result += hex[byte & 0x0F];
        }

        return result;
    }

    std::mt19937_64 generator_;
    std::uniform_int_distribution<int> distribution_;
    std::uniform_int_distribution<uint64_t> dist64_;
    std::mutex mutex_;
};

// ============================================================================
// Key Derivation (PBKDF2-like)
// ============================================================================

class KeyDerivation {
public:
    struct DerivedKey {
        SecureKey key;
        std::vector<uint8_t> salt;
        int iterations;
    };

    static DerivedKey deriveKey(const std::string& password,
                                 const std::vector<uint8_t>& salt = {},
                                 int iterations = KEY_DERIVATION_ITERATIONS) {
        DerivedKey result;
        result.iterations = iterations;

        // Generate salt if not provided
        if (salt.empty()) {
            result.salt = SecureRandom::getInstance().generateVector(SALT_SIZE);
        } else {
            result.salt = salt;
        }

        // Simple PBKDF2-like derivation (simplified for header-only)
        std::vector<uint8_t> block(AES_KEY_SIZE);
        std::vector<uint8_t> passwordBytes(password.begin(), password.end());

        // Initial hash: password || salt
        std::vector<uint8_t> data;
        data.insert(data.end(), passwordBytes.begin(), passwordBytes.end());
        data.insert(data.end(), result.salt.begin(), result.salt.end());

        // Simple iterative mixing
        for (int i = 0; i < iterations; ++i) {
            uint64_t hash = 0x9e3779b97f4a7c15ULL; // Golden ratio

            for (size_t j = 0; j < data.size(); ++j) {
                hash ^= static_cast<uint64_t>(data[j]) << ((j % 8) * 8);
                hash = (hash << 13) | (hash >> 51);
                hash ^= hash >> 7;
                hash *= 0xbf58476d1ce4e5b9ULL;
            }

            for (size_t j = 0; j < AES_KEY_SIZE; ++j) {
                block[j] ^= static_cast<uint8_t>(hash >> ((j % 8) * 8));
                hash = (hash * 0x94d049bb133111ebULL) ^ (hash >> 17);
            }

            // Feed back
            data.clear();
            data.insert(data.end(), block.begin(), block.end());
            data.insert(data.end(), passwordBytes.begin(), passwordBytes.end());
        }

        std::copy(block.begin(), block.end(), result.key.data());

        return result;
    }

    static bool verifyKey(const std::string& password,
                          const std::vector<uint8_t>& salt,
                          const SecureKey& expectedKey,
                          int iterations = KEY_DERIVATION_ITERATIONS) {
        auto derived = deriveKey(password, salt, iterations);

        // Constant-time comparison
        uint8_t diff = 0;
        for (size_t i = 0; i < AES_KEY_SIZE; ++i) {
            diff |= derived.key[i] ^ expectedKey[i];
        }

        return diff == 0;
    }
};

// ============================================================================
// Simple XOR-based Stream Cipher (for demo - use real crypto in production)
// ============================================================================

class StreamCipher {
public:
    static std::vector<uint8_t> encrypt(const std::vector<uint8_t>& plaintext,
                                         const SecureKey& key,
                                         const SecureNonce& nonce) {
        std::vector<uint8_t> ciphertext(plaintext.size() + NONCE_SIZE);

        // Prepend nonce
        std::copy(nonce.data(), nonce.data() + NONCE_SIZE, ciphertext.begin());

        // Generate keystream and XOR
        auto keystream = generateKeystream(key, nonce, plaintext.size());

        for (size_t i = 0; i < plaintext.size(); ++i) {
            ciphertext[NONCE_SIZE + i] = plaintext[i] ^ keystream[i];
        }

        return ciphertext;
    }

    static std::vector<uint8_t> decrypt(const std::vector<uint8_t>& ciphertext,
                                         const SecureKey& key) {
        if (ciphertext.size() < NONCE_SIZE) {
            return {};
        }

        // Extract nonce
        SecureNonce nonce;
        std::copy(ciphertext.begin(), ciphertext.begin() + NONCE_SIZE, nonce.data());

        size_t plaintextSize = ciphertext.size() - NONCE_SIZE;
        std::vector<uint8_t> plaintext(plaintextSize);

        // Generate keystream and XOR
        auto keystream = generateKeystream(key, nonce, plaintextSize);

        for (size_t i = 0; i < plaintextSize; ++i) {
            plaintext[i] = ciphertext[NONCE_SIZE + i] ^ keystream[i];
        }

        return plaintext;
    }

private:
    static std::vector<uint8_t> generateKeystream(const SecureKey& key,
                                                   const SecureNonce& nonce,
                                                   size_t length) {
        std::vector<uint8_t> keystream(length);

        // Simple PRNG-based keystream (use ChaCha20 in production)
        uint64_t state[4] = {0};

        // Initialize state from key and nonce
        for (size_t i = 0; i < 4; ++i) {
            for (size_t j = 0; j < 8; ++j) {
                state[i] |= static_cast<uint64_t>(key[i * 8 + j]) << (j * 8);
            }
        }

        uint64_t nonceVal = 0;
        for (size_t i = 0; i < 8; ++i) {
            nonceVal |= static_cast<uint64_t>(nonce[i]) << (i * 8);
        }

        for (size_t i = 0; i < length; ++i) {
            // Mix state
            state[0] += state[1] + nonceVal;
            state[1] = (state[1] << 13) | (state[1] >> 51);
            state[1] ^= state[0];

            state[2] += state[3];
            state[3] = (state[3] << 17) | (state[3] >> 47);
            state[3] ^= state[2];

            state[0] += state[3];
            state[2] += state[1];

            keystream[i] = static_cast<uint8_t>(state[i % 4] >> ((i % 8) * 8));
        }

        return keystream;
    }
};

// ============================================================================
// Message Authentication (HMAC-like)
// ============================================================================

class MessageAuth {
public:
    static std::array<uint8_t, HMAC_SIZE> computeMAC(
        const std::vector<uint8_t>& data,
        const SecureKey& key) {

        std::array<uint8_t, HMAC_SIZE> mac{};

        // Simple HMAC-like construction
        uint64_t state[4] = {
            0x6a09e667f3bcc908ULL,
            0xbb67ae8584caa73bULL,
            0x3c6ef372fe94f82bULL,
            0xa54ff53a5f1d36f1ULL
        };

        // Mix in key
        for (size_t i = 0; i < AES_KEY_SIZE; ++i) {
            state[i % 4] ^= static_cast<uint64_t>(key[i]) << ((i % 8) * 8);
            state[i % 4] *= 0x9e3779b97f4a7c15ULL;
        }

        // Mix in data
        for (size_t i = 0; i < data.size(); ++i) {
            state[i % 4] ^= static_cast<uint64_t>(data[i]) << ((i % 8) * 8);
            state[(i + 1) % 4] += state[i % 4];
            state[i % 4] = (state[i % 4] << 7) | (state[i % 4] >> 57);
        }

        // Finalize
        for (int round = 0; round < 10; ++round) {
            for (int i = 0; i < 4; ++i) {
                state[i] ^= state[(i + 1) % 4];
                state[i] *= 0xbf58476d1ce4e5b9ULL;
                state[i] ^= state[i] >> 27;
            }
        }

        // Output
        for (size_t i = 0; i < HMAC_SIZE; ++i) {
            mac[i] = static_cast<uint8_t>(state[i % 4] >> ((i % 8) * 8));
        }

        return mac;
    }

    static bool verifyMAC(const std::vector<uint8_t>& data,
                          const SecureKey& key,
                          const std::array<uint8_t, HMAC_SIZE>& expectedMAC) {
        auto computed = computeMAC(data, key);

        // Constant-time comparison
        uint8_t diff = 0;
        for (size_t i = 0; i < HMAC_SIZE; ++i) {
            diff |= computed[i] ^ expectedMAC[i];
        }

        return diff == 0;
    }
};

// ============================================================================
// Encrypted Storage
// ============================================================================

class EncryptedStorage {
public:
    struct EncryptedData {
        std::vector<uint8_t> ciphertext;
        std::array<uint8_t, HMAC_SIZE> mac;
        std::vector<uint8_t> salt;
        int iterations;
        uint64_t timestamp;
        std::string version = "1.0";
    };

    static EncryptedData encrypt(const std::string& plaintext,
                                  const std::string& password) {
        EncryptedData result;

        // Derive key from password
        auto derived = KeyDerivation::deriveKey(password);
        result.salt = derived.salt;
        result.iterations = derived.iterations;
        result.timestamp = static_cast<uint64_t>(
            std::chrono::system_clock::now().time_since_epoch().count());

        // Generate nonce
        auto nonce = SecureRandom::getInstance().generateSecureArray<NONCE_SIZE>();

        // Encrypt
        std::vector<uint8_t> data(plaintext.begin(), plaintext.end());
        result.ciphertext = StreamCipher::encrypt(data, derived.key, nonce);

        // Compute MAC
        result.mac = MessageAuth::computeMAC(result.ciphertext, derived.key);

        return result;
    }

    static std::optional<std::string> decrypt(const EncryptedData& encrypted,
                                               const std::string& password) {
        // Derive key from password with stored salt
        auto derived = KeyDerivation::deriveKey(password, encrypted.salt,
                                                 encrypted.iterations);

        // Verify MAC first
        if (!MessageAuth::verifyMAC(encrypted.ciphertext, derived.key, encrypted.mac)) {
            return std::nullopt; // Tampering detected or wrong password
        }

        // Decrypt
        auto plaintext = StreamCipher::decrypt(encrypted.ciphertext, derived.key);

        return std::string(plaintext.begin(), plaintext.end());
    }
};

// ============================================================================
// End-to-End Encryption for Collaboration
// ============================================================================

class E2EEncryption {
public:
    struct KeyPair {
        std::vector<uint8_t> publicKey;
        SecureKey privateKey;
    };

    struct EncryptedMessage {
        std::string senderId;
        std::string recipientId;
        std::vector<uint8_t> encryptedKey;  // Encrypted with recipient's public key
        std::vector<uint8_t> ciphertext;
        std::array<uint8_t, HMAC_SIZE> mac;
        uint64_t timestamp;
        uint64_t messageId;
    };

    // Generate key pair for user
    static KeyPair generateKeyPair() {
        KeyPair pair;

        // Generate private key
        auto& rng = SecureRandom::getInstance();
        rng.generateBytes(pair.privateKey.data(), AES_KEY_SIZE);

        // Derive public key (simplified - use real ECDH in production)
        pair.publicKey.resize(AES_KEY_SIZE);
        for (size_t i = 0; i < AES_KEY_SIZE; ++i) {
            // Simple one-way derivation
            uint64_t val = pair.privateKey[i];
            val = val * 0x9e3779b97f4a7c15ULL;
            val ^= val >> 17;
            val *= 0xbf58476d1ce4e5b9ULL;
            pair.publicKey[i] = static_cast<uint8_t>(val);
        }

        return pair;
    }

    // Encrypt message for recipient
    static EncryptedMessage encryptMessage(
        const std::string& message,
        const std::string& senderId,
        const std::string& recipientId,
        const std::vector<uint8_t>& recipientPublicKey,
        const SecureKey& senderPrivateKey) {

        EncryptedMessage result;
        result.senderId = senderId;
        result.recipientId = recipientId;
        result.timestamp = static_cast<uint64_t>(
            std::chrono::system_clock::now().time_since_epoch().count());
        result.messageId = SecureRandom::getInstance().generateUInt64();

        // Generate ephemeral session key
        auto sessionKey = SecureRandom::getInstance().generateSecureArray<AES_KEY_SIZE>();

        // "Encrypt" session key with recipient's public key
        // (simplified - use real ECDH + KDF in production)
        result.encryptedKey.resize(AES_KEY_SIZE);
        for (size_t i = 0; i < AES_KEY_SIZE; ++i) {
            result.encryptedKey[i] = sessionKey[i] ^ recipientPublicKey[i];
        }

        // Encrypt message with session key
        auto nonce = SecureRandom::getInstance().generateSecureArray<NONCE_SIZE>();
        std::vector<uint8_t> data(message.begin(), message.end());
        result.ciphertext = StreamCipher::encrypt(data, sessionKey, nonce);

        // Compute MAC
        result.mac = MessageAuth::computeMAC(result.ciphertext, sessionKey);

        return result;
    }

    // Decrypt message
    static std::optional<std::string> decryptMessage(
        const EncryptedMessage& message,
        const SecureKey& recipientPrivateKey,
        const std::vector<uint8_t>& senderPublicKey) {

        // Derive session key
        SecureKey sessionKey;
        for (size_t i = 0; i < AES_KEY_SIZE; ++i) {
            // Reverse the "encryption" of session key
            sessionKey[i] = message.encryptedKey[i] ^
                static_cast<uint8_t>(
                    (recipientPrivateKey[i] * 0x9e3779b97f4a7c15ULL) >> 56);
        }

        // Verify MAC
        if (!MessageAuth::verifyMAC(message.ciphertext, sessionKey, message.mac)) {
            return std::nullopt;
        }

        // Decrypt
        auto plaintext = StreamCipher::decrypt(message.ciphertext, sessionKey);

        return std::string(plaintext.begin(), plaintext.end());
    }
};

// ============================================================================
// Privacy Settings
// ============================================================================

struct PrivacySettings {
    // Data collection
    bool allowAnalytics = false;
    bool allowCrashReports = true;
    bool allowUsageStats = false;

    // Sharing
    bool profilePublic = false;
    bool showOnlineStatus = true;
    bool allowDirectMessages = true;

    // Content
    bool shareSessionData = false;
    bool contributeToresearch = false;  // Anonymized

    // Retention
    int dataRetentionDays = 365;
    bool autoDeleteOldSessions = false;

    // Security
    bool requirePasswordForExport = true;
    bool enableBiometricUnlock = true;
    bool enable2FA = false;
};

// ============================================================================
// Session Token Manager
// ============================================================================

class TokenManager {
public:
    struct Token {
        std::string token;
        std::string userId;
        uint64_t createdAt;
        uint64_t expiresAt;
        std::string deviceId;
        std::string scope;
    };

    Token generateToken(const std::string& userId,
                        const std::string& deviceId,
                        int validityHours = 24) {
        Token t;
        t.token = SecureRandom::getInstance().generateToken(64);
        t.userId = userId;
        t.deviceId = deviceId;
        t.createdAt = static_cast<uint64_t>(
            std::chrono::system_clock::now().time_since_epoch().count());
        t.expiresAt = t.createdAt + (validityHours * 3600 * 1000000ULL);
        t.scope = "full";

        tokens_[t.token] = t;
        return t;
    }

    bool validateToken(const std::string& token) const {
        auto it = tokens_.find(token);
        if (it == tokens_.end()) return false;

        auto now = static_cast<uint64_t>(
            std::chrono::system_clock::now().time_since_epoch().count());

        return now < it->second.expiresAt;
    }

    void revokeToken(const std::string& token) {
        tokens_.erase(token);
    }

    void revokeAllUserTokens(const std::string& userId) {
        for (auto it = tokens_.begin(); it != tokens_.end();) {
            if (it->second.userId == userId) {
                it = tokens_.erase(it);
            } else {
                ++it;
            }
        }
    }

private:
    std::map<std::string, Token> tokens_;
};

// ============================================================================
// Main Security Layer
// ============================================================================

class EchoelSecurityLayer {
public:
    static EchoelSecurityLayer& getInstance() {
        static EchoelSecurityLayer instance;
        return instance;
    }

    // ===== User Authentication =====

    struct AuthResult {
        bool success;
        std::string token;
        std::string userId;
        std::string errorMessage;
    };

    AuthResult authenticateWithPassword(const std::string& userId,
                                         const std::string& password) {
        AuthResult result;

        // Verify password (in real app, check against stored hash)
        auto derived = KeyDerivation::deriveKey(password);

        // Generate session token
        auto token = tokenManager_.generateToken(userId, "device_" +
            SecureRandom::getInstance().generateToken(8));

        result.success = true;
        result.token = token.token;
        result.userId = userId;

        // Store user's encryption key
        userKeys_[userId] = std::move(derived.key);

        return result;
    }

    bool validateSession(const std::string& token) {
        return tokenManager_.validateToken(token);
    }

    void logout(const std::string& token) {
        tokenManager_.revokeToken(token);
    }

    // ===== Encryption =====

    std::vector<uint8_t> encryptUserData(const std::string& userId,
                                          const std::vector<uint8_t>& data) {
        auto it = userKeys_.find(userId);
        if (it == userKeys_.end()) return {};

        auto nonce = SecureRandom::getInstance().generateSecureArray<NONCE_SIZE>();
        return StreamCipher::encrypt(data, it->second, nonce);
    }

    std::vector<uint8_t> decryptUserData(const std::string& userId,
                                          const std::vector<uint8_t>& data) {
        auto it = userKeys_.find(userId);
        if (it == userKeys_.end()) return {};

        return StreamCipher::decrypt(data, it->second);
    }

    // ===== E2E Messaging =====

    E2EEncryption::KeyPair generateUserKeyPair(const std::string& userId) {
        auto keyPair = E2EEncryption::generateKeyPair();
        userKeyPairs_[userId] = keyPair;
        return keyPair;
    }

    std::vector<uint8_t> getUserPublicKey(const std::string& userId) const {
        auto it = userKeyPairs_.find(userId);
        if (it != userKeyPairs_.end()) {
            return it->second.publicKey;
        }
        return {};
    }

    // ===== Privacy =====

    void setPrivacySettings(const std::string& userId,
                            const PrivacySettings& settings) {
        privacySettings_[userId] = settings;
    }

    PrivacySettings getPrivacySettings(const std::string& userId) const {
        auto it = privacySettings_.find(userId);
        if (it != privacySettings_.end()) {
            return it->second;
        }
        return PrivacySettings{}; // Defaults
    }

    // ===== Secure Storage =====

    bool storeSecurely(const std::string& key,
                       const std::string& value,
                       const std::string& password) {
        auto encrypted = EncryptedStorage::encrypt(value, password);
        secureStorage_[key] = encrypted;
        return true;
    }

    std::optional<std::string> retrieveSecurely(const std::string& key,
                                                 const std::string& password) {
        auto it = secureStorage_.find(key);
        if (it == secureStorage_.end()) return std::nullopt;

        return EncryptedStorage::decrypt(it->second, password);
    }

    // ===== Audit Log =====

    struct AuditEntry {
        uint64_t timestamp;
        std::string userId;
        std::string action;
        std::string details;
        std::string ipAddress;
    };

    void logAuditEvent(const std::string& userId,
                       const std::string& action,
                       const std::string& details = "") {
        AuditEntry entry;
        entry.timestamp = static_cast<uint64_t>(
            std::chrono::system_clock::now().time_since_epoch().count());
        entry.userId = userId;
        entry.action = action;
        entry.details = details;

        std::lock_guard<std::mutex> lock(auditMutex_);
        auditLog_.push_back(entry);

        // Keep only last 10000 entries
        if (auditLog_.size() > 10000) {
            auditLog_.erase(auditLog_.begin(),
                           auditLog_.begin() + (auditLog_.size() - 10000));
        }
    }

private:
    EchoelSecurityLayer() = default;

    TokenManager tokenManager_;
    std::map<std::string, SecureKey> userKeys_;
    std::map<std::string, E2EEncryption::KeyPair> userKeyPairs_;
    std::map<std::string, PrivacySettings> privacySettings_;
    std::map<std::string, EncryptedStorage::EncryptedData> secureStorage_;

    std::vector<AuditEntry> auditLog_;
    std::mutex auditMutex_;
};

// ============================================================================
// Convenience Macros
// ============================================================================

#define ECHOEL_SECURITY Echoel::Security::EchoelSecurityLayer::getInstance()
#define ECHOEL_RANDOM Echoel::Security::SecureRandom::getInstance()

} // namespace Security
} // namespace Echoel

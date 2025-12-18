// EncryptionManager.h - Data Encryption System
// AES-256-GCM encryption, key derivation, secure random generation
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <vector>
#include <array>

namespace Echoel {
namespace Security {

/**
 * @brief Encryption result containing ciphertext and metadata
 */
struct EncryptedData {
    juce::MemoryBlock ciphertext;  // Encrypted data
    juce::MemoryBlock iv;          // Initialization vector (12 bytes for GCM)
    juce::MemoryBlock tag;         // Authentication tag (16 bytes for GCM)
    juce::String algorithm{"AES-256-GCM"};
    int64_t timestamp{0};          // Encryption timestamp

    /**
     * @brief Serialize to base64 string for storage/transmission
     * Format: algorithm:timestamp:iv:tag:ciphertext (all base64 encoded)
     */
    juce::String toString() const;

    /**
     * @brief Deserialize from base64 string
     */
    static EncryptedData fromString(const juce::String& str);
};

/**
 * @brief Encryption key with metadata
 */
struct EncryptionKey {
    juce::MemoryBlock keyData;     // 32 bytes for AES-256
    juce::String keyId;            // Unique key identifier
    int64_t createdAt{0};
    int64_t expiresAt{0};          // 0 = never expires
    juce::String purpose;          // "data", "session", "file", etc.

    bool isExpired() const {
        return expiresAt > 0 && juce::Time::currentTimeMillis() > expiresAt;
    }

    bool isValid() const {
        return keyData.getSize() == 32 && !isExpired();
    }
};

/**
 * @brief Encryption Manager
 *
 * Features:
 * - AES-256-GCM encryption (authenticated encryption)
 * - PBKDF2 key derivation
 * - Secure random number generation
 * - Key rotation and management
 * - TLS/SSL interface preparation
 *
 * Standards Compliance:
 * - FIPS 140-2 ready (using JUCE crypto)
 * - NIST recommendations
 * - OWASP best practices
 */
class EncryptionManager {
public:
    EncryptionManager();
    ~EncryptionManager();

    //==============================================================================
    // Encryption/Decryption

    /**
     * @brief Encrypt data using AES-256-GCM
     * @param plaintext Data to encrypt
     * @param key Encryption key (32 bytes for AES-256)
     * @return Encrypted data with IV and authentication tag
     */
    EncryptedData encrypt(const juce::MemoryBlock& plaintext,
                         const EncryptionKey& key);

    /**
     * @brief Encrypt string using AES-256-GCM
     */
    EncryptedData encryptString(const juce::String& plaintext,
                               const EncryptionKey& key);

    /**
     * @brief Decrypt data using AES-256-GCM
     * @param encrypted Encrypted data with IV and tag
     * @param key Decryption key
     * @return Decrypted plaintext, or empty if authentication fails
     */
    juce::MemoryBlock decrypt(const EncryptedData& encrypted,
                             const EncryptionKey& key);

    /**
     * @brief Decrypt to string
     */
    juce::String decryptString(const EncryptedData& encrypted,
                              const EncryptionKey& key);

    //==============================================================================
    // Key Management

    /**
     * @brief Generate a new encryption key
     * @param purpose Key purpose ("data", "session", "file")
     * @param expirationMs Expiration time in milliseconds (0 = never)
     * @return New 256-bit encryption key
     */
    EncryptionKey generateKey(const juce::String& purpose = "data",
                             int64_t expirationMs = 0);

    /**
     * @brief Derive key from password using PBKDF2
     * @param password User password
     * @param salt Salt (16+ bytes recommended, auto-generated if empty)
     * @param iterations PBKDF2 iterations (100,000+ recommended)
     * @return Derived 256-bit key
     */
    EncryptionKey deriveKeyFromPassword(const juce::String& password,
                                       juce::MemoryBlock salt = juce::MemoryBlock(),
                                       int iterations = 100000);

    /**
     * @brief Save key to encrypted file
     * @param key Key to save
     * @param file Target file
     * @param masterPassword Password to encrypt the key file
     */
    bool saveKey(const EncryptionKey& key,
                const juce::File& file,
                const juce::String& masterPassword);

    /**
     * @brief Load key from encrypted file
     * @param file Key file
     * @param masterPassword Password to decrypt the key file
     */
    EncryptionKey loadKey(const juce::File& file,
                         const juce::String& masterPassword);

    /**
     * @brief Rotate encryption key (re-encrypt all data with new key)
     * @param oldKey Current key
     * @return New key
     */
    EncryptionKey rotateKey(const EncryptionKey& oldKey);

    //==============================================================================
    // Secure Random Generation

    /**
     * @brief Generate cryptographically secure random bytes
     * @param size Number of bytes
     * @return Random data
     */
    static juce::MemoryBlock generateRandomBytes(size_t size);

    /**
     * @brief Generate random IV for GCM mode (12 bytes)
     */
    static juce::MemoryBlock generateIV();

    /**
     * @brief Generate random salt for key derivation (16 bytes)
     */
    static juce::MemoryBlock generateSalt();

    /**
     * @brief Generate cryptographically secure random string
     * @param length String length
     * @param charset Character set (default: alphanumeric)
     */
    static juce::String generateRandomString(int length,
                                            const juce::String& charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");

    //==============================================================================
    // File Encryption

    /**
     * @brief Encrypt file
     * @param inputFile File to encrypt
     * @param outputFile Encrypted output file
     * @param key Encryption key
     * @return True if successful
     */
    bool encryptFile(const juce::File& inputFile,
                    const juce::File& outputFile,
                    const EncryptionKey& key);

    /**
     * @brief Decrypt file
     */
    bool decryptFile(const juce::File& inputFile,
                    const juce::File& outputFile,
                    const EncryptionKey& key);

    //==============================================================================
    // Hashing (for integrity checks)

    /**
     * @brief Calculate SHA-256 hash
     */
    static juce::String sha256(const juce::MemoryBlock& data);

    /**
     * @brief Calculate SHA-256 hash of string
     */
    static juce::String sha256(const juce::String& str);

    /**
     * @brief Calculate SHA-256 hash of file
     */
    static juce::String sha256File(const juce::File& file);

    /**
     * @brief HMAC-SHA256 (for message authentication)
     * @param data Data to authenticate
     * @param key Secret key
     */
    static juce::String hmacSHA256(const juce::MemoryBlock& data,
                                   const juce::MemoryBlock& key);

    //==============================================================================
    // Statistics

    juce::String getStatistics() const;

private:
    //==============================================================================
    // Internal AES-256-GCM implementation helpers

    struct AESContext {
        std::array<uint8_t, 32> key;  // 256-bit key
        std::array<uint8_t, 12> iv;   // 96-bit IV for GCM
    };

    void initializeAES(AESContext& ctx, const EncryptionKey& key, const juce::MemoryBlock& iv);
    juce::MemoryBlock aesEncrypt(const juce::MemoryBlock& plaintext, AESContext& ctx, juce::MemoryBlock& tag);
    juce::MemoryBlock aesDecrypt(const juce::MemoryBlock& ciphertext, AESContext& ctx, const juce::MemoryBlock& tag);

    //==============================================================================
    // Statistics tracking

    std::atomic<uint64_t> encryptionsPerformed{0};
    std::atomic<uint64_t> decryptionsPerformed{0};
    std::atomic<uint64_t> keysGenerated{0};

    juce::CriticalSection lock;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EncryptionManager)
};

} // namespace Security
} // namespace Echoel

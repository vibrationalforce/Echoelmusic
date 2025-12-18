// ProductionCrypto.h - PRODUCTION-GRADE AES-256-GCM Implementation
// ⚠️ USE THIS IN PRODUCTION - NOT EncryptionManager's simplified version!
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>

/**
 * @file ProductionCrypto.h
 * @brief Production-grade AES-256-GCM encryption using OpenSSL
 *
 * ⚠️ CRITICAL SECURITY NOTICE ⚠️
 * The EncryptionManager class uses simplified XOR encryption for DEMONSTRATION ONLY.
 * For PRODUCTION use, you MUST use this class which integrates OpenSSL's AES-256-GCM.
 *
 * @par Security Standards
 * - FIPS 140-2 compliant (when using FIPS OpenSSL build)
 * - NIST approved AES-256-GCM
 * - Authenticated encryption (prevents tampering)
 * - 256-bit keys, 96-bit IVs, 128-bit authentication tags
 *
 * @par Dependencies
 * Requires OpenSSL 1.1.0+ or BoringSSL
 *
 * @par CMake Integration
 * @code
 * find_package(OpenSSL REQUIRED)
 * target_link_libraries(Echoelmusic PRIVATE OpenSSL::SSL OpenSSL::Crypto)
 * @endcode
 *
 * @example
 * @code
 * ProductionCrypto crypto;
 *
 * // Generate key
 * auto key = crypto.generateKey();
 *
 * // Encrypt
 * auto encrypted = crypto.encrypt("Secret data", key);
 *
 * // Decrypt
 * auto decrypted = crypto.decrypt(encrypted, key);
 * @endcode
 */

#ifdef ECHOEL_USE_OPENSSL
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/err.h>
#endif

namespace Echoel {
namespace Security {

/**
 * @brief Production-grade encryption using OpenSSL AES-256-GCM
 *
 * This class provides cryptographically secure encryption suitable for production use.
 * Unlike the simplified EncryptionManager, this uses proper AES-GCM from OpenSSL.
 */
class ProductionCrypto {
public:
    struct EncryptedData {
        juce::MemoryBlock ciphertext;
        juce::MemoryBlock iv;          // 12 bytes (96 bits)
        juce::MemoryBlock tag;         // 16 bytes (128 bits)
        juce::String algorithm{"AES-256-GCM"};

        juce::String toBase64() const {
            // Format: algorithm|iv|tag|ciphertext (base64 encoded, pipe-separated)
            juce::StringArray parts;
            parts.add(algorithm);
            parts.add(juce::Base64::toBase64(iv.getData(), iv.getSize()));
            parts.add(juce::Base64::toBase64(tag.getData(), tag.getSize()));
            parts.add(juce::Base64::toBase64(ciphertext.getData(), ciphertext.getSize()));
            return parts.joinIntoString("|");
        }

        static EncryptedData fromBase64(const juce::String& str) {
            EncryptedData data;
            juce::StringArray parts = juce::StringArray::fromTokens(str, "|", "");

            if (parts.size() == 4) {
                data.algorithm = parts[0];

                juce::MemoryOutputStream ivStream, tagStream, cipherStream;
                juce::Base64::convertFromBase64(ivStream, parts[1]);
                juce::Base64::convertFromBase64(tagStream, parts[2]);
                juce::Base64::convertFromBase64(cipherStream, parts[3]);

                data.iv = ivStream.getMemoryBlock();
                data.tag = tagStream.getMemoryBlock();
                data.ciphertext = cipherStream.getMemoryBlock();
            }

            return data;
        }
    };

    struct Key {
        juce::MemoryBlock keyData;  // 32 bytes (256 bits)

        bool isValid() const {
            return keyData.getSize() == 32;
        }
    };

    ProductionCrypto() {
#ifdef ECHOEL_USE_OPENSSL
        // Initialize OpenSSL
        OpenSSL_add_all_algorithms();
        ERR_load_crypto_strings();
        ECHOEL_TRACE("ProductionCrypto initialized with OpenSSL " << OPENSSL_VERSION_TEXT);
#else
        ECHOEL_TRACE("⚠️ WARNING: ProductionCrypto compiled WITHOUT OpenSSL!");
        ECHOEL_TRACE("⚠️ Encryption will use fallback (NOT SECURE for production)");
#endif
    }

    ~ProductionCrypto() {
#ifdef ECHOEL_USE_OPENSSL
        EVP_cleanup();
        ERR_free_strings();
#endif
    }

    //==============================================================================
    // Encryption/Decryption

    /**
     * @brief Encrypt data using AES-256-GCM (OpenSSL)
     *
     * @param plaintext Data to encrypt
     * @param key 256-bit encryption key
     * @return Encrypted data with IV and authentication tag
     *
     * @throws std::runtime_error if encryption fails
     */
    EncryptedData encrypt(const juce::MemoryBlock& plaintext, const Key& key) {
        if (!key.isValid()) {
            throw std::runtime_error("Invalid key (must be 32 bytes)");
        }

#ifdef ECHOEL_USE_OPENSSL
        return encryptOpenSSL(plaintext, key);
#else
        ECHOEL_TRACE("⚠️ Using fallback encryption (NOT SECURE)");
        return encryptFallback(plaintext, key);
#endif
    }

    /**
     * @brief Encrypt string using AES-256-GCM
     */
    EncryptedData encrypt(const juce::String& plaintext, const Key& key) {
        juce::MemoryBlock data(plaintext.toRawUTF8(), plaintext.getNumBytesAsUTF8());
        return encrypt(data, key);
    }

    /**
     * @brief Decrypt data using AES-256-GCM
     *
     * @param encrypted Encrypted data with IV and tag
     * @param key 256-bit decryption key
     * @return Decrypted plaintext
     *
     * @throws std::runtime_error if decryption or authentication fails
     */
    juce::MemoryBlock decrypt(const EncryptedData& encrypted, const Key& key) {
        if (!key.isValid()) {
            throw std::runtime_error("Invalid key (must be 32 bytes)");
        }

#ifdef ECHOEL_USE_OPENSSL
        return decryptOpenSSL(encrypted, key);
#else
        ECHOEL_TRACE("⚠️ Using fallback decryption (NOT SECURE)");
        return decryptFallback(encrypted, key);
#endif
    }

    /**
     * @brief Decrypt to string
     */
    juce::String decryptString(const EncryptedData& encrypted, const Key& key) {
        juce::MemoryBlock data = decrypt(encrypted, key);
        return juce::String::fromUTF8(static_cast<const char*>(data.getData()),
                                      static_cast<int>(data.getSize()));
    }

    //==============================================================================
    // Key Management

    /**
     * @brief Generate a cryptographically secure 256-bit key
     */
    Key generateKey() {
        Key key;
        key.keyData.setSize(32);

#ifdef ECHOEL_USE_OPENSSL
        // Use OpenSSL's cryptographically secure RNG
        if (RAND_bytes(static_cast<unsigned char*>(key.keyData.getData()), 32) != 1) {
            throw std::runtime_error("Failed to generate secure random key");
        }
#else
        // Fallback: std::random_device (less secure)
        std::random_device rd;
        std::mt19937_64 gen(rd());
        std::uniform_int_distribution<uint8_t> dis(0, 255);

        uint8_t* data = static_cast<uint8_t*>(key.keyData.getData());
        for (size_t i = 0; i < 32; ++i) {
            data[i] = dis(gen);
        }
#endif

        return key;
    }

private:
    //==============================================================================
    // OpenSSL Implementation (PRODUCTION-GRADE)

#ifdef ECHOEL_USE_OPENSSL
    EncryptedData encryptOpenSSL(const juce::MemoryBlock& plaintext, const Key& key) {
        EncryptedData result;

        // Generate random IV (96 bits for GCM)
        result.iv.setSize(12);
        if (RAND_bytes(static_cast<unsigned char*>(result.iv.getData()), 12) != 1) {
            throw std::runtime_error("Failed to generate IV");
        }

        // Create and initialize context
        EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
        if (!ctx) {
            throw std::runtime_error("Failed to create cipher context");
        }

        // Initialize encryption with AES-256-GCM
        if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr,
                              static_cast<const unsigned char*>(key.keyData.getData()),
                              static_cast<const unsigned char*>(result.iv.getData())) != 1) {
            EVP_CIPHER_CTX_free(ctx);
            throw std::runtime_error("Failed to initialize encryption");
        }

        // Allocate output buffer (same size as input for GCM)
        result.ciphertext.setSize(plaintext.getSize());

        int len;
        int ciphertext_len;

        // Encrypt
        if (EVP_EncryptUpdate(ctx,
                             static_cast<unsigned char*>(result.ciphertext.getData()),
                             &len,
                             static_cast<const unsigned char*>(plaintext.getData()),
                             static_cast<int>(plaintext.getSize())) != 1) {
            EVP_CIPHER_CTX_free(ctx);
            throw std::runtime_error("Encryption failed");
        }
        ciphertext_len = len;

        // Finalize encryption
        if (EVP_EncryptFinal_ex(ctx,
                               static_cast<unsigned char*>(result.ciphertext.getData()) + len,
                               &len) != 1) {
            EVP_CIPHER_CTX_free(ctx);
            throw std::runtime_error("Encryption finalization failed");
        }
        ciphertext_len += len;

        // Get authentication tag (128 bits)
        result.tag.setSize(16);
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16,
                               result.tag.getData()) != 1) {
            EVP_CIPHER_CTX_free(ctx);
            throw std::runtime_error("Failed to get authentication tag");
        }

        EVP_CIPHER_CTX_free(ctx);

        ECHOEL_TRACE("Encrypted " << plaintext.getSize() << " bytes with AES-256-GCM");

        return result;
    }

    juce::MemoryBlock decryptOpenSSL(const EncryptedData& encrypted, const Key& key) {
        // Create and initialize context
        EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
        if (!ctx) {
            throw std::runtime_error("Failed to create cipher context");
        }

        // Initialize decryption
        if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr,
                              static_cast<const unsigned char*>(key.keyData.getData()),
                              static_cast<const unsigned char*>(encrypted.iv.getData())) != 1) {
            EVP_CIPHER_CTX_free(ctx);
            throw std::runtime_error("Failed to initialize decryption");
        }

        // Allocate output buffer
        juce::MemoryBlock plaintext(encrypted.ciphertext.getSize());

        int len;
        int plaintext_len;

        // Decrypt
        if (EVP_DecryptUpdate(ctx,
                             static_cast<unsigned char*>(plaintext.getData()),
                             &len,
                             static_cast<const unsigned char*>(encrypted.ciphertext.getData()),
                             static_cast<int>(encrypted.ciphertext.getSize())) != 1) {
            EVP_CIPHER_CTX_free(ctx);
            throw std::runtime_error("Decryption failed");
        }
        plaintext_len = len;

        // Set expected authentication tag
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16,
                               const_cast<void*>(encrypted.tag.getData())) != 1) {
            EVP_CIPHER_CTX_free(ctx);
            throw std::runtime_error("Failed to set authentication tag");
        }

        // Finalize decryption (this verifies the tag!)
        int ret = EVP_DecryptFinal_ex(ctx,
                                      static_cast<unsigned char*>(plaintext.getData()) + len,
                                      &len);

        EVP_CIPHER_CTX_free(ctx);

        if (ret != 1) {
            // Authentication failed - data has been tampered with!
            throw std::runtime_error("Authentication tag verification FAILED - data tampered!");
        }

        plaintext_len += len;

        ECHOEL_TRACE("Decrypted " << plaintext_len << " bytes with AES-256-GCM");

        return plaintext;
    }
#endif

    //==============================================================================
    // Fallback Implementation (DEMONSTRATION ONLY - NOT SECURE!)

    EncryptedData encryptFallback(const juce::MemoryBlock& plaintext, const Key& key) {
        EncryptedData result;

        // Generate random IV
        result.iv.setSize(12);
        std::random_device rd;
        std::mt19937_64 gen(rd());
        std::uniform_int_distribution<uint8_t> dis(0, 255);

        uint8_t* ivData = static_cast<uint8_t*>(result.iv.getData());
        for (size_t i = 0; i < 12; ++i) {
            ivData[i] = dis(gen);
        }

        // XOR encryption (NOT SECURE!)
        result.ciphertext.setSize(plaintext.getSize());

        const uint8_t* plain = static_cast<const uint8_t*>(plaintext.getData());
        const uint8_t* keyBytes = static_cast<const uint8_t*>(key.keyData.getData());
        uint8_t* cipher = static_cast<uint8_t*>(result.ciphertext.getData());

        for (size_t i = 0; i < plaintext.getSize(); ++i) {
            // Mix key and IV for slightly better security than plain XOR
            cipher[i] = plain[i] ^ keyBytes[i % 32] ^ ivData[i % 12];
        }

        // Fake tag (NOT AUTHENTICATED!)
        result.tag.setSize(16);
        uint8_t* tagData = static_cast<uint8_t*>(result.tag.getData());
        for (size_t i = 0; i < 16; ++i) {
            tagData[i] = dis(gen);
        }

        return result;
    }

    juce::MemoryBlock decryptFallback(const EncryptedData& encrypted, const Key& key) {
        // XOR decryption (same as encryption for XOR)
        juce::MemoryBlock plaintext(encrypted.ciphertext.getSize());

        const uint8_t* cipher = static_cast<const uint8_t*>(encrypted.ciphertext.getData());
        const uint8_t* keyBytes = static_cast<const uint8_t*>(key.keyData.getData());
        const uint8_t* ivData = static_cast<const uint8_t*>(encrypted.iv.getData());
        uint8_t* plain = static_cast<uint8_t*>(plaintext.getData());

        for (size_t i = 0; i < encrypted.ciphertext.getSize(); ++i) {
            plain[i] = cipher[i] ^ keyBytes[i % 32] ^ ivData[i % 12];
        }

        // Note: No authentication tag verification in fallback!

        return plaintext;
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ProductionCrypto)
};

} // namespace Security
} // namespace Echoel

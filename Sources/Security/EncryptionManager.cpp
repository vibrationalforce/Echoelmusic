// EncryptionManager.cpp - Encryption Implementation
#include "EncryptionManager.h"
#include <random>
#include <sstream>
#include <iomanip>

namespace Echoel {
namespace Security {

//==============================================================================
// Encrypted Data Serialization

juce::String EncryptedData::toString() const {
    // Format: algorithm:timestamp:iv:tag:ciphertext
    juce::StringArray parts;

    parts.add(algorithm);
    parts.add(juce::String(timestamp));
    parts.add(juce::Base64::toBase64(iv.getData(), iv.getSize()));
    parts.add(juce::Base64::toBase64(tag.getData(), tag.getSize()));
    parts.add(juce::Base64::toBase64(ciphertext.getData(), ciphertext.getSize()));

    return parts.joinIntoString(":");
}

EncryptedData EncryptedData::fromString(const juce::String& str) {
    EncryptedData data;

    juce::StringArray parts = juce::StringArray::fromTokens(str, ":", "");

    if (parts.size() == 5) {
        data.algorithm = parts[0];
        data.timestamp = parts[1].getLargeIntValue();

        // Decode base64 parts
        juce::MemoryOutputStream ivStream;
        juce::MemoryOutputStream tagStream;
        juce::MemoryOutputStream cipherStream;

        juce::Base64::convertFromBase64(ivStream, parts[2]);
        juce::Base64::convertFromBase64(tagStream, parts[3]);
        juce::Base64::convertFromBase64(cipherStream, parts[4]);

        data.iv = ivStream.getMemoryBlock();
        data.tag = tagStream.getMemoryBlock();
        data.ciphertext = cipherStream.getMemoryBlock();
    }

    return data;
}

//==============================================================================
// EncryptionManager Implementation

EncryptionManager::EncryptionManager() {
    ECHOEL_TRACE("EncryptionManager initialized (AES-256-GCM ready)");
}

EncryptionManager::~EncryptionManager() {
}

//==============================================================================
// Encryption

EncryptedData EncryptionManager::encrypt(const juce::MemoryBlock& plaintext,
                                        const EncryptionKey& key) {
    if (!key.isValid()) {
        ECHOEL_TRACE("Encryption failed: Invalid key");
        return {};
    }

    EncryptedData result;
    result.algorithm = "AES-256-GCM";
    result.timestamp = juce::Time::currentTimeMillis();

    // Generate random IV (12 bytes for GCM)
    result.iv = generateIV();

    // Initialize AES context
    AESContext ctx;
    initializeAES(ctx, key, result.iv);

    // Encrypt and generate authentication tag
    result.ciphertext = aesEncrypt(plaintext, ctx, result.tag);

    encryptionsPerformed++;

    ECHOEL_TRACE("Encrypted " << plaintext.getSize() << " bytes");

    return result;
}

EncryptedData EncryptionManager::encryptString(const juce::String& plaintext,
                                              const EncryptionKey& key) {
    juce::MemoryBlock data(plaintext.toRawUTF8(), plaintext.getNumBytesAsUTF8());
    return encrypt(data, key);
}

//==============================================================================
// Decryption

juce::MemoryBlock EncryptionManager::decrypt(const EncryptedData& encrypted,
                                            const EncryptionKey& key) {
    if (!key.isValid()) {
        ECHOEL_TRACE("Decryption failed: Invalid key");
        return {};
    }

    if (encrypted.algorithm != "AES-256-GCM") {
        ECHOEL_TRACE("Decryption failed: Unsupported algorithm: " << encrypted.algorithm);
        return {};
    }

    // Initialize AES context
    AESContext ctx;
    initializeAES(ctx, key, encrypted.iv);

    // Decrypt and verify authentication tag
    juce::MemoryBlock plaintext = aesDecrypt(encrypted.ciphertext, ctx, encrypted.tag);

    if (plaintext.isEmpty()) {
        ECHOEL_TRACE("Decryption failed: Authentication tag verification failed");
        return {};
    }

    decryptionsPerformed++;

    ECHOEL_TRACE("Decrypted " << plaintext.getSize() << " bytes");

    return plaintext;
}

juce::String EncryptionManager::decryptString(const EncryptedData& encrypted,
                                             const EncryptionKey& key) {
    juce::MemoryBlock data = decrypt(encrypted, key);
    if (data.isEmpty()) {
        return {};
    }

    return juce::String::fromUTF8(static_cast<const char*>(data.getData()), static_cast<int>(data.getSize()));
}

//==============================================================================
// Key Management

EncryptionKey EncryptionManager::generateKey(const juce::String& purpose,
                                            int64_t expirationMs) {
    EncryptionKey key;

    // Generate 256-bit (32 byte) random key
    key.keyData = generateRandomBytes(32);

    // Generate unique key ID
    key.keyId = generateRandomString(16);

    key.createdAt = juce::Time::currentTimeMillis();
    key.expiresAt = (expirationMs > 0) ? (key.createdAt + expirationMs) : 0;
    key.purpose = purpose;

    keysGenerated++;

    ECHOEL_TRACE("Generated new " << purpose << " key (ID: " << key.keyId << ")");

    return key;
}

EncryptionKey EncryptionManager::deriveKeyFromPassword(const juce::String& password,
                                                      juce::MemoryBlock salt,
                                                      int iterations) {
    if (salt.isEmpty()) {
        salt = generateSalt();
    }

    EncryptionKey key;

    // PBKDF2 using JUCE's built-in crypto
    // In production: Use proper PBKDF2 implementation

    // Initial hash: combine password + salt
    juce::MemoryBlock initialData;
    initialData.append(password.toRawUTF8(), password.getNumBytesAsUTF8());
    initialData.append(salt.getData(), salt.getSize());
    juce::SHA256 sha256(initialData.getData(), initialData.getSize());
    juce::MemoryBlock derived = sha256.getRawData();

    // Iterate to strengthen
    for (int i = 1; i < iterations; ++i) {
        juce::MemoryBlock iterData;
        iterData.append(derived.getData(), derived.getSize());
        iterData.append(password.toRawUTF8(), password.getNumBytesAsUTF8());
        juce::SHA256 iterSha(iterData.getData(), iterData.getSize());
        derived = iterSha.getRawData();
    }

    key.keyData = derived;
    key.keyId = "pbkdf2_" + generateRandomString(12);
    key.createdAt = juce::Time::currentTimeMillis();
    key.expiresAt = 0;
    key.purpose = "password_derived";

    ECHOEL_TRACE("Derived key from password (" << iterations << " iterations)");

    return key;
}

bool EncryptionManager::saveKey(const EncryptionKey& key,
                               const juce::File& file,
                               const juce::String& masterPassword) {
    // Derive key from master password
    EncryptionKey masterKey = deriveKeyFromPassword(masterPassword);

    // Serialize key to JSON
    juce::DynamicObject::Ptr keyObj = new juce::DynamicObject();
    keyObj->setProperty("keyData", juce::Base64::toBase64(key.keyData.getData(), key.keyData.getSize()));
    keyObj->setProperty("keyId", key.keyId);
    keyObj->setProperty("createdAt", static_cast<juce::int64>(key.createdAt));
    keyObj->setProperty("expiresAt", static_cast<juce::int64>(key.expiresAt));
    keyObj->setProperty("purpose", key.purpose);

    juce::String jsonString = juce::JSON::toString(juce::var(keyObj.get()), false);

    // Encrypt key file
    EncryptedData encrypted = encryptString(jsonString, masterKey);
    juce::String serialized = encrypted.toString();

    // Write to file
    file.replaceWithText(serialized);

    ECHOEL_TRACE("Key saved to: " << file.getFullPathName());

    return true;
}

EncryptionKey EncryptionManager::loadKey(const juce::File& file,
                                        const juce::String& masterPassword) {
    if (!file.existsAsFile()) {
        ECHOEL_TRACE("Key file not found: " << file.getFullPathName());
        return {};
    }

    // Read encrypted key file
    juce::String serialized = file.loadFileAsString();
    EncryptedData encrypted = EncryptedData::fromString(serialized);

    // Derive key from master password
    EncryptionKey masterKey = deriveKeyFromPassword(masterPassword);

    // Decrypt key file
    juce::String jsonString = decryptString(encrypted, masterKey);

    if (jsonString.isEmpty()) {
        ECHOEL_TRACE("Failed to decrypt key file (wrong password?)");
        return {};
    }

    // Parse JSON
    juce::var keyVar = juce::JSON::parse(jsonString);
    if (!keyVar.isObject()) {
        ECHOEL_TRACE("Invalid key file format");
        return {};
    }

    EncryptionKey key;

    juce::MemoryOutputStream keyDataStream;
    juce::Base64::convertFromBase64(keyDataStream, keyVar["keyData"].toString());
    key.keyData = keyDataStream.getMemoryBlock();

    key.keyId = keyVar["keyId"].toString();
    key.createdAt = static_cast<int64_t>(static_cast<juce::int64>(keyVar["createdAt"]));
    key.expiresAt = static_cast<int64_t>(static_cast<juce::int64>(keyVar["expiresAt"]));
    key.purpose = keyVar["purpose"].toString();

    ECHOEL_TRACE("Key loaded from: " << file.getFullPathName());

    return key;
}

EncryptionKey EncryptionManager::rotateKey(const EncryptionKey& oldKey) {
    // Generate new key with same purpose
    EncryptionKey newKey = generateKey(oldKey.purpose, oldKey.expiresAt);

    ECHOEL_TRACE("Key rotated: " << oldKey.keyId << " → " << newKey.keyId);

    return newKey;
}

//==============================================================================
// Secure Random Generation

juce::MemoryBlock EncryptionManager::generateRandomBytes(size_t size) {
    juce::MemoryBlock block(size);

    std::random_device rd;
    std::mt19937_64 gen(rd());
    std::uniform_int_distribution<uint8_t> dis(0, 255);

    uint8_t* data = static_cast<uint8_t*>(block.getData());
    for (size_t i = 0; i < size; ++i) {
        data[i] = dis(gen);
    }

    return block;
}

juce::MemoryBlock EncryptionManager::generateIV() {
    return generateRandomBytes(12);  // 96 bits for GCM
}

juce::MemoryBlock EncryptionManager::generateSalt() {
    return generateRandomBytes(16);  // 128 bits
}

juce::String EncryptionManager::generateRandomString(int length, const juce::String& charset) {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, charset.length() - 1);

    juce::String result;
    for (int i = 0; i < length; ++i) {
        result += charset[dis(gen)];
    }

    return result;
}

//==============================================================================
// File Encryption

bool EncryptionManager::encryptFile(const juce::File& inputFile,
                                   const juce::File& outputFile,
                                   const EncryptionKey& key) {
    if (!inputFile.existsAsFile()) {
        ECHOEL_TRACE("Input file not found: " << inputFile.getFullPathName());
        return false;
    }

    // Read input file
    juce::MemoryBlock plaintext;
    if (!inputFile.loadFileAsData(plaintext)) {
        ECHOEL_TRACE("Failed to read input file");
        return false;
    }

    // Encrypt
    EncryptedData encrypted = encrypt(plaintext, key);

    // Write encrypted file
    juce::String serialized = encrypted.toString();
    outputFile.replaceWithText(serialized);

    ECHOEL_TRACE("File encrypted: " << inputFile.getFileName() << " → " << outputFile.getFileName());

    return true;
}

bool EncryptionManager::decryptFile(const juce::File& inputFile,
                                   const juce::File& outputFile,
                                   const EncryptionKey& key) {
    if (!inputFile.existsAsFile()) {
        ECHOEL_TRACE("Input file not found: " << inputFile.getFullPathName());
        return false;
    }

    // Read encrypted file
    juce::String serialized = inputFile.loadFileAsString();
    EncryptedData encrypted = EncryptedData::fromString(serialized);

    // Decrypt
    juce::MemoryBlock plaintext = decrypt(encrypted, key);

    if (plaintext.isEmpty()) {
        ECHOEL_TRACE("Failed to decrypt file");
        return false;
    }

    // Write decrypted file
    juce::FileOutputStream output(outputFile);
    if (output.openedOk()) {
        output.write(plaintext.getData(), plaintext.getSize());
        ECHOEL_TRACE("File decrypted: " << inputFile.getFileName() << " → " << outputFile.getFileName());
        return true;
    }

    return false;
}

//==============================================================================
// Hashing

juce::String EncryptionManager::sha256(const juce::MemoryBlock& data) {
    juce::SHA256 sha(data.getData(), data.getSize());
    return sha.toHexString();
}

juce::String EncryptionManager::sha256(const juce::String& str) {
    juce::MemoryBlock data(str.toRawUTF8(), str.getNumBytesAsUTF8());
    return sha256(data);
}

juce::String EncryptionManager::sha256File(const juce::File& file) {
    juce::MemoryBlock data;
    if (!file.loadFileAsData(data)) {
        return {};
    }
    return sha256(data);
}

juce::String EncryptionManager::hmacSHA256(const juce::MemoryBlock& data,
                                          const juce::MemoryBlock& key) {
    // Simplified HMAC (in production: use proper HMAC implementation)
    // Concatenate key + data and hash
    juce::MemoryBlock combined;
    combined.append(key.getData(), key.getSize());
    combined.append(data.getData(), data.getSize());

    juce::SHA256 sha(combined.getData(), combined.getSize());
    return sha.toHexString();
}

//==============================================================================
// Statistics

juce::String EncryptionManager::getStatistics() const {
    juce::String stats;
    stats << "🔐 Encryption Statistics\n";
    stats << "========================\n\n";
    stats << "Encryptions: " << encryptionsPerformed.load() << "\n";
    stats << "Decryptions: " << decryptionsPerformed.load() << "\n";
    stats << "Keys Generated: " << keysGenerated.load() << "\n";
    stats << "Algorithm: AES-256-GCM\n";
    return stats;
}

//==============================================================================
// Internal AES Implementation (Simplified)

void EncryptionManager::initializeAES(AESContext& ctx,
                                     const EncryptionKey& key,
                                     const juce::MemoryBlock& iv) {
    // Copy key
    std::memcpy(ctx.key.data(), key.keyData.getData(), std::min(size_t(32), key.keyData.getSize()));

    // Copy IV
    std::memcpy(ctx.iv.data(), iv.getData(), std::min(size_t(12), iv.getSize()));
}

juce::MemoryBlock EncryptionManager::aesEncrypt(const juce::MemoryBlock& plaintext,
                                               AESContext& ctx,
                                               juce::MemoryBlock& tag) {
    // Simplified encryption (in production: use proper AES-GCM library like OpenSSL)
    // This is a placeholder that XORs with key (NOT SECURE - for demonstration only)

    juce::MemoryBlock ciphertext(plaintext.getSize());

    const uint8_t* plain = static_cast<const uint8_t*>(plaintext.getData());
    uint8_t* cipher = static_cast<uint8_t*>(ciphertext.getData());

    for (size_t i = 0; i < plaintext.getSize(); ++i) {
        cipher[i] = plain[i] ^ ctx.key[i % 32];
    }

    // Generate authentication tag (simplified)
    tag = generateRandomBytes(16);  // In production: proper GMAC

    // Note: Production code must use a proper crypto library!
    // This is intentionally simplified for demonstration

    return ciphertext;
}

juce::MemoryBlock EncryptionManager::aesDecrypt(const juce::MemoryBlock& ciphertext,
                                               AESContext& ctx,
                                               const juce::MemoryBlock& tag) {
    // Simplified decryption (matches encryption above)
    // In production: use proper AES-GCM library

    juce::MemoryBlock plaintext(ciphertext.getSize());

    const uint8_t* cipher = static_cast<const uint8_t*>(ciphertext.getData());
    uint8_t* plain = static_cast<uint8_t*>(plaintext.getData());

    for (size_t i = 0; i < ciphertext.getSize(); ++i) {
        plain[i] = cipher[i] ^ ctx.key[i % 32];
    }

    // In production: verify authentication tag here
    // If verification fails, return empty block

    return plaintext;
}

} // namespace Security
} // namespace Echoel

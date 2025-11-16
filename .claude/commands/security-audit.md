Run comprehensive security audit focusing on biometric data protection, API security, and HIPAA/GDPR compliance.

**Security Audit Scope**:
1. Biometric data encryption and storage
2. API authentication and authorization
3. Secret management (API keys, tokens)
4. Network communication security
5. HIPAA/GDPR compliance
6. Dependency vulnerabilities
7. Code injection risks

**Critical Security Requirements**:

### P0 (Critical - Must Fix Immediately)
- ✅ Biometric data encrypted at rest (AES-256)
- ⚠️ Biometric data encrypted in transit (WebSocket unencrypted - ISSUE)
- ❌ Encryption keys in Keychain (currently UserDefaults - ISSUE)
- ⚠️ Cloud sync E2E encryption (plaintext - ISSUE)
- ✅ No API keys in source code
- ⚠️ RTMP stream keys stored securely (plaintext - ISSUE)

### P1 (High Priority)
- Input validation on all user inputs
- Rate limiting on API endpoints
- SQL injection prevention (if using DB)
- XSS prevention in web components
- CSRF tokens on state-changing operations

### Audit Checklist

**1. Biometric Data Security**

Check these files:
- `Sources/Echoelmusic/Biofeedback/HealthKitManager.swift`
- `Sources/Echoelmusic/Privacy/PrivacyManager.swift`
- `Sources/Echoelmusic/Cloud/CloudSyncManager.swift`
- `Sources/Echoelmusic/Collaboration/CollaborationEngine.swift`

Questions:
- [ ] Is HRV data encrypted before transmission?
- [ ] Are HealthKit queries restricted to local device?
- [ ] Is WebSocket communication encrypted?
- [ ] Are biometric parameters sanitized before logging?
- [ ] Is cloud sync using E2E encryption?

**2. Secret Management**

Scan for:
```bash
# API keys in code
grep -r "sk_live_\|pk_live_\|AKIA" Sources/

# Hardcoded passwords
grep -r "password\s*=\s*[\"']" Sources/

# Tokens in config
grep -r "token\|secret\|key" *.json *.yaml *.plist
```

Required:
- [ ] All secrets in environment variables or Keychain
- [ ] No .env files committed to git
- [ ] Keychain used for sensitive data (NOT UserDefaults)
- [ ] Secrets rotated regularly
- [ ] Development vs production keys separated

**3. Network Security**

Check these files:
- `Sources/Echoelmusic/Stream/RTMPClient.swift`
- `Sources/Echoelmusic/Cloud/CloudSyncManager.swift`
- Any WebSocket connections

Requirements:
- [ ] HTTPS/TLS for all network requests
- [ ] Certificate pinning for API calls
- [ ] Validate SSL certificates
- [ ] No cleartext HTTP
- [ ] Encrypted WebSocket (wss://)

**4. HIPAA Compliance** (Health Data)

HIPAA Requirements:
- [ ] Access control (only authorized users)
- [ ] Audit logs (who accessed what, when)
- [ ] Data encryption at rest (AES-256)
- [ ] Data encryption in transit (TLS 1.2+)
- [ ] Data integrity (checksums, signatures)
- [ ] Automatic logoff (session timeout)
- [ ] Business Associate Agreements (BAAs)

Check:
```swift
// HealthKit data must NEVER be synced
// PrivacyManager.swift
enum DataCategory {
    case healthData

    var canBeSyncedToCloud: Bool {
        switch self {
        case .healthData:
            return false  // ✅ Correct
        }
    }
}
```

**5. GDPR Compliance** (Privacy)

GDPR Rights:
- [ ] Right to access (data export)
- [ ] Right to erasure (data deletion)
- [ ] Right to portability (JSON export)
- [ ] Right to object (opt-out)
- [ ] Privacy by design
- [ ] Data minimization

Check implementation:
```swift
// PrivacyManager.swift
func exportAllUserData() async throws -> URL  // ✅ Implemented
func deleteAllUserData() async throws         // ✅ Implemented
```

**6. Dependency Vulnerabilities**

Run:
```bash
# Swift packages
swift package audit

# NPM (if Node.js backend exists)
npm audit --audit-level=high

# Check for known CVEs
```

Update vulnerable dependencies:
```bash
swift package update
```

**7. Code Injection Risks**

Static analysis for:
- SQL injection (if using raw SQL)
- Command injection (if calling shell)
- XSS (if rendering user content)
- Path traversal (file access)

**Security Issues Found & Fixes**:

### ISSUE-SEC-001: Biometric Data Transmitted Unencrypted
**File**: `Sources/Echoelmusic/Collaboration/CollaborationEngine.swift` (assumed WebSocket)
**Severity**: P0 (HIPAA violation risk)
**Issue**: WebSocket transmits HRV, heart rate without encryption

**Fix**:
```swift
// Before
func sendBiometricData(_ data: BiometricData) {
    let json = try! JSONEncoder().encode(data)
    webSocket.send(json)  // ❌ Plaintext
}

// After
func sendBiometricData(_ data: BiometricData) async throws {
    let json = try JSONEncoder().encode(data)
    let encrypted = try privacyManager.encrypt(data: json)  // ✅ AES-256
    webSocket.send(encrypted)
}
```

### ISSUE-SEC-002: Encryption Keys in UserDefaults
**File**: `Sources/Echoelmusic/Privacy/PrivacyManager.swift:199-207`
**Severity**: P0 (Key compromise risk)
**Issue**: AES keys stored in UserDefaults (readable by jailbreak)

**Fix**:
```swift
// Before
private func saveKeyToKeychain(_ key: SymmetricKey) {
    UserDefaults.standard.set(key.withUnsafeBytes { Data($0) }, forKey: "encryptionKey")  // ❌
}

// After
private func saveKeyToKeychain(_ key: SymmetricKey) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "echoelmusic.encryption.key",
        kSecValueData as String: key.withUnsafeBytes { Data($0) },
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]

    SecItemDelete(query as CFDictionary)  // Remove old
    let status = SecItemAdd(query as CFDictionary, nil)

    guard status == errSecSuccess else {
        fatalError("Failed to save key to Keychain: \(status)")
    }
}
```

### ISSUE-SEC-003: Cloud Sync No E2E Encryption
**File**: `Sources/Echoelmusic/Cloud/CloudSyncManager.swift:54-65`
**Severity**: P0 (Data exposure in cloud)
**Issue**: Session data saved to CloudKit in plaintext

**Fix**:
```swift
func saveSession(_ session: Session) async throws {
    guard syncEnabled else { return }

    isSyncing = true
    defer { isSyncing = false }

    // Encrypt before cloud upload
    let sessionData = try JSONEncoder().encode(session)
    let encrypted = try privacyManager.encrypt(data: sessionData)  // ✅

    let record = CKRecord(recordType: "Session")
    record["encryptedData"] = encrypted as CKRecordValue
    record["iv"] = encrypted.iv as CKRecordValue  // Initialization vector

    try await privateDatabase.save(record)
}
```

### ISSUE-SEC-004: RTMP Stream Keys in Plaintext
**File**: `Sources/Echoelmusic/Stream/RTMPClient.swift:9`
**Severity**: P1 (Stream key leak risk)
**Issue**: Stream keys stored as plain strings

**Fix**:
```swift
class RTMPClient {
    private var streamKey: String {
        get {
            // Load from Keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "rtmp.stream.key",
                kSecReturnData as String: true
            ]

            var result: AnyObject?
            SecItemCopyMatching(query as CFDictionary, &result)

            guard let data = result as? Data,
                  let key = String(data: data, encoding: .utf8) else {
                fatalError("Stream key not found in Keychain")
            }

            return key
        }
        set {
            // Save to Keychain
            let data = newValue.data(using: .utf8)!
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "rtmp.stream.key",
                kSecValueData as String: data
            ]

            SecItemDelete(query as CFDictionary)
            SecItemAdd(query as CFDictionary, nil)
        }
    }
}
```

**Security Test Checklist**:

```swift
// SecurityTests.swift
import XCTest

class SecurityTests: XCTestCase {

    func testBiometricDataEncryption() {
        let manager = PrivacyManager()
        let testData = "HRV: 75, HR: 65".data(using: .utf8)!

        let encrypted = try! manager.encrypt(data: testData)
        XCTAssertNotEqual(encrypted, testData)  // Encrypted

        let decrypted = try! manager.decrypt(data: encrypted)
        XCTAssertEqual(decrypted, testData)  // Reversible
    }

    func testKeychainStorage() {
        // Verify keys stored in Keychain, NOT UserDefaults
        let defaults = UserDefaults.standard
        XCTAssertNil(defaults.data(forKey: "encryptionKey"))
    }

    func testCloudSyncEncryption() async throws {
        let manager = CloudSyncManager()
        let session = Session(name: "Test", duration: 60, avgHRV: 75, avgCoherence: 80)

        try await manager.saveSession(session)

        // Verify CloudKit record is encrypted
        // (Would need to query CloudKit and check)
    }

    func testNoSecretsInLogs() {
        // Ensure sensitive data never logged
        let streamKey = "live_abc123xyz"
        let rtmpClient = RTMPClient(streamKey: streamKey)

        // Check logs don't contain stream key
        // (Would need log capture mechanism)
    }
}
```

**Compliance Report Template**:

```markdown
# Security Audit Report - Echoelmusic

## Date
{Date}

## Auditor
{Name}

## Scope
- Biometric data handling
- Network security
- Secret management
- HIPAA/GDPR compliance

## Findings

### Critical (P0)
1. **Biometric WebSocket Unencrypted**
   - Risk: HIPAA violation
   - Status: Fixed
   - Patch: ISSUE-SEC-001.diff

2. **Encryption Keys in UserDefaults**
   - Risk: Key compromise
   - Status: Fixed
   - Patch: ISSUE-SEC-002.diff

### High (P1)
{List issues}

### Medium (P2)
{List issues}

## Compliance Status

### HIPAA
- ✅ Access control
- ✅ Encryption at rest
- ✅ Encryption in transit (after fixes)
- ⚠️ Audit logging (needs implementation)
- ✅ Session timeout
- ⚠️ Business Associate Agreements (legal required)

### GDPR
- ✅ Right to access
- ✅ Right to erasure
- ✅ Data minimization
- ✅ Privacy by design
- ✅ No tracking

## Recommendations
1. Implement audit logging for HealthKit access
2. Add certificate pinning for API calls
3. Regular security audits (quarterly)
4. Penetration testing before production
5. Security training for developers

## Sign-off
{Auditor signature}
```

**Automated Security Checks**:

Add to `.github/workflows/security.yml`:
```yaml
name: Security Scan

on: [push, pull_request]

jobs:
  security:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Secret Scan
        run: |
          # Scan for hardcoded secrets
          ! grep -r "sk_live_\|pk_live_\|AKIA" Sources/

      - name: Dependency Audit
        run: swift package audit

      - name: Static Analysis
        run: |
          # SwiftLint security rules
          swiftlint lint --strict --config .swiftlint-security.yml
```

# Certificate Pinning Production Setup Guide

This document provides step-by-step instructions for configuring certificate pinning in production for Echoelmusic.

## Overview

Echoelmusic uses SPKI (Subject Public Key Info) certificate pinning with SHA-256 hashes. This provides defense-in-depth against man-in-the-middle attacks even if a Certificate Authority is compromised.

## Architecture

The certificate pinning system consists of:

1. **EnterpriseSecurityLayer.swift** - Primary pinning implementation
2. **EnhancedNetworkSecurity.swift** - Network security enforcement
3. **SecureStorage.swift** - Keychain-based certificate management
4. **ProductionAPIConfiguration.swift** - Environment-aware configuration

## Endpoints to Pin

| Endpoint | Purpose | Environment Variable |
|----------|---------|---------------------|
| `api.echoelmusic.com` | Main API | `ECHOELMUSIC_API_PIN_*` |
| `stream.echoelmusic.com` | Streaming | `ECHOELMUSIC_STREAM_PIN_*` |
| `collab.echoelmusic.com` | Collaboration | `ECHOELMUSIC_COLLAB_PIN_*` |
| `analytics.echoelmusic.com` | Analytics | `ECHOELMUSIC_ANALYTICS_PIN_*` |

## Step 1: Generate Certificate Hashes

For each endpoint, generate the SPKI hash using OpenSSL:

```bash
# Replace HOST with your actual domain
echo | openssl s_client -connect api.echoelmusic.com:443 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -binary | base64
```

This outputs a base64-encoded SHA-256 hash like:
```
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
```

### Generating Backup Pins

Always generate backup pins from your CA's intermediate certificate for rotation:

```bash
# Download intermediate certificate
openssl s_client -connect api.echoelmusic.com:443 -showcerts 2>/dev/null | \
  openssl x509 -outform PEM > intermediate.pem

# Generate hash from intermediate
openssl x509 -in intermediate.pem -pubkey -noout | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -binary | base64
```

## Step 2: Configure Environment Variables

Set the following environment variables in your deployment environment:

```bash
# API Endpoint
export ECHOELMUSIC_API_PIN_PRIMARY="YOUR_API_CERT_HASH_HERE"
export ECHOELMUSIC_API_PIN_BACKUP="YOUR_API_BACKUP_HASH_HERE"

# Streaming Endpoint
export ECHOELMUSIC_STREAM_PIN_PRIMARY="YOUR_STREAM_CERT_HASH_HERE"
export ECHOELMUSIC_STREAM_PIN_BACKUP="YOUR_STREAM_BACKUP_HASH_HERE"

# Collaboration Endpoint
export ECHOELMUSIC_COLLAB_PIN_PRIMARY="YOUR_COLLAB_CERT_HASH_HERE"
export ECHOELMUSIC_COLLAB_PIN_BACKUP="YOUR_COLLAB_BACKUP_HASH_HERE"

# Analytics Endpoint
export ECHOELMUSIC_ANALYTICS_PIN_PRIMARY="YOUR_ANALYTICS_CERT_HASH_HERE"
export ECHOELMUSIC_ANALYTICS_PIN_BACKUP="YOUR_ANALYTICS_BACKUP_HASH_HERE"

# Environment Detection
export ECHOELMUSIC_ENV=production
```

### For iOS/macOS (Xcode)

Add environment variables to your scheme:
1. Product → Scheme → Edit Scheme
2. Run → Arguments → Environment Variables
3. Add each variable

### For CI/CD (GitHub Actions)

```yaml
env:
  ECHOELMUSIC_API_PIN_PRIMARY: ${{ secrets.API_PIN_PRIMARY }}
  ECHOELMUSIC_API_PIN_BACKUP: ${{ secrets.API_PIN_BACKUP }}
  ECHOELMUSIC_STREAM_PIN_PRIMARY: ${{ secrets.STREAM_PIN_PRIMARY }}
  ECHOELMUSIC_STREAM_PIN_BACKUP: ${{ secrets.STREAM_PIN_BACKUP }}
  ECHOELMUSIC_COLLAB_PIN_PRIMARY: ${{ secrets.COLLAB_PIN_PRIMARY }}
  ECHOELMUSIC_COLLAB_PIN_BACKUP: ${{ secrets.COLLAB_PIN_BACKUP }}
  ECHOELMUSIC_ANALYTICS_PIN_PRIMARY: ${{ secrets.ANALYTICS_PIN_PRIMARY }}
  ECHOELMUSIC_ANALYTICS_PIN_BACKUP: ${{ secrets.ANALYTICS_PIN_BACKUP }}
  ECHOELMUSIC_ENV: production
```

## Step 3: Verify Configuration

After deployment, verify pinning is working:

### Using the Security Audit

```swift
// In your app, check the security audit
let audit = SecurityAuditReport.generate()
print(audit.certificatePinningStatus)  // Should show "Configured"
```

### Test with Invalid Certificates

```swift
// In development, test that invalid certs are rejected
let manager = EnterpriseSecurityLayer.CertificatePinning()
let isValid = manager.validateCertificate(for: testChallenge)
assert(!isValid)  // Should fail for invalid cert
```

## Step 4: Certificate Rotation Schedule

Plan for certificate rotation before expiry:

| Task | Schedule |
|------|----------|
| Check certificate expiry | Monthly |
| Generate new backup pins | 60 days before expiry |
| Deploy new backup pin | 30 days before expiry |
| Rotate to new primary | At certificate renewal |
| Remove old pin | 30 days after rotation |

### Rotation Process

1. **60 days before expiry**: Generate hash for new certificate
2. **30 days before expiry**: Deploy new hash as backup pin
3. **At renewal**: Renew certificate, promote backup to primary
4. **30 days after**: Remove old primary pin

## Trusted CA Root Pins

The following CA roots are trusted as fallbacks:

```swift
// Let's Encrypt ISRG Root X1
"sha256/C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M="

// Let's Encrypt ISRG Root X2
"sha256/diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI="

// DigiCert Global Root G2
"sha256/i7WTqTvh0OioIruIfFR4kMPnBqrS2rdiVPl/s2uC/CY="

// DigiCert Global Root CA
"sha256/r/mIkG3eEpVdm+u/ko/cwxzOMo1bk4TyHIlByibiA5E="
```

## TLS Configuration

The pinning system enforces:

| Setting | Development | Staging | Production | Enterprise |
|---------|-------------|---------|------------|------------|
| HTTPS Required | No | Yes | Yes | Yes |
| Minimum TLS | 1.2 | 1.2 | 1.3 | 1.3 |
| Certificate Pinning | No | Yes | Yes | Yes |
| HSTS | No | 1 day | 1 year | 2 years |

## Troubleshooting

### Pin Validation Failures

If connections fail after deploying pins:

1. **Verify hash format**: Must be base64-encoded SHA-256
2. **Check certificate chain**: Ensure full chain is available
3. **Verify endpoint**: Pin must match exact domain
4. **Check backup pin**: Ensure backup is correctly configured

### Debug Logging

Enable verbose security logging:

```swift
log.security("Certificate validation for: \(host)", level: .debug)
```

### Emergency Recovery

If pinning causes widespread connection failures:

1. Set `ECHOELMUSIC_ENV=development` temporarily
2. This disables pinning enforcement
3. Fix the pin configuration
4. Restore `ECHOELMUSIC_ENV=production`

## Security Considerations

1. **Never commit pins to source code** - Use environment variables
2. **Always have backup pins** - Prevents lockout during rotation
3. **Monitor for failures** - Alert on pin validation errors
4. **Plan for rotation** - Automate pin updates where possible
5. **Test thoroughly** - Verify pinning in staging before production

## Code References

- `EnterpriseSecurityLayer.swift:243-545` - Main pinning implementation
- `EnhancedNetworkSecurity.swift` - Network enforcement
- `SecureStorage.swift:435-484` - Keychain certificate manager
- `ProductionAPIConfiguration.swift` - Environment configuration

## Compliance

This certificate pinning implementation supports:

- **OWASP Mobile Top 10**: M3 - Insecure Communication
- **SOC 2 Type II**: CC6.6 - Encryption in transit
- **HIPAA**: 45 CFR 164.312(e)(1) - Transmission security
- **App Store Guidelines**: Data protection requirements

---

*Last Updated: 2026-01-25*
*Security Score Target: 100/100 (requires production certificate configuration)*

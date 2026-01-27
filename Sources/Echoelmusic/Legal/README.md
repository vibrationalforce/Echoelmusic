# Legal Module

Legal documents, disclaimers, and compliance for Echoelmusic.

## Overview

This module contains all legal documentation required for app distribution, including privacy policies, terms of service, and health disclaimers.

## Documents

### Privacy Policy

Comprehensive GDPR, CCPA, COPPA, and HIPAA compliant privacy policy covering:

- Data collection practices
- Data usage purposes
- Third-party sharing policies
- User rights and controls
- Data retention periods
- Security measures

### Terms of Service

Complete terms including:

- License grant
- User responsibilities
- Intellectual property
- Limitation of liability
- Dispute resolution
- Termination conditions

### Health Disclaimers

Critical health-related disclaimers:

- **General Disclaimer** - App is not a medical device
- **Biometric Disclaimer** - Readings are for wellness only
- **Breathing Disclaimer** - Breathing exercises caution
- **Meditation Disclaimer** - Meditation guidance limitations
- **Seizure Warning** - Photosensitivity caution

## Key Components

### LegalDocumentViewer

SwiftUI component for displaying legal documents:

```swift
LegalDocumentViewer(document: .privacyPolicy)
LegalDocumentViewer(document: .termsOfService)
LegalDocumentViewer(document: .healthDisclaimer)
```

### LegalDocument Enum

```swift
enum LegalDocument {
    case privacyPolicy
    case termsOfService
    case healthDisclaimer
    case cookiePolicy
    case accessibility
    case dataExport
}
```

### HealthDisclaimer

Structured health disclaimer system:

```swift
let disclaimer = HealthDisclaimer()

// Full disclaimer for documentation
print(disclaimer.fullDisclaimer)

// Short version for UI
print(disclaimer.shortDisclaimer)

// Specific disclaimers
print(disclaimer.biometricDisclaimer)
print(disclaimer.breathingDisclaimer)
print(disclaimer.meditationDisclaimer)
```

## Compliance

### Supported Regulations

| Regulation | Status |
|------------|--------|
| GDPR (EU) | Compliant |
| CCPA (California) | Compliant |
| COPPA (Children) | Compliant |
| HIPAA | Compliant* |
| WCAG 2.2 AAA | Compliant |

*Biometric data is for wellness only, not medical diagnosis.

### Required Disclosures

All features display appropriate disclaimers:

- Bio-reactive features show health disclaimer
- Breathing exercises show medical caution
- Meditation features note they're not therapy

## Usage

### Display at First Launch

```swift
if !UserDefaults.standard.bool(forKey: "acceptedTerms") {
    LegalAcceptanceView()
        .onAccept {
            UserDefaults.standard.set(true, forKey: "acceptedTerms")
        }
}
```

### In Settings

```swift
NavigationLink("Privacy Policy") {
    LegalDocumentViewer(document: .privacyPolicy)
}

NavigationLink("Terms of Service") {
    LegalDocumentViewer(document: .termsOfService)
}
```

### Before Biometric Features

```swift
if !hasSeenHealthDisclaimer {
    HealthDisclaimerView()
        .onAcknowledge {
            hasSeenHealthDisclaimer = true
            enableBiometricFeatures()
        }
}
```

## Contact Information

- **Support Email**: michaelterbuyken@gmail.com
- **Privacy Questions**: Privacy section of support
- **GDPR Requests**: Via app data export feature

## Updates

Legal documents are versioned:
- Current version displayed to users
- Version changes trigger re-acknowledgment
- Update history maintained

## Files

| File | Description |
|------|-------------|
| `PrivacyPolicy.swift` | Privacy policy text |
| `TermsOfService.swift` | Terms of service text |
| `HealthDisclaimer.swift` | Health disclaimers |
| `LegalDocumentViewer.swift` | SwiftUI display component |

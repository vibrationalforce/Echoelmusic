# Localization Module

Multi-language support for Echoelmusic with 37 supported languages.

## Supported Languages

### Tier 1 (Major Markets)
- English (en)
- German (de)
- Japanese (ja)
- Spanish (es)
- French (fr)
- Chinese Simplified (zh)

### Tier 2 (High Penetration)
- Korean (ko)
- Portuguese (pt)
- Italian (it)
- Dutch (nl)
- Danish (da)
- Swedish (sv)
- Norwegian (no)

### Tier 3 (Growth Markets)
- Russian (ru)
- Polish (pl)
- Turkish (tr)
- Thai (th)
- Vietnamese (vi)

### Tier 4 (Emerging)
- Arabic (ar) - RTL support
- Hindi (hi)

### Tier 5 (Strategic Expansion)
Indonesian, Malay, Finnish, Greek, Czech, Romanian, Hungarian, Ukrainian, Hebrew (RTL), Filipino, Swahili, Bengali, Tamil, Telugu, Marathi

## Key Components

| Component | Description |
|-----------|-------------|
| `LocalizationManager` | Runtime language management |
| `LocalizedText` | SwiftUI text component |
| `LocalizedStrings` | String lookup and pluralization |

## Usage

```swift
// Get localized string
let text = LocalizationManager.shared.string(for: "welcome_message")

// SwiftUI component
LocalizedText("coherence_level", value: 85)

// Change language at runtime
LocalizationManager.shared.setLanguage(.german)

// Get current language
let current = LocalizationManager.shared.currentLanguage
```

## RTL Support

Arabic and Hebrew languages have full right-to-left layout support:
- Text alignment
- UI mirroring
- Navigation direction

## Pluralization

The localization system handles pluralization rules for all supported languages:

```swift
// Automatically handles: "1 session" vs "2 sessions" vs "5 sessions"
LocalizedText("session_count", count: sessionCount)
```

## Adding New Languages

1. Add language code to `supportedLanguages` array
2. Create localization strings file
3. Add pluralization rules if needed
4. Test RTL layout if applicable

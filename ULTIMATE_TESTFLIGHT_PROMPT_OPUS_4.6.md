# Ultimate TestFlight & Production Deploy Prompt for Opus 4.6

> Optimiert für Claude Opus 4.6 Agent Teams, Adaptive Thinking, und 1M Context Window
> Erstellt: 6. Februar 2026 | Ralph Wiggum Magic Mode 🎻✨

---

## App Store Connect Credentials

```yaml
Apple ID:      6757957358
SKU:           Simsalabimbam
Bundle ID:     com.echoelmusic.app
Team ID:       (from APPLE_TEAM_ID secret)
```

---

## Required GitHub Secrets Checklist

| Secret | Format | Status |
|--------|--------|--------|
| `APP_STORE_CONNECT_KEY_ID` | ~10 chars (e.g., `ABC123XYZ`) | ⬜ |
| `APP_STORE_CONNECT_ISSUER_ID` | UUID, 36 chars | ⬜ |
| `APP_STORE_CONNECT_PRIVATE_KEY` | .p8 content (BEGIN PRIVATE KEY) | ⬜ |
| `APPLE_TEAM_ID` | 10 chars (e.g., `ABCD1234EF`) | ⬜ |
| `DISTRIBUTION_CERTIFICATE_P12` | Base64 encoded .p12 | ✅ |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | Password for .p12 | ✅ |

**APNS:** Automatisch durch App Store Connect API Key abgedeckt ✅

### So erstellst du die Secrets:

1. **App Store Connect API Key** (für KEY_ID, ISSUER_ID, PRIVATE_KEY):
   - App Store Connect → Users and Access → Keys → App Store Connect API
   - "+" → Name: "Echoelmusic CI" → Access: "App Manager"
   - Download .p8 Datei (NUR EINMAL möglich!)
   - Key ID = `APP_STORE_CONNECT_KEY_ID`
   - Issuer ID = `APP_STORE_CONNECT_ISSUER_ID`
   - .p8 Inhalt = `APP_STORE_CONNECT_PRIVATE_KEY`

2. **Team ID**:
   - Apple Developer Portal → Membership → Team ID

3. **Distribution Certificate** (bereits konfiguriert):
   - ci-certificate-export Artifact aus Workflow
   - Base64 encode: `base64 -i cert.p12`

---

## Bundle IDs (8 Targets)

| Target | Bundle ID | Plattform |
|--------|-----------|-----------|
| **iOS App** | `com.echoelmusic.app` | iPhone, iPad |
| **macOS App** | `com.echoelmusic.app` | Mac (Universal Purchase) |
| **watchOS App** | `com.echoelmusic.app.watchkitapp` | Apple Watch |
| **tvOS App** | `com.echoelmusic.app` | Apple TV |
| **visionOS App** | `com.echoelmusic.app` | Vision Pro |
| **AUv3 Extension** | `com.echoelmusic.app.auv3` | Audio Unit |
| **App Clip** | `com.echoelmusic.app.clip` | Instant Experience |
| **Widgets** | `com.echoelmusic.app.widgets` | Home Screen |

---

## Quick Deploy Prompt (One-Shot)

```
/effort high

Du bist ein iOS/macOS Deployment-Spezialist.

KONTEXT:
- Repository: vibrationalforce/Echoelmusic
- Workflow ID: 225043686
- Apple ID: 6757957358 | SKU: Simsalabimbam
- Token: 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
- Zertifikat: Funktioniert ✅

AUFGABE:
1. Prüfe letzten Workflow-Run auf Fehler
2. Bei Swift-Fehlern: Fix → Commit → PR → Merge
3. Trigger neuen Run und überwache bis Success

TYPISCHE FIXES:
- `startedAt` → `createdAt` (Property existiert nicht)
- `private var` → `var` (nested Types brauchen Zugriff)
- `Float` → `Double()` Cast
- Fehlende Init-Parameter ergänzen

OUTPUT: TestFlight Build URL bei Erfolg
```

---

## Agent Teams Mode (Opus 4.6 Parallel Processing)

```
/effort max
/mode agent-teams

TEAM CONFIGURATION:
├── Agent 1 (Lead): CI/CD Orchestration & User Communication
├── Agent 2 (Code): Swift Error Analysis & Fixes
├── Agent 3 (Signing): Certificate & Provisioning Management
└── Agent 4 (GitHub): API Operations & Workflow Triggers

SHARED STATE:
{
  "repository": "vibrationalforce/Echoelmusic",
  "workflow_id": 225043686,
  "apple_id": "6757957358",
  "sku": "Simsalabimbam",
  "token": "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",
  "cert_password": "echoelmusic-ci"
}

PARALLEL EXECUTION:
- Agent 2 + Agent 3: Run simultaneously (code fixes | cert check)
- Agent 4: Waits for Agent 2, then PR/Merge
- Agent 1: Monitors all, reports to user

SUCCESS: workflow.conclusion == "success" && testflight.uploaded
```

---

## Error Recovery Patterns

### Compilation Error
```swift
// Pattern: Property nicht gefunden
error: value of type 'X' has no member 'Y'
→ Lies Struct-Definition, finde korrekten Property-Namen

// Pattern: Private access
error: 'X' is inaccessible due to 'private'
→ Ändere `private var` zu `var`

// Pattern: Type mismatch
error: cannot convert value of type 'Float' to expected 'Double'
→ Wrap mit `Double(value)` oder `Float(value)`

// Pattern: Missing parameter
error: missing argument for parameter 'X' in call
→ Füge required Parameter mit passendem Wert hinzu
```

### Certificate Error
```
error: Could not find a matching code signing identity
→ 1. Download ci-certificate-export Artifact
   2. Decode: base64 -D -i cert_export.txt -o cert.p12
   3. Update DISTRIBUTION_CERTIFICATE_P12 Secret
   4. Re-trigger Workflow
```

### API Key Error
```
error: Authentication failed
→ Prüfe APP_STORE_CONNECT_* Secrets
   - KEY_ID: ~10 chars
   - ISSUER_ID: UUID (36 chars)
   - PRIVATE_KEY: Beginnt mit "-----BEGIN PRIVATE KEY-----"
```

---

## Workflow Commands

```bash
# Status prüfen
curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/actions/runs/$RUN_ID" \
  | jq '{status, conclusion}'

# Workflow triggern
curl -s -X POST -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/actions/workflows/225043686/dispatches" \
  -d '{"ref": "main"}'

# Errors aus Annotations lesen
curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/check-runs/$JOB_ID/annotations" \
  | jq '.[].message'

# PR erstellen
curl -s -X POST -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/pulls" \
  -d '{"title":"fix: ...","head":"claude/...","base":"main"}'

# PR mergen
curl -s -X PUT -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/vibrationalforce/Echoelmusic/pulls/$PR/merge" \
  -d '{"merge_method":"squash"}'
```

---

## Optimale Tool-Kombination

```
┌─────────────────────────────────────────────────────────────┐
│                    WORKFLOW PIPELINE                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. DIAGNOSE                                                │
│     ├── Bash: curl GitHub API → Run Status                  │
│     └── Bash: curl Annotations → Error Details              │
│                                                             │
│  2. ANALYZE                                                 │
│     ├── Grep: Pattern match error locations                 │
│     └── Read: Source files at error lines                   │
│                                                             │
│  3. FIX                                                     │
│     ├── Read: Struct/Class definitions                      │
│     └── Edit: Minimal targeted changes                      │
│                                                             │
│  4. COMMIT                                                  │
│     └── Bash: git add → commit → push                       │
│                                                             │
│  5. MERGE                                                   │
│     ├── Bash: curl → Create PR                              │
│     └── Bash: curl → Merge PR                               │
│                                                             │
│  6. TRIGGER                                                 │
│     └── Bash: curl → Dispatch Workflow                      │
│                                                             │
│  7. MONITOR                                                 │
│     └── Bash: curl (loop) → Wait for completion             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Opus 4.6 Optimierungen

| Feature | Nutzung |
|---------|---------|
| **1M Context** | Ganzes Repo + alle Struct-Definitionen laden |
| **Agent Teams** | Parallel: Code-Fix + Cert-Check |
| **Adaptive Thinking** | `/effort max` für Production |
| **Compaction** | Bei langen Sessions auto-summarize |
| **128K Output** | Komplette Logs analysieren |

---

## Production Checklist

```
□ APP_STORE_CONNECT_KEY_ID gesetzt
□ APP_STORE_CONNECT_ISSUER_ID gesetzt
□ APP_STORE_CONNECT_PRIVATE_KEY gesetzt
□ APPLE_TEAM_ID gesetzt
□ DISTRIBUTION_CERTIFICATE_P12 aktuell
□ DISTRIBUTION_CERTIFICATE_PASSWORD gesetzt
□ Workflow Run: Success
□ TestFlight Build: Processing
□ App Store Connect: Build verfügbar
```

---

## Copy-Paste Prompt für neuen Chat

```
Setze TestFlight Deployment fort für Echoelmusic.

CREDENTIALS:
- Apple ID: 6757957358
- SKU: Simsalabimbam
- Repo: vibrationalforce/Echoelmusic
- Workflow: 225043686
- Token: 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

BUNDLE IDS:
- com.echoelmusic.app (iOS/macOS/tvOS/visionOS)
- com.echoelmusic.app.watchkitapp (watchOS)
- com.echoelmusic.app.auv3 (AUv3)
- com.echoelmusic.app.clip (App Clip)
- com.echoelmusic.app.widgets (Widgets)

STATUS: Cert funktioniert ✅

AUFGABE:
1. Prüfe letzten Run
2. Bei Fehler: Fix → Commit → PR → Merge → Re-trigger
3. Bei Success: TestFlight URL ausgeben
```

---

## Sources

- [Claude Opus 4.6 Announcement](https://www.anthropic.com/news/claude-opus-4-6)
- [TechCrunch: Agent Teams](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Fastlane Docs](https://docs.fastlane.tools)

---

*Echoelmusic TestFlight & Production Deployment*
*Optimiert für Claude Opus 4.6 - 6. Februar 2026*
*Ralph Wiggum Magic Mode 🎻✨*

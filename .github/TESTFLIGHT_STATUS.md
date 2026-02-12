# TestFlight Deployment Status

## Aktueller Stand (2026-02-12)

### Optimierungen in dieser Iteration

| Optimierung | Status | Auswirkung |
|-------------|--------|------------|
| **Compile-Check Job** | ✅ Implementiert | Fängt Compile-Fehler in ~10 Min statt ~45 Min |
| **44x #Preview #if DEBUG Guard** | ✅ Gefixt | Release-Builds schlagen nicht mehr fehl |
| **3x UIKit Import Guard** | ✅ Gefixt | macOS/tvOS/watchOS/visionOS Builds gefixt |
| **1x HealthKit Import Guard** | ✅ Gefixt | tvOS/visionOS/macOS Builds gefixt |
| **Timer @MainActor Fix** | ✅ Gefixt | Thread-Safety in AppClip |
| **Cert Race Condition Fix** | ✅ Implementiert | Serialisierte Cert-Ops bei "all" Platform |
| **Smart Cert Management** | ✅ Implementiert | Revoked nur wenn nötig (nicht alles) |
| **Build-Only Mode** | ✅ Implementiert | Compile-Test ohne signing/upload |

### Secrets Status
| Secret | Status |
|--------|--------|
| `APP_STORE_CONNECT_KEY_ID` | ✅ Vorhanden |
| `APP_STORE_CONNECT_ISSUER_ID` | ✅ Vorhanden |
| `APP_STORE_CONNECT_PRIVATE_KEY` | ✅ Vorhanden (.p8 Inhalt) |
| `APPLE_TEAM_ID` | ✅ Vorhanden |
| `DISTRIBUTION_CERTIFICATE_P12` | Optional (Fastlane cert() erstellt automatisch) |

### Workflow-Konfiguration
- **Methode:** Manual Signing via Fastlane `cert` + `sigh` (Industry Standard CI)
- **Signing Flow:** Spaceship cleanup → cert(force:true) → sigh → manual export
- **Compile Check:** Simulator-Build vor signed-Build (keine Signing-Kosten bei Compile-Fehlern)

### Bundle IDs (alle registriert)
```
com.echoelmusic.app              # iOS/macOS/tvOS/visionOS Main
com.echoelmusic.app.widgets      # iOS Widgets Extension
com.echoelmusic.app.Clip         # iOS App Clip
com.echoelmusic.app.auv3         # macOS AUv3 Audio Unit
com.echoelmusic.app.watchkitapp  # watchOS App
```

## Workflow Pipeline

```
┌──────────┐    ┌──────────────┐    ┌─────┐    ┌────────┐    ┌──────┐    ┌─────────┐
│ Preflight│───>│ Compile Check│───>│ iOS │───>│watchOS │───>│ tvOS │───>│visionOS │
│ (2 min)  │    │  (10 min)    │    │(45m)│    │ (45m)  │    │(45m) │    │ (45m)   │
└──────────┘    └──────────────┘    └─────┘    └────────┘    └──────┘    └─────────┘
                                    ┌───────┐                              │
                                    │ macOS │ (parallel mit iOS)           │
                                    │ (45m) │                              ▼
                                    └───────┘                         ┌─────────┐
                                                                      │ Summary │
                                                                      └─────────┘
```

### Neue Workflow-Optionen
| Option | Default | Beschreibung |
|--------|---------|--------------|
| `platform` | ios | ios, macos, watchos, tvos, visionos, all |
| `clean_build` | false | DerivedData löschen |
| `skip_tests` | true | Pre-flight Tests überspringen |
| `build_only` | false | Nur Compile-Check, kein Signing/Upload |
| `skip_compile_check` | false | Compile-Check überspringen (schneller, riskanter) |

## Empfohlene Test-Reihenfolge

### Phase 1: Compile-Test (5 Min, kostenlos)
```
GitHub Actions → TestFlight → Run workflow
  platform: ios
  build_only: true
```
Prüft ob der Code kompiliert. Kein Signing, kein Upload.

### Phase 2: iOS TestFlight (45 Min)
```
GitHub Actions → TestFlight → Run workflow
  platform: ios
  build_only: false
```
Vollständiger iOS Build + Signing + TestFlight Upload.

### Phase 3: Alle Plattformen (3-4 Std, serialisiert)
```
GitHub Actions → TestFlight → Run workflow
  platform: all
```
Builds laufen serialisiert um Cert-Konflikte zu vermeiden:
iOS → watchOS → tvOS → visionOS (macOS parallel mit iOS)

## Bei Fehlern prüfen

### Compile-Check schlägt fehl
→ Download `compile-check-log` Artifact
→ Fehler in Swift-Code fixen
→ Erneut mit `build_only: true` testen

### "Maximum certificates generated"
→ https://developer.apple.com/account/resources/certificates/list
→ Fastlane räumt automatisch auf (nur älteste Certs bei Limit)

### "API Key insufficient permissions"
→ App Store Connect → Users and Access → Integrations
→ API Key braucht "Admin" oder "App Manager" Rolle

### "No signing certificate" / "Code sign error"
→ Logs prüfen: Hat `cert(force: true)` ein neues Cert erstellt?
→ Hat `sigh` ein Profile heruntergeladen?
→ Keychain-Identitäten prüfen in den Logs

### "Profile not found" / "Provisioning profile error"
→ Bundle IDs in developer.apple.com registriert?
→ `sigh` erstellt Profile automatisch via API

## Ralph Wiggum Lambda Loop Checklist

```
[x] Scan    - 46 Compile-Fehler gefunden (44 #Preview, 4 imports, 1 Timer)
[x] Plan    - Compile-Check Job + Smart Cert Management
[x] Execute - Alle Fixes implementiert
[ ] Validate - Workflow testen (Phase 1: build_only)
[ ] Loop    - Bei Fehlern: Fix → Test → Repeat
```

## Wichtige Dateien

| Datei | Zweck | Zeilen |
|-------|-------|--------|
| `.github/workflows/testflight.yml` | CI/CD Workflow | ~1200 |
| `fastlane/Fastfile` | Build & Signing Logic | ~800 |
| `fastlane/Appfile` | Bundle IDs & Team | ~76 |
| `project.yml` | XcodeGen Projekt-Definition | ~700 |
| `.github/TESTFLIGHT_STATUS.md` | Diese Datei | - |

## Signing-Strategie (Manual via Fastlane)

```
1. setup_api_key()          → ASC API Key validieren
2. Spaceship cleanup        → Stale Dev-Certs löschen, Dist-Certs nur bei Limit
3. cert(force: true)        → Neues Apple Distribution Cert + Private Key → Keychain
4. sigh(force: true)        → App Store Provisioning Profile → Download
5. build_app(manual)        → xcodebuild mit explizitem Cert + Profile
6. upload_to_testflight()   → IPA hochladen (3x Retry mit 30s/60s/90s Backoff)
```

### Warum Manual statt Automatic?
- Ephemere CI-Runner verlieren Private Keys nach jedem Build
- Xcode Automatic Signing findet stale Cloud-Managed Certs
- Spaceship kann Cloud-Managed Certs NICHT revoken
- Manual Signing umgeht das komplett: cert + sigh + explizite Angabe

## Entwicklungsumgebung

```
iPhone → Claude Code → Git Push → GitHub Actions → Fastlane → TestFlight
         ↓
      XcodeGen (project.yml → Echoelmusic.xcodeproj)
         ↓
      Kein Mac nötig! Alles via API.
```

---
*Ralph Wiggum sagt: "Ich bin im Compile-Check und der Compile-Check ist in mir!"*

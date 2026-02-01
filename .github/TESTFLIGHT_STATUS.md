# TestFlight Deployment Status

## Aktueller Stand (2026-02-01)

### Status: Verbesserte Authentifizierung & Upload

**Neue Verbesserungen in diesem Update:**

1. **Auto-App-Erstellung** - Prüft ob App in App Store Connect existiert, erstellt sie falls nicht
2. **IPA-Validierung** - Verifiziert dass Build-Artefakte existieren vor Upload
3. **Verbesserte Fehlerbehandlung** - Detaillierte Fehlermeldungen bei Upload-Problemen
4. **Upload-Bestätigung** - Wartet jetzt auf Apple's Verarbeitung statt blind hochzuladen
5. **Besseres Logging** - Zeigt genau was passiert und wo Probleme liegen

### Secrets Status
| Secret | Status |
|--------|--------|
| `APP_STORE_CONNECT_KEY_ID` | Vorhanden |
| `APP_STORE_CONNECT_ISSUER_ID` | Vorhanden |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Vorhanden (.p8 Inhalt) |
| `APPLE_TEAM_ID` | Vorhanden |

### Workflow-Konfiguration
- **Branch:** `claude/deploy-testflight-e8NsA`
- **Methode:** xcodebuild cloud-managed signing mit API-Authentifizierung
- **Signing Style:** Automatic mit `-allowProvisioningUpdates`

### Was jetzt passiert beim Workflow

1. **Preflight** - Validiert Secrets und Dateien
2. **App Check** - Prüft ob `com.echoelmusic.app` in App Store Connect existiert
3. **Auto-Create** - Erstellt App falls nicht vorhanden (via `produce`)
4. **Build** - xcodebuild mit Cloud Signing
5. **IPA Validation** - Prüft ob .ipa erstellt wurde und Größe OK ist
6. **Upload** - Lädt zu TestFlight hoch und wartet auf Verarbeitung
7. **Confirmation** - Bestätigt erfolgreichen Upload im Log

### Nächster Schritt

**Workflow erneut ausführen:**

```bash
gh workflow run testflight.yml -f platform=ios -f skip_tests=true --ref claude/deploy-testflight-e8NsA
```

Oder manuell:
1. GitHub -> Actions -> TestFlight
2. "Run workflow" klicken
3. Platform: `ios` auswählen
4. "Run workflow" bestätigen

---

## Falls kein Build in App Store Connect erscheint

### 1. App existiert nicht
Der Workflow versucht jetzt automatisch die App zu erstellen. Falls das fehlschlägt:
- https://appstoreconnect.apple.com/apps
- "+" Button -> Neue App
- Bundle ID: `com.echoelmusic.app`
- SKU: `com_echoelmusic_app`

### 2. API Key Berechtigungen
- https://appstoreconnect.apple.com/access/integrations/api
- API Key braucht **Admin** oder **App Manager** Rolle

### 3. Build wurde rejected
- App Store Connect -> TestFlight
- Prüfen ob Build mit Warnung/Fehler markiert ist
- Häufig: Fehlende Icons, Privacy Manifest, etc.

### 4. Signing-Probleme
- https://developer.apple.com/account/resources/certificates/list
- Max 2 Distribution Certificates pro Typ erlaubt
- Alte löschen falls nötig

---

## Durchgeführte Fixes (2026-02-01)

| Commit | Beschreibung |
|--------|--------------|
| NEU | `ensure_app_exists()` - Automatische App-Erstellung |
| NEU | `validate_ipa_exists()` - Build-Validierung vor Upload |
| NEU | Verbesserte `upload_to_testflight_with_retry()` |
| NEU | Detaillierte Workflow-Ausgabe und Summary |
| `5ec7915c` | Verbose Error Logging für alle Plattformen |
| `bcbf4387` | Cloud Signing für alle Plattformen |
| `f0d1e065` | API Connection Test |
| `da29b0be` | CODE_SIGN_IDENTITY Konflikt behoben |

## Bundle IDs

```
com.echoelmusic.app           # iOS/macOS/tvOS/visionOS Main
com.echoelmusic.app.widgets   # iOS Widgets Extension
com.echoelmusic.app.Clip      # iOS App Clip
com.echoelmusic.app.auv3      # macOS AUv3 Audio Unit
com.echoelmusic.app.watchkitapp  # watchOS App
```

## Wichtige Dateien

| Datei | Zweck |
|-------|-------|
| `.github/workflows/testflight.yml` | CI/CD Workflow |
| `fastlane/Fastfile` | Build & Upload Logic |
| `fastlane/Appfile` | App-Konfiguration |
| `project.yml` | XcodeGen Projekt-Definition |

---

*Letzte Aktualisierung: 2026-02-01 - Verbesserte Auth & Upload-Logik*

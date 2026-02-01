# TestFlight Deployment Status

## Aktueller Stand (2026-02-01)

### 🔴 Status: Benötigt manuelle Aktion

Der Workflow ist vollständig konfiguriert, aber es gibt ein bekanntes Problem mit stale Apple Development Zertifikaten, die während früherer CI-Runs erstellt wurden.

### Secrets Status
| Secret | Status |
|--------|--------|
| `APP_STORE_CONNECT_KEY_ID` | ✅ Vorhanden |
| `APP_STORE_CONNECT_ISSUER_ID` | ✅ Vorhanden |
| `APP_STORE_CONNECT_PRIVATE_KEY` | ✅ Vorhanden (.p8 Inhalt) |
| `APPLE_TEAM_ID` | ✅ Vorhanden |

### Workflow-Konfiguration
- **Branch:** `claude/deploy-testflight-e8NsA`
- **Methode:** xcodebuild cloud-managed signing mit API-Authentifizierung
- **Aktueller Run:** https://github.com/vibrationalforce/Echoelmusic/actions/runs/21565257277

### Was funktioniert ✅
1. **Keychain Setup** - Erstellt temporäre CI-Keychain korrekt
2. **API Key Setup** - Schreibt AuthKey.p8 für xcodebuild
3. **Project Generation** - XcodeGen generiert Xcode-Projekt
4. **Fastlane Start** - Fastlane startet und läuft ~50 Sekunden

### Was fehlschlägt ❌
Der Build schlägt in der "Deploy to TestFlight" Phase fehl. Das wahrscheinlichste Problem:

**Stale Development Certificates:**
- Frühere CI-Runs haben "Apple Development" Zertifikate erstellt
- Die privaten Schlüssel dieser Zertifikate sind verloren (ephemere Runner)
- Xcode versucht, diese Zertifikate zu verwenden, kann aber nicht

---

## 🛠️ NÄCHSTER SCHRITT: Zertifikate bereinigen

### Option 1: Development Zertifikate widerrufen (EMPFOHLEN)

1. Öffne https://developer.apple.com/account/resources/certificates/list
2. Suche nach **"Apple Development"** Zertifikaten
3. **Widerrufe (Revoke)** alle Apple Development Zertifikate
4. **NICHT** die Distribution Zertifikate widerrufen!
5. Führe den Workflow erneut aus:
   ```
   GitHub Actions → TestFlight → Run workflow → ios
   ```

### Option 2: Alle Zertifikate neu erstellen

Wenn Option 1 nicht funktioniert:

1. Öffne https://developer.apple.com/account/resources/certificates/list
2. Widerrufe ALLE Zertifikate (Development und Distribution)
3. Widerrufe auch alle Provisioning Profiles
4. Führe den Workflow erneut aus - Xcode erstellt alles neu

### Option 3: Fastlane Match einrichten (Langfristige Lösung)

Für zuverlässiges CI empfehlen wir Fastlane Match:
- Speichert Zertifikate in einem privaten Git-Repo
- Alle CI-Runs verwenden dieselben Zertifikate
- Dokumentation: https://docs.fastlane.tools/actions/match/

---

## Durchgeführte Fixes (2026-02-01)

| Commit | Beschreibung |
|--------|--------------|
| `0fabc54c` | Robustes Keychain Setup für alle Plattformen |
| `2fbe0611` | CODE_SIGN_IDENTITY Konflikt entfernt |
| `fd1bef90` | cert/sigh Actions hinzugefügt |
| `0648bddf` | Manual signing Ansatz |
| `ab7ebe9a` | Vereinfachte xcargs |
| `2d0dbb94` | get_provisioning_profile mit lane_context |
| `348a12e9` | Debug-Logging hinzugefügt |
| `d2ae7338` | bundle exec entfernt |
| `f5dcf793` | xcodebuild cloud signing (aktueller Stand) |

## Bundle IDs (alle registriert)

```
com.echoelmusic.app           # iOS/macOS/tvOS/visionOS Main
com.echoelmusic.app.widgets   # iOS Widgets Extension
com.echoelmusic.app.Clip      # iOS App Clip
com.echoelmusic.app.auv3      # macOS AUv3 Audio Unit
com.echoelmusic.app.watchkitapp  # watchOS App
```

## Workflow Trigger

### iOS testen
```bash
gh workflow run testflight.yml -f platform=ios -f skip_tests=true --ref claude/deploy-testflight-e8NsA
```

### Alle Plattformen
```bash
gh workflow run testflight.yml -f platform=all -f skip_tests=true --ref claude/deploy-testflight-e8NsA
```

## Bei Erfolg

- [ ] Alle Plattformen testen
- [ ] PR erstellen für main branch
- [ ] TestFlight Links verteilen

## Wichtige Dateien

| Datei | Zweck |
|-------|-------|
| `.github/workflows/testflight.yml` | CI/CD Workflow |
| `fastlane/Fastfile` | Build & Upload Logic |
| `project.yml` | XcodeGen Projekt-Definition |

## Fehlerdiagnose

### "Apple Development signing certificate" Error
→ Development Zertifikate widerrufen (siehe oben)

### "Maximum certificates generated"
→ https://developer.apple.com/account/resources/certificates/list
→ Alte Zertifikate löschen (max 2 erlaubt pro Typ)

### "API Key insufficient permissions"
→ App Store Connect → Users and Access → Integrations
→ API Key braucht "Admin" oder "App Manager" Rolle

### "Profile not found"
→ Workflow verwendet `-allowProvisioningUpdates`
→ Prüfen ob App IDs registriert sind

---
*Letzte Aktualisierung: 2026-02-01 15:20*

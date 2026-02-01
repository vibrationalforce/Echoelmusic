# TestFlight Deployment Status

## Aktueller Stand (2026-02-01)

### 🟡 Status: Bereit zum Testen

**Provisioning-Konflikt behoben** - der Workflow sollte jetzt funktionieren.

`CODE_SIGN_IDENTITY: "Apple Distribution"` wurde entfernt, da es mit `CODE_SIGN_STYLE: Automatic` in Konflikt stand. Xcodebuild wählt bei Automatic Signing die richtige Identity automatisch.

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
- **Signing Style:** Automatic mit `-allowProvisioningUpdates`

### Was funktioniert ✅
1. **Keychain Setup** - Erstellt temporäre CI-Keychain korrekt
2. **API Key Setup** - Schreibt AuthKey.p8 für xcodebuild
3. **Project Generation** - XcodeGen generiert Xcode-Projekt
4. **Fastlane Start** - Fastlane startet korrekt
5. **Zertifikate** - Stale Development Certs widerrufen ✅

### Nächster Schritt ▶️
**Workflow erneut ausführen:**

```bash
gh workflow run testflight.yml -f platform=ios -f skip_tests=true --ref claude/deploy-testflight-e8NsA
```

Oder manuell:
1. GitHub → Actions → TestFlight
2. "Run workflow" klicken
3. Platform: `ios` auswählen
4. "Run workflow" bestätigen

---

## 🔧 Falls der Build erneut fehlschlägt

### Problem: "Maximum certificates generated"
→ https://developer.apple.com/account/resources/certificates/list
→ Alte Distribution Zertifikate löschen (max 2 erlaubt pro Typ)

### Problem: "API Key insufficient permissions"
→ App Store Connect → Users and Access → Integrations
→ API Key braucht "Admin" oder "App Manager" Rolle

### Problem: "Profile not found" oder "Provisioning profile expired"
→ https://developer.apple.com/account/resources/profiles/list
→ Alte Profiles löschen, Workflow erstellt neue automatisch

### Langfristige Lösung: Fastlane Match

Für zuverlässiges CI empfehlen wir Fastlane Match:
- Speichert Zertifikate in einem privaten Git-Repo
- Alle CI-Runs verwenden dieselben Zertifikate
- Dokumentation: https://docs.fastlane.tools/actions/match/

---

## Durchgeführte Fixes (2026-02-01)

| Aktion | Beschreibung | Status |
|--------|--------------|--------|
| `da29b0be` | CODE_SIGN_IDENTITY entfernt (Konflikt mit Automatic) | ✅ |
| Development Cert revoked | Stale Apple Development Zertifikate widerrufen | ✅ |
| `19c456f1` | TESTFLIGHT_STATUS mit nächsten Schritten | ✅ |
| `f5dcf793` | xcodebuild cloud signing (aktueller Ansatz) | ✅ |
| `d2ae7338` | bundle exec entfernt, keychain debug | ✅ |
| `348a12e9` | Debug-Logging hinzugefügt | ✅ |
| `2d0dbb94` | get_provisioning_profile mit lane_context | ✅ |
| `ab7ebe9a` | Vereinfachte xcargs | ✅ |
| `0648bddf` | Manual signing Ansatz (superseded) | ⏭️ |
| `fd1bef90` | cert/sigh Actions (superseded) | ⏭️ |

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

### "Conflicting provisioning settings" Error
→ `CODE_SIGN_IDENTITY` aus project.yml entfernen wenn `CODE_SIGN_STYLE: Automatic` verwendet wird
→ Xcodebuild wählt bei Automatic die richtige Identity (Development für Debug, Distribution für Archive)

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
*Letzte Aktualisierung: 2026-02-01 - Certificate revoked, ready for deployment test*

# TestFlight Deployment Status

## Aktueller Stand (2026-01-31)

### Secrets Status
| Secret | Status |
|--------|--------|
| `APP_STORE_CONNECT_KEY_ID` | ✅ Vorhanden |
| `APP_STORE_CONNECT_ISSUER_ID` | ✅ Vorhanden |
| `APP_STORE_CONNECT_PRIVATE_KEY` | ✅ Vorhanden (.p8 Inhalt) |
| `APPLE_TEAM_ID` | ✅ Vorhanden |
| `DISTRIBUTION_CERTIFICATE_BASE64` | ❌ Nicht nötig (automatisch via API) |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | ❌ Nicht nötig |

### Workflow-Konfiguration
- **Branch:** `claude/deploy-testflight-e8NsA`
- **Letzte Fixes:** Keychain Setup Konsistenz für alle Plattformen
- **Methode:** xcodebuild cloud-managed signing mit API-Authentifizierung

### Letzte Korrekturen (2026-01-31)
1. ✅ **Keychain Setup Fix**: watchOS, tvOS, visionOS Jobs hatten inkonsistentes Keychain Setup
   - Vorher: `security list-keychains -d user -s "$KEYCHAIN_NAME"` (überschreibt alle Keychains)
   - Nachher: `security list-keychains -d user -s "$KEYCHAIN_NAME" $(security list-keychains -d user | tr -d '"')` (behält vorhandene Keychains)
2. ✅ **API Key Validierung**: Hinzugefügt in allen Plattform-Jobs
3. ✅ **Verbesserte Logging**: Retry-Logik mit detaillierten Ausgaben

### Bundle IDs (alle registriert)
```
com.echoelmusic.app           # iOS/macOS/tvOS/visionOS Main
com.echoelmusic.app.widgets   # iOS Widgets Extension
com.echoelmusic.app.Clip      # iOS App Clip
com.echoelmusic.app.auv3      # macOS AUv3 Audio Unit
com.echoelmusic.app.watchkitapp  # watchOS App
```

## Nächste Schritte

### 1. Workflow testen
```
GitHub Actions → TestFlight → Run workflow → ios
```

### 2. Bei Erfolg
- [ ] Alle Plattformen testen (all)
- [ ] PR erstellen für main branch
- [ ] TestFlight Link teilen

### 3. Bei Fehlern prüfen

#### "Maximum certificates generated"
→ https://developer.apple.com/account/resources/certificates/list
→ Alte Zertifikate löschen (max 2 erlaubt)

#### "API Key insufficient permissions"
→ App Store Connect → Users and Access → Integrations
→ API Key braucht "Admin" oder "App Manager" Rolle

#### "Profile not found"
→ Fastlane erstellt Profile automatisch
→ Prüfen ob App IDs registriert sind

#### "Code sign error"
→ Logs prüfen ob API Key korrekt geladen wird
→ Team ID prüfen

## Ralph Wiggum Loop Checklist

```
[ ] Scan    - Workflow Logs lesen
[ ] Plan    - Fehler identifizieren
[ ] Execute - Fix implementieren
[ ] Validate - Erneut testen
[ ] Loop    - Bis es funktioniert
```

## Wichtige Dateien

| Datei | Zweck |
|-------|-------|
| `.github/workflows/testflight.yml` | CI/CD Workflow |
| `fastlane/Fastfile` | Build & Upload Logic |
| `fastlane/Appfile` | Bundle IDs & Team |
| `project.yml` | XcodeGen Projekt-Definition |
| `docs/TESTFLIGHT_SETUP.md` | Setup-Anleitung |

## Entwicklungsumgebung

```
iPhone → Claude Code → Git Push → GitHub Actions → Fastlane → TestFlight
         ↓
      XcodeGen (project.yml → Echoelmusic.xcodeproj)
         ↓
      Kein Mac nötig! Alles via API.
```

## Letzte Änderungen

1. ✅ Manuellen Certificate-Import entfernt (kein .p12 nötig)
2. ✅ `generate_apple_certs: true` für alle Plattformen
3. ✅ Konsistente API-Key-Setup Schritte
4. ✅ Dokumentation aktualisiert
5. ✅ Keychain Setup für watchOS/tvOS/visionOS korrigiert (behält vorhandene Keychains)
6. ✅ API Key File Validierung hinzugefügt
7. ✅ Verbesserte Retry-Logik mit detaillierter Ausgabe

## Bekannte Issues & Lösungen

### "Keychain not accessible" oder "No identity found"
→ Das neue Keychain-Setup erhält vorhandene Keychains, was dieses Problem beheben sollte.

### "Code sign error" bei watchOS/tvOS/visionOS
→ Stellen Sie sicher, dass die App IDs in developer.apple.com registriert sind:
- `com.echoelmusic.app.watchkitapp` (watchOS)
- `com.echoelmusic.app` (tvOS, visionOS)

### "Provisioning profile doesn't include signing certificate"
→ Xcodebuild mit `-allowProvisioningUpdates` sollte automatisch Profile erstellen.
→ Falls nicht: Überprüfen Sie die Zertifikate unter https://developer.apple.com/account/resources/certificates/list

---
*Ralph Wiggum sagt: "Das Zertifikat ist in der Cloud, und die Cloud ist im Computer!"*

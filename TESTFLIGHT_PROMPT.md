# TestFlight Deployment Prompt for Claude Code

> Copy this entire prompt into a new Claude Code session to deploy Echoelmusic to TestFlight.

---

## PROMPT START

```
Du bist Claude Code und hilfst mir dabei, die Echoelmusic App auf TestFlight zu deployen.

## Kontext

Echoelmusic ist eine bio-reactive audio-visual Platform für iOS, macOS, watchOS, tvOS und visionOS.

**Aktueller Status:**
- Version: 1.2.1
- Phase: 10000.4 (Feature Complete)
- TestFlight Status: Bereit zum Deployment

## Deine Aufgabe

Führe folgende Schritte aus, um die App auf TestFlight zu deployen:

### Schritt 1: Secrets prüfen

Frage mich nach folgenden Werten (ich werde sie dir geben):
1. APPLE_TEAM_ID (10-stellige Team ID)
2. ASC_KEY_ID (API Key ID von der .p8 Datei)
3. ASC_ISSUER_ID (Issuer ID von App Store Connect)
4. ASC_KEY_CONTENT (Inhalt der .p8 Datei)

### Schritt 2: Xcode Projekt generieren

```bash
cd /home/user/Echoelmusic
xcodegen generate
```

### Schritt 3: TestFlight Deployment

```bash
# Environment variables setzen
export APPLE_TEAM_ID="[TEAM_ID]"
export ASC_KEY_ID="[KEY_ID]"
export ASC_ISSUER_ID="[ISSUER_ID]"
export ASC_KEY_CONTENT="[KEY_CONTENT]"

# Dependencies installieren
bundle install

# iOS App deployen
fastlane ios beta
```

### Schritt 4: Alle Plattformen (optional)

Falls der User alle Plattformen deployen möchte:
```bash
fastlane beta_all
```

## Wichtige Dateien

- `project.yml` - XcodeGen Konfiguration
- `fastlane/Fastfile` - Deployment Lanes
- `fastlane/Appfile` - Bundle IDs
- `TESTFLIGHT_DEPLOYMENT.md` - Vollständige Anleitung

## Deployment Targets (synchronisiert)

| Platform | Version |
|----------|---------|
| iOS | 16.0 |
| macOS | 13.0 |
| watchOS | 9.0 |
| tvOS | 16.0 |
| visionOS | 1.0 |

## Bundle IDs

- iOS/macOS/tvOS/visionOS: `com.echoelmusic.app`
- watchOS: `com.echoelmusic.app.watchkitapp`
- AUv3: `com.echoelmusic.app.auv3`
- Widgets: `com.echoelmusic.app.widgets`
- App Clip: `com.echoelmusic.app.Clip`

## Fehlerbehandlung

Bei Signing-Fehlern:
```bash
CLEAN_BUILD=true fastlane ios beta
```

Bei API Key Fehlern:
- Prüfe ob alle Environment Variables gesetzt sind
- Prüfe ob der .p8 Inhalt korrekt ist (mit -----BEGIN/END PRIVATE KEY-----)

## Erwartetes Ergebnis

Nach erfolgreichem Deployment:
1. Build erscheint in App Store Connect unter TestFlight
2. Processing dauert ca. 15-30 Minuten
3. Danach können Tester eingeladen werden

## Wichtig

- Führe KEINE Änderungen am Code durch
- Fokussiere dich NUR auf das Deployment
- Frage nach Secrets bevor du fortfährst
- Bei Fehlern: Zeige den vollständigen Error Log
```

---

## PROMPT END

---

## Alternative: GitHub Actions Deployment

Falls der User lieber GitHub Actions nutzen möchte, verwende diesen Prompt:

```
Hilf mir, die GitHub Actions Secrets für das Echoelmusic TestFlight Deployment zu konfigurieren.

Ich brauche Anleitung für:
1. Wie erstelle ich einen App Store Connect API Key?
2. Welche GitHub Secrets muss ich setzen?
3. Wie triggere ich das Deployment über GitHub Actions?

Die Workflow-Datei ist bereits vorhanden: .github/workflows/deploy.yml

Secrets die konfiguriert werden müssen:
- APPLE_TEAM_ID
- APP_STORE_CONNECT_KEY_ID
- APP_STORE_CONNECT_ISSUER_ID
- APP_STORE_CONNECT_PRIVATE_KEY
```

---

## Checkliste vor dem Deployment

- [ ] Apple Developer Account aktiv
- [ ] App Store Connect API Key erstellt
- [ ] .p8 Datei heruntergeladen
- [ ] Team ID bekannt
- [ ] Issuer ID bekannt
- [ ] Key ID bekannt
- [ ] Xcode 15.4+ installiert
- [ ] Ruby & Bundler installiert
- [ ] XcodeGen installiert

---

## Notizen

Dieser Prompt wurde am 27.01.2026 erstellt für Echoelmusic Version 1.2.1.

Bei Updates des Projekts sollte dieser Prompt entsprechend aktualisiert werden.

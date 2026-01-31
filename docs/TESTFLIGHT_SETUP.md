# TestFlight CI/CD Setup Guide

## Die Lösung: Automatisches Signing via API

Echoelmusic nutzt **Fastlane mit App Store Connect API** für vollautomatisches Code Signing.
Keine lokalen Zertifikate (.p12) nötig - alles passiert in der Cloud!

## Benötigte GitHub Secrets (4 Stück)

| Secret | Beschreibung | Format |
|--------|--------------|--------|
| `APP_STORE_CONNECT_KEY_ID` | API Key ID | ~10 Zeichen (z.B. `ABC123XYZ`) |
| `APP_STORE_CONNECT_ISSUER_ID` | Team Issuer UUID | 36 Zeichen UUID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | AuthKey_XXX.p8 Inhalt | PEM Format mit `-----BEGIN PRIVATE KEY-----` |
| `APPLE_TEAM_ID` | 10-stellige Team ID | 10 Zeichen (z.B. `ABCD1234EF`) |

## Setup Anleitung

### Schritt 1: API Key erstellen

1. Öffne https://appstoreconnect.apple.com/access/integrations/api
2. Klicke "+" um einen neuen Key zu erstellen
3. Name: `CI/CD Key` (oder ähnlich)
4. Zugriff: **Admin** oder **App Manager**
5. Lade die `.p8` Datei herunter (nur einmal möglich!)
6. Notiere die **Key ID** und **Issuer ID**

### Schritt 2: GitHub Secrets konfigurieren

Gehe zu: `https://github.com/DEIN-USERNAME/Echoelmusic/settings/secrets/actions`

1. **APP_STORE_CONNECT_KEY_ID**: Die Key ID aus Schritt 1
2. **APP_STORE_CONNECT_ISSUER_ID**: Die Issuer ID aus Schritt 1
3. **APP_STORE_CONNECT_PRIVATE_KEY**: Den kompletten Inhalt der .p8 Datei:
   ```
   -----BEGIN PRIVATE KEY-----
   MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkw...
   -----END PRIVATE KEY-----
   ```
4. **APPLE_TEAM_ID**: Deine Team ID (findest du unter https://developer.apple.com/account)

### Schritt 3: Workflow starten

1. Gehe zu Actions → "TestFlight"
2. Klicke "Run workflow"
3. Wähle Plattform (ios, macos, all, etc.)
4. Fertig! 🎉

## Wie funktioniert das?

Fastlane nutzt `get_certificates` mit `generate_apple_certs: true`:

1. **Zertifikate**: Werden automatisch via API erstellt/heruntergeladen
2. **Provisioning Profiles**: Werden via `sigh` automatisch erstellt
3. **Signing**: Passiert mit `-allowProvisioningUpdates` Flag

```ruby
# Fastfile Auszug
get_certificates(
  api_key: api_key,
  platform: "ios",
  type: "appstore",
  generate_apple_certs: true,  # <- Das ist der Schlüssel!
  keychain_path: keychain[:path],
  keychain_password: keychain[:password]
)
```

## Bundle IDs

| App | Bundle ID |
|-----|-----------|
| iOS Main | `com.echoelmusic.app` |
| iOS Widgets | `com.echoelmusic.app.widgets` |
| iOS App Clip | `com.echoelmusic.app.Clip` |
| macOS Main | `com.echoelmusic.app` |
| macOS AUv3 | `com.echoelmusic.app.auv3` |
| watchOS | `com.echoelmusic.app.watchkitapp` |

## Fehlerbehebung

### "Maximum number of certificates generated"

Apple limitiert Distribution Certificates auf 2. Lösche alte unter:
https://developer.apple.com/account/resources/certificates/list

Fastlane versucht zuerst, existierende Zertifikate wiederzuverwenden.

### "API Key has insufficient permissions"

Der API Key braucht **Admin** oder **App Manager** Rolle.

### "No profiles found"

Die Provisioning Profiles werden automatisch erstellt wenn:
1. Der API Key ausreichend Berechtigungen hat
2. Die App ID registriert ist (passiert automatisch)
3. Die Bundle ID korrekt ist

### Build schlägt bei Signing fehl

Prüfe in den Logs:
- Wird der API Key korrekt geladen?
- Ist die Team ID korrekt?
- Hat der API Key Admin-Rechte?

## Plattformen

| Plattform | Workflow Input | Fastlane Lane |
|-----------|----------------|---------------|
| iOS | `ios` | `fastlane ios beta` |
| macOS | `macos` | `fastlane mac beta` |
| watchOS | `watchos` | `fastlane ios beta_watchos` |
| tvOS | `tvos` | `fastlane ios beta_tvos` |
| visionOS | `visionos` | `fastlane ios beta_visionos` |
| Alle | `all` | Parallel alle Plattformen |

## Vorteile dieser Lösung

- **Kein Mac nötig** - Alles via API
- **Kein .p12 Export** - Zertifikate werden automatisch erstellt
- **Kein Keychain-Passwort** - CI erstellt temporäre Keychain
- **Automatische Profile** - Werden bei Bedarf erstellt/erneuert
- **iPhone-Entwicklung möglich** - Mit Claude Code + XcodeGen + Fastlane

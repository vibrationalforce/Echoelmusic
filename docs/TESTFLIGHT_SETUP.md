# TestFlight CI/CD Setup Guide

## Das Problem

Xcode's "Automatic Signing" funktioniert in CI **nicht ohne lokale Certificates**. Die Fehlermeldungen:

```
No signing certificate "iPhone Developer" found
No profiles for 'com.echoelmusic.app' were found
```

## Die Lösung: Distribution Certificate als Secret

Du brauchst 2 zusätzliche GitHub Secrets:

| Secret | Beschreibung |
|--------|--------------|
| `DISTRIBUTION_CERTIFICATE_BASE64` | Dein Apple Distribution Certificate (.p12) als Base64 |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | Das Passwort der .p12 Datei |

### Schritt 1: Certificate exportieren

1. Öffne **Keychain Access** auf deinem Mac
2. Finde dein **Apple Distribution** Certificate (unter "Meine Zertifikate")
3. Rechtsklick → **Exportieren...**
4. Format: `.p12`
5. Wähle ein sicheres Passwort

### Schritt 2: Base64 konvertieren

```bash
base64 -i certificate.p12 | pbcopy
```

Der Base64-String ist jetzt in deiner Zwischenablage.

### Schritt 3: GitHub Secrets hinzufügen

Gehe zu: `https://github.com/DEIN-USERNAME/Echoelmusic/settings/secrets/actions`

1. **DISTRIBUTION_CERTIFICATE_BASE64**: Füge den Base64-String ein
2. **DISTRIBUTION_CERTIFICATE_PASSWORD**: Das Passwort aus Schritt 1

### Vollständige Secret-Liste

| Secret | Status | Hinweis |
|--------|--------|---------|
| `APP_STORE_CONNECT_KEY_ID` | ✅ Vorhanden | API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | ✅ Vorhanden | Team Issuer UUID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | ✅ Vorhanden | AuthKey_XXX.p8 Inhalt |
| `APPLE_TEAM_ID` | ✅ Vorhanden | 10-stellige Team ID |
| `DISTRIBUTION_CERTIFICATE_BASE64` | ❌ **NEU** | .p12 als Base64 |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | ❌ **NEU** | .p12 Passwort |

## Kein Certificate? Neues erstellen!

Falls du noch kein Distribution Certificate hast:

1. Öffne https://developer.apple.com/account/resources/certificates/list
2. Klicke "+" → "Apple Distribution"
3. Erstelle einen CSR mit Keychain Access
4. Lade das Certificate herunter
5. Doppelklick zum Installieren
6. Exportiere als .p12 (siehe oben)

## Alternative: Fastlane Match (empfohlen für Teams)

Für Teams mit mehreren Entwicklern empfehlen wir [Fastlane Match](https://docs.fastlane.tools/actions/match/).

Match verwaltet Certificates und Profiles zentral in einem privaten Git-Repo.

```ruby
# Matchfile
git_url("git@github.com:your-org/certificates.git")
type("appstore")
app_identifier(["com.echoelmusic.app", "com.echoelmusic.app.widgets"])
```

## Fehlerbehebung

### "Maximum number of certificates generated"

Apple limitiert die Anzahl der Distribution Certificates auf 2. Lösche alte über:
https://developer.apple.com/account/resources/certificates/list

### "No profiles found"

Die Provisioning Profiles werden automatisch erstellt wenn:
1. Das Certificate korrekt im Keychain ist
2. Die App ID registriert ist (wird automatisch erstellt)
3. Der API Key "Admin" oder "App Manager" Rolle hat

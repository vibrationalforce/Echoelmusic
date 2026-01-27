# App Clip Website Setup - echoelmusic.com

## Übersicht

Dieses Dokument beschreibt alle Schritte, die auf der Website `echoelmusic.com` durchgeführt werden müssen, damit der Echoelmusic App Clip funktioniert.

---

## 1. Apple App Site Association (AASA) Datei

### Deployment

Die Datei `.well-known/apple-app-site-association` muss im Root der Domain liegen:

```
https://echoelmusic.com/.well-known/apple-app-site-association
```

### Wichtig

1. **TEAM_ID ersetzen** - Ersetze `TEAM_ID` mit deiner Apple Developer Team ID
   - Findest du unter: https://developer.apple.com/account → Membership → Team ID
   - Format: `XXXXXXXXXX` (10 Zeichen)

2. **Content-Type** - Die Datei muss mit `application/json` ausgeliefert werden

3. **HTTPS** - Muss über HTTPS erreichbar sein (kein HTTP)

4. **Kein Redirect** - Darf nicht umgeleitet werden

### Nginx Konfiguration

```nginx
location /.well-known/apple-app-site-association {
    default_type application/json;
    add_header Cache-Control "max-age=3600";
}
```

### Apache Konfiguration

```apache
<Files "apple-app-site-association">
    Header set Content-Type "application/json"
</Files>
```

---

## 2. App Clip Meta Tags

Auf allen Seiten, die den App Clip auslösen sollen, diese Meta Tags im `<head>`:

```html
<!-- App Clip Meta Tags für echoelmusic.com/clip/* -->
<meta name="apple-itunes-app" content="app-clip-bundle-id=com.echoelmusic.app.Clip, app-id=XXXXXXXXXX">
```

### Für spezifische Sessions

**Breathwork Session:**
```html
<!-- https://echoelmusic.com/clip/breathwork -->
<meta name="apple-itunes-app" content="app-clip-bundle-id=com.echoelmusic.app.Clip, app-id=XXXXXXXXXX, app-clip-display=card">
```

---

## 3. Smart App Banner

Zeigt Banner auf der Website, der zum App Clip oder Full App führt:

```html
<meta name="apple-itunes-app" content="app-id=XXXXXXXXXX, app-clip-bundle-id=com.echoelmusic.app.Clip, app-clip-display=card">
```

---

## 4. Open Graph Tags für App Clip Cards

Für schöne Vorschau-Karten in Messages, Social Media:

```html
<!-- Standard OG Tags -->
<meta property="og:title" content="Echoelmusic Quick Session">
<meta property="og:description" content="Starte eine bio-reaktive Meditation in Sekunden">
<meta property="og:image" content="https://echoelmusic.com/images/appclip-card.png">
<meta property="og:url" content="https://echoelmusic.com/clip/breathwork">
<meta property="og:type" content="website">

<!-- App Clip spezifisch -->
<meta name="apple-mobile-web-app-capable" content="yes">
```

### Empfohlene Bildgrößen

| Verwendung | Größe | Format |
|------------|-------|--------|
| App Clip Card | 1200 x 630 px | PNG/JPG |
| App Clip Code Header | 1024 x 1024 px | PNG |

---

## 5. URL-Struktur

### Aktive Routen für App Clip

| Route | Beschreibung |
|-------|--------------|
| `/clip/breathwork` | 3 min Box Breathing |
| `/clip/meditation` | 5 min Kurzmeditation |
| `/clip/coherence` | 2 min Coherence Check |
| `/clip/soundbath` | 3 min Sound Bath |
| `/clip/energize` | 1.5 min Energie-Boost |
| `/clip/event/{id}` | Event-spezifische Session |
| `/clip/venue/{id}` | Venue-spezifische Session |

### Query Parameter

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `duration` | Int (Sekunden) | Custom Dauer (max 300s) |
| `session` | String | Session-Typ für Venue |

**Beispiele:**
```
https://echoelmusic.com/clip/meditation?duration=180
https://echoelmusic.com/clip/venue/yoga-studio-berlin?session=breathwork
```

---

## 6. Landing Pages

Für jeden Session-Typ sollte eine Fallback-Webseite existieren (für Nicht-iOS-Nutzer):

```
/clip/breathwork/index.html
/clip/meditation/index.html
/clip/coherence/index.html
/clip/soundbath/index.html
/clip/energize/index.html
```

### Inhalt der Landing Pages

1. Session-Beschreibung
2. App Store Link zur Vollversion
3. Web-basierte Alternative (falls vorhanden)
4. Android Play Store Link

---

## 7. App Clip Codes erstellen

In App Store Connect unter "App Clip Experiences":

1. **Default Experience** erstellen
   - URL: `https://echoelmusic.com/clip`
   - Titel: "Echoelmusic Quick Session"
   - Untertitel: "Bio-reaktive Meditation"

2. **Advanced Experiences** für jede Session
   - Breathwork: `https://echoelmusic.com/clip/breathwork`
   - Meditation: `https://echoelmusic.com/clip/meditation`
   - etc.

### App Clip Code Design

- **Badge Style**: Ring oder Camera (empfohlen: Camera für bessere Erkennung)
- **Farbe**: Passend zu Echoelmusic Branding (Purple/Blue Gradient)
- **Download**: SVG für Print, PNG für Digital

---

## 8. Validierung

### AASA Validator Tools

1. **Apple's Validator:**
   https://search.developer.apple.com/appsearch-validation-tool/

2. **Branch.io Validator:**
   https://branch.io/resources/aasa-validator/

### Checkliste

- [ ] AASA Datei deployed
- [ ] TEAM_ID ersetzt
- [ ] Content-Type ist `application/json`
- [ ] HTTPS aktiv (kein Mixed Content)
- [ ] Meta Tags auf Landing Pages
- [ ] OG Images hochgeladen
- [ ] Landing Pages für alle Sessions
- [ ] App Clip Experience in App Store Connect erstellt
- [ ] App Clip Codes generiert

---

## 9. Debugging

### Safari Web Inspector

1. Öffne Safari auf Mac
2. Aktiviere "Entwickler" Menü (Einstellungen → Erweitert)
3. Verbinde iPhone
4. Safari → Entwickler → [iPhone] → echoelmusic.com
5. Console zeigt AASA-Fehler

### Console App (Mac)

1. Öffne Console.app
2. Filtere nach: `swcd` oder `apsd`
3. Scanne QR/NFC und beobachte Logs

### Xcode Environment Variable

Für lokales Testen:
```
_XCAppClipURL = https://echoelmusic.com/clip/breathwork
```

---

## 10. Kontakte

**Apple Developer Support:**
https://developer.apple.com/contact/

**App Clip Dokumentation:**
https://developer.apple.com/documentation/app_clips

---

*Zuletzt aktualisiert: 2026-01-27*

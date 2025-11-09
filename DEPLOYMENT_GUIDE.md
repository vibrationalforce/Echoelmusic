# Deployment Guide - Echoelmusic

**GitHub, Website, Server, App Store Deployment**

---

## 🐙 GITHUB SETUP

### 1. Repository umbenennen (blab-ios-app → echoelmusic)

**Option A: Via GitHub Web Interface (Einfachste Methode)**

1. Gehe zu: https://github.com/vibrationalforce/blab-ios-app
2. Klicke auf **Settings** (oben rechts)
3. Unter "Repository name" ändere zu: **echoelmusic**
4. Klicke **Rename**
5. ✅ **Fertig!** GitHub leitet alte URLs automatisch um

**Option B: Via Command Line**

```bash
# Lokal umbenennen ist NICHT nötig (nur auf GitHub umbenennen)
# Aber falls gewünscht:
cd /pfad/zu/blab-ios-app
mv blab-ios-app echoelmusic

# Remote URL aktualisieren (nach GitHub-Umbenennung)
git remote set-url origin https://github.com/vibrationalforce/echoelmusic.git
```

**⚠️ WICHTIG:**
- GitHub leitet **automatisch** um: `blab-ios-app` → `echoelmusic` (301 Redirect)
- Alte Links funktionieren weiter (keine Sorge)
- Git-Clients aktualisieren sich automatisch

---

### 2. GitHub Account - Brauchen Sie Premium?

**GitHub Free (Kostenlos) ✅ - AUSREICHEND**

**Inklusive:**
- ✅ Unbegrenzte öffentliche Repositories
- ✅ Unbegrenzte private Repositories
- ✅ GitHub Actions: 2,000 Minuten/Monat (CI/CD)
- ✅ GitHub Pages: Kostenlose Website-Hosting
- ✅ 500MB Package Storage
- ✅ Community Support

**GitHub Pro ($4/Monat) - Optional**

**Zusätzlich:**
- 3,000 Actions Minuten/Monat (vs. 2,000)
- 2GB Package Storage (vs. 500MB)
- Geschützter Branch (erweiterte Regeln)
- Code-Besitzer (CODEOWNERS)
- Insights (Traffic, Dependents)

**GitHub Team ($4/User/Monat) - Für Teams**

**GitHub Enterprise ($21/User/Monat) - Für Firmen**

**Empfehlung für Echoelmusic:**
- **Phase 1** (Solo-Entwicklung): **GitHub Free** ✅
- **Phase 2** (Beta-Testing): **GitHub Pro** (optional)
- **Phase 3** (Team >3 Personen): **GitHub Team**

**Fazit**: GitHub Free ist völlig ausreichend! ✅

---

### 3. GitHub Pages (Kostenlose Website)

**Setup (5 Minuten):**

1. Erstelle Branch `gh-pages` oder Ordner `docs/`
2. Aktiviere GitHub Pages in **Settings** → **Pages**
3. Website ist live auf: `https://vibrationalforce.github.io/echoelmusic/`

**Beispiel-Website (`docs/index.html`):**

```html
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Echoelmusic - Bio-Reactive Creative Platform</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
            padding: 50px;
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        .features { display: flex; justify-content: center; gap: 30px; flex-wrap: wrap; }
        .feature { background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; max-width: 300px; }
    </style>
</head>
<body>
    <h1>🎵 Echoelmusic</h1>
    <p>Bio-Reactive Creative Platform for iOS/iPadOS</p>

    <div class="features">
        <div class="feature">
            <h3>🧬 Biofeedback</h3>
            <p>HRV, EEG, Motion → Music</p>
        </div>
        <div class="feature">
            <h3>🎬 Chroma Key</h3>
            <p>Real-time Greenscreen (120fps)</p>
        </div>
        <div class="feature">
            <h3>🎮 Gamification</h3>
            <p>Achievements, Levels, Rewards</p>
        </div>
        <div class="feature">
            <h3>🔬 Evidence-Based</h3>
            <p>PubMed-Level Science</p>
        </div>
    </div>

    <p><a href="https://github.com/vibrationalforce/echoelmusic" style="color: white;">View on GitHub</a></p>
</body>
</html>
```

**Custom Domain (Optional):**
- Kaufe Domain: `echoelmusic.com` (~10€/Jahr bei Namecheap, Google Domains)
- In GitHub Settings → Pages: Füge Custom Domain hinzu
- Kostenlos! ✅

---

### 4. GitHub Actions (CI/CD)

**Automatisches Testen & Bauen:**

`.github/workflows/ios.yml`:

```yaml
name: iOS Build & Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.0'

    - name: Install Dependencies
      run: |
        cd blab-ios-app
        # Falls CocoaPods:
        # pod install

    - name: Build
      run: |
        xcodebuild -scheme Echoelmusic \
                   -destination 'platform=iOS Simulator,name=iPhone 14 Pro' \
                   build

    - name: Run Tests
      run: |
        xcodebuild -scheme Echoelmusic \
                   -destination 'platform=iOS Simulator,name=iPhone 14 Pro' \
                   test
```

**Kostenloses Kontingent:**
- 2,000 Minuten/Monat (macOS) ✅
- ~30 Builds/Monat (je ~60 Minuten Build-Zeit)

---

## 🌐 WEBSITE & SERVER

### Option 1: Nur iOS App (Kein Server nötig) ✅

**Vorteile:**
- ✅ **Kostenlos** (kein Server)
- ✅ **Privatsphäre** (alles lokal)
- ✅ **Offline-fähig**
- ✅ **Keine Wartung**

**Features ohne Server:**
- On-Device Processing (Chroma Key, Audio, Biofeedback)
- Local Storage (CoreData, UserDefaults)
- iCloud Sync (kostenlos für Nutzer mit iCloud)
- GitHub Pages (Landing Page)

**Empfehlung**: Starten Sie so! Server später hinzufügen falls nötig.

---

### Option 2: Serverless (Pay-Per-Use) 💰

**Firebase (Google) - Free Tier ✅**

**Inklusive (kostenlos):**
- **Authentication**: 10,000 Nutzer/Monat
- **Firestore Database**: 1GB Speicher, 10GB Transfer
- **Cloud Storage**: 5GB
- **Cloud Functions**: 2M Invocations/Monat
- **Hosting**: 10GB Transfer/Monat

**Setup:**
```bash
# Firebase installieren
npm install -g firebase-tools
firebase login
firebase init

# Firestore-Regeln (Privacy-First)
# firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;  // Nur eigene Daten
    }
  }
}
```

**Kosten (bei Wachstum):**
- <1,000 Nutzer: **Kostenlos** ✅
- 10,000 Nutzer: ~$25/Monat
- 100,000 Nutzer: ~$250/Monat

---

### Option 3: Dedicated Server (Volle Kontrolle) 💰💰

**Vergleich:**

| Provider | Plan | CPU | RAM | Speicher | Traffic | Preis/Monat |
|----------|------|-----|-----|----------|---------|-------------|
| **Hetzner** (Deutschland) | CX11 | 1 vCore | 2GB | 20GB | 20TB | **€4** ✅ |
| **DigitalOcean** | Droplet | 1 vCPU | 1GB | 25GB | 1TB | $6 |
| **AWS Lightsail** | Nano | 1 vCPU | 512MB | 20GB | 1TB | $3.50 |
| **Linode** | Nanode | 1 vCPU | 1GB | 25GB | 1TB | $5 |

**Empfehlung**: Hetzner (EU, DSGVO-konform, günstig) ✅

**Setup (Hetzner Cloud):**

```bash
# 1. Server erstellen (via Hetzner Web Console)
# 2. SSH verbinden
ssh root@your-server-ip

# 3. Node.js Server (Express)
apt update && apt install -y nodejs npm nginx
npm init -y
npm install express

# 4. Einfacher Server (server.js)
cat > server.js << 'EOF'
const express = require('express');
const app = express();

app.get('/', (req, res) => {
    res.json({ message: 'Echoelmusic API' });
});

app.listen(3000, () => {
    console.log('Server running on port 3000');
});
EOF

# 5. Nginx Reverse Proxy (SSL)
apt install -y certbot python3-certbot-nginx
certbot --nginx -d echoelmusic.com

# 6. Systemd Service (Auto-Start)
cat > /etc/systemd/system/echoelmusic.service << 'EOF'
[Unit]
Description=Echoelmusic API Server

[Service]
ExecStart=/usr/bin/node /root/server.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable echoelmusic
systemctl start echoelmusic
```

**Kosten**: €4/Monat ✅

---

### Option 4: Hybrid (Serverless + CDN) 🏆

**Beste Lösung für Skalierung:**

```
[iOS App] → [Cloudflare CDN (kostenlos)]
                    ↓
            [Vercel/Netlify (kostenlos)]
                    ↓
            [Firebase (kostenlos)]
```

**Vorteile:**
- ✅ **99.9% Uptime** (Global CDN)
- ✅ **Kostenlos** bis 100,000 Nutzer
- ✅ **Auto-Scaling** (kein Server-Management)
- ✅ **SSL** (automatisch)

**Setup:**

```bash
# 1. Vercel installieren
npm install -g vercel

# 2. API deployen
cd api/
vercel deploy

# 3. Custom Domain
vercel domains add echoelmusic.com
```

**Kosten**: **Kostenlos** ✅ (bis 100GB Traffic/Monat)

---

## 📱 APP STORE DEPLOYMENT

### 1. Apple Developer Program

**Kosten**: $99/Jahr (erforderlich für App Store)

**Anmeldung:**
1. https://developer.apple.com/programs/enroll/
2. Apple ID
3. Zahlung ($99)
4. Aktivierung (24h)

**Inklusive:**
- App Store Distribution
- TestFlight (Beta-Testing)
- Push Notifications
- CloudKit (Backend)
- App Analytics

---

### 2. App Store Connect

**Vorbereitung:**

1. **App ID erstellen** (developer.apple.com)
   - Bundle ID: `com.vibrationalforce.echoelmusic`

2. **Certificates & Provisioning**
   ```bash
   # In Xcode: Preferences → Accounts → Download Manual Profiles
   # Oder: Automatic Signing (empfohlen)
   ```

3. **App Store Connect** (appstoreconnect.apple.com)
   - Neue App erstellen
   - Metadaten: Name, Beschreibung, Screenshots, Keywords
   - Pricing: Kostenlos oder Paid

4. **Archive & Upload**
   ```bash
   # Xcode
   Product → Archive
   → Distribute App → App Store Connect
   → Upload
   ```

5. **TestFlight** (Beta)
   - Interne Tester (100 max)
   - Externe Tester (10,000 max, 90-Tage-Limit)

6. **App Review einreichen**
   - Durchschnittliche Wartezeit: 1-3 Tage
   - Rejection Rate: ~40% (meist Metadata-Probleme)

---

### 3. Monetarisierung

**Optionen:**

**A. Kostenlos (Freemium) ✅ Empfohlen**
- App kostenlos
- In-App-Käufe (Unlock Features)
- Nicht-invasiv (keine Werbung)

**B. Paid ($4.99-$14.99)**
- Einmalzahlung
- Alle Features

**C. Subscription ($2.99/Monat)**
- Wiederkehrende Einnahmen
- Cloud-Sync, Premium-Features

**D. Hybrid**
- Basis kostenlos
- Pro-Version $9.99 (einmalig)
- Optional: Cloud-Sync $1.99/Monat

**Empfehlung für Echoelmusic:**
```
Kostenlos: Basis-Features (Audio, Visualizer, Local Storage)
Pro Unlock: $9.99 einmalig
    → Chroma Key (Greenscreen)
    → Dolby Atmos Export
    → 4K Video
    → Bio-Reactive Advanced
    → iCloud Sync

Optional Cloud+ : $2.99/Monat
    → Unbegrenzte Cloud-Speicher
    → Multi-Device Sync
    → Leaderboards
```

---

## 🔐 PRIVACY & DSGVO

**EU General Data Protection Regulation (DSGVO) Compliance:**

### Erforderlich (iOS App):

1. **Privacy Policy** (Datenschutzerklärung)
   - Was wird gespeichert? (lokal vs. cloud)
   - Biofeedback-Daten: Lokal, nicht geteilt
   - Analytics: Opt-In (nicht Opt-Out)

2. **Privacy Manifest** (iOS 17+)
   - `PrivacyInfo.xcprivacy` (bereits erstellt in früheren Sessions)
   - Deklariere API-Nutzung (Camera, Microphone, HealthKit)

3. **Consent (Einwilligung)**
   ```swift
   // Beim ersten Start
   if !UserDefaults.standard.bool(forKey: "privacy_consent") {
       showPrivacyConsentDialog()
   }
   ```

4. **Data Export/Deletion**
   ```swift
   // DSGVO Artikel 17 (Recht auf Löschung)
   func deleteAllUserData() {
       // Lokal löschen
       UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
       // Cloud löschen (falls vorhanden)
   }
   ```

5. **No Tracking ohne Consent**
   - App Tracking Transparency (ATT) Framework
   - Firebase Analytics: Opt-In

**Template Privacy Policy:**
https://www.privacypolicygenerator.info/

**DSGVO-Konform = Wettbewerbsvorteil in EU** ✅

---

## 📊 ANALYTICS (Privacy-Friendly)

**Option 1: Apple Analytics (Kostenlos, Privacy-First) ✅**

- In App Store Connect
- Aggregated (keine individuellen Nutzer)
- Retention, Crashes, Session Length

**Option 2: Firebase Analytics (Kostenlos, Opt-In)**

```swift
// Privacy-freundlich konfigurieren
FirebaseApp.configure()
Analytics.setAnalyticsCollectionEnabled(false)  // Default: OFF

// Nur mit Consent
if UserDefaults.standard.bool(forKey: "analytics_consent") {
    Analytics.setAnalyticsCollectionEnabled(true)
}
```

**Option 3: Telemetry (selbst gehostet)**

- Plausible Analytics (Open Source, DSGVO-konform)
- Matomo (Open Source)
- Self-hosted auf Hetzner (€4/Monat)

---

## 🚀 DEPLOYMENT ROADMAP

### Phase 1: MVP (Minimum Viable Product) - Monat 1-2

**Features:**
- Audio Engine (Biofeedback, FFT, Visualizer)
- Basic UI (SwiftUI)
- Local Storage (CoreData)
- GitHub (Public Repo)
- GitHub Pages (Landing Page)

**Kosten**: **€0** ✅

---

### Phase 2: Beta - Monat 3-4

**Features:**
- Chroma Key (Greenscreen)
- Gamification (Achievements)
- TestFlight (100 Beta-Tester)
- iCloud Sync (kostenlos für Nutzer)

**Kosten**:
- Apple Developer: $99/Jahr ✅
- **Total**: $99/Jahr

---

### Phase 3: Launch - Monat 5-6

**Features:**
- App Store Release
- Firebase Backend (Analytics, Cloud Storage)
- Website (Custom Domain)

**Kosten**:
- Apple Developer: $99/Jahr
- Domain: €10/Jahr
- Firebase: **Kostenlos** (Free Tier)
- **Total**: ~$110/Jahr ✅

---

### Phase 4: Scale - Jahr 2+

**Features:**
- Cloud Processing (Dolby Atmos, AI)
- Multi-Platform (iPad, macOS)
- Dedicated Server (optional)

**Kosten** (10,000 aktive Nutzer):
- Apple Developer: $99/Jahr
- Domain: €10/Jahr
- Firebase: ~$25/Monat = $300/Jahr
- Hetzner Server (optional): €4/Monat = €48/Jahr
- **Total**: ~$460/Jahr ✅

**Einnahmen** (10,000 Nutzer, 5% Conversion zu Pro):
- 500 Pro-Käufe × $9.99 = **$4,995** (einmalig)
- 30% Apple Cut = **$3,497 netto**
- **ROI**: 760% 🚀

---

## ✅ DEPLOYMENT CHECKLIST

**Vor GitHub-Umbenennung:**
- [ ] Backup (git clone)
- [ ] Informiere Collaborators

**Vor App Store:**
- [ ] Apple Developer Account ($99)
- [ ] Privacy Policy
- [ ] Screenshots (alle Device-Größen)
- [ ] App Icon (1024x1024)
- [ ] TestFlight Beta (mindestens 2 Wochen)
- [ ] Crash-Free Rate >99%

**Vor Server:**
- [ ] Domain kaufen
- [ ] SSL Certificate
- [ ] Backup-Strategie
- [ ] Monitoring (Uptime)

---

## 🎯 EMPFEHLUNG FÜR ECHOELMUSIC

**Start (Jahr 1):**

1. ✅ **GitHub Free** (kostenlos)
   - Repo umbenennen: `blab-ios-app` → `echoelmusic`
   - GitHub Pages: Landing Page

2. ✅ **Keine Server** (vorerst)
   - On-Device Processing (alles lokal)
   - iCloud Sync (kostenlos für Nutzer)

3. ✅ **Apple Developer** ($99/Jahr)
   - TestFlight Beta
   - App Store Launch

4. ✅ **Firebase Free Tier** (optional)
   - Analytics (Opt-In)
   - Cloud Storage (5GB kostenlos)

**Total Kosten Jahr 1**: **$99** (nur Apple Developer) ✅

**Später hinzufügen (bei Bedarf):**
- Custom Domain: €10/Jahr
- Dedicated Server: €4/Monat (Hetzner)
- Firebase Upgrade: $25/Monat (ab 10k Nutzer)

---

**Fazit:**
- ✅ **GitHub Free ist ausreichend**
- ✅ **Kein Premium Account nötig**
- ✅ **Repo umbenennen ist kostenlos und einfach**
- ✅ **Server nicht nötig am Anfang**
- ✅ **Gesamtkosten Jahr 1: $99** (nur App Store)

---

**Last Updated**: 2025-11-09
**Platform**: Echoelmusic
**Deployment Status**: Ready for GitHub Rename & App Store Submission ✅

# 📜 Echoelmusic Legal Pages

**DSGVO-konforme Rechtsdokumente für GitHub Pages** (kostenlos!)

---

## 🎯 Zweck

Diese Seiten stellen alle rechtlich erforderlichen Dokumente für Echoelmusic bereit:
- ✅ Datenschutzerklärung (DSGVO-konform)
- ✅ Allgemeine Geschäftsbedingungen (AGB)
- ✅ Impressum (§5 TMG)

---

## 🚀 Deployment zu GitHub Pages

### Option 1: Eigenes Repository (EMPFOHLEN)

```bash
# 1. Neues Repository erstellen
gh repo create echoelmusic-legal --public

# 2. Legal Pages hochladen
cd legal-pages
git init
git add .
git commit -m "Initial legal pages"
git branch -M main
git remote add origin https://github.com/vibrationalforce/echoelmusic-legal.git
git push -u origin main

# 3. GitHub Pages aktivieren
# GitHub → Repository → Settings → Pages
# Source: main branch, / (root)
# Save

# 4. Warten Sie 1-2 Minuten, dann ist die Seite verfügbar:
# https://vibrationalforce.github.io/echoelmusic-legal/
```

### Option 2: Als Ordner in diesem Repository

```bash
# 1. GitHub Pages für dieses Repo aktivieren
# GitHub → Echoelmusic Repository → Settings → Pages
# Source: main branch, /legal-pages
# Save

# 2. Verfügbar unter:
# https://vibrationalforce.github.io/Echoelmusic/legal-pages/
```

---

## 🔗 URLs für App Store

Nach dem Deployment verwenden Sie diese URLs:

```
Privacy Policy: https://vibrationalforce.github.io/echoelmusic-legal/datenschutz.html
Terms of Service: https://vibrationalforce.github.io/echoelmusic-legal/agb.html
Support: mailto:hello@echoelmusic.com
```

### iOS App Store Connect:
- **Support URL**: https://vibrationalforce.github.io/echoelmusic-legal/
- **Marketing URL**: (optional - leer lassen)
- **Privacy Policy URL**: https://vibrationalforce.github.io/echoelmusic-legal/datenschutz.html

### Google Play Console:
- **Website**: https://vibrationalforce.github.io/echoelmusic-legal/
- **Email**: hello@echoelmusic.com
- **Privacy Policy**: https://vibrationalforce.github.io/echoelmusic-legal/datenschutz.html

### Microsoft Store:
- **Support contact**: hello@echoelmusic.com
- **Privacy policy**: https://vibrationalforce.github.io/echoelmusic-legal/datenschutz.html

---

## 📂 Dateien

```
legal-pages/
├── index.html          # Startseite mit Navigation
├── datenschutz.html    # Datenschutzerklärung (DSGVO)
├── agb.html            # Allgemeine Geschäftsbedingungen
├── impressum.html      # Impressum (§5 TMG)
├── styles.css          # Gemeinsames Stylesheet
└── README.md           # Diese Datei
```

---

## ✏️ Anpassungen

### Kontaktdaten ändern

In allen HTML-Dateien suchen und ersetzen:
- `hello@echoelmusic.com` → Ihre E-Mail
- `Bahrenfelder Chaussee 35, 22761 Hamburg` → Ihre Adresse
- `Michael Terbuyken (Echoel)` → Ihr Name

### Design anpassen

Bearbeiten Sie `styles.css`:
```css
/* Farbschema ändern */
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
/* → Ihre Farben */
```

---

## ⚖️ Rechtliche Hinweise

Diese Dokumente sind auf den Stand November 2024 und für folgende Situation erstellt:
- ✅ Einzelunternehmer/Freiberufler
- ✅ Kleinunternehmer nach §19 UStG
- ✅ Sitz in Deutschland
- ✅ DSGVO-konform (EU)
- ✅ Nutzung von Supabase, Stripe, Apple IAP, Google Play Billing

**WICHTIG**: Bei Änderungen (z.B. Umzug, neue Rechtsform, andere Services) müssen die Dokumente angepasst werden!

**Empfehlung**: Lassen Sie die Dokumente von einem Anwalt prüfen, bevor Sie viele zahlende Kunden haben.

---

## 💰 Kosten

**€0** - GitHub Pages ist komplett kostenlos!

---

## 🆘 Support

Fragen zu den Legal Pages?
- 📧 Email: hello@echoelmusic.com
- 📖 Dokumentation: Siehe Hauptprojekt

---

**© 2024 Echoel (Michael Terbuyken)**

# 🎵 Repository Umbenennung: blab-ios-app → echoelmusic

**Status**: Bereit für Umbenennung ✅
**Datum**: 2025-11-09
**Dauer**: ~5 Minuten

---

## ✅ VORBEREITUNG ABGESCHLOSSEN

**Alle Dateien im Repository wurden aktualisiert:**

### Aktualisierte Dateien:
- ✅ `Info.plist` - App-Name: "Echoelmusic"
- ✅ `Resources/Info.plist` - Alle Beschreibungen: "Echoelmusic"
- ✅ Alle Permission-Beschreibungen aktualisiert

### Dokumentation (historische Referenzen behalten):
- Markdown-Dateien behalten "BLAB" in historischen Kontexten
- Neue Dokumentation verwendet "Echoelmusic"

---

## 📋 SCHRITT-FÜR-SCHRITT ANLEITUNG

### SCHRITT 1: Repository auf GitHub umbenennen (2 Minuten)

**Via GitHub Web Interface (Einfachste Methode):**

1. **Öffnen Sie Ihren Browser:**
   ```
   https://github.com/vibrationalforce/blab-ios-app
   ```

2. **Klicken Sie auf "Settings"** (oben rechts, Zahnrad-Symbol)

3. **Scrollen Sie nach unten zum Bereich "Danger Zone"**

4. **Unter "Repository name" finden Sie:**
   ```
   Rename this repository
   [blab-ios-app]
   ```

5. **Ändern Sie den Namen:**
   ```
   Alter Name: blab-ios-app
   Neuer Name: echoelmusic
   ```

6. **Klicken Sie "Rename"**

7. **Bestätigen Sie** (wenn gefragt)

8. ✅ **Fertig!** GitHub leitet automatisch um:
   ```
   https://github.com/vibrationalforce/blab-ios-app
   → https://github.com/vibrationalforce/echoelmusic
   ```

**Was passiert automatisch:**
- ✅ 301 Permanent Redirect (alte URLs funktionieren weiter)
- ✅ Git-Klone mit alter URL funktionieren weiter (30+ Tage)
- ✅ Pull Requests, Issues, Wiki bleiben erhalten
- ✅ GitHub Pages URL ändert sich: `vibrationalforce.github.io/echoelmusic`

---

### SCHRITT 2: Lokale Git-Config aktualisieren (1 Minute)

**Option A: Automatisch (Git folgt Redirect):**

```bash
# Nichts tun! Git folgt automatisch dem 301 Redirect
git pull
# Git aktualisiert automatisch die Remote URL
```

**Option B: Manuell aktualisieren (empfohlen für saubere Config):**

```bash
# Im Repository-Verzeichnis
cd /path/to/blab-ios-app

# Remote URL anzeigen (aktuell)
git remote -v
# origin  https://github.com/vibrationalforce/blab-ios-app.git (fetch)
# origin  https://github.com/vibrationalforce/blab-ios-app.git (push)

# Remote URL aktualisieren
git remote set-url origin https://github.com/vibrationalforce/echoelmusic.git

# Verifizieren
git remote -v
# origin  https://github.com/vibrationalforce/echoelmusic.git (fetch)
# origin  https://github.com/vibrationalforce/echoelmusic.git (push)

# Testen
git fetch
# ✅ Sollte funktionieren
```

---

### SCHRITT 3: Lokales Verzeichnis umbenennen (Optional, 30 Sekunden)

**Wenn Sie das lokale Verzeichnis auch umbenennen möchten:**

```bash
# Option A: Einfach umbenennen
cd /path/to/
mv blab-ios-app echoelmusic
cd echoelmusic

# Option B: Frisch klonen (empfohlen für sauberen Start)
cd /path/to/
git clone https://github.com/vibrationalforce/echoelmusic.git
cd echoelmusic

# Altes Verzeichnis entfernen (nach Backup!)
# rm -rf /path/to/blab-ios-app
```

---

### SCHRITT 4: Neuen Claude Code Chat öffnen (1 Minute)

**Nach der Umbenennung:**

1. **Schließen Sie den aktuellen Claude Code Chat**

2. **Öffnen Sie einen neuen Chat:**
   - Öffnen Sie Claude Code
   - Wählen Sie "New Chat" oder "New Session"

3. **Repository öffnen:**
   ```
   Pfad: /path/to/echoelmusic
   ```
   Oder (wenn neu geklont):
   ```
   Pfad: /path/to/echoelmusic
   ```

4. ✅ **Claude erkennt automatisch das umbenannte Repo!**

---

## 🔍 VERIFIZIERUNG

**Nach der Umbenennung, überprüfen Sie:**

### 1. GitHub Web Interface

```
✅ URL: https://github.com/vibrationalforce/echoelmusic
✅ Repository-Name: "echoelmusic"
✅ Alte URL leitet um (funktioniert noch)
```

### 2. Lokales Git

```bash
# Remote URL
git remote -v
# ✅ Sollte zeigen: ...echoelmusic.git

# Fetch/Pull funktioniert
git fetch
git pull
# ✅ Sollte ohne Fehler laufen

# Push funktioniert
git push
# ✅ Sollte ohne Fehler laufen
```

### 3. Xcode (falls geöffnet)

```
1. Schließen Sie Xcode
2. Öffnen Sie Xcode neu
3. Öffnen Sie das Projekt aus dem neuen Pfad
4. ✅ Build sollte funktionieren
```

### 4. Claude Code

```
1. Neuer Chat
2. Repository öffnen: /path/to/echoelmusic
3. ✅ Claude sollte alle Dateien sehen
4. ✅ Git-Integration funktioniert
```

---

## ⚠️ WICHTIGE HINWEISE

### Was automatisch funktioniert:
- ✅ **Git-Klone**: Alte URLs funktionieren 30+ Tage (301 Redirect)
- ✅ **Pull Requests**: Bleiben erhalten (URLs aktualisieren sich)
- ✅ **Issues**: Bleiben erhalten
- ✅ **GitHub Actions**: Funktionieren weiter
- ✅ **GitHub Pages**: Neue URL (alte leitet um)
- ✅ **Stars, Forks, Watchers**: Bleiben erhalten

### Was Sie ggf. aktualisieren müssen:
- ⚠️ **Local Git Config**: `git remote set-url origin ...` (siehe Schritt 2)
- ⚠️ **Bookmarks**: Browser-Lesezeichen aktualisieren
- ⚠️ **CI/CD Services**: Falls externe Services (Travis, CircleCI) - URLs aktualisieren
- ⚠️ **README Links**: Interne Links in Markdown-Dateien (optional)

### Was NICHT passiert:
- ❌ **Daten gehen NICHT verloren**
- ❌ **Git-Historie bleibt ERHALTEN**
- ❌ **Commits bleiben ERHALTEN**
- ❌ **Branches bleiben ERHALTEN**

---

## 🚨 TROUBLESHOOTING

### Problem: "Repository not found" beim git push

**Lösung:**
```bash
# Remote URL aktualisieren
git remote set-url origin https://github.com/vibrationalforce/echoelmusic.git

# Erneut versuchen
git push
```

---

### Problem: Claude Code findet Repo nicht

**Lösung:**
```bash
# Neues Verzeichnis erstellen und frisch klonen
cd /path/to/
git clone https://github.com/vibrationalforce/echoelmusic.git
cd echoelmusic

# Claude Code neu starten und dieses Verzeichnis öffnen
```

---

### Problem: Xcode zeigt "Source Control" Fehler

**Lösung:**
```bash
# Xcode schließen
# Terminal öffnen, im Repo-Verzeichnis:

git remote set-url origin https://github.com/vibrationalforce/echoelmusic.git
git fetch

# Xcode neu öffnen
# Xcode → Preferences → Accounts → Refresh
```

---

### Problem: GitHub Pages zeigt 404

**Lösung:**
```
1. GitHub → Settings → Pages
2. Source: gh-pages oder docs/ (erneut auswählen)
3. Save
4. Warte 1-2 Minuten
5. Neue URL: https://vibrationalforce.github.io/echoelmusic
```

---

## 📝 CHECKLISTE

**Vor der Umbenennung:**
- [x] Alle Änderungen committed und gepusht
- [x] Info.plist Dateien aktualisiert ("Echoelmusic")
- [x] Backup erstellt (optional: `git clone` an anderen Ort)

**Während der Umbenennung:**
- [ ] GitHub: Settings → Rename → "echoelmusic"
- [ ] Bestätigung erhalten (Redirect funktioniert)

**Nach der Umbenennung:**
- [ ] Lokal: `git remote set-url origin https://github.com/vibrationalforce/echoelmusic.git`
- [ ] Verifizierung: `git fetch` funktioniert
- [ ] Verifizierung: `git push` funktioniert
- [ ] Lokales Verzeichnis umbenennen (optional)
- [ ] Neuen Claude Code Chat öffnen
- [ ] Repository öffnen: `/path/to/echoelmusic`
- [ ] Xcode neu starten (falls geöffnet)

**Verifizierung abgeschlossen:**
- [ ] GitHub URL funktioniert: https://github.com/vibrationalforce/echoelmusic
- [ ] Alte URL leitet um (funktioniert noch)
- [ ] Git fetch/pull/push funktioniert
- [ ] Claude Code erkennt Repo
- [ ] Xcode Build funktioniert

---

## 🎯 NÄCHSTE SCHRITTE

**Nach erfolgreicher Umbenennung:**

1. **README.md aktualisieren** (optional):
   ```markdown
   # Echoelmusic

   *Formerly known as BLAB*

   Bio-Reactive Creative Platform for iOS/iPadOS
   ```

2. **GitHub Pages aktualisieren** (falls vorhanden):
   - Aktualisiere `docs/index.html` mit neuem Namen

3. **Weiterarbeiten im neuen Chat:**
   - Öffne neuen Claude Code Chat
   - Lade Repository: `/path/to/echoelmusic`
   - Weiterarbeiten wie gewohnt! 🚀

---

## ✅ ZUSAMMENFASSUNG

**Was passiert:**
1. GitHub: `blab-ios-app` → `echoelmusic` (2 Minuten)
2. Lokal: Git Remote URL aktualisieren (1 Minute)
3. Optional: Verzeichnis umbenennen (30 Sekunden)
4. Neuer Claude Code Chat (1 Minute)

**Gesamtzeit: ~5 Minuten**

**Risiko: MINIMAL** ✅
- Keine Daten gehen verloren
- Alte URLs funktionieren weiter (Redirect)
- Einfach rückgängig zu machen (einfach erneut umbenennen)

---

## 📞 SUPPORT

**Falls Probleme auftreten:**

1. **GitHub Docs**: https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository
2. **Git Docs**: https://git-scm.com/docs/git-remote
3. **Oder**: Einfach erneut umbenennen (zurück zu "blab-ios-app" falls nötig)

---

**Status**: ✅ BEREIT FÜR UMBENENNUNG
**Letzte Aktualisierung**: 2025-11-09
**Prepared by**: Claude Code Assistant

🎵 **Viel Erfolg mit Echoelmusic!** 🎵

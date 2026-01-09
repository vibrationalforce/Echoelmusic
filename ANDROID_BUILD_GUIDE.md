# Echoelmusic Android APK Build Guide

## Schnellstart - APK Erstellen

### Voraussetzungen

1. **Android Studio** (Arctic Fox oder neuer)
   - Download: https://developer.android.com/studio

2. **Java 17** (JDK)
   ```bash
   # macOS
   brew install openjdk@17

   # Ubuntu/Debian
   sudo apt install openjdk-17-jdk

   # Windows
   # Installiere von https://adoptium.net/
   ```

3. **Android SDK** (via Android Studio installiert)
   - API Level 34 (Android 14)
   - NDK 25.x oder neuer

---

## Build-Schritte

### Option 1: Android Studio (Empfohlen)

1. **Projekt öffnen**
   ```
   File → Open → [Echoelmusic/android Ordner]
   ```

2. **Gradle Sync**
   - Warte bis "Gradle sync finished" erscheint
   - Falls Fehler: File → Invalidate Caches → Restart

3. **APK Erstellen**
   ```
   Build → Build Bundle(s) / APK(s) → Build APK(s)
   ```

4. **APK Finden**
   ```
   android/app/build/outputs/apk/debug/app-debug.apk
   ```

### Option 2: Kommandozeile

```bash
cd android

# Debug APK
./gradlew assembleDebug

# Release APK (signiert)
./gradlew assembleRelease

# APK Pfad:
# Debug:   app/build/outputs/apk/debug/app-debug.apk
# Release: app/build/outputs/apk/release/app-release.apk
```

---

## APK auf Handy Installieren

### Methode 1: USB-Kabel

```bash
# Mit ADB (Android Debug Bridge)
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Methode 2: APK direkt übertragen

1. **USB-Debugging aktivieren** auf dem Handy:
   - Einstellungen → Über das Telefon → 7x auf "Build-Nummer" tippen
   - Einstellungen → Entwickleroptionen → USB-Debugging AN

2. **APK kopieren**
   - Verbinde Handy per USB
   - Kopiere die APK-Datei auf das Handy

3. **Installation erlauben**
   - Einstellungen → Sicherheit → "Unbekannte Quellen" aktivieren

4. **APK auf dem Handy öffnen und installieren**

### Methode 3: QR-Code / Cloud

1. Lade die APK auf Google Drive / Dropbox hoch
2. Öffne den Link auf deinem Handy
3. Installiere

---

## Häufige Probleme

### Problem: "SDK location not found"
```bash
# Erstelle local.properties im android/ Ordner:
echo "sdk.dir=/path/to/Android/Sdk" > local.properties
```

### Problem: "NDK not found"
1. Öffne Android Studio → Tools → SDK Manager
2. SDK Tools Tab → NDK (Side by side) installieren

### Problem: Gradle Sync Fehler
```bash
# Cache löschen
./gradlew clean
./gradlew --refresh-dependencies
```

### Problem: "INSTALL_FAILED_UPDATE_INCOMPATIBLE"
```bash
# Alte Version deinstallieren
adb uninstall com.echoelmusic.app
```

---

## Release APK Signieren

Für Google Play Store:

1. **Keystore erstellen**
   ```bash
   keytool -genkey -v -keystore echoelmusic.keystore -alias echoelmusic -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **In build.gradle.kts hinzufügen**
   ```kotlin
   signingConfigs {
       create("release") {
           storeFile = file("echoelmusic.keystore")
           storePassword = "YOUR_PASSWORD"
           keyAlias = "echoelmusic"
           keyPassword = "YOUR_PASSWORD"
       }
   }
   ```

3. **Release Build**
   ```bash
   ./gradlew assembleRelease
   ```

---

## GitHub Actions (Automatischer Build)

Die CI/CD Pipeline baut automatisch APKs bei jedem Push:

```yaml
# .github/workflows/build.yml
build-android:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-java@v4
      with:
        java-version: '17'
    - run: cd android && ./gradlew assembleRelease
```

APKs findest du unter: **Actions → Build → Artifacts**

---

## Kontakt

Bei Problemen: michaelterbuyken@gmail.com

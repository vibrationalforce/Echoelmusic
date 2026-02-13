# Prompt Template: Vereinfache TestFlight CI auf reine API Key Authentication

## Ziel
Vereinfache den TestFlight-Workflow (`testflight.yml`) und die Fastlane-Konfiguration (`fastlane/Fastfile`) auf **reine App Store Connect API Key Authentication** -- den modernen, von Apple empfohlenen Weg für CI.

**Kernprinzip:** xcodebuild mit `-allowProvisioningUpdates` + API Key Flags verwaltet Zertifikate und Provisioning Profiles vollautomatisch. Kein manuelles Cert-Management nötig.

---

## Aktueller Stand (was entfernt werden soll)

### Probleme mit dem jetzigen Ansatz:
1. **Fastlane `cert` + `sigh`** erzeugt/verwaltet Certs manuell -- komplex, fehleranfällig
2. **Keychain-Management** (create, unlock, import, cleanup) -- unnötig mit API Key Auth
3. **Spaceship Cert-Cleanup** (revoke dev certs, manage dist cert limit) -- unnötig
4. **`DISTRIBUTION_CERTIFICATE_P12`** Secret -- wird nicht mehr gebraucht
5. **`DISTRIBUTION_CERTIFICATE_PASSWORD`** Secret -- wird nicht mehr gebraucht
6. **`build_xcargs_manual()`** mit `CODE_SIGN_STYLE=Manual` -- wird Automatic

### Was bleiben soll:
- Die 4 Kern-Secrets: `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`, `APPLE_TEAM_ID`
- Preflight-Validation dieser 4 Secrets
- Compile Check (Simulator, kein Signing)
- Caching (SPM, DerivedData)
- Pro-Plattform Jobs (ios, macos, watchos, tvos, visionos)
- Upload-to-TestFlight mit Retry
- Summary Job
- Build-Only Mode
- 60min Timeout

---

## Gewünschte neue Architektur

### testflight.yml - Pro Plattform-Job:
```
1. Checkout
2. Setup Xcode
3. Cache Swift PM + DerivedData
4. Install XcodeGen
5. Generate Project (mit echtem TEAM_ID)
6. Setup API Key (.p8 Datei schreiben)
7. Archive mit xcodebuild:
   xcodebuild archive \
     -project Echoelmusic.xcodeproj \
     -scheme Echoelmusic \
     -destination "generic/platform=iOS" \
     -archivePath ./build/Echoelmusic.xcarchive \
     -configuration Release \
     -allowProvisioningUpdates \
     -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
     -authenticationKeyID "$ASC_KEY_ID" \
     -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8 \
     DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
     CODE_SIGN_STYLE=Automatic \
     COMPILER_INDEX_STORE_ENABLE=NO
8. Export IPA:
   xcodebuild -exportArchive \
     -archivePath ./build/Echoelmusic.xcarchive \
     -exportPath ./build \
     -exportOptionsPlist ExportOptions.plist \
     -allowProvisioningUpdates \
     -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
     -authenticationKeyID "$ASC_KEY_ID" \
     -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8
9. Upload via Fastlane (upload_to_testflight nur)
10. Cleanup (.p8 löschen)
```

### ExportOptions.plist (neue Datei):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
```

### Fastfile - Vereinfacht:
- `setup_api_key` bleibt (für `upload_to_testflight`)
- `upload_to_testflight_with_retry` bleibt
- **ENTFERNEN:** `setup_manual_signing`, `build_xcargs_manual`, `get_or_create_certificates`, `cleanup_certificates`, `setup_keychain`, `parse_cert_date`, `write_api_key_to_disk`
- `build_app()` wird nicht mehr gebraucht -- xcodebuild wird direkt im Workflow aufgerufen
- Lanes werden zu reinen Upload-Lanes (nur `upload_to_testflight`)

### Oder Alternative: Fastlane `build_app` mit API Key Auth beibehalten:
```ruby
lane :beta do
  api_key = setup_api_key

  build_app(
    project: "Echoelmusic.xcodeproj",
    scheme: "Echoelmusic",
    configuration: "Release",
    export_method: "app-store",
    destination: "generic/platform=iOS",
    derived_data_path: "./build/DerivedData",
    archive_path: "./build/Echoelmusic.xcarchive",
    output_directory: "./build",
    output_name: "Echoelmusic",
    export_options: {
      signingStyle: "automatic",
      teamID: TEAM_ID
    },
    xcargs: "DEVELOPMENT_TEAM=#{TEAM_ID} CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates -authenticationKeyIssuerID #{ENV['ASC_ISSUER_ID']} -authenticationKeyID #{ENV['ASC_KEY_ID']} -authenticationKeyPath #{File.expand_path('~/.appstoreconnect/private_keys/AuthKey_' + ENV['ASC_KEY_ID'] + '.p8')} COMPILER_INDEX_STORE_ENABLE=NO"
  )

  upload_to_testflight_with_retry(api_key, "iOS Build #{BUILD_NUMBER}")
end
```

---

## Dateien die geändert werden müssen

1. **`.github/workflows/testflight.yml`**
   - Entferne "Setup Keychain" Steps aus allen Jobs
   - Vereinfache "Deploy to TestFlight" Steps
   - Entferne DISTRIBUTION_CERTIFICATE_P12/PASSWORD Referenzen
   - Entferne "Upload Certificate Export" Steps
   - Keychain Cleanup vereinfachen (nur .p8 löschen)

2. **`fastlane/Fastfile`**
   - Entferne: `setup_manual_signing`, `build_xcargs_manual`, `get_or_create_certificates`, `cleanup_certificates`, `setup_keychain`, `parse_cert_date`, `write_api_key_to_disk`
   - Lanes vereinfachen: nur API Key + build_app (Automatic Signing) + upload

3. **Evtl. neue Datei: `ExportOptions.plist`** (wenn du xcodebuild direkt im Workflow nutzt statt Fastlane build_app)

4. **`project.yml`** - Prüfen ob `CODE_SIGN_STYLE: Automatic` gesetzt ist

---

## Zu beachtende Secrets

### Benötigt (bereits vorhanden):
- `APP_STORE_CONNECT_KEY_ID` - Key ID aus App Store Connect > Users > Keys
- `APP_STORE_CONNECT_ISSUER_ID` - Issuer ID (UUID)
- `APP_STORE_CONNECT_PRIVATE_KEY` - .p8 Datei Inhalt (PEM Format)
- `APPLE_TEAM_ID` - 10-stellige Team ID

### Nicht mehr benötigt (können entfernt werden):
- `DISTRIBUTION_CERTIFICATE_P12`
- `DISTRIBUTION_CERTIFICATE_PASSWORD`

---

## Wichtige Hinweise
- Compile Check (Simulator) bleibt UNVERÄNDERT (braucht kein Signing)
- 60min Timeout beibehalten (30min+ Compile-Zeit)
- `build_only` Mode bleibt (Simulator, kein Signing)
- Concurrency-Groups bleiben
- Bundle IDs: com.echoelmusic.app (+ .auv3, .clip, .watchkitapp, .widgets)
- CLAUDE.md und Memory-Dateien NICHT ändern
- Nach dem Umbau: Workflow auf GitHub pushen und mit `build_only=false`, `skip_compile_check=true` testen (Compile Check hat ja schon bestanden)

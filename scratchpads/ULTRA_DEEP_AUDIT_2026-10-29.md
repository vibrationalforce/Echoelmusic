# ULTRA DEEP AUDIT — Echoelmusic / Echoel Studio, Stand 2026-10-29 (Nacht vor der Entscheidungsrunde)

**Auftrag (Founder, 28.10. 23:xx):** „Mache Ultra Deep Audit, wir entscheiden alles morgen zusammen.“
**Gemessen an:** `claude/echoelmusic-review-optimize-u5jjpd` @ `3586d53a` (= `main` `587090bc` plus drei Doku-Commits).
Build **10015 (11.0.0)** ist seit 22:16 UTC in App Store Connect `VALID`.
**Methode:** vier lesende Linsen parallel (Produktcode · Außenbehauptungen/Website/Recht · Ship-Pfad/CI/Sicherheit ·
Backlog/Entscheidungen/Widersprüche), dazu eigene Messungen. Nichts gebaut, nichts geändert, kein Swift-Toolchain.
Jede Zahl trägt ihren Befehl oder ihre Datei:Zeile. **Zeilennummern sind Daten, keine Sachverhalte** — vor dem Zitieren
neu greppen (CLAUDE.md §E). „Nicht messbar“ heißt: Zustand im Apple-Konto, den das Repo nicht trägt.

---

## 0. Kernbefund in sechs Sätzen

1. **Der Code ist als DAW mit Gurt-Modulation und ruhigem Bild solide** — Render-Thread diszipliniert, Format 3 mit echter
   Migration und Golden-Dateien, 810 Testfunktionen in Core/DSP/Engine, alle zehn Hausgesetze aus `EchoelStudio/CLAUDE.md`
   messbar eingehalten, 0 Force-Unwraps, 0 `print`.
2. **Als „1.0 enthält alles“ (Plan 25.10.) ist er kein Kandidat:** W4 (Licht/OSC/ADM-OSC), W7 (Video), W8 (Stimme),
   W9 (Gesicht/Bewegung) sind **null Zeilen**; W1 hat von drei Körperquellen nur den Gurt; W5 hat weder DDSP noch MPE-Out.
   Rest grob **45–55 Scheiben** = Wochen, nicht Tage.
3. **Der Engpass ist nicht Code, sondern Founder-Hand:** IAP-Produkt in ASC (F-15, überfällig seit 27.10.), eine
   Geräte-Sitzung (~45 min), eine Zeile in `studio.yml` (F25), eine Kamera-Begründung in `EchoelStudio/project.yml`.
4. **Nach außen stimmt fast nichts mit Build 10015 überein:** der Store-Text in `fastlane/metadata` ist zu 100 % der
   Alt-App-Text (Kamera, Health, Atem, OSC, MPE, Licht, DDSP, Genres — alles 0 Treffer im Studio), die Website spricht
   im Präsens von Dingen, die nur die eingefrorene Alt-App hatte, die AGB sind acht Monate älter als das Produkt.
5. **Elf Widersprüche zwischen „aktiven“ Dokumenten** (Förderung, Tauchfliege, Umfang von 1.0, Preis, Körper als Kern
   oder Gimmick, Mac-Weg …) — zwei `decisions.csv`-Zeilen (1332, 1333) sind beide `active` und widersprechen sich.
6. **Die Geräte-Warteschlange misst die falsche App:** 411 offene Marker, alle in der eingefrorenen Alt-App; für Studio
   stehen 30 Punkte in sechs Familien in `FOUNDER_INBOX.md` §2 und `EchoelStudio/RELEASE` (~75–90 min).

---

## 1. Harte Zahlen (eigene Messung)

| Größe | Wert | Befehl |
|---|---|---|
| Studio App | 11 497 Zeilen, **0 Tests** | `git ls-files 'EchoelStudio/App/**/*.swift' \| xargs cat \| wc -l` |
| Studio Core | 7 044 Zeilen, 39 Testdateien, 388 `func test` | dito je Paket |
| Studio DSP | 4 218 Zeilen, 23 Testdateien, 195 Tests | |
| Studio Engine (+Kernels, Host) | 5 585 Zeilen, 33 Testdateien, 227 Tests | |
| Studio Plugins | 725 Zeilen, **0 Tests** | |
| Studio gesamt | 245 Swift-Dateien, **810 Tests** | `git grep -h -E "^\s*func test" -- EchoelStudio \| wc -l` |
| Alt-App (eingefroren) | 522 Dateien, 188 324 Zeilen; Tests/CISmoke 969, Tests/EchoelmusicTests 301 Dateien | `git ls-files 'Sources/**/*.swift'` |
| Geräte-Marker offen | **411** in 358 Dateien, alle Alt-App; Studio: 0 | `python3 scripts/founder-verify.py` |
| Entscheidungen überfällig | **506** (540 am 30.09., 453 am 22.10.) | `./review.sh \| grep -c '^REVIEW DUE'` |
| Scratchpads | 466 Dateien, 8,6 MB (+186 Archiv); `docs/dev` 44; `memory/` 8 Dateien 1,6 MB | `git ls-files 'scratchpads/*.md'` |
| Immer geladenes Gesetz | `CLAUDE.md` 149 149 B (Deckel 150 000) | `wc -c CLAUDE.md` |
| Remote-Zweige | **184** | `git ls-remote --heads origin \| wc -l` |
| Uploads 28.10. | 5 (10011–10015), keiner gerätegeprüft | `EchoelStudio/RELEASE` |
| Doctor | 3 Criticals, **alle Alt-App-CI** (benchmark.yml, ci.yml, Spacing-Ratchet in `Sources/`); der `studio.yml`-pipefail-Hinweis ist ein Fehlalarm (`set -eo pipefail` steht Z. 156) | `python3 scripts/doctor.py` |

---

## 2. Produktcode `EchoelStudio/` (Linse 1)

### 2a. Wellen-Status, gemessen

| Welle | Stand | Beleg |
|---|---|---|
| **W0** ✅ | Keys/Pads, Loop/Overdub, Starter-Song, Import alter Songs, Mikrofon-Aufnahme | `App/Views/PlayKeysView.swift`, `Core/EarlierSongImport.swift`, `App/Engine/InputRecorder.swift` |
| **W1 Körper** | **Nur BLE-Gurt** (`App/Body/HeartRateStrap.swift`, ein Besitzer, 30-Hz-Glide) → `BodyChannel` → `ModulationInputs` (Puls, HRV, Kohärenz). **Kamera-rPPG: kein Produzent** — `AVCaptureSession|HKHealthStore|CoreMotion` → 0 Treffer; `RPPGConditioning`/`PulsePeriodEstimator` sind portiert, aber aufruferlos. Atem: Enum-Fall ohne Produzent. HealthKit/Watch: nichts. `project.yml` hat **keine** Kamera-/Health-Begründung (nur Bluetooth, Mikro, Local Network) | `git grep -E "AVCapture|HKHealth|CoreMotion" -- 'EchoelStudio/**/*.swift'` |
| **W2 Modulation** | **Kern + Engine + Tür fertig.** 7 Quellen im Enum, `routeLimit 64`, **Format 3** mit Migration (v1/v2 → leer, v2 MIT Routen abgelehnt), Golden, Routen auf Volume/Pan/Sends/Master UND Synth-Patch-Werte; Offline-Export friert ein (kein `modulation:`). Tür `ModulateMenu` nur in Arrange. **Abweichung:** `DSP/LinearRamp.swift` hat null Produktions-Aufrufer — Glättung läuft im Strap auf Main, nicht pro Sample im Render. LFO/Makro/MIDI-CC nur als Enum-Fälle | `Core/Modulation.swift`, `Project.swift:9,96–105`, `EngineSnapshot.swift:282–366` |
| **W3 Bild** | `FieldFrame` + `FlashLimit` (≤ 3 Blitze/s, Test), `FieldView` als SwiftUI-Canvas 30 fps im eigenen Blatt; **fünfter Tab**, kein schwebendes Fenster/Vollbild (Plan F3 sagt anderes). F4 (Bildparameter als Routenziel) und Metal: abwesend | `Core/Field.swift`, `App/Field/FieldView.swift` |
| **W4 Verbindungen** | **Nichts.** Network-Treffer exakt: Network MIDI (Default aus) + StoreKit. Art-Net/sACN/OSC/ADM-OSC = zwei Kommentare. Gate „Network only where named“ existiert, F25-Zeile ungenutzt | `studio.yml:40–52` |
| **W5 Klang+** | Sechs Engines (classic, supersaw, fm, sub, morph, mallet) + `LadderFilter`. **DDSP 0, MPE-Out 0**, MIDI-Out nur Clock + Launchpad-Licht | `DSP/SynthEngine.swift:12` |
| **W6 Store** | Kaufcode fertig: StoreKit 2, `com.echoelmusic.app.pro`, App-Group-Record, Extension-Fallback, Demo-Gate 2 s/30 s. **Produkt in ASC fehlt** | `App/Store/StoreController.swift`, `Plugins/Shared/PluginUnlock.swift:16` |
| **W7 Video** | 0 | |
| **W8 Stimme** | 0 (kein Pitch-Tracker im Studio-DSP) | |
| **W9 Gesicht/Bewegung** | 0 | |
| **W10 Generative Intelligenz** | Teil 1: `AgentSession` mit 11 Tools über `ProjectStore.perform` (Law 1). **Fehlt:** Melodie/Harmonie in Tonart, Klang aus einem Satz, Arrangement-Vorschläge. Nur iOS 26 + Apple Intelligence | `App/Agent/AgentSession.swift:205–210` |

### 2b. Korrektheits-Risiken, gerankt

1. **Format 3 öffnet in 10004–10011 nicht — und Autosave schreibt jeden Song beim ersten Öffnen als Format 3 zurück.** Wer auf einen alten TestFlight zurückgeht, sieht keinen Song mehr (Daten intakt). **mittel.** Keine Quarantäne-Kopie der alten Fassung, kein Test für das Nutzer-Erlebnis (`Project.swift:82`, `DocumentController.swift:653`, `ProjectCodec.swift:27`).
2. **`SynthKernel.values` wird von Main und Render ungeschützt geschrieben** — UI-Änderung an einem gerouteten Parameter wird im nächsten Block vom Routenwert überschrieben; „stored“ und „kernel“ divergieren absichtlich. **niedrig**, kein Test (`SynthKernel.swift:55–60`, `EngineCore.swift:1443`).
3. **Render-Thread sonst sauber:** 0 `os_log/Logger/NSLock/DispatchQueue/Task` in Engine- und DSP-Sources; Snapshot-Tausch ohne Freigabe; `@Sendable nonisolated` Source-Block; `InputRecorder` Ring + Atomics. ✔
4. **Swift-6-Hazards:** `MainActor.assumeIsolated` an 9 Stellen in Notification-/Route-Callbacks; falsch, falls ein Callback je auf einer Nebenqueue käme. **mittel**, nur Gerät prüft es (`AudioEngine.swift:226–289`, `PluginHost.swift:143/148`, `MIDIInput.swift:579`, `DocumentController.swift:353/370`).
5. **Force-Unwrap / `print` / `try!` / `as!`: 0.** ✔
6. **NaN-Pfade der neuen DSP-Teile** (Morph, Mallet, Ladder, Modulation, Ramp) guarden und sind getestet. **niedrig.**
7. **Undo/Save:** all-or-nothing, Limit 500, atomares Schreiben, Autosave-Fenster, Song-Quarantäne. ✔
8. **Field-Flash** passiert `FlashLimit`; Gerät unbestätigt.

### 2c. Die fünf wichtigsten ungetesteten Verhaltensweisen
1. Gesamter W1-Lebenszyklus in der App (Scan-Timeout, Reconnect, Glide → Inputs) — 0 Tests, nur `BodyChannel` ist gepinnt.
2. Export-Determinismus bei gesetzten Live-Quellen — folgt nur aus einem Default-Argument.
3. Patch-Modulation im echten Render-Pfad — nur die Kompilierung ist getestet.
4. Format-3-Rückwärtsfall im `DocumentController` — nur die Ablehnung im Codec.
5. AudioEngine Session-/Route-Wechsel (`assumeIsolated`, Stall, `beforeRateChange`) — App-Ziel ohne Tests.

### 2d. Hausgesetze
Law 1 (eine Tür) · 3 (gespeicherte Namen) · 5 (Render) · 6 (kein heißer Zustand im Rumpf) · 7 (ein Sheet-Slot, 11 Fälle) ·
9 (kein `!`, kein `print`) · 10 (Netz nur wo genannt) · „eine Uhr“: **alle halten.** Ein veralteter Kommentar:
`AudioEngine.playheadTick` „never a view body“ wird in `FieldView.swift:34` gelesen (unschädlich, TimelineView-getrieben).

---

## 3. Ship-Pfad, Store, CI, Sicherheit (Linse 3)

### 3a. Wie ein Build heute zu Testern kommt
Jede Änderung an `EchoelStudio/RELEASE` auf einem Nicht-`main`-Zweig → Gate wartet auf den grünen `Echoel Studio`-Lauf
desselben SHA → Archiv mit Build `10000 + run_number` → Upload → Poll bis `VALID/INVALID`. Funktioniert; 12 Uploads.
**Falle:** `studio.yml` hat `cancel-in-progress: true` — ein zweiter Push auf den Zweig während des Gates cancelt den
Studio-Lauf, das Gate liest `cancelled`, der Upload ist verloren (zweimal am 28.10. passiert).
**Ein versehentlicher Alt-App-Upload ist strukturell ausgeschlossen:** `testflight.yml` lädt nur mit
`legacy_upload == 'LEGACY'`, und keine Tür sendet das Wort. Beide Apps teilen Bundle-IDs und ASC-Record 6757957358;
Versions-Train 11.0.0 > 10.79 und Build-Offset 10000 > 2xxx halten die Reihenfolge.

### 3b. Store-Bereitschaft (W6) — Geschäftsmodell laut Repo: App frei + EIN Non-Consumable `com.echoelmusic.app.pro`

| Posten | Stand | Wer |
|---|---|---|
| Paid Applications Schedule | unklar (F1 betraf nur den Upload); `APP_STORE_CONNECT.md:47–48` nennt es als Bedingung | Founder, nicht messbar |
| IAP-Produkt in ASC | **nicht angelegt** (In-App-Käufe-Seite leer, 18.10.; F-15 überfällig seit 27.10.) | **Founder — Blocker Nr. 1** |
| Preis | **widersprüchlich:** 14,99–19,99 € (`memory/decisions.md:355`) vs 24,99–29,99 € (`NEUPLANUNG_2026-10-18.md:283`) | Founder |
| Kaufcode | fertig, Sandbox-Kauf ungetestet (SP4) | Gerät nach F-15 |
| App Group F17 | **erledigt 21.10.**; `EchoelStudio/RELEASE:26` sagt noch das Gegenteil (veralteter Satz) | Sitzung korrigiert beim nächsten Bump |
| Usage Descriptions | Bluetooth, Mikrofon, Local Network vorhanden; keine Kamera/Health/Location — korrekt für 10015 | ✔ |
| Privacy Manifest / Export Compliance | beide Bundles ✔ / `ITSAppUsesNonExemptEncryption: NO` ✔ | ✔ |
| Privacy-Labels in ASC | „Data Not Collected“ durch Code gedeckt; Eintrag fehlt | Founder |
| **Store-Text** | `fastlane/metadata/**` = **Alt-App**; Studio-Entwurf existiert (`docs/dev/APP_STORE_LISTING_STUDIO_11.md`), nicht übernommen. ⚠️ `Deliverfile:105 skip_metadata false` würde bei `fastlane deliver` den Alt-Text live stellen (`Fastfile:272` hat `skip_metadata: true` — zwei Dateien, zwei Wahrheiten) | Sitzung (Datei) + Founder (ASC) |
| Screenshots | `fastlane/screenshots/` = `.gitkeep`; Snapfile zielt auf nicht existierendes Scheme; iPhone 6,9" + iPad 13" nötig | Founder-Gerät |
| Altersfreigabe, externe TestFlight-Gruppe (F-08c), Review-Notes „kein Medizinprodukt“ | nicht dokumentiert / fehlt | Founder (Sitzung entwirft Review-Notes) |
| Terms/Privacy fürs Studio | GM37(2): §8 nach Panel-Lesung abmahnfähig ab erstem Verkauf | Founder, Rechtsrat |

### 3c. CI-Ehrlichkeit
`Echoel Studio` beweist: Core/DSP/Engine-Tests auf macOS, iOS-Builds, Simulator-Debug-Build, Mach-O-Scan, Launch-Smoke 20 s,
Release-Gerätebuild unsigniert, zwei Python-Strukturchecks. **Compile-only:** App (40 Dateien) und Plugins (6) — Store,
AUv3-Render, Views, Gurt, AudioEngine nur durch Build und Gerät; kein `auval` in CI. Linux misst, blockt nicht.
Auto-Merge wartet pro Scope auf das Gate; Docs-Commits fahren als Passagiere (`CLAUDE.md`, `memory/**`, `scratchpads/**`,
`fastlane/**`, `ContentPipeline/**` starten keinen Merge).

### 3d. Sicherheit
Keine committed Secrets (`.p8/.p12/mobileprovision/settings.local.json` → 0). Workflows: Keychain gelöscht, Logs gescrubbt,
API-Key `chmod 600`. **Offen (founder-gated):** Actions per Tag statt SHA, XcodeGen-Download ohne Prüfsumme (T5/T6), genau
im Job, der den ASC-Schlüssel hält; `gstack`-Skill mit Telemetrie-Pfaden noch im Repo (E30/T10). Bluetooth-Datenpfad:
nur UI und Routen lesen, kein Log, keine Datei, kein Netz — **on device only ✔**, deckungsgleich mit `privacy.html:110`.
AUv3-Extension-Entitlements: `group.com.echoelmusic.shared`, bewusst.

### 3e. Founder-gated F1–F25 gegen den Baum
Erledigt: F1, F17, F18, F22, F23. Überholt: F7, F9, F10, F19. **Studio-relevant offen: F13 (Store-Text), F16 (Canary),
F24 (sieben Root-Dateien), F25 (Netz-Zeile für W4).** Rest Alt-App-only.

---

## 4. Außenbehauptungen, Website, Recht (Linse 2)

### 4a. Overclaims (Auswahl, je Zeile ein 2.3-Risiko)
- **Store-Text** `fastlane/metadata/en-US/description.txt:1–3,8,10,12–13,22,24,27–28,34–40,47`, `keywords.txt`, `subtitle.txt`
  „Bio-Reactive Instrument“, `release_notes.txt:6–9` (41 Genres): Atem, Kamera-Puls, Apple Health lesen UND schreiben,
  Standort/Wetter, Tempo folgt Puls, DDSP, Genres, Touch-Noten, Retro-Capture, MIDI-Noten-Out, MPE, OSC, ADM-OSC, Art-Net,
  sACN, externer Bildschirm — **alles 0 Treffer in `EchoelStudio/`**.
- **Website:** `index.html` Titel „A Bio-Reactive Performance Instrument for iPhone“ (:24), Schema-Markup „Ships today: …
  Art-Net and sACN … OSC, ADM-OSC“ (:102–104), Hero (:657), „The instrument ships today — sound, visuals, light and space“
  (:834), Specs-Kacheln (:915–924); `overview.html` „live today“ für EchoelBio/Net/Vis/Lux/Stage (:158–164);
  `faq.html` Präsens für Kamera/HealthKit/OSC/Art-Net/MPE, „At launch it will be free, with full access to all features“
  (:235) vs Einmalkauf; `press.html` komplett Alt-App; `manifest.json:4` Beschreibung + `:14` Kategorie `"health"`;
  `version.json:33–72` Phantom-Changelog (RTMP, EchoelBeat, Typ `EchoelCreativeWorkspace` existiert nicht).
  Ohne jeden Studio-Hinweis: `health.html`, `terms.html`, `security.html`, `artist.html`, `impressum.html`, `one-clock.html`.
- **README.md:5,19,20,33,77** — „TestFlight pending an App Group fix“ (12 Uploads später), Alt-App „on TestFlight today“.
- **Der Build widerspricht sich selbst:** `EchoelStudio/App/Views/AboutView.swift:17` „Body signals, visuals, light and spatial
  output are not in this build“ — Gurt (10012) und Field sind drin; `docs/claims.html:86` ebenso.

### 4b. Underclaims (Studio kann es, niemand sagt es)
Bluetooth-Gurt mit HRV/Kohärenz · sechs Synth-Engines · 13+ Tonsysteme + Kammerton 400–480 Hz · Field mit 3-Hz-Grenze ·
Modulations-Matrix Körper→Parameter/Sends · Hosting fremder AUv3 · Mikrofon-/Interface-Aufnahme · Network MIDI, MIDI-Clock,
MIDI-Learn, Launchpad · Session-View, Loop/Overdub, Automation · 24-bit/48k-WAV mit LUFS/True-Peak · offenes `.echoel`-Format +
AirDrop · Import der Alt-App-Songs · Drums + Sampler · iPad. `roadmap.html:115` datiert Visual und Modulation auf 2028.

### 4c. Marken-Leitplanken
GitHub-Repo-Beschreibung: „🎵 Multidimensional Biofeedback Creation and **Wellbeing**. Share your Progress - a fair and
sensitive Plattform for all“ — verstößt gegen BRAND/CLAIMS §2, suggeriert Social/Tracking, Tippfehler. `manifest.json:14`
Kategorie `health`. `health.html:92`/`terms.html:133` nennen „relaxation features“ als Produktteil. „heilsam“: **0 Treffer**
in docs/ContentPipeline/fastlane. ContentPipeline sauber.

### 4d. Rechtsseiten — Fakten, kein Rechtsrat
- `privacy.html` (19.10.): Studio-Block :102–111 deckungsgleich mit `project.yml` (Gurt, Mikro, Netz, Kauf) ✔; Lücke :232
  Widerruf nennt Bluetooth nicht; Alt-App-Teil :113–255.
- `terms.html` „Updated: February 2026“, 0× „Echoel Studio“: :97 beschreibt Alt-App (Licht), :98 „Version 1.0 … free“ vs
  gebauter Einmalkauf, :113 Live Colabo (Studio 0), :121 Reverse-Engineering-Verbot bei MIT-Quelle, :177 Drittanbieter ohne
  Audio Units/StoreKit, :184 „Four things … All three“, **§8 :150–160** Ausschluss Personenschäden, Deckel gezahlter Betrag/50 €,
  „regardless of … negligence“, kein Carve-out — GM37(2).
- Review-Winkel: 5.1.3 = Metadaten-Mismatch (Health im Text, nicht im Code); 1.4.1 Disclaimer vorhanden; Risikowörter
  „coherence“ ohne Definition, „relaxation features“, `manifest` `health`, GitHub „Wellbeing“.

### 4e. Website-Umbau nach `REVIVAL_PLAN_2026-10-28.md`
Menü heute Overview · Tools · FAQ · Support, inline in 22 Seiten (kein Template). Fehlt: Studio-Seite, Vision-Seite,
Tools-Katalog mit Status, `ECHOELTOOLS_CATALOG.md` (Plan Schritt 4). Größe ≈ 6–8 Dateien substanziell + 22 Nav-Touches,
~800–1000 Zeilen; Store-Text-Neufassung 2 Sprachen × 5 Dateien ≈ 120 Zeilen.

---

## 5. Widersprüche zwischen „aktiven“ Dokumenten (Linse 4)

| # | Widerspruch | A | B | Frage |
|---|---|---|---|---|
| K1 | Förderung gestrichen — lebt in vier Dateien weiter | `decisions.csv:1329` active | `ECHOEL_VISION:59,344,364–368`, `PLAN_ENGINE_RECOVERY:91–140`, `TODO_FOUNDER:14–39` ohne Banner | Streichung endgültig? (GM37.1) |
| K2 | Tauchfliege raus (22.10.) / drin (28.10.) | `memory/decisions.md` 22.10., `ECHOEL_VISION:351` | `memory/vision.md:13` (Founder-Push, ohne decisions-Zeile) | Vision oder Streichung? (GM37.1) |
| K3 | Installation „kein Geschäftsfeld“ vs Palace als Abonnent und Website-Menü | `decisions.csv:1330` | `vision.md:12`, `REVIVAL_PLAN:56`, GM37-Empfehlung | Ausgabeziel ja · Einnahme nein · Website ja/nein? |
| K4 | „Nur Entwicklung / Store first“ vs Website-Umbau | `decisions.csv:1331`, `PLAN_STORE_FIRST:111,137` | `REVIVAL_PLAN:50–75` | Website nur Store-Pflicht oder Revival-Menü? |
| K5 | 1.0 = Umfang W1–W10 vs Datum „so schnell wie möglich“ | `decisions.csv:1333`, `PLAN_ONE_POINT_ZERO:6,17` | `decisions.csv:1331`; **`:1332` active sagt „Video … bleiben außerhalb von 1.0“** | Was ist 1.0? |
| K6 | Körper „kleines Gimmick“ vs „Echoels Kern“ | `FOUNDER_PRODUCT_LAW:27–33`, `ECHOEL_VISION:112–114` | `PLAN_ONE_POINT_ZERO:42`, `vision.md:20`, `REVIVAL_PLAN:61` | Welcher Satz geht nach außen? |
| K7 | DDSP vor oder nach 1.0 | `PLAN_ONE_POINT_ZERO:34` „vor“ | GM30 Empfehlung „(b) nach“ | GM30.2 |
| K8 | Mac nativ vs „Designed for iPad“ | GM36 Empfehlung nativ | `PLAN_STORE_FIRST:87`, E34 | GM36.2 |
| K9 | Preis | 14,99–19,99 € | 24,99–29,99 € | Basispreis, eine Zahl |
| K10 | `RELEASE:26` „App Group not requested“ | | Entitlements tragen beide Gruppen seit 21.10. | kein Entscheid, Sitzung korrigiert |
| K11 | Bitten-Budget 5 je Build vs 30 offene Punkte, 4 Uploads/Tag | `FOUNDER_INBOX:16–25` | `SESSION_LOG` 28.10. | Regel gilt ab wann wieder? |

---

## 6. Offene Founder-Fragen (Stand `FOUNDER_INBOX.md`, 44 offene Zeilen in §1)

**Blockiert 1.0:** F-15/E37 (IAP + Paid Apps Schedule + Preis) · GM37 (Richtung, Terms, „heilsam“) · GM36 (Plattformen =
Zeitplan) · GM28 (Store-Text übernehmen) · E15/GM16 (Mac/Vision „Designed for iPad“-Häkchen) · E14 (Store-Kästchen) ·
F-16/F-17 (ASC-Version 11.0, Screenshots) · H16 (Mindestalter in den AGB).
**Blockiert eine Welle:** GM30 (W5/Stufe K) · F25 (W4) · GM2/GM22 (W3 F4 Look im Stück) · Kamera-Begründung (W1 rPPG).
**Kann warten:** GM4, GM14, GM29 (billig, lohnt), E4b, E9/E20/E24–E27, E29/E30/E33, E31/E32/LR1–LR6, H1–H19 außer H16,
alle Alt-App-Fragen GM9–GM21, GM23–GM27, GM31–GM34, §3 F2–F6/F15 (Alt-App-CI).

---

## 7. Geräte-Bitten
**Studio, gültig für 10015:** SP (5, SP1 überholt, SP2 „teilweise“ ohne Host/Build), SR (5), SN (5), SM (5, braucht
Adapter/Interface/AirPlay), SA (5, braucht Interface), RELEASE-10015 (5) = **30 Punkte, 6 Familien, ~75–90 min**;
das Budget sagt 5 je Build. **Alt-App:** 411 Marker + G-Familien + zwei Geräte-Sitzungen (~50 min) — ohne Legacy-Upload
kann keine davon je einen Build bekommen. Empfehlung: als „ALT — eingefroren“ markieren.

---

## 8. Entscheidungs-Agenda für den 29.10. (nach Entsperrwirkung geordnet)

| # | Entscheidung | Optionen | Empfehlung | Was die Sitzung danach am selben Tag baut |
|---|---|---|---|---|
| 1 | **F-15: IAP `com.echoelmusic.app.pro` + Paid Apps Schedule + Basispreis** | a) heute, 19,99 € · b) 24,99 € · c) später | **a** — einziger Blocker auf allen Plattformen, seit 27.10. überfällig | SP4-Anleitung, Kauf-Satz in `CLAIMS.md`, Privacy-Label-Entwurf, Review-Notes |
| 2 | **Eine Geräte-Sitzung (~45 min):** SP2-Angabe (Host/Build/-3000), RELEASE-10015 1–5, SR1–SR4 | a) heute · b) nach nächstem Build | **a** — schließt zwei Familien, öffnet WIP | K1+K2 (Echoel-Keys-Kern, kein gated File) |
| 3 | **GM37.1 Tauchfliege + Förderung** | a) Streichung gilt · b) Vision 28.10. gilt | **a** (Panel 6/6; `decisions.csv:1329–1330` jüngstes protokolliertes Wort) | Banner auf vier Dateien, `vision.md:13`, zwei decisions-Zeilen |
| 4 | **K5: Was ist 1.0?** | a) 1.0 = W1–W6, 1.1 = W7–W10 · b) alles, Datum folgt · c) heute + W6 | **a** — hält „so schnell wie möglich“ UND „Körper drin“ | Plan umsortieren, `decisions.csv:1332` superseded, NEUPLANUNG nachführen |
| 5 | **F25: eine Zeile in `studio.yml`** | ja / nein bis 1.1 | **ja** — W4 ist der Weg zur Installation als Ausgabeziel (K3) | `ConnectionsOutput.swift` Scheibe 1 (Art-Net, aus bis Einschalten) |
| 6 | **Kamera-Begründung in `EchoelStudio/project.yml`** (W1 rPPG) | a) Founder trägt Zeile ein (Sitzung liefert Diff) · b) Gurt bleibt einzige Quelle | **a** — Flaggschiff-Quelle; zwei DSP-Kerne warten aufruferlos | Kamera-FSM + Publisher → `BodyChannel(.camera)` |
| 7 | **GM30 (1–4)** | je Inbox | 1 ja · 2 (b) wenn #4 = a · 3 ja · 4 ohne | K3/K4 nach #2 |
| 8 | **GM36** Plattformen, Mac-Weg, privat | | iPhone/iPad/Mac/Vision via „Designed for iPad“, privat erst nach Store | MIT-Sätze, Minuten-Messung |
| 9 | **GM37.2/.3 + H16:** Terms/Privacy neu (Anwalt), „heilsam“ raus, Mindestalter | | Anwalt ja vor erstem Verkauf | Copy ohne „heilsam“, Vorlagen markieren |
| 10 | **K3/K4: Website-Umfang bis 1.0** | a) nur Store-Pflicht (Privacy/Terms/Claims) · b) Revival-Menü jetzt | **a** — jede Website-Stunde ist keine Studio-Stunde | `REVIVAL_PLAN` Schritt 1 datieren, index Hero/Meta/Schema auf Studio |
| 11 | **K11 Bitten-Budget** | ausgesetzt bis 31.10. / gilt | gilt ab 1.11.; bis dahin ein Bump je Tag mit genau fünf Punkten | §2 auf 5 ziehen |
| 12 | **Alt-App-Geräteliste einfrieren** (411 Marker, G-Familien) | a) BLOCKED „ALT eingefroren“ · b) ein Legacy-Upload | **a** | Marker-Familie markieren, Inbox §2 kürzen |
| 13 | **GM28 Store-Text nach `fastlane/metadata`** | ja/nein | ja, nach #2 | Übernahme aus `APP_STORE_LISTING_STUDIO_11.md` + Wächter |
| 14 | **GM29 Bildschirm-Tastenleiste in P1** | ja/nein | ja (eine Scheibe) | baut sie |
| 15 | **K6 der eine Außen-Satz** (Workstation, Körper als Modul) | | `ECHOEL_VISION` §2 gilt | `vision.md:20`, `REVIVAL_PLAN:61`, `AboutView.swift:17`, `claims.html:86` nachziehen |

**Kernsatz:** vier Founder-Handlungen (F-15, Geräte-Sitzung, F25, Kamera-Zeile) und zwei Richtungsentscheide (K5, GM37.1);
alles andere kann die Sitzung am selben Tag bauen.

---

## 9. Was die Sitzung OHNE jede Entscheidung bauen kann (reine Sitzungsarbeit, kein gated File)
W2-Rest (LFO/Makro/MIDI-CC als Quellen; `LinearRamp` in den Render) · W3 F4/F5 · W10 D1–D4 (Tonart-Generierung) ·
W8 B4/B5 (Granular-Kern, Mikrofon ist da) · W1-Kamera-Code bis zur Plist-Zeile · Sky S1b (Sternkatalog) · A10 Texture ·
`AboutView.swift:17` + `claims.html:86` + `RELEASE:26` korrigieren · `fastlane/Appfile:52` (AUv3 „RETIRED“) ·
Store-Text-Datei vorbereiten (ohne Kauf-Satz) · Review-Notes-Entwurf · Format-3-Rückwärtsfall mit Quarantäne-Kopie + Test ·
Alt-App-Marker als eingefroren markieren · `version.json` Phantom-Changelog.

## 10. Grenzen dieses Audits
Kein Build, kein Test gelaufen (kein Toolchain); ASC-/Konto-Zustand nicht messbar; Zeilennummern altern; die Rechtsseiten sind
als Fakten beschrieben, nicht bewertet; Klang, Gefühl und Geräteverhalten sind außerhalb der Reichweite jeder Linse.
Vier Linsen × ~300 000 Token; Rohberichte liegen in den Sitzungs-Transkripten, die Kernpunkte in diesem Dokument.

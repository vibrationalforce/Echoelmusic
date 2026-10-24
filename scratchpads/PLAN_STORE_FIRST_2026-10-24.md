# PLAN_STORE_FIRST — Echoel Studio zeitgleich im App Store auf iPhone · iPad · Mac · Vision Pro, dann Repo privat
> **Provenienz.** Founder 2026-10-24 abends: „Ich bringe die App an den Start, verkaufe sie über den
> App Store … Sobald die App für das gesamte Apple Ökosystem zeitgleich im Store ist, stelle ich das
> Repo auf privat. Dann kommen die anderen Betriebssysteme." Gemessen von fünf Lese-Agenten (App-Layer,
> Audio/AUv3, Store/ASC, privates Repo, andere OS) und von einem Kritiker zu diesem Plan verdichtet
> (Workflow `wf_64e229bb-d22`, read-only). Die Sitzung hat den Plan gegengelesen und drei Dinge
> geändert: Zeilennummern der lebenden Inbox durch Zeilen-IDs ersetzt (eine Zeilennummer ist ein
> Datum, kein Sachverhalt), die Founder-Fragen in §7 an GM36 gehängt, die Risiken als §8 angefügt.
> Entscheidungen hier sind EMPFEHLUNGEN; die Founder-Zeile ist GM36 in `docs/dev/FOUNDER_INBOX.md`.
> Dieser Plan ersetzt in NEUPLANUNG §5 die gestrichene Förder-Reihenfolge als Fahrplan NACH P1.

Stand: Branch `claude/echoelmusic-review-optimize-u5jjpd`, 2026-10-24. Alle Zeilen gemessen (Befehl steht dabei) oder als `vermutet` markiert. Nichts wurde geändert. Web-Belege tragen URL und Datum aus den Leser-Berichten; ich habe keine neue Suche gemacht.

Kurzfassung in drei Sätzen: „Gesamtes Apple-Ökosystem zeitgleich" ist mit **null Codeänderung** erreichbar, wenn Mac und Vision Pro über „Designed for iPad" laufen — das ist in App Store Connect heute per Default **an** (E15 in `docs/dev/FOUNDER_INBOX.md` Zeile E15). Der einzige echte Blocker ist kein Code, sondern **F-15**: der Kauf `com.echoelmusic.app.pro` existiert in App Store Connect nicht (`FOUNDER_INBOX.md` Zeile E37, `EchoelStudio/Plugins/Shared/PluginUnlock.swift:16`). Die eine offene Gerätefrage, die den Mac-Weg entscheidet: **laden GarageBand/Logic auf einem Apple-Silicon-Mac die iOS-Extension aus dem bestehenden TestFlight-Build?** Das misst der Founder an einem Nachmittag, ohne eine Zeile zu ändern.

---

## 1. Was heute schon geht (gemessen)

| Was | Beleg | Status |
|---|---|---|
| Core, DSP, Engine deklarieren iOS 18 **und** macOS 15 | `EchoelStudio/{Core,DSP,Engine}/Package.swift:12-13` bzw. `:69-70` (`grep -n "\.macOS" EchoelStudio/*/Package.swift`) | sicher |
| Engine inkl. EchoelHost wird in CI auf dem macOS-Runner per `swift test` gebaut | `.github/workflows/studio.yml:148` | sicher (ob EchoelHost dabei kompiliert: vermutet, kein Log gelesen) |
| Core + DSP + Kernels/Engine bauen und testen auf Linux | `.github/workflows/studio-linux.yml:57-85`; Host-Grenze `Engine/Package.swift:49 #if !os(Linux)` | sicher; letzter Lauf grün/rot: nicht gemessen |
| Studio ist iPad-fähig → „Designed for iPad" auf Mac (Apple Silicon) und Vision Pro ist möglich | `EchoelStudio/project.yml:66 TARGETED_DEVICE_FAMILY "1,2"`, `:73 UIRequiresFullScreen NO`; keine `UIRequiredDeviceCapabilities` (Grep → 0) | sicher |
| Keine Kamera, kein UIScreen/UIDevice, kein fullScreenCover im Studio | `git grep "AVCaptureDevice\|UIScreen\|UIDevice\|fullScreenCover" -- EchoelStudio` → 0 | sicher |
| StoreKit-Code ist plattformneutral (kein UIKit, kein `#if os`) | `EchoelStudio/App/Store/StoreController.swift:48,116-118` | sicher |
| Ein App-Record, eine Bundle-ID für alle Plattformen | `project.yml:7-9,64` (`com.echoelmusic.app`, Record 6757957358) | sicher |
| App-Group `group.com.echoelmusic.shared` ist iOS-Stil und seit 02/2025 auf allen Mac-Produkttypen zulässig — **nicht umbenennen** | Apple DTS Thread 721701 (rev. 2025-08-12, gelesen 2026-10-24); Entitlements `Support/App/EchoelStudio.entitlements:18`, `Support/Plugins/EchoelPlugins.entitlements:38` | sicher |
| AUv3-Render-Block ist plattformneutral (kein Lock, keine Allokation, Doppel-Import AudioToolbox+AVFoundation) | `Plugins/Shared/InstrumentAudioUnit.swift:1-2, 230-282` | sicher |
| TestFlight-Upload-Pfad läuft (Build 10004+) | `studio-testflight.yml`, `EchoelStudio/RELEASE` | sicher |

**Was heute NICHT geht:** kein Mac-, Catalyst- oder visionOS-Target (`project.yml:41 platform: iOS`; Extension `:136-137 SDKROOT iphoneos`, `SUPPORTED_PLATFORMS iphoneos iphonesimulator`); ein Icon-Set nur `platform: ios` (`App/Assets.xcassets/AppIcon.appiconset/Contents.json`); Entitlements ohne Sandbox; kein `auval` in CI (Grep über `.github/workflows` → nur `pr-check.yml:144`, Alt-App).

**Korrekturen an den Lesern (gemessen):**
- AVAudioSession in `App/Engine/AudioEngine.swift`: die Leser nennen 11, 13 und ~14 Stellen. `grep -c AVAudioSession` liefert **15 Zeilen** (+1 in `PluginHost.swift`). Die Größenordnung stimmt, die Zahl schwankt je Zählweise — deshalb hier der Befehl, nicht die Zahl.
- `runs-on`: Leser 4 zählt 16 macOS / 14 Ubuntu. `grep -h runs-on .github/workflows/*.yml | sort | uniq -c` liefert **15 macOS** (14× `macos-26`, 1× `macos-15`) und **16 Ubuntu**. Für die Kostenfrage unerheblich, für „messen statt zitieren" nicht.
- Die Aussage „Catalyst-AUv3 wird seit Xcode 26.1 nicht mehr registriert" (Leser 1 und 2) stützt sich auf **einen unbeantworteten Forum-Thread** (808035). Leser 1 baut darauf seine Hauptempfehlung „nativ statt Catalyst". Das trägt nicht. Die Frage wird am Founder-Mac entschieden, nicht durch den Thread (Scheibe 3).
- Leser 3 schreibt „Universal Purchase ab 2 Plattformen, dann unumkehrbar". Richtig — aber für „Designed for iPad" ist das **gegenstandslos**: dort gibt es nur die iOS-Plattform im Record. Es greift erst, wenn du ein natives Mac-/Vision-Target hochlädst.

---

## 2. Reihenfolge der Scheiben

Gate-Legende: **CI** = ein Push entscheidet · **Mac** = braucht den Founder-Mac · **ASC** = braucht das App-Store-Connect-/Developer-Konto des Founders.

### Scheibe 0 — Der eine Test, der den ganzen Mac-Weg entscheidet (S, Mac, sicher)
Installiere den bestehenden TestFlight-Build 10004+ über TestFlight-für-Mac auf einem Apple-Silicon-Mac (Tester-Gruppe: „Test iPhone and iPad apps on Apple silicon Macs → Enable", Apple-Hilfe gelesen 2026-10-24). Öffne GarageBand oder Logic. Suche „Echoel". Ergebnis in `FOUNDER_INBOX.md` §2 eintragen.
- Erscheinen die Plugins und spielen 30 s → **Mac braucht kein eigenes Target für den Launch.** Der Kauf (das Produkt!) funktioniert dort über denselben Pfad wie auf iOS.
- Erscheinen sie nicht → Scheibe 3 wird Pflicht und gated den Launch (siehe §4).
Ohne diese Messung ist jede Mac-Entscheidung Rätselraten. Kein Apple-Dokument belegt oder widerlegt es (beide Leser: acht Suchen, nichts). ⚠️ Ein Intel-Mac kann den Test nicht fahren (`FOUNDER_INBOX.md` Zeile E34).

### Scheibe 1 — Store-Fundament, alles ASC (S, ASC, sicher)
1. Paid Applications Schedule akzeptieren (Account Holder).
2. Produkt `com.echoelmusic.app.pro` anlegen, nicht-verbrauchbar, **ein** Basis-Land + Basispreis (gilt für alle 175 Storefronts und alle Plattformen; Apple-Hilfe „Set a price for an IAP", gelesen 2026-10-24). Preisband ist im Repo widersprüchlich (14,99–19,99 € in `memory/decisions.md:355`, 24,99–29,99 € in `NEUPLANUNG_2026-10-18.md:279`) → Founder-Frage 2.
3. Record-Metadaten von der Alt-App auf Studio umstellen (Name, Untertitel, Keywords, Privacy-Label; Entwurf `docs/dev/APP_STORE_LISTING_STUDIO_11.md`). Sonst erben Mac/Vision den Text „Bio-Reactive Instrument".
4. „Pricing and Availability → Mac (Apple Silicon)" und „→ Apple Vision Pro" **anlassen** (Default an). Das ist E15.
Gate: Sandbox-Kauf in der App + Synth in AUM neu laden (SP4 in der Inbox).

### Scheibe 2 — iPhone + iPad fertig machen (S–M, CI + Gerät, sicher)
Das ist der eigentliche Produkt-Rückstand und liegt außerhalb dieses Berichts (NEUPLANUNG §5, `BAUSTELLEN_BOARD.md`). Für den Launch zählt: Gerätetests nach `CLAIMS.md` (36 Sätze, „nichts davon auf einem Gerät geprüft", `:90`), Screenshots iPhone + iPad, Release Notes. Store-Text ohne den Kauf-Satz, bis F-15 und der Host-Test stehen (`CLAIMS.md:127`).

### Scheibe 3 — Mac nur falls Scheibe 0 scheitert, oder als 1.1 (S bis L, Mac + CI + ASC)
Drei Wege, aufsteigend:
- **3a Mac Catalyst** (M, vermutet): UIKit und AVAudioSession bleiben (Catalyst 13.1+). Neu: Catalyst-Target in `project.yml` (founder-gated), Mac-Icon-Set, Sandbox-Entitlements (`app-sandbox`, `device.audio-input`, `network.client`, `application-groups`), macOS-Provisioning-Profil mit beiden App-Groups (neue Signier-Probe), Menü-Politur. **Erster Schritt (S, Mac):** `xcodebuild -destination 'platform=macOS,variant=Mac Catalyst'` — der liefert die Fehlerliste, die die Leser nur vorhersagen. Dann `auval -v aumu eSyn Echo` für alle 8 Komponenten. Dieser Lauf beantwortet die Catalyst-AUv3-Frage direkt.
- **3b Nativ macOS** (L, sicher): zusätzlich AVAudioSession-Abstraktion (15 Zeilen in `AudioEngine.swift`, Semantik der Howl-Regeln `:125-134` neu auf CoreAudio-Begriffe), Picker→`.fileImporter` (Muster schon in `SoundPanel.swift:57`), Share→`ShareLink`, `UIViewController`→`NSViewController` in `PluginHost.swift:605-619`/`PluginInterfaceView.swift`, 8× `.topBarLeading/Trailing` + 6× `navigationBarTitleDisplayMode` ersetzen, Extension-UI auf `NSHostingController` (`PluginViewController.swift:26,61,92`). Schätzung der Leser „2–3 Wochen" ist **[N]**, keine Messung.
- **Empfehlung:** 3a zuerst messen, 3b nur, wenn `auval` unter Catalyst wirklich scheitert. Das deckt sich mit der am 2026-10-16 schon getroffenen Entscheidung E34 („E15 zuerst, Mac Catalyst danach", `FOUNDER_INBOX.md` Zeile E34).
Gate je Weg: Xcode-Build auf dem Mac → `auval` → Signier-Probe (studio-signing-probe.yml, founder-gated) → TestFlight-Mac → Sandbox-Kauf.

### Scheibe 4 — Vision Pro (S, ASC, sicher)
„Designed for iPad" bleibt an. Kein Code. Hinweis in der Vision-Beschreibung, dass Mikrofon/Interface dort ungemessen sind. Native visionOS ist L (Layered Icon, Fenster/Volumes, eigenes Target) und **schließt den Kompatibilitätsmodus dauerhaft aus** (Apple-Hilfe, gelesen 2026-10-24) — nicht für 1.0.

### Scheibe 5 — Texte und Screenshots je Plattform (M, Founder-Gerät, sicher)
Beim „Add Platform" werden Description, Promotional Text und Screenshots **nicht** übernommen. Für „Designed for iPad" gilt dagegen: Apple zeigt die iOS-Seite unverändert — dann müssen „for iPhone and iPad"-Sätze (`APP_STORE_LISTING_STUDIO_11.md:33,45,57`) auf dem Mac korrekt bleiben (sind sie: es ist die iPad-App). Hardware-Sätze (Mikrofon `CLAIMS.md:115`, Bluetooth-MIDI `:109`, Files/AirDrop `:119`) nur behaupten, was auf dem Mac gemessen ist.

### Scheibe 6 — Einreichung (S, ASC)
Eine Version, ein Build, iOS-Plattform mit Mac- und Vision-Verfügbarkeit, erster IAP im selben Review. Nach Freigabe: „zeitgleich" ist erfüllt, weil es **ein** Listing ist.

### Scheibe 7 — Repo privat (S für den Schalter, M für die Vorarbeit) → §5.

---

## 3. Die eine Entscheidung je offener Frage

| Frage | Entscheidung | Warum |
|---|---|---|
| **Catalyst vs. nativ Mac** | Für 1.0: **keins von beiden**, „Designed for iPad" — **falls Scheibe 0 grün**. Für 1.1 oder bei rotem Scheibe-0: **Catalyst zuerst messen** (ein Nachmittag), nativ nur bei gemessenem `auval`-Fehler. | Nativ ist L mit einer Semantik-Neuabbildung (Howl-Regeln). Der Beleg gegen Catalyst ist ein unbeantworteter Forum-Post. E34 hat Catalyst am 2026-10-16 bereits gewählt. |
| **Vision native vs. Designed for iPad** | **Designed for iPad.** | 0 Code, Default an. Native = L und unumkehrbar gegenüber dem Kompatibilitätsmodus. Studio hat keine Kamera, keine Device-Capabilities, die es ausschließen (gemessen). |
| **Watch** | **Nein** für Studio 1.0. | Es gibt kein Studio-Watch-Target. Das Alt-App-Watch-Target ist nicht eingebettet und braucht einen Transport (WCSession, neues Framework). Nichts an Studio ist eine Watch-Fläche. |
| **tvOS** | **Nein.** | Kein Target, keine Eingabe, kein AUv3-Markt. GM16 (`FOUNDER_INBOX.md` Zeile GM16) nennt es nur als spätere Ausgabe-Fläche. |
| **iPad** | **Ja, ist drin** (`TARGETED_DEVICE_FAMILY "1,2"`). | Universal Purchase iPhone+iPad verlangt genau das. Layout-Politur (88 pt/Takt ohne Zoom, `ArrangeView.swift:18`) ist M, kein Blocker. |

---

## 4. Was „zeitgleich" kostet

**Mit „Designed for iPad":** Die langsamste Plattform ist **iPhone/iPad selbst** — Scheibe 2 plus Scheibe 1. Mac und Vision kosten nichts extra und können den Launch nicht aufhalten. „Zeitgleich" ist dann ein Nebeneffekt, kein Projekt.

**Mit nativem oder Catalyst-Mac im 1.0:** Die langsamste Plattform ist **der Mac**. Gründe: neues Target in founder-gated `project.yml`, neue Signier-Probe mit macOS-Profil (die iOS-Probe brauchte fünf Läufe, `FOUNDER_INBOX.md` Zeile F17), Mac-Icon-Set, Sandbox, `auval`, Mac-Review mit Sandbox-Pflicht (Apple „macOS distribution", gelesen 2026-10-24), eigene Screenshots und Description, und bei nativ die L-Abstraktion. Realistisch Wochen, alle am Founder-Mac und -Konto; **vermutet**, keine Messung.

**Alternative:** iPhone + iPad (mit Mac/Vision als Kompatibilitätsmodus) als 1.0, natives/Catalyst-Mac als 1.1. Trade-off: Sobald die native Mac-Plattform freigegeben ist, **ersetzt** sie die iPad-App auf dem Mac und Apple migriert die Nutzer (Apple-Hilfe „Manage availability on Macs with Apple silicon", gelesen 2026-10-24). Dann ist Universal Purchase da und unumkehrbar. Preis der Alternative: Mac-Nutzer sehen bis 1.1 Touch-Metriken (44-pt-Ziele, `Theme.swift:72`) und kein Menü. Gewinn: der Launch hängt nicht an einer Plattform, für die heute keine einzige Zeile gebaut ist.

**Meine Empfehlung:** die Alternative — mit Scheibe 0 als Pflicht davor. Der Founder-Satz „zeitgleich im Store" ist damit wörtlich erfüllt.

---

## 5. Privates Repo: Kosten und drei Optionen

**Was privat NICHT ändert (sicher):** Jeder Klon und jeder Fork behält den bisherigen Stand unter MIT (`LICENSE:1-10`); bestehende öffentliche Forks bleiben öffentlich. Privat schützt nur **künftige** Commits. `NEUPLANUNG_2026-10-18.md:246` sagt das selbst.

**Was vorher falsch würde (gemessen, `grep -n MIT`):** `docs/roadmap.html:126` („source code is public under the MIT licence") und `:113`, `README.md:9,22,169`, `CONTRIBUTING.md:15`, Überschrift `docs/security.html:136`. Store-Text behauptet nichts dergleichen. Intern: `ECHOEL_VISION_2026-10-19.md:41,325`, `NEUPLANUNG:243-253`. `decisions.csv` hat zur Privat-Frage keine eigene Zeile — die heutige Zeile nennt „privat" nur im Nebensatz.

**Kostenlogik (Web, 2026-10-24, docs.github.com war nicht abrufbar — Zahlen aus Suchauszügen, vor dem Schalten gegenlesen):** private Repos: Free 2.000 / Pro 3.000 Minuten, macOS zählt 10×, Überschreitung 0,08 USD/min. Ein Studio-Push startet 2 macOS-Jobs (Timeouts 30+40 min, `studio.yml:29,187`). Die Push-Rate pro Monat ist **nicht messbar** aus diesem Container; Leser 4 nennt 48–700 USD/Monat — das ist ein Faktor 15 Unsicherheit, also **keine Zahl, sondern eine Lücke**. Erste Handlung vor dem Schalter: `mcp__github__actions_list` → `python3 scripts/gh-run-status.py` für 30 Tage, Minuten summieren.

| Option | Laufende Kosten | Aufwand | Haken |
|---|---|---|---|
| **A** Privat + GitHub Pro (≈4 USD) + gehostete macOS-Runner | Plan billig, Minuten offen (s. o.) | S Schalter + S Textkorrekturen + **M: Legacy-Workflows stilllegen** (ci.yml hat 5 macOS-Jobs für die eingefrorene Alt-App; founder-gated) | Ohne Stilllegung zahlst du für Gates einer eingefrorenen App. Default-Ausgabenlimit 0 USD → Gates bleiben stehen statt zu kosten. |
| **B** Privat + Self-hosted Mac-Runner | ≈0 USD Minuten (Gebühr 0,002 USD/min verschoben, Status beobachten) | L: VNC-Session, Xcode 26.2, Secrets lokal, 15 `runs-on`-Zeilen in 9 founder-gated Workflows | Runner-Verfügbarkeit = CI-Verfügbarkeit. „Mit Anna von unterwegs" spricht gegen den eigenen Mac; gemieteter Mac mini ≈144 EUR/Monat [N aus S]. |
| **C** Code öffentlich, Planung in privates Begleit-Repo (= E32, `FOUNDER_INBOX.md` Zeile E32) | 0 USD | M: Umzug `docs/dev/`, `scratchpads/`, `memory/`, Hook-Pfade, Wächter | Quellcode bleibt offen — was er für alles bis heute ohnehin unwiderruflich ist. Widerspricht dem Wortlaut „Repo auf privat". |

**Empfehlung: A, in dieser Reihenfolge:** (1) Minuten messen, (2) Legacy-Workflows auf `workflow_dispatch` (founder-gated, du bestätigst), (3) MIT-Texte und `decisions.csv`-Zeile, (4) Pro buchen, Ausgabenlimit bewusst setzen, (5) schalten. Fällt die Messung über ≈1.000 macOS-Minuten/Monat, wechsle auf B mit gemietetem Runner. C nur, wenn du die Offenheit des Codes bewusst behalten willst — dann ist es die billigste und ehrlichste Form. Pages: Website braucht auf Free ein öffentliches Repo; auf Pro geht privat. Ob Cloudflare Pages mit privatem Repo weiterbaut: nicht recherchiert — vor dem Schalter prüfen (`docs/CLAUDE.md:64-66`).

---

## 6. Andere Betriebssysteme (zwei Sätze)

Wiederverwendbar sind 54 der 60 Dateien unter `EchoelStudio/{Core,DSP,Engine}/Sources` (nur Foundation, Observation, Synchronization; Linux-Build belegt in `studio-linux.yml`), das JSON-Songformat (`docs/FORMAT.md`) und die Render-Logik — nur die sechs EchoelHost-Dateien (AVFoundation/AudioToolbox, ungeguardet) und die gesamte App- und Plugin-Schicht (SwiftUI, CoreMIDI, StoreKit, AUv3) sind Apple. Vorher eine S-Reparatur: `Engine/Package.swift:49 #if !os(Linux)` schützt Windows/Android nicht — muss `#if canImport(AVFoundation)` o. ä. werden; Swift SDK für Android ist seit 6.3 offiziell, Windows seit 2020 (swift.org, 2026-10-24), die UI ist auf beiden ein Neubau (L).

---

## 7. Die Founder-Fragen (gebündelt in GM36, eine Zeile Antwort reicht)

1. Scheibe 0: Hast du einen Apple-Silicon-Mac, und kannst du den TestFlight-Build 10004+ dort über TestFlight-für-Mac installieren und in GarageBand/Logic nach „Echoel“ suchen? Empfehlung: Ja, als allererstes — das Ergebnis entscheidet, ob Mac für 1.0 ein eigenes Target braucht (vermutlich nicht). Ein Intel-Mac kann es nicht; dann sag das.
2. Preis für com.echoelmusic.app.pro: 14,99–19,99 € (memory/decisions.md:355) oder 24,99–29,99 € (NEUPLANUNG_2026-10-18.md:279)? Empfehlung: ein Basispreis um 19,99 € in Deutschland als Basis-Storefront; er gilt automatisch für alle Plattformen und 175 Storefronts, du kannst ihn später nur mit 14 Tagen Vorlauf für andere Storefronts ändern.
3. Darf Mac/Vision im 1.0 ausschließlich als „Designed for iPad“ laufen (Häkchen E15 bleibt an, kein eigenes Target), mit nativem/Catalyst-Mac als 1.1? Empfehlung: Ja — das erfüllt „gesamtes Ökosystem zeitgleich“ wörtlich und hängt den Launch nicht an eine Plattform ohne eine einzige gebaute Zeile.
4. Repo privat: Option A (Pro-Plan + gehostete Runner, Legacy-Workflows vorher stilllegen) oder Option C (Code offen, nur Planung privat)? Empfehlung: A — aber erst nach der Minuten-Messung per GitHub-API; und du bestätigst die Stilllegung von ci.yml/full-tests.yml/xcode-compile-check.yml/benchmark.yml/pr-check.yml/testflight.yml (founder-gated).
5. Darf ich vor dem Schalten die MIT-/Open-Source-Sätze korrigieren (docs/roadmap.html:113,126, README.md:9/22/169, CONTRIBUTING.md:15, docs/security.html:136) und eine eigene decisions.csv-Zeile „Repo privat nach Launch“ anlegen? Empfehlung: Ja, im selben Commit wie der Schalter; bis dahin bleiben sie wahr.
6. Watch und tvOS sind für Studio 1.0 raus (kein Target, kein Transport). Einverstanden? Empfehlung: Ja; „gesamtes Ökosystem“ heißt im Store-Sinn iPhone · iPad · Mac · Vision Pro mit einem Listing.

---

## 8. Risiken, die der Kritiker stehen ließ

- F-15 ist Blocker Nr. 1 auf allen Plattformen: ohne angelegtes Produkt und akzeptiertes Paid Applications Schedule gibt es weder Sandbox-Test noch Verkauf; der erste IAP muss mit einer App-Version zusammen in den Review (Apple-Hilfe, gelesen 2026-10-24).
- Kein Apple-Dokument belegt, dass die iOS-AUv3-Extension als „Designed for iPad“ auf dem Mac in Hosts erscheint (zwei Leser, acht Suchen, nichts). Scheitert Scheibe 0, wird der Mac vom Null-Aufwand zur langsamsten Plattform (M–L) und gated den Launch.
- Der Record trägt noch Alt-App-Metadaten („Bio-Reactive Instrument“). Jede Plattform erbt sie; auf einem Mac-/Vision-Listing ist das eine 2.3-Ablehnung. Umstellen VOR dem Review.
- Universal Purchase wird nach Freigabe von zwei Plattform-Versionen unumkehrbar; ein versehentlich hochgeladener nativer Mac-/Vision-Build bindet die Plattform dauerhaft an den Record und schaltet den „Designed for iPad“-Modus dort ab.
- Privat-Schalten kostet unbepreist: die macOS-Minuten pro Monat sind nicht gemessen (Spanne der Leser 48–700 USD, Faktor 15). Ohne Stilllegung der fünf Legacy-macOS-Jobs zahlt der Founder für Gates einer eingefrorenen App; mit Ausgabenlimit 0 USD stehen stattdessen alle Gates still.
- Privat schützt nur künftige Commits: der gesamte bisherige Stand inklusive docs/dev-Planung bleibt in Klonen und Forks unwiderruflich MIT. Wer „privat“ als Geheimhaltung des Produkts liest, liest falsch.
- project.yml, Info.plist, Entitlements und .github/workflows sind founder-gated: jedes Mac-Target, jede Sandbox-Zeile, jede Runner-Umstellung und jede Workflow-Stilllegung braucht deine Hand oder Freigabe — der Zeitplan hängt an deiner Verfügbarkeit, nicht an der Codemenge.
- Alle „kompiliert auf macOS“-Aussagen der Leser sind Lesen, kein Gate — in dieser Session gibt es keinen Toolchain. Der erste xcodebuild mit macOS-Destination auf deinem Mac liefert die echte Fehlerliste; bis dahin sind alle Mac-Aufwandsklassen vermutet.

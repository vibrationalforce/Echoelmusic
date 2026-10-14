# Realitäts-Check, Stabilität, Hype-Kontrolle und Belohnungssystem — 2026-10-14

Auftrag (Echoel, 2026-10-14): „Stability, quality, DMMW–GMMW Reality Check, Deep Audit und
Marketing Hype Control, soziale Umverteilung durch User und Feedback System: rewards via
bitcoin oder andere Strategie."

Methode: drei lesende Prüfer parallel (Realität gegen Code, Stabilität, Belohnung/Recht).
Jeder Befund unten nennt Datei und Zeile; Kernbefunde habe ich selbst am Code nachgeprüft.
**Nichts hier ist auf einem Gerät gemessen.** „Im Code nachgewiesen" heißt gelesen, nicht gehört.

---

## 1. Hype-Kontrolle — was nach außen behauptet wird

**App-Store-Text (beide Sprachen): sauber.** Jede genannte Fähigkeit hat einen erreichbaren
Besitzer im Code.

**Website und README: sieben Übertreibungen, korrigiert in `8ed722967`:**

| Stelle | war | ist | Grund |
|---|---|---|---|
| `docs/index.html` Titel (3×) | „The **First** Bio-Reactive Performance Instrument" | „A Bio-Reactive Performance Instrument for iPhone" | Superlativ ohne Beleg (UWG §5) |
| `docs/index.html` Karte | „Resonance breathing — ein Guide führt" | entfernt | `BreathGuideView` hat keine Tür (`BioSourceView(` → 0 Aufrufer) |
| `docs/overview.html:261` | Warnung vor „brainwave-entrainment modes" | „nicht beim Fahren/an Maschinen" | Modus unerreichbar; Wort verletzt die Markenregel |
| `docs/overview.html:252` | „your data never leaves your hardware" | Opt-in-Ausgänge benannt | absolut falsch (OSC, Health, Nearby, Wetter) |
| `docs/index.html:909` | „Runs everywhere" | „Built native for iPhone" | nur iPhone wird ausgeliefert |
| `docs/index.html:760` | „Your pulse drives the bass" | „Your pulse sets the tempo until you lock it" | `SubBassVoice` liest keinen Puls |
| `docs/index.html:664` | „feel the bass through a dedicated sub" | Sub-Bass-Stimme eine Oktave tiefer | Stereo-Ausgang; Haptik nur Beat |
| `docs/overview.html:200` | „never an AUv3 host" | Hosting neu, Geräteprüfung läuft | seit 2026-10-13/14 im Code |

**Offen, nächster Hype-Schritt:**
- **GitHub-Repo-Beschreibung (gehört dem Founder):** „…Creation and **Wellbeing**. Share your
  Progress – a fair and sensitive Plattform for all." — Wellness-Wort (gestrichen in
  `ContentPipeline/CLAIMS.md`) und eine Teilen-Plattform, die es nicht gibt. Vorschlag:
  *„Bio-reactive instrument for iPhone — heart and breath drive sound, visuals, light
  (Art-Net/sACN) and spatial objects (ADM-OSC). On-device, no account."*
- Widersprüche zwischen Seiten: `docs/tools.html:174` („no note grid") und
  `docs/brainstorming.html:150` („not a sampler") gegen `faq.html`, die Editor und Sampler korrekt
  nennt; `README.md:53` nennt die Arrange-Fläche „nicht ausgeliefert".
- Barrierefreiheit: `docs/tools.html:224` („VoiceOver-first") behauptet mehr als `faq.html:270`.
- Zu klein gemacht: Siri/Shortcuts-Befehle und MIDI 2.0 Out sind im Code, die Seiten sagen
  „Roadmap".
- `docs/press.html:91` „professional generative music" — Klang-Check 1 ist ein Founder-Ohr-Urteil,
  noch offen.
- **In der App selbst:** eine Wissenschafts-Karte (`TheChromeSpeaksOneLanguageTests` zitiert sie)
  sagt „Echoelmusic paces one steady rate". Ob der Atem-Taktgeber erreichbar ist, wird vor einer
  Änderung geprüft.

## 2. DMMW/GMMW — Realität im Code heute

| Säule | Stand | Beleg |
|---|---|---|
| Audio-Engine | ausgeliefert | `AudioEngine.swift` (RetroCapture, AutoMixChain) |
| MIDI / MPE | In: eine monophone Stimme, keine Zonen · Out: MPE + MIDI-2.0-Quelle | `MIDIOutput.swift` |
| Instrumente | ausgeliefert (DDSP, Poly, Sub); Sampler pro Spur verdrahtet, Gerät offen | `LaneVoiceRack.swift` |
| Effekte | ausgeliefert (eingebaut); fremde Effekt-Plugins: Modell + Bus, Einhängen fehlt (H6) | `EchoelFXChain`, `PluginEffectInsert.swift` |
| Aufnahme | teilweise: Mitschnitt des eigenen Ausgangs + MIDI-Take; kein Mikrofon (#1302) | `RetroCapture` |
| Arrangement | verdrahtet, Gerät offen | `WorkstationView.swift` |
| Mix / Master | verdrahtet | `PieceMixerView.swift`, `AutoMixChain` |
| Automation | verdrahtet, Gerät offen; Schreiben aus dem Spiel fehlt | `TrackInspectorView.swift` |
| Video | nicht vorhanden (#1304) | — |
| Visuals | ausgeliefert | `MetalBioView`, `ExternalDisplayScene.swift` |
| Licht | ausgeliefert (Art-Net, sACN) | `EchoelmusicApp.swift` |
| Raum | nur Steuerseite (ADM-OSC aus und ein); Render-Kerne ohne Aufrufer | `ADMOSCSender`, `OSCReceiver`; `VBAPPanner(` → 0 |
| Streaming | Gerüst, HaishinKit nicht verlinkt | `BroadcastView(` → 0 |
| Zusammenarbeit | verdrahtet (Multipeer, nah) | `EchoelStudioView.swift` |
| KI | Siri/Shortcuts + „Describe this piece" verdrahtet, Gerät offen | `EchoelAppIntents.swift` |
| Plugin-Hosting | Instrumente verdrahtet (1 Tag alt), Gerät offen | `HostedInstrumentHost.swift` |
| Eigenes AUv3 | gerätegeprüft nur in AUM | `Sources/EchoelmusicAUv3/` |
| Bio | ausgeliefert (Kamera, HealthKit); BLE-Gurt Gerät offen | `CameraRPPGBioPublisher`, `PolarH10BioPublisher` |

**Ehrliche Lesart:** Die DMMW ist zu gut der Hälfte verdrahtet. Video und Streaming fehlen ganz,
Raum ist nur Steuerung. Das Größte, was fehlt, ist kein Code, sondern **Geräte-Nachweise**: das
Werkzeug `scripts/founder-verify.py` zählt **357 offene Prüfbitten in 305 Dateien, 0 beantwortet**.

## 3. Stabilität und Qualität

**Messwerte:** `doctor.py` 0 kritisch · Modal-Kette 12 von 14 · Off-Main-Fallen (Familie
2613/2618) 0 · keine gefährlichen Force-Unwraps · neue Divisionen abgesichert.
⚠️ Zwei Decken ohne Luft: Literal-Ratsche 696/696 und `CLAUDE.md` 15 B unter 150 000 B.

**Top-Risiken und was damit geschah:**

| # | Risiko | Art | Status |
|---|---|---|---|
| 1 | Absturzschutz von heute (2624) erklärte tonhöhenveränderte Audio-Teile in Headphone space für „nicht verbunden": stumm, plus Neuaufbau bei jedem Play | stilles Fehlverhalten | **behoben `6d2d64572`** — Weg bis 32 Stationen, Wächter 1b |
| 2 | Plugin-Wahl während des Spiels hält die laufende Engine an; scheitert der Neustart, ist die App stumm bis zum Tippen auf „Degraded" | Absturzfamilie | offen — Laden auf den nächsten Stopp verschieben (nächste Scheibe) |
| 3 | Ein Plugin, das die Engine nicht einhängen kann, wurde bei jedem Teil-Start neu geladen | Wiederhol-Sturm | **behoben `8b1203e93`** |
| 4 | Ein abgestürztes Plugin könnte die Spur stumm halten, wenn iOS ein anderes Objekt meldet | still, unbelegt | offen — auch `unit.audioUnit` vergleichen, unbekannte Meldungen loggen |
| 5 | Neuaufbau beim Play (Pause/Neustart) | Absturzfamilie | durch #1 seltener |
| 6 | Spur-Bus (H6-3) könnte Pegel/Panorama beim Start zurücksetzen | still, unbelegt | Geräte-Sitzung Familie 4 |
| 7 | Stiller Starttod Build 2621 unerklärt | Stabilität | braucht ein Geräte-Log |
| 8 | Hängende Noten bei gehosteten Plugins nach Stop unbelegt; Pegelbereich 0…1 statt 0…2 | still | Geräte-Sitzung Familie 3 |
| 9 | Zwei Decken ohne Luft | Prozess | vor dem nächsten Text-Zuwachs Provenienz ins Ledger verschieben |
| 10 | CI-Signal unzuverlässig (#396, Stale-Pages, falsches Grün in `full-tests.yml`) | Prozess | founder-gated (`FOUNDER_INBOX.md` §3) |

**Solide:** ein Besitzer pro Plugin-Slot; veraltete Ladevorgänge werden verworfen; jeder
Graph-Eingriff schreibt zuerst seine Sprosse ins Diagnose-Log; jeder Neustart geht durch den
einen Helfer, der bei Fehlschlag in den Degraded-Zustand übergibt; Spur-Busse bauen nie auf einer
laufenden Engine.

## 4. Eine Geräte-Sitzung, 30 Minuten (Build nach `8b1203e93`)

Diagnose-Export bereithalten. Fünf Familien statt verstreuter Bitten:

1. **Start (5 min):** dreimal kalt starten, alle fünf Bühnen antippen, bei laufendem Puls das
   Tonart-Menü öffnen und ändern, in den Hintergrund und zurück. Erwartet: kein Schwarzbild, kein
   Safe Mode, Menü reagiert. Einmal das Log exportieren.
2. **Headphone space (5 min):** Kopfhörer, Mixer → Headphone space an, zwei Audio-Spuren, auf
   einer Part-Pitch +7 oder Warp. Erwartet seit dem Fix: beide klingen.
3. **Fremdes Plugin (8 min):** AUv3-Synth auf eine Rack-Spur. (a) im Stopp wählen, spielen, Stop —
   hängen Noten? (b) während des Spiels ein anderes wählen — kurzer Aussetzer, kein „Degraded"?
   (c) Plugin-Fenster öffnen, Klang ändern, schließen, speichern, neu öffnen — kommt der Klang
   wieder? (d) Kopfhörer im Spiel ab- und anstecken. (e) Fader auf Maximum gegen eine eingebaute
   Stimme vergleichen.
4. **Rack-Pegel (4 min):** zwei MIDI-Spuren auf 0,5 und hart links/rechts, speichern, App beenden,
   neu starten, spielen — stimmen Pegel und Panorama ab der ersten Note?
5. **Export und MIDI (8 min):** WAV-Export bis zum Teilen-Blatt; MIDI-Keyboard anstecken und
   spielen; Health-Quelle neu starten; drei Genres je 2 Minuten mit Puls (Klang-Urteil).

## 5. Belohnung und faire Umverteilung

### Urteil Bitcoin: **ablehnen — höchstens später, und nur außerhalb der App**

- **Apple** (Review Guidelines, heute abgerufen): Krypto ist als Freischaltung verboten (3.1.1);
  Krypto für Aufgaben, Downloads, Empfehlungen oder Social-Posts ist verboten (3.1.5(v)); ein
  Wallet in der App nur für Firmen-Accounts (3.1.5(i)); belohnte App-Store-Bewertungen können zum
  Ausschluss aus dem Developer Program führen.
- **Steuer:** Bitcoin im Betriebsvermögen hat keine Haltefrist — jede Auszahlung ist ein eigener
  Veräußerungsvorgang mit Buchung. Empfänger zahlen Steuern auf den Euro-Wert.
- **Aufsicht:** MiCA gilt; eigene Zahlungen aus dem eigenen Wallet sind vermutlich kein
  Krypto-Dienst, Guthaben für Nutzer halten oder Punkte in BTC tauschen wären es (Anwaltsfrage).
- **Datenschutz:** Was in der Blockchain steht, lässt sich nicht löschen — Konflikt mit dem
  Löschrecht (DSGVO Art. 17).
- **Erfahrung des Marktes:** Sound.xyz offline seit 16.01.2026, Audius-Token rund −95 %,
  Ampled (Künstler-Genossenschaft) Ende 2023 eingestellt. Überlebt haben Modelle mit Geld in Euro,
  Dritten für die Compliance und Bezahlung für echte Arbeit oder Nutzung (Splice: über 25 Mio. $
  an Creator, verteilt nach Nutzung).

**Fair wird es durch die Verteilung, nicht durch die Währung.**

### Stufenplan

| Stufe | Was | Rechtliches Risiko |
|---|---|---|
| **v1.0 (heute, kostenlos)** | Feedback über TestFlight, GitHub Discussions und einen „Feedback senden"-Link (nur App-Version, nie Bio-Daten); öffentlicher Changelog mit Namen; Hall of Fame; Liste der Mitwirkenden für ein Gratis-Jahr „Echoel Live" | keins — kein Geld fließt |
| **v1.1 (Abo „Echoel Live")** | Gratis-Jahr per Apple-Angebotscode für Tester und Mitwirkende; beauftragte Presets, Looks, Genres mit Vertrag und Euro-Honorar; ein offen veröffentlichter Topf aus Abo-Einnahmen, verteilt nach anonymer, auf dem Gerät gezählter Nutzung (Splice-Logik — Council + Datenschutz-Prüfung vorher); gedeckelte Fehler-Prämie in Euro für Sicherheit und Abstürze | gering — Verträge, Steuerberater |
| **Nie** | Belohnung für Bewertungen; Krypto oder Punkte für Downloads, Empfehlungen, Posts; Krypto als Freischaltung; Wallet in der App; eigener Token/NFT; Auszahlung gekoppelt an Bio-Werte; Verlosungen mit Einsatz | — |

**Vor jeder Geldzahlung:** Steuerberater (Buchung, Kleinunternehmer-Grenzen 25 000 € / 100 000 €,
Einordnung der Empfänger, Scheinselbständigkeit beim Topf) und Anwalt (Vertragsvorlagen,
Gewinnspiel-Regeln, Datenschutzerklärung für Feedback-Werkzeuge).

## 6. Was jetzt passiert

1. Fix für Risiko 2: Plugin-Wahl im Spiel lädt erst beim nächsten Stopp (keine Pause der laufenden
   Engine).
2. Fix für Risiko 4: Absturz-Meldung eines Plugins robuster zuordnen.
3. Website-Widersprüche (Editor, Sampler, Siri, MIDI 2.0, Barrierefreiheit) in einem Schritt.
4. Weiter mit H6: Effekt in den Spur-Bus einhängen und entfernen.
5. Founder: Repo-Beschreibung; die Geräte-Sitzung aus §4.

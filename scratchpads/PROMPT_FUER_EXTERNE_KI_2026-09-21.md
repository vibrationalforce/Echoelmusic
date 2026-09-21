# Prompt für eine externe KI (ChatGPT o. ä.) — Lösungsansätze für Echoel

Zweck: ein selbsttragender Prompt, den der Founder unverändert einfügen kann. Er enthält
Repo- und Website-Link, das Insider-Wissen, das eine fremde KI sonst falsch rät, und die
gemessenen Problemstellungen. Erstellt 2026-09-21.

⚠️ Beim Aktualisieren: jede Zahl hier ist eine MESSUNG mit Datum, kein Sachverhalt. Wer sie
nachführt, misst sie neu — sonst schickt der Prompt eine fremde KI auf einen alten Stand.

---

## ——— AB HIER KOPIEREN ———

Du bist ein erfahrener iOS-/Audio-Engineer und Produktstratege. Ich brauche **Lösungsansätze
mit Abwägung**, keinen fertigen Code. Denk gründlich nach, bevor du antwortest.

### Das Produkt

**Echoel** ist ein bio-reaktives Musikinstrument für iPhone. Der Körper spielt es: Herzschlag,
Herzratenvariabilität (HRV), Kohärenz und Atmung steuern in Echtzeit Klang, Bild, Licht und
immersiven Raum. Es ist ein **Instrument**, keine DAW und kein Wellness-Produkt.

- Repo: https://github.com/vibrationalforce/Echoelmusic
- Website: https://echoelmusic.com (Quelle liegt im Repo unter `docs/`, GitHub Pages)
- Status: iPhone-App auf TestFlight, v1.0 kostenlos geplant. Zusätzlich ein AUv3-Plugin
  (Instrument) im selben Projekt.

### Insider-Wissen — bitte lies das, bevor du etwas vorschlägst

Das meiste davon steht nicht im README, und fast jede KI rät es falsch.

**Harte technische Regeln, nicht verhandelbar:**
- **Swift 100 %, NULL externe Abhängigkeiten.** `Package.swift` hat ein leeres
  `dependencies`-Array. Kein JUCE, kein CMake, kein C++, keine SPM-Pakete.
- iOS 18 Minimum, **Swift 6 strict concurrency**, SwiftUI + `@Observable`.
- Erlaubte Frameworks: SwiftUI, AVFoundation, **Accelerate/vDSP**, Metal, CoreMIDI, Network,
  HealthKit, CoreBluetooth. Build über XcodeGen + Fastlane + GitHub Actions.
- **Audio-Thread-Verbote (absolut):** keine Locks, kein malloc/Array-Allokation, kein
  ObjC-Messaging, kein File-I/O, kein GCD/async, kein `print`/`os_log` im Render-Block.
  Erlaubt: vorab allozierte Float-Arrays, `vDSP_*`, `memcpy`, Arithmetik, C-Mathe,
  Lock-free-Ringpuffer.
- Nur iPhone (`TARGETED_DEVICE_FAMILY = "1"`). iPad ist bewusst aus: kein iPad hat eine
  rückseitige LED, und die Haupt-Biosignalquelle (Kamera-rPPG) braucht den Blitz als Licht.

**Was bewusst ENTFERNT wurde — bitte nicht zurückvorschlagen:**
Mikrofon-/Audio-Eingang, Video-Aufnahme und -Schnitt, Autotune, Harmonizer,
Granularsynthese, Noten-Editor/Piano-Roll, Drums/Beat-Maker, Timeline/Arrangement/Clips,
Mehrspur-Aufnahme, AUv3-**Hosting** fremder Plugins, RTMP/Streaming. Das waren
Founder-Entscheidungen, keine Lücken. Die Produktgrenze lautet: **geht es um den Klang, der
JETZT entsteht (behalten) oder um das Anordnen von Material ÜBER ZEIT (gestrichen)?**

**Biosignal-Quellen, die es wirklich gibt:** Kamera-rPPG (Finger auf Linse + Blitz,
Flaggschiff), Apple HealthKit, universeller BLE-Herzgurt (0x180D), Demo-Generator.
**Es gibt kein** Gesichts-/Mimik-Tracking, keine Bewegungserkennung, kein EEG.

**Ausgänge, die real sind:** OSC (`/echoelmusic/bio/*`), ADM-OSC (immersive Objekte),
Art-Net und sACN (Licht/DMX), MIDI-Ausgang inkl. MPE-out und MIDI-2.0-Quelle,
MIDI-Dateiexport. MPE-**Eingang** gibt es nicht (kein Zonen-Parsing).

**Marke — harte Grenze:** Biofeedback ist hier **wissenschaftliche Modulationsquelle**, nicht
Wellness. Niemals „Heilfrequenzen", Chakren, Solfeggio, Meditation-App, Therapie. Kein
Overclaim: es darf nur behauptet werden, was auch ausgeliefert wird (eine falsche Behauptung
im App Store ist eine 2.3-Ablehnung).

**Zum AUv3-Plugin (wichtig für Problem 1–4):** Target `EchoelmusicAUv3`, Typ `aumu`/`echl`,
reines Swift, in die App eingebettet. Es kompiliert **absichtlich nur** das Verzeichnis
`Sources/Echoelmusic/DSP/` plus drei Foundation-only Dateien aus `Core/` — diese Isolation ist
der Grund, warum es abhängigkeitsfrei ist, und sie soll bleiben. Es lädt gerätegeprüft in AUM
(Sept. 2026). Logic/GarageBand sind ungetestet.

---

### Die Probleme — bitte für jedes einen Lösungsweg

#### 1. Das AUv3 folgt der Sample-Rate des Hosts nicht

`EchoelmusicAudioUnit` baut seine Engines als `let` mit fest verdrahteten 48 kHz:
`EchoelDDSP(sampleRate: 48000)` und `EchoelCellular(cellCount: 128, sampleRate: 48000)`.
`EchoelDDSP.sampleRate` ist ein `public let` — nach `init` nicht mehr änderbar.
`outputBus.format` wird nirgends beobachtet.

Folge in einem 44,1-kHz-Host (GarageBand iOS ist genau das): alles klingt **~8,1 % zu tief**
(≈ 1,47 Halbtöne), LFOs und Hüllkurven laufen ~8,8 % zu langsam. In AUM auf 48 kHz stimmt die
Tonhöhe exakt (gemessen: 220,15 Hz gegen 220 Hz Default) — die Raten sind dort gleich, deshalb
ist der Defekt dort unsichtbar.

Gerade repariert: die Sub-Engines **innerhalb** von `EchoelDDSP` (Filter, LFO, Entrainment)
lesen jetzt `self.sampleRate` statt eines Literals. Offen ist die Extension selbst.

**Frage:** Was ist der sauberste Weg, die Engines aus dem Host-Format neu zu bauen? Konkret:
Wo genau im AUv3-Lebenszyklus (`allocateRenderResources()`? `shouldChangeToFormat`?), wie
verhindert man einen Neubau auf dem Render-Thread, was passiert bei einem Format-Wechsel
mitten im Spiel, und wie testet man das ohne zweiten Host? Alternativen wie „intern auf 48 kHz
rechnen und am Ausgang resamplen" bitte mit abwägen — Latenz, Qualität, Audio-Thread-Verbote.

#### 2. Das AUv3 kostet ~20 Prozentpunkte CPU für EINE Instanz

AUMs Anzeige liest 1 % ohne Plugin und 19–24 % mit genau einer Instanz, **ohne gespielte
Note**. Budget des Projekts: CPU < 30 %, FAIL > 50 %. Vier Instanzen wären das Gerät.

Die Ursache ist strukturell und liegt in `EchoelCellular.render(buffer:frameCount:)`. **Pro
Ausgabe-Sample** läuft:

```swift
// Smoothing über ALLE Zellen — pro Sample, cellCount = 128
let smoothFactor = 1.0 - smoothing * 0.99
for i in 0..<cellCount {
    smoothedWavetable[i] += (wavetable[i] - smoothedWavetable[i]) * smoothFactor
}
```

und im additiven Modus zusätzlich:

```swift
for i in 0..<count {                       // count = min(partialCount, cellCount)
    let partialFreq = frequency * Float(i + 1)
    if partialFreq > sampleRate * 0.5 { break }
    phases[i] += partialFreq / sampleRate * 2.0 * .pi
    if phases[i] > 2.0 * .pi { phases[i] -= 2.0 * .pi }
    let amplitude = smoothedWavetable[i] > 0 ? 1.0 / Float(i + 1) : 0
    sample += sin(phases[i]) * amplitude * invCount   // skalares sin() pro Partial
}
```

Bei 48 kHz sind das grob 6 Mio. Float-Ops und über 1 Mio. skalare `sin()` pro Sekunde,
komplett un-vektorisiert — neben einem `EchoelDDSP`-Pfad, der bereits vDSP-gebatcht ist.

**Frage:** Wie bringt man das in Budget, ohne den Klangcharakter zu verlieren? Ich erwarte
eine Abwägung zwischen mindestens: (a) die Glättungsschleife aus dem Pro-Sample-Pfad heben
(sie ändert sich nur bei jedem Evolution-Schritt), (b) das Ganze auf Blockverarbeitung mit
`vDSP_vsub`/`vDSP_vsma`/`vDSP_vma` umstellen, (c) die Partials über `vvsinf` batchen statt
skalar, (d) Wavetable- statt Echtzeit-Sinus-Summation. Wo liegt das beste
Aufwand-Wirkung-Verhältnis, und was davon ändert hörbar den Klang? Bitte auch sagen, wie ich
das **messe** statt schätze (Xcode-Instruments-Weg für ein AUv3 in einem Fremd-Host).

#### 3. Das Plugin klingt, sobald es geladen ist

`allocateRenderResources()` ruft `synth.noteOn(...)`, das Master-Meter springt beim
Instanziieren auf −10 dBFS — ohne Note, ohne Transport. In der App ist das richtig (ein
Drone-Instrument, das atmet). In einem fremden Host: Spur anlegen → sofort Ton, und manche
Hosts rufen `allocateRenderResources` schon beim Scannen.

**Frage:** Was ist hier Konvention und was ist Fehler? Wie lösen andere Drone-/Generative-
Instrumente das? Vorschlag für einen Schalter, der beide Nutzergruppen bedient, ohne dass das
Plugin beim Host-Scan Krach macht.

#### 4. Das Plugin soll auch MIDI ausgeben können

Der Körper soll MIDI in den Host schicken und **jedes** Instrument dort steuern, nicht nur
unseres. Heute ist es ein `aumu` (Instrument) und taucht deshalb in AUMs Liste
„MIDI PROCESSORS" nicht auf. `AudioUnitViewController` erfüllt bereits `AUAudioUnitFactory`,
MIDI-Ausgang (`MIDIOutput`, UMP-Encoder) ist gebaut.

**Frage:** Ist eine ZWEITE AudioComponent (`aumi`) aus **derselben** Extension der richtige
Weg — verzweigt in `createAudioUnit(with:)` am `componentDescription`? Welche Fallstricke gibt
es (Info.plist, Registrierung, Host-Kompatibilität, `MIDIOutputNames`/
`scheduleMIDIEventBlock`)? Oder ist ein eigenes Target sauberer, obwohl das mehr Wartung ist?

#### 5. Musikalität: „kein Moment soll wie der andere klingen"

Die Generierung ist vollständig deterministisch und seed-getrieben (SplitMix64). Zwei Seeds:
ein Struktur-Seed (Körper-Snapshot, trägt Skelett/Register/Dichte) und ein Evolving-Seed
(melodische Detailschicht). Alle 25–45 s wird neu geseedet. Ein 8-Takt-Loop besteht aus acht
verschieden komponierten Takten. Es gibt einen globalen Regler „Bar variation" (0…1), der fünf
Performance-Achsen eines Genre-Presets streut, während drei Identitäts-Achsen festbleiben —
die Idee ist: **das Genre-Preset ist eine MITTE mit Streuung, keine Schablone.** Dazu atmet
pro Rhythmus-Charakter die Notenlänge und die Figur rotiert pro Takt.

Ziel des Founders, wörtlich: *„einen Status erreichen, wo kein Moment wie der andere klingt.
Auch die Genre-Presets sollen einen Vibe haben aber nicht gleich klingen. Immer random und
variationsreich. Wie stark die Variation ist kann man dann einstellen."* Und: die Genres
sollen **organisch und professionell** klingen, die Parameter „intelligent", damit es immer
musikalisch sinnvoll bleibt.

**Frage:** Welche Variations-Mechanismen fehlen einem generativen System noch, wenn Seed,
Re-Seed-Kadenz, Per-Takt-Komposition, Mood-Streuung und Rhythmus-Rotation schon da sind? Ich
suche die Achse mit dem größten hörbaren Gewinn pro Aufwand — und ausdrücklich auch das
Gegenargument: ab wann kippt „variationsreich" in „beliebig" und zerstört die Genre-Identität?
Gerne mit Verweis auf bewährte Verfahren (Markov-/Grammatik-Ansätze, Ornamentierungs-Regeln,
Phrasen-Bögen, Tension-Kurven, Call-and-Response).

#### 6. Die Biosignal-Quelle hängt am Blitz

`CameraCapture` koppelt die rPPG-Beleuchtung an `device.hasTorch`. Zwei unbehandelte Fälle:
Geräte ohne Blitz, und thermisches Absenken des Blitzes bei längeren Sessions — beides führt
dazu, dass der Puls nicht mehr einrastet, ohne dass der Nutzer erfährt, warum.

**Frage:** Ansätze für rPPG-Robustheit auf iPhone — Signalaufbereitung bei schwankender
Beleuchtung, Erkennung des Degradations-Zustands, ehrliche Nutzerführung statt stiller
Fehlmessung. Und: gibt es einen belastbaren Weg ohne Blitz (Umgebungslicht, Gesicht statt
Finger), oder ist das physikalisch nicht drin?

#### 7. Die Website (https://echoelmusic.com)

Statische GitHub-Pages-Seite, Quelle unter `docs/`. Seiten u. a.: `index`, `overview`,
`artist`, `architecture`, `integrations`, `faq`, `health`, `claims`, `accessibility`,
`privacy`, `security`, `press`, plus Integrations-Seiten für Resolume-OSC, Reaper-OSC und
Art-Net/sACN.

Das Positionierungsproblem: Echoel ist **weder eine DAW noch eine Wellness-App**. Beide
Schubladen sind falsch, und Besucher sortieren es reflexhaft in eine davon. Die Zielgruppen
sind Installations-Künstler, Event-/Theater-/Kino-Techniker, Performer und Producer, die
Biofeedback als Steuerquelle wollen — plus Menschen, die über den Körper ins eigene kreative
Potential kommen wollen, **ohne** Esoterik-Framing.

**Frage:** Wie positioniert und strukturiert man eine solche Seite? Konkret: Was gehört „above
the fold"? Wie erklärt man in einem Satz, was das Ding ist, ohne DAW- oder Wellness-Assoziation
auszulösen? Welche Seite fehlt, welche ist überflüssig? Wie bringt man die offenen Standards
(OSC, ADM-OSC, Art-Net, sACN, MIDI) als Kaufargument nach vorn, ohne dass es nach Datenblatt
aussieht? Und: SEO/Auffindbarkeit für eine Kategorie, die noch keinen etablierten Suchbegriff
hat.

---

### Was ich von dir will

Für **jedes** Problem:
1. **Zwei bis drei Lösungswege**, nach Aufwand-Wirkung sortiert — nicht nur der beste.
2. **Warum** dieser Weg, und **was er kostet** (Risiko, Wartung, was kaputtgehen kann).
3. **Was ich messen muss**, um zu wissen, ob es geholfen hat — keine Behauptungen, die ich
   nicht prüfen kann.
4. Wo du dir **unsicher** bist: sag es, statt zu raten. Eine ehrliche Lücke ist mir mehr wert
   als eine plausible Erfindung.

Wenn du das Repo oder die Website ansehen kannst, tu es — aber prüfe jede Annahme gegen die
Regeln oben, denn das Repo trägt auch viel dokumentierte Historie über Dinge, die es nicht
mehr gibt.

### Was du NICHT vorschlagen sollst

- Eine Abhängigkeit hinzufügen (JUCE, AudioKit, TensorFlow, irgendein SPM-Paket).
- C++ oder CMake.
- Eine Timeline-/Arrangement-/Clip-Oberfläche, Mehrspur-Aufnahme, Mikrofon-Eingang, Video,
  Autotune, Harmonizer, Piano-Roll — alles bewusst gestrichen.
- Wellness-, Meditations-, Heilungs- oder Esoterik-Framing in irgendeiner nutzersichtbaren
  Formulierung.
- Irgendetwas, das im Audio-Render-Block alloziert, sperrt oder Objective-C anfasst.

## ——— BIS HIER KOPIEREN ———

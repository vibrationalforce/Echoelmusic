# PLAN — Echoel Multicam (YoloBox-Ersatz), 2026-10-15

Founder 2026-10-15: „Im Prinzip soll die Technologie von YOLObox auch ersetzt werden. Also mehrere
Kameras captured und syncen plus Audio aber auf professionellste Art und Weise direkt in die
Echoelmusic Software bzw als Stream, Colabo und Content Schmiede."

## Was YoloBox Ultra kann (Händlerangaben, nicht Herstellerdoku)
4× HDMI + USB-C/USB-A Eingänge · NDI + SRT ein/aus · RTMP/RTMPS · ISO-Aufnahme jedes Eingangs +
Programm · Multistream (3× quer, 2× hoch) · Line/Mic-In · Grafiken/Overlays.

## Was das iPhone kann und was nicht (gemessen per Recherche, nicht am Gerät)
- **USB/HDMI-Kameras (UVC): nur iPad** mit USB-C. Auf dem iPhone findet `AVCaptureDevice`
  keine externen Kameras (Apple-Forum-Antworten, Doku nennt „On iPad"). → HDMI-Eingänge = iPad-Ziel.
- **Front + Rück gleichzeitig:** `AVCaptureMultiCamSession` (XS/XR und neuer). Keine Abhängigkeit.
- **Weitere iPhones als Kameras:** nur übers Netz — eigenes Echoel-zu-Echoel (Multipeer/Network,
  keine Abhängigkeit), SRT (Blackmagic Camera ≥ 3.2 sendet SRT/RTMP; Empfang braucht libsrt, C,
  MPL-2.0), NDI (NDI-SDK; iOS-Lizenz bei NDI zu klären).
- **Audio-Interfaces** (BiG SiX, Xone:96) über USB-C: class-compliant am iPhone möglich; hängt am
  Mikrofon-/Eingangs-Landing E10-1 (Info.plist, founder-gated).
- **Stream raus:** RTMP/SRT braucht eine Bibliothek (HaishinKit, geplant, nicht verlinkt).

## Was Entfalt beiträgt (vibrationalforce/entfalt, Zweig claude/entfalt-bootstrap-rlkkrk)
Kein iPhone-Code (Bash/ffmpeg, Remotion, Marketing-Skills) — aber erprobte SPEZIFIKATIONEN, die
als Export-/Content-Logik ins Produkt portiert werden (Recovery-Prinzip: Kern portieren, nichts
hineinkopieren):
- `pipeline/scripts/studio.sh`: Zeitversatz zweier Aufnahmen (`--versatz`), Zoom-Ausschnitte im
  Zielverhältnis, Bild-im-Bild-Ecken, hoch 1080×1920 / quer 1920×1080 — das ist das Multicam-
  Schnitt-Rezept, heute von Hand.
- `pipeline/scripts/loudnorm.sh`: −14 LUFS / TP −1 Ziel je Plattform.
- `formats/PLATFORM_SPECS.md`, `stream/STREAM_FORMATS.md` (F1–F4), `stream/CLIP_ERNTE.md`:
  Formate, Clip-Ernte nach dem Stream.
- `stream/OBS_SETUP.md`: Audio-Routing Xone:96 → BiG SiX (eine Clock), Szenen-Gerüst.

## Reihenfolge (eine Scheibe je Zyklus, jede mit Wächter)
- **M1 — Zwei Linsen, eine Aufnahme:** Front + Rück gleichzeitig (`AVCaptureMultiCamSession`),
  zwei Takes auf zwei Video-Spuren. Keine Abhängigkeit.
- **M2 — Winkel-Schnitt:** heute zeigt die Spur-Ebene nur die ERSTE Bildspur. Eine Programm-Spur
  wählt je Takt/Teil den Winkel (Multicam-Schnitt wie im NLE).
- **M3 — Auto-Sync per Ton:** mehrere Aufnahmen (z. B. drei iPhones mit Blackmagic Camera)
  importieren, per Audio-Kreuzkorrelation ausrichten — ersetzt `studio.sh --versatz`. Braucht den
  Ton der Datei (heute legt Import Video nur das Bild ab).
- **M4 — Echoel-Kamera-Link:** zweites iPhone mit Echoel im Kamera-Modus sendet Bild + Song-Uhr
  an das Haupt-iPhone (Multipeer/Network, HEVC über VideoToolbox). Keine Abhängigkeit.
- **M5 — Stream raus:** RTMP/SRT, Multistream hoch + quer. **Braucht HaishinKit — Founder-OK.**
- **M6 — Fremd-Eingänge:** SRT (Blackmagic Camera) und NDI. **Braucht libsrt / NDI-SDK —
  Founder-OK + NDI-Lizenzklärung.**
- **iPad-Ziel:** HDMI/USB-Kameras über UVC — erst wenn iPad als Target zurückkommt.

## Update 2026-10-15 (abends) — nach M1 (`e27de94d9`) und der Grok-Heavy-Recherche

Grok-Rücklauf gemessen (Lernmodus, `[verified 8/12]`): bestätigt sind hardwareCost-Grenze,
`synchronizationClock`, `AVCaptureDataOutputSynchronizer` (liefert nur gepaart, synchronisiert
nichts), Continuity Camera nur iPhone→Mac/TV, Drift-Rechnung (20 ppm × 3600 s = 72 ms) und —
**neu und wichtig** — MultipeerConnectivity ist ab der Xcode-27-Beta abgekündigt (Apple DTS im
Entwicklerforum; die von Grok genannte Technote-Nummer TN3213 ließ sich nicht finden).
**Nicht übernommen:** „Front und Rück sind auf Sensorebene synchron“ — Apple belegt das nur für
die Teil-Kameras EINES virtuellen Geräts; Front + Rück sind zwei unabhängige Geräte.
„NDI im App Store SICHER erlaubt“ — die NDI-Lizenzseite nennt nur Android-Stores; für iOS gilt
weiter: sdk@ndi.video fragen. „HaishinKit 2.2.5 März 2026“ — gefunden nur 2.0.9 (Juli 2025);
offen.

### Neue Reihenfolge
1. **M2 — Winkel sichtbar machen** (zuerst, weil die Front-Aufnahme aus M1 heute auf Spur 1 liegt
   und NICHT gezeigt wird): eine Programm-Auswahl je Teil/Takt, welche Video-Spur das Bild stellt.
   Der Spieler bleibt EIN Besitzer (`VideoLanePlayer`), er wählt nur die Quelle. Keine Abhängigkeit.
2. **M1b — bildgenauer Start:** statt zwei `AVCaptureMovieFileOutput` je Linse ein
   `AVCaptureVideoDataOutput` + `AVAssetWriter`; beide Writer starten an DERSELBEN Zeit der
   `session.synchronizationClock` (`startSession(atSourceTime:)`), frühere Bilder werden
   verworfen. Ergebnis: Versatz höchstens ein Bild, statt „einige ms + Startzufall“.
   ⚠️ `TheShareReadyClipIsNotSoldAnywhereTests` verbietet heute `AVAssetWriterInput(mediaType: .video`
   in `Sources/` — der Wächter wird im SELBEN Commit bewusst umgestellt (erlaubt nur in
   `Video/VideoTakeCamera.swift`), nie still umgangen.
3. **M3 — Ton-Abgleich (GCC-PHAT)**, Funktionsliste unten. ⚠️ Eigene Echoel-Aufnahmen sind heute
   NUR Bild — M3 wirkt zuerst auf importierte Dateien mit Ton (Blackmagic Camera, andere Apps).
   Eigene Takes mit Ton brauchen den Mikrofon-Pfad (E10-1, Info.plist — Founder).
4. **M4 — zweites iPhone als Kamera über Network.framework + VideoToolbox (HEVC, Low-Latency)**,
   eigene NTP-artige Uhr (Ping-Paare, beste Hälfte, `mach_continuous_time`). **Nicht** Multipeer.
   **Daraus folgt K1:** die laufende Kollaboration (`Sync/MultipeerSession.swift`, 538 Zeilen,
   beim Start konstruiert) steht auf dem abgekündigten Framework → Umzug auf denselben
   Network.framework-Transport wie M4. Ein Transport, zwei Nutzer (#416).
5. **M5 — Stream raus** (HaishinKit, BSD-3; SRT als eigenes Modul `SRTHaishinKit`, nur SPM) —
   Founder-OK für die Abhängigkeit.
6. **M6 — fremde Kameras** (SRT-Empfang von Blackmagic Camera; NDI erst nach Antwort von
   sdk@ndi.video) — Founder-OK.

### M3 — Funktionsliste (jede rein und mit Wächter aus Python-Sollwerten)
- `AudioSyncReader` — liest aus einer Datei ein Mono-Fenster, auf 8 kHz heruntergerechnet
  (`AVAssetReader`, Ton-Spur der Datei; keine Ton-Spur → klare Absage).
- `GCCPHAT.offset(_ a:, _ b:, maxLagSamples:) -> (lag, confidence)` — vDSP-FFT, siehe unten.
- `GCCPHAT.parabolicPeak` — Feinposition zwischen zwei Abtastwerten.
- `SyncConfidence` — Verhältnis Hauptspitze zu zweithöchster Spitze; unter der Schwelle wird
  NICHT verschoben, die Oberfläche sagt „kein sicherer Treffer".
- `ClockDrift.estimate` — Versatz am Anfang und am Ende messen → ppm; über der Schwelle
  ein Hinweis (Resampling ist ein eigener späterer Schritt).
- `AngleAlignPlan` — rechnet aus den Versätzen die neuen Startpositionen der Teile; geschrieben
  wird über `TimelineStore` als EIN Undo-Schritt.
- Tür: „Align by Sound" in der Teil-Leiste, wenn zwei oder mehr Video-/Audio-Teile gewählt sind.

### GCC-PHAT in fünf Sätzen
Beide Aufnahmen werden in Frequenzen zerlegt (FFT). Das eine Spektrum wird mit dem gespiegelten
(konjugierten) anderen multipliziert — das ergibt das Kreuzspektrum. Dieses wird durch seinen
eigenen Betrag geteilt, sodass nur die PHASE übrig bleibt: jede Frequenz zählt gleich, ein lauter
Bass oder Hall dominiert nicht mehr. Die Rück-Transformation (inverse FFT) ergibt eine Kurve mit
einer scharfen Spitze genau beim Zeitversatz. Wie deutlich diese Spitze über der zweithöchsten
steht, ist das Vertrauensmaß.

## Update 2026-10-15 (nachts) — Grok Heavy Runde 2, gemessen

- **M1b nimmt `AVAssetWriter`, nicht `AVCaptureMovieFileOutput`.** Nur der Writer legt den Start
  fest: `startSession(atSourceTime:)` bildet eine Quellzeit auf Filmzeit 0 ab. Alle
  Ausgabe-Puffer einer Multicam-Session tragen Zeiten der `synchronizationClock`. Ein
  gemeinsamer Startpunkt auf dieser Uhr gibt also beiden Linsen dieselbe Null, und die
  Song-Stelle folgt aus derselben Uhr über `AVAudioTime.hostTime`.
  ⚠️ Front und Rück laufen dabei NICHT im Gleichschritt: Gleichschritt gilt nur für die
  Teile eines virtuellen Geräts (WWDC19-249). Der Rest-Versatz ist höchstens ein Bild und
  wird gemessen, nicht angenommen. Apple nennt dazu keine Zahlen.
- **K1 braucht KEINE Änderung an der Info.plist und kein Multicast-Entitlement.**
  `NSLocalNetworkUsageDescription` und `NSBonjourServices` mit `_echoel-colab._tcp` stehen
  schon in `Resources/iOS/Info.plist`. Das Entitlement ist nur bei frei gewählten
  Bonjour-Typen oder echtem Multicast Pflicht (TN3179). Weg: `NWListener`/`NWBrowser` +
  Bonjour, `includePeerToPeer`, TLS. Apples Anleitung ist **TN3213** (Seite vorhanden, Titel
  bestätigt; der Text war von hier nicht lesbar).
  ⚠️ „Ganzes Framework in Xcode 27 abgekündigt" ist weiter UNVERIFIZIERT: ein DTS-Beitrag
  sagt, Multipeer sei offiziell NICHT abgekündigt (TN3151). Der Umzug lohnt sich trotzdem —
  Gegendruck/Flusskontrolle fehlt, NSStream läuft aus.
- **Uhren-Abgleich zwischen zwei iPhones (M4):** Für einen einfachen Ping-Abgleich gibt es
  KEINE belegte Genauigkeit. Er wird bei M4 am Gerät gemessen, bevor eine Zahl im Plan steht.

## M1b — Verträge vor dem Bau (Astra-Gegenprüfung B6/B7, 2026-10-15)

⛔ „Rest-Versatz höchstens ein Bild" stand hier oben und ist UNBELEGT — gestrichen als Zusage;
gemessen wird am Gerät. Ein gemeinsamer Writer-Start ist ein gemeinsamer DATEI-Ursprung, kein
gleichzeitiges erstes Bild.

Zuerst rein und mit Sollwerten (Wächter vor dem Writer-Umbau):
1. **Song-Anker** (reine Funktion): Take-ID + Host-Zeit + Song-Tick + Tempo-Abschnitt beim Start.
   480 PPQ, 120 BPM, Anker 100,000 s ↔ 3.840 Ticks, Quellzeit 100,050 s → **3.888 Ticks**,
   unabhängig vom Stop-Zeitpunkt. 200 ms Startverzögerung bei 120 BPM = **192 Ticks**, sichtbar,
   nie still auf Medienzeit 0 gezogen. Zwei Tempo-Abschnitte (0,5 s @120 + 0,5 s @60) = **720**.
2. **Uhr-Domänen**: nur konvertierte Zeiten vergleichen (`CMSyncConvertTime`); ungültige
   Korrelation → „nicht bestimmbar", nie Tick 0.
3. **Gestoppter Song**: Platzierungsregel (Cue-Takt), weil keine musikalische Zeit läuft.
4. **Erste Samples je Linse** festhalten; Anfangslücke einer Linse = Spur dort transparent
   (M2 zeigt dann die untere) — nicht dunkel.
5. **Rückstau/Verlust** gehört ins Take-Ergebnis; keine unbegrenzten Puffer.
6. Rotation am Writer-Input (Transform), nicht über den Movie-File-Weg.
Der Wächter `TheShareReadyClipIsNotSoldAnywhereTests` (Anspruch 4) wird im SELBEN Commit wie der
Writer bewusst umgestellt.

## Ehrlichkeit
Nichts davon ist am Gerät bestätigt. Nach außen (Store, Website, CLAIMS) wird nichts davon
behauptet, bevor es läuft.

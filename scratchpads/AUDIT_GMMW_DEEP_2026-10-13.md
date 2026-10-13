# GMMW Deep Audit — Synthese (2026-10-13)

**Auftrag (Founder):** „Deep Audit. Alles verstehen und Richtung GMMW korrigieren. Wurde was Falsches
gelöscht? Gibt es Dinge, die noch nicht richtig verbunden sind?"
**Werkzeug:** Workflow `wf_b009e54f-195` — drei Teams (Deletions · Wiring · GMMW-Drift), je drei
Arbeiter + ein Lead, der adversarial nachmisst; 13 Agenten, 371 Werkzeugaufrufe, 80 min.
Jede Zahl unten ist vom Lead auf HEAD nachgemessen (kommentarbereinigt, nach Typ, nicht nach Dateiname).
Dazu drei fremde Berichte desselben Tages im Lernmodus (Grok, ChatGPT, unbekannt — `inspiration.csv`).

## 1 · Wurde etwas Falsches gelöscht? — NEIN

- In diesem Klon ist **keine** Datei aus `Sources/` oder `Tests/` verschwunden (`git log --diff-filter=D` → leer, 326 Commits).
- Jede als gelöscht geführte Fläche ist wirklich weg (Mikrofon, Video-Aufnahme, Harmonizer, Drums,
  Pianoroll-Ansicht, Face), und **keine** hinterließ hängende Verweise.
- Der Puls-Pfad (`CameraCapture` · `CameraAnalyzer` · `RPPGConditioning` · `PulsePeriodEstimator`), die
  Rausch-Triade, `PianoRollModel`, alle drei Bio-Quellen, `WeatherProvider`, die Clip-Modelle: da.
- Einzige Löschung mit Nebenwirkung: `c84ae1fb1` (Security R5) nahm mit der Drive-ID auch die kuratierte
  Sample-Karte (`SAMPLES_MAP.tsv`, 181 Zeilen, ohne Geheimnis) — am selben Tag kam der Sampler je Spur
  zurück (GA-4). Die Karte ist aus der Git-Historie holbar; kein Code hing daran.

**Das eigentliche Problem sind die Papiere, nicht der Code** — und sie hinken in EINE Richtung: der Code
ist weiter als die Pläne und Texte sagen. Dokumente, aus denen eine Sitzung plant, erklärten Lebendes
für tot (Aufnahme-Knopf, WeatherProvider, Grain, Kopfhörer-Raum) und Totes für vorhanden
(HaishinKit, Multitrack-Recorder, Video-Capture, vier WA4-Flächen).

## 2 · Was ist noch nicht richtig verbunden?

| Befund | Messung | Klasse |
|---|---|---|
| Rausch-Triade: nur `BioEventGraph` ist verdrahtet | `BioSignalDeconvolver`, `HilbertSensorMapper`: 0 Aufrufer | Register (erledigt in CLAUDE.md) |
| `SessionEngine` hängt beim Start im Master-Graph, keine Ansicht zeigt ihn | `EchoelmusicApp.swift:975 attach(to:)` | Founder-Frage (GM18) |
| Song-Form wird gespeichert, nie zurückgelesen | `restoreSong` schreibt keine `ArrangementStore`; 0 Schreiber | WA2 Scenes — Kommentar-Scheibe |
| Kohärenz fehlt auf der Apple-Health-Quelle | `HealthKitBioPublisher.swift:168 coherence: 0` | Feature (Watch-Plan), Doku erledigt |
| `bioEvents` hat ohne `osc.out`-Route keinen Abnehmer; Überläufe zählt niemand | `EchoelmusicApp.swift:683` | SH-10-Zeile (klein) |
| Erster Take ins LEERE Stück unmöglich | `RecordTake.state → .songCannotPlay`, `play:684` | **Scheibe R2 (#77)** |
| J0 Stems: `StemCaptureSession(` 0 Produktionsaufrufer | S-A3c-2b (#4/#5) | geplant |
| J1 „hörbares Duo": nur Bio-Frames + Link-Proben, kein PCM | `MultipeerSession` | Roadmap, nicht behaupten |
| `EchoelFDNReverb`: fertig, flag-gated auf ein Flag ohne Leser, kein Register | 0 Aufrufer | Register + B11 oder E21 |
| 13 Archiv-Bausteine Scope YES ohne Plan-Slice | Karplus · Ladder · Cellular (App) · FDN · Ringmod · Freeze · Multiband · Fixture-Profile · Keystone · SharePlay · CloudSync · Euclid · Audio→MIDI | PLAN_GMMW A5 nachtragen |
| Spatial-Render-Hälfte: Register sagt 7, Wächter pinnt 5; 2 transitive Waisen | `EchoelRenderLayout`, `AutomationGestureRecorder` | Wächter-Erweiterung (mit nächstem Sources-Push) |
| `EchoelEntrainment` („Deep Sleep / Meditation / Peak Focus") stumm, türlos im Render-Pfad | Tiefe 0, Tür nur in türloser `BioSourceView` | Founder-Frage (GM19) |
| Hot-State-Wächter kennt drei ≥10-Hz-Schreiber nicht | Transport-Position, Tempo-Glide, OSC-Eingang (alle Leser in Blättern) | Wächter-Erweiterung |
| Fünf Speicher-Wurzeln fehlen im Wurzel-Register, zwei ohne Entscheidung | `PerformerSignature`, `bioVitals.v1` | Founder-Frage (GM20) |

## 3 · Drift Richtung GMMW (nach außen)

App-Store-Text, Startseite, FAQ und `CLAIMS.md` verkaufen weiter das reine Instrument: die Workstation,
auf der die App startet, der Mixer und der Sampler je Spur fehlen oder werden verneint; mehrere Seiten
erklären die 2026er Streichungen (Video, Streaming, Hosting) zur Produktgrenze — gegen das
Produktgesetz vom 24.09. → EIN Commit CLAIMS + faq + claims.html (Wächter koppelt sie), Store-Text ist
Founder-Sache (GM21).

## 4 · Heute gelandet (alle Doku, kein Gate-Lauf, main folgt per Passagier)

README-Root · CLAUDE.md ×3 (WeatherProvider, Multitrack/MPE/Video, CL-1) · CL-2 decisions.csv ·
Spatial-Audit-Banner · B2-Wahrheit (3 Stellen) · CL-3 Archiv (D11 · B5 · J4 · H2) · CL-6 Masterplan ·
CLAUDE.md Wiring-Wahrheit (Triade · SessionEngine · FÜNF · HealthKit · bioEvents; H1-Lehre → Ledger §AM) ·
A2b-Zeilen (16 Slices) · drei Lern-Logs.

## 5 · Reihenfolge ab hier

1. CLAIMS + faq + claims.html (ein Commit) · PLAN_GMMW A5 (13 Bausteine) · PLAN_RESTRUCTURE §7.5 (fünf Kerne raus aus der Löschliste) · FEATURE_STATUS §0/§2c.
2. **R2 (#77)** erster Take ins leere Stück — nimmt die Kommentar-Korrekturen mit (`BroadcastEngine.swift:6`, `WaterCaustics` Kopf, `SessionView` Kopf, `restoreSong`) und die zwei Wächter-Erweiterungen (Spatial-Keep, Hot-State).
3. #78 Notenfarbe · F1 Fluid.

## 6 · Founder-Fragen (einmal, in `docs/dev/FOUNDER_INBOX.md`)

GM18 SessionEngine-Attach · GM19 Entrainment-Wortwahl · GM20 zwei Bio-Wurzeln · GM21 Store-Absatz ARRANGE ·
GM22 trägt das Stück sein Bild (visueller Look)? · offen bleiben GM1, GM5, GM8.

## 7 · Lehren

- Ein Register altert in EINE Richtung, wenn Scheiben schneller landen als Zeilen — „der Code ist weiter als
  das Papier" ist der häufigere Fehler als die Über-Behauptung.
- Ein fremdes Modell ohne Baum findet Datei-Abwesenheiten, die `git ls-files` widerlegt; seine
  Text-gegen-Text-Vergleiche (README↔Code, LICENSE↔Package.swift) trafen alle.
- Das Artefakt gehört in den Auftrag: die eine Behauptung auf dem xcresult (22 rote Tests) ist die, die
  die Sitzung selbst nicht ziehen kann (Blob-Host 403).

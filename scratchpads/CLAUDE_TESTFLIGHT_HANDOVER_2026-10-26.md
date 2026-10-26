# Claude-Handover — professionelle Umsetzung der Vision bis zum nächsten TestFlight

Stand: 26.10.2026, Europe/Madrid. Dies ist ein konkreter Integrationsauftrag aus dem Founder-Wunsch, Grok einzusetzen und parallel selbst weiterzuarbeiten. Er ersetzt kein Produktgesetz und behauptet keinen neuen TestFlight-Upload.

## 1. Direkt beginnen

Lies aktuellen `main`, den Vorbereitungsbranch und alle betroffenen PR-Diffs. Die gemessene Basis ist `3f240b3d2d784379d4b645d0a83438b6da77f354`; der veröffentlichte G4-Fix ist `21a22939c0cd4f85c120bfc2d8fb89f98ebaddf3` auf `codex/studio-testflight-preparation-2026-10-26`. Übernimm ihn erst nach Prüfung gegen deinen tatsächlichen Arbeitsstand. Kein alter HEAD wird blind vorausgesetzt.

Lies `EchoelStudio/CLAUDE.md`, `docs/dev/FOUNDER_PRODUCT_LAW.md` und den vollständigen `scratchpads/PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md`. **W0–W10 bleiben das angestrebte vollständige 1.0-Produkt.** Die ältere Reihenfolge und das frühere Verbot generierter Noten dürfen diesen jüngeren Founder-Auftrag nicht wieder einschränken. Gleichzeitig bleiben technische Baugesetze und ehrliche Claims erhalten.

Die Vorbereitung besteht aus drei Dateien:

- `scratchpads/GROK_TESTFLIGHT_AUFTRAEGE_2026-10-26.md`: vier getrennte Grok-Aufträge mit konkretem Lieferformat.
- diese Datei: Implementierungsreihenfolge, belegte Basis, reale Grenzen und Release-Prozedur.
- `scratchpads/TESTFLIGHT_ACCEPTANCE_2026-10-26.json`: Engineering-Abnahmefälle und getrennt davon tatsächlich beobachtete Prüfläufe.

Ein Gerätetest, der auf den Founder wartet, stoppt keine unabhängige reine Implementierung. Er verhindert die Abnahme und den entsprechenden stabilen Claim der betroffenen Funktion. Keine TestFlight-Version darf als vollständige Vision beschrieben werden, solange Pflichtfunktionen fehlen oder nur Platzhalter sind.

## 2. Bereits tatsächlich geleistete Arbeit

### G4a — Plugin-Zustände richtig zuordnen und Fehler unterscheiden

Commit: [`21a22939c0cd4f85c120bfc2d8fb89f98ebaddf3`](https://github.com/vibrationalforce/Echoelmusic/commit/21a22939c0cd4f85c120bfc2d8fb89f98ebaddf3).

Genau drei Dateien:

1. `EchoelStudio/Core/Sources/EchoelCore/PluginStateCapture.swift` — neuer Foundation-only-Entscheider.
2. `EchoelStudio/Core/Tests/EchoelCoreTests/PluginStateCaptureTests.swift` — elf neue Verhaltenstests.
3. `EchoelStudio/App/Engine/PluginHost.swift` — Integration, bestehende Aufrufsignaturen bleiben.

**Fehlerursache:** `CutFade.bridge(from:to:)` hält beim Instrument-/Pluginwechsel kurz den alten Track im abgespielten Projekt. `AudioEngine.publish` sendet diese Brücke, während `store.project` bereits das neue Plugin nennen kann. Der alte Capture-Pfad prüfte die Komponentenidentität nicht. Dadurch konnten die Settings der noch geladenen Unit in den Songzustand einer anderen Plugin-Referenz gelangen.

**Neues Verhalten:** Der tatsächliche `PluginComponent` muss dem vom Dokument erwarteten entsprechen, bevor der Settings-Lieferant aufgerufen wird. Eingebaute Instrumente werden nicht als fehlende Plugins behandelt. Track- und Master-Inserts bleiben erfasst. Nur `.changed(Data)` erzeugt einen Zustandsbefehl. Die anderen Ergebnisse sind `.unavailable`, `.notSerializable`, `.tooLarge(byteCount:)` und `.unchanged`; sie behalten den letzten gültigen Dokumentzustand. `captureResults` enthält den letzten Capture-Durchlauf, getrennt von Playback-Fehlern.

**Grenze:** `.changed` bedeutet erfasst, nicht auf Datenträger gespeichert. `captureResults` ist noch keine sichtbare Warnung für Musiker. Bestehende `try?`-Aufrufer und die Aktualisierung von `syncedState` vor der tatsächlichen Store-Übernahme bleiben als G4b offen. Kein AUv3-Recall auf Gerät wurde durch diese Sitzung ausgeführt.

**Ausgeführter lokaler Test:** Swift 6.4.1, SwiftPM `--build-system native`, Ubuntu/x86_64. **327 originale Core-XCTest-Methoden ausgeführt, 327 bestanden, 0 Fehler, 0 übersprungen**, einschließlich der elf neuen Tests und aller 13 vorhandenen `FormatGoldenTests`. Einzelmethodenliste und Runner-Zusammenfassung stimmen überein. Der native SwiftPM-Buildmodus ist in dieser Toolchain als veraltet markiert; das ist dokumentiert, nicht unterdrückt. Der frühere Versuch mit dem neuen Standard-Buildsystem kam vor den Tests zum Stillstand; der explizite vorhandene native Buildpfad ermöglichte den tatsächlichen Lauf.

Zur Reproduktion auf einer installierten Toolchain:

```bash
swift test --package-path EchoelStudio/Core
```

Bei derselben Linux-Toolchain gegebenenfalls den explizit belegten `--build-system native` verwenden. macOS/iOS bleiben die native Integrationsprüfung.

**CI-Bezug für diesen Codecommit:** [Echoel Studio 40373230888](https://github.com/vibrationalforce/Echoelmusic/actions/runs/40373230888), [Echoel Studio Linux 40373230754](https://github.com/vibrationalforce/Echoelmusic/actions/runs/40373230754). Vor Übernahme die abgeschlossenen Jobs und tatsächlich ausgeführten Schritte lesen. Die aktuelle Conclusion und der endgültige Handover-HEAD werden im zugehörigen PR festgehalten; ein späterer Docs-Commit ist kein automatisch mitgetesteter Release-Commit.

Die vollständigen Paket-Joblogs dieses neuen Codecommits wurden zusätzlich gelesen: macOS/Xcode 26.2/Swift 6.2.3 **327 Core + 154 DSP + 206 Engine/Kernels/Host**, Linux/Swift 6.2.4 **327 Core + 154 DSP + 181 Engine/Kernels**, jeweils ohne Fehler und ohne übersprungene XCTest-Fälle. In beiden Core-Läufen bestehen die elf neuen Capture-Tests. Das sind abgeschlossene Paketprüfungen; den Abschluss des separaten App-Jobs zusätzlich lesen. Die fehlenden Host-Tests unter Linux sind keine übersprungenen Tests, sondern Teil des dort nicht deklarierten Host-Targets.

### Vorbereitungsbasis und bisheriger Upload

Die native Studio-Basis `3f240b3d` hat [Run 40295827025](https://github.com/vibrationalforce/Echoelmusic/actions/runs/40295827025) bestanden. Der vollständige Paket-Joblog belegt **316 Core-, 154 DSP- und 206 Engine/Kernels/Host-XCTest-Ausführungen**, jeweils ohne Fehler. Toolchain: Xcode 26.2 / Apple Swift 6.2.3. Diese Zahlen gehören zur Basis, nicht zum neuen G4-Commit.

Der jüngste im gelesenen Run-Fenster belegte Studio-Upload bleibt **11.0.0 / Build 10010**, Source-SHA `5eeeb3e35313eed66350b13d973ba59adbe5b0b2`, [Run 40179831237](https://github.com/vibrationalforce/Echoelmusic/actions/runs/40179831237). Dessen [Archive-/Upload-Log](https://github.com/vibrationalforce/Echoelmusic/actions/runs/40179831237/job/121131206608) zeigt tatsächlichen Upload-Erfolg und Apples `state=VALID`. Uploadzeit: 25.10.2026, 10:33:32 Europe/Madrid. Das ist Verarbeitung bei Apple, keine Geräteabnahme.

**10011 ist kein belegter Upload.** Die Loop-Commits `4ab8ba4c3569ffa8140015f0251785e777a6171a` und `8f6d94a44adf1b7cb06ee69effc9ac9dc8d70db4` liegen nach dem Source-SHA des 10010-Uploads. Die Aussage „W0 erledigt / 10011“ im Plan ersetzt keinen Herkunftsbeleg. Loop/Overdub bleiben Beta bis zu einer konkreten Abnahme auf einem Build, der diese Commits enthält.

## 3. Vision vollständig erhalten, Stand korrekt lesen

| Welle | Stand an der gelesenen Basis | Nächster überprüfbarer Schritt |
|---|---|---|
| W0 Einstieg, Loop, Overdub | Screen-Keys, Pads, Starter-Projekt und Loop-/MIDI-Wrap-Code vorhanden; Upload- und Gerätebeleg nicht gleichsetzen | Loop/Overdub einschließlich gehaltenem Ton über Wrap und Stop/Undo auf tatsächlich passendem Build prüfen |
| W1 Körper | HRV/RR/rPPG-Kerne in DSP; Source, Adapter und View sind Platzhalter ohne durchgängige Messkette | gültiger Zustand, Opt-in, echter Producer, Plattformdeklarationen und erreichbare Anzeige |
| W2 Modulation | Format 2, kein gespeicherter ModRoute-Pfad | Semantik und Format 3, danach Compile-/Renderpfad und UI |
| W3 Bild | keine entsprechende Studio-Visual-Kette | musikalischer Snapshot, erste Visual-Fläche, Fenster-/Ressourcenbesitz, Flash/A11y-Abnahme |
| W4 Verbindungen | Network MIDI und Clock vorhanden; geplantes Licht-/OSC-/ADM-OSC-Modul fehlt | reine Encoder/Egress-Policy, dann benannter Netzwerkbesitzer nach F25 |
| W5 Klang+ | Synth, Drums, Sampler, Plugin; kein DDSP-Gerät und kein belegter MPE-Out-Notenpfad in Studio | reine DDSP-Portierung, Instrumentadapter, MPE Out, Modulation über W2 |
| W6 Store | Kauf-/Unlock-Pfad vorhanden; keine vollständige kommerzielle Abnahme | Produkt/Vertrag/Preis, echte Host-Prüfung, Metadaten nur aus belegten Funktionen |
| W7 Video | keine Studio-Capture-/Schnitt-/A/V-Exportkette | neuer AVFoundation-Besitzer, Zeit-/Medienvertrag, nichtdestruktiver Schnitt und synchroner Export |
| W8 Stimme | entsprechende Studio-Autotune-/Harmonizer-/Granular-Kette fehlt | pro Prozessor reiner geprüfter Kern, Kerneladapter, Live-/Clip-Anbindung |
| W9 Gesicht/Bewegung | keine entsprechende Studio-Produzentenkette | lokale gültige Quellen, Kamera-Arbitration, Opt-in, W2-Anbindung |
| W10 Assistenz | reale Menü-Tür, FoundationModels-Tools, Befehlstür und Songwechsel-Schutz vorhanden | stabile Zielidentität, Abbruch/Teilresultat/Undo, Musikrahmen sowie Klang aus einem Satz und editierbare Arrangement-Vorschläge |

„Vorhanden“ bezieht sich auf gelesenen Code. Keine Zeile dieser Tabelle bescheinigt Gerätefunktion. Native Watch-/Mac-/Vision-Ziele, Streaming und Ableton Link bleiben nach dem Plan vom 25.10. außerhalb von 1.0 und sichtbar im langfristigen Ziel. Zusammenarbeit und Netzwerk-Audio brauchen eigenständige Interoperabilitätsverträge; „Distributed“ im Nordstern ist kein Implementierungsbeleg.

## 4. Ein Schreiber, konkrete nächste Scheiben

### S0 — Basis und Integration

Vor Änderung sauberen oder bewusst isolierten Checkout sicherstellen. `git diff`, `git log`, tatsächliche PR-Heads und den letzten grünen Studio-Lauf lesen. G4a gegen eigene Änderungen prüfen. #428 und #429 sind Dokumentationsarbeit und kein Beleg einer erweiterten App. Ihre gewünschten Korrekturen können getrennt reviewt werden.

Nicht wieder aufnehmen: den alten Branch `docs/one-point-zero-is-the-workstation` als Scope-Quelle mergen; Issue #418 ohne Crash-Stack schließen; veraltete PRs #422–#424 aufgrund eines alten Handover-Kommentars zusammenführen. Keine direkte Änderung von `main`.

### S1 — G4b: Erfassung bis zur Übernahme ehrlich rückmelden

G4a übernimmt zuerst. Dann einen reinen Vertrag für Capture → Store-Übernahme → Dateisave definieren und testen. `syncedState` darf eine abgelehnte Store-Übernahme nicht als übernommen behandeln. Die sieben bestehenden Aufrufer sind in `EchoelStudioApp`, `DocumentController` und `PluginInterfaceView`; nicht alle gleichzeitig in eine übergroße Scheibe ziehen.

Empfohlene Teilung: zuerst bestehendes `ProjectStore.absorb`-Verhalten und die fehlgeschlagene Übernahme mit `ProjectStoreTests` prüfen; danach Host-API und je eine Aufruferfamilie anpassen, mit kompatibler Übergangsform. Abschließend sichtbare Meldung am vorhandenen Status-/Exportpfad. Kein generischer neuer Notification-Bus.

Abnahme: unverändert ist kein Fehler; nicht geladen/nicht serialisierbar/zu groß hat eine erkennbare Ursache; letzter gültiger Zustand bleibt; alter Zustand eines anderen Plugins gelangt nie ins neue; Export meldet, wenn aktuelle Settings nicht übernommen wurden. Kein „gespeichert“ vor erfolgreichem Dateischreiben.

### S2 — G3a: Stimmenidentität im reinen Sampler

Dateien: `EchoelStudio/DSP/Sources/EchoelDSP/Sampler.swift` und `EchoelStudio/DSP/Tests/EchoelDSPTests/SamplerTests.swift`.

Ein prüfbares Voice-Handle mit Generation bzw. gleichwertige eindeutige Identität einführen. `noteOff(pitch:)` gibt derzeit alle gehaltenen Stimmen dieser Tonhöhe frei. Eine neue gezielte Freigabe muss die gewählte Stimme lösen, ohne eine andere gleich klingende Stimme zu beenden. Bestehende Pitch-API kompatibel halten, bis ihre Aufrufer bewusst umgestellt sind. Fest allokierter Pool, kein Render-Lock, keine Allokation im Ereignispfad.

Abnahme: zwei Stimmen derselben Tonhöhe, gezielte Freigabe einer Stimme; veraltetes Handle nach Voice-Steal/Reset/Samplewechsel; Generation-Wiederverwendung; Poolgrenze; endliche Ausgabe.

### S3 — G3b: Wiederholte Taste nach Root-Wechsel

Dateien: `EchoelStudio/Engine/Sources/EchoelKernels/SamplerKernel.swift` und `EchoelStudio/Engine/Tests/EchoelKernelsTests/SamplerKernelTests.swift`.

Vor Überschreiben des gehaltenen Eintrags die frühere **eigene** Stimme lösen. Aktueller `sounding[note]` speichert nur transponierte Tonhöhe; deshalb das Handle aus S2 mitführen. Ein bloßes `noteOff(oldPitch)` ist unzureichend, wenn eine zweite Taste nach Clamping/Transposition dieselbe Tonhöhe hält.

Abnahme: Note-On derselben Taste, Root ändern, wieder Note-On, Note-Off; keine gehaltene alte Stimme. Zusätzlich zwei verschiedene Tasten auf gleicher Ausgangstonhöhe, Kanalvarianten, CC120/123, Samplewechsel und Reset. Eine weiterhin nur mit `sounding[note]` adressierte Tabelle schützt nicht zwei gleiche Tasten auf verschiedenen Kanälen: kanalbezogene Halter oder bewusst erhaltene Zusammenfassung ausdrücklich festlegen und testen. Daraus keinen MPE-Claim ableiten. Danach erst der atomare Float-Parameterpfad als eigene Scheibe derselben Datei; keine parallelen Schreiber.

### S4 — G2a: Quellenidentität im reinen LiveKeys-Vertrag

Dateien: `EchoelStudio/Engine/Sources/EchoelEngine/LiveKeys.swift` und `EchoelStudio/Engine/Tests/EchoelEngineTests/LiveKeysTests.swift`.

Eine gehaltene Taste gehört zu `(source, channel, key)`. Reservierte interne Identität für Bildschirmtasten festlegen; bestehende Aufrufer vorübergehend über eine klar benannte Default-Quelle kompatibel halten. Kapazität, Quellendisconnect, Reconnect-Generation, Retarget und Panic sind Teil des Vertrags.

Die vorhandene Pitch-Aggregation bleibt ausdrücklich erhalten: `LiveKeys` fasst Halter derselben `(slot, pitch)` zu einer hörbaren Note zusammen. `holder` muss deshalb alle Quellen und Kanäle berücksichtigen. Release/Disconnect senden erst ein abschließendes Note-Off, wenn kein anderer Halter dieser Tonhöhe im Slot bleibt. Das bestehende Off→On bei einem erneuten Anschlag ist eine gesonderte Retrigger-Regel. Diese Scheibe verspricht keine unabhängigen Stimmen oder Ausdrucksdimensionen je Quelle.

Abnahme: zwei Quellen, gleicher Kanal, gleiche Taste; Note-Off von Quelle A lässt B gehalten und erzeugt kein abschließendes Engine-Note-Off. Nach B-Off folgt die erforderliche Freigabe. Quellenverlust löst nur deren Halter. Keine neue dynamische Allokation im Render-/Realtimepfad.

### S5 — G2b: MIDI-Eingang und Aufnahme durchgängig anbinden

`EchoelStudio/App/Engine/MIDIInput.swift` enthält `LiveRouter.Captured`, `LiveRouter.receive`, die CoreMIDI-Quellen-Tags und den Parser. Die Quelle dort erhalten und bis zum gehaltenen Ton sowie zur Take-Zuordnung führen. Prüfe die tatsächlichen Aufrufer in `AudioEngine` und den bestehenden MIDI-Take-Konverter, bevor du die höchstens drei Dateien der nächsten Scheibe festlegst. Neue API, App-Wiring und Aufnahmeumstellung bei Bedarf in getrennte kompatible Scheiben teilen.

**Aufnahmefalle:** `LiveRouter.Captured` erfasst heute bei Noten bereits `decided.notes`, also auch synthetische Off→On-Ereignisse aus dem Retrigger. Beide Ausgaben beim B-Anschlag einfach mit Quelle B zu markieren kann das Off der zuvor hörbaren A-Note falsch zuordnen. `MIDITake.open` und `remnants` sind bislang nach Pitch adressiert. Zuerst festlegen, ob der Take quellengebundene ursprüngliche Spielereignisse oder den hörbar zusammengeführten Ausgang abbildet. Capture- und Take-Identität müssen gemeinsam zu dieser Entscheidung passen; ein einzelnes zusätzliches Source-Feld ist kein vollständiger Fix.

Abnahme: A-On → B-On derselben Taste → A-Off → B-Off mit unterschiedlichen Zeitpunkten; nach jedem Schritt Engine-Nachrichten und offene Aufnahmeereignisse prüfen. Der Take entspricht der gewählten Semantik, synthetische Offs beenden keine falschen Quellennoten. Dazu Screen-Keys plus Hardware, Disconnect, kein verwaistes Note-Off und keine MPE-Ausdrucksdaten als Bedien-Learn. Diese Scheibe implementiert weder MPE In noch UMP-Typ 4.

### S6 — AU-Renderfehler erreichen den Export

`HostedUnit.render` und `HostedEffect.process` erhöhen heute `sampleTime` und kehren bei `status != noErr` zurück, ohne den Fehler an den Export zu melden. Beginne mit einem begrenzten Fehlerstatusvertrag in den vorhandenen Hosted-Processing-Protokollen/Kernels und seinen Verhaltenstests. Danach jeden Host-Adapter mit den vorhandenen `HostedUnitTests` bzw. `HostedEffectTests` anbinden; zuletzt Engine-/Dokumentexport. Jede Teilung bleibt innerhalb von drei Dateien.

Im Render keine Exception, Formatierung, Log-Ausgabe, Allokation oder Actor-Hops. Fehlerdaten über einen begrenzten, geeigneten Übergabepfad auslesen. Offline-Export muss beim relevanten Fehler scheitern und eine unvollständige Datei erkennbar behandeln; Live-Playback braucht eine gesonderte nachvollziehbare Fehlerpolitik.

Abnahme: injizierter Nicht-null-Status eines Stub-Plugins; Fehler in einem späteren Block; Instrument und Insert; erfolgreicher Kontrollrender; keine falsche Erfolgsmeldung durch korrekte WAV-Länge allein. Stems prüfen Startsample, Kanalzahl, Länge, Peak und gemeinsamen Zeitbezug. Hardware-Loops müssen über den dafür vorgesehenen Echtzeitpfad laufen.

### S7 — W1/W2 und die weiteren Medienwellen

Grok G-A liefert Body-/Modulationsvertrag und Referenztests. Claude prüft diese gegen echte Source- und Engine-Besitzer und integriert in der dort verlangten Reihenfolge. Keine Laufzeitmodulation über `ParameterWriter` ins Dokument schreiben. Keine Format-3-Änderung ohne alte Format-1/2-Goldens und neue Migrationstests.

Danach können W3/W4 und W5 in ihren voneinander unabhängigen vorbereitenden Scheiben abwechseln. G-B liefert Visual-/Protokollverträge; G-C Klang- und MPE-Out-Verträge; G-D Kamera-/Video-/Agent-Verträge. W8 kann reine Kerne vor der Kamera-Abnahme entwickeln. W10 kann bestehende Befehle und Abbruchverhalten vor Video härten. W9 übernimmt den einen Kamera-Besitzer von W7/G-D und die Quellenvalidität von W1/G-A.

W6 läuft als Release-Vorbereitung mit, wird aber nicht aufgrund seiner Nummer zum Store-Start vor W7–W10. Erst die tatsächlich erforderliche vollständige Funktionsliste und ihre Abnahmen rechtfertigen den vollständigen 1.0-Claim.

## 5. Drei wichtige Integrationskorrekturen

### Echte Quellen brauchen echte Plattformdeklarationen

Die gelesenen `EchoelStudio/project.yml`, `EchoelStudio/Support/Info.plist` und Entitlements enthalten Mikrofon/Local Network sowie App Groups, aber keine vollständigen Kamera-/Bluetooth-/Health-Deklarationen. W1 darf daher nicht als reines UI-Wiring fertiggemeldet werden. Grok liefert die Produzentenmatrix; Claude bereitet den konkreten minimalen Diff vor. Bestehende Founder-Gates für `project.yml`/Workflows beachten. F25 betrifft den spezifischen Netzwerk-Allowlist-Eintrag und wird nicht als allgemeine Blockade verwendet.

### Doctor meldet einen bereits bestätigten Fehlalarm

`scripts/doctor.py`, `section_a`, erkennt die gültige Form `set -eo pipefail` in Studios „Build Engine for iOS“ nicht. Die vier bisherigen Selbsttests bestehen, decken diesen Fall aber nicht ab. `--section A` meldet weiterhin kritische Kategorien; daraus keinen Studio-Buildfehler ableiten.

Separate vorbereitete Reparatur: Parser-/Statushelper und eigene Verhaltens-Selbsttests in `scripts/doctor.py`, keine Workflow-Änderung. Gültige kombinierte/getrennte Flags, Kommentar-/Echo-Gegenbeispiele, Deaktivierung mit `set +o pipefail` und Reihenfolge vor/nach Build abdecken. Der bestehende `PIPESTATUS`-Pfad bleibt als eigener Fall. Der reale Buildschritt selbst benötigt diese Reparatur nicht.

### Grüner Upload ist nicht automatisch Apple VALID

`scripts/asc-build-state.rb` beendet auch den 30-Minuten-Timeout mit Exit 0 und Warnung. Beim nächsten Upload deshalb explizit `processingState=VALID` belegen. Build 10010 hat diesen zusätzlichen Beleg; für einen neuen Build wird er neu erhoben.

## 6. Release-Verfahren für Claude

1. **Integration abschließen:** aktueller eigener Branch, saubere Diffs, die ausgewählten Funktionen erreichbar, alle vorgesehenen reinen Tests ausgeführt, keine still übersprungenen Fälle. Keine pauschale Formulierung „alles fertig“.
2. **Native Gate lesen:** `Echoel Studio` auf genau dem vorgesehenen Integrationsstand. Bei Push-Läufen den Commit prüfen; bei PR-Läufen zusätzlich den tatsächlichen Checkout-SHA aus dem Joblog, weil `actions/checkout` den synthetischen Merge-Commit statt nur des PR-Heads auscheckt. Beide Jobs und tatsächliche Test-/Buildschritte prüfen: Pakete auf macOS, Core/DSP/Engine/Host für iOS, App-Simulatorbuild, Extension-Grenzprüfung, Simulatorstart und unsigned Release-Gerätebuild. Linux ist zusätzliche Portabilitätsevidenz; unter Linux existiert `EchoelHost` nicht.
3. **Gerätefragen auswählen:** aus der Engineering-Matrix höchstens fünf verständliche Fälle für diesen Build, bevorzugt drei neue Verhaltensweisen und zwei tragende Regressionen. Vorhandene Founder-Familien SP/SR/SN in `FOUNDER_INBOX` nutzen, keine verstreuten neuen Listen. Loop/Overdub explizit aufnehmen, wenn diese Commits erstmals auf dem Gerät geprüft werden.
4. **Release-Notiz vorbereiten:** jede genannte Funktion muss auf dem Upload-SHA vorhanden sein. Den veralteten F17-Satz in `EchoelStudio/RELEASE` im beabsichtigten Upload-Schritt korrigieren: das tatsächliche 10010-App-Archiv trägt beide Gruppen, die Extension nur `.shared`. Die Datei nicht beiläufig für Dokumentationspflege ändern.
5. **Bewusst auslösen:** erst nach grünem Studio-Integrationsstand `EchoelStudio/RELEASE` auf einem Nicht-main-Branch ändern und pushen, wenn der konkrete Upload im aktuellen Auftrag autorisiert ist. Der Workflow wartet anschließend auf den Studio-Lauf genau dieses Release-SHA. Während dieses Gate-/Uploadlaufs keine weiteren konkurrierenden Studio-Pushes auf denselben Branch.
6. **Archiv und Upload belegen:** tatsächliche App/Extension, Bundle-IDs, Marketingversion, `10000 + run_number`, signierte Entitlements, Uploadresultat, Apple VALID und dSYMs lesen. Ein Merge auf main allein lädt Studio nicht hoch. Kein Upload durch Änderung der eingefrorenen `.deploy/release`.
7. **Gerätetest und Bericht:** Gerät/OS, Audio-Route, Host/Pluginversion, konkreter Ablauf und Ergebnis festhalten. Nicht ausgeführte Fälle bleiben `NOT_RUN`. Gerätetest entscheidet über Recall, Klang, Sensorik und Bedienung; CI entscheidet darüber nicht.

**Simulatorgrenze:** Die aktuelle Launch-Smoke-Kopie entfernt `PlugIns` vor dem Start. Sie prüft den Main-App-Start über 20 Sekunden, keinen AUv3-Host und keine Extension-Registrierung in AUM.

**PR-/CI-Grenze:** Der bisherige PR Build Check #429 ist in SwiftLint mit Exit 2 gescheitert; die Detailursache konnte nicht gelesen werden. `.swiftlint.yml` umfasst `Sources` und `Tests`, nicht Studio. Das ersetzt weder den Studio-Gate noch wird es pauschal als harmlos abgetan. Bei einem neuen PR seine eigenen Checks lesen. Keine unbekannte Branch-Protection-Regel erfinden.

**Auto-Merge-Grenze:** Die gelesenen Auto-Merge-Workflows reagieren auf Pushes nach `claude/**`, nicht auf `codex/**`, und prüfen keinen PR-Draft-Status. Ein Draft allein schützt auf einem Claude-Branch nicht vor dieser Automation. Den Review-Branch bewusst wählen; keine automatische Zusammenführung aus dieser Vorbereitung ableiten.

## 7. Abnahmeprotokoll pro Scheibe und pro Build

```text
Basis-SHA / eigener Commit:
Geänderte Dateien (höchstens drei je Scheibe):
Erreichbares neues Verhalten:
Ausgeführte Tests / Toolchain / Anzahl / Fehler / Skips:
Studio-Lauf / Event / PR-Head / tatsächlich ausgecheckter SHA:
Offene Host-/Geräte-/Netzwerkfälle:
Release-SHA / TestFlight-Run / Buildnummer:
App- und Extension-Archivbeleg:
Apple processingState:
dSYM-Artefakt:
Gerät / OS / Route / Host / Ergebnis:
Nächste konkrete Scheibe:
```

Die Aussage „professionell implementiert“ verlangt einen vollständigen Weg von Eingabe über Dokument und Engine bis zur sicht-/hörbaren Wirkung, Speicherung, Undo und Export. Ein Enum, ein UI-Platzhalter, eine Bibliothek oder ein grüner Dateischreibvorgang allein schließt diesen Weg nicht.

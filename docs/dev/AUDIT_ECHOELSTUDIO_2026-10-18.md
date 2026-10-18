# Audit EchoelStudio — 2026-10-18

Auftrag (Founder): „Deep Repo Audit — kommen wir von hier aus Richtung Echoelmusic-Vision, ohne
extra neue Produkte anzulegen? Es sollte alles angelegt sein."

Vier read-only Prüfungen auf `claude/echoelmusic-review-optimize-u5jjpd` @ `4811035`: Identität und
Ship-Pfad · Vision-Abdeckung · Code-Zustand · Port-Inventar Alt → Neu. Nichts davon ist gerätegeprüft.
Zeilennummern sind ein Datum, keine Tatsache — vor dem Handeln neu messen.

---

## 1. Antwort in drei Sätzen

**Ja — die Vision ist ohne neues App-Store-Objekt erreichbar, aber NICHT so, wie M7 heute gebaut ist.**
Registriert sind nur `com.echoelmusic.app` (Record 6757957358) und seine Unter-IDs, darunter genau
EINE Audio-Unit-ID (`.app.auv3`); EchoelStudio baut dagegen unter `com.echoelmusic.studio` mit vier
Erweiterungen und vier Kauf-Produkten, die es nirgends gibt. Die Architektur trägt die Vision (alle
Bereiche passen als Module an `ParameterAddress`, `Command`, `EngineSnapshot`) — zwei Türen aus
NEUSTART §3.5 fehlen noch: das Spur-Modell „Quelle + Ziel" und eine allgemeine Ereignis-Spur.

## 2. Was „alles angelegt" konkret heißt

| Objekt | Registriert | EchoelStudio heute | Ziel |
|---|---|---|---|
| App | `com.echoelmusic.app` | `com.echoelmusic.studio` (`EchoelStudio/project.yml`) | `com.echoelmusic.app` beim Wechsel (M1) |
| Audio-Unit-Erweiterung | `com.echoelmusic.app.auv3` (eine) | vier: `.studio.synth/.drums/.sampler/.effects` | **EINE** Erweiterung `.app.auv3` mit allen sieben Komponenten (Synth, Drums, Sampler, 4 Effekte) |
| Kauf | im Code nur `com.echoelmusic.app.pro` (Alt-App); **kein Beleg, dass es in ASC angelegt ist** | vier `com.echoelmusic.studio.*` | **EIN** Kauf schaltet alle eigenen Plugins in fremden Hosts frei |
| App Group | `group.com.echoelmusic` | keine (richtig: die `.auv3`-ID hat die Fähigkeit nicht, sonst `-3000`) | so lassen — Lizenz über StoreKit in der Erweiterung |
| Widgets, Watch, Clip, Notification | registriert | nicht vorhanden | später, unter den vorhandenen IDs |

Eine Erweiterung mit Instrumenten und Effekten zugleich ist zulässig; das Muster „Unit nach
Komponenten-Beschreibung wählen" existiert schon (`Plugins/Effects`, `PluginViewController.makeUnit`).

**Ein Kauf-Produkt lässt sich nicht vermeiden, wenn etwas verkauft wird.** Ist `com.echoelmusic.app.pro`
in App Store Connect schon angelegt, ist es der Weg mit null neuen Objekten. Sonst braucht es genau
eines — ein Produkt im bestehenden Record, keine neue App, keine neue ID.
**Gemessen 2026-10-18 (Bildschirmaufnahme des Founders):** in ASC existiert noch KEIN In-App-Kauf, und
die App steht bei iOS 1.0 „In Vorbereitung zur Übermittlung" — nie veröffentlicht, also nur Tester
betroffen. Vor dem ersten Kauf muss der Account-Inhaber den aktualisierten „Paid Applications Schedule"
akzeptieren. (Die Entscheidung vom
2026-10-17 „einzeln plus Komplett-Paket" wird damit auf „ein Paket" reduziert — Founder-Frage E37.)

## 3. Was vor dem Wechsel auf `com.echoelmusic.app` fehlt

| Punkt | Stand | Schwere |
|---|---|---|
| Bundle-IDs | `com.echoelmusic.studio*` | BLOCKER — Erweiterungs-IDs müssen mit der App-ID beginnen |
| `testflight.yml` | baut nur die Alt-App | BLOCKER — und mit `-allowProvisioningUpdates` würde ein Lauf auf EchoelStudio heute still neue App-IDs im Developer-Portal anlegen. Erst IDs umstellen, dann den Workflow |
| Build-Nummer | `CURRENT_PROJECT_VERSION: "1"` fest in allen Targets | BLOCKER — jeder Upload wäre Build 1 |
| Version | `0.1.0` | ÄNDERN — der Record steht bei 10.79.x, die nächste muss höher sein (z. B. 11.0.0) |
| App-Icon | keins | BLOCKER |
| Privacy-Manifest | keins; benutzt `UserDefaults`, `mach_absolute_time` | BLOCKER (App und Erweiterung) |
| `ITSAppUsesNonExemptEncryption` | fehlt | ÄNDERN — sonst hängt jeder Build an „Missing Compliance" |
| iPad (`"1,2"`) | Record ist iPhone-only | ÄNDERN — erlaubt im Update, braucht iPad-Screenshots, nicht umkehrbar |

## 4. Was Tester beim Wechsel verlieren (die Alt-App ist auf TestFlight)

1. **Ihre Projekte** — die Alt-App speichert `TimelineDocument`, EchoelStudio liest nur `.echoel`; kein Import.
2. **Das AUv3 `aumu/echl` (BodyVibe)** — das einzige gerätegeprüfte Host-Feature (AUM, 2026-09-20).
   Gespeicherte AUM-Sessions finden es nicht mehr, wenn die neue `.auv3`-Erweiterung `echl` nicht trägt.
3. Kamera-Puls, Bio-Panel, HealthKit, BLE-Gurt · Visual-Fenster · OSC/ADM-OSC/Art-Net/sACN ·
   MIDI-Datei-Export (steht im Store-Text!) · LUFS/True-Peak · Widget · Siri-Kurzbefehle · Multipeer.

Bio, Visual, Licht und Raum sind laut NEUSTART bewusst nach V1 verschoben. MIDI-Export und
Lautheitsmessung gehören laut NEUSTART §2 dagegen IN V1 und fehlen.

## 5. Vision-Abdeckung

Gemessen am Code, nicht an den Statusabsätzen.

| Bereich | EchoelStudio | Tür in der Architektur |
|---|---|---|
| Komponieren, Arrangieren, Automation | stark | `Command`, `ParameterAddress` — sauber |
| Instrumente, Effekte, AUv3-Host | ja (keine MIDI-Effekte, keine Plugin-Presets) | Insert-Kette sauber; Built-ins hart je Slot in `EngineCore` (zweiter Weg neben `InstrumentKernel`) |
| Aufnahme | Audio ja, **MIDI nein** | `RecordController` + `addNotes` |
| Mixing | Fader, Pan, Sends, Returns, Direkt-Ausgänge; **keine Meter, keine Gruppen** | Gruppen brauchen ein anderes Spur-Modell |
| Mastering | **nein** (Master ohne Inserts, kein LUFS/Limiter) | Master-Inserts: ein Codec-Feld + Master-Stufe |
| MIDI/MPE | Noten rein, Clock rein/raus, Netzwerk-MIDI; **kein Pitch-Bend/Aftertouch/CC zum Instrument, keine Noten raus** | `PlaybackPlan.NoteEvent` ist nur Note an/aus → Ereignis-Union nötig |
| Agent | elf Werkzeuge, auf dem Gerät | handgeschrieben neben dem Katalog; `CommandCatalog`-Kommentar behauptet das Gegenteil |
| Bio, Visual, Licht, Raum, Video, Streaming, Kollaboration | nein (nach V1) | **blockiert** durch das fehlende Spur-Modell und die fehlende Ereignis-Spur; außerdem fehlt eine LIVE-Modulationsschicht (heute geht jede Steuerung über das Dokument und damit über Undo) |

## 6. Code-Zustand — echte Befunde

Gehalten hat: Snapshot-Übergabe, Sampler-Ring, Ringe, eine Sheet-Stelle, kein `print`/`!`/`try!`.

| # | Schwere | Befund | Ort |
|---|---|---|---|
| 1 | HOCH | Routenwechsel (Kopfhörer, Bluetooth, Anrufende) während einer Aufnahme verwirft die ganze Aufnahme; ohne Eingang danach hängt jede weitere Aufnahme bis zum Neustart | `App/Engine/AudioEngine.swift` `configure` setzt `recorder = nil`, `take`/`drainTask` bleiben |
| 2 | MITTEL | Aufnahmen > 10 min werden verworfen (Import-Grenze gilt auch für Takes), CAF bleibt verwaist | `DocumentController` → `AudioFileImport.decode` |
| 3 | MITTEL | Beim Folgen einer fremden Clock veröffentlichen acht Stellen die Tempo-Karte des Songs statt der gespielten → Sprung, dann Relock; Automation wird an falschen Ticks geschrieben | `AudioEngine.publish(project)` statt `publish(playing(project))`, `playheadTick` |
| 4 | MITTEL | Clock-Tempo schreibt über Undo: jede andere Aktion schließt den Schritt, der nächste Tempo-Wert löscht den Redo-Stapel | `MIDIInput` Tempo-Schreiben + Coalescing |
| 5 | MITTEL | Export rechnet den ganzen Song im RAM (×4 Kopien), `UInt32` fällt über 4 GB → ein Element bei Takt 9000 tötet die App | `OfflineRender.swift` |
| 6–14 | NIEDRIG | Audio-Spur-Gain nach Position statt Slot · unsortierte Regionen aus Datei spielen nicht · `setClipLength` kann Unladbares speichern · Synth/Sampler-Parameter ohne Atomics · Instrument-Render liest die Kernel-Referenz mehrfach · Lane-Kopien pro Ereignis · Lizenz nur beim Erzeugen geprüft (Kauf im offenen Host wirkt erst nach Neuladen) · verworfener Sample-Load · drei veraltete Zeilen in `EchoelStudio/CLAUDE.md` | siehe Prüfbericht |

Außerdem: `App/` hat keinen Test-Target — `AudioEngine`, `PluginHost`, `DocumentController`, MIDI und Store sind ungetestet.

## 7. Widersprüche zwischen den Gesetzesdateien

NEUSTART sagt, es gehe CLAUDE.md, FOUNDER_PRODUCT_LAW und MASTER_PLAN vor — keine der drei verweist
zurück. Root-`CLAUDE.md` nennt weiter „bio-reaktives Instrument", „WA3 next", iPhone-only, Abo-Modell,
`ProGate`. NEUSTART selbst plant Ableton Link an fünf Stellen und streicht es an einer sechsten
(Founder 2026-10-18: draußen). Eine Sitzung, die eine dieser Dateien zuerst liest, plant falsch.

## 8. Reihenfolge — ohne ein einziges neues App-Store-Objekt

1. **Identität** (keine Founder-Handlung nötig, reversibel, CI baut unsigniert): EchoelStudio-IDs auf
   `com.echoelmusic.app` / `.app.auv3`; die vier Erweiterungen zu EINER zusammenlegen; Kauf-IDs auf EINE.
2. **HOCH-Befund 1** (Aufnahme bei Routenwechsel) und die MITTEL-Befunde 3–5.
3. **Ship-Grundlagen:** Build-Nummer, Version ≥ 11.0.0, Icon, Privacy-Manifest, Verschlüsselungs-Schlüssel.
4. **V1-Lücken, die der Store-Text verspricht oder Profis erwarten:** MIDI-Datei-Export, Meter,
   Master-Inserts + LUFS/True-Peak, MIDI-Aufnahme, Pitch-Bend/CC.
5. **Erst dann** `testflight.yml` auf EchoelStudio umstellen (Founder-Entscheidung E38: wann, und ob
   die Tester-Verluste aus §4 vorher geschlossen sein müssen).
6. Danach die zwei Türen (Spur-Modell, Ereignis-Spur) + Live-Modulation — die Voraussetzung, damit
   Bio, Visual, Licht und Raum als Module zurückkommen.

---

## 9. Stand nach dem Abarbeiten (2026-10-18, Abend)

Nur kompiliert und in CI getestet — nichts gerätegeprüft.

| Punkt | Commit |
|---|---|
| §8.1 Identität (eine App-ID, eine Erweiterung, ein Kauf) | `1118a1b` |
| Befund 1 Aufnahme bei Routenwechsel · Befund 2 Takes > 10 min | `30c861d` |
| Befund 3 Tempo-Karte beim Folgen · Befund 4 Clock-Tempo über Undo | `c4cb613` |
| Befund 5 Export im RAM / UInt32-Falle | `e115d72` |
| §3 Version 11.0.0, Build-Nummer, Icon, Privacy-Manifeste, Verschlüsselung | `24bb4a2` |
| §4 MIDI-Datei-Export | `d45b7b6` |
| §4 Meter | `ff779ea` |
| §4 Lautheit (BS.1770 / EBU R 128) und True-Peak am Export | `1d254e0` |
| §4 MIDI-Aufnahme auf eine scharfgeschaltete Instrumentenspur | `b978009` |
| §4 Pitch-Bend und Sustain-Pedal live (Synth + gehostete AUv3) | `1e97c97` |
| §4 Master-Inserts (Dokument · Engine · App · Export) | `2e66371` · `023b219` |

Damit ist §8.1–8.4 abgearbeitet. Offen bleibt: Bends und Controller AUFNEHMEN und abspielen (braucht die
Ereignis-Spur, §8.6), dann `testflight.yml` (E38). Master-Inserts laufen hinter dem Master-Fader: der
Master-Gain ist in die Spur-Gains eingerechnet, die Kette sitzt deshalb dort, wo ein Limiter hingehört.
Nachgezogen: eine Aufnahme während des Folgens einer fremden Clock wird mit der gespielten Tempo-Karte
platziert, nicht mit der des Songs (`commitTake(tempoMap:)`).

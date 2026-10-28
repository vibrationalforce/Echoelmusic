# Revival Plan — Erwecke alles zum Leben (2026-10-28)

**Auftrag:** Alle historischen EchoelTools, die Website-Vision und OneClock als Master wieder zum Leben erwecken und in die aktuelle Studio-Architektur + Website integrieren.

**Grundsatz:** Nicht die alte App wiederbeleben, sondern die **Fähigkeiten** als Module in der einen Workstation (Echoel Studio) und als klare, ehrliche Präsentation auf der Website.

---

## 1. OneClock als Master

Zwei Bedeutungen, beide behalten und sichtbar machen:

| Bedeutung              | Ort                          | Rolle                                      |
|------------------------|------------------------------|--------------------------------------------|
| **Website-OneClock**   | `one-clock.html` (oder neu)  | Freie Einladung: Atemzyklus an Weltzeit. Kein Account, keine Daten, kein Kauf. |
| **Engine-OneClock**    | EchoelEngine Transport       | Die eine Uhr. Keine zweite Tempo-/Play-Wahrheit. Bio/Flow nur als ControlSource, die explizit committed. |

**Website-Umsetzung:**
- Startseite: OneClock prominent als Einstieg („Die eine Uhr – für dich und für das Studio“).
- Link zu einem einfachen, offline-fähigen OneClock-Widget (Atem + Weltzeit).
- Im Studio: Transport ist die einzige Zeitquelle; Bio-Tempo nur als Vorschlag.

---

## 2. EchoelTools wieder herausholen und als Module integrieren

Aus FAQ, Architecture und Vision-Dokumenten die historischen Tools:

| Tool           | Historischer Kern                     | In Studio als Modul                          | Priorität |
|----------------|---------------------------------------|----------------------------------------------|-----------|
| EchoelSynth    | DDSP + Poly + Sub                     | Instrument-Kernel + AUv3                     | P0 (teilweise da) |
| EchoelGen      | Generative Loops                      | Agent-Hilfe / Clip-Generator (keine Noten schreiben ohne User) | P1 |
| EchoelFX       | Charakter-Effekte                     | Insert-Kette (bereits teilweise)             | P0 |
| EchoelMIDI     | MIDI 1.0/2.0 + MPE out                | MIDI-In/Out + Event-Union                    | P0 |
| EchoelBio      | HR, HRV, Atem, Coherence              | ModSource (BodyFrame)                        | P1 |
| EchoelNet      | OSC + ADM-OSC                         | Event-Spur / Output                          | P2 |
| EchoelVis      | Metal Bio-Visuals                     | Visual-Spur / zweiter Screen                 | P2 |
| EchoelLux      | Art-Net / sACN                        | Licht-Spur                                   | P2 |
| EchoelMix      | Mixer + Master                        | bereits in Studio                            | — |
| EchoelAI       | On-Device Intelligence                | Agent (bereits angelegt)                     | P1 |
| EchoelStage    | Externes Display                      | Stage-Output                                 | P2 |

**Technische Integration:**
- Tools leben als **Domains / Tracks** (Source → Target).
- Bio, Visual, Licht, Raum werden **nicht** in den Core gezwungen, sondern als Module, die über den EngineBus oder einen ModSource-Bus andocken.
- Keine neuen Bundle-IDs. Alles unter `com.echoelmusic.app`.

---

## 3. Website zum Leben erwecken

### Neues Menü (Vorschlag)
1. **Studio** — aktuelles Produkt + TestFlight
2. **Tools** — EchoelTools-Katalog (live / planned / history)
3. **OneClock** — die eine Uhr (Website + Engine)
4. **Vision** — multidimensional, Installationen, Inklusion
5. **Roadmap** — ehrlich, mit Studio vs. Module
6. **Artist**

### Startseite
- Hero: „Echoel Studio – die eine Workstation. Dein Körper spielt sie.“
- OneClock als visueller Einstieg.
- Klarer Banner: „Seit Oktober 2026 ist Echoel Studio die Workstation. Bio, Licht und Visual kommen als Module zurück.“
- CTAs: TestFlight + Tools-Katalog.

### Tools-Seite neu
- Grid der EchoelTools mit Status (Live in Studio / Live in Alt-App / Planned / Removed).
- Jede Karte verlinkt auf Architektur oder Roadmap.
- History-Sektion: was gebaut, was entfernt, was zurückkommt.

---

## 4. Nächste konkrete Schritte

1. **Website:** Menü + Startseite + Tools-Katalog aktualisieren (statisch, ehrlich).
2. **Studio:** ModSource-Protokoll + BodyFrame-Adapter fertigstellen (ohne die ganze Alt-App zu portieren).
3. **OneClock:** Website-Seite prominent machen; Engine-Clock als einzige Zeitquelle dokumentieren und testen.
4. **Katalog:** `docs/dev/ECHOELTOOLS_CATALOG.md` anlegen und mit Status pflegen.
5. **Claude:** Die bestehenden Feedback-Dateien + diesen Plan als Auftrag geben.

---

**Zusammenfassung:** Alles zum Leben erwecken heißt nicht „alles auf einmal bauen“, sondern die historische Vision als klare Module und eine ehrliche Website wieder sichtbar und anschlussfähig machen. OneClock ist der Master – für die Zeit und für die Einladung.

Erstellt 2026-10-28 auf Basis von Website, FAQ, Vision-Dokumenten und Team-Review.

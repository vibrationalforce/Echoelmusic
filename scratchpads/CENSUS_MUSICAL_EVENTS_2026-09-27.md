# Architektur-Check: musikalische Ereignisse als gemeinsame Quelle für Audio · Video · Visual · Ausgänge (2026-09-27)

**Auftrag (Founder, wörtlich gekürzt):** Prüfen, ob Echoelmusic musikalische Ereignisse (Beat, Takt,
Position, Start/Stop, Seek, Loop; Clip-/Szenenwechsel; Automation, optionale Bio-Modulation)
gemeinsam für Audio, Video, Visuals und externe Ausgänge nutzbar macht — angestoßen von der
rekordbox-/PRO-DJ-LINK-Bridge-/SoundSwitch-Ankündigung. **Kein Implementierungsauftrag.** Nichts
gebaut, keine Abhängigkeit, keine Integration.

**Quellenlage, ehrlich:** Web-Quellen waren in dieser Sitzung durch den Egress-Proxy gesperrt; zur
Ankündigung liegt nur ein Suchtreffer-Ausschnitt vor (**unbestätigte Sekundärquelle**). Daraus wird
hier NICHTS über eine offene API oder eine PRO-DJ-LINK-Kompatibilität abgeleitet. Unterschieden wird
allein zwischen öffentlich dokumentierten Schnittstellen (MIDI-Clock/Start/Stop/SPP, Ableton Link
als frei lizenzierter SDK-Weg, OSC, Art-Net/sACN, ADM-OSC, MTC) und Integrationen, die eine Lizenz
oder Partnerschaft brauchen (PRO DJ LINK, rekordbox-interne Bridges). Die zweite Gruppe ist für
Echoelmusic heute weder erreichbar noch geplant; sie steht hier nur, damit niemand sie aus dem
Wort „Bridge" herausliest.

Alles Folgende ist **aus dem Code gemessen** (zwei read-only-Zensus-Durchläufe, `git grep`, Lesen
der Erzeuger und Verbraucher), nicht geschätzt. Wo eine Zahl steht, steht der Grund daneben, warum
sie sich bewegen kann.

## 0. Begriffe sauber getrennt — und was davon existiert

| Ebene | Bedeutung | Stand im Code |
|---|---|---|
| **Tempo-/Phasen-Sync** | gemeinsames BPM, gemeinsame Beat-Phase | EINE Uhr (`PatternEngine`, `DispatchSourceTimer`), ins `Transport` relayed; MIDI-Clock **aus** (Start/Stop/24 ppqn), kein Clock-**Eingang** irgendeiner Art |
| **Track-Identität** | „welcher Titel läuft" | nicht vorhanden und nicht nötig: Echoel spielt das eigene Dokument, keine fremden Titel |
| **Wiedergabeposition** | Takt/Beat/Tick, Seek | intern vorhanden (`TimelineStore`, `TimelineRegionPlayer`), `Transport.seek` hat **keinen Aufrufer**; nach außen nur `beatPhase` (viertel-quantisiert) und `tempo` über OSC — **kein Song-Position-Pointer**, kein `Continue` |
| **Musikalische Struktur** | Sektion, Phrase, Downbeat | `MusicalFrame.sectionIndex` wird **nie geschrieben**; `ArrangementSection` hat keinen Erzeuger; **keine Phrasen-Erkennung** — wird hier ausdrücklich NICHT behauptet |

## 1. Eindeutige Zeit-/Zustandsverantwortung?

**Fundament (ja, im Kern):** Es gibt genau eine Beat-Uhr. `PatternEngine` tickt, `Transport` hat
keinen eigenen Timer. Tempo hat eine Schreibkette mit benannter Quelle (`TempoSource`:
user · flowServo · automation · modulationRoute · remoteControl; kein Default — T1/T2/T3 in
`CLAUDE.md`, Wächter `TempoInvariantTests`). `MusicalFrame` wird pro Sechzehntel aus
`PianoRollModel.trigger` veröffentlicht (Noten, Grundton, Skala, Tempo-Spiegel, Beat-Phase,
Master-Pegel) und ist der eine Frame, den Visual, Licht, Raum und OSC lesen.

**Lücken (gemessen):**
- `MusicalFrame.tempoBPM` ist ein Spiegel vom Seed-Zeitpunkt und **veraltet während eines Glides**
  — Verbraucher, die ihn als Uhr nehmen, driften.
- `sectionIndex` hat keinen Schreiber; `beatPhase` ist auf Viertel quantisiert — Taktgrenzen leitet
  **jeder Abonnent selbst** ab (Metal, Art-Net/sACN-`MusicMediaMap`, ADM-OSC, OSC), also vier
  Ableitungen einer Wahrheit.
- **Kein Loop-Bereich**: es wird immer der ganze Song gespielt, `loopEnabled` hat keinen Schreiber.
- **Kein Seek-Erzeuger**: `Transport.seek` ist ungerufen; ein Sprung an eine Position ist heute
  keine Nutzerhandlung.

## 2. Können Arrangement und Performance dieselben Mappings nutzen?

**Fundament:** Beide sitzen auf demselben `TimelineStore`/`ClipStore` und derselben Uhr. Der
tick-quantisierte Szenen-/Clip-Start (`ClipLaunchEngine`, `LaunchTransition`) ist der EINZIGE
tick-quantisierte Mechanismus im Repo. Automation läuft tick-gebunden über `ParameterApplyRouter`;
die Bio-Matrix läuft mit 100 ms Wanduhr (`ModulationEngine`) — zwei Takte, bewusst verschieden.

**Lücke, und sie ist die größte des Checks:** Es gibt **vier disjunkte Mapping-Vokabulare** plus
den Szenen-Start:
1. das Routing-Gitter der Patchbay (Quellen → Ports),
2. die Modulationsmatrix (`ModRoute`, Body → Parameter),
3. die Parameter-Wirbelsäule (`EchoelParameterRegistry`/`ParameterApplyRouter`, Automation),
4. die Arrangement-Automation (`TimelineStore.setSongAutomation`, `track.<id>.<base>`),
5. Szenen-Start-Ereignisse (`LaunchTransition`), die **nur die Audio-Seite erreichen**.

Ein Mapping „Downbeat → Licht-Blackout-Release" oder „Szene 3 → Visual-Preset" ist mit keinem der
vier heute ausdrückbar, weil Visual keine `visual.*`-Schlüssel in der Registry hat (gemessen: null)
und das Licht zwar einen Deskriptor trägt, aber als **nicht automatisierbar** eingestuft ist
(`ParameterDomain`-Eligibility, P2). Arrangement und Performance teilen die Uhr, nicht die Ziele.

## 3. Externe Systeme über klar begrenzte Adapter?

**Fundament:** Die Sender sind getrennte Klassen mit eigener Adresse und eigenem Lebenszyklus
(`OSCSender`, `ADMOSCSender`, `ArtNetSender`, `SACNSender`, `MIDIOutput`); Ingress ist getrennt
(`OSCReceiver` mit Allowlist, Opt-in aus; `MIDIBusPublisher`). Alle sprechen offene Standards.

**Lücken:**
- **Keine Protokoll-Naht**: die Adapter sind konkrete Typen ohne gemeinsames Protokoll, gestartet
  aus `applyRouting()`; ein neuer Ausgang (z. B. ein Link-Peer) hieße „fünfter Sonderfall", nicht
  „weiterer Adapter".
- **Kein Clock-Eingang**: MIDI-Clock wird vom Parser verworfen, Ableton Link / MTC / PRO DJ LINK
  fehlen, `Transport.clockSource` wird nirgends gelesen. Echoel ist heute **nur Master**.
- MIDI-Ausgang sendet Start/Stop/Clock, **kein SPP, kein Continue** — ein Slave kann Tempo und
  Lauf folgen, nicht der Position.
- Lizenz-/Partner-Integrationen (PRO DJ LINK, rekordbox-Bridges) sind **kein** Adapter-Kandidat
  ohne Founder-Entscheidung und Vertrag; aus der Ankündigung folgt nichts.

## 4. Verbindungsverlust, Uhrwechsel, Stop — definiert?

**Fundament:** Stop ist EINE Handlung mit definierter Kaskade (One-Stop-Gesetz, `OneStartControlTests`);
das Licht hat seit #1446/#1447 definierte Ausgangs-Kontinuität (begrenzter In-flight-Puffer,
Art-Net-Stop-Kontinuität, Stall-Erholung); MIDI-Ausgang sendet Stop.

**Lücken:**
- OSC/ADM-OSC: Sendefehler werden **verworfen**, bei Stop wird **nichts** gesendet (kein
  „letzter Frame", kein Ende-Signal) — ein Visual-Host friert auf dem letzten Wert ein.
- MIDI-Ausgang: **Zielverlust unerkannt** (kein Reconnect-Pfad, keine Anzeige).
- **Kein ausgangsweiter Panic** (alle Noten aus, alle Ausgänge in definierten Zustand) — pro
  Adapter verschieden oder abwesend.
- OSC-Steuereingang hat **kein Sender-Timeout**: ein entfernter Regler, der verstummt, hält seinen
  letzten Wert unbegrenzt.
- „Uhrwechsel" ist heute leer, weil es keinen zweiten Uhrgeber gibt — die Frage stellt sich erst mit
  einem Clock-Eingang, und dann muss sie VOR dem Eingang beantwortet sein (Fail-closed:
  ohne Peer zurück zur eigenen Uhr, ohne Sprung im Takt).

## 5. Kann EchoelAI Mappings über validierte Befehle konfigurieren, während die Engine zeitgenau ausführt?

**Fundament:** Der Befehlsweg ist typisiert und schmal (`EchoelCommand` mit fünf Befehlen,
Parser mit Allowlist, `EchoelCommandExecutor` mit Plan-Basis, Replay-Schutz, Consent, Undo-
Journal; Reparaturen 2a–2e und 3a/3b dieser Sitzung). Die Ausführung geht **nur durch die
Knopf-Schreiber** (`TrackMix.setLevel`, `TrackParts.duplicate`, `MediaLookUndo`) — genau die
Trennung, die man für „Konfigurieren, nicht Rendern" will.

**Lücken:** Es gibt **keinen Befehl** für Route, Matrix, Szene oder Tempo, und **keinen
tick-quantisierten Haken** („ab nächstem Takt") für einen Agenten-Befehl — `ClipLaunchEngine`
hat ihn, der Executor nicht. Ein Mapping-Befehl bräuchte zuerst ein gemeinsames Mapping-Modell
(§2), sonst würde EchoelAI vier Vokabulare lernen.

## Zusammenfassung: Fundamente und Lücken, nach Wirkung geordnet

**Trägt heute:** eine Uhr · benannte Tempo-Quellen · ein `MusicalFrame` für alle Ausgabe-Medien ·
tick-quantisierter Szenen-Start · offene Standards auf allen Ausgängen · typisierter Agentenweg.

**Fehlt, in dieser Reihenfolge des Nutzens (kein Bauauftrag, nur Rangfolge):**
1. **Struktur im Frame** — `sectionIndex`/Downbeat einmal schreiben statt viermal ableiten; Tempo im
   Frame aus der Uhr, nicht aus dem Seed.
2. **Ein Mapping-Modell** (Quelle-Ereignis → Ziel-Parameter mit Zeitbezug), auf das Matrix,
   Automation und Szenen-Start projizieren — Voraussetzung für §2 und §5.
3. **Definierter Ausgangs-Zustand bei Stop/Verlust** für OSC/ADM-OSC/MIDI (Ende-Signal, Panic,
   Zielverlust sichtbar, Eingangs-Timeout).
4. **Position nach außen** (SPP/Continue) und ein Seek-Erzeuger — erst dann ist „Position" ein
   gemeinsames Ereignis.
5. **Clock-Eingang** nur als letzter Schritt, mit vorher entschiedener Fail-closed-Regel; MIDI-Clock
   und Ableton Link (frei, SDK) sind die dokumentierten Wege — PRO DJ LINK ist es nicht.

**Nicht behauptet:** Phrasen-/Sektions-/Beat-Erkennung fremder Audiosignale, rekordbox-Kompatibilität,
irgendeine PRO-DJ-LINK-Fähigkeit.

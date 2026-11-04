# Pitch an ein Senior Apple Developer Team — eine Schleife, ein Satz

Stand `main` `1e7c64aec`, 2026-10-14. Tauchfliege ist ein eigenes, privates Projekt von Michael; nicht Teil von Echoelmusic.

## Der Satz im Raum

Echoelmusic ist das Instrument, das ein Stück auf Ton, Bild, Licht und Raum
legt. Es steuert kein Fahrzeug, liest kein Gehirn und ist kein Medizinprodukt.

Wer den zweiten Satz weglässt, verliert den Raum.

## Was heute gebaut ist

Gemessen in `project.yml`, nicht aus dem Pitch-Film.

| Fläche | Stand | Beleg |
|---|---|---|
| iPhone, iOS 18 | Das Produkt. Familie nur iPhone. | `TARGETED_DEVICE_FAMILY: "1"`, `IPHONEOS_DEPLOYMENT_TARGET: "18.0"` |
| Widget | Im App-Bundle. | Ziel `EchoelmusicWidgets`, Abhängigkeit eingebettet |
| Audio Unit | AUv3-Instrument im App-Bundle, hostet selbst nichts. | Ziel `EchoelmusicAUv3` |
| Apple Watch | Ziel existiert, Einbettung aus. Archiv scheiterte an der Watch-Phase. | Abhängigkeit auskommentiert, Kommentar C6b |
| iPad | Bewusst aus. Die Kamera-Pulsquelle braucht die Taschenlampe; kein iPad hat sie. | Kommentarblock über `TARGETED_DEVICE_FAMILY` |
| Mac, visionOS, tvOS | Kein App-Ziel. Zwei Warteschlangen nennen die Namen nur als Kommentar. | `Core/SPSCQueue.swift`, `Core/MemoryPressureHandler.swift` |

Die großen Flächen sind als Ausgang gedacht (externer Schirm, ADM-OSC), nicht
als zweite App. Das steht im selben Kommentar, der iPad ausschließt.

Bedienung ohne Geste ist angefangen, nicht fertig. Arrangement-Blöcke und die
Slip-Knöpfe des Audio-Editors tragen Namen für VoiceOver und Switch Control
(`ArrangeCanvasView.swift`, `AudioPartSlip.swift`). Der Editor sagt selbst,
wo eine Fläche noch keine Accessibility-Baum hat (`AudioPartEditorView.swift`).

## Die Schleife, die ein Senior-Team annimmt

Eine Plattform pro Schleife, und nur wenn die vorherige Tür zu ist. Kein
gleichzeitiger Sprung auf iPad, Mac, Vision, Android und ein Implantat.

1. **iPhone zu Ende bedienbar.** Jede eigene Fläche (Wellenform, Pads, Metal),
   die heute nur eine Geste ist, bekommt denselben benannten Zugang, den
   Arrangement und Slip schon haben. Das ist der Weg für Menschen, die nicht
   tippen können: Switch Control, Sprachsteuerung, AssistiveTouch. Systemfunktionen,
   kein neues Gerät.
2. **Watch nur einbetten,** wenn die Archiv-Phase in Xcode geprüft ist. Der
   Kommentar sagt, woran es liegt. Nicht vom Linux-Rechner raten.
3. **iPad als Instrument,** erst mit einer Biosquelle, die dort trägt (Gurt ist
   gebaut), und mit dem Umbruch, den der Kommentar als #292 nennt. Vier
   Einstellungen und der Wächter `DeviceFamilyIsPhoneOnlyTests` in einem Commit.
4. **Dieselbe Bildmaschine auf einer räumlichen Fläche.** visionOS wäre ein
   Ausgang des vorhandenen Metal-Bildes, keine zweite App und kein zweites Stück.
5. **Andere Betriebssysteme über das, was schon eine Tür ist.** AUv3 ist die
   Tür in andere Apple-Hosts. VST3 und CLAP bleiben spätere Türen. Kein
   Android-Neubau, keine zweite Codebasis.

## Kein Fahrzeug

Tauchfliege ist ein eigenes, privates Projekt von Michael; nicht Teil von Echoelmusic.

Echoelmusic kann später ein OSC- oder MIDI-Signal an eine **andere**,
zertifizierte Anlage schicken, so wie es heute Licht und Raum schickt. Es wird
nicht der Flugrechner. Diesen Satz nicht umdrehen.

## Neuralink und „für Invalide“

Menschen mit unterschiedlichen Zugängen sind der Grund für Schleife 1, nicht
für ein Implantat im App-Store-Text.

Im Repo gibt es keine Neuralink-Schnittstelle. Eine behauptete Gedankensteuerung
eines Fahrzeugs oder des Instruments wäre eine Medizin- und eine
Sicherheitsbehauptung. Beides ist hier verboten: die App ist kein Medizinprodukt
und steuert kein Fahrzeug.

WATCH, bis drei Dinge gleichzeitig schriftlich da sind: eine dokumentierte
Eingabeschnittstelle, die Einwilligung der Person, und ein Verantwortlicher,
der nicht diese App ist. Bis dahin bleibt die Eingabe das, was Apple schon
anbietet.

## Was in diesem Raum nicht gesagt wird

- „Wir sind auf allen Apple-Plattformen.“ Eine ist ausgeliefert.
- „VR/XR ist fertig.“ Es gibt ein Metal-Bild und einen türlosen Raumausgang.
- „Neuralink steuert die App.“ Es gibt keine Schnittstelle.
- Heilung, Therapie, Diagnose.

## Nächste Scheibe

Keine Plattform. Eine Fläche, die Switch Control heute nicht erreicht, benennen
und mit einem Wächter schließen. Erst danach die Watch-Einbettung in Xcode
ansehen. iPad, visionOS und jede Fahrzeug- oder Implantat-Frage bleiben
Founder-Entscheidungen mit eigenem Träger.

# Auftrag an ChatGPT Astra: Zielbild, drei Telefone

Kopiere alles ab der Linie in einen NEUEN Chat. Nicht in den Planungs-Chat.
Füge Astras Antwort danach hier im Chat ein. Jede Zeile wird gegen den genannten
Stand gemessen, bevor etwas davon in die App kommt. Astra schreibt nicht.

Das Bild liegt daneben: `reports/zielbild-echoelmusic-2026-10-13.jpg`
https://github.com/vibrationalforce/Echoelmusic/blob/reports/astra-zielbild/reports/zielbild-echoelmusic-2026-10-13.jpg

---

Du arbeitest als PRÜFER für Echoel (Michael Terbuyken, Studio Hamburg). Mehrere KIs helfen mit, und jede hat genau eine Spur. Nur einer schreibt.

WAS ECHOEL IST
Echoelmusic ist eine iPhone-App, Instrument und Produktionsumgebung zugleich. Herzschlag und Atem können Klang, Bild, Licht und Raum in Echtzeit mitsteuern. Biofeedback ist eine gemessene Steuerquelle. Echoel ist kein Wellness-, Meditations- oder Therapieprodukt. Was die App HEUTE ausliefert, steht nur in ContentPipeline/CLAIMS.md. Alles andere ist ein Ziel und kein heutiges Feature.

CODE (öffentlich, MIT-Lizenz), fester Stand: Commit 1e7c64aecfb63e3dc52da62aa001bbdf88d97eac.
Eine Datei öffnest du so:
https://github.com/vibrationalforce/Echoelmusic/blob/1e7c64aecfb63e3dc52da62aa001bbdf88d97eac/<Pfad>#L<von>-L<bis>
Wenn du Links nicht öffnen kannst, antworte nur „Kann die Dateien nicht öffnen.“ und hör auf. Rate nicht, was darin steht.

DEINE ROLLE
- Du prüfst das Zielbild gegen den Code an diesem Stand. Du schreibst keinen Code, keine Patches, keine Befehle und keine Skripte.
- Du entwirfst keine dritte Navigation und keine neuen Wörter. Ein Konflikt ist ein Befund. Ein Ersatz-Menü ist keiner.
- Nur Claude Code schreibt ins Repo. Der Founder entscheidet den Umfang. Ob etwas baut, sagt die CI. Wie es aussieht, sagt das Gerät.
- Deine Antwort wird Punkt für Punkt nachgemessen. Belege zählen, Lob zählt nicht.
- Wenn eine Datei und dieser Auftrag sich widersprechen, gilt die Datei. Den Widerspruch schreibst du als Befund.

WAHRHEITSREGELN
- Erfinde keine Dateien, Funktionen, Zeilennummern oder Zahlen. Nenne nur Stellen, die du selbst geöffnet hast, oder Sätze, die unten als Bildbeschreibung stehen.
- Siehst du das Bild nicht, gilt nur die Beschreibung. Erfinde keine Pixel. Schreib dann „ANNAHME: Bild nicht gesehen“ in die offenen Fragen, nicht in die Tabelle.
- „Weiß ich nicht“ ist besser als Raten. „Nichts gefunden“ ist eine gültige Antwort.

ROTE LINIEN
- Keine Heilung, Therapie, Diagnose oder medizinische Wirkung.
- Keine Heilfrequenzen, kein Solfeggio, keine Chakren.
- Kein Löschen von Sicherheits- oder Haftungshinweisen.

PRIVATE DATEN
Frag nie nach Logs, Diagnose-Dateien, Puls-, Atem- oder anderen Gesundheitswerten, Nutzerdaten, Schlüsseln oder Dateien von einem Rechner.

ANTWORTFORMAT (genau so, nichts davor und nichts danach)
Modell: ChatGPT Astra · Auftrag: Zielbild drei Telefone gegen die vorhandene Hülle · Stand: 1e7c64aec
| Nr | Datei:Zeile | Befund (1 Satz) | Folge (1 Satz) | sicher/vermutet |
|---|---|---|---|---|
| 1 | … | … | … | … |
- Höchstens 8 Zeilen.
- Ein Treffer zählt nur, wenn das Bild und der geöffnete Code verschieden sind, oder wenn das Bild eine zweite Tür zu etwas zeichnet, das schon einen Namen hat.
- Findest du nichts, schreib genau eine Zeile: | – | – | nichts gefunden | <Grund> | sicher |
- Darunter: „Offene Fragen:“, je eine Zeile, höchstens 3, oder „keine“.
- Keine Einleitung, keine Zusammenfassung, kein Code, kein neues Menü.

AUFTRAG
Das Zielbild (Überschrift auf dem Blatt: „Designkonzept · Zielbild“. Darüber das Zeichen E, „Echoelmusic“, Satz „Ein Stück. Viele Ausdrucksformen.“) zeigt drei iPhones desselben Stücks „Nachtstück“, Status „Gespeichert“.

Gemeinsam auf allen drei:
- Oben drei Wörter: Arrangement, Spielen, Mix.
- Unten drei Wörter: Stück, Medien, Ausgabe.
- Dieselbe Transportzeile: Stopp, Play, Aufnahme, „120 BPM“, „4/4“, „D-Moll“.

Telefon 1, unten Stück, oben Arrangement:
- Spuren Drums, Bass, Akkorde, Textur. Drums, Bass und Textur zeigen Wellenform-Clips. Akkorde zeigt farbige Notenbalken und ist gewählt.
- Knöpfe „+ Spur“ und „Import“.
- Darunter „Akkorde · Noten“ mit den Tonhöhen A4, F4, D4.
- Felder „Raster 1/16“ und „Anschlag 0.78“.

Telefon 2, unten Stück, oben Spielen:
- Sechzehn Pads in vier Reihen: C5 D5 E5 G5 / A4 H4 C5 D5 / D4 F4 A4 C5 / G3 A3 H3 D4. D4, F4 und A4 tragen farbige Ringe.
- Intro, Thema, Dub. Thema ist gewählt.
- „Filter 1.20 kHz“ und „Raum 0.42“.
- Eine Zeile „Körper · Quelle wählen“.

Telefon 3, unten Ausgabe:
- Überschrift Ausgabe. Ein Bild aus zwei farbigen Ringfeldern.
- Bild, Licht, Raum. Bild ist gewählt.
- Zeilen: iPhone „Vorschau aktiv“, Projektor „Nicht verbunden“, Licht „Nicht verbunden“, Raumklang „Stereo“.
- „Exportieren“, „Bild halten“, „Licht aus“.

ÖFFNE NUR DIESE STELLEN und prüfe das Bild dagegen:
- Sources/Echoelmusic/Studio/StudioStage.swift — die zwei Bühnen, die fünf Wörter der unteren Leiste, und welche Bühne den Transport im Kopf trägt.
- Tests/CISmoke/ThePieceStageHasOnePlayTests.swift und Tests/CISmoke/OneStartControlTests.swift — was „ein Play“ verbietet.
- Sources/Echoelmusic/Resources/Localizable.xcstrings — die Einträge Arrange, Mixer, Instrument, Browse, Piece: welche Sprachen stehen dort.
- Sources/Echoelmusic/Sequencer/TrackInstrument.swift — die Fälle und was der Kopf über Drums sagt.
- ContentPipeline/CLAIMS.md — nur, um zu sehen, ob Bild, Licht, Raum und Export dort als heute ausgeliefert stehen. Eine Zeile, die dort fehlt, ist kein Befund gegen das Bild, sondern eine offene Frage.

FRAGEN, die du mit Datei und Zeile beantwortest, sonst nicht als Zeile aufnimmst:
1. Welche Tür des heutigen unteren Schalters hat im Bild keinen eigenen Namen mehr, und ist das im Code eine zweite Tür oder ein zusammengelegter Name?
2. „Spielen“ oben und die Transportzeile auf derselben Fläche: widerspricht das der Ein-Play-Regel, oder sitzt Play im Bild nur einmal?
3. Sind die deutschen Wörter des Bildes die Zeichenketten, die die App heute zeigt?
4. Die Spur „Drums“ mit Wellenform: behauptet das Bild die Drum-Stimme, die der Dateikopf beschreibt, oder nur einen Spurnamen über einem Audio-Clip?
5. „Ausgabe“ mit Bild, Licht, Raum und Exportieren: liegt das heute auf einer Fläche oder auf mehreren, und zeichnet das Bild davon eine zweite Tür?

Nur Konflikte in die Tabelle. Was das Bild und der Code gleich sagen, schreibst du nicht hin. Was nur das Gerät entscheiden kann, ist eine offene Frage.
Antworte nur in der Tabelle aus dem Kopf.

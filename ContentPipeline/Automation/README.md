# Automation

Ein Hilfsskript kommt hierher, wenn ein Handgriff sich zum dritten Mal wiederholt — nicht
vorher. Auto-Posting bleibt ausgeschlossen (siehe ../README.md).

⛔ Hier stand "Noch leer, absichtlich" — seit #1183 stimmt das nicht mehr, und diese Zeile ist
die einzige Beschreibung des Verzeichnisses. Wer sie stehen lässt, hat ein Verzeichnis, das
sich selbst für leer erklärt und zwei Werkzeuge enthält.

## autocut (#1183, Founder-Auftrag 2026-09-09)

**Doppelklick auf `Autocut.command`.** Der Rest ist ein Menü.

| Befehl | Tut |
|---|---|
| `proxy` | kleine Datei + Kontaktbogen — gegen "Videos hochladen dauert ewig"; **lange Seite 854 px**, damit Hochformat nicht benachteiligt wird (#1188) |
| `sync` | misst den Versatz zweier Aufnahmen über den TON und **verweigert die Antwort**, wenn er sich nicht sicher ist (Exit 2) |
| `highlights` | findet die lautesten Stellen und schneidet sie auf Wunsch (`--brand` brennt die Marke gleich ein) |
| `brand` | Echoel-Marke einbrennen — **immer in eine neue Datei**, das Original bleibt |
| `zoom` | an die Stelle heranzoomen, **wo etwas passiert** — `--aspect 9:16` macht Hochformat daraus |
| `--selftest` | treibt die reinen Kerne gegen synthetische Signale mit BEKANNTER Verschiebung — braucht kein ffmpeg |
| `--drive ORDNER` | baut zwei echte Videos mit bekanntem Versatz und fährt alles durch — braucht ffmpeg |

**Was bewiesen ist:** die Rechen-Kerne (`--selftest`, grün; drei Mutanten machen ihn
nachweislich ROT — ein grüner Test, der nicht rot werden kann, beweist nichts) UND die
ffmpeg-Hülle (`--drive`, grün gegen echte Videos: Versatz auf 0 ms getroffen, die drei
lautesten Stellen gefunden, die geschnittenen Clips tragen wirklich den lauten Teil).

⛔ Hier stand "alles was ffmpeg anfasst ist nicht bewiesen". Das stimmte nur, solange
niemand nachsah: `ffmpeg` fehlt im PATH dieses Containers, aber das Wheel `imageio-ffmpeg`
liefert eine echte Binärdatei (`.claude/skills/watch-clip`). **"Nicht auf dem PATH" ist nicht
dasselbe wie "nicht verfügbar"** — der Unterschied hat eine ganze Prüfung als unmöglich
erscheinen lassen, die zehn Minuten kostete.

**Was NUR der Mac beweisen kann:** die `.command` selbst, und ob ECHTES Kameramaterial
syncet — die Testvideos teilen denselben erzeugten Ton, zwei Geräte im Raum teilen nur den
Lautstärkeverlauf.

**Braucht:** `python3` + `ffmpeg`. **Kein ffprobe** (der einzige Nutzer war eine Funktion ohne
Aufrufer, #1184), kein pip, kein numpy.

## Die CI in der Ausgabe (#1185)

Founder 2026-09-09: *"Echoelmusic CI soll auch mit eingebaut werden. Siehe Website und
Echoelmusic Repo."* Gemessen und im Quelltext neben jedem Wert belegt:

| | Wert | Quelle |
|---|---|---|
| Tinte | `#e0e0e0` | `EchoelTheme.text` == Website `--text` |
| Grund | `#000000` | `EchoelTheme.bg` == Website `--bg` |
| Marke | E + Echo-Wellen | `docs/favicon-512.png` (das SVG nennt sich selbst „CI v7.1") |
| Rand | 1 px, 20 % Tinte | Website `--border rgba(224,224,224,0.08..0.2)` |

**Kein Grün.** `EchoelTheme.accent` trägt dort den Vermerk *signal only* — es bedeutet ein
gemessenes Signal. Als Zierfarbe bräche es die eigene CI.

**Kein Text.** Die Wortmarke bräuchte den ffmpeg-Filter `drawtext`, und **ob der da ist, lässt
sich nicht am Bau-Flag ablesen**: die geprüfte Binärdatei meldet `--enable-libfreetype` und hat
trotzdem NULL `drawtext` in `-filters`. Ein Bau-Flag ist eine Absicht, die Filterliste ist die
Tatsache. Die Bildmarke braucht keine Schrift und läuft überall.

**Die Platte ist keine Dekoration.** Die Marke ist helle Tinte; auf einer hellen
Bildschirmaufnahme verschwände sie ohne dunklen Grund. Massive Füllung plus 1-px-Rand ist genau
das, was die Uncodixfy-Regeln verlangen — Glasoptik, Verlauf und Schein sind dort verboten.

⚠️ "spannendste Stelle" ist hier als **Energie** definiert (laut = spannend). Das ist eine
ANNAHME, keine Messung von Spannung; das Werkzeug druckt darum je Clip seinen Wert, damit man
ihm widersprechen kann. Wenn der Founder etwas anderes meint (Bewegung im Bild, Gesicht,
Sprache), ist das eine eigene Scheibe und keine Feineinstellung.

## Auto-Zoom (#1186)

Founder 2026-09-09: *"An die richtigen Ausschnitte heranzoomen wo was passiert bei
bildschirmaufnahmen etc."*

**Wonach es sucht: VERÄNDERUNG, nicht Lautstärke.** Eine Bildschirmaufnahme steht
grösstenteils still; „wo passiert etwas" heisst dort buchstäblich „wo ändern sich Pixel".
Das ist eine **andere Frage als bei `highlights`** — und für eine stumme Aufnahme die
einzige, die überhaupt eine Antwort hat.

Ablauf: 4 Bilder/s auf ein 48×27-Raster → Differenz zum VORIGEN Bild (nicht zum ersten:
sonst gilt ein einmaliges Scrollen für den Rest des Clips als „aktiv") → kleinstes Rechteck,
das 75 % der Veränderung enthält → 10 % Luft drumherum → Seitenverhältnis → Zuschnitt.

Vier Sicherungen, jede mit eigenem Anspruch und eigenem Mutanten:
- **nie enger als ein Viertel des Bildes** — sonst wäre ein blinkender Cursor ein Standbild
- **immer gerade Kanten** — h264 bricht sonst ab, mit einer Meldung über Pixelformate, die
  nichts über die Ursache sagt
- **immer im Bild**, auch bei krummen Rasterteilungen (400 Fälle geprüft)
- **völlig ruhiges Material → das GANZE Bild**, keine willkürliche Ecke

⛔ **AUF ECHTEM MATERIAL TAT ER ZUERST NICHTS — und das ist der wichtigste Befund dieser
Runde (#1187).** An synthetischem Material mit EINER blinkenden Stelle arbeitete er perfekt.
An drei echten iPhone-Bildschirmaufnahmen der laufenden App gab er **100 % der Fläche** zurück,
also gar keinen Zoom. Der Grund ist kein Fehler, sondern das Material: **bei laufender App
bewegt sich der ganze Schirm** (Bio-Visual, Pegel, Zahlen). Gemessene Konzentration —
Anteil der Veränderung in den aktivsten 10 % der Fläche — **20,3 % · 33,2 % · 33,9 %** gegen
**100 %** bei einer einzelnen Stelle.

Seither **verweigert** `zoom` unter 50 % Konzentration, so wie `sync` unter 1,25× Vertrauen:
ein willkürlicher Ausschnitt sieht absichtlich aus und ist schlimmer als keiner. `--force`
macht es trotzdem.

⭐ **GESETZ: ein Werkzeug an synthetischem Material zu prüfen beweist die RECHNUNG, nie den
NUTZEN.** Beides braucht seine eigene Probe, und die zweite braucht echtes Material.

⚠️ **Grenze der ersten Fassung: EIN Ausschnitt für den ganzen Clip.** Wandert die Handlung,
gewinnt die Stelle mit der meisten Bewegung. Ein Zoom, der mitwandert, ist eine eigene
Scheibe — und die Frage, ob Schnitte oder weiche Fahrten, gehört dem Founder.

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
| `proxy` | 480p-Datei + Kontaktbogen — gegen "Videos hochladen dauert ewig" |
| `sync` | misst den Versatz zweier Aufnahmen über den TON und **verweigert die Antwort**, wenn er sich nicht sicher ist (Exit 2) |
| `highlights` | findet die lautesten Stellen und schneidet sie auf Wunsch (`--brand` brennt die Marke gleich ein) |
| `brand` | Echoel-Marke einbrennen — **immer in eine neue Datei**, das Original bleibt |
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

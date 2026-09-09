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
| `highlights` | findet die lautesten Stellen und schneidet sie auf Wunsch |
| `--selftest` | treibt die reinen Kerne gegen synthetische Signale mit BEKANNTER Verschiebung |

**Was bewiesen ist:** die Rechen-Kerne — `--selftest` läuft grün, und drei Mutanten
(Überhang verworfen · Fenster wiederholt · NaN-Filter entfernt) machen ihn nachweislich
ROT. Ein grüner Test, der nicht rot werden kann, beweist nichts.
**Was NICHT bewiesen ist:** alles, was ffmpeg anfasst — dieser Container hat kein ffmpeg und
kein macOS. Der erste echte Lauf gehört dem Founder.

**Braucht:** `python3` + `brew install ffmpeg`. Sonst nichts, kein pip, kein numpy.

⚠️ "spannendste Stelle" ist hier als **Energie** definiert (laut = spannend). Das ist eine
ANNAHME, keine Messung von Spannung; das Werkzeug druckt darum je Clip seinen Wert, damit man
ihm widersprechen kann. Wenn der Founder etwas anderes meint (Bewegung im Bild, Gesicht,
Sprache), ist das eine eigene Scheibe und keine Feineinstellung.

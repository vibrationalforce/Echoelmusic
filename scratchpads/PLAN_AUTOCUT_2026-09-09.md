# PLAN — autocut (Founder-Ask 2026-09-09)

**Status: Scheibe 1 GEBAUT (#1183). Scheiben 2–3 offen.**

## Der Auftrag, wörtlich

> "Das Dauer leider ewig mit dem Drive kannst du mir eine autocut application bauen, die ich
> auf dem Mac Book installiere? Oder soll ich das Repo hier mit Davinci Resolve verbinden?"

Auf Nachfrage:
> "Soll alles können. Aktuell Auto Sync der Clips und herausschneiden der spannendsten Stellen"
> — und was ewig dauert: **"Videos hochladen"**.

Also DREI Dinge, und das dritte hat er nicht als Aufgabe formuliert, sondern als Schmerz:
Sync · Highlights · Upload.

## Die Entscheidung (Council, kompakt)

**Keine Mac-App.** Ein eigenes Target heißt Signierung, Notarisierung, Wartung und ein ZWEITES
PRODUKT neben dem Instrument — genau die Fläche, deren Streichung `PRODUCT_DEFINITION.md`
begründet. Dazu praktisch: diese Sitzung hat kein macOS und kein Xcode, könnte eine App also
weder bauen noch testen. Eine ungetestete App zu liefern wäre schlechter als ein getestetes
Skript.

**DaVinci Resolve NICHT zuerst.** Sein Skripting-Zugang unterscheidet sich zwischen Free und
Studio, und **es ist nicht bekannt, welche Fassung der Founder hat**. Ein Resolve-Pfad, der auf
seiner Fassung nicht existiert, ist verlorene Arbeit. Er kann Resolve später bekommen — die
Schnittlisten, die `highlights` druckt, sind der natürliche Übergabepunkt.

**Also: eine Python-Datei plus eine `.command` zum Doppelklicken.** Doppelklick war seine
Anforderung ("installiere"), nicht Terminal-Bedienung.

## Was gebaut ist (Scheibe 1, #1183)

`ContentPipeline/Automation/autocut.py` — eine Datei, keine Abhängigkeit (kein pip, kein numpy).

| Unterbefehl | Verfahren |
|---|---|
| `proxy` | ffmpeg → 480p CRF 32 mp4 + 4×4 Kontaktbogen |
| `sync` | Hüllkurven-Korrelation, grob (10 Hz) → fein (100 Hz) → Parabel-Verfeinerung |
| `highlights` | Präfixsummen über die Energie-Hüllkurve, überlappungsfreie Fensterwahl |
| `--selftest` | acht Ansprüche gegen synthetische Signale, **grün** |

`Autocut.command` — Doppelklick, prüft python3 und ffmpeg, fährt ZUERST den Selbsttest, dann
ein Menü mit Datei-hierher-ziehen.

### Drei Entwurfsgründe, die im Quelltext stehen und hier nicht wiederholt werden müssen
1. **Hüllkurve statt Rohwelle.** Zwei Mikrofone teilen die Lautstärke-Kontur, nicht Phase und
   Klangfarbe. Rohwellen-Korrelation scheitert an genau dem Unterschied.
2. **Grob→fein ist eine BEDINGUNG, keine Optimierung.** 120 s bei 100 Hz sind 12 000 Werte;
   volle Korrelation in reinem Python wäre Minuten pro Paar.
3. **Vertrauen = Spitze / zweitbeste Spitze.** Ein falscher Sync sieht richtiger aus als gar
   keiner. Unter 1,25× **verweigert** das Werkzeug und gibt Exit 2 zurück.

## Was NICHT bewiesen ist — und warum das so bleiben muss, bis er läuft

Dieser Container hat **kein ffmpeg** (gemessen) und **kein macOS**. Also:
- Die reinen Kerne sind getrieben. Das lief.
- Die ffmpeg-Hülle und die `.command` sind **ungetestet**. Der erste echte Lauf ist seiner.

Das steht im Kopf beider Dateien. Eine "getestet"-Behauptung wäre hier die teuerste Sorte
Falschaussage: er würde ihr sein Material anvertrauen.

## Offene Scheiben

- **2 — `sync` schreibt aus.** Heute misst er nur und druckt. Ausrichten kostet ein
  `ffmpeg -ss`/`-itsoffset` pro Clip. Erst nach seinem ersten Lauf, weil die Messung stimmen
  muss, bevor sie etwas schreibt.
- **3 — "spannend" jenseits von Laut.** Heute = Energie, und das Werkzeug sagt das. Bild-
  Bewegung (Frame-Differenz) wäre die nächste Größe. **Braucht seine Antwort, was er meint** —
  raten wäre hier billig und falsch.
- **Resolve-Übergabe.** Erst wenn bekannt ist: Free oder Studio.

# Deep Audit und Produktwert — Echoelmusic (2026-10-15)

Founder: „Ich merke, dass es an vielen Stellen nicht richtig funktioniert und die Bedienbarkeit zu
komplex ist. … An welcher Stelle hat mein bisheriges Vibe Coding wirklich Brauchbares
hervorgebracht? Wie kann ich das Beste aus Echoelmusic herausholen und nebenbei vermarkten?"

Grundlage: vier Lese-Audits (Bedienbarkeit · Zuverlässigkeit · Produktwert · Vermarktung) am Stand
`5e9d57f` / Build 10.79.504, Kernzahlen von Hand nachgeprüft. Nichts davon ist auf einem Gerät gemessen.

## 1. Der ehrliche Befund in fünf Sätzen

1. **Fast nichts ist auf dem Gerät bestätigt.** 393 offene Prüf-Bitten im Code, **0** mit Datum
   als bestätigt markiert. Dated device evidence gibt es für genau zwei Dinge: der AUv3 lädt und
   klingt in AUM (20.09.), der Kamera-Puls lockt (älter, undatiert).
2. **Jeder Build vergrößert den Rückstand**: 280 → 343 → 367 offene Bitten in drei Tagen. Gebaut
   wird schneller als geprüft — das ist der Kern von „funktioniert an vielen Stellen nicht".
3. **Kein einziger Absturz-Fix ist auf dem Gerät nachgeprüft** (Export-SIGTRAP 2613/2618, stiller
   Start-Tod 2621, Safe Mode).
4. **Die Bedienung ist zu breit**: 5 Tabs auf 2 Bühnen, 9 Chips, 88 Regler in einer Ansicht
   (`EchoelStudioView`, 13 404 Zeilen), Tempo an 4 Stellen, 2 Play-Knöpfe, 23 „noch nicht
   verfügbar"-Sackgassen. Eine frische Installation öffnet auf einem **leeren Arrange, in dem Play
   ausgegraut ist** — der erste Eindruck ist Stille.
5. **Der echte Wert ist klein, klar und einzigartig** (Abschnitt 2), umgeben von ~59 000 Zeilen
   Studio-Oberfläche, die mit fertigen Apps konkurriert, ohne sie zu schlagen.

## 2. Wo das Vibe Coding wirklich Brauchbares hervorgebracht hat

| Kern | lebt | einzigartig | Reife (Wächter-Dateien) | Wert |
|---|---|---|---|---|
| Puls über die Kamera (Finger auf die Linse), BLE-Gurt | ja | **ja — keine iOS-Musik-App hat das** | 42 / 16 | 5 |
| Körper → Klang (Bio-Stimme, Modulations-Matrix) | ja | **ja** | 31 / 16 | 5 |
| Komponist in Tonart/Skala/Genre, vom Körper geformt | ja | **ja** | 47 | 5 |
| Tempo folgt dem Körper (Flow) | ja | **ja** | 2 (dünn) | 4 |
| Licht und Raum vom Telefon (Art-Net, sACN, ADM-OSC, OSC) | ja | **ja — keine iOS-Musik-App sendet DMX/ADM-OSC** | 21–37 | 4 |
| Bio-Visual (Metal, blitzsicher) | ja | teils | 58 | 4 |
| AUv3-Instrument (in AUM bestätigt) | ja | als Bio-Stimme ja | 24 | 4 |
| DSP-Bibliothek (41 Dateien, nur Foundation/Accelerate) | ja | nein, aber solide und wiederverwendbar | 53 | 3 |
| MIDI-Clock-Master, MPE out | ja | nein | dünn | 2 |

**Dazu zwei Werte, die unabhängig vom Produkt bleiben:** das Wächter-Bündel (`Tests/CISmoke`, 920
Dateien) und die Prüf-Werkzeuge (`scripts/`, 29) — eine Methode, mit der eine KI ohne Compiler
nicht lügt. Und die Bio-Signal-Kerne (HRV, RR-Hygiene, Atmung) als reine, wiederverwendbare Rechnung.

**Wo der Aufwand verpufft ist:** dieselbe Fähigkeit wurde mehrfach gebaut und wieder gestrichen
(DAW ×4, Piano-Roll ×3, Licht ×4, Visual ×4, Raum ×3, Streaming ×3), dazu ein C++/JUCE-Zweig, der nie
kompilierte. Schätzung: mehr als die Hälfte aller je geschriebenen Zeilen steckte in Hüllen, die
später gestrichen wurden — die Algorithmen darin überlebten oft.

## 3. Was das Beste aus Echoelmusic herausholt — fünf Entscheidungen

1. **Zwei Wochen Breiten-Stopp, eine Geräte-Sitzung.** Keine neue Fläche, bis die 20-Minuten-
   Sitzung (`docs/dev/DEVICE_SESSION_2026-10-12.md`, 15 Schritte) einmal beantwortet ist und die
   drei Absturz-Familien bestätigt sind. Ohne Ohr und Auge am Gerät baut jede Runde Rückstand.
2. **Die Kette zum Produkt machen:** Puls → Körper-Stimme → Komponist in Tonart → Körper-Tempo →
   Bild, Licht, Raum. Das ist das, was niemand sonst hat. Jede neue Arbeit muss diese Kette
   besser machen oder sie hörbar machen (eigene Drums gehören dazu — sie machen den Komponisten
   hörbar).
3. **Vereinfachen statt erweitern** — acht kleine Scheiben, je eine Zeile bis ein Ansicht-Teil:
   (a) frische Installation öffnet auf dem **Instrument**, nicht auf dem leeren Arrange (kehrt die
   Entscheidung vom 30.09. „Das Stück ist das Zuhause" um — deins);
   (b) EIN Play;
   (c) ein Hinweis „Finger auf die Rückkamera", sobald Play läuft;
   (d) Routing: alles außer Bluetooth-MIDI hinter „Bühne / Erweitert";
   (e) Field-Panel: vier Hauptregler, der Rest hinter „Mehr";
   (f) Tempo nur noch an EINER Stelle bearbeitbar;
   (g) Sackgassen ausblenden statt ausgrauen;
   (h) neun Chips → sechs (Mix+Master, Mood in Sound, Save/Export ins Logo-Menü).
4. **Den DAW-Anspruch einfrieren.** Arrange, Mixer, Audio-Editor bleiben, wie sie sind — Fehler
   reparieren ja, neue Funktionen nein, bis die Kette sitzt. Gegen Cubasis, Logic oder
   BeatMaker gewinnt Echoel nicht auf deren Feld.
5. **Hardware als Bühnen-Werkzeug**, nicht als Hauptfläche: Clock (gebaut), Ports pro
   Nachrichtenart, Drums an die TR-8S — für dein eigenes Set, hinter „Bühne".

⚠️ **Eine Spannung, die nur du auflöst:** am 15.10. hast du Biofeedback „nur ein kleines Gimmick"
genannt und Profi-Produktion an die erste Stelle gesetzt. Die Messung sagt das Gegenteil: die
Bio-Kette ist der einzige Teil, der einzigartig ist, am dichtesten bewacht, und der einzige mit
Geräte-Beleg. Meine Empfehlung: **Bio als Haken und Herz, Produktion als Tiefe** — nicht umgekehrt.

## 4. Nebenbei vermarkten — mit dem, was heute wahr ist

**Bestes Publikum:** Installations-, Licht- und Bühnenkünstler (VJs, Resolume/TouchDesigner,
Lichtdesign) — deine eigene Welt (Wasser-Licht-Klang), und die Fähigkeiten dafür sind heute wahr.
Produzenten erst, wenn der AUv3 in mehr als einem Host bestätigt ist.

**Sechs wahre Sätze** (aus `ContentPipeline/CLAIMS.md`): Finger auf die Kamera liest den Puls ·
Puls, HRV, Kohärenz und Atem formen den Klang live · das Bild ist spielbar · Licht und Raum vom
Telefon (Art-Net, sACN, ADM-OSC) · generative Musik in Tonart und Genre, WAV- und MIDI-Export · läuft
als AUv3-Instrument in AUM.

**Nie sagen:** läuft in Logic/Ableton/GarageBand · Wellness/Meditation/Stress · Apple Watch steuert
es · im App Store / Preis / Pro · Mikrofon, Aufnahme, Streaming.

**Fünf kleine Schritte neben der Entwicklung:**
1. Ein Puls-Video pro Woche nach der vorhandenen Vorlage (`ContentPipeline/Scripts/
   template_short_form.md`, Schnitt mit `Autocut.command`): Finger auf die Linse, Zahl lockt, Klang
   setzt ein. Noch ist nichts veröffentlicht (`Published/LOG.md`).
2. Ein Clip „das Telefon fährt echtes Licht" in deiner eigenen Installation — der stärkste Beleg.
3. Ein Demo-Clip ganz oben auf `docs/index.html` (die Seite hat noch kein Video).
4. Die vorhandenen OSC-Anleitungen (Resolume, TouchDesigner, Reaper) in deren Communities teilen,
   mit TestFlight-Einladung.
5. `press.html` und `artist.html` an Veranstalter schicken, die dich kennen (Fusion, Kampnagel,
   Pudel): „frei, TestFlight, live gespielt". Deine Musikprojekte zeigen Echoel-Material als
   Making-of.

Der vegane Food-Blog bleibt getrennt — es gibt keinen wahren Satz, der ihn mit dem Produkt verbindet.

# iPhone — 5 Minuten echte Nutzung (DMMW-Fluss, 2026-09-29)

Build: _wird nach dem TestFlight-Upload eingetragen (state=VALID)_
Gerät: iPhone, Kopfhörer oder Lautsprecher, Lautstärke mittel.

Jeder Schritt hat EIN erwartetes Ergebnis. Ein ❌ bitte mit Schritt-Nummer und einem Satz
melden („7: Stop hält die Musik nicht an"). Wenn die App abstürzt oder schwarz bleibt:
Diagnose-Log exportieren (Settings → Diagnostics) und mitschicken.

## 0:00 — Start (Stabilität)
1. App kalt starten. **Erwartet:** kein schwarzer Bildschirm, die Instrument-Fläche mit der
   Bereichs-Zeile (Compose · Perform · Visuals · Library · Settings) erscheint.

## 0:30 — Neues Stück → Spur → Part → Noten
2. **Create a piece** (bzw. „New piece"). **Erwartet:** Projektkopf zeigt einen neuen Namen,
   die Workstation ist leer; der Guide nennt Schritt 1.
3. **Add MIDI Track**. **Erwartet:** Satz „Added MIDI …" nennt die Spur; sie ist ausgewählt.
4. **New MIDI Part**. **Erwartet:** ein Part erscheint im Arrangement, der Noten-Editor öffnet.
5. Zwei, drei Noten ins Raster tippen. **Erwartet:** jede Note bleibt stehen; der Guide
   springt auf „Play".

## 1:30 — Arrangement + Play/Stop
6. Den Part verschieben oder kopieren (Part-Leiste). **Erwartet:** er landet auf dem Takt,
   den die Leiste nennt; Undo nimmt es zurück.
7. **Play the song**, nach ein paar Takten **Stop**. **Erwartet:** die geschriebenen Noten
   KLINGEN; Stop hält alles an (auch den Projektkopf). Zeile unter Play nennt den Starttakt.

## 2:30 — Speichern / Wiederöffnen
8. **Save** → Namen tippen → speichern. **Erwartet:** Projektkopf trägt den Namen.
9. **Library** öffnen. **Erwartet:** die Zeile nennt „Saved <Datum, Uhrzeit>"; Long-Press
   zeigt **Rename** und **Delete** (ohne Wischen erreichbar).
10. **Rename** → neuer Name → Save. **Erwartet:** Zeile bleibt an ihrem Platz, Datum unverändert.
11. App ganz schließen, neu starten, Library → das Stück öffnen. **Erwartet:** dieselben Noten
    und Parts; Play klingt wie in Schritt 7.

## 3:30 — Perform
12. **Perform**. **Erwartet:** Szenen des Stücks sind sichtbar; eine Szene starten wechselt
    auf ihrem Takt, ohne Aussetzer.

## 4:00 — Visuals (Klang → Licht)
13. **Visuals** / Visual-Fenster öffnen, Musik laufen lassen. **Erwartet:** Farbwolken
    erscheinen, solange Noten klingen; bei Stille ein ruhiger, farbloser Zustand.
14. Notenraster einschalten, dann Kammerton (A4) auf 432 stellen und ein anderes Tonsystem
    (z. B. ein Maqām) wählen. **Erwartet:** die Rasterzellen wechseln SOFORT die Farbe.
15. iOS Einstellungen → Bedienungshilfen → Farbfilter → Graustufen an, zurück zur App.
    **Erwartet:** jede Rasterzelle nennt weiterhin ihren Notennamen; der Grundton ist am
    dickeren Rand erkennbar. (Danach Graustufen wieder aus.)
16. Optional: Bewegung reduzieren an. **Erwartet:** keine Welle beim Tippen, Raster bleibt.

## Bekannte Grenzen (kein ❌)
- Löschen aus Menü/Rotor hat kein Undo.
- Parts landen auf der Haupt-MIDI-Spur, nicht auf einer zweiten ausgewählten MIDI-Spur.
- Das Stille-Neutral im Feld ist warm, das der Daten grau — Look-Entscheidung offen.

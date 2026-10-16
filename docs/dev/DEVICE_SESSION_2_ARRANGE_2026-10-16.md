# Gerätesitzung 2 — Arrangement & Performance (ab Build 10.79.515)

Elf Prüfungen, zusammen etwa 33 Minuten, nach Wert geordnet: wer nach Prüfung 4 aufhören muss,
hat das Wichtigste schon. Sie decken die ganze Arrange-&-Perform-Liste ab (A1 · A2 · A4b · A4c ·
A5 · A7 · A8 · A9 · A10 · P1–P4 · 7a–7c) — alles Gates-grün, nichts davon auf einem Gerät gesehen.

⚠️ **Build prüfen, bevor du anfängst:** Logo-Menü ≡ → Save/Export → „Diagnostics“, erste Zeile
muss `launch v10.79.515` oder höher sagen. P4b/P4c und 7a–7c sind erst ab 10.79.515 drin; auf
10.79.514 fehlen die Prüfungen 8–11. Bildschirmaufnahme mitlaufen lassen. Stürzt etwas ab:
notieren, Diagnose teilen, die übrigen Punkte offen lassen.

**Vorbereitung (2 min):** ein neues Stück (≡ → Open → „New piece“). Unten „Arrange“ → „Add“ →
„Add MIDI Track“ zweimal, damit zwei Synth-Spuren da sind. Beim Antworten reicht je Zeile
**ja / nein + ein Satz**.

Kopf: Build ____ · iPhone ____ · iOS ____ · Datum ____

| # | Prüfung | Zeit | Tun | Bestanden, wenn … | Ergebnis |
|---|---|---|---|---|---|
| 1 | **Start** (Ship-Gate 5) | 2 min | App wegwischen, Icon tippen, dreimal. | Kein schwarzer Bildschirm, kein Safe Mode, kein Einfrieren. Kam doch Safe Mode: direkt nach Telefon-Neustart oder TestFlight-Installation? | |
| 2 | **Leere Spur antippen → Teil** (A1) | 2 min | Auf der ersten Synth-Spur auf Takt 3 tippen. Dann auf das neue Teil tippen. | Ein 4-Takt-Teil steht auf Takt 3, der Noten-Editor geht auf. Der zweite Tipp wählt es nur aus — kein zweites Teil. | |
| 3 | **Einzähler vor Record** (A10) | 4 min | Ein paar Noten ins Teil setzen. „Click“ gedrückt halten → „Count-in“ → „1 bar“. Spur scharf schalten, Record. Dann noch einmal Record, und während des Einzählens Record erneut tippen. | Vier Klicks, auf dem fünften startet das Stück, ohne Lücke oder Doppelklick. Der Abbruch stoppt alles, nichts wird aufgenommen, der Klick ist danach wieder so wie vorher (an oder aus). | |
| 4 | **Auswählen, kopieren, einfügen** (A9) | 3 min | „Select“, zwei Teile auf verschiedenen Spuren antippen. „Copy“. Lineal auf einem späteren Takt antippen, „Paste“. Undo. Dann „Delete“, Undo. | Beide Teile haben einen Ring, „2 parts“. Nach Paste stehen beide wieder, ab dem getippten Takt, jedes auf seiner Spur, mit demselben Abstand. Je ein Undo nimmt Paste bzw. Delete ganz zurück. | |
| 5 | **Cycle ziehen** (A2) | 3 min | „Cycle“ an. Den rechten Griff des Bandes zwei Takte nach rechts ziehen, loslassen, Play. Undo. Dann nur kurz auf einen Griff tippen. | Der Rahmen folgt dem Finger taktweise; Play wiederholt den neuen Bereich. Undo gibt den alten zurück. Ein bloßer Tipp setzt nur die Abspielposition. | |
| 6 | **Marker** (A5) | 2 min | Lineal auf Takt 5 antippen → „Marker“. Noch einmal „Marker“. Undo. | Eine Marke mit kleinem Fähnchen oben steht auf Takt 5, auch neben der Startlinie sichtbar; der zweite Tipp nimmt sie weg, Undo stellt sie wieder her. Ist sie auf dem Lineal gut zu lesen? | |
| 7 | **Spur-Farbe und -Reihenfolge** (A4b · A4c) | 3 min | Eine Synth-Spur öffnen → Seite „Track“ → „Colour“ → „Orchid“, dann „Automatic“. Danach auf der zweiten Spur „Move up“, Undo. Während das Stück spielt noch einmal „Move up“. | Kopf, Teile und Mixer-Streifen werden orchid, „Automatic“ macht sie wieder teal. Die Reihenfolge ändert sich im Canvas UND im Mixer, Undo stellt sie zurück. Während des Spielens: kein Knacken, kein Hänger. Neben der Echoel-Spur ist „Move up“ für eine MIDI-Spur ausgegraut. | |
| 8 | **Session: Szenen auf dem Takt** (P1 · P2 · P3) | 4 min | Ein drittes Teil anlegen, damit jede Spur zwei hat. Oben „Arrangement“ → „Session“. Play, eine Szene starten. Dann „Launch on“ → „2 Bars“ und ein einzelnes Teil starten. | Jede Spur bleibt in ihrer Spalte, das Raster scrollt seitlich. Die Szene wechselt auf dem nächsten Takt, mit „2 Bars“ auf der nächsten Zwei-Takt-Linie, und das Teil beginnt von vorn. Klingt der Wechsel sauber? | |
| 9 | **Session ins Arrangement aufnehmen** (P4b · P4c) | 4 min | In Session „Record to arrangement“ an. Play, Szene 1, nach zwei Takten Szene 2, nach zwei weiteren Stop. Zurück auf „Arrangement“. Einmal Undo. Dann mit Cycle AUS eine Szene über das Ende des Stücks hinaus laufen lassen, bis es von vorn beginnt, und erst im zweiten Durchgang Stop. Zum Schluss den Schalter aus und erneut starten. | Die gestarteten Teile stehen auf beiden Spuren genau dort, wo sie liefen, über den alten Teilen. Ein Undo nimmt die ganze Aufnahme zurück. Über das Stück-Ende hinweg wird weiter aufgenommen: auch im zweiten Durchgang stehen Teile, im Takt mit dem ersten (zwischen dem Neubeginn und der ersten Schleifengrenze des Teils darf das alte Arrangement stehen). Mit dem Schalter aus wird nichts geschrieben. ⚠️ Ein Cycle-Sprung beendet die Aufnahme absichtlich. | |
| 10 | **Automation auf dem Canvas** (7a · 7b · 7c) | 4 min | Eine Synth-Spur öffnen → Seite „Automation“, einen Parameter wählen, zwei Punkte setzen. Zurück auf den Canvas. Dann in der Leiste „Draw automation“: auf der Spurzeile bei Takt 3 oben und bei Takt 7 unten tippen; einen Punkt halten und schieben; einen antippen; „Done“. | Die Kurve der Track-Seite liegt als Linie über den Teilen dieser Spur, an denselben Takten, auch nach dem Zoomen. Die Zeile zeigt den Parameter, den du auf der Track-Seite gewählt hast. Tippen setzt einen Punkt, Halten und Schieben verschiebt ihn auf ein Sechzehntel, Tippen auf einen Punkt löscht ihn, jede Berührung ist genau ein Undo. Nach „Done“ reagieren die Teile wieder auf Tipps. | |
| 11 | **Teil benennen, Spur duplizieren** (A8 · A7) | 3 min | Ein Teil antippen → Spur öffnen → Seite „Part“ → Name „Strophe“, Return. Dann Seite „Track“ → „Duplicate track“. Play. Undo. | Das Teil heißt auf dem Canvas „Strophe“. Unter der Spur steht „<Name> copy“ mit denselben Teilen und demselben Klang, ausgewählt; beide klingen. Ein Undo nimmt die Kopie ganz weg. Auf der Echoel-Spur gibt es den Knopf nicht. | |

Zum Schluss ein Satz, ohne nachzudenken: **Fühlt sich das Arrangement schon wie ein Werkzeug an,
das du für ein echtes Stück nehmen würdest — und was fehlt dir zuerst?** ______

**Wenn Zeit bleibt:** Gerätesitzung 1 (`docs/dev/DEVICE_SESSION_1_2026-10-17.md`, Klang, Puls,
Export, Unterbrechung) ist ebenfalls noch offen. Ihre Prüfungen 2–4 kann keine Sitzung ersetzen.

**Danach:** dieses Blatt (ein Foto reicht) und die Diagnose an Claude Code. Jede bestandene Zeile
wird an der Quelle als `VERIFIED-2026-10-xx` markiert (die Prüfschritte stehen dort als
`NEEDS-FOUNDER-VERIFY (A1)` … `(7b)`, `(A7)`, `(A8)`, gelistet von
`python3 scripts/founder-verify.py --since 26be2e6~1`). Jede nicht bestandene wird die nächste
Reparatur, vor jeder neuen Funktion.

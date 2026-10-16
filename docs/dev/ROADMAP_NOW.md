# Echoelmusic — Roadmap, 14. Oktober 2026

Die Reihenfolge für die nächsten Monate. Drei Dateien bleiben darüber:

- [`FOUNDER_PRODUCT_LAW.md`](FOUNDER_PRODUCT_LAW.md) sagt, was Echoel ist.
- [`ECHOELMUSIC_MASTER_PLAN.md`](ECHOELMUSIC_MASTER_PLAN.md) sagt das Modell. Seine WA1–WA4 sind geschlossen.
- [`FEATURE_STATUS.md`](FEATURE_STATUS.md) sagt, was heute läuft. Öffentliche Texte behaupten nur das.

[`ROADMAP.md`](ROADMAP.md) ist die ältere Ausführungsliste. Dieser Text gewinnt gegen sie, wo die Reihenfolge gemeint ist. Die Bauordnung vom 8. Oktober steht in [`scratchpads/PLAN_GMMW_2026-10-08.md`](../../scratchpads/PLAN_GMMW_2026-10-08.md) Abschnitt A2; viel davon ist gelandet (Absturz-Sweep, Audio-Editor, ein Teil der Generatoren, Bild-Schutz, Selbstheilung). Hier steht, was davon noch zählt und was nicht dazukommt.

Eine Scheibe, höchstens drei Dateien, ein Wächter, dann das Gerät. Keine neue Plattform, bevor die Zeile darüber auf dem iPhone stimmt.

## Jetzt

1. **Die Developer-Lizenz annehmen.** Ohne das bleibt der nächste Archive-Upload stehen. Das kann nur der Account Holder.
2. **Den Plugin-Branch zu Ende prüfen.** Compile, Quick Test und die volle Suite waren auf `7c21b9c` grün. Die blockierende Pipeline ist am Timeout von „Build for Testing“ hängen geblieben. Diesen Lauf klären. Keinen neuen Umfang auf den Branch legen.
3. **Am Gerät nachsehen,** was schon gebaut ist und noch niemand gehört oder gesehen hat. Zuerst Start und Absturz, dann der Audio-Editor (Welle, Fades, Trim, Slip), dann ob ein Take ins leere Stück wirklich klingt.
4. **Eine Hülle, nicht zwei.** Heute stehen unten fünf Wörter: Arrange, Mixer, Instrument, Browse, Piece. Das Drei-Telefon-Bild will Stück, Medien, Ausgabe. Eins wird das Ziel. Das andere bleibt eine Zeichnung. Beides zu bauen ist die Unübersichtlichkeit, die vermieden werden sollte.
5. **Eine Fläche für Switch Control.** Arrangement und Slip haben schon Namen. Die nächste stumme Fläche (Wellenform, Pads oder Bild) bekommt denselben Zugang. Das ist der Weg für Menschen, die nicht tippen können.

## Danach — das Instrument auf dem iPhone fertig

In dieser Ordnung, jede Zeile erst am Gerät, bevor die nächste anfängt:

1. Der Audio-Editor dort schließen, wo das Gerät noch nein sagt.
2. Generatoren, die schon eine Tür haben („Compose here“, „Edit a copy“, Sampler), am Gerät hören. Keine neue Tür, solange die vorhandene stumm ist.
3. Die Bildspur erst, wenn ein Aufrufer das vorbereitete Bild wirklich zeigt. Der Blitzschutz bleibt davor, nicht dahinter.
4. Selbstheilung nur noch dort, wo ein echtes Log eine Lücke zeigt. Kein weiterer Ausbau auf Vorrat.
5. App-Store-Text zuletzt, und nur mit Sätzen, die `FEATURE_STATUS.md` trägt. Die neue Lizenz und die Steuerregeln für Verkäufe gelten erst, wenn etwas kostet. StoreKit bleibt aus.

## Später — eine Tür nach der anderen

| Tür | Wann | Nicht vorher |
|---|---|---|
| Apple Watch | Wenn die Einbettung in Xcode geprüft ist | Vom Linux-Rechner raten |
| iPad | Wenn die Biosquelle nicht die Taschenlampe brauch | Die Familie in `project.yml` umlegen. Heute ist sie bewusst nur iPhone |
| visionOS | Wenn das iPhone-Bild am Gerät stimmt | Eine zweite App. Dieselbe Bildmaschine, ein räumlicher Ausgang |
| Weitere AUv3-Hosts | Wenn AUM noch einmal und ein zweiter Host dasselbe Preset halten | Hosting fremder Plugins als Beweis |
| VST3, CLAP | Wenn die AUv3-Tür ruhig ist | Eine zweite Codebasis |
| Andere Betriebssysteme | Über diese Türen | Ein Android-Neubau |
| Bezahlen (v1.1) | Wenn der Store-Text und die Lizenz stehen | Gruppenkäufe und Steuerdaten vorher |

## Nicht diese App

- Tauchfliege als Fahrzeug, Personenbeförderung, Airbus als Partner. Die Übergabe vom 5. Oktober ist eine Konzeptprüfung mit 37 offenen Befunden. Höchstens später ein OSC- oder MIDI-Signal an eine Anlage, die jemand anders zertifiziert.
- Neuralink und jede Gedankensteuerung. Keine Schnittstelle im Repo, kein Medizinprodukt.
- Wellness, Therapie, Diagnose, Heilfrequenzen.
- Eine zweite Navigation, ein Dashboard, ein „Session“-Knopf neben Play.

## Die eine offene Entscheidung

Ist das nächste Jahr das fertige iPhone-Instrument auf der heutigen Hülle, oder der Umbau auf Stück / Medien / Ausgabe? Plattformen, Tauchfliege und Implantat warten auf diese Antwort. Bis sie da ist, gilt die Spalte „Jetzt“ und die heutige Hülle.

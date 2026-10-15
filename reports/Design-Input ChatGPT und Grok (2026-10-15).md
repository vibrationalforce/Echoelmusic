# Design-Input von ChatGPT und Grok (2026-10-15)

**Gebrauch:** Kopf (§1) + EINEN Auftrag in einen NEUEN Chat, dazu **5 Screenshots** aus der
Gerätesitzung: (1) Instrument nach dem Start, (2) Arrange mit Teilen, (3) Mixer, (4) Device-Seite
einer Spur mit Plugin-Zeile, (5) Noten-Editor. Ohne Bilder nicht abschicken — dann kommen
allgemeine Tipps zurück. Antworten unverändert an Claude Code; dort wird gemessen, bevor
etwas übernommen wird. Nichts Privates mitschicken (keine Logs, keine Projekte mit fremder Musik).

---

## 1. Kopf (immer mitschicken)

Du bist DESIGN-PRÜFER, nicht Bauer. Echoelmusic ist eine iPhone-App (SwiftUI, dunkles Thema) für
Musikproduktion, Live-Performance und Bild/Licht: Instrument, Arrange, Mixer, Plugin-Host (AUv3),
Noten-Editor; der Puls über die Kamera ist eine optionale Modulationsquelle.
Die Screenshots zeigen den heutigen Stand (TestFlight 10.79.505).

**Feste Regeln, die du NICHT ändern sollst:** dunkles Thema · Radien höchstens 12 pt · keine
Glas-/Blur-Effekte, keine Glow-/Neon-Effekte, Schatten höchstens 8 pt · Übergänge 100–200 ms,
nur Deckkraft/Farbe · Grün nur für Körpersignale · jede Zahl ist ein Wertfeld (Name + Zahl +
Einheit), kein Drehknopf · Blitze höchstens 3 Hz · Schrift Atkinson Hyperlegible · keine neue
Bühne und kein neues Pop-up-Fenster (fünf Bühnen: Arrange · Mixer · Instrument · Browse · Piece).
Keine modulare Patch-Fläche. **Einhand- und Daumen-Skala** (Vorbild Koala), große Touch-Ziele
(44 pt, live 60 pt). **Sichtbare Hierarchie:** was auf den ersten Blick, was auf den zweiten, was
erst nach einem Tipp. **Barrierefreiheit:** große Schrift, VoiceOver, kein Zustand nur über Farbe.
Fokus ist professionelle Medienproduktion auf dem Daumen; Bio ist eine optionale Quelle.

**Bekannte Schwächen (gemessen):** zu viele verschiedene Abstände und Schriftgrößen; zwei Arten
von Überschriften; Bedienelemente mit 34–36 pt statt 44 pt; Rahmen von Bedienelementen kaum
sichtbar; das Instrument hat 8 Chips und viele Regler; Effekt-Plugins sind noch nicht einfügbar.

**Antwortformat (Pflicht):** höchstens 8 Punkte; jeder Punkt: welcher Screenshot · was genau ·
warum (Lesbarkeit, Treffsicherheit, Hierarchie, Barrierefreiheit) · kleinster Änderungsschritt.
Kein Code. Keine Marketing- oder Wellness-Sprache.

---

## 2. Auftrag C — für ChatGPT: die Richtung zeigen

1. **Ein Bild je Bühne:** Entwirf für Screenshot 1 (Instrument) und 3 (Mixer) je EIN Mockup im
   gleichen dunklen Stil, das professioneller und ruhiger wirkt — gleiche Funktionen, weniger
   gleichzeitig sichtbar. Halte die festen Regeln ein.
2. **Hierarchie:** Was soll auf dem Instrument-Bildschirm auf den ersten Blick, was auf den zweiten,
   was erst nach einem Tipp sichtbar sein? Drei Ebenen, je höchstens fünf Elemente.
3. **Plugin-Kachel:** Wie sieht auf der Device-Seite (Screenshot 4) eine Kachel für ein
   Instrument-Plugin und eine für ein Effekt-Plugin aus — Name, Hersteller, Öffnen, Umgehen
   (Bypass), Entfernen — wie es Logic für iPad und AUM machen, aber in diesem Stil?
4. **Noten-Editor (Screenshot 5):** Was macht ihn für einen Finger treffsicherer?
Am Ende: eine Tabelle Bühne · wichtigste Änderung · warum.

## 3. Auftrag G — für Grok: das Design angreifen

1. **Erste Sekunde:** Was versteht ein Profi-Produzent auf jedem der 5 Screenshots NICHT sofort?
   Je Bild der größte Stolperstein.
2. **Vergleich:** Leg jeden Screenshot neben das entsprechende Bild aus Ableton Note, Logic Pro
   für iPad, Koala Sampler oder AUM. Wo wirkt Echoel amateurhaft — konkret (Abstand, Ausrichtung,
   Beschriftung, Dichte), nicht „fühlt sich billig an"?
3. **Barrierefreiheit:** Wo scheitert jemand mit großer Schrift, VoiceOver oder schwacher Sicht?
4. **Was nicht ändern:** Welche zwei Dinge sind schon gut und dürfen beim Umbau nicht verloren gehen?
Am Ende: EIN Satz, welche eine Änderung den größten Profi-Eindruck bringt.

---

## 4. Rücklauf: fünf KI-Mockups (2026-10-15) — gemessen

Eingang: fünf Entwürfe (Arrange · Mixer · Instrument · Device · Noten-Editor), erkennbar KI-erzeugt
(jede Seite eine andere Leiste unten; Funktionen, die es nicht gibt). Als RICHTUNG gelesen, nicht
als Vorlage.

### Übernehmen (je eine Scheibe, kein neuer Screen)
| # | Muster aus dem Entwurf | Heute im Code | Scheibe |
|---|---|---|---|
| U1 | **Noten-Editor: Werkzeug-Wahl Add · Move · Lengthen** statt 0,3-s-Halten für alles | jede Bearbeitung braucht Halten (`PartNoteEditor` `LongPressGesture(minimumDuration: 0.3)`) | **EP-3b**: im Modus Move/Lengthen zieht ein Finger auf einer Note sofort; Scrollen bleibt auf leerer Fläche |
| U2 | **Noten-Inspektor unten: Velocity · Dauer · Start · Tonhöhe** als Zahlenfelder | nur Velocity (`NoteVelocityRow`) | **N-F1**: Start/Dauer/Tonhöhe der gewählten Note als `EchoelValueField`, ein Undo-Schritt |
| U3 | **Arrange-Teilleiste: Start + Länge + Snap** sichtbar | nur „Starts at bar" (`SelectedPartBar.swift:980`), ganze Takte | **EP-4** (geplant): Start Takt.Schlag.16tel, Länge, Snap-Wahl |
| U4 | **Device-Kette: Zeile je Slot mit Öffnen · Umgehen · Entfernen + leerer Slot** | Instrument-Zeile mit „Open plugin"; Effekt-Slots klingen nicht | **H6-6** (geplant): genau diese Zeile |
| U5 | **Mixer: Pegel und Pan als Zahl über dem Meter, Master mit LUFS** | Pegel/Pan als Felder, Meter `TrackLevelMeter` (B5) | Prüfen am Gerät, ob die Zahl auf den ersten Blick lesbar ist — sonst Anordnung, kein neues Element |
| U6 | **Instrument: Zeile = Name + Unterzeile + Wert rechts**, einheitlich | `EchoelValueField` hat Name + Wert; Unterzeilen uneinheitlich | Teil von D-System (Regel 1/7), Fläche für Fläche |

### Nicht übernehmen (mit Grund)
- **Schieberegler** auf der Device-Seite und Pan-Regler im Mixer — Regel: jede Zahl ist ein Wertfeld.
- **„Create from Within / Let the moment shape the music"** — Deko-Text, Uncodixfy-Verbot.
- **Kleine Großbuchstaben-Überschriften** („DEVICE CHAIN") — Eyebrow-Labels, verboten; `groupHeader`.
- **Je Bildschirm eine eigene Leiste unten** (Tracks/Mix/Settings, Editor/Lyrics …) — die fünf Bühnen bleiben die EINE Leiste.
- **Vocal-/Backing-Vox-Spuren, Lyrics, Echoel als Delay** — gibt es nicht (kein Mikrofon seit #1302, `LyricsModel` tot, Echoel-AUv3 ist ein Instrument) — darf auch in keinem Promo-Bild auftauchen.
- **Lila Akzent** — der Akzent bleibt Grün und nur für Körpersignale.
- **Bunte Noten nach Zufall** — bei uns trägt die Farbe die Tonhöhe (`SpectralColor`), das bleibt.

### Reihenfolge
U1 (EP-3b) und U2 (N-F1) zuerst — sie treffen dein Urteil „Editing zu ungenau" direkt. Dann U3
(EP-4). U4 mit H6-5/6. U5/U6 nach den echten Screenshots.

---

## 5. Zweite Runde (nach Build 10.79.508) — nur zum Bearbeiten von MIDI-Clips

Vorher: Kopf (§1) wie oben, dazu 4 ECHTE Bildschirmaufnahmen aus 10.79.508: (a) Noten-Editor mit
einer gewählten Note und den drei Zahlenfeldern, (b) Teil-Leiste mit Starts at bar/beat, Length,
Repeat, (c) Arrange mit mehreren Teilen, (d) ein 20-s-Bildschirmvideo: Note antippen → ziehen →
länger ziehen → Undo.

**Auftrag G2 — Grok: die Reibung finden.** Spiele denselben Ablauf gedanklich in Ableton Note,
Logic Pro für iPad (Piano Roll) und Koala nach: eine 4-Takt-Bassline eingeben, zwei Noten
verschieben, eine verlängern, den Teil 4× wiederholen, einen Takt später starten lassen. Zähle je
App die Taps und Gesten. Wo braucht Echoel mehr Schritte, wo ist es unklar, was ein Finger gerade
tut? Höchstens 8 Punkte, je: Schritt · Echoel-Taps · Vorbild-Taps · kleinster Fix. Kein Code.

**Auftrag C2 — ChatGPT: den Editor ruhig machen.** Entwirf auf Basis von Bild (a) und (b) EIN
Mockup des Noten-Editors im selben dunklen Stil: wo sitzen Werkzeug-Wahl (Add · Move · Lengthen),
Raster-Wahl, Zoom, Undo und der Noten-Inspektor, sodass alles mit dem Daumen erreichbar ist und
das Raster möglichst groß bleibt? Feste Regeln aus §1 (keine Schieberegler, keine eigene untere
Leiste, keine Deko-Texte). Dazu drei Sätze: was auf den ersten Blick, was auf den zweiten, was
erst nach einem Tipp.

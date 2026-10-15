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

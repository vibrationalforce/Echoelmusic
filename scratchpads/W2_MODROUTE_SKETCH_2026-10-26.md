# W2 Sketch — ModRoute (BodyFrame → Parameter)
**Datum:** 2026-10-26  
**Nach:** W1-Rest + Publisher-Port

## Ziel
ModRoute im Song: Quelle (BodyFrame.heartRate / hrv / coherence) → Parameter, mit Tiefe und Kurve. Im Render-Pass, feste Obergrenze. Format v3 + Migration.

## Scope (mehrere Scheiben)
1. ModRoute-Struktur definieren (Quelle, Ziel, Tiefe, Kurve).
2. Song-Model erweitern + Format v3 Migration (leere Routen als Default).
3. Eine Route im Render anwenden.
4. Golden-Test für Roundtrip.

## Gesetze
- PatternEngine bleibt Clock-Authority.
- Keine Claims ohne Device.
- Scheiben ≤3 Dateien.

**Status:** Skizze. Nächste nach Publisher.

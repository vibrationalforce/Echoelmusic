# Gap Closure Plan — Closing Gaps to Echoelmusic Vision
**Datum:** 2026-10-26  
**Mandat:** Alle Lücken schließen (soweit ohne Device/Founder-Gate möglich, dann vorbereiten).

## Priorisierte Lücken (aus Deep Audit)

1. **W1-Rest: Sichtbare BodyFrame-Anzeige + Aus-Schalter + a11y**  
   - Ziel: Puls / HRV / Kohärenz sichtbar, Toggle, vollständige Accessibility.  
   - Dateien ≤3. CI → Device-Verify.  
   - Status: Plan klar, Implementierung nächster konkreter Schritt.

2. **W2: ModRoute im Song (Body → Parameter)**  
   - Format v3 + Migration.  
   - Sketch existiert.  
   - Nach W1.

3. **One Session Ownership**  
   - DMMWProject als einzigen Owner messen und angleichen.  
   - Census-basiert, schrittweise.

4. **W4 Verbindungen + Spatial Aufrufer**  
   - Licht/OSC/ADM-OSC als Modul (F25).  
   - Render-Kerne anschließen.

5. **W4+ Network Jitter / Master Clock**  
   - Dokumentiert, Voraussetzungen F25 + Audio-Thread.  
   - Nicht jetzt bauen.

6. **W7 Video Recovery**  
   - Capture/Edit als erprobter Kern portieren (historisch riskant).

7. **AI Planner Tür**  
   - Assistive, nie im Callback.

## Sofort umsetzbar (Docs / Vorbereitung)
- Diese Closure-Plan-Datei.  
- Accessibility-Anforderungen in W1-Rest-Definition festziehen.  
- Format-v3-Sketch weiter detaillieren.  
- Handover mit Closure-Plan verlinken.

## Was Device / Founder braucht
- Alle Implementierungen: CI + Device-Verify.  
- F25, F24, Store, final Merges.

## Nächster konkreter Schritt
W1-Rest als implementierbare Scheibe definieren (View + Wiring + Toggle + a11y). Claude oder nächste Session kann sie direkt bauen.

**Regeln unverändert.** Scheiben ≤3 Dateien, keine Claims, Audio-Thread heilig.

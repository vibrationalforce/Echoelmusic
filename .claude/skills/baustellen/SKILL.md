# Baustellen — board-getriebener Closeout-Loop (ECC-Muster, Echoel-eigen)

Adoptiert aus „Everything Claude Code" (Founder-Reel 2026-07-17) sind die MUSTER —
Verification-Loop + Board-Orchestrierung — nicht das Paket (Entscheid in
decisions.csv 2026-07-17). Das Board ist `scratchpads/BAUSTELLEN_BOARD.md`; beide liegen im
privaten Repo `echoelmusic-intern`.

## Das Gesetz des Loops

**Keine Baustelle gilt als geschlossen ohne ihren Verify-Weg.** Der Verify-Weg
steht als Spalte am Board und ist fast immer der Founder-Gerätetest (Modus-Lehre:
sein Test IST das Verify; CI-grün ist nur das Gate davor). „Code gepusht" ≠ fertig.

## Loop (jede Session / jeder Heartbeat)

1. **Board lesen** (`echoelmusic-intern/scratchpads/BAUSTELLEN_BOARD.md`) — VOR dem Task-Tool; das
   Board ist die konsolidierte Wahrheit, die Task-Liste die Historie.
2. **Oberste AKTIV-Zeile ziehen**, deren nächste Slice nicht blockiert ist.
   Founder-Direktiven des Tages überstimmen die Reihenfolge sofort.
3. **Slice bauen** (integriert, nicht Ein-Punkt — Founder-Verdikt 07-17), Route-
   Spalte beachten (Reviewer-Agent, Plan-Dokument in `echoelmusic-intern/scratchpads/`, Copy-Gesetz).
4. **Gates und Deploy.** Echoel Studio: der Lauf `Echoel Studio` auf genau dem Commit
   (Conclusion), dann TestFlight nach dem Skill `studio-release` (`EchoelStudio/RELEASE`,
   genau fünf Prüfungen als Test-Bitten „öffne X, prüfe Y"). Nur wenn die Scheibe
   `Sources/` oder `Tests/` berührt: zusätzlich Xcode Compile Check und der CI/CD-Schritt
   `Build for Testing`. `.deploy/release` gehört der eingefrorenen früheren App.
5. **Board aktualisieren**: Slice-Fortschritt, Verify-Spalte (CI ✓ / Gerät offen /
   Founder ✓ + Build-Nummer), Erledigtes in die ERLEDIGT-Tabelle (nie löschen),
   Blockiertes nach BLOCKIERT mit dem, worauf es wartet.
6. **Lernen persistieren** (im privaten Repo `echoelmusic-intern`): echte Dead-Ends/Playbooks →
   `scratchpads/HARNESS_LEDGER.md` (unser Instinct-System), Entscheide → `decisions.csv` +
   `memory/decisions.md`.

## Board-Pflege-Regeln

- Neue Founder-Asks landen SOFORT als Zeile (Quelle verbatim-Kern + Datum).
- Jede Zeile braucht: Nächste Slice (konkret, heute baubar) + Verify-Weg
  (was der Founder auf dem Gerät sieht/hört). Fehlt einer, ist die Zeile
  unfertig — zuerst schärfen.
- BLOCKIERT-Zeilen nennen exakt das fehlende Artefakt (z.B. „Log nach Neustart");
  bei jedem Founder-Kontakt die oberste Blockade EINMAL freundlich erinnern.
- Maximal ~6 AKTIV-Zeilen; der Rest wartet in OFFEN (Fokus schlägt Breite).

## Grenzen

Ersetzt weder Council (Entscheidungen) noch Ralph-Loop (Build-Disziplin) noch die
harten Gesetze (Audio-Thread, Rausch-Triade, Sheet-Decke, 10-Hz-Regel). Kein
Import externer Skill-Pakete ohne Founder-Entscheid.

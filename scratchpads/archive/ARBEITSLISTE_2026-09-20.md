# Arbeitsliste 2026-09-20 — „sammle alles was getan werden muss und arbeite es ab"

Gesammelt aus: Task-Liste (#22–#62), `scratchpads/BAUSTELLEN_BOARD.md`,
`scratchpads/DEEP_AUDIT_UNIVERSUM_2026-09-20.md`, `python3 scripts/founder-verify.py`,
den acht stehenden Prüfern und `doctor --section A/B/C/D`.

**Sortiert nach WER es schließen kann.** Das ist die Achse, die zählt: die Liste liest sich
doppelt so lang wie sie ist, solange Geräte- und Founder-Posten zwischen den baubaren stehen.

---

## A — MEINE (baubar in dieser Sitzung, kein Gerät, kein Founder)

| # | Posten | Stand |
|---|---|---|
| A1 | **B1 Universelle Modulation** — `ModDestinationKey.all` von 1 auf 12 Ziele, projiziert aus `PolySynthVoice.automatableBases` | **JETZT** |
| A2 | **B3 `ImmersiveStageView` betüren** | offen — ⚠️ Ship-Gate 4 sagt „demonstrierbar, nicht erforderlich"; bewusst türlos. Kein Defekt ⇒ NICHT ohne Founder-Frage |
| A3 | #62 sechs Meta-Descriptions > 160 Zeichen (architecture 261, tools 248, artist 225, brainstorming 201, resolume-osc 182, artnet-sacn 164) | offen, klein |
| A4 | Gate-Lesung nach jedem Push | laufend |

## B — FOUNDER-GERÄT (keine Sitzung kann sie schließen)

- **149 OPEN asks in 124 Dateien.** Nicht hier abgeschrieben — die Liste DRUCKT
  `python3 scripts/founder-verify.py`, nach Bereichen (AUDIO allein 50). Eine Abschrift wäre
  #416 und am nächsten Commit veraltet.
- Task #34 — vier Genre-A/Bs auf dem Gerät (Ohr).
- Board A10 (48 kHz Host-Rate, GarageBand-Hälfte offen) · A11 (CPU ≈20 pp, braucht Xcode-Profil)
  · O4–O8.
- Ship-Gate 1 (Klang) und 5 (Stabilität) — beide sensorisch, beide nur am Gerät.

## C — FOUNDER-ENTSCHEIDUNG (nicht meine, ausdrücklich)

- Task #27 — Markenzeile „Create from Within" vs. „multidimensional".
- Board A12 — Drone-beim-Laden. Klangentscheidung.
- Board A13 — zweite `aumi`-Komponente aus derselben Extension (Council, dann eine Scheibe).
- **B2 Signature** (`BioSessionSummary` ↔ `Project`) — kehrt „MeditationView bleibt bewusst
  türlos" um.
- Branch-Konsolidierung und Store-Texte — vom Founder ausdrücklich reserviert.

## D — BLOCKIERT (kein Weg, bis etwas anderes existiert)

- Task #58 — `gnawaGuembri` (kulturelle Zuschreibung + `BassGrammar` existiert nicht),
  `koraOstinato` (Regal existiert nicht).
- Task #40 — Musikalität/intelligente Parameter: kein sicherer nicht-geräte-gebundener Slice
  gefunden. ⚠️ A1 ist die Ausnahme, die es GIBT: es macht Parameter nicht klüger, es macht sie
  vom Körper erreichbar.

## E — FOUNDER-GATED BEFUNDE (berichten, nicht editieren — Stand unverändert)

`auto-merge-claude.yml` wartet auf kein Gate · neun Stellen in `ci.yml`/`benchmark.yml`/
`full-tests.yml`, an denen ein Build-Fehler nichts rot färben kann · `ci.yml:290/291` filtert
das nicht existierende `ComprehensiveTestSuite` · verwaiste `Info.plist`-Schlüssel
(`NSMicrophoneUsageDescription`, `NSPhotoLibraryAddUsageDescription`, die Frontlinsen-Hälfte von
`NSCameraUsageDescription`) · `project.yml:296` veraltete Watch-Route · `CLAUDE.md` liegt in
keinem Workflow-Pfadfilter.

## F — UMGEBUNG (nie berichtet, gehört in jeden Statusbericht)

`context7` und `perplexity` brauchen eine Autorisierung, die in einer nicht-interaktiven
Sitzung nicht geht. `firecrawl`, `gsd-memory`, `supabase`, `vibekanban`, `xcode-build`
konnten sich nicht verbinden — **Verbindungsfehler, keine fehlende Fähigkeit.**

---

## Die Reihenfolge, in der ich A abarbeite

1. **A1 (B1)** — die einzige Scheibe, die eine PRODUKT-Behauptung wahr macht: „alle Parameter
   vom Biofeedback modulierbar" war bis heute ein Ziel von fünfzehn.
2. **A3** — sechs Meta-Descriptions, rein redaktionell.
3. **A2** nur nach einer Founder-Frage; es ist keine Lücke, es ist eine Entscheidung.

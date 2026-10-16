# GSIDMMW — Audit-Übergabe 2026-10-16 (gemessen, nicht übernommen)

**Quelle.** Founder-Paste „ECHOELMUSIC — GSIDMMW · Deep Research, statisches Audit und
Implementierungsauftrag für Claude Code", Stand 2026-10-16, Prüfstand `main` = `32b65affc`
und Branch-HEAD `4dbcfc6`. Fremdes Modell-Output → Lernmodus: jede Behauptung ist eine
Hypothese, gemessen an HEAD `02f36f1`. Der Text selbst steht hier NICHT wörtlich; nur das
Gemessene und die Paketliste.

**Founder-Entscheidung (aus der Paste, als Founder-Nachricht gesendet):** oberstes Ziel
GSIDMMW = Generative Superintelligence Distributed Multidimensional Multimedia Workstation.
Verankert in `docs/dev/FOUNDER_PRODUCT_LAW.md` §1 und `ECHOELMUSIC_MASTER_PLAN.md` §1.
Nach außen gilt weiter: kein „superintelligence" in Website, Store-Text, Katalog
(`TheCopyMakesNoHealthClaimTests`, 353e14f).

## Befunde F1–F8 — gemessen

| # | Behauptung | Messung an `02f36f1` | Verdikt |
|---|---|---|---|
| F1 | Masterplan §5 und `EchoelCommand.swift` sagen „no caller", obwohl `AgentReportBanner.describePiece` `FoundationModelsBrain()` konstruiert | beide Zeilen vorhanden; Konstruktion `AgentReportBanner.swift:62-64` | BESTÄTIGT → behoben (Paket A) |
| F1b | `FeatureFlags.echoelAI` hat null Leser | `git grep -n "FeatureFlags.echoelAI" -- Sources \| grep -v ': *//'` → 0 außerhalb der Deklaration | BESTÄTIGT, bleibt so |
| F2 | späte Beschreibung landet nach Projektwechsel im falschen Stück | `describe` schrieb `notice` nach `await brain.respond` ohne Bindung an `documentGeneration` | BESTÄTIGT → behoben (Paket B) |
| F3 | keine Deadline, kein Abbruch; `isWorking` über den ganzen Modellaufruf | `isWorking = true` + `defer` um `respond` | BESTÄTIGT → behoben (Paket B) |
| F4 | kein Modell schlägt Aktionen vor; `EchoelPostedPlanner` reicht typisierte Aktionen durch | `run(...)` plant nur mit `EchoelPostedPlanner(actions:)` | BESTÄTIGT, offen (Paket C) |
| F5 | Snapshot bindet nur Auswahl + `documentGeneration` | `EchoelProjectSnapshot` | BESTÄTIGT, offen (Paket D) |
| F6 | `ParameterToolCore.set` liest nicht zurück, kein Undo | so in PLAN_GMMW AI-7a/b schon benannt | BESTÄTIGT, offen (Paket D) |
| F7 | keine dauerhafte Job-/Herkunftskette | nicht einzeln nachgemessen | UNVERIFIZIERT, offen (Paket E) |
| F8 | geteiltes Dokument entfernt `sessionEnvelope`; Peer-Pfad ist kein Audiotransport | nicht einzeln nachgemessen | UNVERIFIZIERT, offen (Paket F) |

Nicht gemessen, weil ohne Netz aus der Sandbox: die Webquellen Q1–Q12 (Link Audio, Magenta RT 2,
Lyria RealTime). Sie sind Recherche-Hinweise, keine Integrationszusage.

## Pakete — Stand

- **A** Ziel + Status wahr verankern — ERLEDIGT (Law §1, Masterplan §1 + §5-Zeile, PLAN_GMMW-Verweis,
  ULTRAMASTERPLAN als untergeordnet markiert, `EchoelCommand.swift`-Kopf).
- **B** Beschreibung gehört bis zum Ende zum richtigen Stück — GEBAUT, Gates offen: Ticket +
  `documentGeneration` nach jedem await, Stop ≠ Close, Deadline 45 s (`describeDeadline`),
  `isModelBusy` verhindert gestapelte Modellarbeit; Wächter `TheAgentDescribesThePieceTests` 5–9.
  Gerät offen: echter Modellaufruf, Stop unter Last.
- **C** modellgestützter Planner — **C1 GEBAUT (`183650e`)**: `EchoelModelPlanner`, drei erlaubte
  Befehle, max. 3 Schritte, nur `"selected"` als Ziel, Frage statt Raten (`needsAnswer`),
  `planRefused` mit Grund; Wächter `TheModelPlansOnlyWhatItMayTests`. **KEINE TÜR.** C2 = Tür:
  Kandidat ist ein App-Intent „Ask Echoel" mit Freitext über die vorhandene Inbox/Desk-Bahn (kein
  neues UI). ⚠️ Er braucht eine ZWEITE Produktions-Konstruktion von `FoundationModelsBrain`, die
  `TheOnDeviceModelHasOneGateTests` heute verbietet („exactly ONE") — das ist bewusst Gesetz,
  also Council vor dem Umbau, nicht still nachziehen.
- **D** `agentEligible`/`applyAgent` mit Rücklesen + Ziel-Revisionen (PLAN_GMMW AI-7a/b).
- **E** generierte Ergebnisse als normale Clips mit Herkunft (Erweiterung von `keepComposerTake`).
- **F** Medienzeit (M1b), Projektpaket mit Medien, Zusammenarbeit, LAN-Audio-Studie (Link Audio) —
  jede neue Abhängigkeit Founder-Gate.
- **G** externe Generatoren (Magenta RT 2 auf Apple-Silicon-Mac, Lyria RealTime) erst nach E.

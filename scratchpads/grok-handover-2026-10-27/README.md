# Claude — geprüfte Grok-Übergabe und ausführbares G-A-Paket

Stand: **27.10.2026, Europe/Madrid**. Auftrag: Groks Arbeit erneut prüfen, fehlende
Referenzmaterialien ergänzen und alles strukturiert im Repository übergeben.
Gemessene Basis: `main` **31ce86372ed852626f186f91d2984996bb958b89**.
Arbeitsbranch: `codex/claude-grok-handover-2026-10-27`.

**Hier beginnen.** Dieses Paket ergänzt die Übergabe vom 26.10. und korrigiert
Groks ursprünglichen README-Status. Es verändert keinen Produktionscode und löst
keinen Release aus. Claude bleibt der integrierende Produktionsschreiber.

## 1. Lieferumfang

| Datei | Zweck |
|---|---|
| [AUDIT.md](AUDIT.md) | Groks tatsächliche Änderungen, belegte Lücken und Korrekturen |
| [CONTRACT.md](../../.claude/skills/g-a-body-modulation/references/CONTRACT.md) | W1/W2: Zustände, Generationen, Modulation, Format, Export, Permissions |
| [FIXTURES.json](../../.claude/skills/g-a-body-modulation/references/FIXTURES.json) | Feste Sollwerte mit Begründung; keine echten Körperdaten |
| [reference.py](../../.claude/skills/g-a-body-modulation/references/reference.py) | Ausführbare Offline-Referenz, Standardbibliothek, mit negativen Kontrollen |
| [VALIDATION.json](VALIDATION.json) | Tatsächliche Prüfresultate, Dateihashes und offene Integrationsfälle |
| [DOCTOR_STATUS.md](DOCTOR_STATUS.md) | Ausgeführter Doctor, Befundgruppen und Reichweite |

Der vorhandene [G-A-Einstieg](../../.claude/skills/g-a-body-modulation/SKILL.md)
zeigt jetzt auf vorhandene Ressourcen. **Keine B/C/D-Skills oder fertigen B/C/D-Pakete
behaupten:** sie sind im geprüften Stand nicht geliefert. Ihre Aufträge bleiben gültig.

## 2. Sofort ausführbar

Aus dem Repository-Root:

```bash
python3 .claude/skills/g-a-body-modulation/references/reference.py --selftest
python3 .claude/skills/g-a-body-modulation/references/reference.py --selftest --json
python3 scripts/doctor.py
```

Referenz: Exit 0 nur bei bestandenen ausgeführten Prüfungen. Doctor: auf der
Basis Exit 1, drei kritische Gruppen; [Einordnung](DOCTOR_STATUS.md).
Python-PASS bedeutet **Referenzvertrag geprüft**, nicht Swift-/iPhone-PASS.
Keine neuen Core-, App-, AUv3- oder Gerätetests durch dieses Paket ausgeführt.
Die Produktions-Abnahmekriterien bleiben NOT_RUN.

## 3. Bestehende Arbeit zusammenführen

1. Aktuellen Branch, `git status`, `main` und relevante PR-Diffs lesen. Bei anderem
   HEAD Befunde gegenprüfen; niemals altes Material blind anwenden.
2. [PR #430](https://github.com/vibrationalforce/Echoelmusic/pull/430) ist weiterhin
   offen. G4a-Codecommit `21a22939c0cd4f85c120bfc2d8fb89f98ebaddf3` ist **nicht**
   in der hier gemessenen main-Basis. Übernahme auf Doppelarbeit und Konflikte prüfen.
3. Die drei Dokumente von #430 sind bis zu dessen Integration über feste Links zu lesen:
   [Grok-Aufträge G-A–D](https://github.com/vibrationalforce/Echoelmusic/blob/8f4cd9611833e3909d398056fe139d18ee7eb182/scratchpads/GROK_TESTFLIGHT_AUFTRAEGE_2026-10-26.md),
   [G4/G3/G2/AU-Hintergrund](https://github.com/vibrationalforce/Echoelmusic/blob/8f4cd9611833e3909d398056fe139d18ee7eb182/scratchpads/CLAUDE_TESTFLIGHT_HANDOVER_2026-10-26.md),
   [75 geplante Abnahmefälle](https://github.com/vibrationalforce/Echoelmusic/blob/8f4cd9611833e3909d398056fe139d18ee7eb182/scratchpads/TESTFLIGHT_ACCEPTANCE_2026-10-26.json).
   Nicht durch Referenztests automatisch auf PASS setzen und nicht duplizieren.
4. #428/#429 betreffen Audit/Claims. Separat reviewen; alte #422–#424 nicht ungeprüft
   als Scope-Autorität mergen. Keine pauschale Repo-Bereinigung in dieser Integration.

## 4. Reihenfolge für Claude

Die neueste vollständige [W0–W10-Vision](../PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md)
und das [Produktgesetz](../../docs/dev/FOUNDER_PRODUCT_LAW.md) bestimmen den Umfang;
[Studio-Gesetze](../../EchoelStudio/CLAUDE.md) die Implementierung.
G-A vorbereitet bedeutet nicht, dass vorhandene Datenverlust-/Stimmenfehler verschwinden.

| Schritt | Ergebnis / Abnahme |
|---|---|
| S0 | Basis und #430 abgleichen; G4a nur einmal übernehmen |
| S1 / G4b | Capture → Store-Annahme → Dateisave trennen; `syncedState` erst nach Annahme; Fehler sichtbar, letzten gültigen Zustand erhalten |
| S2 / G3a–b | Sampler-Stimmen mit Handles/Generationen, dann Kernel-Lebenszyklus; gleich hohe Noten dürfen sich nicht versehentlich beenden |
| S3 / G2a–b | MIDI-Quellenidentität und gemeinsame Notenhalter; synthetische Retrigger korrekt aufnehmen |
| S4 | AU-Renderfehler an Offline-Export weiterreichen; fehlerhafte Datei nicht als Erfolg melden |
| A1 | Reine Körperzustände + Swift-Verhaltenstests aus S*-Vektoren; je Metrik eigene Gültigkeit |
| A2 | MainActor-Besitzer und echte Produzenten; späte Mess-/Permission-Callbacks tokenprüfen; UI ohne Platzhalter |
| A3 | Quell-/Zieladressierung und ModRoute-Schema finalisieren; Format 3, vorhandene Golden-Fixtures bewahren, keine Default-Routen |
| A4 | Vorkompilierte begrenzte Routen, Automation/Taper, sichere Snapshots, Sample-Rampen, Frozen-Export |
| A5 | Vollständigen sichtbaren Workflow und fünf passende Geräteschritte abnehmen |

Jeder Schritt besteht gegebenenfalls aus mehreren Scheiben **höchstens drei Dateien
pro Commit**. Eine neue Command-Familie braucht Case, apply, Katalog und Verhaltenstest:
die Grenze durch vorbereitende Typ-/Test-Scheiben einhalten, keine Pflicht weglassen.
G-A-Referenzarbeit kann unabhängig erfolgen, während eine Geräteabnahme wartet.
Für jede Scheibe passenden Test und tatsächlich gebauten SHA dokumentieren.

Danach G-B (W3/W4), G-C (W5/W8), G-D (W7/W9/W10) mit denselben Anforderungen ausführen:
Vertrag + Datenvektoren + überprüfbares Referenzergebnis. Vorhandene AgentSession/
AgentTools ausbauen, keinen zweiten Assistenten bauen. Produktionskamera und Sensoren
brauchen einen gemeinsamen Ressourcenvertrag. Netzwerk und Biometrie-Egress bleiben
explizit einschaltbar. W6 bleibt mit dem vollständigen Releaseumfang verzahnt;
Preis/Verträge/Store-Abgabe sind eigene Founder-Entscheidungen.

## 5. Korrigierte Statusgrenzen

- **W0:** Code für Einstieg/Loop/Overdub vorhanden; „erledigt“ ersetzt keine passende
  Build-/Geräteabnahme. Im erneut gelesenen Fenster der letzten 50 Workflow-Runs ist
  der jüngste Studio-TestFlight-Lauf weiter Run `40179831237`, Runnummer 10, Quell-SHA
  `5eeeb3e35313eed66350b13d973ba59adbe5b0b2`. Ein Upload 10011 ist dort nicht belegt.
- **W1/W2:** Platzhalter und Skizzen; dieses Paket ergänzt Verträge und Tests der
  Referenz, nicht den Sensor-/Audiopfad. Konstante Körperwerte vor Integration entfernen.
- **W10:** Menü, lokaler FoundationModels-Assistent, Befehlstür und Songwechsel-Schutz
  existieren. Vollständige generative Workflows sind damit noch nicht abgenommen.
- **CI #430:** [Studio-PR-Lauf](https://github.com/vibrationalforce/Echoelmusic/actions/runs/40376079505)
  inzwischen `completed/success`, gemeldeter Head `8f4cd961`. Das ist der ältere
  PR-Lauf, **kein Test dieses Pakets** und kein neuer TestFlight-Upload.

## 6. Startauftrag

> Lies diesen Einstieg, AUDIT.md und VALIDATION.json auf dem veröffentlichten
> Übergabebranch. Vergleiche deinen Stand mit main und PR #430. Erhalte die volle
> W0–W10-Vision und arbeite als ein Produktionsschreiber. Übernimm G4a nur einmal;
> bearbeite G4b/G3/G2/AU und dann G-A in kleinen geprüften Scheiben. Nutze die
> Python-Vektoren als zusätzliche Sollwerte für echte Swift-Verhaltenstests.
> Policy-Zahlen und Quellnamen des Referenzmodells sind gekennzeichnete Vorschläge,
> kein eingefrorener Produktstandard. Schließe Produzent, Zustand, Engine, Bedienung,
> Undo, Save/Recall und Export durchgängig. Keine Platzhalter oder ungemessenen
> Geräte-/Latenz-/Releasebehauptungen. Dokumentiere pro Scheibe Ergebnis, SHA und
> verbleibende Abnahme. Führe anschließend G-B/C/D bis zum vollständigen beauftragten
> Umfang fort.

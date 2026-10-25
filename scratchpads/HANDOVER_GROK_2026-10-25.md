# Handover Protocol — Grok Team → Claude / Founder
**Datum:** 2026-10-25 (Sonntag, ~13:15 CET)  
**Von:** Grok-Team (Benjamin, Harper, Lucas, Grok)  
**An:** Claude-Session (Token-Limit bis Mittwoch 09:00 UTC / 11:00 CET) + Founder  
**Branch:** `claude/echoelmusic-review-optimize-u5jjpd` (HEAD: 8c2e010 — HRV normalization port)

## Was bereits erledigt ist (heute + letzte Tage)
- Merge-Konflikt in `docs/dev/FOUNDER_INBOX.md` gelöst: main reingeholt, neuere Fassung (GM34–36 + Nachträge 23.10. abends) behalten. Commit `37f99c23a`.
- W0 abgeschlossen: Bildschirmtasten/Pads/Erststart (Build 10010) + Song-Loop / Overdub / Record ohne Vorbereitung (Build 10011 geplant).
- W1.1 / W1.2 gestartet: rPPG-Conditioning, PulsePeriodEstimator, HRV-Coherence, HRV-Metrics (RMSSD/SDNN/pNN50), RR-Interval-Hygiene, HRV-Normalization nach EchoelDSP portiert (Foundation-only, Tests mit). Mehrere Commits heute 09:35–09:40 UTC.
- Plan aktualisiert: `scratchpads/PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md` — 1.0 enthält jetzt **alles** (inkl. Video W7, Voice FX W8, Face/Motion W9, Generative Intelligence W10). Scope-Cuts von Sep 2026 aufgehoben; Engineering-Lektionen bleiben.
- Auto-Merge nach Konfliktlösung wieder grün (laut Session-Notiz).

## Aktueller Stand
- **HEAD:** 8c2e010958a24cbde71dd466048b418976831146 (feat(dsp): port HRV normalization...)
- **Build 10010:** hochgeladen, Apple verarbeitet noch (App Store Connect — nur Founder sichtbar).
- **Offene Docs-PRs auf main:** #422, #423, #424 (Roadmap_NOW, Pitch, Astra-Zielbild) — alle docs-only, reviewed, merge-bereit.
- **Issue #418:** alter Crash-Report, triagiert, empfohlen als not-reproducible zu schließen.
- **CI:** macOS + Linux Gates auf den recent Ports sollten laufen; Device-Verify offen.

## Was wir (Grok) bis Mittwoch übernehmen können
Ohne Device / ohne lokales Xcode / ohne Ship-Gate:
1. **Weiter W1-Ports:** nächste reine Math-/Foundation-Bausteine aus dem alten Bio-Pfad (z.B. CameraAnalyzer-Teile, PolarH10-Publisher-Logik, HealthKit-Mapper) als kleine Scheiben nach EchoelDSP oder Core portieren + Tests.
2. **Docs & Ledger:** FEATURE_STATUS, FOUNDER_INBOX, SESSION_LOG, CLAUDE.md auf aktuellen Stand bringen (Build-Nummern, neue Wellen, offene Verify-Items).
3. **Nächste Pläne skizzieren:** detaillierte Scheiben-Liste für W1 Rest (Kamera-rPPG voll, BLE-Gurt, HealthKit) und W2 (ModRoute).
4. **PRs vorbereiten / reviewen:** die offenen Docs-PRs finalisieren, neue Docs-PRs für Plan-Updates oder Ledger.
5. **Issue-Triage & Kommentare.**
6. **Übergabe-Protokoll pflegen** (diese Datei aktualisieren).

## Was Device / Founder braucht (nicht übernehmbar)
- Bestätigung Build 10010 in App Store Connect.
- Device-Test der Loop/Overdub/Record-Änderungen (Build 10011).
- rPPG / Kamera / BLE / HealthKit am echten iPhone (W1).
- Klang, Stabilität, Launch, Bio-Mappings (Ship-Gate).
- Finale Merges nach main und TestFlight-Auslösung.
- F-15 / Store-Texte / Paid-Apps-Vertrag (W6).

## Empfohlene nächste Schritte (priorisiert)
1. **Jetzt:** diese Handover-Datei committen (geschieht mit diesem Commit).
2. **Heute/Montag:** nächste klare W1-Scheibe identifizieren und als Draft-PR oder Commit vorbereiten (z.B. CameraRPPGBioPublisher-Kern oder PolarH10-Publisher).
3. **Parallel:** die drei offenen Docs-PRs (#422–424) mergen (Owner-Entscheidung).
4. **Bis Mittwoch:** SESSION_LOG / FOUNDER_INBOX aktualisieren, weitere Foundation-Ports, Plan für W2 skizzieren.
5. **Mittwoch:** Claude-Session neu starten, dieses Protokoll lesen, nahtlos weitermachen.

## Regeln, die wir einhalten
- Eine Scheibe ≤ 3 Dateien, TDD wo möglich, CI als Orakel.
- Kein Push nach main, kein Merge, kein TestFlight, kein Info.plist / Workflow / Entitlements ohne Founder.
- Geschützte DSP-Triade nicht anfassen.
- Science-only, kein Wellness-Framing.
- Jede Änderung mit Commit-Message + Co-Authored-By.

**Status:** Übergabe gestartet. Wir arbeiten weiter bis Mittwoch und aktualisieren diese Datei.

---
*Erstellt von Grok-Team via GitHub-Tools. Nächstes Update folgt.*

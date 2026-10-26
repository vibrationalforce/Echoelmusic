# Handover Protocol — Grok Team → Claude / Founder
**Datum:** 2026-10-26 (Montag, ~09:00 CET)  
**Von:** Grok-Team (Benjamin, Harper, Lucas, Grok)  
**An:** Claude-Session (Token-Limit bis Mittwoch 09:00 UTC) + Founder  
**Branch:** `claude/echoelmusic-review-optimize-u5jjpd` (HEAD nach diesem Commit)  
**Mandat:** Volle Entscheidungsgewalt. Fehlende E2E-Verknüpfungen der DMMW/GSIMMW-Vision finden und respektvoll vorantreiben. Klare Übersicht für Claude.

## Was bereits erledigt ist
- Merge-Konflikt FOUNDER_INBOX.md gelöst (`37f99c23a`).
- W0 abgeschlossen (Screen Keys, Song-Loop/Overdub/Record).
- W1 pure Math nach EchoelDSP portiert (rPPG Conditioning, PulsePeriodEstimator, HRV Coherence/Metrics/Normalization, RR Hygiene/Adjacency). CI-grün auf macOS+Linux.
- Plan 1.0: `PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md` — alles in 1.0 (W7 Video, W8 Voice, W9 Face/Motion, W10 Generative AI). Scope-Cuts aufgehoben.
- Auto-Merge frei.

## Neuer Task (User 26.10.) — Network Jitter & Master Clock
**Status:** Dokumentiert als **W4+** (nach Verbindungen), nicht jetzt implementiert.  
**Abgleich mit Super Power:** Aktuell OSC/ADM-OSC/Art-Net/sACN (UDP, single-target). Kein PTP, kein SRT/WebRTC, kein Master-Clock-Domain für Netzwerk. Audio-Thread strikt geschützt.  
**Platzierung:** Hinter W1 (Body) und W4 (Connections). Voraussetzungen: F25 (studio.yml Zeile), Device-Verify für jede Latenz-Behauptung, keine Audio-Thread-Verletzung.  
**Nächster Schritt:** Als F26 oder Plan-Notiz aufnehmen (dieser Commit).

## Fehlende End-to-End-Verknüpfungen (DMMW/GSIMMW)
Aktuell wired (gemessen):
- Body → EngineBus (latestBio) → BioReactiveSynth / OSC egress.
- MIDI In → monophonic performer.
- Modulation Matrix (seit #1250) bio → Parameter.

Fehlend / halb:
- Volle BodyFrame (Kamera + BLE + HealthKit) → sichtbare Anzeige + Aus-Schalter (W1 Rest).
- ModRoute im Song (Quelle → Parameter, Tiefe, Kurve) als persistiert (W2, Format v3).
- Generative Visuals als eigene Fläche, gespeist von Song + Body (W3).
- Licht/OSC/ADM-OSC als ein Modul „Verbindungen“, alles aus bis Opt-in (W4).
- DDSP als viertes Instrument + MPE Out + Bio-Reaktivität (W5).
- Network Audio Streaming / PTP Master Clock (W4+ / neuer Task).

**Priorität:** W1 Rest abschließen (sichtbare BodyFrame), dann W2 ModRoute, dann W4 Verbindungen. Network-Jitter dahinter.

## Aktueller Stand
- Build 10010: Apple verarbeitet (Founder-Check).
- Offene Docs-PRs #422–424: merge-bereit (Roadmap_NOW, Pitch, Astra).
- Issue #418: empfohlen zu schließen (not reproducible).
- F24: Root-Dateien Empfehlung (Build-Skripte weg, skills-lock + wrangler bleiben) — rein Docs.
- F25: W4 wartet auf eine Zeile in studio.yml.

## Was wir bis Mittwoch tun (entschieden)
1. Dieses Handover + neues Overview-Dokument pflegen.
2. Nächsten W1-Rest als Plan skizzieren (BodyFrame Anzeige).
3. Network-Task als klaren Inbox-/Plan-Eintrag fixieren.
4. Docs-PRs Status kommentieren / finalisieren.
5. Weitere pure Foundation-Ports vorbereiten, wo klar und ≤3 Dateien.
6. SESSION_LOG / FOUNDER_INBOX Auszüge aktualisieren, wo risikofrei.

## Was Device / Founder braucht
- Apple Build 10010 bestätigen.
- Device-Tests (Loop, rPPG, Klang, Launch).
- Finale Merges + TestFlight.
- F-15 / Store.

## Regeln
Eine Scheibe ≤3 Dateien. Kein main-Push, kein Merge, kein TestFlight, kein project.yml/studio.yml/Info.plist/Workflow ohne Founder. Geschützte DSP nicht anfassen. Science-only.

**Status:** Non-stop bis Mittwoch. Nächstes Update in diesem File und in OVERVIEW_E2E_2026-10-26.md.

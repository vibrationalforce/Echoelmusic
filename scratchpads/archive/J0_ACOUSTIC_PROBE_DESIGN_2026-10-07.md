# J0 — akustische Rundlauf-Messung: Entwurf (2026-10-07, nicht gebaut)

Stand: Entwurf nach read-only-Prüfung (Reviewer C). **Nichts davon ist im Code.** Gebaut wird erst,
wenn (1) E10-1 integriert ist und (2) der Founder die zwei Fragen unten beantwortet hat.

## Founder-Fragen, bevor gebaut wird
1. **Info.plist `NSMicrophoneUsageDescription`** verspricht nach E10-1: Mikrofon „nur bei scharfer
   Spur + Record". Eine Messung benutzt es außerhalb davon → der Satz muss erweitert werden
   (App Review 5.1.1). Die Datei ist founder-gated. Vorschlag: „… and when you start a
   one-time latency measurement in the Audio route row."
2. **Bezug Gerätezeit statt elektrischer Referenz.** `AVAudioRecorder.record(atTime:)` +
   `AVAudioPlayer.play(atTime:)` auf `deviceCurrentTime`; ein konstanter Versatz bleibt
   unentdeckt, bis eine USB-Loopback-Messung (Kabel Ausgang→Eingang) ihn beziffert. Eine
   In-Band-Referenz bräuchte `inputNode`/RemoteIO/VPIO = #1302-Familie → nur auf Founder-Wunsch.

## Form (kleinste)
- NEU `Audio/RoundTripProbe.swift` — `@MainActor @Observable`, Zustände idle/settling/running/
  analysing/done/refused, `EndReason` (completed, user, timeout, interruption, routeChanged,
  rateChanged, background, recorderFailed, permission, busy, routeUnsuitable, settleFailed),
  8 Wiederholungen à 0,6 s, Burst 30 ms, maxLag 350 ms, **maxSeconds 8**.
- `Audio/AudioConfiguration.swift` — `case latencyCalibration` (eigener Besitzer, #299) +
  lesendes `recordRouteHolders`.
- `Studio/EchoelStudioView.swift` — in `AudioRouteRow` ein Knopf „Measure round trip" + eine
  Ergebniszeile (Blatt, kein neuer Modal).
- `Audio/LoopbackCalibration.swift` — Kopf „Wired: NO" → „Wired: RoundTripProbe; Device: no".
- Kein `.inputNode`, kein Tap, keine zweite Engine. Temp-Datei in `temporaryDirectory`, in
  `finish(_:)` gelöscht. Rate = Session-Rate NACH dem Claim (nicht 48 000). Kein `/2`.
- Vorbedingungen: Erlaubnis schon erteilt (keine Abfrage hier), Transport steht, kein anderer
  Halter, Ausgang ∈ {Speaker, LineOut, USBAudio} (Kopfhörer/Bluetooth → `routeUnsuitable`).
- Log-Zeile: `LatencyBudgetReport.logLine()` + `ref=deviceTime` + `session.mode`;
  `heard=UNMEASURED`, `netRTT` getrennt, verworfene Reihe → `rejected=<grund>`, nie eine Zahl.

## Wächter
NEU `TheRoundTripProbeEndsOnEveryExitTests` (7 Ansprüche: kein Eingangsknoten; genau ein Claim,
Release nur in `finish(`; maxSeconds ≤ 10; Konstruktion nur in EchoelStudioView, Start nur im
Button; keine 48 000; Temp-Datei + `removeItem` in finish; kein Halbieren). Im selben Commit
nachzuziehen: `TheRecordRouteHasOneClaimantTests`, `AnAudioTrackRecordsTheMicrophoneTests`
Anspruch 4, `TheLoopbackCalibrationRejectsWhatItCannotMeasureTests` Anspruch 6.

## Geräte-Abnahme (Build MIT der Sonde, `echoel_diag.log` exportiert)
1. Ohne Erlaubnis → `permission`, kein Prompt, keine `route: claim`-Zeile.
2. Erlaubt, Transport aus, Lautsprecher, ruhiger Raum → `calib: start 1/4…4/4`, `stop 1/2…2/2`,
   eine Ergebniszeile (`spread≤0.5 n≥7/8`), Route freigegeben, Mikro-Punkt < 1 s weg.
3. 3× wiederholen: ±0,5 ms. 4. Abbruch / Kontrollzentrum / Hintergrund / Anruf / Kopfhörer →
   genau ein `calib: ENDED <grund>`, keine Ergebniszeile, keine Temp-Datei, Wiedergabe danach ok.
5. Endet allein in ≤ 8 s. 6. Kopfhörer vorher → `routeUnsuitable`. 7. Record scharf → `busy`.
8. Kamera-rPPG an (44,1 kHz) → gleicher Wert ±1 ms oder `rateChanged`, nie ~8,8 % daneben.
9. USB-Interface mit Loopback-Kabel → Wert nahe `reported=`; Differenz = Bezugsversatz.
10. Body voice hörbar → Ablehnung oder gleicher Wert ±0,5 ms. 11. `diag-ladder.py` ohne offene Sprosse.

## Nebenbefund
`AudioEngine.swift:740` zitiert `TheMeasuredLatencyReachesTheDiagLogTests` — mit #1302
(`a86d57192`) gelöscht; der Anker `latencyBreadcrumb(reason: "engine reconfigured"` ist unbewacht.

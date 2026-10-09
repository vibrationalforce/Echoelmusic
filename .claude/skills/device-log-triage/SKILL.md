---
name: device-log-triage
description: Use when given an iOS crash or on-device anomaly — a .ips file,
  Console/device log, echoel_diag.log, or a MetricKit MXCrashDiagnostic — to reach a
  root cause and a minimal fix. Echoel has NO local Swift build, so device logs + CI
  are the only ground truth. Load when the user pastes a crash/diag log, reports an
  on-device crash/freeze, or asks "why did it crash on TestFlight".
---

# Device Log Triage (Echoel)

Echoel ships to TestFlight and iterates from device logs the founder pastes
(often `echoel_diag.log` with timestamped launch/rPPG/transport lines). This skill
turns that raw text into a routed fix.

## Steps

- [ ] Identify the build/version in the log header (e.g. "10.76.56 (2092)"). Confirm
      the fix you're verifying is actually IN that build — a fix pushed after the
      build number the user sees is NOT yet on their device.
- [ ] For a real crash `.ips`: match the correct dSYM to the exact app version, then
      symbolicate (Xcode auto-symbolicates a linked dSYM; else `atos`). MetricKit
      `MXCrashDiagnostic` arrives UNSYMBOLICATED.
- [ ] Read the crashing thread's top frames + termination reason (EXC_BAD_ACCESS,
      SIGSEGV, watchdog 0x8badf00d, `required condition is false: ...`).
- [ ] For an `echoel_diag.log` (no stack): read the last lines before the gap/stop —
      the last successful stage tells you where it died (launch stages, "camera
      started", "polyVoice.noteOn", "stopEverything").
- [ ] After a `CRASH SIG…` marker, two lines name WHERE it died: `crash thread/queue:`
      is the pthread name (main thread, CoreMIDI, any named thread — EMPTY on a libdispatch
      worker, so builds 2613/2618 wrote none) and `crash queue:` is the current dispatch
      queue's label (since 10.79.495; the one line a worker-thread trap writes). A
      `dispatch_assert_queue` SIGTRAP on a worker = an inferred-`@MainActor` closure trapping
      at ENTRY on that queue — the body is innocent; the rule is in
      `TheOffMainDispatchHandlerIsSendableTests`.
- [ ] Read the lines the GMMW SH slices added (2026-10-08) before guessing:
      `image <exe> uuid= text= load= slide=` names the binary — match the uuid to the dSYM,
      and `atos -o <dSYM> -l <load> <address>` turns every frame into a symbol (SH-7) ·
      `previous run ended: …` on the NEXT launch is the last crash in one line: signal,
      queue, app offsets, last line, version — read it first (SH-7) · `main: stalled` /
      `main: still stalled — no answer for n s` means the main queue stopped answering; a
      log that ENDS in one with no `CRASH` marker reads as a watchdog kill (0x8badf00d) or
      a jetsam — compare the last `memory:` line (SH-9, SH-6) · `self-check: …` says what
      the app came up with, 3 s after launch and after each engine self-heal (SH-10) ·
      `governor:` thermal/power/tier steps (SH-6) · `export`/`take` ladders (SH-5).

## Route to the fix (Echoel signatures)

- [ ] `required condition is false: _isInput` → a tap on `AVAudioEngine.outputNode`
      (forbidden) → reuse `RetroCapture` ring; load `avaudio-route-resilience`.
- [ ] SwiftUI metadata / type-metadata decoder frame, SIGSEGV at first render, black
      screen → `.sheet`-chain metadata limit → load `swiftui-render-safety`.
- [ ] Freeze/ANR while biofeedback runs (not a crash), menu/Picker unresponsive →
      10 Hz `@Observable` read in an ancestor body → `swiftui-render-safety`
      diagnosing section (audit the PARENT/ROOT).
- [ ] Captured/exported audio "höher"/pitch-shifted vs. live → 48k-vs-actual
      sample-rate mismatch on a camera-active route → `avaudio-route-resilience`.
- [ ] Audio-thread stack (render block) with malloc/lock/objc_msgSend → run the
      `audio-thread-reviewer` agent.
- [ ] SIGTRAP with a `crash queue:` label (the `dispatch_assert_queue` family) → run
      `python3 scripts/isolation-inventory.py` (`doctor.py --section F`) and fix EVERY
      TRAPS-ON-WORKER site it lists in that family, not only the one in the log.
- [ ] A log ending in `main: still stalled` (no crash marker) → a main-thread hang. An
      executor flood (10.76.48: a main-actor hop per camera frame) → batch through a
      Sendable queue into an existing low-rate poll. Body-rebuild churn (10.76.41/50)
      answers every ping and will NOT show here → `swiftui-render-safety`.

## Output

- [ ] One-line root cause + the smallest fix (≤3 files, Ralph Wiggum). No refactor.
- [ ] The fix commit carries a `Tests/CISmoke` guard that is RED on the parent —
      transcribed and graded per `Tests/CISmoke/CLAUDE.md` §0/§3 — and it names the CLASS,
      not only the site (builds 1769/1777 were fixed without one; the class came back).
- [ ] State honestly whether the fix is compile-verified (CI/Xcode gate) vs.
      device-verified — an audio-graph/route fix is NOT proven until a device run.

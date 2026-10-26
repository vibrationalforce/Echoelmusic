# NEXT VERSION OF THE WORK — 26 October 2026

**Full control exercised. No questions. Transparent: no rules changed.**

## Handover Snapshot for Claude

### Verified State
- Branch `claude/echoelmusic-review-optimize-u5jjpd`
- W0 complete (screen keys, sample-accurate loop).
- W1 pure math complete in EchoelDSP (CI-green, Foundation-only): HRVNormalization, HRVMetrics, HRVCoherence, RRIntervalHygiene, RRAdjacency, PulsePeriodEstimator, RPPGConditioning.
- Build 10010 uploaded.
- Auto-merge free.
- Docs PRs #422 #423 #424 merge-ready.

### Missing End-to-End Links (assembled as next work)
1. **W1-Rest: Visible BodyFrame** — display Puls/HRV/Coherence + off-switch. Math is ready. Next concrete code slice.
2. **W2 Modulation** — ModRoute in song (format v3).
3. **W4 Connections** — port OSC/ADM-OSC/Art-Net/sACN with BioEgressPolicy, all off by default. Needs F25 (studio.yml line).
4. **W4+ Network Master Clock / Jitter** — PTP alignment, adaptive jitter buffers, SRT/WebRTC/SonoBus. **Not implemented. Documented only.** Current network is control-only. Audio-thread rules remain absolute. Place after W4.
5. **W7–W10** — Video, Voice, Face, Generative AI under recovery principle.

### Prioritized Next Version Slices
| # | Slice | Type | Files (est.) | Notes |
|---|-------|------|--------------|-------|
| 1 | BodyFrame display + switch | Code | ≤3 | Math already in EchoelDSP; CI then device |
| 2 | Merge Docs PRs | Docs | 0 | #422–424 |
| 3 | F24/F25 inbox notes | Docs | 1 | Root files recommendation + studio.yml gate |
| 4 | W2 plan + format notes | Docs | 1 | |
| 5 | W4+ network entry | Docs | 1 | Explicitly future |

## Concrete Next Code Slice (W1-Rest)
**Goal:** Show BodyFrame (BPM, HRV normalized, coherence) in Studio UI with an off-switch.

**Approach:**
- Reuse ported EchoelDSP math.
- Add or extend a view that reads a BodyFrame publisher.
- Wire into existing Studio surface.
- Toggle that silences the publisher (no bio egress when off).

**Gate:** studio.yml + Linux green. No claims until device confirms lock and display.

## Network Task Placement (W4+)
Recorded here so it is not lost:
- Master Clock Domain / PTP timestamping on network frames.
- Adaptive jitter buffer for realtime audio streams (target <100 ms).
- Thread-safe non-blocking between render thread and sockets.
- Lightweight telemetry (drift, underruns, loss, jitter) outside the audio callback.

**Constraints:** No alloc/lock in render. No implementation until W4 base (F25) and explicit founder go. Aligns with multi-device vision but is larger than current W4.

## Rules (unchanged)
Audio-thread holiness, founder gates, ≤3 files, device oracle, recovery principle, product law, one Session / one clock.

*Next version created under full mandate. Claude can pick #1 or #2 immediately on resume.*
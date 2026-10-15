# Plan — Hardware live: iPhone → Xone:96 (USB, several channels) + H90 on MIDI clock

Founder 2026-10-15: „TestFlight optimieren für iPhone – Xone 96 – Deep Techno Live Set, Return A
und B … Eventide H90 analog." · Answers: USB with several channels; H90 delays synced by MIDI clock
from the iPhone. · Law the same day: „Sollte auch ohne externe Effekte gehen. Aber all umfassende
Hardware Integration soll möglich sein" → every route below is ADDITIVE; the app alone stays whole.

## Measured state (read-only map, spot-checked by hand)

| Area | Today | Where |
|---|---|---|
| Output width | Graph clamped to stereo: `channels: min(outputFormat.channelCount, 2)`, built once behind `graphPrepared` | `Audio/AudioEngine.swift` ~:866 |
| Session | `.playback`, 48 kHz preferred, 512-frame buffer (256 opt-in); no `setPreferredOutputNumberOfChannels` anywhere | `Audio/AudioConfiguration.swift` |
| Route change | USB arrival is log-only; loss → `recoverEngine` restart, never a format rebuild | `AudioConfiguration.handleRouteChange`, `AudioEngine` watchdog |
| Buses | Per-rack-slot `AVAudioMixerNode` (`attachTrackBus`), before engine start only; SubBass + bio voice not bussed; timeline audio straight to master | `AudioEngine.attachTrackBus` |
| Model | `TimelineLane` level/pan/mute/solo via `mergeMixer`; no sends, no output field | `Sequencer/Timeline.swift` |
| MIDI clock | Main-queue `DispatchSourceTimer`, 24 PPQN, packet timestamp **0** (send now) → jitter = main-thread latency; to ALL destinations + virtual source; Start on the first pulse; no SPP/Continue; no clock past bar 1; rides the `midi.out` route | `Audio/MIDIOutput.swift` ~:628–716 |
| Own FX | Deep Tech preset: dotted-8th delay 0.18, room 0.40; "Clean (dry)" character exists | `Sequencer/GenreFX.swift` |

## Slices (one Ralph slice each, guard each)

**HW-1 Clock on host time (cheap, highest value for the H90).** Pulses carry a FUTURE
`MIDITimeStamp` (mach host time) computed from one anchor (`play` host time + n × pulse length),
sent a small lookahead ahead by the existing timer; CoreMIDI delivers on time regardless of
main-thread load. Pure `ClockSchedule` (anchor, bpm, n → host ticks; tempo change re-anchors at
the current pulse, keeping phase) with golden values. No new thread, no audio-thread work.
*Device:* H90 tempo readout steady while a Picker is open.

**HW-2 Start past bar 1.** Song Position Pointer + Continue instead of "no clock", so the H90
follows a set started mid-piece. Pure SPP math (16ths since song start, 14 bits).

**HW-3 See the interface.** When a USB route arrives, ask for `maximumOutputNumberOfChannels`
and show it in the existing "Audio route" row ("Xone:96 — 8 outputs"). Status only; no graph change.

**HW-4 Output assignment (model).** `TimelineLane.outputPair: Int?` (nil = main, written only as
non-nil, decodeIfPresent, masked in nothing — it DOES change what sounds). Mixer strip: a menu
Picker "Out: Main · 3/4 · 5/6 · 7/8", offered only when the route has > 2 channels.

**HW-5 Multi-out graph (the hard one — Council + device before merge).** Session requests N
channels; `processingFormat` stays stereo for the master, and `outputNode` takes an N-channel
format; each output pair gets its own stereo submixer + `AutoMixChain` limiter; a lane whose
`outputPair` is set routes its bus there instead of `masterMixer`. RetroCapture keeps tapping the
main pair. Rebuild on route change (USB in/out) through the existing `recoverEngine` path, with
breadcrumbs before each step. Falls back to all-main when the route has 2 channels.

**HW-7 MIDI destination picker (before HW-8/9).** Clock, notes and MPE go to EVERY CoreMIDI
destination today (`MIDIOutput.send`, `sendSystemWord`). With the H90 on USB its notes arrive
unasked. A per-message-kind choice in Routing (clock → H90, notes → a synth, or all), persisted
by destination name; "all" stays the default so nothing that works today stops.

**HW-8 Program Change per section.** A section of the piece can name a program (0–127, channel);
entering it sends 0xCn on the clock's host-time stamp. H90 preset follows the set.

**HW-9 Matrix → CC out.** A modulation-matrix destination "MIDI CC n" (channel, number), sent
deduplicated at the matrix's ~1 Hz bio rate (never per audio buffer), so the body can move an H90
parameter. Learned mapping stays on the H90.

## The chain since 2026-10-15 (founder): iPhone → H90 → MIDI Thru → Roland TR-8S

Every device behind the H90 sees the SAME stream, so the MIDI CHANNEL decides who answers, not
the destination (HW-7 matters less). Measured channels today:
· notes, MPE off: channel 1 (`allocateChannel`, `ch = 0`).
· notes, MPE on: member channels 2…16 — **this includes 10**, the TR-8S's usual drum channel:
  every tenth or so note would fire a drum. Until HW-11, keep MPE out OFF in this chain.
· clock / Start / Stop / SPP / Continue: no channel — every device follows (wanted).

**HW-10 Drums → MIDI (TR-8S).** The composer still computes a drum grid per genre (four-on-floor,
half-time, …; `BioComposition.drumSteps`, 8 tracks × 16 steps, `BioComposer.Track`) and the
instrument plays `silentBeat()` (founder 2026-07-07 cut the INTERNAL drums; product law
2026-09-24 makes that phase history). A Routing switch "Drums to MIDI" (default off, channel 10,
note per track editable, defaults kick 36 · snare 38 · closed hat 42 · open hat 46 …) sends the
genre groove as notes on each step, on the clock's host-time stamp. The app's own sound is
unchanged; the TR-8S becomes the drum voice. Fills the reference piece's drum gap through
hardware; the in-app drum role stays its own slice (standalone law). Note map is UNVERIFIED
against the TR-8S defaults — editable for that reason.

**HW-11 Channel discipline.** MPE zone narrows to members 2…9 when "Drums to MIDI" is on, so
channel 10 is never a member channel; the RPN zone message announces the narrower zone.

**HW-6 External sends (later).** A send per lane to an output pair (post-fader), so an outboard
return (H90 on the Xone) can be fed directly from the app as well as from the mixer. Additive.

## Open device facts (founder, one session)
- Xone:96 USB: how many outputs does iOS report? (HW-3 prints it.)
- Does the Xone:96 pass USB-MIDI clock to its MIDI DIN out, or is the H90 on its own USB/MIDI path?

## Council (2026-10-15, condensed)
Architect: HW-5 touches the crash-sensitive attach/restart path — keep it last, behind HW-3/HW-4,
one graph change per slice. DSP Purist: no per-pulse work on the render thread; host-time stamps
are the standard way. Vision-Keeper: additive — main pair always plays the whole piece. Shipper:
HW-1 + HW-2 + HW-3 ship this week; HW-5 needs a device in hand. Skeptic: Xone:96 channel count
and its MIDI-thru are unmeasured — print, do not assume. User-Advocate: the Out picker hides at
2 channels so a phone-only user never sees it. **Gate: proceed with HW-1 now.**

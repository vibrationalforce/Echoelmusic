# HISTORY ARCHIVE — historical capability register and recovery index

**What this is.** Every meaningful capability this repository ever started, measured against its
full Git history (2025-10-15 "Blab" → 2026-09-24, about 8,100 commits, about 1,140 deleted source
files). For each one it says whether the capability actually worked, and what a recovery should
reuse, port or rebuild.

**Authority.** Product scope is decided by `docs/dev/FOUNDER_PRODUCT_LAW.md` (the DMMW, current
since 2026-09-24). **This file never decides scope.** A capability recorded here as *removed* is
not therefore *forbidden*: a historical deletion revokes an implementation, not necessarily the
capability.

**Scope is not a claim.** Nothing in this file may be quoted in public copy as a shipping feature.
What ships is `docs/dev/FEATURE_STATUS.md`; what may be claimed is `ContentPipeline/CLAIMS.md`.

**How it was measured.**
- Deletions: `git log --diff-filter=D --format='%h %ad %s' --date=short -- <path>`, then the file read at `git show <sha>^:<path>`.
- Reachability today: comment-stripped `git grep` for constructors, plus `python3 scripts/doctor.py --section C`.
- Where a claim rests only on a file header or a commit message, the field says `?` (UNKNOWN).
- Nothing in this file was verified on a device.
- Line counts are from the historical files and are dates, not facts (#818).

---

## The recovery principle (read before restoring anything)

> **NEVER restore a historical subsystem by copying it wholesale merely because it once existed.**

```
CURRENT CAPABILITY NEEDED
→ inspect the current implementation
→ inspect the historical implementations (this file)
→ identify the proven algorithm / semantics / tests
→ discard stale ownership / UI / persistence / runtime assumptions
→ port only the valuable core
→ integrate it into the CURRENT canonical owners
→ test end to end, then verify on a device
```

**Three facts from the history make this rule non-optional.**

1. **Most of the "professional" history never compiled.**
   - The whole C++/JUCE layer (2025-11 → 2026-01-13, `48811de03`) sat behind `option(USE_JUCE … OFF)`, and JUCE was never vendored. Every CI invocation found passed `-DUSE_JUCE=OFF`.
   - Several Swift layers compiled but **never processed a sample**. Example: `Audio/Nodes/NodeGraph.process` had no caller.
2. **Many "AI / Quantum / 16K / Dante / NDI" names were overclaims.**
   - No trained model ever existed in this repo: no `.mlmodel`, `.mlpackage` or `.onnx` file anywhere in history.
   - Several engines fabricated outputs — random file sizes, `"0x"+UUID` transaction hashes, invented benchmark numbers.
3. **The same capability was rebuilt 3–4 times,** each time on a new shell (DAW ×4, piano roll ×3, light ×4, spatial ×3, visual ×4, streaming ×3). The churn came from shell pivots, not from failed algorithms — so the algorithms are often worth porting even when the architecture is not.

### Legend

| Field | Values |
|---|---|
| **C / R / O** | Compiled · user-Reachable · produced real Output — `Y` / `N` / `?` |
| **Scope** | per FOUNDER_PRODUCT_LAW: `YES` · `LATER` · `RESEARCH` · `NO` |
| **Class** | `CURRENT` real today · `REUSE` sleeping implementation can be reconnected · `PORT ALGORITHM` keep the math, discard the architecture · `REBUILD` capability wanted, implementation unsuitable · `DO NOT RESTORE` fake/pseudoscience/unsafe · `RESEARCH` interesting, not product-ready |

Each entry: **Impl** (historical implementations, dates, commits) · **C/R/O** · **Real** ·
**Stub/overclaim** · **Removed because** · **Scope / Class** · **Owner** (current → target) ·
**Deps / Risks** · **Next safe slice**.

Bulk-deletion commits cited below:

| Commit | Date | Message |
|---|---|---|
| `48811de03` | 2026-01-13 | "Remove JUCE framework completely" |
| `f6afae7ea` | 2026-03-03 | "strip app to DAW + Video only" (622 files) |
| `3dfd8cc0a` | 2026-03-28 | "strip to bio-reactive soundscape core — 138 → 28 files" |
| `cf21ff3d8` | 2026-06-12 | dead-module sweep |
| #121 | 2026-07-24…31 | "reines Instrument" Slices 2–4 |
| #1301 / #1302 / #1304 / #1305 | 2026-09-12 | face · audio input · video capture · harmonizer + granular |

---

## A. AUDIO / INSTRUMENTS

### A1 · EchoelDDSP / PolySynthVoice (harmonic-plus-noise synth)
- **Impl:** `DSP/EchoelDDSP.swift` (2026-03 →), `Tools/PolySynthVoice.swift`. It has a vDSP partial bank, 65 IIR noise bands, ADSR, spectral morph, and `InstrumentTimbre` profiles (violin, flute, trumpet, cello, clarinet, oboe). The app runs five instances: 12-voice harmony, lead, bass, touch, and the lane rack.
- **C/R/O:** Y/Y/Y
- **Real:** all of it.
- **Stub/overclaim:** header prose — "FIR noise" (it is IIR) and "12 mappings / LF/HF → reverb" (no producer).
- **Removed because:** —
- **Scope / Class:** YES / **CURRENT**
- **Owner:** `PolySynthVoice` + `SynthPatch`/`PatchStore`
- **Deps / Risks:** —
- **Next safe slice:** correct the two stale header claims.

### A2 · SubBassVoice + SubCharacter
- **Impl:** sine sub one octave down, with presence (2f/4f) and heat (tanh).
- **C/R/O:** Y/Y/Y
- **Scope / Class:** YES / **CURRENT**
- **Owner:** `Tools/SubBassVoice`
- **Next safe slice:** —

### A3 · BioReactiveSynthVoice
- **Impl:** one DDSP voice played by pulse and breath plus mono MIDI in. Silent until armed.
- **C/R/O:** Y/Y ("Body voice")/Y
- **Stub/overclaim:** its own FX chain is never used.
- **Scope / Class:** YES / **CURRENT**
- **Next safe slice:** decide whether its dead FX chain is removed or wired.

### A4 · EchoelModalBank (physical modelling)
- **Impl:** `DSP/EchoelModalBank.swift`, 871 lines. A modal resonator bank with material presets (bell, plate, bar, string, glass, drum, gong) and strike position. Its only instantiator was `DrumSynthVoice`, deleted by #167 on 2026-07-31.
- **C/R/O:** Y/N/Y (it sounded as drum pads until #166)
- **Real:** all of it, and it is tested.
- **Removed because:** the drum kit was removed, not the resonator.
- **Scope / Class:** YES / **REUSE**
- **Owner:** → a new percussive/mallet voice behind `SynthPatch` or a lane voice.
- **Deps / Risks:** audio-thread audit before wiring.
- **Next safe slice:** a one-voice host in the lane rack plus a source guard. No UI yet.

### A5 · EchoelCellular (cellular-automaton synthesis)
- **Impl:** `DSP/EchoelCellular.swift`, 563 lines. CA as wavetable, additive, FM, and 2-D Life (rules 30/90/110).
- **C/R/O:** Y / Y in AUv3 only / Y
- **Scope / Class:** YES / **REUSE** in the app target
- **Owner:** AUv3 `texture` voice → app texture layer.
- **Risks:** CPU (#1385 raised latent defects once it had a caller).
- **Next safe slice:** app-side texture voice behind a default-off switch.

### A6 · SamplerVoice (one-shot player)
- **Impl:** `Sequencer/SamplerVoice.swift`, with a lock-free trigger counter.
- **C/R/O:** Y/N/Y (no UI loads a sample)
- **Scope / Class:** YES / **REUSE**
- **Owner:** lane rack sampler slot.
- **Deps:** a sample-import surface (Workstation import exists for audio lanes).
- **Next safe slice:** "load sample into slot" from the managed media library.

### A7 · Historical EchoelSynth (5 engines)
- **Impl:** `Sound/EchoelSynth.swift`, 969 lines, 2026-03-09 → `3dfd8cc0a` 2026-03-28. Engines: analog unison, 2-op FM, 8-shape wavetable, Karplus-Strong, supersaw. Followed by SVF, chorus and drive.
- **C/R/O:** Y/Y/Y (played from `MultiTouchInstrumentView`)
- **Removed because:** the refocus to the soundscape core.
- **Scope / Class:** YES / **PORT ALGORITHM** (Karplus-Strong, FM and supersaw as `EchoelDDSP` sibling engines)
- **Owner:** → `SynthPatch` engine selector.
- **Next safe slice:** port Karplus-Strong as a pure kernel with tests.

### A8 · Historical EchoelBass (A/B morph: 808 · Reese · Moog ladder · TB-303 · FM growl)
- **Impl:** `Sound/EchoelBass.swift`, 906 lines, 2026-02-20 → `3dfd8cc0a`.
- **C/R/O:** Y/Y/Y
- **Scope / Class:** YES / **PORT ALGORITHM** (the ladder filter and 303 slide/accent are the valuable cores)
- **Owner:** → `SubBassVoice` / bass lane.
- **Next safe slice:** port the ladder filter as a pure DSP type.

### A9 · Drums / 808 (EchoelBeat, TR808BassSynth, DrumSynthVoice, lane kits, Android TR-808, C++ DrumSynthesizer)
- **Impl:**
  - EchoelBeat — 16 pads plus real-time 808 hi-hat synthesis, 2026-02 → 03-28.
  - TR808BassSynth — 2025-12 → 03-28.
  - DrumSynthVoice / LaneDrumKitVoice — ModalBank-based, 2026-06 → 07-31, #167.
  - C++ DrumSynthesizer — 12 voices, never compiled.
- **C/R/O:** Y/Y/Y (Swift); N/N/N (C++)
- **Removed because:** founder, "erstmal gar nicht mehr rein" (#167). The kit sounded thin.
- **Scope / Class:** YES / **REBUILD** (reuse ModalBank, port the 808 hi-hat and kick-glide math)
- **Owner:** → a drum lane voice. `LaneVoiceKind.drums` / `TrackInstrument.drums` still exist.
- **Next safe slice:** a pure kick/hat kernel with tests, no door.

### A10 · SampledInstrumentVoice (General MIDI soundfont)
- **Impl:** `AVAudioUnitSampler` plus the 31 MB GeneralUser GS soundfont, 2026-07-04 → 07-07 (`6c9258b1a`).
- **C/R/O:** Y/Y/Y
- **Removed because:** founder, "Real Instruments Komplett raus".
- **Scope / Class:** LATER / **REBUILD** (licence review of any bundled soundfont; app size)
- **Next safe slice:** licence audit only.

### A11 · EchoelQuant (Schrödinger-equation synthesis)
- **Impl:** `Quantum/EchoelQuant.swift`, 917 lines. Split-step Fourier. Deleted `f6afae7ea`.
- **C/R/O:** Y/?/?
- **Real:** a legitimate, exotic synthesis technique.
- **Stub/overclaim:** filed under "Quantum" marketing.
- **Scope / Class:** RESEARCH / **RESEARCH**
- **Next safe slice:** port to a pure kernel only if the founder wants the timbre. It must never be named "quantum" in product copy.

### A12 · C++ JUCE synth suite (EchoSynth · WaveForge · WaveWeaver · FrequencyFusion · SampleEngine · RhythmMatrix)
- **Impl:** `Sources/DSP|Synth|Instrument/*.cpp`, 2025-11 → `48811de03`.
- **C/R/O:** N/N/N
- **Real:** plausible textbook code.
- **Stub/overclaim:** SampleEngine's "time-stretch" is a pitch change.
- **Scope / Class:** YES (capabilities) / **PORT ALGORITHM** at most (JUCE-bound, allocates on the audio thread)
- **Next safe slice:** none until a concrete engine is requested.

### A13 · Metronome · UniversalSoundLibrary · InstrumentOrchestrator · CinematicScoringEngine
- **Impl:**
  - `MetronomeVoice` is live — **CURRENT**.
  - UniversalSoundLibrary ("all instruments worldwide", offline renderers) and InstrumentOrchestrator are PARTIAL.
  - CinematicScoringEngine never rendered audio — STUB.
- **Class:** Metronome **CURRENT**; the rest **DO NOT RESTORE** (the catalogue claims) — any real engine goes through A7/A12.

---

## B. FX

### B1 · EchoelFXChain (13 stages) + characters + genre presets + bio modulation
- **Impl:** filter (ZDF SVF) → saturation → tape/VHS → bitcrush → chorus → flanger → phaser → tremolo → delay (digital/tape/ping-pong) → reverb (Freeverb) → width → compressor → limiter.
  - 11 characters (incl. Cassette and Vinyl).
  - About 60 genre presets.
  - `FXBioModulator` drives 13 targets.
  - `ChannelInsertFX` per bus.
- **C/R/O:** Y/Y/Y (FX chip, "All parameters")
- **Scope / Class:** YES / **CURRENT**
- **Next safe slice:** —

### B2 · EchoelFDNReverb (8-line FDN, Hadamard, Jot RT60)
- **Impl:** 2026-07-13. Zero production constructions.
- **C/R/O:** Y/N/? (tests only)
- **Scope / Class:** YES / **REUSE**
- **Owner:** → an alternate reverb algorithm inside `EchoelFXChain`.
- **Risks:** CPU per voice chain; consider a send bus.
- **Next safe slice:** a chain stage variant behind the reverb algorithm picker.

### B3 · Convolution / EchoelSpaceReverb / DDSP convolution
- **Impl:**
  - `EchoelSpaceReverb` (room-in-room, synthetic IRs): zero constructions.
  - The `EchoelDDSP` convolution stage is hard-off (`useConvolutionReverb` never set, #546).
  - C++ ConvolutionReverb: never compiled.
- **Scope / Class:** YES / **REUSE** (Space) · **PORT ALGORITHM** (C++)
- **Next safe slice:** wire SpaceReverb on a send, CPU measured.

### B4 · Harmonizer
- **Impl:** `EchoelHarmonizer` — a two-tap crossfaded pitch shifter with two voices and 15 named intervals. 2026-06-16 → #1305. The C++ 4-voice Harmonizer was never compiled.
- **C/R/O:** Y/Y/Y
- **Removed because:** founder, "Kein … Harmonizer".
- **Scope / Class:** YES (DMMW) / **PORT ALGORITHM**, with a better shifter (see B6)
- **Next safe slice:** after B6 exists.

### B5 · Granular ("Echoel Grain")
- **Impl:** `EchoelGranular` — a grain pool over a pre-allocated delay line on the mic path. 2026-08-21 → #1305. UniversalSoundLibrary's "granular" was a fake.
- **C/R/O:** Y/Y/Y
- **Removed because:** it went with the audio input.
- **Scope / Class:** YES (future "Echoel Grain") / **PORT ALGORITHM**. The grain scheduler is reusable; the source must become a buffer or clip, not the mic.
- **Next safe slice:** a pure grain kernel over an in-memory buffer, with tests.

### B6 · Pitch correction / phase vocoder / formant
- **Impl:**
  - `VoicePitchCorrector` — YIN → scale → `AVAudioUnitTimePitch`, monitor only. 2026-07-12 → #1302.
  - `PhaseVocoder` — vDSP STFT, Laroche–Dolson phase locking, LPC formant preservation, 481 lines. 2026-02 → `3dfd8cc0a`. Never wired.
  - `EchoelVoice` AUv3 kernel — never shipped.
  - C++ PitchCorrection — never compiled.
- **C/R/O:** Y/Y/Y (corrector) · Y/N/? (phase vocoder)
- **Scope / Class:** YES / **PORT ALGORITHM** (the phase vocoder is the most valuable DSP in the archive)
- **Owner:** → `DSP/` pure type → pitch per clip / harmonizer / time-stretch modes.
- **Deps:** `DSP/PitchTracker` (live).
- **Next safe slice:** port the phase vocoder as a pure `DSP/` type plus tests. No wiring.

### B7 · Vocoder
- **Impl:**
  - `VocoderCore` — data mapping only, "NO audio DSP", → #1302.
  - C++ Vocoder — 8–32 bands, never compiled.
- **Scope / Class:** LATER / **PORT ALGORITHM** (C++ band math). The Swift file was never a vocoder.
- **Next safe slice:** —

### B8 · Spectral / resonance processing (SpectralSculptor, ResonanceHealer-as-DSP, de-esser)
- **Impl:** C++, never compiled. The "AI denoiser" is spectral subtraction. `ResonanceHealer` carried organ-healing claims (see M).
- **Scope / Class:** LATER / **PORT ALGORITHM** for the soothe-like FFT suppression and spectral subtraction, under neutral names. **DO NOT RESTORE** the "Healer" framing.

### B9 · Historical dynamics and tone modules
- **Impl:**
  - Swift `ClassicAnalogEmulations` — SSL/API/Pultec/Fairchild/LA-2A/1176/Vari-Mu names over simple envelope + tanh.
  - `NeveInspiredDSP`.
  - C++ VintageEffects (tape, VHS, tube, vinyl, auto-wah).
  - LofiBitcrusher, Underwater, TapeDelay, ClassicPreamp, HarmonicForge, ModulationSuite (ring mod, Bode shifter).
  - FET/Opto compressors, FormantFilter.
- **C/R/O:**
  - Swift: Y / N / N — `SaturationNode` sat inside `NodeGraph`, which never processed audio.
  - C++: N / N / N.
- **Stub/overclaim:** hardware brand names on generic algorithms.
- **Scope / Class:** YES / **PORT ALGORITHM** selectively: ring mod, Bode shifter, formant filter, multiband saturation. **DO NOT RESTORE** the brand-name emulation claims.
- **Next safe slice:** ring mod + frequency shifter as `EchoelFXChain` stage candidates.

### B10 · ProMixEngine effect list (34 names → 4 nodes)
- **C/R/O:** Y/?/N as named
- **Class:** **DO NOT RESTORE** (it mapped 34 advertised effects onto 4 processors).

---

## C. MIX / MASTER / EXPORT

### C1 · AutoMixChain (master)
- **Impl:** 4-band EQ (HP 45 · LS 140 · PK 2.8 k · HS 9 k), 4 tone profiles, auto-gain toward `LoudnessTarget` (−14/−16/−23/−24 LUFS), Apple PeakLimiter.
- **C/R/O:** Y/Y/Y
- **Stub/overclaim:** the auto-gain steers by unweighted RMS, not by the R128 number shown.
- **Scope / Class:** YES / **CURRENT** (defect D2)
- **Next safe slice:** feed the auto-gain from `EchoelLoudnessMeter`.

### C2 · R128 / true peak metering
- **Impl:** `EchoelLoudnessMeter` — BS.1770-4: K-weighting, M/S/I, gating, LRA. `EchoelMeter` — peak/RMS plus 4× Catmull-Rom true-peak estimate.
- **C/R/O:** Y/Y/Y (Master chip)
- **Stub/overclaim:**
  - ~~K-weighting coefficients are the 48 kHz set at every rate~~ — REPAIRED by E3 (2026-09-24, `2e6b54d66`): derived per rate by the bilinear transform, 44.1–192 kHz supported, any other rate reads the floor instead of borrowing coefficients.
  - True peak is an estimate, not a polyphase oversampler.
- **Scope / Class:** YES / **CURRENT**
- **Next safe slice:** per-rate coefficients; polyphase true peak.

### C3 · Export (LoopExporter / SingleExport / RetroCapture)
- **Impl:** a bar-exact loop WAV (24-bit) or AAC; a 30 s pre-roll ring.
- **C/R/O:** Y/Y/Y
- **Stub/overclaim:** normalisation is RMS and up to +12 dB with **no ceiling after it** (defect D1).
- **Scope / Class:** YES / **CURRENT**
- **Next safe slice:** the export-quality repair (see the end of this file).

### C4 · TrackFreeze / offline bounce
- **Impl:** `TrackFreezeEngine`, 491 lines — `enableManualRenderingMode` + `renderOffline`. 2026-02 → `3dfd8cc0a`.
- **C/R/O:** Y/?/Y
- **Scope / Class:** YES / **PORT ALGORITHM** (the offline-render core is what a proper export needs: faster than real time, no live capture)
- **Owner:** → export pipeline.
- **Next safe slice:** after C3 is repaired.

### C5 · StemRendering / UniversalExportPipeline / ExportManager
- **Impl:**
  - `StemRenderingEngine` — per-stem WAV/FLAC/AAC; its MP3 option cannot be encoded. PARTIAL.
  - `UniversalExportPipeline` — **simulated** export with a random file size. STUB.
  - `ExportManager` — M4A regardless of the chosen format. PARTIAL.
- **Scope / Class:** YES / **REBUILD** (stems); **DO NOT RESTORE** (UniversalExportPipeline).

### C6 · Historical mastering suite (C++)
- **Impl:** StyleAwareMastering (genre targets, RMS "LUFS"), MasteringMentor (advice only), SpectrumMaster, MultibandCompressor, DynamicEQ, PassiveEQ, StereoImager, TransientDesigner, BrickWallLimiter ("true peak" that cannot exceed its endpoints), EchoConsole (SSL strip), PhaseAnalyzer, psychoacoustic headers. SmartMixer ("AI", placeholder).
- **C/R/O:** N/N/N
- **Scope / Class:** YES / **PORT ALGORITHM** for the multiband crossover, M/S imager, transient designer, dynamic EQ. **DO NOT RESTORE** SmartMixer or the fake true-peak.
- **Next safe slice:** a master-bus compressor as a pure type (the master has none today).

### C7 · Mixer surfaces (ProMixEngine, MixerView, EchoelMixView, ChannelRackView)
- **Impl:** four generations, the last deleted 2026-07-27 (it mixed channels with no sound).
- **Scope / Class:** YES / **REBUILD** on `TimelineStore` lanes. `mixerPanel` is **CURRENT** for the instrument.

---

## D. MIDI / DAW

### D1 · Arrangement / timeline
- **Impl:**
  - `DAWArrangementView` (2026-01).
  - `ArrangementView` (06-12, then 06-20 → 07-19).
  - `ArrangeTimelineView` (07-10 → 07-25).
  - Today `TimelineStore` plus `WorkstationView`: view, play, import audio/MIDI, add tracks, tempo ×2/÷2, pitch per track.
- **C/R/O:** Y/Y/Y (Workstation)
- **Removed because:** the #121 pure-instrument phase (views only; the models were salvaged).
- **Scope / Class:** YES / **CURRENT** (read/play/import) + **REBUILD** (editing)
- **Owner:** `TimelineStore` / `ClipStore` / `TimelineRegionPlayer`.
- **Deps:** undo (D6).
- **Next safe slice:** move/trim a region, with undo, on `TimelineStore`.

### D2 · Session / clip launcher
- **Impl:** `SessionClipView` (01-28 → 03-25), `ClipLauncherGrid` (01 → 03), `ClipView` (06-10, 06-18 → 07-25).
- **C/R/O:** Y/Y/Y (June–July)
- **Scope / Class:** YES / **REBUILD** (`LaunchQuantizer` never existed)
- **Owner:** → `ClipStore` + transport quantise.

### D3 · Piano roll (three generations) + note editing
- **Impl:**
  - `MIDI/PianoRollView` (2025-12 → 03-08).
  - `Views/PianoRollView` (03-09 → 03-25).
  - `Studio/PianoRollView` (06-09 → #475, 2026-08-07).
  - `RollHitTest`, `RollFitMath` and `RollNoteOps` survived as orphans; since Phase 3 / M1 `PartNoteEditor` calls `RollHitTest.classify` and (via `ClipNoteEdit`) `RollFitMath.medianPitch` again — the REBUILD this row names, started.
  - `PianoRollModel` is **CURRENT**: the note engine plus the `MusicalFrame` publisher.
- **Removed because:** founder, "Pianoroll soll raus".
- **Scope / Class:** YES / **REBUILD** (reuse the Roll* math and the #470 unit-to-period law)
- **Next safe slice:** a note-editor surface on a Workstation MIDI region.

### D4 · Automation editors
- **Impl:** `AutomationLaneView` (01), `AutomationView` / `ClipAutomationView` (06-22 → 07-25), `TimelineAutomationRow` (07-17 → #473). `AutomationPlayer` **plays** persisted curves; nothing can draw one.
- **Scope / Class:** YES / **REBUILD** (the player and the `TimelineAutomationRowMath` core are current)

### D5 · Cue system / step sequencers
- **Impl:** `ProCueSystem` (03-21 → 03-28), `VisualStepSequencer`, `EchoelSeqEngine`. `PatternEngine` is **CURRENT** as the transport clock.
- **Scope / Class:** LATER / **REBUILD**

### D6 · Undo / redo
- **Impl:** `UndoRedoManager` (2025-12 → `3dfd8cc0a`). **None exists today.**
- **Scope / Class:** YES / **REBUILD**. It is a prerequisite for any editing slice.
- **Next safe slice:** a command-log core for `TimelineStore` edits.

### D7 · Browser / sample browser / channel rack
- **Impl:** `BrowserView` / `SampleBrowserView` (→ 07-27), `ChannelRackView` (→ 07-27).
- **Scope / Class:** YES / **REBUILD** on the managed `MediaLibrary`.

### D8 · MPE / MIDI 2
- **Impl:**
  - MPE **out**: live and switchable (#713).
  - MPE input: no zones, so it is not real (#548). Bend, press and slide all sound (#939/#942).
  - MIDI 2.0: input parse; a second, default-off MIDI 2.0 output source (#1253).
- **Scope / Class:** YES / **CURRENT** (out) + **REBUILD** (zones need a second consumer; `scratchpads/PLAN_MPE_ZONES_2026-09-01.md`, #548)
- **Next safe slice:** the plan's first slice.

### D9 · MIDI file import / export
- **Impl:**
  - Export: **CURRENT** (`MIDIFileExporter`, export slot).
  - Import: `MIDIFileImporter` (06-22). It lost its door 07-02 and came back as a Workstation MIDI track on 09-23 (S2).
- **Scope / Class:** YES / **CURRENT**

### D10 · App shells (13-workspace hub, StudioRoot 4 tabs, 6-surface bar, Tools grid, SurfaceSwitcher, Session-as-home)
- **Impl:** each lived from about a day to about 6 weeks.
- **Stub/overclaim:** the hub fronted engines that did not exist.
- **Scope / Class:** — / **DO NOT RESTORE** any old shell. A DMMW shell is a new design decision (UI law: surfaces are replaceable).
- **Next safe slice:** a founder design session, not code.

### D11 · Lyrics model / take recorder
- **Impl:** `LyricsModel` (syllabification, melisma; zero references); `TakeRecorder` / `RecordController` (`arm()` has no caller; needs an audio input).
- **Scope / Class:** LATER / **REUSE** once an audio input exists (E-series).

---

## E. RECORDING / AUDIO INPUT

### E1 · Audio input / multitrack recording
- **Impl:**
  - `RecordingEngine` (2025-11 → `3dfd8cc0a`).
  - `MultiTrackRecorder` (2026-05 → #1302).
  - `MicrophoneManager` / `AudioInputManager` / `MonitorInsertAU` / `FeedbackGuard` (→ #1302).
  - `MixTapRecorder` (07-01, the same day it crashed with `_isInput`).
- **C/R/O:** Y / partly / Y
- **Removed because:** founder, "Face und Audio Input komplett entfernen". The input graph produced the `isInputConnToConverter` crash family.
- **Scope / Class:** YES / **REBUILD**. Do not restore the old graph. The `RecordRouteOwner` refcount law (#299) and "`NSMicrophoneUsageDescription` must return in the SAME commit as any `RecordRouteOwner` case" stay law.
- **Owner:** → a new input owner on `AudioConfiguration`.
- **Deps:** the Info.plist key (founder-gated), `avaudio-route-resilience`.
- **Next safe slice:** a design note plus a Council review. No code before the founder signs off the plist change.

---

## F. VIDEO / VISUAL

### F1 · VideoWeaver / historical video editor / multicam / colour grading
- **Impl:**
  - C++ VideoWeaver ("DaVinci/FCP", "up to 16K") — never compiled.
  - Swift `VideoEditingEngine`, `MultiCamStabilizer`, `ProColorGrading`, `BPMGridEditEngine` (2025-11 → 03-03; partly restored 03-10, re-deleted 03-28).
  - Video lanes (07-13 → 07-25; the player was never instantiated).
- **C/R/O:** N/N/N (C++); Y/?/? (Swift)
- **Stub/overclaim:** "16K" originated here and stayed in 10 store locales until 2026-06-20.
- **Scope / Class:** YES / **REBUILD** on AVFoundation (own the workflow, integrate the codecs). **DO NOT RESTORE** the 16K/8K claims.
- **Owner:** → `ClipKind.video` (kept) + `TimelineStore`.

### F2 · Chroma key
- **Impl:** `ChromaKeyEngine` + `ChromaKey.metal` ("6-pass"). The shader was never compiled; the engine had zero constructors.
- **C/R/O:** N/N/N
- **Scope / Class:** LATER / **REBUILD**

### F3 · Video capture (P3)
- **Impl:** `VideoRecorder` / `VisualRecorder` / `VideoMuxer` — recorded the Metal visual to mp4 with an audio mux (07-01 → #1304).
- **C/R/O:** Y/Y/? — founder, "hat leider nicht geklappt".
- **Scope / Class:** YES / **REBUILD**. `SingleExport` owns the only `AVAssetWriter` today (audio).
- **Next safe slice:** a device-log review of why it failed, before any rebuild.

### F4 · VisualForge / VJ compositor / EchoelVis / quantum-photonics shaders
- **Impl:**
  - VisualForge (C++, "50+ generators") — N/N/N.
  - `EchoelVisualCompositor` + ISF parser (2026-02) — Y/?/?.
  - EchoelVis (8 modes, "120 fps", 18 days) — Y/Y/Y.
  - Quantum/photonics/holographic shaders — overclaim.
- **Scope / Class:** YES / **PORT ALGORITHM** (the ISF parser and multi-layer compositing are the reusable parts). **DO NOT RESTORE** "quantum/photonics/holographic".

### F5 · MetalBioView + floating visual window + meters
- **Impl:** re-created 2026-06-17; pinned at 60 fps. It includes `SpectralDonutView` and the four analysis meters (S4c).
- **C/R/O:** Y/Y/Y
- **Scope / Class:** YES / **CURRENT**

### F6 · Streaming video engines (8K)
- **Impl:** `ProfessionalStreamingEngine` "8K UHD".
- **Class:** **DO NOT RESTORE** the claim; see J4 for streaming.

---

## G. LIGHTING / STAGE

### G1 · Art-Net / sACN (EchoelLux lineage)
- **Impl:** MIDIToLightMapper (Blab) → C++ LightController (packet class) → `EchoelLuxEngine` (03-10 → 03-28) → today's `ArtNetSender` / `SACNSender` (unicast), with bounded in-flight and stop continuity (#1446/#1447).
- **C/R/O:** Y/Y/Y
- **Scope / Class:** YES / **CURRENT**
- **Next safe slice:** fixture profiles (`LightFixtureGroup` is unwired).

### G2 · Laser / ILDA
- **Impl:** `ILDALaserController` (2026-01, 1,027 lines, `NWConnection`); C++ LaserForce (stub, with an unsafe "audience scanning" claim).
- **Scope / Class:** RESEARCH / **RESEARCH** (laser safety is regulated; any product path integrates certified controllers).

### G3 · Push 3 LEDs
- **Impl:** real CoreMIDI SysEx (Ableton header `F0 00 21 1D`), 2025-10 → 03-03. Never device-verified.
- **Scope / Class:** LATER / **PORT ALGORITHM**

### G4 · Stage / external display / keystone / cues
- **Impl:**
  - `EchoelStageEngine` (external screen, 4-corner keystone, cues; 03-10 → 03-28).
  - Today: `ExternalDisplayScene` (system role) — **CURRENT**, not device-verified.
  - Syphon/NDI/SMPTE-2110 "transports" — stubs.
- **Scope / Class:** YES / **PORT ALGORITHM** (keystone + cues)

---

## H. SPATIAL / XR

### H1 · Historical HRTF (Blab) / SpatialForge (C++) / Swift spatial kernels
- **Impl:**
  - Blab `AVAudioEnvironmentNode` HRTF (real, with "4D Orbital / AFA" overclaims).
  - SpatialForge ("Atmos 9.1.6, 7th-order Ambisonics"; actually `sin(azimuth)` panning; never compiled).
  - Swift `AmbisonicsProcessor` / `HRTFProcessor` / `ObjectBasedAudioRenderer` / `RoomSimulation` / `Doppler` (02-13 → 03-03; real vDSP, wiring unknown).
- **Scope / Class:** YES / **PORT ALGORITHM** (the Swift kernels). **DO NOT RESTORE** the SpatialForge claims.

### H2 · Current ADM-OSC + spatial render cores
- **Impl:**
  - `ADMOSCSender` + `SpatialSceneStore` — **CURRENT** (spec addresses since #1210; default port 4001).
  - `VBAPPanner`, `AmbisonicsEncode`, `BinauralPanner`, `EchoelSpaceReverb`, `BioPhaser`, `SpatialAutomationMapping` — zero callers.
  - `ImmersiveStageView` — doorless on purpose.
- **Scope / Class:** YES / **CURRENT** (control half) + **REUSE** (render half)
- **Next safe slice:** binaural monitoring of the scene on headphones via `BinauralPanner`.

### H3 · AirPods head tracking
- **Impl:** `HeadTrackingManager` (`CMHeadphoneMotionManager`), 2025-11 → 03-03. Zero hits today.
- **Scope / Class:** LATER / **REBUILD**

### H4 · Vision / XR
- **Impl:** `Platforms/visionOS/*`, `ImmersiveQuantumSpace`, `VisionOSImmersiveEngine`. A visionOS scheme never existed.
- **C/R/O:** ?/N/N
- **Scope / Class:** YES / **REBUILD** (new target = founder-gated `project.yml`)

---

## I. BIO / SENSOR

### I1 · Camera pulse (rPPG)
- **Impl:** `CameraPPGEngine` (02-26 → 03-03) → `CameraAnalyzer` (03-04) → `CameraRPPGBioPublisher` (06-05), the flagship. Coherence accumulates since #1220.
- **C/R/O:** Y/Y/Y (locks on device)
- **Scope / Class:** YES / **CURRENT**

### I2 · BLE heart-rate strap (0x180D) · HealthKit · Watch-via-HealthKit
- **Impl:** `PolarH10BioPublisher` (universal BLE HR), `HealthKitBioPublisher`. There were four duplicate HealthKit managers historically.
- **C/R/O:** Y/Y/Y (strap not device-verified)
- **Scope / Class:** YES / **CURRENT**

### I3 · EEG
- **Impl:**
  - `EEGSensorBridge` twice: 02-04 → 03-03, and 03-21 → 04-19. Real BLE UUIDs for Muse `FE8D` / NeuroSky / OpenBCI; vDSP band power.
  - `BrainwaveModulation` core (07-20 → #1302).
  - `.eegBurst` and `/echoelmusic/bio/event/eeg` exist with zero producers.
- **C/R/O:** Y/?/? (never device-verified)
- **Scope / Class:** RESEARCH / **PORT ALGORITHM** (band power), as a modulation SOURCE only. **DO NOT RESTORE** "consciousness state" inference.

### I4 · Motion
- **Impl:** `MotionMusicController` (03-26 → 03-28), `MotionActivityProvider` (04-08 → 06-12), `SharedMotionManager`. No CoreMotion import today; `.motion.hasProducer` is false.
- **Scope / Class:** LATER / **REBUILD** (a producer for the existing `.motion` channel)

### I5 · Face / hand / gaze
- **Impl:** ARKit face (52 blend shapes), Vision hands, `GazeTracker` (→ 03-03), `SmileDetector` (03-25 → 03-31), `FaceExpressionBioPublisher` + body pose (07-18 → #1301).
- **C/R/O:** Y/Y/? (door since #1257, one day)
- **Removed because:** founder, "Face … komplett entfernen".
- **Scope / Class:** RESEARCH / **RESEARCH**. It needs a founder decision plus privacy/consent design; never emotion inference. The provenance-gating law in `ModSource.isMeasured` stays.

### I6 · Watch
- **Impl:**
  - `Platforms/watchOS/WatchApp` + `WatchConnectivityManager` (a real `WCSession`, 447 lines; 2025-11 → 03-03).
  - `EchoelmusicWatch` target (06-01): **compiled, not embedded**, no transport.
- **Scope / Class:** YES / **PORT ALGORITHM** (the WCSession code) + **REUSE** (the target)
- **Deps:** `project.yml` (founder-gated), a new framework (Council).
- **Next safe slice:** the Scheibe B of `scratchpads/PLAN_WATCH_2026-09-13.md`.

### I7 · Breathing / Session / Meditation / BreathGuide
- **Impl:** `SessionView` / `SessionEngine` / `SessionGuide` / `SessionClock` / `EntrainmentEngine` (07-05; it explicitly refuses brainwave claims), `MeditationView`, `BreathGuideView` (≤0.2 Hz flash law, contraindication confirmation).
- **C/R/O:** Y/N/Y
- **Removed because:** founder, "keine Atemübung" (home, not capability).
- **Scope / Class:** LATER / **REUSE**

### I8 · Oura
- **Impl:** `OuraRingIntegration` (01-12), `OuraRingClient` (03-21 → 06-12; OAuth PKCE with `clientID = ""`, so it could never authenticate).
- **Scope / Class:** LATER / **REBUILD** via HealthKit (no SDK).

### I9 · Weather / circadian
- **Impl:** `WeatherProvider` + `CircadianClock` (03-28 → 06-12; WeatherKit disabled for lack of entitlement). Weather colouring exists today in the Mood chip.
- **Scope / Class:** LATER / **CURRENT** (weather colouring)

### I10 · Protected DSP triad + HRV maths
- **Impl:** `BioSignalDeconvolver`, `HilbertSensorMapper`, `BioEventGraph`, `HRVMetrics`, `HRVCoherence`, `RespirationEstimator`, `PoincareMetrics`.
- **C/R/O:** Y/Y/Y
- **Scope / Class:** YES / **CURRENT** (protected, read-only)

---

## J. NETWORK / COLLAB / BROADCAST

### J1 · OSC (third generation)
- **Impl:** C++ `OSCManager` → `OSCEngine` (03) → today's `OSCSender` (bio, music, mod) + `OSCReceiver` (control in, opt-in, allowlist).
- **C/R/O:** Y/Y/Y
- **Scope / Class:** YES / **CURRENT**

### J2 · Multipeer "Live Colabo" / SharePlay / CloudKit
- **Impl:**
  - `LiveColaboView` over MultipeerConnectivity (06-23) — **CURRENT**, not device-verified.
  - `GroupActivitiesManager` (SharePlay, real API, → 03-03) — **PORT ALGORITHM**.
  - `CloudSyncManager` (real CK calls, → 03-03).
  - Today's `CloudSync` has no caller; `AnnouncementCenter` is gated off (`cloudKitConfigured = false`) — **REUSE**.

### J3 · WebRTC / server infrastructure / worldwide collaboration
- **Impl:** `CollaborationEngine` against `wss://signaling.echoelmusic.com` (does not exist), `ServerInfrastructure` against invented hosts.
- **Class:** **DO NOT RESTORE**. A real remote-collaboration capability needs a real backend decision (**REBUILD** when scoped).

### J4 · RTMP / BroadcastPublisher / streaming
- **Impl:**
  - `RTMPClient` (hand-rolled handshake + AMF0 over `NWConnection`, Blab era → 03-03; never verified against a server).
  - `LiveStreamEngine` (04-18 → 04-19; its subject said RTMP, the code wrote local mp4).
  - Today `BroadcastPublisher`: a `#if canImport(HaishinKit)` scaffold. HaishinKit is not linked.
- **Scope / Class:** YES / **REBUILD** by integrating a proven library (new dependency = founder sign-off; `docs/dev/BROADCAST_HAISHINKIT_FINISH.md`)

### J5 · NDI / Dante / AES67 / SMPTE ST 2110
- **Impl:** `NDISyphonEngine` (Bonjour only), `DanteTransport` (home-made RTP/"AES67"), `VideoNetworkTransport` ("ST 2110 8K"), `DanteAudioTransport` (no network calls).
- **Class:** **DO NOT RESTORE** the home-made transports. Integrate the NDI SDK / AES67 when scoped (**REBUILD** by integration).

### J6 · Ableton Link
- **Impl:** C++ stub; Swift `AbletonLinkClient` (clean-room wire protocol, 01-15 → 03-28, interop unverified).
- **Scope / Class:** YES / **REBUILD** via LinkKit (free, needs Council + founder dependency sign-off)

---

## K. PLATFORMS

| # | Platform | History | C/R/O | Scope / Class |
|---|---|---|---|---|
| K1 | iOS (iPhone) | live | Y/Y/Y | YES / **CURRENT** |
| K2 | iPad | switched off; 5 settings + a guard + prose (see CLAUDE.md iPad row). No torch for rPPG | —/—/— | YES / **REUSE** (settings) — needs a bio source there |
| K3 | macOS / Catalyst | targets added 2026-01-23, never reached TestFlight; Catalyst decided 06-01, never adopted | ?/N/N | YES / **REBUILD** |
| K4 | Watch | see I6 | Y/N/N | YES / **REUSE** + **PORT ALGORITHM** |
| K5 | Vision | see H4 | ?/N/N | YES / **REBUILD** |
| K6 | Android (app, Wear OS, Automotive; Oboe synth) | 2025-12 → 03-03; CI red in every sampled run; carried Quantum/SuperIntelligence modules | ?/N/N | LATER / **REBUILD** |
| K7 | Web / WASM (EchoelWeb) | Web Audio + PWA, 01-15 → 03-03; no `emcc` run, no deployment found | ?/N/N | LATER / **RESEARCH** |
| K8 | Desktop experiments (JUCE standalone, iPlug2, ASIO/JACK/PipeWire/WASAPI) | SDK-less headers; desktop CI was masked green | N/N/N | LATER / **DO NOT RESTORE** (the scaffolds) |
| K9 | tvOS, App Clip, notification service | targets 01-29 → 03-03 | ?/N/N | LATER / **REBUILD** |
| K10 | Widgets | embedded, shipped since build 1472 | Y/Y/Y | YES / **CURRENT** |

---

## L. PLUGIN ECOSYSTEM

| # | Capability | History | C/R/O | Scope / Class |
|---|---|---|---|---|
| L1 | AUv3 plugin (Echoel inside hosts) | 6 cycles; restored 2026-09-20 (#1385) as `aumu`/`echl`, loads in AUM | Y/Y/Y | YES / **CURRENT** — "runs in Logic/GarageBand" not released |
| L2 | Historical plugin hosting | `InterAppAudioManager` (02), `InterAppAudioEngine`=AUv3 host (03), `AUv3Host` / `LaneAUInstrumentHost` / `AUv3BrowserView` (06 → 07-24, #121 Slice 2) | Y/Y/Y | YES / **PORT ALGORITHM** (the `AVAudioUnitComponentManager` host path) |
| L3 | VST3 / CLAP | entry points with "replace with the real SDK" (02-20); never built | N/N/N | YES / **REBUILD** — needs a desktop target and the vendor SDKs (founder dependency sign-off) |
| L4 | AAX / OFX / DCTL / FFX | historical stubs | N/N/N | RESEARCH / **DO NOT RESTORE** the stubs |
| L5 | Common EchoelModule core | today the AUv3 compiles `DSP/` in isolation (Foundation + Accelerate only) — that isolation IS the portable core | Y/—/— | YES / **CURRENT** (as a law) — future slice: name the module boundary for L3 |

---

## M. AI

| # | Capability | History | C/R/O | Scope / Class |
|---|---|---|---|---|
| M1 | Deterministic intelligent tools | `BioComposer` (58 genres, 41 offered), `ChordSuggest`, `BioVariationMaze` ("Explore"), `SoundPrompt` (keyword mapper), key/A4/tempo detection on import | Y/Y/Y | YES / **CURRENT** — never call these "AI" in copy |
| M2 | EchoelAI shell | `BrainBackend`, `FoundationModelsBrain` (iOS 26), `ParameterToolCore`, `EchoelLanguageModel`/router, `BioMusicDirector`; zero callers; `FeatureFlags.echoelAI` has zero readers | Y/N/N | YES / **REUSE** — first slice: one caller behind an explicit user action |
| M3 | LLMService | real clients for Anthropic/OpenAI/Ollama (2026-01 → 03-03); no key entry in the app; would have sent bio context to the cloud | Y/N/N | YES (provider adapters) / **PORT ALGORITHM** — a new adapter must pass `BioEgressPolicy` and consent |
| M4 | AIComposer / AIModelLoader / MLModelManager | "CoreML-powered" with no model ever bundled; downloads from a host that served nothing | Y/?/N (as AI) | — / **DO NOT RESTORE** the claims; the algorithmic fallback lives on in M1 |
| M5 | AIComposerEngine (Markov, Euclidean) | real algorithmic composition, superseded by BioComposer | Y/?/Y | — / **PORT ALGORITHM** (Euclidean rhythms) |
| M6 | Stem separation ("Demucs v4, 8.5 dB SDR") | a fixed frequency-band mask; invented benchmark numbers | Y/?/N | YES (real separation) / **DO NOT RESTORE** the fake — **REBUILD** with a real model or provider |
| M7 | NFTFactory | "quantum-safe" minting; `"0x"+UUID` transaction hashes, `"Qm"+UUID` CIDs | Y/?/fabricated | NO / **DO NOT RESTORE** |
| M8 | SuperIntelligence / Quantum / Lambda / Echoela persona / WorldModel / PQC registry | marketing prose around parameters; random-matrix "world model"; placeholder PQC | ?/?/N | NO / **DO NOT RESTORE** |
| M9 | Legitimate future native AI | on-device models (Foundation Models), provider adapters, real stem separation, audio-to-MIDI (the historical `AudioToMIDIConverter` was plausible DSP) | — | YES / **RESEARCH** → **REBUILD** per engine |

---

## N. EXPLICITLY REJECTED — DO NOT RESTORE (science and claims)

These stay closed under FOUNDER_PRODUCT_LAW §4. The DSP underneath is sometimes real; the
framing is what is rejected.

- **Binaural / isochronic brainwave entrainment** (432 Hz "healing" carrier, 40 Hz gamma framed near Alzheimer research). Purged `cefd34f3e` (2026-03-02).
- **ResonanceHealer** (organ frequencies, Solfeggio, Schumann, chakra tuning). Purged `a7e605bb2` (2026-01-09).
- **"Biophysical" cluster** ("bone harmony", tissue resonance, EVM of "tissue micro-movements"), **NeuroSpiritual** (consciousness states without EEG), **ClinicalEvidenceBase** (therapy interventions), **wellness therapy headers** (colour-light therapy, vibrotherapy).
- **Longevity / nutrition advice**, **Adey EMF engine**, **astronaut health**, **CoherenceCore** (vibroacoustic therapy monorepo).
- **Overclaims:** "16K", "8K @ 60 fps ST 2110", "38 languages" (about 33 keys each), "quantum-safe", "SuperIntelligence", "Nobel Prize Multitrillion Dollar" modules, fabricated export sizes and hashes.

---

## Recovery-class counts

Primary class per entry (A1…M9; table rows count one each; section N counts once). Several
entries carry a second class (e.g. D1 = CURRENT + REBUILD); only the first is counted here.
Hand-tallied on 2026-09-24 — the entries mix list and table form, so no single `grep` re-derives
it. Treat it as a dated snapshot (#818), not a pinned number.

| Class | Entries |
|---|---|
| CURRENT | 25 |
| REUSE | 10 |
| PORT ALGORITHM | 20 |
| REBUILD | 25 |
| RESEARCH | 5 |
| DO NOT RESTORE | 12 |
| **Total** | **97** |

---

## Current defects discovered while building this register

- **D1 · export can clip.** `SingleExport.normalizeGainDB` allows up to +12 dB, then applies it with `vDSP_vsmul`, and **no limiter or ceiling follows**. The captured source is already peak-limited near 0 dBFS, so a sparse take read at −20 against a −14 target is written about 6 dB over full scale into a 24-bit integer WAV. Code-read; not device-verified.
- **D2 · two loudness engines disagree.** The meter shown is R128. The auto-gain and the export normaliser steer by unweighted RMS.
- **D3 · K-weighting coefficients are the 48 kHz set at every sample rate.** A documented approximation; the offset at 44.1 kHz has not been measured. → **REPAIRED by E3 (2026-09-24, `2e6b54d66`).** Measured before the repair: +1.13 dB at 20 Hz, +0.40 dB at 60 Hz, +0.33 dB at 1.5 kHz at 44.1 kHz. After: within 0.005 dB of the standard at 44.1 kHz; the export now takes peak and loudness in one 44.1 kHz decode.
- **D4 · stale header claims in `EchoelDDSP.swift`.** "FIR noise"; "LF/HF → reverb".
- **D5 · `SamplerVoice` has no loader.** No UI can load a sample into the rack slot.
- **D6 · no undo** anywhere, while editing capabilities are in scope.

### Export-quality repair — readiness

**READY** as a bounded slice:
1. a true-peak-aware ceiling after the normalisation gain;
2. the normaliser measured by `EchoelLoudnessMeter` over the loop window instead of RMS;
3. a guard that pins the ceiling.

The DSP is small, owned by one file (`Audio/SingleExport.swift`), audio-thread-free (it runs in an export queue), and blocked by nothing founder-gated. It changes what the exported file sounds like, so it needs a device listen after CI.

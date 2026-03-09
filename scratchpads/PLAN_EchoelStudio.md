# PLAN: EchoelStudio — Unified Creative Workspace

**Date:** 2026-03-09
**Branch:** `claude/implement-todo-item-Jz0Pa`
**Goal:** Merge 5 separate tabs (DAW, Live, Synth, FX, Video) into one unified BPM-synchronized view called **EchoelStudio**.

---

## Problem Statement

Currently the app has 5 isolated tabs in `MainNavigationHub`:
- **DAW** → `DAWArrangementView` (audio arrangement + recording)
- **Live** → `SessionClipView` (Ableton-style clip launcher)
- **Synth** → `EchoelSynthView` (keyboard, drums, bass, presets)
- **FX** → `EchoelFXView` (effects node graph)
- **Video** → `VideoEditorView` (NLE with own timeline + AVPlayer)

**Issues:**
1. Video timeline not BPM-synchronized with audio timeline
2. Synth not connected to arrangement tracks
3. FX is global, not per-track
4. User must constantly switch tabs to do anything useful
5. VideoEditorView creates its own `VideoEditingEngine()` instead of using `workspace.videoEditor`

---

## Target Architecture

```
EchoelStudio (one view)
┌────────────────────────────────────────────────────────────────────┐
│ Header: [Arrangement │ Session] toggle    [Video Preview toggle]   │
├──────────┬─────────────────────────────────────────────────────────┤
│ Track    │ Unified BPM Timeline (shared pixelsPerSecond + zoom)    │
│ List     │ ═══════════════════════════════════════════════════════  │
│          │  🎵 Audio 1    ▓▓▓▓░░▓▓▓▓▓░░░░░                        │
│          │  🎵 Audio 2    ░░▓▓▓▓░░░░▓▓▓░░░                        │
│          │  🎹 MIDI 1     ♩♩♩♩░░♩♩░░♩♩♩♩░                        │
│          │  🎬 Video      🟦🟦🟦🟦░░🟩🟩🟩🟩░░░                  │
│          │  🔊 Master     [master fader + metering]                │
├──────────┴─────────────────────────────────────────────────────────┤
│ Bottom Panel (toggleable):                                         │
│   [🎹 Instruments] [🔊 Mixer] [🎨 FX] [🎬 Video Preview]         │
│   ┌────────────────────────────────────────────────────────────┐   │
│   │ Current panel content (Keys/Drums/Bass/Mixer/FX/Preview)  │   │
│   └────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
Transport Bar (unchanged — already shared)
```

---

## Implementation Cycles (Ralph Wiggum Lambda)

### Cycle 0: Preparation — Fix VideoEditorView Engine Wiring
**Files:** `VideoEditorView.swift`
**Change:** Use `workspace.videoEditor` instead of creating local `VideoEditingEngine()`
**Why:** Without this, video and audio are on separate engines
**Test:** Verify BPM change in workspace propagates to video timeline

### Cycle 1: Create EchoelStudioView Shell
**Files:** `EchoelStudioView.swift` (NEW), `MainNavigationHub.swift`
**Change:**
- Create `EchoelStudioView` that combines DAW arrangement + video track
- Replace 5-tab system with single view in `MainNavigationHub`
- Keep transport bar exactly as-is
- Keep sidebar for future panels (but remove tab switching)
**Layout:**
- Top: Track list + unified timeline (from DAWArrangementView)
- Bottom: Toggleable panel area (empty initially)
**Test:** Build succeeds, app shows unified timeline

### Cycle 2: Video Track in Timeline
**Files:** `EchoelStudioView.swift`, `DAWArrangementView.swift`
**Change:**
- Add video track type to timeline (thumbnail strip synced to BPM grid)
- Video preview as floating/dockable panel
- Video track uses same `pixelsPerSecond` and zoom as audio tracks
**Test:** Video clips appear on timeline, scroll/zoom with audio tracks

### Cycle 3: Instrument Drawer (Bottom Panel)
**Files:** `EchoelStudioView.swift`
**Change:**
- Bottom panel with tabs: Instruments | Mixer | FX | Video Preview
- Instruments tab embeds `EchoelSynthView` content (keys, drums, bass, presets)
- Panel is collapsible (drag handle or button)
**Test:** Instrument drawer opens/closes, synth panels work

### Cycle 4: Mixer Panel
**Files:** `EchoelStudioView.swift`
**Change:**
- Mixer tab in bottom panel shows channel strips from `ProMixEngine`
- Per-track volume, pan, mute, solo (already exists in ProMixEngine)
- Linked to track list (selecting track highlights channel)
**Test:** Mixer shows channels matching tracks, controls work

### Cycle 5: FX Per-Track Panel
**Files:** `EchoelStudioView.swift`
**Change:**
- FX tab shows insert chain for selected track
- Reuse existing `EchoelFXView` content but scoped to selected track's channel strip
- 4 insert slots per channel (already modeled in ProMixEngine)
**Test:** Select track → FX panel shows that track's inserts

### Cycle 6: Session/Arrangement Toggle
**Files:** `EchoelStudioView.swift`
**Change:**
- Header button toggles between Arrangement view and Session clip grid
- Arrangement = timeline view (default)
- Session = clip launcher grid (from `SessionClipView`)
- Both share same tracks and engine
**Test:** Toggle switches view, playback state preserved

### Cycle 7: Polish & Mobile Layout
**Files:** `EchoelStudioView.swift`
**Change:**
- iPhone: Stack vertically (timeline top, panel bottom, no sidebar)
- iPad: Side-by-side with collapsible panels
- Remove old tab views (cleanup dead code)
**Test:** Works on both iPhone and iPad layouts

---

## Files Affected (Summary)

| File | Action |
|------|--------|
| `EchoelStudioView.swift` | **CREATE** — Main unified view |
| `MainNavigationHub.swift` | **MODIFY** — Remove 5-tab system, embed EchoelStudio |
| `VideoEditorView.swift` | **MODIFY** — Use workspace.videoEditor |
| `DAWArrangementView.swift` | **EXTRACT** — Timeline rendering becomes reusable |
| `EchoelSynthView.swift` | **KEEP** — Embedded as panel content |
| `EchoelFXView.swift` | **KEEP** — Embedded as panel content |
| `SessionClipView.swift` | **KEEP** — Used in Session toggle mode |
| `EchoelmusicApp.swift` | **NO CHANGE** — Init sequence stays |
| `EchoelCreativeWorkspace.swift` | **NO CHANGE** — Already wired correctly |

---

## What Gets Deleted Eventually

After all cycles:
- `MainNavigationHub.Tab` enum (no more tabs)
- `mobileTabBar` (replaced by bottom panel tabs)
- Standalone video editor entry point (merged into studio)

---

## What Does NOT Change

- Transport bar (already shared, works great)
- Audio engine pipeline (AudioEngine → ProMixEngine → hardware)
- EchoelCreativeWorkspace (already the central hub)
- Recording engine
- BPM grid engine
- All DSP/bio algorithms
- Settings view
- Session/Track data model

---

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Massive single view = slow rendering | Use `@ViewBuilder` + lazy sections, isolate redraws |
| Video preview performance | Keep Metal rendering in isolated subview |
| Breaking existing functionality | Each cycle builds on previous, tests after each |
| Mobile layout complexity | iPhone gets simplified version (no sidebar) |

---

## Success Criteria

1. One view, one timeline, audio + video synchronized
2. All existing functionality accessible (synth, fx, mixer, recording)
3. BPM grid applies to both audio and video tracks
4. No new dependencies, no new targets
5. Build and tests pass after each cycle
6. Transport bar, bio-feedback, metering all work as before

---

## Order of Execution

```
Cycle 0 → Cycle 1 → Cycle 2 → Cycle 3 → Cycle 4 → Cycle 5 → Cycle 6 → Cycle 7
  Fix       Shell     Video     Instru-   Mixer     FX per    Session   Polish
  wiring              track     ments               track     toggle
```

Each cycle: ONE commit, build, test, evaluate. No batching.

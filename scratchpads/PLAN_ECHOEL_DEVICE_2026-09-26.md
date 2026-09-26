# PLAN — Echoel as flagship Device (Phase 3, founder order 2026-09-25)

Status: EF1 + EF2 SHIPPED · EF3 DEFERRED (decision below) · 2026-09-26

## Census summary (measured before this plan)
- The Echoel instrument's state is APP-GLOBAL today: genre `@AppStorage studio.genre` (5 writers),
  FX character `@AppStorage studio.fxCharacter` (2 writers: the Effects-panel Picker and `open(_:)`).
- Per-song it already round-trips through the Project TAKE fields (`fxCharacterRaw` …), not through
  the song document. The song (`TimelineDocument`) carries NO trace of which Echoel it plays.
- What plays a lane is DERIVED: the roll lane (first non-bio MIDI lane) plays Echoel;
  `builtinInstrument` names rack voices. DC1 (`DeviceChain.inserts`) sounds on rack POLY voices only;
  its header reserves the instrument slot for "when the Echoel device becomes an instance".
- The Workstation's Echoel track shows the instance read-only (`EchoelInstanceLine`), and its
  Effect row is hidden (`TrackMix.controls … effect: false`).
- WA3 §A.2 typeID for the Echoel device: `com.echoelmusic.device.echoel`
  (`EchoelInstanceState.deviceType = "echoel.instrument"` is an unpersisted label, not a typeID).

## Council — EF1: move the Echoel FX character's OWNER onto the roll lane's instrument insert
· Architect: proceed — one owner on the song, the `@AppStorage` key demoted to the instrument's
  working copy; concern: every writer of the copy must also write the owner, or the two split.
· Skeptic: the split is the failure mode — Live Colabo / shared-document opens call `open(_:)`
  alone, so `open(_:)` itself must write the owner, and the adoption after `restoreSong` must win.
  A later build's Echoel instance (typeVersion 2) must never be overwritten by an import.
· Shipper: one fact (FX character) only — genre, patch, mood stay app-global this slice.
· User-Advocate: the reachable workflow is "select the Echoel track → pick its Effect → hear it";
  the row must not show a guess when no instance exists yet.
· Aesthetic Maximalist: `.auto` (genre's effect) must be offered on the Echoel track — it is the
  default most players hear.
→ Recommendation: EF1 as below. Gate: proceed-with-mitigation (the four sync points are named and
  guarded; no instrument-slot DERIVATION change — the roll-lane rule stays the one truth of WHAT
  plays; the instance carries only HOW it is set).

## EF1 — shape
1. `DeviceChain.instrument: DeviceInsert?` under the existing `deviceChain` key (own coding key,
   `try?`-decoded; absent → same bytes as DC1). A chain is stored as none only when it has no
   inserts AND no instrument (`isEmpty`). `settingCharacter` keeps the instrument.
2. `DeviceInsert.echoelTypeID = "com.echoelmusic.device.echoel"`, `echoelTypeVersion = 1`;
   state = sorted-keys JSON `[String: String]`, one key today (`fxCharacter`); unknown keys are
   KEPT on rewrite; a later version / other type is never read nor rewritten.
3. `TimelineDocument.echoelFXCharacter` — the roll lane's readable instance value, nil otherwise.
4. `TimelineStore.setEchoelFXCharacter(_:)` — THE one writer; roll lane only; removes a stale
   Echoel instance from any other lane (one instance per song); refuses to rewrite an unreadable
   instance; no-op when unchanged.
5. ESV (no body read of `timeline.document`): the Effects Picker's `onChange` and `open(_:)` write
   the owner; `adoptEchoelFXFromSong()` (owner → copy, or import copy → owner when absent) runs at
   launch, after `restoreSong` in `openFromLibrary`, and on `.echoelCompositionEdited "fxCharacter"`.
6. Workstation inspector: the Echoel track gets an Effect row (incl. "Auto (genre)") ONLY when the
   song has a readable instance (`controls.effect`); it writes the store and posts
   `.echoelCompositionEdited "fxCharacter"` so the instrument adopts and sounds it.

## Evidence plan
COMPILES (Compile Check + BfT) · TESTED (new guard: pure chain/insert, decode, real-store writer,
inspector gating, ESV sync-point scans) · REVIEWED (independent reviewer) · DEVICE = open
(founder: pick an effect on the Echoel track, hear it; relaunch; Save → Open another → back).

## Next slices (not started)
EF2 genre onto the instance · EF3 patch identity onto the instance · then Clips/Scenes/Session.

## As built + review (2026-09-26)
- EF1 6d68bea64; review repair fce169210 (independent review: no HIGH; M1 doc capture, M2 stale
  contract, M3 roll lane appearing after launch had no instance → inspector now requests it on
  appear; L3/L4 guard sharpened; L5–L7 docs).
- OPEN L1: an Effects pick is written to `@AppStorage` at once, the song after a 250 ms debounce;
  a kill inside that window lets the older song win at the next launch's adoption (a normal
  suspend flushes). Candidate fix: flush on the Effects-pick write, or adopt only when the
  song's save is newer — decide with EF2.
- OPEN L2: the owner write rides `.onChange(of: fxCharacter)`; a gesture-only Binding (the #1371
  shape) is the stronger form. Harmless today (programmatic writes re-state the same value).

## EF2 — the genre as the instance's second fact (2026-09-26)
- SHAPE: same instance, second field `genre` (v1 stays string-valued); `settingEchoelField` is the
  one rewrite path both facts share (later version / other type / non-v1 state → refused).
  `TimelineStore.writeEchoelField` is the one store body; `setEchoelGenre` beside
  `setEchoelFXCharacter`. `TimelineDocument.echoelGenre` reads the roll lane only.
- OWNER/COPY: the song owns the genre; `StudioDefaultKeys.genre` (`style`) is the working copy.
  Writers of the copy write the song: the genre case of `handleCompositionEdit` (header Picker +
  OSC remote both reach it) FIRST, `open(_:)`, the Sound reset. Readers adopt: launch (silent,
  genre BEFORE the FX character, whose stamp reads `style`), after a library Open (silent — a
  loaded take's saved notes must not be recomposed), the Workstation edit `"echoelGenre"`
  (announced: the full genre semantics incl. recompose). An un-offered song genre is replaced by
  the copy, never adopted into an unreachable row.
- WORKSTATION: `echoelGenreRow` (menu Picker, header's own shelf root) on the Echoel track, only
  once the song holds a genre; `requestEchoelInstanceIfMissing` imports each missing fact once
  (an EF1 song gains its genre on first open).
- L1 applies to the genre as well (debounced song write vs immediate `@AppStorage`); still OPEN,
  same candidate fix. Divergence case recorded: a Project whose saved `style` differs from its
  song's genre — the song wins after a library Open, silently (scale/timbre not re-derived).
- EVIDENCE: COMPILES pending (gates) · TESTED by claims 8/9 (forward) · REVIEWED · DEVICE open.
- REVIEW of 83b617760 (no HIGH): MED-1 REPAIRED — a recovery row can pair a take with a song from
  another moment, so `openFromLibrary` now writes the TAKE's genre into the song (the loaded
  notes/scale/timbre are the take's) instead of adopting the song's; the "divergence case" above
  is therefore resolved in the take's favour. LOW-1 OPEN (an OSC genre outside `offered` reaches
  the song until the next launch; pre-existing for the header; an `offered` check in the genre
  case collides with `LaunchLogsWhatItWokeUpWithTests`' sole-index pin — deliberately not done).
  LOW-2 = L1. LOW-3 doc corrected.

## EF3 (patch identity) — DEFERRED, Council 2026-09-26
· Skeptic: `currentPatch` has 13 writers in `EchoelStudioView`, is NOT persisted across launches
  (launch = `SynthPatch.factory[studio.presetIndex]` or the genre's patch), and the TAKE already
  carries it (`Project.patch`, restored by `open(_:)`). Moving it onto the song re-creates the
  MED-1 take-vs-song conflict on the largest value of all.
· Aesthetic Maximalist: the sound matters most, but the Sound chip already reaches it (presets,
  save-as); a song-owned patch adds no new playable range.
· Shipper / User-Advocate: EF1+EF2 make the instance real, song-carried and Workstation-reachable;
  the founder's order continues with Clips/Scenes/Session.
→ EF closes at EF2. Re-open EF3 only with a decision on WHO owns the patch (take vs song), which is
  the Clips/Scenes question itself — a clip carrying its own sound is where it belongs, if anywhere.

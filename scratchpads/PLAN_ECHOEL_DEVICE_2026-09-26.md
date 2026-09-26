# PLAN — Echoel as flagship Device (Phase 3, founder order 2026-09-25)

Status: EF1 IN PROGRESS · 2026-09-26

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

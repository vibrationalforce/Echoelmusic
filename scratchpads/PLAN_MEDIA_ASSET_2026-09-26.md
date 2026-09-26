# PLAN — MediaAsset + lazy Browser (Phase 3, after the MIDI editor)

Founder order (2026-09-25, "CLOSE WA4, THEN CREATION WORKFLOW"): MIDI editor → **MediaAsset + lazy
Browser** → native DeviceChain → Echoel as flagship Device → Clips/Scenes/Session → Automation
editing → Recording/Input. Every slice ships architectural progress + a reachable user workflow +
behavioural verification.

## Census (read-only, 2026-09-26 00:30Z)

- **`Core/MediaLibrary`** owns the managed homes `Media/Audio` · `Media/Video` · `Media/Image` in the
  App Group container. `importAudio` copies a picked file under a readable, collision-free name
  (O11). `resolveRef` is THE resolver. It re-roots a dead absolute path BY FILE NAME against the
  homes (H6, container UUID changes on update/migration).
  ⇒ **The durable identity of a managed file is already (home, file name), not its absolute path.**
- **`Sequencer/AudioImport`** is the transaction: copy → measure the COPY → `Clip(kind: .audio)` into a
  free `ClipStore` slot → `TimelineRegion` via `TimelineStore.addRegion` (one undo step).
  - On failure it deletes ONLY the copy it just made. Its header forbids any orphan sweep (#527).
- **`ClipStore`** has 8 fixed slots (compatibility, not a future capacity). Identity is `Clip.id`.
  `Clip` is overloaded: it is both the source-media record (`mediaRef`, `nativeDurationSeconds`,
  `nativeBPM`) and the creative content. `SESSION_OWNERSHIP_CENSUS.md` §L calls a `MediaAsset`
  "justified, not introduced here".
- **Importing the same file twice** gives two copies and two clips, and spends two slots.
- **Nothing lists the library.** A file imported once can only be used again by picking it from
  Files again, which makes a new copy and spends a new slot. `HISTORY_ARCHIVE` D7 marks the
  browser YES / **REBUILD on the managed `MediaLibrary`** (`BrowserView`/`SampleBrowserView`
  were deleted 07-27).
- **Guards that move with this phase:**
  - `TheWorkstationImportsAudioTests` claim 14 forbids any `MediaAsset` type "until it lands as a
    decision" (#364: *"not yet", not "never"*).
  - Claim 16 forbids `MediaLibrary.` in `WorkstationView`, so the browser is its own leaf file.
  - The `importRow` doc says "no browser — the surface this phase was told not to grow". That is
    the Audio Import V1 phase; the founder's new order lifts it.
  - `TheWorkstationHasADoorTests` claim F says `WorkstationView` sends `timeline` only
    `document`. The leaf reads the stores itself and a helper owns the writes (the
    `PartNoteEditor` / `AudioImport.addAudioTrack` shape).

## Council — the identity and the persistence question

- **Architect:** the identity is (kind, managed file name), the key `resolveRef` already honours,
  and there is NO index file: the directory is the truth for "which files exist", `ClipStore` is
  the truth for "who uses them". A fifth persistence root (Ω49) is what an asset registry most
  naturally grows; do not grow it.
- **Skeptic:** a content hash is the "real" dedup identity. Reading whole WAVs on the main actor
  at import is a freeze, though, and a hash stored nowhere gets recomputed on every listing.
  Dedup is a separate slice (MA2). (As built it runs on the main actor, CAPPED — see MA2 below.)
- **Shipper:** MA1 = the type + the lazy list + "Place". That is the smallest slice that gives the
  user something they could not do before: reuse an imported file without Files, without a new
  copy, and without a new slot.
- **User-Advocate:** list only Audio. The Video and Image homes have no live consumer since #1304,
  so listing them would advertise a capability that is absent.
- **DSP Purist:** nothing on the audio thread. Placement is an ordinary region; playback is the
  existing `AudioLanePlayer`.
- **→ Gate: proceed.** Log: `decisions.csv` + `memory/decisions.md` (MediaAsset identity =
  home + name; no index; Audio-only browser).

## Slices

### MA1 — MediaAsset + the lazy library list + "Place" (this cycle)

- `Core/MediaAsset.swift` (pure, Foundation-only):
  - `MediaAsset` { `kind` (.audio for now; enum ready for .video/.image), `fileName`,
    `byteSize` }.
  - `MediaAsset.Key` = kind + fileName.
  - `key(forRef:)` normalises ANY stored `mediaRef` (current path, dead-container path) by its
    `Media/<Home>/<name>` tail. It returns nil for anything else (bundle refs, `Documents/Videos`,
    empty).
  - `usage(of:clips:document:)` returns the clips that carry the asset and the count of parts in
    the song playing those clips.
  - `sorted(_:)` sorts by name, case-insensitive and locale-aware.
- `MediaLibrary.listAudio()`: ONE `contentsOfDirectory(includingPropertiesForKeys: [.fileSizeKey])`
  → `[MediaAsset]`. It is called only OFF the main actor, from the leaf.
- `Sequencer/MediaPlacement.swift`:
  - `plan(asset:clips:document:bpm:)` returns one of:
    - `.reuse(region)` — a clip already carries this asset: a new region with THAT clip id on the
      import's lane (`AudioImport.firstImportableAudioLane`, #416) at `nextStartTick`, length from
      the clip's own duration. No slot is spent, no copy is made.
    - `.needsClip` — an orphan file.
    - `.failure(.noAudioLane / .unknownLength)`.
  - `place(...)` is the ONE writer:
    - reuse → `timeline.addRegion` (one undo step);
    - orphan → `AudioImport.commit` with `importFile = identity` and
      `deleteManagedCopy = no-op`. **The browser never deletes a file.**
  - Returns the landing so the leaf selects it.
- `Studio/MediaBrowserView.swift` (leaf, mounted in `WorkstationView` under the import rows):
  - a "Media" switch;
  - when it opens: one detached listing, and a LazyVStack of rows (name, size, "in N parts" /
    "not in the song");
  - "Place" on each row: selects the landed part and says what happened on its own line;
  - an empty state that names Import Audio.
  - No modal, no `@AppStorage`, no hot reads.
- Guard `TheMediaLibraryIsBrowsedAndPlacedTests`:
  - pure key cases;
  - usage;
  - plan: reuse / orphan / no lane / unknown length;
  - real-store: reuse spends no slot and is one undo step; orphan never deletes;
  - source scan: the listing runs detached, not in `body`; the leaf is mounted; no `.sheet`.
- Moved in the same commit:
  - claim 14, which inverts to "exactly one MediaAsset declaration, in Core/MediaAsset.swift";
  - the `importRow` doc;
  - this plan.
- Device check: NEEDS-FOUNDER-VERIFY.

### MA2 — de-duplicate on import

- Before copying a picked file, look for a managed Audio asset with the SAME byte size.
- For such a candidate, compare the content byte-for-byte in chunks.
- On a match, reuse the asset and its clip (if any) instead of a second copy and a second slot.
- ⭐ DESIGN (measured 2026-09-26 00:35Z): the import is ALREADY main-actor synchronous and
  already COPIES the whole file on the main actor (`MediaLibrary.importAudio` inside
  `AudioImport.perform`). ⛔ The next sentence stood here and the review of 7b691faf8 refuted it:
  "a compare reads at most the bytes the copy it replaces would read and write" — false, because
  `FileManager.copyItem` CLONES on APFS, so a same-volume copy costs about nothing and an
  uncapped compare would be a NEW freeze. As built (e23c0ed92) the compare is CAPPED instead:
  size filter first, only files ≤ `MediaLibrary.dedupByteCeiling` (32 MiB), a 64 KB head probe,
  1 MB chunks, and no compare at all without an audio track. So MA2 still does NOT need the
  async rewrite; moving the whole import off-main is its own, larger slice (it
  reshapes `handleImport` and many needles in `TheWorkstationImportsAudioTests`).
- Shape: `MediaLibrary.existingAudio(matching:)` (size filter over `listAudio`, then a chunked
  `FileHandle` compare) → if found, `AudioImport.perform` hands the EXISTING asset to
  `MediaPlacement.place` and reports a `Landing` built from it; else today's copy path,
  unchanged. The de-dup branch never reaches `commit`'s delete.
- Guard: equal bytes → no new file in the home and no new slot; one differing byte → a copy; a
  same-size different file → a copy; the de-dup branch cannot delete.
- **BUILT 2026-09-26** (`MediaLibrary.existingAudio`/`identicalAudio`/`sameBytes`,
  `AudioImport.preferredExisting`/`landExisting`, `Landing.reusedLibraryFile`, `MediaPlacement.Placed`
  now carries `clip` + `slotIndex`). One refinement over the design: of several identical files
  (a pre-MA2 library can hold two), the one a clip already plays wins, so the reuse spends no
  slot. Guard: `TheImportReusesAnIdenticalLibraryFileTests`. Device: NEEDS-FOUNDER-VERIFY.

### MA3 — asset facts + remove an unused file (HOLD until measured)

- Duration, rate and channels, measured lazily per visible row.
- "Remove from library" only when NO clip in ClipStore AND no saved project in the library
  references it. Saved projects can carry clips (#527 hazard), so this needs its own census of
  `ProjectStore` first. It is destructive, so the user confirms. Not started until that census
  exists.

## Out of scope (founder list)

- video / image browsing;
- tags;
- search over a remote catalogue;
- sample instruments;
- plugin hosting.

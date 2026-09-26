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

### MA3 — READ-ONLY REFERENCE CENSUS (done 2026-09-26 ~13:10Z, HEAD `818325672`; nothing deleted or migrated)

Founder direction 2026-09-26 ("CLOSE MIDI EVIDENCE, THEN MEDIA ASSET / BROWSER"): MA3 first as
read-only forensics. Measured by a read-only census agent, key claims re-read by hand
(`AudioClipFactory.swift:18-22`, `DMMWProject.swift:117-135`, `MediaAsset.swift:90-108/147-161`,
`MediaLibrary.swift:179-198`).

| question | answer today |
|---|---|
| persistent owner of a media reference | `Clip.mediaRef: String?` — in `ClipStore.slots` (8 fixed, `AppGroupStore "Clips"`) AND in every saved project. `TimelineRegion` holds only `clipID`. A second kind: `TimelineLane.samplePath` (absolute, writer has no production caller; old documents can carry it) |
| form of `mediaRef` | ABSOLUTE path into the App Group `Media/Audio` home (container UUID can change → `resolveRef` re-roots by file name, H6). Not a bookmark, not relative, not a UUID |
| writers | `AudioImport.plan` (import, MA2 reuse, orphan placement) · `TakeRecorder.finish` (unreachable, recorder nil since #1302) · wholesale: `ClipStore.replaceSlots` (Open) and `ClipStore.init` (load) |
| saved projects | `ProjectStore` → `Project.sessionEnvelope: Data?` (opaque) → `DMMWProject.Content { timeline, clipSlots: [Clip?] }` — a FULL COPY of the grid, paths included, in every saved row AND the autosave/recovery row. Decoded only at Open; `.newer`/`.unreadable` envelopes are never decoded. Shares/Colabo strip the envelope |
| shared use | many regions → one clip (Place reuse, duplicate, split); many clips → one file (orphan placement, pre-MA2 duplicates); many saved rows → one file (every save snapshots the grid) |
| managed home | App Group `Media/Audio` (fallback Application Support, then temp). Readable collision-free names; `uniqueName` avoids only names that exist NOW → a freed name would be handed out again |
| missing media | `resolveRef` nil → the part is skipped; Play greys out via `canPlay`. NO missing label, NO relink, NO per-part reason. The library lists only files that exist, so a clip whose file is gone is invisible there |
| delete helpers | only `AudioImport`'s abort of the copy it just made. `ClipStore.clear(at:)` and `AppGroupStore.delete(name:)` have no caller. Region/lane/project deletes never touch files |
| outside the home | `resolveRef` accepts ANY existing absolute path (no containment); old documents can hold bare names, `Documents/Videos`, bundle `drum:`/`lib:` refs in `samplePath`. `Documents/Recordings` (RetroCapture) and `Documents/Exports` are unmanaged and unreferenced |
| derivatives | none on disk (no waveform cache, thumbnails, proxies; analysis → `Clip.nativeBPM` or prose) |
| launch cost | none from media: listing only while the browser is open (detached); `fileExists` probes in `songCanStart()`/`SessionLaunchView` on document/grid change only |
| cleanup classification | IMPOSSIBLE today: `MediaAsset.usage` sees the live grid + live song only — not saved rows, not autosave, not `samplePath`, not legacy bare refs (which play but have no key) |

**Hazards a naive "delete unused" would hit:** (1) "not in the song" ≠ unused — a saved project or
the autosave row may be the only owner; (2) bare-name legacy refs play but count as unused;
(3) `samplePath` lanes are invisible to usage; (4) `.newer`/`.unreadable` rows make "unreferenced"
UNPROVABLE; (5) name reuse after a delete silently rebinds old refs to a different file (exact
path or H6 re-root); (6) H6 matches a dead path by name across all three homes; (7) `resolveRef`
plays files outside `Media/`; (8) region-less clips still own their file.

### Revised order (Council 2026-09-26, after the census)

- Architect: every browser slice is a PROJECTION over what is already in memory; no index file, no
  new persistence root. Identity stays (home, file name); `Clip.id` never doubles as it.
- Skeptic: deletion is the only irreversible step and the census shows it is undecidable today.
- User-Advocate: a missing file is SILENT today (Play just greys out) — the identity law says
  availability must read "missing" and relink must stay possible.
- Shipper: the first browser loop lacks exactly SEARCH/FILTER and PREVIEW. Filter is the smallest.
- → Gate: proceed with B1; deletion HOLD.

- **B1 — filter by name** (this cycle): a name field in the open list; a pure
  `MediaAsset.matching(_:query:)` (case- and diacritic-insensitive, order kept) over the listing
  already in memory. No new I/O, nothing while closed.
- **B2 — missing media is named, relink stays possible**: a projection of the live grid's audio
  clips whose `mediaRef` does not resolve (computed in the browser's detached task, only while
  open); a "Missing on this device" section with the clip name and the parts that use it; Relink =
  choose a library file → ONE `ClipStore` writer replaces `mediaRef` (+ re-measured length), keeping
  `Clip.id`, regions and name. Needs its own Council (undo? duration change vs. placed lengths).
- **B3 — preview** (audition a library file): needs an audio-graph owner (the existing audition
  voice?) — design first; device-gated for sound.
- **Remove / delete — HOLD.** Prerequisites before any code: (a) a census that decodes every
  `ProjectStore` envelope incl. the autosave row and REFUSES when any row is `.newer`/`.unreadable`;
  (b) counts `samplePath` and bare-name refs by name; (c) "remove from library view" and "delete
  managed file" are two different actions, the second confirmed; (d) a freed name is never handed
  out again (or refs carry more than the name); (e) never touches files outside `Media/`.

### Shipped (2026-09-26)

| slice | commit | what | evidence |
|---|---|---|---|
| B1 filter | `1013dab43` | `MediaAsset.matching`, "Filter by name" field, "N of M files" | guard claim 7; reviewed (LOW B1/B2 → `a68bf05fa`) |
| B2a missing named | `6bf47f8b9` | `MediaAsset.missing`, "Missing on this device" section, asked of `AudioLanePlayer.resolvedURL` once per open listing | guard claim 8; review running |
| B2b relink | `aa7089d90` | `MediaRelink` + `ClipStore.relinkAudio` (one writer), Relink menu over the filtered library | guard claim 9; review running |
| review LOWs | `a68bf05fa` | count line only beside a non-empty result; label hidden from VoiceOver; note-canvas move preview = commit | guard claim 5 (drag guard) |

B2 Council decisions (made while building, recorded here so they are not re-litigated):
- **Same recording only.** A clip with a known length refuses a file of another length
  (tolerance `max(50 ms, 1 %)`); a different sound is a new part (Place). A clip that never
  learned its length takes the file's.
- **Not an Undo step.** The history holds the song; a clip's file is clip state like its tempo.
  Relinking again undoes it.
- **Never a file operation.** The chosen file is used where it is.
- ⚠️ The measurement runs on the tap (one header read, main actor) — device-unconfirmed.

Evidence level for all four: compiles only when the gates say so (pending at time of writing);
execution of claims 7–9 is UNRECORDED until an xcresult or targeted run exists (same #396/#807
limit as the MIDI slices); device acceptance is the founder's:
NEEDS-FOUNDER-VERIFY lives in the guard header.

## Out of scope (founder list)

- video / image browsing;
- tags;
- search over a remote catalogue;
- sample instruments;
- plugin hosting.

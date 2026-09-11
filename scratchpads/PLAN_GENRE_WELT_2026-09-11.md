# PLAN — Genre-Welt (Rubriken · Unterrubriken · alle Kulturkreise · nie gleich klingen) — 2026-09-11

**Founder-Ask (2026-09-11, wörtlich):** „Baue alles ultraplan ultraechoel ultracode inklusive Genre Optimierung
Erweiterung es soll nie gleich klingen aber trotzdem sehr musikalisch und authentisch es soll mehr Genre Rubriken
und unterrubriken geben für jeden und alle Kulturkreise inkl underground und traditionelle sowie verschieden
klassische spirituelle und populäre Stile."

**Gesetze, die über diesem Plan stehen:** Instrument, kein Wellness-Produkt (CLAUDE.md BRAND) — spirituelle
Traditionen NUR als MUSIKALISCHE Traditionen mit neutralem Vokabular (`TheGenreVocabularyStaysNeutralTests`);
keine Künstler-/Label-/Film-/Stadt-/Hardware-Namen; Englisch als Basissprache; kein neuer Modal; keine Drums
(stumm), keine Leads (`leadDensity` 0, Wächter); keine Differenzierung über Tempo/Drums; Transport bleibt 4/4×16;
persistierte `rawValue`s werden nie umbenannt; Variation als opt-in `Input`-Feld mit byte-identischem nil-Pfad;
`GenreFamilyDistinctnessTests` (7-Tupel-Fingerprint über `offered`) darf nie rot werden.

## §0 Karte (Understand-Workflow wf_eda72a9f-8c6, sechs Leser + Synthese, 2026-09-11 ~12:10 UTC)

**ECHOEL GENRE ENGINE — DESIGNER'S MAP (synthesized from six reader reports, load-bearing claims re-measured 2026-09-11)**

Measured baseline: `MusicStyle` = 36 cases (`awk 'NR>=263&&NR<=575' … | grep -c '^    case'` → 36), `offered` = 19 (`Sources/Echoelmusic/Sequencer/MusicStyle.swift:134`), 4 `Category` cases (`:193`). The "39 blocking guards" = the 39 files in `Tests/CISmoke` that reference `MusicStyle` (`git grep -l MusicStyle -- 'Tests/CISmoke/*.swift' | wc -l` → 39, of 527 files); 31 of them sweep `allCases`/`offered` automatically. Full list: AFailedSaveLeavesATrace · AutosaveSlot · BassRhythmOverride · CleanIsDry · FilterCutoffClamp · GainLatchRecovery · GenreAnchorFloor · GenreBassGrammar · GenreBatchFourVoicing · GenreBatchThreeVoicing · GenreDarkMinimal · GenreDeepTech · GenreDelaySyncResolvability · GenreFamilyDistinctness · GenrePsyProgHouse · GenreSwingReachesTheClock · GenreTempoFold · LaunchLogsWhatItWokeUpWith · LeadRoleAbsence · LivelinessMovesTheStillnessGate · LivelinessReachesTheDensityDecision · MoodKnobsSayWhatTheyDo · OneDefinitionOfAParameterRange · PadRhythmOverride · PatchVibratoAnchor · RoleTimbreTrim · SoundRowsCanReachTheShippedPatches · SynthPatchValuesResolve · TakeDistance · TheBassRoleHasItsOwnVoice · TheGenerateLineExplainsItsNoteCount · TheGenreVocabularyStaysNeutral · TheLastCrashOutlivesOneLaunch · TheOfferedRosterIsTheRoster · ThePaceIsTiltedInsideTheGenre · TheRawTakeTravelsWithTheTake · TheToneSystemTravelsWithTheTake · UnmeasuredPulseIsNotZero · WebsitePagesAreFindableAndHonest.

---

## 1. Definitive touchpoint checklist — adding ONE genre

**A. Compiler-forced (exhaustive switches, no `default:`) — 14 sites**
`Sources/Echoelmusic/Sequencer/MusicStyle.swift`:
1. `enum MusicStyle` — new `case` in `:263-575` (rawValue = persisted token; never rename later, see §4)
2. `Category.genres` switch `:223` (hand-ordered list per category; picker Section order)
3. `category` `:247`
4. `displayName` `:581`
5. `lineage` `:629`
6. `beatArchetype` `:702` (derives `chordArticulation` `:770` and `isBeatDriven` `:1374` — no edit there)
7. `tempoRange` `:934`
8. `defaultTempo` `:1055` (must lie inside tempoRange — GenreFamilyDistinctnessTests:285)
9. `swing` `:1103` (0…0.5; must not be smaller than minimalTechno's non-zero swing — GenreBatchFourVoicingTests:259)
10. `leadPatchName` switch `:1200` (property `:1161`); one of six warm names `"Soft Keys"/"Warm Strings"/"Hollow Reed"/"Pluck"/"Choir Vox"/"Deep Sub"`; non-sustained genres count toward pigeonhole ceiling `ceil(N/6)` (GenreBatchFourVoicingTests:301-340, MusicStyleLeadTests:15-36)
11. `mixLevels` `:1288`
12. `scale` `:1316`
13. `harmonicProfile` `:1382` (fields `progression/chordTones/padOctave/leadOctave/arpeggiated/leadDensity/sustained`, `:30-61`; `leadDensity` MUST be 0 — LeadRoleAbsenceTests:46/91)
14. `Sources/Echoelmusic/Sequencer/GenrePatches.swift:53` `synthPatch` (unique name + unique 2-hex-digit UUID suffix; values on the Sound-panel grid: SoundRowsCanReachTheShippedPatchesTests; enum strings must be exact EchoelDDSP rawValues: SynthPatchValuesResolveTests)
15. `Sources/Echoelmusic/Sequencer/GenreFX.swift:305` `rawFXPreset` (delaySync must resolve at `tempoRange.upperBound`: GenreDelaySyncResolvabilityTests:105; `filterEnabled` is acid-only: GenreFamilyDistinctnessTests:131-153)

**B. Silent-on-omission (has `default:`) — decide explicitly**
16. `MusicStyle.offered` `:134` — WITHOUT this line the genre is doorless (`:169-174` says so)
17. `sustainedFlächen` `:84-91` — must equal `allCases.filter{sustained}` (GenreFamilyDistinctnessTests:340; MusicStyleTests:82)
18. `defaultMode` `:1700`, default `.studioLocked` at `:1706` — breath-paced/calm genres must be listed for `.flowFree` (the file warns at `:1701-1704`)
19. `beatFlavor` `:888`, default `.neutral` `:928` — inaudible (drum grid muted), optional
20. `GenrePatches.swift:399` `bassPatch` (default nil `:465`) and `BassGrammar.swift:114` `bassGrammar` (default nil `:121`) — BOTH or NEITHER (TheBassRoleHasItsOwnVoiceTests); a new `BassGrammar` case must be owned by an offered genre (GenreBassGrammarTests "owned ∪ authoredAhead == allCases")
21. `BioComposer.swift:877` `switch input.style` (default at `:919`) — only `.dubTechno/.trap` have a special arm; optional

**C. Literal pins that go red when `offered.count` changes**
22. `Sources/Echoelmusic/Studio/EchoelStudioView.swift:6922` caption "(9 of the 19 offered)" + `Tests/CISmoke/MoodKnobsSayWhatTheyDoTests.swift:160` (`offered.count == 19`, no-7th count 9) — same commit
23. `Tests/CISmoke/WebsitePagesAreFindableAndHonestTests.swift:594/616` compares copy counts to `offered.count`/`allCases.count` over `docs/*.html` and every `fastlane/metadata/*/release_notes.txt`: measured copy sites `docs/tools.html:174`, `docs/brainstorming.html:138`, `docs/press.html:101,126`, `fastlane/metadata/en-US/release_notes.txt:6`, `de-DE/release_notes.txt:6` ("Nineteen curated genres"), `docs/architecture.html:235` ("36 genres", "25 of 36 … 11 shared floor" — moves with allCases)
24. Prose counts in `MusicStyle.swift:174-190` Category doc ("36 cases, 19 offered … rock 0 of 5") — TheOfferedRosterIsTheRosterTests only pins the needle "ROSTER is `offered`" and the STRUCK phrase, plus `offered.count < allCases.count`
25. Stale prose already wrong (fix or leave, but do not plan from): `RoleTimbreTrimTests.swift:15,209` "16 offered"; `LivelinessMovesTheStillnessGateTests.swift:7` "sixteen"; `EchoelDDSP.swift:294,1824` (26/16/33)

**D. Hand-written superlatives a new genre can tie/break by construction**
26. `GenreAnchorFloorTests.swift:202-215` — one-section set literal {selfObservation, stillMeditation, psytrance, doom, deepDrone, minimalTechno}; a genre with `progression.count == 1` OR (`sustained && progression.count > 2`) must be added
27. Voicing exclusivity: `[0,3,4]`,`[0,2,6]` (GenreBatchThree:96), `[0,4]`,`[0,2,6,8]` (GenreBatchFour:153/171/116), `[0,4,6]` (GenreDeepTechTests), `[0,4,11]` + "dyads == [.minimalTechno]" (GenreDarkMinimalTests), `([0,6,5],[0,2,4])` pair and sole `.rollingSixteenths` and sole offered fourOnFloor+pingPong (GenrePsyProgHouseTests:56-85)
28. `upliftingTrance` has strictly the most distinct progression roots of any offered genre (GenreBatchThree:119) — a new genre with ≥ its root count reds it
29. `techHouse` sole offered beat-driven mixolydian (GenreBatchThree:141); `detroitTechno` sole electronic comp (GenreBatchFour:188)
30. Pentatonic scales used ONLY by deepDrone/ambientPulse over allCases; deepDrone lowest padOctave of offered (GenreFamilyDistinctnessTests:220-261)
31. Delay-axis ratchet: drum-free offered genres must form ≥5 clusters at 5 % spacing and "THIS SITS EXACTLY ON ITS BOUND" (GenreDelaySyncResolvabilityTests:176,183-212); at most one offered genre clamped at defaultTempo
32. Swing: `offered.filter{swing==0}.count > 5` (GenreSwingReachesTheClockTests)
33. `≥4` offered sustained Flächen, default genre calm and offered (GenreFamilyDistinctnessTests:318)
34. Non-blocking (`Tests/EchoelmusicTests`, cannot fail a merge, #208): `MusicStyleTests:11` category partition (the ONLY taxonomy-completeness guard), `:139` drum-free set literal, `:130` rock power chords, `:283` artist-name ban; GenrePatchesTests:57 `timbreProfile.isEmpty` (no instrument emulation)

**E. Per-batch convention (#983 template)**
35. `Tests/CISmoke/Genre<Name>Tests.swift` — copy `GenreDeepTechTests` shape: door (offered + category + `Category.x.offeredGenres` + displayName) · voicing literals + "no other arm" sweep · rhythm literals · bass pair · brightness/FX orderings vs named neighbours · header `NEEDS-FOUNDER-VERIFY` with the listening instruction ON the marker line
36. `decisions.csv` row; `scratchpads/PLAN_*`; `docs/dev/FEATURE_MATRIX.md:227/232`

---

## 2. Variation surface ("nie gleich klingen")

**Where randomness exists (shipped default path: `suggestJourney`/`voiceLeading`/`humanize` all true, `EchoelStudioView.swift:10176-10186`):**
- Seeds are chosen by the studio, not the composer: `structureSeed = override ?? bioSeed(frame)` (`EchoelStudioView.swift:9959`); `bioSeed` hashes HR×100, HRV/coherence/breathPhase×100 000 (`:9865-9884`) — so with a live frame the STRUCTURE seed differs on virtually every generate (cohesion is nominal, as the composer reader flagged); no frame ⇒ `takeFallbackSeed` rolled once per Start (`:9392`). XOR performer salt `:9981`, weather salt `:10014`.
- Detail seed `evolvingSeed = structureSeed ^ (evolution × golden)` `:10019`; `evolution &+= 1` per real generate `:9952`; evolve loop re-seeds every 25–45 s (`:9810-9821`) and `evolveShouldReseed()` returns true unconditionally (`:9841`). Play regenerates (`generate(reason:"start")`).
- Inside `BioComposer.compose` (`BioComposer.swift:837`): journey pick within the coherence window (`ChordSuggest.journey` `:312`, no style parameter — genre-agnostic; first k roots overwritten by genre progression via `genreAnchorCount` `:411`), inversion via `chordSeed` `:2423`, per-note velocity jitter/`nextUUID` from `rng` (`:425`), `humanizeVelocity` `:621`, `hrvHumanize` `:658`, `padSeed`/`rhythmSeed` only inside `if let padRhythm/bassRhythm` (`:2477`, `:1709`).
- Performer door: `variationsCard` in `tempoToolsPanel` (`EchoelStudioView.swift:3917/3888`) → `BioVariationMaze.explore(count: 6)` (`:10843`) → `applyVariation` `:10854`. Per-lane seed split `LaneComposerInput.swift:10-28`.

**Where it is MISSING:**
- `structureRNG` draws at `:2251/2260` (rotation/splice/turnaround) sit in the `else` branches `:2225-2270`, reached only when `suggestJourney == false` (`chordSuggestControl` guard `:367`); the draw at `:2687` is inside the dormant lead block (leadDensity 0 everywhere). **On a sustained Fläche the per-take variety is journey pick + inversion + velocity jitter — that thinness is the likely felt cause of "gleich".**
- Rhythm cells: hard 4/4×16 (`BioComposer.swift:123`, `PatternEngine.swift:32`, `Transport.swift:63`, `RoleRhythm.swift:534/617/674` `cells/4`, `% 16` at `:1509/1949`). Existing cells: dotted [6,4], tresillo [3,3,2] and [3,3,2,2,3,3] (`heartbeatOnsets`), skank/stab/comp grids, 4 `BassGrammar` figures, 6 `RoleRhythm` characters. `git grep -i 'clave\|6/8\|7/8\|5/4' -- Sources` → nothing beyond tresillo comments. No clave, no 6/8, no odd meter — that is a transport/roll epic, not a genre field.
- Sub-step timing: `PianoRollModel.trigger` fires on `startStep == step` (`PianoRollView.swift:1118`); `pushFraction` honoured on the Field arp only (`RoleRhythm.swift:72`).
- Drum grid: `generate()` loads `BioComposer.silentBeat()` unconditionally (`EchoelStudioView.swift:10444`, founder 2026-07-07) — `beatArchetype`/`beatFlavor`/GenreFlavor compute grids nobody hears. HARNESS_LEDGER records two DEAD cycles (v329/v330) here.
- No plain "new take" button (grep reroll|regenerate|newTake → 0); "Randomize timbre" (`:8112`) randomizes the patch.
- Tuning is user-owned (`@AppStorage("toneSystemID")`, `WorkspaceView.swift:1154`), never genre-selected (0 refs to `TuningSystem/toneSystem/tuningID` in the four genre tables).

**What the convergence history forbids (#77/#79/#81/#125, v327–v336, #327, #418/#419, #983):**
- No lead lines re-added without a founder ask (leadDensity 0 is a blocking guard).
- No differentiation by drums or tempo (both excluded from the fingerprint by design; drums inaudible).
- Bio-modulation must be patch-ANCHORED deviations (v333 `bioBaseFilterCutoff`, v334 `bioBaseBrightness`), never absolute writes — that was the real "erst individuell, dann alles gleich" vector.
- Calm = maximally genre-characteristic (v327/v328 anchor polarity, full anchor by coherence 0.7, `max(1,…)` floor).
- Overrides (pad/bass rhythm, grammar) must be reached for by a player, never a new default (`BioComposer.swift:195-201`; nil paths byte-identical: BassRhythmOverrideTests/PadRhythmOverrideTests). Adding draws earlier in the `rng` stream shifts every later UUID/velocity — a variation engine should be an opt-in `Input` field (repo precedent #253/#983).
- "Verify the layer is AUDIBLE before iterating on it" (HARNESS_LEDGER playbook).

---

## 3. Non-Western material available / missing

**Available**
- `Scale`: 57 cases (`MusicalKey.swift`, `grep -c '^    case'` → 57), families `europeanFolk/middleEast/eastAsia/india` (`:239-247`): middleEast `[doubleHarmonic, phrygianDominant, persian]`, eastAsia `[hirajoshi, iwato, insen, yo, inSakura, kumoi, pelog]`, india `[marwa, purvi, todi, malkauns, charukeshi, hamsadhwani, shanmukhapriya]`, europeanFolk `[hungarianMinor/Major, romanianMinor, neapolitan…]` — ALL 12-TET integer sets; the file itself says "12-TET APPROXIMATIONS … Tone system picks WHICH pitches exist; Scale picks which of them are used" (`:230-238`). Pitch-set uniqueness enforced (IndianScaleTests).
- `TuningSystem.library`: 15 ids (`MicrotonalTuning.swift:132-163`): edo12/24/19/31, just-major/minor, pythagorean, meantone-quarter, **maqam-rast, maqam-bayati, maqam-hijaz, gamelan-slendro, gamelan-pelog, hirajoshi**, bohlen-pierce. Wired to every pitched voice via `applyTuning()` (`EchoelStudioView.swift:4407-4470`), guarded by EveryPitchedVoiceFollowsTheToneSystemTests. Model = 12-slot per-pitch-class nearest-degree retune (`:195`); non-octave periods retune nothing (`:180`).
- Rhythm cells: tresillo half of clave only; dotted; genre swing.

**Missing**
- Genres use 9 Western scales only (minor 8, phrygian 7, major 6, dorian 5, mixolydian 4, lydian 2, harmonicMinor 2, pentatonic 1+1); `oriental` = `.phrygian`, `klezmer` = `.harmonicMinor` (`MusicStyle.swift:1356-1357` region). No genre uses any Family-shelf scale.
- No genre→tuning field; a maqām genre would sound 12-TET unless the player picks a tone system. Ownership collision if added: user picker + `Project.toneSystemID` (TheToneSystemTravelsWithTheTakeTests).
- No degree-walking composer for 5/7-degree tunings (Sléndro collapses pitch classes up to −300 cents).
- No clave, 6/8, 7/8, 12/8, additive meters; no tāla cycle; no drone-plus-melody idiom (leads are banned).
- No percussion at all (muted).

---

## 4. Hard constraints

- **Vocabulary ban** (`Tests/CISmoke/TheGenreVocabularyStaysNeutralTests.swift:58-60`, over `displayName`+`lineage` of allCases, never rawValue): `chakra, solfeggio, healing, "heal ", aura, esoteric, third eye, vibrational force, manifest, cleanse, detox, cure, therapy, therapeutic`. Plus CLAUDE.md BRAND: no BLAB/Vibrational Force/Solfeggio. `lineage` = sound-character fragments only — no artist/label/film/hardware ("303" removed)/city names (`MusicStyle.swift:19-20`); "hypnotic" was removed as altered-state adjacent. Spiritual traditions may be named as MUSICAL traditions only (Deep Ambient precedent for "Esoteric Meditation").
- **English base**: `CFBundleDevelopmentRegion=en` (`Resources/iOS/Info.plist:5-6`); genre strings not in the String Catalog (0 hits); German headers were a bug fixed 2026-07-29 (`MusicStyle.swift:202-217`).
- **Persisted token law**: rawValue lives in `@AppStorage("studio.genre")` (three readers), `Project.styleRaw`/`RawTake.styleRaw` (fallback `.dubTechno`/nil), `TimelineLane.genreOverride` (`try?` → nil), OSC `/echoelmusic/ctrl/genre` (`OSCReceiver.swift:151`, `EchoelmusicApp.swift:1297`, no `offered` clamp). Rename = silent reset. Precedent: `case stillMeditation = "esotericMeditation"` (`:552`, #570). **A two-level taxonomy must be additive metadata over `MusicStyle` (a parent property), not a nested enum.**
- **Modal ceiling**: 14 file-wide presentation modifiers (`doctor --section D`), pinned; two setterless slots `midiImportPresented :793`, `showMeditation :814`. A taxonomy browser goes into `dropdownContent`/a panel (no new `.sheet`); `Picker(.menu)` cannot nest Sections; nested `Menu` precedent at `EchoelFXView.swift:1157-1168`; strip height is pinned; hot reads in a leaf only (10.76.41/50); ≤10 rows per ViewBuilder block; `labeled("Genre")` must remain built (`WorkspaceView.swift:1181`, TheHeaderStripWearsTheOneFormatTests).
- **Founder curation doctrine**: roster is curated by EAR (07-24 delegation, #254 widening allowed, calm centre and calm default protected — GenreFamilyDistinctnessTests:318); 17 un-offered genres are "dark on purpose" (`MusicStyle.swift:142-190`); re-offering is a listening decision. Ship-Gate check 1 (Klang) is FOUNDER-EAR only; every batch ends with `NEEDS-FOUNDER-VERIFY`, store copy states roster COUNT, never quality. Beat stays OFF ("Flächen bleiben, Timbre/Harmonie schärfen").
- **Fingerprint** (`GenreFamilyDistinctnessTests.swift:37-49`, sweep `:69` over `offered` only): `(chordArticulation, scale, progression, chordTones, padOctave, arpeggiated, sustained)` — exact 7-tuple equality is the collision; tempo and drums excluded; purely static, no `compose()` call. Two world genres sharing scale+voicing+register must differ on articulation/progression/padOctave.

---

## 5. Contradictions between readers — resolved by measurement

| Claim | Readers | Measured |
|---|---|---|
| `leadPatchName` switch line | taxonomy 1162 / sound 1161 / guards 1200 | property `:1161`, `switch self` `:1200` (guards correct for the switch; others cited the declaration) |
| Number of exhaustive MusicStyle switches | taxonomy "12 … 11 listed"; guards "12"; ui "12" | 12 `switch self` over MusicStyle in the file (247,581,629,702,888,934,1055,1103,1200,1288,1316,1382,1700 = 13 incl. defaultMode) minus 2 with `default:` (928, 1706) = **11 exhaustive** + `Category` pair (212,223) + BeatArchetype (770); plus `synthPatch:53` and `rawFXPreset:305` ⇒ **13 compiler-forced arms + Category.genres** |
| GenreFX has extra switches | none mentioned | `GenreFX.swift:843/861/880` are `FXCharacter` switches, not MusicStyle — no touchpoint |
| Banned-list line | taxonomy 63-66 / guards 58-61 / sound 39-42 / history 50-60 | `:58-60` |
| BioComposer style switch | ui "drumAccents :875 with default" | `switch input.style` at `:877`, default at `:919`; `:875` is the `drumAccents` declaration |
| `dynamicDepth` line | composer 10047 | `:10053` (same fact: breathDepth passed = `0.3+0.5·coherence`) |
| `padSeed` line | composer 2521 | `:2477` (inside `if let padRhythm`) — fact holds |
| "structureRNG never consumed on shipped path" | composer | confirmed: `:2251/2260` in `else` branches of `if let sc = suggest` (`:2154/2225/2240`); `:2687` inside dormant lead block |
| "tempo windows must be pairwise distinct" | sound (MusicStyleTests:302) | `:302-308` pins ONLY dubTechno 118…128 vs trap 130…150 — not pairwise; and non-blocking |
| "testScalesAreGenreAppropriate accepts world scales?" | sound open question | `:320-324` pins only dubTechno/trap/selfObservation — a new genre's scale is unconstrained there |
| Tests sweeping allCases/offered | taxonomy "39" | 39 over all `Tests/`, 31 in CISmoke; the 39 CISmoke files that reference `MusicStyle` at all are the "39 blocking guards" |
| RegenSchedule | ui | `quietWindow 0.45 :63`, `minAutoSeedGap 6.0 :68`, `minUserGap 2.0 :73` — confirmed |
| Category count guard | taxonomy "MusicStyleTests non-blocking" vs guards | confirmed: 7 CISmoke hits on `MusicStyle.Category`, all per-genre `.electronic` checks; no `Category.allCases` in CISmoke |
| `sustainedFlächen` production reader | taxonomy "test-only" | confirmed list `:84-91`; guarded twice |
| `#125` provenance | history | still inferred (no ledger entry in this shallow clone); code comments cite it |

Single most important design consequence: **variation must be added as opt-in `BioComposer.Input` fields (or a coarsened structure seed) that leave the nil path byte-identical, and world genres must carry their identity on the fingerprint axes plus an optional, nil-defaulting tuning field — never on drums, tempo, or a renamed rawValue.**
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

---

## §1–§5 ENTWURF (Design-Workflow wf_5a01793a-49f, 9 Agenten, 2 Jurys, 2026-09-11 ~16:00 UTC)

Quelle: Workflow `wf_5a01793a-49f` (9/9 Agenten grün, 0 Fehler, ~91 min, 2,43 M Subagent-Token).
Drei Architektur-Entwürfe, ein Weltkatalog, zwei Prüfberichte (Engine/Fingerprint · Vokabular/Marke),
zwei unabhängige Jurys (beide Sieger: `musicologist`), dann diese Synthese. Roh-Ergebnisse je Agent:
`subagents/workflows/wf_5a01793a-49f/journal.jsonl` (Session-Verzeichnis, nicht im Repo).

⚠️ **Das ist ein ENTWURF, kein Gesetz.** Jede Messung darin wird vor ihrer Scheibe neu gegen den Baum
gefahren — der Plan nennt seine Befehle selbst. Founder-Punkte in §5 sind offen und blockieren die
jeweils genannte Scheibe, nicht den Plan.

Synthese aus drei Entwürfen, zwei Jury-Urteilen (beide: Sieger **musicologist**), dem Kulturkatalog und zwei
Prüfberichten. **Jede abgelehnte Zeile ist gestrichen oder mit ANGEWANDTER Korrektur übernommen** (§2b).

**Heute gemessen:** `MusicStyle` = 36 Fälle · `offered` = 19 · `Category` = 4 · lead-tragend (`allCases` ohne
`sustained`) = **27**, Decke `ceil(27/6)` = **5**, Verteilung **Deep Sub 5 · Soft Keys 5 · Pluck 5 · Warm
Strings 4 · Hollow Reed 4 · Choir Vox 4** ⇒ genau DREI freie Plätze. `composeHarmonic`-Aufrufstellen =
**`BioComposer.swift:888` und `:924`** (nicht 877/929 — das sind die `switch input.style`-Arme). `.sustained` →
`chordOnsets(:1934)` → `heartbeatOnsets(:1939)`, EIN genre-blinder Onset-Erzeuger. ⚠️ `MusicStyle.swift:1190-1195`
sagt weiter „At 20 the ceiling is still 4 … ZERO HEADROOM" — veraltet, in G1 durch den Befehl zu ersetzen (#818).

---

## §1 ENTSCHEIDUNG — die Architektur in zehn Zeilen

1. **`MusicStyle` bleibt das flache Enum und der persistierte Token.** Ein `rawValue` wird NIE umbenannt
   (`@AppStorage("studio.genre")`, `Project.styleRaw`, `RawTake.styleRaw`, `TimelineLane.genreOverride`, OSC
   `/echoelmusic/ctrl/genre`); Präzedenz `case stillMeditation = "esotericMeditation"`. Neu BLOCKIEREND gepinnt:
   `TheGenreTokensNeverChangeTests` nagelt `Set(allCases.map(\.rawValue))` gegen ein Literal.
2. **`Category` 4 → 9 Rubriken**, `.meditative` bleibt ERSTER Fall (`MusicStyleTests:29`), `.acoustic` zieht sich
   zurück — gemessen sicher: sein rawValue ist nirgends persistiert, und `Category.acoustic` wird außerhalb von
   `MusicStyle.swift` nirgends genannt (`git grep -n "Category\.\|\.acoustic\b" -- Sources Tests` → nur
   `WorkspaceView:1190`, sieben `.electronic`-Prüfungen in CISmoke, `MusicStyleTests`).
3. **Neu `MusicStyle.Subcategory`** = die 32 Unterrubriken, mit `parent: Category` und kurzem `title`.
   `MusicStyle.subcategory` ist die EINE neue erschöpfende `switch self`; `MusicStyle.category` wird zu
   `subcategory.parent`. **Netto-Compiler-Zwang unverändert:** ein 36-Arm-Switch wird durch einen strikt
   informativeren ERSETZT, keiner entfällt.
4. **Regal-Zugehörigkeit wird ABGELEITET, nie ein zweites handsortiertes Literal:**
   `Subcategory.genres = allCases.filter { $0.subcategory == self }`, `Category.genres = subcategories.flatMap(\.genres)`,
   Reihenfolge = Deklarationsreihenfolge. Damit kann ein Genre nicht regal-los sein — genau der Defekt, den
   `ScaleFamilyTests` bewacht.
5. **Die Tür bleibt EIN `Picker(.menu)` in `labeled("Genre")`** (`WorkspaceView.swift:1181-1200`,
   `TheHeaderStripWearsTheOneFormatTests`): flache `Section`-Liste über `Subcategory.allCases` in
   Eltern-dann-Kind-Ordnung. **Der Eltern-Titel wird NICHT in den Header konkateniert** — `ScaleFamilyTests:108`
   deckelt Header bei 22 Zeichen, weil ein `UIMenu`-Gruppentitel bei `.accessibility1` am ENDE abschneidet —
   „World · Near East & Maqām" verlöre die identifizierende Hälfte. Kein neuer `.sheet` (Modal-Decke 14).
6. **Authentizität trägt in dieser Reihenfolge: Tonsystem → Bordun-Intervall (`chordTones`) → Register
   (`padOctave`) → Pad-Zelle (`PadGrammar`).** Nicht Schlagzeug (stumm), nicht Tempo, nicht Metrum (4/4×16 fest),
   nicht Leads (`leadDensity ≡ 0`, blockierend). **NULL neue `Scale`-Fälle** — 20 Welt-Skalen liegen ungenutzt in
   den vier Family-Regalen, und `MusicalKey.degree` läuft über jede Kardinalität.
7. **`PadGrammar`** (neue Datei, exakt die `BassGrammar`-Form, `default: nil`): eine authored 16-Schritt-
   Akkordzelle, die die vier archetyp-abgeleiteten Raster umgeht, eingesetzt an **ZWEI** Stellen — echte Onsets
   (`:2550`) UND `genreRate`-Schätzung (`:2483`), weil eine Schätzung aus einem ungespielten Pfad „den Pad
   beschreibt, der nicht geschrieben wird" (#419). **Ohne das unterschieden sich elf Welt-Bordune nur in
   Tonvorrat und Register, passierten das statische 7-Tupel und klängen nach demselben Stück — die
   #81/#125-Konvergenz, vorgeladen.**
8. **`GenreIdiom` + `VariationEnvelope`**: Variation zieht aus der EIGENEN legalen Menge der Tradition — ein
   illegaler Zug ist nicht darstellbar. Die Hüllkurve wird PRO GENRE deklariert, mit explizitem `.fixed` für
   „variiert absichtlich nicht" (`deepDrone`), damit „unbewegt gewollt" von „noch nicht authored" trennbar bleibt.
9. **BESITZ-REGEL für genre-vorgeschlagene Tonsysteme: das Genre SCHLÄGT VOR, der Spieler BESITZT, die Aufnahme
   ERINNERT.** `suggestedToneSystemID: String?`, `default: nil`. GENAU EINE Schreibstelle:
   `handleCompositionEdit` Fall `"genre"` (`EchoelStudioView:4603-4607`) — der Arm, der ohnehin `scale` und
   `currentPatch` ganz überschreibt und der laut eigenem Doc (`:4595-4601`) NUR bei Nutzer-Interaktion feuert, nie
   beim programmatischen `open(_:)`. `nil` lässt die Wahl unberührt; `open(_:)` fragt das Feld NIE — die Aufnahme
   sticht das Genre. Kein zweiter Besitzer, kein `onChange`-Wächter (BLE-3-Lehre). **Tabelle landet LEER; der
   erste Nicht-nil-Wert ist eine Founder-Entscheidung (§5-2).**
10. **NIL-PFAD BYTE-IDENTISCH, konstruktiv statt versprochen.** `Input.idiomVariation: Bool = false` (die
    `voiceLeading`/`humanize`-Form, defaultet im memberwise `init :289-312`); `padGrammar`/`genreIdiom` sind nil
    per `default:`; jeder Hook ist ein `if let`. Der Keim kommt aus dem Golden-Ratio-Mix — die
    `chordSeed :2423`-Präzedenz („derived WITHOUT consuming either RNG stream") —, also **kein zusätzlicher Zug
    auf `rng :838` oder `structureRNG :843`**. Zwei Wächter: Note-für-Note-Gleichheit UND UUID-SEQUENZ-Gleichheit
    bei verschiedenem Idiom-Keim — Letztere beweist „kein Stream-Versatz"; eine Gleichheitsprüfung allein nicht.

**Verworfen, damit es niemand neu vorschlägt:** die `GenreSpec`-Zeilenform (eine authored Zeile je Genre) ist die
richtige END-Form und der falsche WEG — ~900 Zeilen Transposition aus 13 erschöpfenden Switches in der
meistbewachten Datei, ohne lokale Toolchain, geprüft gegen eine Tabelle, die dieselbe Hand aus derselben Quelle
einfriert; ein vertauschter Wert KOMPILIERT, und `auto-merge-claude.yml` wartet auf kein Gate. Ebenso verworfen:
`offered`/`sustainedFlächen` per Zeilenfeld abzuleiten — `MusicStyle.swift:190-192` nennt die Kuration eine
Founder-Entscheidung, „never a side effect of somebody reading this comment and tidying it up".

---

## §2 TAXONOMIE-BAUM — 9 Rubriken · 32 Unterrubriken · 36 bestehende + 48 neue

**Zeilenformat je NEUEM Genre (alle 13 compiler-erzwungenen Arme + die stillen Felder):** Zeile 1 =
`caseName` "displayName" — lineage · Zeile 2 = `scale`/toneSystemID | beatArchetype | lo-hi@default/swing |
leadPatchName | progression | chordTones | padOctave | Flags | defaultMode | synthPatch | fxPreset | Bass-Paar | PadGrammar
**A**=arpeggiated · **S**=sustained (⇒ `sustainedFlächen`; bei `progression.count == 1` zusätzlich `GenreAnchorFloor`) ·
**FF**=`.flowFree` (MUSS in `defaultMode :1700` explizit stehen — der Switch endet auf `default: .studioLocked`,
eine Auslassung ist STILL; die Liste wird beim Bauen AUS DEN ZEILEN abgeleitet, nie abgeschrieben) · **SL**=studioLocked ·
Bass-Paar = `bassPatch` UND `bassGrammar` gemeinsam oder gar nicht · **nil** = kein Tonsystem-Vorschlag.
**mixLevels-Skizze je Familie** `(bass, harmony, lead)`, Prüfbereich 0.8…1.3: Flächen/Bordune (0.96, 1.06, 0.85) ·
Chant (0.98, 1.08, 0.85) · beat chord-led (1.06, 1.04, 0.88) · beat bass-led (1.15, 0.92, 0.88) · Folk
(1.02, 1.02, 0.86) · Underground (1.16, 0.90, 0.88).
`timbreProfile` bleibt bei JEDEM Patch leer (`GenrePatchesTests:57`); jeder Patch braucht einen eindeutigen Namen
und ein eindeutiges **zweistelliges** Hex-Suffix (ein- oder dreistellig ⇒ `UUID(uuidString:)` nil ⇒ `?? UUID()`
prägt pro Aufruf neu, #254-Falle).

### 1 · `.meditative` "Contemplative & Ambient" (bleibt ERSTE Rubrik)
**Still Pads** · bestehend `selfObservation` `stillMeditation` `drift` `contemplation` `deepDrone`
`glacialField` "Glacial Field" — Motionless high cluster · wide air
`lydianAugmented`/nil|none|42-60@50/0|WarmStrings|[0,2]|[0,1,4]|5|S|FF|"Glacier Pad" v.slow att|v.long hall, tape damping|—|`pedalDrone`
**Moving Ambient** · bestehend `ambientPulse`
`slowBloom` "Slow Bloom" — Widening five-note stack · slow opening
`prometheus`/nil|none|56-72@62/0|HollowReed|[0,2]|[0,2,4,6,8]|4|—|FF|"Bloom Pad" v.slow att|v.wide hall, slow widener|—|—
**Cinematic Atmospheres** · bestehend `sciFi`

### 2 · `.electronic` "Electronic"
**Techno** · bestehend `dubTechno` `minimalTechno` `detroitTechno` `acidTechno` `deepTech` `darkMinimal`
`industrialTechno` "Industrial Techno" — Metallic semitone cluster
`locrian`/nil|fourOnFloor|132-145@138/0|DeepSub|[0,1]|[0,1,5]|3|—|SL|"Iron Stab" hard att|hard sat, short metal plate|"Iron Sub"+`sparseSub`|—
**House** · bestehend `deepHouse` `techHouse` `psyProgHouse` `disco`
`afroHouse` "Afro House" — Warm dorian vamp · rolling offbeat chord
`dorian`/nil|offbeat|118-124@120/0.10|ChoirVox|[0,3,0,4]|[0,2,4]|4|—|SL|"Warm Skank" fast att|mid room, 1/16 slap, tape sat|"Round Sub"+`offbeatEighths`|—
**Trance** · bestehend `upliftingTrance` `psytrance`
`darkPsyTrance` "Dark Psy" — Flattened second over a raised third
`phrygianDominant`/nil|fourOnFloor|145-155@148/0|DeepSub|[0,1]|[0,2,4]|3|A|SL|"Dark Arp"|short dark room, 1/16, heavy sat|"Dark Sub"+`rollingSixteenths`|—
**Synth & Electro** · bestehend `eighties` `synthwave` `earlySynth` `futuristic`

### 3 · `.rock` "Rock, Punk & Metal"
**Rock** · bestehend `rock` `rocknroll`
**Punk** · bestehend `punk` — **Metal** · bestehend `heavyMetal` `doom`
`blackMetal` "Black Metal" — Tremolo-fast raised-fourth minor
`hungarianMinor`/nil|backbeat|160-200@180/0|DeepSub|[0,1,6]|[0,4,7]|4|—|SL|"Cold Stack" hard att|long thin hall, NO delay|"Cold Sub"+`drivingEighths`|—

### 4 · `.jazz` "Jazz, Blues & Soul"
**Jazz** · bestehend `jazz`
`modalJazz` "Modal Jazz" — Two-chord dorian vamp
`dorian`/nil|backbeat|100-160@120/0.30|SoftKeys|[0,3]|[0,2,4,6]|4|—|SL|"Warm Comp Keys"|mid warm room, no delay|"Walk Sub"+`drivingEighths`|—
**Soul** · neu
`soulBallad` "Soul Ballad" — Warm major sevenths · gospel-leaning cadence
`major`/nil|backbeat|64-86@72/0.18|ChoirVox|[0,3,5]|[0,2,4,6]|4|—|SL|"Warm Keys"|warm plate long tail|"Round Sub"+`offbeatEighths`|—

### 5 · `.popular` "Popular & Contemporary"
**Hip-Hop** · bestehend `trap`
`boomBapHipHop` "Boom Bap" — Dusty minor seventh loop · warm filtered top
`minor`/nil|backbeat|84-96@90/0.16|SoftKeys|[0,5]|[0,2,4,6]|3|—|SL|"Dust Keys"|small dark room, tape wow, LPF|"Dust Sub"+`sparseSub`|—
**R&B & Pop** · neu
`electroFunk` "Electro Funk" — Snapping minor seventh comp
`minor`/nil|backbeat|112-124@118/0.08|SoftKeys|[0,3,4]|[0,2,4,6]|4|—|SL|"Snap Keys" hard att|tight room, 1/16 slap|"Snap Sub"+`drivingEighths`|—
**Caribbean** · bestehend `ska` `rocksteady`
`rootsReggae` "Roots Reggae" — Minor skank on the offbeat
`minor`/nil|offbeat|68-84@76/0.20|DeepSub|[0,3]|[0,2,4]|3|—|SL|"Skank Organ" fast att|long 1/4 tape echo w/ fb|"Roll Sub"+`offbeatEighths`|—

### 6 · `.classical` "Classical & Orchestral"
**Early & Baroque** · neu
`baroqueCounterpoint` "Baroque Counterpoint" — Running figured lines · clear triadic motion
`major`/**meantone-quarter**|none|84-120@100/0|HollowReed|[0,4,5]|[0,2,4]|4|A|SL|"Chamber Pluck" fast att|small bright chamber, no delay|—|—
**Classical & Romantic** · bestehend `classical`
`romanticNocturne` "Romantic Nocturne" — Singing minor colour over rolling figures
`harmonicMinor`/nil|none|52-80@64/0|SoftKeys|[0,3,4]|[0,2,4,6]|4|—|FF|"Nocturne Keys" soft att|long warm hall, no delay|—|—
**Impressionist & Modern** · neu
`impressionistColour` "Impressionist Colour" — Floating whole-tone haze
`wholeTone`/nil|none|56-82@68/0|WarmStrings|[0,2]|[0,2,4]|4|A|FF|"Haze Pad"|long soft hall + heavy pre-delay|—|—
`contemporaryClassical` "Contemporary Classical" — Symmetric mode clusters
`messiaen6`/nil|none|44-76@58/0|HollowReed|[0,3,5]|[0,1,4]|4|—|FF|"Severe Cluster"|big cold hall, no delay|—|`maSpacing`

### 7 · `.chant` "Chant, Choir & Drone"
**Chant & Polyphony** · neu
`plainchant` "Plainchant" — Open-fifth drone in dorian colour
`dorian`/**pythagorean**|none|44-62@52/0|ChoirVox|[0]|[0,4,7]|4|S|FF|"Stone Voice" slow att|v.long stone room, no delay|—|`pedalDrone`
`byzantineChant` "Byzantine Chant" — Held ison under an augmented-second mode
`doubleHarmonic`/**edo24**|none|46-64@54/0|ChoirVox|[0,1]|[0,3,7]|3|S|FF|"Vault Voice"|huge vault hall, no delay|—|`pedalDrone`
`choralPolyphony` "Choral Polyphony" — Pure-thirds cadences in just intonation
`major`/**just-major**|none|50-76@62/0|ChoirVox|[0,3,4]|[0,2,4]|4|—|FF|"Pure Choir" soft att|cathedral hall, v.long tail|—|—
**Devotional Modal** · neu
`sufiDevotional` "Sufi Devotional" — Reed-like modal colour over a low drone
`phrygianDominant`/**maqam-hijaz**|none|60-84@70/0|HollowReed|[0,3]|[0,3,7]|3|S|FF|"Reed Drone"|long warm hall, 1/2 tape low fb|—|`pedalDrone`
`qawwaliModal` "Qawwali Modal" — Modal vamp with offbeat chord placement
`charukeshi`/nil|offbeat|96-132@112/0.14|ChoirVox|[0,4]|[0,2,4]|4|—|**SL**|"Vamp Voice"|mid hall, short slap, warm sat|"Vamp Sub"+`offbeatEighths`|`iqaWahdah`
`malkaunsDrone` "Malkauns Drone" — Slow five-note unfolding over a held tonic
`malkauns`/nil|none|40-60@46/0|ChoirVox|[0]|[0,2,4]|3|S|FF|"Tonic Drone" v.slow att|long warm hall, no delay|—|`pedalDrone`
**Court Ensembles** · neu
`gamelanPelog` "Gamelan Pelog" — Interlocking struck-metal figures
`pelog`/**gamelan-pelog**|none|48-72@58/0|WarmStrings|[0,2]|[0,2,4]|4|A|FF|"Struck Metal"|long bright hall|—|`gongCycle`
`gagakuCourt` "Gagaku Court Music" — Mouth-organ tone clusters · very slow
`yo`/nil|none|40-56@46/0|HollowReed|[0,4]|[0,1,4]|5|S|FF|"Cluster Reed" slow att|big open-air hall, no delay|—|`pedalDrone`
**Gospel & Spiritual** · neu
`gospelChoir` "Gospel Choir" — Full seventh-chord choir stacks
`major`/nil|backbeat|72-100@84/0.20|ChoirVox|[0,3,4]|[0,2,4,6]|4|—|SL|"Church Choir"|warm church plate, light chorus|"Church Sub"+`offbeatEighths`|—
**Drone & Overtone** · neu
`overtoneDrone` "Overtone Drone" — Fixed low fundamental
`egyptian`/**just-major**|none|40-54@44/0|DeepSub|[0]|[0,2,7]|3|S|FF|"Partial Drone"|long dark hall, no delay|—|`pedalDrone`
`lowBreathDrone` "Low Breath Drone" — One continuous low fundamental
`iwato`/**just-major**|none|40-52@44/0|DeepSub|[0]|[0,1,5]|3|S|FF|"Breath Drone"|big dark hall, no delay|—|`pedalDrone`

### 8 · `.folk` "Folk & Regional Traditions"
**European Folk** · bestehend `klezmer`
`celticAir` "Celtic Air" — Unhurried dorian voicings over open fourths
`dorian`/nil|none|60-84@70/0.18|HollowReed|[0,6]|[0,3,7]|4|—|FF|"Air Reed" soft att|mid natural hall, no delay|—|—
`nordicFiddle` "Nordic Fiddle" — Droning double-stop fifths
`minor`/nil|backbeat|108-136@120/0.16|WarmStrings|[0,6,5]|[0,3,7]|3|—|SL|"Sympathetic Bow"|bright wood room, short tail|"Drone Sub"+`pedalDrone`|—
`balkanModal` "Balkan Modal" — Raised-fourth minor runs · brassy reed edge
`hungarianMinor`/nil|backbeat|120-170@140/0|HollowReed|[0,4,3]|[0,2,4]|4|A|SL|"Brass Reed"|bright mid room, short delay|"Brass Sub"+`drivingEighths`|`additive332`
`andalusianCadence` "Andalusian Cadence" — Descending modal cadence
`phrygianDominant`/nil|offbeat|90-130@108/0.10|Pluck|[0,2,1]|[0,2,4]|4|—|SL|"Nylon Pluck" v.fast att|small bright room, no delay|"Cadence Sub"+`drivingEighths`|—
`rebetikoModal` "Rebetiko Modal" — Plucked long-neck figures
`doubleHarmonic`/**maqam-hijaz**|offbeat|96-140@118/0.14|ChoirVox|[0,4]|[0,2,4]|4|A|SL|"Long-Neck Pluck"|small bright room, one slap|"Loping Sub"+`offbeatEighths`|`iqaMaqsum`
**Near East & Central Asia** · bestehend `oriental` → displayName **"Modal Near East"** (rawValue bleibt, §5)
`maqamBayati` "Maqam Bayati" — Modal drone in bayati colour · body-paced
`phrygian`/**maqam-bayati**|none|44-70@56/0|HollowReed|[0]|[0,3,7]|3|S|FF|"Bayati Drone"|mid dry hall, no delay|—|`pedalDrone`
`persianModal` "Persian Modal" — Slow modal unfolding over a held tonic
`persian`/**edo24**|none|46-72@58/0|Pluck|[0,2]|[0,3,7]|3|S|FF|"Quarter Pluck" fast att|mid warm hall, no delay|—|`pedalDrone`
`turkishMakam` "Turkish Makam" — Modal line over a held drone
`doubleHarmonic`/**edo24**|none|50-96@68/0|WarmStrings|[0,3]|[0,2,4,6]|4|S|FF|"Makam Bow"|long warm hall, no delay|—|`pedalDrone`
**South Asia** · neu
`carnaticMela` "Carnatic Mela" — Mela pitch set over a tonic-fifth drone
`shanmukhapriya`/nil|none|56-104@76/0|ChoirVox|[0,4]|[0,2,4]|4|—|FF|"Drone Bed"|small warm room, no delay|—|`pedalDrone`
**East & Southeast Asia** · neu
`zhiMode` "Zhi Mode" — Bright anhemitonic pentatonic · plucked runs
`yo`/nil|none|54-88@68/0|WarmStrings|[0,3]|[0,2,4]|5|A|FF|"Airy Pluck"|bright mid hall, no delay|—|`maSpacing`
`japaneseKoto` "Japanese Koto" — Sparse plucked pentatonic figures
`hirajoshi`/**hirajoshi**|none|50-84@64/0|Pluck|[0,2]|[0,1,4]|4|A|FF|"Koto Pluck" v.fast att|mid bright room|—|`maSpacing`
`koreanModal` "Korean Modal" — Sparse plucked five-note figures
`insen`/nil|backbeat|72-120@92/0.20|DeepSub|[0,4]|[0,2,4]|3|—|SL|"Dry Pluck"|small dry room, no delay|"Dry Sub"+`sparseSub`|—
`slendroModal` "Slendro Modal" — Near-equidistant five-tone cycle
`egyptian`/**gamelan-slendro**|none|52-80@64/0|HollowReed|[0,3]|[0,2,4]|4|A|FF|"Equid Metal" v.fast att|bright open hall, slight detune|—|`gongCycle`
**Africa** · neu
`koraOstinato` "Kora Ostinato" — Interlocking plucked ostinato
`major`/**just-major**|none|84-112@96/0.12|Pluck|[0,4,3]|[0,2,4]|5|A|SL|"Harp Pluck" v.fast att|bright natural room|—|`kotekanInterlock`
`gnawaGuembri` "Gnawa Guembri" — Low three-string lute ostinato
`minor`/nil|offbeat|88-116@98/0.16|DeepSub|[0,6]|[0,3,7]|3|—|SL|"Low Lute"|mid dark room, short slap|"Lute Sub"+`pedalDrone`|`callResponse`
**Latin America** · neu
`andeanHighland` "Andean Highland" — Two-chord minor cycle · thin bright air
`minor`/nil|none|88-120@100/0.10|DeepSub|[0,5,6]|[0,2,4]|4|—|SL|"Thin Air Pad"|big open-air hall, long tail|"Air Sub"+`sparseSub`|—
`cumbia` "Cumbia" — Two-chord minor cycle
`minor`/nil|offbeat|88-104@96/0.12|SoftKeys|[0,4]|[0,2,4]|4|—|SL|"Lilt Keys"|bright mid room, short slap|"Lilt Sub"+`offbeatEighths`|—
`tangoMarcato` "Tango Marcato" — Marcato minor comp · harmonic-minor colour
`harmonicMinor`/nil|backbeat|92-128@112/0.10|HollowReed|[0,3,4]|[0,2,4,6]|3|—|SL|"Marcato Reed"|small warm room, no delay|"Marcato Sub"+`drivingEighths`|—

### 9 · `.underground` "Underground & Fringe"
**Dub & Drone** · neu
`dubEcho` "Dub Echo" — Chord fragments in feedback delay
`minor`/nil|offbeat|66-82@72/0.18|SoftKeys|[0,5]|[0,2,4,6]|3|—|SL|"Echo Stab"|long **1/2** tape delay high fb|"Dub Sub"+`offbeatEighths`|—
`droneMetal` "Drone Metal" — One immense downtuned chord · glacial decay
`locrian`/nil|halfTime|40-60@46/0|DeepSub|[0]|[0,4,7]|3|S|SL|"Immense Stack" slow att|huge hall, extreme sat, no delay|"Immense Sub"+`pedalDrone`|`pedalDrone`
**Lo-Fi & Hazy** · bestehend `vaporwave`
`loFiHipHop` "Lo-Fi Hip-Hop" — Warm detuned seventh loop
`dorian`/nil|backbeat|72-88@80/0.22|SoftKeys|[0,5,3]|[0,2,4,6]|4|—|SL|"Wobble Keys"|small dark room, tape wow|"Wobble Sub"+`sparseSub`|—
**Dark Synth Scenes** · neu
`slowedGothPop` "Slowed Goth Pop" — Dragged half-time pulse
`harmonicMinor`/nil|halfTime|60-76@66/0.16|ChoirVox|[0,1]|[0,2,4]|3|—|SL|"Dragged Choir" slow att|long dark plate, **1/2** high fb|"Drag Sub"+`sparseSub`|—

**Zählprüfung:** bestehend 7+16+5+1+3+1+0+2+1 = **36** · neu 2+3+1+2+3+4+11+18+4 = **48** · 84 Zeilen,
32 Unterrubriken, 9 Rubriken. Keine dieser Zahlen gehört als Literal in den Quelltext (#818).

**ZURÜCKGESTELLT, nicht vergessen — 22 Katalog-Zeilen, die dieser Plan NICHT baut.** Entweder verdoppeln sie
eine schon dichte Unterrubrik (`progressiveHouse` `progressiveTrance` `latinPop` `dancehall` `chillwave`
`hyperpopBright` `brightSynthPop` `tidalAmbient` `postRock` `shapeNoteHarmony` `contemporaryRnB` `afrobeatsPop`
`brazilianBossa` `fadoLament` `dungeonSynth`), oder ihre IDENTITÄT ist genau das, was die Engine strukturell
nicht kann (`progressiveMetal` = ungerades Metrum · `bebopSwing` = die LINIE · `minimalPulse` = Phasing zweier
Stimmen · `breakcoreHarmony` = zerschnittene Breaks · `slowBlues` = gebogene mikrotonale Intonation, die keine
Bibliotheks-Stimmung modelliert · `orchestralScore`/`deepBass` = kein Kulturkreis, nur Register). Jede ist im
Katalog vollständig spezifiziert und kann als eigener Batch nachkommen; gekürzt wurde wegen der drei
Sättigungsgrenzen beider Prüfberichte: Fingerabdruck-Raum, Lead-Taubenschlag, sieben Kopie-Stellen pro Batch.

### §2b KORREKTUREN gegenüber dem Katalog — jede aus einem Prüfbefund, jede oben bereits angewandt
1. `impressionistColour` **`[0,2,4,6]`→`[0,2,4]`**: auf 6-töniger `wholeTone` = Halbtöne [0,4,8,12] — übermäßig +
   Oktavdopplung, OHNE Quinte; `GenreBatchFourVoicingTests:123-136` verlangt von jedem vierstimmigen Genre außer
   `detroitTechno` die **7** im Stack ⇒ BLOCKIEREND ROT.
2. `slowBlues` **`[0,2,4,6]`→`[0,2,4]`**: auf `bluesMinor` = [0,5,7,12], Sus4 mit Oktave, kein Septakkord.
3. `choralPolyphony` **`[0,4,5]`→`[0,3,4]`** und `koraOstinato` **`[0,4]`→`[0,4,3]`**: beide kollidierten auf dem
   SCHWÄCHEREN Schlüssel von `MusicStyleTests.testEveryGenreHasADistinctMusicalIdentity` (ohne `arpeggiated`) mit
   `baroqueCounterpoint` bzw. `minimalPulse` — rot im NICHT-blockierenden Bündel, also STILL.
4. `andalusianCadence` **`[2,1,0]`→`[0,2,1]`**: einzige Progression ohne Tonika-Öffnung, und `composeHarmonic`
   rotiert über `progressionPhase` (`:2213-2215`) — die geordnete Kadenz wird gar nicht gespielt.
5. `koreanModal` **60–140→72–120**: 2,33 wäre das erste Fenster über einer Oktave und schaltete die
   Oktav-Abstandshälfte von `GenreTempoFoldTests` über `isSubOctaveWindow` STILL ab.
6. `qawwaliModal` **= `.studioLocked`**: der Katalog widersprach sich selbst (Zeile SL, Touchpoint-Liste FF).
7. `electroFunk` **→ `.popular`, nicht `.electronic`**: `.backbeat`→`.comp`, und `GenreBatchFourVoicingTests:192`
   pinnt „`detroitTechno` ist das EINZIGE elektronische Genre, das compt". Der Entwurf ist billiger als die
   Wächter-Umschreibung (#364). **Kommentar AN die Claim-Zeile:** zieht eine spätere Umsortierung ein
   `.backbeat`-Genre nach `.electronic`, wird sie auf korrektem Code rot — Reparatur ist dann das Doc.
8. **Marken-/Respekt-Umbenennungen** — der Literal-Wächter ließ ALLE durch, die Regel ist nicht der Wächter:
   `oriental`→„Modal Near East" (rawValue gepinnt, §5-4) · `didgeridooDrone`→`lowBreathDrone` (kulturell besessenes
   Repertoire + japanische Skala; Oceania-Regal entfällt) · `flamencoCante`→`andalusianCadence` („Cante" = der
   GESANG, den `leadDensity ≡ 0` ausschließt — AUv3-Klasse) · `koraGriot`→`koraOstinato` (erbliche soziale Rolle;
   die Notes sagten „No griot is named", der displayName tat es) · `chinesePentatonic`→`zhiMode` ·
   `southeastAsianModal`→`slendroModal` · `balkanDance`→`balkanModal` · `cumbiaGroove`→`cumbia` ·
   `gamelanCeremonial`→`gamelanPelog` · `carnaticKriti`→`carnaticMela` · `dhrupadAlap`→`malkaunsDrone` ·
   `maqamTaqsim`→`maqamBayati` · `persianDastgah`→`persianModal` · `koreanSanjo`→`koreanModal` ·
   `tangoBandoneon`→`tangoMarcato`. **Rubriken:** „Popular & Urban"→„Popular & Contemporary" · „Sacred &
   Devotional Traditions"→„Chant, Choir & Drone" · „Lo-Fi & Hypnagogic"→„Lo-Fi & Hazy" (`deepDrone`s Quelltext
   hält fest, dass „hypnotic" als zustandsnah entfernt wurde) · „Still Flächen"→„Still Pads" (einziger
   Nicht-ASCII-String, dazu CLAUDE.md-Jargon) · „Court & Temple Ensembles"→„Court Ensembles".
9. **`lineage`-Regel, auf 14 überlebende Zeilen angewandt: kein `lineage` darf behaupten, was seine eigenen
   `authenticityNotes` dementieren.** Gestrichene Wortklassen — PERKUSSION (backbeat, handclap, one-drop, hats,
   cross-rhythm: stumm) · STIMME/MELODIE (melody, singing, cante, taqsim, alap, solo: `leadDensity ≡ 0`) ·
   UNMETRIERT/FREI (`flowFree` ist immer noch eine Uhr) · TECHNIK, die es nicht gibt (circular breathing,
   whistling partials, bends, gamaka, gong cycle, overlapping voice lines).
10. **Zwei BESTEHENDE `lineage` tragen Markennamen** und ziehen mit, sobald der Bann geweitet wird, sonst ist der
    Wächter auf korrektem Baum rot: `trap` „Booming **808** sub-bass", `jazz` „Warm **Rhodes** seventh chords".
11. **Delay-Decke, VOR der FX-Zeile zu rechnen:** `maxDelaySeconds = 2.0` ⇒ Halbe braucht hi ≥ 60, Ganze hi ≥ 120
    (`GenreDelaySyncResolvabilityTests:105`, BLOCKIEREND über `allCases`). Deshalb „no delay": `glacialField`(60)
    `overtoneDrone`(54) `lowBreathDrone`(52) `gagakuCourt`(56) `malkaunsDrone`(60) `droneMetal`(60). `dubEcho`(82)
    darf die Halbe (1,46 s), NICHT die punktierte Halbe (2,20 s) oder Ganze (2,93 s).
12. **Register:** `padOctave` 5 nutzen VIER neue Zeilen (`glacialField` `gagakuCourt` `zhiMode` `koraOstinato`)
    und NULL bestehende — der Katalog sagte „drei". Kein Newcomer unter 3, damit `deepDrone`(2) die niedrigste
    angebotene Oktave strikt behält.
13. **Fingerabdruck-Nachbarn, je Batch VOR dem Schreiben zu prüfen:** `droneMetal`↔`doom` (`[0]`/`[0,4,7]`) ·
    `industrialTechno`↔`darkMinimal` · `loFiHipHop`↔`modalJazz`↔`jazz`. Drei Zeilen laufen auf denselben
    Quart-Stack **[0,5,10]** (`malkaunsDrone` `koreanModal` `slendroModal`) — legal, unterschieden, aber verwandt
    klingend. `droneMetal`s `[0,4,7]` auf `locrian` ist [0,6,12] — TRITONUS + Oktave, kein Powerchord; im
    Case-Doc so benennen.

---

## §3 VARIATIONS-ENGINE — „nie gleich klingen", ohne den Nil-Pfad zu bewegen

**Diagnose zuerst.** Zufall FEHLT nicht: `structureSeed = override ?? bioSeed(frame)` (`EchoelStudioView:9959`)
unterscheidet sich mit lebendem Frame bei fast jedem Generate. Dünn ist das AUTHORED-Material: der Studio-Pfad
übergibt `suggestJourney: true`, also nimmt `composeHarmonic` den `if let sc = suggest`-Zweig und die drei
`structureRNG`-Züge (`:2251/2260`) im `else` werden NIE konsumiert; `:2687` liegt im schlafenden Lead-Block. Auf
einer Fläche bleibt: Journey-Pick + Inversion + Velocity-Jitter — **und jedes `sustained`-Genre teilt sich EINEN
Onset-Erzeuger.** Die Engine liefert Breite und legale Bewegung, nicht mehr Entropie.

**Typen** — `Sequencer/PadGrammar.swift` und `Sequencer/GenreIdiom.swift`, reine Foundation-Werttypen, kein Audio,
kein SwiftUI, beide in der `BassGrammar.swift`-Form inkl. `extension MusicStyle { … default: nil }`:
```
enum PadGrammar { pedalDrone, iqaWahdah, iqaMaqsum, gongCycle, kotekanInterlock, maSpacing, additive332 }
  // je eine feste 16-Schritt-Figur aus Hit(phase:length:level:) — aufsteigend, nicht überlappend, length >= 1
enum GenreIdiom { fixed, modalDrift, registerInterlock, ascentDescent, maSpacing, callResponse }
struct VariationEnvelope { rootOffsets: [Int]; registerDrift: ClosedRange<Int>; cellChoices: [Int] } // pro Genre
struct IdiomControl { idiom; envelope; seed: UInt64; amount: Float }   // derive(...) -> .neutral bei amount 0
```
**Bereiche je Familie** (die Hüllkurve IST der Unterschied zwischen „variiert" und „driftet weg"): Bordun/Chant
`rootOffsets [0]`, Drift 0, Zellwahl nur Onset-WEGLASSUNG — **`deepDrone` bekommt `.fixed`, weil Unbewegtheit
seine Qualität IST** · Maqām/Makam `[0,3,4]` (Sayr-Ziel Quarte oder Quinte, nie chromatische Anleihe), Drift 0 ·
Gamelan/Ostinato `[0]`, Drift −1…+1 (Kotekan), 2 Zellen · Rāga/Mela `[0]`, Auf-/Abstiegs-Permutation + optionale
Varjya-Auslassung aus pro-Skala legaler Menge · Call-Response `[0]`, zwei authored Zellen · beat-getrieben
Rotation der EIGENEN Progression, Drift 0. **Drei Felder sind einer Variante VERBOTEN und werden negativ gepinnt:
`arpeggiated`, `sustained`, `leadDensity`** — die ersten zwei machen eine Fläche zur Fläche, das dritte weckte die
fünf schlafenden Lead-Pfade, die `LeadRoleAbsenceTests` schlafend hält.

**Keim:** `seed = (input.structureSeed ?? input.seed) &* 0x9E3779B97F4A7C15 &+ nonce` — der `chordSeed :2423`-Mix
(Kommentar dort: „derived WITHOUT consuming either RNG stream"), **nicht** `rng.next()`.
**Stärke ist kohärenz-gegated, Polarität wie `genreAnchorCount` (`:411-420`, Boden 0.34, voll bei 0.7):**
`amount = max(varyFloor, 1 - coherence)`, `varyFloor = 0.25`; bei `amount == 0` exakt `.neutral`. **Ruhiger Körper
⇒ die kanonische Option, Variation verengt sich** — v327/v328 auf der neuen Achse. `varyFloor` ist der EINE Wert,
den kein Test entscheiden kann: `NEEDS-FOUNDER-VERIFY` AUF seiner Deklarationszeile.

**Vier `if let`-Haken in `compose()`, keiner im heißen Pfad** (`let idiom = Self.idiomControl(for: input)` neben
`voiceLead :865`/`suggest :869`): **(a)** Anker-Rotation `:2213` `rotBase + (idiom?.rootOffset ?? 0)` — die
verankerten Wurzeln kommen weiterhin NUR aus der eigenen Progression (#77/#81/#125 unberührt), die Aufnahme
BETRITT sie an anderer legaler Stelle · **(b)** Sayr-Substitution in der `k > 0`-Schleife `:2213-2216` ·
**(c)** Arp-Figur `:2519-2537` (Index-Permutation / Oktav-Offset statt `voiced[t % count]`) · **(d)** Zellwahl an
`:2550` UND an der Raten-Schätzung `:2483`. **(a) ist der einzige Haken, den ALLE Genres ausführen — härter zu
prüfen als die drei anderen** (der Block trägt selbst den Vermerk, dass eine Inline-`genreAnchorCount`-Fassung
wochenlang still 0 für `n == 1` lieferte).

**Tür ohne neue Fläche:** EIN „Vary"-Knopf in der VORHANDENEN `variationsCard` (`:3917`, gebaut bei `:3896`), der
`variationNonce` erhöht und auf DERSELBEN `structureSeed` neu generiert — „dasselbe Stück, neue Aufnahme".
Gemessen: `grep -i 'reroll|regenerate|newTake'` → 0; es gibt heute keinen Neu-Aufnahme-Knopf, und genau das ist
die gefühlte Antwort auf „es klingt immer gleich".

**Wächter, die den Nil-Pfad beweisen (vier, nicht einer):**
· `TheIdiomVariationLeavesTheNilPathAloneTests` — jedes angebotene Genre × 3 Keime × 3 Körperzustände, Flagge AUS
  gegen AN bei nil-Idiom, note-für-note (id, pitch, startStep, lengthSteps, velocity), `BassRhythmOverrideTests`-Form.
· `TheIdiomVariationDrawsNoRNGTests` — zwei Composes, die sich NUR im Idiom-Keim unterscheiden, müssen dieselbe
  Notenanzahl UND dieselbe **UUID-SEQUENZ** liefern. Das ist die Eigenschaft, die „kein Stream-Versatz" belegt;
  eine Gleichheitsprüfung allein kann sie nicht belegen.
· `ThePadGrammarLeavesTheNilPathAloneTests` — golden auf einer Fläche.
· `TheVariationEnvelopesNeverCollideTests` — die legalen Mengen sind ENDLICH, also volle Hülle jedes angebotenen
  Genres aufzählen und behaupten: **kein realisiertes 7-Tupel gleicht dem BASIS-Tupel eines anderen angebotenen
  Genres, und keine zwei realisierten Tupel verschiedener Genres kollidieren.** `GenreFamilyDistinctnessTests` ist
  rein STATISCH und ruft `compose()` nie — eine Compose-Zeit-Variation ist dort unsichtbar; dieser Sweep ist das
  Einzige, was das Loch schließt.

---

## §4 SCHEIBENPLAN G0…G15 — Ralph-Wiggum-Ordnung, je Scheibe ≤3 Quelldateien

⚠️ **Web-Sitzung: kein `swift`.** Jede Scheibe wird per TRANSKRIPTION benotet (Wächter in Python nachbauen, gegen
`git show <parent>:<path>` UND den Arbeitsbaum fahren) plus CI: `Xcode Compile Check`, CI/CD `Build for Testing` +
`gh-test-verdict.py`. `auto-merge-claude.yml` wartet auf KEIN Gate.

**G0 — DIE KAPTION ZÄHLT SICH SELBST** (2 Dateien, kein Genre, grün per Konstruktion). `EchoelStudioView:6922`:
„(9 of the 19 offered)" wird Interpolation über `offered.count` + die abgeleitete Kein-Septakkord-Zahl;
`MoodKnobsSayWhatTheyDoTests:160`: BEIDE Literale werden zu DENSELBEN Ableitungen — **kein Boden `>= 19`**, ein
Boden erlaubt eine Kaption, die nach unten lügt. CLIFF-Zusicherungen (0.60/0.50) bleiben. **`docs/` und `fastlane`
bleiben LITERAL** — `WebsitePagesAreFindableAndHonest:594/616` macht eine falsche Store-Behauptung zum
Merge-Fehler, eine abgeleitete Store-Zeile hebelte das aus. Entfernt EINEN Touchpoint aus allen elf Batches.

**G1 — TAXONOMIE-SKELETT** (`MusicStyle.swift`, `WorkspaceView.swift`; KEIN Genre, `offered` unverändert ⇒ jeder
Zähl-Pin unberührt). `Category` 4→9 · `Subcategory` (32, in Category-Ordnung) mit `parent`/`title` (≤22 Zeichen) ·
`subcategory`-Switch · `category = subcategory.parent` · abgeleitete `genres`/`offeredGenres` · die sechs
`.acoustic`-Genres umhängen · Picker über `Subcategory.allCases` · Patch-Suffix-Block `40`…`85` reservieren · **den
veralteten Prosa-Block `:1190-1195` durch den Ableitungsbefehl ersetzen** (#818).
NEU `Tests/CISmoke/GenreSubcategoryTests.swift`: Partition total+disjunkt · `sub.genres.allSatisfy { $0.category ==
sub.parent }` · `Set(offered) == Set(Subcategory.allCases.flatMap(\.offeredGenres))` (Türlos-Falle auf der NEUEN
Iterationswurzel) · kein leeres Regal · Titel ASCII, ≤22 Zeichen, bannwortfrei · `allCases.first.parent ==
.meditative` · **Quelltext-Scan: der `subcategory`-Switch hat KEIN `default:` und ist kein Dictionary** — der
Compiler kann seine eigene Anwesenheit nicht pinnen, und ein späteres „Optimieren" zu einem Dictionary brächte die
Türlos-Falle eine Ebene tiefer zurück. NEU `TheGenreTokensNeverChangeTests` (rawValue-Menge gegen Literal).
**AMEND `TheGenreVocabularyStaysNeutralTests`:** dieselbe Bannliste ZUSÄTZLICH über `Category.title` und
`Subcategory.title` (additiv ⇒ kein #364), erweitert um `hypnagog · hypnotic · altered state · astral · shamanic ·
kundalini · mantra · sacred geometry · oriental · urban`; das ⛔ „niemals `rawValue`" bleibt WÖRTLICH stehen, sonst
wird `esotericMeditation` falsch-rot. **Im selben Commit:** `trap`/`jazz`-lineage (808/Rhodes, §2b-10) und der
`oriental`-displayName, sonst ist die geweitete Liste auf korrektem Baum rot.
**Verify:** Picker öffnen — neun Rubriken mit ihren Regalen lesbar und nicht zu lang?

**G2 — PADGRAMMAR** (neu `Sequencer/PadGrammar.swift`; `BioComposer.swift` für die zwei `if let` bei `:2483` und
`:2550`). Alle Genres nil ⇒ byte-identisch. NEU `ThePadGrammarLeavesTheNilPathAloneTests` (golden) +
`GenrePadGrammarTests` (aufsteigend, nicht überlappend, im Takt, `length >= 1` = #205/#176; `owned ∪ authoredAhead
== allCases`, `GenreBassGrammarTests:94-99`-Form). ⚠️ **`authoredAhead` startet VOLL und leert sich über G5…G15** —
in das Doc des Tests schreiben, sonst liest der erste Batch wie ein Wächterbruch statt wie eine eingelöste
Reservierung (`BassGrammar:112-113` dokumentiert dieselbe Form). **Verify:** keiner.

**G3 — GENREIDIOM + VARIATIONS-ENGINE + TÜR** (neu `Sequencer/GenreIdiom.swift`; `BioComposer.swift` für
`Input.idiomVariation`, `idiomControl`, vier Haken; `EchoelStudioView.swift` für `variationNonce`, „Vary" in
`variationsCard`, `idiomVariation: true` bei `:10192`). Idiom nil ⇒ byte-identisch AUCH bei gesetzter Flagge.
NEU: die vier Wächter aus §3. **AMEND:** keiner. **Verify (`NEEDS-FOUNDER-VERIFY` auf der `varyFloor`-Zeile):**
„Zweimal dasselbe Genre bei ruhigem Körper — dasselbe Stück in neuer Aufnahme (richtig) oder ein anderes Stück
(Floor zu hoch)? Und bewegt es sich bei unruhigem Körper hörbar mehr?"

**G4 — TONSYSTEM-VORSCHLAG, TABELLE LEER** (`MusicStyle.swift` nil-Default-Tabelle; `EchoelStudioView.swift` das
EINE `if let` bei `:4604`). Null Verhaltensänderung. NEU `TheGenreSuggestsTheToneSystemTests`: (1) jeder
Nicht-nil-Vorschlag löst in `TuningSystem.library` auf (eine erfundene Id degradiert über `named()` STILL zu
12-TET) · (2) der Genre-Arm enthält das `if let` und KEIN `?? "edo12"` · (3) `open(_:)` nennt
`suggestedToneSystemID` NIRGENDS · (4) der „nur bei Nutzer-Interaktion"-Vertrag steht weiter bei `:4595-4601` (die
Sicherheit der Regel hängt daran) · (5) mindestens ein angebotenes Genre schlägt NICHTS vor. NEU
`TheSuggestedToneSystemsDoNotCollapseTheScaleTests`: umgestimmte Cent-Werte einer Oktave PAARWEISE VERSCHIEDEN
(Sléndros 5-Grad-Raster kollabiert sonst Tonklassen bis −300 Cent). ⚠️ **(5) und der Kollaps-Wächter sind
VAKUUM-grün, solange die Tabelle leer ist** (#806: ein Skip ist kein Pass); tragend ab G7/G9.
**Founder-Gate:** §5-2 VOR dem ersten Nicht-nil-Wert.

### Batch-Vorlage G5…G15 (je 3 Quelldateien: `MusicStyle.swift`, `GenrePatches.swift`, `GenreFX.swift`)
IM SELBEN COMMIT: Enum-Fälle + alle 13 Arme + `offered` + `sustainedFlächen` (aus den Zeilen ABGELEITET, nie
abgeschrieben) + `defaultMode`-`.flowFree`-Arme + das `GenreAnchorFloorTests:202-215`-Literal für jedes Genre mit
`progression.count == 1` (**Literal ERWEITERN, nicht durch das Prädikat ersetzen** — der Dateikopf sagt, das
Literal IST der Zeuge einer Ableitung, die der Test schon rechnet) + die sieben Kopie-Stellen
(`docs/tools.html:174`, `brainstorming.html:138`, `press.html:101,126`, `architecture.html:235`, jede
`fastlane/metadata/*/release_notes.txt:6` — der Wächter liest das VERZEICHNIS, keine Locale kann ausfallen) +
`Tests/CISmoke/Genre<Name>Tests.swift` in der `GenreDeepTechTests`-Form (Tür · Voicing-Literale + „kein anderer
Arm"-Sweep · Zelle + Bass-Paar · FX-Ordnung gegen benannte Nachbarn · `NEEDS-FOUNDER-VERIFY` mit der Hörfrage AUF
der Markerzeile).
**Transkription je Batch:** den neuen Wächter UND `GenreFamilyDistinctness`, `GenreAnchorFloor`,
`GenreDelaySyncResolvability`, `GenreBatchFourVoicing` nachbauen — wer nur den eigenen Wächter transkribiert,
sieht seine eigenen Kollisionen nicht.
**Vor jedem Batch zu RECHNEN, nie abzuschreiben:** (a) Lead-Decke `ceil(leadBearing/6)` über
`allCases.filter { !sustained }` und welcher Name DARUNTER liegt — heute 27/5, Deep Sub/Soft Keys/Pluck VOLL;
`leadPatchName` ist das einzige Feld, das ohne Plan-Änderung wandern darf · (b) voller 7-Tupel-Sweep inkl. der
nicht angebotenen Arme · (c) `delaySync` bei `tempoRange.upperBound` · (d) zwei freie Hex-Suffixe je Genre.
**Nicht antasten (sichere Richtung):** `GenreSwingReachesTheClock` · `GenreFamilyDistinctness:318` ·
`TheOfferedRosterIsTheRoster`. **Design-Zwänge statt Wächter-Edits:** ≤3 Progressionswurzeln · kein Mixolydisch ·
keine Dyade · kein `.signature` · kein `filterEnabled` · jede vierstimmige Stimmführung ist `[0,2,4,6]` UND
enthält die 7 · `swing` 0 oder ≥0.06 · `padOctave` ≥3.

| Scheibe | Unterrubrik(en) | Genres | zusätzlich |
|---|---|---|---|
| G5 | Still Pads · Moving Ambient · Techno · House · Trance | glacialField, slowBloom, industrialTechno, afroHouse, darkPsyTrance | 4 lead-tragend ⇒ 27→31, Decke 5→6, Neuberechnung zwingend |
| G6 | Metal · Jazz · Soul · Hip-Hop · R&B · Caribbean | blackMetal, modalJazz, soulBallad, boomBapHipHop, electroFunk, rootsReggae | Detroit-Kommentar (§2b-7) an `GenreBatchFour:192`; `MusicStyleTests:130` mitlesen |
| G7 | Baroque · Classical & Romantic · Impressionist | baroqueCounterpoint, romanticNocturne, impressionistColour, contemporaryClassical | 3× `.flowFree`; `meantone-quarter` = erster Tonsystem-Vorschlag ⇒ §5-2 muss beantwortet sein |
| G8 | Chant & Polyphony | plainchant, byzantineChant, choralPolyphony | AnchorFloor +plainchant; `pythagorean`/`edo24`/`just-major` |
| G9 | Devotional Modal · Court Ensembles | sufiDevotional, qawwaliModal, malkaunsDrone, gamelanPelog, gagakuCourt | AnchorFloor +malkaunsDrone; Kollaps-Wächter wird TRAGEND (5↔5-Kardinalität) |
| G10 | Gospel · Drone & Overtone | gospelChoir, overtoneDrone, lowBreathDrone | AnchorFloor +beide Bordune |
| G11 | European Folk | celticAir, nordicFiddle, balkanModal, andalusianCadence, rebetikoModal | `GenrePsyProgHouse`-Paar prüfen (`nordicFiddle` nutzt `[0,6,5]`) |
| G12 | Near East & Central Asia · South Asia | maqamBayati, persianModal, turkishMakam, carnaticMela | AnchorFloor +maqamBayati; 3× `S` |
| G13 | East & Southeast Asia | zhiMode, japaneseKoto, koreanModal, slendroModal | Pentatonik-Anspruch (siehe unten) |
| G14 | Africa · Latin America | koraOstinato, gnawaGuembri, andeanHighland, cumbia, tangoMarcato | — |
| G15 | Dub & Drone · Lo-Fi & Hazy · Dark Synth | dubEcho, droneMetal, loFiHipHop, slowedGothPop | AnchorFloor +droneMetal; `dubEcho`-Delay zuerst rechnen |

**Die EINE Wächter-Frage mit Text (G13, `GenreFamilyDistinctnessTests:220-261`):** die zwei Ansprüche
(„Pentatonik nur `deepDrone`/`ambientPulse`", „`deepDrone` hält die niedrigste `padOctave`") bleiben WÖRTLICH wahr
— `yo`/`hirajoshi`/`insen`/`pelog`/`egyptian` sind pentatonisch in der KLASSE, aber eigene `Scale`-Fälle, und kein
Newcomer geht unter `padOctave 3`. **Also NICHT amendieren, sondern als Design-Zwang festschreiben** und in den
Kommentar des Anspruchs schreiben, warum er den Welt-Batch überlebt hat; dazu den Entmischungs-ZEUGEN behalten
(`deepDrone`/`ambientPulse` bleiben das einzige `sustained`-Pentatonik-Paar, jeder Newcomer unterscheidet sich von
beiden auf Artikulation UND Register). Ein Löschen oder eine Allowlist zöge eine echte Anti-Konvergenz-Sperre für
eine Benennungsbequemlichkeit zurück.

---

## §5 OFFEN / FOUNDER — vor dem jeweils genannten Punkt zu beantworten, EINMAL, nicht pro Batch

1. **KURATION — die einzige Frage, die den ganzen Plan blockieren kann. VOR G5.** `offered` ist heute 19 von 36,
   und `MusicStyle.swift:190-192` sagt: „Widening the roster is a founder decision, one array line — never a side
   effect." Dieser Plan legt 48 Genres an (22 weitere sind im Katalog spezifiziert und zurückgestellt, §2).
   **Frage: sollen alle 48 in den Picker (dann 67 Einträge über 32 Regale) — oder landen sie in der Taxonomie und
   du wählst je Batch per Ohr aus?** Die #254-Präzedenz sagt „angeboten von Anfang an, sonst ist es ein türloses
   Genre"; dagegen steht, dass Ship-Gate 1 (Klang) NUR dein Ohr ist und `GenreFamilyDistinctness:318` nur ruhig
   ≥ 4 verlangt, also eine still un-kuratierte Palette NICHT rot werden würde. **Empfehlung: pro Batch anbieten,
   mit deinem Ja nach der Hörprobe** — jede Scheibe bleibt umkehrbar, und der Picker wächst in Portionen, die du
   gehört hast.
2. **TONSYSTEM-BESITZ — VOR G7** (dem ersten Batch mit `meantone-quarter`). Heute überschreibt ein Genrewechsel
   schon `scale` UND `currentPatch`; dieser Plan macht daraus DREI, und `toneSystemID` hat eine eigene Picker-Tür,
   einen `SoundReset`-Eintrag und reist im Projekt mit. **Frage: Genrewechsel stimmt das Instrument um (mein
   Vorschlag, konsistent mit den zwei bestehenden Überschreibungen, `open(_:)` sticht immer) — oder lieber eine
   nicht-destruktive „Vorgeschlagen: Maqām Ḥijāz [Übernehmen]"-Zeile?** Die zweite Form ist sicherer und kostet
   genau das, was die Welt-Genres hörbar macht: ohne Umstimmung klingt ein Maqām-Genre 12-TET.
3. **`varyFloor = 0.25` — mit G3, am Gerät.** Kein Test kann ihn entscheiden. Hörfrage steht auf der
   Deklarationszeile als `NEEDS-FOUNDER-VERIFY`.
4. **`oriental` → displayName „Modal Near East".** Überholter Sammelbegriff ohne musikalischen Referenten, jetzt
   neben drei Genres, die ihre Tradition exakt benennen. rawValue bleibt, Genre ist nicht angeboten, also
   kostenlos. **Nur dein Ja fehlt** + eine Zeile in `decisions.csv`.
5. **Instrumenten- und Traditionsnamen in `displayName`** (`japaneseKoto`, `gnawaGuembri`, `koraOstinato`,
   `tangoMarcato`, `sufiDevotional`): die Datei-eigene Regel bannt Künstler, Label, Film, Hardware und Städte,
   sagt über AKUSTISCHE Instrumente und Traditionsnamen aber nichts, und der Bestand nutzt sie bereits
   („clarinet", „Berlin School", „Goa"). **Einmal entscheiden, vor G9**, nicht pro Batch.
6. **NICHT in diesem Epos, absichtlich:** Metrum (4/4×16 ist fest — 7/8, 9/8, Tāla, Compás, Clave und Gong-Zyklus
   sind damit NICHT darstellbar, weshalb keine nutzersichtbare Zeile eine Rhythmus-Behauptung trägt) ·
   Schlagzeug (stumm seit #166/#167) · Lead-Stimmen (`leadDensity ≡ 0`, blockierend — deshalb wurde „Flamenco
   Cante" zu „Andalusian Cadence") · neue `Scale`-Fälle · neue externe Abhängigkeit · neuer Modal. Jeder Punkt
   ist ein eigenes Epos mit eigener Founder-Frage.
7. **Kein Punkt dieses Plans ist geräteverifiziert.** Alles ist compile- und CI-geprüft; die Hörproben sammelt
   `python3 scripts/founder-verify.py`, erledigt wird mit `VERIFIED-JJJJ-MM-TT` auf DERSELBEN Markerzeile.

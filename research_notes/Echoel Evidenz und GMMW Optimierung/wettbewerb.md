# Wettbewerb und Stand der Technik 2025–2026 für Echoelmusic (GMMW)

Method note: about 12 web searches (WebSearch summaries; no full-page fetches). Most findings come from secondary or aggregator sources, and each is flagged where that matters. Perplexity, Firecrawl and Context7 were unavailable because their connections failed.

## 1. Bio-reactive and biofeedback music apps

### Takeaway
The consumer "body → sound" market is dominated by **passive wellness listening** (Endel, Brain.fm) or **closed hardware-plus-app biofeedback** (HeartMath, PlantWave). None of them is a **performance instrument or production tool** with open outputs (OSC, MIDI, DMX, ADM). Echoel's positioning, "instrument, not wellness", sits in an empty quadrant.

### Cited Findings
- **Endel** builds soundscapes that are generated endlessly on the device from local inputs: weather, time of day, walking cadence, and heart rate when an Apple Watch is worn. It also has a standalone Watch app — [endel.io](https://endel.io/); [iMore](https://www.imore.com/apple-profiles-team-behind-ambient-sound-app-endel)
- Endel's albums on streaming platforms are not adaptive (they are produced by the engine, but not in real time) — [endel.io](https://endel.io/)
- Endel was Apple Watch App of the Year 2020 — [App Store story](https://apps.apple.com/story/id1535416234)
- Endel pricing: free to download, with in-app purchases from about $59.99 to $119.99 (March 2026 snapshot). The US annual price is about $119.99 (aggregator data, updated July 2026). Official pricing was not verifiable — [AppPricingLab](https://apppricinglab.com/iap/apple/1346247457); [OpenTheRank](https://opentherank.com/productivity-pricing/endel/)
- Endel's 2021 focus study was not peer-reviewed (stated by a competitor's blog, so the source is biased) — [brain.fm blog](https://www.brain.fm/blog/best-focus-music-app-brain-fm-vs-endel-vs-noisli)
- **Brain.fm** uses "neural phase locking" (amplitude modulation for neural entrainment). No heart-rate input was found — [brain.fm blog](https://www.brain.fm/blog/best-focus-music-app-brain-fm-vs-endel-vs-noisli)
- **Wavepaths** (Mendel Kaelen with Brian Eno) makes generative music for therapeutic and psychedelic contexts. Coverage dates from 2017, and no heart-rate sensing was found — [Rolling Stone](https://rollingstone.com/culture/culture-news/hot-digital-shaman-new-app-wavepaths-guides-users-through-therapeutic-trips-129396)
- **HeartMath** sells a coherence sensor plus app. The app is free with a 7-day trial and then a subscription. The sensor costs about $159 (undated listing), and buying an Inner Balance Coherence Plus sensor unlocks lifetime app access — [AppFollow HeartMath](https://apps.appfollow.io/ios/heartmath/6446414998?country=us); [AppFollow Inner Balance](https://apps.appfollow.io/ios/inner-balance/569278747?country=us)
- **PlantWave** (the successor to MIDI Sprout, by Data Garden) sonifies plant biodata: $220 on Kickstarter, $299 retail, with an optional pro tier of $99 per year for instrument design — [Synthtopia](https://synthtopia.com/?p=111353); [AudioCipher](https://www.audiocipher.com/post/plantwave)
- There are open and DIY MidiSprout clones (Spad Electronics "Symbiotic") — [Tindie](https://www.tindie.com/products/spadelectronics/diy-synth-biodata-sonification-midisprout/)

### Inferences
- The market sells **outcomes** (focus, sleep, calm), and its science claims are often weakly backed. Echoel's "science-first, self-observation, not diagnosis" stance is both a differentiator and an App Store risk guard (Guideline 1.4.1 and 2.3).
- PlantWave's model (hardware plus a pro subscription for instrument design) is the closest "biodata as instrument" analogue, but it uses plant data and has no light or spatial output.
- HeartMath's coherence metric is the public reference point for "coherence". Echoel's HRV-coherence wording should stay distinguishable from it and avoid implying HeartMath equivalence.

### Gaps
- Muse, Myndlift, Moodbeam and Biosync: not researched, because the search budget ran out.
- No current 2026 feature changes found for Brain.fm or Wavepaths.
- No other App Store app found that combines camera-rPPG with generative music.

## 2. Mobile DAWs and audio-editing UX standards

### Takeaway
Logic Pro for iPad sets the bar: AI-assisted parts, stem splitting, retroactive capture and MIDI Learn, on a subscription. Cubasis sets the desktop-like editing bar (glue, undo history during playback, time-stretch, AUv3 hosting). Echoel's audio editing (slip, fades, split/join, normalize, scrub) covers those basics. It lacks hosting and comping, and it does not need to compete there.

### Cited Findings
- **Logic Pro for iPad 2.2** (2025) added: a better Stem Splitter (now also separating guitar and piano), Flashback Capture, Learn MIDI for hardware controllers, and new sound packs. It costs $4.99 per month or $49 per year and requires iPadOS 18.4 — [AppleWorld.Today](https://appleworld.today/2025/05/apple-has-introduced-new-logic-pro-updates-for-mac-and-ipad/)
- Logic launched on iPad in May 2023 with Apple Pencil automation drawing and Sample Alchemy — [TechCrunch](https://techcrunch.com/?p=2539915); [Mixdown](https://mixdownmag.com.au/news/apple-introduces-logic-pro-for-ipad-a-mobile-and-multi-touch-version-of-the-daw/)
- Reported but unverified: an "Apple Creator Studio" with a Synth Player that generates synth parts for both Logic on Mac and Logic on iPad — [GarageBand Guide](https://thegaragebandguide.com/logic-pro-for-mac-update-explained-new-features-and-compatibility-changes-coming)
- **Cubasis 3**: Audio Glue, mono conversion, undo history usable during playback, 32-bit float engine, 24-bit/96 kHz I/O, élastique 3 time-stretch and pitch-shift, 8 insert plus 8 send effects, and AUv3, IAA and Audiobus hosting — [Steinberg What's New](https://download.steinberg.net/downloads_software/Cubasis/Cubasis_3_Web_Help/QU_Whatsnew.html); [mwm.ai listing](https://mwm.ai/apps/cubasis-3-daw-music-studio/1207839273); [Music Symposium review](https://symposium.music.org/index.php/62-2/item/11573-cubasis-3-a-mobile-digital-audio-workstation)
- **Koala Sampler** runs as an AUv3 with Ableton Link and Ableton Live Set export. Users have reported AUv3 bugs inside Cubasis — [Loopy Pro forum](https://forum.loopypro.com/discussion/53725/problem-using-koala-sampler-auv3-plugin-with-cubasis-3-5)
- **Ableton Move/Note 2.0** shipped with Live 12.4 (headline only; details not retrieved) — [Audiofanzine](https://fr.audiofanzine.com/workstation-daw-sequenceur-iphone-ipod-touch-ipad/news/)

### Inferences
- Common expectations are Ableton Link, Live Set export and MIDI Learn, and MIDI Learn now exists even in Logic for iPad. Ableton Link would need to go through Council approval, since CLAUDE.md allows LinkKit.
- Flashback Capture parallels Echoel's RetroCapture, so Echoel could market the equivalent if it is exposed.
- Stem splitting is now table stakes in Apple's own app. Echoel should **integrate** rather than build, in line with its product law.

### Gaps
- BandLab, GarageBand 2025–26 and Logic 2.3+ details were not found. No authoritative comping UX comparison was found for mobile.

## 3. Generative engines and on-device AI

### Takeaway
Apple's Foundation Models framework (iOS 26) gives free, offline, private LLM access from Swift. It suits typed command proposals and patch or arrangement suggestions, not audio generation. App Intents in iOS 26 add interactive snippets, which match Echoel's "Siri proposes typed commands, one executor runs them" design.

### Cited Findings
- **Foundation Models**: shipped with iOS, iPadOS and macOS 26. It runs on device, works offline and has no inference cost. It supports structured output via `@Generable`/`@Guide`, plus tool calling — [9to5Mac](https://9to5mac.com/2025/09/29/apple-intelligence-ios-26-models-developers/); [ADTmag](https://adtmag.com/articles/2025/06/10/apple-launches-ondevice-ai-framework-and-tools.aspx); [Atelier Socle guide](https://www.atelier-socle.com/en/articles/foundation-models-api-guide)
- It requires Apple Intelligence hardware (iPhone 15 Pro, iPhone 16 and later). This comes from a secondary source, so Apple's documentation should be checked — [Atelier Socle](https://www.atelier-socle.com/en/articles/foundation-models-api-guide)
- **App Intents (iOS 26)**: `SnippetIntent` interactive snippets (SwiftUI) in Siri, Spotlight and Visual Intelligence; `IntentValueQuery`; `@DeferredProperty` (secondary sources) — [Superwall](https://superwall.com/blog/app-intents-interactive-snippets-in-ios-26); [Blake Crosley](https://blakecrosley.com/blog/app-intents-2-ios-26-additions)
- **Bronze**: the original 2012 iPhone format used probabilistic Markov models (Goldsmiths). The later London AI startup raised a $1.3M pre-seed and sells a B2B engine for games and VR — [The Quietus](https://thequietus.com/?p=6339); [pkmital](https://pkmital.com/home/works/bronze-format/); [MBW](https://www.musicbusinessworldwide.com/ai-music-tech/)

### Inferences
- Echoel's in-house rule-based music theory plus an LLM-as-planner setup (Foundation Models proposing typed commands) is the privacy-preserving, App Store-safe route, and it avoids neural audio-generation licensing risk.

### Gaps
- No 2026 source found for on-device neural audio generation on iPhone (for example, Stable Audio running on device).

## 4. Immersive and installation tools, and how mobile sources plug in

### Takeaway
ADM-OSC v1.0 (AES, 2024) is the interoperability layer, and Spat Revolution complies fully. The typical professional chain is sensor → TouchDesigner (mapping) → OSC to Notch and Art-Net or sACN to fixtures. Current iPhone bio→OSC bridges (TDInput, PulseOSC) only **forward** Watch or strap heart rate. Echoel sends processed bio **plus** music state **plus** ADM objects **plus** DMX from one phone.

### Cited Findings
- ADM-OSC was originated by FLUX::, L-Acoustics and Radio France. The v1.0 specification was published as an AES Convention 157 paper (September 2024) and is a basic interoperability layer between object editors and renderers — [Spat docs](https://doc.flux.audio/spat-revolution/Ecosystem_&_integration_ADM_OSC.html); [AES e-Library](https://aes2.org/publications/elibrary-page/?id=22722)
- Spat Revolution 25.01 is fully ADM-OSC v1.0 compliant, adds relative OSC messages and MiRA support, and handles ADM-OSC on input and output — [FLUX::](https://www.flux.audio/?p=25453)
- L-ISA Controller is listed as supporting ADM-OSC, and d&b is a contributor (En-Bridge). Soundscape's support is unconfirmed — [PyPI adm-osc](https://pypi.org/project/adm-osc/); [GitHub ADM-OSC](https://redirect.github.com/eviau-sat/ADM-OSC)
- TouchDesigner controls DMX, Art-Net and sACN fixtures natively — [Derivative](https://derivative.ca/feature/lighting-and-live-shows)
- Notch records and plays back Art-Net, which allows rehearsal without performers. A TouchDesigner app was used as the OSC translator to Notch on the Bad Bunny tour — [Notch manual](https://manual.notch.one/0.9.23/en/docs/nodes/interactive/artnet-recording-playback/); [Notch](https://notch.one/?p=64651)
- **TDInput** (iOS) sends Watch and iPhone sensors to TouchDesigner over OSC. Heart rate comes from a Watch workout session (`/watch/heart/bpm`) — [App Store TDInput](https://apps.apple.com/us/app/tdinput/id6760799367)
- **PulseOSC** sends heart rate from a Watch, AirPods or BLE strap over OSC and is aimed at VRChat — [App Store PulseOSC](https://apps.apple.com/app/id6757429299)
- ZIG SIM and ZIG SIM PRO offer no heart rate, only motion, GPS and ARKit over OSC — [ZIG SIM](https://apps.apple.com/jo/app/zig-sim/id1112909974)
- Research precedent: the "Heart Fire" study turned smartwatch heart rate into TouchDesigner visuals (n=10) — [Frontiers 2023](https://frontiersin.org/articles/10.3389/fcomp.2023.1150348/full)
- Art-Net carries RDM and sACN does not — [UWM](https://sites.uwm.edu/swhite/2018/08/20/art-net-and-theatre)

### Inferences
- Integrators already build heart-rate shows by hand with a Watch, a bridge and TouchDesigner. Echoel can sell itself as **"the bio-reactive object source"** that drops into that chain. It needs a stable, documented OSC namespace (it already has `/echoelmusic/*`) and provenance flags, which are already partly present.
- Concrete wins:
  - publish a TouchDesigner/Notch template (.tox) and an ADM-OSC test with Spat Revolution;
  - support ADM-OSC relative messages;
  - add an "Art-Net record" equivalent so a bio session can be replayed for rehearsal.

### Gaps
- L-ISA and d&b Soundscape v1.0 conformance were not confirmed.

## 5. Opportunities, gaps and risks for Echoel

### Takeaway
Echoel can own the space as an **open-standards, iPhone-native, bio-reactive performance source and generative workstation**. It should not compete with Logic or Cubasis on editing depth, or with Endel on wellness.

### Cited Findings
(Derived from the sources above; see the sections they come from.)
- No surveyed competitor combines bio input with OSC, ADM-OSC and DMX output on iPhone: TDInput and PulseOSC are raw forwarders, and Endel and HeartMath are closed ([TDInput](https://apps.apple.com/us/app/tdinput/id6760799367), [endel.io](https://endel.io/))
- Platform AI (Foundation Models, App Intents snippets) is free and on-device ([9to5Mac](https://9to5mac.com/2025/09/29/apple-intelligence-ios-26-models-developers/))

### Inferences
- **Opportunities:**
  1. Camera-rPPG with no extra hardware, against HeartMath's $159 sensor and Endel's need for a Watch.
  2. Open namespace documentation and templates for TouchDesigner, Notch and Spat users.
  3. An App Intents "performance commands" snippet.
  4. Ableton Link and Live Set export, which the mobile ecosystem expects.
  5. Pricing anchored between PlantWave's pro tier ($99/yr) and Endel (about $120/yr) for an annual "Live" tier.
- **Risks:**
  - App Store 1.4.1 and 2.3 over health or coherence claims.
  - Apple bundling AI parts and stem splitting into Logic, which commoditizes generative "parts".
  - Foundation Models hardware limits, which exclude older iPhones.
  - rPPG reliability compared with chest straps, given that integrators expect stable heart rate.
  - Spreading too thin against mature desktop tools (TouchDesigner, Notch).

### Gaps
- No market-size data or download numbers for the niche, and no user research.

# What "fully AUv3-capable" means for a pro iPad/iPhone workstation (plugin + host), Apple platforms, as of 2026-10

Method note: Apple API facts were read from the developer.apple.com documentation JSON (the same data behind each linked page), so availability strings below are Apple's own. Pages I could not fetch (swift.org forums, wiki.loopypro.com, kymatica.com and audiokitpro.com were unreachable from this session) are cited from search-result summaries only and are marked "(snippet only)". Sources from before 2024 are marked "(pre-2024, possibly outdated)". Tags used in the checklists: **[REQ]** = required for the plugin or host to work at all, **[PRO]** = expected by pros and the hosts they use, **[OPT]** = optional. The tags are my classification, not Apple's. Echoel's deployment floor is iOS 18, so every API below except `AVMIDIEventListBlock` (iOS 27) is available to it.

## 1. Component types (aumu / aufx / aumf / aumi / augn), several components in one extension, and when to offer which

### Takeaway
There are five AUv3 component types: instrument `aumu`, effect `aufx`, music effect `aumf` (an effect that takes MIDI), MIDI processor `aumi` and generator `augn`. Hosts put each type in a different slot, so the type decides where a user can insert the unit. An `aumu` that also sends MIDI shows up in AUM's MIDI slots but not in Logic Pro for iPad's MIDI FX slot (2023 report). The Info.plist `AudioComponents` key is an array, and `AudioUnitExtensionSetComponentList` (iOS 11) changes that list at runtime. Apple's archived guide still says "exactly one audio unit" per extension, which conflicts with this.

### Cited Findings
- Four variants in the archived guide: Generator `kAudioUnitType_Generator` (creates audio from DSP), Instrument `kAudioUnitType_MusicDevice` (responds to MIDI), Effect `kAudioUnitType_Effect`, Music Effect `kAudioUnitType_MusicEffect` (DSP that responds to MIDI events). The guide's codes are "Effect (aufx), Generator (augn), Instrument (aumu), and Music Effect (aufm)". **"aufm" is a typo**: the type is `aumf` (see the AudioKit tutorial below). — [Apple App Extension Programming Guide: Audio Unit (archived, pre-2024)](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/AudioUnit.html)
- Same guide: "Each Audio Unit app extension contains exactly one audio unit"; "Audio Unit app extensions cannot perform recording"; supported "in iOS 9.0 and later, and in macOS v10.11 and later". — [Apple archived guide (pre-2024)](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/AudioUnit.html)
- Info.plist keys under `NSExtension > NSExtensionAttributes > AudioComponents` (an **array** of dicts): `description`, `manufacturer` (exactly 4 alphanumeric characters), `name`, `sandboxSafe` (**macOS only**), `subtype` (exactly 4 characters), `tags`, `type`, `version`. The extension point ID is `com.apple.AudioUnit-UI` with a UI and `com.apple.AudioUnit` without one. Predefined localized tags include Bass, Delay, Distortion, Drums, Dynamics, Effects, Equalizer, Filter, Guitar, Imaging, MIDI, Mixer, Panner, Pitch, Reverb, Sampler, Synthesizer, Time Effect and Vocal. — [Apple archived guide (pre-2024)](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/AudioUnit.html)
- `AudioUnitExtensionSetComponentList(_:_:)` (iOS 11.0, macOS 10.13, visionOS 1.0) "allows the implementor of an audio unit extension to dynamically modify the list of component registrations for the extension". The calling process's bundle ID must prefix or match the extension identifier. — [Apple docs](https://developer.apple.com/documentation/audiotoolbox/audiounitextensionsetcomponentlist(_:_:))
- `kAudioUnitType_MusicDevice`: "can be used as a software musical instrument, such as a sampler or synthesizer. It responds to MIDI ... and can create notes." `kAudioUnitType_MusicEffect`: "An effect unit that can respond to MIDI control messages, typically through a mapping of MIDI messages to parameters." `kAudioUnitType_MIDIProcessor` exists on iOS, macOS and visionOS, but its page has no abstract. — [MusicDevice](https://developer.apple.com/documentation/audiotoolbox/kaudiounittype_musicdevice), [MusicEffect](https://developer.apple.com/documentation/audiotoolbox/kaudiounittype_musiceffect), [MIDIProcessor](https://developer.apple.com/documentation/audiotoolbox/kaudiounittype_midiprocessor)
- The Xcode template offers Music Effect (`aumf`) but no MIDI Processor (`aumi`) option, so `aumi` has to be set by hand later. — [AudioKit Pro AUv3 MIDI tutorial (snippet only, pre-2024)](https://audiokitpro.com/auv3-midi-tutorial-part1)
- The current Xcode "Audio Unit Extension App" template (multiplatform) generates a host app and an extension. It "uses Swift and SwiftUI for the business logic and user interface, C++ for real-time processing, and Objective-C for interacting between Swift and C++". — [Apple: Creating an Audio Unit extension](https://developer.apple.com/documentation/avfaudio/creating-an-audio-unit-extension)
- Logic Pro for iPad placement rules: audio effects go on every channel strip type except the master; "MIDI effects can be inserted on instrument channel strips only. Software instruments can be inserted on instrument channel strips only." Installed AU extensions appear "in the Audio Units section of the Audio FX and Instrument menus". — [Logic Pro User Guide for iPad](https://support.apple.com/guide/logicpro-ipad/lpip9b35f249/ipados) (the page also exists in the 3.0 / iPadOS 26 edition: [link](https://support.apple.com/en-sa/guide/logicpro-ipad/lpip9b35f249/3.0/ipados/26))
- Host quirk: an `aumu` that outputs both audio and MIDI is offered as an audio generator AND as a MIDI sender in AUM and apeMatrix, but Logic Pro for iPad does not list it under MIDI FX. The thread has no answer (June 2023). — [Apple Developer Forums 730956 (pre-2024)](https://developer.apple.com/forums/thread/730956)
- Hosts adopted MIDI-only AUs: AUM added a "MIDI strip" channel type for MIDI-only plugins in v1.3 (snippet only), and Audiobus 3.1 added AUv3 MIDI out and MIDI effects in its MIDI Input and Effect positions (snippet only). — [AUM App Store listing](https://apps.apple.com/py/app/id1055636344), [Audiobus forum: AUM 1.3](https://forum.audiob.us/discussion/32487/massive-aum-update-1-3-0-dropped)

### Inferences
- The conflict between "exactly one audio unit per extension" (archived guide) and the `AudioComponents` array plus `AudioUnitExtensionSetComponentList` is unresolved in the sources. My inference is that the archived sentence describes the 2015 template and that one extension can register several components. **Verify on device** before relying on it.
- For Echoel: the shipped `aumu` covers the instrument slot only. A "pro citizen" offering would add (a) an `aumi` MIDI processor, which is the only way to land in Logic iPad's MIDI FX slot and the natural home for a body-driven MIDI generator, and (b) an `aumf` or `aufx` if body-driven processing of the host's audio is wanted.
- Checklist:
  - `aumu` instrument (iOS 9+) **[REQ]** for an instrument; already shipped.
  - Correct 4-character subtype and manufacturer, and a fixed `version` that increments with each release **[REQ]**.
  - `tags` (Synthesizer, MIDI, …) **[PRO]**, because hosts group by tag.
  - `aumi` MIDI-processor component (iOS 11+ era) **[PRO]** for a MIDI-generating instrument.
  - `aumf` music effect **[OPT]**.
  - Several components in one extension **[OPT]**, UNVERIFIED.

### Gaps
- I found no Apple doc giving the introduction OS for `aumi`. The `kAudioUnitType_MIDIProcessor` page shows no version string.
- I could not confirm whether current Logic Pro for iPad (3.x) lists `aumi` units under MIDI FX. The 2023 thread only implies it.

## 2. Parameters, automation, state and presets

### Takeaway
Pro-grade means: a stable `AUParameterTree` (KVO on rearrangement), ramp-capable parameters driven by `scheduleParameterBlock` and `AURenderEventType.parameterRamp`, touch/release gesture events for host automation recording, `fullState` plus `fullStateForDocument`, factory presets (number ≥ 0) and user presets (`supportsUserPresets`, number < 0, iOS 13+). Hosts are inconsistent in how they display and restore preset and state; for example, Logic shows "Untitled" for an AUv3 `currentPreset` (June 2026 report).

### Cited Findings
- `AUParameterTree`: "The parameter tree is KVO-compliant. An audio unit may choose to dynamically rearrange the tree; when doing so, it must issue a KVO notification on the audio unit's parameterTree property." — [Apple AUParameterTree](https://developer.apple.com/documentation/audiotoolbox/auparametertree)
- `scheduleParameterBlock` (iOS 9): a host should fetch it before rendering. It "is safe to call from any thread context, including realtime audio render threads. Subclasses should not override this; it is implemented in the base class and will schedule the events to be provided to the internalRenderBlock". — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/scheduleparameterblock)
- `AURenderEventType` cases: `.parameter`, `.parameterRamp`, `.MIDI`, `.midiSysEx`, `.midiEventList`. — [Apple AURenderEventType](https://developer.apple.com/documentation/audiotoolbox/aurendereventtype)
- `AUParameter.setValue(_:originator:atHostTime:eventType:)` (iOS 10) takes `AUParameterAutomationEventType` `.value` / `.touch` / `.release`. — [setValue…eventType](https://developer.apple.com/documentation/audiotoolbox/auparameter/setvalue(_:originator:athosttime:eventtype:)), [AUParameterAutomationEventType](https://developer.apple.com/documentation/audiotoolbox/auparameterautomationeventtype)
- `AudioUnitParameterOptions` flags include `flag_CanRamp`, `flag_IsHighResolution`, `flag_NonRealTime`, `flag_OmitFromPresets`, `flag_ValuesHaveStrings`, `flag_ExpertMode`, `flag_MeterReadOnly` and `flag_DisplayLogarithmic`. The page itself states "These constants are relevant only in macOS, and not in iOS" (probably AUv2-era wording; treat it as possibly outdated). — [Apple AudioUnitParameterOptions](https://developer.apple.com/documentation/audiotoolbox/audiounitparameteroptions)
- `parametersForOverview(withCount:)` returns the AU's "most important parameters … to be displayed in a compact generic view". — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/parametersforoverview(withcount:))
- `allParameterValues`: KVO fires "in response to certain events where potentially all parameter values are invalidated—for example, the selection of a preset." — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/allparametervalues)
- `fullState` (iOS 9): "The audio unit should not persist transitory properties such as stream formats, but should save and restore all other properties. The base class implementation … saves the values of all parameters currently in the parameter tree … depth-first preorder traversal." It is bridged to `kAudioUnitProperty_ClassInfo`. — [Apple fullState](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/fullstate)
- `fullStateForDocument` (iOS 9): it separates user-preset state from global state "such as a synthesizer's primary tuning setting … suitable for saving in a user document". "Subclasses that do not implement this property interface with the fullState property instead." — [Apple fullStateForDocument](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/fullstatefordocument)
- User preset API (iOS 13): `supportsUserPresets`, `userPresets`, `saveUserPreset(_:)`, `deleteUserPreset(_:)` and `presetState(for:)`. Opting in "automatically enables your Audio Unit to load, save, and delete user presets. The default implementation … reads from and writes to an internal store", and the developer can override it (for example to use iCloud). Factory presets use `number >= 0` and user presets `number < 0`. To restore a user preset, call `presetState(for:)` and set the result as `fullStateForDocument`. — [Apple sample: Creating custom audio effects (iOS 17 sample)](https://developer.apple.com/documentation/avfaudio/creating-custom-audio-effects)
- Hosts KVO-observe `userPresets` to learn about added or deleted presets. A user preset needs a negative `number`. — [Apple: Incorporating Audio Effects and Instruments](https://developer.apple.com/documentation/audiotoolbox/incorporating-audio-effects-and-instruments)
- WWDC19: "with iOS 13, you can store user presets for your extensions that are accessible across applications" (snippet only, pre-2024). — [WWDC19 session 509](https://developer.apple.com/videos/play/wwdc2019/509/)
- `currentPreset`: "When getting this property, the preset does not reflect whether parameters may have been modified since it was selected." — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/currentpreset)
- Host quirks reported on the forums (listing titles and summaries, as of 2026-10-19): "Logic Pro is not displaying AUv3 currentPreset" (Logic shows "Untitled" while AUv2 plugins show their names, June 2026); "How to mark Audio Unit as dirty (needing to be saved)" (an AUv2 plugin cannot tell Logic its state changed, January 2026). — [Apple Developer Forums, AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)
- Community reports of AUv3 state-saving failures in Loopy Pro ("several challenges") and "some oddities in AUM though not as bad". A plugin restored its state in AUM and Loopy Pro "except for the name" (snippet only, anecdotal). The Loopy Pro wiki says each AUv3 plugin's state is saved automatically with the project (snippet only). — [Loopy Pro forum](https://forum.loopypro.com/discussion/comment/1072887/), [Loopy Pro wiki](https://wiki.loopypro.com/Setting_Up_and_Using_AUv3_Plugins)

### Inferences
- Pitfall: if the state lives outside the parameter tree (for Echoel: genre, key/scale, bio-mapping, the body-voice arm), the base `fullState` silently drops it. Override `fullState` and `fullStateForDocument`, version the dictionary, and tolerate unknown or missing keys on restore. This is the AU equivalent of Echoel's own decode-loss problem (the #527 class).
- Checklist:
  - `AUParameterTree` with stable addresses and identifiers that never get renumbered between releases (iOS 9) **[REQ]**.
  - Ramp-capable parameters plus handling of `.parameterRamp` in render **[PRO]**.
  - Touch/release events from the plugin's own UI gestures (iOS 10) **[PRO]**, because hosts need them to record automation.
  - `implementorStringFromValueCallback` / value strings **[PRO]**.
  - `parametersForOverview` **[OPT]**.
  - `fullState` override covering non-parameter state **[REQ]**.
  - `fullStateForDocument` **[PRO]**.
  - Factory presets **[PRO]**.
  - `supportsUserPresets = true` (iOS 13) **[PRO]**.
  - Correct `currentPreset` getter and setter, plus `allParameterValues` KVO on preset load **[PRO]**.

### Gaps
- I found no authoritative per-host list of exactly which state hooks AUM, Loopy Pro, Cubasis, Drambo and NanoStudio call (`fullState` vs `fullStateForDocument`) or in what order. The community threads are anecdotal.

## 3. MIDI: MIDI 2.0 / UMP, MPE, MIDI output from an AU

### Takeaway
UMP for AUs exists since iOS 15: the host sets `hostMIDIProtocol`, the AU declares `audioUnitMIDIProtocol`, MIDI comes in through `scheduleMIDIEventListBlock` and render events of type `.midiEventList`, and goes out through `midiOutputEventListBlock`. Legacy MIDI 1.0 byte output (`midiOutputEventBlock` plus `midiOutputNames`) dates from iOS 11. Hosts can convert protocols on their own: one report has a tap block receiving MIDI 2.0 even though 1.0 was requested. iOS 27 / WWDC26 added a new AVFAudio typealias, `AVMIDIEventListBlock`.

### Cited Findings
- `scheduleMIDIEventListBlock: AUMIDIEventListBlock?` — iOS 15.0, macOS 12.0, visionOS 1.0. — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/schedulemidieventlistblock)
- `midiOutputEventListBlock: AUMIDIEventListBlock?` (get/set) — iOS 15.0, macOS 12.0, visionOS 1.0. — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/midioutputeventlistblock)
- `hostMIDIProtocol: MIDIProtocolID` (get/set) and `audioUnitMIDIProtocol: MIDIProtocolID` (get) — both iOS 15.0, macOS 12.0. — [hostMIDIProtocol](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/hostmidiprotocol), [audioUnitMIDIProtocol](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/audiounitmidiprotocol)
- `AVMIDIEventListBlock = (Int64, UInt8, UnsafePointer<MIDIEventList>) -> OSStatus`, "A block used by an audio unit to send or receive MIDIEventList data". Availability: **iOS 27.0, iPadOS 27.0, macOS 27.0, visionOS 27.0** (new with the 2026 OS releases). — [Apple AVMIDIEventListBlock](https://developer.apple.com/documentation/avfaudio/avmidieventlistblock)
- `midiOutputNames` (iOS 11), `midiOutputBufferSizeHint` (iOS 11), and `midiOutputEventBlock` / `AUMIDIOutputEventBlock` listed under "Managing MIDI Events". — [midiOutputNames](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/midioutputnames), [midiOutputBufferSizeHint](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/midioutputbuffersizehint), [AUAudioUnit](https://developer.apple.com/documentation/audiotoolbox/auaudiounit)
- `virtualMIDICableCount`: "A music device or effect can support up to 256 virtual MIDI cables of input." — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/virtualmidicablecount)
- `supportsMPE` (iOS 10): "indicates whether the audio unit supports multi-dimensional polyphonic expression." — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/supportsmpe)
- MIDI-CI profiles on AUs: `profileState(forCable:channel:)`, `enable(_:cable:onChannel:)`, `disableProfile(_:cable:onChannel:)`, `profileChangedBlock` — iOS 12.0, macOS 10.14. — [Apple profileState](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/profilestate(forcable:channel:))
- Legacy `AUScheduleMIDIEventBlock`: MIDI 1.0 bytes only, "sysex … must be the only event", "running status is not allowed". The UMP route is the event-list block plus the MIDI 2.0 protocol (snippet-level summary of the doc and forum). — [AUScheduleMIDIEventBlock](https://developer.apple.com/documentation/audiotoolbox/auschedulemidieventblock), [Forums 688123](https://developer.apple.com/forums/thread/688123)
- Protocol caveat: with the host MIDI protocol set to 1.0 on both AUs, a tap block "still received voice channel events automatically converted to UMP MIDI 2.0 format" (snippet only). — [Forums 751579](https://developer.apple.com/forums/thread/751579)
- Forum (2026-10): "How is AUv3 MIDI plug-in supposed to figure out the sample rate of the host?" MIDI FX processors have no audio I/O, so they cannot read the sample rate from a bus format, and Logic does not update it when it changes. — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)
- Forum (2026-10): "Does Logic Pro expose completion of an Audio Unit MIDI output route?" asks whether any API or ordering guarantee confirms that an AU's MIDI output events have been delivered (0 replies). — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)
- WWDC17 introduced AUv3 MIDI output, and the AudioUnitV3Example sample was updated to pass MIDI through (pre-2024). — [Forums 79284](https://developer.apple.com/forums/thread/79284)

### Inferences
- An AU that emits MIDI should read the host's `musicalContextBlock` and `AudioTimeStamp.mSampleTime` for timing, and should cache `midiOutputEventBlock` / `midiOutputEventListBlock` in `allocateRenderResources`. Apple's guidance to cache the context blocks before rendering suggests the same for the output blocks (inference).
- For Echoel: the app's own MPE IN has no zones (CLAUDE.md), so `supportsMPE = true` on the plugin would be an over-claim until the plugin renders per-note expression polyphonically.
- Checklist:
  - Handle MIDI 1.0 `.MIDI` render events (iOS 9) **[REQ]** for `aumu`.
  - Declare `audioUnitMIDIProtocol` and handle `.midiEventList` (iOS 15) **[PRO]** for MIDI 2.0 hosts.
  - `midiOutputNames` plus the output block (iOS 11 / iOS 15 for UMP) **[PRO]** if the instrument emits notes.
  - `supportsMPE` **[OPT]**, and only if true.
  - MIDI-CI profiles **[OPT]**.
  - `AVMIDIEventListBlock` (iOS 27) **[OPT]**, above Echoel's floor.

### Gaps
- No WWDC26 session or release note describing `AVMIDIEventListBlock` was found. Only the typealias page was confirmed.
- I found no host matrix showing which iOS hosts send UMP to AUs. Logic Pro iPad and Cubasis MIDI 2.0 support for AUs is UNVERIFIED.

## 4. Host sync: musical context, transport, latency, tail, render quantum, sample-rate changes, offline bounce

### Takeaway
The host provides tempo, beat position and transport state through blocks that the AU must cache in realtime-safe storage before rendering. Latency must be fixed. Tail time drives how long hosts keep rendering after the input stops. `maximumFramesToRender` is fixed while resources are allocated, and the AU must accept any frame count up to it. `isRenderingOffline` signals a bounce, during which the AU may block or use costlier algorithms.

### Cited Findings
- `musicalContextBlock` and `transportStateBlock` (iOS 9): "An audio unit accessing this property should cache it in realtime-safe storage before beginning to render." They bridge to AUv2 `HostCallback_GetBeatAndTempo` / `GetMusicalTimeLocation` / `GetTransportState(2)`. — [musicalContextBlock](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/musicalcontextblock), [transportStateBlock](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/transportstateblock)
- `AUHostTransportStateFlags`: `changed` (start, stop, seek), `moving`, `recording`, `cycling` (looping). — [Apple](https://developer.apple.com/documentation/audiotoolbox/auhosttransportstateflags)
- `latency`: "should reflect the delay due to signal processing (e.g. FFTs), not as an effect". "A latency that varies with parameter settings, including bypass, is generally not useful to hosts … If an algorithm has a variable latency, it should be adjusted upwards to some fixed latency." — [Apple latency](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/latency)
- `tailTime`: "the time interval between when the input stream ends … and when the output stream becomes silent … should also reflect the duration of an effect (e.g. reverberation)." — [Apple tailTime](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/tailtime)
- `maximumFramesToRender`: "must be set by the host before render resources are allocated. It cannot be changed while render resources are allocated." — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/maximumframestorender)
- `isRenderingOffline`: "An audio unit may respond by using a more expensive signal processing algorithm, or allowing itself to block at render time if data being generated on secondary work threads is not ready in time." — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/isrenderingoffline)
- `renderQuality` takes values 0–127; `shouldBypassEffect` and `canProcessInPlace` also exist. — [renderQuality](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/renderquality), [shouldBypassEffect](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/shouldbypasseffect)
- `channelCapabilities` encodes valid input/output channel pairs (e.g. `(-1,-1)` = any equal count). `AUAudioUnitBus.supportedChannelLayoutTags` lists layouts. — [channelCapabilities](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/channelcapabilities), [supportedChannelLayoutTags](https://developer.apple.com/documentation/audiotoolbox/auaudiounitbus/supportedchannellayouttags)
- `contextName` lets the host name the context (e.g. "track 3") for display in the AU's view. — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/contextname)
- Render-quantum pitfall (November 2025 forum): an FFT AUv3 that returns fewer samples than requested "fails auval and gets ignored by Logic". — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)
- Offline host pitfall (August 2025): offline rendering in an AVAudioEngine-based host produced silence. — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)
- Load-time pitfall (June 2026): "Logic Pro 12 crashes when AudioUnit takes too long to load" (20–30 s initialization). — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)

### Inferences
- Sample-rate changes arrive as a new bus format, followed by a fresh `allocateRenderResources`. All per-rate state (filters, envelopes, the bio-clock to sample mapping) must be rebuilt there, never in render (inference from the `maximumFramesToRender` and allocation rules).
- For Echoel: the instrument's body-driven tempo should NOT fight the host. Under a host transport, the plugin should follow `musicalContextBlock` tempo and treat the body as a modulation source. This is the AU-side mirror of the T1/T2 tempo invariant (my inference; a founder decision).
- Checklist:
  - Render any `frameCount ≤ maximumFramesToRender` and always fill the full buffer **[REQ]**.
  - Rebuild per-rate state in `allocateRenderResources` **[REQ]**.
  - Cache the `musicalContextBlock` / `transportStateBlock` in allocate **[PRO]**.
  - Fixed `latency` **[PRO]**, if there is any look-ahead.
  - `tailTime` for reverb and release tails **[PRO]**.
  - `isRenderingOffline` handling (no realtime-only shortcuts, deterministic bio playback or a frozen bio value during a bounce) **[PRO]**.
  - Fast `init` / `allocateRenderResources`; no multi-second loads **[REQ]**, given the 2026 Logic crash.
  - `contextName` display **[OPT]**.

### Gaps
- I found no Apple statement on the typical render quantum per iOS host (AUM user-selectable, Logic iPad fixed, …). UNVERIFIED.

## 5. UI: AUViewController / SwiftUI, view configurations, host sizes, keyboard and accessibility

### Takeaway
The principal class subclasses `AUViewController` (or `NSObject` when there is no UI) and conforms to `AUAudioUnitFactory`. The host sizes the remote view. `supportedViewConfigurations(_:)` / `select(_:)` (iOS 11) let the plugin accept host-proposed sizes, but host support is uneven: GarageBand iOS calls it, Logic Pro iPad did not (2023), Logic on the Mac offered only oversized sizes, and Apple DTS said plugins cannot suggest sizes.

### Cited Findings
- `AUViewController` (iOS 9) "conform[s] to the NSExtensionRequestHandling protocol". When a custom UI exists, the extension "must implement a subclass of AUViewController and implement the AUAudioUnitFactory protocol inside the subclass". — [Apple AUViewController](https://developer.apple.com/documentation/coreaudiokit/auviewcontroller)
- `AUAudioUnitFactory`: if the unit has no custom UI, subclass `NSObject` "In this case, the hosting app must create a generic user interface". — [Apple AUAudioUnitFactory](https://developer.apple.com/documentation/audiotoolbox/auaudiounitfactory)
- `requestViewController(completionHandler:)`: "The completion handler is called on a thread or dispatch queue internal to the audio unit's implementation". The view controller "must be a subclass of AUViewController". There is an async variant. — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/requestviewcontroller(completionhandler:))
- `providesUserInterface` (iOS 11); `supportedViewConfigurations(_ available: [AUAudioUnitViewConfiguration]) -> IndexSet` and `select(_:)` (iOS 11); `AUAudioUnitViewConfiguration` (iOS 11, CoreAudioKit). — [supportedViewConfigurations](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/supportedviewconfigurations(_:)), [select](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/select(_:)), [AUAudioUnitViewConfiguration](https://developer.apple.com/documentation/coreaudiokit/auaudiounitviewconfiguration), [providesUserInterface](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/providesuserinterface)
- Apple's host sample defines compact (400×100) and expanded (800×500) configurations. `hostHasController` "indicates whether the host app should show its control surface for the view configuration. The host app should respect this setting." — [Apple: Incorporating Audio Effects and Instruments](https://developer.apple.com/documentation/audiotoolbox/incorporating-audio-effects-and-instruments)
- Archived guide: "In iOS, a host app defines the size and position of a container view that embeds the remote view controller". — [Apple archived guide (pre-2024)](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/AudioUnit.html)
- Host behaviour (May–June 2023, pre-2024): GarageBand's letterbox layout is about 1024×335. Logic Pro iPad "does not call" `supportedViewConfigurations`. GarageBand iOS does call it. Logic Pro (Mac, Catalyst AU) calls it "but only provides oversized screen sizes". Apple Code Level Support said: "The host determines the possible window dimensions, and plugins have no influence over these, nor can they suggest suitable dimensions to the host." One reply reports a blank Logic iPad "tile" view. — [Forums 730609 (pre-2024)](https://developer.apple.com/forums/thread/730609)
- Debugging guidance (Apple silicon, out-of-process): "don't assume callbacks happen on the main thread … dispatch to the main queue"; "use event deltas" for mouse movement; add free-floating dialogs and tooltips "as a subwindow to the main window"; "you can't create custom properties that share pointers to objects." — [Apple: Debugging Out-of-Process Audio Units on Apple Silicon](https://developer.apple.com/documentation/audiotoolbox/debugging-out-of-process-audio-units-on-apple-silicon)
- Forum (June 2026): "AUv3 extension icon cannot be resolved on one iPad across all host applications". — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)

### Inferences
- A SwiftUI UI is hosted inside the `AUViewController` (for example through a `UIHostingController` child, which Apple's current template does). The plugin view must reflow from GarageBand's ~1024×335 strip to full screen. That is the same adaptivity debt Echoel already tracks (#292). A fixed-size SwiftUI layout fails there.
- Checklist:
  - Fully resizable view, no fixed frames **[REQ]**.
  - UI work dispatched to main from KVO and parameter observers **[REQ]**.
  - `supportedViewConfigurations` accepting at least a compact and an expanded size (iOS 11) **[PRO]**, despite uneven host support.
  - Respect `hostHasController` **[PRO]**.
  - Dynamic Type and VoiceOver labels on controls **[PRO]**, UNVERIFIED against host behaviour.
  - Hardware keyboard focus **[OPT]**.

### Gaps
- I found no current (2025–2026) source on Logic Pro iPad 3.x or AUM view-size behaviour. The 2023 findings may be outdated.
- I found no Apple guidance specific to accessibility or keyboard focus inside a remote AU view. UNVERIFIED.

## 6. Process model: out-of-process vs in-process, Mac / Catalyst / "Designed for iPad", visionOS, WWDC25/26 changes

### Takeaway
On iOS and iPadOS, AUv3 always runs out-of-process; DTS says this is "strictly enforced on iOS". In-process loading (`loadInProcess`, `isLoadedInProcess`) is macOS-only and requires packaging the AU code in a framework. Since macOS 11, AUs run in `AUHostingServiceXPC` (or `_arrow` under Rosetta). Most AUAudioUnit APIs are marked visionOS 1.0, and third-party AUv3 plugins ship for visionOS. I found no AUv3-specific WWDC25 or WWDC26 session. The only new symbols I found are `intendedSpatialExperience` (visionOS 26, output units only) and `AVMIDIEventListBlock` (OS 27).

### Cited Findings
- "Like all App Extensions in iOS, AUv3 plug-ins run out-of-process … communication … over interprocess communication (IPC)." "In macOS only, you can load an appropriately packaged plug-in in-process". iOS supports AUv2 only for those "provided by the operating system". — [Apple: Incorporating Audio Effects and Instruments](https://developer.apple.com/documentation/audiotoolbox/incorporating-audio-effects-and-instruments)
- `AudioComponentInstantiationOptions.loadInProcess` is available on **macOS 10.11 only**. `.loadOutOfProcess` is iOS 9 / macOS 10.11 / visionOS 1.0. `isLoadedInProcess` is **macOS 10.15 only**. — [loadInProcess](https://developer.apple.com/documentation/audiotoolbox/audiocomponentinstantiationoptions/loadinprocess), [loadOutOfProcess](https://developer.apple.com/documentation/audiotoolbox/audiocomponentinstantiationoptions/loadoutofprocess), [isLoadedInProcess](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/isloadedinprocess)
- In-process packaging (macOS): all executable code goes into a framework, the extension keeps a placeholder source file, the framework is named in the `AudioComponentBundle` attribute, and the principal class lives in the framework. — [Apple: Creating custom audio effects](https://developer.apple.com/documentation/avfaudio/creating-custom-audio-effects)
- DTS (Quinn, March 2026): "To meet platform security goals plug-ins must run in a separate process. This is strictly enforced on iOS and it's generally a good idea on macOS." — [Forums 818192](https://developer.apple.com/forums/thread/818192)
- macOS 11+: "the system loads audio units into a separate process … `AUHostingServiceXPC_arrow` for Rosetta and `AUHostingServiceXPC` for native". Debugging requires disabling SIP. — [Apple: Debugging Out-of-Process AUs](https://developer.apple.com/documentation/audiotoolbox/debugging-out-of-process-audio-units-on-apple-silicon)
- Catalyst regression (November 2025): "Mac Catalyst: AUv3 Extension no longer works on MacOS, still works on iOS" after Xcode 26.1. — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)
- `intendedSpatialExperience` (**visionOS 26.0**): "Only useful for output AUAudioUnits - setting on a non-output AU is a no-op." — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/intendedspatialexperience-7uqrm)
- Vendor claim: the JAX AudioVisualizer AUv3 is available for "MacOS (Apple Silicon) - iOS (iPhone) - iPadOS (iPad) - visionOS (Apple Vision Pro)" and "require[s] a supporting host application". — [App Store: JAX AudioVisualizer](https://apps.apple.com/sg/app/jax-audiovisualizer/id6479594041)
- WWDC25 audio sessions found: 251 (input picker on iOS/iPadOS 26, AirPods high-quality recording, spatial audio capture) and 297 (Apple Positional Audio Codec). No AUv3 session was found. — [WWDC25 251](https://developer.apple.com/videos/play/wwdc2025/251/), [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- Audio workgroups (iOS 14 / macOS 11): the audio frameworks automatically join realtime render threads, including the IPC calls to out-of-process AUs, to the device workgroup. AUs that create their own realtime threads must join them. `renderContextObserver` (iOS 14): "Implement this property if your Audio Unit creates auxilliary realtime rendering threads." `osWorkgroup` (iOS 14) exposes the device's workgroup. — [WWDC20 10224](https://developer.apple.com/videos/play/wwdc2020/10224/), [renderContextObserver](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/rendercontextobserver), [osWorkgroup](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/osworkgroup)

### Inferences
- For a Swift-only AU on iOS, the in-process framework split is irrelevant. It matters only if Echoel's AU should load in-process in Logic for Mac (which would need a macOS / Catalyst build). Out-of-process IPC overhead per render cycle is the iOS baseline every host lives with.
- Checklist:
  - Out-of-process-safe design: no shared pointers, all host callbacks may be off-main (iOS 9) **[REQ]**.
  - Workgroup join for any helper realtime threads (iOS 14) **[REQ if such threads exist]**.
  - macOS in-process packaging **[OPT]**, macOS only.
  - visionOS build **[OPT]**.

### Gaps
- UNVERIFIED: whether an iPhone/iPad AUv3 ("Designed for iPad" on an Apple silicon Mac) appears in Logic Pro for Mac or other Mac hosts in 2026. Sources show such listings exist but no host confirmation.
- UNVERIFIED: which first-party or third-party visionOS hosts load AUv3.
- I found no WWDC26 session on Audio Units. Release notes were not checked.

## 7. App Group / shared container between app and extension

### Takeaway
The App Group (`com.apple.security.application-groups`, ID `group.…`, registered in the developer account for iOS) is the supported channel between the containing app and the AU extension. It gives a shared `UserDefaults(suiteName:)`, a shared container URL, keychain access-group use, and IPC primitives. Apple DTS names it the way to pass purchase state, because StoreKit is not supported inside app extensions.

### Cited Findings
- App groups let apps "access one or more shared containers" and enable IPC through "Mach IPC, POSIX semaphores and shared memory". "You can also use an app group to share data between an app extension … and its host app." Container IDs "must begin with `group.`". "You need to register app groups for iOS, iPadOS, tvOS, visionOS, and watchOS apps." The limit is "a maximum of 1,000 app groups" per account. The APIs are `UserDefaults(suiteName:)`, `containerURL(forSecurityApplicationGroupIdentifier:)`, and a background `URLSession` `sharedContainerIdentifier`. An app group can also serve as a Keychain Access Group. — [Apple: Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- Entitlement `com.apple.security.application-groups` (iOS 3.0+). The `<team id>.<group>` format is macOS-only and needs no registration. — [Apple: App Groups Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups)
- DTS (March 2026): the app checks the purchase with StoreKit, "stores the state in an app group or keychain access group, and the extension checks that state". The keychain route needs the data protection keychain. On iOS, "XPC is not an option because third-party apps can't publish named XPC endpoints," and a Unix socket "falls over as soon as the listener process moves to the background and gets suspended." — [Forums 818192](https://developer.apple.com/forums/thread/818192)
- Default user-preset storage is an "internal store" that the developer may override (for example iCloud). — [Apple: Creating custom audio effects](https://developer.apple.com/documentation/avfaudio/creating-custom-audio-effects)

### Inferences
- Uses for Echoel: (1) licence and entitlement state, (2) shared user presets and patches so that the app's `PatchStore` and the plugin agree, and (3) shared sample or impulse data (read-only from the extension). Provisioning steps: register `group.com.echoelmusic` (CLAUDE.md says it already exists for the app), add the entitlement to BOTH the app and the AUv3 target, and regenerate profiles. The AUv3 target currently has no App Group (task context). Under the repo's rules that is a `project.yml` change and therefore founder-gated.
- Checklist:
  - App Group on the extension (iOS 3+ entitlement) **[PRO]** (required as soon as presets, licence or content are shared).
  - Shared-defaults reads only off the render thread **[REQ]**.

### Gaps
- I found no Apple doc on file-coordination or locking practice for the app and extension writing the same preset file concurrently.

## 8. Distribution: App Review rules, IAP unlock inside an extension, demo-mode conventions

### Takeaway
App Review guideline 4.4 (updated 2026-10-16) says extensions "may not include marketing, advertising, or in-app purchases". DTS confirmed in March 2026 that "we don't support StoreKit in app extensions". So the unlock must be bought in the containing app, written to the App Group or keychain, and read by the extension. I found no sourced description of plugin-maker "demo mode" conventions.

### Cited Findings
- Guideline 4.4: "Apps hosting or containing extensions must comply with the App Extension Programming Guide … and should include some functionality, such as help screens and settings interfaces where possible. You should clearly and accurately disclose what extensions are made available in the app's marketing text, and the extensions may not include marketing, advertising, or in-app purchases." The page was last updated October 16, 2026. — [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- DTS: "I've confirmed that we don't support StoreKit in app extensions" (exception: iMessage extensions). A signed token was rejected because other code in the host process could steal it. Launching the app headlessly from the extension is "uncertain and likely fragile". — [Forums 818192](https://developer.apple.com/forums/thread/818192)
- Conflicting community reports: one developer saw "Invalid container for application" on a StoreKit receipt refresh from an AUv3; another claimed IAP worked from a framework inside the extension and that the guideline had been removed (snippet only). **The 2026 guideline text and DTS contradict the "removed" claim.** — [Forums 693297](https://developer.apple.com/forums/thread/693297), [JUCE forum (host-behaviour context only)](https://forum.juce.com/t/inapppurchases-from-auv3-plugin/55109)
- macOS host entitlement pitfall (September 2025): Transporter rejected a build using `temporary-exception.audio-unit-host`. — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)
- Logic Pro iPad guidance to users: AU extensions "need to first be installed on your iPad"; one installs "as an app on the Home Screen"; search "AUv3" in the App Store. — [Logic Pro User Guide for iPad](https://support.apple.com/guide/logicpro-ipad/lpip9b35f249/ipados)

### Inferences
- For Echoel's stated pricing ("App free, plugins bought once, never a subscription", per CLAUDE.md / `decisions.csv`): a non-consumable is bought in the app, the app writes a verified flag (`Transaction.currentEntitlements` checked app-side) into the App Group or a shared keychain item, and the extension only reads it. The extension must show no purchase UI. A "locked" plugin may at most point the user to the app, and even that wording risks 4.4's "marketing" clause (UNVERIFIED how review treats it).
- Checklist:
  - No StoreKit and no purchase or ad UI in the extension **[REQ]**.
  - App-side entitlement written to the App Group / keychain **[REQ if paid]**.
  - Marketing text discloses the extension **[REQ]** (4.4).
  - Help and settings screens in the container app **[PRO]**.

### Gaps
- UNVERIFIED: demo-mode conventions of known iOS plugin makers (noise bursts, time limits, preset-save lock). I found no primary source in this session.
- UNVERIFIED: whether App Review accepts an "unlock in the app" notice inside the extension UI.

## 9. Validation and testing: auval, hosts, the de-facto compatibility bar

### Takeaway
`auval` is the macOS validation tool, and Logic on the Mac ignores AUs that fail it. For iOS the practical bar is a host matrix. Vendors publicly list AUM, Cubasis, GarageBand, Logic Pro for iPad, BeatMaker 3, NanoStudio, Loopy Pro and Drambo. I found no sourced, authoritative way to run auval against an iOS-only AUv3.

### Cited Findings
- An FFT-based AUv3 returning partial buffers "fails auval and gets ignored by Logic" (November 2025). — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit)
- Out-of-process AU debugging on Apple silicon: attach Xcode to `AUHostingServiceXPC` after disabling SIP. — [Apple](https://developer.apple.com/documentation/audiotoolbox/debugging-out-of-process-audio-units-on-apple-silicon)
- De-facto host list as advertised by a long-standing plugin vendor: "AUM, Cubasis 3, GarageBand, Logic Pro for iPad, BeatMaker 3, NanoStudio, Loopy Pro, Drambo". — [Audio Damage iOS page](https://www.audiodamage.com/pages/ios)
- Logic tells users to check each AU's compatibility "with the latest version of Logic Pro". — [Logic Pro User Guide for iPad](https://support.apple.com/guide/logicpro-ipad/lpip9b35f249/ipados)
- Known host quirks collected here: Logic iPad does not call `supportedViewConfigurations` (2023); `aumu` with MIDI out is missing from Logic iPad MIDI FX (2023); Logic shows "Untitled" for AUv3 presets (2026); Logic 12 crashes on slow AU load (2026); Loopy Pro and AUM state-saving oddities (snippet only). — [Forums 730609](https://developer.apple.com/forums/thread/730609), [Forums 730956](https://developer.apple.com/forums/thread/730956), [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit), [Loopy Pro forum](https://forum.loopypro.com/discussion/comment/1072887/)
- Apple's own host sample, "Incorporating Audio Effects and Instruments" (iOS 13+, Xcode 16), lists AUs, shows view configurations and handles factory and user presets: a free first host for smoke tests. — [Apple sample](https://developer.apple.com/documentation/audiotoolbox/incorporating-audio-effects-and-instruments)

### Inferences
- Minimum device matrix for "pro citizen": AUM (the reference iOS host; MIDI matrix, multi-instance, state), Logic Pro for iPad (Apple's own host, preset display, view sizing), GarageBand (letterbox size, most users), Loopy Pro (state save), plus Cubasis and Drambo. Each needs a load → play → automate → save → kill → reload → state-equal check. The "loaded in AUM once" on the older sibling app satisfies the first step for one host only (consistent with CLAUDE.md's own "one device run proves one host").
- Checklist:
  - Device-run in AUM, Logic iPad and GarageBand **[REQ before claiming host support]**.
  - Loopy Pro, Cubasis, Drambo, NanoStudio **[PRO]**.
  - auval on a Mac / Catalyst build **[OPT]**, UNVERIFIED for iOS-only builds.

### Gaps
- UNVERIFIED: whether `auval` / `auvaltool` on an Apple silicon Mac can validate an iOS AUv3 installed as a "Designed for iPad" app.
- I found no Cubasis, Drambo or NanoStudio developer documentation.

## 10. As a HOST: what a pro iOS host must support

### Takeaway
A pro iOS host discovers units through `AVAudioUnitComponentManager` (tags, descriptions), instantiates asynchronously and never blocks main, embeds `requestViewController` UIs with view configurations, browses factory and user presets, maps parameters through `AUParameterTree` / `scheduleParameterBlock`, supplies musical context, transport and `contextName`, sets `maximumFramesToRender` before allocation, compensates fixed latency, honours tail time, bounces with `isRenderingOffline`, persists `fullStateForDocument` in the project, and routes MIDI to and from `aumi` / `aumf` / `aumu` (UMP since iOS 15). Inter-App Audio is deprecated since iOS 13.

### Cited Findings
- `AVAudioUnitComponentManager` (iOS 9): it searches components "without opening them"; it supports "system tags and arbitrary user tags … Hosts … can present groupings of audio units according to the tags". Search is by `NSPredicate`, block or `AudioComponentDescription`. — [Apple](https://developer.apple.com/documentation/avfaudio/avaudiounitcomponentmanager)
- `instantiate(with:options:)`: "Certain types of audio units must be instantiated asynchronously, such as version 3 units with a view." "Do not block the main thread while waiting for the completion handler to be called; this can deadlock." — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/instantiate(with:options:completionhandler:))
- `requestViewController` callback "is invoked on a background thread, so you need to dispatch control back to the main queue". Set `maximumFramesToRender` on the AUv3 object (AUv2 equivalent `kAudioUnitProperty_MaximumFramesPerSlice`). — [Apple: Migrating Your Audio Unit Host to the AUv3 API](https://developer.apple.com/documentation/audiotoolbox/migrating-your-audio-unit-host-to-the-auv3-api)
- `renderBlock`: "a host should fetch this block and cache the result. The block can then be called from a realtime context without the possibility of blocking". — [Apple](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/renderblock)
- Host-side extras: `AUMessageChannel` / `messageChannel(for:)` (iOS 16) for custom bidirectional data ("The host manages the message channel object's lifetime"); `migrateFromPlugin` (iOS 16); `token(byAddingRenderObserver:)` for per-render observers (usable for CPU metering, inference). — [messageChannel](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/messagechannel(for:)), [AUMessageChannel](https://developer.apple.com/documentation/audiotoolbox/aumessagechannel), [migrateFromPlugin](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/migratefromplugin), [AUAudioUnit](https://developer.apple.com/documentation/audiotoolbox/auaudiounit)
- Inter-App Audio: `AudioOutputUnitPublish` was **deprecated in iOS 13.0** (visionOS: deprecated at 1.0). — [Apple](https://developer.apple.com/documentation/audiotoolbox/audiooutputunitpublish(_:_:_:_:))
- Community: state-saving in hosts works only for AUv3 (IAA "doesn't support state-saving") (snippet only). AUM routes MIDI output from AU extensions through a MIDI matrix with per-destination filtering, and saves sessions with plugin chain and routing (snippet only). — [Loopy Pro forum](https://forum.loopypro.com/discussion/comment/1072887/), [AUM App Store listing](https://apps.apple.com/py/app/id1055636344)
- Host pitfall (August 2025): `AVAudioUnitComponentManager` listed AUv3 but not AUv2 in a host (expected on iOS, where only system AUv2 exist). — [Forums AudioUnit tag](https://developer.apple.com/forums/tags/audiounit), [Apple: Incorporating…](https://developer.apple.com/documentation/audiotoolbox/incorporating-audio-effects-and-instruments)

### Inferences
- For Echoel as host (`AUAudioUnit.instantiate` already in use), a gap list from the APIs above:
  - Persist each instance's `fullStateForDocument` inside `DMMWProject` / `TimelineDocument`, plus the `AudioComponentDescription` and version, and degrade visibly when a plugin is missing **[REQ]**.
  - Provide `musicalContextBlock` / `transportStateBlock` from `PatternEngine` / `Transport` **[PRO]**.
  - Set `contextName` to the track name **[OPT]**.
  - Latency compensation from `latency` **[PRO]**.
  - Keep rendering for `tailTime` after stop **[PRO]**.
  - Offline bounce with `isRenderingOffline = true` (relevant to `SingleExport`) **[PRO]**.
  - Preset browser covering factory and user presets plus KVO **[PRO]**.
  - Parameter list and automation lanes from `AUParameterTree` into the existing `ModulationEngine` / `SongAutomationEditor` projection **[PRO]**.
  - MIDI routing to `aumi` and from AU MIDI output (`midiOutputEventListBlock`) **[PRO]**.
  - Several instances with independent state **[REQ]**.
  - A per-plugin CPU or overload indicator **[OPT]**.
  - Async instantiation and asynchronous UI request without blocking main **[REQ]**; the render-safety law in CLAUDE.md applies here.
- Hosting adds a modal or embedded plugin-UI surface. In EchoelStudioView this must reuse a slot and not append a modifier (the black-screen law).

### Gaps
- I found no Apple doc on recommended host behaviour for AU crashes or `kAudioComponentErr_InstanceInvalidated` recovery beyond the forum mention of that error.

## 11. Realtime safety in Swift AU render blocks

### Takeaway
Apple's rule for AU render code is explicit: "Don't allocate memory, perform file I/O, take locks, or interact with the Swift or Objective-C runtimes when rendering audio". That is why Apple's own samples put the DSP in C++. Swift-only AUs must avoid ARC traffic, closure capture boxing, CoW arrays, existentials and generic metadata instantiation, and error throwing on the render path. LLVM 20's RealtimeSanitizer has a Swift wrapper for detecting violations.

### Cited Findings
- Apple: "To ensure glitch-free performance, your plug-in's audio processing must occur in a real-time safe context. Don't allocate memory, perform file I/O, take locks, or interact with the Swift or Objective-C runtimes when rendering audio." — [Apple: Creating custom audio effects](https://developer.apple.com/documentation/avfaudio/creating-custom-audio-effects)
- Apple's template uses "C++ for real-time processing, and Objective-C for interacting between Swift and C++". — [Apple: Creating an Audio Unit extension](https://developer.apple.com/documentation/avfaudio/creating-an-audio-unit-extension)
- `AUInternalRenderBlock` signature: `(UnsafeMutablePointer<AudioUnitRenderActionFlags>, UnsafePointer<AudioTimeStamp>, AUAudioFrameCount, Int, UnsafeMutablePointer<AudioBufferList>, UnsafePointer<AURenderEvent>?, AURenderPullInputBlock?) -> AUAudioUnitStatus`. "If instead an error is returned, the output data should be assumed to be invalid." — [Apple](https://developer.apple.com/documentation/audiotoolbox/auinternalrenderblock)
- Swift pitfalls named in a Swift gain-loop write-up: exclusivity checking, protocol lookup and metadata instantiation, and copy-on-write on arrays, each of which may allocate (snippet only). — [Infinum write-up](https://infinum.com/?p=19264889)
- Swift Forums: the compiler can wrap a returned Swift closure in a block that calls `swift_allocObject` inside `internalRenderBlock`. Class-backed types (Array, String) imply reference counting, and errors heap-allocate. An experimental `@_noAllocations` attribute makes the compiler error on possible heap allocation (snippet only). — [Swift Forums: Realtime threads with Swift](https://forums.swift.org/t/realtime-threads-with-swift/40562), [Swift Forums: Is Swift really not performant enough for realtime audio?](https://forums.swift.org/t/is-swift-really-not-performant-enough-for-realtime-audio/65372)
- RealtimeSanitizer ships with LLVM 20 and is integrated in Clang. The Swift wrapper "RTSanStandaloneSwift" bundles a prebuilt RTSan with a Swift API (snippet only). — [Swift Forums: Introducing RealtimeSanitizer for Swift](https://forums.swift.org/t/introducing-realtimesanitizer-for-swift/78898), [Infinum](https://infinum.com/?p=19264889)
- `musicalContextBlock` / `transportStateBlock` must be cached before render. `scheduleParameterBlock` is safe from realtime threads. — [musicalContextBlock](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/musicalcontextblock), [scheduleParameterBlock](https://developer.apple.com/documentation/audiotoolbox/auaudiounit/scheduleparameterblock)

### Inferences
- Swift-only render pattern (consistent with Echoel's existing `nonisolated(unsafe)` mirror law):
  - Build the render closure once, in `allocateRenderResources`, capturing only a pre-allocated `final class` kernel through `Unmanaged`, or capturing unsafe pointers.
  - Preallocate every buffer to `maximumFramesToRender`.
  - Walk the `AURenderEvent` linked list by pointer.
  - No `[Float]` mutation, no `String`, no `throw`, no `any Protocol` calls, no `@MainActor` hop, no `os_log`.
  - Hand parameters across through atomics or the event list only.
- A RealtimeSanitizer CI or test step would turn this into a machine check. It requires an LLVM-20-class toolchain, and whether Xcode 26 exposes `-fsanitize=realtime` is UNVERIFIED.

### Gaps
- UNVERIFIED: Apple's current (2026) official position on Swift DSP in render blocks beyond the sample text, and whether Xcode 26 ships RealtimeSanitizer.
- The Swift Forums pages could not be fetched in this session. Details come from search summaries.

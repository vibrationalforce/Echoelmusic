# Spatial / Immersive Audio Production for an iPhone/iPad Workstation (state: October 2026)

Scope note: production technology only. Tags used on every item:
**[OS-FW: framework, min OS]** = an Apple (or other OS) framework provides it ·
**[OPEN]** = open standard / permissively licensed spec or code ·
**[PROPRIETARY]** = licence, certification or a vendor tool is required ·
**[NOT-ON-DEVICE]** = cannot reasonably be done inside an iOS/iPadOS app today.
"UNVERIFIED" marks claims I could not confirm against a primary source.
Research date: 2026-10-19. Two Apple pages (help.apple.com, apple.com) failed to resolve from
the research sandbox (DNS), so the Apple Music delivery spec below is quoted from search
snippets of Apple's own page plus Dolby's playbook, not from a full fetch.

## 1. Apple frameworks: what exists for spatial rendering, monitoring and encoding (PHASE, AVAudioEnvironmentNode, AUSpatialMixer, head tracking, visionOS, WWDC 2025 ASAF/APAC)

### Takeaway
Apple has four separate layers. (1) **AVAudioEnvironmentNode** (iOS 8+) is the AVAudioEngine-native 3D mixer. It spatializes **mono inputs only**. Its listed multichannel outputs have no height layouts. Head tracking was added in iOS 18, and personalized-HRTF access works through an entitlement. (2) **PHASE** (iOS 15+) is a game-style engine with geometry and occlusion. (3) **AUSpatialMixer** (AudioToolbox) is the renderer that WWDC25 shows behind the new Cinematic `AUAudioMix`, with headphone, built-in-speaker and external-speaker output and 5.1 / 7.1.4 layouts. (4) **APAC** is Apple's delivery codec. Its platform **encoder needs OS 26** and handles **channel-based up to 64 ch and ambisonics up to 3rd order, not objects**. Its **decoder runs on iOS 17+**. **ASAF** is Apple's production format (BWF + PCM + metadata), and it has **no public specification**.

### Cited Findings
**AVAudioEnvironmentNode / AVAudio3DMixing** — [OS-FW: AVFAudio, iOS/iPadOS 8.0, macOS 10.10, visionOS 1.0]
- `AVAudioEnvironmentNode` is "a mixer node that simulates a 3D audio environment". Sources are any `AVAudioMixing` node (e.g. `AVAudioPlayerNode`). The listener is implicit. Distance attenuation and reverb are properties. — [Apple: AVAudioEnvironmentNode](https://developer.apple.com/documentation/avfaudio/avaudioenvironmentnode)
- **Hard limit:** "Spatialization applies only to inputs with a mono channel connection format. This class doesn't spatialize stereo inputs or support inputs with connection formats of more than two channels." — [Apple: AVAudioEnvironmentNode](https://developer.apple.com/documentation/avfaudio/avaudioenvironmentnode)
- Multichannel output is limited to these channel-layout tags: `kAudioChannelLayoutTag_AudioUnit_4`, `_5_0`, `_6_0`, `_7_0`, `_7_0_Front`, `_8`. No x.y.4 height layout appears in that list. Other members: `outputType: AVAudioEnvironmentOutputType`, `applicableRenderingAlgorithms`, `listenerPosition`, `listenerAngularOrientation`, `listenerVectorOrientation`, `distanceAttenuationParameters`, `reverbParameters`, `outputVolume`. — [Apple: AVAudioEnvironmentNode](https://developer.apple.com/documentation/avfaudio/avaudioenvironmentnode)
- `AVAudio3DMixingRenderingAlgorithm` has seven cases, set per input bus:
  - `.auto`: "Automatically selects the highest-quality rendering algorithm available for the current playback hardware"
  - `.equalPowerPanning`: cheapest, stereo field
  - `.sphericalHead`: ITD-based headphone emulation
  - `.HRTF`: "filtering to emulate 3D space in headphones"
  - `.HRTFHQ`: "A higher-quality head-related transfer function rendering algorithm"
  - `.soundField`: "renders to multichannel hardware"
  - `.stereoPassThrough`: no localization

  "When rendering to multichannel hardware, most of the rendering algorithms only render to channels 1 and 2, excluding `.soundField` and `.auto`." — [Apple: AVAudio3DMixingRenderingAlgorithm](https://developer.apple.com/documentation/avfaudio/avaudio3dmixingrenderingalgorithm)
- **Head tracking:** `isListenerHeadTrackingEnabled` is available on iOS/iPadOS/tvOS/Mac Catalyst 18.0 and macOS 15.0 (visionOS is not listed). It "enable[s] head tracking with compatible AirPods" and requires the `com.apple.developer.coremotion.head-pose` entitlement. — [Apple: isListenerHeadTrackingEnabled](https://developer.apple.com/documentation/avfaudio/avaudioenvironmentnode/islistenerheadtrackingenabled)
- The June 2024 AVFAudio update added three things [OS-FW: iOS 18]:
  - head tracking, as above
  - "Tailor AVAudioEnvironmentNode output according to a person's personalized spatial audio profile" via the `com.apple.developer.spatial-audio.profile-access` entitlement
  - an `AVGameBypassSystemSpatialAudio` Info.plist key that makes the node ignore the new Control Center spatial-audio toggle

  — [Apple: AVFAudio updates](https://developer.apple.com/documentation/updates/avfaudio)

**PHASE (Physical Audio Spatialization Engine)** — [OS-FW: PHASE, iOS/iPadOS 15.0, macOS 12.0, tvOS 17.0, visionOS 1.0]
- PHASE is a game/app engine with sources, listener, occluders, shapes and materials, geometric occlusion, reverb/reflections, and sound-event node trees. Mixers: `PHASESpatialMixerDefinition` (via "Spatial Mixing"), `PHASEAmbientMixerDefinition` ("outputs sound in a particular direction"), `PHASEChannelMixerDefinition` ("routes sound directly to the device's output"). Other pieces: `PHASEAutomaticHeadTrackingFlags`, a "Personalizing spatial audio in your app" article, and pull/stream nodes. Apple's own note: "If the audio in your game or app doesn't incorporate environmental events or cues, you can use AVFoundation or Core Audio." — [Apple: PHASE](https://developer.apple.com/documentation/phase)
- In Sept 2025 a developer asked an Apple engineer whether the PHASE AmbientMixer would gain ambisonic support. The engineer gave no roadmap ("I'm unable to share anything on that front here"). — [Apple Developer Forums thread 801541](https://developer.apple.com/forums/thread/801541)

**AUSpatialMixer / AUAudioMix (WWDC 2025)** — [OS-FW: AudioToolbox + Cinematic; Audio Mix on iOS/macOS 26]
- `kAudioUnitSubType_SpatialMixer` exists in AudioToolbox, but its documentation page shows no availability metadata and no description. — [Apple: kAudioUnitSubType_SpatialMixer](https://developer.apple.com/documentation/audiotoolbox/kaudiounitsubtype_spatialmixer)
- WWDC25 session 251 ("Enhance your app's audio recording capabilities"):
  - Signal flow: FOA input → speech/ambience separation → `AUSpatialMixer`.
  - `AUAudioMix` parameters: `RemixAmount`, `Style`, `EnableSpatialization` (off by default; when off, output is 5 ch = 4 FOA + 1 dialog; when on, layouts such as 5.1 and 7.1.4), `SpatialMixerOutputType` (headphones / built-in speakers / external speakers), and `SpatialAudioMixMetadata` (CFData).
  - The session does not describe AVAudioEngine use.

  — [WWDC25 session 251](https://developer.apple.com/videos/play/wwdc2025/251/)
- From the same session, the capture and file side:
  - iOS 18: spatial capture via `AVCaptureMovieFileOutput` with `multichannelAudioMode = .firstOrderAmbisonics`.
  - iOS 26: spatial capture with `AVAssetWriter` (two `AVCaptureAudioDataOutput`s, `spatialAudioChannelLayoutTag`, `AVCaptureSpatialAudioMetadataSampleGenerator`), plus QuickTime audio `.qta` and the Cinematic `CNAssetSpatialAudioInfo` / `CNSpatialAudioRenderingStyle`.
  - The format is FOA, "HOA-ACN-SN3D".
  - Asset layout: AAC stereo compatibility track + APAC spatial track + at least one metadata track.

  — [WWDC25 session 251](https://developer.apple.com/videos/play/wwdc2025/251/)

**APAC (Apple Positional Audio Codec)** — encoder [OS-FW: macOS/iOS/iPadOS/tvOS/visionOS 26.0]; decoder [OS-FW: macOS 14.0, iOS/iPadOS/tvOS 17.0, visionOS 1.0]
- Apple's APAC document (June 2025) says: "The APAC encoder that ships with Apple platforms supports scene-based and channel-based formats". Ambisonics is "supported up to third order". — [Apple: APAC platform encoder/decoder PDF](https://developer.apple.com/av-foundation/Apple-Positional-Audio-Codec.pdf)
- Profile/Level table from the same PDF:

  | Input | Profile | Level |
  |---|---|---|
  | Ambisonics, max order 3 | 5 | 0 |
  | 2 ch | 31 | 0 |
  | 6 ch | 31 | 1 |
  | 8 ch | 31 | 2 |
  | 12 ch | 31 | 3 |
  | 24 ch | 31 | 4 |
  | 32 ch | 31 | 5 |
  | 64 ch | 31 | 6 |

  — [Apple APAC PDF](https://developer.apple.com/av-foundation/Apple-Positional-Audio-Codec.pdf)
- Loudness/DRC metadata sits in the bitstream and is mandatory. `AVEncoderContentSourceKey` takes an `AVAudioContentSource` value. `AVEncoderDynamicRangeControlConfigurationKey` takes an `AVAudioDynamicRangeControlConfiguration` value; "the value AVAudioDynamicRangeControlConfiguration_None should not be utilized, as inclusion of loudness/DRC metadata is a mandatory requirement". `AVEncoderASPFrequencyKey` sets the sync-packet interval: for HLS, every segment must start with an ASP, and the recommended interval is 1.6 s (= 75 at 48 kHz). `afconvert` supports `-d apac`, e.g. `-l MPEG_5_1_A` or FOA `-l 0xBE0004`, and decoding FOA to binaural PCM with `-l Binaural`. — [Apple APAC PDF](https://developer.apple.com/av-foundation/Apple-Positional-Audio-Codec.pdf)
- A WWDC25 quote (via the forum thread) says APAC "is required for any Apple immersive video experience". APAC playback is "available on all Apple platforms except watchOS, and supports Channels, Objects, Higher Order Ambisonics, Dialogue, Binaural audio, interactive elements". — [Apple Developer Forums 801541, quoting WWDC25 "Learn About Apple Immersive Video Technologies"](https://developer.apple.com/forums/thread/801541)
- Secondary report: APAC streams at 64–768 kbps, mainly in .MP4. — [TechRadar](https://www.techradar.com/audio/apple-quietly-just-unveiled-a-new-spatial-audio-format-that-expands-on-dolby-atmos-and-that-rivals-google-and-samsungs-eclipsa-audio) (secondary, not in Apple's PDF)

**ASAF (Apple Spatial Audio Format)** — [PROPRIETARY / undocumented]
- WWDC25 description (quoted in the forum): "composed of new metadata coupled with linear PCM, and a powerful new spatial renderer that's built into Apple platforms … numerous point sources and high resolution sound scenes, or higher order ambisonics". "ASAF is carried inside of broadcast Wave files with linear PCM signals and metadata … to stream ASAF audio, you will need to encode that audio as an mp4 APAC file." — [Apple Developer Forums 801541](https://developer.apple.com/forums/thread/801541)
- The Apple engineer's answer (Sept 2025) says documentation is "mostly … WWDC videos" and API docs, with no format spec. "Davinci Resolve is currently capable of authoring ambisonic ASAF content". Resolve and the Compressor app can encode an ASAF master WAV into APAC. AVPlayer plays ASAF content, for example on a RealityKit `VideoMaterial`. — [Apple Developer Forums 801541](https://developer.apple.com/forums/thread/801541)
- DaVinci Resolve 20.1 added Apple Spatial Audio (ASAF) mixing and Vision Pro support. — [audioXpress](https://audioxpress.com/news/blackmagic-design-announces-davinci-resolve-20-1-adding-support-for-apple-spatial-audio-and-apple-vision-pro)
- Press framing: ASAF was designed mainly for visionOS but runs on iOS/macOS/tvOS. APAC can also carry Dolby Atmos data instead of ASAF. — [TechRadar](https://www.techradar.com/audio/apple-quietly-just-unveiled-a-new-spatial-audio-format-that-expands-on-dolby-atmos-and-that-rivals-google-and-samsungs-eclipsa-audio); [Mix](https://www.mixonline.com/business/apple-introduces-new-spatial-audio-format) (secondary)

**visionOS / RealityKit audio** — [OS-FW: RealityKit, visionOS 1.0]
- `SpatialAudioComponent` sets how sound emits from an entity (directivity e.g. `.beam(focus:)`) and incorporates the room acoustics. `AmbientAudioComponent` emits each channel from an angle relative to the entity, without reverberation, and ignores position. `ChannelAudioComponent` renders channel-based content without spatialization. Audio loads through `AudioFileResource` and plays via `AudioPlaybackController`. — [Apple: SpatialAudioComponent](https://developer.apple.com/documentation/realitykit/spatialaudiocomponent); [Apple: AmbientAudioComponent](https://developer.apple.com/documentation/realitykit/ambientaudiocomponent); [Apple: Playing spatial audio in visionOS](https://developer.apple.com/documentation/visionos/playing-spatial-audio-in-visionos)
- Ambisonics in AVAudioEngine dates back to WWDC19 session 510 (older), and the layout tag is `kAudioChannelLayoutTag_HOA_ACN_SN3D`. This is cited by the forum thread starter, not an Apple engineer. — [Apple Developer Forums 801541](https://developer.apple.com/forums/thread/801541)

### Inferences
- With Echoel's iOS 18 floor, `isListenerHeadTrackingEnabled` and the personalized-profile entitlement are available without an availability gate. APAC **encoding** needs `#available(iOS 26, *)`. APAC **decoding** is always available.
- `AVAudioEnvironmentNode` fits **object monitoring of mono sources on headphones**: each track becomes a mono object on its own input bus, rendered with HRTFHQ plus head tracking. It cannot be the bed/ambisonic renderer, because it takes no multichannel inputs and lists no height output layout. A 7.1.4 bed monitor or an ambisonic-scene monitor would have to go through `AUSpatialMixer`, which can be hosted as an `AVAudioUnit` in AVAudioEngine. Whether AUSpatialMixer accepts arbitrary bed and HOA inputs in a third-party graph is not documented in what I read — see Gaps.
- The **platform APAC encoder** handles channel-based and ambisonic content only. An independent app can therefore deliver APAC as "bed up to 64 ch" or "HOA up to 3rd order". It cannot author object-based ASAF/APAC through a documented API. Only Apple's own and partner tools (Resolve, Compressor) are named as ASAF authors.
- PHASE is the wrong layer for a DAW. It is event- and geometry-driven, and Apple itself redirects non-game apps to AVFoundation/Core Audio.

### Gaps
- AUSpatialMixer: no Apple doc page with availability, input formats (does it take HOA or a 7.1.4 bed as input?), or the property list. The constant names `kAudioUnitProperty_SpatialMixerOutputType` and `kSpatialMixerOutputType_*` are UNVERIFIED as exact spellings beyond the WWDC25 parameter names.
- ASAF metadata schema: not public. Apple engineer, Sept 2025: no documentation beyond WWDC sessions. I found nothing newer up to Oct 2026.
- Whether `AVAssetWriter` + APAC can carry **objects** written by a third-party app: UNVERIFIED. The PDF says the platform encoder is scene- and channel-based.
- WWDC 2026 (June 2026) announcements: not researched. I found no source in this pass, so anything announced there is a gap.
- I found no source on `CMHeadphoneMotionManager` (iOS 14+) details in this pass. Its relationship to the newer `head-pose` entitlement is UNVERIFIED.

## 2. Delivery formats: which can an independent app write legally and technically (Atmos ADM BWF, ADM/BW64, Ambisonics, binaural, IAMF/Eclipsa, MPEG-H, Sony 360RA)

### Takeaway
Two deliverables are fully open and writable today with no licence: **ADM BWF/BW64 as an open container + metadata** (ITU-R BS.2076-3 / BS.2088) and **IAMF / Eclipsa Audio** (AOM royalty-free, BSD-3-Clause-Clear reference code, accepted by YouTube). **Ambisonics** (ACN/SN3D) and **binaural stereo renders** are also open. Apple Music asks specifically for a **Dolby Atmos ADM BWF**: 48 kHz / 24-bit, ≤ -18 LKFS, ≤ -1 dBTP, built from stems. Writing that file is technically possible because Dolby publishes an ADM profile for application developers. Whether a file from a non-Dolby renderer passes Apple's QC is UNVERIFIED. **MPEG-H** and **Sony 360RA** require licences.

### Cited Findings
**Apple Music immersive delivery** — [PROPRIETARY target (Dolby Atmos), open container]
- Search snippets of Apple's own asset guide:
  - 5.1/7.1 audio is LPCM in .mov at 48 kHz, 16 or 24 bit.
  - Atmos is delivered as BWF ADM, one file per album track.
  - Track boundaries must be within ±1,000 samples at 48 kHz (half a frame) of the stereo deliverable.
  - "5.1 and 7.1 audio files generated from stereo mixes are not allowed. Upmixing from 5.1 to 7.1 is not allowed."
  - Integrated loudness "should not exceed -18 LKFS measured as per ITU-R BS.1770-4". True peak -1 dBTP.
  - "Immersive audio that does not meet the requirements may be removed from Apple Music."

  — [Apple Video & Audio Asset Guide (via search; direct fetch failed)](https://help.apple.com/itc/videoaudioassetguide/en.lproj/itcf946aaace.html)
- Dolby Atmos Music Delivery Playbook (June 2024): target -18 LKFS ±2 LU (BS.1770-4), peaks ≤ -1 dBTP. For albums, measure each track and target the loudest at -18. Binaural Render Mode is set per bed and object (Off/Near/Mid/Far). The master file carries max 128 channels = 10 bed + 118 objects at 24-bit/48 kHz. — [Dolby Atmos Music Delivery Playbook (PDF)](https://dolby.com/siteassets/dolby-institute/dolby-atmos-music-accelerator/dolby-atmos-music-delivery-playbook-1.pdf)
- "Dolby Atmos Master ADM Profile v1.0" (22 July 2019) is "intended primarily for application developers who wish to implement support for ADM BWF .wav files". The cover is marked confidential. MediaArea lists v1.1 as the latest known version and calls the profile a required subset of ADM. — [Dolby ADM Profile v1.0 PDF](https://developer.dolby.com/globalassets/documentation/technology/dolby_atmos_master_adm_profile_v1.0.pdf); [MediaArea spec page](https://mediaarea.net/Specs/Dolby_Atmos_Master_ADM_Profile) (older, 2019)
- Dolby offers two routes to its renderer: native integration in a DAW, or the standalone Dolby Atmos Renderer next to the DAW (up to 128 inputs, with a Music Panner plug-in in AAX/AU/VST). The Renderer now includes the former Production and Mastering Suites. — [Dolby: Dolby Atmos Renderer](https://professional.dolby.com/product/dolby-atmos-content-creation/dolby-atmos-renderer/)
- Distributor-level requirements (stems not stereo, no upmix, sync to the stereo reference) are repeated by aggregators. — [Revelator helpdesk](https://helpdesk.revelator.com/support/solutions/articles/69000859704); [Music Gateway](https://help.musicgateway.com/do-you-distribute-dolby-atmos-releases) (secondary)

**ADM / BW64 / reference renderer (ITU, EBU)** — [OPEN]
- ITU-R **BS.2076-3** (Audio Definition Model) was approved in February 2025 and is in force; -0 to -2 are superseded. — [ITU-R BS.2076-3](https://www.itu.int/rec/R-REC-BS.2076-3-202502-I/en)
- **BS.2088** specifies BW64, which lifts the 4 GB WAVE limit and links metadata. **BS.2127** (June 2019) is the ADM reference renderer for BS.2051 layouts and is largely based on the EBU ADM Renderer (EAR). — [EBU Tech 3388](https://knowledgehub.ebu.ch/files/live/sites/tech/files/shared/tech/tech3388.pdf); [libear docs](https://libear.readthedocs.io/)
- **libear** is C++14, implements BS.2127 gain calculation, and is licensed **Apache-2.0** (IRT + BBC R&D). It does not read BW64 or parse ADM XML; the companion projects libbw64 and libadm do. Missing features: Cartesian positions, divergence, zoneExclusion, channelLock, screenRef, screenEdgeLock. — [github.com/ebu/libear](https://github.com/ebu/libear); [libear docs](https://libear.readthedocs.io/)
- The EAR Python reference documentation cites BS.2076-1. Whether EAR has been updated for BS.2076-3 is unknown. — [PyPI ear](https://pypi.org/project/ear/)

**IAMF / Eclipsa Audio** — [OPEN: AOM royalty-free spec; BSD-3-Clause-Clear code]
- Eclipsa Audio is Google and Samsung's brand for AOMedia IAMF, "available under a royalty free license from AOMedia". — [Google Open Source Blog, Jan 2025](https://opensource.googleblog.com/2025/01/introducing-eclipsa-audio-immersive-audio-for-everyone.html)
- Profiles (June 2025 post):

  | Profile | IAMF version | Audio elements | Channels |
  |---|---|---|---|
  | Simple | v1.0 | 1 | 16 |
  | Base | v1.1 | 2 | 18 |
  | Base-Enhanced | v1.1 | 28 | 28 |

  Codecs: Opus, AAC, FLAC, PCM. An open-source Eclipsa DAW/NLE plugin was released. Since January 2025 YouTube accepts Eclipsa (IAMF v1.0) uploads; the codec string is `iamf.001.001.Opus`. Samsung's 2025 TVs and soundbars support it. The example video uses 3rd-order ambisonics + stereo = 2 elements / 18 channels. — [Google Open Source Blog, June 2025](https://opensource.googleblog.com/2025/06/introducing-open-source-daw-plugin-for-eclipsa-audio.html)
- **libiamf** is the reference decoder and conformance code for IAMF v1.1.0, including the base-enhanced profile. The spec was approved as final on 24 Oct 2024. Licence: **BSD-3-Clause-Clear**. — [github.com/AOMediaCodec/libiamf](https://github.com/AOMediaCodec/libiamf)
- **iamf-tools** (encoder tooling) is BSD 3-Clause Clear and is also mirrored into AOSP. — [AOSP iamf_tools](https://android.googlesource.com/platform/external/iamf_tools)
- Google also cites an open binaural renderer behind Eclipsa (Tonmeister magazine, 2025). — [Tonmeister](https://tonmeister.org/de/magazin/2025/4/democratising-immersive-audio/) (not fetched; secondary)

**MPEG-H 3D Audio and Sony 360 Reality Audio** — [PROPRIETARY]
- Via LA's MPEG-H 3D Audio patent pool launched in June 2021 (licensors include Fraunhofer, Dolby, Sony, later Samsung, Panasonic and others). Per-unit fees start at US$0.70 for the first 500k units and fall to US$0.25 above 50M, with an annual cap of US$20M. The pool covers the Low Complexity and Baseline profiles of ISO/IEC 23008-3. — [Via LA: MPEG-H](https://www.via-la.com/licensing/mpeg-h/)
- Sony 360RA is object-based on MPEG-H 3D Audio. Sony requires a content-creation licence to edit and encode, and a format licence agreement to distribute. Distribution apps must include Sony's decoder, renderer and virtualizer. The authoring tool is the WalkMix Creator plug-in (Audio Futures, Inc.). — [Sony 360RA licensing](https://sony.co.jp/en/Products/360RA/licensing); [Sony Create 360RA](https://www.sony.co.jp/en/Products/create360RA/); [Fraunhofer/Business Wire 2021](https://www.businesswire.com/news/home/20211022005382/en/Fraunhofer-IIS-Announces-Sony-has-Licensed-MPEG-H-Audio-Decoder-Software-and-joined-the-MPEG-H-Trademark-Program)

**Ambisonics conventions** — [OPEN]
- Apple's native ambisonic convention is ACN channel order with SN3D normalisation (the AmbiX convention): the WWDC25 FOA layout is "HOA-ACN-SN3D", and the layout tag is `kAudioChannelLayoutTag_HOA_ACN_SN3D`. — [WWDC25 session 251](https://developer.apple.com/videos/play/wwdc2025/251/); [Apple Developer Forums 801541](https://developer.apple.com/forums/thread/801541)
- APAC encodes ambisonics up to 3rd order (16 ch). — [Apple APAC PDF](https://developer.apple.com/av-foundation/Apple-Positional-Audio-Codec.pdf)

### Inferences
Writability summary for an independent iOS app:

| Format | Tag | Can Echoel write it? | Main constraint |
|---|---|---|---|
| ADM BWF / BW64 (open ADM, BS.2076-3 + BS.2088) | [OPEN] | Yes: plain RIFF/BW64 chunk writing plus ADM XML | None |
| "Dolby Atmos" ADM BWF for Apple Music | Container [OPEN] / compliance [PROPRIETARY] | Probably writable | Must match the Dolby Atmos Master ADM Profile: ≤ 128 ch, 10 bed + 118 objects, binaural render mode metadata, -18 LKFS / -1 dBTP |
| APAC .mp4 | [OS-FW: AVFoundation, iOS 26] | Yes | Bed or HOA ≤ 3rd order only, loudness/DRC metadata mandatory |
| IAMF / Eclipsa (.mp4) | [OPEN] | Yes | Opus/AAC/FLAC/PCM; Opus and FLAC encoding have no Apple-native path, see Gaps |
| AmbiX FOA/HOA WAV | [OPEN] | Yes, trivially | None |
| Binaural stereo render | [OPEN] | Yes | Offline-render the monitor path to a stereo file |
| MPEG-H / Sony 360RA | [PROPRIETARY] | Not without licences | Via LA pool, Sony format licence |
| Dolby Digital Plus JOC / AC-4 encoding (consumer Atmos) | [PROPRIETARY] | No | Not offered to third-party apps per sources read, UNVERIFIED |

- Writing the Dolby-profile ADM BWF is a separate question from **rendering** it. Echoel would preview through its own or Apple's renderer, never through Dolby's. Since Apple's QC follows Dolby's tools, a self-rendered binaural preview can differ from what Apple Music users hear. That is a product risk, not a legal one.

### Gaps
- **Legal:** I found no Dolby page stating whether a non-licensee may write files described as "Dolby Atmos" ADM BWF, or what trademark use requires. The ADM profile PDF is marked "Confidential information", so its redistribution terms are unclear. UNVERIFIED and needs Dolby Professional contact.
- **Apple QC:** I found no source saying whether Apple Music accepts Atmos ADM BWF masters not produced by the Dolby Atmos Renderer or Logic. UNVERIFIED.
- `.amb` (FuMa-ordered B-format WAVE-EX): no current primary source found in this pass.
- IAMF on Apple: no native Opus/FLAC encoder path into IAMF was found in this pass. libiamf is decoder-only, and an encoder would be iamf-tools (C++/Abseil), which conflicts with Echoel's Swift-only, zero-dependency rule.
- MPEG-H authoring tool licensing (Fraunhofer MPEG-H Authoring Suite) and any free tier: not found.

## 3. Production workflow norms: object vs bed vs scene mixing, headphone monitoring (personalized HRTF), immersive loudness, and what Logic Pro offers

### Takeaway
Professional immersive music today is **bed + objects (Dolby Atmos model)**, delivered as ADM BWF, monitored on headphones through a binaural render with per-object near/mid/far modes, and measured with BS.1770 (now -5). Apple Music sets a ceiling of -18 LKFS / -1 dBTP. **Scene-based (ambisonic)** mixing is the norm for 360/VR/YouTube and is the only scene format Apple's APAC encoder takes. Logic Pro on **Mac** has full Atmos (7.1.4 panners, ADM BWF export). I found **no source that Logic Pro for iPad has Atmos tools**.

### Cited Findings
- Bed + object model: a Dolby Atmos master holds up to 128 channels (10 bed + 118 objects). The bed ranges from LCR to 7.1.2, and each bed or object carries a binaural render mode (Off/Near/Mid/Far). — [Dolby Atmos Music Delivery Playbook (June 2024)](https://dolby.com/siteassets/dolby-institute/dolby-atmos-music-accelerator/dolby-atmos-music-delivery-playbook-1.pdf)
- Headphone QC practice: the Dolby renderer's binaural output is used as a "reasonable QC proxy" for Apple Music Spatial Audio. The article also advises limiting peaks for binaural playback to about 3 dB or less per track. — [Production Expert](https://www.production-expert.com/production-expert-1/if-you-are-mixing-dolby-atmos-for-music-for-apple-music-read-this-now) (practitioner, secondary)
- Loudness for immersive is measured with ITU-R BS.1770. The current edition is **BS.1770-5** (Nov 2023); Apple and Dolby still cite -4, and a further revision is in drafting in 2024–2026 (TIES-restricted). — [ITU-R BS.1770-5](https://www.itu.int/rec/R-REC-BS.1770-5-202311-I)
- Targets: Apple ≤ -18 LKFS integrated, ≤ -1 dBTP; Dolby -18 LKFS ±2 LU. — [Apple Asset Guide (via search)](https://help.apple.com/itc/videoaudioassetguide/en.lproj/itcf946aaace.html); [Dolby playbook](https://dolby.com/siteassets/dolby-institute/dolby-atmos-music-accelerator/dolby-atmos-music-delivery-playbook-1.pdf)
- Personalized HRTF: on iOS, Personalized Spatial Audio builds an HRTF from an iPhone head scan. Third-party apps can apply it to `AVAudioEnvironmentNode` output with the `com.apple.developer.spatial-audio.profile-access` entitlement (iOS 18). PHASE has a "Personalizing spatial audio in your app" article. — [Apple: AVFAudio updates](https://developer.apple.com/documentation/updates/avfaudio); [Apple: PHASE](https://developer.apple.com/documentation/phase); consumer context: [AppleVis forum](https://applevis.com/comment/163275) (anecdotal)
- Logic Pro (Mac): integrated Dolby Atmos since 10.7, with panners and meters up to 7.1.4 and export of Apple Music-compatible Atmos ADM BWF. — [MIDI.org on Logic Pro 10.7](https://midi.org/apple-releases-logic-pro-10-7-with-dolby-atmos-and-spatial-audio); [Apple Logic Pro page (via search)](https://www.apple.com/logic-pro/) (10.7 is 2021, older)
- Search results for Logic Pro for iPad 2 list Session Players, ChromaGlow and Stem Splitter. The "Spatial Audio" items found (downmix/trim) are not attributed to iPad. No source found that the iPad app mixes or exports Atmos. — [Apple Logic Pro page (via search)](https://www.apple.com/logic-pro/) (UNVERIFIED for iPad)
- Scene-based capture on iPhone is FOA (iOS 18 / 26 APIs). Apple's Audio Mix modes (Cinematic, Studio, In-Frame, speech-only, ambience-only) are a consumer-grade remix of FOA, not a mixing workflow. — [WWDC25 session 251](https://developer.apple.com/videos/play/wwdc2025/251/)

### Inferences
- An iPad DAW that offers bed + objects + ADM BWF export would cover something that Logic Pro for iPad appears not to cover (UNVERIFIED). That is a real gap in the iPad market, not a duplication.
- Minimum professional monitoring chain on device:
  1. Object positions per track.
  2. A binaural headphone render with HRTF, head tracking and personalized profile, via `AVAudioEnvironmentNode` for mono objects, or `AUSpatialMixer` for beds.
  3. A **BS.1770 multichannel loudness meter** (K-weighting per channel with channel weights; heights are included with weight 1.0 in BS.1770-4/-5; UNVERIFIED detail).
  4. True-peak metering.
  5. A **fold-down/stereo reference** for Apple's sync rule.
- Per-object binaural render mode (near/mid/far) is metadata Echoel would have to store per track to produce a Dolby-profile ADM.

### Gaps
- Exact BS.1770-5 changes relative to -4 for multichannel/height channel weights: not read (the PDF was not fetched).
- Apple's own loudness targets for APAC / Apple Immersive content: not found.
- Logic Pro for iPad current version (Oct 2026) feature list: apple.com was unreachable from the sandbox. UNVERIFIED.

## 4. Live / installation side: ADM-OSC status and supporters, and open-source renderers with licences

### Takeaway
**ADM-OSC v1.0** is a published, MIT-licensed spec (implementation guide on the AES eLibrary) for streaming object metadata over OSC. It is implemented by most immersive live systems: L-ISA, SPAT Revolution, Merging Ovation, Nuendo, Meyer SpaceMap Go, QLab 5, Adamson FletcherMachine, d&b En-Bridge, Fulcrum One and others. Open-source renderer cores are split by licence. **Apache-2.0 / BSD / MIT** (libear, Steam Audio, Resonance Audio, Omnitone, libiamf) can be studied or ported with attribution. **GPLv3** (IEM, SPARTA) and **LGPL-2.1+** (libspatialaudio) are problematic for a closed App Store binary.

### Cited Findings
- **ADM-OSC** [OPEN, MIT] — [github.com/immersive-audio-live/ADM-OSC](https://github.com/immersive-audio-live/ADM-OSC)
  - Status: "Specification v1.0 and implementation guide" via the AES eLibrary (no date on the page). The dictionary covers most ADM object properties and is still being extended. There is an OSC live test tool (talker/listener) and a Python module.
  - Listed implementations: SPAT Revolution (FLUX::), L-ISA Controller (L-Acoustics), Ovation (Merging), Nuendo (Steinberg), SpaceMap Go (Meyer Sound), QLab 5 (Figure 53), Space Controller (Sound Particles), Modulo Kinetic (Modulo Pi), Iosono (Barco), **FletcherMachine (Adamson)**, En-Bridge (d&b audiotechnik), Fulcrum One (Fulcrum Acoustic).
  - Contributors: Adamson, d&b, DiGiCo, Dolby, Lawo, Magix, Merging, Meyer, Steinberg. Originators: L-Acoustics, FLUX::, Radio France.
  - Conventions: the sender always sends **normalized** positions, and the receiver applies any local scaling of x/y/z/distance. Gain is normalized (≤ 1.0 in the error example). Address examples: `/adm/obj/1/gain`, plus azim/elev/dist, `aed` and `xyz` messages.
- Origin (2021): FLUX::, L-Acoustics and Radio France proposed OSC as a streaming protocol aligned with ITU BS.2076-2. SPAT Revolution and L-ISA Controller shipped first. — [AudioTechnology](https://www.audiotechnology.com/news/push-for-object-based-immersive-standardisation); [LSi Online](https://www.lsionline.com/standardisation-for-object-based-audio-sought) (older, 2021)
- **Holophonix** and **d&b Soundscape (DS100)** are not named on the ADM-OSC page; d&b appears via En-Bridge. — [ADM-OSC GitHub](https://github.com/immersive-audio-live/ADM-OSC)
- **IEM Plug-in Suite**: GPL-3, JUCE, ambisonics up to 7th order, IEM Graz. — [Arch Linux package](https://www.archlinux.org/packages/extra/x86_64/iempluginsuite); [GitHub tu-studio/IEMPluginSuite](https://github.com/tu-studio/IEMPluginSuite); [AlternativeTo](https://alternativeto.net/software/iem-plug-in-suite/about)
- **SPARTA**: "provided under the GPLv3 License". Built with JUCE + Spatial_Audio_Framework (SAF). Plugins include AmbiENC, AmbiBIN, AmbiDEC, Binauraliser, Panner (VBAP) and 6DoFconv, up to 10th order. Bundled COMPASS / HO-DirAC / HOSIRR / CroPaC components have their own terms. — [github.com/leomccormack/SPARTA](https://github.com/leomccormack/SPARTA); [SoundingFuture](https://soundingfuture.com/tools/sparta)
- **libspatialaudio**: LGPL-2.1-or-later (Debian/EPEL metadata). It renders ADM (BS.2127-1) and IAMF, ambisonics encode/rotate/zoom/decode up to 3rd order, objects, speaker layouts, and binaural with SOFA HRTFs. v0.4 came out in 2025 (Videolabs). — [J-B Kempf blog: libspatialaudio 0.4](https://jbkempf.com/blog/2025/libspatialaudio-0.4); [Debian NEW: libspatialaudio](https://ftp-master.debian.org/new/libspatialaudio_0.4-1.html)
- **Steam Audio**: full SDK source under **Apache-2.0** since 20 Feb 2024 (SDK 4.5.2), commercial use allowed. — [Phoronix](https://phoronix.com/news/Steam-Audio-SDK-Fully-Open); [GameFromScratch](https://gamefromscratch.com/valve-open-source-steam-audio/)
- **Resonance Audio**: open-sourced under **Apache-2.0** in March 2018 (library, engine plugins, VST). — [Google Open Source Blog 2018](https://opensource.googleblog.com/2018/03/resonance-audio-open-source.html) (older)
- **Omnitone** (Web FOA/HOA decoding): Apache-2.0; it powers Resonance Audio for web. — [github.com/GoogleChrome/omnitone](https://github.com/GoogleChrome/omnitone)
- **libear** (BS.2127): Apache-2.0. — [github.com/ebu/libear](https://github.com/ebu/libear)

### Inferences
- Adamson FletcherMachine and d&b En-Bridge are both listed ADM-OSC implementations. One correct ADM-OSC sender, using normalized coordinates and letting the receiver scale, therefore covers a broad set of venue systems without per-vendor code. The `aed` / `xyz` compound messages are worth supporting alongside the single-parameter addresses.
- For a Swift-only, zero-dependency app, the usable references are **specs and permissive code to port**: libear for ITU-conformant ADM gain maths, Steam Audio and Resonance for HRTF/ambisonic binaural ideas. The GPLv3 suites (IEM, SPARTA) are useful as **listening references in a host on a Mac**, not as code sources. LGPL libspatialaudio needs dynamic linking to stay compliant, and dynamic linking of third-party libraries is awkward on iOS. This is an inference; legal confirmation is needed.
- HRTF data: SOFA files (e.g. used by libspatialaudio) are the open interchange format. Datasets carry their own licences (see Gaps).

### Gaps
- Full ADM-OSC v1.0 address table and axis orientation: the repo's `documentation.md` returned 404 at the URL tried, and the AES eLibrary document was not fetched. The authoritative table should be read from the repo's current files.
- Holophonix and d&b Soundscape native ADM-OSC support: not confirmed by a primary source in this pass.
- Licence of the Spatial_Audio_Framework (SAF) itself, separate from the SPARTA plugins: not confirmed (ISC vs GPL UNVERIFIED).
- App Store compatibility of GPLv3 code: I did not fetch an FSF or Apple source in this pass; it is stated above as an inference only.
- HRTF dataset licences (SADIE II, KEMAR/MIT, CIPIC, HUTUBS): not researched.

## 5. Cross-platform later: Android, Windows, Linux, Web

### Takeaway
Every target OS has an OS-level spatializer, but each consumes a different representation. **Android** has a platform `Spatializer` effect (multichannel to binaural, head tracking via BT HID, API 32/33) and IAMF tooling in AOSP. **Windows** has `ISpatialAudioClient` / Windows Sonic (static bed up to 8.1.4.4 plus dynamic objects). **Web** has `PannerNode` HRTF (mono objects) and Omnitone (ambisonics). **Linux** has no OS spatial API; libraries such as libspatialaudio exist. A portable Echoel pipeline should therefore keep its own **open intermediate (ADM-style objects + bed + HOA)** and map that onto each OS renderer, not depend on any one of them.

### Cited Findings
- **Android** [OS-FW: android.media.Spatializer, API 32; head tracking API 33]:
  - Architecture: multichannel audio → mixer thread → post-processing spatializer effect → stereo to the HAL. `SpatializerPoseController` merges and filters head-tracker sensor data, which arrives over HID from the Bluetooth driver.
  - Android 13 lowered latency, unified the app APIs, and exposed head-tracking state through system APIs.
  - Apps can mark streams as not to be spatialized, or as already spatialized.

  — [AOSP: Spatial audio and head tracking](https://source.android.com/docs/core/audio/spatial)
- `Spatializer.isHeadTrackerAvailable()` was added in API 33. State listeners exist from API 32. `isAvailable()` reflects hardware and effect compatibility. — [Android: Spatializer reference](https://developer.android.com/reference/android/media/Spatializer.html)
- AOSP carries `external/iamf_tools`, BSD-3-Clause-Clear, including an android17-release branch. — [AOSP iamf_tools](https://android.googlesource.com/platform/external/iamf_tools/+/refs/heads/android17-release)
- **Windows** [OS-FW: Windows Spatial Sound / `ISpatialAudioClient`]:
  - `ISpatialAudioClient` is part of Windows Sonic and creates streams that emit from 3D positions.
  - Static objects form a channel bed of up to 8.1.4.4 (17 static channels). Dynamic objects can move freely. `GetMaxDynamicObjectCount` returns 0 when spatial sound is unavailable, and `GetNativeStaticObjectTypeMask` returns the bed channels native to the active renderer.

  — [Microsoft Learn: ISpatialAudioClient](https://learn.microsoft.com/en-us/windows/win32/api/spatialaudioclient/nn-spatialaudioclient-ispatialaudioclient); [Microsoft Learn: Spatial Sound](https://learn.microsoft.com/windows/win32/coreaudio/spatial-sound); [Microsoft Learn: render spatial sound using spatial audio objects](https://learn.microsoft.com/en-us/windows/win32/coreaudio/render-spatial-sound-using-spatial-audio-objects)
- Xbox docs: Windows Sonic supports 220 dynamic objects; on Windows the limits scale with format and PC. — [Xbox: Spatial audio overview](https://devdocs.xbox.com/build/console-features/audio/overviews/spatial-audio-overview)
- Dolby Atmos for Windows apps plugs into the same `ISpatialAudioClient` object model: create static/dynamic objects, feed buffers per frame, update positions. — [Dolby developer: Dolby Atmos in Windows applications](https://developer.dolby.com/platforms/windows/dolby-atmos/implementation/)
- **Web** [OPEN: W3C Web Audio API]: `PannerNode.panningModel` is `"equalpower"` (default) or `"HRTF"` (convolution with measured impulse responses from human subjects). It has been Baseline, widely available, since July 2015. — [MDN: PannerNode.panningModel](https://developer.mozilla.org/docs/Web/API/PannerNode/panningModel)
- Omnitone (Apache-2.0) does FOA/HOA binaural decoding on the Web. — [github.com/GoogleChrome/omnitone](https://github.com/GoogleChrome/omnitone)
- **Linux**: libspatialaudio (LGPL-2.1+) is packaged in Debian and EPEL. IEM is packaged for Arch (LV2/VST3/standalone). — [Debian NEW: libspatialaudio](https://ftp-master.debian.org/new/libspatialaudio_0.4-1.html); [Arch: iempluginsuite](https://www.archlinux.org/packages/extra/x86_64/iempluginsuite)

### Inferences
- The common denominator across Apple (`AVAudioEnvironmentNode`), Web (`PannerNode`) and Windows (dynamic objects) is **mono point-source objects with positions**. Android's platform spatializer instead takes **multichannel beds** (e.g. 5.1/7.1) and binauralizes them. A portable design therefore stores **object positions + a channel bed + optional HOA**, the ADM model. It can render to OS object APIs where they exist, pre-render beds where only a bed spatializer exists, and export ADM BWF / IAMF as the open interchange everywhere.
- IAMF is the only immersive delivery format with open reference code, an AOSP presence, YouTube ingest and royalty-free terms at once. That makes it the natural cross-platform counterpart to Apple's APAC.

### Consolidated support matrix (synthesis across all five questions; each row traces to findings above)

| Capability Echoel needs | How | Tag |
|---|---|---|
| Per-track object position metadata (az/el/dist or xyz, gain, width) | Own model, ADM-shaped (BS.2076-3) | [OPEN] |
| Live object out to venue rigs | ADM-OSC v1.0, normalized positions | [OPEN, MIT] |
| Headphone monitoring, mono objects, HRTF | `AVAudioEnvironmentNode` + `.HRTFHQ` | [OS-FW: AVFAudio, iOS 8] |
| Head-tracked monitoring | `isListenerHeadTrackingEnabled` + head-pose entitlement | [OS-FW: AVFAudio, iOS 18] |
| Personalized HRTF | `spatial-audio.profile-access` entitlement | [OS-FW: iOS 18] |
| Bed (5.1 / 7.1.4) and FOA spatial monitoring | `AUSpatialMixer` (as seen behind `AUAudioMix`) | [OS-FW: AudioToolbox; input-format support UNVERIFIED] |
| Game-style geometry/occlusion | PHASE | [OS-FW: PHASE, iOS 15] (not a DAW fit) |
| Ambisonic bus (ACN/SN3D, up to 3rd order for APAC) | Own encoder (VBAP/HOA cores exist in sibling app) | [OPEN] |
| Dolby Atmos ADM BWF master for Apple Music | BW64 writer + ADM XML per Dolby ADM Profile, -18 LKFS / -1 dBTP | Container [OPEN]; Atmos compliance [PROPRIETARY], acceptance UNVERIFIED |
| Open ADM BWF master | BW64 + ADM XML | [OPEN] |
| APAC .mp4 (Apple devices, Vision Pro) | `AVAssetWriter` + APAC keys; bed ≤ 64 ch or HOA ≤ 3rd order | [OS-FW: AVFoundation, encode iOS 26 / decode iOS 17] |
| ASAF production master | No public spec; Resolve/Compressor only | [PROPRIETARY / not feasible for third parties today] |
| IAMF / Eclipsa (YouTube, Android, Samsung) | Spec + BSD reference; encoder would need porting | [OPEN] (encoder path on iOS = gap) |
| Binaural stereo deliverable | Offline render of the monitor path | [OPEN] |
| Multichannel loudness + true peak | BS.1770-5 meter, own implementation | [OPEN] |
| Dolby renderer-exact binaural / DD+JOC / AC-4 encode | Dolby Renderer on a Mac | [PROPRIETARY]; [NOT-ON-DEVICE] |
| MPEG-H / Sony 360RA | Via LA pool + Sony format licence | [PROPRIETARY] |
| Android playback | Platform Spatializer (beds) / IAMF | [OS-FW: API 32/33] |
| Windows playback | `ISpatialAudioClient` (bed 8.1.4.4 + dynamic objects) | [OS-FW: Windows Spatial Sound] |
| Web playback | `PannerNode` HRTF + Omnitone | [OPEN] |

### Gaps
- Android: whether the platform Spatializer accepts **object** or **ambisonic** input (vs channel beds only) was not confirmed. Third-party "spatializer for apps" APIs beyond the effect were not researched.
- Linux: no OS-level spatial-audio API found; PipeWire spatializer modules were not researched.
- Windows: the exact 7.1.4 static channel-mask constant was not confirmed.
- WWDC 2026 / iOS 27 spatial additions: not researched in this pass. Any Apple change since June 2026 is uncovered.

# Immersive video formats an iPhone/iPad multimedia app can produce (2025–2026): Apple first, then cross-platform

Research date: 2026-10-19. Scope: what each immersive format is, what it requires (capture rig vs. rendered content), and how an app could WRITE it from rendered Metal frames plus its own audio using OS codecs only (AVFoundation / VideoToolbox / CoreMedia). Most Apple sources are WWDC 2023–2026 sessions and Apple's developer documentation (doc availability metadata read 2026-10-19). Some third-party pages (developers.meta.com, support.google.com, w3.org) could NOT be fetched from this sandbox (DNS / proxy 403). Facts from those pages are taken from search-result snippets and are marked "(via search snippet)". Anything I could not confirm is marked UNVERIFIED or listed under Gaps.

## 1. Apple MV-HEVC spatial video (stereo layers, metadata, AVAssetWriter)

### Takeaway
Writing stereo MV-HEVC from rendered frames is a documented, supported path: AVAssetWriter + `AVAssetWriterInputTaggedPixelBufferGroupAdaptor` + VideoToolbox MV-HEVC compression keys (iOS 17+). Apple's own reference sample converts a **CG render** (virtual cameras 64 mm apart, 80° FOV) into spatial video, so rendered content, not only camera capture, is a sanctioned source. Spatial metadata (baseline, horizontal FOV, disparity adjustment) is what turns "stereo" into "spatial". One caveat for currency: the tagged-buffer adaptor's documentation now shows an end of availability at iOS 27.0, which I read as deprecated in iOS 27. I did not find its replacement.

### Cited Findings
- MV-HEVC is the visionOS 3D video format and is supported in MPEG-4 and QuickTime. It stores "a single track containing multiple layers for the video, where the track and layers share a frame size", unlike side-by-side, which packs both eyes into one frame. — [Apple sample: Converting side-by-side 3D video to MV-HEVC and spatial video](https://developer.apple.com/tutorials/data/documentation/avfoundation/converting-side-by-side-3d-video-to-multiview-hevc-and-spatial-video.md)
- The required compression-properties dictionary is `kVTCompressionPropertyKey_MVHEVCVideoLayerIDs: [0,1]`, `kVTCompressionPropertyKey_MVHEVCViewIDs: [0,1]`, `kVTCompressionPropertyKey_MVHEVCLeftAndRightViewIDs: [0,1]` (the first element is the left eye), `kVTCompressionPropertyKey_HasLeftStereoEyeView: true` and `kVTCompressionPropertyKey_HasRightStereoEyeView: true`. It is passed with `AVVideoCodecKey: .hevc` and per-eye width/height under `AVVideoCompressionPropertiesKey`. — [same Apple sample](https://developer.apple.com/tutorials/data/documentation/avfoundation/converting-side-by-side-3d-video-to-multiview-hevc-and-spatial-video.md)
- Spatial metadata keys and their encodings: `kVTCompressionPropertyKey_ProjectionKind = kCMFormatDescriptionProjectionKind_Rectilinear`, `kVTCompressionPropertyKey_StereoCameraBaseline` = UInt32 **micrometres** (64 mm → 64000), `kVTCompressionPropertyKey_HorizontalFieldOfView` = UInt32 in **thousandths of a degree** (80° → 80000), `kVTCompressionPropertyKey_HorizontalDisparityAdjustment` = Int32 ×10 000 (+2 % → 200). — [same Apple sample](https://developer.apple.com/tutorials/data/documentation/avfoundation/converting-side-by-side-3d-video-to-multiview-hevc-and-spatial-video.md)
- "Adding spatial metadata to a stereo MV-HEVC video prompts Apple platforms to consider the video as *spatial* instead of just stereo, and opts the video into visual treatments on Apple Vision Pro that can minimize common causes of stereo viewing discomfort." — [same Apple sample](https://developer.apple.com/tutorials/data/documentation/avfoundation/converting-side-by-side-3d-video-to-multiview-hevc-and-spatial-video.md)
- **Rendered content is the reference case.** The sample's default input "is a sequence of renders of a 3D scene, showing an animated hummingbird model… The virtual cameras used to create these renders were positioned 64mm apart with a horizontal field of view of 80 degrees". A +2 % disparity adjustment "positions the nearest object… just behind the front of the window". — [same Apple sample](https://developer.apple.com/tutorials/data/documentation/avfoundation/converting-side-by-side-3d-video-to-multiview-hevc-and-spatial-video.md)
- Frames are appended as `CMTaggedBuffer`s tagged `[.videoLayerID(n), .stereoView(eye)]` through `AVAssetWriterInputTaggedPixelBufferGroupAdaptor.appendTaggedBuffers(_:withPresentationTime:)`. The adaptor's own `pixelBufferPool` supplies the per-eye `CVPixelBuffer`s. — [same Apple sample](https://developer.apple.com/tutorials/data/documentation/avfoundation/converting-side-by-side-3d-video-to-multiview-hevc-and-spatial-video.md)
- `kVTCompressionPropertyKey_MVHEVCVideoLayerIDs` availability: iOS 17.0, iPadOS 17.0, macOS 14.0, visionOS 1.0. — [Apple doc](https://developer.apple.com/tutorials/data/documentation/videotoolbox/kvtcompressionpropertykey_mvhevcvideolayerids.md)
- `AVAssetWriterInputTaggedPixelBufferGroupAdaptor` availability metadata reads "iOS: 17.0.0 - 27.0.0" (likewise iPadOS, macOS 14.0–27.0, visionOS 1.0–27.0). I read this as deprecated in the 2026 OS releases. — [Apple doc](https://developer.apple.com/tutorials/data/documentation/avfoundation/avassetwriterinputtaggedpixelbuffergroupadaptor.md)
- Format references: "Apple HEVC Stereo Video – Interoperability Profile" and "ISO Base Media File Format and Apple HEVC Stereo Video". — [HEVC-Stereo-Video-Profile.pdf](https://developer.apple.com/av-foundation/HEVC-Stereo-Video-Profile.pdf), [Stereo-Video-ISOBMFF-Extensions.pdf](https://developer.apple.com/av-foundation/Stereo-Video-ISOBMFF-Extensions.pdf)
- A developer write-up says visionOS will not treat a file as spatial unless the layer IDs plus horizontal FOV and disparity adjustment are set. — [Finn Voorhees, Reading and writing spatial video with AVFoundation](https://www.finnvoorhees.com/words/reading-and-writing-spatial-video-with-avfoundation) (secondary)
- Reading both eyes back requires `kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs` under `AVVideoDecompressionPropertiesKey`. One developer reported an Intel Mac rejecting the key ("not supported for video codec type hvc1"). — [Apple Developer Forums 745225](https://developer.apple.com/forums/thread/745225), [742971](https://developer.apple.com/forums/thread/742971)
- iPhone's own spatial capture is 1920×1080 at 30 fps in SDR, MV-HEVC with one layer per eye (iPhone 15 Pro and later). — [Apple Final Cut Pro User Guide](https://support.apple.com/guide/final-cut-pro/vere1b07dc3b/mac)
- iPhone 17 Pro is reported to still be limited to 1080p30 for spatial capture, although the same class of chip records 2D at 4K120. — [UploadVR](https://www.uploadvr.com/iphone-17-pro-still-limited-to-1080p-30fps-spatial-video-recording/) (secondary). A blog claiming 4K60 spatial on iPhone 17 Pro Max conflicts with this and looks unreliable.
- Working with MV-HEVC in Compressor, Motion and Final Cut Pro requires an Apple-silicon Mac with macOS 14 or later. — [Apple Compressor guide](https://support.apple.com/en-sg/guide/compressor/aside/cpsr633b8802/4.10/mac/14.6)

### Inferences
- Echoel already renders Metal. Spatial export means rendering the scene twice per frame with two virtual cameras (left and right, a set baseline such as 64 mm, a known horizontal FOV) into two IOSurface-backed `CVPixelBuffer`s from the adaptor pool, then appending them as one tagged group. No codec is shipped: VideoToolbox does the MV-HEVC encode. This fits the "OS codecs only" rule.
- The baseline/FOV/disparity values come straight from the virtual camera, so a renderer can supply them exactly rather than estimating them. For generative abstract visuals the "baseline" is a creative choice. A small baseline and conservative disparity are the comfort-safe default (the Apple sample uses +2 %).
- Because the tagged-buffer adaptor shows an end of availability at iOS 27, new code should look for its replacement in the iOS 27 SDK before committing to it. On an iOS 18 deployment floor the adaptor itself is still available.
- Apple's own spatial capture stays at 1080p30 per eye even on 2025 iPhones. That suggests real-time stereo encode at larger sizes is constrained on phone hardware. Treat a 4K-per-eye **real-time** stereo export on iPhone as unproven; an **offline** (non-real-time) render-and-encode is the safer design.

### Gaps
- Which Apple chips have a hardware MV-HEVC **encoder** path, as opposed to software or GPU, and the maximum encodable MV-HEVC resolution and frame rate on iPhone/iPad: no Apple statement found.
- The minimum OS for the spatial-metadata keys (`StereoCameraBaseline`, `HorizontalFieldOfView`, `HorizontalDisparityAdjustment`): not fetched. The sample is tagged macOS 15 / Xcode 16, which suggests iOS 18, but this is UNVERIFIED.
- The iOS 27 successor to `AVAssetWriterInputTaggedPixelBufferGroupAdaptor`: the guessed doc URL returned 404. UNVERIFIED.

## 2. Apple Projected Media Profile (APMP, WWDC25): 180°, 360°, wide-FOV

### Takeaway
APMP is Apple's QuickTime/MP4 signalling for 180° (half-equirectangular), 360° (equirectangular) and wide-FOV (ParametricImmersive) video, in mono or stereo. It lives in new `vexu` boxes and plays natively on visionOS 26. The VideoToolbox projection keys needed to WRITE it exist from iOS 18 / macOS 15 / visionOS 2. A renderer can therefore tag an equirectangular Metal output at write time with one compression property.

### Cited Findings
- Projection kinds: half-equirectangular, where "the X coordinate within the video frame represents the range from negative 90 to positive 90 degrees"; equirectangular, where "the horizontal axis maps longitude from negative to positive 180 degrees, while the vertical axis maps latitude from negative to positive 90 degrees"; and ParametricImmersive, which "represents the intrinsics and lens distortion parameters associated with wide-angle or fisheye lenses". AppleImmersiveVideo is a separate projection kind. — [WWDC25 session 297, Learn about the Apple Projected Media Profile](https://developer.apple.com/videos/play/wwdc2025/297/)
- Half-equirectangular frames have a square aspect ratio. — [WWDC25 297 (search summary of Apple page)](https://developer.apple.com/videos/play/wwdc2025/297/)
- Signalling lives in boxes inside Video Extended Usage (`vexu`): a stereo view box (required for stereoscopic 180), a projection box, a lens collection box (for ParametricImmersive) and a view packing box (side-by-side or over-under). Spec: "QuickTime and ISO Base Media File Formats and Spatial and Immersive Media". — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/); [spec PDF](https://developer.apple.com/av-foundation/Stereo-Video-ISOBMFF-Extensions.pdf)
- Writing: "I'm using the CompressionPropertyKey kind to specify the equirectangular projection kind. Compression properties are passed to AVAssetWriterInput using the outputSettings dictionary property AVVideoCompressionPropertiesKey." — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- `kVTCompressionPropertyKey_ProjectionKind` is available on iOS 18.0, iPadOS 18.0, macOS 15.0 and visionOS 2.0. Values: `kVTProjectionKind_Rectilinear`, `_Equirectangular`, `_HalfEquirectangular`, `_ParametricImmersive`. "The value will be set on the format description (`kCMFormatDescriptionExtension_ProjectionKind`)". — [Apple doc](https://developer.apple.com/tutorials/data/documentation/videotoolbox/kvtcompressionpropertykey_projectionkind.md)
- `kCMFormatDescriptionProjectionKind_HalfEquirectangular` is available on iOS 18.0, iPadOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0 and watchOS 11.0. — [Apple doc](https://developer.apple.com/tutorials/data/documentation/coremedia/kcmformatdescriptionprojectionkind_halfequirectangular.md)
- Stereo can be frame-packed (side-by-side or over-under) or MV-HEVC. Apple's recommended path is to edit frame-packed and then "Encode and publish using the multiview HEVC or MV-HEVC codec for efficient delivery and playback on visionOS." — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- Publishing recommendations for visionOS: HEVC Main or Main 10, 4:2:0; Rec.709 or P3-D65; 7680×3840 at 10-bit for monoscopic; 4320×4320 per eye for stereoscopic; "30 fps recommended for 10-bit monoscopic 8K or stereoscopic 4K"; "we recommend not exceeding 150 megabits per second peak". — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- Conversion of legacy Google spherical metadata (V1/V2): pass `AVURLAssetShouldParseExternalSphericalTagsKey: true` and check the `.convertedFromExternalSphericalTags` format-description extension. The macOS `avconvert` utility can also convert. Wide-FOV camera files (GoPro, Insta360) are converted with `ParametricImmersiveAssetInfo` (ImmersiveMediaSupport). — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- Identification: `AVAssetPlaybackAssistant.playbackConfigurationOptions` contains `.nonRectilinearProjection` (APMP and AIV) and `.appleImmersiveVideo` (AIV only). — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- HLS supports APMP: `REQ-VIDEO-LAYOUT` signals stereo and half-equirectangular, and the map segment must carry the format-description extension. AVQT now measures APMP 180/360. — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- Final Cut Pro reads and writes APMP for 360 formats. Canon EOS VR Utility and GoPro Player were announced to export APMP. — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- visionOS 26 playback: "In visionOS 26, all applications already implementing Quick Look APIs, will automatically support immersive media profiles". AVKit (`AVPlayerViewController` + `AVExperienceController`) and RealityKit `VideoPlayerComponent` support the same profiles. Progressive mode is preferred over full for APMP and AIV. — [WWDC25 session 296, Support immersive video playback in visionOS apps](https://developer.apple.com/videos/play/wwdc2025/296/)

### Inferences
- For Echoel's generative visuals, **mono 360 equirectangular APMP is the lowest-friction immersive export.** Render a cube map (6 faces) or directly per-pixel equirectangular in a Metal compute pass. Append via a normal `AVAssetWriterInputPixelBufferAdaptor` with HEVC plus `kVTCompressionPropertyKey_ProjectionKind = kVTProjectionKind_Equirectangular`. This is one key on top of a normal HEVC writer, and it is available on the app's iOS 18 floor.
- **180° stereo** follows the same path with half-equirectangular plus either frame-packing (view packing box) or MV-HEVC layers (section 1). It costs two renders per frame.
- Generative content has no lens, so ParametricImmersive (lens intrinsics and distortion) is a capture-side profile and not needed for rendered output.
- 7680×3840 mono or 4320×4320 per eye are Apple's *playback* targets for Vision Pro. Encoding at that size on iPhone/iPad is a separate, unproven question (section 6).

### Gaps
- Whether iOS/iPadOS 26 **play** APMP with projection-aware rendering (Photos, AVPlayer) or only as flat frames: no source found. Sessions 297 and 296 address visionOS only.
- Availability of `kVTProjectionKind_ParametricImmersive` and of the view-packing compression key on iOS: not checked.
- The four-character codes of the new `vexu` child boxes: the session does not state them. They are in the spec PDF, which I did not open.

## 3. Apple Immersive Video (AIV), `.aivu` and ImmersiveMediaSupport

### Takeaway
AIV is Apple's top-tier, **camera-calibration-driven** format: MV-HEVC 4320×4320 per eye, 90 fps, P3-D65-PQ, with per-frame lens calibration metadata and APAC audio. The authoring framework (ImmersiveMediaSupport) is public but available on **macOS 26 and visionOS 26 only**, not iOS/iPadOS per Apple's doc metadata. Apple's materials describe AIV in terms of factory-calibrated immersive cameras such as the Blackmagic URSA Cine Immersive. Whether purely rendered content can be valid AIV is not stated anywhere I found.

### Cited Findings
- "Apple Immersive Video is the highest quality immersive experience for video playback on Apple Vision Pro… it requires specific cameras that are capable of capturing this high-fidelity video, such as the Blackmagic URSA Cine Immersive". Cameras are "uniquely calibrated from the factory… this calibration information is included with every video file". — [WWDC25 session 403, Learn about Apple Immersive Video technologies](https://developer.apple.com/videos/play/wwdc2025/403/)
- Recommended rendering spec: "MV-HEVC at a recommended resolution of 4320 by 4320 per eye, 90 frames per second, with a P3-D65-PQ color space." — [WWDC25 403](https://developer.apple.com/videos/play/wwdc2025/403/)
- ImmersiveMediaSupport availability: macOS 26.0 and visionOS 26.0 only. "Immersive Media Support enables you to create custom workflows for processing Apple Immersive Video (AIV). Use it to read and write AIV-specific metadata and enable previewing content in editorial workflows." Types include `VenueDescriptor`, `ImmersiveCamera`, `ImmersiveCameraCalibration`, `ImmersiveDynamicMask`, `PresentationCommand` (Fade, FadeEnvironment, SetCamera, ShotFlop, ShotFlip), `PresentationDescriptor`, `ParametricImmersiveAssetInfo`, `ImmersiveMediaRemotePreviewSender`/`Receiver`, `ImmersivePreviewRenderer` and `AIVUValidator`. — [Apple doc: Immersive Media Support](https://developer.apple.com/tutorials/data/documentation/immersivemediasupport.md)
- AIVU: "a container of your output video with the PresentationDescriptor muxed into it and has the VenueDescriptor as metadata included within it". It plays from Files/Quick Look on visionOS and is "the best way to easily ingest or share your content". Writing requires projection kind AppleImmersiveVideo, plus VenueDescriptor (AIME data, `.quickTimeMetadataAIMEData`) and timed PresentationDescriptor items (`.quickTimeMetadataPresentationImmersiveMedia`) written with AVAssetWriter. Validation uses `AIVUValidator.validate(url:)`. — [WWDC25 403](https://developer.apple.com/videos/play/wwdc2025/403/)
- The authoring sample's inputs are "An Apple Immersive Video MV-HEVC video file without any necessary metadata", an AIME calibration file, **or alternatively** "An optional USDZ file to use for camera calibration instead of an AIME file" together with "a dynamic mask JSON data file". The output is an AIVU. The sample runs on macOS 26 / Xcode 26. — [Apple sample: Authoring Apple Immersive Video](https://developer.apple.com/documentation/immersivemediasupport/authoring-apple-immersive-video.md)
- HLS publishing: average bandwidth 25–100 Mbps and peak 50–150 Mbps (the transcript wording; the page summary conflicts with "25–150 Mbps average"). Multivariant playlist version 12+, venue description data ID pointing to the AIME file, content type fully immersive, stereo layout with AIV projection, and APAC audio. — [WWDC25 403](https://developer.apple.com/videos/play/wwdc2025/403/)
- Audio: ASAF (Apple Spatial Audio Format) is the production format (PCM plus metadata in Broadcast Wave). "APAC is required for any Apple immersive video experience". The tools are Apple Pro Tools plugins or DaVinci Resolve Studio. — [WWDC25 403](https://developer.apple.com/videos/play/wwdc2025/403/)
- visionOS 27 (WWDC26): "Apple Immersive Video supports both video-on-demand and live broadcast streaming in visionOS". "Video is captured and streamed at 90 frames per second with a near-human visual acuity greater than 100 megapixels per frame". IMS adds "camera presentation override commands, an ImmersivePreviewRenderer API, and wide-aspect-ratio portals". Static foveation can be applied before encode for streamable AIV. An ASAF Production Suite is downloadable. Related session: "Build live production tools for Apple Immersive Video". — [WWDC26 session 287 (visionOS 27)](https://developer.apple.com/videos/play/wwdc2026/287/); [WWDC26 338](https://developer.apple.com/videos/play/wwdc2026/338)
- A secondary source (CineD) claims the framework extends to iPadOS/iOS. This conflicts with Apple's doc metadata (macOS 26 / visionOS 26 only) and is UNVERIFIED. — [CineD](https://www.cined.com/?p=428330)

### Inferences
- An iPhone/iPad app **cannot author AIVU on-device** with Apple's framework today, because ImmersiveMediaSupport is not on iOS. AIV is a Mac post-production target at best.
- AIV's value is metadata-driven **lens calibration** for real stereo camera rigs. A generative renderer has no lens to calibrate. The USDZ + dynamic-mask calibration route suggests a calibration can be described as geometry, which might in principle let a synthetic "camera" be described. Whether such a file passes `AIVUValidator`, and whether Apple permits CG content as "Apple Immersive Video", is UNVERIFIED. For rendered content, APMP 180/360 (section 2) is the sanctioned and simpler target.
- 4320×4320 per eye at 90 fps far exceeds what iPhone records for spatial video (1080p30 per eye). AIV is not a realistic real-time iPhone export.

### Gaps
- Any Apple statement on whether rendered/CG content may be AIV, and any branding or licensing conditions on the "Apple Immersive Video" name: not found.
- What "Apple Immersive Video Utility" is: the app named in the task was not described in sessions 403 or 287, and I did not find its page. UNVERIFIED.
- AIV playback on iOS/macOS (as flat or reprojected video): not stated. The sessions target Vision Pro.

## 4. Live immersive rendering instead of encoding: CompositorServices, RealityKit, and what an iPad app could stream to Vision Pro

### Takeaway
Live stereo rendering into Vision Pro needs either a native visionOS app (CompositorServices `CompositorLayer` Metal loop or RealityKit) or, since macOS 26, a **Mac** app using `RemoteImmersiveSpace`. That API is macOS-only per Apple's docs, so an iPad/iPhone app has no equivalent remote-immersive API. From iPad, the documented path into Vision Pro is ordinary 2D AirPlay mirroring to Vision Pro's AirPlay Receiver.

### Cited Findings
- `RemoteImmersiveSpace` availability: **macOS 26.0 only**. "A scene that presents its content in an unbounded space on a remote device… compositor content that your macOS app presents on a user's chosen visionOS device". Content is a `CompositorLayer` running a Metal render loop. It supports `.full` immersion style, `remoteDeviceIdentifier` for an `ARKitSession` on the headset, and `supportsRemoteScenes` to gate the button. Only one immersive space can be open at a time. — [Apple doc: RemoteImmersiveSpace](https://developer.apple.com/tutorials/data/documentation/swiftui/remoteimmersivespace.md)
- Press coverage: macOS Tahoe 26 apps can render 3D/immersive scenes directly on Vision Pro, and CompositorServices comes to macOS 26. — [9to5Mac](https://9to5mac.com/2025/06/12/macos-apps-can-now-render-3d-scenes-directly-on-apple-vision-pro/), [UploadVR](https://www.uploadvr.com/macos-spatial-rendering-announced-wwdc25/) (secondary)
- A forum report says the device picker failed with no devices found on macOS 26.4 beta / visionOS 26.3.1, with no resolution shown. — [Apple Developer Forums 818404](https://developer.apple.com/forums/thread/818404)
- Vision Pro supports AirPlay Receiver: "devices can also mirror their screen or view to your Apple Vision Pro when AirPlay Receiver is in use". — [Apple Vision Pro User Guide](https://support.apple.com/en-om/guide/apple-vision-pro/tanf4ca9ada2/visionos)
- visionOS 26.x release notes mention a Vision Pro app on iPhone/iPad that can turn on AirPlay to view Vision Pro experiences, and same-room shared experiences. Version attribution varies between sources (26.1 vs 26.4/26.6). — [Apple: About visionOS 26 Updates](https://support.apple.com/123024); [MacTrast](https://www.mactrast.com/2025/11/apple-releases-visionos-26-1-brings-vision-pro-app-for-ipad/)
- "Foveated Streaming launched in visionOS 26.4… compresses video based on where a person is looking… The streaming protocol is powered by NVIDIA CloudXR." The Spatial Preview framework (macOS) previews spatial photos, AIV and 3D content on Vision Pro. — [WWDC26 287](https://developer.apple.com/videos/play/wwdc2026/287/); [WWDC26 286 foveated streaming](https://developer.apple.com/videos/play/wwdc2026/286); [WWDC26 282 Spatial Preview](https://developer.apple.com/videos/play/wwdc2026/282)
- In a visionOS app, RealityKit `VideoPlayerComponent` plays all immersive profiles (spatial, APMP, AIV) with portal, progressive and full modes. — [WWDC25 296](https://developer.apple.com/videos/play/wwdc2025/296/)

### Inferences
- For a music app that is "iPhone-first", there are three realistic Vision Pro routes. (a) A file export (APMP/MV-HEVC) that the user opens in Vision Pro (Files/Photos/Quick Look). (b) Plain AirPlay mirroring of the 2D visual to Vision Pro, which is not immersive. (c) A separate visionOS target, or a Mac companion using `RemoteImmersiveSpace`, that renders the same visual live from the music app's control data. That control data could be the OSC / `MusicalFrame` stream Echoel already sends, rather than video.
- Route (c) streams **parameters, not pixels**, which matches Echoel's existing OSC / ADM-OSC egress and avoids encoding entirely. It requires a new target (visionOS or macOS), which is a scope decision for the founder.

### Gaps
- Whether SharePlay can carry a live immersive visual from iPad to Vision Pro, and whether AirPlay from iPhone to Vision Pro can carry spatial/immersive video (rather than 2D mirroring): not found.
- Any iPadOS equivalent of `RemoteImmersiveSpace`: none in the docs I read (macOS 26 only). This absence is from doc metadata, not an explicit statement.

## 5. Cross-platform: VR180/360 spatial-media metadata, YouTube, Meta Quest, fulldome, NDI, Syphon/Spout

### Takeaway
Outside Apple, 360/180 video is signalled with Google's Spherical Video V2 boxes (`st3d`/`sv3d`) and ambisonic audio with the `SA3D` box. These differ from Apple's APMP `vexu` boxes, so one file needs both sets of metadata, or there must be two exports. YouTube wants AmbiX FOA (ACN/SN3D, 48 kHz). Quest prefers HEVC/AV1 with top-bottom stereo, and MV-HEVC is now accepted with an AV1 SBS fallback. Fulldome is a square azimuthal-equidistant fisheye, typically 4096² at 30 fps. NDI's free SDK is royalty-free with an attribution link. Syphon/Spout are same-machine macOS/Windows only, with no iOS.

### Cited Findings
**Google Spherical Video V2 (MP4/ISOBMFF and WebM)**
- `st3d` (stereo_mode: 0 mono, 1 top-bottom, 2 left-right, 3 stereo-custom, 4 right-left) and `sv3d` (container) sit in the VisualSampleEntry, `st3d` before `sv3d`. Children: `svhd` (metadata_source string), `proj` → `prhd` (yaw/pitch/roll in 16.16 fixed point) plus one of `equi` (four 0.32 fixed-point `projection_bounds` crops: top, bottom, left, right), `cbmp` (cubemap 3×2) or `mshp` (mesh). If both V1 and V2 are present, "V2 taking priority when they differ". WebM uses a `Projection` element (ID 0x7670). — [google/spatial-media: Spherical Video V2 RFC](https://github.com/google/spatial-media/blob/master/docs/spherical-video-v2-rfc.md)

**Google Spatial Audio RFC (`SA3D`)**
- `SA3D` sits in the sound sample entry (`mp4a`, `lpcm`, `sowt`). Fields: version 0, `head_locked_stereo` flag, ambisonic_type 0 = periphonic, ambisonic_order (1 → 4 channels), channel_ordering 0 = ACN, normalization 0 = SN3D, num_channels, channel_map. Example: a 6-channel W,Y,Z,X,L,R head-locked layout uses map 0–5. — [google/spatial-media: Spatial Audio RFC](https://github.com/google/spatial-media/blob/master/docs/spatial-audio-rfc.md)

**YouTube**
- Spatial audio: AmbiX (ACN, SN3D). Two formats: FOA, and FOA + head-locked stereo. Only one audio track per file. FOA = 4 channels W,Y,Z,X at 48 kHz, AAC (MP4/MOV) at 256 kbps minimum, or Opus in MP4 with channel mapping family 2 at 512 kbps minimum. Head-locked = 6 channels W,Y,Z,X,L,R, Opus at 768 kbps minimum. The metadata tool must be run before upload. (via search snippet) — [YouTube Help: Use spatial audio in 360-degree and VR videos](https://support.google.com/youtube/answer/6395969)
- Conflict: a third-party blog (updated 2024) says YouTube dropped 4+2 head-locked support and that spatial audio works only on non-Apple hardware. This contradicts the official page. — [vrtonung.de](https://www.vrtonung.de/en/?p=12039)
- 180/360 upload: the file must be modified "with an app like Adobe Premiere (2019 or higher) or script before uploading". (via search snippet) — [YouTube Help: Upload 180- or 360-degree videos](https://support.google.com/youtube/answer/6178631)

**Meta Quest (Meta Horizon developer media requirements; via search snippets, page not fetchable here)**
- 2D streaming codecs: AV1 (Quest 3 and later only), HEVC, VP9, AVC. For 180/360 stereo, H.265 or AV1, Top/Bottom; "MV-HEVC with AV1 SBS fallback stream. If using MV-HEVC: HDR10+ or Dolby Vision Profile 20". Bitrate "typically… higher than 35 mbps". For 180 2D, aim for 30–60 pixels per degree, "Max 5760x5760 / 60fps (hardware decode limit)". 180 content at 48–60 fps "to mitigate stutter and judder". SBS realistic maximum 7680×3840 / 60 fps. — [Meta: Media requirements](https://developers.meta.com/horizon/documentation/android-apps/media-requirements)
- A third-party guide gives 25–60 Mbps targets and 3840×3840 (stereo) / 3840×1920 (mono) minimums. — [Bitmovin](https://bitmovin.com/best-encoding-settings-meta-vr-360-headsets/) (secondary)

**Fulldome / planetarium**
- IMERSA: "A Dome-Master is a 2-D representation of the 3-D hemispherical dome screen"; "Only circular dome masters (i.e., a square source frame) are acceptable"; azimuthal equidistant fisheye with the centre as zenith and the circle edge as horizon. — [IMERSA guidelines](https://imersa.org/guidelines)
- NOIRLab: Fulldome 4K master 4096×4096 at 30 fps, 8K master 8192×8192 at 30 fps. — [NOIRLab video formats](https://noirlab.edu/public/videoformats)
- Melbourne Planetarium: standard playback 30 fps, 60 fps accepted at 4K/2K, HEVC at 60 Mbit/s (30 fps) or 120 Mbit/s (60 fps). — [Museums Victoria: content delivery specifications](https://museumsvictoria.com.au/scienceworks/visiting/melbourne-planetarium/content-delivery-specifications)
- Real-time dome servers exist at 8192² / 60 Hz (VIOSO). Zeiss: 4K systems "with an effective 12 to 15 million pixels are widely used as standard". — [VIOSO Fulldome Solutions PDF](https://vioso.com/wp-content/uploads/VIOSO-Fulldome-Solutions-22.pdf); [ZEISS](https://www.zeiss.com/planetariums/us/products/planetarium-technique/fulldome-systems/standard-video-projectors.html)
- Practitioner notes on an 8K fulldome pipeline. — [Paul Bourke](https://paulbourke.net/dome/8K/)

**NDI (stage / projection-mapping video over IP)**
- Free NDI SDK: "you may use the NDI library within free or commercial Products… without paying any license fees". You must "provide a link to ndi.video in a location close to all locations where NDI is used/selected within the product, on your website, and in its documentation". NDI tools may not be redistributed. The NDI Advanced SDK is royalty-based and needs a vendor ID (licensing@ndi.video). Using "NDI" in a product name needs the brand guidelines. The binding License Agreement ships in the SDK folder and I did not read it. — [NDI docs: Licensing](https://docs.ndi.video/docs/sdk/licensing); [NDI Advanced SDK licensing](https://docs.ndi.video/all/developing-with-ndi/advanced-sdk/licensing)

**Syphon / Spout**
- Syphon (macOS) and Spout (Windows) share GPU textures between apps on the **same computer**. Cross-machine needs bridges such as tcpSyphon/tcpSpout. — [HeavyM help](https://help.heavym.net/hc/articles/360021470439), [Resolume forum](https://resolume.com/forum/viewtopic.php?p=58977)
- Spout2 is BSD-2-Clause / Simplified BSD (© Lynn Jarvis). — [Spout2 GitHub releases](https://github.com/leadedge/Spout2/releases), [MADRIX legal info](https://help.madrix.com/m5/html/madrix/hidh_legalinformation_spout.html)

### Inferences
- **The Apple and Google metadata sets are disjoint.** AVFoundation writes APMP (`vexu`) natively. I found no evidence that it writes Google `st3d`/`sv3d` or `SA3D`. A YouTube/Quest-compatible export would need a post-write box-injection step: rewriting MP4 sample-entry boxes, which is container work, not a codec, so it does not violate "no own codec". Alternatively, the user runs Google's metadata injector. A second, platform-specific export preset is cleaner than one file that tries to satisfy both.
- VR180 in Spherical V2 is expressed as `equi` with left/right `projection_bounds` cropping a quarter of the sphere off each side, inferred from the bounds definition. The RFC does not name VR180, so check against Google's VR180 docs before implementing.
- Fulldome is the closest match to Echoel's "Installation · Event · Theater" positioning. It is mono, square, 30 fps standard, and renderable in one Metal pass (cube map → azimuthal-equidistant fisheye). 4096×4096 ≈ 16.8 MP per frame. My understanding of the HEVC spec is that this exceeds the Level 5.x picture-size cap and needs a Level 6-class encoder; I did not confirm this in this session, so it is UNVERIFIED. Whether iPhone/iPad VideoToolbox accepts it is a device test.
- NDI would be Echoel's first external binary dependency. Its licence is compatible with a commercial app if the attribution link is shown, but adding it is a dependency/Council decision under project rules. Syphon/Spout are irrelevant on iOS: they are same-machine desktop APIs.

### Gaps
- YouTube's current recommended resolutions and frame rates for 360/VR180 uploads (the help page could not be fetched): not confirmed.
- Whether YouTube/Quest read Apple APMP metadata directly: not found.
- NDI SDK iOS support and App Store constraints (background, network permissions): not confirmed.
- Syphon framework licence: not confirmed (the result only covered a BSD wrapper).
- Meta Quest local-file (sideloaded) player metadata requirements versus streaming apps: Meta's page targets streaming services.

## 6. Spatial audio attached to immersive video

### Takeaway
On Apple, the delivery codec for immersive video audio is **APAC**: it is required for AIV, recommended for APMP, and encodable 1st–3rd order ambisonics via AVAssetWriter on iOS/macOS/visionOS. Cross-platform (YouTube/Quest), the established form is FOA AmbiX (ACN/SN3D) in AAC or Opus, tagged with Google's `SA3D` box. These are different codecs and need different files.

### Cited Findings
- "Apple Positional Audio Codec is a high-efficiency spatial audio codec and is recommended for encoding spatial audio including ambisonics with APMP video". Orders: 1st = 4 channels, 2nd = 9, 3rd = 16. The built-in APAC encoder on iOS, macOS and visionOS (via AVAssetWriter) supports 1st–3rd order. Decoding is available on all Apple platforms except watchOS. Bitrates range from 384 kbps (1st order) to 768 kbps (3rd order). APAC can be segmented for HLS. — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- "APAC is required for any Apple immersive video experience". APAC supports channels, objects, HOA, dialogue and binaural, at bitrates "as low as 64 kilobits per second". ASAF is the production format. — [WWDC25 403](https://developer.apple.com/videos/play/wwdc2025/403/)
- Apple's APAC spec: the encoder handles scene-based and channel-based input, with ambisonics up to 3rd order. The input channel layout must be configured. The encoder embeds loudness and DRC metadata in the bitstream. — [Apple Positional Audio Codec PDF](https://developer.apple.com/av-foundation/Apple-Positional-Audio-Codec.pdf)
- iOS 26: apps using AVAssetWriter can record Spatial Audio as FOA, 4 channels, ACN/SN3D, using two writer inputs (stereo and FOA) plus `AVCaptureSpatialAudioMetadataSampleGenerator` for the timed metadata track. — [WWDC25 session 251 (transcript index)](https://nonstrict.eu/wwdcindex/wwdc2025/251/) (secondary index of Apple's transcript)
- FFmpeg reports APAC as an unknown codec, so decoding outside Apple is hard. — [fourMs/apac-decode](https://github.com/fourMs/apac-decode)
- A developer forum thread (late 2025) reports scant ASAF/APAC documentation and no code examples. — [Apple Developer Forums 801541](https://developer.apple.com/forums/thread/801541)
- YouTube FOA/head-locked requirements and the `SA3D` box: see section 5. — [YouTube Help 6395969](https://support.google.com/youtube/answer/6395969); [Spatial Audio RFC](https://github.com/google/spatial-media/blob/master/docs/spatial-audio-rfc.md)

### Inferences
- An app that already produces its own audio can write an ambisonic bed (FOA, 4 channels ACN/SN3D) as APAC through AVAssetWriter for Apple targets. The same PCM can be written as 4-channel AAC with an injected `SA3D` box for YouTube. Both use OS encoders only. This presumes the app has an ambisonic encoder of its own. The project context lists an ambisonics encode core as present but unwired, so this is a build item, not a capability.
- APAC at 384 kbps for FOA is small next to the video (≤150 Mbps), so audio does not change file-size budgets.

### Gaps
- Minimum iOS version for APAC **encoding** in AVAssetWriter, and the exact `AudioFormatID` / settings dictionary: no code sample found. The iOS 26 capture session is the earliest explicit mention; it may be earlier (UNVERIFIED).
- Dolby Atmos in immersive video: not researched successfully. No source found on whether iOS can *encode* Atmos (E-AC-3 JOC) via AVAssetWriter, or on Quest/YouTube Atmos acceptance. Treat Atmos as UNVERIFIED and likely licence-bound.
- Quest's accepted spatial-audio formats for local or streamed 360 files: not found.

## 7. Practical limits on iPhone/iPad: encode throughput, thermal limits, file sizes, MV-HEVC hardware

### Takeaway
No Apple source states MV-HEVC encoder throughput or chip support. The strongest evidence is indirect: Apple's own spatial capture remains 1080p30 per eye even on iPhone 17 Pro, while Apple's *playback* targets for Vision Pro are 4320² per eye (APMP stereo) to 4320² per eye at 90 fps (AIV). File sizes follow from Apple's bitrate caps, roughly 1.1 GB per minute at the 150 Mbps peak.

### Cited Findings
- iPhone spatial capture is 1920×1080, 30 fps, SDR, MV-HEVC (iPhone 15 Pro and later). — [Apple Final Cut Pro User Guide](https://support.apple.com/guide/final-cut-pro/vere1b07dc3b/mac)
- iPhone 17 Pro is still 1080p30 spatial while 2D reaches 4K120. — [UploadVR](https://www.uploadvr.com/iphone-17-pro-still-limited-to-1080p-30fps-spatial-video-recording/) (secondary)
- APMP peak bitrate recommendation is ≤150 Mbps; resolution targets are 7680×3840 mono and 4320×4320 per eye stereo, 30 fps. — [WWDC25 297](https://developer.apple.com/videos/play/wwdc2025/297/)
- AIV: 4320×4320 per eye, 90 fps, 50–150 Mbps peak for HLS tiers. — [WWDC25 403](https://developer.apple.com/videos/play/wwdc2025/403/)
- Quest hardware decode limit: 5760×5760 / 60 fps (via search snippet). — [Meta: Media requirements](https://developers.meta.com/horizon/documentation/android-apps/media-requirements)
- MV-HEVC tooling on Mac requires Apple silicon. — [Apple Compressor guide](https://support.apple.com/en-sg/guide/compressor/aside/cpsr633b8802/4.10/mac/14.6)

### Inferences
- File-size arithmetic from the cited bitrates: 150 Mbps ≈ 18.75 MB/s ≈ 1.1 GB/min ≈ 67 GB/h. 60 Mbps (dome HEVC at 30 fps) ≈ 450 MB/min. 35 Mbps (Quest floor) ≈ 260 MB/min.
- Design implication for Echoel: export immersive formats **offline**. Render the visual deterministically from a recorded control/automation timeline at whatever speed the GPU and encoder sustain, rather than encoding live during a performance. Live encode during a performance competes with the audio thread's thermal and CPU budget, and the app's own law ties quality to thermal state. This is an inference, not measured.
- The capability check before any export should be `AVAssetWriter.canApply(outputSettings:forMediaType:)` (used in Apple's sample) at the target resolution on the actual device. That is the only reliable answer to "does this iPhone encode X".

### Gaps
- Measured encode throughput (frames per second) for 4K/8K mono HEVC, or for stereo MV-HEVC, on A17 Pro / A18 Pro / A19 Pro / M-series iPads: no source found.
- Thermal throttling curves for sustained HEVC encode on iPhone/iPad: no source found.
- HEVC level and tier ceilings of the iPhone/iPad hardware encoder (for example whether 4096² or 7680×3840 is accepted): no Apple source found.

## 8. Accessibility and safety for immersive visuals

### Takeaway
WCAG 2.3.1's "three flashes" rule and its thresholds are defined in **degrees of visual field** (25 % of any 10° field). The familiar 341×256-pixel shortcut assumes a desktop monitor, so in a headset or dome the test area must be computed in visual angle. Apple's visionOS HIG adds motion-comfort rules: keep peripheral motion low, use gentle, user-initiated transitions, and provide a ground plane. visionOS 26 automatically reduces immersion on high-motion APMP content in Quick Look, AVKit and RealityKit.

### Cited Findings
- WCAG thresholds: no more than three general and/or red flashes in any one second, or combined area of concurrent flashes within 25 % of any 10° visual field (≈0.006 sr). A general flash is a pair of opposing luminance changes of at least 10 % of maximum relative luminance where the darker image is below 0.80. A red flash involves a saturated red. 341×256 px is the 10° test area at 1024×768 for a 15–17″ screen viewed at 22–26″. (via search snippets of W3C pages; direct fetch failed) — [W3C WCAG 2.2 Understanding 2.3.1](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html); [W3C WCAG 3 draft: No flashing over threshold](https://www.w3.org/WAI/WCAG3/informative/animation-and-movement/avoid-physical-harm/no-flashing-over-threshold/)
- WCAG notes these thresholds were "originally based on guidelines for the broadcasting industry as adapted for desktop monitors". People are more sensitive to red flashing, so there is a separate red test. — [W3C WCAG 2.2 Understanding 2.3.1](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) (via search snippet)
- The WCAG 3 draft notes that CSS pixel density (96 ppi) makes the pixel estimate less conservative than the 75–85 ppi basis of the thresholds. — [W3C WCAG 3 draft](https://www.w3.org/WAI/WCAG3/informative/animation-and-movement/avoid-physical-harm/no-flashing-over-threshold/) (draft)
- A 2024 comparison (Jordan & Vanderheiden) of five photosensitivity guidelines, including ITU-R BT.1702, finds all address flash magnitude, rate, area and saturated red "but with varying thresholds and measurement approaches". — [IEEE paper record](https://www.infona.pl/resource/bwmeta1.element.ieee-art-000007148104); [gap-analysis summary](https://a11y-paradise.onrender.com/reviews/69cacf6cc3a0012d6bd9135c) (secondary)
- Apple HIG, Immersive experiences: "Always avoid displaying too much movement near the edges of a person's field of view." "Keep animation subtle." "To help immerse people in a primary task like watching a video, avoid displaying a lot of movement or high-contrast details in your environment." "Design smooth, predictable transitions when changing immersion… Avoid sudden, jarring transitions." "Let people choose when to enter or exit a more immersive experience." "Always provide a ground plane mesh so people don't feel like they're floating." An approximately 1.5 m boundary applies to progressive/full styles. — [Apple HIG: Immersive experiences](https://developer.apple.com/design/human-interface-guidelines/immersive-experiences)
- visionOS 26: "motion detection is now supported for Apple Projected Media Profile content. Now, QuickLook and AVKit, detect high motion during playback and automatically reduce immersion level". RealityKit emits `VideoComfortMitigationDidOccur` (`.reduceImmersion`, `.play`, `.pause`). There is no mitigation in portal mode, and reduced immersion applies only in progressive mode. — [WWDC25 296](https://developer.apple.com/videos/play/wwdc2025/296/)
- Spatial metadata on MV-HEVC opts the video into Vision Pro treatments that "minimize common causes of stereo viewing discomfort". — [Apple MV-HEVC sample](https://developer.apple.com/tutorials/data/documentation/avfoundation/converting-side-by-side-3d-video-to-multiview-hevc-and-spatial-video.md)

### Inferences
- For immersive exports, the flash limiter should be specified **per 10° of visual angle**, not per screen fraction. In an equirectangular 360 frame of width W, 10° of longitude at the equator is W/36 pixels, with more pixels per degree towards the poles. In a 4096² domemaster with a 180° field, 10° is about 228 px of radius. A full-field brightness pulse (the typical "bio-reactive pulse") covers far more than 25 % of every 10° field, so the 3-per-second cap applies with no area exemption. This is derived arithmetic, not a cited rule.
- Large-field luminance pulses and camera motion in 360/180 renders are both seizure and motion-sickness risks. For generative visuals the safer defaults are a static virtual camera (no rendered camera translation), slow peripheral motion, and fades rather than cuts.

### Gaps
- The exact ITU-R BT.1702 numerical thresholds and the Harding FPA test method: the ITU text could not be accessed. Not verified.
- Any photosensitivity guideline written specifically for head-mounted displays or domes: none found.
- The Apple HIG "Motion" page (referenced from the Immersive experiences page) was not fetched.

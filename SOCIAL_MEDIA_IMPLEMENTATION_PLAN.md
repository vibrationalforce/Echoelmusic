# 📱 BLAB Social Media & Content Creation - Implementation Plan

**Status:** 🔴 NOT IMPLEMENTED
**Priority:** HIGH (User Request)
**Timeline:** 8-10 weeks
**Last Update:** 2025-10-28

---

## 📊 Current State Analysis

### ✅ What EXISTS:
- Audio-only export (WAV, M4A, AIFF, CAF)
- Bio-data export (JSON, CSV)
- iOS Share Sheet (basic system sharing)
- 5 visualization modes (Particles, Cymatics, Waveform, Spectral, Mandala)
- Real-time audio-reactive visuals

### ❌ What's MISSING:
- **Video export** (audio + visuals combined)
- **Social media API integration** (Snapchat, Instagram, TikTok, YouTube, etc.)
- **AI-generated content** (prompt-based creation)
- **Storytelling tools** (templates, narratives)
- **Complex animations** (keyframe-based, templates)
- **Photo/video filters** (realistic effects)
- **Platform-optimized export** (aspect ratios, formats, durations)

---

## 🎯 Implementation Roadmap

### **PHASE 1: Video Export Foundation** (Week 1-2)

**Goal:** Enable basic video recording of audio + visuals

#### 1.1 Video Recording Engine
```swift
// Sources/Blab/Recording/VideoRecordingEngine.swift (NEW)
import AVFoundation
import Metal
import MetalKit

class VideoRecordingEngine: ObservableObject {
    // Core Components
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // Video Settings
    private let videoSize: CGSize
    private let frameRate: Int = 60
    private let bitrate: Int = 10_000_000  // 10 Mbps

    // Recording State
    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0

    /// Start video recording
    func startRecording(outputURL: URL, size: CGSize) throws {
        // Setup AVAssetWriter
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoMaxKeyFrameIntervalKey: frameRate
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        // Audio settings
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128_000
        ]

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true

        // Pixel buffer adaptor
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        // Add inputs
        assetWriter?.add(videoInput!)
        assetWriter?.add(audioInput!)

        // Start session
        assetWriter?.startWriting()
        assetWriter?.startSession(atSourceTime: .zero)

        isRecording = true
        print("🎥 Video recording started")
    }

    /// Append video frame from MTLTexture
    func appendVideoFrame(texture: MTLTexture, at time: CMTime) {
        guard let pixelBuffer = createPixelBuffer(from: texture) else { return }

        if videoInput?.isReadyForMoreMediaData == true {
            pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: time)
        }
    }

    /// Append audio buffer
    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        if audioInput?.isReadyForMoreMediaData == true {
            audioInput?.append(sampleBuffer)
        }
    }

    /// Stop recording and finalize video
    func stopRecording() async throws -> URL {
        isRecording = false

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await assetWriter?.finishWriting()

        guard let outputURL = assetWriter?.outputURL else {
            throw RecordingError.exportFailed("No output URL")
        }

        print("🎥 Video recording finished: \(outputURL.lastPathComponent)")
        return outputURL
    }

    /// Convert Metal texture to CVPixelBuffer
    private func createPixelBuffer(from texture: MTLTexture) -> CVPixelBuffer? {
        // Implementation using CVPixelBuffer and Metal
        // ... (detailed implementation)
        return nil
    }
}
```

#### 1.2 Visualization Renderer Integration
```swift
// Sources/Blab/Visual/VisualizationVideoRenderer.swift (NEW)
class VisualizationVideoRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    /// Render visualization to texture
    func renderToTexture(
        mode: VisualizationMode,
        audioData: FFTData,
        bioData: BioParameters,
        size: CGSize
    ) -> MTLTexture? {
        // Render current visualization mode to Metal texture
        // Returns texture ready for video encoding
        return nil
    }
}
```

#### 1.3 Export Manager Extension
```swift
// Extension to ExportManager.swift
extension ExportManager {
    /// Export session as video (audio + visuals)
    func exportVideo(
        session: Session,
        visualizationMode: VisualizationMode,
        resolution: VideoResolution = .hd1080,
        format: VideoFormat = .mp4
    ) async throws -> URL {
        // Implementation
        return URL(fileURLWithPath: "")
    }
}

enum VideoResolution {
    case hd720      // 1280x720
    case hd1080     // 1920x1080
    case hd4K       // 3840x2160
    case vertical   // 1080x1920 (Stories/TikTok)
    case square     // 1080x1080 (Instagram)
}

enum VideoFormat {
    case mp4
    case mov
    case hevc       // H.265 (better compression)
}
```

**Deliverables:**
- ✅ Video recording from live performance
- ✅ Audio + Visuals synchronized export
- ✅ Multiple resolution/format support

---

### **PHASE 2: Social Media Integration** (Week 3-4)

**Goal:** Direct API integration with major platforms

#### 2.1 Platform SDKs Integration

**Package.swift additions:**
```swift
dependencies: [
    // Social Media SDKs
    .package(url: "https://github.com/Snap-Kit/SnapKit-iOS", from: "1.0.0"),
    // Note: Instagram, TikTok, YouTube require developer accounts
]
```

#### 2.2 Social Media Manager
```swift
// Sources/Blab/Social/SocialMediaManager.swift (NEW)
import Foundation

class SocialMediaManager: ObservableObject {
    @Published var availablePlatforms: [SocialPlatform] = []
    @Published var isAuthenticated: [SocialPlatform: Bool] = [:]

    /// Authenticate with platform
    func authenticate(platform: SocialPlatform) async throws {
        switch platform {
        case .snapchat:
            try await authenticateSnapchat()
        case .instagram:
            try await authenticateInstagram()
        case .tiktok:
            try await authenticateTikTok()
        case .youtube:
            try await authenticateYouTube()
        case .twitter:
            try await authenticateTwitter()
        case .facebook:
            try await authenticateFacebook()
        }
    }

    /// Upload video to platform
    func uploadVideo(
        url: URL,
        platform: SocialPlatform,
        metadata: VideoMetadata
    ) async throws -> UploadResult {
        // Platform-specific upload implementation
        return UploadResult(success: true, url: url, platform: platform)
    }
}

enum SocialPlatform: String, CaseIterable {
    case snapchat = "Snapchat"
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case youtube = "YouTube Shorts"
    case twitter = "Twitter/X"
    case facebook = "Facebook"
}

struct VideoMetadata {
    var title: String
    var description: String
    var tags: [String]
    var visibility: Visibility
    var aspectRatio: AspectRatio

    enum Visibility {
        case publicPost
        case friends
        case privatePost
    }

    enum AspectRatio {
        case vertical    // 9:16 (Stories, Reels, Shorts, TikTok)
        case horizontal  // 16:9 (YouTube)
        case square      // 1:1 (Instagram Feed)
    }
}

struct UploadResult {
    let success: Bool
    let url: URL?
    let platform: SocialPlatform
    let postID: String?
    let error: Error?
}
```

#### 2.3 Platform-Specific Exporters

**Snapchat:**
```swift
// Sources/Blab/Social/Platforms/SnapchatExporter.swift (NEW)
import SnapKit

class SnapchatExporter {
    /// Export optimized for Snapchat Spotlight
    func exportForSpotlight(session: Session) async throws -> URL {
        // Vertical video (9:16), max 60 seconds
        // Optimized for discovery algorithm
        return URL(fileURLWithPath: "")
    }
}
```

**Instagram:**
```swift
// Sources/Blab/Social/Platforms/InstagramExporter.swift (NEW)
class InstagramExporter {
    /// Export for Instagram Reels
    func exportForReels(session: Session) async throws -> URL {
        // Vertical (9:16), 15-90 seconds
        // Music-focused optimization
        return URL(fileURLWithPath: "")
    }

    /// Export for Instagram Feed (square)
    func exportForFeed(session: Session) async throws -> URL {
        // Square (1:1), cinematic look
        return URL(fileURLWithPath: "")
    }

    /// Export for Instagram Stories
    func exportForStories(session: Session) async throws -> URL {
        // Vertical (9:16), 15 seconds max
        return URL(fileURLWithPath: "")
    }
}
```

**TikTok:**
```swift
// Sources/Blab/Social/Platforms/TikTokExporter.swift (NEW)
class TikTokExporter {
    /// Export optimized for TikTok algorithm
    func exportForTikTok(session: Session) async throws -> URL {
        // Vertical (9:16), 15-60 seconds
        // Hook in first 3 seconds
        // Beat-synced visuals
        return URL(fileURLWithPath: "")
    }
}
```

**YouTube Shorts:**
```swift
// Sources/Blab/Social/Platforms/YouTubeExporter.swift (NEW)
class YouTubeExporter {
    /// Export for YouTube Shorts
    func exportForShorts(session: Session) async throws -> URL {
        // Vertical (9:16), max 60 seconds
        // Higher bitrate for quality
        return URL(fileURLWithPath: "")
    }
}
```

**Deliverables:**
- ✅ Platform authentication flow
- ✅ Direct upload to 6+ platforms
- ✅ Platform-specific optimization

---

### **PHASE 3: AI-Driven Content Creation** (Week 5-7)

**Goal:** Prompt-based generation and storytelling

#### 3.1 AI Content Generator
```swift
// Sources/Blab/AI/ContentGenerator.swift (NEW)
import CoreML

class ContentGenerator: ObservableObject {
    @Published var isGenerating: Bool = false

    /// Generate video from text prompt
    func generateFromPrompt(
        prompt: String,
        style: ContentStyle,
        duration: TimeInterval
    ) async throws -> GeneratedContent {
        // Use on-device ML models or cloud APIs
        // - Music generation (audio synthesis)
        // - Visual generation (animation templates)
        // - Story arc creation

        return GeneratedContent(
            audioURL: URL(fileURLWithPath: ""),
            visualTemplate: .mandala,
            storyBeats: []
        )
    }
}

enum ContentStyle {
    case ambient        // Calm, flowing
    case energetic      // Fast, dynamic
    case dramatic       // Cinematic, emotional
    case psychedelic    // Abstract, trippy
    case minimalist     // Clean, simple
}

struct GeneratedContent {
    let audioURL: URL
    let visualTemplate: VisualizationMode
    let storyBeats: [StoryBeat]
}

struct StoryBeat {
    let time: TimeInterval
    let intensity: Float
    let visualMode: VisualizationMode
    let description: String
}
```

#### 3.2 Storytelling Engine
```swift
// Sources/Blab/AI/StorytellingEngine.swift (NEW)
class StorytellingEngine {
    /// Create narrative structure
    func createStory(
        theme: StoryTheme,
        duration: TimeInterval,
        climaxAt: TimeInterval?
    ) -> Story {
        // Generate story arc with:
        // - Intro (build tension)
        // - Rising action
        // - Climax (peak intensity)
        // - Resolution

        return Story(beats: [], duration: duration)
    }
}

enum StoryTheme {
    case journey        // Adventure, exploration
    case transformation // Personal growth
    case connection     // Relationships, unity
    case discovery      // Mystery, revelation
    case celebration    // Joy, triumph
}

struct Story {
    let beats: [StoryBeat]
    let duration: TimeInterval
}
```

#### 3.3 Animation Template System
```swift
// Sources/Blab/Visual/AnimationTemplates.swift (NEW)
class AnimationTemplateLibrary {
    /// Pre-built animation templates
    static let templates: [AnimationTemplate] = [
        .particleExplosion,
        .mandalaBlossom,
        .waveformPulse,
        .cymaticRipple,
        .geometricMorph
    ]
}

struct AnimationTemplate {
    let name: String
    let duration: TimeInterval
    let keyframes: [AnimationKeyframe]

    static let particleExplosion = AnimationTemplate(
        name: "Particle Explosion",
        duration: 3.0,
        keyframes: [
            AnimationKeyframe(time: 0.0, state: .gathered),
            AnimationKeyframe(time: 1.5, state: .exploded),
            AnimationKeyframe(time: 3.0, state: .settled)
        ]
    )
}

struct AnimationKeyframe {
    let time: TimeInterval
    let state: AnimationState
}

enum AnimationState {
    case gathered
    case exploded
    case settled
    // ... more states
}
```

#### 3.4 Photo/Video Filter Integration
```swift
// Sources/Blab/Visual/Filters/FilterEngine.swift (NEW)
import CoreImage
import Photos

class FilterEngine {
    /// Apply photo/video filters to visualization
    func applyFilter(
        to texture: MTLTexture,
        filter: VideoFilter
    ) -> MTLTexture {
        // Use Core Image or custom Metal shaders
        return texture
    }
}

enum VideoFilter {
    case cinematic      // Film-like grading
    case vibrant        // Boosted colors
    case vintage        // Retro look
    case neon           // Cyberpunk style
    case ethereal       // Soft, dreamy
    case glitch         // Digital artifacts
}
```

**Deliverables:**
- ✅ Prompt-based content generation
- ✅ Storytelling structure creation
- ✅ Animation template library
- ✅ Photo/video filter effects

---

### **PHASE 4: Advanced UI & User Experience** (Week 8-9)

**Goal:** Intuitive content creation interface

#### 4.1 Content Creation View
```swift
// Sources/Blab/Views/ContentCreationView.swift (NEW)
import SwiftUI

struct ContentCreationView: View {
    @StateObject private var contentGenerator = ContentGenerator()
    @StateObject private var socialManager = SocialMediaManager()
    @State private var prompt: String = ""
    @State private var selectedPlatforms: Set<SocialPlatform> = []

    var body: some View {
        VStack {
            // Prompt Input
            PromptInputField(text: $prompt)

            // Style Selection
            StylePicker()

            // Platform Selection
            PlatformSelector(selected: $selectedPlatforms)

            // Generate Button
            GenerateButton(action: generateContent)

            // Preview
            ContentPreview()

            // Export & Share
            ExportControls()
        }
    }

    func generateContent() {
        Task {
            let content = try await contentGenerator.generateFromPrompt(
                prompt: prompt,
                style: .ambient,
                duration: 30.0
            )
            // Preview and export
        }
    }
}
```

#### 4.2 Platform-Specific Templates
```swift
// Pre-configured templates for each platform
struct PlatformTemplate {
    let platform: SocialPlatform
    let resolution: VideoResolution
    let duration: TimeInterval
    let aspectRatio: CGSize
    let recommendedStyles: [ContentStyle]
}
```

**Deliverables:**
- ✅ Intuitive content creation UI
- ✅ Platform-specific templates
- ✅ Real-time preview
- ✅ One-tap export & share

---

### **PHASE 5: Polish & Optimization** (Week 10)

**Goal:** Performance optimization and bug fixes

#### Tasks:
- [ ] Video encoding performance optimization
- [ ] Memory management for long recordings
- [ ] Network upload optimization (chunked, resumable)
- [ ] Error handling and retry logic
- [ ] Analytics integration
- [ ] User testing & feedback

---

## 🔧 Technical Requirements

### Dependencies:
```swift
// Package.swift additions
dependencies: [
    // Video Processing
    .package(url: "https://github.com/FFmpeg-iOS/FFmpeg-iOS", from: "4.4.0"),

    // Social Media SDKs (require developer accounts)
    // Snapchat Kit
    // Facebook SDK
    // TikTok SDK (limited availability)

    // AI/ML (optional, for on-device generation)
    .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.1.0"),
]
```

### Platform Requirements:
- **iOS 16.0+** (for ReplayKit Screen Recording)
- **Metal 3** (for advanced rendering)
- **200+ MB RAM** (for video encoding)
- **Developer accounts** for each social platform

### API Keys Needed:
1. **Snapchat Developer Account** - https://kit.snapchat.com
2. **Instagram Graph API** (Meta) - https://developers.facebook.com
3. **TikTok for Developers** - https://developers.tiktok.com
4. **YouTube Data API v3** - https://developers.google.com/youtube
5. **Twitter API v2** - https://developer.twitter.com

---

## 📊 Timeline & Milestones

| Phase | Duration | Status | Complexity |
|-------|----------|--------|------------|
| Phase 1: Video Export | 2 weeks | 🔴 Not Started | Medium |
| Phase 2: Social Media | 2 weeks | 🔴 Not Started | High |
| Phase 3: AI Content | 3 weeks | 🔴 Not Started | Very High |
| Phase 4: Advanced UI | 2 weeks | 🔴 Not Started | Medium |
| Phase 5: Polish | 1 week | 🔴 Not Started | Low |
| **Total** | **10 weeks** | **0% Complete** | **High** |

---

## 🚨 Risks & Challenges

### Technical Challenges:
1. **Real-time video encoding performance** - May require Metal optimization
2. **Platform API limitations** - Instagram/TikTok have restricted APIs
3. **File size limits** - Different per platform (100MB - 4GB)
4. **AI model integration** - On-device vs cloud trade-offs

### Business Challenges:
1. **API access approval** - Can take weeks/months for TikTok, Instagram
2. **Platform policy compliance** - Each platform has different rules
3. **Content moderation** - Automated checks required
4. **Revenue sharing** - Some platforms take % of monetization

### Mitigation Strategies:
- Start with open platforms (YouTube, Twitter)
- Implement robust error handling
- Build fallback to iOS Share Sheet if APIs fail
- Use native iOS PhotoKit for local saving
- Implement progressive disclosure (start simple, add features)

---

## 🎯 Recommended Approach

### **Option A: Full Implementation (10 weeks)**
- Complete all 5 phases
- Direct API integration for all platforms
- AI-powered content generation
- **Pros:** Feature-complete, best UX
- **Cons:** Long timeline, high complexity

### **Option B: MVP Implementation (4 weeks)**
- Phase 1: Video export only
- Use iOS Share Sheet (skip direct APIs)
- Pre-built templates (skip AI generation)
- **Pros:** Quick to market, simpler
- **Cons:** Less seamless, manual sharing

### **Option C: Hybrid Approach (6 weeks)** ⭐ RECOMMENDED
- Phase 1: Video export (2 weeks)
- Phase 2: Social media for 2-3 platforms only (Snapchat, Instagram) (2 weeks)
- Phase 4: Basic UI (2 weeks)
- Skip AI generation initially (add later)
- **Pros:** Balanced timeline, core features
- **Cons:** Limited platform support initially

---

## 📝 Next Steps

### Immediate Actions:
1. **Developer Account Registration:**
   - [ ] Register for Snapchat Kit developer account
   - [ ] Apply for Instagram Graph API access
   - [ ] Register for TikTok for Developers
   - [ ] Enable YouTube Data API v3
   - [ ] Get Twitter API v2 access

2. **Technical Preparation:**
   - [ ] Review Apple's PhotoKit documentation
   - [ ] Test AVAssetWriter video encoding performance
   - [ ] Prototype Metal-to-video pipeline
   - [ ] Evaluate on-device ML model options

3. **Design Phase:**
   - [ ] Create UI mockups for content creation flow
   - [ ] Design platform selection interface
   - [ ] Define video template specifications
   - [ ] Plan story structure templates

---

## 💰 Cost Estimate

### Development Costs:
- **Full-time developer (10 weeks):** €40,000 - €60,000
- **API costs (monthly):** €100 - €500
- **Testing devices:** €2,000 - €3,000
- **App Store / Developer accounts:** €300/year

### Maintenance Costs (annual):
- Platform API updates: €5,000 - €10,000
- Content moderation: €1,000 - €5,000
- Server costs (if using cloud AI): €1,200 - €6,000

---

## ✅ Success Metrics

### Key Performance Indicators:
- **Video export success rate** > 95%
- **Upload success rate** > 90%
- **Video encoding time** < 2x playback duration
- **App crash rate during recording** < 0.1%
- **User satisfaction** > 4.5/5 stars

### Platform-Specific Metrics:
- **Instagram Reels shares/week** > 100
- **TikTok uploads/week** > 50
- **YouTube Shorts views** > 10,000/month

---

## 🎨 Example Use Cases

### Use Case 1: Live Performance to TikTok
1. User performs live with BLAB (bio-reactive visuals)
2. Records 60-second performance
3. App automatically generates vertical video (9:16)
4. One-tap upload to TikTok with auto-generated caption
5. Video goes live with optimized metadata

### Use Case 2: AI-Generated Content
1. User enters prompt: "Ethereal meditation journey with mandalas"
2. AI generates 3-minute piece with story arc
3. User previews and adjusts intensity curve
4. Exports as Instagram Reel (90 seconds) + YouTube Short (60 seconds)
5. Uploads to both platforms simultaneously

### Use Case 3: Multi-Platform Campaign
1. User creates 5-minute performance session
2. App generates 5 different cuts:
   - TikTok (60s, vertical)
   - Instagram Reel (90s, vertical)
   - YouTube Short (60s, vertical)
   - Instagram Feed (60s, square)
   - YouTube Video (5min, horizontal)
3. Each optimized for platform algorithm
4. One-tap distribution to all platforms

---

**Built with scientific rigor and modern iOS technologies.**

🤖 Generated with [Claude Code](https://claude.com/claude-code)

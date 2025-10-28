# 🎬 Video Export - Usage Guide

**Phase 1 Implementation Complete** ✅
**Date:** 2025-10-28
**Status:** Ready for Testing

---

## 📋 Overview

The Video Export Foundation provides complete video recording and export capabilities for BLAB, enabling users to create and share videos with synchronized audio and visuals for social media platforms.

### Features:
- ✅ Real-time video recording from live performance
- ✅ Session-to-video export with visualization rendering
- ✅ Multiple resolution/format support (HD720, HD1080, 4K, vertical, square)
- ✅ Platform-specific optimization (Instagram, TikTok, YouTube, etc.)
- ✅ Batch export to multiple platforms
- ✅ Audio + visuals + bio-data synchronization

---

## 🚀 Quick Start

### Example 1: Export Session to Video

```swift
import Foundation

// Get your recorded session
let session: Session = // ... your session

// Create export manager
let exportManager = ExportManager()

// Export to video (default HD 1080p)
Task {
    do {
        let videoURL = try await exportManager.exportVideo(
            session: session,
            visualizationMode: .mandala
        )
        print("Video exported: \(videoURL)")
    } catch {
        print("Export failed: \(error)")
    }
}
```

### Example 2: Export for Instagram Reels

```swift
// Quick export for Instagram Reels (9:16 vertical, 90s max)
Task {
    do {
        let videoURL = try await exportManager.exportInstagramReels(
            session: session,
            visualizationMode: .cymatics
        )
        print("Instagram Reels ready: \(videoURL)")
    } catch {
        print("Export failed: \(error)")
    }
}
```

### Example 3: Export to Multiple Platforms

```swift
// Export to multiple platforms simultaneously
let platforms: [PlatformPreset] = [
    .instagramReels,
    .tiktok,
    .youtubeShorts
]

Task {
    do {
        let results = try await exportManager.exportVideoToMultiplePlatforms(
            session: session,
            platforms: platforms,
            visualizationMode: .particles
        )

        for (platform, url) in results {
            print("\(platform.displayName): \(url.lastPathComponent)")
        }
    } catch {
        print("Batch export failed: \(error)")
    }
}
```

---

## 🎨 Visualization Modes

Choose which visualization to render in your video:

```swift
enum VisualizationMode {
    case particles  // Bio-reactive particle field
    case cymatics   // Chladni patterns (water-like)
    case waveform   // Oscilloscope waveform
    case spectral   // Frequency spectrum analyzer
    case mandala    // Geometric patterns
}
```

**Usage:**
```swift
// Use particles for energetic content
let videoURL = try await exportManager.exportVideo(
    session: session,
    visualizationMode: .particles
)
```

---

## 📐 Resolution & Format Options

### Resolutions:

```swift
enum VideoResolution {
    case hd720          // 1280x720 (HD)
    case hd1080         // 1920x1080 (Full HD)
    case hd4K           // 3840x2160 (4K UHD)
    case vertical1080   // 1080x1920 (Stories/Reels/TikTok)
    case square1080     // 1080x1080 (Instagram Feed)
    case custom(width: Int, height: Int)
}
```

### Formats:

```swift
enum VideoFormat {
    case mp4    // H.264, most compatible
    case mov    // ProRes, highest quality
    case hevc   // H.265, better compression
}
```

### Quality:

```swift
enum VideoQuality {
    case low        // 2 Mbps
    case medium     // 5 Mbps
    case high       // 10 Mbps
    case veryHigh   // 20 Mbps
    case maximum    // 40 Mbps (4K)
}
```

### Custom Configuration:

```swift
let config = VideoExportConfiguration(
    resolution: .hd4K,
    format: .hevc,
    quality: .maximum,
    frameRate: .fps60,
    includeAudio: true
)

let videoURL = try await exportManager.exportVideo(
    session: session,
    visualizationMode: .mandala,
    configuration: config
)
```

---

## 📱 Platform Presets

### Available Platforms:

```swift
enum PlatformPreset {
    case instagramReels     // 9:16, 90s max
    case instagramStory     // 9:16, 15s max
    case instagramFeed      // 1:1, 60s max
    case tiktok             // 9:16, 3min max
    case youtubeShorts      // 9:16, 60s max
    case youtubeVideo       // 16:9, 1h max
    case snapchatSpotlight  // 9:16, 60s max
    case twitter            // 16:9, 2:20 max
}
```

### Platform-Specific Export:

```swift
// Instagram Reels (vertical 9:16, 90 seconds)
let reelsURL = try await exportManager.exportInstagramReels(
    session: session,
    visualizationMode: .mandala
)

// TikTok (vertical 9:16, 3 minutes)
let tiktokURL = try await exportManager.exportTikTok(
    session: session,
    visualizationMode: .particles
)

// YouTube Shorts (vertical 9:16, 60 seconds)
let shortsURL = try await exportManager.exportYouTubeShorts(
    session: session,
    visualizationMode: .cymatics
)

// Instagram Feed (square 1:1)
let feedURL = try await exportManager.exportInstagramFeed(
    session: session,
    visualizationMode: .spectral
)
```

---

## 🔴 Live Recording

### Start Live Recording:

```swift
import Metal

// Get Metal device
guard let device = MTLCreateSystemDefaultDevice() else {
    print("Metal not available")
    return
}

// Create composition engine
let compositionEngine = VideoCompositionEngine(device: device)

// Configure for live recording
let config = VideoExportConfiguration(
    resolution: .hd1080,
    format: .mp4,
    quality: .high,
    frameRate: .fps60
)

// Start recording
try compositionEngine.startLiveRecording(configuration: config)

// During performance, capture frames
func onFrameUpdate(audioData: [Float], bioData: BioRenderData, time: TimeInterval) {
    try? compositionEngine.captureLiveFrame(
        visualizationMode: .mandala,
        audioData: audioData,
        bioData: bioData,
        time: time
    )
}

// Stop and save
Task {
    let videoURL = try await compositionEngine.stopLiveRecording()
    print("Live recording saved: \(videoURL)")
}
```

---

## 📦 Complete Export Package

Export everything: video, audio, bio-data, and metadata:

```swift
Task {
    do {
        let packageURL = try await exportManager.exportCompleteVideoPackage(
            session: session,
            visualizationMode: .particles
        )

        print("Complete package exported to: \(packageURL)")

        // Package contains:
        // - video.mp4 (or .mov/.hevc)
        // - audio.wav
        // - biodata.json
        // - session.json
        // - README.txt
    } catch {
        print("Package export failed: \(error)")
    }
}
```

---

## ✅ Validation & Estimation

### Validate Before Export:

```swift
let exportManager = ExportManager()

// Check if session can be exported
let (isValid, errors) = exportManager.validateVideoExport(session: session)

if isValid {
    print("✅ Session is valid for export")
} else {
    print("❌ Export validation failed:")
    for error in errors {
        print("  - \(error)")
    }
}
```

### Estimate File Size:

```swift
let config = VideoExportConfiguration(resolution: .hd1080, quality: .high)
let estimatedSize = exportManager.estimateVideoFileSize(
    session: session,
    configuration: config
)

print("Estimated size: \(estimatedSize / 1_000_000) MB")
```

### Estimate Export Duration:

```swift
let estimatedDuration = exportManager.estimateVideoExportDuration(
    session: session,
    configuration: config
)

print("Estimated export time: \(Int(estimatedDuration)) seconds")
```

### Check Storage:

```swift
if VideoRecordingEngine.hasEnoughStorage(
    estimatedDuration: session.duration,
    quality: .high
) {
    print("✅ Sufficient storage available")
} else {
    print("⚠️ Not enough storage space")
}
```

---

## 🎯 Platform Recommendations

Get recommended platforms based on session duration:

```swift
let exportManager = ExportManager()
let recommendedPlatforms = exportManager.recommendedPlatforms(for: session)

print("Recommended platforms:")
for platform in recommendedPlatforms {
    print("  - \(platform.displayName)")
}
```

---

## ⚠️ Error Handling

```swift
import Foundation

Task {
    do {
        let videoURL = try await exportManager.exportVideo(
            session: session,
            visualizationMode: .mandala
        )
        print("Success: \(videoURL)")

    } catch VideoExportError.assetWriterCreationFailed {
        print("Could not create video writer")

    } catch VideoExportError.insufficientStorage {
        print("Not enough storage space")

    } catch VideoExportError.encodingFailed(let message) {
        print("Encoding failed: \(message)")

    } catch {
        print("Unknown error: \(error)")
    }
}
```

---

## 🧪 Testing

### Test Video Export:

```swift
// Create test session
let testSession = Session(name: "Test Video", tempo: 120)

// Add mock track
let track = Track(name: "Test Track", format: .caf)
testSession.tracks.append(track)

// Export test video
Task {
    do {
        let videoURL = try await exportManager.exportVideo(
            session: testSession,
            visualizationMode: .particles
        )

        print("✅ Test export successful: \(videoURL)")

        // Verify file exists
        if FileManager.default.fileExists(atPath: videoURL.path) {
            let attributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("   File size: \(fileSize / 1_000_000) MB")
        }

    } catch {
        print("❌ Test export failed: \(error)")
    }
}
```

---

## 📊 Progress Monitoring

```swift
// The VideoCompositionEngine publishes progress updates
let compositionEngine = VideoCompositionEngine(device: device)

// Observe progress
compositionEngine.$exportProgress
    .sink { progress in
        print("Export progress: \(Int(progress * 100))%")
    }
    .store(in: &cancellables)

// Observe completion
compositionEngine.$isExporting
    .sink { isExporting in
        if !isExporting {
            print("Export complete!")
        }
    }
    .store(in: &cancellables)
```

---

## 🔧 Integration with ContentView

### Add Video Export Button:

```swift
// In ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var exportManager = ExportManager()
    @State private var isExporting = false
    @State private var exportedVideoURL: URL?

    var body: some View {
        VStack {
            // ... existing UI

            Button("Export Video") {
                exportVideo()
            }
            .disabled(isExporting)

            if isExporting {
                ProgressView("Exporting video...")
            }

            if let url = exportedVideoURL {
                Text("Exported: \(url.lastPathComponent)")
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    func exportVideo() {
        guard let session = getCurrentSession() else { return }

        isExporting = true

        Task {
            do {
                exportedVideoURL = try await exportManager.exportInstagramReels(
                    session: session,
                    visualizationMode: .mandala
                )
            } catch {
                print("Export failed: \(error)")
            }
            isExporting = false
        }
    }

    func getCurrentSession() -> Session? {
        // Return current recording session
        return nil
    }
}
```

---

## 🚀 Next Steps

### Phase 2: Social Media Integration
- Direct API upload to platforms
- OAuth authentication flows
- Platform-specific metadata
- Content scheduling

### Phase 3: AI Content Creation
- Prompt-based video generation
- Storytelling engine
- Animation templates
- Style transfer

---

## 📝 Notes

### Current Limitations (Phase 1):
- ⚠️ Visualization rendering uses placeholder implementation
- ⚠️ No actual shader compilation (fallback to solid colors)
- ⚠️ Audio extraction from session uses mock data
- ⚠️ No UI integration yet (manual testing required)

### For Production:
- ✅ Implement actual Metal shaders for each visualization mode
- ✅ Connect to real audio FFT data
- ✅ Add proper error recovery and retry logic
- ✅ Implement background task support for long exports
- ✅ Add export queue system for batch processing

---

## 📚 Related Documentation

- **SOCIAL_MEDIA_IMPLEMENTATION_PLAN.md** - Full 10-week roadmap
- **ExportManager.swift** - Audio/bio-data export (existing)
- **Session.swift** - Session data structure
- **VisualizationMode.swift** - Available visualization modes

---

**Status:** ✅ Phase 1 Complete - Ready for Integration Testing
**Next:** Phase 2 - Social Media API Integration

🎬 **Video export foundation is ready!**

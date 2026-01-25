# Export Module

Data and media export capabilities for Echoelmusic.

## Overview

The Export module enables users to export their sessions, recordings, presets, and data in various formats.

## Export Types

### Session Export

Export meditation session data:

```swift
let exporter = SessionExporter()

// Export single session
let data = try exporter.export(session, format: .json)

// Export all sessions
let archive = try exporter.exportAll(format: .csv)

// Export with recordings
let package = try exporter.exportWithAudio(session)
```

### Formats

| Format | Extension | Use Case |
|--------|-----------|----------|
| JSON | .json | Data interchange |
| CSV | .csv | Spreadsheet analysis |
| PDF | .pdf | Reports and sharing |
| Audio | .m4a/.wav | Audio recordings |
| Video | .mp4 | Session recordings |
| Package | .echoelmusic | Full session bundle |

### Audio Export

Export audio recordings:

```swift
let audioExporter = AudioExporter()

// Export as M4A (AAC)
let m4a = try audioExporter.export(recording, format: .m4a, quality: .high)

// Export as WAV (lossless)
let wav = try audioExporter.export(recording, format: .wav)

// Export with visualization
let video = try audioExporter.exportWithVisuals(recording, resolution: .hd1080)
```

### Data Export (GDPR)

Export all user data (GDPR compliance):

```swift
let gdprExporter = GDPRExporter()

// Generate full data export
let package = try await gdprExporter.exportAllUserData()

// Includes:
// - All sessions
// - Presets
// - Settings
// - Analytics (anonymized)
// - Cloud data
```

## Key Components

### ExportManager

Central export coordinator:

```swift
let manager = ExportManager()

// Quick export
let url = try await manager.quickExport(session)

// Custom export
let url = try await manager.export(
    items: [session1, session2],
    format: .pdf,
    options: ExportOptions(
        includeCharts: true,
        includeRawData: false,
        dateRange: .lastMonth
    )
)
```

### ExportOptions

```swift
struct ExportOptions {
    var format: ExportFormat
    var quality: ExportQuality
    var includeCharts: Bool
    var includeRawData: Bool
    var includeRecordings: Bool
    var dateRange: DateRange
    var anonymize: Bool
}
```

### Sharing

Direct sharing integration:

```swift
// Share via system share sheet
manager.share(exportedFile, from: viewController)

// AirDrop
manager.airdrop(exportedFile)

// Email
manager.email(exportedFile, to: "user@example.com")
```

## Video Export

Export session recordings with visualizations:

```swift
let videoExporter = VideoExporter()

// Export options
let options = VideoExportOptions(
    resolution: .uhd4k,
    frameRate: 60,
    codec: .h265,
    includeAudio: true,
    includeOverlay: true
)

let url = try await videoExporter.export(session, options: options)
```

### Resolutions

| Resolution | Dimensions | Use Case |
|------------|------------|----------|
| `.hd720` | 1280×720 | Quick share |
| `.hd1080` | 1920×1080 | Standard |
| `.uhd4k` | 3840×2160 | High quality |
| `.uhd8k` | 7680×4320 | Professional |

## Cloud Export

Export to cloud services:

```swift
// iCloud Drive
try await manager.exportToiCloud(file)

// Files app
manager.exportToFiles(file, from: viewController)
```

## Progress Tracking

```swift
manager.exportProgress
    .sink { progress in
        progressBar.progress = progress.fractionCompleted
        statusLabel.text = progress.localizedDescription
    }
    .store(in: &cancellables)
```

## Files

| File | Description |
|------|-------------|
| `ExportManager.swift` | Central export coordinator |
| `SessionExporter.swift` | Session data export |
| `AudioExporter.swift` | Audio file export |
| `VideoExporter.swift` | Video export with visuals |
| `GDPRExporter.swift` | Full data export |

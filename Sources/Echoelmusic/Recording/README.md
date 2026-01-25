# Recording Module

Multi-track audio and video recording engine for Echoelmusic.

## Features

- **Multi-track Recording**: Record multiple audio sources simultaneously
- **Biometric Data Capture**: Sync HRV/heart rate data with recordings
- **Video Recording**: Capture visual output along with audio
- **Export Formats**: WAV, AIFF, M4A, MP4, MOV
- **Session Management**: Organize recordings by session and date

## Key Components

| Component | Description |
|-----------|-------------|
| `RecordingEngine` | Core recording orchestration |
| `AudioRecorder` | Audio track capture |
| `VideoRecorder` | Visual capture with Metal rendering |
| `SessionRecorder` | Full session recording with bio data |
| `ExportManager` | Format conversion and export |

## Usage

```swift
// Start a recording session
let recorder = RecordingEngine.shared
recorder.startSession(name: "Meditation Session")

// Add tracks
recorder.addAudioTrack(source: .microphone)
recorder.addAudioTrack(source: .synthOutput)
recorder.addBioDataTrack()

// Record
try await recorder.startRecording()

// Stop and export
let session = await recorder.stopRecording()
try await ExportManager.export(session, format: .wav)
```

## Dependencies

- AVFoundation
- Metal (for video)
- HealthKit (for bio data sync)

## Notes

- Recordings are stored in the app's Documents directory
- Large recordings may require significant storage
- Video recording requires GPU access

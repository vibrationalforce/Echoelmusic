# AI Module

The AI module provides machine learning capabilities for Echoelmusic, including on-device inference, model management, and intelligent audio/visual generation.

## Components

### MLModelManager
Comprehensive ML model management system handling:
- Model loading and caching
- Version management and OTA updates
- Checksum validation
- Memory-aware model loading
- Batch inference processing

### AIComposer
AI-powered music composition engine:
- Melodic pattern generation
- Harmonic progression suggestion
- Bio-reactive composition (HRV-driven)
- Style transfer between genres

### LLMService
Large Language Model integration for:
- Natural language music descriptions
- Preset name generation
- Session summaries
- User intent understanding

### OnDeviceIntelligence
Apple Silicon optimized on-device AI:
- Neural Engine acceleration
- Privacy-preserving inference
- Real-time audio analysis
- Gesture and emotion recognition

### EnhancedMLModels
Advanced ML model configurations:
- Custom CoreML model definitions
- Input/output feature handling
- Model performance optimization

### AIModelLoader
Model loading utilities:
- Lazy loading with memory pressure handling
- Model precompilation
- Device capability detection

## Available ML Models

| Model | Purpose | Input | Output |
|-------|---------|-------|--------|
| `sound_style_transfer` | Transform audio timbre | Audio buffer | Styled audio |
| `voice_to_midi` | Convert voice to MIDI notes | Audio | MIDI events |
| `emotion_recognition` | Detect user emotion from voice/face | Audio/Image | Emotion label |
| `hrv_coherence_predictor` | Predict HRV coherence trends | Bio data | Coherence forecast |
| `music_generation` | Generate musical phrases | Parameters | Audio/MIDI |
| `visual_style_transfer` | Apply visual styles | Image | Styled image |
| `gesture_recognition` | Recognize hand gestures | Video frames | Gesture label |
| `breathing_pattern_analysis` | Analyze breathing patterns | Bio data | Pattern classification |

## Usage

```swift
// Load and use a model
let manager = MLModelManager.shared
try await manager.loadModel(.emotionRecognition)

// Run inference
let result = try await manager.infer(
    model: .emotionRecognition,
    input: audioFeatures
)
```

## Platform Support

- iOS 17+ (Neural Engine)
- macOS 14+ (Apple Silicon)
- visionOS 1+ (Spatial computing)

## Privacy

All inference runs on-device. No audio or biometric data is sent to external servers.

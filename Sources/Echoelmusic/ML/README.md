# ML Module

Machine Learning models and inference engine for Echoelmusic.

## Features

- **On-Device Inference**: All ML runs locally, no cloud required
- **CoreML Integration**: Optimized Apple Neural Engine support
- **Model Management**: OTA updates, caching, version control
- **Bio-Reactive ML**: Models trained on biometric data patterns

## Models

| Model | Purpose | Size |
|-------|---------|------|
| `CoherencePredictor` | Predict HRV coherence trends | ~5 MB |
| `MoodClassifier` | Classify emotional states | ~8 MB |
| `MelodyGenerator` | AI music composition | ~15 MB |
| `BeatDetector` | Real-time tempo detection | ~3 MB |
| `VoiceAnalyzer` | Voice emotion analysis | ~10 MB |
| `GestureRecognizer` | Hand gesture classification | ~12 MB |
| `FaceTracker` | Facial expression analysis | Built-in |
| `AudioEnhancer` | AI audio enhancement | ~20 MB |

## Key Components

| Component | Description |
|-----------|-------------|
| `MLModelManager` | Model loading and lifecycle |
| `InferenceEngine` | Real-time prediction |
| `ModelCache` | Efficient model caching |
| `OTAUpdater` | Over-the-air model updates |

## Usage

```swift
// Load and use a model
let predictor = try await MLModelManager.shared.loadModel(.coherencePredictor)
let prediction = try await predictor.predict(hrvData)

// Check model availability
let available = MLModelManager.shared.isModelAvailable(.melodyGenerator)

// Update models
try await MLModelManager.shared.checkForUpdates()
```

## Model Updates

Models can be updated without app updates:
1. New models are downloaded in background
2. Verified with cryptographic signatures
3. Atomically swapped on next use
4. Fallback to bundled models if needed

## Privacy

- All inference runs on-device
- No biometric data leaves the device
- Models are trained on anonymized aggregate data
- User can opt-out of model improvement program

## Performance

| Model | Inference Time | Device |
|-------|---------------|--------|
| CoherencePredictor | <5ms | iPhone 12+ |
| MoodClassifier | <10ms | iPhone 12+ |
| MelodyGenerator | <50ms | iPhone 12+ |

Models are optimized for Apple Neural Engine (ANE) when available.

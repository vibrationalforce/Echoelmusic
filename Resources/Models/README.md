# CoreML Models Directory

This directory contains CoreML models used by Echoelmusic Pro for AI-powered features.

## Model Files (Placeholder Stubs)

The following models are referenced by the codebase:

1. **ShotQuality.mlmodel** - Analyzes video frame quality (0-1 score)
2. **EmotionClassifier.mlmodel** - Detects 7 emotions from facial expressions + bio-data
3. **SceneDetector.mlmodel** - Classifies 10+ scene types (indoor, outdoor, studio, etc.)
4. **ColorGrading.mlmodel** - Suggests optimal color adjustments based on scene analysis
5. **BeatDetector.mlmodel** - Detects music beats for automatic video editing

## Current Implementation Status

**IMPORTANT:** The codebase currently uses algorithmic fallbacks when models are not present:
- Shot quality: Rule-based image analysis (histogram, sharpness, composition)
- Emotion detection: Bio-signal analysis (HRV, coherence, heart rate)
- Scene classification: Heuristic-based detection
- Beat detection: Fixed tempo estimation

These fallbacks provide 70% of the intended functionality without requiring trained models.

## Creating Dummy Models (For Development)

To create minimal placeholder models for testing:

### Using Python + coremltools:

**Automated Script (Recommended):**
```bash
cd Resources/Models
pip install coremltools numpy
python3 generate_dummy_models.py
```

This will create all 5 dummy models:
- ShotQuality.mlmodel
- EmotionClassifier.mlmodel
- SceneDetector.mlmodel
- ColorGrading.mlmodel
- BeatDetector.mlmodel

**Note:** Requires macOS with Python 3.7+ and coremltools. On Linux, use algorithmic fallbacks (already implemented).

### Using CreateML on macOS:

1. Open **CreateML** app
2. Create new **Image Classifier** project
3. Add minimal training data (10-20 images per class)
4. Train for 1 iteration (dummy training)
5. Export as `.mlmodel`

## Production Models (Future)

For production, these models should be trained on:
- **Shot Quality:** 10k+ labeled video frames (good/bad/excellent)
- **Emotion Classifier:** Facial expression dataset + bio-signal correlation
- **Scene Detector:** Scene classification dataset (indoor/outdoor/studio/etc.)
- **Color Grading:** Professional color-graded image pairs
- **Beat Detector:** Audio dataset with beat annotations

## Integration

Models are loaded in:
- `Sources/Echoelmusic/AI/CoreMLModels.swift`
- `Sources/Echoelmusic/Video/VideoAICreativeHub.swift`
- `Sources/Echoelmusic/Video/CinemaCameraSystem.swift`

## Open Source Alternatives

Consider integrating these pre-trained models:
- **Demucs v4** (Meta) - Audio stem separation
- **MediaPipe** (Google) - Face/hand tracking
- **ResNet-50** - Scene classification
- **YOLOv8** - Object detection

Convert ONNX to CoreML: `pip install onnx-coreml`

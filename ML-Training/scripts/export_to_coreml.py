#!/usr/bin/env python3
"""
Echoelmusic - CoreML Export Utility
====================================
Exports trained PyTorch models to CoreML format for iOS/macOS deployment.

Output: .mlmodel files for Xcode integration
"""

import torch
import torch.nn as nn
import coremltools as ct
from coremltools.models.neural_network import quantization_utils
import json
from pathlib import Path
import numpy as np

# Import model architecture
from train_emotion_classifier import EmotionClassifier, EMOTIONS


def export_emotion_classifier():
    """Export emotion classifier to CoreML."""

    print("=" * 60)
    print("Echoelmusic CoreML Export")
    print("=" * 60)

    models_dir = Path(__file__).parent.parent / "models"
    output_dir = Path(__file__).parent.parent.parent / "Sources" / "Echoelmusic" / "AI" / "Models"
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load trained model
    print("\n[1/4] Loading trained model...")
    checkpoint_path = models_dir / "emotion_classifier.pt"

    if not checkpoint_path.exists():
        print(f"    ERROR: Model not found at {checkpoint_path}")
        print("    Run train_emotion_classifier.py first!")
        return

    checkpoint = torch.load(checkpoint_path, map_location="cpu")
    scaler_params = checkpoint["scaler_params"]

    # Recreate model architecture
    model = EmotionClassifier(input_size=5, hidden_size=64, num_classes=8)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    print("    Model loaded successfully")

    # Trace model for export
    print("\n[2/4] Tracing model...")
    example_input = torch.randn(1, 5)  # Batch of 1, 5 features

    traced_model = torch.jit.trace(model, example_input)

    # Convert to CoreML
    print("\n[3/4] Converting to CoreML...")

    # Define input/output specifications
    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(
                name="biometrics",
                shape=(1, 5),
                dtype=np.float32
            )
        ],
        outputs=[
            ct.TensorType(name="emotion_probabilities")
        ],
        minimum_deployment_target=ct.target.iOS15,
        convert_to="mlprogram"
    )

    # Add metadata
    mlmodel.author = "Echoelmusic"
    mlmodel.short_description = "Emotion classification from biometric data (HRV, HR, Coherence)"
    mlmodel.version = "1.0.0"

    # Add input/output descriptions
    mlmodel.input_description["biometrics"] = (
        "Normalized biometric features: [heart_rate, hrv_sdnn, hrv_rmssd, coherence, respiration_rate]. "
        f"Normalize using mean={scaler_params['mean']}, scale={scaler_params['scale']}"
    )
    mlmodel.output_description["emotion_probabilities"] = (
        f"Probabilities for {len(EMOTIONS)} emotions: {', '.join(EMOTIONS)}"
    )

    # Save CoreML model
    print("\n[4/4] Saving CoreML model...")
    output_path = output_dir / "EmotionClassifier.mlpackage"
    mlmodel.save(str(output_path))

    print(f"    Saved: {output_path}")

    # Also save normalization parameters for Swift
    swift_params_path = output_dir / "EmotionClassifierParams.json"
    with open(swift_params_path, "w") as f:
        json.dump({
            "normalization": {
                "mean": scaler_params["mean"],
                "scale": scaler_params["scale"],
                "features": scaler_params["feature_names"]
            },
            "emotions": EMOTIONS,
            "model_version": "1.0.0"
        }, f, indent=2)

    print(f"    Saved: {swift_params_path}")

    # Print usage instructions
    print("\n" + "=" * 60)
    print("Export complete!")
    print("=" * 60)
    print("""
Swift Integration:
------------------
1. Add EmotionClassifier.mlpackage to Xcode project
2. Use the model:

```swift
import CoreML

class EmotionPredictor {
    private let model = try! EmotionClassifier()

    // Normalization params from EmotionClassifierParams.json
    private let mean: [Float] = [73.2, 52.1, 42.3, 0.54, 14.2]
    private let scale: [Float] = [15.8, 18.7, 15.2, 0.19, 4.1]

    func predict(hr: Float, sdnn: Float, rmssd: Float,
                 coherence: Float, resp: Float) -> String {
        // Normalize inputs
        let normalized = MLMultiArray(shape: [1, 5], dataType: .float32)
        normalized[0] = NSNumber(value: (hr - mean[0]) / scale[0])
        normalized[1] = NSNumber(value: (sdnn - mean[1]) / scale[1])
        normalized[2] = NSNumber(value: (rmssd - mean[2]) / scale[2])
        normalized[3] = NSNumber(value: (coherence - mean[3]) / scale[3])
        normalized[4] = NSNumber(value: (resp - mean[4]) / scale[4])

        let output = try! model.prediction(biometrics: normalized)
        // Return emotion with highest probability
    }
}
```
""")


def export_all():
    """Export all trained models to CoreML."""
    export_emotion_classifier()
    # Add more model exports here as needed
    # export_music_style_classifier()
    # export_pattern_recognizer()


if __name__ == "__main__":
    export_all()

# Echoelmusic ML Training

Python-based machine learning training pipeline for Echoelmusic iOS/macOS app.

## Architecture: "Bridge not Destination"

```
[Python: Training]  →  [CoreML: Model]  →  [Swift: Runtime]
     This repo           .mlpackage         App/AI/Models/
```

## Setup

```bash
cd ML-Training
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Available Models

### 1. Emotion Classifier
Classifies emotional state from biometric data (HRV, HR, Coherence).

**Train:**
```bash
python scripts/train_emotion_classifier.py
```

**Export to CoreML:**
```bash
python scripts/export_to_coreml.py
```

**Input Features:**
- `heart_rate`: Float (40-200 BPM)
- `hrv_sdnn`: Float (0-200 ms)
- `hrv_rmssd`: Float (0-150 ms)
- `coherence`: Float (0-1)
- `respiration_rate`: Float (4-30 breaths/min)

**Output Classes:**
- neutral, happy, sad, energetic, calm, anxious, focused, relaxed

## Directory Structure

```
ML-Training/
├── README.md
├── requirements.txt
├── scripts/
│   ├── train_emotion_classifier.py
│   └── export_to_coreml.py
├── models/              # Trained PyTorch models
│   ├── emotion_classifier.pt
│   └── emotion_scaler.json
└── data/                # Training datasets
```

## Research References

Emotion classification based on:
- HeartMath Institute: Coherence and emotional regulation
- Porges Polyvagal Theory: Vagal tone and emotional states
- Task Force of ESC/NASPE: HRV standards (1996)

## Adding New Models

1. Create training script in `scripts/`
2. Define model architecture compatible with CoreML
3. Add export function to `export_to_coreml.py`
4. Update this README

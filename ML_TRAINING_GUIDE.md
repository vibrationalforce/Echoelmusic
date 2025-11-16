# CoreML Model Training Guide für Echoelmusic

Diese Anleitung beschreibt, wie die CoreML-Modelle für die Composition School trainiert werden.

## Übersicht

Die Echoelmusic Composition School nutzt 4 CoreML-Modelle:

1. **GenreClassifier** - Klassifiziert Audio in Musik-Genres
2. **TechniqueRecognizer** - Erkennt Produktionstechniken in Audio
3. **PatternGenerator** - Generiert genre-spezifische MIDI-Patterns
4. **MixAnalyzer** - Analysiert Mix-Qualität und gibt Verbesserungsvorschläge

## Voraussetzungen

```bash
# Python Dependencies
pip install coremltools tensorflow numpy librosa scikit-learn

# Optional: PyTorch für moderne Architekturen
pip install torch torchvision
```

## 1. GenreClassifier Training

### Datensatz

- **Benötigt:** ~10.000 Audio-Samples pro Genre (min. 1.000)
- **Genres:** EDM, Jazz, Classical, Hip-Hop, Ambient, Rock, World, Experimental
- **Format:** WAV/MP3, 44.1kHz, Mono/Stereo

### Feature Extraction

```python
import librosa
import numpy as np

def extract_audio_features(audio_path):
    """Extract features für Genre Classification"""
    y, sr = librosa.load(audio_path, sr=44100, duration=30.0)

    # Tempo
    tempo, _ = librosa.beat.beat_track(y=y, sr=sr)

    # Spectral Features
    spectral_centroids = librosa.feature.spectral_centroid(y=y, sr=sr)
    spectral_rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr)
    zero_crossing_rate = librosa.feature.zero_crossing_rate(y)

    # MFCC (13 coefficients)
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    mfcc_mean = np.mean(mfcc, axis=1)

    # Chroma (12 bins)
    chroma = librosa.feature.chroma_stft(y=y, sr=sr)
    chroma_mean = np.mean(chroma, axis=1)

    # RMS Energy
    rms = librosa.feature.rms(y=y)

    # Spectral Flux
    spectral_flux = np.mean(np.diff(spectral_centroids))

    # Spectral Contrast
    spectral_contrast = librosa.feature.spectral_contrast(y=y, sr=sr)

    return {
        'tempo': tempo,
        'spectral_centroid': np.mean(spectral_centroids),
        'spectral_rolloff': np.mean(spectral_rolloff),
        'zero_crossing_rate': np.mean(zero_crossing_rate),
        'mfcc': mfcc_mean,
        'chroma': chroma_mean,
        'rms': np.mean(rms),
        'spectral_flux': spectral_flux,
        'spectral_contrast': np.mean(spectral_contrast)
    }
```

### Model Architecture

```python
import tensorflow as tf
from tensorflow import keras

def build_genre_classifier():
    """Build Genre Classification Model"""

    # Input layers
    tempo_input = keras.Input(shape=(1,), name='tempo')
    spectral_centroid_input = keras.Input(shape=(1,), name='spectral_centroid')
    spectral_rolloff_input = keras.Input(shape=(1,), name='spectral_rolloff')
    zcr_input = keras.Input(shape=(1,), name='zero_crossing_rate')
    rms_input = keras.Input(shape=(1,), name='rms')
    flux_input = keras.Input(shape=(1,), name='spectral_flux')
    contrast_input = keras.Input(shape=(1,), name='spectral_contrast')
    mfcc_input = keras.Input(shape=(13,), name='mfcc')
    chroma_input = keras.Input(shape=(12,), name='chroma')

    # Concatenate all features
    concat = keras.layers.Concatenate()([
        tempo_input, spectral_centroid_input, spectral_rolloff_input,
        zcr_input, rms_input, flux_input, contrast_input,
        mfcc_input, chroma_input
    ])

    # Dense layers
    x = keras.layers.Dense(256, activation='relu')(concat)
    x = keras.layers.Dropout(0.3)(x)
    x = keras.layers.Dense(128, activation='relu')(x)
    x = keras.layers.Dropout(0.3)(x)
    x = keras.layers.Dense(64, activation='relu')(x)

    # Output layers
    genre_output = keras.layers.Dense(8, activation='softmax', name='genre')(x)
    confidence_output = keras.layers.Dense(1, activation='sigmoid', name='confidence')(x)

    model = keras.Model(
        inputs=[tempo_input, spectral_centroid_input, spectral_rolloff_input,
                zcr_input, rms_input, flux_input, contrast_input,
                mfcc_input, chroma_input],
        outputs=[genre_output, confidence_output]
    )

    model.compile(
        optimizer='adam',
        loss={'genre': 'categorical_crossentropy', 'confidence': 'mse'},
        metrics={'genre': 'accuracy', 'confidence': 'mae'}
    )

    return model
```

### Conversion to CoreML

```python
import coremltools as ct

def convert_to_coreml(tf_model, save_path='GenreClassifier.mlmodel'):
    """Convert TensorFlow model to CoreML"""

    # Convert to CoreML
    coreml_model = ct.convert(
        tf_model,
        convert_to='mlprogram',  # Use ML Program (iOS 15+)
        minimum_deployment_target=ct.target.iOS15,
        inputs=[
            ct.TensorType(name='tempo', shape=(1,)),
            ct.TensorType(name='spectral_centroid', shape=(1,)),
            ct.TensorType(name='spectral_rolloff', shape=(1,)),
            ct.TensorType(name='zero_crossing_rate', shape=(1,)),
            ct.TensorType(name='mfcc', shape=(13,)),
            ct.TensorType(name='chroma', shape=(12,)),
            ct.TensorType(name='rms', shape=(1,)),
            ct.TensorType(name='spectral_flux', shape=(1,)),
            ct.TensorType(name='spectral_contrast', shape=(1,))
        ]
    )

    # Add metadata
    coreml_model.short_description = "Genre Classification for Echoelmusic"
    coreml_model.author = "Echoelmusic AI Team"
    coreml_model.license = "Proprietary"
    coreml_model.version = "1.0"

    # Save
    coreml_model.save(save_path)
    print(f"✅ CoreML model saved to {save_path}")

    return coreml_model
```

---

## 2. TechniqueRecognizer Training

### Datensatz

- **Multi-Label Classification** - Ein Track kann mehrere Techniken enthalten
- **Labels:** Alle 20 ProductionTechniques (siehe `CompositionSchool.swift`)
- **Benötigt:** ~5.000 Tracks mit manueller Annotation

### Feature Extraction

```python
def extract_technique_features(audio_path):
    """Extract features für Technique Recognition"""
    y, sr = librosa.load(audio_path, sr=44100)

    features = {}

    # Dynamic Range (Compression Detection)
    features['dynamic_range'] = np.max(y) - np.min(y)

    # Stereo Width
    if y.ndim == 2:
        correlation = np.corrcoef(y[0], y[1])[0, 1]
        features['stereo_width'] = 1.0 - correlation
    else:
        features['stereo_width'] = 0.0

    # Frequency Spectrum Variance (Filter/EQ Detection)
    spec = np.abs(librosa.stft(y))
    features['spectrum_variance'] = np.var(spec)

    # Temporal Modulation (Delay/Reverb Detection)
    autocorr = librosa.autocorrelate(y)
    features['temporal_modulation'] = np.max(autocorr[sr//10:sr])  # 100ms-1s delay

    # Transient Detection (Compression/Limiting)
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    features['transient_strength'] = np.mean(onset_env)

    # Harmonic/Percussive Separation
    y_harmonic, y_percussive = librosa.effects.hpss(y)
    features['harmonic_ratio'] = np.sum(np.abs(y_harmonic)) / (np.sum(np.abs(y)) + 1e-6)

    return features
```

### Multi-Label Model

```python
def build_technique_recognizer():
    """Multi-label classification for production techniques"""

    input_layer = keras.Input(shape=(6,), name='features')  # 6 technique features

    x = keras.layers.Dense(128, activation='relu')(input_layer)
    x = keras.layers.Dropout(0.4)(x)
    x = keras.layers.Dense(64, activation='relu')(x)
    x = keras.layers.Dropout(0.4)(x)

    # 20 output neurons (one per technique) with sigmoid for multi-label
    output = keras.layers.Dense(20, activation='sigmoid', name='techniques')(x)

    model = keras.Model(inputs=input_layer, outputs=output)

    model.compile(
        optimizer='adam',
        loss='binary_crossentropy',  # Multi-label!
        metrics=['binary_accuracy']
    )

    return model
```

---

## 3. PatternGenerator Training (LSTM/Transformer)

### Datensatz

- **MIDI Sequences** - Genre-spezifische MIDI-Patterns
- **Benötigt:** ~50.000 MIDI-Patterns pro Genre
- **Quellen:** MIDI databases, DAW-Projekte, synthesierte Patterns

### LSTM Architecture

```python
def build_pattern_generator():
    """LSTM-based pattern generator"""

    # Genre one-hot (8 genres)
    genre_input = keras.Input(shape=(8,), name='genre')

    # Technique one-hot (20 techniques)
    technique_input = keras.Input(shape=(20,), name='technique')

    # Parameters (tempo, bars, complexity)
    tempo_input = keras.Input(shape=(1,), name='tempo')
    bars_input = keras.Input(shape=(1,), name='bars')
    complexity_input = keras.Input(shape=(1,), name='complexity')

    # Concatenate conditioning
    conditioning = keras.layers.Concatenate()([
        genre_input, technique_input,
        tempo_input, bars_input, complexity_input
    ])

    # Embedding
    x = keras.layers.Dense(256, activation='relu')(conditioning)
    x = keras.layers.RepeatVector(64)(x)  # Repeat for sequence length

    # LSTM layers
    x = keras.layers.LSTM(512, return_sequences=True)(x)
    x = keras.layers.Dropout(0.3)(x)
    x = keras.layers.LSTM(512, return_sequences=True)(x)
    x = keras.layers.Dropout(0.3)(x)

    # Output: [pitch, velocity, start_time, duration] per note
    # Max 64 notes per pattern
    output = keras.layers.TimeDistributed(
        keras.layers.Dense(4, activation='sigmoid')
    )(x)

    model = keras.Model(
        inputs=[genre_input, technique_input, tempo_input, bars_input, complexity_input],
        outputs=output
    )

    model.compile(optimizer='adam', loss='mse')

    return model
```

### Data Preparation

```python
def prepare_midi_data(midi_files, genre_labels, technique_labels):
    """Prepare MIDI data for training"""
    X_genre = []
    X_technique = []
    X_tempo = []
    X_bars = []
    X_complexity = []
    Y_notes = []

    for midi_file, genre, techniques in zip(midi_files, genre_labels, technique_labels):
        # Load MIDI
        midi = pretty_midi.PrettyMIDI(midi_file)

        # Extract notes
        notes = []
        for instrument in midi.instruments:
            for note in instrument.notes[:64]:  # Max 64 notes
                notes.append([
                    note.pitch / 127.0,           # Normalize to 0-1
                    note.velocity / 127.0,
                    note.start / midi.get_end_time(),
                    note.get_duration() / midi.get_end_time()
                ])

        # Pad if less than 64 notes
        while len(notes) < 64:
            notes.append([0, 0, 0, 0])

        # One-hot encode genre and techniques
        genre_onehot = np.zeros(8)
        genre_onehot[genre] = 1

        technique_onehot = np.zeros(20)
        for tech in techniques:
            technique_onehot[tech] = 1

        X_genre.append(genre_onehot)
        X_technique.append(technique_onehot)
        X_tempo.append([estimate_tempo(midi)])
        X_bars.append([estimate_bars(midi)])
        X_complexity.append([calculate_complexity(notes)])
        Y_notes.append(notes)

    return {
        'genre': np.array(X_genre),
        'technique': np.array(X_technique),
        'tempo': np.array(X_tempo),
        'bars': np.array(X_bars),
        'complexity': np.array(X_complexity)
    }, np.array(Y_notes)
```

---

## 4. MixAnalyzer Training

### Datensatz

- **Professional Mixes** mit Annotations (Frequency Balance, Dynamic Range, etc.)
- **Amateur Mixes** für Vergleich
- **Benötigt:** ~10.000 analysierte Tracks

### Regression Model

```python
def build_mix_analyzer():
    """Mix quality analyzer with regression outputs"""

    input_layer = keras.Input(shape=(1024,), name='spectrum')  # FFT spectrum

    x = keras.layers.Dense(512, activation='relu')(input_layer)
    x = keras.layers.Dropout(0.3)(x)
    x = keras.layers.Dense(256, activation='relu')(x)
    x = keras.layers.Dropout(0.3)(x)
    x = keras.layers.Dense(128, activation='relu')(x)

    # Multiple regression outputs
    freq_balance = keras.layers.Dense(6, activation='sigmoid', name='freq_balance')(x)
    dynamic_range = keras.layers.Dense(1, activation='linear', name='dynamic_range')(x)
    stereo_width = keras.layers.Dense(1, activation='sigmoid', name='stereo_width')(x)
    peak_level = keras.layers.Dense(1, activation='sigmoid', name='peak_level')(x)
    rms_level = keras.layers.Dense(1, activation='sigmoid', name='rms_level')(x)

    model = keras.Model(
        inputs=input_layer,
        outputs=[freq_balance, dynamic_range, stereo_width, peak_level, rms_level]
    )

    model.compile(
        optimizer='adam',
        loss='mse',
        metrics=['mae']
    )

    return model
```

---

## Training Pipeline

### Complete Training Script

```python
#!/usr/bin/env python3
"""
Complete training pipeline for all Echoelmusic CoreML models
"""

import os
import argparse
from pathlib import Path

def train_all_models(data_dir, output_dir):
    """Train all 4 CoreML models"""

    print("🚀 Starting Echoelmusic ML Training Pipeline")

    # 1. Genre Classifier
    print("\n1️⃣ Training GenreClassifier...")
    genre_model = build_genre_classifier()
    # ... load data and train ...
    genre_model.fit(X_train, y_train, epochs=100, validation_split=0.2)
    convert_to_coreml(genre_model, f"{output_dir}/GenreClassifier.mlmodel")

    # 2. Technique Recognizer
    print("\n2️⃣ Training TechniqueRecognizer...")
    technique_model = build_technique_recognizer()
    # ... load data and train ...
    technique_model.fit(X_train, y_train, epochs=80, validation_split=0.2)
    convert_to_coreml(technique_model, f"{output_dir}/TechniqueRecognizer.mlmodel")

    # 3. Pattern Generator
    print("\n3️⃣ Training PatternGenerator...")
    pattern_model = build_pattern_generator()
    # ... load MIDI data and train ...
    pattern_model.fit(X_train, y_train, epochs=150, validation_split=0.2)
    convert_to_coreml(pattern_model, f"{output_dir}/PatternGenerator.mlmodel")

    # 4. Mix Analyzer
    print("\n4️⃣ Training MixAnalyzer...")
    mix_model = build_mix_analyzer()
    # ... load mix data and train ...
    mix_model.fit(X_train, y_train, epochs=100, validation_split=0.2)
    convert_to_coreml(mix_model, f"{output_dir}/MixAnalyzer.mlmodel")

    print("\n✅ All models trained successfully!")
    print(f"📦 Models saved to: {output_dir}")
    print("\n📋 Next steps:")
    print("1. Copy .mlmodel files to Xcode project")
    print("2. Add to Resources folder")
    print("3. Xcode will compile to .mlmodelc")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--data-dir', required=True, help='Path to training data')
    parser.add_argument('--output-dir', default='./models', help='Output directory')
    args = parser.parse_args()

    train_all_models(args.data_dir, args.output_dir)
```

---

## Model Deployment

### Xcode Integration

1. **Drag `.mlmodel` files** in Xcode-Projekt unter `Sources/Echoelmusic/Resources/`
2. **Xcode kompiliert automatisch** zu `.mlmodelc`
3. **CoreMLModelManager** lädt Modelle beim App-Start

### Testing

```swift
// Test Genre Classification
let modelManager = CoreMLModelManager.shared
let genreClassifier = modelManager.getGenreClassifier()

let testFeatures = AudioFeatures(
    tempo: 128.0,
    spectralCentroid: 0.65,
    // ... other features
)

let result = genreClassifier.classify(audioFeatures: testFeatures)
print("Detected genre: \(result.primaryGenre) with \(result.confidence * 100)% confidence")
```

---

## Performance Optimization

### Model Quantization

```python
# Reduce model size with quantization
coreml_model_quantized = ct.models.neural_network.quantization_utils.quantize_weights(
    coreml_model,
    nbits=8  # 8-bit quantization
)
```

### On-Device Training (iOS 15+)

```python
# Enable updatable models for on-device fine-tuning
coreml_model.make_updatable(['dense_1', 'dense_2'])
```

---

## Resources

- **Datasets:**
  - [GTZAN Genre Collection](http://marsyas.info/downloads/datasets.html)
  - [Million Song Dataset](http://millionsongdataset.com/)
  - [Lakh MIDI Dataset](https://colinraffel.com/projects/lmd/)

- **Tools:**
  - [librosa](https://librosa.org/) - Audio analysis
  - [CoreML Tools](https://coremltools.readme.io/) - Model conversion
  - [Create ML](https://developer.apple.com/machine-learning/create-ml/) - Apple's ML framework

---

**Hinweis:** Die Modelle trainieren dauert je nach Hardware 4-24 Stunden. Empfohlen: GPU-beschleunigte Umgebung (NVIDIA CUDA oder Apple Metal).

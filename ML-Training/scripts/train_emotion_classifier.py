#!/usr/bin/env python3
"""
Echoelmusic - Emotion Classifier Training
==========================================
Trains a neural network to classify emotional states from biometric data.

Based on HRV research (HeartMath, Porges Polyvagal Theory):
- Heart Rate (HR)
- Heart Rate Variability (HRV SDNN, RMSSD)
- Coherence Score
- Respiration Rate

Output: CoreML model for iOS/macOS deployment
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import json
from pathlib import Path
from tqdm import tqdm

# Emotion classes matching Swift EnhancedMLModels.Emotion
EMOTIONS = [
    "neutral",
    "happy",
    "sad",
    "energetic",
    "calm",
    "anxious",
    "focused",
    "relaxed"
]

class EmotionClassifier(nn.Module):
    """
    Neural network for emotion classification from biometrics.

    Input features (5):
        - heart_rate: Float (40-200 BPM)
        - hrv_sdnn: Float (0-200 ms)
        - hrv_rmssd: Float (0-150 ms)
        - coherence: Float (0-1)
        - respiration_rate: Float (4-30 breaths/min)

    Output: 8 emotion probabilities
    """

    def __init__(self, input_size=5, hidden_size=64, num_classes=8):
        super().__init__()

        self.network = nn.Sequential(
            # Input layer
            nn.Linear(input_size, hidden_size),
            nn.BatchNorm1d(hidden_size),
            nn.ReLU(),
            nn.Dropout(0.3),

            # Hidden layer 1
            nn.Linear(hidden_size, hidden_size),
            nn.BatchNorm1d(hidden_size),
            nn.ReLU(),
            nn.Dropout(0.3),

            # Hidden layer 2
            nn.Linear(hidden_size, hidden_size // 2),
            nn.BatchNorm1d(hidden_size // 2),
            nn.ReLU(),

            # Output layer
            nn.Linear(hidden_size // 2, num_classes)
        )

    def forward(self, x):
        return self.network(x)


def generate_synthetic_data(n_samples=10000):
    """
    Generate synthetic training data based on HRV research.

    In production, replace with real biometric datasets from:
    - PhysioNet databases
    - WESAD dataset
    - AMIGOS dataset
    """
    np.random.seed(42)

    data = []

    # Define biometric profiles for each emotion (based on research)
    profiles = {
        "neutral": {"hr": (65, 80), "sdnn": (40, 60), "rmssd": (30, 50), "coh": (0.4, 0.6), "resp": (12, 16)},
        "happy": {"hr": (70, 90), "sdnn": (50, 80), "rmssd": (40, 70), "coh": (0.6, 0.85), "resp": (14, 18)},
        "sad": {"hr": (55, 70), "sdnn": (30, 50), "rmssd": (20, 40), "coh": (0.3, 0.5), "resp": (10, 14)},
        "energetic": {"hr": (85, 120), "sdnn": (60, 100), "rmssd": (50, 80), "coh": (0.5, 0.7), "resp": (16, 22)},
        "calm": {"hr": (55, 70), "sdnn": (50, 80), "rmssd": (40, 70), "coh": (0.7, 0.95), "resp": (8, 12)},
        "anxious": {"hr": (80, 110), "sdnn": (20, 40), "rmssd": (15, 35), "coh": (0.2, 0.4), "resp": (18, 26)},
        "focused": {"hr": (65, 85), "sdnn": (45, 70), "rmssd": (35, 55), "coh": (0.6, 0.8), "resp": (12, 16)},
        "relaxed": {"hr": (55, 68), "sdnn": (55, 90), "rmssd": (45, 75), "coh": (0.75, 0.95), "resp": (6, 10)},
    }

    samples_per_class = n_samples // len(EMOTIONS)

    for emotion_idx, emotion in enumerate(EMOTIONS):
        profile = profiles[emotion]

        for _ in range(samples_per_class):
            # Generate sample with natural variation
            hr = np.random.uniform(*profile["hr"])
            sdnn = np.random.uniform(*profile["sdnn"])
            rmssd = np.random.uniform(*profile["rmssd"])
            coh = np.random.uniform(*profile["coh"])
            resp = np.random.uniform(*profile["resp"])

            # Add some noise for realism
            hr += np.random.normal(0, 3)
            sdnn += np.random.normal(0, 5)
            rmssd += np.random.normal(0, 4)
            coh += np.random.normal(0, 0.05)
            resp += np.random.normal(0, 1)

            # Clamp values to valid ranges
            hr = np.clip(hr, 40, 200)
            sdnn = np.clip(sdnn, 5, 200)
            rmssd = np.clip(rmssd, 5, 150)
            coh = np.clip(coh, 0, 1)
            resp = np.clip(resp, 4, 30)

            data.append({
                "heart_rate": hr,
                "hrv_sdnn": sdnn,
                "hrv_rmssd": rmssd,
                "coherence": coh,
                "respiration_rate": resp,
                "emotion": emotion_idx
            })

    return pd.DataFrame(data)


def train_model(epochs=100, batch_size=64, learning_rate=0.001):
    """Train the emotion classifier."""

    print("=" * 60)
    print("Echoelmusic Emotion Classifier Training")
    print("=" * 60)

    # Generate or load data
    print("\n[1/5] Generating training data...")
    df = generate_synthetic_data(n_samples=10000)

    # Prepare features and labels
    feature_cols = ["heart_rate", "hrv_sdnn", "hrv_rmssd", "coherence", "respiration_rate"]
    X = df[feature_cols].values
    y = df["emotion"].values

    # Split data
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # Normalize features
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_val = scaler.transform(X_val)

    # Save scaler parameters for CoreML
    scaler_params = {
        "mean": scaler.mean_.tolist(),
        "scale": scaler.scale_.tolist(),
        "feature_names": feature_cols
    }

    # Convert to tensors
    X_train_t = torch.FloatTensor(X_train)
    y_train_t = torch.LongTensor(y_train)
    X_val_t = torch.FloatTensor(X_val)
    y_val_t = torch.LongTensor(y_val)

    # Create data loaders
    train_dataset = TensorDataset(X_train_t, y_train_t)
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)

    # Initialize model
    print("\n[2/5] Initializing model...")
    model = EmotionClassifier(input_size=5, hidden_size=64, num_classes=8)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, patience=10, factor=0.5)

    print(f"    Model parameters: {sum(p.numel() for p in model.parameters()):,}")

    # Training loop
    print(f"\n[3/5] Training for {epochs} epochs...")
    best_val_acc = 0

    for epoch in range(epochs):
        model.train()
        train_loss = 0

        for X_batch, y_batch in train_loader:
            optimizer.zero_grad()
            outputs = model(X_batch)
            loss = criterion(outputs, y_batch)
            loss.backward()
            optimizer.step()
            train_loss += loss.item()

        # Validation
        model.eval()
        with torch.no_grad():
            val_outputs = model(X_val_t)
            val_loss = criterion(val_outputs, y_val_t).item()
            val_preds = val_outputs.argmax(dim=1)
            val_acc = (val_preds == y_val_t).float().mean().item()

        scheduler.step(val_loss)

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_model_state = model.state_dict().copy()

        if (epoch + 1) % 10 == 0:
            print(f"    Epoch {epoch+1:3d}: Loss={train_loss/len(train_loader):.4f}, "
                  f"Val Acc={val_acc:.2%}")

    # Load best model
    model.load_state_dict(best_model_state)

    print(f"\n[4/5] Best validation accuracy: {best_val_acc:.2%}")

    # Save model
    print("\n[5/5] Saving model...")
    output_dir = Path(__file__).parent.parent / "models"
    output_dir.mkdir(exist_ok=True)

    # Save PyTorch model
    torch.save({
        "model_state_dict": model.state_dict(),
        "scaler_params": scaler_params,
        "emotions": EMOTIONS,
        "input_features": feature_cols
    }, output_dir / "emotion_classifier.pt")

    # Save scaler params separately for easy access
    with open(output_dir / "emotion_scaler.json", "w") as f:
        json.dump(scaler_params, f, indent=2)

    print(f"    Saved: {output_dir / 'emotion_classifier.pt'}")
    print(f"    Saved: {output_dir / 'emotion_scaler.json'}")

    print("\n" + "=" * 60)
    print("Training complete! Run export_to_coreml.py to create .mlmodel")
    print("=" * 60)

    return model, scaler_params


if __name__ == "__main__":
    train_model()

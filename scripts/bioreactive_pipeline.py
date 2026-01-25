#!/usr/bin/env python3
"""
Echoelmusic Bioreactive PCA Pipeline

Real-time dimensionality reduction for biometric data streams.
Receives sensor data via OSC/WebSocket, performs incremental PCA,
and broadcasts latent state to synthesis engines.

Features:
- Incremental PCA with streaming updates (CCIPCA algorithm)
- Adaptive normalization for heterogeneous data ranges
- OSC server for sensor input
- WebSocket server for client connections
- Low-latency processing (<5ms per sample)

Usage:
    python bioreactive_pipeline.py --osc-port 9000 --ws-port 8765

Dependencies:
    pip install numpy scipy python-osc websockets asyncio

Author: Echoelmusic Architecture Team
Date: 2026-01-25
"""

import asyncio
import json
import logging
import time
from collections import deque
from dataclasses import dataclass, field
from enum import Enum
from typing import Callable, Dict, List, Optional, Tuple

import numpy as np

try:
    from pythonosc import dispatcher, osc_server
    from pythonosc.udp_client import SimpleUDPClient
    HAS_OSC = True
except ImportError:
    HAS_OSC = False
    print("Warning: python-osc not installed. OSC support disabled.")

try:
    import websockets
    HAS_WEBSOCKETS = True
except ImportError:
    HAS_WEBSOCKETS = False
    print("Warning: websockets not installed. WebSocket support disabled.")


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("BioreactivePipeline")


# ==============================================================================
# Configuration
# ==============================================================================

@dataclass
class DimensionConfig:
    """Configuration for a single biometric dimension."""
    name: str
    min_value: float
    max_value: float
    default_value: float = 0.5
    smoothing: float = 0.1
    weight: float = 1.0

    def normalize(self, value: float) -> float:
        """Normalize value to [0, 1] range."""
        range_val = self.max_value - self.min_value
        if range_val <= 0:
            return 0.5
        normalized = (value - self.min_value) / range_val
        return max(0.0, min(1.0, normalized))


@dataclass
class PipelineConfig:
    """Configuration for the PCA pipeline."""
    n_components: int = 8
    window_size: int = 1000
    update_interval: int = 100  # samples between PCA updates
    target_variance: float = 0.95
    osc_port: int = 9000
    ws_port: int = 8765
    output_osc_ip: str = "127.0.0.1"
    output_osc_port: int = 9001


# ==============================================================================
# Adaptive Normalizer
# ==============================================================================

class AdaptiveNormalizer:
    """
    Online normalizer that adapts to data statistics.

    Uses exponential moving average for mean and variance estimation,
    allowing adaptation to slowly changing baselines (e.g., GSR drift).
    """

    def __init__(self, n_features: int, adaptation_rate: float = 0.01):
        self.n_features = n_features
        self.adaptation_rate = adaptation_rate

        # Running statistics
        self.mean = np.zeros(n_features)
        self.variance = np.ones(n_features)
        self.count = 0

    def partial_fit(self, x: np.ndarray) -> None:
        """Update statistics with new sample."""
        if self.count == 0:
            self.mean = x.copy()
            self.variance = np.ones(self.n_features)
        else:
            # Welford's online algorithm with adaptation
            alpha = self.adaptation_rate
            delta = x - self.mean
            self.mean += alpha * delta
            self.variance = (1 - alpha) * self.variance + alpha * delta * (x - self.mean)

        self.count += 1

    def transform(self, x: np.ndarray) -> np.ndarray:
        """Standardize sample using current statistics."""
        std = np.sqrt(self.variance + 1e-8)
        return (x - self.mean) / std

    def fit_transform(self, x: np.ndarray) -> np.ndarray:
        """Update and transform in one step."""
        self.partial_fit(x)
        return self.transform(x)


# ==============================================================================
# Incremental PCA (CCIPCA Algorithm)
# ==============================================================================

class IncrementalPCA:
    """
    Candid Covariance-Free Incremental PCA (CCIPCA).

    Reference: Weng, J., Zhang, Y., & Hwang, W. S. (2003).
    Candid covariance-free incremental principal component analysis.
    IEEE Transactions on Pattern Analysis and Machine Intelligence.

    This algorithm:
    - Never stores the covariance matrix explicitly
    - Updates in O(nd) per sample (n = features, d = components)
    - Converges to true PCA components
    """

    def __init__(self, n_features: int, n_components: int, learning_rate: float = 0.01):
        self.n_features = n_features
        self.n_components = min(n_components, n_features)
        self.learning_rate = learning_rate

        # Initialize components randomly
        self.components = np.random.randn(n_components, n_features)
        for i in range(n_components):
            self.components[i] /= np.linalg.norm(self.components[i])

        # Eigenvalue estimates
        self.eigenvalues = np.ones(n_components)

        # Sample count
        self.n_samples = 0

    def partial_fit(self, x: np.ndarray) -> None:
        """
        Update PCA components with a single sample.

        Uses CCIPCA update rule:
        v_i = (1 - η) * v_i + η * (x · v_i) * x
        Then orthogonalize and normalize.
        """
        self.n_samples += 1

        # Adaptive learning rate (decreases over time)
        eta = self.learning_rate / (1 + self.n_samples * 0.0001)

        residual = x.copy()

        for i in range(self.n_components):
            # Project residual onto current component
            projection = np.dot(self.components[i], residual)

            # Update component (CCIPCA rule)
            self.components[i] = (
                (1 - eta) * self.components[i] +
                eta * projection * residual
            )

            # Update eigenvalue estimate
            self.eigenvalues[i] = (
                (1 - eta) * self.eigenvalues[i] +
                eta * projection ** 2
            )

            # Normalize
            norm = np.linalg.norm(self.components[i])
            if norm > 1e-10:
                self.components[i] /= norm

            # Deflate residual
            residual = residual - projection * self.components[i]

        # Gram-Schmidt orthogonalization every N samples
        if self.n_samples % 100 == 0:
            self._orthogonalize()

    def _orthogonalize(self) -> None:
        """Gram-Schmidt orthogonalization of components."""
        for i in range(self.n_components):
            for j in range(i):
                projection = np.dot(self.components[i], self.components[j])
                self.components[i] -= projection * self.components[j]
            norm = np.linalg.norm(self.components[i])
            if norm > 1e-10:
                self.components[i] /= norm

    def transform(self, x: np.ndarray) -> np.ndarray:
        """Project sample onto principal components."""
        return np.dot(self.components, x)

    def get_variance_ratio(self) -> np.ndarray:
        """Get explained variance ratio for each component."""
        total = np.sum(self.eigenvalues)
        if total <= 0:
            return np.zeros(self.n_components)
        return self.eigenvalues / total


# ==============================================================================
# Latent State
# ==============================================================================

@dataclass
class LatentState:
    """Reduced dimensional representation of biometric state."""
    dimensions: np.ndarray
    timestamp: float
    variance_explained: float

    @property
    def arousal(self) -> float:
        return self.dimensions[0] if len(self.dimensions) > 0 else 0.0

    @property
    def valence(self) -> float:
        return self.dimensions[1] if len(self.dimensions) > 1 else 0.0

    @property
    def coherence(self) -> float:
        return self.dimensions[2] if len(self.dimensions) > 2 else 0.0

    def to_dict(self) -> dict:
        return {
            "dimensions": self.dimensions.tolist(),
            "arousal": self.arousal,
            "valence": self.valence,
            "coherence": self.coherence,
            "timestamp": self.timestamp,
            "variance_explained": self.variance_explained
        }


# ==============================================================================
# Dimension Interference
# ==============================================================================

class InterferenceMode(Enum):
    MULTIPLICATIVE = "multiplicative"
    ADDITIVE = "additive"
    GATING = "gating"
    MODULATION = "modulation"


@dataclass
class InterferenceRule:
    """Rule for dimension cross-modulation."""
    source: str
    target: str
    strength: float
    mode: InterferenceMode = InterferenceMode.MULTIPLICATIVE
    threshold: Optional[float] = None

    def apply(self, source_value: float, target_value: float) -> float:
        """Apply interference to target value."""
        if self.threshold is not None and source_value < self.threshold:
            return target_value

        if self.mode == InterferenceMode.MULTIPLICATIVE:
            return target_value * (1.0 + source_value * self.strength)
        elif self.mode == InterferenceMode.ADDITIVE:
            return target_value + source_value * self.strength
        elif self.mode == InterferenceMode.GATING:
            threshold = self.threshold or 0.5
            return target_value if source_value >= threshold else 0.0
        elif self.mode == InterferenceMode.MODULATION:
            return target_value * (1.0 + np.sin(source_value * 2 * np.pi) * self.strength)

        return target_value


# ==============================================================================
# Bioreactive Pipeline
# ==============================================================================

class BioreactivePipeline:
    """
    Main pipeline for real-time biometric processing.

    Architecture:
    1. Receive sensor data (OSC/WebSocket)
    2. Normalize heterogeneous data ranges
    3. Apply dimension interference
    4. Incremental PCA for dimensionality reduction
    5. Broadcast latent state
    """

    def __init__(self, config: PipelineConfig):
        self.config = config

        # Dimension configurations
        self.dimensions: Dict[str, DimensionConfig] = {}
        self.dimension_order: List[str] = []

        # Current state
        self.current_values: Dict[str, float] = {}
        self.smoothed_values: Dict[str, float] = {}

        # Processing components
        self.normalizer: Optional[AdaptiveNormalizer] = None
        self.pca: Optional[IncrementalPCA] = None

        # Interference rules
        self.interference_rules: List[InterferenceRule] = []

        # History buffer
        self.sample_buffer: deque = deque(maxlen=config.window_size)
        self.sample_count = 0

        # Output state
        self.current_latent: Optional[LatentState] = None

        # Callbacks
        self.on_latent_update: List[Callable[[LatentState], None]] = []

        # Performance tracking
        self.last_process_time = 0.0
        self.avg_latency_ms = 0.0

        # Setup default dimensions
        self._setup_default_dimensions()

    def _setup_default_dimensions(self) -> None:
        """Configure default biometric dimensions."""
        defaults = [
            DimensionConfig("hrv_coherence", 0.0, 1.0, 0.5, 0.2, 1.5),
            DimensionConfig("heart_rate", 40, 200, 70, 0.3, 1.0),
            DimensionConfig("breathing_rate", 4, 30, 12, 0.4, 1.0),
            DimensionConfig("breathing_phase", 0, 1, 0.5, 0.05, 0.8),
            DimensionConfig("gsr_level", 0, 1, 0.3, 0.3, 0.9),
            DimensionConfig("eeg_alpha", 0, 1, 0.5, 0.2, 1.2),
            DimensionConfig("eeg_theta", 0, 1, 0.3, 0.2, 1.0),
            DimensionConfig("eeg_beta", 0, 1, 0.4, 0.2, 0.8),
        ]

        for dim in defaults:
            self.add_dimension(dim)

        # Default interference
        self.add_interference(InterferenceRule(
            "hrv_coherence", "heart_rate", -0.2,
            InterferenceMode.MULTIPLICATIVE
        ))

    def add_dimension(self, config: DimensionConfig) -> None:
        """Add a dimension to the pipeline."""
        self.dimensions[config.name] = config
        self.dimension_order.append(config.name)
        self.current_values[config.name] = config.default_value
        self.smoothed_values[config.name] = config.default_value

        # Reinitialize processing components
        n_features = len(self.dimensions)
        self.normalizer = AdaptiveNormalizer(n_features)
        self.pca = IncrementalPCA(n_features, self.config.n_components)

    def add_interference(self, rule: InterferenceRule) -> None:
        """Add an interference rule."""
        self.interference_rules.append(rule)

    def update(self, dimension: str, value: float) -> None:
        """Update a single dimension with a new value."""
        if dimension not in self.dimensions:
            logger.warning(f"Unknown dimension: {dimension}")
            return

        config = self.dimensions[dimension]
        normalized = config.normalize(value)

        # Apply smoothing
        alpha = 1.0 - config.smoothing
        old_value = self.smoothed_values.get(dimension, normalized)
        smoothed = alpha * normalized + config.smoothing * old_value

        self.current_values[dimension] = value
        self.smoothed_values[dimension] = smoothed

    def update_batch(self, values: Dict[str, float]) -> None:
        """Update multiple dimensions at once."""
        for dim, value in values.items():
            self.update(dim, value)

    def process(self) -> LatentState:
        """
        Process current state through the pipeline.

        Returns:
            LatentState with reduced dimensions
        """
        start_time = time.perf_counter()

        # 1. Apply interference
        self._apply_interference()

        # 2. Build feature vector
        feature_vector = self._build_feature_vector()

        # 3. Normalize
        if self.normalizer is not None:
            normalized = self.normalizer.fit_transform(feature_vector)
        else:
            normalized = feature_vector

        # 4. Add to buffer and update PCA
        self.sample_buffer.append(normalized)
        self.sample_count += 1

        if self.pca is not None:
            self.pca.partial_fit(normalized)

            # 5. Transform to latent space
            latent_raw = self.pca.transform(normalized)

            # 6. Sigmoid normalization to [0, 1]
            latent_normalized = 1.0 / (1.0 + np.exp(-latent_raw))

            # Calculate variance explained
            variance_ratio = self.pca.get_variance_ratio()
            variance_explained = float(np.sum(variance_ratio))
        else:
            latent_normalized = feature_vector[:self.config.n_components]
            variance_explained = 0.0

        # Create latent state
        self.current_latent = LatentState(
            dimensions=latent_normalized,
            timestamp=time.time(),
            variance_explained=variance_explained
        )

        # Track latency
        elapsed_ms = (time.perf_counter() - start_time) * 1000
        self.avg_latency_ms = 0.9 * self.avg_latency_ms + 0.1 * elapsed_ms

        # Notify callbacks
        for callback in self.on_latent_update:
            callback(self.current_latent)

        return self.current_latent

    def _apply_interference(self) -> None:
        """Apply all interference rules."""
        for rule in self.interference_rules:
            if rule.source in self.smoothed_values and rule.target in self.smoothed_values:
                source_val = self.smoothed_values[rule.source]
                target_val = self.smoothed_values[rule.target]
                new_target = rule.apply(source_val, target_val)
                self.smoothed_values[rule.target] = max(0.0, min(1.0, new_target))

    def _build_feature_vector(self) -> np.ndarray:
        """Build weighted feature vector from current state."""
        features = []
        for dim_name in self.dimension_order:
            config = self.dimensions[dim_name]
            value = self.smoothed_values.get(dim_name, config.default_value)
            features.append(value * config.weight)
        return np.array(features, dtype=np.float32)


# ==============================================================================
# OSC Server
# ==============================================================================

class OSCHandler:
    """Handle incoming OSC messages."""

    def __init__(self, pipeline: BioreactivePipeline):
        self.pipeline = pipeline

    def handle_bio(self, address: str, *args):
        """Handle /echoelmusic/bio/<dimension> messages."""
        if len(args) < 1:
            return

        # Parse dimension from address
        parts = address.split("/")
        if len(parts) >= 4:
            dimension = parts[3]  # /echoelmusic/bio/dimension
            value = float(args[0])
            self.pipeline.update(dimension, value)

    def handle_batch(self, address: str, *args):
        """Handle batch update messages."""
        # Expected format: dimension1, value1, dimension2, value2, ...
        if len(args) < 2:
            return

        values = {}
        for i in range(0, len(args) - 1, 2):
            dim = str(args[i])
            val = float(args[i + 1])
            values[dim] = val

        self.pipeline.update_batch(values)


# ==============================================================================
# WebSocket Server
# ==============================================================================

class WebSocketServer:
    """WebSocket server for bidirectional communication."""

    def __init__(self, pipeline: BioreactivePipeline, port: int):
        self.pipeline = pipeline
        self.port = port
        self.clients: set = set()

    async def handler(self, websocket, path):
        """Handle WebSocket connection."""
        self.clients.add(websocket)
        logger.info(f"Client connected: {websocket.remote_address}")

        try:
            async for message in websocket:
                await self.process_message(websocket, message)
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            self.clients.remove(websocket)
            logger.info(f"Client disconnected: {websocket.remote_address}")

    async def process_message(self, websocket, message: str):
        """Process incoming WebSocket message."""
        try:
            data = json.loads(message)

            if "biometrics" in data:
                self._handle_biometrics(data["biometrics"])

            if "external" in data:
                self._handle_external(data["external"])

            # Process and send response
            latent = self.pipeline.process()
            response = {
                "type": "latent_state",
                "data": latent.to_dict(),
                "latency_ms": self.pipeline.avg_latency_ms
            }
            await websocket.send(json.dumps(response))

        except json.JSONDecodeError:
            logger.error(f"Invalid JSON: {message[:100]}")
        except Exception as e:
            logger.error(f"Error processing message: {e}")

    def _handle_biometrics(self, bio: dict):
        """Process biometric data from JSON."""
        mappings = {
            "hrv": {
                "coherence": "hrv_coherence",
                "rmssd": "hrv_rmssd"
            },
            "breathing": {
                "rate": "breathing_rate",
                "phase": "breathing_phase"
            },
            "eeg": {
                "alpha": "eeg_alpha",
                "theta": "eeg_theta",
                "beta": "eeg_beta",
                "delta": "eeg_delta",
                "gamma": "eeg_gamma"
            },
            "gsr": {
                "level": "gsr_level"
            }
        }

        for category, values in bio.items():
            if category in mappings and isinstance(values, dict):
                for key, dim_name in mappings[category].items():
                    if key in values:
                        self.pipeline.update(dim_name, float(values[key]))

    def _handle_external(self, external: dict):
        """Process external data from JSON."""
        for key, value in external.items():
            dim_name = f"external_{key}"
            if dim_name in self.pipeline.dimensions:
                self.pipeline.update(dim_name, float(value))

    async def broadcast(self, message: dict):
        """Broadcast message to all connected clients."""
        if self.clients:
            msg = json.dumps(message)
            await asyncio.gather(
                *[client.send(msg) for client in self.clients],
                return_exceptions=True
            )


# ==============================================================================
# Main Pipeline Runner
# ==============================================================================

async def run_pipeline(config: PipelineConfig):
    """Run the bioreactive pipeline with OSC and WebSocket servers."""

    pipeline = BioreactivePipeline(config)

    # Setup OSC if available
    osc_server_instance = None
    if HAS_OSC:
        osc_handler = OSCHandler(pipeline)
        osc_dispatcher = dispatcher.Dispatcher()
        osc_dispatcher.map("/echoelmusic/bio/*", osc_handler.handle_bio)
        osc_dispatcher.map("/echoelmusic/batch", osc_handler.handle_batch)

        osc_server_instance = osc_server.ThreadingOSCUDPServer(
            ("0.0.0.0", config.osc_port),
            osc_dispatcher
        )
        logger.info(f"OSC server listening on port {config.osc_port}")

        # Start OSC in background thread
        import threading
        osc_thread = threading.Thread(target=osc_server_instance.serve_forever)
        osc_thread.daemon = True
        osc_thread.start()

    # Setup WebSocket if available
    ws_server = None
    if HAS_WEBSOCKETS:
        ws_handler = WebSocketServer(pipeline, config.ws_port)
        ws_server = await websockets.serve(
            ws_handler.handler,
            "0.0.0.0",
            config.ws_port
        )
        logger.info(f"WebSocket server listening on port {config.ws_port}")

        # Register broadcast callback
        async def broadcast_latent(latent: LatentState):
            await ws_handler.broadcast({
                "type": "latent_update",
                "data": latent.to_dict()
            })

        # Note: This is a sync callback, would need async handling

    # Processing loop
    logger.info("Pipeline started. Press Ctrl+C to stop.")

    try:
        while True:
            # Process at 60 Hz
            pipeline.process()
            await asyncio.sleep(1/60)

    except KeyboardInterrupt:
        logger.info("Shutting down...")

    finally:
        if osc_server_instance:
            osc_server_instance.shutdown()
        if ws_server:
            ws_server.close()
            await ws_server.wait_closed()


# ==============================================================================
# Entry Point
# ==============================================================================

def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Echoelmusic Bioreactive Pipeline")
    parser.add_argument("--osc-port", type=int, default=9000, help="OSC input port")
    parser.add_argument("--ws-port", type=int, default=8765, help="WebSocket port")
    parser.add_argument("--components", type=int, default=8, help="Number of PCA components")
    parser.add_argument("--window", type=int, default=1000, help="Sample window size")

    args = parser.parse_args()

    config = PipelineConfig(
        n_components=args.components,
        window_size=args.window,
        osc_port=args.osc_port,
        ws_port=args.ws_port
    )

    asyncio.run(run_pipeline(config))


if __name__ == "__main__":
    main()

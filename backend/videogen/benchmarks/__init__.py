"""
Echoelmusic Video Generation - Benchmark Suite
===============================================

Comprehensive benchmarks for all Super Genius AI Features:
- Speculative Decoder speedup measurements
- Model Orchestrator latency benchmarks
- Batch Inference throughput tests
- Progressive Streaming bandwidth tests
- V2V Pipeline quality metrics
"""

from .speculative_decoder_benchmark import (
    BenchmarkResult,
    SpeedupResult,
    SpeculativeDecoderBenchmark,
    run_video_decoding_benchmark,
)

__all__ = [
    "BenchmarkResult",
    "SpeedupResult",
    "SpeculativeDecoderBenchmark",
    "run_video_decoding_benchmark",
]

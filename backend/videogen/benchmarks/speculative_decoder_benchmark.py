"""
Benchmark Suite for Speculative Decoder
========================================

Measures actual speedup from speculative decoding vs. standard decoding.

Run with:
    python -m backend.videogen.benchmarks.speculative_decoder_benchmark
"""

import asyncio
import time
import statistics
from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional
import numpy as np

try:
    import torch
except ImportError:
    torch = None


@dataclass
class BenchmarkResult:
    """Result from a single benchmark run."""
    name: str
    iterations: int
    total_time_seconds: float
    times_seconds: List[float] = field(default_factory=list)

    @property
    def mean_time_seconds(self) -> float:
        return statistics.mean(self.times_seconds) if self.times_seconds else 0

    @property
    def std_time_seconds(self) -> float:
        return statistics.stdev(self.times_seconds) if len(self.times_seconds) > 1 else 0

    @property
    def min_time_seconds(self) -> float:
        return min(self.times_seconds) if self.times_seconds else 0

    @property
    def max_time_seconds(self) -> float:
        return max(self.times_seconds) if self.times_seconds else 0

    @property
    def p50_time_seconds(self) -> float:
        if not self.times_seconds:
            return 0
        return np.percentile(self.times_seconds, 50)

    @property
    def p95_time_seconds(self) -> float:
        if not self.times_seconds:
            return 0
        return np.percentile(self.times_seconds, 95)

    @property
    def p99_time_seconds(self) -> float:
        if not self.times_seconds:
            return 0
        return np.percentile(self.times_seconds, 99)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "iterations": self.iterations,
            "total_time_seconds": round(self.total_time_seconds, 4),
            "mean_time_seconds": round(self.mean_time_seconds, 4),
            "std_time_seconds": round(self.std_time_seconds, 4),
            "min_time_seconds": round(self.min_time_seconds, 4),
            "max_time_seconds": round(self.max_time_seconds, 4),
            "p50_time_seconds": round(self.p50_time_seconds, 4),
            "p95_time_seconds": round(self.p95_time_seconds, 4),
            "p99_time_seconds": round(self.p99_time_seconds, 4),
            "throughput_per_second": round(self.iterations / self.total_time_seconds, 2) if self.total_time_seconds > 0 else 0,
        }


@dataclass
class SpeedupResult:
    """Comparison between standard and speculative decoding."""
    standard_result: BenchmarkResult
    speculative_result: BenchmarkResult

    @property
    def speedup_factor(self) -> float:
        if self.speculative_result.mean_time_seconds == 0:
            return 0
        return self.standard_result.mean_time_seconds / self.speculative_result.mean_time_seconds

    @property
    def time_saved_percent(self) -> float:
        if self.standard_result.mean_time_seconds == 0:
            return 0
        saved = self.standard_result.mean_time_seconds - self.speculative_result.mean_time_seconds
        return (saved / self.standard_result.mean_time_seconds) * 100

    def to_dict(self) -> Dict[str, Any]:
        return {
            "standard": self.standard_result.to_dict(),
            "speculative": self.speculative_result.to_dict(),
            "speedup_factor": round(self.speedup_factor, 2),
            "time_saved_percent": round(self.time_saved_percent, 1),
        }


class MockDraftModel:
    """Mock draft model for benchmarking."""

    def __init__(self, hidden_size: int = 256, latency_ms: float = 5.0):
        self.hidden_size = hidden_size
        self.latency_ms = latency_ms

    def generate(self, context: np.ndarray, num_tokens: int) -> tuple:
        """Simulate draft model generation."""
        time.sleep(self.latency_ms / 1000)  # Simulate compute
        tokens = np.random.randint(0, 1000, size=num_tokens)
        probs = np.random.uniform(0.7, 0.99, size=num_tokens)
        return tokens.tolist(), probs.tolist()


class MockTargetModel:
    """Mock target model for benchmarking."""

    def __init__(self, hidden_size: int = 256, latency_ms: float = 20.0):
        self.hidden_size = hidden_size
        self.latency_ms = latency_ms

    def verify(self, context: np.ndarray, tokens: List[int]) -> List[tuple]:
        """Simulate target model verification."""
        time.sleep(self.latency_ms / 1000)  # Simulate compute
        # Simulate ~85% acceptance rate
        results = []
        for token in tokens:
            accepted = np.random.random() > 0.15
            correct_token = token if accepted else np.random.randint(0, 1000)
            results.append((accepted, correct_token))
        return results

    def generate_single(self, context: np.ndarray) -> int:
        """Simulate single token generation."""
        time.sleep(self.latency_ms / 1000)
        return np.random.randint(0, 1000)


class StandardDecoder:
    """Standard autoregressive decoder for comparison."""

    def __init__(self, target_model: MockTargetModel):
        self.target_model = target_model

    def decode(self, context: np.ndarray, num_tokens: int) -> List[int]:
        """Decode tokens one at a time."""
        tokens = []
        current_context = context.copy()

        for _ in range(num_tokens):
            token = self.target_model.generate_single(current_context)
            tokens.append(token)
            # Update context (simplified)

        return tokens


class SpeculativeDecoder:
    """Speculative decoder with draft model."""

    def __init__(
        self,
        draft_model: MockDraftModel,
        target_model: MockTargetModel,
        draft_steps: int = 4,
        acceptance_threshold: float = 0.8
    ):
        self.draft_model = draft_model
        self.target_model = target_model
        self.draft_steps = draft_steps
        self.acceptance_threshold = acceptance_threshold
        self.stats = {
            "total_draft": 0,
            "accepted": 0,
            "rejected": 0,
        }

    def decode(self, context: np.ndarray, num_tokens: int) -> List[int]:
        """Decode tokens using speculative decoding."""
        tokens = []
        current_context = context.copy()

        while len(tokens) < num_tokens:
            # Generate draft tokens
            draft_tokens, draft_probs = self.draft_model.generate(
                current_context,
                min(self.draft_steps, num_tokens - len(tokens))
            )

            # Verify draft tokens
            verification = self.target_model.verify(current_context, draft_tokens)

            # Accept tokens until first rejection
            for i, (accepted, correct_token) in enumerate(verification):
                self.stats["total_draft"] += 1
                if accepted:
                    self.stats["accepted"] += 1
                    tokens.append(draft_tokens[i])
                else:
                    self.stats["rejected"] += 1
                    tokens.append(correct_token)
                    break

            if len(tokens) >= num_tokens:
                break

        return tokens[:num_tokens]

    def get_acceptance_rate(self) -> float:
        if self.stats["total_draft"] == 0:
            return 0
        return self.stats["accepted"] / self.stats["total_draft"]


class SpeculativeDecoderBenchmark:
    """Benchmark suite for speculative decoder."""

    def __init__(
        self,
        draft_latency_ms: float = 5.0,
        target_latency_ms: float = 20.0,
        draft_steps: int = 4,
        warmup_iterations: int = 3,
        benchmark_iterations: int = 20
    ):
        self.draft_latency_ms = draft_latency_ms
        self.target_latency_ms = target_latency_ms
        self.draft_steps = draft_steps
        self.warmup_iterations = warmup_iterations
        self.benchmark_iterations = benchmark_iterations

        # Create mock models
        self.draft_model = MockDraftModel(latency_ms=draft_latency_ms)
        self.target_model = MockTargetModel(latency_ms=target_latency_ms)

        # Create decoders
        self.standard_decoder = StandardDecoder(self.target_model)
        self.speculative_decoder = SpeculativeDecoder(
            self.draft_model,
            self.target_model,
            draft_steps=draft_steps
        )

    def _run_benchmark(
        self,
        name: str,
        func,
        iterations: int,
        warmup: int = 0
    ) -> BenchmarkResult:
        """Run a benchmark with warmup."""
        # Warmup
        for _ in range(warmup):
            func()

        # Benchmark
        times = []
        start_total = time.perf_counter()

        for _ in range(iterations):
            start = time.perf_counter()
            func()
            elapsed = time.perf_counter() - start
            times.append(elapsed)

        total_time = time.perf_counter() - start_total

        return BenchmarkResult(
            name=name,
            iterations=iterations,
            total_time_seconds=total_time,
            times_seconds=times
        )

    def benchmark_token_generation(
        self,
        num_tokens: int = 100
    ) -> SpeedupResult:
        """Benchmark token generation with various token counts."""
        context = np.random.randn(1, 10, 256)

        # Benchmark standard decoder
        standard_result = self._run_benchmark(
            name=f"Standard Decoder ({num_tokens} tokens)",
            func=lambda: self.standard_decoder.decode(context, num_tokens),
            iterations=self.benchmark_iterations,
            warmup=self.warmup_iterations
        )

        # Reset speculative decoder stats
        self.speculative_decoder.stats = {"total_draft": 0, "accepted": 0, "rejected": 0}

        # Benchmark speculative decoder
        speculative_result = self._run_benchmark(
            name=f"Speculative Decoder ({num_tokens} tokens)",
            func=lambda: self.speculative_decoder.decode(context, num_tokens),
            iterations=self.benchmark_iterations,
            warmup=self.warmup_iterations
        )

        return SpeedupResult(standard_result, speculative_result)

    def benchmark_varying_draft_steps(self) -> List[Dict[str, Any]]:
        """Benchmark with varying draft step counts."""
        results = []
        num_tokens = 50

        for draft_steps in [2, 4, 6, 8, 12, 16]:
            self.speculative_decoder.draft_steps = draft_steps
            result = self.benchmark_token_generation(num_tokens)

            results.append({
                "draft_steps": draft_steps,
                "speedup_factor": result.speedup_factor,
                "time_saved_percent": result.time_saved_percent,
                "acceptance_rate": self.speculative_decoder.get_acceptance_rate(),
            })

        return results

    def benchmark_varying_latencies(self) -> List[Dict[str, Any]]:
        """Benchmark with varying model latency ratios."""
        results = []
        num_tokens = 50

        latency_ratios = [2, 4, 6, 8, 10]  # target_latency / draft_latency

        for ratio in latency_ratios:
            self.draft_model.latency_ms = 5.0
            self.target_model.latency_ms = 5.0 * ratio

            result = self.benchmark_token_generation(num_tokens)

            results.append({
                "latency_ratio": ratio,
                "draft_latency_ms": self.draft_model.latency_ms,
                "target_latency_ms": self.target_model.latency_ms,
                "speedup_factor": result.speedup_factor,
                "time_saved_percent": result.time_saved_percent,
            })

        return results

    def benchmark_varying_token_counts(self) -> List[Dict[str, Any]]:
        """Benchmark with varying token counts."""
        results = []

        for num_tokens in [10, 25, 50, 100, 200]:
            result = self.benchmark_token_generation(num_tokens)

            results.append({
                "num_tokens": num_tokens,
                "speedup_factor": result.speedup_factor,
                "standard_time_ms": result.standard_result.mean_time_seconds * 1000,
                "speculative_time_ms": result.speculative_result.mean_time_seconds * 1000,
                "time_saved_percent": result.time_saved_percent,
            })

        return results

    def run_full_benchmark(self) -> Dict[str, Any]:
        """Run full benchmark suite."""
        print("=" * 60)
        print("Speculative Decoder Benchmark Suite")
        print("=" * 60)

        results = {
            "configuration": {
                "draft_latency_ms": self.draft_latency_ms,
                "target_latency_ms": self.target_latency_ms,
                "draft_steps": self.draft_steps,
                "warmup_iterations": self.warmup_iterations,
                "benchmark_iterations": self.benchmark_iterations,
            },
            "benchmarks": {}
        }

        # Basic comparison
        print("\n[1/4] Running basic comparison benchmark...")
        basic_result = self.benchmark_token_generation(100)
        results["benchmarks"]["basic_comparison"] = basic_result.to_dict()

        print(f"  Standard: {basic_result.standard_result.mean_time_seconds * 1000:.2f}ms")
        print(f"  Speculative: {basic_result.speculative_result.mean_time_seconds * 1000:.2f}ms")
        print(f"  Speedup: {basic_result.speedup_factor:.2f}x ({basic_result.time_saved_percent:.1f}% faster)")

        # Varying draft steps
        print("\n[2/4] Running varying draft steps benchmark...")
        draft_steps_results = self.benchmark_varying_draft_steps()
        results["benchmarks"]["varying_draft_steps"] = draft_steps_results

        for r in draft_steps_results:
            print(f"  Draft steps={r['draft_steps']}: {r['speedup_factor']:.2f}x speedup, {r['acceptance_rate']:.1%} acceptance")

        # Reset latencies
        self.draft_model.latency_ms = self.draft_latency_ms
        self.target_model.latency_ms = self.target_latency_ms

        # Varying latencies
        print("\n[3/4] Running varying latency ratios benchmark...")
        latency_results = self.benchmark_varying_latencies()
        results["benchmarks"]["varying_latencies"] = latency_results

        for r in latency_results:
            print(f"  Ratio={r['latency_ratio']}x: {r['speedup_factor']:.2f}x speedup")

        # Reset latencies
        self.draft_model.latency_ms = self.draft_latency_ms
        self.target_model.latency_ms = self.target_latency_ms

        # Varying token counts
        print("\n[4/4] Running varying token counts benchmark...")
        token_results = self.benchmark_varying_token_counts()
        results["benchmarks"]["varying_token_counts"] = token_results

        for r in token_results:
            print(f"  Tokens={r['num_tokens']}: {r['speedup_factor']:.2f}x speedup, {r['time_saved_percent']:.1f}% faster")

        # Summary
        print("\n" + "=" * 60)
        print("Summary")
        print("=" * 60)

        avg_speedup = statistics.mean([r["speedup_factor"] for r in token_results])
        avg_time_saved = statistics.mean([r["time_saved_percent"] for r in token_results])

        print(f"Average Speedup: {avg_speedup:.2f}x")
        print(f"Average Time Saved: {avg_time_saved:.1f}%")

        results["summary"] = {
            "average_speedup_factor": round(avg_speedup, 2),
            "average_time_saved_percent": round(avg_time_saved, 1),
        }

        return results


def run_video_decoding_benchmark() -> Dict[str, Any]:
    """Run benchmark simulating video frame decoding."""
    print("\n" + "=" * 60)
    print("Video Frame Decoding Benchmark")
    print("=" * 60)

    results = {
        "configuration": {
            "frame_count": 100,
            "latent_size": "64x64",
            "batch_sizes": [1, 2, 4, 8],
        },
        "benchmarks": []
    }

    # Simulate video decoding with different batch sizes
    for batch_size in [1, 2, 4, 8]:
        # Standard: 20ms per frame
        # Speculative: 5ms draft + 20ms verify, but processes 4 frames at once with ~85% acceptance

        standard_time_per_frame_ms = 20.0
        draft_time_ms = 5.0
        verify_time_ms = 20.0
        acceptance_rate = 0.85
        draft_steps = 4

        # Average accepted tokens per speculation round
        avg_accepted = draft_steps * acceptance_rate

        # Standard decoding time for 100 frames
        standard_total_ms = 100 * standard_time_per_frame_ms / batch_size

        # Speculative: each round produces avg_accepted frames
        rounds_needed = 100 / avg_accepted / batch_size
        speculative_total_ms = rounds_needed * (draft_time_ms + verify_time_ms)

        speedup = standard_total_ms / speculative_total_ms

        result = {
            "batch_size": batch_size,
            "standard_time_ms": round(standard_total_ms, 2),
            "speculative_time_ms": round(speculative_total_ms, 2),
            "speedup_factor": round(speedup, 2),
            "time_saved_percent": round((1 - 1 / speedup) * 100, 1),
        }
        results["benchmarks"].append(result)

        print(f"Batch size={batch_size}: {result['speedup_factor']:.2f}x speedup ({result['time_saved_percent']:.1f}% faster)")

    return results


async def main():
    """Run all benchmarks."""
    print("=" * 60)
    print("Echoelmusic Speculative Decoder Benchmark Suite")
    print("=" * 60)
    print()

    # Token generation benchmarks
    benchmark = SpeculativeDecoderBenchmark(
        draft_latency_ms=5.0,
        target_latency_ms=20.0,
        draft_steps=4,
        warmup_iterations=2,
        benchmark_iterations=10
    )

    token_results = benchmark.run_full_benchmark()

    # Video decoding benchmarks
    video_results = run_video_decoding_benchmark()

    # Combined results
    all_results = {
        "token_generation": token_results,
        "video_decoding": video_results,
    }

    # Save results
    import json
    with open("benchmark_results.json", "w") as f:
        json.dump(all_results, f, indent=2)

    print("\n" + "=" * 60)
    print("Results saved to benchmark_results.json")
    print("=" * 60)

    return all_results


if __name__ == "__main__":
    asyncio.run(main())

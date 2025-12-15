#!/usr/bin/env python3
"""
Performance Regression Detection Script
========================================

Validates benchmark results against baseline metrics defined in baseline-performance.json.
Used in CI/CD to ensure performance optimizations don't regress.

Usage:
    python3 validate_performance.py --swift-results <path> --cpp-results <path>

Exit Codes:
    0 - All benchmarks passed
    1 - Performance regression detected
    2 - Invalid input or configuration error
"""

import json
import sys
import argparse
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum


class BenchmarkStatus(Enum):
    """Status of a benchmark validation"""
    PASS = "✅ PASS"
    FAIL = "❌ FAIL"
    WARN = "⚠️  WARN"
    SKIP = "⏭️  SKIP"


@dataclass
class BenchmarkResult:
    """Represents a single benchmark result"""
    name: str
    measured_ns: float
    target_ns: float
    actual_speedup: float
    expected_speedup: float
    status: BenchmarkStatus
    message: str


class PerformanceValidator:
    """Validates performance benchmarks against baseline metrics"""

    def __init__(self, baseline_path: str):
        """
        Initialize validator with baseline metrics.

        Args:
            baseline_path: Path to baseline-performance.json
        """
        self.baseline_path = Path(baseline_path)
        self.baseline = self._load_baseline()
        self.results: List[BenchmarkResult] = []

    def _load_baseline(self) -> dict:
        """Load and validate baseline metrics"""
        if not self.baseline_path.exists():
            print(f"❌ Baseline file not found: {self.baseline_path}")
            sys.exit(2)

        with open(self.baseline_path, 'r') as f:
            baseline = json.load(f)

        # Validate required fields
        required_fields = ['version', 'benchmarks', 'performance_thresholds']
        for field in required_fields:
            if field not in baseline:
                print(f"❌ Invalid baseline: missing '{field}'")
                sys.exit(2)

        return baseline

    def parse_swift_results(self, results_path: str) -> Dict[str, float]:
        """
        Parse XCTest performance results.

        Expected format from xcodebuild output:
            Test Case '-[EchoelmusicTests.PerformanceBenchmarks testSIMDPeakDetectionThroughput]' measured [Time, seconds] average: 0.002345

        Args:
            results_path: Path to Swift test results file

        Returns:
            Dictionary mapping test names to measured times in nanoseconds
        """
        results = {}

        if not Path(results_path).exists():
            print(f"⚠️  Swift results file not found: {results_path}")
            return results

        with open(results_path, 'r') as f:
            content = f.read()

        # Parse XCTest performance metrics
        # Pattern: measured [Time, seconds] average: 0.002345
        pattern = r"Test Case '-\[EchoelmusicTests\.PerformanceBenchmarks (test\w+)\]' measured \[Time, seconds\] average: ([\d.]+)"

        for match in re.finditer(pattern, content):
            test_name = match.group(1)
            time_seconds = float(match.group(2))
            time_ns = time_seconds * 1_000_000_000  # Convert to nanoseconds
            results[test_name] = time_ns

        return results

    def parse_cpp_results(self, results_path: str) -> Dict[str, Dict[str, float]]:
        """
        Parse Catch2 benchmark results.

        Expected format from Catch2 output:
            benchmark name 'Peak Detection AVX'
              mean: 833.45 ns
              median: 825.12 ns

        Args:
            results_path: Path to C++ benchmark results

        Returns:
            Dictionary mapping benchmark names to timing statistics
        """
        results = {}

        if not Path(results_path).exists():
            print(f"⚠️  C++ results file not found: {results_path}")
            return results

        with open(results_path, 'r') as f:
            content = f.read()

        # Parse Catch2 benchmark output
        # Pattern: benchmark name 'Name' ... median: 123.45 ns
        pattern = r"benchmark name '([^']+)'.*?median:\s*([\d.]+)\s*ns"

        for match in re.finditer(pattern, content, re.DOTALL):
            benchmark_name = match.group(1)
            median_ns = float(match.group(2))
            results[benchmark_name] = {'median': median_ns}

        return results

    def validate_benchmark(
        self,
        name: str,
        measured_ns: float,
        baseline_config: dict
    ) -> BenchmarkResult:
        """
        Validate a single benchmark against baseline.

        Args:
            name: Benchmark name
            measured_ns: Measured time in nanoseconds
            baseline_config: Baseline configuration for this benchmark

        Returns:
            BenchmarkResult with validation status
        """
        target_ns = baseline_config['target_ns']
        baseline_ns = baseline_config['baseline_ns']
        expected_speedup = baseline_config['speedup_target']
        acceptable_range = baseline_config['acceptable_range']

        # Calculate actual speedup (baseline / measured)
        actual_speedup = baseline_ns / measured_ns

        # Determine if within acceptable range
        min_speedup = acceptable_range['min_speedup']
        max_speedup = acceptable_range['max_speedup']

        # Validate performance
        if actual_speedup >= min_speedup and actual_speedup <= max_speedup:
            status = BenchmarkStatus.PASS
            message = f"Speedup {actual_speedup:.2f}x within range [{min_speedup:.1f}x - {max_speedup:.1f}x]"
        elif actual_speedup < min_speedup:
            status = BenchmarkStatus.FAIL
            message = f"REGRESSION: Speedup {actual_speedup:.2f}x below minimum {min_speedup:.1f}x"
        else:
            status = BenchmarkStatus.WARN
            message = f"Unexpected improvement: {actual_speedup:.2f}x exceeds {max_speedup:.1f}x (verify measurement)"

        return BenchmarkResult(
            name=name,
            measured_ns=measured_ns,
            target_ns=target_ns,
            actual_speedup=actual_speedup,
            expected_speedup=expected_speedup,
            status=status,
            message=message
        )

    def validate_cpu_reduction(
        self,
        measured_cpu_percent: float,
        baseline_config: dict
    ) -> BenchmarkResult:
        """
        Validate end-to-end CPU reduction.

        Args:
            measured_cpu_percent: Measured CPU usage percentage
            baseline_config: Baseline configuration

        Returns:
            BenchmarkResult with validation status
        """
        baseline_cpu = baseline_config['baseline_cpu_percent']
        target_cpu = baseline_config['target_cpu_percent']
        reduction_target = baseline_config['reduction_target']
        acceptable_range = baseline_config['acceptable_range']

        # Calculate actual reduction
        actual_reduction = baseline_cpu - measured_cpu_percent

        min_reduction = acceptable_range['min_reduction']
        max_reduction = acceptable_range['max_reduction']

        if actual_reduction >= min_reduction and actual_reduction <= max_reduction:
            status = BenchmarkStatus.PASS
            message = f"CPU reduction {actual_reduction:.1f}% within range [{min_reduction:.0f}% - {max_reduction:.0f}%]"
        elif actual_reduction < min_reduction:
            status = BenchmarkStatus.FAIL
            message = f"REGRESSION: CPU reduction {actual_reduction:.1f}% below target {min_reduction:.0f}%"
        else:
            status = BenchmarkStatus.WARN
            message = f"Exceeds target: {actual_reduction:.1f}% reduction (verify measurement)"

        return BenchmarkResult(
            name="endToEndPipeline",
            measured_ns=0,  # Not applicable
            target_ns=0,
            actual_speedup=0,
            expected_speedup=0,
            status=status,
            message=message
        )

    def print_summary(self):
        """Print validation summary report"""
        print("\n" + "=" * 80)
        print("📊 PERFORMANCE VALIDATION REPORT")
        print("=" * 80)
        print(f"\nBaseline: {self.baseline['version']} (commit {self.baseline['commit']})")
        print(f"Platform: {self.baseline['platform']}")
        print(f"Optimizations: {', '.join(self.baseline['optimizations_applied'])}")
        print("\n" + "-" * 80)
        print(f"{'Benchmark':<35} {'Status':<12} {'Speedup':<15} {'Result'}")
        print("-" * 80)

        pass_count = 0
        fail_count = 0
        warn_count = 0

        for result in self.results:
            status_str = result.status.value
            speedup_str = f"{result.actual_speedup:.2f}x" if result.actual_speedup > 0 else "N/A"

            print(f"{result.name:<35} {status_str:<12} {speedup_str:<15} {result.message}")

            if result.status == BenchmarkStatus.PASS:
                pass_count += 1
            elif result.status == BenchmarkStatus.FAIL:
                fail_count += 1
            elif result.status == BenchmarkStatus.WARN:
                warn_count += 1

        print("-" * 80)
        print(f"\nSummary: {pass_count} passed, {fail_count} failed, {warn_count} warnings")
        print("=" * 80 + "\n")

        return fail_count == 0

    def run_validation(
        self,
        swift_results_path: Optional[str] = None,
        cpp_results_path: Optional[str] = None
    ) -> bool:
        """
        Run full validation suite.

        Args:
            swift_results_path: Path to Swift test results
            cpp_results_path: Path to C++ benchmark results

        Returns:
            True if all benchmarks passed, False if any failed
        """
        print("\n🔍 Starting performance validation...\n")

        # Parse Swift results
        swift_results = {}
        if swift_results_path:
            print(f"📱 Parsing Swift results from: {swift_results_path}")
            swift_results = self.parse_swift_results(swift_results_path)
            print(f"   Found {len(swift_results)} Swift benchmark(s)")

        # Parse C++ results
        cpp_results = {}
        if cpp_results_path:
            print(f"⚙️  Parsing C++ results from: {cpp_results_path}")
            cpp_results = self.parse_cpp_results(cpp_results_path)
            print(f"   Found {len(cpp_results)} C++ benchmark(s)")

        # Validate each benchmark against baseline
        benchmarks = self.baseline['benchmarks']

        # Map Swift test names to baseline benchmark names
        swift_test_mapping = {
            'testSIMDPeakDetectionThroughput': 'simdPeakDetection',
            'testCompressorDetectionThroughput': 'compressorDetection',
            'testReverbBlockProcessingThroughput': 'reverbBlockProcessing',
            'testDryWetMixSIMDThroughput': 'dryWetMixFMA',
            'testBioReactiveChainThroughput': 'bioReactiveChain',
            'testCoefficientCachingEffectiveness': 'coefficientCaching',
            'testMemoryAllocationOverhead': 'memoryAccess',
            'testEndToEndAudioPipelineThroughput': 'endToEndPipeline',
        }

        # Validate Swift benchmarks
        for test_name, measured_ns in swift_results.items():
            if test_name in swift_test_mapping:
                benchmark_name = swift_test_mapping[test_name]
                if benchmark_name in benchmarks:
                    baseline_config = benchmarks[benchmark_name]
                    result = self.validate_benchmark(
                        benchmark_name,
                        measured_ns,
                        baseline_config
                    )
                    self.results.append(result)

        # Validate C++ benchmarks
        cpp_benchmark_mapping = {
            'SIMD Peak Detection Benchmark': 'simdPeakDetection',
            'SIMD Dry/Wet Mix Benchmark': 'dryWetMixFMA',
            'Coefficient Caching Benchmark': 'coefficientCaching',
            'Memory Access Pattern Benchmark': 'memoryAccess',
        }

        for benchmark_name, timings in cpp_results.items():
            if benchmark_name in cpp_benchmark_mapping:
                baseline_name = cpp_benchmark_mapping[benchmark_name]
                if baseline_name in benchmarks:
                    baseline_config = benchmarks[baseline_name]
                    result = self.validate_benchmark(
                        baseline_name,
                        timings['median'],
                        baseline_config
                    )
                    self.results.append(result)

        # Print summary and return validation status
        return self.print_summary()


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Validate performance benchmarks against baseline metrics'
    )
    parser.add_argument(
        '--baseline',
        default='baseline-performance.json',
        help='Path to baseline performance metrics JSON'
    )
    parser.add_argument(
        '--swift-results',
        help='Path to Swift test results file'
    )
    parser.add_argument(
        '--cpp-results',
        help='Path to C++ benchmark results file'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose output'
    )

    args = parser.parse_args()

    # Create validator
    validator = PerformanceValidator(args.baseline)

    # Run validation
    success = validator.run_validation(
        swift_results_path=args.swift_results,
        cpp_results_path=args.cpp_results
    )

    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

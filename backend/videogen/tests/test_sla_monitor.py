"""
Tests for SLA Monitor - Super Genius AI Feature #9
"""

import pytest
import time
from datetime import datetime, timedelta

from ..layer4_deployment.production_ready import (
    SLALevel,
    SLATarget,
    SLAMetrics,
    SLAViolation,
    SLAMonitor,
    sla_monitor,
)


class TestSLATarget:
    """Tests for SLATarget class."""

    def test_target_creation(self):
        """Test creating an SLA target."""
        target = SLATarget(
            level=SLALevel.STANDARD,
            uptime_percent=99.0,
            latency_p50_ms=500,
            latency_p95_ms=2000,
            latency_p99_ms=5000,
            error_rate_percent=1.0,
            throughput_rps=20
        )

        assert target.level == SLALevel.STANDARD
        assert target.uptime_percent == 99.0


class TestSLAMetrics:
    """Tests for SLAMetrics class."""

    def test_meets_sla_success(self):
        """Test SLA compliance check - success."""
        target = SLATarget(
            level=SLALevel.STANDARD,
            uptime_percent=99.0,
            latency_p50_ms=500,
            latency_p95_ms=2000,
            latency_p99_ms=5000,
            error_rate_percent=1.0,
            throughput_rps=20
        )

        metrics = SLAMetrics(
            uptime_percent=99.5,
            latency_p50_ms=100,
            latency_p95_ms=500,
            latency_p99_ms=1000,
            error_rate_percent=0.5,
            current_throughput_rps=25,
            requests_total=1000,
            errors_total=5,
            period_start=datetime.now() - timedelta(hours=1),
            period_end=datetime.now()
        )

        meets, violations = metrics.meets_sla(target)

        assert meets
        assert len(violations) == 0

    def test_meets_sla_failure(self):
        """Test SLA compliance check - failure."""
        target = SLATarget(
            level=SLALevel.CRITICAL,
            uptime_percent=99.99,
            latency_p50_ms=50,
            latency_p95_ms=100,
            latency_p99_ms=200,
            error_rate_percent=0.01,
            throughput_rps=100
        )

        metrics = SLAMetrics(
            uptime_percent=98.0,  # Below target
            latency_p50_ms=100,   # Above target
            latency_p95_ms=500,   # Above target
            latency_p99_ms=1000,  # Above target
            error_rate_percent=2.0,  # Above target
            current_throughput_rps=50,
            requests_total=1000,
            errors_total=20,
            period_start=datetime.now() - timedelta(hours=1),
            period_end=datetime.now()
        )

        meets, violations = metrics.meets_sla(target)

        assert not meets
        assert len(violations) >= 4  # Multiple violations


class TestSLAMonitor:
    """Tests for SLAMonitor class."""

    def setup_method(self):
        self.monitor = SLAMonitor(
            target_level=SLALevel.STANDARD,
            window_seconds=60
        )

    def test_record_request_success(self):
        """Test recording a successful request."""
        self.monitor.record_request(100, success=True)

        metrics = self.monitor.get_current_metrics()
        assert metrics.requests_total == 1
        assert metrics.errors_total == 0

    def test_record_request_failure(self):
        """Test recording a failed request."""
        self.monitor.record_request(5000, success=False, error_msg="Timeout")

        metrics = self.monitor.get_current_metrics()
        assert metrics.errors_total == 1

    def test_record_downtime(self):
        """Test recording downtime."""
        self.monitor.record_downtime(30.0, "Server restart")

        metrics = self.monitor.get_current_metrics()
        assert metrics.uptime_percent < 100.0

    def test_latency_percentiles(self):
        """Test latency percentile calculation."""
        # Record requests with varying latencies
        for latency in [10, 20, 30, 40, 50, 100, 200, 500, 1000, 2000]:
            self.monitor.record_request(latency, success=True)

        metrics = self.monitor.get_current_metrics()

        assert metrics.latency_p50_ms > 0
        assert metrics.latency_p95_ms >= metrics.latency_p50_ms
        assert metrics.latency_p99_ms >= metrics.latency_p95_ms

    def test_get_sla_status(self):
        """Test getting SLA status."""
        for _ in range(10):
            self.monitor.record_request(100, success=True)

        status = self.monitor.get_sla_status()

        assert 'target_level' in status
        assert 'meets_sla' in status
        assert 'metrics' in status
        assert 'targets' in status
        assert status['target_level'] == 'standard'

    def test_violation_detection(self):
        """Test violation detection."""
        violations_detected = []

        def callback(violation):
            violations_detected.append(violation)

        monitor = SLAMonitor(
            target_level=SLALevel.CRITICAL,
            window_seconds=60,
            alert_callback=callback
        )

        # Record very slow requests to trigger violation
        for _ in range(100):
            monitor.record_request(10000, success=True)  # 10s latency

        # Should have detected violations
        status = monitor.get_sla_status()
        assert len(violations_detected) > 0 or not status['meets_sla']

    def test_violation_history(self):
        """Test violation history retrieval."""
        self.monitor.record_downtime(120, "Major outage")

        history = self.monitor.get_violation_history()

        assert len(history) >= 1
        assert history[-1]['type'] == 'downtime'
        assert history[-1]['severity'] == 'critical'

    def test_throughput_calculation(self):
        """Test throughput calculation."""
        # Record 10 requests
        for _ in range(10):
            self.monitor.record_request(100, success=True)

        metrics = self.monitor.get_current_metrics()

        assert metrics.current_throughput_rps > 0

    def test_error_rate_calculation(self):
        """Test error rate calculation."""
        # 90 successful, 10 failed
        for _ in range(90):
            self.monitor.record_request(100, success=True)
        for _ in range(10):
            self.monitor.record_request(100, success=False)

        metrics = self.monitor.get_current_metrics()

        assert metrics.error_rate_percent == pytest.approx(10.0, rel=0.1)


class TestSLALevels:
    """Tests for different SLA levels."""

    def test_critical_level_targets(self):
        """Test CRITICAL level has strictest targets."""
        monitor = SLAMonitor(target_level=SLALevel.CRITICAL)

        assert monitor.target.uptime_percent == 99.99
        assert monitor.target.latency_p99_ms == 200

    def test_best_effort_level_targets(self):
        """Test BEST_EFFORT level has most lenient targets."""
        monitor = SLAMonitor(target_level=SLALevel.BEST_EFFORT)

        assert monitor.target.uptime_percent == 95.0
        assert monitor.target.latency_p99_ms == 30000

    def test_all_levels_have_targets(self):
        """Test all SLA levels are defined."""
        for level in SLALevel:
            monitor = SLAMonitor(target_level=level)
            assert monitor.target is not None
            assert monitor.target.level == level


class TestGlobalSLAMonitor:
    """Tests for global SLA monitor instance."""

    def test_global_monitor_exists(self):
        """Test global monitor is initialized."""
        assert sla_monitor is not None
        assert isinstance(sla_monitor, SLAMonitor)

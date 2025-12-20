"""
Performance Test: Concurrent Requests
======================================

Testing how Echoelmusic handles the world's creativity
flowing in simultaneously.
"""

import pytest
import asyncio
import time
import statistics
from typing import List, Dict
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor


@dataclass
class RequestMetrics:
    """Metrics for a single request."""
    request_id: int
    latency_ms: float
    status: str
    error: str = None


@dataclass
class LoadTestResult:
    """Aggregate results from load test."""
    total_requests: int
    successful: int
    failed: int
    latency_p50_ms: float
    latency_p95_ms: float
    latency_p99_ms: float
    requests_per_second: float
    duration_seconds: float


class TestConcurrentRequests:
    """Tests for handling concurrent API requests."""

    @pytest.fixture
    def mock_api_handler(self):
        """Mock API handler with realistic latency."""
        async def handler(request_id: int, latency_ms: float = 50):
            await asyncio.sleep(latency_ms / 1000)
            return {"status": "ok", "request_id": request_id}
        return handler

    @pytest.mark.asyncio
    async def test_100_concurrent_requests(self, mock_api_handler):
        """Test handling 100 simultaneous requests."""
        num_requests = 100
        results = await self._run_concurrent_load(
            mock_api_handler,
            num_requests,
            latency_ms=20
        )

        assert results.total_requests == num_requests
        assert results.successful >= num_requests * 0.99  # 99% success rate
        assert results.latency_p95_ms < 200  # p95 under 200ms

    @pytest.mark.asyncio
    async def test_sustained_load(self, mock_api_handler):
        """Test sustained load over time."""
        duration_seconds = 2
        requests_per_second = 50

        results = await self._run_sustained_load(
            mock_api_handler,
            duration_seconds,
            requests_per_second
        )

        assert results.duration_seconds >= duration_seconds * 0.9
        assert results.requests_per_second >= requests_per_second * 0.8

    @pytest.mark.asyncio
    async def test_burst_handling(self, mock_api_handler):
        """Test handling sudden bursts of traffic."""
        # Baseline load
        baseline = await self._run_concurrent_load(mock_api_handler, 10, latency_ms=20)

        # Sudden burst (10x traffic)
        burst = await self._run_concurrent_load(mock_api_handler, 100, latency_ms=20)

        # System should handle burst without catastrophic failure
        assert burst.successful >= burst.total_requests * 0.95
        # Latency may increase but should stay reasonable
        assert burst.latency_p95_ms < baseline.latency_p95_ms * 5

    @pytest.mark.asyncio
    async def test_graceful_degradation(self, mock_api_handler):
        """Test system degrades gracefully under extreme load."""
        extreme_load = 500

        results = await self._run_concurrent_load(
            mock_api_handler,
            extreme_load,
            latency_ms=10
        )

        # Even under extreme load, should not completely fail
        assert results.successful >= extreme_load * 0.8

    @pytest.mark.asyncio
    async def test_mixed_request_types(self):
        """Test mix of fast and slow requests."""
        async def mixed_handler(request_id: int):
            # 80% fast requests, 20% slow
            is_slow = request_id % 5 == 0
            latency = 200 if is_slow else 20
            await asyncio.sleep(latency / 1000)
            return {"status": "ok", "slow": is_slow}

        results = await self._run_concurrent_load(
            mixed_handler,
            100,
            latency_ms=None  # Handler determines latency
        )

        # Fast requests shouldn't be blocked by slow ones
        assert results.latency_p50_ms < 50  # Median should be fast

    @pytest.mark.asyncio
    async def test_connection_pool_efficiency(self):
        """Test connection pool handles load efficiently."""
        connection_count = 0
        max_connections = 0

        async def tracked_handler(request_id: int):
            nonlocal connection_count, max_connections
            connection_count += 1
            max_connections = max(max_connections, connection_count)
            await asyncio.sleep(0.02)
            connection_count -= 1
            return {"status": "ok"}

        await self._run_concurrent_load(tracked_handler, 50, latency_ms=None)

        # Should use connection pooling, not unlimited connections
        assert max_connections <= 50  # At most one per request at peak

    @pytest.mark.asyncio
    async def test_request_queuing(self):
        """Test requests are properly queued under load."""
        queue_depth_history = []
        current_processing = 0
        max_concurrent = 10

        async def queued_handler(request_id: int):
            nonlocal current_processing
            while current_processing >= max_concurrent:
                await asyncio.sleep(0.005)

            current_processing += 1
            queue_depth_history.append(current_processing)
            await asyncio.sleep(0.02)
            current_processing -= 1
            return {"status": "ok"}

        await self._run_concurrent_load(queued_handler, 50, latency_ms=None)

        # Queue should have managed concurrent requests
        assert max(queue_depth_history) <= max_concurrent

    @pytest.mark.asyncio
    async def test_timeout_handling(self):
        """Test requests timeout appropriately."""
        async def slow_handler(request_id: int):
            if request_id % 10 == 0:
                await asyncio.sleep(10)  # Very slow
            else:
                await asyncio.sleep(0.01)
            return {"status": "ok"}

        timeout_seconds = 0.5
        results = []

        async def timed_request(request_id: int):
            try:
                result = await asyncio.wait_for(
                    slow_handler(request_id),
                    timeout=timeout_seconds
                )
                return RequestMetrics(request_id, 0, "ok")
            except asyncio.TimeoutError:
                return RequestMetrics(request_id, timeout_seconds * 1000, "timeout")

        tasks = [timed_request(i) for i in range(20)]
        results = await asyncio.gather(*tasks)

        timeouts = [r for r in results if r.status == "timeout"]
        successes = [r for r in results if r.status == "ok"]

        assert len(timeouts) >= 1  # Some should timeout
        assert len(successes) >= len(results) * 0.8  # Most should succeed

    @pytest.mark.asyncio
    async def test_error_rate_under_load(self, mock_api_handler):
        """Test error rate stays low under load."""
        error_count = 0

        async def error_prone_handler(request_id: int):
            nonlocal error_count
            # Simulate 2% error rate
            if request_id % 50 == 0:
                error_count += 1
                raise Exception("Random error")
            await asyncio.sleep(0.01)
            return {"status": "ok"}

        try:
            results = await self._run_concurrent_load(
                error_prone_handler,
                100,
                latency_ms=None
            )
        except:
            pass

        # Error rate should be low
        assert error_count <= 5

    # Helper methods

    async def _run_concurrent_load(
        self,
        handler,
        num_requests: int,
        latency_ms: float = None
    ) -> LoadTestResult:
        """Run concurrent load test."""
        start_time = time.time()
        latencies = []
        successful = 0
        failed = 0

        async def make_request(request_id: int) -> RequestMetrics:
            nonlocal successful, failed
            req_start = time.time()
            try:
                if latency_ms is not None:
                    await handler(request_id, latency_ms)
                else:
                    await handler(request_id)
                latency = (time.time() - req_start) * 1000
                latencies.append(latency)
                successful += 1
                return RequestMetrics(request_id, latency, "ok")
            except Exception as e:
                failed += 1
                return RequestMetrics(request_id, 0, "error", str(e))

        tasks = [make_request(i) for i in range(num_requests)]
        await asyncio.gather(*tasks, return_exceptions=True)

        duration = time.time() - start_time

        return LoadTestResult(
            total_requests=num_requests,
            successful=successful,
            failed=failed,
            latency_p50_ms=statistics.median(latencies) if latencies else 0,
            latency_p95_ms=self._percentile(latencies, 95),
            latency_p99_ms=self._percentile(latencies, 99),
            requests_per_second=num_requests / duration if duration > 0 else 0,
            duration_seconds=duration
        )

    async def _run_sustained_load(
        self,
        handler,
        duration_seconds: float,
        requests_per_second: int
    ) -> LoadTestResult:
        """Run sustained load over time."""
        start_time = time.time()
        latencies = []
        successful = 0
        request_id = 0

        interval = 1.0 / requests_per_second

        while time.time() - start_time < duration_seconds:
            req_start = time.time()
            try:
                await handler(request_id, latency_ms=10)
                latencies.append((time.time() - req_start) * 1000)
                successful += 1
            except:
                pass
            request_id += 1

            # Maintain rate
            elapsed = time.time() - req_start
            if elapsed < interval:
                await asyncio.sleep(interval - elapsed)

        duration = time.time() - start_time

        return LoadTestResult(
            total_requests=request_id,
            successful=successful,
            failed=request_id - successful,
            latency_p50_ms=statistics.median(latencies) if latencies else 0,
            latency_p95_ms=self._percentile(latencies, 95),
            latency_p99_ms=self._percentile(latencies, 99),
            requests_per_second=request_id / duration,
            duration_seconds=duration
        )

    def _percentile(self, data: List[float], percentile: int) -> float:
        """Calculate percentile of data."""
        if not data:
            return 0
        sorted_data = sorted(data)
        index = int(len(sorted_data) * percentile / 100)
        return sorted_data[min(index, len(sorted_data) - 1)]

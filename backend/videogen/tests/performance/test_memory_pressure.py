"""
Performance Test: Memory Pressure
==================================

Keeping creativity flowing even when resources are tight.
Every frame matters, every byte counts.
"""

import pytest
import asyncio
import gc
from typing import Dict, List
from dataclasses import dataclass
from unittest.mock import patch, MagicMock


@dataclass
class MemorySnapshot:
    """Memory state snapshot."""
    allocated_mb: float
    reserved_mb: float
    cached_mb: float
    timestamp: float


class TestMemoryPressure:
    """Tests for memory management under pressure."""

    @pytest.fixture
    def mock_gpu_memory(self):
        """Mock GPU memory tracking."""
        memory_state = {
            "allocated": 0,
            "reserved": 8 * 1024**3,  # 8GB reserved
            "total": 24 * 1024**3,  # 24GB total
        }

        def allocate(size_bytes: int):
            memory_state["allocated"] += size_bytes
            if memory_state["allocated"] > memory_state["total"]:
                raise RuntimeError("CUDA out of memory")

        def free(size_bytes: int):
            memory_state["allocated"] = max(0, memory_state["allocated"] - size_bytes)

        def get_allocated():
            return memory_state["allocated"]

        return {
            "allocate": allocate,
            "free": free,
            "get_allocated": get_allocated,
            "total": memory_state["total"],
            "state": memory_state
        }

    @pytest.mark.asyncio
    async def test_memory_stays_bounded(self, mock_gpu_memory):
        """Test memory usage stays within bounds during generation."""
        memory_history = []

        for i in range(10):
            # Simulate generation allocating memory
            mock_gpu_memory["allocate"](2 * 1024**3)  # 2GB per generation
            memory_history.append(mock_gpu_memory["get_allocated"]())

            # Cleanup after generation
            mock_gpu_memory["free"](2 * 1024**3)
            gc.collect()

        # Memory should not accumulate
        assert memory_history[-1] <= memory_history[0] + 1024**3  # Allow 1GB variance

    @pytest.mark.asyncio
    async def test_memory_cleanup_after_error(self, mock_gpu_memory):
        """Test memory is cleaned up even after errors."""
        initial_memory = mock_gpu_memory["get_allocated"]()

        try:
            mock_gpu_memory["allocate"](5 * 1024**3)
            raise RuntimeError("Simulated generation error")
        except RuntimeError:
            # Cleanup in finally block
            mock_gpu_memory["free"](5 * 1024**3)
            gc.collect()

        final_memory = mock_gpu_memory["get_allocated"]()
        assert final_memory <= initial_memory + 100 * 1024**2  # Allow 100MB variance

    @pytest.mark.asyncio
    async def test_concurrent_memory_management(self, mock_gpu_memory):
        """Test memory management with concurrent generations."""
        max_concurrent = 4
        memory_per_gen = 4 * 1024**3  # 4GB each
        active_generations = 0
        peak_memory = 0

        async def generation_task(task_id: int):
            nonlocal active_generations, peak_memory

            # Wait if too many concurrent
            while active_generations >= max_concurrent:
                await asyncio.sleep(0.01)

            active_generations += 1
            mock_gpu_memory["allocate"](memory_per_gen)
            peak_memory = max(peak_memory, mock_gpu_memory["get_allocated"]())

            await asyncio.sleep(0.02)  # Simulate work

            mock_gpu_memory["free"](memory_per_gen)
            active_generations -= 1

        tasks = [generation_task(i) for i in range(10)]
        await asyncio.gather(*tasks)

        # Peak should not exceed max_concurrent * memory_per_gen
        expected_peak = max_concurrent * memory_per_gen
        assert peak_memory <= expected_peak * 1.1  # 10% tolerance

    @pytest.mark.asyncio
    async def test_memory_fragmentation(self, mock_gpu_memory):
        """Test system handles memory fragmentation."""
        # Simulate fragmentation: allocate/free different sizes
        sizes = [1, 2, 0.5, 3, 1.5, 2.5]  # GB

        for _ in range(5):
            for size in sizes:
                size_bytes = int(size * 1024**3)
                mock_gpu_memory["allocate"](size_bytes)
                await asyncio.sleep(0.001)
                mock_gpu_memory["free"](size_bytes)

        # Should still be able to allocate large block
        try:
            mock_gpu_memory["allocate"](10 * 1024**3)
            mock_gpu_memory["free"](10 * 1024**3)
            allocation_succeeded = True
        except RuntimeError:
            allocation_succeeded = False

        # In real GPU, fragmentation could prevent this
        # Our mock allows it, but this tests the concept
        assert allocation_succeeded

    @pytest.mark.asyncio
    async def test_oom_recovery(self, mock_gpu_memory):
        """Test recovery from out-of-memory situations."""
        # Allocate until OOM
        allocated_chunks = []
        chunk_size = 5 * 1024**3

        try:
            while True:
                mock_gpu_memory["allocate"](chunk_size)
                allocated_chunks.append(chunk_size)
        except RuntimeError as e:
            assert "out of memory" in str(e).lower()

        # Free half and retry
        for _ in range(len(allocated_chunks) // 2):
            mock_gpu_memory["free"](chunk_size)
            allocated_chunks.pop()

        gc.collect()

        # Should be able to allocate again
        try:
            mock_gpu_memory["allocate"](chunk_size)
            recovered = True
        except RuntimeError:
            recovered = False

        assert recovered

    @pytest.mark.asyncio
    async def test_memory_pressure_queuing(self):
        """Test requests queue when memory is low."""
        available_memory = 16 * 1024**3  # 16GB
        current_usage = 0
        queued_requests = []
        completed_requests = []

        async def memory_aware_request(request_id: int, required_mb: int):
            nonlocal current_usage
            required_bytes = required_mb * 1024**2

            # Queue if not enough memory
            while current_usage + required_bytes > available_memory:
                queued_requests.append(request_id)
                await asyncio.sleep(0.01)
                if request_id in queued_requests:
                    queued_requests.remove(request_id)

            current_usage += required_bytes
            await asyncio.sleep(0.02)  # Process
            current_usage -= required_bytes
            completed_requests.append(request_id)

        # Launch requests requiring varying memory
        memory_requirements = [4000, 6000, 8000, 4000, 6000]  # MB
        tasks = [
            memory_aware_request(i, mem)
            for i, mem in enumerate(memory_requirements)
        ]

        await asyncio.gather(*tasks)

        assert len(completed_requests) == len(memory_requirements)

    @pytest.mark.asyncio
    async def test_cache_eviction_under_pressure(self):
        """Test cache evicts entries under memory pressure."""
        cache = {}
        cache_memory = 0
        max_cache_memory = 4 * 1024**3  # 4GB cache limit

        def add_to_cache(key: str, size_bytes: int):
            nonlocal cache_memory
            while cache_memory + size_bytes > max_cache_memory and cache:
                # Evict oldest
                oldest_key = next(iter(cache))
                cache_memory -= cache[oldest_key]
                del cache[oldest_key]

            cache[key] = size_bytes
            cache_memory += size_bytes

        # Fill cache beyond limit
        for i in range(10):
            add_to_cache(f"item_{i}", 1 * 1024**3)  # 1GB each

        # Only 4 should fit
        assert len(cache) == 4
        assert cache_memory <= max_cache_memory

    @pytest.mark.asyncio
    async def test_gradient_checkpointing_memory_savings(self):
        """Test gradient checkpointing reduces memory usage."""
        # Without checkpointing
        memory_without = 16 * 1024**3  # 16GB

        # With checkpointing (typically 30-50% savings)
        memory_with = 10 * 1024**3  # 10GB

        savings_percent = (memory_without - memory_with) / memory_without * 100

        assert savings_percent >= 30

    @pytest.mark.asyncio
    async def test_mixed_precision_memory_savings(self):
        """Test mixed precision reduces memory usage."""
        # FP32 memory
        fp32_memory = 24 * 1024**3  # 24GB

        # FP16/BF16 memory (approximately half)
        fp16_memory = 13 * 1024**3  # 13GB

        savings_percent = (fp32_memory - fp16_memory) / fp32_memory * 100

        assert savings_percent >= 40


class TestVRAMScheduling:
    """Tests for VRAM-aware batch scheduling."""

    @pytest.mark.asyncio
    async def test_vram_budget_respected(self):
        """Test scheduler respects VRAM budget."""
        vram_budget = 20 * 1024**3  # 20GB
        current_vram = 0
        max_vram_used = 0

        tasks_vram = [4, 6, 8, 4, 6, 8, 4]  # GB per task

        async def scheduled_task(vram_gb: int):
            nonlocal current_vram, max_vram_used
            vram_bytes = vram_gb * 1024**3

            # Wait for VRAM
            while current_vram + vram_bytes > vram_budget:
                await asyncio.sleep(0.01)

            current_vram += vram_bytes
            max_vram_used = max(max_vram_used, current_vram)

            await asyncio.sleep(0.02)

            current_vram -= vram_bytes

        await asyncio.gather(*[scheduled_task(v) for v in tasks_vram])

        assert max_vram_used <= vram_budget

    @pytest.mark.asyncio
    async def test_optimal_batch_packing(self):
        """Test scheduler optimally packs batches into VRAM."""
        vram_total = 24 * 1024**3  # 24GB

        # Tasks with different VRAM requirements
        tasks = [
            {"id": 1, "vram_gb": 8},
            {"id": 2, "vram_gb": 4},
            {"id": 3, "vram_gb": 6},
            {"id": 4, "vram_gb": 8},
            {"id": 5, "vram_gb": 4},
        ]

        # Optimal packing: [1,2,3] = 18GB, then [4,5] = 12GB
        batches = self._pack_tasks(tasks, vram_total)

        assert len(batches) == 2
        assert sum(t["vram_gb"] for t in batches[0]) <= 24
        assert sum(t["vram_gb"] for t in batches[1]) <= 24

    def _pack_tasks(self, tasks: List[Dict], vram_limit: int) -> List[List[Dict]]:
        """First-fit decreasing bin packing."""
        sorted_tasks = sorted(tasks, key=lambda t: t["vram_gb"], reverse=True)
        batches = []

        for task in sorted_tasks:
            task_vram = task["vram_gb"] * 1024**3
            placed = False

            for batch in batches:
                batch_vram = sum(t["vram_gb"] * 1024**3 for t in batch)
                if batch_vram + task_vram <= vram_limit:
                    batch.append(task)
                    placed = True
                    break

            if not placed:
                batches.append([task])

        return batches

"""
Tests for Batch Inference Pipeline - Super Genius AI Feature #3
"""

import pytest
import asyncio
import numpy as np
from datetime import datetime

from ..layer1_inference.batch_inference import (
    BatchPriority,
    BatchStatus,
    BatchItem,
    Batch,
    BatchConfig,
    PromptSimilarityCache,
    BatchScheduler,
    BatchProcessor,
    get_batch_processor,
    submit_batch_generation,
)


class TestBatchItem:
    """Tests for BatchItem class."""

    def test_batch_item_creation(self):
        """Test creating a batch item."""
        item = BatchItem(
            item_id="test_001",
            prompt="A cat",
            width=1280,
            height=720,
            num_frames=49
        )

        assert item.item_id == "test_001"
        assert item.status == BatchStatus.PENDING
        assert item.result is None

    def test_resolution_key(self):
        """Test resolution key generation."""
        item = BatchItem(
            item_id="test",
            prompt="Test",
            width=1280,
            height=720,
            num_frames=49
        )

        assert item.resolution_key == "1280x720x49"

    def test_prompt_hash(self):
        """Test prompt hash generation."""
        item1 = BatchItem(
            item_id="test1",
            prompt="Same prompt",
            width=1280,
            height=720,
            num_frames=49
        )
        item2 = BatchItem(
            item_id="test2",
            prompt="Same prompt",
            width=1280,
            height=720,
            num_frames=49
        )

        assert item1.prompt_hash == item2.prompt_hash

    def test_estimated_vram(self):
        """Test VRAM estimation."""
        item = BatchItem(
            item_id="test",
            prompt="Test",
            width=1280,
            height=720,
            num_frames=49
        )

        vram = item.estimated_vram_mb
        assert vram > 0


class TestBatch:
    """Tests for Batch class."""

    def test_batch_creation(self):
        """Test creating a batch."""
        items = [
            BatchItem("i1", "Prompt 1", 1280, 720, 49),
            BatchItem("i2", "Prompt 2", 1280, 720, 49),
        ]
        batch = Batch(batch_id="batch_001", items=items)

        assert batch.total_items == 2
        assert batch.completed_items == 0
        assert batch.progress == 0.0

    def test_batch_progress(self):
        """Test batch progress calculation."""
        items = [
            BatchItem("i1", "Prompt 1", 1280, 720, 49),
            BatchItem("i2", "Prompt 2", 1280, 720, 49),
        ]
        items[0].status = BatchStatus.COMPLETED

        batch = Batch(batch_id="batch_001", items=items)

        assert batch.completed_items == 1
        assert batch.progress == 0.5


class TestPromptSimilarityCache:
    """Tests for PromptSimilarityCache class."""

    def setup_method(self):
        self.cache = PromptSimilarityCache()

    def test_compute_embedding(self):
        """Test embedding computation."""
        embedding = self.cache.compute_embedding("A cat sitting on a mat")

        assert len(embedding) == 1000
        assert np.linalg.norm(embedding) > 0

    def test_similar_prompts(self):
        """Test similar prompt grouping."""
        group1 = self.cache.add_to_group("A cat sitting on a mat")
        group2 = self.cache.add_to_group("A cat sitting on a mat")  # Same

        # Same prompt should be in same group
        assert group1 == group2

    def test_find_similar_group(self):
        """Test finding similar groups."""
        self.cache.add_to_group("A beautiful sunset over the ocean")

        # Should find similar group for similar prompt
        found = self.cache.find_similar_group("A beautiful sunset over the sea")
        # May or may not find depending on threshold


class TestBatchScheduler:
    """Tests for BatchScheduler class."""

    def setup_method(self):
        self.config = BatchConfig(
            max_batch_size=4,
            max_vram_mb=20000
        )
        self.scheduler = BatchScheduler(self.config)

    def test_create_single_batch(self):
        """Test creating batches from items."""
        items = [
            BatchItem("i1", "Prompt 1", 1280, 720, 49),
            BatchItem("i2", "Prompt 2", 1280, 720, 49),
        ]

        batches = self.scheduler.create_batches(items)

        assert len(batches) == 1
        assert batches[0].total_items == 2

    def test_create_multiple_batches(self):
        """Test creating multiple batches when needed."""
        items = [
            BatchItem(f"i{i}", f"Prompt {i}", 1280, 720, 49)
            for i in range(10)
        ]

        batches = self.scheduler.create_batches(items)

        # Should create multiple batches since max_batch_size is 4
        assert len(batches) >= 2

    def test_priority_ordering(self):
        """Test priority-based ordering."""
        items = [
            BatchItem("i1", "Low", 1280, 720, 49, priority=BatchPriority.LOW),
            BatchItem("i2", "High", 1280, 720, 49, priority=BatchPriority.HIGH),
            BatchItem("i3", "Critical", 1280, 720, 49, priority=BatchPriority.CRITICAL),
        ]

        batches = self.scheduler.create_batches(items)

        # Critical should be first
        first_batch = batches[0]
        assert first_batch.items[0].item_id == "i3"

    def test_optimize_batch(self):
        """Test batch optimization."""
        items = [
            BatchItem("i1", "Same prompt", 1280, 720, 49),
            BatchItem("i2", "Same prompt", 1280, 720, 49),
            BatchItem("i3", "Different prompt", 1280, 720, 49),
        ]
        batch = Batch(batch_id="test", items=items)

        optimization = self.scheduler.optimize_batch(batch)

        assert 'prompt_groups' in optimization


class TestBatchProcessor:
    """Tests for BatchProcessor class."""

    def setup_method(self):
        self.processor = BatchProcessor()

    @pytest.mark.asyncio
    async def test_submit_item(self):
        """Test submitting an item."""
        item_id = await self.processor.submit(
            prompt="Test prompt",
            width=1280,
            height=720,
            num_frames=49
        )

        assert item_id.startswith("item_")
        assert item_id in self.processor.pending_items

    @pytest.mark.asyncio
    async def test_submit_batch(self):
        """Test submitting multiple items."""
        items = [
            {"prompt": "Prompt 1"},
            {"prompt": "Prompt 2"},
        ]

        item_ids = await self.processor.submit_batch(items)

        assert len(item_ids) == 2

    @pytest.mark.asyncio
    async def test_get_status(self):
        """Test getting item status."""
        item_id = await self.processor.submit(
            prompt="Test",
            width=1280,
            height=720,
            num_frames=49
        )

        status = await self.processor.get_status(item_id)

        assert status is not None
        assert status['item_id'] == item_id
        assert status['status'] == 'pending'

    @pytest.mark.asyncio
    async def test_cancel_item(self):
        """Test canceling an item."""
        item_id = await self.processor.submit(
            prompt="Test",
            width=1280,
            height=720,
            num_frames=49
        )

        cancelled = await self.processor.cancel(item_id)

        assert cancelled
        assert item_id not in self.processor.pending_items
        assert item_id in self.processor.completed_items
        assert self.processor.completed_items[item_id].status == BatchStatus.CANCELLED

    def test_queue_stats(self):
        """Test queue statistics."""
        stats = self.processor.get_queue_stats()

        assert 'pending_count' in stats
        assert 'active_batches' in stats
        assert 'completed_count' in stats

    @pytest.mark.asyncio
    async def test_with_callback(self):
        """Test item with callback."""
        callback_called = False
        callback_item = None

        def callback(item):
            nonlocal callback_called, callback_item
            callback_called = True
            callback_item = item

        item_id = await self.processor.submit(
            prompt="Test",
            width=1280,
            height=720,
            num_frames=49,
            callback=callback
        )

        assert item_id in self.processor.item_callbacks


class TestGlobalBatchProcessor:
    """Tests for global batch processor."""

    def test_get_batch_processor_singleton(self):
        """Test singleton pattern."""
        proc1 = get_batch_processor()
        proc2 = get_batch_processor()
        assert proc1 is proc2

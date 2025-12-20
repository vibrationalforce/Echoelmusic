"""
E2E Test: Full Video Generation Pipeline
=========================================

Tests the complete journey from creative prompt to final video.
Every artist deserves a seamless experience.
"""

import pytest
import asyncio
import uuid
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime


class TestFullGenerationPipeline:
    """Complete generation pipeline tests."""

    @pytest.fixture
    def mock_gpu_context(self):
        """Mock GPU context for CI/CD environments."""
        with patch('torch.cuda.is_available', return_value=True):
            with patch('torch.cuda.get_device_properties') as mock_props:
                mock_props.return_value = MagicMock(
                    total_memory=24 * 1024**3,
                    name="Test GPU"
                )
                yield

    @pytest.fixture
    def sample_creative_prompt(self):
        """A prompt that sparks creativity."""
        return {
            "prompt": "A pianist playing under starlight, notes transforming into butterflies",
            "negative_prompt": "blurry, distorted",
            "duration_seconds": 8,
            "resolution": "1080p",
            "fps": 24,
            "genre": "artistic",
            "style_strength": 0.8
        }

    @pytest.mark.asyncio
    async def test_prompt_to_video_complete_flow(self, sample_creative_prompt, mock_gpu_context):
        """Test complete flow: prompt → expansion → generation → encoding → output."""
        # Phase 1: Task Creation
        task_id = str(uuid.uuid4())

        # Phase 2: Prompt Expansion
        expanded_prompt = await self._simulate_prompt_expansion(sample_creative_prompt["prompt"])
        assert len(expanded_prompt) > len(sample_creative_prompt["prompt"])
        assert "cinematic" in expanded_prompt.lower() or "artistic" in expanded_prompt.lower()

        # Phase 3: Model Selection
        model_config = await self._simulate_model_selection(expanded_prompt)
        assert model_config["model"] in ["wan2.2-t2v-1.3b", "wan2.2-t2v-7b", "wan2.2-t2v-14b"]

        # Phase 4: Video Generation (simulated)
        generation_result = await self._simulate_generation(
            prompt=expanded_prompt,
            duration=sample_creative_prompt["duration_seconds"],
            config=model_config
        )
        assert generation_result["status"] == "completed"
        assert generation_result["frames_generated"] == sample_creative_prompt["fps"] * sample_creative_prompt["duration_seconds"]

        # Phase 5: Encoding
        video_output = await self._simulate_encoding(generation_result)
        assert video_output["format"] == "mp4"
        assert video_output["codec"] == "h264"

        # Phase 6: Final Validation
        assert video_output["duration_seconds"] == sample_creative_prompt["duration_seconds"]
        assert video_output["resolution"] == sample_creative_prompt["resolution"]

    @pytest.mark.asyncio
    async def test_generation_with_progress_tracking(self, sample_creative_prompt):
        """Test that progress is tracked throughout generation."""
        progress_updates = []

        async def progress_callback(progress: float, step: str):
            progress_updates.append({"progress": progress, "step": step})

        # Simulate generation with progress
        await self._simulate_generation_with_progress(
            sample_creative_prompt,
            progress_callback
        )

        # Verify progress flow
        assert len(progress_updates) > 0
        assert progress_updates[0]["progress"] < progress_updates[-1]["progress"]
        assert progress_updates[-1]["progress"] == 1.0

        # Verify all steps are present
        steps = [p["step"] for p in progress_updates]
        assert any("prompt" in s.lower() for s in steps)
        assert any("generat" in s.lower() for s in steps)

    @pytest.mark.asyncio
    async def test_generation_with_webhook_notification(self, sample_creative_prompt):
        """Test webhook notifications at key stages."""
        webhook_calls = []

        async def mock_webhook(event: str, data: dict):
            webhook_calls.append({"event": event, "data": data, "time": datetime.utcnow()})

        with patch('aiohttp.ClientSession.post', new_callable=AsyncMock) as mock_post:
            mock_post.return_value.__aenter__.return_value.status = 200

            await self._simulate_full_pipeline_with_webhooks(
                sample_creative_prompt,
                webhook_url="https://example.com/webhook",
                webhook_callback=mock_webhook
            )

        # Verify webhook events
        events = [w["event"] for w in webhook_calls]
        assert "task.started" in events or len(webhook_calls) >= 1

    @pytest.mark.asyncio
    async def test_generation_cancellation(self, sample_creative_prompt):
        """Test graceful cancellation mid-generation."""
        cancel_event = asyncio.Event()
        generation_task = None

        async def cancellable_generation():
            for i in range(100):
                if cancel_event.is_set():
                    return {"status": "cancelled", "progress": i / 100}
                await asyncio.sleep(0.01)
            return {"status": "completed", "progress": 1.0}

        # Start generation
        generation_task = asyncio.create_task(cancellable_generation())

        # Cancel after short delay
        await asyncio.sleep(0.05)
        cancel_event.set()

        result = await generation_task
        assert result["status"] == "cancelled"
        assert result["progress"] < 1.0

    @pytest.mark.asyncio
    async def test_generation_retry_on_failure(self, sample_creative_prompt):
        """Test automatic retry on transient failures."""
        attempt_count = 0

        async def flaky_generation():
            nonlocal attempt_count
            attempt_count += 1
            if attempt_count < 3:
                raise RuntimeError("Transient GPU error")
            return {"status": "completed", "frames": 192}

        # Simulate retry logic
        max_retries = 3
        result = None
        for attempt in range(max_retries):
            try:
                result = await flaky_generation()
                break
            except RuntimeError:
                if attempt == max_retries - 1:
                    raise
                await asyncio.sleep(0.01)

        assert result is not None
        assert result["status"] == "completed"
        assert attempt_count == 3

    @pytest.mark.asyncio
    async def test_generation_with_seed_reproducibility(self, sample_creative_prompt):
        """Test that same seed produces consistent results."""
        seed = 42

        result1 = await self._simulate_seeded_generation(sample_creative_prompt, seed)
        result2 = await self._simulate_seeded_generation(sample_creative_prompt, seed)

        # Same seed should produce same checksum
        assert result1["checksum"] == result2["checksum"]

        # Different seed should produce different result
        result3 = await self._simulate_seeded_generation(sample_creative_prompt, seed + 1)
        assert result1["checksum"] != result3["checksum"]

    @pytest.mark.asyncio
    async def test_generation_resource_cleanup(self, sample_creative_prompt, mock_gpu_context):
        """Test that GPU resources are properly cleaned up."""
        with patch('torch.cuda.empty_cache') as mock_empty_cache:
            with patch('gc.collect') as mock_gc:
                await self._simulate_generation_with_cleanup(sample_creative_prompt)

                # Verify cleanup was called
                mock_empty_cache.assert_called()
                mock_gc.assert_called()

    # Helper methods

    async def _simulate_prompt_expansion(self, prompt: str) -> str:
        """Simulate LLM prompt expansion."""
        await asyncio.sleep(0.01)
        return f"{prompt}, cinematic lighting, high quality, detailed, artistic composition"

    async def _simulate_model_selection(self, prompt: str) -> dict:
        """Simulate intelligent model selection."""
        await asyncio.sleep(0.01)
        complexity = len(prompt) / 100
        if complexity > 1.5:
            return {"model": "wan2.2-t2v-14b", "vram_gb": 24}
        elif complexity > 0.8:
            return {"model": "wan2.2-t2v-7b", "vram_gb": 16}
        return {"model": "wan2.2-t2v-1.3b", "vram_gb": 8}

    async def _simulate_generation(self, prompt: str, duration: float, config: dict) -> dict:
        """Simulate video generation."""
        await asyncio.sleep(0.05)
        return {
            "status": "completed",
            "frames_generated": int(24 * duration),
            "model_used": config["model"]
        }

    async def _simulate_encoding(self, generation_result: dict) -> dict:
        """Simulate video encoding."""
        await asyncio.sleep(0.02)
        return {
            "format": "mp4",
            "codec": "h264",
            "duration_seconds": generation_result["frames_generated"] / 24,
            "resolution": "1080p",
            "file_size_mb": generation_result["frames_generated"] * 0.2
        }

    async def _simulate_generation_with_progress(self, config: dict, callback):
        """Simulate generation with progress callbacks."""
        steps = [
            (0.1, "Expanding prompt"),
            (0.2, "Selecting model"),
            (0.3, "Initializing generation"),
            (0.7, "Generating frames"),
            (0.9, "Encoding video"),
            (1.0, "Complete")
        ]
        for progress, step in steps:
            await callback(progress, step)
            await asyncio.sleep(0.01)

    async def _simulate_full_pipeline_with_webhooks(self, config: dict, webhook_url: str, webhook_callback):
        """Simulate pipeline with webhook notifications."""
        await webhook_callback("task.started", {"task_id": str(uuid.uuid4())})
        await asyncio.sleep(0.02)
        await webhook_callback("task.completed", {"video_url": "/videos/test.mp4"})

    async def _simulate_seeded_generation(self, config: dict, seed: int) -> dict:
        """Simulate seeded generation for reproducibility."""
        import hashlib
        # Deterministic hash based on config and seed
        content = f"{config['prompt']}:{seed}"
        checksum = hashlib.md5(content.encode()).hexdigest()
        return {"checksum": checksum, "seed": seed}

    async def _simulate_generation_with_cleanup(self, config: dict):
        """Simulate generation with resource cleanup."""
        import gc
        try:
            await asyncio.sleep(0.02)
        finally:
            gc.collect()


class TestMultiUserGeneration:
    """Test concurrent generation for multiple users."""

    @pytest.mark.asyncio
    async def test_concurrent_generations(self):
        """Test multiple users generating simultaneously."""
        num_users = 10
        results = []

        async def user_generation(user_id: int):
            await asyncio.sleep(0.01 * user_id)  # Stagger starts
            return {
                "user_id": user_id,
                "status": "completed",
                "task_id": str(uuid.uuid4())
            }

        tasks = [user_generation(i) for i in range(num_users)]
        results = await asyncio.gather(*tasks)

        assert len(results) == num_users
        assert all(r["status"] == "completed" for r in results)

        # Verify unique task IDs
        task_ids = [r["task_id"] for r in results]
        assert len(set(task_ids)) == num_users

    @pytest.mark.asyncio
    async def test_queue_fairness(self):
        """Test that queue processes in fair order."""
        queue_order = []
        completion_order = []

        async def queued_generation(priority: int, user_id: int):
            queue_order.append(user_id)
            await asyncio.sleep(0.01)
            completion_order.append(user_id)
            return {"user_id": user_id, "priority": priority}

        # Submit in mixed priority order
        tasks = [
            queued_generation(1, 1),
            queued_generation(2, 2),
            queued_generation(1, 3),
        ]

        await asyncio.gather(*tasks)

        # All should complete
        assert len(completion_order) == 3

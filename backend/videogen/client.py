#!/usr/bin/env python3
"""
Echoelmusic Video Generation Client
====================================

Python client for the video generation API with:
- Async/sync interfaces
- WebSocket progress streaming
- Automatic retry with exponential backoff
- File download and upload support

Usage:
    # Simple generation
    client = VideoGenClient("http://localhost:8000")
    result = await client.generate("A cinematic sunset over mountains")

    # With progress callback
    async def on_progress(data):
        print(f"Progress: {data['progress']:.1f}% - {data['stage']}")

    result = await client.generate(
        prompt="A cyberpunk city at night",
        genre="scifi",
        resolution=(1920, 1080),
        progress_callback=on_progress
    )

    # Download result
    await client.download(result.output_path, "my_video.mp4")
"""

import os
import sys
import json
import asyncio
import aiohttp
import argparse
from typing import Optional, Dict, Any, Callable, Awaitable, Tuple
from dataclasses import dataclass
from enum import Enum
import uuid
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class TaskStatus(Enum):
    PENDING = "pending"
    QUEUED = "queued"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class GenerationResult:
    """Result of a video generation request"""
    task_id: str
    status: TaskStatus
    output_path: Optional[str] = None
    thumbnail_path: Optional[str] = None
    duration_seconds: float = 0.0
    generation_time_seconds: float = 0.0
    error_message: Optional[str] = None
    metadata: Dict[str, Any] = None

    def __post_init__(self):
        self.metadata = self.metadata or {}


class VideoGenClient:
    """
    Async client for Echoelmusic Video Generation API.

    Features:
    - Async/await interface
    - WebSocket progress streaming
    - Automatic retry with exponential backoff
    - Connection pooling
    """

    def __init__(
        self,
        base_url: str = "http://localhost:8000",
        timeout: float = 3600.0,
        max_retries: int = 3,
    ):
        self.base_url = base_url.rstrip("/")
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self.max_retries = max_retries
        self._session: Optional[aiohttp.ClientSession] = None

    async def __aenter__(self):
        await self.connect()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def connect(self):
        """Create connection session"""
        if self._session is None or self._session.closed:
            self._session = aiohttp.ClientSession(timeout=self.timeout)
        return self._session

    async def close(self):
        """Close connection session"""
        if self._session and not self._session.closed:
            await self._session.close()
            self._session = None

    async def _request(
        self,
        method: str,
        endpoint: str,
        **kwargs
    ) -> Dict[str, Any]:
        """Make HTTP request with retry logic"""
        session = await self.connect()
        url = f"{self.base_url}{endpoint}"

        for attempt in range(self.max_retries):
            try:
                async with session.request(method, url, **kwargs) as response:
                    if response.status >= 400:
                        error = await response.text()
                        raise Exception(f"API error {response.status}: {error}")
                    return await response.json()
            except aiohttp.ClientError as e:
                if attempt == self.max_retries - 1:
                    raise
                wait = 2 ** attempt
                logger.warning(f"Request failed, retrying in {wait}s: {e}")
                await asyncio.sleep(wait)

    async def health(self) -> Dict[str, Any]:
        """Check API health"""
        return await self._request("GET", "/health")

    async def generate(
        self,
        prompt: str,
        negative_prompt: str = "",
        genre: str = "cinematic",
        resolution: Tuple[int, int] = (1280, 720),
        duration: float = 4.0,
        fps: int = 24,
        seed: int = -1,
        guidance_scale: float = 7.5,
        num_inference_steps: int = 50,
        enable_refine: bool = True,
        target_resolution: Tuple[int, int] = (1920, 1080),
        progress_callback: Optional[Callable[[Dict[str, Any]], Awaitable[None]]] = None,
        wait: bool = True,
    ) -> GenerationResult:
        """
        Generate a video from text prompt.

        Args:
            prompt: Text description of the video
            negative_prompt: What to avoid in the video
            genre: Video genre (cinematic, anime, scifi, etc.)
            resolution: Base generation resolution (width, height)
            duration: Video duration in seconds
            fps: Frames per second
            seed: Random seed (-1 for random)
            guidance_scale: Classifier-free guidance scale
            num_inference_steps: Number of denoising steps
            enable_refine: Enable upscaling/refinement
            target_resolution: Target resolution after refinement
            progress_callback: Async callback for progress updates
            wait: Wait for completion (if False, returns immediately with task_id)

        Returns:
            GenerationResult with output paths and metadata
        """
        # Calculate frames
        num_frames = int(duration * fps)

        # Prepare request
        request_data = {
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "genre": genre,
            "width": resolution[0],
            "height": resolution[1],
            "num_frames": num_frames,
            "fps": fps,
            "seed": seed,
            "guidance_scale": guidance_scale,
            "num_inference_steps": num_inference_steps,
            "enable_refine": enable_refine,
            "target_resolution": list(target_resolution),
        }

        # Submit task
        response = await self._request("POST", "/generate", json=request_data)
        task_id = response["task_id"]

        logger.info(f"Task submitted: {task_id}")

        if not wait:
            return GenerationResult(
                task_id=task_id,
                status=TaskStatus.QUEUED,
            )

        # Wait for completion with progress
        if progress_callback:
            return await self._wait_with_websocket(task_id, progress_callback)
        else:
            return await self._wait_with_polling(task_id)

    async def _wait_with_websocket(
        self,
        task_id: str,
        callback: Callable[[Dict[str, Any]], Awaitable[None]],
    ) -> GenerationResult:
        """Wait for task completion using WebSocket"""
        ws_url = self.base_url.replace("http", "ws") + f"/ws/{task_id}"

        try:
            async with aiohttp.ClientSession() as session:
                async with session.ws_connect(ws_url) as ws:
                    async for msg in ws:
                        if msg.type == aiohttp.WSMsgType.TEXT:
                            data = json.loads(msg.data)
                            await callback(data)

                            if data.get("completed"):
                                return GenerationResult(
                                    task_id=task_id,
                                    status=TaskStatus.COMPLETED,
                                    output_path=data.get("output_path"),
                                    thumbnail_path=data.get("thumbnail_path"),
                                    duration_seconds=data.get("duration_seconds", 0),
                                    generation_time_seconds=data.get("generation_time_seconds", 0),
                                    metadata=data.get("metadata", {}),
                                )

                            if data.get("failed"):
                                return GenerationResult(
                                    task_id=task_id,
                                    status=TaskStatus.FAILED,
                                    error_message=data.get("error"),
                                )

                        elif msg.type == aiohttp.WSMsgType.ERROR:
                            raise Exception(f"WebSocket error: {ws.exception()}")

        except Exception as e:
            logger.warning(f"WebSocket failed, falling back to polling: {e}")
            return await self._wait_with_polling(task_id)

    async def _wait_with_polling(
        self,
        task_id: str,
        interval: float = 2.0,
    ) -> GenerationResult:
        """Wait for task completion using polling"""
        while True:
            response = await self._request("GET", f"/status/{task_id}")

            status = TaskStatus(response["status"])

            if status == TaskStatus.COMPLETED:
                return GenerationResult(
                    task_id=task_id,
                    status=status,
                    output_path=response.get("output_path"),
                    thumbnail_path=response.get("thumbnail_path"),
                    duration_seconds=response.get("duration_seconds", 0),
                    generation_time_seconds=response.get("generation_time_seconds", 0),
                    metadata=response.get("metadata", {}),
                )

            if status == TaskStatus.FAILED:
                return GenerationResult(
                    task_id=task_id,
                    status=status,
                    error_message=response.get("error_message"),
                )

            if status == TaskStatus.CANCELLED:
                return GenerationResult(
                    task_id=task_id,
                    status=status,
                )

            await asyncio.sleep(interval)

    async def status(self, task_id: str) -> GenerationResult:
        """Get task status"""
        response = await self._request("GET", f"/status/{task_id}")
        return GenerationResult(
            task_id=task_id,
            status=TaskStatus(response["status"]),
            output_path=response.get("output_path"),
            thumbnail_path=response.get("thumbnail_path"),
            duration_seconds=response.get("duration_seconds", 0),
            generation_time_seconds=response.get("generation_time_seconds", 0),
            error_message=response.get("error_message"),
            metadata=response.get("metadata", {}),
        )

    async def cancel(self, task_id: str) -> bool:
        """Cancel a pending or processing task"""
        response = await self._request("POST", f"/cancel/{task_id}")
        return response.get("cancelled", False)

    async def download(
        self,
        remote_path: str,
        local_path: str,
        progress_callback: Optional[Callable[[float], Awaitable[None]]] = None,
    ) -> str:
        """
        Download generated video.

        Args:
            remote_path: Path returned by generation
            local_path: Local path to save video
            progress_callback: Progress callback (0-100)

        Returns:
            Local path of downloaded file
        """
        session = await self.connect()
        url = f"{self.base_url}/download?path={remote_path}"

        async with session.get(url) as response:
            if response.status != 200:
                raise Exception(f"Download failed: {response.status}")

            total = int(response.headers.get("content-length", 0))
            downloaded = 0

            with open(local_path, "wb") as f:
                async for chunk in response.content.iter_chunked(8192):
                    f.write(chunk)
                    downloaded += len(chunk)
                    if progress_callback and total > 0:
                        await progress_callback(downloaded / total * 100)

        logger.info(f"Downloaded to {local_path}")
        return local_path

    async def list_genres(self) -> list:
        """Get list of available video genres"""
        response = await self._request("GET", "/genres")
        return response.get("genres", [])

    async def system_info(self) -> Dict[str, Any]:
        """Get system hardware information"""
        return await self._request("GET", "/system")


# ============================================================
# Synchronous wrapper for simple usage
# ============================================================
class SyncVideoGenClient:
    """Synchronous wrapper for VideoGenClient"""

    def __init__(self, *args, **kwargs):
        self._async_client = VideoGenClient(*args, **kwargs)

    def _run(self, coro):
        return asyncio.get_event_loop().run_until_complete(coro)

    def generate(self, *args, **kwargs) -> GenerationResult:
        return self._run(self._async_client.generate(*args, **kwargs))

    def status(self, task_id: str) -> GenerationResult:
        return self._run(self._async_client.status(task_id))

    def cancel(self, task_id: str) -> bool:
        return self._run(self._async_client.cancel(task_id))

    def download(self, remote_path: str, local_path: str) -> str:
        return self._run(self._async_client.download(remote_path, local_path))

    def close(self):
        self._run(self._async_client.close())


# ============================================================
# CLI Interface
# ============================================================
async def main():
    """CLI interface for video generation"""
    parser = argparse.ArgumentParser(
        description="Echoelmusic Video Generation Client",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate a simple video
  python client.py generate "A cinematic sunset over mountains"

  # Generate with options
  python client.py generate "A cyberpunk city" --genre scifi --resolution 1920x1080

  # Check status
  python client.py status <task_id>

  # Download result
  python client.py download <remote_path> <local_path>
        """
    )

    parser.add_argument(
        "--url",
        default=os.environ.get("VIDEOGEN_URL", "http://localhost:8000"),
        help="API server URL"
    )

    subparsers = parser.add_subparsers(dest="command", help="Command")

    # Generate command
    gen_parser = subparsers.add_parser("generate", help="Generate video")
    gen_parser.add_argument("prompt", help="Text prompt")
    gen_parser.add_argument("--negative", default="", help="Negative prompt")
    gen_parser.add_argument("--genre", default="cinematic", help="Video genre")
    gen_parser.add_argument("--resolution", default="1280x720", help="Resolution WxH")
    gen_parser.add_argument("--duration", type=float, default=4.0, help="Duration in seconds")
    gen_parser.add_argument("--fps", type=int, default=24, help="Frames per second")
    gen_parser.add_argument("--seed", type=int, default=-1, help="Random seed")
    gen_parser.add_argument("--no-refine", action="store_true", help="Disable refinement")
    gen_parser.add_argument("--output", "-o", help="Download to local path")

    # Status command
    status_parser = subparsers.add_parser("status", help="Check task status")
    status_parser.add_argument("task_id", help="Task ID")

    # Cancel command
    cancel_parser = subparsers.add_parser("cancel", help="Cancel task")
    cancel_parser.add_argument("task_id", help="Task ID")

    # Download command
    dl_parser = subparsers.add_parser("download", help="Download video")
    dl_parser.add_argument("remote_path", help="Remote path")
    dl_parser.add_argument("local_path", help="Local path")

    # Info command
    subparsers.add_parser("info", help="Get system info")

    # Genres command
    subparsers.add_parser("genres", help="List available genres")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return

    async with VideoGenClient(args.url) as client:
        if args.command == "generate":
            # Parse resolution
            w, h = map(int, args.resolution.split("x"))

            async def progress_callback(data):
                progress = data.get("progress", 0)
                stage = data.get("stage", "")
                print(f"\r[{progress:5.1f}%] {stage}", end="", flush=True)

            print(f"Generating video: {args.prompt}")
            print(f"Genre: {args.genre}, Resolution: {w}x{h}, Duration: {args.duration}s")
            print()

            result = await client.generate(
                prompt=args.prompt,
                negative_prompt=args.negative,
                genre=args.genre,
                resolution=(w, h),
                duration=args.duration,
                fps=args.fps,
                seed=args.seed,
                enable_refine=not args.no_refine,
                progress_callback=progress_callback,
            )

            print()  # New line after progress

            if result.status == TaskStatus.COMPLETED:
                print(f"✓ Generation complete!")
                print(f"  Output: {result.output_path}")
                print(f"  Duration: {result.duration_seconds:.1f}s")
                print(f"  Generation time: {result.generation_time_seconds:.1f}s")

                if args.output:
                    print(f"  Downloading to {args.output}...")
                    await client.download(result.output_path, args.output)
                    print(f"✓ Downloaded!")

            else:
                print(f"✗ Generation failed: {result.error_message}")
                sys.exit(1)

        elif args.command == "status":
            result = await client.status(args.task_id)
            print(f"Task: {result.task_id}")
            print(f"Status: {result.status.value}")
            if result.output_path:
                print(f"Output: {result.output_path}")
            if result.error_message:
                print(f"Error: {result.error_message}")

        elif args.command == "cancel":
            cancelled = await client.cancel(args.task_id)
            if cancelled:
                print(f"✓ Task {args.task_id} cancelled")
            else:
                print(f"✗ Could not cancel task {args.task_id}")

        elif args.command == "download":
            async def progress(pct):
                print(f"\rDownloading: {pct:.1f}%", end="", flush=True)

            await client.download(args.remote_path, args.local_path, progress)
            print(f"\n✓ Downloaded to {args.local_path}")

        elif args.command == "info":
            info = await client.system_info()
            print(json.dumps(info, indent=2))

        elif args.command == "genres":
            genres = await client.list_genres()
            print("Available genres:")
            for genre in genres:
                print(f"  - {genre}")


if __name__ == "__main__":
    asyncio.run(main())

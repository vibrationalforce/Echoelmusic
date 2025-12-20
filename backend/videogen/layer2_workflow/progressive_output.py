"""
Progressive Frame Streaming - Super Genius AI Feature #4

Enables real-time preview during video generation by streaming
frames as they are decoded, rather than waiting for full completion.

Features:
- Real-time frame streaming via WebSocket
- Multi-resolution preview (low-res first)
- Adaptive quality based on network conditions
- Frame caching for scrubbing
- Progress estimation and ETA
"""

import asyncio
import time
import json
import base64
import io
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Callable, Awaitable, AsyncGenerator, Any
from datetime import datetime, timedelta
import logging
import numpy as np

logger = logging.getLogger(__name__)

# Optional imports for image encoding
try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False


class StreamQuality(str, Enum):
    """Quality levels for progressive streaming."""
    THUMBNAIL = "thumbnail"  # 128px, fast preview
    PREVIEW = "preview"      # 256px, low quality
    STANDARD = "standard"    # 512px, medium quality
    HIGH = "high"           # Original resolution


class StreamEventType(str, Enum):
    """Types of streaming events."""
    GENERATION_STARTED = "generation_started"
    FRAME_AVAILABLE = "frame_available"
    PROGRESS_UPDATE = "progress_update"
    QUALITY_CHANGE = "quality_change"
    GENERATION_COMPLETED = "generation_completed"
    GENERATION_FAILED = "generation_failed"
    ETA_UPDATE = "eta_update"


@dataclass
class StreamConfig:
    """Configuration for progressive streaming."""
    initial_quality: StreamQuality = StreamQuality.PREVIEW
    enable_adaptive_quality: bool = True
    frame_buffer_size: int = 30
    jpeg_quality: int = 75
    send_interval_ms: int = 100
    enable_frame_cache: bool = True
    max_cached_frames: int = 200


@dataclass
class StreamEvent:
    """An event in the stream."""
    event_type: StreamEventType
    timestamp: datetime = field(default_factory=datetime.now)
    frame_index: Optional[int] = None
    frame_data: Optional[bytes] = None  # Encoded frame
    quality: Optional[StreamQuality] = None
    progress: Optional[float] = None
    eta_seconds: Optional[float] = None
    metadata: Dict[str, Any] = field(default_factory=dict)

    def to_json(self) -> str:
        """Convert to JSON for WebSocket transmission."""
        data = {
            'event': self.event_type.value,
            'timestamp': self.timestamp.isoformat(),
            'progress': self.progress,
            'eta_seconds': self.eta_seconds,
            'metadata': self.metadata
        }

        if self.frame_index is not None:
            data['frame_index'] = self.frame_index

        if self.quality is not None:
            data['quality'] = self.quality.value

        if self.frame_data is not None:
            data['frame_data'] = base64.b64encode(self.frame_data).decode('utf-8')

        return json.dumps(data)


@dataclass
class GenerationProgress:
    """Tracks generation progress."""
    total_frames: int
    completed_frames: int = 0
    started_at: Optional[datetime] = None
    last_frame_at: Optional[datetime] = None
    frame_times: List[float] = field(default_factory=list)

    @property
    def progress(self) -> float:
        if self.total_frames == 0:
            return 0.0
        return self.completed_frames / self.total_frames

    @property
    def average_frame_time(self) -> float:
        if not self.frame_times:
            return 0.0
        return sum(self.frame_times[-10:]) / len(self.frame_times[-10:])

    @property
    def eta_seconds(self) -> float:
        if self.average_frame_time == 0:
            return 0.0
        remaining = self.total_frames - self.completed_frames
        return remaining * self.average_frame_time

    def add_frame(self):
        """Record a completed frame."""
        now = datetime.now()
        if self.last_frame_at:
            elapsed = (now - self.last_frame_at).total_seconds()
            self.frame_times.append(elapsed)
        self.last_frame_at = now
        self.completed_frames += 1


class FrameEncoder:
    """Encodes frames for streaming."""

    def __init__(self, jpeg_quality: int = 75):
        self.jpeg_quality = jpeg_quality

    def encode(
        self,
        frame: np.ndarray,
        quality: StreamQuality = StreamQuality.STANDARD
    ) -> bytes:
        """Encode a frame to JPEG bytes."""
        if not HAS_PIL:
            # Fallback to raw bytes
            return frame.tobytes()

        # Resize based on quality
        target_size = self._get_target_size(quality, frame.shape)

        # Convert to PIL Image
        if frame.dtype != np.uint8:
            frame = (frame * 255).astype(np.uint8)

        img = Image.fromarray(frame)

        # Resize if needed
        if target_size != (img.width, img.height):
            img = img.resize(target_size, Image.Resampling.LANCZOS)

        # Encode to JPEG
        buffer = io.BytesIO()
        jpeg_quality = self._get_jpeg_quality(quality)
        img.save(buffer, format='JPEG', quality=jpeg_quality)

        return buffer.getvalue()

    def _get_target_size(
        self,
        quality: StreamQuality,
        original_shape: tuple
    ) -> tuple:
        """Get target size based on quality level."""
        h, w = original_shape[:2]
        aspect_ratio = w / h

        max_sizes = {
            StreamQuality.THUMBNAIL: 128,
            StreamQuality.PREVIEW: 256,
            StreamQuality.STANDARD: 512,
            StreamQuality.HIGH: max(w, h)
        }

        max_dim = max_sizes.get(quality, 512)

        if w > h:
            new_w = min(w, max_dim)
            new_h = int(new_w / aspect_ratio)
        else:
            new_h = min(h, max_dim)
            new_w = int(new_h * aspect_ratio)

        return (new_w, new_h)

    def _get_jpeg_quality(self, quality: StreamQuality) -> int:
        """Get JPEG quality based on stream quality."""
        quality_map = {
            StreamQuality.THUMBNAIL: 50,
            StreamQuality.PREVIEW: 65,
            StreamQuality.STANDARD: 75,
            StreamQuality.HIGH: 90
        }
        return quality_map.get(quality, 75)


class AdaptiveQualityController:
    """Adapts streaming quality based on network conditions."""

    def __init__(
        self,
        initial_quality: StreamQuality = StreamQuality.PREVIEW,
        window_size: int = 10
    ):
        self.current_quality = initial_quality
        self.window_size = window_size
        self.send_times: List[float] = []
        self.frame_sizes: List[int] = []

    def record_send(self, frame_size: int, send_time: float):
        """Record a frame send for analysis."""
        self.send_times.append(send_time)
        self.frame_sizes.append(frame_size)

        # Keep only recent samples
        if len(self.send_times) > self.window_size:
            self.send_times.pop(0)
            self.frame_sizes.pop(0)

        # Adapt quality
        self._adapt_quality()

    def _adapt_quality(self):
        """Adapt quality based on recent performance."""
        if len(self.send_times) < 3:
            return

        avg_time = sum(self.send_times) / len(self.send_times)
        avg_size = sum(self.frame_sizes) / len(self.frame_sizes)

        # Calculate effective bandwidth (bytes/second)
        bandwidth = avg_size / max(avg_time, 0.001)

        # Quality thresholds (bytes/second)
        if bandwidth > 1_000_000:  # 1 MB/s
            target = StreamQuality.HIGH
        elif bandwidth > 500_000:  # 500 KB/s
            target = StreamQuality.STANDARD
        elif bandwidth > 100_000:  # 100 KB/s
            target = StreamQuality.PREVIEW
        else:
            target = StreamQuality.THUMBNAIL

        # Only change if significantly different
        quality_order = [StreamQuality.THUMBNAIL, StreamQuality.PREVIEW,
                        StreamQuality.STANDARD, StreamQuality.HIGH]
        current_idx = quality_order.index(self.current_quality)
        target_idx = quality_order.index(target)

        # Gradual changes
        if target_idx > current_idx:
            self.current_quality = quality_order[current_idx + 1]
        elif target_idx < current_idx:
            self.current_quality = quality_order[current_idx - 1]

    def get_current_quality(self) -> StreamQuality:
        """Get the current recommended quality."""
        return self.current_quality


class FrameCache:
    """Caches frames for scrubbing/seeking."""

    def __init__(self, max_frames: int = 200):
        self.max_frames = max_frames
        self._cache: Dict[int, Dict[StreamQuality, bytes]] = {}
        self._access_order: List[int] = []

    def store(
        self,
        frame_index: int,
        quality: StreamQuality,
        data: bytes
    ):
        """Store a frame in the cache."""
        if frame_index not in self._cache:
            self._cache[frame_index] = {}
            self._access_order.append(frame_index)

        self._cache[frame_index][quality] = data

        # Evict old frames if needed
        while len(self._cache) > self.max_frames:
            oldest = self._access_order.pop(0)
            del self._cache[oldest]

    def get(
        self,
        frame_index: int,
        quality: StreamQuality
    ) -> Optional[bytes]:
        """Get a frame from the cache."""
        if frame_index not in self._cache:
            return None

        qualities = self._cache[frame_index]
        if quality in qualities:
            return qualities[quality]

        # Fall back to highest available quality
        quality_order = [StreamQuality.HIGH, StreamQuality.STANDARD,
                        StreamQuality.PREVIEW, StreamQuality.THUMBNAIL]
        for q in quality_order:
            if q in qualities:
                return qualities[q]

        return None

    def get_cached_indices(self) -> List[int]:
        """Get list of cached frame indices."""
        return list(self._cache.keys())


class ProgressiveOutputStream:
    """
    Main class for progressive frame streaming.

    Provides real-time frame streaming during video generation.
    """

    def __init__(self, config: Optional[StreamConfig] = None):
        self.config = config or StreamConfig()
        self.encoder = FrameEncoder(self.config.jpeg_quality)
        self.quality_controller = AdaptiveQualityController(
            self.config.initial_quality
        )
        self.frame_cache = FrameCache(self.config.max_cached_frames)

        self._subscribers: Dict[str, asyncio.Queue] = {}
        self._active_sessions: Dict[str, GenerationProgress] = {}
        self._lock = asyncio.Lock()

        logger.info("ProgressiveOutputStream initialized")

    async def subscribe(self, session_id: str) -> AsyncGenerator[StreamEvent, None]:
        """
        Subscribe to stream events for a session.

        Yields StreamEvents as they occur.
        """
        queue: asyncio.Queue = asyncio.Queue()

        async with self._lock:
            self._subscribers[session_id] = queue

        try:
            while True:
                event = await queue.get()
                yield event

                # Check for terminal events
                if event.event_type in [
                    StreamEventType.GENERATION_COMPLETED,
                    StreamEventType.GENERATION_FAILED
                ]:
                    break

        finally:
            async with self._lock:
                if session_id in self._subscribers:
                    del self._subscribers[session_id]

    async def start_generation(
        self,
        session_id: str,
        total_frames: int,
        width: int,
        height: int,
        fps: int = 24
    ):
        """Start a new generation session."""
        async with self._lock:
            self._active_sessions[session_id] = GenerationProgress(
                total_frames=total_frames,
                started_at=datetime.now()
            )

        event = StreamEvent(
            event_type=StreamEventType.GENERATION_STARTED,
            progress=0.0,
            metadata={
                'total_frames': total_frames,
                'width': width,
                'height': height,
                'fps': fps
            }
        )

        await self._broadcast(session_id, event)
        logger.info(f"Started generation session {session_id}")

    async def emit_frame(
        self,
        session_id: str,
        frame_index: int,
        frame: np.ndarray,
        force_quality: Optional[StreamQuality] = None
    ):
        """Emit a generated frame."""
        progress = self._active_sessions.get(session_id)
        if not progress:
            logger.warning(f"No active session: {session_id}")
            return

        # Record timing
        progress.add_frame()

        # Determine quality
        if self.config.enable_adaptive_quality and force_quality is None:
            quality = self.quality_controller.get_current_quality()
        else:
            quality = force_quality or StreamQuality.STANDARD

        # Encode frame
        start_time = time.time()
        frame_data = self.encoder.encode(frame, quality)
        encode_time = time.time() - start_time

        # Cache if enabled
        if self.config.enable_frame_cache:
            self.frame_cache.store(frame_index, quality, frame_data)

        # Create event
        event = StreamEvent(
            event_type=StreamEventType.FRAME_AVAILABLE,
            frame_index=frame_index,
            frame_data=frame_data,
            quality=quality,
            progress=progress.progress,
            eta_seconds=progress.eta_seconds,
            metadata={
                'encode_time_ms': encode_time * 1000,
                'frame_size_bytes': len(frame_data)
            }
        )

        # Record for adaptive quality
        send_start = time.time()
        await self._broadcast(session_id, event)
        send_time = time.time() - send_start

        self.quality_controller.record_send(len(frame_data), send_time)

    async def emit_progress(
        self,
        session_id: str,
        progress: float,
        message: Optional[str] = None
    ):
        """Emit a progress update."""
        progress_obj = self._active_sessions.get(session_id)
        eta = progress_obj.eta_seconds if progress_obj else None

        event = StreamEvent(
            event_type=StreamEventType.PROGRESS_UPDATE,
            progress=progress,
            eta_seconds=eta,
            metadata={'message': message} if message else {}
        )

        await self._broadcast(session_id, event)

    async def complete_generation(
        self,
        session_id: str,
        success: bool = True,
        error: Optional[str] = None,
        result_url: Optional[str] = None
    ):
        """Complete a generation session."""
        event_type = (StreamEventType.GENERATION_COMPLETED if success
                     else StreamEventType.GENERATION_FAILED)

        progress = self._active_sessions.get(session_id)

        event = StreamEvent(
            event_type=event_type,
            progress=1.0 if success else progress.progress if progress else 0.0,
            metadata={
                'error': error,
                'result_url': result_url,
                'total_time_seconds': (
                    (datetime.now() - progress.started_at).total_seconds()
                    if progress and progress.started_at else None
                )
            }
        )

        await self._broadcast(session_id, event)

        # Cleanup
        async with self._lock:
            if session_id in self._active_sessions:
                del self._active_sessions[session_id]

        logger.info(f"Completed generation session {session_id}: success={success}")

    async def get_cached_frame(
        self,
        frame_index: int,
        quality: StreamQuality = StreamQuality.STANDARD
    ) -> Optional[bytes]:
        """Get a cached frame for scrubbing."""
        return self.frame_cache.get(frame_index, quality)

    async def _broadcast(self, session_id: str, event: StreamEvent):
        """Broadcast an event to subscribers."""
        async with self._lock:
            if session_id in self._subscribers:
                queue = self._subscribers[session_id]
                await queue.put(event)

    def get_session_info(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Get information about an active session."""
        progress = self._active_sessions.get(session_id)
        if not progress:
            return None

        return {
            'total_frames': progress.total_frames,
            'completed_frames': progress.completed_frames,
            'progress': progress.progress,
            'eta_seconds': progress.eta_seconds,
            'average_frame_time': progress.average_frame_time,
            'cached_frames': len(self.frame_cache.get_cached_indices())
        }


class WebSocketStreamHandler:
    """Handler for WebSocket-based streaming."""

    def __init__(self, output_stream: ProgressiveOutputStream):
        self.stream = output_stream

    async def handle_connection(
        self,
        session_id: str,
        send_fn: Callable[[str], Awaitable[None]]
    ):
        """
        Handle a WebSocket connection.

        Args:
            session_id: The generation session ID
            send_fn: Function to send messages to the WebSocket
        """
        try:
            async for event in self.stream.subscribe(session_id):
                await send_fn(event.to_json())
        except Exception as e:
            logger.error(f"WebSocket error for session {session_id}: {e}")


# Singleton instance
_stream: Optional[ProgressiveOutputStream] = None


def get_progressive_stream() -> ProgressiveOutputStream:
    """Get the global progressive stream instance."""
    global _stream
    if _stream is None:
        _stream = ProgressiveOutputStream()
    return _stream


async def stream_generation(
    session_id: str,
    frames: AsyncGenerator[np.ndarray, None],
    total_frames: int,
    width: int,
    height: int,
    fps: int = 24
) -> AsyncGenerator[StreamEvent, None]:
    """
    Convenience function to stream a generation.

    Yields StreamEvents as frames are generated.
    """
    stream = get_progressive_stream()

    await stream.start_generation(
        session_id, total_frames, width, height, fps
    )

    frame_index = 0
    async for frame in frames:
        await stream.emit_frame(session_id, frame_index, frame)
        frame_index += 1

    await stream.complete_generation(session_id, success=True)

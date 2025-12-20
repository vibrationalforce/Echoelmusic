"""
Video Inpainting - Super Genius AI Feature #6

Enables intelligent video inpainting for:
- Object removal
- Background replacement
- Content addition
- Temporal consistency

Features:
- Mask-based inpainting
- Automatic object tracking
- Flow-guided propagation
- Edge blending
"""

import asyncio
import numpy as np
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Tuple, Any, Callable, Union
import logging

logger = logging.getLogger(__name__)

# Optional imports
try:
    import cv2
    HAS_CV2 = True
except ImportError:
    HAS_CV2 = False


class InpaintMode(str, Enum):
    """Inpainting modes."""
    REMOVE = "remove"           # Remove and fill
    REPLACE = "replace"         # Replace with new content
    BLEND = "blend"             # Blend with overlay
    BACKGROUND = "background"   # Replace background
    EXTEND = "extend"           # Outpainting


class BlendMode(str, Enum):
    """Blending modes for compositing."""
    NORMAL = "normal"
    MULTIPLY = "multiply"
    SCREEN = "screen"
    OVERLAY = "overlay"
    SOFT_LIGHT = "soft_light"
    HARD_LIGHT = "hard_light"


@dataclass
class MaskFrame:
    """A mask for a single frame."""
    frame_index: int
    mask: np.ndarray  # Binary mask [H, W]
    confidence: float = 1.0


@dataclass
class InpaintRegion:
    """Definition of a region to inpaint."""
    region_id: str
    mode: InpaintMode
    mask_frames: List[MaskFrame]
    replacement_content: Optional[np.ndarray] = None  # For REPLACE mode
    blend_mode: BlendMode = BlendMode.NORMAL
    feather_radius: int = 10
    temporal_smoothing: float = 0.5


@dataclass
class InpaintResult:
    """Result of inpainting operation."""
    frames: np.ndarray
    regions_processed: int
    quality_score: float
    warnings: List[str] = field(default_factory=list)


@dataclass
class InpaintConfig:
    """Configuration for inpainting."""
    temporal_consistency: bool = True
    flow_guided: bool = True
    edge_blending: bool = True
    feather_radius: int = 10
    num_iterations: int = 3
    fill_method: str = "telea"  # or "ns" for Navier-Stokes


class MaskTracker:
    """Tracks masks across frames for temporal consistency."""

    def __init__(self, tracking_method: str = "flow"):
        self.tracking_method = tracking_method
        self._prev_frame: Optional[np.ndarray] = None
        self._prev_mask: Optional[np.ndarray] = None

    def propagate_mask(
        self,
        current_frame: np.ndarray,
        mask: Optional[np.ndarray] = None
    ) -> np.ndarray:
        """
        Propagate mask from previous frame to current frame.

        Args:
            current_frame: Current video frame
            mask: Optional new mask to use

        Returns:
            Propagated mask
        """
        if mask is not None:
            self._prev_mask = mask.copy()
            self._prev_frame = current_frame.copy()
            return mask

        if self._prev_mask is None or self._prev_frame is None:
            return np.zeros(current_frame.shape[:2], dtype=np.uint8)

        if not HAS_CV2:
            # Fallback without OpenCV
            return self._prev_mask.copy()

        # Use optical flow for propagation
        prev_gray = cv2.cvtColor(self._prev_frame, cv2.COLOR_RGB2GRAY)
        curr_gray = cv2.cvtColor(current_frame, cv2.COLOR_RGB2GRAY)

        # Calculate optical flow
        try:
            flow = cv2.calcOpticalFlowFarneback(
                prev_gray, curr_gray, None,
                pyr_scale=0.5, levels=3, winsize=15,
                iterations=3, poly_n=5, poly_sigma=1.2, flags=0
            )
        except Exception as e:
            logger.warning(f"Flow calculation failed: {e}")
            return self._prev_mask.copy()

        # Warp mask using flow
        h, w = self._prev_mask.shape
        y_coords, x_coords = np.mgrid[0:h, 0:w].astype(np.float32)

        new_x = x_coords + flow[..., 0]
        new_y = y_coords + flow[..., 1]

        propagated = cv2.remap(
            self._prev_mask.astype(np.float32),
            new_x, new_y,
            interpolation=cv2.INTER_LINEAR,
            borderMode=cv2.BORDER_CONSTANT,
            borderValue=0
        )

        # Threshold back to binary
        propagated = (propagated > 0.5).astype(np.uint8) * 255

        # Update state
        self._prev_frame = current_frame.copy()
        self._prev_mask = propagated

        return propagated


class FrameInpainter:
    """Inpaints individual frames."""

    def __init__(self, config: InpaintConfig):
        self.config = config

    def inpaint(
        self,
        frame: np.ndarray,
        mask: np.ndarray,
        mode: InpaintMode = InpaintMode.REMOVE,
        replacement: Optional[np.ndarray] = None
    ) -> np.ndarray:
        """
        Inpaint a single frame.

        Args:
            frame: Input frame [H, W, C]
            mask: Binary mask [H, W]
            mode: Inpainting mode
            replacement: Replacement content for REPLACE mode

        Returns:
            Inpainted frame
        """
        if mode == InpaintMode.REMOVE:
            return self._inpaint_remove(frame, mask)
        elif mode == InpaintMode.REPLACE:
            return self._inpaint_replace(frame, mask, replacement)
        elif mode == InpaintMode.BLEND:
            return self._inpaint_blend(frame, mask, replacement)
        elif mode == InpaintMode.BACKGROUND:
            return self._inpaint_background(frame, mask, replacement)
        else:
            return frame

    def _inpaint_remove(
        self,
        frame: np.ndarray,
        mask: np.ndarray
    ) -> np.ndarray:
        """Remove masked region and fill."""
        if not HAS_CV2:
            return self._fallback_inpaint(frame, mask)

        # Ensure mask is uint8
        mask_uint8 = mask.astype(np.uint8)
        if mask_uint8.max() == 1:
            mask_uint8 = mask_uint8 * 255

        # Choose inpainting method
        if self.config.fill_method == "telea":
            result = cv2.inpaint(
                frame, mask_uint8,
                inpaintRadius=self.config.feather_radius,
                flags=cv2.INPAINT_TELEA
            )
        else:
            result = cv2.inpaint(
                frame, mask_uint8,
                inpaintRadius=self.config.feather_radius,
                flags=cv2.INPAINT_NS
            )

        return result

    def _inpaint_replace(
        self,
        frame: np.ndarray,
        mask: np.ndarray,
        replacement: Optional[np.ndarray]
    ) -> np.ndarray:
        """Replace masked region with new content."""
        if replacement is None:
            return frame

        # Resize replacement if needed
        if replacement.shape[:2] != frame.shape[:2]:
            if HAS_CV2:
                replacement = cv2.resize(
                    replacement,
                    (frame.shape[1], frame.shape[0]),
                    interpolation=cv2.INTER_LINEAR
                )
            else:
                # Simple resize fallback
                replacement = self._simple_resize(replacement, frame.shape[:2])

        # Apply mask
        mask_3d = np.expand_dims(mask, axis=-1).astype(np.float32)
        if mask_3d.max() > 1:
            mask_3d = mask_3d / 255.0

        # Feather mask edges
        if self.config.edge_blending and HAS_CV2:
            mask_3d = cv2.GaussianBlur(
                mask_3d,
                (self.config.feather_radius * 2 + 1,) * 2,
                0
            )

        # Blend
        result = frame * (1 - mask_3d) + replacement * mask_3d
        return result.astype(np.uint8)

    def _inpaint_blend(
        self,
        frame: np.ndarray,
        mask: np.ndarray,
        overlay: Optional[np.ndarray]
    ) -> np.ndarray:
        """Blend overlay with frame using mask."""
        if overlay is None:
            return frame

        # Resize overlay if needed
        if overlay.shape[:2] != frame.shape[:2]:
            if HAS_CV2:
                overlay = cv2.resize(
                    overlay,
                    (frame.shape[1], frame.shape[0])
                )

        # Apply mask
        mask_3d = np.expand_dims(mask, axis=-1).astype(np.float32)
        if mask_3d.max() > 1:
            mask_3d = mask_3d / 255.0

        # Blend based on mode (normal blend)
        alpha = mask_3d * 0.7  # 70% opacity
        result = frame * (1 - alpha) + overlay * alpha

        return result.astype(np.uint8)

    def _inpaint_background(
        self,
        frame: np.ndarray,
        mask: np.ndarray,
        new_background: Optional[np.ndarray]
    ) -> np.ndarray:
        """Replace background (inverse of mask)."""
        if new_background is None:
            return frame

        # Invert mask (mask should be foreground)
        inv_mask = 1 - mask.astype(np.float32) / 255.0

        return self._inpaint_replace(frame, inv_mask, new_background)

    def _fallback_inpaint(
        self,
        frame: np.ndarray,
        mask: np.ndarray
    ) -> np.ndarray:
        """Simple fallback inpainting without OpenCV."""
        result = frame.copy()

        # Simple average fill
        mask_bool = mask > 0
        if not np.any(mask_bool):
            return result

        # Get surrounding pixels for fill color
        kernel_size = self.config.feather_radius * 2 + 1
        for c in range(3):
            channel = frame[..., c].astype(np.float32)

            # Dilate mask
            dilated = self._dilate_mask(mask_bool, kernel_size)

            # Get fill value from border
            border = dilated & ~mask_bool
            if np.any(border):
                fill_value = np.mean(channel[border])
            else:
                fill_value = np.mean(channel)

            result[..., c][mask_bool] = fill_value

        return result

    def _dilate_mask(
        self,
        mask: np.ndarray,
        kernel_size: int
    ) -> np.ndarray:
        """Simple mask dilation."""
        if HAS_CV2:
            kernel = np.ones((kernel_size, kernel_size), np.uint8)
            return cv2.dilate(mask.astype(np.uint8), kernel).astype(bool)

        # Fallback
        result = mask.copy()
        h, w = mask.shape
        half_k = kernel_size // 2

        for y in range(h):
            for x in range(w):
                if mask[y, x]:
                    y_start = max(0, y - half_k)
                    y_end = min(h, y + half_k + 1)
                    x_start = max(0, x - half_k)
                    x_end = min(w, x + half_k + 1)
                    result[y_start:y_end, x_start:x_end] = True

        return result

    def _simple_resize(
        self,
        image: np.ndarray,
        target_size: Tuple[int, int]
    ) -> np.ndarray:
        """Simple bilinear resize without OpenCV."""
        h, w = target_size
        orig_h, orig_w = image.shape[:2]

        # Create coordinate grids
        y_ratio = orig_h / h
        x_ratio = orig_w / w

        result = np.zeros((h, w, image.shape[2]), dtype=image.dtype)

        for y in range(h):
            for x in range(w):
                # Source coordinates
                src_y = y * y_ratio
                src_x = x * x_ratio

                # Get integer parts
                y0 = int(src_y)
                x0 = int(src_x)
                y1 = min(y0 + 1, orig_h - 1)
                x1 = min(x0 + 1, orig_w - 1)

                # Interpolation weights
                wy = src_y - y0
                wx = src_x - x0

                # Bilinear interpolation
                result[y, x] = (
                    (1 - wy) * (1 - wx) * image[y0, x0] +
                    wy * (1 - wx) * image[y1, x0] +
                    (1 - wy) * wx * image[y0, x1] +
                    wy * wx * image[y1, x1]
                )

        return result


class VideoInpainter:
    """
    Main video inpainting class.

    Features:
    - Multi-region inpainting
    - Temporal consistency
    - Flow-guided propagation
    - Edge blending
    """

    def __init__(self, config: Optional[InpaintConfig] = None):
        self.config = config or InpaintConfig()
        self.frame_inpainter = FrameInpainter(self.config)
        self.mask_tracker = MaskTracker()

        logger.info("VideoInpainter initialized")

    async def inpaint(
        self,
        video_frames: np.ndarray,
        regions: List[InpaintRegion]
    ) -> InpaintResult:
        """
        Inpaint multiple regions in a video.

        Args:
            video_frames: Video frames [T, H, W, C]
            regions: List of regions to inpaint

        Returns:
            InpaintResult with modified frames
        """
        result_frames = video_frames.copy()
        warnings = []

        for region in regions:
            logger.info(f"Processing region {region.region_id}")

            try:
                result_frames = await self._inpaint_region(
                    result_frames, region
                )
            except Exception as e:
                warnings.append(f"Failed to process region {region.region_id}: {e}")
                logger.error(f"Inpainting error: {e}")

        # Calculate quality score
        quality_score = self._compute_quality(video_frames, result_frames)

        return InpaintResult(
            frames=result_frames,
            regions_processed=len(regions) - len(warnings),
            quality_score=quality_score,
            warnings=warnings
        )

    async def _inpaint_region(
        self,
        frames: np.ndarray,
        region: InpaintRegion
    ) -> np.ndarray:
        """Inpaint a single region across all frames."""
        result = frames.copy()
        num_frames = frames.shape[0]

        # Build mask dictionary
        mask_dict = {mf.frame_index: mf.mask for mf in region.mask_frames}

        # Reset tracker
        self.mask_tracker = MaskTracker()

        for i in range(num_frames):
            # Get or propagate mask
            if i in mask_dict:
                mask = self.mask_tracker.propagate_mask(
                    frames[i], mask_dict[i]
                )
            else:
                mask = self.mask_tracker.propagate_mask(frames[i])

            # Inpaint frame
            result[i] = self.frame_inpainter.inpaint(
                result[i],
                mask,
                mode=region.mode,
                replacement=region.replacement_content
            )

        # Apply temporal smoothing if enabled
        if self.config.temporal_consistency:
            result = self._temporal_smooth(result, region.temporal_smoothing)

        return result

    def _temporal_smooth(
        self,
        frames: np.ndarray,
        strength: float = 0.5
    ) -> np.ndarray:
        """Apply temporal smoothing to reduce flickering."""
        if strength <= 0:
            return frames

        result = frames.copy().astype(np.float32)

        for i in range(1, len(frames) - 1):
            # Weighted average with neighbors
            w_prev = strength / 2
            w_next = strength / 2
            w_curr = 1 - strength

            result[i] = (
                w_prev * result[i - 1] +
                w_curr * result[i] +
                w_next * result[i + 1]
            )

        return result.astype(np.uint8)

    def _compute_quality(
        self,
        original: np.ndarray,
        result: np.ndarray
    ) -> float:
        """Compute inpainting quality score."""
        # Simple metric: measure edge consistency

        # Calculate temporal consistency
        temporal_diff = 0.0
        for i in range(1, len(result)):
            diff = np.abs(result[i].astype(float) - result[i - 1].astype(float))
            temporal_diff += np.mean(diff)

        temporal_score = 1.0 - min(1.0, temporal_diff / (len(result) * 50))

        return temporal_score

    def create_mask_from_bbox(
        self,
        height: int,
        width: int,
        bbox: Tuple[int, int, int, int],
        feather: bool = True
    ) -> np.ndarray:
        """Create a mask from a bounding box."""
        x, y, w, h = bbox
        mask = np.zeros((height, width), dtype=np.uint8)
        mask[y:y + h, x:x + w] = 255

        if feather and HAS_CV2:
            mask = cv2.GaussianBlur(
                mask,
                (self.config.feather_radius * 2 + 1,) * 2,
                0
            )

        return mask

    def create_mask_from_points(
        self,
        height: int,
        width: int,
        points: List[Tuple[int, int]],
        closed: bool = True
    ) -> np.ndarray:
        """Create a mask from polygon points."""
        mask = np.zeros((height, width), dtype=np.uint8)

        if not HAS_CV2:
            # Simple fallback - fill bounding box
            if points:
                xs = [p[0] for p in points]
                ys = [p[1] for p in points]
                mask[min(ys):max(ys), min(xs):max(xs)] = 255
            return mask

        pts = np.array(points, dtype=np.int32).reshape((-1, 1, 2))

        if closed:
            cv2.fillPoly(mask, [pts], 255)
        else:
            cv2.polylines(mask, [pts], False, 255, self.config.feather_radius)

        return mask


# Singleton instance
_inpainter: Optional[VideoInpainter] = None


def get_video_inpainter() -> VideoInpainter:
    """Get the global video inpainter instance."""
    global _inpainter
    if _inpainter is None:
        _inpainter = VideoInpainter()
    return _inpainter


async def inpaint_video(
    video_frames: np.ndarray,
    regions: List[InpaintRegion]
) -> InpaintResult:
    """Convenience function to inpaint a video."""
    inpainter = get_video_inpainter()
    return await inpainter.inpaint(video_frames, regions)

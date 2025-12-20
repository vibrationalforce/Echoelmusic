"""
Video Warp Effects System
=========================

Inspired by Minimal Audio's 40+ warp effects for wavetable transformation.
Provides temporal, spatial, and stylistic video transformations.

Features:
- Temporal warps (time-stretch, reverse, loop, freeze)
- Spatial warps (zoom, pan, rotate, perspective, fisheye)
- Color warps (palette shift, gradient map, color grading)
- Motion warps (speed curves, motion blur, optical flow)
- Style warps (cross-style interpolation, glitch, datamosh)
"""

import numpy as np
from typing import Optional, Dict, Any, List, Tuple, Callable, Union
from dataclasses import dataclass, field
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class WarpCategory(str, Enum):
    """Categories of warp effects"""
    TEMPORAL = "temporal"
    SPATIAL = "spatial"
    COLOR = "color"
    MOTION = "motion"
    STYLE = "style"
    GLITCH = "glitch"


class WarpType(str, Enum):
    """Individual warp effect types"""
    # Temporal
    TIME_STRETCH = "time_stretch"
    TIME_REVERSE = "time_reverse"
    TIME_LOOP = "time_loop"
    TIME_FREEZE = "time_freeze"
    TIME_STUTTER = "time_stutter"
    TIME_PINGPONG = "time_pingpong"
    TIME_RANDOM = "time_random"

    # Spatial
    ZOOM = "zoom"
    PAN = "pan"
    ROTATE = "rotate"
    PERSPECTIVE = "perspective"
    FISHEYE = "fisheye"
    BARREL = "barrel"
    MIRROR = "mirror"
    KALEIDOSCOPE = "kaleidoscope"
    TILE = "tile"

    # Color
    HUE_SHIFT = "hue_shift"
    SATURATION = "saturation"
    BRIGHTNESS = "brightness"
    CONTRAST = "contrast"
    INVERT = "invert"
    GRADIENT_MAP = "gradient_map"
    COLOR_GRADE = "color_grade"
    DUOTONE = "duotone"
    POSTERIZE = "posterize"

    # Motion
    MOTION_BLUR = "motion_blur"
    SPEED_RAMP = "speed_ramp"
    OPTICAL_FLOW = "optical_flow"
    FRAME_BLEND = "frame_blend"
    ECHO = "echo"

    # Style
    STYLE_TRANSFER = "style_transfer"
    CROSS_FADE = "cross_fade"
    DISSOLVE = "dissolve"

    # Glitch
    DATAMOSH = "datamosh"
    PIXEL_SORT = "pixel_sort"
    RGB_SPLIT = "rgb_split"
    SCAN_LINES = "scan_lines"
    VHS = "vhs"
    NOISE = "noise"
    CORRUPT = "corrupt"


@dataclass
class WarpKeyframe:
    """Keyframe for animated warp parameters"""
    frame: int
    value: float
    easing: str = "linear"  # linear, ease_in, ease_out, ease_in_out, bounce


@dataclass
class WarpEffect:
    """Configuration for a single warp effect"""
    warp_type: WarpType
    amount: float = 1.0  # Effect intensity (0.0 to 2.0)
    enabled: bool = True

    # Animation
    animated: bool = False
    keyframes: List[WarpKeyframe] = field(default_factory=list)

    # Type-specific parameters
    params: Dict[str, Any] = field(default_factory=dict)

    # Blend mode
    blend_mode: str = "normal"  # normal, add, multiply, screen, overlay

    def get_value_at_frame(self, frame: int, total_frames: int) -> float:
        """Get interpolated value at specific frame"""
        if not self.animated or not self.keyframes:
            return self.amount

        # Find surrounding keyframes
        prev_kf = None
        next_kf = None

        for kf in sorted(self.keyframes, key=lambda k: k.frame):
            if kf.frame <= frame:
                prev_kf = kf
            if kf.frame >= frame and next_kf is None:
                next_kf = kf

        if prev_kf is None:
            return self.keyframes[0].value if self.keyframes else self.amount
        if next_kf is None or prev_kf == next_kf:
            return prev_kf.value

        # Interpolate
        t = (frame - prev_kf.frame) / (next_kf.frame - prev_kf.frame)
        t = self._apply_easing(t, prev_kf.easing)

        return prev_kf.value + (next_kf.value - prev_kf.value) * t

    def _apply_easing(self, t: float, easing: str) -> float:
        """Apply easing function"""
        if easing == "linear":
            return t
        elif easing == "ease_in":
            return t * t
        elif easing == "ease_out":
            return 1 - (1 - t) * (1 - t)
        elif easing == "ease_in_out":
            return 3 * t * t - 2 * t * t * t
        elif easing == "bounce":
            if t < 0.5:
                return 4 * t * t * t
            else:
                return 1 - pow(-2 * t + 2, 3) / 2
        return t


@dataclass
class WarpChain:
    """Chain of warp effects applied in sequence"""
    name: str
    effects: List[WarpEffect] = field(default_factory=list)
    enabled: bool = True

    def add_effect(self, effect: WarpEffect) -> None:
        """Add effect to chain"""
        self.effects.append(effect)

    def remove_effect(self, index: int) -> None:
        """Remove effect from chain"""
        if 0 <= index < len(self.effects):
            self.effects.pop(index)

    def reorder(self, old_index: int, new_index: int) -> None:
        """Reorder effects in chain"""
        if 0 <= old_index < len(self.effects) and 0 <= new_index < len(self.effects):
            effect = self.effects.pop(old_index)
            self.effects.insert(new_index, effect)


class WarpProcessor:
    """
    Processes video frames with warp effects.

    Applies a chain of effects to video frames, supporting
    animation, blending, and real-time parameter modulation.
    """

    def __init__(self):
        self._effect_processors: Dict[WarpType, Callable] = {
            # Temporal
            WarpType.TIME_STRETCH: self._process_time_stretch,
            WarpType.TIME_REVERSE: self._process_time_reverse,
            WarpType.TIME_LOOP: self._process_time_loop,
            WarpType.TIME_FREEZE: self._process_time_freeze,
            WarpType.TIME_STUTTER: self._process_time_stutter,
            WarpType.TIME_PINGPONG: self._process_time_pingpong,

            # Spatial
            WarpType.ZOOM: self._process_zoom,
            WarpType.PAN: self._process_pan,
            WarpType.ROTATE: self._process_rotate,
            WarpType.MIRROR: self._process_mirror,
            WarpType.KALEIDOSCOPE: self._process_kaleidoscope,

            # Color
            WarpType.HUE_SHIFT: self._process_hue_shift,
            WarpType.SATURATION: self._process_saturation,
            WarpType.BRIGHTNESS: self._process_brightness,
            WarpType.CONTRAST: self._process_contrast,
            WarpType.INVERT: self._process_invert,
            WarpType.POSTERIZE: self._process_posterize,

            # Motion
            WarpType.MOTION_BLUR: self._process_motion_blur,
            WarpType.ECHO: self._process_echo,

            # Glitch
            WarpType.RGB_SPLIT: self._process_rgb_split,
            WarpType.SCAN_LINES: self._process_scan_lines,
            WarpType.VHS: self._process_vhs,
            WarpType.NOISE: self._process_noise,
        }

    def process_frame(
        self,
        frame: np.ndarray,
        chain: WarpChain,
        frame_idx: int,
        total_frames: int,
        prev_frames: Optional[List[np.ndarray]] = None
    ) -> np.ndarray:
        """
        Process a single frame through the warp chain.

        Args:
            frame: Input frame [H, W, C]
            chain: Warp effect chain
            frame_idx: Current frame index
            total_frames: Total frames in video
            prev_frames: Previous frames (for temporal effects)

        Returns:
            Processed frame
        """
        if not chain.enabled:
            return frame

        result = frame.copy()

        for effect in chain.effects:
            if not effect.enabled:
                continue

            processor = self._effect_processors.get(effect.warp_type)
            if processor:
                amount = effect.get_value_at_frame(frame_idx, total_frames)
                result = processor(
                    result,
                    amount,
                    effect.params,
                    frame_idx,
                    total_frames,
                    prev_frames
                )

        return result

    def process_video(
        self,
        frames: np.ndarray,
        chain: WarpChain
    ) -> np.ndarray:
        """
        Process entire video through warp chain.

        Args:
            frames: Video frames [F, H, W, C]
            chain: Warp effect chain

        Returns:
            Processed video frames
        """
        num_frames = frames.shape[0]
        result = np.zeros_like(frames)
        prev_frames = []

        for i in range(num_frames):
            result[i] = self.process_frame(
                frames[i],
                chain,
                i,
                num_frames,
                prev_frames[-5:] if prev_frames else None
            )
            prev_frames.append(frames[i])

        return result

    # -------------------------------------------------------------------------
    # Temporal Effects
    # -------------------------------------------------------------------------

    def _process_time_stretch(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Time stretch - handled at video level"""
        return frame  # Placeholder - actual implementation modifies frame order

    def _process_time_reverse(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Time reverse"""
        return frame

    def _process_time_loop(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Time loop"""
        return frame

    def _process_time_freeze(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Freeze frame"""
        freeze_frame = params.get("freeze_at", 0)
        if frame_idx >= freeze_frame and amount > 0.5:
            return prev[0] if prev else frame
        return frame

    def _process_time_stutter(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Stutter effect - repeat frames"""
        stutter_interval = int(params.get("interval", 4))
        if frame_idx % stutter_interval != 0 and prev and amount > 0.5:
            return prev[-1]
        return frame

    def _process_time_pingpong(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Ping-pong loop"""
        return frame

    # -------------------------------------------------------------------------
    # Spatial Effects
    # -------------------------------------------------------------------------

    def _process_zoom(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Zoom in/out"""
        if abs(amount - 1.0) < 0.01:
            return frame

        h, w = frame.shape[:2]
        scale = 1.0 + (amount - 1.0) * 0.5  # Limit zoom range

        # Calculate crop region
        new_h, new_w = int(h / scale), int(w / scale)
        y1 = (h - new_h) // 2
        x1 = (w - new_w) // 2

        # Crop and resize
        cropped = frame[y1:y1+new_h, x1:x1+new_w]

        try:
            from PIL import Image
            pil_img = Image.fromarray(cropped)
            pil_img = pil_img.resize((w, h), Image.Resampling.LANCZOS)
            return np.array(pil_img)
        except ImportError:
            return frame

    def _process_pan(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Pan horizontally/vertically"""
        h, w = frame.shape[:2]
        pan_x = int(params.get("pan_x", 0) * amount * w * 0.2)
        pan_y = int(params.get("pan_y", 0) * amount * h * 0.2)

        result = np.zeros_like(frame)
        src_x1, src_y1 = max(0, -pan_x), max(0, -pan_y)
        src_x2, src_y2 = min(w, w - pan_x), min(h, h - pan_y)
        dst_x1, dst_y1 = max(0, pan_x), max(0, pan_y)
        dst_x2, dst_y2 = min(w, w + pan_x), min(h, h + pan_y)

        result[dst_y1:dst_y2, dst_x1:dst_x2] = frame[src_y1:src_y2, src_x1:src_x2]
        return result

    def _process_rotate(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Rotate frame"""
        if abs(amount) < 0.01:
            return frame

        try:
            from PIL import Image
            angle = amount * 360 * params.get("speed", 0.1)
            pil_img = Image.fromarray(frame)
            pil_img = pil_img.rotate(angle, resample=Image.Resampling.BILINEAR, expand=False)
            return np.array(pil_img)
        except ImportError:
            return frame

    def _process_mirror(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Mirror effect"""
        axis = params.get("axis", "horizontal")
        if amount > 0.5:
            if axis == "horizontal":
                return np.fliplr(frame)
            else:
                return np.flipud(frame)
        return frame

    def _process_kaleidoscope(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Kaleidoscope effect"""
        segments = int(params.get("segments", 6))
        # Simplified: mirror and rotate
        result = frame.copy()
        if amount > 0.3:
            result = np.fliplr(result)
        if amount > 0.6:
            result = np.flipud(result)
        return result

    # -------------------------------------------------------------------------
    # Color Effects
    # -------------------------------------------------------------------------

    def _process_hue_shift(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Shift hue"""
        try:
            import cv2
            hsv = cv2.cvtColor(frame, cv2.COLOR_RGB2HSV)
            hsv[:, :, 0] = (hsv[:, :, 0] + int(amount * 180)) % 180
            return cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)
        except ImportError:
            return frame

    def _process_saturation(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Adjust saturation"""
        try:
            import cv2
            hsv = cv2.cvtColor(frame, cv2.COLOR_RGB2HSV).astype(np.float32)
            hsv[:, :, 1] = np.clip(hsv[:, :, 1] * amount, 0, 255)
            return cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)
        except ImportError:
            return frame

    def _process_brightness(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Adjust brightness"""
        adjustment = int((amount - 1.0) * 128)
        return np.clip(frame.astype(np.int16) + adjustment, 0, 255).astype(np.uint8)

    def _process_contrast(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Adjust contrast"""
        mean = np.mean(frame)
        return np.clip((frame.astype(np.float32) - mean) * amount + mean, 0, 255).astype(np.uint8)

    def _process_invert(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Invert colors"""
        if amount > 0.5:
            return 255 - frame
        return frame

    def _process_posterize(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Posterize (reduce color levels)"""
        levels = max(2, int(8 - amount * 6))
        return (frame // (256 // levels)) * (256 // levels)

    # -------------------------------------------------------------------------
    # Motion Effects
    # -------------------------------------------------------------------------

    def _process_motion_blur(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Motion blur using previous frames"""
        if not prev or amount < 0.1:
            return frame

        num_blend = min(int(amount * 5), len(prev))
        result = frame.astype(np.float32)

        for i, prev_frame in enumerate(prev[-num_blend:]):
            weight = (i + 1) / (num_blend + 1) * 0.5
            result = result * (1 - weight) + prev_frame.astype(np.float32) * weight

        return result.astype(np.uint8)

    def _process_echo(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Echo/trail effect"""
        if not prev or amount < 0.1:
            return frame

        decay = params.get("decay", 0.7)
        result = frame.astype(np.float32)

        for i, prev_frame in enumerate(reversed(prev[-3:])):
            weight = amount * (decay ** (i + 1))
            result = np.maximum(result, prev_frame.astype(np.float32) * weight)

        return np.clip(result, 0, 255).astype(np.uint8)

    # -------------------------------------------------------------------------
    # Glitch Effects
    # -------------------------------------------------------------------------

    def _process_rgb_split(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """RGB channel split"""
        offset = int(amount * 20)
        result = frame.copy()

        # Shift red channel
        result[:, offset:, 0] = frame[:, :-offset, 0] if offset > 0 else frame[:, :, 0]
        # Shift blue channel
        result[:, :-offset, 2] = frame[:, offset:, 2] if offset > 0 else frame[:, :, 2]

        return result

    def _process_scan_lines(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """CRT scan lines"""
        result = frame.copy()
        line_spacing = max(2, int(10 - amount * 8))
        darkness = 0.3 + amount * 0.4

        for i in range(0, frame.shape[0], line_spacing):
            result[i, :] = (result[i, :].astype(np.float32) * darkness).astype(np.uint8)

        return result

    def _process_vhs(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """VHS distortion"""
        result = frame.copy()

        # Add horizontal shift
        shift = int(np.sin(frame_idx * 0.5) * amount * 10)
        if shift > 0:
            result = np.roll(result, shift, axis=1)

        # Add noise
        noise = np.random.randint(-int(amount * 30), int(amount * 30) + 1, frame.shape)
        result = np.clip(result.astype(np.int16) + noise, 0, 255).astype(np.uint8)

        return result

    def _process_noise(
        self, frame: np.ndarray, amount: float, params: Dict,
        frame_idx: int, total: int, prev: Optional[List]
    ) -> np.ndarray:
        """Add noise"""
        noise_level = int(amount * 50)
        noise = np.random.randint(-noise_level, noise_level + 1, frame.shape)
        return np.clip(frame.astype(np.int16) + noise, 0, 255).astype(np.uint8)


# Preset warp chains
WARP_PRESETS = {
    "retro_vhs": WarpChain(
        name="Retro VHS",
        effects=[
            WarpEffect(WarpType.VHS, amount=0.7),
            WarpEffect(WarpType.SCAN_LINES, amount=0.5),
            WarpEffect(WarpType.SATURATION, amount=0.8),
        ]
    ),
    "psychedelic": WarpChain(
        name="Psychedelic",
        effects=[
            WarpEffect(WarpType.HUE_SHIFT, amount=0.5, animated=True),
            WarpEffect(WarpType.KALEIDOSCOPE, amount=0.8),
            WarpEffect(WarpType.RGB_SPLIT, amount=0.3),
        ]
    ),
    "glitch_art": WarpChain(
        name="Glitch Art",
        effects=[
            WarpEffect(WarpType.RGB_SPLIT, amount=0.6),
            WarpEffect(WarpType.NOISE, amount=0.3),
            WarpEffect(WarpType.POSTERIZE, amount=0.4),
        ]
    ),
    "dreamy": WarpChain(
        name="Dreamy",
        effects=[
            WarpEffect(WarpType.ECHO, amount=0.5),
            WarpEffect(WarpType.BRIGHTNESS, amount=1.1),
            WarpEffect(WarpType.SATURATION, amount=0.7),
        ]
    ),
    "cinematic": WarpChain(
        name="Cinematic",
        effects=[
            WarpEffect(WarpType.CONTRAST, amount=1.2),
            WarpEffect(WarpType.SATURATION, amount=0.9),
            WarpEffect(WarpType.BRIGHTNESS, amount=0.95),
        ]
    ),
}


# Global processor instance
warp_processor = WarpProcessor()


__all__ = [
    # Enums
    "WarpCategory",
    "WarpType",
    # Config
    "WarpKeyframe",
    "WarpEffect",
    "WarpChain",
    # Processing
    "WarpProcessor",
    "warp_processor",
    # Presets
    "WARP_PRESETS",
]

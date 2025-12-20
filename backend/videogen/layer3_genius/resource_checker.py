"""
Auto Resource Checker & Optimizer
=================================

Automatically detects hardware capabilities and configures
optimal settings for video generation.

Features:
- GPU detection and VRAM analysis
- CPU/RAM profiling
- Automatic precision selection
- Batch size optimization
- Memory-efficient configuration
"""

import torch
import platform
import os
from typing import Optional, Dict, Any, Tuple, List
from dataclasses import dataclass
from enum import Enum
import logging
import subprocess

logger = logging.getLogger(__name__)


class GPUVendor(Enum):
    NVIDIA = "nvidia"
    AMD = "amd"
    INTEL = "intel"
    APPLE = "apple"
    UNKNOWN = "unknown"


class PrecisionLevel(Enum):
    FP32 = "fp32"
    FP16 = "fp16"
    BF16 = "bf16"
    INT8 = "int8"
    NF4 = "nf4"


@dataclass
class GPUInfo:
    """GPU hardware information"""
    name: str
    vendor: GPUVendor
    vram_gb: float
    compute_capability: Optional[Tuple[int, int]]
    driver_version: Optional[str]
    cuda_version: Optional[str]
    supports_bf16: bool
    supports_flash_attention: bool
    supports_nf4: bool


@dataclass
class CPUInfo:
    """CPU hardware information"""
    name: str
    cores: int
    threads: int
    frequency_ghz: float
    architecture: str


@dataclass
class SystemInfo:
    """Complete system information"""
    gpu: Optional[GPUInfo]
    cpu: CPUInfo
    ram_gb: float
    os: str
    python_version: str
    torch_version: str
    cuda_available: bool


@dataclass
class HardwareProfile:
    """Hardware profile for optimization decisions"""
    tier: str  # "high", "medium", "low", "cpu_only"
    gpu_info: Optional[GPUInfo]
    available_vram_gb: float
    available_ram_gb: float
    can_use_bf16: bool
    can_use_flash_attention: bool
    can_use_nf4: bool
    recommended_batch_size: int
    recommended_tile_size: int


@dataclass
class OptimalConfig:
    """Optimal configuration for video generation"""
    precision: PrecisionLevel
    batch_size: int
    tile_size: int
    use_flash_attention: bool
    use_tea_cache: bool
    use_tiled_vae: bool
    enable_cpu_offload: bool
    enable_sequential_offload: bool
    max_resolution: Tuple[int, int]
    max_frames: int
    max_duration_seconds: float
    estimated_vram_usage_gb: float
    warnings: List[str]


class ResourceChecker:
    """
    Automatic resource detection and optimization.

    Analyzes system hardware and provides optimal configuration
    for video generation based on available resources.
    """

    # Resolution presets with approximate VRAM requirements
    RESOLUTION_REQUIREMENTS = {
        (854, 480): {"min_vram": 4, "base_frames": 49},    # 480p
        (1280, 720): {"min_vram": 8, "base_frames": 49},   # 720p
        (1920, 1080): {"min_vram": 12, "base_frames": 33}, # 1080p
        (2560, 1440): {"min_vram": 16, "base_frames": 25}, # 1440p
        (3840, 2160): {"min_vram": 24, "base_frames": 17}, # 4K
        (7680, 4320): {"min_vram": 48, "base_frames": 9},  # 8K
    }

    def __init__(self):
        self._system_info: Optional[SystemInfo] = None
        self._hardware_profile: Optional[HardwareProfile] = None

    def check_system(self) -> SystemInfo:
        """
        Analyze complete system hardware.

        Returns:
            SystemInfo with all hardware details
        """
        if self._system_info is not None:
            return self._system_info

        gpu_info = self._detect_gpu()
        cpu_info = self._detect_cpu()
        ram_gb = self._detect_ram()

        self._system_info = SystemInfo(
            gpu=gpu_info,
            cpu=cpu_info,
            ram_gb=ram_gb,
            os=f"{platform.system()} {platform.release()}",
            python_version=platform.python_version(),
            torch_version=torch.__version__,
            cuda_available=torch.cuda.is_available()
        )

        logger.info(f"System detected: {self._system_info}")
        return self._system_info

    def _detect_gpu(self) -> Optional[GPUInfo]:
        """Detect GPU information"""
        if not torch.cuda.is_available():
            # Check for Apple Silicon
            if platform.system() == "Darwin" and platform.processor() == "arm":
                return GPUInfo(
                    name="Apple Silicon",
                    vendor=GPUVendor.APPLE,
                    vram_gb=self._get_apple_gpu_memory(),
                    compute_capability=None,
                    driver_version=None,
                    cuda_version=None,
                    supports_bf16=True,
                    supports_flash_attention=False,
                    supports_nf4=True
                )
            return None

        try:
            device = torch.cuda.current_device()
            props = torch.cuda.get_device_properties(device)
            cc = (props.major, props.minor)

            # Detect CUDA version
            cuda_version = None
            if hasattr(torch.version, 'cuda'):
                cuda_version = torch.version.cuda

            return GPUInfo(
                name=props.name,
                vendor=GPUVendor.NVIDIA,
                vram_gb=props.total_memory / (1024 ** 3),
                compute_capability=cc,
                driver_version=self._get_nvidia_driver_version(),
                cuda_version=cuda_version,
                supports_bf16=cc >= (8, 0),  # Ampere+
                supports_flash_attention=cc >= (8, 0),
                supports_nf4=True
            )
        except Exception as e:
            logger.warning(f"GPU detection failed: {e}")
            return None

    def _detect_cpu(self) -> CPUInfo:
        """Detect CPU information"""
        try:
            import multiprocessing
            cores = multiprocessing.cpu_count()

            return CPUInfo(
                name=platform.processor() or "Unknown CPU",
                cores=cores // 2,  # Approximate physical cores
                threads=cores,
                frequency_ghz=0.0,  # Would need psutil for accurate info
                architecture=platform.machine()
            )
        except Exception as e:
            logger.warning(f"CPU detection failed: {e}")
            return CPUInfo(
                name="Unknown",
                cores=4,
                threads=8,
                frequency_ghz=0.0,
                architecture=platform.machine()
            )

    def _detect_ram(self) -> float:
        """Detect available RAM in GB"""
        try:
            import psutil
            return psutil.virtual_memory().total / (1024 ** 3)
        except ImportError:
            # Fallback
            return 16.0

    def _get_nvidia_driver_version(self) -> Optional[str]:
        """Get NVIDIA driver version"""
        try:
            result = subprocess.run(
                ["nvidia-smi", "--query-gpu=driver_version", "--format=csv,noheader"],
                capture_output=True, text=True
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
        return None

    def _get_apple_gpu_memory(self) -> float:
        """Estimate Apple Silicon GPU memory (shared with RAM)"""
        try:
            import psutil
            total_ram = psutil.virtual_memory().total / (1024 ** 3)
            # Apple Silicon can use up to ~70% of RAM for GPU
            return total_ram * 0.7
        except ImportError:
            return 8.0

    def get_hardware_profile(self) -> HardwareProfile:
        """
        Get hardware profile for optimization.

        Returns:
            HardwareProfile with tier classification
        """
        if self._hardware_profile is not None:
            return self._hardware_profile

        system = self.check_system()

        if system.gpu is None:
            # CPU only
            self._hardware_profile = HardwareProfile(
                tier="cpu_only",
                gpu_info=None,
                available_vram_gb=0,
                available_ram_gb=system.ram_gb,
                can_use_bf16=False,
                can_use_flash_attention=False,
                can_use_nf4=False,
                recommended_batch_size=1,
                recommended_tile_size=256
            )
        else:
            vram = system.gpu.vram_gb

            if vram >= 24:
                tier = "high"
                batch_size = 2
                tile_size = 768
            elif vram >= 16:
                tier = "medium"
                batch_size = 1
                tile_size = 512
            elif vram >= 8:
                tier = "low"
                batch_size = 1
                tile_size = 384
            else:
                tier = "very_low"
                batch_size = 1
                tile_size = 256

            self._hardware_profile = HardwareProfile(
                tier=tier,
                gpu_info=system.gpu,
                available_vram_gb=vram,
                available_ram_gb=system.ram_gb,
                can_use_bf16=system.gpu.supports_bf16,
                can_use_flash_attention=system.gpu.supports_flash_attention,
                can_use_nf4=system.gpu.supports_nf4,
                recommended_batch_size=batch_size,
                recommended_tile_size=tile_size
            )

        return self._hardware_profile

    def get_optimal_config(
        self,
        target_resolution: Tuple[int, int] = (1280, 720),
        target_duration: float = 4.0,
        fps: int = 24
    ) -> OptimalConfig:
        """
        Get optimal configuration for target output.

        Args:
            target_resolution: Target (width, height)
            target_duration: Target duration in seconds
            fps: Frames per second

        Returns:
            OptimalConfig with all optimized settings
        """
        profile = self.get_hardware_profile()
        warnings = []

        # Determine precision
        if profile.tier == "cpu_only":
            precision = PrecisionLevel.FP32
        elif profile.can_use_bf16 and profile.available_vram_gb >= 16:
            precision = PrecisionLevel.BF16
        elif profile.can_use_nf4 and profile.available_vram_gb < 12:
            precision = PrecisionLevel.NF4
        else:
            precision = PrecisionLevel.FP16

        # Calculate frames
        target_frames = int(target_duration * fps)

        # Adjust resolution based on VRAM
        max_resolution = self._get_max_resolution(profile.available_vram_gb)
        if target_resolution[0] * target_resolution[1] > max_resolution[0] * max_resolution[1]:
            warnings.append(f"Resolution reduced to {max_resolution[0]}x{max_resolution[1]} due to VRAM constraints")
            target_resolution = max_resolution

        # Adjust frame count
        max_frames = self._get_max_frames(profile.available_vram_gb, target_resolution)
        if target_frames > max_frames:
            warnings.append(f"Frame count reduced to {max_frames} due to VRAM constraints")
            target_frames = max_frames

        # Calculate estimated VRAM usage
        estimated_vram = self._estimate_vram_usage(
            target_resolution, target_frames, precision
        )

        # Determine offloading
        enable_cpu_offload = profile.available_vram_gb < 12
        enable_sequential_offload = profile.available_vram_gb < 8

        if enable_cpu_offload:
            warnings.append("CPU offloading enabled - generation will be slower")

        return OptimalConfig(
            precision=precision,
            batch_size=profile.recommended_batch_size,
            tile_size=profile.recommended_tile_size,
            use_flash_attention=profile.can_use_flash_attention,
            use_tea_cache=True,  # Always beneficial
            use_tiled_vae=target_resolution[0] >= 1920,
            enable_cpu_offload=enable_cpu_offload,
            enable_sequential_offload=enable_sequential_offload,
            max_resolution=target_resolution,
            max_frames=target_frames,
            max_duration_seconds=target_frames / fps,
            estimated_vram_usage_gb=estimated_vram,
            warnings=warnings
        )

    def _get_max_resolution(self, vram_gb: float) -> Tuple[int, int]:
        """Get maximum resolution for given VRAM"""
        for res, req in reversed(list(self.RESOLUTION_REQUIREMENTS.items())):
            if vram_gb >= req["min_vram"]:
                return res
        return (854, 480)  # Minimum fallback

    def _get_max_frames(
        self,
        vram_gb: float,
        resolution: Tuple[int, int]
    ) -> int:
        """Get maximum frames for given VRAM and resolution"""
        for res, req in self.RESOLUTION_REQUIREMENTS.items():
            if res == resolution:
                # Scale frames based on available VRAM
                vram_ratio = vram_gb / req["min_vram"]
                return min(int(req["base_frames"] * vram_ratio), 120)

        return 25  # Default

    def _estimate_vram_usage(
        self,
        resolution: Tuple[int, int],
        frames: int,
        precision: PrecisionLevel
    ) -> float:
        """Estimate VRAM usage in GB"""
        # Base model size
        base_model_gb = {
            PrecisionLevel.FP32: 56.0,
            PrecisionLevel.FP16: 28.0,
            PrecisionLevel.BF16: 28.0,
            PrecisionLevel.INT8: 14.0,
            PrecisionLevel.NF4: 7.0
        }.get(precision, 28.0)

        # Latent size
        latent_h = resolution[1] // 8
        latent_w = resolution[0] // 8
        latent_channels = 16

        bytes_per_element = 2 if precision in [PrecisionLevel.FP16, PrecisionLevel.BF16] else 4
        latent_size_gb = (frames * latent_channels * latent_h * latent_w * bytes_per_element) / (1024 ** 3)

        # Working memory (attention, etc.)
        working_memory_gb = latent_size_gb * 4

        return base_model_gb + latent_size_gb + working_memory_gb

    def print_report(self) -> str:
        """Generate human-readable hardware report"""
        system = self.check_system()
        profile = self.get_hardware_profile()
        config = self.get_optimal_config()

        report = []
        report.append("=" * 60)
        report.append("ECHOELMUSIC VIDEO GENERATION - HARDWARE REPORT")
        report.append("=" * 60)
        report.append("")

        # System Info
        report.append("SYSTEM:")
        report.append(f"  OS: {system.os}")
        report.append(f"  Python: {system.python_version}")
        report.append(f"  PyTorch: {system.torch_version}")
        report.append(f"  CUDA Available: {system.cuda_available}")
        report.append("")

        # GPU Info
        if system.gpu:
            report.append("GPU:")
            report.append(f"  Name: {system.gpu.name}")
            report.append(f"  VRAM: {system.gpu.vram_gb:.1f} GB")
            if system.gpu.compute_capability:
                cc = system.gpu.compute_capability
                report.append(f"  Compute Capability: {cc[0]}.{cc[1]}")
            report.append(f"  BF16 Support: {system.gpu.supports_bf16}")
            report.append(f"  Flash Attention: {system.gpu.supports_flash_attention}")
        else:
            report.append("GPU: Not detected (CPU mode)")
        report.append("")

        # CPU Info
        report.append("CPU:")
        report.append(f"  Name: {system.cpu.name}")
        report.append(f"  Cores/Threads: {system.cpu.cores}/{system.cpu.threads}")
        report.append("")

        # Memory
        report.append("MEMORY:")
        report.append(f"  RAM: {system.ram_gb:.1f} GB")
        if system.gpu:
            report.append(f"  VRAM: {system.gpu.vram_gb:.1f} GB")
        report.append("")

        # Hardware Profile
        report.append("PROFILE:")
        report.append(f"  Tier: {profile.tier.upper()}")
        report.append(f"  Batch Size: {profile.recommended_batch_size}")
        report.append(f"  Tile Size: {profile.recommended_tile_size}")
        report.append("")

        # Optimal Config
        report.append("RECOMMENDED CONFIG:")
        report.append(f"  Precision: {config.precision.value}")
        report.append(f"  Max Resolution: {config.max_resolution[0]}x{config.max_resolution[1]}")
        report.append(f"  Max Frames: {config.max_frames}")
        report.append(f"  Max Duration: {config.max_duration_seconds:.1f}s")
        report.append(f"  Flash Attention: {config.use_flash_attention}")
        report.append(f"  TeaCache: {config.use_tea_cache}")
        report.append(f"  Tiled VAE: {config.use_tiled_vae}")
        report.append(f"  CPU Offload: {config.enable_cpu_offload}")
        report.append(f"  Est. VRAM: {config.estimated_vram_usage_gb:.1f} GB")
        report.append("")

        if config.warnings:
            report.append("WARNINGS:")
            for warning in config.warnings:
                report.append(f"  ! {warning}")
            report.append("")

        report.append("=" * 60)

        return "\n".join(report)

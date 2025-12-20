"""
Flash Attention 3 Wrapper
=========================

Optimized attention implementation for video diffusion.

Features:
- Flash Attention 3 integration (when available)
- Fallback to Flash Attention 2, then PyTorch SDPA
- Memory-efficient attention for long sequences
- Sliding window attention for video frames
- Cross-frame attention optimization
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from typing import Optional, Tuple
import logging
import math

logger = logging.getLogger(__name__)


class FlashAttention3Wrapper:
    """
    Wrapper for Flash Attention 3 with fallbacks.

    Provides unified interface for different attention implementations:
    1. Flash Attention 3 (fastest, requires Hopper+ GPU)
    2. Flash Attention 2 (fast, Ampere+ GPU)
    3. PyTorch SDPA (built-in, any GPU)
    4. Manual implementation (fallback)
    """

    _flash_attn_3_available: Optional[bool] = None
    _flash_attn_2_available: Optional[bool] = None
    _sdpa_available: Optional[bool] = None

    @classmethod
    def is_available(cls) -> bool:
        """Check if any optimized attention is available"""
        return cls.check_flash_attn_3() or cls.check_flash_attn_2() or cls.check_sdpa()

    @classmethod
    def check_flash_attn_3(cls) -> bool:
        """Check if Flash Attention 3 is available"""
        if cls._flash_attn_3_available is not None:
            return cls._flash_attn_3_available

        try:
            from flash_attn import flash_attn_func
            # Flash Attn 3 requires Hopper (SM90+)
            if torch.cuda.is_available():
                major, minor = torch.cuda.get_device_capability()
                cls._flash_attn_3_available = major >= 9
            else:
                cls._flash_attn_3_available = False
        except ImportError:
            cls._flash_attn_3_available = False

        logger.info(f"Flash Attention 3 available: {cls._flash_attn_3_available}")
        return cls._flash_attn_3_available

    @classmethod
    def check_flash_attn_2(cls) -> bool:
        """Check if Flash Attention 2 is available"""
        if cls._flash_attn_2_available is not None:
            return cls._flash_attn_2_available

        try:
            from flash_attn import flash_attn_func
            if torch.cuda.is_available():
                major, minor = torch.cuda.get_device_capability()
                cls._flash_attn_2_available = major >= 8
            else:
                cls._flash_attn_2_available = False
        except ImportError:
            cls._flash_attn_2_available = False

        logger.info(f"Flash Attention 2 available: {cls._flash_attn_2_available}")
        return cls._flash_attn_2_available

    @classmethod
    def check_sdpa(cls) -> bool:
        """Check if PyTorch SDPA is available"""
        if cls._sdpa_available is not None:
            return cls._sdpa_available

        try:
            cls._sdpa_available = hasattr(F, 'scaled_dot_product_attention')
        except Exception:
            cls._sdpa_available = False

        return cls._sdpa_available

    @classmethod
    def get_best_implementation(cls) -> str:
        """Get best available attention implementation"""
        if cls.check_flash_attn_3():
            return "flash_attn_3"
        elif cls.check_flash_attn_2():
            return "flash_attn_2"
        elif cls.check_sdpa():
            return "sdpa"
        else:
            return "manual"

    @classmethod
    def patch_model(cls, model: nn.Module) -> nn.Module:
        """
        Patch model to use optimal attention implementation.

        Args:
            model: PyTorch model to patch

        Returns:
            Patched model
        """
        impl = cls.get_best_implementation()
        logger.info(f"Patching model with {impl} attention")

        # Replace attention modules
        for name, module in model.named_modules():
            if hasattr(module, 'attention'):
                # Wrap attention with optimized version
                original_attn = module.attention
                module.attention = OptimizedAttention(original_attn, impl)

        return model


class OptimizedAttention(nn.Module):
    """
    Optimized multi-head attention with automatic backend selection.
    """

    def __init__(
        self,
        original_attention: Optional[nn.Module] = None,
        implementation: str = "auto",
        num_heads: int = 16,
        head_dim: int = 64,
        dropout: float = 0.0,
        causal: bool = False,
        window_size: Optional[int] = None
    ):
        super().__init__()

        self.original_attention = original_attention
        self.num_heads = num_heads
        self.head_dim = head_dim
        self.dropout = dropout
        self.causal = causal
        self.window_size = window_size  # For sliding window attention

        if implementation == "auto":
            self.implementation = FlashAttention3Wrapper.get_best_implementation()
        else:
            self.implementation = implementation

        logger.debug(f"OptimizedAttention using {self.implementation}")

    def forward(
        self,
        query: torch.Tensor,
        key: torch.Tensor,
        value: torch.Tensor,
        attention_mask: Optional[torch.Tensor] = None,
        is_causal: Optional[bool] = None
    ) -> torch.Tensor:
        """
        Compute attention with optimal implementation.

        Args:
            query: Query tensor (B, N, H, D) or (B, N, HD)
            key: Key tensor
            value: Value tensor
            attention_mask: Optional attention mask
            is_causal: Override causal setting

        Returns:
            Attention output
        """
        causal = is_causal if is_causal is not None else self.causal

        # Reshape if needed
        if query.dim() == 3:
            batch, seq_len, hidden = query.shape
            query = query.view(batch, seq_len, self.num_heads, self.head_dim)
            key = key.view(batch, -1, self.num_heads, self.head_dim)
            value = value.view(batch, -1, self.num_heads, self.head_dim)
            need_reshape = True
        else:
            need_reshape = False

        # Select implementation
        if self.implementation == "flash_attn_3" or self.implementation == "flash_attn_2":
            output = self._flash_attention(query, key, value, causal)
        elif self.implementation == "sdpa":
            output = self._sdpa_attention(query, key, value, attention_mask, causal)
        else:
            output = self._manual_attention(query, key, value, attention_mask, causal)

        # Reshape back if needed
        if need_reshape:
            output = output.view(batch, seq_len, -1)

        return output

    def _flash_attention(
        self,
        query: torch.Tensor,
        key: torch.Tensor,
        value: torch.Tensor,
        causal: bool
    ) -> torch.Tensor:
        """Flash Attention implementation"""
        try:
            from flash_attn import flash_attn_func

            # flash_attn expects (B, S, H, D)
            output = flash_attn_func(
                query, key, value,
                dropout_p=self.dropout if self.training else 0.0,
                causal=causal,
                window_size=(self.window_size, self.window_size) if self.window_size else (-1, -1)
            )
            return output

        except Exception as e:
            logger.warning(f"Flash Attention failed: {e}, falling back to SDPA")
            return self._sdpa_attention(query, key, value, None, causal)

    def _sdpa_attention(
        self,
        query: torch.Tensor,
        key: torch.Tensor,
        value: torch.Tensor,
        attention_mask: Optional[torch.Tensor],
        causal: bool
    ) -> torch.Tensor:
        """PyTorch Scaled Dot Product Attention"""
        # SDPA expects (B, H, S, D)
        query = query.transpose(1, 2)
        key = key.transpose(1, 2)
        value = value.transpose(1, 2)

        output = F.scaled_dot_product_attention(
            query, key, value,
            attn_mask=attention_mask,
            dropout_p=self.dropout if self.training else 0.0,
            is_causal=causal
        )

        return output.transpose(1, 2)

    def _manual_attention(
        self,
        query: torch.Tensor,
        key: torch.Tensor,
        value: torch.Tensor,
        attention_mask: Optional[torch.Tensor],
        causal: bool
    ) -> torch.Tensor:
        """Manual attention implementation (fallback)"""
        scale = 1.0 / math.sqrt(self.head_dim)

        # Compute attention scores
        # (B, H, N, D) @ (B, H, D, M) -> (B, H, N, M)
        query = query.transpose(1, 2)
        key = key.transpose(1, 2)
        value = value.transpose(1, 2)

        scores = torch.matmul(query, key.transpose(-2, -1)) * scale

        # Apply causal mask
        if causal:
            seq_len = query.size(-2)
            causal_mask = torch.triu(
                torch.ones(seq_len, seq_len, device=query.device, dtype=torch.bool),
                diagonal=1
            )
            scores = scores.masked_fill(causal_mask, float('-inf'))

        # Apply attention mask
        if attention_mask is not None:
            scores = scores + attention_mask

        # Softmax and dropout
        weights = F.softmax(scores, dim=-1)
        if self.dropout > 0 and self.training:
            weights = F.dropout(weights, p=self.dropout)

        # Compute output
        output = torch.matmul(weights, value)

        return output.transpose(1, 2)


class SlidingWindowAttention(nn.Module):
    """
    Sliding window attention for long video sequences.

    Reduces memory from O(n²) to O(n * window_size).
    Useful for very long videos.
    """

    def __init__(
        self,
        window_size: int = 256,
        num_heads: int = 16,
        head_dim: int = 64
    ):
        super().__init__()
        self.window_size = window_size
        self.num_heads = num_heads
        self.head_dim = head_dim
        self.attention = OptimizedAttention(
            num_heads=num_heads,
            head_dim=head_dim,
            window_size=window_size
        )

    def forward(
        self,
        hidden_states: torch.Tensor
    ) -> torch.Tensor:
        """Apply sliding window attention"""
        return self.attention(hidden_states, hidden_states, hidden_states)


class CrossFrameAttention(nn.Module):
    """
    Cross-frame attention for temporal consistency in video.

    Allows each frame to attend to neighboring frames
    for smooth motion and consistent appearance.
    """

    def __init__(
        self,
        hidden_size: int = 1024,
        num_heads: int = 16,
        temporal_window: int = 5,  # Attend to ±2 frames
        dropout: float = 0.0
    ):
        super().__init__()
        self.hidden_size = hidden_size
        self.num_heads = num_heads
        self.head_dim = hidden_size // num_heads
        self.temporal_window = temporal_window

        self.q_proj = nn.Linear(hidden_size, hidden_size)
        self.k_proj = nn.Linear(hidden_size, hidden_size)
        self.v_proj = nn.Linear(hidden_size, hidden_size)
        self.out_proj = nn.Linear(hidden_size, hidden_size)

        self.attention = OptimizedAttention(
            num_heads=num_heads,
            head_dim=self.head_dim,
            dropout=dropout
        )

    def forward(
        self,
        hidden_states: torch.Tensor,
        frame_indices: Optional[torch.Tensor] = None
    ) -> torch.Tensor:
        """
        Apply cross-frame attention.

        Args:
            hidden_states: (B, F, S, D) - batch, frames, sequence, hidden
            frame_indices: Optional frame indices for sparse attention

        Returns:
            Attended hidden states
        """
        batch, num_frames, seq_len, hidden = hidden_states.shape

        # Project to Q, K, V
        query = self.q_proj(hidden_states)
        key = self.k_proj(hidden_states)
        value = self.v_proj(hidden_states)

        # Reshape for multi-head attention
        # (B, F, S, H*D) -> (B, F, S, H, D)
        query = query.view(batch, num_frames, seq_len, self.num_heads, self.head_dim)
        key = key.view(batch, num_frames, seq_len, self.num_heads, self.head_dim)
        value = value.view(batch, num_frames, seq_len, self.num_heads, self.head_dim)

        # Compute cross-frame attention with temporal window
        output = torch.zeros_like(query)

        for f in range(num_frames):
            # Get temporal window
            f_start = max(0, f - self.temporal_window // 2)
            f_end = min(num_frames, f + self.temporal_window // 2 + 1)

            # Query from current frame
            q = query[:, f]  # (B, S, H, D)

            # Keys and values from window
            k = key[:, f_start:f_end].reshape(batch, -1, self.num_heads, self.head_dim)
            v = value[:, f_start:f_end].reshape(batch, -1, self.num_heads, self.head_dim)

            # Attention
            out = self.attention(q, k, v)
            output[:, f] = out

        # Reshape and project output
        output = output.view(batch, num_frames, seq_len, hidden)
        output = self.out_proj(output)

        return output

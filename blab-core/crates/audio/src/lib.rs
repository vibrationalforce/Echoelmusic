//! BLAB Audio Core
//!
//! Cross-platform audio engine with ultra-low latency (<5ms)
//! Supports: iOS, Android, macOS, Windows, Linux, Web
//!
//! Features:
//! - Real-time audio I/O
//! - Multi-track recording
//! - MIDI 2.0 + MPE
//! - Spatial audio (HRTF, Ambisonics)
//! - Bio-reactive parameter mapping
//! - VST3/AU/CLAP plugin hosting

use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::sync::Arc;

pub mod engine;
pub mod processor;
pub mod buffer;
pub mod midi;

pub use engine::AudioEngine;
pub use processor::AudioProcessor;
pub use buffer::AudioBuffer;

/// Audio configuration
#[derive(Debug, Clone)]
pub struct AudioConfig {
    /// Sample rate (Hz)
    pub sample_rate: u32,

    /// Buffer size (frames)
    pub buffer_size: u32,

    /// Number of input channels
    pub input_channels: u16,

    /// Number of output channels
    pub output_channels: u16,
}

impl Default for AudioConfig {
    fn default() -> Self {
        Self {
            sample_rate: 48000,
            buffer_size: 256,  // ~5ms @ 48kHz
            input_channels: 2,
            output_channels: 2,
        }
    }
}

/// Bio-reactive parameters
#[derive(Debug, Clone, Copy)]
pub struct BioParameters {
    /// HRV coherence (0.0 - 1.0)
    pub hrv_coherence: f32,

    /// Heart rate (BPM)
    pub heart_rate: f32,

    /// Breathing rate (breaths/min)
    pub breathing_rate: f32,

    /// Audio level (0.0 - 1.0)
    pub audio_level: f32,

    /// Voice pitch (Hz)
    pub voice_pitch: f32,
}

impl Default for BioParameters {
    fn default() -> Self {
        Self {
            hrv_coherence: 0.5,
            heart_rate: 70.0,
            breathing_rate: 12.0,
            audio_level: 0.5,
            voice_pitch: 0.0,
        }
    }
}

/// Initialize audio engine
pub fn init() -> Result<AudioEngine> {
    let config = AudioConfig::default();
    AudioEngine::new(config).context("Failed to initialize audio engine")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_audio_config_default() {
        let config = AudioConfig::default();
        assert_eq!(config.sample_rate, 48000);
        assert_eq!(config.buffer_size, 256);
    }

    #[test]
    fn test_bio_parameters_default() {
        let bio = BioParameters::default();
        assert_eq!(bio.heart_rate, 70.0);
        assert_eq!(bio.breathing_rate, 12.0);
    }
}

//! Audio Engine - Core audio processing system

use crate::{AudioConfig, BioParameters};
use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::sync::{Arc, Mutex};

/// Main audio engine
pub struct AudioEngine {
    config: AudioConfig,
    stream: Option<cpal::Stream>,
    processor: Arc<Mutex<AudioProcessor>>,
}

impl AudioEngine {
    /// Create new audio engine
    pub fn new(config: AudioConfig) -> Result<Self> {
        let processor = Arc::new(Mutex::new(AudioProcessor::new(&config)));

        Ok(Self {
            config,
            stream: None,
            processor,
        })
    }

    /// Start audio processing
    pub fn start(&mut self) -> Result<()> {
        let host = cpal::default_host();
        let device = host
            .default_output_device()
            .context("No output device available")?;

        let config = cpal::StreamConfig {
            channels: self.config.output_channels,
            sample_rate: cpal::SampleRate(self.config.sample_rate),
            buffer_size: cpal::BufferSize::Fixed(self.config.buffer_size),
        };

        let processor = Arc::clone(&self.processor);

        let stream = device.build_output_stream(
            &config,
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                if let Ok(mut proc) = processor.lock() {
                    proc.process(data);
                }
            },
            |err| eprintln!("Audio stream error: {}", err),
            None,
        )?;

        stream.play()?;
        self.stream = Some(stream);

        Ok(())
    }

    /// Stop audio processing
    pub fn stop(&mut self) {
        self.stream = None;
    }

    /// Update bio-reactive parameters
    pub fn update_bio_parameters(&self, params: BioParameters) {
        if let Ok(mut proc) = self.processor.lock() {
            proc.update_bio_parameters(params);
        }
    }

    /// Get current latency (ms)
    pub fn get_latency_ms(&self) -> f32 {
        let samples = self.config.buffer_size as f32;
        let rate = self.config.sample_rate as f32;
        (samples / rate) * 1000.0
    }
}

/// Audio processor (DSP)
pub struct AudioProcessor {
    sample_rate: f32,
    bio_params: BioParameters,
    phase: f32,  // For test tone
}

impl AudioProcessor {
    pub fn new(config: &AudioConfig) -> Self {
        Self {
            sample_rate: config.sample_rate as f32,
            bio_params: BioParameters::default(),
            phase: 0.0,
        }
    }

    /// Process audio buffer
    pub fn process(&mut self, output: &mut [f32]) {
        // Bio-reactive sine wave (440 Hz * HRV coherence)
        let freq = 440.0 * (0.5 + self.bio_params.hrv_coherence);
        let phase_increment = freq / self.sample_rate;

        for sample in output.iter_mut() {
            *sample = (self.phase * 2.0 * std::f32::consts::PI).sin() * 0.2;
            self.phase += phase_increment;
            if self.phase >= 1.0 {
                self.phase -= 1.0;
            }
        }
    }

    pub fn update_bio_parameters(&mut self, params: BioParameters) {
        self.bio_params = params;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_audio_processor() {
        let config = AudioConfig::default();
        let mut processor = AudioProcessor::new(&config);

        let mut buffer = vec![0.0; 256];
        processor.process(&mut buffer);

        // Check that output is non-zero
        assert!(buffer.iter().any(|&x| x != 0.0));
    }

    #[test]
    fn test_latency_calculation() {
        let config = AudioConfig {
            sample_rate: 48000,
            buffer_size: 256,
            ..Default::default()
        };

        let engine = AudioEngine::new(config).unwrap();
        let latency = engine.get_latency_ms();

        // 256 samples @ 48kHz = ~5.33ms
        assert!((latency - 5.33).abs() < 0.1);
    }
}

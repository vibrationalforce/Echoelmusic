//! BLAB Visual Core
//!
//! Cross-platform GPU-accelerated visual engine
//! Supports: Metal (iOS/macOS), Vulkan (Android/Linux), DirectX 12 (Windows), WebGPU (Web)
//!
//! Features:
//! - 100,000+ particle systems
//! - Audio-reactive shaders
//! - Bio-reactive visuals
//! - Real-time cymatics
//! - Fractal generation
//! - Video compositing

use anyhow::{Context, Result};
use wgpu::util::DeviceExt;

pub mod particles;
pub mod shaders;
pub mod renderer;

pub use particles::ParticleSystem;
pub use renderer::{RenderPipeline, RenderPipelineConfig, CymaticsRenderer};

/// GPU backend selection
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GpuBackend {
    /// Metal (iOS, macOS)
    Metal,
    /// Vulkan (Android, Linux, Windows)
    Vulkan,
    /// DirectX 12 (Windows)
    DirectX12,
    /// OpenGL (Fallback)
    OpenGL,
    /// WebGPU (Web)
    WebGPU,
}

impl GpuBackend {
    /// Get appropriate backend for current platform
    pub fn auto_select() -> Self {
        #[cfg(target_os = "ios")]
        return Self::Metal;

        #[cfg(target_os = "macos")]
        return Self::Metal;

        #[cfg(target_os = "android")]
        return Self::Vulkan;

        #[cfg(target_os = "windows")]
        return Self::DirectX12;

        #[cfg(target_os = "linux")]
        return Self::Vulkan;

        #[cfg(target_arch = "wasm32")]
        return Self::WebGPU;
    }

    /// Convert to wgpu backend
    pub fn to_wgpu_backends(self) -> wgpu::Backends {
        match self {
            Self::Metal => wgpu::Backends::METAL,
            Self::Vulkan => wgpu::Backends::VULKAN,
            Self::DirectX12 => wgpu::Backends::DX12,
            Self::OpenGL => wgpu::Backends::GL,
            Self::WebGPU => wgpu::Backends::BROWSER_WEBGPU,
        }
    }
}

/// Visual engine configuration
#[derive(Debug, Clone)]
pub struct VisualConfig {
    /// GPU backend (auto-selected by default)
    pub backend: GpuBackend,

    /// Target frame rate
    pub target_fps: u32,

    /// Particle count
    pub particle_count: u32,

    /// Enable bio-reactivity
    pub bio_reactive: bool,

    /// Enable audio-reactivity
    pub audio_reactive: bool,
}

impl Default for VisualConfig {
    fn default() -> Self {
        Self {
            backend: GpuBackend::auto_select(),
            target_fps: 60,
            particle_count: 10000,
            bio_reactive: true,
            audio_reactive: true,
        }
    }
}

/// Bio-reactive visual parameters
#[derive(Debug, Clone, Copy)]
pub struct BioVisualParams {
    /// HRV coherence (0.0 - 1.0) → Color hue
    pub hrv_coherence: f32,

    /// Heart rate (BPM) → Animation speed
    pub heart_rate: f32,

    /// Breathing rate (breaths/min) → Particle density
    pub breathing_rate: f32,

    /// Audio level (0.0 - 1.0) → Brightness
    pub audio_level: f32,

    /// Frequency (Hz) → Pattern frequency
    pub frequency: f32,
}

impl Default for BioVisualParams {
    fn default() -> Self {
        Self {
            hrv_coherence: 0.5,
            heart_rate: 70.0,
            breathing_rate: 12.0,
            audio_level: 0.5,
            frequency: 440.0,
        }
    }
}

/// Visual engine
pub struct VisualEngine {
    config: VisualConfig,
    instance: wgpu::Instance,
    adapter: wgpu::Adapter,
    device: wgpu::Device,
    queue: wgpu::Queue,
    particle_system: Option<ParticleSystem>,
}

impl VisualEngine {
    /// Create new visual engine
    pub async fn new(config: VisualConfig) -> Result<Self> {
        // Create wgpu instance with selected backend
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends: config.backend.to_wgpu_backends(),
            dx12_shader_compiler: Default::default(),
            flags: wgpu::InstanceFlags::default(),
            gles_minor_version: wgpu::Gles3MinorVersion::Automatic,
        });

        // Get adapter (GPU)
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                force_fallback_adapter: false,
                compatible_surface: None,
            })
            .await
            .context("Failed to find suitable GPU adapter")?;

        // Get device and queue
        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    label: Some("BLAB Visual Device"),
                    required_features: wgpu::Features::empty(),
                    required_limits: wgpu::Limits::default(),
                },
                None,
            )
            .await
            .context("Failed to create GPU device")?;

        println!(
            "[VisualEngine] Initialized with backend: {:?}",
            config.backend
        );
        println!("[VisualEngine] GPU: {}", adapter.get_info().name);

        Ok(Self {
            config,
            instance,
            adapter,
            device,
            queue,
            particle_system: None,
        })
    }

    /// Initialize particle system
    pub fn init_particles(&mut self, count: u32) -> Result<()> {
        let particle_system = ParticleSystem::new(&self.device, count)?;
        self.particle_system = Some(particle_system);
        println!("[VisualEngine] Initialized {} particles", count);
        Ok(())
    }

    /// Update with bio-reactive parameters
    pub fn update(&mut self, params: BioVisualParams, delta_time: f32) {
        if let Some(particles) = &mut self.particle_system {
            particles.update(&self.device, &self.queue, params, delta_time);
        }
    }

    /// Render frame
    pub fn render(&self, surface: &wgpu::Surface, width: u32, height: u32) -> Result<()> {
        // Get surface texture
        let output = surface.get_current_texture()?;
        let view = output
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        // Create command encoder
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Render Encoder"),
            });

        // Render pass
        {
            let _render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Render Pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color {
                            r: 0.05,
                            g: 0.05,
                            b: 0.15,
                            a: 1.0,
                        }),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
            });

            // Render particles here
        }

        // Submit commands
        self.queue.submit(std::iter::once(encoder.finish()));
        output.present();

        Ok(())
    }

    /// Get GPU info
    pub fn gpu_info(&self) -> String {
        let info = self.adapter.get_info();
        format!(
            "{} (Backend: {:?}, Type: {:?})",
            info.name, info.backend, info.device_type
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_backend_selection() {
        let backend = GpuBackend::auto_select();
        println!("Auto-selected backend: {:?}", backend);

        #[cfg(target_os = "ios")]
        assert_eq!(backend, GpuBackend::Metal);

        #[cfg(target_os = "android")]
        assert_eq!(backend, GpuBackend::Vulkan);
    }

    #[test]
    fn test_visual_config() {
        let config = VisualConfig::default();
        assert_eq!(config.target_fps, 60);
        assert_eq!(config.particle_count, 10000);
    }

    #[tokio::test]
    async fn test_visual_engine_init() {
        let config = VisualConfig::default();
        let result = VisualEngine::new(config).await;

        // May fail in CI without GPU
        if let Ok(engine) = result {
            println!("GPU: {}", engine.gpu_info());
        }
    }
}

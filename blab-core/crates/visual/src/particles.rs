//! GPU Particle System
//!
//! 100,000+ particles with compute shader physics

use anyhow::Result;
use bytemuck::{Pod, Zeroable};
use wgpu::util::DeviceExt;

/// Single particle (GPU layout)
#[repr(C)]
#[derive(Debug, Clone, Copy, Pod, Zeroable)]
pub struct Particle {
    /// Position (x, y)
    pub position: [f32; 2],
    /// Velocity (vx, vy)
    pub velocity: [f32; 2],
    /// Color (hue)
    pub hue: f32,
    /// Life (0.0 - 1.0)
    pub life: f32,
    /// Size (pixels)
    pub size: f32,
    /// Brightness (0.0 - 1.0)
    pub brightness: f32,
}

/// Particle system uniforms
#[repr(C)]
#[derive(Debug, Clone, Copy, Pod, Zeroable)]
pub struct ParticleUniforms {
    /// Time (seconds)
    pub time: f32,
    /// Delta time (seconds)
    pub delta_time: f32,
    /// Audio level (0.0 - 1.0)
    pub audio_level: f32,
    /// Frequency (Hz)
    pub frequency: f32,
    /// HRV coherence (0.0 - 1.0)
    pub hrv_coherence: f32,
    /// Heart rate (BPM)
    pub heart_rate: f32,
    /// Breathing rate (breaths/min)
    pub breathing_rate: f32,
    /// Particle count
    pub particle_count: u32,
}

/// GPU particle system
pub struct ParticleSystem {
    particle_buffer: wgpu::Buffer,
    uniform_buffer: wgpu::Buffer,
    compute_pipeline: wgpu::ComputePipeline,
    bind_group: wgpu::BindGroup,
    particle_count: u32,
    time: f32,
}

impl ParticleSystem {
    /// Create new particle system
    pub fn new(device: &wgpu::Device, count: u32) -> Result<Self> {
        // Initialize particles
        let particles = vec![
            Particle {
                position: [0.0, 0.0],
                velocity: [0.0, 0.0],
                hue: 0.5,
                life: 1.0,
                size: 2.0,
                brightness: 1.0,
            };
            count as usize
        ];

        // Create particle buffer
        let particle_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Particle Buffer"),
            contents: bytemuck::cast_slice(&particles),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        });

        // Create uniform buffer
        let uniforms = ParticleUniforms {
            time: 0.0,
            delta_time: 0.016,
            audio_level: 0.5,
            frequency: 440.0,
            hrv_coherence: 0.5,
            heart_rate: 70.0,
            breathing_rate: 12.0,
            particle_count: count,
        };

        let uniform_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Particle Uniforms"),
            contents: bytemuck::cast_slice(&[uniforms]),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        });

        // Create compute shader (placeholder)
        let compute_shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Particle Compute Shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("shaders/particles.wgsl").into()),
        });

        // Create compute pipeline
        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Particle Bind Group Layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::COMPUTE,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Storage { read_only: false },
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::COMPUTE,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
            ],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("Particle Pipeline Layout"),
            bind_group_layouts: &[&bind_group_layout],
            push_constant_ranges: &[],
        });

        let compute_pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
            label: Some("Particle Compute Pipeline"),
            layout: Some(&pipeline_layout),
            module: &compute_shader,
            entry_point: "main",
        });

        // Create bind group
        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("Particle Bind Group"),
            layout: &bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: particle_buffer.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: uniform_buffer.as_entire_binding(),
                },
            ],
        });

        Ok(Self {
            particle_buffer,
            uniform_buffer,
            compute_pipeline,
            bind_group,
            particle_count: count,
            time: 0.0,
        })
    }

    /// Update particles
    pub fn update(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        params: super::BioVisualParams,
        delta_time: f32,
    ) {
        self.time += delta_time;

        // Update uniforms
        let uniforms = ParticleUniforms {
            time: self.time,
            delta_time,
            audio_level: params.audio_level,
            frequency: params.frequency,
            hrv_coherence: params.hrv_coherence,
            heart_rate: params.heart_rate,
            breathing_rate: params.breathing_rate,
            particle_count: self.particle_count,
        };

        queue.write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&[uniforms]));

        // Run compute shader
        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("Particle Update Encoder"),
        });

        {
            let mut compute_pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
                label: Some("Particle Compute Pass"),
                timestamp_writes: None,
            });

            compute_pass.set_pipeline(&self.compute_pipeline);
            compute_pass.set_bind_group(0, &self.bind_group, &[]);

            // Dispatch compute shader (64 threads per workgroup)
            let workgroup_count = (self.particle_count + 63) / 64;
            compute_pass.dispatch_workgroups(workgroup_count, 1, 1);
        }

        queue.submit(std::iter::once(encoder.finish()));
    }
}

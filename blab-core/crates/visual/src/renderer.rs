//! Render Pipeline for Bio-Reactive Visuals
//!
//! High-performance GPU renderer supporting:
//! - Particle systems (100k+)
//! - Cymatics visualization
//! - Fractal generation
//! - Real-time effects

use wgpu::util::DeviceExt;
use anyhow::Result;

/// Render pipeline configuration
pub struct RenderPipelineConfig {
    pub width: u32,
    pub height: u32,
    pub sample_count: u32,
    pub format: wgpu::TextureFormat,
}

impl Default for RenderPipelineConfig {
    fn default() -> Self {
        Self {
            width: 1920,
            height: 1080,
            sample_count: 1,
            format: wgpu::TextureFormat::Bgra8UnormSrgb,
        }
    }
}

/// Main render pipeline
pub struct RenderPipeline {
    config: RenderPipelineConfig,
    particle_render_pipeline: wgpu::RenderPipeline,
    cymatics_render_pipeline: Option<wgpu::RenderPipeline>,
    vertex_buffer: wgpu::Buffer,
    index_buffer: wgpu::Buffer,
    num_indices: u32,
}

impl RenderPipeline {
    /// Create new render pipeline
    pub fn new(
        device: &wgpu::Device,
        config: RenderPipelineConfig,
    ) -> Result<Self> {
        // Create particle render pipeline
        let particle_shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Particle Shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("shaders/particle_render.wgsl").into()),
        });

        let particle_render_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Particle Render Pipeline"),
            layout: None,
            vertex: wgpu::VertexState {
                module: &particle_shader,
                entry_point: "vs_main",
                buffers: &[
                    wgpu::VertexBufferLayout {
                        array_stride: std::mem::size_of::<crate::particles::Particle>() as wgpu::BufferAddress,
                        step_mode: wgpu::VertexStepMode::Instance,
                        attributes: &wgpu::vertex_attr_array![
                            0 => Float32x2,  // position
                            1 => Float32x2,  // velocity
                            2 => Float32,    // hue
                            3 => Float32,    // life
                            4 => Float32,    // size
                            5 => Float32,    // brightness
                        ],
                    },
                ],
            },
            fragment: Some(wgpu::FragmentState {
                module: &particle_shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format: config.format,
                    blend: Some(wgpu::BlendState {
                        color: wgpu::BlendComponent {
                            src_factor: wgpu::BlendFactor::SrcAlpha,
                            dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                            operation: wgpu::BlendOperation::Add,
                        },
                        alpha: wgpu::BlendComponent {
                            src_factor: wgpu::BlendFactor::One,
                            dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                            operation: wgpu::BlendOperation::Add,
                        },
                    }),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: None,
                unclipped_depth: false,
                polygon_mode: wgpu::PolygonMode::Fill,
                conservative: false,
            },
            depth_stencil: None,
            multisample: wgpu::MultisampleState {
                count: config.sample_count,
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            multiview: None,
        });

        // Create quad vertices for particle billboarding
        let vertices: &[f32] = &[
            -0.5, -0.5,  // Bottom-left
             0.5, -0.5,  // Bottom-right
             0.5,  0.5,  // Top-right
            -0.5,  0.5,  // Top-left
        ];

        let vertex_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Particle Quad Vertex Buffer"),
            contents: bytemuck::cast_slice(vertices),
            usage: wgpu::BufferUsages::VERTEX,
        });

        let indices: &[u16] = &[
            0, 1, 2,  // First triangle
            2, 3, 0,  // Second triangle
        ];

        let index_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Particle Quad Index Buffer"),
            contents: bytemuck::cast_slice(indices),
            usage: wgpu::BufferUsages::INDEX,
        });

        Ok(Self {
            config,
            particle_render_pipeline,
            cymatics_render_pipeline: None,
            vertex_buffer,
            index_buffer,
            num_indices: indices.len() as u32,
        })
    }

    /// Render particles to texture
    pub fn render_particles(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
        particle_buffer: &wgpu::Buffer,
        particle_count: u32,
        bind_group: &wgpu::BindGroup,
    ) {
        let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("Particle Render Pass"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(wgpu::Color {
                        r: 0.0,
                        g: 0.0,
                        b: 0.0,
                        a: 1.0,
                    }),
                    store: wgpu::StoreOp::Store,
                },
            })],
            depth_stencil_attachment: None,
            timestamp_writes: None,
            occlusion_query_set: None,
        });

        render_pass.set_pipeline(&self.particle_render_pipeline);
        render_pass.set_bind_group(0, bind_group, &[]);
        render_pass.set_vertex_buffer(0, particle_buffer.slice(..));
        render_pass.set_vertex_buffer(1, self.vertex_buffer.slice(..));
        render_pass.set_index_buffer(self.index_buffer.slice(..), wgpu::IndexFormat::Uint16);
        render_pass.draw_indexed(0..self.num_indices, 0, 0..particle_count);
    }

    /// Get render configuration
    pub fn config(&self) -> &RenderPipelineConfig {
        &self.config
    }

    /// Resize render targets
    pub fn resize(&mut self, width: u32, height: u32) {
        self.config.width = width;
        self.config.height = height;
    }
}

/// Cymatics visualization renderer
pub struct CymaticsRenderer {
    pipeline: wgpu::RenderPipeline,
    bind_group: wgpu::BindGroup,
    frequency_buffer: wgpu::Buffer,
}

impl CymaticsRenderer {
    /// Create new cymatics renderer
    pub fn new(device: &wgpu::Device, format: wgpu::TextureFormat) -> Result<Self> {
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Cymatics Shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("shaders/cymatics.wgsl").into()),
        });

        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Cymatics Bind Group Layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
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
            label: Some("Cymatics Pipeline Layout"),
            bind_group_layouts: &[&bind_group_layout],
            push_constant_ranges: &[],
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Cymatics Render Pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: "vs_main",
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format,
                    blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
        });

        // Create frequency buffer
        let frequency_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Cymatics Frequency Buffer"),
            size: std::mem::size_of::<CymaticsUniforms>() as u64,
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("Cymatics Bind Group"),
            layout: &bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: frequency_buffer.as_entire_binding(),
                },
            ],
        });

        Ok(Self {
            pipeline,
            bind_group,
            frequency_buffer,
        })
    }

    /// Update frequency data
    pub fn update_frequency(&self, queue: &wgpu::Queue, frequency: f32, amplitude: f32) {
        let uniforms = CymaticsUniforms {
            frequency,
            amplitude,
            time: 0.0, // Updated per frame
            _padding: 0.0,
        };

        queue.write_buffer(&self.frequency_buffer, 0, bytemuck::bytes_of(&uniforms));
    }

    /// Render cymatics pattern
    pub fn render(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        view: &wgpu::TextureView,
    ) {
        let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("Cymatics Render Pass"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Load,
                    store: wgpu::StoreOp::Store,
                },
            })],
            depth_stencil_attachment: None,
            timestamp_writes: None,
            occlusion_query_set: None,
        });

        render_pass.set_pipeline(&self.pipeline);
        render_pass.set_bind_group(0, &self.bind_group, &[]);
        render_pass.draw(0..6, 0..1); // Full-screen quad
    }
}

#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
struct CymaticsUniforms {
    frequency: f32,
    amplitude: f32,
    time: f32,
    _padding: f32,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_render_pipeline_creation() {
        // Test requires GPU context, skip in CI
        // Integration tests will cover this
    }
}

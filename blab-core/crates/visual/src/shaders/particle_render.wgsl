// Particle Rendering Shader
// Renders bio-reactive particles to screen with instancing

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) uv: vec2<f32>,
};

struct Particle {
    @location(0) particle_pos: vec2<f32>,
    @location(1) velocity: vec2<f32>,
    @location(2) hue: f32,
    @location(3) life: f32,
    @location(4) size: f32,
    @location(5) brightness: f32,
};

struct Uniforms {
    resolution: vec2<f32>,
    time: f32,
    _padding: f32,
};

@group(0) @binding(0)
var<uniform> uniforms: Uniforms;

// Vertex shader - instanced particle rendering
@vertex
fn vs_main(
    @builtin(vertex_index) vertex_index: u32,
    @builtin(instance_index) instance_index: u32,
    particle: Particle,
) -> VertexOutput {
    var output: VertexOutput;

    // Quad vertices (billboarding)
    var positions = array<vec2<f32>, 6>(
        vec2<f32>(-0.5, -0.5),
        vec2<f32>( 0.5, -0.5),
        vec2<f32>( 0.5,  0.5),
        vec2<f32>(-0.5, -0.5),
        vec2<f32>( 0.5,  0.5),
        vec2<f32>(-0.5,  0.5)
    );

    var uvs = array<vec2<f32>, 6>(
        vec2<f32>(0.0, 0.0),
        vec2<f32>(1.0, 0.0),
        vec2<f32>(1.0, 1.0),
        vec2<f32>(0.0, 0.0),
        vec2<f32>(1.0, 1.0),
        vec2<f32>(0.0, 1.0)
    );

    let quad_pos = positions[vertex_index];
    output.uv = uvs[vertex_index];

    // Scale by particle size
    let scaled_pos = quad_pos * particle.size;

    // World position
    let world_pos = particle.particle_pos + scaled_pos;

    // NDC conversion (0,0 center, -1..1 range)
    let ndc_pos = vec2<f32>(
        (world_pos.x / uniforms.resolution.x) * 2.0 - 1.0,
        -((world_pos.y / uniforms.resolution.y) * 2.0 - 1.0)
    );

    output.position = vec4<f32>(ndc_pos, 0.0, 1.0);

    // HSV to RGB color conversion
    output.color = vec4<f32>(hsv_to_rgb(particle.hue, 0.8, particle.brightness), particle.life);

    return output;
}

// Fragment shader - circular particle with glow
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    // UV to center distance
    let center = vec2<f32>(0.5, 0.5);
    let dist = distance(input.uv, center);

    // Circular fade (soft edge)
    let alpha = smoothstep(0.5, 0.3, dist);

    // Glow effect
    let glow = exp(-dist * 8.0);

    var color = input.color;
    color.a *= alpha * input.color.a;
    color.rgb += color.rgb * glow * 0.3;

    return color;
}

// HSV to RGB conversion
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let x = c * (1.0 - abs((h * 6.0) % 2.0 - 1.0));
    let m = v - c;

    var rgb: vec3<f32>;

    if (h < 0.166667) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (h < 0.333333) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (h < 0.5) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (h < 0.666667) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (h < 0.833333) {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }

    return rgb + vec3<f32>(m, m, m);
}

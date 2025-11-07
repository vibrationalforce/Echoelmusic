// Flow Field Compute Shader
// Bio-reactive vector field for particle guidance

struct FlowFieldUniforms {
    // Resolution
    width: u32,
    height: u32,

    // Bio-parameters
    hrv_coherence: f32,     // Field complexity
    heart_rate: f32,        // Rotation speed
    breathing_rate: f32,    // Wave frequency
    audio_level: f32,       // Turbulence strength

    // Physics
    flow_strength: f32,     // Field force magnitude
    noise_scale: f32,       // Noise detail level
    time: f32,              // Animation time

    _padding: f32,
};

@group(0) @binding(0)
var<uniform> uniforms: FlowFieldUniforms;

// Output: 2D vector field (direction + magnitude)
@group(0) @binding(1)
var<storage, read_write> flow_field: array<vec2<f32>>;

// Perlin noise implementation
fn hash(p: vec2<f32>) -> f32 {
    var h = dot(p, vec2<f32>(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

fn noise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);

    let a = hash(i);
    let b = hash(i + vec2<f32>(1.0, 0.0));
    let c = hash(i + vec2<f32>(0.0, 1.0));
    let d = hash(i + vec2<f32>(1.0, 1.0));

    let u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractal Brownian Motion (multi-octave noise)
fn fbm(p: vec2<f32>, octaves: u32) -> f32 {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    var pos = p;

    for (var i: u32 = 0u; i < octaves; i = i + 1u) {
        value += amplitude * noise(pos * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// Curl noise for divergence-free flow
fn curl_noise(p: vec2<f32>) -> vec2<f32> {
    let eps = 0.01;

    // Sample noise around point
    let n_x = fbm(vec2<f32>(p.x + eps, p.y), 4u);
    let n_y = fbm(vec2<f32>(p.x, p.y + eps), 4u);
    let n_center = fbm(p, 4u);

    // Compute curl (∇ × noise)
    let dx = (n_x - n_center) / eps;
    let dy = (n_y - n_center) / eps;

    return vec2<f32>(dy, -dx);
}

// Vortex field (heart rate driven)
fn vortex_field(p: vec2<f32>, center: vec2<f32>, strength: f32) -> vec2<f32> {
    let delta = p - center;
    let dist = length(delta);

    if (dist < 0.001) {
        return vec2<f32>(0.0, 0.0);
    }

    let angle = atan2(delta.y, delta.x);
    let tangent = vec2<f32>(-sin(angle), cos(angle));

    // Vortex strength falls off with distance
    let vortex_strength = strength / (1.0 + dist * dist);

    return tangent * vortex_strength;
}

// Breathing wave field
fn breathing_wave(p: vec2<f32>, time: f32, frequency: f32) -> vec2<f32> {
    let wave_phase = sin(p.x * frequency + time) * cos(p.y * frequency + time);
    let wave_x = cos(wave_phase * 3.14159);
    let wave_y = sin(wave_phase * 3.14159);

    return vec2<f32>(wave_x, wave_y);
}

// Compute shader main
@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let x = global_id.x;
    let y = global_id.y;

    if (x >= uniforms.width || y >= uniforms.height) {
        return;
    }

    // Normalize coordinates to [-1, 1]
    let pos = vec2<f32>(
        (f32(x) / f32(uniforms.width)) * 2.0 - 1.0,
        (f32(y) / f32(uniforms.height)) * 2.0 - 1.0
    );

    // Time-varying noise position
    let noise_pos = pos * uniforms.noise_scale + vec2<f32>(uniforms.time * 0.1, 0.0);

    // Base curl noise field
    var flow = curl_noise(noise_pos) * uniforms.flow_strength;

    // Add HRV-driven vortices (coherence determines number and strength)
    let vortex_count = u32(uniforms.hrv_coherence * 4.0) + 1u;
    for (var i: u32 = 0u; i < vortex_count; i = i + 1u) {
        let angle = f32(i) / f32(vortex_count) * 6.283185 + uniforms.time * uniforms.heart_rate / 60.0;
        let vortex_center = vec2<f32>(
            cos(angle) * 0.5,
            sin(angle) * 0.5
        );
        flow += vortex_field(pos, vortex_center, uniforms.hrv_coherence * 0.3);
    }

    // Add breathing-reactive wave
    let breathing_freq = uniforms.breathing_rate / 10.0;
    let breathing_time = uniforms.time * uniforms.breathing_rate / 60.0 * 6.283185;
    flow += breathing_wave(pos, breathing_time, breathing_freq) * 0.2;

    // Add audio-reactive turbulence
    let turbulence = curl_noise(noise_pos * 2.0 + vec2<f32>(uniforms.time * 0.5, 0.0));
    flow += turbulence * uniforms.audio_level * 0.5;

    // Normalize and scale
    let magnitude = length(flow);
    if (magnitude > 0.001) {
        flow = normalize(flow) * min(magnitude, 2.0);
    }

    // Write to output buffer
    let index = y * uniforms.width + x;
    flow_field[index] = flow;
}

// Helper: Sample flow field at position (bilinear interpolation)
fn sample_flow_field(pos: vec2<f32>) -> vec2<f32> {
    // Convert position to grid coordinates
    let grid_x = (pos.x + 1.0) * 0.5 * f32(uniforms.width);
    let grid_y = (pos.y + 1.0) * 0.5 * f32(uniforms.height);

    // Get integer coordinates
    let x0 = u32(floor(grid_x));
    let y0 = u32(floor(grid_y));
    let x1 = min(x0 + 1u, uniforms.width - 1u);
    let y1 = min(y0 + 1u, uniforms.height - 1u);

    // Get fractional part
    let fx = fract(grid_x);
    let fy = fract(grid_y);

    // Sample four corners
    let f00 = flow_field[y0 * uniforms.width + x0];
    let f10 = flow_field[y0 * uniforms.width + x1];
    let f01 = flow_field[y1 * uniforms.width + x0];
    let f11 = flow_field[y1 * uniforms.width + x1];

    // Bilinear interpolation
    let f0 = mix(f00, f10, fx);
    let f1 = mix(f01, f11, fx);

    return mix(f0, f1, fy);
}

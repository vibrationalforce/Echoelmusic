// Audio Spectrum Visualization Shader
// Real-time frequency spectrum with bio-reactive colors

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

struct SpectrumUniforms {
    // Bio-parameters
    hrv_coherence: f32,    // Color gradient
    heart_rate: f32,       // Animation speed
    breathing_rate: f32,   // Bar width modulation

    // Audio parameters
    audio_level: f32,      // Overall volume
    time: f32,             // Animation time

    // Visual config
    bar_count: u32,        // Number of frequency bars
    smoothing: f32,        // Temporal smoothing
    gain: f32,             // Amplitude multiplier

    _padding: vec3<f32>,
};

@group(0) @binding(0)
var<uniform> uniforms: SpectrumUniforms;

// FFT magnitude data (256 bins)
@group(0) @binding(1)
var<storage, read> fft_data: array<f32>;

// Vertex shader
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    var output: VertexOutput;

    var positions = array<vec2<f32>, 6>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>( 1.0, -1.0),
        vec2<f32>( 1.0,  1.0),
        vec2<f32>(-1.0, -1.0),
        vec2<f32>( 1.0,  1.0),
        vec2<f32>(-1.0,  1.0)
    );

    var uvs = array<vec2<f32>, 6>(
        vec2<f32>(0.0, 0.0),
        vec2<f32>(1.0, 0.0),
        vec2<f32>(1.0, 1.0),
        vec2<f32>(0.0, 0.0),
        vec2<f32>(1.0, 1.0),
        vec2<f32>(0.0, 1.0)
    );

    output.position = vec4<f32>(positions[vertex_index], 0.0, 1.0);
    output.uv = uvs[vertex_index];

    return output;
}

// Fragment shader
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    let uv = input.uv;

    // Determine which frequency bin this pixel represents
    let bar_width = 1.0 / f32(uniforms.bar_count);
    let bar_index = u32(uv.x / bar_width);

    // Calculate position within bar
    let bar_uv_x = fract(uv.x * f32(uniforms.bar_count));

    // Breathing-reactive bar spacing
    let breathing_phase = sin(uniforms.time * uniforms.breathing_rate / 60.0 * 6.283185);
    let spacing = 0.05 + breathing_phase * 0.02;

    // Bar outline
    var alpha = 1.0;
    if (bar_uv_x < spacing || bar_uv_x > (1.0 - spacing)) {
        alpha = 0.0;  // Gap between bars
    }

    // Get FFT magnitude for this bar
    let fft_index = min(bar_index * 2u, 255u);  // Map bars to FFT bins
    var magnitude = fft_data[fft_index] * uniforms.gain;

    // Logarithmic scaling for better visual representation
    magnitude = log(1.0 + magnitude * 10.0) / log(11.0);

    // Heart rate reactive animation
    let hr_phase = uniforms.time * uniforms.heart_rate / 60.0;
    let wave = sin(f32(bar_index) * 0.5 + hr_phase * 6.283185) * 0.1 + 1.0;
    magnitude *= wave;

    // Clamp magnitude
    magnitude = clamp(magnitude, 0.0, 1.0);

    // Check if pixel is within bar height
    var bar_alpha = 0.0;
    if (uv.y < magnitude) {
        bar_alpha = 1.0;
    }

    // Gradient within bar (bottom to top)
    let gradient_pos = uv.y / max(magnitude, 0.01);

    // HRV-reactive color scheme
    // Low frequencies: warmer colors
    // High frequencies: cooler colors
    let freq_pos = f32(bar_index) / f32(uniforms.bar_count);
    let base_hue = freq_pos * 0.6 + uniforms.hrv_coherence * 0.3;

    // Color gradient from bottom (bright) to top (darker)
    let saturation = 0.8 + gradient_pos * 0.2;
    let value = 1.0 - gradient_pos * 0.3;

    var color = hsv_to_rgb(base_hue, saturation, value);

    // Add glow at peaks
    if (abs(uv.y - magnitude) < 0.02) {
        color += vec3<f32>(0.5, 0.5, 0.5);
    }

    // Add reflection effect in bottom half
    if (uv.y < 0.5) {
        let mirror_y = 1.0 - uv.y;
        if (mirror_y < magnitude) {
            let reflection_alpha = (0.5 - uv.y) * 0.4;
            let reflection_color = hsv_to_rgb(base_hue, saturation * 0.5, value * 0.5);
            color = mix(color, reflection_color, reflection_alpha);
            bar_alpha = max(bar_alpha, reflection_alpha);
        }
    }

    // Audio level reactive background glow
    let bg_glow = uniforms.audio_level * 0.1;
    color += vec3<f32>(bg_glow, bg_glow * 0.5, bg_glow * 0.8);

    return vec4<f32>(color, bar_alpha * alpha);
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

// Smooth minimum for soft blending
fn smin(a: f32, b: f32, k: f32) -> f32 {
    let h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

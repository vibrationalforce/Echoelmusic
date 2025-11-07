// Cymatics Visualization Shader
// Generates Chladni plate patterns based on frequency and bio-parameters

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

struct CymaticsUniforms {
    frequency: f32,      // Hz (from voice pitch or music)
    amplitude: f32,      // 0.0-1.0 (from audio level)
    time: f32,           // For animation
    _padding: f32,
};

@group(0) @binding(0)
var<uniform> uniforms: CymaticsUniforms;

// Full-screen quad vertex shader
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    var output: VertexOutput;

    // Full-screen triangle
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

// Cymatics pattern fragment shader
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    // Center UV coordinates
    let uv = input.uv * 2.0 - 1.0;
    let aspect_ratio = 16.0 / 9.0;
    let uv_corrected = vec2<f32>(uv.x * aspect_ratio, uv.y);

    // Distance from center
    let dist = length(uv_corrected);

    // Chladni plate equation: sin(n*x)*sin(m*y) - sin(m*x)*sin(n*y)
    // n, m derived from frequency
    let freq_normalized = uniforms.frequency / 440.0; // Normalize to A4
    let n = floor(freq_normalized * 4.0) + 2.0;
    let m = floor(freq_normalized * 3.0) + 1.0;

    // Plate vibration modes
    let x = uv_corrected.x * 3.14159 * n;
    let y = uv_corrected.y * 3.14159 * m;

    let pattern1 = sin(x) * sin(y) - sin(y * 1.5) * sin(x * 0.8);
    let pattern2 = cos(x * 0.7) * cos(y * 1.2) + sin(x + y);

    // Combine patterns with time-based morphing
    let morph = sin(uniforms.time * 0.5) * 0.5 + 0.5;
    let combined = mix(pattern1, pattern2, morph);

    // Standing wave interference
    let wave = sin(dist * 20.0 * freq_normalized - uniforms.time * 2.0);
    let interference = combined * wave * uniforms.amplitude;

    // Create nodal lines (where vibration is zero)
    let nodal_strength = smoothstep(0.1, 0.0, abs(interference));

    // Color based on amplitude and pattern
    let hue = fract(freq_normalized * 0.5 + uniforms.time * 0.1);
    let color_base = hsv_to_rgb(hue, 0.7, 0.9);

    // Dark nodal lines, bright anti-nodal regions
    let brightness = (1.0 - nodal_strength) * uniforms.amplitude;
    var final_color = color_base * brightness;

    // Add glow to nodal lines
    let glow = nodal_strength * 0.3;
    final_color += vec3<f32>(glow, glow, glow * 0.5);

    // Vignette for circular boundary
    let vignette = smoothstep(1.2, 0.8, dist);
    final_color *= vignette;

    return vec4<f32>(final_color, 1.0);
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

// Perlin-like noise for organic patterns
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

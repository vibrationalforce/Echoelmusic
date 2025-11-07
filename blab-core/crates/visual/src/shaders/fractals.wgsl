// Fractal Visualization Shader
// Bio-reactive Mandelbrot and Julia set renderer

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

struct FractalUniforms {
    zoom: f32,           // Zoom level (from HRV coherence)
    center_x: f32,       // Pan X
    center_y: f32,       // Pan Y
    iterations: u32,     // Max iterations (from heart rate)

    julia_mode: u32,     // 0 = Mandelbrot, 1 = Julia
    julia_c_real: f32,   // Julia constant (from breathing)
    julia_c_imag: f32,   // Julia constant (from pitch)

    color_shift: f32,    // Hue shift (from audio level)
    time: f32,           // Animation time
    _padding: vec3<f32>,
};

@group(0) @binding(0)
var<uniform> uniforms: FractalUniforms;

// Full-screen quad vertex shader
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
        vec2<f32>(0.0, 1.0),
        vec2<f32>(1.0, 1.0),
        vec2<f32>(1.0, 0.0),
        vec2<f32>(0.0, 1.0),
        vec2<f32>(1.0, 0.0),
        vec2<f32>(0.0, 0.0)
    );

    output.position = vec4<f32>(positions[vertex_index], 0.0, 1.0);
    output.uv = uvs[vertex_index];

    return output;
}

// Mandelbrot set iteration
fn mandelbrot(c: vec2<f32>, max_iter: u32) -> f32 {
    var z = vec2<f32>(0.0, 0.0);
    var iter: u32 = 0u;

    for (var i: u32 = 0u; i < max_iter; i = i + 1u) {
        // z = z^2 + c
        let z_real = z.x * z.x - z.y * z.y + c.x;
        let z_imag = 2.0 * z.x * z.y + c.y;
        z = vec2<f32>(z_real, z_imag);

        iter = i;

        // Escape condition
        if (dot(z, z) > 4.0) {
            break;
        }
    }

    // Smooth iteration count
    if (iter < max_iter) {
        let log_zn = log(dot(z, z)) / 2.0;
        let nu = log(log_zn / log(2.0)) / log(2.0);
        return f32(iter) + 1.0 - nu;
    }

    return f32(iter);
}

// Julia set iteration
fn julia(z0: vec2<f32>, c: vec2<f32>, max_iter: u32) -> f32 {
    var z = z0;
    var iter: u32 = 0u;

    for (var i: u32 = 0u; i < max_iter; i = i + 1u) {
        // z = z^2 + c
        let z_real = z.x * z.x - z.y * z.y + c.x;
        let z_imag = 2.0 * z.x * z.y + c.y;
        z = vec2<f32>(z_real, z_imag);

        iter = i;

        if (dot(z, z) > 4.0) {
            break;
        }
    }

    if (iter < max_iter) {
        let log_zn = log(dot(z, z)) / 2.0;
        let nu = log(log_zn / log(2.0)) / log(2.0);
        return f32(iter) + 1.0 - nu;
    }

    return f32(iter);
}

// Burning Ship fractal (variation)
fn burning_ship(c: vec2<f32>, max_iter: u32) -> f32 {
    var z = vec2<f32>(0.0, 0.0);
    var iter: u32 = 0u;

    for (var i: u32 = 0u; i < max_iter; i = i + 1u) {
        // z = (|Re(z)| + i|Im(z)|)^2 + c
        z = abs(z);
        let z_real = z.x * z.x - z.y * z.y + c.x;
        let z_imag = 2.0 * z.x * z.y + c.y;
        z = vec2<f32>(z_real, z_imag);

        iter = i;

        if (dot(z, z) > 4.0) {
            break;
        }
    }

    if (iter < max_iter) {
        return f32(iter) - log2(log2(dot(z, z)));
    }

    return f32(iter);
}

// Fragment shader
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    // Map UV to complex plane
    let aspect_ratio = 16.0 / 9.0;
    var uv = (input.uv * 2.0 - 1.0) * vec2<f32>(aspect_ratio, 1.0);

    // Apply zoom and pan
    uv = uv / uniforms.zoom + vec2<f32>(uniforms.center_x, uniforms.center_y);

    // Compute fractal
    var iterations: f32;

    if (uniforms.julia_mode == 0u) {
        // Mandelbrot
        iterations = mandelbrot(uv, uniforms.iterations);
    } else {
        // Julia
        let c = vec2<f32>(uniforms.julia_c_real, uniforms.julia_c_imag);
        iterations = julia(uv, c, uniforms.iterations);
    }

    // Normalize iteration count
    let t = iterations / f32(uniforms.iterations);

    // Color mapping with bio-reactive hue shift
    let hue = fract(t * 3.0 + uniforms.color_shift + uniforms.time * 0.1);
    let saturation = 0.8;
    let value = t < 1.0 ? 1.0 : 0.0;

    var color = hsv_to_rgb(hue, saturation, value);

    // Add glow for set interior
    if (t >= 1.0) {
        color = vec3<f32>(0.0, 0.0, 0.05);
    }

    return vec4<f32>(color, 1.0);
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

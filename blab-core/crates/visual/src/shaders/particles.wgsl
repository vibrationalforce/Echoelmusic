// WGSL Particle Compute Shader
// Bio-reactive particle physics

struct Particle {
    position: vec2<f32>,
    velocity: vec2<f32>,
    hue: f32,
    life: f32,
    size: f32,
    brightness: f32,
}

struct Uniforms {
    time: f32,
    delta_time: f32,
    audio_level: f32,
    frequency: f32,
    hrv_coherence: f32,
    heart_rate: f32,
    breathing_rate: f32,
    particle_count: u32,
}

@group(0) @binding(0) var<storage, read_write> particles: array<Particle>;
@group(0) @binding(1) var<uniform> uniforms: Uniforms;

// Random function
fn random(seed: f32) -> f32 {
    return fract(sin(seed * 12.9898) * 43758.5453);
}

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let index = global_id.x;

    if (index >= uniforms.particle_count) {
        return;
    }

    var particle = particles[index];

    // Update life
    particle.life -= uniforms.delta_time * 0.2;

    // Respawn if dead
    if (particle.life <= 0.0) {
        let seed = f32(index) + uniforms.time;
        let rand_x = random(seed * 1.1) * 2.0 - 1.0;
        let rand_y = random(seed * 2.3) * 2.0 - 1.0;

        particle.position = vec2<f32>(rand_x, rand_y) * 0.1;
        particle.velocity = normalize(vec2<f32>(rand_x, rand_y)) * 0.01;
        particle.life = 1.0;
        particle.size = (1.0 + uniforms.audio_level) * 2.0;
        particle.brightness = 1.0;
    }

    // Audio-reactive forces
    let audio_force = uniforms.audio_level * 0.005;
    let direction = normalize(particle.velocity);
    particle.velocity += direction * audio_force;

    // Bio-reactive attractor (HRV-driven)
    let attractor_pos = vec2<f32>(0.0, 0.0);
    let to_attractor = attractor_pos - particle.position;
    let dist_to_attractor = length(to_attractor);

    if (dist_to_attractor > 0.001) {
        let attractor_force = uniforms.hrv_coherence * 0.001;
        particle.velocity += normalize(to_attractor) * attractor_force / dist_to_attractor;
    }

    // Breathing-reactive turbulence
    let breath_phase = sin(uniforms.time * uniforms.breathing_rate / 60.0 * 6.283185);
    let turbulence = breath_phase * 0.002;
    particle.velocity += vec2<f32>(
        sin(particle.position.x * 10.0 + uniforms.time) * turbulence,
        cos(particle.position.y * 10.0 + uniforms.time) * turbulence
    );

    // Damping
    particle.velocity *= 0.98;

    // Update position
    particle.position += particle.velocity * uniforms.delta_time * 60.0;

    // Wrap around edges
    if (particle.position.x < -1.0) { particle.position.x = 1.0; }
    if (particle.position.x > 1.0) { particle.position.x = -1.0; }
    if (particle.position.y < -1.0) { particle.position.y = 1.0; }
    if (particle.position.y > 1.0) { particle.position.y = -1.0; }

    // HRV → Hue
    particle.hue = uniforms.hrv_coherence * 0.5;

    // Heart rate → Hue oscillation
    let heart_rate_norm = (uniforms.heart_rate - 40.0) / 80.0;
    particle.hue += sin(uniforms.time * heart_rate_norm * 2.0) * 0.1;

    // Clamp hue
    particle.hue = fract(particle.hue);

    // Size based on velocity
    let speed = length(particle.velocity);
    particle.size = (1.0 + speed * 100.0) * (1.0 + uniforms.audio_level);

    // Brightness fades with life
    particle.brightness = particle.life * 0.5 + 0.5;

    // Write back
    particles[index] = particle;
}

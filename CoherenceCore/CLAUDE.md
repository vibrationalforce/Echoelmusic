# CLAUDE.md - CoherenceCore Framework Build Rules

## Project Overview

**CoherenceCore** is a quad-platform biophysical resonance framework for tissue micro-vibration analysis (Scan) and coherent stimulation (Wellness) via sound, haptics, and visuals.

### Platforms
| Platform | Framework | Version | Audio API | Camera API |
|----------|-----------|---------|-----------|------------|
| iOS | React Native + Expo | SDK 52+ | expo-av | expo-camera |
| Android | React Native + Expo | SDK 52+ | expo-av | expo-camera |
| Windows | Tauri 2.0 | Rust | cpal | crabcamera |
| Linux | Tauri 2.0 | Rust | cpal | crabcamera |

---

## RALPH WIGGUM LAMBDA LOOP PROTOCOL

### State Files (Context Persistence)
```
CoherenceCore/
├── PRD.json          # Feature tracking with "passes": true/false
├── tests.json        # Hardware validation tests
├── progress.log      # Error logging and iteration history
└── CLAUDE.md         # This file - build rules
```

### Loop Execution Rules

1. **Read State First**: Before any code change, read PRD.json to determine current feature status
2. **Smallest Step**: Execute only ONE code change per iteration
3. **Build Immediately**: After each change, run `npm run build` or `cargo build`
4. **Test After Build**: Run relevant tests from tests.json
5. **Log Errors**: Write failures to progress.log with timestamp
6. **Self-Correct**: Use error logs to fix issues in next iteration
7. **Update State**: Mark features as "passes": true when tests pass
8. **Completion Token**: Output `{COMPLETED_RALPH_LOOP}` only when ALL features pass

### Error Recovery
```
IF build_error:
  1. Log error to progress.log
  2. Analyze error message
  3. Apply fix in next iteration
  4. Re-run build
  5. If same error 3x, escalate to alternate approach
```

---

## BUILD COMMANDS

### Mobile (React Native + Expo)
```bash
cd apps/mobile
npm install
npx expo prebuild
npx expo run:ios        # iOS simulator
npx expo run:android    # Android emulator
npm run test            # Jest tests
```

### Desktop (Tauri 2.0)
```bash
cd apps/desktop
cargo build             # Debug build
cargo build --release   # Release build
cargo test              # Rust tests
npm run tauri dev       # Development mode
npm run tauri build     # Production build
```

### Monorepo (Turborepo)
```bash
# From CoherenceCore root
npm install
npm run build           # Build all packages
npm run test            # Test all packages
npm run dev             # Development mode
```

---

## BIOPHYSICAL FREQUENCY PARAMETERS

### Evidence-Based Presets (WELLNESS ONLY - NO MEDICAL CLAIMS)

| Preset | Frequency Range | Primary Hz | Target | Research |
|--------|-----------------|------------|--------|----------|
| **Osteo-Sync** | 35-45 Hz | 40 Hz | Osteoblast activity | Rubin et al. (2006) |
| **Myo-Resonance** | 45-50 Hz | 47.5 Hz | Myofibril coherence | Judex & Rubin (2010) |
| **Neural-Flow** | 38-42 Hz | 40 Hz | Gamma entrainment | Iaccarino et al. (2016) |

### Frequency Generation Formula
```typescript
// Sine wave generation at target frequency
function generateSineWave(frequency: number, sampleRate: number, duration: number): Float32Array {
  const samples = sampleRate * duration;
  const buffer = new Float32Array(samples);
  const omega = 2 * Math.PI * frequency;

  for (let i = 0; i < samples; i++) {
    buffer[i] = Math.sin(omega * i / sampleRate);
  }

  return buffer;
}
```

---

## HARDWARE VALIDATION

### Nyquist Theorem Compliance
```
Target Frequency Range: 1-60 Hz
Minimum Sample Rate: 2 × 60 Hz = 120 Hz

Camera Requirements:
- Ideal: 120 fps (full Nyquist for 60 Hz)
- Acceptable: 60 fps (Nyquist for 30 Hz, sub-sample higher)
- Minimum: 30 fps (limited to 15 Hz detection)

IMU Requirements:
- Target: 100 Hz sampling
- expo-sensors.setUpdateInterval(10) = 100 Hz
- Nyquist limit: 50 Hz detection
```

### LiDAR Limitations
```
Apple LiDAR: Max 15 Hz → Only suitable for < 7.5 Hz detection
NOT recommended for primary frequency detection
Use as supplementary depth data only
```

---

## SAFETY COMPLIANCE (STRICT)

### Mandatory Disclaimer
Every screen MUST display:
```
"Wellness/Informational Tool - No Medical Advice"
```

### Session Limits
| Parameter | Value | Enforcement |
|-----------|-------|-------------|
| Max Session Duration | 15 minutes | Auto-cutoff at 900s |
| Max Duty Cycle | 70% | Software limit |
| Max Amplitude | 80% | Capped in audio/haptic APIs |
| Cooldown Period | 5 minutes | Required between sessions |

### Safety Implementation
```typescript
const SAFETY_LIMITS = {
  maxSessionDurationMs: 15 * 60 * 1000, // 15 minutes
  maxDutyCycle: 0.7,
  maxAmplitude: 0.8,
  cooldownPeriodMs: 5 * 60 * 1000, // 5 minutes
};

function enforceSessionLimit(startTime: number): boolean {
  const elapsed = Date.now() - startTime;
  if (elapsed >= SAFETY_LIMITS.maxSessionDurationMs) {
    stopAllStimulation();
    return false; // Session ended
  }
  return true; // Continue allowed
}
```

---

## EVM (EULERIAN VIDEO MAGNIFICATION)

### Algorithm Steps
1. **Spatial Decomposition**: Build Laplacian pyramid (4-6 levels)
2. **Temporal Filtering**: Bandpass filter each level (target: 1-60 Hz)
3. **Amplification**: Multiply filtered signal by amplification factor
4. **Reconstruction**: Collapse pyramid back to image
5. **Visualization**: Display amplified motion

### WebGL Shader (Mobile)
```glsl
// Laplacian pyramid downsample
precision highp float;
uniform sampler2D u_texture;
uniform vec2 u_resolution;

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution;
  vec2 texel = 1.0 / u_resolution;

  // 2x2 averaging with Gaussian weights
  vec4 color =
    texture2D(u_texture, uv) * 0.25 +
    texture2D(u_texture, uv + vec2(texel.x, 0.0)) * 0.25 +
    texture2D(u_texture, uv + vec2(0.0, texel.y)) * 0.25 +
    texture2D(u_texture, uv + texel) * 0.25;

  gl_FragColor = color;
}
```

### wgpu Shader (Desktop)
```wgsl
// Laplacian pyramid compute shader
@group(0) @binding(0) var input_texture: texture_2d<f32>;
@group(0) @binding(1) var output_texture: texture_storage_2d<rgba8unorm, write>;
@group(0) @binding(2) var tex_sampler: sampler;

@compute @workgroup_size(8, 8)
fn downsample(@builtin(global_invocation_id) id: vec3<u32>) {
  let dims = textureDimensions(input_texture);
  let uv = vec2<f32>(id.xy) / vec2<f32>(dims);
  let texel = 1.0 / vec2<f32>(dims);

  let color =
    textureSample(input_texture, tex_sampler, uv) * 0.25 +
    textureSample(input_texture, tex_sampler, uv + vec2(texel.x, 0.0)) * 0.25 +
    textureSample(input_texture, tex_sampler, uv + vec2(0.0, texel.y)) * 0.25 +
    textureSample(input_texture, tex_sampler, uv + texel) * 0.25;

  textureStore(output_texture, id.xy, color);
}
```

---

## AUDIO OUTPUT (VAT - Vibroacoustic Therapy)

### Mobile (expo-av)
```typescript
import { Audio } from 'expo-av';

async function playFrequency(frequency: number, duration: number) {
  // Generate sine wave buffer
  const sampleRate = 44100;
  const samples = sampleRate * duration;
  const buffer = new Float32Array(samples);

  for (let i = 0; i < samples; i++) {
    buffer[i] = Math.sin(2 * Math.PI * frequency * i / sampleRate);
  }

  // Create audio from buffer (requires native module)
  const sound = new Audio.Sound();
  await sound.loadAsync({ uri: createWavBlob(buffer, sampleRate) });
  await sound.playAsync();
}
```

### Desktop (cpal)
```rust
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

fn play_frequency(frequency: f32, duration_secs: f32) -> Result<(), Box<dyn Error>> {
    let host = cpal::default_host();
    let device = host.default_output_device().unwrap();
    let config = device.default_output_config()?;

    let sample_rate = config.sample_rate().0 as f32;
    let mut sample_clock = 0f32;

    let stream = device.build_output_stream(
        &config.into(),
        move |data: &mut [f32], _| {
            for sample in data.iter_mut() {
                let t = sample_clock / sample_rate;
                *sample = (t * frequency * 2.0 * std::f32::consts::PI).sin();
                sample_clock += 1.0;
            }
        },
        |err| eprintln!("Stream error: {}", err),
        None,
    )?;

    stream.play()?;
    std::thread::sleep(Duration::from_secs_f32(duration_secs));
    Ok(())
}
```

---

## DIRECTORY STRUCTURE

```
CoherenceCore/
├── apps/
│   ├── mobile/                 # React Native + Expo
│   │   ├── app/                # Expo Router screens
│   │   ├── components/         # React components
│   │   ├── hooks/              # Custom hooks
│   │   ├── lib/                # Shared utilities
│   │   └── package.json
│   └── desktop/                # Tauri 2.0
│       ├── src/                # Rust source
│       ├── src-tauri/          # Tauri config
│       └── Cargo.toml
├── packages/
│   ├── core/                   # Shared business logic
│   ├── evm-engine/             # EVM algorithms
│   ├── frequency-engine/       # Frequency generation
│   └── shared-types/           # TypeScript types
├── PRD.json                    # Feature tracking
├── tests.json                  # Hardware validation
├── progress.log                # Error/iteration log
├── turbo.json                  # Turborepo config
└── CLAUDE.md                   # This file
```

---

## COMPLETION CRITERIA

The `{COMPLETED_RALPH_LOOP}` token is output when:

1. All features in PRD.json have `"passes": true`
2. All tests in tests.json have `"passes": true`
3. `git status` shows clean working tree
4. Mobile app builds for iOS and Android
5. Desktop app builds for Windows and Linux
6. All safety compliance tests pass

---

*Last Updated: 2026-01-14 | Ralph Wiggum Lambda Loop Mode ACTIVE*

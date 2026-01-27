# Presets Module

Curated preset system for Echoelmusic engines.

## Preset Categories

| Category | Count | Description |
|----------|-------|-------------|
| Bio-Reactive | 10+ | HRV/coherence-optimized settings |
| Musical | 10+ | Genre-specific audio configurations |
| Visual | 10+ | Visual effect presets |
| Lighting | 10+ | DMX/LED show presets |
| Streaming | 5+ | Platform-optimized streaming settings |
| Collaboration | 5+ | Group session configurations |

## Key Components

| Component | Description |
|-----------|-------------|
| `PresetManager` | Central preset management |
| `EnginePreset` | Engine configuration snapshot |
| `PresetStorage` | Persistence and cloud sync |

## Built-in Presets

### Bio-Reactive
- Deep Meditation
- Active Flow
- Zen Master
- Heart Coherence
- Breathing Sync

### Musical
- Ambient Drone
- Techno Minimal
- Neo Classical
- Bio Jazz
- Quantum Beats

### Visual
- Sacred Mandala
- Cosmic Nebula
- Quantum Field
- Bio Pulse
- Fractal Flow

## Usage

```swift
// Load a preset
let preset = PresetManager.shared.preset(named: "Deep Meditation")
try await UnifiedControlHub.shared.apply(preset)

// Save current state as preset
let custom = UnifiedControlHub.shared.capturePreset()
try await PresetManager.shared.save(custom, name: "My Preset")

// List available presets
let presets = PresetManager.shared.allPresets(category: .bioReactive)
```

## Custom Presets

Users can create and share custom presets. Presets are stored as JSON and can be:
- Exported/imported via files
- Shared via iCloud
- Published to the community (future feature)

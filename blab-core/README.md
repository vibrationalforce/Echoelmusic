# BLAB Core (Rust)

Cross-platform performance engine for BLAB Allwave.

## Architecture

```
blab-core/
├── crates/
│   ├── audio/    # Audio engine (cpal, symphonia)
│   ├── visual/   # GPU engine (wgpu, lyon)
│   ├── ai/       # AI engine (ort, candle)
│   ├── video/    # Video engine (ffmpeg)
│   ├── bio/      # Bio-signal processing
│   └── ffi/      # FFI bindings (iOS, Android, Desktop)
└── Cargo.toml    # Workspace manifest
```

## Build

```bash
cd blab-core
cargo build --release
cargo test
```

## Platforms

- ✅ iOS (via Swift FFI)
- ✅ Android (via JNI)
- ✅ macOS (native)
- ✅ Windows (native)
- ✅ Linux (native)
- ✅ Web (WASM)

## Performance Targets

- Audio latency: < 5ms
- Video FPS: 60-120 (adaptive)
- CPU usage: < 20%
- GPU usage: < 30%
- Memory: < 500 MB

## License

AGPL-3.0-or-later (Core Engine)
Commercial license available for proprietary use.

See `../MULTIPLATFORM_STRATEGY.md` for full details.

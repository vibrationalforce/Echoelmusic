# Performance Module

Adaptive performance optimization for Echoelmusic.

## Features

- **Adaptive Quality**: Dynamic quality adjustment based on device capabilities
- **Resource Monitoring**: Real-time CPU, GPU, memory tracking
- **Thermal Management**: Automatic throttling to prevent overheating
- **Battery Optimization**: Power-efficient modes for mobile devices
- **Frame Rate Targeting**: Automatic FPS adjustment (30/60/120 Hz)

## Key Components

| Component | Description |
|-----------|-------------|
| `PerformanceMonitor` | Real-time resource tracking |
| `AdaptiveQualityManager` | Automatic quality scaling |
| `ThermalManager` | Temperature-based throttling |
| `PowerManager` | Battery optimization |

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Control Loop | 60 Hz | Bio-reactive response |
| Audio Latency | <10ms | Real-time audio |
| CPU Usage | <30% | Thermal headroom |
| Memory | <200 MB | System resources |
| Frame Rate | 60 FPS | ProMotion: 120 FPS |

## Quality Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| Ultra | Full features, max particles | High-end devices |
| High | Reduced particles | Modern devices |
| Medium | Simplified visuals | Older devices |
| Low | Minimal effects | Battery saver |
| Auto | Adaptive switching | Recommended |

## Usage

```swift
// Enable adaptive quality
PerformanceMonitor.shared.adaptiveQuality = true

// Check current metrics
let metrics = PerformanceMonitor.shared.currentMetrics
print("CPU: \(metrics.cpuUsage)%")
print("Memory: \(metrics.memoryUsage) MB")
print("Temperature: \(metrics.thermalState)")

// Force quality level
AdaptiveQualityManager.shared.setQualityLevel(.medium)
```

## Best Practices

1. Use `@MainActor` for UI-related code
2. Avoid heap allocations in audio callbacks
3. Use SIMD (Accelerate framework) for DSP
4. Profile with Instruments regularly
5. Test on lowest-spec supported devices

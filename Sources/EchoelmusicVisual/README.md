# EchoelmusicVisual

**Purpose:** Visual renderer, shader pipeline, XR bridge placeholder.

## Responsibilities

- Define RenderNode protocol and VisualParameter types
- Provide Metal/placeholder renderer skeleton
- XRBridge placeholder for visionOS/ARKit/RealityKit hooks

## Getting Started

```swift
import EchoelmusicVisual

// Create visual renderer
let renderer = VisualRenderer()
try renderer.initialize(device: metalDevice)

// Render frame
let params = VisualParameters(
    audioLevel: 0.8,
    coherence: 75,
    heartRate: 72
)
try renderer.render(drawable: drawable, parameters: params)
```

## Testing

XRBridge availability tests in `Tests/EchoelmusicVisualTests`

## Notes

- Heavy GPU work deferred to Phase 4
- Keep API stable and minimal for now
- XRBridge is visionOS/ARKit placeholder

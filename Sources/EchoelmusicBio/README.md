# EchoelmusicBio

**Purpose:** Bio-signal ingestion and mapping.

## Responsibilities

- Define BioSignal types (HR, HRV, Breath, GSR, Motion)
- Provide BioMappingGraph to map signals → audio/visual parameters
- Privacy-first: transient signals, opt-in storage

## Getting Started

```swift
import EchoelmusicBio

// Create bio-mapping
let graph = BioMappingGraph()
graph.addMapping(.init(
    bioSignal: .hrv,
    targetParameter: "filterCutoff",
    mappingCurve: .linear,
    intensity: 1.0
))

// Apply mappings
let bioValues: [BioSignalType: Double] = [.hrv: 0.7]
let parameters = graph.applyMappings(bioValues: bioValues)
```

## Testing

Tests in `Tests/EchoelmusicBioTests` validate mapping curves and signal pipeline.

## Privacy

- All bio-signals are transient by default
- Storage requires explicit user opt-in
- HIPAA/GDPR compliant data handling

# W2 ModRoute — Concrete Sketch
2026-10-26 — proactive continuation.

## Type (suggested)
```swift
struct ModRoute: Codable, Equatable {
    var source: ModSource          // .body(.hrv) | .lfo | .macro | .midiCC
    var target: ParameterAddress
    var depth: Double              // 0…1
    var curve: Curve               // .linear | .exp | .sCurve
}

enum ModSource: Codable {
    case body(BodyChannel)         // .hrv, .coherence, .heartRate, .breath
    case lfo(LFOID)
    case macro(MacroID)
    case midiCC(UInt8)
}
```

## Persistence
- Add `modRoutes: [ModRoute]` to the song document.
- Format version 3 on write.
- On read of v2: migrate to empty array.

## Render
- Evaluate routes on the control-rate tick (not inside the audio callback).
- Apply depth * sourceValue to the target parameter via the existing ParameterWriter path.
- Hard upper bound on number of active routes (e.g. 32).

## Next executable slice
1. Add the type in EchoelCore.
2. Add the field + migration in the codec.
3. One offline test that a body channel produces a non-zero modulation value.

Ready for implementation after W1 display is device-verified.

*No rules changed.*
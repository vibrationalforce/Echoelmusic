import EchoelCore

/// The built-in devices' kernels as the app's engine plays them — the one place that names a
/// concrete instrument kernel. A new built-in device is its Core table, its kernel and a case
/// here; `EngineCore` plays whatever this returns, in `InstrumentDevice.builtIn` order.
public enum BuiltInKernels {
    /// The engine's kernel for `device`, or nil for a plugin or an instrument from a later build.
    /// Never on the render thread: it allocates. `maximumFrames` is the engine's block size, the
    /// most a kernel renders in one call; a smaller one renders a range in pieces, which the
    /// synth's wheels no longer hear (their glides run per sample, audit 2026-10-23).
    public static func kernel(for device: InstrumentDevice, sampleRate: Double,
                              maximumFrames: Int) -> (any EngineInstrumentKernel)? {
        switch device {
        case .synth:
            return SynthKernel(sampleRate: sampleRate, maximumFrames: maximumFrames)
        case .drums:
            // At the song's default (unity, as the engine always played the kit); the plugin starts
            // at the table's default.
            return DrumKernel(sampleRate: sampleRate, maximumFrames: maximumFrames,
                              level: Float(SynthParameter.drumsLevel.songDefault))
        case .sampler:
            let sampler = SamplerKernel(sampleRate: sampleRate, maximumFrames: maximumFrames)
            // The table's patch before the first note, not at the first render after it.
            sampler.commitParameters()
            return sampler
        case .plugin, .unrecognized:
            return nil
        }
    }
}

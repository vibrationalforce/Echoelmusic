import EchoelCore
import EchoelDSP
import Foundation

/// The wavetables a song's synths cut from its files (EchoelTools: a synth fed with the
/// musician's own sample). Each is built OFF the render thread — once per file and cycle count,
/// kept by its `WavetableSource` — and handed to the snapshot, which the render thread only reads.
/// A table that is not built yet plays the factory shapes; an export builds every table before it
/// renders (`OfflineRender`), so what it writes is what plays once the table is in.
public enum Wavetables {
    /// Every wavetable `project` plays whose file `samples` holds, once per source. Only a synth
    /// track's: the table belongs to the synth, whatever engine plays now, so switching engines
    /// mid-song finds it ready.
    public static func pending(in project: Project, samples: [MediaID: SampleBuffer]) -> [(WavetableSource, SampleBuffer)] {
        var seen = Set<WavetableSource>()
        var result: [(WavetableSource, SampleBuffer)] = []
        for track in project.tracks where track.kind == .instrument && track.instrument.device == .synth {
            guard let source = track.instrument.wavetable, let buffer = samples[source.media],
                  seen.insert(source).inserted else { continue }
            result.append((source, buffer))
        }
        return result
    }

    /// The table of one source. Allocates and takes time: never on the render thread, nor in a
    /// view body. Nil for a file with no sound in it — the synth then plays the factory shapes.
    public static func build(_ source: WavetableSource, from buffer: SampleBuffer) -> WavetableBank? {
        WavetableBank(sample: buffer, frames: source.frames)
    }

    /// Every table `project` needs, built now: what an export or a bake plays.
    public static func prepare(_ project: Project, samples: [MediaID: SampleBuffer]) -> [WavetableSource: WavetableBank] {
        var tables: [WavetableSource: WavetableBank] = [:]
        for (source, buffer) in pending(in: project, samples: samples) {
            if let bank = build(source, from: buffer) { tables[source] = bank }
        }
        return tables
    }
}

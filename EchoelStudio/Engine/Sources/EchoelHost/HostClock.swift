import AudioToolbox
import AVFoundation
import EchoelKernels
import Foundation
import Synchronization

/// The host's answer to "where is the song?" for one loaded Audio Unit: tempo, time signature,
/// beat position and whether the transport moves. Its two blocks are set on the unit before its
/// render resources are allocated, because most units read them only then. The engine writes it
/// on the render thread before each render call (`HostedUnit.follow`, `HostedEffect.follow`); the
/// unit reads it from inside that call, or from another thread to draw — every value is atomic, so
/// neither side waits.
public final class HostClock: Sendable {
    private let playing = Atomic<Bool>(false)
    private let changed = Atomic<Bool>(false)
    private let tempo = Atomic<UInt64>(Double(120).bitPattern)
    private let numerator = Atomic<Int>(4)
    private let denominator = Atomic<Int>(4)
    private let beat = Atomic<UInt64>(Double(0).bitPattern)
    private let downbeat = Atomic<UInt64>(Double(0).bitPattern)
    private let toNextBeat = Atomic<Int>(0)
    private let sample = Atomic<UInt64>(Double(0).bitPattern)
    private let cycleStart = Atomic<UInt64>(Double(0).bitPattern)
    private let cycleEnd = Atomic<UInt64>(Double(0).bitPattern)

    public init() {}

    /// Render thread: where the song is for the unit's next render call.
    public func update(_ transport: HostTransport) {
        playing.store(transport.isPlaying, ordering: .relaxed)
        if transport.changed { changed.store(true, ordering: .relaxed) }
        tempo.store(transport.tempo.bitPattern, ordering: .relaxed)
        numerator.store(transport.numerator, ordering: .relaxed)
        denominator.store(transport.denominator, ordering: .relaxed)
        beat.store(transport.beat.bitPattern, ordering: .relaxed)
        downbeat.store(transport.downbeat.bitPattern, ordering: .relaxed)
        toNextBeat.store(transport.samplesToNextBeat, ordering: .relaxed)
        sample.store(transport.sample.bitPattern, ordering: .relaxed)
        let cycling = transport.isCycling
        cycleStart.store((cycling ? transport.cycleStart : 0).bitPattern, ordering: .relaxed)
        cycleEnd.store((cycling ? transport.cycleEnd : 0).bitPattern, ordering: .relaxed)
    }

    /// For `AUAudioUnit.musicalContextBlock`.
    public var musicalContextBlock: AUHostMusicalContextBlock {
        { [self] tempoOut, numeratorOut, denominatorOut, beatOut, toNextBeatOut, downbeatOut in
            tempoOut?.pointee = Double(bitPattern: tempo.load(ordering: .relaxed))
            numeratorOut?.pointee = Double(numerator.load(ordering: .relaxed))
            denominatorOut?.pointee = denominator.load(ordering: .relaxed)
            beatOut?.pointee = Double(bitPattern: beat.load(ordering: .relaxed))
            toNextBeatOut?.pointee = toNextBeat.load(ordering: .relaxed)
            downbeatOut?.pointee = Double(bitPattern: downbeat.load(ordering: .relaxed))
            return true
        }
    }

    /// For `AUAudioUnit.transportStateBlock`. While the song loops, the loop is the cycle, in
    /// beats; without one the cycle is 0 to 0 and not reported. "changed" is reported once after
    /// each start, stop or jump. The two cycle words are read apart, so a unit asking during a loop
    /// edit can see one old and one new end for one call — the next call has both.
    public var transportStateBlock: AUHostTransportStateBlock {
        { [self] flagsOut, sampleOut, cycleStartOut, cycleEndOut in
            var flags: AUHostTransportStateFlags = []
            if changed.exchange(false, ordering: .relaxed) { flags.insert(.changed) }
            if playing.load(ordering: .relaxed) { flags.insert(.moving) }
            let start = Double(bitPattern: cycleStart.load(ordering: .relaxed))
            let end = Double(bitPattern: cycleEnd.load(ordering: .relaxed))
            if end > start { flags.insert(.cycling) }
            flagsOut?.pointee = flags
            sampleOut?.pointee = Double(bitPattern: sample.load(ordering: .relaxed))
            cycleStartOut?.pointee = start
            cycleEndOut?.pointee = end
            return true
        }
    }
}

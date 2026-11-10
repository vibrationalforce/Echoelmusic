import EchoelCore
import Foundation
import Synchronization

/// The live value of each modulation source, as the app last measured it, for the render thread
/// to read (wave W2). One cell per `ModulationSource`, each normalized 0 … 1 or ABSENT: a source
/// that is not measured right now adds nothing to any route (G-A contract) — never a centred
/// stand-in. An offline render reads none of this, so an export never depends on a live sensor.
/// `lfo.1` has a cell but no writer: it is read from the song position (`Modulation.songLFO`).
/// No locks, no allocation after `init`; any thread may write, the render thread reads.
public final class ModulationInputs: @unchecked Sendable {
    private final class Cell: @unchecked Sendable {
        /// The value's bit pattern; NaN means absent. A value that must stay on the device (Apple
        /// Health, REC-1, App Store 5.1.3) is stored negated (sign bit set, `-0.0` for zero): value and
        /// provenance live in ONE atomic, so no reader can pair a private value with a shareable flag.
        let bits = Atomic<UInt64>(Double.nan.bitPattern)
    }

    private let cells: [Cell]

    public init() {
        cells = ModulationSource.allCases.map { _ in Cell() }
    }

    /// The source's newest measurement, or nil when it stopped being measured. A value outside
    /// 0 … 1 or not finite is stored as absent rather than clamped into a full swing.
    /// `mayLeaveDevice` is the value's provenance: false for a value that must stay on this
    /// device (Apple Health); it travels with the value, so the next writer sets its own.
    public func set(_ source: ModulationSource, _ value: Double?, mayLeaveDevice: Bool = true) {
        guard let index = Self.index(source) else { return }
        let stored = value.flatMap { $0.isFinite && (0...1).contains($0) ? $0 : nil }
            .map { mayLeaveDevice ? Swift.abs($0) : -Swift.abs($0) } ?? .nan
        cells[index].bits.store(stored.bitPattern, ordering: .relaxed)
    }

    /// Render-safe: the source's value, or nil while it is absent.
    public func value(_ source: ModulationSource) -> Double? {
        guard let index = Self.index(source) else { return nil }
        return value(at: index)
    }

    /// The source's value for anything that sends it off the device (MIDI out, the live stream's
    /// picture): nil while it is absent, and nil for a value that must stay on the device. Render-safe.
    public func shareableValue(_ source: ModulationSource) -> Double? {
        guard let index = Self.index(source), index < cells.count else { return nil }
        let reading = Double(bitPattern: cells[index].bits.load(ordering: .relaxed))
        return reading.isNaN || reading.sign == .minus ? nil : reading
    }

    /// Render-safe, by the source's position in `ModulationSource.allCases`.
    public func value(at index: Int) -> Double? {
        guard index >= 0, index < cells.count else { return nil }
        let reading = Double(bitPattern: cells[index].bits.load(ordering: .relaxed))
        if reading.isNaN { return nil }
        return reading.sign == .minus ? -reading : reading
    }

    /// Every source absent again: a stopped sensor, a song switch.
    public func clear() {
        for cell in cells { cell.bits.store(Double.nan.bitPattern, ordering: .relaxed) }
    }

    public static func index(_ source: ModulationSource) -> Int? {
        ModulationSource.allCases.firstIndex(of: source)
    }
}

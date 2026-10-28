import EchoelCore
import Foundation
import Synchronization

/// The live value of each modulation source, as the app last measured it, for the render thread
/// to read (wave W2). One cell per `ModulationSource`, each normalized 0 … 1 or ABSENT: a source
/// that is not measured right now adds nothing to any route (G-A contract) — never a centred
/// stand-in. An offline render reads none of this, so an export never depends on a live sensor.
/// No locks, no allocation after `init`; any thread may write, the render thread reads.
public final class ModulationInputs: @unchecked Sendable {
    private final class Cell: @unchecked Sendable {
        /// The value's bit pattern; NaN means absent.
        let bits = Atomic<UInt64>(Double.nan.bitPattern)
    }

    private let cells: [Cell]

    public init() {
        cells = ModulationSource.allCases.map { _ in Cell() }
    }

    /// The source's newest measurement, or nil when it stopped being measured. A value outside
    /// 0 … 1 or not finite is stored as absent rather than clamped into a full swing.
    public func set(_ source: ModulationSource, _ value: Double?) {
        guard let index = Self.index(source) else { return }
        let stored = value.flatMap { $0.isFinite && (0...1).contains($0) ? $0 : nil } ?? .nan
        cells[index].bits.store(stored.bitPattern, ordering: .relaxed)
    }

    /// Render-safe: the source's value, or nil while it is absent.
    public func value(_ source: ModulationSource) -> Double? {
        guard let index = Self.index(source) else { return nil }
        return value(at: index)
    }

    /// Render-safe, by the source's position in `ModulationSource.allCases`.
    public func value(at index: Int) -> Double? {
        guard index >= 0, index < cells.count else { return nil }
        let reading = Double(bitPattern: cells[index].bits.load(ordering: .relaxed))
        return reading.isNaN ? nil : reading
    }

    /// Every source absent again: a stopped sensor, a song switch.
    public func clear() {
        for cell in cells { cell.bits.store(Double.nan.bitPattern, ordering: .relaxed) }
    }

    public static func index(_ source: ModulationSource) -> Int? {
        ModulationSource.allCases.firstIndex(of: source)
    }
}

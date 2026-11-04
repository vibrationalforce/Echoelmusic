import EchoelCore
import EchoelDSP
import Foundation
import Synchronization

/// The built-in drum kit as a plugin plays it: General MIDI drum notes in, stereo out, the level at
/// address 0 and the kit's sound after it (the kick's glide, the hats' and toms' models, each
/// piece's tune, decay and level — `InstrumentDevice.drums`). Shared by the Echoel Drums Audio
/// Unit and its tests. Nothing allocates after `init`.
public final class DrumKernel: InstrumentKernel, @unchecked Sendable {
    /// The drums' Core table (`InstrumentDevice.drums`): the level at address 0, the sound after it.
    public static let parameters = InstrumentDevice.drums.parameters.map(InstrumentKernelParameter.init)
    public let sampleRate: Double
    public let maximumFrames: Int

    private let level: Atomic<UInt32>
    /// The level's range, copied from the table once.
    private let range: ClosedRange<Float>
    private var kit: DrumKit
    private let mono: UnsafeMutablePointer<Float>
    /// The level the output is at; it glides toward the parameter so a move never clicks.
    private var gain: Float
    private let glide: Float
    /// Every address's value (the level's is read from `level`), each clamped to its row, and a
    /// version the render thread compares so the kit's sound is set only after a change.
    private let values: UnsafeMutablePointer<Float>
    private let lower: UnsafeMutablePointer<Float>
    private let upper: UnsafeMutablePointer<Float>
    private let count: Int
    private let version = Atomic<UInt64>(0)
    private var appliedVersion: UInt64 = .max
    /// Addresses of the kit's sound, looked up by key once: -1 where the table has no such row.
    private let glideAddress: Int
    private let hatAddress: Int
    private let tomAddress: Int
    /// Per piece (kit order): tune, decay, level.
    private let pieceAddresses: UnsafeMutablePointer<SIMD4<Int32>>

    public convenience init(sampleRate: Double, maximumFrames: Int = 4_096) {
        self.init(sampleRate: sampleRate, maximumFrames: maximumFrames, level: Float(Self.parameters.first?.defaultValue ?? 0.8))
    }

    /// The kit at `level` from its first sample: the output starts there instead of gliding to it.
    /// The app's engine plays its drums at the song's default, 1 (unity, as it always has); the
    /// plugin starts at the table's default. A glide from 0.8 never quite reaches 1 in `Float`, so a level the engine
    /// needs exactly has to be set here, not through `setParameter`.
    public init(sampleRate: Double, maximumFrames: Int, level start: Float) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        self.maximumFrames = Swift.max(1, maximumFrames)
        let row = Self.parameters.first
        range = row.map { Float($0.range.lowerBound)...Float($0.range.upperBound) } ?? 0...1
        let clamped = start.isFinite ? Swift.min(Swift.max(start, range.lowerBound), range.upperBound) : range.upperBound
        level = Atomic(clamped.bitPattern)
        gain = clamped
        kit = DrumKit(sampleRate: Float(rate))
        mono = .allocate(capacity: self.maximumFrames)
        mono.initialize(repeating: 0, count: self.maximumFrames)
        glide = 1 - expf(-1 / (0.005 * Float(rate)))
        let table = Self.parameters
        count = table.count
        values = .allocate(capacity: Swift.max(1, count))
        lower = .allocate(capacity: Swift.max(1, count))
        upper = .allocate(capacity: Swift.max(1, count))
        for (i, row) in table.enumerated() {
            values[i] = Float(row.defaultValue)
            lower[i] = Float(row.range.lowerBound)
            upper[i] = Float(row.range.upperBound)
        }
        let rows = InstrumentDevice.drums.parameters
        func address(_ key: String) -> Int { rows.firstIndex { $0.key.rawValue == key } ?? -1 }
        glideAddress = address(SynthParameter.drumsKickGlide.key.rawValue)
        hatAddress = address(SynthParameter.drumsHatModel.key.rawValue)
        tomAddress = address(SynthParameter.drumsTomModel.key.rawValue)
        pieceAddresses = .allocate(capacity: DrumKit.Piece.allCases.count)
        pieceAddresses.initialize(repeating: SIMD4(repeating: -1), count: DrumKit.Piece.allCases.count)
        for (index, piece) in SynthParameter.drumPieces.enumerated() where index < DrumKit.Piece.allCases.count {
            pieceAddresses[index] = SIMD4(Int32(address("drums.\(piece.key).tune")), Int32(address("drums.\(piece.key).decay")),
                                          Int32(address("drums.\(piece.key).level")), -1)
        }
        applySound()
    }

    deinit {
        mono.deallocate()
        values.deallocate()
        lower.deallocate()
        upper.deallocate()
        pieceAddresses.deallocate()
    }

    /// Any thread. Clamped to the row's range; a value that is not finite is ignored.
    public func setParameter(_ address: Int, _ value: Float) {
        guard value.isFinite, address >= 0, address < count else { return }
        if address == 0 {
            level.store(Swift.min(Swift.max(value, range.lowerBound), range.upperBound).bitPattern, ordering: .relaxed)
            return
        }
        values[address] = Swift.min(Swift.max(value, lower[address]), upper[address])
        version.add(1, ordering: .releasing)
    }

    public func parameter(_ address: Int) -> Float {
        guard address >= 0, address < count else { return 0 }
        return address == 0 ? Float(bitPattern: level.load(ordering: .relaxed)) : values[address]
    }

    /// The value at `address`, or `fallback` where the table has no such row.
    private func value(_ address: Int32, _ fallback: Float) -> Float {
        address >= 0 && Int(address) < count ? values[Int(address)] : fallback
    }

    /// Render thread (and `init`): hands the kit the values set since the last time. A ringing hit
    /// keeps its sound; the next one plays the new values.
    private func applySound() {
        let now = version.load(ordering: .acquiring)
        guard now != appliedVersion else { return }
        appliedVersion = now
        for piece in DrumKit.Piece.allCases {
            let at = pieceAddresses[piece.rawValue]
            kit.setSound(DrumKit.PieceSound(tune: value(at[0], 0), decay: value(at[1], 1), level: value(at[2], 1)), for: piece)
        }
        kit.setKickGlide(value(Int32(glideAddress), 1))
        kit.setHatModel(value(Int32(hatAddress), 0).rounded() == 1 ? .metal : .noise)
        kit.setTomModel(value(Int32(tomAddress), 0).rounded() == 1 ? .modal : .sine)
    }

    // MARK: - Render thread

    /// Render thread. Whether a piece is ringing.
    public var isSounding: Bool { kit.activeVoiceCount > 0 }

    /// The level is read at the top of every render; the kit's sound is handed over here.
    public func commitParameters() { applySound() }

    /// Render thread. All sound off (CC 120).
    public func reset() { kit.reset() }

    /// Note on plays a piece; note off is ignored (drums are one-shots); CC 120 silences the kit.
    /// A hit on a silent kit starts at the level, not gliding from an old one: the app's engine
    /// renders no silent kernel, so a level set in a break would otherwise reach the next hit
    /// only after its transient.
    public func receive(status: UInt8, _ data1: UInt8, _ data2: UInt8) {
        switch status & 0xF0 {
        case 0x90:
            if !isSounding { gain = Float(bitPattern: level.load(ordering: .relaxed)) }
            applySound()
            kit.noteOn(pitch: data1 & 0x7F, velocity: data2 & 0x7F)
        case 0xB0 where data1 == 120: kit.reset()
        default: break
        }
    }

    public func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, gain demo: Float) {
        let target = Float(bitPattern: level.load(ordering: .relaxed))
        applySound()
        var done = 0
        while done < frames {
            let n = Swift.min(frames - done, maximumFrames)
            mono.update(repeating: 0, count: n)
            kit.render(into: UnsafeMutableBufferPointer(start: mono, count: n))
            for i in 0..<n {
                gain += (target - gain) * glide
                let sample = mono[i].isFinite ? mono[i] * gain * demo : 0
                left[done + i] = sample
                right[done + i] = sample
            }
            done += n
        }
    }
}

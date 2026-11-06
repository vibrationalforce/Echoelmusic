import Foundation

/// The sequence numbers of the DMX frames a run sends, per light protocol and per universe on the
/// wire, as both standards count (Q2). A receiver drops a frame whose number runs backwards (E1.31
/// §6.7.2 treats a step back of 1 … 20 as out of order), so switching an output off and on again,
/// pointing it at another receiver or opening a second iPad window never starts a universe's count
/// over within one run: there is no reset. A new launch starts again from the first number — the
/// receiver has heard nothing from this source for longer than its timeout, so it takes the new
/// stream as new.
public struct WireSequences: Equatable, Sendable {
    private var last: [LitLedger.Output: [Int: UInt8]] = [:]

    public init() {}

    /// The number of the next frame of `output` to `universe`, and the count moves on: Art-Net
    /// runs 1 … 255 and never says 0 (`ArtDMXPacket.nextSequence`), sACN wraps 255 → 0
    /// (`E131Packet.nextSequence`).
    public mutating func next(_ output: LitLedger.Output, universe: Int) -> UInt8 {
        let previous = last[output]?[universe] ?? 0
        let number: UInt8
        switch output {
        case .artNet: number = ArtDMXPacket.nextSequence(previous)
        case .sacn: number = E131Packet.nextSequence(previous)
        }
        last[output, default: [:]][universe] = number
        return number
    }
}

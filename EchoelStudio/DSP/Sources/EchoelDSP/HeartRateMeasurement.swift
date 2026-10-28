import Foundation

/// One Bluetooth Heart Rate Measurement (characteristic 0x2A37 of the Heart Rate service 0x180D),
/// as a chest strap sends it about once a second. Ported from the earlier app's strap reader
/// (`PolarH10BioPublisher.parseHRMeasurement`) for wave W1 "body"; the rules are the Bluetooth
/// SIG profile's:
/// - flags bit 0: heart rate as one byte (0) or two little-endian bytes (1);
/// - bits 1–2: `10` the strap can tell skin contact and has none, `11` it has contact, `0x` it
///   cannot tell;
/// - bit 3: a two-byte energy field follows (skipped);
/// - bit 4: RR intervals follow, two little-endian bytes each, in 1/1024 s.
///
/// A strap that reports no contact keeps sending its last rate with the electrodes off the skin:
/// that reading is `nil` here, with no rate and no beats, so it can never pass for a body.
public struct HeartRateMeasurement: Equatable, Sendable {
    public enum Contact: Equatable, Sendable {
        /// The strap does not report contact.
        case unknown
        case detected
    }

    /// Beats per minute as the strap counted them.
    public let beatsPerMinute: Int
    /// The beat-to-beat intervals in this packet, in milliseconds, oldest first.
    public let rrIntervalsMilliseconds: [Double]
    public let contact: Contact

    /// Nil for an empty or cut-off packet and for a strap that reports it is off the skin.
    public init?(_ bytes: [UInt8]) {
        guard let flags = bytes.first else { return nil }
        let wideRate = flags & 0x01 != 0
        let contactSupported = flags & 0x02 != 0
        let contactDetected = flags & 0x04 != 0
        let energyPresent = flags & 0x08 != 0
        let intervalsPresent = flags & 0x10 != 0
        guard !(contactSupported && !contactDetected) else { return nil }
        var index = 1
        if wideRate {
            guard index + 1 < bytes.count else { return nil }
            beatsPerMinute = Int(bytes[index]) | Int(bytes[index + 1]) << 8
            index += 2
        } else {
            guard index < bytes.count else { return nil }
            beatsPerMinute = Int(bytes[index])
            index += 1
        }
        if energyPresent { index += 2 }
        var intervals: [Double] = []
        if intervalsPresent {
            while index + 1 < bytes.count {
                let raw = Int(bytes[index]) | Int(bytes[index + 1]) << 8
                intervals.append(Double(raw) * 1_000 / 1_024)
                index += 2
            }
        }
        rrIntervalsMilliseconds = intervals
        contact = contactSupported ? .detected : .unknown
    }
}

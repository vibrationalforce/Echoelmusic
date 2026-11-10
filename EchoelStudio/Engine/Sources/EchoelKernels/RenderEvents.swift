/// Where a host's event falls inside one render call, worked out without arithmetic that can
/// trap. A render block reads three numbers a host made: the call's sample time (a `Double`), an
/// event's time (an `Int64`) and a parameter's address (a `UInt64`). Swift stops the process when
/// a `Double` that is not a number is turned into an integer, when a subtraction leaves its type,
/// and when an address does not fit an index — and in another app's host the process is the one
/// every Echoelmusic unit of the session runs in. A host owes none of these numbers a meaning
/// (a timestamp's flags may say its sample time is not valid), so each is read here in a way
/// that always has an answer.
///
/// Pure and allocation-free: a render block calls it.
public enum RenderEvents {
    /// The call's first sample as an event time, cut toward zero. A sample time that is not
    /// finite, or lies beyond what an `Int64` holds, counts as 0: the events of that call then
    /// take effect at its start or its end (`offset`), late by at most one call, and never lost.
    @inline(__always)
    public static func start(sampleTime: Double) -> Int64 {
        Int64(exactly: sampleTime.rounded(.towardZero)) ?? 0
    }

    /// The frame inside this call at which an event stamped `eventTime` takes effect: its distance
    /// from `start`, never before `done` (the frames already rendered) and never past `frames`.
    /// A distance that does not fit the type is as far behind, or ahead, as it can be.
    @inline(__always)
    public static func offset(eventTime: Int64, start: Int64, done: Int, frames: Int) -> Int {
        let (distance, overflowed) = eventTime.subtractingReportingOverflow(start)
        let relative: Int64 = overflowed ? (eventTime < start ? Int64.min : Int64.max) : distance
        let earliest = Int64(Swift.max(done, 0))
        let latest = Swift.max(Int64(Swift.max(frames, 0)), earliest)
        return Int(Swift.min(Swift.max(relative, earliest), latest))
    }

    /// A host's parameter address as a kernel's index; -1, which no kernel has, for an address
    /// beyond an index.
    @inline(__always)
    public static func address(_ address: UInt64) -> Int {
        Int(exactly: address) ?? -1
    }
}

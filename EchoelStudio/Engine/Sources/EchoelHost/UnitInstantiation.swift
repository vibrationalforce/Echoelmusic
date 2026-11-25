import Foundation
import Synchronization

/// Waits for an answer that arrives through a completion handler — `AUAudioUnit.instantiate`, whose
/// extension may never start, or start too late — or for a deadline, whichever comes first. The
/// first of the two is the answer; the other is ignored, so a unit that arrives after the deadline
/// is dropped instead of playing in a slot that already said it failed. Main thread or any task;
/// never the render thread (it locks and sleeps).
public enum UnitInstantiation {
    /// How long a unit from another maker may take to start before its slot says so: long enough
    /// for an extension that loads a sample library on first start, short enough that a page does
    /// not say "Loading…" for ever.
    public static let deadline: Duration = .seconds(15)

    /// Starts the request with `start`, which must call its argument once with the answer (more
    /// calls are ignored), and returns that answer, or `timedOut` once `timeout` has passed.
    public static func answer<Value: Sendable>(within timeout: Duration, timedOut: Value,
                                               _ start: (@escaping @Sendable (Value) -> Void) -> Void) async -> Value {
        let once = Once<Value>()
        return await withCheckedContinuation { (continuation: CheckedContinuation<Value, Never>) in
            once.arm(continuation)
            let timer = Task {
                // Cancelled once the answer came; resolving then would change nothing, but say so.
                guard (try? await Task.sleep(for: timeout)) != nil else { return }
                once.resolve(timedOut)
            }
            start { value in
                once.resolve(value)
                timer.cancel()
            }
        }
    }

    /// Resumes its continuation exactly once, with whichever value comes first.
    private final class Once<Value: Sendable>: Sendable {
        private let slot = Mutex<CheckedContinuation<Value, Never>?>(nil)

        func arm(_ continuation: CheckedContinuation<Value, Never>) {
            slot.withLock { $0 = continuation }
        }

        func resolve(_ value: Value) {
            let continuation = slot.withLock { stored in
                let first = stored
                stored = nil
                return first
            }
            continuation?.resume(returning: value)
        }
    }
}

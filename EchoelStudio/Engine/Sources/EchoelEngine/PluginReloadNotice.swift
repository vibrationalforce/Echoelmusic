/// What the status line says after hosted plugins are loaded again — after one stopped by itself,
/// after a media reset, after a new sample rate — and only what turned out true (review
/// 2026-10-21). A reload is said once it has happened, never at the stop; a unit that does not
/// come back is named with its reason; and every sentence names its units, so it stays true
/// whatever else happens before or after it. A reload for a new sample rate is said only when it
/// fails: the rate change has its own notice, and the settings survive it.
///
/// `Slot` is where a unit plays (a track's instrument, an insert), `Component` which unit it is:
/// a slot that now asks for another unit drops out without a word.
public struct PluginReloadNotice<Slot: Hashable & Sendable, Component: Hashable & Sendable>: Sendable {
    public enum Cause: Sendable, Equatable {
        /// The unit stopped by itself.
        case crash
        /// The media services were reset.
        case reset
        /// The output's sample rate changed.
        case rate
    }

    private struct Pending: Sendable {
        var name: String
        var component: Component
        var cause: Cause
    }

    private var pending: [Slot: Pending] = [:]
    private var reloaded: [(name: String, cause: Cause)] = []
    private var failures: [(name: String, reason: String)] = []

    /// The status line's sentence, or nil when there is nothing to say yet.
    public private(set) var text: String?

    public init() {}

    /// Whether `slot` is waiting for its unit to come back.
    public func isPending(_ slot: Slot) -> Bool {
        pending[slot] != nil
    }

    /// The unit in `slot` is gone and is being loaded again.
    public mutating func stopped(_ slot: Slot, name: String, component: Component, cause: Cause) {
        pending[slot] = Pending(name: name, component: component, cause: cause)
    }

    /// The unit is gone and is not loaded again — it stopped too often.
    public mutating func refused(name: String, reason: String) {
        failures.append((name, reason))
        compose()
    }

    /// The unit in `slot` came back. Nothing changes for a slot that was not waiting.
    public mutating func loaded(_ slot: Slot) {
        guard let done = pending.removeValue(forKey: slot) else { return }
        reloaded.append((done.name, done.cause))
        compose()
    }

    /// The unit in `slot` did not come back, for `reason`.
    public mutating func failed(_ slot: Slot, reason: String) {
        guard let done = pending.removeValue(forKey: slot) else { return }
        failures.append((done.name, reason))
        compose()
    }

    /// Keeps waiting only for the slots that still want the same unit; a slot that was removed or
    /// now names another plugin is not loaded again, so nothing is said about it.
    public mutating func keep(where stillWanted: (Slot, Component) -> Bool) {
        pending = pending.filter { stillWanted($0.key, $0.value.component) }
    }

    /// The status line was cleared (Play, a finished export): what is said from now on is only
    /// what happens next. Reloads still under way are announced when they finish.
    public mutating func clear() {
        reloaded = []
        failures = []
        text = nil
    }

    private mutating func compose() {
        var sentences: [String] = []
        if failures.count == 1, let only = failures.first {
            sentences.append(only.reason)
        } else if failures.count > 1 {
            sentences.append("\(Self.list(failures.map { $0.name })) did not load again; their pages say why.")
        }
        let crashed = Self.unique(reloaded.filter { $0.cause == .crash }.map { $0.name })
        if !crashed.isEmpty {
            sentences.append(crashed.count == 1
                ? "\(Self.list(crashed)) stopped and was loaded again with its last saved settings."
                : "\(Self.list(crashed)) stopped and were loaded again with their last saved settings.")
        }
        let afterReset = Self.unique(reloaded.filter { $0.cause == .reset }.map { $0.name })
        if !afterReset.isEmpty {
            sentences.append(afterReset.count == 1
                ? "\(Self.list(afterReset)) was loaded again after an audio reset, with its last saved settings."
                : "\(Self.list(afterReset)) were loaded again after an audio reset, with their last saved settings.")
        }
        text = sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    /// Two copies of one plugin are one name in a sentence.
    private static func unique(_ names: [String]) -> [String] {
        var seen: Set<String> = []
        return names.filter { seen.insert($0).inserted }
    }

    /// "A", "A and B", "A, B and C".
    static func list(_ names: [String]) -> String {
        let distinct = unique(names)
        guard let last = distinct.last else { return "" }
        guard distinct.count > 1 else { return last }
        return distinct.dropLast().joined(separator: ", ") + " and " + last
    }
}

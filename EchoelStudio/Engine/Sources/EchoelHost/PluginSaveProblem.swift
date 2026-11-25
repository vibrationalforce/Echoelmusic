import EchoelCore
import Foundation

/// What the page of a loaded plugin says when its settings could not go into the song: one
/// sentence, naming the plugin, the cause, and that the song keeps what it had (every outcome but
/// a change leaves the stored state in place, `PluginStateCapture`). Kept here, not in the app,
/// so the wording of each outcome is tested.
public enum PluginSaveProblem {
    /// What one capture means for the sentence on the page.
    public enum Verdict: Equatable, Sendable {
        /// The settings were read (changed or not): any earlier sentence goes.
        case clear
        /// Nothing was asked of this unit — it is not loaded, or the slot names another plugin
        /// now: an earlier sentence stays as it was.
        case keep
        case problem(String)
    }

    /// `isLoaded`: the slot's unit is loaded and is the plugin the song names. Only then does an
    /// unavailable state mean that the plugin gave none.
    public static func verdict(for capture: PluginStateCapture, name: String, isLoaded: Bool) -> Verdict {
        let kept = "The song keeps the settings saved before."
        switch capture {
        case .changed, .unchanged:
            return .clear
        case .unavailable:
            return isLoaded ? .problem("\(name) gave no settings to save. \(kept)") : .keep
        case .notSerializable:
            return .problem("\(name)'s settings could not be saved: the plugin returned settings a song cannot hold. \(kept)")
        case .tooLarge(let bytes):
            return .problem("\(name)'s settings are too large to save (\(megabytes(bytes)), the limit is \(megabytes(PluginComponent.maximumStateBytes))). \(kept)")
        }
    }

    /// The song refused the settings the plugin gave (`ProjectStore` threw).
    public static func refused(name: String, reason: String) -> String {
        "The song did not take \(name)'s settings (\(reason)). It keeps the settings saved before."
    }

    /// Bytes as megabytes with one decimal, the way the page shows a size: "8.0 MB".
    static func megabytes(_ bytes: Int) -> String {
        let tenths = (Swift.max(0, bytes) * 10 + 524_288) / 1_048_576
        return "\(tenths / 10).\(tenths % 10) MB"
    }
}

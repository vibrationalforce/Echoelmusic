import EchoelCore

/// The state an Echoel instrument unit hands a host and takes back (`AUAudioUnit.fullState`).
public enum InstrumentState {
    /// Written into every state an Echoel instrument hands out, so a restore can tell it from a
    /// state the earlier app wrote under the same `echl` id.
    public static let markerKey = "echoel.studio"
    /// `kAUPresetDataKey`: where the base `fullState` keeps its snapshot of the parameter tree,
    /// value by address.
    static let baseSnapshotKey = "data"

    /// What to give the base restore. The earlier app's instrument, before its own state fix,
    /// saved its parameters under "data" by address, and `echl` now opens the synth, whose
    /// addresses mean other things: that instrument's HRV would land on the Cutoff. Such a state
    /// opens at the synth's defaults instead. A state this app wrote keeps everything.
    public static func forBaseRestore(_ state: [String: Any]?, subtype: UInt32) -> [String: Any]? {
        guard var state, subtype == OwnPlugin.legacyBodyVibe.component.subtype, state[markerKey] == nil else {
            return state
        }
        state.removeValue(forKey: baseSnapshotKey)
        return state
    }
}

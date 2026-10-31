/// The Audio Units Echoel makes, as the app's store and the plugins themselves know them. All of
/// them ship in ONE extension (`com.echoelmusic.app.auv3`); the instruments are unlocked by the
/// one purchase the plugin layer names (`PluginUnlock`, `Plugins/Shared/PluginUnlock.swift`), the
/// effects need nothing. The open packages describe the plugins; they do not know that anything
/// is sold — the product id lives with the store and the licence check that read it.
///
/// A component's `name` is the unit's own name; the host shows it after the manufacturer
/// ("Echoel: Synth", conductor 2026-10-31), so it never repeats "Echoel". Type, subtype and
/// manufacturer are what a host session saves, and they never change.
public struct OwnPlugin: Sendable, Equatable, Identifiable {
    public let component: PluginComponent
    public let summary: String

    public var id: UInt32 { component.subtype }

    public static let synth = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("eSyn"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Synth",
                                   manufacturerName: "Echoel"),
        summary: "The studio's synth.")

    public static let drums = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("eDrm"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Drums",
                                   manufacturerName: "Echoel"),
        summary: "The studio's synthesized drum kit on the General MIDI drum map.")

    public static let sampler = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("eSmp"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Sampler",
                                   manufacturerName: "Echoel"),
        summary: "Load a sample and play it across the keys. The sample is saved with the host's session.")

    /// The four standard effects for other hosts (`StandardEffect.extensionComponent`). In Echoel
    /// itself they stay free under their own ids.
    public static let effects = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code("xEQ5"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Effects",
                                   manufacturerName: "Echoel"),
        summary: "EQ, Compressor, Delay and Reverb.")

    /// The instrument the earlier Echoelmusic app shipped (`echl`, "EchoelBodyVibe"). The
    /// extension still answers to it with the synth, so a host session saved with it opens.
    /// Not listed in the store: it is a door for old sessions, not a product.
    public static let legacyBodyVibe = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("echl"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Synth",
                                   manufacturerName: "Echoel"),
        summary: "Opens host sessions saved with the earlier Echoelmusic instrument.")

    /// What the purchase unlocks in other hosts.
    public static let instruments: [OwnPlugin] = [synth, drums, sampler]
    /// Free in other hosts as in Echoel.
    public static let free: [OwnPlugin] = [effects]
    public static let all: [OwnPlugin] = instruments + free
}

/// The drum kit's note map as one line, for every place that explains it — the Drums page in
/// the Studio and the Drums plugin in a host say the same thing. One note per piece, in note
/// order; `DrumMapTests` (EchoelKernelsTests) plays each one through the kit and checks it sounds
/// as the piece it names, so the line cannot drift from what the kit plays.
public enum DrumNoteMap {
    public static let pieces: [(name: String, note: Int)] = [
        ("Kick", 36), ("Snare", 38), ("Clap", 39), ("Closed Hat", 42),
        ("Low Tom", 45), ("Open Hat", 46), ("Crash", 49), ("High Tom", 50),
    ]

    /// "General MIDI drum map: Kick 36 · Snare 38 · … · High Tom 50."
    public static var line: String {
        "General MIDI drum map: " + pieces.map { "\($0.name) \($0.note)" }.joined(separator: " · ") + "."
    }
}

/// The effects every Echoel user has, free: the channel tools of a desk. They are Audio Units
/// registered inside the app, so they sit on the same insert chain as any other plugin and are
/// saved, automated and learned the same way.
public enum StandardEffect: String, CaseIterable, Sendable, Identifiable {
    // A new effect goes at the end: a saved insert names its component, never this order.
    case equalizer, compressor, delay, reverb, chorus, phaser, flanger, limiter, saturation, tremolo, bitcrusher, tape, stereoWidth, ringModulator, frequencyShifter,
        pitchCorrection, harmonizer, granular

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .equalizer: "EQ"
        case .compressor: "Compressor"
        case .delay: "Delay"
        case .reverb: "Reverb"
        case .chorus: "Chorus"
        case .phaser: "Phaser"
        case .flanger: "Flanger"
        case .limiter: "Limiter"
        case .saturation: "Saturation"
        case .tremolo: "Tremolo"
        case .bitcrusher: "Bitcrusher"
        case .tape: "Tape"
        case .stereoWidth: "Stereo Width"
        case .ringModulator: "Ring Modulator"
        case .frequencyShifter: "Frequency Shifter"
        case .pitchCorrection: "Pitch Correction"
        case .harmonizer: "Harmonizer"
        case .granular: "Granular"
        }
    }

    public var component: PluginComponent {
        let subtype = switch self {
        case .equalizer: "eEQ5"
        case .compressor: "eCmp"
        case .delay: "eDly"
        case .reverb: "eRvb"
        case .chorus: "eCho"
        case .phaser: "ePhs"
        case .flanger: "eFlg"
        case .limiter: "eLim"
        case .saturation: "eSat"
        case .tremolo: "eTrm"
        case .bitcrusher: "eBit"
        case .tape: "eTap"
        case .stereoWidth: "eWid"
        case .ringModulator: "eRng"
        case .frequencyShifter: "eFsh"
        case .pitchCorrection: "eTun"
        case .harmonizer: "eHrm"
        case .granular: "eGrn"
        }
        return PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code(subtype),
                               manufacturer: PluginComponent.code("Echo"), name: "Echoel \(title)",
                               manufacturerName: "Echoel")
    }

    /// The same effect as the Audio Unit extension registers it for other hosts. A different
    /// subtype from `component` on purpose: the app registers `component` in its own process,
    /// and two registrations of one id would leave which one loads to chance.
    public var extensionComponent: PluginComponent {
        let subtype = switch self {
        case .equalizer: "xEQ5"
        case .compressor: "xCmp"
        case .delay: "xDly"
        case .reverb: "xRvb"
        case .chorus: "xCho"
        case .phaser: "xPhs"
        case .flanger: "xFlg"
        case .limiter: "xLim"
        case .saturation: "xSat"
        case .tremolo: "xTrm"
        case .bitcrusher: "xBit"
        case .tape: "xTap"
        case .stereoWidth: "xWid"
        case .ringModulator: "xRng"
        case .frequencyShifter: "xFsh"
        case .pitchCorrection: "xTun"
        case .harmonizer: "xHrm"
        case .granular: "xGrn"
        }
        // The host shows "Echoel: EQ" — manufacturer, then this name, as `Plugins/AUv3/Info.plist`
        // registers it. The app's own copy (`component`) keeps its stored name: a song saves it.
        return PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code(subtype),
                               manufacturer: PluginComponent.code("Echo"), name: title,
                               manufacturerName: "Echoel")
    }

    /// The standard effect an extension component is, if it is one.
    public init?(extensionComponent component: PluginComponent) {
        guard let match = Self.allCases.first(where: {
            $0.extensionComponent.type == component.type && $0.extensionComponent.subtype == component.subtype
                && $0.extensionComponent.manufacturer == component.manufacturer
        }) else { return nil }
        self = match
    }

    /// The standard effect a component is, if it is one.
    public init?(component: PluginComponent) {
        guard let match = Self.allCases.first(where: {
            $0.component.type == component.type && $0.component.subtype == component.subtype
                && $0.component.manufacturer == component.manufacturer
        }) else { return nil }
        self = match
    }
}

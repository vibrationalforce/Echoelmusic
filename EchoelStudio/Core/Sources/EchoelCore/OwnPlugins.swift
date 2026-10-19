/// The Audio Units Echoel makes, as the app's store and the plugins themselves know them. All of
/// them ship in ONE extension (`com.echoelmusic.app.auv3`); the instruments are unlocked by the
/// one purchase the plugin layer names (`PluginUnlock`, `Plugins/Shared/PluginUnlock.swift`), the
/// effects need nothing. The open packages describe the plugins; they do not know that anything
/// is sold — the product id lives with the store and the licence check that read it.
public struct OwnPlugin: Sendable, Equatable, Identifiable {
    public let component: PluginComponent
    public let summary: String

    public var id: UInt32 { component.subtype }

    public static let synth = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("eSyn"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Echoel Synth",
                                   manufacturerName: "Echoel"),
        summary: "The studio's synth.")

    public static let drums = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("eDrm"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Echoel Drums",
                                   manufacturerName: "Echoel"),
        summary: "The studio's synthesized drum kit on the General MIDI drum map.")

    public static let sampler = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("eSmp"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Echoel Sampler",
                                   manufacturerName: "Echoel"),
        summary: "Load a sample and play it across the keys. The sample is saved with the host's session.")

    /// The four standard effects for other hosts (`StandardEffect.extensionComponent`). In Echoel
    /// itself they stay free under their own ids.
    public static let effects = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code("xEQ5"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Echoel Effects",
                                   manufacturerName: "Echoel"),
        summary: "EQ, Compressor, Delay and Reverb.")

    /// The instrument the earlier Echoelmusic app shipped (`echl`, "EchoelBodyVibe"). The
    /// extension still answers to it with the synth, so a host session saved with it opens.
    /// Not listed in the store: it is a door for old sessions, not a product.
    public static let legacyBodyVibe = OwnPlugin(
        component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("echl"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Echoel Synth",
                                   manufacturerName: "Echoel"),
        summary: "Opens host sessions saved with the earlier Echoelmusic instrument.")

    /// What the purchase unlocks in other hosts.
    public static let instruments: [OwnPlugin] = [synth, drums, sampler]
    /// Free in other hosts as in Echoel.
    public static let free: [OwnPlugin] = [effects]
    public static let all: [OwnPlugin] = instruments + free
}

/// The effects every Echoel user has, free: the channel tools of a desk. They are Audio Units
/// registered inside the app, so they sit on the same insert chain as any other plugin and are
/// saved, automated and learned the same way.
public enum StandardEffect: String, CaseIterable, Sendable, Identifiable {
    case equalizer, compressor, delay, reverb

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .equalizer: "EQ"
        case .compressor: "Compressor"
        case .delay: "Delay"
        case .reverb: "Reverb"
        }
    }

    public var component: PluginComponent {
        let subtype = switch self {
        case .equalizer: "eEQ5"
        case .compressor: "eCmp"
        case .delay: "eDly"
        case .reverb: "eRvb"
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
        }
        return PluginComponent(type: PluginComponent.code("aufx"), subtype: PluginComponent.code(subtype),
                               manufacturer: PluginComponent.code("Echo"), name: "Echoel \(title)",
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

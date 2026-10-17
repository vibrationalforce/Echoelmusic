/// The Audio Units Echoel makes and sells, as the app's store and the plugins themselves know
/// them. One list, so a product id cannot differ between the place that sells a plugin and the
/// plugin that checks the sale.
public struct OwnPlugin: Sendable, Equatable, Identifiable {
    /// The in-app purchase that unlocks the plugin in every host.
    public let productID: String
    public let component: PluginComponent
    public let summary: String

    public var id: String { productID }

    public static let synth = OwnPlugin(
        productID: "com.echoelmusic.studio.synth",
        component: PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("eSyn"),
                                   manufacturer: PluginComponent.code("Echo"), name: "Echoel Synth",
                                   manufacturerName: "Echoel"),
        summary: "The studio's synth as an Audio Unit for AUM, Logic, Cubasis, GarageBand and other hosts.")

    public static let all: [OwnPlugin] = [synth]
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

    /// The standard effect a component is, if it is one.
    public init?(component: PluginComponent) {
        guard let match = Self.allCases.first(where: {
            $0.component.type == component.type && $0.component.subtype == component.subtype
                && $0.component.manufacturer == component.manufacturer
        }) else { return nil }
        self = match
    }
}

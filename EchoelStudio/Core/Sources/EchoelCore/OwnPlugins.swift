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

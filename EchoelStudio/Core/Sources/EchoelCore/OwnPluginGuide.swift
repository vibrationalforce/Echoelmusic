/// What every place that explains Echoelmusic's own Audio Units says about them in other apps —
/// the store page first (A88-4: it read like a test log): what they are, how to load one, what a
/// device has tried and what it has not. Built from the units it is given, `OwnPlugin.instruments`
/// and `OwnPlugin.free` unless told otherwise, so a unit added there joins every line without a
/// change to a page.
///
/// Like the rest of the open packages it knows nothing of a sale (decision of 2026-10-19): the
/// purchase, its price and what it unlocks belong to the plugin layer (`PluginUnlock`) and to the
/// store page's own lines. The one sentence about hosts is the one a device check allows
/// (`ContentPipeline/CLAIMS.md`: the Synth in AUM on an iPhone, 2026-11-10); it stands alone in
/// `tried`, so no other line can widen it, and `untested` beside it says what it does not cover,
/// as every public page that carries the sentence does.
public struct OwnPluginGuide: Equatable, Sendable {
    /// What the units are: their names, as Audio Units for other apps, and built into Echoelmusic.
    public let what: String
    /// How to load one in another app: the kind of unit to add, then its name and its maker as the
    /// host lists them.
    public let howToLoad: String
    /// What a device has tried so far, said once and on its own.
    public let tried: String
    /// What no device has tried yet: every unit but the one `tried` names, the free ones too, and
    /// every other host app.
    public let untested: String

    /// The unit `tried` speaks of: the one a device has tried in another app.
    private static let triedUnit = OwnPlugin.synth

    /// The lines for the instruments `units` and the `free` units; no instruments read as the ones
    /// the app ships, so a page never shows a sentence with a hole in it.
    public init(units: [OwnPlugin] = OwnPlugin.instruments, free: [OwnPlugin] = OwnPlugin.free) {
        let listed = units.isEmpty ? OwnPlugin.instruments : units
        let names = listed.map(\.component.name)
        let maker = listed.first?.component.manufacturerName ?? "Echoelmusic"
        what = listed.count == 1
            ? "\(Self.joined(names, by: "and")) as an Audio Unit for other apps. In Echoelmusic it is built in."
            : "\(Self.joined(names, by: "and")) as Audio Units for other apps. In Echoelmusic they are built in."
        howToLoad = "In the other app, add an Audio Unit instrument and choose \(Self.joined(names, by: "or")) by \(maker)."
        tried = "The synthesizer has been tried in AUM on an iPhone."
        let others = (listed + free).filter { $0.id != Self.triedUnit.id }.map(\.component.name)
        untested = Self.sentenceStart(Self.joined(others + ["other host apps"], by: "and")) + " are not yet tested."
    }

    /// "Synth", "Synth and Drums", "Synth, Drums and Sampler".
    private static func joined(_ names: [String], by word: String) -> String {
        guard let last = names.last else { return "" }
        let rest = names.dropLast()
        return rest.isEmpty ? last : rest.joined(separator: ", ") + " \(word) " + last
    }

    /// `text` with a capital first letter, as it opens a sentence ("Other host apps …").
    private static func sentenceStart(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}

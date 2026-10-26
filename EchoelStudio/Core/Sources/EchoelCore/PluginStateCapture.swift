import Foundation

/// One attempt to capture a plugin's document settings. A changed value is ready for a
/// command, not a claim that the document or its file has accepted it. Every other outcome
/// leaves the last stored state in place. This is a control-side operation, never render work.
public enum PluginStateCapture: Equatable, Sendable {
    case unavailable
    case notSerializable
    case tooLarge(byteCount: Int)
    case unchanged
    case changed(Data)

    /// Reads settings only from the component the document currently names. During a
    /// replacement fade the host can still hold the previous unit in the same slot.
    /// Nil settings mean unavailable; an empty dictionary is a valid state.
    public static func evaluate(component: PluginComponent?, expected: PluginComponent,
                                stored: Data?, settings: () -> [String: Any]?) -> Self {
        guard component == expected, let propertyList = settings() else { return .unavailable }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: propertyList,
                                                            format: .binary, options: 0) else {
            return .notSerializable
        }
        guard data.count <= PluginComponent.maximumStateBytes else {
            return .tooLarge(byteCount: data.count)
        }
        return data == stored ? .unchanged : .changed(data)
    }
}

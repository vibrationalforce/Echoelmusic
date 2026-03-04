import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Lightweight haptic feedback helper for UI interactions
enum HapticHelper {

    enum Style {
        case light, medium, heavy, selection
    }

    enum NotificationType {
        case success, warning, error
    }

    /// Fire a single impact haptic
    static func impact(_ style: Style) {
        #if canImport(UIKit) && !os(macOS)
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light: uiStyle = .light
        case .medium: uiStyle = .medium
        case .heavy: uiStyle = .heavy
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }
        UIImpactFeedbackGenerator(style: uiStyle).impactOccurred()
        #endif
    }

    /// Fire a notification haptic (success, warning, error)
    static func notification(_ type: NotificationType) {
        #if canImport(UIKit) && !os(macOS)
        let uiType: UINotificationFeedbackGenerator.FeedbackType
        switch type {
        case .success: uiType = .success
        case .warning: uiType = .warning
        case .error: uiType = .error
        }
        UINotificationFeedbackGenerator().notificationOccurred(uiType)
        #endif
    }
}

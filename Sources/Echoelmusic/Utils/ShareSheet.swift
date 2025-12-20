import SwiftUI

#if os(iOS)
import UIKit

// MARK: - Share Sheet

/// UIViewControllerRepresentable wrapper for UIActivityViewController
/// Provides a SwiftUI-compatible way to present the iOS share sheet
///
/// Usage:
/// ```swift
/// @State private var showShareSheet = false
/// @State private var shareURL: URL?
///
/// .sheet(isPresented: $showShareSheet) {
///     if let url = shareURL {
///         ShareSheet(activityItems: [url])
///     }
/// }
/// ```
public struct ShareSheet: UIViewControllerRepresentable {
    /// Items to share (URLs, strings, images, etc.)
    public let activityItems: [Any]

    /// Activity types to exclude from the share sheet
    public var excludedActivityTypes: [UIActivity.ActivityType]?

    /// Optional completion handler called when sharing completes or is cancelled
    public var onComplete: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)?

    public init(
        activityItems: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil,
        onComplete: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)? = nil
    ) {
        self.activityItems = activityItems
        self.excludedActivityTypes = excludedActivityTypes
        self.onComplete = onComplete
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.excludedActivityTypes = excludedActivityTypes
        controller.completionWithItemsHandler = onComplete
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed - activity items are set at creation
    }
}

// MARK: - Share Sheet Modifier

/// View modifier for easily presenting a share sheet
public struct ShareSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]?
    var onComplete: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)?
    var onDismiss: (() -> Void)?

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                ShareSheet(
                    activityItems: items,
                    excludedActivityTypes: excludedActivityTypes,
                    onComplete: onComplete
                )
            }
    }
}

public extension View {
    /// Present a share sheet with the given items
    /// - Parameters:
    ///   - isPresented: Binding to control sheet presentation
    ///   - items: Items to share
    ///   - excludedActivityTypes: Activity types to exclude
    ///   - onComplete: Completion handler
    ///   - onDismiss: Called when sheet is dismissed
    func shareSheet(
        isPresented: Binding<Bool>,
        items: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil,
        onComplete: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(ShareSheetModifier(
            isPresented: isPresented,
            items: items,
            excludedActivityTypes: excludedActivityTypes,
            onComplete: onComplete,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Haptic Feedback

/// Provides haptic feedback for various events
public enum HapticFeedback {
    /// Light impact feedback (subtle)
    case light
    /// Medium impact feedback
    case medium
    /// Heavy impact feedback (strong)
    case heavy
    /// Success notification feedback
    case success
    /// Warning notification feedback
    case warning
    /// Error notification feedback
    case error
    /// Selection changed feedback
    case selection

    /// Trigger the haptic feedback
    public func trigger() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

#endif

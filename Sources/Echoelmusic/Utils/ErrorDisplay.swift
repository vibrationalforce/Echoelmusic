//
//  ErrorDisplay.swift
//  Echoelmusic
//
//  Created: 2025-11-26
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  USER-FACING ERROR DISPLAY SYSTEM
//  Replaces silent print() errors with user-visible alerts
//

import SwiftUI

/// Global error manager for user-facing error messages
@MainActor
class ErrorDisplayManager: ObservableObject {
    static let shared = ErrorDisplayManager()

    // MARK: - Published Properties

    @Published var currentError: DisplayableError?
    @Published var errorHistory: [DisplayableError] = []

    private let maxHistorySize = 20

    // MARK: - Error Types

    struct DisplayableError: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let severity: Severity
        let timestamp: Date
        let actionTitle: String?
        let action: (() -> Void)?

        enum Severity {
            case info       // Blue - informational
            case warning    // Yellow - something might be wrong
            case error      // Red - something failed
            case critical   // Red with alert - immediate attention needed
        }

        init(
            title: String,
            message: String,
            severity: Severity = .error,
            actionTitle: String? = nil,
            action: (() -> Void)? = nil
        ) {
            self.title = title
            self.message = message
            self.severity = severity
            self.timestamp = Date()
            self.actionTitle = actionTitle
            self.action = action
        }
    }

    // MARK: - Public Methods

    /// Show error to user
    func show(
        title: String,
        message: String,
        severity: DisplayableError.Severity = .error,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        let error = DisplayableError(
            title: title,
            message: message,
            severity: severity,
            actionTitle: actionTitle,
            action: action
        )

        currentError = error
        errorHistory.insert(error, at: 0)

        // Limit history size
        if errorHistory.count > maxHistorySize {
            errorHistory.removeLast()
        }

        // Also print to console for debugging
        let severityIcon = iconFor(severity: severity)
        print("\(severityIcon) [\(title)] \(message)")
    }

    /// Dismiss current error
    func dismiss() {
        currentError = nil
    }

    /// Clear all error history
    func clearHistory() {
        errorHistory.removeAll()
    }

    // MARK: - Convenience Methods

    func showInfo(_ title: String, message: String) {
        show(title: title, message: message, severity: .info)
    }

    func showWarning(_ title: String, message: String) {
        show(title: title, message: message, severity: .warning)
    }

    func showError(_ title: String, message: String) {
        show(title: title, message: message, severity: .error)
    }

    func showCritical(_ title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        show(title: title, message: message, severity: .critical, actionTitle: actionTitle, action: action)
    }

    // MARK: - Private Helpers

    private func iconFor(severity: DisplayableError.Severity) -> String {
        switch severity {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    private init() {}
}

// MARK: - SwiftUI View Modifier

extension View {
    /// Attach error display to view hierarchy
    func errorDisplay() -> some View {
        modifier(ErrorDisplayModifier())
    }
}

struct ErrorDisplayModifier: ViewModifier {
    @StateObject private var errorManager = ErrorDisplayManager.shared

    func body(content: Content) -> some View {
        content
            .alert(
                errorManager.currentError?.title ?? "Error",
                isPresented: Binding(
                    get: { errorManager.currentError != nil },
                    set: { if !$0 { errorManager.dismiss() } }
                )
            ) {
                if let error = errorManager.currentError {
                    Button("OK") {
                        errorManager.dismiss()
                    }

                    if let actionTitle = error.actionTitle, let action = error.action {
                        Button(actionTitle) {
                            action()
                            errorManager.dismiss()
                        }
                    }
                }
            } message: {
                if let error = errorManager.currentError {
                    Text(error.message)
                }
            }
    }
}

// MARK: - Error History View

struct ErrorHistoryView: View {
    @StateObject private var errorManager = ErrorDisplayManager.shared

    var body: some View {
        List {
            if errorManager.errorHistory.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.green.opacity(0.5))
                    Text("No Errors")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("All systems operating normally")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(errorManager.errorHistory) { error in
                    ErrorHistoryRow(error: error)
                }
            }
        }
        .navigationTitle("Error History")
        .toolbar {
            if !errorManager.errorHistory.isEmpty {
                Button("Clear") {
                    errorManager.clearHistory()
                }
            }
        }
    }
}

struct ErrorHistoryRow: View {
    let error: ErrorDisplayManager.DisplayableError

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Severity indicator
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)

                Text(error.title)
                    .font(.headline)

                Spacer()

                Text(relativeTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var severityIcon: String {
        switch error.severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var severityColor: Color {
        switch error.severity {
        case .info: return .blue
        case .warning: return .yellow
        case .error: return .orange
        case .critical: return .red
        }
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: error.timestamp, relativeTo: Date())
    }
}

#if DEBUG
struct ErrorDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Button("Show Info") {
                ErrorDisplayManager.shared.showInfo("Settings Saved", message: "Your preferences have been saved successfully")
            }

            Button("Show Warning") {
                ErrorDisplayManager.shared.showWarning("Low Storage", message: "You have less than 1GB of storage remaining")
            }

            Button("Show Error") {
                ErrorDisplayManager.shared.showError("Export Failed", message: "Could not export project: Insufficient disk space")
            }

            Button("Show Critical") {
                ErrorDisplayManager.shared.showCritical(
                    "Audio Engine Stopped",
                    message: "The audio engine has stopped unexpectedly. Restart required.",
                    actionTitle: "Restart",
                    action: {
                        print("Restarting audio engine...")
                    }
                )
            }

            NavigationLink("Error History") {
                ErrorHistoryView()
            }
        }
        .errorDisplay()
    }
}
#endif

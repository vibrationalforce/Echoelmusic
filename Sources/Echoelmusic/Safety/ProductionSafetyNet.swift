// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// Production Safety Net - Prevent Destructive Operations
// Inspired by: claude-code-safety-net - Adapted for bio-reactive content safety

import Foundation
import SwiftUI
import Combine

// MARK: - Production Safety Net
/// Safety layer that prevents destructive operations on bio-data, content, and system
/// Operates at application level with semantic analysis of operations
@MainActor
public final class ProductionSafetyNet: ObservableObject {

    public static let shared = ProductionSafetyNet()

    // MARK: - State

    @Published public var blockedOperations: [BlockedOperation] = []
    @Published public var safetyRules: [SafetyRule] = []
    @Published public var isActive: Bool = true
    @Published public var safetyLevel: SafetyLevel = .standard

    // MARK: - Safety Level

    public enum SafetyLevel: String, CaseIterable {
        case minimal = "Minimal"        // Only critical protections
        case standard = "Standard"      // Recommended for most users
        case strict = "Strict"          // Maximum protection
        case custom = "Custom"          // User-defined rules

        public var description: String {
            switch self {
            case .minimal: return "Protects only against data loss"
            case .standard: return "Balanced protection for daily use"
            case .strict: return "Maximum safety for production environments"
            case .custom: return "Custom rules defined by user"
            }
        }
    }

    // MARK: - Safety Rule

    public struct SafetyRule: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var description: String
        public var category: Category
        public var pattern: String         // Pattern to match
        public var action: Action
        public var isEnabled: Bool
        public var priority: Int           // Higher = checked first

        public enum Category: String, Codable, CaseIterable {
            case bioData = "Bio-Data"
            case content = "Content"
            case session = "Session"
            case export = "Export"
            case system = "System"
            case financial = "Financial"
        }

        public enum Action: String, Codable {
            case block = "Block"           // Completely prevent
            case warn = "Warn"             // Show warning, allow proceed
            case confirm = "Confirm"       // Require explicit confirmation
            case log = "Log"               // Allow but log
        }
    }

    // MARK: - Blocked Operation

    public struct BlockedOperation: Identifiable {
        public let id: UUID
        public let timestamp: Date
        public let operation: String
        public let reason: String
        public let rule: SafetyRule
        public let context: [String: String]
    }

    // MARK: - Default Rules

    public static let defaultRules: [SafetyRule] = [
        // Bio-Data Protection
        SafetyRule(
            id: UUID(),
            name: "Prevent Bio-Data Deletion",
            description: "Block deletion of user's biometric data without explicit consent",
            category: .bioData,
            pattern: "delete.*bio|remove.*health|clear.*hrv",
            action: .block,
            isEnabled: true,
            priority: 100
        ),
        SafetyRule(
            id: UUID(),
            name: "Bio-Data Export Confirmation",
            description: "Require confirmation before exporting bio-data",
            category: .bioData,
            pattern: "export.*bio|share.*health|send.*hrv",
            action: .confirm,
            isEnabled: true,
            priority: 90
        ),
        SafetyRule(
            id: UUID(),
            name: "Protect Bio-Signatures",
            description: "Prevent modification of verified bio-signatures",
            category: .bioData,
            pattern: "modify.*signature|edit.*bio.*sign",
            action: .block,
            isEnabled: true,
            priority: 95
        ),

        // Content Protection
        SafetyRule(
            id: UUID(),
            name: "Prevent Mass Content Deletion",
            description: "Block bulk deletion of user content",
            category: .content,
            pattern: "delete.*all|remove.*everything|clear.*projects",
            action: .block,
            isEnabled: true,
            priority: 100
        ),
        SafetyRule(
            id: UUID(),
            name: "Confirm Permanent Delete",
            description: "Require confirmation for permanent content deletion",
            category: .content,
            pattern: "permanent.*delete|bypass.*trash",
            action: .confirm,
            isEnabled: true,
            priority: 85
        ),
        SafetyRule(
            id: UUID(),
            name: "Protect Published Content",
            description: "Warn before modifying already-published content",
            category: .content,
            pattern: "edit.*published|modify.*live",
            action: .warn,
            isEnabled: true,
            priority: 70
        ),

        // Session Protection
        SafetyRule(
            id: UUID(),
            name: "Prevent Session Corruption",
            description: "Block operations that could corrupt active sessions",
            category: .session,
            pattern: "force.*terminate|kill.*session|corrupt",
            action: .block,
            isEnabled: true,
            priority: 100
        ),
        SafetyRule(
            id: UUID(),
            name: "Live Stream Safety",
            description: "Confirm before ending live streams",
            category: .session,
            pattern: "end.*stream|stop.*live|terminate.*broadcast",
            action: .confirm,
            isEnabled: true,
            priority: 80
        ),

        // Export Protection
        SafetyRule(
            id: UUID(),
            name: "Confirm Public Export",
            description: "Require confirmation for public exports",
            category: .export,
            pattern: "export.*public|publish.*all|broadcast",
            action: .confirm,
            isEnabled: true,
            priority: 75
        ),

        // System Protection
        SafetyRule(
            id: UUID(),
            name: "Protect System Settings",
            description: "Block unauthorized system setting changes",
            category: .system,
            pattern: "reset.*factory|clear.*settings|delete.*config",
            action: .block,
            isEnabled: true,
            priority: 100
        ),

        // Financial Protection
        SafetyRule(
            id: UUID(),
            name: "Confirm Purchase",
            description: "Require confirmation for any purchase",
            category: .financial,
            pattern: "purchase|buy|subscribe|upgrade.*paid",
            action: .confirm,
            isEnabled: true,
            priority: 100
        )
    ]

    // MARK: - Initialization

    private init() {
        loadRules()
    }

    private func loadRules() {
        // Load custom rules from storage, fall back to defaults
        safetyRules = Self.defaultRules
    }

    // MARK: - Operation Checking

    /// Check if an operation is safe to execute
    public func checkOperation(_ operation: String, context: [String: String] = [:]) -> SafetyCheckResult {
        guard isActive else {
            return .allowed
        }

        // Sort rules by priority
        let activeRules = safetyRules
            .filter { $0.isEnabled }
            .sorted { $0.priority > $1.priority }

        for rule in activeRules {
            if matchesPattern(operation, pattern: rule.pattern) {
                switch rule.action {
                case .block:
                    let blocked = BlockedOperation(
                        id: UUID(),
                        timestamp: Date(),
                        operation: operation,
                        reason: rule.description,
                        rule: rule,
                        context: context
                    )
                    blockedOperations.append(blocked)
                    return .blocked(rule: rule, reason: rule.description)

                case .warn:
                    return .warning(rule: rule, message: rule.description)

                case .confirm:
                    return .requiresConfirmation(rule: rule, message: rule.description)

                case .log:
                    logOperation(operation, rule: rule, context: context)
                    return .allowed
                }
            }
        }

        return .allowed
    }

    /// Execute operation with safety check
    public func executeWithSafety<T>(
        operation: String,
        context: [String: String] = [:],
        action: () async throws -> T
    ) async throws -> T {
        let result = checkOperation(operation, context: context)

        switch result {
        case .allowed:
            return try await action()

        case .blocked(let rule, let reason):
            throw SafetyError.operationBlocked(rule: rule.name, reason: reason)

        case .warning(_, let message):
            // Log warning but proceed
            print("⚠️ Safety Warning: \(message)")
            return try await action()

        case .requiresConfirmation(let rule, let message):
            throw SafetyError.confirmationRequired(rule: rule.name, message: message)
        }
    }

    // MARK: - Pattern Matching

    private func matchesPattern(_ operation: String, pattern: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(operation.startIndex..., in: operation)
        return regex?.firstMatch(in: operation, options: [], range: range) != nil
    }

    // MARK: - Logging

    private func logOperation(_ operation: String, rule: SafetyRule, context: [String: String]) {
        // In production: Send to analytics/audit log
        print("📝 Safety Log: \(operation) matched rule '\(rule.name)'")
    }

    // MARK: - Rule Management

    public func addRule(_ rule: SafetyRule) {
        safetyRules.append(rule)
        saveRules()
    }

    public func removeRule(id: UUID) {
        safetyRules.removeAll { $0.id == id }
        saveRules()
    }

    public func toggleRule(id: UUID) {
        if let index = safetyRules.firstIndex(where: { $0.id == id }) {
            safetyRules[index].isEnabled.toggle()
            saveRules()
        }
    }

    private func saveRules() {
        // Persist to storage
    }

    // MARK: - Result Types

    public enum SafetyCheckResult {
        case allowed
        case blocked(rule: SafetyRule, reason: String)
        case warning(rule: SafetyRule, message: String)
        case requiresConfirmation(rule: SafetyRule, message: String)
    }

    public enum SafetyError: LocalizedError {
        case operationBlocked(rule: String, reason: String)
        case confirmationRequired(rule: String, message: String)

        public var errorDescription: String? {
            switch self {
            case .operationBlocked(let rule, let reason):
                return "Operation blocked by '\(rule)': \(reason)"
            case .confirmationRequired(let rule, let message):
                return "Confirmation required for '\(rule)': \(message)"
            }
        }
    }
}

// MARK: - Safety Net View

public struct ProductionSafetyNetView: View {
    @ObservedObject private var safetyNet = ProductionSafetyNet.shared
    @State private var showAddRule = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Status Section
                Section {
                    Toggle("Safety Net Active", isOn: $safetyNet.isActive)

                    Picker("Safety Level", selection: $safetyNet.safetyLevel) {
                        ForEach(ProductionSafetyNet.SafetyLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }

                    Text(safetyNet.safetyLevel.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Rules by Category
                ForEach(ProductionSafetyNet.SafetyRule.Category.allCases, id: \.self) { category in
                    let categoryRules = safetyNet.safetyRules.filter { $0.category == category }
                    if !categoryRules.isEmpty {
                        Section(category.rawValue) {
                            ForEach(categoryRules) { rule in
                                ruleRow(rule)
                            }
                        }
                    }
                }

                // Blocked Operations
                if !safetyNet.blockedOperations.isEmpty {
                    Section("Recent Blocked Operations") {
                        ForEach(safetyNet.blockedOperations.suffix(5)) { blocked in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(blocked.operation)
                                    .font(.subheadline)
                                Text(blocked.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(blocked.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Safety Net")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddRule = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func ruleRow(_ rule: ProductionSafetyNet.SafetyRule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: actionIcon(rule.action))
                        .foregroundStyle(actionColor(rule.action))
                    Text(rule.name)
                        .font(.subheadline)
                }
                Text(rule.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in safetyNet.toggleRule(id: rule.id) }
            ))
            .labelsHidden()
        }
    }

    private func actionIcon(_ action: ProductionSafetyNet.SafetyRule.Action) -> String {
        switch action {
        case .block: return "xmark.shield.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .confirm: return "checkmark.shield.fill"
        case .log: return "doc.text.fill"
        }
    }

    private func actionColor(_ action: ProductionSafetyNet.SafetyRule.Action) -> Color {
        switch action {
        case .block: return .red
        case .warn: return .orange
        case .confirm: return .blue
        case .log: return .gray
        }
    }
}

#Preview {
    ProductionSafetyNetView()
}

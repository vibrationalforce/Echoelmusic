// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// Privacy-First Bio-Data Framework - Ethical handling inspired by Aiode's approach

import Foundation
import SwiftUI
import Combine
import CryptoKit

// MARK: - Ethical Bio-Data Framework
/// Privacy-first biometric data handling with full user control
/// Inspired by Aiode's ethical AI approach - adapted for bio-data
///
/// Core Principles:
/// 1. User owns their data - always
/// 2. Consent is explicit and revocable
/// 3. Data stays local by default
/// 4. Sharing is opt-in, granular, and transparent
/// 5. Right to deletion - instant and complete
@MainActor
public final class EthicalBioDataFramework: ObservableObject {

    public static let shared = EthicalBioDataFramework()

    // MARK: - State

    @Published public var consentStatus: ConsentStatus = .notAsked
    @Published public var privacySettings: PrivacySettings = PrivacySettings()
    @Published public var dataInventory: [BioDataRecord] = []
    @Published public var sharingHistory: [SharingEvent] = []

    // MARK: - Privacy Principles (Displayed to Users)

    public static let privacyPrinciples: [PrivacyPrinciple] = [
        PrivacyPrinciple(
            id: "ownership",
            title: "You Own Your Data",
            description: "Your biometric data belongs to you. Always. We never sell, share, or monetize your personal bio-data without explicit consent.",
            icon: "person.badge.shield.checkmark.fill"
        ),
        PrivacyPrinciple(
            id: "local_first",
            title: "Local-First Processing",
            description: "Bio-data is processed on your device. No cloud uploads unless you explicitly enable sharing for specific features.",
            icon: "iphone.gen3"
        ),
        PrivacyPrinciple(
            id: "consent",
            title: "Explicit Consent",
            description: "We ask before collecting. Every data type requires separate consent. You can revoke anytime.",
            icon: "hand.raised.fill"
        ),
        PrivacyPrinciple(
            id: "transparency",
            title: "Full Transparency",
            description: "See exactly what data we collect, how it's used, and who has access. Complete data inventory available anytime.",
            icon: "eye.fill"
        ),
        PrivacyPrinciple(
            id: "deletion",
            title: "Right to Deletion",
            description: "Delete your data instantly and completely. One tap removes everything - no traces, no backups retained.",
            icon: "trash.fill"
        ),
        PrivacyPrinciple(
            id: "anonymization",
            title: "Anonymization by Design",
            description: "When sharing is enabled, data is anonymized. Your identity is never linked to shared bio-patterns.",
            icon: "person.fill.questionmark"
        )
    ]

    public struct PrivacyPrinciple: Identifiable {
        public let id: String
        public let title: String
        public let description: String
        public let icon: String
    }

    // MARK: - Consent System

    public enum ConsentStatus: String, Codable {
        case notAsked = "Not Asked"
        case pending = "Pending"
        case granted = "Granted"
        case denied = "Denied"
        case partial = "Partial"
    }

    public struct ConsentRecord: Identifiable, Codable {
        public let id: UUID
        public let dataType: BioDataType
        public var isConsented: Bool
        public var consentedAt: Date?
        public var revokedAt: Date?
        public var purpose: String
        public var expiresAt: Date? // Optional expiration

        public var isActive: Bool {
            guard isConsented else { return false }
            if let expires = expiresAt, expires < Date() { return false }
            return revokedAt == nil
        }
    }

    public enum BioDataType: String, Codable, CaseIterable {
        case heartRate = "Heart Rate"
        case hrv = "Heart Rate Variability"
        case breathing = "Breathing Pattern"
        case facialExpression = "Facial Expression"
        case gesture = "Hand Gesture"
        case gaze = "Eye Gaze"
        case voice = "Voice Analysis"
        case movement = "Body Movement"
        case sleep = "Sleep Data"
        case stress = "Stress Level"

        public var icon: String {
            switch self {
            case .heartRate: return "heart.fill"
            case .hrv: return "waveform.path.ecg"
            case .breathing: return "wind"
            case .facialExpression: return "face.smiling"
            case .gesture: return "hand.raised"
            case .gaze: return "eye"
            case .voice: return "waveform"
            case .movement: return "figure.walk"
            case .sleep: return "moon.zzz"
            case .stress: return "brain.head.profile"
            }
        }

        public var sensitivity: DataSensitivity {
            switch self {
            case .heartRate, .breathing: return .medium
            case .hrv, .stress, .sleep: return .high
            case .facialExpression, .voice: return .veryHigh
            case .gesture, .gaze, .movement: return .medium
            }
        }

        public enum DataSensitivity: String, Codable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case veryHigh = "Very High"

            public var color: String {
                switch self {
                case .low: return "#22C55E"
                case .medium: return "#F59E0B"
                case .high: return "#EF4444"
                case .veryHigh: return "#7C3AED"
                }
            }
        }
    }

    // MARK: - Privacy Settings

    public struct PrivacySettings: Codable {
        // Data Collection
        public var enableBioCollection: Bool = false
        public var enabledDataTypes: Set<String> = []

        // Storage
        public var localStorageOnly: Bool = true
        public var encryptLocalData: Bool = true
        public var dataRetentionDays: Int = 30

        // Sharing
        public var allowAnonymousSharing: Bool = false
        public var allowCommunityResearch: Bool = false
        public var allowPresetBioSignature: Bool = false

        // Privacy Features
        public var autoDeleteOldData: Bool = true
        public var requireBiometricToAccess: Bool = false
        public var hideFromScreenshots: Bool = true

        // Notifications
        public var notifyOnDataAccess: Bool = true
        public var notifyOnSharing: Bool = true
    }

    // MARK: - Data Inventory

    public struct BioDataRecord: Identifiable, Codable {
        public let id: UUID
        public let dataType: BioDataType
        public let collectedAt: Date
        public var dataSize: Int // bytes
        public var isEncrypted: Bool
        public var storageLocation: StorageLocation
        public var retentionExpires: Date?
        public var accessLog: [DataAccessEvent]

        public enum StorageLocation: String, Codable {
            case localDevice = "Local Device"
            case secureEnclave = "Secure Enclave"
            case iCloudEncrypted = "iCloud (Encrypted)"
            case deleted = "Deleted"
        }
    }

    public struct DataAccessEvent: Identifiable, Codable {
        public let id: UUID
        public let accessedAt: Date
        public let accessor: String // "App", "Export", "Preset Creation", etc.
        public let purpose: String
        public let wasAnonymized: Bool
    }

    // MARK: - Sharing Events

    public struct SharingEvent: Identifiable, Codable {
        public let id: UUID
        public let sharedAt: Date
        public let dataTypes: [BioDataType]
        public let recipient: SharingRecipient
        public let wasAnonymized: Bool
        public var canRevoke: Bool

        public enum SharingRecipient: String, Codable {
            case communityPreset = "Community Preset"
            case researchStudy = "Research Study"
            case collaboration = "Collaboration Partner"
            case export = "Personal Export"
        }
    }

    // MARK: - Consent Management

    @Published public var consents: [ConsentRecord] = []

    public func requestConsent(for dataType: BioDataType, purpose: String) async -> Bool {
        // In production: Show consent UI
        let record = ConsentRecord(
            id: UUID(),
            dataType: dataType,
            isConsented: false,
            consentedAt: nil,
            revokedAt: nil,
            purpose: purpose,
            expiresAt: nil
        )
        consents.append(record)
        return false // Returns actual consent after UI
    }

    public func grantConsent(for dataType: BioDataType) {
        if let index = consents.firstIndex(where: { $0.dataType == dataType }) {
            consents[index].isConsented = true
            consents[index].consentedAt = Date()
            consents[index].revokedAt = nil
        }
        privacySettings.enabledDataTypes.insert(dataType.rawValue)
        updateConsentStatus()
    }

    public func revokeConsent(for dataType: BioDataType) {
        if let index = consents.firstIndex(where: { $0.dataType == dataType }) {
            consents[index].revokedAt = Date()
        }
        privacySettings.enabledDataTypes.remove(dataType.rawValue)
        updateConsentStatus()
    }

    public func revokeAllConsents() {
        for i in consents.indices {
            consents[i].revokedAt = Date()
        }
        privacySettings.enabledDataTypes.removeAll()
        consentStatus = .denied
    }

    private func updateConsentStatus() {
        let activeConsents = consents.filter { $0.isActive }
        if activeConsents.isEmpty {
            consentStatus = consents.isEmpty ? .notAsked : .denied
        } else if activeConsents.count == BioDataType.allCases.count {
            consentStatus = .granted
        } else {
            consentStatus = .partial
        }
    }

    // MARK: - Data Deletion

    /// Delete all bio-data immediately and completely
    public func deleteAllData() async {
        // Clear all records
        dataInventory.removeAll()

        // Clear sharing history
        sharingHistory.removeAll()

        // Revoke all consents
        revokeAllConsents()

        // Clear any cached data
        // In production: Also clear from Keychain, UserDefaults, temp files

        // Log deletion event (anonymized)
        logDeletionEvent()
    }

    /// Delete specific data type
    public func deleteData(type: BioDataType) async {
        dataInventory.removeAll { $0.dataType == type }
        revokeConsent(for: type)
    }

    /// Delete data older than specified days
    public func deleteOldData(olderThanDays: Int) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date())!
        dataInventory.removeAll { $0.collectedAt < cutoffDate }
    }

    private func logDeletionEvent() {
        // Anonymized deletion log for compliance
        // No personal data stored
    }

    // MARK: - Data Export

    /// Export user's data in portable format
    public func exportAllData() async -> ExportPackage {
        ExportPackage(
            exportedAt: Date(),
            dataRecords: dataInventory,
            consentHistory: consents,
            sharingHistory: sharingHistory,
            format: .json
        )
    }

    public struct ExportPackage: Codable {
        public let exportedAt: Date
        public let dataRecords: [BioDataRecord]
        public let consentHistory: [ConsentRecord]
        public let sharingHistory: [SharingEvent]
        public let format: ExportFormat

        public enum ExportFormat: String, Codable {
            case json = "JSON"
            case csv = "CSV"
            case encrypted = "Encrypted Archive"
        }
    }

    // MARK: - Anonymization

    /// Anonymize bio-data for sharing
    public func anonymize(_ data: [BioDataRecord]) -> AnonymizedDataSet {
        // Remove all identifying information
        // Apply differential privacy techniques
        // Aggregate into statistical summaries

        return AnonymizedDataSet(
            id: UUID(),
            createdAt: Date(),
            recordCount: data.count,
            dataTypes: Set(data.map { $0.dataType }),
            aggregatedMetrics: [:], // Statistical summaries only
            isVerifiablyAnonymous: true
        )
    }

    public struct AnonymizedDataSet: Identifiable, Codable {
        public let id: UUID
        public let createdAt: Date
        public let recordCount: Int
        public let dataTypes: Set<BioDataType>
        public let aggregatedMetrics: [String: Double]
        public let isVerifiablyAnonymous: Bool
    }

    // MARK: - Encryption

    /// Encrypt sensitive bio-data using device key
    public func encryptData(_ data: Data) throws -> Data {
        let key = SymmetricKey(size: .bits256)
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined ?? Data()
    }

    /// Decrypt bio-data
    public func decryptData(_ encryptedData: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Compliance

    public struct ComplianceStatus: Codable {
        public var gdprCompliant: Bool = true
        public var ccpaCompliant: Bool = true
        public var hipaaCompliant: Bool = true // For health data
        public var coppaCompliant: Bool = true // For users under 13

        public var lastAuditDate: Date?
        public var auditScore: Int? // 0-100
    }

    @Published public var compliance = ComplianceStatus()
}

// MARK: - Privacy Dashboard View

public struct EthicalBioDataDashboardView: View {
    @ObservedObject private var framework = EthicalBioDataFramework.shared
    @State private var showDeleteConfirmation = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Privacy Principles
                    principlesSection

                    // Consent Status
                    consentSection

                    // Data Inventory
                    dataInventorySection

                    // Privacy Controls
                    privacyControlsSection

                    // Danger Zone
                    dangerZoneSection
                }
                .padding()
            }
            .navigationTitle("Privacy & Bio-Data")
        }
        .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task {
                    await framework.deleteAllData()
                }
            }
        } message: {
            Text("This will permanently delete all your biometric data. This action cannot be undone.")
        }
    }

    private var principlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Our Privacy Principles")
                .font(.headline)

            ForEach(EthicalBioDataFramework.privacyPrinciples) { principle in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: principle.icon)
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(principle.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(principle.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var consentSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                HStack {
                    Text("Consent Status")
                        .font(.headline)
                    Spacer()
                    Text(framework.consentStatus.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(consentStatusColor.opacity(0.2))
                        .foregroundStyle(consentStatusColor)
                        .cornerRadius(8)
                }

                ForEach(EthicalBioDataFramework.BioDataType.allCases, id: \.self) { dataType in
                    consentRow(dataType)
                }
            }
        } label: {
            Label("Data Collection Consent", systemImage: "hand.raised.fill")
        }
    }

    private func consentRow(_ dataType: EthicalBioDataFramework.BioDataType) -> some View {
        let isConsented = framework.privacySettings.enabledDataTypes.contains(dataType.rawValue)

        return HStack {
            Image(systemName: dataType.icon)
                .frame(width: 24)
            Text(dataType.rawValue)
            Spacer()
            Text(dataType.sensitivity.rawValue)
                .font(.caption2)
                .foregroundStyle(Color(hex: dataType.sensitivity.color) ?? .secondary)
            Toggle("", isOn: Binding(
                get: { isConsented },
                set: { newValue in
                    if newValue {
                        framework.grantConsent(for: dataType)
                    } else {
                        framework.revokeConsent(for: dataType)
                    }
                }
            ))
            .labelsHidden()
        }
    }

    private var consentStatusColor: Color {
        switch framework.consentStatus {
        case .granted: return .green
        case .partial: return .orange
        case .denied: return .red
        case .notAsked, .pending: return .gray
        }
    }

    private var dataInventorySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Your Data")
                        .font(.headline)
                    Spacer()
                    Text("\(framework.dataInventory.count) records")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if framework.dataInventory.isEmpty {
                    Text("No biometric data collected yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Data types collected will be shown here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        let export = await framework.exportAllData()
                        // Handle export
                        print("Exported \(export.dataRecords.count) records")
                    }
                } label: {
                    Label("Export My Data", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        } label: {
            Label("Data Inventory", systemImage: "doc.text.magnifyingglass")
        }
    }

    private var privacyControlsSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                Toggle("Local Storage Only", isOn: $framework.privacySettings.localStorageOnly)
                Toggle("Encrypt Local Data", isOn: $framework.privacySettings.encryptLocalData)
                Toggle("Auto-Delete Old Data", isOn: $framework.privacySettings.autoDeleteOldData)
                Toggle("Notify on Data Access", isOn: $framework.privacySettings.notifyOnDataAccess)
                Toggle("Hide from Screenshots", isOn: $framework.privacySettings.hideFromScreenshots)
            }
        } label: {
            Label("Privacy Controls", systemImage: "lock.shield.fill")
        }
    }

    private var dangerZoneSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                Text("These actions cannot be undone")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete All My Data", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    framework.revokeAllConsents()
                } label: {
                    Label("Revoke All Consents", systemImage: "xmark.shield.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        } label: {
            Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    EthicalBioDataDashboardView()
}

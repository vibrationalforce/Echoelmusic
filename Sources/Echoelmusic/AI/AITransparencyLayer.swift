//
//  AITransparencyLayer.swift
//  Echoelmusic
//
//  AI Transparency & Consent Layer - A+ Ethical Standards
//  Provides clear disclosure of AI-powered features
//
//  Created: 2026-01-27
//

import SwiftUI
import Combine

// MARK: - AI Feature Categories

/// Categories of AI features for transparency disclosure
public enum AIFeatureCategory: String, CaseIterable, Identifiable {
    case faceTracking = "Face Tracking"
    case gestureRecognition = "Gesture Recognition"
    case voiceAnalysis = "Voice Analysis"
    case musicGeneration = "Music Generation"
    case visualGeneration = "Visual Generation"
    case biometricAnalysis = "Biometric Analysis"
    case sceneDirection = "AI Scene Direction"
    case soundDesign = "AI Sound Design"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .faceTracking: return "face.smiling"
        case .gestureRecognition: return "hand.raised"
        case .voiceAnalysis: return "waveform"
        case .musicGeneration: return "music.note"
        case .visualGeneration: return "paintpalette"
        case .biometricAnalysis: return "heart.fill"
        case .sceneDirection: return "film"
        case .soundDesign: return "speaker.wave.3"
        }
    }

    var description: String {
        switch self {
        case .faceTracking:
            return "Detects facial expressions to modulate audio-visual parameters. All processing is on-device."
        case .gestureRecognition:
            return "Recognizes hand gestures to control audio and visual effects. Processed locally."
        case .voiceAnalysis:
            return "Analyzes voice input for pitch, timbre, and emotion. Never recorded or transmitted."
        case .musicGeneration:
            return "Generates musical elements using ML models based on your bio-data and preferences."
        case .visualGeneration:
            return "Creates visual elements and animations using AI algorithms."
        case .biometricAnalysis:
            return "Processes heart rate and HRV data locally to create coherence scores. This is art, not medical analysis."
        case .sceneDirection:
            return "Automatically selects camera angles and transitions during live performances."
        case .soundDesign:
            return "Designs sounds using neural networks based on your input parameters."
        }
    }

    var privacyNote: String {
        switch self {
        case .faceTracking, .gestureRecognition:
            return "Camera data is processed on-device and never stored or transmitted."
        case .voiceAnalysis:
            return "Voice data is processed in real-time on-device and immediately discarded."
        case .musicGeneration, .visualGeneration, .soundDesign:
            return "ML models run locally. Your creations are yours alone."
        case .biometricAnalysis:
            return "Health data stays on your device via HealthKit. This is not medical advice."
        case .sceneDirection:
            return "AI decisions are based on audio/bio analysis, not personal identification."
        }
    }

    var dataProcessing: DataProcessingType {
        switch self {
        case .faceTracking, .gestureRecognition, .voiceAnalysis:
            return .realTimeOnDevice
        case .musicGeneration, .visualGeneration, .soundDesign, .biometricAnalysis, .sceneDirection:
            return .onDeviceML
        }
    }

    enum DataProcessingType: String {
        case realTimeOnDevice = "Real-time, On-device"
        case onDeviceML = "On-device ML Model"
        case cloudProcessing = "Cloud Processing"

        var icon: String {
            switch self {
            case .realTimeOnDevice: return "bolt.fill"
            case .onDeviceML: return "cpu"
            case .cloudProcessing: return "cloud"
            }
        }
    }
}

// MARK: - AI Transparency Manager

/// Manages AI feature disclosure and consent
@MainActor
public class AITransparencyManager: ObservableObject {

    public static let shared = AITransparencyManager()

    // MARK: - Published State

    @Published public var enabledFeatures: Set<AIFeatureCategory> = []
    @Published public var hasShownDisclosure: Bool = false
    @Published public var showingDisclosure: Bool = false
    @Published public var activeAIFeatures: Set<AIFeatureCategory> = []

    // MARK: - Consent Storage

    private let consentKey = "echoelmusic_ai_consent"
    private let disclosureShownKey = "echoelmusic_ai_disclosure_shown"

    // MARK: - Initialization

    private init() {
        loadConsent()
    }

    private func loadConsent() {
        if let data = UserDefaults.standard.data(forKey: consentKey),
           let features = try? JSONDecoder().decode([String].self, from: data) {
            enabledFeatures = Set(features.compactMap { AIFeatureCategory(rawValue: $0) })
        } else {
            // Default: all on-device features enabled by default
            enabledFeatures = Set(AIFeatureCategory.allCases.filter {
                $0.dataProcessing != .cloudProcessing
            })
        }
        hasShownDisclosure = UserDefaults.standard.bool(forKey: disclosureShownKey)
    }

    private func saveConsent() {
        let features = enabledFeatures.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(features) {
            UserDefaults.standard.set(data, forKey: consentKey)
        }
        UserDefaults.standard.set(true, forKey: disclosureShownKey)
    }

    // MARK: - Feature Control

    /// Check if an AI feature is enabled
    public func isEnabled(_ feature: AIFeatureCategory) -> Bool {
        enabledFeatures.contains(feature)
    }

    /// Enable or disable an AI feature
    public func setEnabled(_ feature: AIFeatureCategory, enabled: Bool) {
        if enabled {
            enabledFeatures.insert(feature)
        } else {
            enabledFeatures.remove(feature)
        }
        saveConsent()
        log.info("AI feature \(feature.rawValue): \(enabled ? "enabled" : "disabled")", category: .ai)
    }

    /// Mark an AI feature as currently active
    public func markActive(_ feature: AIFeatureCategory) {
        guard isEnabled(feature) else { return }
        activeAIFeatures.insert(feature)
    }

    /// Mark an AI feature as inactive
    public func markInactive(_ feature: AIFeatureCategory) {
        activeAIFeatures.remove(feature)
    }

    /// Show AI disclosure sheet
    public func showDisclosure() {
        showingDisclosure = true
    }

    /// Dismiss disclosure and mark as shown
    public func dismissDisclosure() {
        showingDisclosure = false
        hasShownDisclosure = true
        saveConsent()
    }

    /// Enable all on-device features
    public func enableAllOnDevice() {
        enabledFeatures = Set(AIFeatureCategory.allCases.filter {
            $0.dataProcessing != .cloudProcessing
        })
        saveConsent()
    }

    /// Disable all AI features
    public func disableAll() {
        enabledFeatures.removeAll()
        saveConsent()
    }
}

// MARK: - AI Disclosure View

/// View showing AI feature disclosure and consent options
public struct AIDisclosureView: View {
    @ObservedObject var manager = AITransparencyManager.shared
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric private var iconSize: CGFloat = 50

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "brain")
                            .font(.system(size: iconSize))
                            .foregroundColor(.purple)
                            .accessibilityHidden(true)

                        Text("AI-Powered Features")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityAddTraits(.isHeader)

                        Text("Echoelmusic uses AI to enhance your creative experience. All processing happens on your device.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Privacy Assurance
                    PrivacyAssuranceCard()

                    // Feature List
                    VStack(spacing: 12) {
                        ForEach(AIFeatureCategory.allCases) { feature in
                            AIFeatureRow(
                                feature: feature,
                                isEnabled: manager.enabledFeatures.contains(feature)
                            ) { enabled in
                                manager.setEnabled(feature, enabled: enabled)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Quick Actions
                    HStack(spacing: 16) {
                        Button("Enable All") {
                            withAnimation {
                                manager.enableAllOnDevice()
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Disable All") {
                            withAnimation {
                                manager.disableAll()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }

                    // Continue Button
                    Button(action: {
                        manager.dismissDisclosure()
                        dismiss()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .padding(.vertical)
            }
            .navigationTitle("AI Transparency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        manager.dismissDisclosure()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacyAssuranceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                Text("Privacy First")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                PrivacyPoint(icon: "iphone", text: "All AI processing happens on your device")
                PrivacyPoint(icon: "eye.slash", text: "Camera/voice data is never stored or sent")
                PrivacyPoint(icon: "hand.raised", text: "You control which features are enabled")
                PrivacyPoint(icon: "heart.text.square", text: "Health data stays in HealthKit")
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct PrivacyPoint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.green)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AIFeatureRow: View {
    let feature: AIFeatureCategory
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    @State private var showingDetails = false
    @ScaledMetric private var iconWidth: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: feature.icon)
                    .font(.title2)
                    .foregroundColor(.purple)
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(feature.rawValue)
                        .font(.headline)

                    HStack(spacing: 4) {
                        Image(systemName: feature.dataProcessing.icon)
                            .font(.caption2)
                        Text(feature.dataProcessing.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
                .accessibilityLabel("\(feature.rawValue) toggle")
            }

            if showingDetails {
                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(feature.privacyNote)
                        .font(.caption2)
                        .foregroundColor(.green)
                        .italic()
                }
                .padding(.leading, iconWidth + 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            withAnimation {
                showingDetails.toggle()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Tap to \(showingDetails ? "hide" : "show") details")
    }
}

// MARK: - Active AI Indicator

/// Small indicator showing currently active AI features
public struct ActiveAIIndicator: View {
    @ObservedObject var manager = AITransparencyManager.shared

    public init() {}

    public var body: some View {
        if !manager.activeAIFeatures.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "brain")
                    .font(.caption2)
                Text("AI")
                    .font(.caption2.bold())
                Text("·")
                ForEach(Array(manager.activeAIFeatures.prefix(3)), id: \.self) { feature in
                    Image(systemName: feature.icon)
                        .font(.caption2)
                }
                if manager.activeAIFeatures.count > 3 {
                    Text("+\(manager.activeAIFeatures.count - 3)")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.2))
            .cornerRadius(12)
            .onTapGesture {
                manager.showDisclosure()
            }
            .accessibilityLabel("AI features active: \(manager.activeAIFeatures.map { $0.rawValue }.joined(separator: ", "))")
            .accessibilityHint("Tap to view AI settings")
        }
    }
}

// MARK: - View Modifier for AI Disclosure

public struct AIDisclosureModifier: ViewModifier {
    @ObservedObject var manager = AITransparencyManager.shared

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $manager.showingDisclosure) {
                AIDisclosureView()
            }
            .onAppear {
                // Show disclosure on first use
                if !manager.hasShownDisclosure {
                    manager.showDisclosure()
                }
            }
    }
}

extension View {
    /// Add AI transparency disclosure to a view
    public func withAITransparency() -> some View {
        modifier(AIDisclosureModifier())
    }
}

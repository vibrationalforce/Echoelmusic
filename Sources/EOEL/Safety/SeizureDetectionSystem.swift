//
//  SeizureDetectionSystem.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  ADVANCED SEIZURE DETECTION AND PREVENTION
//  Real-time photosensitive seizure pattern detection
//  Based on: Harding & Jeavons (1994), Fisher et al. (2005)
//

import Foundation
import SwiftUI
import Combine
import CoreMotion

// MARK: - Seizure Detection Manager

/// Advanced seizure detection and prevention system
///
/// **Scientific Basis:**
/// - Harding FPA, Jeavons PM. Photosensitive epilepsy. 1994
/// - Fisher RS et al. Photic- and pattern-induced seizures. Epilepsia 2005
/// - ILAE recommendations for photosensitive epilepsy
///
/// **Detection Methods:**
/// 1. Visual pattern analysis (flash frequency, contrast, area)
/// 2. Accelerometer-based convulsion detection
/// 3. Heart rate spike detection (autonomic seizure signs)
/// 4. EEG pattern recognition (future with external EEG)
@MainActor
class SeizureDetectionManager: ObservableObject {
    static let shared = SeizureDetectionManager()

    // MARK: - Published Properties

    @Published var isMonitoring: Bool = false
    @Published var riskLevel: RiskLevel = .safe
    @Published var lastAlert: Date?

    enum RiskLevel: String {
        case safe = "Safe"
        case elevated = "Elevated Risk"
        case high = "High Risk"
        case critical = "CRITICAL - Seizure Risk"
    }

    // MARK: - Detection Thresholds

    /// ILAE and WCAG 2.3.1 recommendations
    struct SafetyThresholds {
        // Flash frequency (Harding & Jeavons criteria)
        static let maxSafeFlashFrequency: Double = 3.0  // Hz (WCAG 2.3.1)
        static let dangerousFlashRange: ClosedRange<Double> = 15.0...25.0  // Hz (peak sensitivity)

        // Spatial extent
        static let maxSafeFlashArea: Double = 0.006  // steradian (25% of central 10°)

        // Luminance
        static let minDangerousContrast: Double = 0.2  // 20% contrast minimum for risk

        // Pattern stimulation
        static let maxSafeStripeWidth: Double = 0.001  // steradian
        static let maxSafePatternFrequency: Double = 8.0  // cycles per degree

        // Accelerometer (convulsion detection)
        static let convulsionMagnitude: Double = 3.0  // g-force
        static let convulsionDuration: TimeInterval = 0.5  // seconds

        // Heart rate (autonomic seizure signs)
        static let preSeizureHeartRateIncrease: Double = 20.0  // bpm above baseline
    }

    // MARK: - Visual Pattern Analysis

    /// Analyze visual pattern for seizure risk
    func analyzeVisualPattern(
        flashFrequency: Double,
        flashArea: Double,
        contrast: Double,
        duration: TimeInterval
    ) -> PatternAnalysisResult {

        var risks: [String] = []
        var riskScore: Double = 0.0

        // 1. Flash Frequency Analysis
        if flashFrequency > SafetyThresholds.maxSafeFlashFrequency {
            risks.append("Flash frequency (\(String(format: "%.1f", flashFrequency)) Hz) exceeds safe limit (3 Hz)")
            riskScore += 0.3

            // Check if in dangerous range (15-25 Hz)
            if SafetyThresholds.dangerousFlashRange.contains(flashFrequency) {
                risks.append("CRITICAL: Frequency in peak sensitivity range (15-25 Hz)")
                riskScore += 0.5
            }
        }

        // 2. Spatial Extent Analysis
        if flashArea > SafetyThresholds.maxSafeFlashArea {
            risks.append("Flash area (\(String(format: "%.4f", flashArea)) sr) exceeds safe limit (0.006 sr)")
            riskScore += 0.2
        }

        // 3. Contrast Analysis
        if contrast > SafetyThresholds.minDangerousContrast {
            risks.append("High contrast (\(String(format: "%.0f", contrast * 100))%) increases risk")
            riskScore += 0.1
        }

        // 4. Duration Analysis
        if duration > 5.0 && riskScore > 0.3 {
            risks.append("Extended duration (\(String(format: "%.1f", duration))s) with unsafe parameters")
            riskScore += 0.2
        }

        // Determine risk level
        let level: RiskLevel
        if riskScore < 0.3 {
            level = .safe
        } else if riskScore < 0.5 {
            level = .elevated
        } else if riskScore < 0.7 {
            level = .high
        } else {
            level = .critical
        }

        return PatternAnalysisResult(
            riskLevel: level,
            riskScore: riskScore,
            identifiedRisks: risks,
            recommendation: generateRecommendation(level: level, risks: risks)
        )
    }

    struct PatternAnalysisResult {
        let riskLevel: RiskLevel
        let riskScore: Double
        let identifiedRisks: [String]
        let recommendation: String
    }

    private func generateRecommendation(level: RiskLevel, risks: [String]) -> String {
        switch level {
        case .safe:
            return "✅ Pattern is safe for general use"
        case .elevated:
            return "⚠️ Elevated risk. Consider reducing flash frequency or area."
        case .high:
            return "🚨 High risk detected. Automatic safety limits will be enforced."
        case .critical:
            return "🚨 CRITICAL RISK - Effect will be blocked to prevent seizure"
        }
    }

    // MARK: - Motion-Based Seizure Detection

    private let motionManager = CMMotionManager()
    private var accelerometerData: [CMAccelerometerData] = []
    private let accelerometerBufferSize = 100  // ~2 seconds at 50 Hz

    /// Start accelerometer monitoring for convulsion detection
    func startMotionMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            print("⚠️ Accelerometer not available")
            return
        }

        motionManager.accelerometerUpdateInterval = 0.02  // 50 Hz
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }

            self.accelerometerData.append(data)

            // Keep buffer size limited
            if self.accelerometerData.count > self.accelerometerBufferSize {
                self.accelerometerData.removeFirst()
            }

            // Analyze for convulsive patterns
            self.analyzeAccelerometerData()
        }

        isMonitoring = true
        print("🔍 Motion monitoring started (50 Hz)")
    }

    func stopMotionMonitoring() {
        motionManager.stopAccelerometerUpdates()
        isMonitoring = false
        accelerometerData.removeAll()
        print("ℹ️ Motion monitoring stopped")
    }

    private func analyzeAccelerometerData() {
        guard accelerometerData.count >= 25 else { return }  // Need at least 0.5s of data

        // Calculate magnitude of recent accelerations
        let recentData = accelerometerData.suffix(25)
        let magnitudes = recentData.map { data in
            sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
        }

        // Check for high-frequency, high-magnitude movements (convulsion pattern)
        let highMagnitudeCount = magnitudes.filter { $0 > SafetyThresholds.convulsionMagnitude }.count

        if Double(highMagnitudeCount) / Double(magnitudes.count) > 0.6 {
            // > 60% of samples show high magnitude = possible convulsion
            detectPossibleSeizure(source: .accelerometer)
        }
    }

    // MARK: - Heart Rate Monitoring

    /// Monitor heart rate for autonomic seizure signs
    func monitorHeartRate(currentHR: Double, baselineHR: Double) {
        let increase = currentHR - baselineHR

        if increase > SafetyThresholds.preSeizureHeartRateIncrease {
            print("⚠️ Significant heart rate increase detected: +\(String(format: "%.0f", increase)) bpm")
            riskLevel = .elevated

            // Check for rapid acceleration (possible pre-ictal state)
            if increase > 40.0 {
                detectPossibleSeizure(source: .heartRate)
            }
        }
    }

    // MARK: - Seizure Detection

    enum SeizureSource {
        case visualPattern
        case accelerometer
        case heartRate
        case userReported
    }

    private func detectPossibleSeizure(source: SeizureSource) {
        // Avoid duplicate alerts within 30 seconds
        if let last = lastAlert, Date().timeIntervalSince(last) < 30.0 {
            return
        }

        lastAlert = Date()
        riskLevel = .critical

        print("🚨 POSSIBLE SEIZURE DETECTED - Source: \(source)")

        // Trigger emergency response
        triggerSeizureEmergencyProtocol(source: source)
    }

    private func triggerSeizureEmergencyProtocol(source: SeizureSource) {
        // 1. Stop all visual stimulation immediately
        NotificationCenter.default.post(name: NSNotification.Name("EmergencyStopVisual"), object: nil)

        // 2. Stop all audio (loud sounds can exacerbate)
        NotificationCenter.default.post(name: NSNotification.Name("EmergencyStopAudio"), object: nil)

        // 3. Log adverse event
        let event = MedicalDeviceComplianceManager.AdverseEvent(
            timestamp: Date(),
            severity: .severe,
            description: "Possible seizure detected via \(source)",
            deviceState: MedicalDeviceComplianceManager.AdverseEvent.DeviceState(
                softwareVersion: "1.0.0",
                activeFeatures: [],
                sessionDuration: 0,
                audioLevel: nil,
                frequency: nil
            ),
            userAction: "Automatic emergency stop",
            outcome: .unknown
        )
        MedicalDeviceComplianceManager.shared.reportAdverseEvent(event)

        // 4. Alert emergency contacts
        EmergencyResponseManager.shared.triggerEmergency(.seizureDetected)

        // 5. Show seizure first aid instructions
        showSeizureFirstAid()
    }

    private func showSeizureFirstAid() {
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowSeizureFirstAid"),
            object: nil
        )
    }

    // MARK: - Red Saturation Filter (Emergency Safe Mode)

    /// Apply red-desaturated filter to reduce seizure risk
    /// Based on: Wilkins et al. (2005) - Red filters reduce pattern sensitivity
    func getEmergencySafeColorFilter() -> ColorMatrix {
        // Reduce red channel (most provocative for photosensitive epilepsy)
        return ColorMatrix(
            r: [0.3, 0.0, 0.0, 0.0],  // Reduce red to 30%
            g: [0.0, 1.0, 0.0, 0.0],  // Keep green
            b: [0.0, 0.0, 1.0, 0.0],  // Keep blue
            a: [0.0, 0.0, 0.0, 1.0]   // Keep alpha
        )
    }

    struct ColorMatrix {
        let r: [Double]
        let g: [Double]
        let b: [Double]
        let a: [Double]
    }

    // MARK: - User Seizure History

    struct SeizureEvent: Identifiable, Codable {
        let id = UUID()
        let timestamp: Date
        let source: String
        let duration: TimeInterval?
        let notes: String?
    }

    private var seizureHistory: [SeizureEvent] = []

    func recordSeizureEvent(_ event: SeizureEvent) {
        seizureHistory.append(event)
        saveSeizureHistory()

        print("📝 Seizure event recorded: \(event.timestamp)")
    }

    func getSeizureHistory() -> [SeizureEvent] {
        return seizureHistory.sorted { $0.timestamp > $1.timestamp }
    }

    private func saveSeizureHistory() {
        do {
            let data = try JSONEncoder().encode(seizureHistory)
            UserDefaults.standard.set(data, forKey: "seizure_history")
        } catch {
            print("❌ Failed to save seizure history: \(error)")
        }
    }

    private func loadSeizureHistory() {
        guard let data = UserDefaults.standard.data(forKey: "seizure_history") else { return }

        do {
            seizureHistory = try JSONDecoder().decode([SeizureEvent].self, from: data)
            print("ℹ️ Loaded \(seizureHistory.count) seizure history events")
        } catch {
            print("❌ Failed to load seizure history: \(error)")
        }
    }

    // MARK: - Initialization

    private init() {
        loadSeizureHistory()
    }
}

// MARK: - Seizure First Aid View

struct SeizureFirstAidView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)

                Text("Seizure First Aid")
                    .font(.title)
                    .fontWeight(.bold)
            }

            Divider()

            Text("If someone is having a seizure:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                FirstAidStep(number: 1, text: "Stay calm and stay with the person")
                FirstAidStep(number: 2, text: "Time the seizure (call 911 if > 5 minutes)")
                FirstAidStep(number: 3, text: "Move nearby objects to prevent injury")
                FirstAidStep(number: 4, text: "Turn person on their side if possible")
                FirstAidStep(number: 5, text: "Place something soft under their head")
                FirstAidStep(number: 6, text: "DO NOT restrain or put anything in mouth")
            }

            Divider()

            Text("Call 911 if:")
                .font(.headline)
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 8) {
                Text("• Seizure lasts > 5 minutes")
                Text("• Person doesn't regain consciousness")
                Text("• Multiple seizures occur")
                Text("• Person is injured")
                Text("• Person is pregnant or has diabetes")
                Text("• First-time seizure")
            }
            .font(.subheadline)

            Spacer()

            Button(action: { dismiss() }) {
                Text("I Understand")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct FirstAidStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 30)

            Text(text)
                .font(.body)
        }
    }
}

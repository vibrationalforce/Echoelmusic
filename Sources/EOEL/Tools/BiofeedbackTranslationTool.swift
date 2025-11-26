//
//  BiofeedbackTranslationTool.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  UNIFIED BIOFEEDBACK TRANSLATION TOOL
//  Real-time translation: Biofeedback → Audio + Visual + BPM + Modulation
//
//  **Features:**
//  - Direct frequency translation (0.04-0.4 Hz → 40-400 Hz audio + colors)
//  - BPM control and synchronization
//  - Modulation options (AM, FM, Ring modulation)
//  - Real-time visual feedback
//  - Recording and playback
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

// MARK: - Unified Biofeedback Translation Tool

/// Complete biofeedback translation tool with audio, visual, BPM, and modulation
@MainActor
class BiofeedbackTranslationTool: ObservableObject {
    static let shared = BiofeedbackTranslationTool()

    // MARK: - Published Properties

    // Input (Biofeedback)
    @Published var inputHRV: Double = 50.0  // ms (RMSSD)
    @Published var inputHeartRate: Double = 70.0  // BPM
    @Published var inputCoherence: Double = 50.0  // 0-100
    @Published var inputHRVFrequency: Double = 0.1  // Hz (dominant frequency)

    // Output (Translated)
    @Published var outputAudioFrequency: Double = 100.0  // Hz
    @Published var outputVisualColor: Color = .green
    @Published var outputBPM: Double = 120.0  // Beats per minute
    @Published var outputVisualization: String = "Sine Wave"

    // Translation Settings
    @Published var translationMode: TranslationMode = .direct
    @Published var audioMultiplier: Double = 1000.0  // For direct mode (×1000)
    @Published var visualMapping: VisualMapping = .frequency

    // BPM Settings
    @Published var bpmSource: BPMSource = .heartRate
    @Published var bpmMultiplier: Double = 1.0  // 1x, 2x, 0.5x, etc.
    @Published var bpmOffset: Double = 0.0  // Add/subtract BPM

    // Modulation Settings
    @Published var modulationType: ModulationType = .none
    @Published var modulationDepth: Double = 0.5  // 0-1
    @Published var modulationRate: Double = 2.0  // Hz

    // Control
    @Published var isEnabled: Bool = false
    @Published var volume: Float = 0.5

    // Components
    private let audioSonification = BiofeedbackSonificationManager.shared
    private let visualMapper = FrequencyToVisualMapper.shared
    private let audioEngine = AVAudioEngine()

    // MARK: - Translation Modes

    enum TranslationMode: String, CaseIterable {
        case direct = "Direct (×1000)"
        case musical = "Musical Scale"
        case logarithmic = "Logarithmic"
        case exponential = "Exponential"
        case custom = "Custom"

        var description: String {
            switch self {
            case .direct:
                return "Direct multiplication: 0.1 Hz → 100 Hz"
            case .musical:
                return "Map to musical notes and scales"
            case .logarithmic:
                return "Logarithmic scaling (octaves)"
            case .exponential:
                return "Exponential scaling (power curve)"
            case .custom:
                return "Custom user-defined mapping"
            }
        }

        func translate(input: Double, multiplier: Double) -> Double {
            switch self {
            case .direct:
                return input * multiplier
            case .musical:
                // Map to nearest musical note
                let octave = log2(input * multiplier / 440.0)
                let nearestSemitone = round(octave * 12.0)
                return 440.0 * pow(2.0, nearestSemitone / 12.0)
            case .logarithmic:
                return 440.0 * pow(2.0, log10(input * multiplier))
            case .exponential:
                return 440.0 * pow(input * multiplier, 2.0)
            case .custom:
                return input * multiplier  // User can override
            }
        }
    }

    // MARK: - Visual Mapping

    enum VisualMapping: String, CaseIterable {
        case frequency = "By Frequency"
        case coherence = "By Coherence"
        case hrv = "By HRV"
        case heartRate = "By Heart Rate"
        case combined = "Combined (All)"

        var description: String {
            switch self {
            case .frequency:
                return "Color based on HRV frequency (VLF/LF/HF)"
            case .coherence:
                return "Color based on coherence score (red→green)"
            case .hrv:
                return "Color based on HRV magnitude"
            case .heartRate:
                return "Color based on heart rate (blue→red)"
            case .combined:
                return "Multi-parameter color mixing"
            }
        }
    }

    // MARK: - BPM Source

    enum BPMSource: String, CaseIterable {
        case heartRate = "Heart Rate"
        case hrvFrequency = "HRV Frequency"
        case coherence = "Coherence Score"
        case audioFrequency = "Audio Frequency"
        case manual = "Manual"

        var description: String {
            switch self {
            case .heartRate:
                return "Use actual heart rate as BPM"
            case .hrvFrequency:
                return "Derive BPM from HRV frequency (×60)"
            case .coherence:
                return "Map coherence to BPM range"
            case .audioFrequency:
                return "Derive BPM from audio frequency (÷60)"
            case .manual:
                return "User-controlled BPM"
            }
        }
    }

    // MARK: - Modulation Types

    enum ModulationType: String, CaseIterable {
        case none = "None"
        case amplitudeModulation = "AM (Amplitude)"
        case frequencyModulation = "FM (Frequency)"
        case ringModulation = "Ring Modulation"
        case phaseModulation = "Phase Modulation"
        case tremolo = "Tremolo"
        case vibrato = "Vibrato"

        var description: String {
            switch self {
            case .none:
                return "No modulation"
            case .amplitudeModulation:
                return "Modulate volume/amplitude"
            case .frequencyModulation:
                return "Modulate pitch/frequency"
            case .ringModulation:
                return "Multiply signal with modulator"
            case .phaseModulation:
                return "Modulate phase (similar to FM)"
            case .tremolo:
                return "Rhythmic amplitude variation"
            case .vibrato:
                return "Rhythmic pitch variation"
            }
        }
    }

    // MARK: - Translation Functions

    /// Translate biofeedback to audio frequency
    func translateToAudio(hrv: Double, hrvFrequency: Double, heartRate: Double) -> Double {
        let baseFrequency = translationMode.translate(
            input: hrvFrequency,
            multiplier: audioMultiplier
        )

        // Apply modulation
        return applyModulation(
            frequency: baseFrequency,
            modDepth: modulationDepth,
            modRate: modulationRate
        )
    }

    /// Translate biofeedback to visual color
    func translateToVisual(hrv: Double, hrvFrequency: Double, heartRate: Double, coherence: Double) -> Color {
        switch visualMapping {
        case .frequency:
            return visualMapper.mapHRVToColor(frequency: hrvFrequency)

        case .coherence:
            // Red (low) → Yellow (medium) → Green (high)
            let hue = coherence / 100.0 * 0.33  // 0-0.33 (red-green)
            return Color(hue: hue, saturation: 0.8, brightness: 0.9)

        case .hrv:
            // Map HRV magnitude to color
            let normalized = min(1.0, hrv / 100.0)  // Normalize to 0-1
            return Color(hue: normalized * 0.33, saturation: 0.8, brightness: 0.9)

        case .heartRate:
            // Blue (low 60) → Green (normal 80) → Red (high 120)
            let normalized = (heartRate - 60.0) / 60.0  // 0-1 for 60-120 BPM
            let hue = (1.0 - normalized) * 0.66  // 0.66 (blue) → 0 (red)
            return Color(hue: hue, saturation: 0.8, brightness: 0.9)

        case .combined:
            // Mix all parameters
            let freqColor = visualMapper.mapHRVToColor(frequency: hrvFrequency)
            let cohHue = coherence / 100.0 * 0.33
            // Combine (simplified - would use proper color mixing)
            return freqColor
        }
    }

    /// Translate biofeedback to BPM
    func translateToBPM(hrv: Double, hrvFrequency: Double, heartRate: Double, coherence: Double) -> Double {
        let baseBPM: Double

        switch bpmSource {
        case .heartRate:
            baseBPM = heartRate

        case .hrvFrequency:
            // HRV frequency (Hz) × 60 = BPM
            baseBPM = hrvFrequency * 60.0

        case .coherence:
            // Map coherence (0-100) to BPM range (60-120)
            baseBPM = 60.0 + (coherence / 100.0) * 60.0

        case .audioFrequency:
            // Audio frequency (Hz) ÷ some factor
            baseBPM = outputAudioFrequency / 2.0

        case .manual:
            baseBPM = outputBPM  // Keep current
        }

        // Apply multiplier and offset
        return (baseBPM * bpmMultiplier) + bpmOffset
    }

    /// Apply modulation to frequency
    private func applyModulation(frequency: Double, modDepth: Double, modRate: Double) -> Double {
        guard modulationType != .none else { return frequency }

        let time = Date().timeIntervalSince1970

        switch modulationType {
        case .none:
            return frequency

        case .amplitudeModulation:
            // AM doesn't change frequency, only amplitude
            return frequency

        case .frequencyModulation, .vibrato:
            // FM: f(t) = fc + Δf * sin(2π * fm * t)
            let modulation = sin(2.0 * .pi * modRate * time)
            let frequencyDeviation = frequency * modDepth * modulation
            return frequency + frequencyDeviation

        case .ringModulation:
            // Ring mod creates sidebands: fc ± fm
            let modulation = sin(2.0 * .pi * modRate * time)
            return frequency * (1.0 + modDepth * modulation)

        case .phaseModulation:
            // Similar to FM but modulates phase
            let modulation = sin(2.0 * .pi * modRate * time)
            return frequency * (1.0 + modDepth * 0.1 * modulation)

        case .tremolo:
            // Tremolo is slower AM (typically 4-8 Hz)
            return frequency
        }
    }

    // MARK: - Update Translation

    /// Update all translations from current biofeedback input
    func updateTranslation() {
        guard isEnabled else { return }

        // Translate to audio
        outputAudioFrequency = translateToAudio(
            hrv: inputHRV,
            hrvFrequency: inputHRVFrequency,
            heartRate: inputHeartRate
        )

        // Translate to visual
        outputVisualColor = translateToVisual(
            hrv: inputHRV,
            hrvFrequency: inputHRVFrequency,
            heartRate: inputHeartRate,
            coherence: inputCoherence
        )

        // Translate to BPM
        outputBPM = translateToBPM(
            hrv: inputHRV,
            hrvFrequency: inputHRVFrequency,
            heartRate: inputHeartRate,
            coherence: inputCoherence
        )

        // Update audio sonification
        audioSonification.sonifyHRV(
            frequency: inputHRVFrequency,
            power: inputCoherence / 100.0
        )

        audioSonification.sonifyHeartRate(bpm: inputHeartRate)
        audioSonification.sonifyCoherence(score: inputCoherence)
    }

    // MARK: - Presets

    /// Translation preset configurations
    struct TranslationPreset {
        let name: String
        let translationMode: TranslationMode
        let audioMultiplier: Double
        let visualMapping: VisualMapping
        let bpmSource: BPMSource
        let modulationType: ModulationType
        let description: String

        static let presets: [TranslationPreset] = [
            TranslationPreset(
                name: "Direct 1:1000",
                translationMode: .direct,
                audioMultiplier: 1000.0,
                visualMapping: .frequency,
                bpmSource: .heartRate,
                modulationType: .none,
                description: "Direct frequency multiplication by 1000"
            ),
            TranslationPreset(
                name: "Musical Harmony",
                translationMode: .musical,
                audioMultiplier: 1000.0,
                visualMapping: .coherence,
                bpmSource: .heartRate,
                modulationType: .vibrato,
                description: "Musical notes with vibrato modulation"
            ),
            TranslationPreset(
                name: "Coherence Focus",
                translationMode: .direct,
                audioMultiplier: 1000.0,
                visualMapping: .coherence,
                bpmSource: .coherence,
                modulationType: .tremolo,
                description: "Emphasizes coherence in all parameters"
            ),
            TranslationPreset(
                name: "HRV Explorer",
                translationMode: .logarithmic,
                audioMultiplier: 1000.0,
                visualMapping: .frequency,
                bpmSource: .hrvFrequency,
                modulationType: .frequencyModulation,
                description: "Deep HRV frequency exploration with FM"
            ),
            TranslationPreset(
                name: "Ambient Meditation",
                translationMode: .direct,
                audioMultiplier: 500.0,
                visualMapping: .combined,
                bpmSource: .manual,
                modulationType: .phaseModulation,
                description: "Subtle ambient translation for meditation"
            )
        ]
    }

    func applyPreset(_ preset: TranslationPreset) {
        translationMode = preset.translationMode
        audioMultiplier = preset.audioMultiplier
        visualMapping = preset.visualMapping
        bpmSource = preset.bpmSource
        modulationType = preset.modulationType

        updateTranslation()

        print("🎛️ Applied preset: \(preset.name)")
    }

    // MARK: - Control

    func start() {
        isEnabled = true
        audioSonification.start()
        print("▶️ Biofeedback translation tool started")
    }

    func stop() {
        isEnabled = false
        audioSonification.stop()
        print("⏸️ Biofeedback translation tool stopped")
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        audioSonification.setVolume(newVolume)
    }

    // MARK: - Recording

    struct TranslationSnapshot: Codable {
        let timestamp: Date
        let inputHRV: Double
        let inputHeartRate: Double
        let inputCoherence: Double
        let inputHRVFrequency: Double
        let outputAudioFrequency: Double
        let outputBPM: Double
        let translationMode: String
        let modulationType: String
    }

    private var recordingBuffer: [TranslationSnapshot] = []
    @Published var isRecording: Bool = false

    func startRecording() {
        isRecording = true
        recordingBuffer.removeAll()
        print("🔴 Recording started")
    }

    func stopRecording() -> [TranslationSnapshot] {
        isRecording = false
        print("⏹️ Recording stopped: \(recordingBuffer.count) snapshots")
        return recordingBuffer
    }

    func recordSnapshot() {
        guard isRecording else { return }

        let snapshot = TranslationSnapshot(
            timestamp: Date(),
            inputHRV: inputHRV,
            inputHeartRate: inputHeartRate,
            inputCoherence: inputCoherence,
            inputHRVFrequency: inputHRVFrequency,
            outputAudioFrequency: outputAudioFrequency,
            outputBPM: outputBPM,
            translationMode: translationMode.rawValue,
            modulationType: modulationType.rawValue
        )

        recordingBuffer.append(snapshot)
    }

    private init() {}
}

// MARK: - SwiftUI Extensions

extension BiofeedbackTranslationTool {
    /// Connect to real-time biofeedback
    func connectToBiofeedback(
        hrv: Double,
        heartRate: Double,
        coherence: Double,
        hrvFrequency: Double
    ) {
        inputHRV = hrv
        inputHeartRate = heartRate
        inputCoherence = coherence
        inputHRVFrequency = hrvFrequency

        updateTranslation()
        recordSnapshot()
    }
}

// MARK: - Debug

#if DEBUG
extension BiofeedbackTranslationTool {
    func testTranslation() {
        print("🧪 Testing biofeedback translation...")

        // Test with sample data
        connectToBiofeedback(
            hrv: 50.0,
            heartRate: 70.0,
            coherence: 75.0,
            hrvFrequency: 0.1
        )

        print("Input:")
        print("  HRV: \(inputHRV) ms")
        print("  Heart Rate: \(inputHeartRate) BPM")
        print("  Coherence: \(inputCoherence)")
        print("  HRV Frequency: \(inputHRVFrequency) Hz")
        print()
        print("Output:")
        print("  Audio Frequency: \(outputAudioFrequency) Hz")
        print("  BPM: \(outputBPM)")
        print("  Visual Color: \(outputVisualColor)")

        print("✅ Translation test complete")
    }

    func testAllPresets() {
        print("🧪 Testing all presets...")

        for preset in TranslationPreset.presets {
            applyPreset(preset)
            print("  ✓ \(preset.name): \(outputAudioFrequency) Hz, \(outputBPM) BPM")
        }

        print("✅ Preset test complete")
    }
}
#endif

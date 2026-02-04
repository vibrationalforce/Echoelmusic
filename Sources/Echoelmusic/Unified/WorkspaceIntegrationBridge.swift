//
//  WorkspaceIntegrationBridge.swift
//  Echoelmusic
//
//  Unified integration bridge connecting DAW, Video, and Live Performance workspaces
//  Ensures all UI elements are properly wired to their respective engines
//
//  Created: 2026-02-04
//

import Foundation
import Combine
import SwiftUI

// MARK: - Workspace Integration Bridge

/// Central bridge that connects all workspace UIs to their engines
/// Enables cross-workspace state synchronization and data flow
@MainActor
public final class WorkspaceIntegrationBridge: ObservableObject {

    // MARK: - Singleton

    public static let shared = WorkspaceIntegrationBridge()

    // MARK: - Shared State

    /// Global transport state shared across all workspaces
    @Published public var isPlaying: Bool = false
    @Published public var isRecording: Bool = false
    @Published public var currentBPM: Double = 120.0
    @Published public var currentPosition: TimeInterval = 0.0
    @Published public var currentBeat: Double = 0.0

    /// Bio-reactive state from HealthKit
    @Published public var heartRate: Double = 72.0
    @Published public var hrvCoherence: Float = 0.5
    @Published public var breathingRate: Double = 12.0
    @Published public var bioSyncEnabled: Bool = true

    /// Master output levels
    @Published public var masterVolume: Float = 0.8
    @Published public var masterPeakL: Float = 0.0
    @Published public var masterPeakR: Float = 0.0

    // MARK: - Engine References

    public weak var audioEngine: AudioEngine?
    public weak var recordingEngine: RecordingEngine?
    public weak var healthKitManager: HealthKitManager?
    public weak var unifiedControlHub: UnifiedControlHub?

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()
    private var positionTimer: Timer?

    // MARK: - Initialization

    private init() {
        setupBindings()
    }

    // MARK: - Configuration

    /// Configure with engine references from app initialization
    public func configure(
        audioEngine: AudioEngine?,
        recordingEngine: RecordingEngine?,
        healthKitManager: HealthKitManager?,
        unifiedControlHub: UnifiedControlHub?
    ) {
        self.audioEngine = audioEngine
        self.recordingEngine = recordingEngine
        self.healthKitManager = healthKitManager
        self.unifiedControlHub = unifiedControlHub

        bindToEngines()
    }

    private func setupBindings() {
        // BPM changes propagate to all systems
        $currentBPM
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] bpm in
                self?.propagateBPMChange(bpm)
            }
            .store(in: &cancellables)
    }

    private func bindToEngines() {
        // Bind to HealthKit updates
        healthKitManager?.$heartRate
            .receive(on: RunLoop.main)
            .assign(to: &$heartRate)

        healthKitManager?.$hrvRMSSD
            .receive(on: RunLoop.main)
            .map { Float($0 / 100.0).clamped(to: 0...1) }
            .assign(to: &$hrvCoherence)

        // Bind to recording engine state
        recordingEngine?.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: &$isRecording)

        recordingEngine?.$isPlaying
            .receive(on: RunLoop.main)
            .assign(to: &$isPlaying)
    }

    // MARK: - Transport Controls (Shared Across Workspaces)

    /// Start playback - works for DAW, Video, and Streaming
    public func startPlayback() {
        isPlaying = true

        // Start DAW/Audio playback
        recordingEngine?.startPlayback()

        // Start position timer
        startPositionTimer()

        // Notify unified control hub
        unifiedControlHub?.setPlaybackState(true)

        #if DEBUG
        print("[WorkspaceIntegration] Started playback")
        #endif
    }

    /// Stop playback
    public func stopPlayback() {
        isPlaying = false

        recordingEngine?.stopPlayback()
        stopPositionTimer()
        unifiedControlHub?.setPlaybackState(false)

        #if DEBUG
        print("[WorkspaceIntegration] Stopped playback")
        #endif
    }

    /// Toggle playback state
    public func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    /// Start recording
    public func startRecording(trackType: RecordingEngine.TrackType = .audio) {
        do {
            try recordingEngine?.startRecording(trackType: trackType)
            isRecording = true

            if !isPlaying {
                startPlayback()
            }

            #if DEBUG
            print("[WorkspaceIntegration] Started recording")
            #endif
        } catch {
            #if DEBUG
            print("[WorkspaceIntegration] Recording failed: \(error)")
            #endif
        }
    }

    /// Stop recording
    public func stopRecording() {
        recordingEngine?.stopRecording()
        isRecording = false

        #if DEBUG
        print("[WorkspaceIntegration] Stopped recording")
        #endif
    }

    /// Seek to position
    public func seek(to position: TimeInterval) {
        currentPosition = position
        currentBeat = position * (currentBPM / 60.0)
        recordingEngine?.seek(to: position)
    }

    /// Seek to beat
    public func seekToBeat(_ beat: Double) {
        currentBeat = beat
        currentPosition = beat / (currentBPM / 60.0)
        recordingEngine?.seek(to: currentPosition)
    }

    // MARK: - BPM Control

    /// Set BPM with propagation to all systems
    public func setBPM(_ bpm: Double) {
        currentBPM = bpm.clamped(to: 20...300)
    }

    private func propagateBPMChange(_ bpm: Double) {
        // Update audio engine
        audioEngine?.setBPM(Float(bpm))

        // Update binaural beats if bio-sync enabled
        if bioSyncEnabled {
            let targetFrequency = mapBPMToBrainwave(bpm)
            audioEngine?.setBinauralBaseFrequency(targetFrequency)
        }

        #if DEBUG
        print("[WorkspaceIntegration] BPM changed to \(bpm)")
        #endif
    }

    private func mapBPMToBrainwave(_ bpm: Double) -> Float {
        // Map BPM to brainwave frequencies
        // Slower BPM = theta/alpha, faster = beta/gamma
        switch bpm {
        case 0..<80: return 6.0   // Theta (meditation)
        case 80..<100: return 10.0 // Alpha (relaxed)
        case 100..<140: return 18.0 // Beta (focused)
        default: return 40.0      // Gamma (peak)
        }
    }

    // MARK: - Track Controls

    /// Set track volume
    public func setTrackVolume(trackID: UUID, volume: Float) {
        recordingEngine?.setTrackVolume(trackID, volume: volume)
    }

    /// Set track pan
    public func setTrackPan(trackID: UUID, pan: Float) {
        recordingEngine?.setTrackPan(trackID, pan: pan)
    }

    /// Set track mute
    public func setTrackMuted(trackID: UUID, muted: Bool) {
        recordingEngine?.setTrackMuted(trackID, muted: muted)
    }

    /// Set track solo
    public func setTrackSoloed(trackID: UUID, soloed: Bool) {
        recordingEngine?.setTrackSoloed(trackID, soloed: soloed)
    }

    /// Set master volume
    public func setMasterVolume(_ volume: Float) {
        masterVolume = volume.clamped(to: 0...1)
        audioEngine?.setMasterVolume(masterVolume)
    }

    // MARK: - Bio-Reactive Controls

    /// Toggle bio-sync mode
    public func toggleBioSync() {
        bioSyncEnabled.toggle()

        if bioSyncEnabled {
            // Apply bio-reactive modulation
            applyBioModulation()
        }
    }

    /// Apply bio-reactive modulation to audio parameters
    public func applyBioModulation() {
        guard bioSyncEnabled else { return }

        // Coherence affects filter cutoff
        let coherence = hrvCoherence
        let normalizedHR = Float((heartRate - 40) / 160).clamped(to: 0...1)

        // Heart rate modulates filter brightness
        audioEngine?.setFilterCutoff(0.3 + normalizedHR * 0.5 + coherence * 0.2)

        #if DEBUG
        print("[WorkspaceIntegration] Bio modulation applied - coherence: \(coherence), HR: \(heartRate)")
        #endif
    }

    // MARK: - Position Timer

    private func startPositionTimer() {
        stopPositionTimer()

        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePosition()
            }
        }
    }

    private func stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
    }

    private func updatePosition() {
        guard isPlaying else { return }

        // Update from recording engine if available
        if let engine = recordingEngine {
            currentPosition = engine.currentTime
            currentBeat = currentPosition * (currentBPM / 60.0)
        } else {
            // Fallback: increment manually
            currentPosition += 1.0/60.0
            currentBeat = currentPosition * (currentBPM / 60.0)
        }

        // Update master peaks (simulated if not available)
        // AudioEngine may not have level metering - use defaults
        masterPeakL = 0.5
        masterPeakR = 0.5

        // Continuous bio modulation
        if bioSyncEnabled && Int(currentPosition * 10) % 5 == 0 {
            applyBioModulation()
        }
    }

    // MARK: - Cross-Workspace Data Export

    /// Export DAW arrangement to video timeline
    public func exportArrangementToVideo() -> [VideoClipData] {
        // RecordingEngine doesn't expose tracks directly
        // This would need to query recording files or session data
        return []
    }

    /// Get current bio data for video overlay
    public func getBioDataForVideoOverlay() -> BioOverlayData {
        return BioOverlayData(
            heartRate: heartRate,
            hrvCoherence: hrvCoherence,
            breathingRate: breathingRate,
            timestamp: currentPosition
        )
    }
}

// MARK: - Supporting Types

public struct VideoClipData {
    let startTime: TimeInterval
    let duration: TimeInterval
    let name: String
    let type: ClipType

    enum ClipType {
        case audio
        case midi
        case video
        case bioReactive
    }
}

public struct BioOverlayData {
    let heartRate: Double
    let hrvCoherence: Float
    let breathingRate: Double
    let timestamp: TimeInterval
}

// MARK: - Float Extension

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

// LivePerformancePlugin.swift
// Echoelmusic - λ Lambda Mode Ralph Wiggum Loop Quantum Light Science
//
// Professional plugin for live musicians and performers
// Set lists, MIDI cues, lighting sync, bio-adaptive click track
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation

/// A comprehensive plugin for live musicians and performers
/// Demonstrates: midiInput, midiOutput, dmxOutput, recording capabilities
public final class LivePerformancePlugin: EchoelmusicPlugin {

    // MARK: - Plugin Info

    public var identifier: String { "com.echoelmusic.live-performance" }
    public var name: String { "Live Performance Manager" }
    public var version: String { "1.0.0" }
    public var author: String { "Echoelmusic Performance Team" }
    public var pluginDescription: String { "Professional live performance management with set lists, MIDI cues, lighting sync, and bio-adaptive click track" }
    public var requiredSDKVersion: String { "2.0.0" }
    public var capabilities: Set<PluginCapability> { [.midiInput, .midiOutput, .dmxOutput, .recording, .bioProcessing, .audioGenerator] }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var performanceName: String = "Untitled Performance"
        public var midiChannel: UInt8 = 1
        public var enableBioAdaptiveTempo: Bool = true
        public var tempoRange: ClosedRange<Float> = 60...180
        public var clickTrackEnabled: Bool = true
        public var lightingSyncEnabled: Bool = true
        public var autoTransitionEnabled: Bool = false

        public enum ClickSound: String, CaseIterable, Sendable {
            case metronome = "Metronome"
            case woodBlock = "Wood Block"
            case beep = "Beep"
            case cowbell = "Cowbell"
            case sideStick = "Side Stick"
        }

        public var clickSound: ClickSound = .metronome
    }

    // MARK: - Performance Data Models

    public struct SetList: Codable, Sendable {
        public var id: UUID
        public var name: String
        public var songs: [Song]
        public var currentSongIndex: Int

        public init(name: String, songs: [Song] = []) {
            self.id = UUID()
            self.name = name
            self.songs = songs
            self.currentSongIndex = 0
        }

        public var currentSong: Song? {
            guard currentSongIndex < songs.count else { return nil }
            return songs[currentSongIndex]
        }
    }

    public struct Song: Codable, Identifiable, Sendable {
        public var id: UUID
        public var title: String
        public var artist: String
        public var bpm: Float
        public var key: String
        public var duration: TimeInterval
        public var cues: [Cue]
        public var midiProgramChange: UInt8?
        public var lightingScene: String?
        public var notes: String

        public init(title: String, artist: String, bpm: Float, key: String, duration: TimeInterval) {
            self.id = UUID()
            self.title = title
            self.artist = artist
            self.bpm = bpm
            self.key = key
            self.duration = duration
            self.cues = []
            self.midiProgramChange = nil
            self.lightingScene = nil
            self.notes = ""
        }
    }

    public struct Cue: Codable, Identifiable, Sendable {
        public var id: UUID
        public var timestamp: TimeInterval
        public var name: String
        public var type: CueType
        public var action: String

        public enum CueType: String, Codable, Sendable {
            case midiProgramChange = "MIDI Program"
            case lightingChange = "Lighting"
            case effectToggle = "Effect"
            case marker = "Marker"
            case automation = "Automation"
        }

        public init(timestamp: TimeInterval, name: String, type: CueType, action: String) {
            self.id = UUID()
            self.timestamp = timestamp
            self.name = name
            self.type = type
            self.action = action
        }
    }

    public struct PerformanceStats: Sendable {
        public var startTime: Date
        public var currentSongStartTime: Date
        public var songsCompleted: Int
        public var totalSongs: Int
        public var cuesTriggered: Int
        public var averageCoherence: Float
        public var averageHeartRate: Float
    }

    // MARK: - State

    public var configuration = Configuration()
    private var currentSetList: SetList?
    private var isPerformanceActive: Bool = false
    private var performanceStartTime: Date?
    private var currentSongStartTime: Date?
    private var songElapsedTime: TimeInterval = 0
    private var nextCueIndex: Int = 0

    // Click track
    private var clickPhase: Float = 0
    private var currentTempo: Float = 120.0
    private var beatCount: Int = 0

    // Bio data
    private var currentHeartRate: Float = 70.0
    private var currentCoherence: Float = 0.5
    private var heartRateHistory: [Float] = []

    // Emergency
    private var emergencyStopActive: Bool = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Plugin Lifecycle

    public func onLoad(context: PluginContext) async throws {
        log.info("Live Performance Plugin loaded - Performance: \(configuration.performanceName)", category: .performance)
        await loadSetList(from: context.dataDirectory)
    }

    public func onUnload() async {
        if isPerformanceActive {
            await stopPerformance()
        }
        log.info("Live Performance Plugin unloaded", category: .performance)
    }

    public func onFrame(deltaTime: TimeInterval) {
        guard isPerformanceActive, !emergencyStopActive else { return }
        songElapsedTime += deltaTime
        checkAndTriggerCues()
        if configuration.autoTransitionEnabled {
            checkAutoTransition()
        }
    }

    public func onBioDataUpdate(_ bioData: BioData) {
        if let hr = bioData.heartRate {
            currentHeartRate = hr
            heartRateHistory.append(hr)
            if heartRateHistory.count > 100 {
                heartRateHistory.removeFirst()
            }
        }
        currentCoherence = bioData.coherence

        if configuration.enableBioAdaptiveTempo, let song = currentSetList?.currentSong {
            let targetTempo = song.bpm
            let hrFactor = (currentHeartRate - 70.0) / 30.0
            let adaptiveTempo = targetTempo + (hrFactor * 10.0)
            currentTempo = adaptiveTempo.clamped(to: configuration.tempoRange)
        }
    }

    public func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
        guard configuration.clickTrackEnabled, isPerformanceActive, !emergencyStopActive else { return }

        let sampleRateF = Float(sampleRate)
        let samplesPerChannel = buffer.count / channels
        let beatsPerSecond = currentTempo / 60.0

        for sample in 0..<samplesPerChannel {
            clickPhase += beatsPerSecond / sampleRateF
            if clickPhase >= 1.0 {
                clickPhase -= 1.0
                beatCount += 1
                let clickSample = generateClickSample(beat: beatCount % 4)
                for channel in 0..<channels {
                    buffer[sample * channels + channel] += clickSample * 0.3
                }
            }
        }
    }

    // MARK: - Set List Management

    /// Load a set list
    public func loadSetList(_ setList: SetList) {
        currentSetList = setList
        nextCueIndex = 0
        log.info("Loaded set list: \(setList.name) - \(setList.songs.count) songs", category: .performance)
    }

    /// Get current set list
    public func getCurrentSetList() -> SetList? {
        return currentSetList
    }

    /// Add song to set list
    public func addSong(_ song: Song) {
        if currentSetList != nil {
            currentSetList?.songs.append(song)
            log.debug("Added song: \(song.title) to set list", category: .performance)
        }
    }

    /// Remove song from set list
    public func removeSong(at index: Int) {
        guard var setList = currentSetList, index < setList.songs.count else { return }
        let removedSong = setList.songs.remove(at: index)
        currentSetList = setList
        log.debug("Removed song: \(removedSong.title) from set list", category: .performance)
    }

    // MARK: - Performance Control

    /// Start the performance
    public func startPerformance() async {
        guard let setList = currentSetList, !setList.songs.isEmpty else {
            log.warning("Cannot start performance - no songs in set list", category: .performance)
            return
        }
        isPerformanceActive = true
        performanceStartTime = Date()
        songElapsedTime = 0
        nextCueIndex = 0
        emergencyStopActive = false
        await startCurrentSong()
        log.info("Performance started: \(setList.name)", category: .performance)
    }

    /// Stop the performance
    public func stopPerformance() async {
        isPerformanceActive = false
        currentSongStartTime = nil
        songElapsedTime = 0
        clickPhase = 0
        beatCount = 0
        sendMIDIAllNotesOff()
        log.info("Performance stopped", category: .performance)
    }

    /// Next song in set list
    public func nextSong() async {
        guard var setList = currentSetList else { return }
        if setList.currentSongIndex < setList.songs.count - 1 {
            setList.currentSongIndex += 1
            currentSetList = setList
            songElapsedTime = 0
            nextCueIndex = 0
            await startCurrentSong()
            log.info("Advanced to next song: \(setList.currentSong?.title ?? "Unknown")", category: .performance)
        } else {
            log.info("Reached end of set list", category: .performance)
        }
    }

    /// Previous song in set list
    public func previousSong() async {
        guard var setList = currentSetList else { return }
        if setList.currentSongIndex > 0 {
            setList.currentSongIndex -= 1
            currentSetList = setList
            songElapsedTime = 0
            nextCueIndex = 0
            await startCurrentSong()
            log.info("Moved to previous song: \(setList.currentSong?.title ?? "Unknown")", category: .performance)
        }
    }

    /// Jump to specific song
    public func jumpToSong(index: Int) async {
        guard var setList = currentSetList, index >= 0, index < setList.songs.count else { return }
        setList.currentSongIndex = index
        currentSetList = setList
        songElapsedTime = 0
        nextCueIndex = 0
        await startCurrentSong()
        log.info("Jumped to song \(index + 1): \(setList.currentSong?.title ?? "Unknown")", category: .performance)
    }

    /// Emergency stop - immediately silence everything
    public func emergencyStop() {
        emergencyStopActive = true
        clickPhase = 0
        beatCount = 0
        sendMIDIAllNotesOff()
        sendMIDIPanic()
        blackoutLights()
        log.critical("EMERGENCY STOP ACTIVATED", category: .performance)
    }

    /// Resume from emergency stop
    public func resumeFromEmergency() {
        emergencyStopActive = false
        log.info("Resumed from emergency stop", category: .performance)
    }

    // MARK: - Cue Management

    /// Manually trigger next cue
    public func triggerNextCue() {
        guard let song = currentSetList?.currentSong, nextCueIndex < song.cues.count else {
            log.debug("No more cues to trigger", category: .performance)
            return
        }
        let cue = song.cues[nextCueIndex]
        executeCue(cue)
        nextCueIndex += 1
    }

    /// Add cue to current song
    public func addCueToCurrentSong(_ cue: Cue) {
        guard var setList = currentSetList else { return }
        let songIndex = setList.currentSongIndex
        setList.songs[songIndex].cues.append(cue)
        currentSetList = setList
        log.debug("Added cue '\(cue.name)' to current song", category: .performance)
    }

    // MARK: - Statistics

    /// Get performance statistics
    public func getPerformanceStats() -> PerformanceStats? {
        guard let startTime = performanceStartTime, let songStart = currentSongStartTime, let setList = currentSetList else {
            return nil
        }
        let avgHR = heartRateHistory.isEmpty ? 0 : heartRateHistory.reduce(0, +) / Float(heartRateHistory.count)
        return PerformanceStats(
            startTime: startTime,
            currentSongStartTime: songStart,
            songsCompleted: setList.currentSongIndex,
            totalSongs: setList.songs.count,
            cuesTriggered: nextCueIndex,
            averageCoherence: currentCoherence,
            averageHeartRate: avgHR
        )
    }

    // MARK: - Private Helpers

    private func startCurrentSong() async {
        guard let song = currentSetList?.currentSong else { return }
        currentSongStartTime = Date()
        currentTempo = song.bpm
        nextCueIndex = 0
        beatCount = 0
        if let program = song.midiProgramChange {
            sendMIDIProgramChange(program: program)
        }
        if let scene = song.lightingScene {
            switchLightingScene(scene)
        }
        log.info("Started song: \(song.title) - BPM: \(song.bpm)", category: .performance)
    }

    private func checkAndTriggerCues() {
        guard let song = currentSetList?.currentSong else { return }
        while nextCueIndex < song.cues.count {
            let cue = song.cues[nextCueIndex]
            if songElapsedTime >= cue.timestamp {
                executeCue(cue)
                nextCueIndex += 1
            } else {
                break
            }
        }
    }

    private func executeCue(_ cue: Cue) {
        log.debug("Triggering cue: \(cue.name) - Type: \(cue.type.rawValue)", category: .performance)
        switch cue.type {
        case .midiProgramChange:
            if let program = UInt8(cue.action) {
                sendMIDIProgramChange(program: program)
            }
        case .lightingChange:
            switchLightingScene(cue.action)
        case .effectToggle:
            log.debug("Toggle effect: \(cue.action)", category: .performance)
        case .marker:
            break
        case .automation:
            log.debug("Execute automation: \(cue.action)", category: .performance)
        }
    }

    private func checkAutoTransition() {
        guard let song = currentSetList?.currentSong else { return }
        if songElapsedTime >= song.duration {
            Task { await nextSong() }
        }
    }

    private func generateClickSample(beat: Int) -> Float {
        let amplitude: Float = beat == 0 ? 1.0 : 0.6
        switch configuration.clickSound {
        case .metronome: return amplitude
        case .woodBlock: return amplitude * 0.8
        case .beep: return amplitude * sin(Float.pi * 2 * 880 * 0.01)
        case .cowbell: return amplitude * 0.9
        case .sideStick: return amplitude * 0.7
        }
    }

    private func sendMIDIProgramChange(program: UInt8) {
        log.midi("MIDI Program Change: \(program) on channel \(configuration.midiChannel)")
    }

    private func sendMIDIAllNotesOff() {
        log.midi("MIDI All Notes Off on channel \(configuration.midiChannel)")
    }

    private func sendMIDIPanic() {
        log.midi("MIDI Panic - All Sound Off")
    }

    private func switchLightingScene(_ scene: String) {
        guard configuration.lightingSyncEnabled else { return }
        log.led("Switching to lighting scene: \(scene)")
    }

    private func blackoutLights() {
        log.led("Blackout all lights")
    }

    private func loadSetList(from directory: URL) async {
        let setListFile = directory.appendingPathComponent("current_setlist.json")
        guard FileManager.default.fileExists(atPath: setListFile.path),
              let data = try? Data(contentsOf: setListFile),
              let setList = try? JSONDecoder().decode(SetList.self, from: data) else {
            log.debug("No existing set list found", category: .performance)
            return
        }
        currentSetList = setList
        log.info("Loaded set list: \(setList.name)", category: .performance)
    }
}

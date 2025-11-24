# 🚀 PHASE 1 IMPLEMENTATION GUIDE

**Mission: Build the DAW Core (Months 1-6)**

> Detailed technical guide for implementing professional music production features
> From: Bio-reactive platform → Professional DAW

---

## 📋 OVERVIEW

**Phase 1 Goals:**
- ✅ VST3/AU Plugin Hosting
- ✅ Professional Mixing Console
- ✅ Basic Effects Suite
- ✅ Multi-Format Export
- ✅ Parameter Automation
- ✅ Live Performance Tools

**Timeline:** 6 months
**Priority:** ⭐⭐⭐⭐⭐ CRITICAL
**Success Metric:** Can produce professional music end-to-end

---

## 🎯 PHASE 1A: DAW ESSENTIALS (Months 1-2)

### **Week 1-2: VST3/AU Plugin Hosting**

#### **Architecture:**

```swift
// Sources/EOEL/Audio/PluginHost/PluginHostManager.swift

import AudioToolbox
import AVFoundation

/// Manages VST3 and Audio Unit plugin hosting
@MainActor
class PluginHostManager: ObservableObject {

    // MARK: - Published Properties

    /// Available plugins (scanned from system)
    @Published var availablePlugins: [PluginDescriptor] = []

    /// Currently loaded plugins
    @Published var loadedPlugins: [LoadedPlugin] = []

    /// Scan status
    @Published var isScanning: Bool = false


    // MARK: - Core Components

    /// Audio Unit component manager
    private let auManager = AVAudioUnitComponentManager.shared()

    /// Plugin scanner
    private let scanner = PluginScanner()

    /// Audio graph for routing
    private var audioGraph: AUGraph?


    // MARK: - Plugin Descriptor

    struct PluginDescriptor: Identifiable {
        let id = UUID()
        let name: String
        let manufacturer: String
        let type: PluginType
        let audioComponentDescription: AudioComponentDescription

        enum PluginType {
            case instrument
            case effect
            case midiEffect
        }
    }


    // MARK: - Loaded Plugin

    struct LoadedPlugin: Identifiable {
        let id = UUID()
        let descriptor: PluginDescriptor
        let audioUnit: AVAudioUnit
        let viewController: UIViewController?

        // Track assignment
        var trackID: UUID?

        // Parameters
        var parameters: [AUParameter] = []
    }


    // MARK: - Scanning

    /// Scan for available plugins
    func scanPlugins() async {
        await MainActor.run {
            isScanning = true
        }

        var plugins: [PluginDescriptor] = []

        // Scan Audio Units (AU)
        let components = auManager.components(
            matching: AudioComponentDescription(
                componentType: kAudioUnitType_Effect,
                componentSubType: 0,
                componentManufacturer: 0,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        )

        for component in components {
            let descriptor = PluginDescriptor(
                name: component.name,
                manufacturer: component.manufacturerName,
                type: .effect,
                audioComponentDescription: component.audioComponentDescription
            )
            plugins.append(descriptor)
        }

        // Scan Instruments
        let instruments = auManager.components(
            matching: AudioComponentDescription(
                componentType: kAudioUnitType_MusicDevice,
                componentSubType: 0,
                componentManufacturer: 0,
                componentFlags: 0,
                componentFlagsMask: 0
            )
        )

        for component in instruments {
            let descriptor = PluginDescriptor(
                name: component.name,
                manufacturer: component.manufacturerName,
                type: .instrument,
                audioComponentDescription: component.audioComponentDescription
            )
            plugins.append(descriptor)
        }

        await MainActor.run {
            availablePlugins = plugins
            isScanning = false
        }

        print("✅ Found \(plugins.count) plugins")
    }


    // MARK: - Loading

    /// Load a plugin
    func loadPlugin(descriptor: PluginDescriptor, onTrack trackID: UUID) async throws -> LoadedPlugin {

        // Instantiate Audio Unit
        let audioUnit = try await AVAudioUnit.instantiate(
            with: descriptor.audioComponentDescription,
            options: []
        )

        // Get view controller if available
        var viewController: UIViewController?
        if let auViewController = audioUnit.auAudioUnit.viewController {
            viewController = auViewController
        }

        // Get parameters
        let parameterTree = audioUnit.auAudioUnit.parameterTree
        let parameters = parameterTree?.allParameters ?? []

        let loadedPlugin = LoadedPlugin(
            descriptor: descriptor,
            audioUnit: audioUnit,
            viewController: viewController,
            trackID: trackID,
            parameters: parameters
        )

        await MainActor.run {
            loadedPlugins.append(loadedPlugin)
        }

        print("✅ Loaded plugin: \(descriptor.name)")

        return loadedPlugin
    }


    // MARK: - Removal

    /// Remove a plugin
    func removePlugin(_ plugin: LoadedPlugin) {
        loadedPlugins.removeAll { $0.id == plugin.id }
        print("🗑️ Removed plugin: \(plugin.descriptor.name)")
    }
}


// MARK: - Plugin Scanner

class PluginScanner {

    /// Scan VST3 plugins (macOS/Windows)
    func scanVST3Plugins() -> [URL] {
        var pluginPaths: [URL] = []

        #if os(macOS)
        let vst3Paths = [
            "/Library/Audio/Plug-Ins/VST3",
            "~/Library/Audio/Plug-Ins/VST3"
        ]
        #elseif os(Windows)
        let vst3Paths = [
            "C:\\Program Files\\Common Files\\VST3"
        ]
        #else
        let vst3Paths: [String] = []
        #endif

        for path in vst3Paths {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            ) {
                pluginPaths.append(contentsOf: contents.filter { $0.pathExtension == "vst3" })
            }
        }

        return pluginPaths
    }
}
```

#### **Integration with AudioEngine:**

```swift
// Sources/EOEL/Audio/AudioEngine.swift

extension AudioEngine {

    /// Plugin host manager
    private(set) var pluginHost: PluginHostManager?


    /// Initialize plugin hosting
    func initializePluginHost() {
        pluginHost = PluginHostManager()

        Task {
            await pluginHost?.scanPlugins()
        }
    }


    /// Insert plugin on track
    func insertPlugin(_ descriptor: PluginHostManager.PluginDescriptor, onTrack trackID: UUID) async throws {
        guard let pluginHost = pluginHost else {
            throw AudioEngineError.pluginHostNotInitialized
        }

        let loadedPlugin = try await pluginHost.loadPlugin(descriptor: descriptor, onTrack: trackID)

        // Insert into audio graph
        // TODO: Insert into track's effect chain

        print("✅ Plugin inserted on track")
    }
}
```

**Deliverables:**
- ✅ Plugin scanning (AU/VST3)
- ✅ Plugin loading & instantiation
- ✅ Plugin UI hosting
- ✅ Parameter access

---

### **Week 3-4: Professional Mixer**

#### **Architecture:**

```swift
// Sources/EOEL/Audio/Mixer/MixerEngine.swift

import AVFoundation

/// Professional mixing console
@MainActor
class MixerEngine: ObservableObject {

    // MARK: - Published Properties

    /// All mixer channels
    @Published var channels: [MixerChannel] = []

    /// Master channel
    @Published var masterChannel: MasterChannel

    /// Metering enabled
    @Published var meteringEnabled: Bool = true


    // MARK: - Mixer Channel

    class MixerChannel: ObservableObject, Identifiable {
        let id = UUID()

        // Track reference
        let trackID: UUID
        let name: String

        // Controls
        @Published var volume: Float = 0.0        // dB (-60 to +6)
        @Published var pan: Float = 0.0           // -1.0 (L) to +1.0 (R)
        @Published var mute: Bool = false
        @Published var solo: Bool = false
        @Published var recordEnabled: Bool = false

        // Metering
        @Published var peakLevel: Float = -96.0   // dB
        @Published var rmsLevel: Float = -96.0    // dB

        // Send levels (to aux/FX buses)
        @Published var sendLevels: [SendLevel] = []

        // Insert effects
        @Published var inserts: [PluginHostManager.LoadedPlugin] = []

        // Audio nodes
        var playerNode: AVAudioPlayerNode?
        var mixerNode: AVAudioMixerNode?

        init(trackID: UUID, name: String) {
            self.trackID = trackID
            self.name = name
        }


        /// Apply volume change
        func setVolume(_ db: Float) {
            volume = db.clamped(to: -60...6)

            // Convert dB to linear gain
            let gain = pow(10.0, volume / 20.0)
            mixerNode?.outputVolume = gain
        }


        /// Apply pan change
        func setPan(_ position: Float) {
            pan = position.clamped(to: -1...1)
            mixerNode?.pan = pan
        }


        /// Toggle mute
        func toggleMute() {
            mute.toggle()
            mixerNode?.outputVolume = mute ? 0.0 : pow(10.0, volume / 20.0)
        }


        /// Toggle solo
        func toggleSolo() {
            solo.toggle()
            // TODO: Handle solo logic in mixer
        }
    }


    // MARK: - Master Channel

    class MasterChannel: ObservableObject {
        @Published var volume: Float = 0.0        // dB
        @Published var peakLevel: Float = -96.0   // dB
        @Published var rmsLevel: Float = -96.0    // dB

        // Limiter (always on master)
        @Published var limiterEnabled: Bool = true
        @Published var limiterThreshold: Float = -1.0  // dB

        var mixerNode: AVAudioMixerNode?


        func setVolume(_ db: Float) {
            volume = db.clamped(to: -60...6)
            let gain = pow(10.0, volume / 20.0)
            mixerNode?.outputVolume = gain
        }
    }


    // MARK: - Send Level

    struct SendLevel: Identifiable {
        let id = UUID()
        let busName: String
        var level: Float  // dB
    }


    // MARK: - Initialization

    init() {
        self.masterChannel = MasterChannel()
    }


    // MARK: - Channel Management

    /// Add a channel
    func addChannel(trackID: UUID, name: String) -> MixerChannel {
        let channel = MixerChannel(trackID: trackID, name: name)
        channels.append(channel)

        print("➕ Added mixer channel: \(name)")
        return channel
    }


    /// Remove a channel
    func removeChannel(_ channel: MixerChannel) {
        channels.removeAll { $0.id == channel.id }
    }


    // MARK: - Solo Logic

    /// Handle solo changes
    func updateSolo() {
        let anySolo = channels.contains { $0.solo }

        for channel in channels {
            if anySolo {
                // If any channel is soloed, mute all non-soloed
                channel.mixerNode?.outputVolume = channel.solo ?
                    pow(10.0, channel.volume / 20.0) : 0.0
            } else {
                // No solo, restore normal volumes
                channel.mixerNode?.outputVolume = channel.mute ?
                    0.0 : pow(10.0, channel.volume / 20.0)
            }
        }
    }


    // MARK: - Metering

    /// Update metering for all channels
    func updateMetering() {
        guard meteringEnabled else { return }

        for channel in channels {
            // Get metering data from AVAudioPlayerNode
            // TODO: Implement proper metering with AVAudioPCMBuffer

            // Placeholder
            channel.peakLevel = -20.0
            channel.rmsLevel = -25.0
        }

        // Master metering
        masterChannel.peakLevel = -10.0
        masterChannel.rmsLevel = -15.0
    }
}


// MARK: - Float Extension

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
```

#### **Mixer UI:**

```swift
// Sources/EOEL/Views/Mixer/MixerView.swift

import SwiftUI

struct MixerView: View {
    @EnvironmentObject var mixer: MixerEngine

    var body: some View {
        HStack(spacing: 0) {
            // Channel strips
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(mixer.channels) { channel in
                        ChannelStripView(channel: channel)
                            .frame(width: 80)
                    }
                }
                .padding()
            }

            // Master channel
            Divider()

            MasterChannelView(channel: mixer.masterChannel)
                .frame(width: 100)
        }
        .background(Color.black)
    }
}


struct ChannelStripView: View {
    @ObservedObject var channel: MixerEngine.MixerChannel

    var body: some View {
        VStack(spacing: 8) {
            // Name
            Text(channel.name)
                .font(.caption)
                .lineLimit(1)

            // Metering
            MeterView(peak: channel.peakLevel, rms: channel.rmsLevel)
                .frame(width: 20, height: 150)

            // Fader
            VStack {
                Slider(
                    value: $channel.volume,
                    in: -60...6,
                    step: 0.1
                ) {
                    Text("Volume")
                }
                .rotationEffect(.degrees(-90))
                .frame(width: 150, height: 30)

                Text("\(channel.volume, specifier: "%.1f") dB")
                    .font(.caption2)
            }
            .frame(height: 150)

            // Pan
            Knob(value: $channel.pan, range: -1...1)
                .frame(width: 40, height: 40)

            Text("Pan")
                .font(.caption2)

            // Buttons
            HStack {
                Button(action: { channel.toggleMute() }) {
                    Text("M")
                        .font(.caption)
                        .frame(width: 30, height: 25)
                        .background(channel.mute ? Color.red : Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }

                Button(action: { channel.toggleSolo() }) {
                    Text("S")
                        .font(.caption)
                        .frame(width: 30, height: 25)
                        .background(channel.solo ? Color.yellow : Color.gray.opacity(0.3))
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .padding(4)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
}


struct MeterView: View {
    let peak: Float
    let rms: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background
                Rectangle()
                    .fill(Color.black)

                // RMS
                Rectangle()
                    .fill(Color.green)
                    .frame(height: meterHeight(for: rms, in: geometry.size.height))

                // Peak
                Rectangle()
                    .fill(Color.yellow)
                    .frame(height: 2)
                    .offset(y: -meterHeight(for: peak, in: geometry.size.height))

                // Clip indicator
                if peak > -1.0 {
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 10)
                        .offset(y: -geometry.size.height + 10)
                }
            }
            .cornerRadius(4)
        }
    }

    private func meterHeight(for db: Float, in totalHeight: CGFloat) -> CGFloat {
        // -60 dB = 0%, 0 dB = 100%
        let normalized = (db + 60.0) / 60.0
        return CGFloat(normalized) * totalHeight
    }
}


struct Knob: View {
    @Binding var value: Float
    let range: ClosedRange<Float>

    @State private var angle: Double = 0.0

    var body: some View {
        Circle()
            .fill(Color.gray)
            .overlay(
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 15)
                    .offset(y: -12)
                    .rotationEffect(.degrees(angle))
            )
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let delta = Float(gesture.translation.height)
                        value -= delta * 0.01 * (range.upperBound - range.lowerBound)
                        value = max(range.lowerBound, min(range.upperBound, value))

                        // Update visual angle
                        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                        angle = Double(normalized) * 270.0 - 135.0
                    }
            )
            .onAppear {
                let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                angle = Double(normalized) * 270.0 - 135.0
            }
    }
}
```

**Deliverables:**
- ✅ Professional mixer engine
- ✅ Channel strip (Volume, Pan, Mute, Solo)
- ✅ Metering (Peak, RMS)
- ✅ Master channel with limiter
- ✅ Professional UI

---

### **Week 5-6: Basic Effects Suite**

```swift
// Sources/EOEL/Audio/Effects/BasicEffects.swift

import AVFoundation

// MARK: - Parametric EQ

class ParametricEQ: ObservableObject {

    struct Band: Identifiable {
        let id = UUID()
        var frequency: Float = 1000.0   // Hz
        var gain: Float = 0.0           // dB
        var q: Float = 1.0              // Q factor
        var enabled: Bool = true

        enum FilterType {
            case peak
            case lowShelf
            case highShelf
            case lowPass
            case highPass
        }
        var type: FilterType = .peak
    }

    @Published var bands: [Band] = [
        Band(frequency: 80, type: .lowShelf),
        Band(frequency: 250),
        Band(frequency: 1000),
        Band(frequency: 4000),
        Band(frequency: 8000),
        Band(frequency: 12000, type: .highShelf)
    ]

    private var eqNode: AVAudioUnitEQ

    init(bandCount: Int = 6) {
        eqNode = AVAudioUnitEQ(numberOfBands: bandCount)

        for (index, band) in bands.enumerated() {
            updateBand(index: index, band: band)
        }
    }

    func updateBand(index: Int, band: Band) {
        guard index < eqNode.bands.count else { return }

        let eqBand = eqNode.bands[index]
        eqBand.frequency = band.frequency
        eqBand.gain = band.gain
        eqBand.bandwidth = band.q
        eqBand.bypass = !band.enabled

        switch band.type {
        case .peak:
            eqBand.filterType = .parametric
        case .lowShelf:
            eqBand.filterType = .lowShelf
        case .highShelf:
            eqBand.filterType = .highShelf
        case .lowPass:
            eqBand.filterType = .lowPass
        case .highPass:
            eqBand.filterType = .highPass
        }
    }

    func getAudioUnit() -> AVAudioUnit {
        return eqNode
    }
}


// MARK: - Compressor

class Compressor: ObservableObject {

    @Published var threshold: Float = -20.0     // dB
    @Published var ratio: Float = 4.0           // 1:ratio
    @Published var attack: Float = 0.01         // seconds
    @Published var release: Float = 0.1         // seconds
    @Published var makeupGain: Float = 0.0      // dB
    @Published var enabled: Bool = true

    private let compressorNode = AVAudioUnitEffect(
        audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
    )

    func updateParameters() {
        // TODO: Set compressor parameters via AUParameter
        // This requires accessing the AudioUnit's parameter tree
    }

    func getAudioUnit() -> AVAudioUnit {
        return compressorNode
    }
}


// MARK: - Reverb

class Reverb: ObservableObject {

    @Published var wetDryMix: Float = 50.0      // 0-100%
    @Published var roomSize: Float = 0.5        // 0-1
    @Published var predelay: Float = 0.02       // seconds
    @Published var enabled: Bool = true

    enum ReverbType {
        case room
        case hall
        case plate
        case chamber
    }
    @Published var type: ReverbType = .hall

    private let reverbNode = AVAudioUnitReverb()

    init() {
        updateParameters()
    }

    func updateParameters() {
        reverbNode.wetDryMix = wetDryMix

        switch type {
        case .room:
            reverbNode.loadFactoryPreset(.smallRoom)
        case .hall:
            reverbNode.loadFactoryPreset(.largeHall)
        case .plate:
            reverbNode.loadFactoryPreset(.plate)
        case .chamber:
            reverbNode.loadFactoryPreset(.largeChamber)
        }
    }

    func getAudioUnit() -> AVAudioUnit {
        return reverbNode
    }
}


// MARK: - Delay

class Delay: ObservableObject {

    @Published var delayTime: Float = 0.5       // seconds
    @Published var feedback: Float = 50.0       // 0-100%
    @Published var wetDryMix: Float = 50.0      // 0-100%
    @Published var enabled: Bool = true
    @Published var tempoSync: Bool = false
    @Published var noteValue: NoteValue = .quarter

    enum NoteValue {
        case sixteenth
        case eighth
        case quarter
        case half
        case whole

        func duration(bpm: Float) -> Float {
            let beatDuration = 60.0 / bpm
            switch self {
            case .sixteenth: return beatDuration / 4
            case .eighth: return beatDuration / 2
            case .quarter: return beatDuration
            case .half: return beatDuration * 2
            case .whole: return beatDuration * 4
            }
        }
    }

    private let delayNode = AVAudioUnitDelay()

    func updateParameters(bpm: Float = 120.0) {
        if tempoSync {
            delayNode.delayTime = TimeInterval(noteValue.duration(bpm: bpm))
        } else {
            delayNode.delayTime = TimeInterval(delayTime)
        }
        delayNode.feedback = feedback
        delayNode.wetDryMix = wetDryMix
    }

    func getAudioUnit() -> AVAudioUnit {
        return delayNode
    }
}
```

**Deliverables:**
- ✅ Parametric EQ (6-band)
- ✅ Compressor
- ✅ Reverb (Room, Hall, Plate)
- ✅ Delay (with tempo sync)

---

### **Week 7-8: Export Engine**

```swift
// Sources/EOEL/Export/ExportEngine.swift

import AVFoundation

/// Professional export engine with multiple format support
class ExportEngine: ObservableObject {

    // MARK: - Export Formats

    enum ExportFormat {
        case wav(bitDepth: BitDepth)
        case mp3(bitrate: MP3Bitrate)
        case flac
        case aac(bitrate: AACBitrate)

        enum BitDepth: Int {
            case bit16 = 16
            case bit24 = 24
            case bit32 = 32
        }

        enum MP3Bitrate: Int {
            case kbps128 = 128
            case kbps192 = 192
            case kbps256 = 256
            case kbps320 = 320
        }

        enum AACBitrate: Int {
            case kbps128 = 128
            case kbps256 = 256
        }
    }


    // MARK: - Export Settings

    struct ExportSettings {
        var format: ExportFormat = .wav(bitDepth: .bit24)
        var sampleRate: Double = 48000.0
        var normalize: Bool = true
        var targetLUFS: Float = -14.0  // Spotify standard
        var dithering: Bool = true
        var metadata: Metadata = Metadata()

        struct Metadata {
            var title: String = ""
            var artist: String = ""
            var album: String = ""
            var year: Int?
            var genre: String = ""
            var isrc: String = ""
            var coverArt: Data?
        }
    }


    // MARK: - Export Progress

    @Published var isExporting: Bool = false
    @Published var progress: Float = 0.0
    @Published var currentOperation: String = ""


    // MARK: - Export Function

    func export(
        session: Session,
        to url: URL,
        settings: ExportSettings
    ) async throws {

        await MainActor.run {
            isExporting = true
            progress = 0.0
            currentOperation = "Preparing export..."
        }

        // 1. Render audio
        await MainActor.run { currentOperation = "Rendering audio..." }
        let renderedBuffer = try await renderSession(session)
        progress = 0.3

        // 2. Normalize (if enabled)
        if settings.normalize {
            await MainActor.run { currentOperation = "Normalizing..." }
            try await normalizeBuffer(renderedBuffer, targetLUFS: settings.targetLUFS)
            progress = 0.5
        }

        // 3. Convert format
        await MainActor.run { currentOperation = "Converting format..." }
        let audioFile = try await convertFormat(
            buffer: renderedBuffer,
            format: settings.format,
            sampleRate: settings.sampleRate,
            url: url
        )
        progress = 0.8

        // 4. Write metadata
        await MainActor.run { currentOperation = "Writing metadata..." }
        try await writeMetadata(to: audioFile, metadata: settings.metadata)
        progress = 1.0

        await MainActor.run {
            isExporting = false
            currentOperation = "Export complete!"
        }

        print("✅ Export complete: \(url.lastPathComponent)")
    }


    // MARK: - Render Session

    private func renderSession(_ session: Session) async throws -> AVAudioPCMBuffer {
        // TODO: Render all tracks, apply effects, mix down

        // Placeholder
        let format = AVAudioFormat(
            standardFormatWithSampleRate: 48000,
            channels: 2
        )!

        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(48000 * 180) // 3 min
        )!

        return buffer
    }


    // MARK: - Normalize

    private func normalizeBuffer(_ buffer: AVAudioPCMBuffer, targetLUFS: Float) async throws {
        // Implement LUFS loudness normalization (ITU-R BS.1770)
        // TODO: Calculate integrated LUFS, apply gain adjustment
    }


    // MARK: - Format Conversion

    private func convertFormat(
        buffer: AVAudioPCMBuffer,
        format: ExportFormat,
        sampleRate: Double,
        url: URL
    ) async throws -> AVAudioFile {

        let audioFormat: AVAudioFormat

        switch format {
        case .wav(let bitDepth):
            audioFormat = AVAudioFormat(
                commonFormat: bitDepth == .bit32 ? .pcmFormatFloat32 : .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: 2,
                interleaved: false
            )!

        case .mp3:
            // Use LAME encoder or iOS AVAssetWriter
            // TODO: Implement MP3 encoding
            fatalError("MP3 encoding not yet implemented")

        case .flac:
            // Use libFLAC
            // TODO: Implement FLAC encoding
            fatalError("FLAC encoding not yet implemented")

        case .aac:
            audioFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 2,
                interleaved: false
            )!
        }

        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: audioFormat.settings
        )

        try audioFile.write(from: buffer)

        return audioFile
    }


    // MARK: - Metadata

    private func writeMetadata(to file: AVAudioFile, metadata: ExportSettings.Metadata) async throws {
        // Write ID3 tags (for MP3) or other metadata formats
        // TODO: Implement metadata writing
    }
}
```

**Deliverables:**
- ✅ WAV export (16/24/32-bit)
- ✅ MP3 export (128-320 kbps)
- ✅ FLAC export
- ✅ AAC export
- ✅ Loudness normalization (LUFS)
- ✅ Metadata embedding

---

## 🎯 PHASE 1B: LIVE PERFORMANCE (Months 3-4)

### **Week 9-10: Ableton Link Integration**

```swift
// Sources/EOEL/Audio/Sync/AbletonLinkManager.swift

import AVFoundation

/// Ableton Link synchronization manager
class AbletonLinkManager: ObservableObject {

    // NOTE: This requires the Ableton Link SDK
    // Download from: https://github.com/Ableton/LinkKit

    @Published var isEnabled: Bool = false
    @Published var isConnected: Bool = false
    @Published var numPeers: Int = 0
    @Published var bpm: Float = 120.0
    @Published var quantum: Float = 4.0  // Beats per bar

    // TODO: Integrate Link SDK
    // private var linkRef: ABLLinkRef?

    func enable() {
        // TODO: Initialize Link
        isEnabled = true
        print("✅ Ableton Link enabled")
    }

    func disable() {
        // TODO: Cleanup Link
        isEnabled = false
        print("❌ Ableton Link disabled")
    }

    func setBPM(_ bpm: Float) {
        self.bpm = bpm
        // TODO: Set Link tempo
    }

    func getPhase() -> Double {
        // TODO: Get current phase from Link
        return 0.0
    }
}
```

**Deliverables:**
- ✅ Link SDK integration
- ✅ BPM sync
- ✅ Phase sync
- ✅ Peer detection

---

### **Week 11-12: Live Looping Engine**

```swift
// Sources/EOEL/Audio/Looping/LiveLoopEngine.swift

import AVFoundation

/// Live looping engine with overdub support
@MainActor
class LiveLoopEngine: ObservableObject {

    // MARK: - Loop State

    enum LoopState {
        case idle
        case recording
        case playing
        case overdubbing
    }

    @Published var state: LoopState = .idle
    @Published var loops: [Loop] = []
    @Published var currentLoopIndex: Int = 0


    // MARK: - Loop

    struct Loop: Identifiable {
        let id = UUID()
        var buffer: AVAudioPCMBuffer
        var length: AVAudioFrameCount
        var isPlaying: Bool = false
    }


    // MARK: - Settings

    @Published var quantize: Bool = true
    @Published var countIn: Bool = true
    @Published var maxLoops: Int = 8


    // MARK: - Audio Components

    private var audioEngine: AVAudioEngine
    private var recordingBuffer: AVAudioPCMBuffer?
    private var playerNodes: [AVAudioPlayerNode] = []


    init(audioEngine: AVAudioEngine) {
        self.audioEngine = audioEngine
    }


    // MARK: - Recording

    func startRecording() {
        guard loops.count < maxLoops else {
            print("⚠️ Max loops reached")
            return
        }

        state = .recording

        // TODO: Start recording from audio input
        // - Create buffer
        // - Start capturing audio
        // - Quantize to beat if enabled

        print("🔴 Recording loop...")
    }

    func stopRecording() {
        guard state == .recording else { return }

        // TODO: Stop recording
        // - Save buffer as new loop
        // - Start playback immediately

        state = .playing
        print("✅ Loop recorded")
    }


    // MARK: - Overdubbing

    func startOverdub() {
        guard !loops.isEmpty else { return }

        state = .overdubbing

        // TODO: Record on top of existing loop
        // - Mix new audio with loop

        print("🔴 Overdubbing...")
    }

    func stopOverdub() {
        state = .playing
        print("✅ Overdub complete")
    }


    // MARK: - Playback

    func togglePlayback() {
        // TODO: Play/pause all loops
    }

    func clear(loopIndex: Int) {
        // TODO: Remove loop
        loops.remove(at: loopIndex)
    }

    func clearAll() {
        loops.removeAll()
        state = .idle
    }


    // MARK: - Undo

    func undo() {
        // TODO: Undo last overdub or remove last loop
    }
}
```

**Deliverables:**
- ✅ Multi-track looping
- ✅ Overdub support
- ✅ Quantized recording
- ✅ Undo/Redo

---

## 📚 TECHNICAL RESOURCES

### **iOS Audio Programming:**
- AVFoundation Framework
- Audio Toolbox Framework
- Core Audio
- Accelerate Framework (DSP)

### **Plugin Hosting:**
- AudioUnit v3 (AUv3)
- VST3 SDK (desktop)
- JUCE Framework (cross-platform)

### **Third-Party SDKs:**
- Ableton Link SDK (sync)
- LAME (MP3 encoding)
- libFLAC (FLAC encoding)

### **Learning Resources:**
- "Learning Core Audio" book
- Apple's Audio Unit Programming Guide
- The Audio Programmer YouTube
- JUCE Forum & Tutorials

---

## ✅ SUCCESS CRITERIA

**Phase 1A Complete:**
- ✅ VST3/AU plugins can be loaded
- ✅ Professional mixer works
- ✅ Basic effects sound good
- ✅ Export works reliably
- ✅ Can produce complete song

**Phase 1B Complete:**
- ✅ Ableton Link syncs perfectly
- ✅ Live looping is tight
- ✅ Can perform live
- ✅ Zero audio dropouts

**Overall Phase 1:**
- ✅ Can replace GarageBand for basic production
- ✅ Professional audio quality
- ✅ Stable & reliable
- ✅ First 100 users happy

---

## 🚀 NEXT STEPS

1. Start with VST3/AU hosting (Week 1)
2. Build mixer UI (Week 3)
3. Implement effects (Week 5)
4. Test export pipeline (Week 7)
5. Integrate Ableton Link (Week 9)
6. Build live looping (Week 11)

**LET'S BUILD! 🎵**

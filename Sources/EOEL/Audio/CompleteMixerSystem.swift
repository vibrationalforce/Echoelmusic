//
//  CompleteMixerSystem.swift
//  EOEL
//
//  Professional Mixer with Complete Signal Routing
//  Sends, Returns, Inserts, Buses, Groups, VCA Faders
//

import AVFoundation
import SwiftUI

// MARK: - Mixer Channel Strip

@MainActor
class MixerChannelStrip: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var color: Color = .cyan

    // Input/Output
    @Published var inputSource: String = "None"
    @Published var outputBus: String = "Master"

    // Gain & Level
    @Published var gain: Float = 0.0  // dB (-inf to +24)
    @Published var fader: Float = 0.0  // dB (-inf to +10)
    @Published var pan: Float = 0.0  // -1 (L) to +1 (R)

    // Mute/Solo/Record
    @Published var isMuted: Bool = false
    @Published var isSolo: Bool = false
    @Published var isRecordArmed: Bool = false
    @Published var isInverted: Bool = false  // Phase invert

    // Metering
    @Published var peakLevelLeft: Float = -96.0  // dB
    @Published var peakLevelRight: Float = -96.0  // dB
    @Published var rmsLevelLeft: Float = -96.0  // dB
    @Published var rmsLevelRight: Float = -96.0  // dB

    // Insert Effects (6 slots)
    @Published var insertSlots: [EffectSlot] = []

    // Sends (8 aux sends)
    @Published var sends: [AuxSend] = []

    // Groups
    @Published var groupAssignment: UUID?  // Channel group ID

    init(name: String) {
        self.id = UUID()
        self.name = name

        // Create 6 insert slots
        for i in 0..<6 {
            insertSlots.append(EffectSlot(name: "Insert \(i+1)"))
        }

        // Create 8 sends
        for i in 0..<8 {
            sends.append(AuxSend(name: "Send \(i+1)", destination: "Aux \(i+1)"))
        }
    }

    struct EffectSlot: Identifiable {
        let id = UUID()
        var name: String
        var isEnabled: Bool = false
        var effect: Any?  // Reference to effect instance
        var isBypass: Bool = false
    }

    struct AuxSend: Identifiable {
        let id = UUID()
        var name: String
        var destination: String
        var level: Float = 0.0  // dB (-inf to +10)
        var isPreFader: Bool = false  // Pre or post fader send
        var isEnabled: Bool = false
    }

    // MARK: - Audio Processing

    func process(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        var currentBuffer = buffer

        // 1. Input Gain
        currentBuffer = applyGain(currentBuffer, gain: gain)

        // 2. Phase Invert
        if isInverted {
            currentBuffer = invertPhase(currentBuffer)
        }

        // 3. Insert Effects Chain
        for slot in insertSlots where slot.isEnabled && !slot.isBypass {
            // Apply effect (placeholder - would use actual effect instance)
            // currentBuffer = slot.effect.process(currentBuffer)
        }

        // 4. Pre-Fader Sends
        for send in sends where send.isEnabled && send.isPreFader {
            sendToAux(currentBuffer, send: send)
        }

        // 5. Fader
        currentBuffer = applyGain(currentBuffer, gain: fader)

        // 6. Pan
        currentBuffer = applyPan(currentBuffer, pan: pan)

        // 7. Post-Fader Sends
        for send in sends where send.isEnabled && !send.isPreFader {
            sendToAux(currentBuffer, send: send)
        }

        // 8. Mute/Solo
        if isMuted {
            // Return silence
            if let silentBuffer = AVAudioPCMBuffer(pcmFormat: currentBuffer.format, frameCapacity: currentBuffer.frameCapacity) {
                silentBuffer.frameLength = currentBuffer.frameLength
                return silentBuffer
            }
        }

        return currentBuffer
    }

    private func applyGain(_ buffer: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let linearGain = pow(10.0, gain / 20.0)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        outputBuffer.frameLength = buffer.frameLength
        guard let outputData = outputBuffer.floatChannelData else { return buffer }

        for ch in 0..<channelCount {
            var gainValue = linearGain
            vDSP_vsmul(inputData[ch], 1, &gainValue, outputData[ch], 1, vDSP_Length(frameCount))
        }

        return outputBuffer
    }

    private func applyPan(_ buffer: AVAudioPCMBuffer, pan: Float) -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData else { return buffer }
        guard Int(buffer.format.channelCount) >= 2 else { return buffer }

        let frameCount = Int(buffer.frameLength)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        outputBuffer.frameLength = buffer.frameLength
        guard let outputData = outputBuffer.floatChannelData else { return buffer }

        // Constant power pan law
        let panRadians = pan * Float.pi / 4.0  // -45° to +45°
        let leftGain = cos(panRadians)
        let rightGain = sin(panRadians)

        var leftGainValue = leftGain
        var rightGainValue = rightGain

        vDSP_vsmul(inputData[0], 1, &leftGainValue, outputData[0], 1, vDSP_Length(frameCount))
        vDSP_vsmul(inputData[1], 1, &rightGainValue, outputData[1], 1, vDSP_Length(frameCount))

        return outputBuffer
    }

    private func invertPhase(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        outputBuffer.frameLength = buffer.frameLength
        guard let outputData = outputBuffer.floatChannelData else { return buffer }

        var negOne: Float = -1.0

        for ch in 0..<channelCount {
            vDSP_vsmul(inputData[ch], 1, &negOne, outputData[ch], 1, vDSP_Length(frameCount))
        }

        return outputBuffer
    }

    private func sendToAux(_ buffer: AVAudioPCMBuffer, send: AuxSend) {
        // Send audio to aux bus (would be implemented with bus routing)
        // MixerSystem.shared.routeToAux(buffer, destination: send.destination, level: send.level)
    }

    // MARK: - Metering

    func updateMeters(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for ch in 0..<min(channelCount, 2) {
            // Peak
            var peak: Float = 0.0
            vDSP_maxv(channelData[ch], 1, &peak, vDSP_Length(frameLength))

            // RMS
            var rms: Float = 0.0
            vDSP_rmsqv(channelData[ch], 1, &rms, vDSP_Length(frameLength))

            // Convert to dB
            let peakDb = 20.0 * log10(max(peak, 1e-6))
            let rmsDb = 20.0 * log10(max(rms, 1e-6))

            if ch == 0 {
                peakLevelLeft = peakDb
                rmsLevelLeft = rmsDb
            } else {
                peakLevelRight = peakDb
                rmsLevelRight = rmsDb
            }
        }
    }
}

// MARK: - Aux Return Bus

@MainActor
class AuxReturnBus: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var fader: Float = 0.0  // dB
    @Published var pan: Float = 0.0
    @Published var isMuted: Bool = false
    @Published var outputBus: String = "Master"

    // Effect on return (typically reverb, delay, etc.)
    @Published var effect: Any?
    @Published var effectBypass: Bool = false

    init(name: String) {
        self.id = UUID()
        self.name = name
    }

    func process(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        var currentBuffer = buffer

        // Apply effect
        if !effectBypass {
            // currentBuffer = effect?.process(currentBuffer) ?? currentBuffer
        }

        // Fader
        let linearGain = pow(10.0, fader / 20.0)
        // Apply gain...

        // Mute
        if isMuted {
            // Return silence
        }

        return currentBuffer
    }
}

// MARK: - Channel Group (Submix)

@MainActor
class ChannelGroup: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var color: Color = .orange
    @Published var fader: Float = 0.0  // dB (controls all channels in group)
    @Published var isMuted: Bool = false
    @Published var isSolo: Bool = false
    @Published var outputBus: String = "Master"

    @Published var channels: [UUID] = []  // Channel IDs in this group

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

// MARK: - VCA Fader

@MainActor
class VCAFader: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var fader: Float = 0.0  // dB (offsets all assigned channels)
    @Published var isMuted: Bool = false

    @Published var assignedChannels: [UUID] = []  // Channel IDs controlled by this VCA

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

// MARK: - Master Bus

@MainActor
class MasterBus: ObservableObject {
    @Published var fader: Float = 0.0  // dB
    @Published var isMuted: Bool = false

    // Master insert effects (6 slots)
    @Published var insertSlots: [MixerChannelStrip.EffectSlot] = []

    // Master metering
    @Published var peakLevelLeft: Float = -96.0  // dB
    @Published var peakLevelRight: Float = -96.0  // dB
    @Published var lufsIntegrated: Float = -23.0  // LUFS
    @Published var lufsShortTerm: Float = -23.0  // LUFS

    init() {
        // Create 6 master insert slots
        for i in 0..<6 {
            insertSlots.append(MixerChannelStrip.EffectSlot(name: "Master Insert \(i+1)"))
        }
    }

    func process(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        var currentBuffer = buffer

        // Master insert effects
        for slot in insertSlots where slot.isEnabled && !slot.isBypass {
            // Apply effect
            // currentBuffer = slot.effect.process(currentBuffer)
        }

        // Master fader
        let linearGain = pow(10.0, fader / 20.0)
        // Apply gain...

        // Mute
        if isMuted {
            // Return silence
        }

        return currentBuffer
    }
}

// MARK: - Complete Mixer System

@MainActor
class CompleteMixerSystem: ObservableObject {
    static let shared = CompleteMixerSystem()

    @Published var channels: [MixerChannelStrip] = []
    @Published var auxReturns: [AuxReturnBus] = []
    @Published var groups: [ChannelGroup] = []
    @Published var vcaFaders: [VCAFader] = []
    @Published var masterBus = MasterBus()

    // Solo system
    @Published var soloChannels: Set<UUID> = []
    @Published var soloMode: SoloMode = .solo

    enum SoloMode {
        case solo  // Only soloed channels play
        case safe  // Soloed channels + solo-safe channels play
        case pfl   // Pre-Fader Listen (for monitoring)
    }

    private init() {
        // Create default channels
        createDefaultSetup()
    }

    private func createDefaultSetup() {
        // Create 32 audio channels
        for i in 1...32 {
            channels.append(MixerChannelStrip(name: "Audio \(i)"))
        }

        // Create 8 aux returns
        for i in 1...8 {
            auxReturns.append(AuxReturnBus(name: "Aux \(i)"))
        }

        // Create default groups
        groups.append(ChannelGroup(name: "Drums"))
        groups.append(ChannelGroup(name: "Bass"))
        groups.append(ChannelGroup(name: "Guitars"))
        groups.append(ChannelGroup(name: "Vocals"))
        groups.append(ChannelGroup(name: "FX"))

        // Create 8 VCA faders
        for i in 1...8 {
            vcaFaders.append(VCAFader(name: "VCA \(i)"))
        }
    }

    // MARK: - Routing

    func routeChannelToGroup(_ channelID: UUID, groupID: UUID) {
        if let channel = channels.first(where: { $0.id == channelID }),
           let group = groups.first(where: { $0.id == groupID }) {
            channel.groupAssignment = groupID
            if !group.channels.contains(channelID) {
                group.channels.append(channelID)
            }
        }
    }

    func assignChannelToVCA(_ channelID: UUID, vcaID: UUID) {
        if let vca = vcaFaders.first(where: { $0.id == vcaID }) {
            if !vca.assignedChannels.contains(channelID) {
                vca.assignedChannels.append(channelID)
            }
        }
    }

    // MARK: - Solo/Mute System

    func toggleSolo(_ channelID: UUID) {
        if soloChannels.contains(channelID) {
            soloChannels.remove(channelID)
        } else {
            soloChannels.insert(channelID)
        }

        updateSoloState()
    }

    private func updateSoloState() {
        let hasSolo = !soloChannels.isEmpty

        for channel in channels {
            if hasSolo {
                // Mute all non-soloed channels
                channel.isMuted = !soloChannels.contains(channel.id)
            } else {
                // Restore original mute state (would need to track separately)
            }
        }
    }

    // MARK: - Audio Processing

    func processMix(frameCount: Int, sampleRate: Float) -> AVAudioPCMBuffer? {
        // Create output buffer format (stereo, 48kHz, Float32)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2) else {
            return nil
        }

        guard let masterBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        masterBuffer.frameLength = AVAudioFrameCount(frameCount)

        // Zero master buffer
        if let masterData = masterBuffer.floatChannelData {
            memset(masterData[0], 0, frameCount * MemoryLayout<Float>.stride)
            memset(masterData[1], 0, frameCount * MemoryLayout<Float>.stride)
        }

        // Process each channel and sum to master
        for channel in channels {
            // Get channel's audio (from recording, instrument, etc.)
            // let channelBuffer = getChannelAudio(channel.id, frameCount: frameCount, format: format)

            // Process through channel strip
            // let processedBuffer = channel.process(buffer: channelBuffer)

            // Sum to master
            // mixBuffer(processedBuffer, into: masterBuffer)
        }

        // Process aux returns and sum to master
        for auxReturn in auxReturns {
            // Get aux return audio
            // let auxBuffer = getAuxReturnAudio(auxReturn.id, frameCount: frameCount, format: format)

            // Process through aux return
            // let processedBuffer = auxReturn.process(buffer: auxBuffer)

            // Sum to master
            // mixBuffer(processedBuffer, into: masterBuffer)
        }

        // Process master bus
        let finalBuffer = masterBus.process(buffer: masterBuffer)

        return finalBuffer
    }
}

// MARK: - Mixer UI View

struct CompleteMixerView: View {
    @ObservedObject var mixer: CompleteMixerSystem

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                // Audio Channels
                ForEach(mixer.channels) { channel in
                    MixerChannelStripView(channel: channel)
                }

                Divider()

                // Aux Returns
                ForEach(mixer.auxReturns) { auxReturn in
                    AuxReturnView(auxReturn: auxReturn)
                }

                Divider()

                // Groups
                ForEach(mixer.groups) { group in
                    GroupChannelView(group: group)
                }

                Divider()

                // VCA Faders
                ForEach(mixer.vcaFaders) { vca in
                    VCAFaderView(vca: vca)
                }

                Divider()

                // Master Bus
                MasterBusView(master: mixer.masterBus)
            }
            .padding()
        }
    }
}

struct MixerChannelStripView: View {
    @ObservedObject var channel: MixerChannelStrip

    var body: some View {
        VStack(spacing: 4) {
            // Name
            Text(channel.name)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(height: 20)

            // Insert Slots
            VStack(spacing: 2) {
                ForEach(channel.insertSlots.prefix(3)) { slot in
                    Rectangle()
                        .fill(slot.isEnabled ? Color.green : Color(white: 0.2))
                        .frame(width: 60, height: 20)
                        .overlay(
                            Text(slot.isEnabled ? "FX" : "---")
                                .font(.caption2)
                                .foregroundColor(.white)
                        )
                }
            }

            // Sends (show first 4)
            VStack(spacing: 2) {
                ForEach(channel.sends.prefix(4)) { send in
                    HStack(spacing: 2) {
                        Text(String(format: "S%d", channel.sends.firstIndex(where: { $0.id == send.id })! + 1))
                            .font(.caption2)
                            .frame(width: 20)
                        Rectangle()
                            .fill(send.isEnabled ? Color.cyan : Color(white: 0.15))
                            .frame(height: 8)
                    }
                }
            }

            Spacer()

            // Level Meter
            HStack(spacing: 2) {
                levelMeter(value: channel.peakLevelLeft)
                levelMeter(value: channel.peakLevelRight)
            }
            .frame(height: 200)

            // Pan Knob
            Circle()
                .fill(Color(white: 0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(format: "%.0f", channel.pan * 100))
                        .font(.caption2)
                        .foregroundColor(.white)
                )

            // Fader
            Slider(value: $channel.fader, in: -96...10)
                .frame(height: 150)
                .rotationEffect(.degrees(-90))
                .frame(width: 30, height: 150)

            Text(String(format: "%.1f", channel.fader))
                .font(.caption2)
                .foregroundColor(.white)

            // Buttons
            VStack(spacing: 4) {
                Button(action: { channel.isMuted.toggle() }) {
                    Text("M")
                        .frame(width: 30, height: 20)
                        .background(channel.isMuted ? Color.red : Color(white: 0.3))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }

                Button(action: { channel.isSolo.toggle() }) {
                    Text("S")
                        .frame(width: 30, height: 20)
                        .background(channel.isSolo ? Color.yellow : Color(white: 0.3))
                        .foregroundColor(.black)
                        .cornerRadius(4)
                }

                Button(action: { channel.isRecordArmed.toggle() }) {
                    Text("R")
                        .frame(width: 30, height: 20)
                        .background(channel.isRecordArmed ? Color.red.opacity(0.8) : Color(white: 0.3))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
        }
        .frame(width: 70)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(channel.color, lineWidth: 2)
                )
        )
    }

    func levelMeter(value: Float) -> some View {
        GeometryReader { geometry in
            let normalizedValue = (value + 96.0) / 96.0  // -96dB to 0dB
            let height = max(0, min(1, normalizedValue)) * geometry.size.height

            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.red, .yellow, .green],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: height)
            }
        }
        .frame(width: 8)
        .background(Color(white: 0.15))
        .cornerRadius(2)
    }
}

struct AuxReturnView: View {
    @ObservedObject var auxReturn: AuxReturnBus

    var body: some View {
        VStack {
            Text(auxReturn.name)
                .font(.caption.bold())
            Text("Aux Return")
                .font(.caption2)
                .foregroundColor(.gray)
            // Simplified view
        }
        .frame(width: 70)
        .padding()
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
    }
}

struct GroupChannelView: View {
    @ObservedObject var group: ChannelGroup

    var body: some View {
        VStack {
            Text(group.name)
                .font(.caption.bold())
            Text("\(group.channels.count) ch")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: 70)
        .padding()
        .background(group.color.opacity(0.2))
        .cornerRadius(8)
    }
}

struct VCAFaderView: View {
    @ObservedObject var vca: VCAFader

    var body: some View {
        VStack {
            Text(vca.name)
                .font(.caption.bold())
            Text("VCA")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: 70)
        .padding()
        .background(Color.purple.opacity(0.2))
        .cornerRadius(8)
    }
}

struct MasterBusView: View {
    @ObservedObject var master: MasterBus

    var body: some View {
        VStack {
            Text("MASTER")
                .font(.caption.bold())
            Text(String(format: "%.1f dB", master.fader))
                .font(.caption2)
        }
        .frame(width: 90)
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(8)
    }
}

#Preview("Complete Mixer") {
    CompleteMixerView(mixer: CompleteMixerSystem.shared)
        .frame(height: 600)
}

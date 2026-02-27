// MixerDSPKernel.swift
// Echoelmusic - Mixer DSP Processing Kernel
//
// Real-time audio buffer processing for ProMixEngine.
// Handles per-channel insert chains, volume/pan, sends, bus summing,
// and metering using actual AVAudioPCMBuffer data.
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import AVFoundation
import Accelerate

// MARK: - Mixer DSP Kernel

/// Real-time DSP kernel that processes audio buffers through the ProMixEngine signal chain.
///
/// Operates on pre-allocated stereo buffers at the session sample rate.
/// Each channel has its own buffer, insert chain (EchoelmusicNode instances),
/// and metering state. Sends, bus summing, and master output are all
/// computed from actual audio data.
///
/// Thread safety: All buffer processing happens on the caller's thread
/// (typically the audio render thread). Node instantiation and graph
/// changes happen on @MainActor.
@MainActor
final class MixerDSPKernel {

    // MARK: - Types

    /// Per-channel DSP state: buffer storage and insert node instances.
    struct ChannelDSP {
        /// The channel UUID this DSP state belongs to.
        let channelID: UUID

        /// Working audio buffer for this channel (stereo, session buffer size).
        var buffer: AVAudioPCMBuffer

        /// Instantiated EchoelmusicNode chain mapped from InsertSlots.
        var insertNodes: [UUID: EchoelmusicNode]  // InsertSlot.id → node

        /// Ordered insert slot IDs for processing sequence.
        var insertOrder: [UUID]
    }

    // MARK: - Properties

    /// Per-channel DSP state keyed by channel UUID.
    private(set) var channelDSPs: [UUID: ChannelDSP] = [:]

    /// Audio format for all buffers.
    let format: AVAudioFormat

    /// Session buffer size in frames.
    let bufferSize: AVAudioFrameCount

    /// Session sample rate.
    let sampleRate: Double

    /// Master output buffer (stereo, session buffer size).
    private(set) var masterBuffer: AVAudioPCMBuffer

    /// Scratch buffer for send mixing and intermediate operations.
    private var scratchBuffer: AVAudioPCMBuffer

    /// Whether the kernel has been prepared.
    private(set) var isPrepared: Bool = false

    // MARK: - Initialization

    /// Creates a new MixerDSPKernel with the given audio configuration.
    ///
    /// - Parameters:
    ///   - sampleRate: Session sample rate in Hz.
    ///   - bufferSize: Audio buffer size in frames.
    init(sampleRate: Double, bufferSize: Int) {
        self.sampleRate = sampleRate
        self.bufferSize = AVAudioFrameCount(bufferSize)

        // Standard stereo interleaved format
        self.format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        self.masterBuffer = MixerDSPKernel.createBuffer(format: format, frameCount: AVAudioFrameCount(bufferSize))
        self.scratchBuffer = MixerDSPKernel.createBuffer(format: format, frameCount: AVAudioFrameCount(bufferSize))
    }

    // MARK: - Channel Management

    /// Allocates DSP resources for a channel.
    func addChannel(id: UUID) {
        guard channelDSPs[id] == nil else { return }

        let buffer = MixerDSPKernel.createBuffer(format: format, frameCount: bufferSize)
        let dsp = ChannelDSP(
            channelID: id,
            buffer: buffer,
            insertNodes: [:],
            insertOrder: []
        )
        channelDSPs[id] = dsp
    }

    /// Releases DSP resources for a channel.
    func removeChannel(id: UUID) {
        if let dsp = channelDSPs[id] {
            for node in dsp.insertNodes.values {
                node.stop()
            }
        }
        channelDSPs.removeValue(forKey: id)
    }

    // MARK: - Insert Chain Management

    /// Synchronizes the insert node chain for a channel with its InsertSlot configuration.
    ///
    /// Creates new nodes for added inserts, removes nodes for deleted inserts,
    /// and preserves existing nodes (with their state) for unchanged inserts.
    func syncInsertChain(channelID: UUID, inserts: [InsertSlot]) {
        guard var dsp = channelDSPs[channelID] else { return }

        let currentIDs = Set(dsp.insertNodes.keys)
        let targetIDs = Set(inserts.map { $0.id })

        // Remove nodes for deleted inserts
        for removedID in currentIDs.subtracting(targetIDs) {
            dsp.insertNodes[removedID]?.stop()
            dsp.insertNodes.removeValue(forKey: removedID)
        }

        // Add nodes for new inserts
        for insert in inserts where !currentIDs.contains(insert.id) {
            if let node = createNode(for: insert) {
                if isPrepared {
                    node.prepare(sampleRate: sampleRate, maxFrames: bufferSize)
                    node.start()
                }
                dsp.insertNodes[insert.id] = node
            }
        }

        // Update insert processing order
        dsp.insertOrder = inserts.map { $0.id }

        channelDSPs[channelID] = dsp
    }

    // MARK: - Audio Processing

    /// Processes one block of audio through the entire mixer signal chain.
    ///
    /// This is the main DSP entry point. It:
    /// 1. Clears all bus/master buffers
    /// 2. Processes each channel's insert chain
    /// 3. Applies phase invert, volume, and pan
    /// 4. Routes pre/post-fader sends to aux bus buffers
    /// 5. Sums channel outputs into their destination (bus or master)
    /// 6. Processes bus channel inserts and routes to master
    /// 7. Processes master channel inserts
    /// 8. Computes real metering from actual buffer data
    ///
    /// - Parameters:
    ///   - channels: Current channel strip states (from ProMixEngine).
    ///   - masterChannel: The master channel strip.
    ///   - inputBuffers: Per-channel input audio buffers keyed by channel UUID.
    ///                   Channels without an input buffer use their existing (zeroed) buffer.
    ///   - frameCount: Number of frames to process this block.
    /// - Returns: The processed master output buffer.
    @discardableResult
    func processBlock(
        channels: inout [ChannelStrip],
        masterChannel: inout ChannelStrip,
        inputBuffers: [UUID: AVAudioPCMBuffer],
        frameCount: Int
    ) -> AVAudioPCMBuffer {
        let frames = min(Int(bufferSize), frameCount)
        guard frames > 0 else { return masterBuffer }

        // Step 0: Clear master and all bus/aux channel buffers
        clearBuffer(masterBuffer, frameCount: frames)
        for (channelID, _) in channelDSPs {
            // Only clear bus/aux buffers (they accumulate from sends)
            if let channel = channels.first(where: { $0.id == channelID }),
               channel.type == .aux || channel.type == .bus {
                clearBuffer(channelDSPs[channelID]!.buffer, frameCount: frames)
            }
        }

        // Step 1: Determine solo state
        let anySoloed = channels.contains { $0.solo }

        // Step 2: Process audio-type channels (audio, instrument) first
        for i in channels.indices {
            let channel = channels[i]
            guard channel.type == .audio || channel.type == .instrument else { continue }

            let isAudible = !channel.mute && (!anySoloed || channel.solo)

            // Copy input buffer into channel DSP buffer (or zero it)
            if let inputBuffer = inputBuffers[channel.id],
               var dsp = channelDSPs[channel.id] {
                copyBuffer(from: inputBuffer, to: dsp.buffer, frameCount: frames)
                channelDSPs[channel.id] = dsp
            } else if channelDSPs[channel.id] != nil {
                clearBuffer(channelDSPs[channel.id]!.buffer, frameCount: frames)
            }

            guard isAudible, var dsp = channelDSPs[channel.id] else {
                channels[i].metering = MeterState()
                continue
            }

            // Process insert chain
            processInsertChain(dsp: &dsp, inserts: channel.inserts, frameCount: frames)
            channelDSPs[channel.id] = dsp

            // Phase invert
            if channel.phaseInvert {
                invertPhase(dsp.buffer, frameCount: frames)
            }

            // Pre-fader sends
            for send in channel.sends where send.isEnabled && send.isPreFader {
                guard let destID = send.destinationID,
                      channelDSPs[destID] != nil else { continue }
                mixInto(
                    destination: &channelDSPs[destID]!.buffer,
                    source: dsp.buffer,
                    gain: send.level,
                    frameCount: frames
                )
            }

            // Apply volume fader + stereo pan (equal-power pan law)
            let (gainL, gainR) = equalPowerPan(pan: channel.pan, volume: channel.volume)
            applyGain(dsp.buffer, gainL: gainL, gainR: gainR, frameCount: frames)

            // Post-fader sends
            for send in channel.sends where send.isEnabled && !send.isPreFader {
                guard let destID = send.destinationID,
                      channelDSPs[destID] != nil else { continue }
                mixInto(
                    destination: &channelDSPs[destID]!.buffer,
                    source: dsp.buffer,
                    gain: send.level,
                    frameCount: frames
                )
            }

            // Update real metering
            channels[i].metering = computeMetering(
                buffer: dsp.buffer,
                frameCount: frames,
                previousPeakHold: channels[i].metering.peakHold
            )

            // Route to output destination (bus or master)
            let destBuffer: UnsafeMutablePointer<AVAudioPCMBuffer>
            if let outputDest = channel.outputDestination,
               outputDest != masterChannel.id,
               channelDSPs[outputDest] != nil {
                mixInto(
                    destination: &channelDSPs[outputDest]!.buffer,
                    source: dsp.buffer,
                    gain: 1.0,
                    frameCount: frames
                )
            } else {
                // Route to master
                mixInto(destination: &masterBuffer, source: dsp.buffer, gain: 1.0, frameCount: frames)
            }
        }

        // Step 3: Process bus/aux channels (they have accumulated send/routed audio)
        for i in channels.indices {
            let channel = channels[i]
            guard channel.type == .aux || channel.type == .bus else { continue }

            let isAudible = !channel.mute && (!anySoloed || channel.solo)
            guard isAudible, var dsp = channelDSPs[channel.id] else {
                channels[i].metering = MeterState()
                continue
            }

            // Process bus insert chain (e.g., reverb on aux bus)
            processInsertChain(dsp: &dsp, inserts: channel.inserts, frameCount: frames)
            channelDSPs[channel.id] = dsp

            // Apply bus volume + pan
            let (gainL, gainR) = equalPowerPan(pan: channel.pan, volume: channel.volume)
            applyGain(dsp.buffer, gainL: gainL, gainR: gainR, frameCount: frames)

            // Update metering
            channels[i].metering = computeMetering(
                buffer: dsp.buffer,
                frameCount: frames,
                previousPeakHold: channels[i].metering.peakHold
            )

            // Route bus output to master
            mixInto(destination: &masterBuffer, source: dsp.buffer, gain: 1.0, frameCount: frames)
        }

        // Step 4: Process master channel inserts
        if var masterDSP = channelDSPs[masterChannel.id] {
            copyBuffer(from: masterBuffer, to: masterDSP.buffer, frameCount: frames)
            processInsertChain(dsp: &masterDSP, inserts: masterChannel.inserts, frameCount: frames)
            copyBuffer(from: masterDSP.buffer, to: masterBuffer, frameCount: frames)
            channelDSPs[masterChannel.id] = masterDSP
        }

        // Apply master volume
        let masterGain = masterChannel.mute ? Float(0) : masterChannel.volume
        applyGain(masterBuffer, gainL: masterGain, gainR: masterGain, frameCount: frames)

        // Step 5: Master metering
        masterChannel.metering = computeMetering(
            buffer: masterBuffer,
            frameCount: frames,
            previousPeakHold: masterChannel.metering.peakHold
        )

        return masterBuffer
    }

    // MARK: - Lifecycle

    /// Prepares all channel nodes for processing.
    func prepare() {
        for (_, dsp) in channelDSPs {
            for node in dsp.insertNodes.values {
                node.prepare(sampleRate: sampleRate, maxFrames: bufferSize)
                node.start()
            }
        }
        isPrepared = true
    }

    /// Stops all channel nodes.
    func stop() {
        for (_, dsp) in channelDSPs {
            for node in dsp.insertNodes.values {
                node.stop()
            }
        }
        isPrepared = false
    }

    /// Resets all channel nodes and clears buffers.
    func reset() {
        for (channelID, dsp) in channelDSPs {
            for node in dsp.insertNodes.values {
                node.reset()
            }
            clearBuffer(dsp.buffer, frameCount: Int(bufferSize))
        }
        clearBuffer(masterBuffer, frameCount: Int(bufferSize))
    }

    // MARK: - Private: Insert Chain Processing

    /// Processes audio through a channel's insert node chain.
    private func processInsertChain(dsp: inout ChannelDSP, inserts: [InsertSlot], frameCount: Int) {
        let time = AVAudioTime(sampleTime: 0, atRate: sampleRate)

        for insert in inserts {
            guard insert.isEnabled,
                  let node = dsp.insertNodes[insert.id],
                  !node.isBypassed else { continue }

            // Sync parameters from InsertSlot to node
            for (key, value) in insert.parameters {
                node.setParameter(name: key, value: value)
            }

            // Process: dry/wet blend
            if insert.dryWet < 1.0 {
                // Copy dry signal to scratch
                copyBuffer(from: dsp.buffer, to: scratchBuffer, frameCount: frameCount)

                // Process wet signal
                let _ = node.process(dsp.buffer, time: time)

                // Blend: output = dry * (1 - wet) + wet * wet_amount
                blendBuffers(
                    dry: scratchBuffer,
                    wet: dsp.buffer,
                    amount: insert.dryWet,
                    frameCount: frameCount
                )
            } else {
                // Fully wet — process in-place
                let _ = node.process(dsp.buffer, time: time)
            }
        }
    }

    // MARK: - Private: Node Factory

    /// Creates an EchoelmusicNode instance for an InsertSlot.
    private func createNode(for insert: InsertSlot) -> EchoelmusicNode? {
        switch insert.effectType {
        // EQ types → FilterNode
        case .parametricEQ, .graphicEQ, .midSideEQ, .dynamicEQ:
            return FilterNode()

        // Dynamics → CompressorNode
        case .compressor, .multibandCompressor, .limiter, .gate,
             .deEsser, .transientShaper, .sidechain:
            return CompressorNode()

        // Reverb types → ReverbNode
        case .convolutionReverb, .algorithmicReverb, .plateReverb,
             .springReverb, .shimmerReverb:
            return ReverbNode()

        // Delay types → DelayNode
        case .stereoDelay, .pingPongDelay, .tapeDelay, .analogDelay:
            return DelayNode()

        // Saturation/Lo-Fi → FilterNode (harmonic coloring via resonance)
        case .saturation, .tapeEmulation, .tubeWarmth, .bitCrusher, .lofi:
            return FilterNode()

        // Modulation → DelayNode (modulated delay)
        case .chorus, .flanger, .phaser, .tremolo, .rotarySpeaker:
            return DelayNode()

        // Pitch → FilterNode (placeholder)
        case .pitchShift, .harmonizer, .vocoder:
            return FilterNode()

        // Stereo → pass-through (pan law handles width)
        case .stereoWidener:
            return nil
        }
    }

    // MARK: - Private: Buffer Operations (vDSP-accelerated)

    /// Creates a new zeroed stereo buffer.
    private static func createBuffer(format: AVAudioFormat, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        // Zero the buffer
        if let channelData = buffer.floatChannelData {
            for ch in 0..<Int(format.channelCount) {
                vDSP_vclr(channelData[ch], 1, vDSP_Length(frameCount))
            }
        }
        return buffer
    }

    /// Clears (zeros) a buffer.
    private func clearBuffer(_ buffer: AVAudioPCMBuffer, frameCount: Int) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = vDSP_Length(min(frameCount, Int(buffer.frameCapacity)))
        for ch in 0..<Int(buffer.format.channelCount) {
            vDSP_vclr(channelData[ch], 1, frames)
        }
        buffer.frameLength = AVAudioFrameCount(frames)
    }

    /// Copies audio data from one buffer to another.
    private func copyBuffer(from source: AVAudioPCMBuffer, to destination: AVAudioPCMBuffer, frameCount: Int) {
        guard let srcData = source.floatChannelData,
              let dstData = destination.floatChannelData else { return }
        let frames = min(frameCount, Int(source.frameLength), Int(destination.frameCapacity))
        let channelCount = min(Int(source.format.channelCount), Int(destination.format.channelCount))
        for ch in 0..<channelCount {
            memcpy(dstData[ch], srcData[ch], frames * MemoryLayout<Float>.size)
        }
        destination.frameLength = AVAudioFrameCount(frames)
    }

    /// Adds (mixes) source buffer into destination buffer with a gain multiplier.
    private func mixInto(destination: inout AVAudioPCMBuffer, source: AVAudioPCMBuffer, gain: Float, frameCount: Int) {
        guard let dstData = destination.floatChannelData,
              let srcData = source.floatChannelData else { return }
        let frames = vDSP_Length(min(frameCount, Int(source.frameLength), Int(destination.frameCapacity)))
        let channelCount = min(Int(source.format.channelCount), Int(destination.format.channelCount))

        var g = gain
        for ch in 0..<channelCount {
            // destination[ch] += source[ch] * gain
            vDSP_vsma(srcData[ch], 1, &g, dstData[ch], 1, dstData[ch], 1, frames)
        }
    }

    /// Applies per-channel gain (for volume + pan).
    private func applyGain(_ buffer: AVAudioPCMBuffer, gainL: Float, gainR: Float, frameCount: Int) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = vDSP_Length(min(frameCount, Int(buffer.frameLength)))
        let channelCount = Int(buffer.format.channelCount)

        if channelCount >= 2 {
            var gL = gainL
            var gR = gainR
            vDSP_vsmul(channelData[0], 1, &gL, channelData[0], 1, frames)
            vDSP_vsmul(channelData[1], 1, &gR, channelData[1], 1, frames)
        } else if channelCount == 1 {
            // Mono: use average gain
            var g = (gainL + gainR) * 0.5
            vDSP_vsmul(channelData[0], 1, &g, channelData[0], 1, frames)
        }
    }

    /// Inverts the phase (multiplies by -1) of all channels.
    private func invertPhase(_ buffer: AVAudioPCMBuffer, frameCount: Int) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = vDSP_Length(min(frameCount, Int(buffer.frameLength)))
        for ch in 0..<Int(buffer.format.channelCount) {
            vDSP_vneg(channelData[ch], 1, channelData[ch], 1, frames)
        }
    }

    /// Blends dry and wet buffers: result = dry * (1 - amount) + wet * amount.
    /// Result is written to the wet buffer.
    private func blendBuffers(dry: AVAudioPCMBuffer, wet: AVAudioPCMBuffer, amount: Float, frameCount: Int) {
        guard let dryData = dry.floatChannelData,
              let wetData = wet.floatChannelData else { return }
        let frames = vDSP_Length(min(frameCount, Int(dry.frameLength), Int(wet.frameLength)))
        let channelCount = min(Int(dry.format.channelCount), Int(wet.format.channelCount))

        var dryAmount = 1.0 - amount
        var wetAmount = amount

        for ch in 0..<channelCount {
            // wet[ch] = dry[ch] * dryAmount + wet[ch] * wetAmount
            // Using two vDSP calls: scale wet, then add scaled dry
            vDSP_vsmul(wetData[ch], 1, &wetAmount, wetData[ch], 1, frames)
            vDSP_vsma(dryData[ch], 1, &dryAmount, wetData[ch], 1, wetData[ch], 1, frames)
        }
    }

    // MARK: - Private: Pan Law

    /// Computes equal-power stereo pan gains.
    ///
    /// Uses constant-power pan law: `L = cos(θ)`, `R = sin(θ)` where θ = 0..π/2.
    /// At center (pan=0): L ≈ 0.707, R ≈ 0.707 (−3 dB each, sums to 0 dB).
    ///
    /// - Parameters:
    ///   - pan: Pan position from -1 (hard left) to +1 (hard right).
    ///   - volume: Channel fader volume (0-1).
    /// - Returns: (gainL, gainR) tuple for left and right channels.
    func equalPowerPan(pan: Float, volume: Float) -> (Float, Float) {
        // Map pan from [-1, 1] to [0, π/2]
        let theta = (pan + 1.0) * 0.5 * Float.pi * 0.5
        let gainL = cos(theta) * volume
        let gainR = sin(theta) * volume
        return (gainL, gainR)
    }

    // MARK: - Private: Metering

    /// Computes real peak/RMS metering from buffer data.
    private func computeMetering(
        buffer: AVAudioPCMBuffer,
        frameCount: Int,
        previousPeakHold: Float
    ) -> MeterState {
        guard let channelData = buffer.floatChannelData,
              buffer.format.channelCount >= 2 else {
            return MeterState()
        }

        let frames = vDSP_Length(min(frameCount, Int(buffer.frameLength)))
        guard frames > 0 else { return MeterState() }

        // Peak detection (L and R)
        var peakL: Float = 0
        var peakR: Float = 0
        vDSP_maxmgv(channelData[0], 1, &peakL, frames)
        vDSP_maxmgv(channelData[1], 1, &peakR, frames)
        let peak = max(peakL, peakR)

        // RMS (L and R averaged)
        var rmsL: Float = 0
        var rmsR: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rmsL, frames)
        vDSP_rmsqv(channelData[1], 1, &rmsR, frames)
        let rms = (rmsL + rmsR) * 0.5

        // Peak hold with decay (≈3 dB/s at 60 Hz update rate)
        let peakHold = max(peak, previousPeakHold * 0.995)

        // Phase correlation: Σ(L*R) / sqrt(Σ(L²) * Σ(R²))
        var correlation: Float = 1.0
        if frames > 0 {
            var dotProduct: Float = 0
            vDSP_dotpr(channelData[0], 1, channelData[1], 1, &dotProduct, frames)

            var sumSqL: Float = 0
            var sumSqR: Float = 0
            vDSP_svesq(channelData[0], 1, &sumSqL, frames)
            vDSP_svesq(channelData[1], 1, &sumSqR, frames)

            let denominator = sqrt(sumSqL * sumSqR)
            if denominator > 1e-10 {
                correlation = dotProduct / denominator
            }
        }

        return MeterState(
            peak: peak,
            rms: rms,
            peakHold: peakHold,
            isClipping: peak > 0.99,
            phaseCorrelation: correlation
        )
    }
}

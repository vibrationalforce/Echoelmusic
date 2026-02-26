// InterAppAudioManager.swift
// Echoelmusic
//
// Inter-App Audio (IAA) support for iOS music production workflows.
// Enables Echoelmusic to act as IAA instrument or effect hosted by
// DAWs like GarageBand, Cubasis, AUM, BeatMaker, etc.
//
// NOTE: IAA is deprecated since iOS 14 in favor of AUv3, but many
// legacy hosts still use it. We support both for maximum compatibility.

#if os(iOS)
import Foundation
import UIKit
import AudioToolbox
import AVFoundation
import Combine

// MARK: - IAA Node Type

/// IAA node type — instrument generates audio, effect processes it
public enum IAANodeType {
    case instrument   // kAudioUnitType_RemoteInstrument
    case effect       // kAudioUnitType_RemoteEffect

    var audioUnitType: OSType {
        switch self {
        case .instrument: return kAudioUnitType_RemoteInstrument
        case .effect:     return kAudioUnitType_RemoteEffect
        }
    }
}

// MARK: - IAA State

/// Current IAA connection state
public enum IAAConnectionState: String {
    case disconnected = "Disconnected"
    case connecting   = "Connecting"
    case connected    = "Connected"
    case error        = "Error"
}

// MARK: - Inter-App Audio Manager

/// Manages Inter-App Audio connections for music production integration.
/// Supports both instrument (generator) and effect (processor) modes.
@MainActor
public final class InterAppAudioManager: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var connectionState: IAAConnectionState = .disconnected
    @Published public private(set) var hostAppName: String?
    @Published public private(set) var isHostConnected: Bool = false
    @Published public private(set) var hostIcon: CGImage?
    @Published public var nodeType: IAANodeType = .instrument

    // MARK: - Audio Components

    private var audioUnit: AudioUnit?
    private let audioEngine = AVAudioEngine()
    private var componentDescription: AudioComponentDescription

    // MARK: - MIDI

    /// MIDI callback for instrument mode
    public var onMIDIEvent: ((UInt8, UInt8, UInt8) -> Void)?

    // MARK: - Transport

    /// Host transport state (from host DAW)
    @Published public private(set) var hostTempo: Double = 120.0
    @Published public private(set) var isHostPlaying: Bool = false
    @Published public private(set) var hostBeatPosition: Double = 0.0

    // MARK: - Initialization

    /// Initialize IAA manager
    /// - Parameter nodeType: Whether to register as instrument or effect
    public init(nodeType: IAANodeType = .instrument) {
        self.nodeType = nodeType

        // Build AudioComponentDescription
        self.componentDescription = AudioComponentDescription(
            componentType: nodeType.audioUnitType,
            componentSubType: fourCharCodeIAA("Esyn"),
            componentManufacturer: fourCharCodeIAA("Echo"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        setupAudioSession()
        registerNotifications()
    }

    deinit {
        // Nonisolated cleanup — cannot call @MainActor methods from deinit
        if let au = audioUnit {
            AudioUnitUninitialize(au)
            AudioComponentInstanceDispose(au)
        }
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth]
            )
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration(0.005) // 5ms latency target
            try session.setActive(true)
        } catch {
            log.log(.error, category: .audio, "IAA: Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Connection

    /// Publish this app as an IAA node (instrument or effect)
    public func publish() {
        connectionState = .connecting

        // Register the audio component
        var desc = componentDescription
        let component = AudioComponentFindNext(nil, &desc)

        guard component != nil else {
            log.log(.error, category: .audio, "IAA: No matching audio component found")
            connectionState = .error
            return
        }

        // Create the audio unit
        var audioUnitRef: AudioUnit?
        let status = AudioComponentInstanceNew(component!, &audioUnitRef)

        guard status == noErr, let au = audioUnitRef else {
            log.log(.error, category: .audio, "IAA: Failed to create audio unit (status: \(status))")
            connectionState = .error
            return
        }

        self.audioUnit = au

        // Set render callback for instrument mode
        if nodeType == .instrument {
            var callbackStruct = AURenderCallbackStruct(
                inputProc: instrumentRenderCallback,
                inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
            )
            AudioUnitSetProperty(
                au,
                kAudioUnitProperty_SetRenderCallback,
                kAudioUnitScope_Global,
                0,
                &callbackStruct,
                UInt32(MemoryLayout<AURenderCallbackStruct>.size)
            )
        }

        // Initialize
        let initStatus = AudioUnitInitialize(au)
        guard initStatus == noErr else {
            log.log(.error, category: .audio, "IAA: Failed to initialize audio unit (status: \(initStatus))")
            connectionState = .error
            return
        }

        connectionState = .connected
        checkHostConnection()
        log.log(.info, category: .audio, "IAA: Published as \(nodeType == .instrument ? "instrument" : "effect")")
    }

    /// Disconnect from IAA host
    public func disconnect() {
        if let au = audioUnit {
            AudioUnitUninitialize(au)
            AudioComponentInstanceDispose(au)
            audioUnit = nil
        }
        connectionState = .disconnected
        isHostConnected = false
        hostAppName = nil
        log.log(.info, category: .audio, "IAA: Disconnected")
    }

    // MARK: - Host Info

    /// Check if connected to a host app
    public func checkHostConnection() {
        guard let au = audioUnit else { return }

        // Check if we have a host
        var connectedState: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioUnitGetProperty(
            au,
            kAudioUnitProperty_IsInterAppConnected,
            kAudioUnitScope_Global,
            0,
            &connectedState,
            &size
        )

        if status == noErr {
            isHostConnected = connectedState != 0
        }

        // Get host icon
        if isHostConnected {
            var iconRef: Unmanaged<CGImage>?
            var iconSize = UInt32(MemoryLayout<Unmanaged<CGImage>>.size)
            let iconStatus = AudioUnitGetProperty(
                au,
                kAudioOutputUnitProperty_HostIcon,
                kAudioUnitScope_Global,
                0,
                &iconRef,
                &iconSize
            )
            if iconStatus == noErr {
                hostIcon = iconRef?.takeRetainedValue()
            }
        }
    }

    /// Navigate to host app (switch back to DAW)
    public func switchToHostApp() {
        guard let au = audioUnit else { return }

        var url: Unmanaged<CFURL>?
        var size = UInt32(MemoryLayout<Unmanaged<CFURL>>.size)
        let status = AudioUnitGetProperty(
            au,
            kAudioUnitProperty_PeerURL,
            kAudioUnitScope_Global,
            0,
            &url,
            &size
        )

        if status == noErr, let hostURL = url?.takeRetainedValue() as URL? {
            UIApplication.shared.open(hostURL)
        }
    }

    // MARK: - Transport

    /// Query host transport state (tempo, play state, position)
    public func updateHostTransport() {
        guard let au = audioUnit else { return }

        var callbackInfo = HostCallbackInfo()
        var size = UInt32(MemoryLayout<HostCallbackInfo>.size)

        let status = AudioUnitGetProperty(
            au,
            kAudioUnitProperty_HostCallbacks,
            kAudioUnitScope_Global,
            0,
            &callbackInfo,
            &size
        )

        if status == noErr {
            // Get tempo
            var tempo: Float64 = 120
            if let beatAndTempo = callbackInfo.beatAndTempoProc {
                var beat: Float64 = 0
                beatAndTempo(callbackInfo.hostUserData, &beat, &tempo)
                hostTempo = tempo
                hostBeatPosition = beat
            }

            // Get transport state
            if let transportState = callbackInfo.transportStateProc2 {
                var playing: DarwinBoolean = false
                var recording: DarwinBoolean = false
                var looping: DarwinBoolean = false
                var currentPosition: Float64 = 0
                var cycleStart: Float64 = 0
                var cycleEnd: Float64 = 0
                transportState(
                    callbackInfo.hostUserData,
                    &playing, &recording, &looping,
                    &currentPosition, &cycleStart, &cycleEnd
                )
                isHostPlaying = playing.boolValue
                hostBeatPosition = currentPosition
            }
        }
    }

    // MARK: - Notifications

    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            Task { @MainActor in
                switch type {
                case .began:
                    self?.connectionState = .disconnected
                case .ended:
                    self?.setupAudioSession()
                    self?.publish()
                @unknown default:
                    break
                }
            }
        }
    }
}

// MARK: - Render Callback (C function)

/// IAA instrument render callback — generates audio for the host
private func instrumentRenderCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    // In a full implementation, this would call into the active DSP kernel
    // (TR808DSPKernel, etc.) to generate audio frames.
    // For now, output silence — actual audio comes from AUv3 pathway.

    guard let bufferList = ioData else { return noErr }
    let abl = UnsafeMutableAudioBufferListPointer(bufferList)
    for buffer in abl {
        if let data = buffer.mData {
            memset(data, 0, Int(buffer.mDataByteSize))
        }
    }
    return noErr
}

// MARK: - Helper

private func fourCharCodeIAA(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) | OSType(char)
    }
    return result
}

#endif

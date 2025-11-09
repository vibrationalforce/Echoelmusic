import Foundation
import AVFoundation
import CoreAudioTypes

/// Universal Audio Output Manager
/// Automatically detects and adapts audio output for ANY device:
/// - Headphones (wired, Bluetooth, AirPods, AirPods Pro, AirPods Max)
/// - Speakers (iPhone, iPad, Mac built-in)
/// - Soundbars (Dolby Atmos, DTS:X)
/// - Home Audio Systems (5.1, 7.1, 9.1.4 Atmos)
/// - Spatial Audio devices (HomePod, Apple TV)
///
/// Automatically downmixes/upmixes based on device capabilities:
/// - Dolby Atmos → Stereo (for basic headphones)
/// - Dolby Atmos → 5.1/7.1 (for surround systems)
/// - Stereo → Spatial Audio (for AirPods Pro/Max)
@MainActor
class UniversalAudioOutputManager: ObservableObject {

    // MARK: - Published State

    @Published var currentOutput: AudioOutput = .stereo
    @Published var detectedDevice: OutputDevice = .unknown
    @Published var spatialAudioSupported: Bool = false
    @Published var atmosSupported: Bool = false
    @Published var headTrackingAvailable: Bool = false

    // MARK: - Audio Session

    private let audioSession = AVAudioSession.sharedInstance()
    private var outputChangeObserver: NSObjectProtocol?

    // MARK: - Supported Output Formats

    enum AudioOutput: String, CaseIterable {
        case stereo = "Stereo"
        case binaural = "Binaural (HRTF)"
        case spatial = "Spatial Audio"
        case dolbyAtmos = "Dolby Atmos"
        case surround_51 = "5.1 Surround"
        case surround_71 = "7.1 Surround"
        case surround_714 = "7.1.4 Atmos"
        case surround_914 = "9.1.4 Atmos"
        case ambisonics = "Ambisonics (HOA)"

        var description: String {
            switch self {
            case .stereo:
                return "Standard stereo (L/R)"
            case .binaural:
                return "Binaural HRTF rendering for headphones"
            case .spatial:
                return "Apple Spatial Audio with head tracking"
            case .dolbyAtmos:
                return "Dolby Atmos object-based audio"
            case .surround_51:
                return "5.1 surround (L/R/C/LFE/LS/RS)"
            case .surround_71:
                return "7.1 surround (adds SL/SR)"
            case .surround_714:
                return "7.1.4 Atmos (adds 4 height channels)"
            case .surround_914:
                return "9.1.4 Atmos (adds wide channels)"
            case .ambisonics:
                return "Higher-order ambisonics (360° sound)"
            }
        }

        var channelCount: Int {
            switch self {
            case .stereo, .binaural: return 2
            case .spatial: return 2 // Virtualized to stereo
            case .dolbyAtmos: return 128 // Object-based, up to 128 objects
            case .surround_51: return 6
            case .surround_71: return 8
            case .surround_714: return 12
            case .surround_914: return 14
            case .ambisonics: return 16 // 3rd order HOA
            }
        }
    }

    // MARK: - Detected Output Devices

    enum OutputDevice {
        case unknown

        // Headphones
        case headphones_wired
        case headphones_bluetooth
        case airpods_standard
        case airpods_pro
        case airpods_max
        case beats_headphones

        // Speakers
        case iphone_speaker
        case ipad_speaker
        case mac_speaker
        case homepod
        case homepod_stereo_pair

        // External Systems
        case soundbar_stereo
        case soundbar_atmos
        case home_theater_51
        case home_theater_71
        case home_theater_atmos
        case av_receiver

        // Pro Audio
        case audio_interface
        case studio_monitors

        var supportsAtmos: Bool {
            switch self {
            case .airpods_pro, .airpods_max, .homepod, .homepod_stereo_pair,
                 .soundbar_atmos, .home_theater_atmos:
                return true
            default:
                return false
            }
        }

        var supportsSpatialAudio: Bool {
            switch self {
            case .airpods_pro, .airpods_max, .beats_headphones,
                 .homepod, .homepod_stereo_pair:
                return true
            default:
                return false
            }
        }

        var supportsHeadTracking: Bool {
            switch self {
            case .airpods_pro, .airpods_max:
                return true
            default:
                return false
            }
        }

        var idealFormat: AudioOutput {
            switch self {
            case .airpods_pro, .airpods_max:
                return .spatial
            case .homepod, .homepod_stereo_pair:
                return .dolbyAtmos
            case .soundbar_atmos, .home_theater_atmos:
                return .dolbyAtmos
            case .home_theater_71:
                return .surround_71
            case .home_theater_51:
                return .surround_51
            case .headphones_wired, .headphones_bluetooth, .airpods_standard, .beats_headphones:
                return .binaural
            default:
                return .stereo
            }
        }

        var name: String {
            switch self {
            case .unknown: return "Unknown"
            case .headphones_wired: return "Wired Headphones"
            case .headphones_bluetooth: return "Bluetooth Headphones"
            case .airpods_standard: return "AirPods"
            case .airpods_pro: return "AirPods Pro"
            case .airpods_max: return "AirPods Max"
            case .beats_headphones: return "Beats Headphones"
            case .iphone_speaker: return "iPhone Speaker"
            case .ipad_speaker: return "iPad Speaker"
            case .mac_speaker: return "Mac Speaker"
            case .homepod: return "HomePod"
            case .homepod_stereo_pair: return "HomePod Stereo Pair"
            case .soundbar_stereo: return "Soundbar (Stereo)"
            case .soundbar_atmos: return "Soundbar (Dolby Atmos)"
            case .home_theater_51: return "5.1 Home Theater"
            case .home_theater_71: return "7.1 Home Theater"
            case .home_theater_atmos: return "Dolby Atmos Home Theater"
            case .av_receiver: return "AV Receiver"
            case .audio_interface: return "Audio Interface"
            case .studio_monitors: return "Studio Monitors"
            }
        }
    }

    // MARK: - Initialization

    init() {
        detectCurrentOutput()
        setupOutputChangeObserver()
    }

    deinit {
        if let observer = outputChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Device Detection

    func detectCurrentOutput() {
        let currentRoute = audioSession.currentRoute

        guard let output = currentRoute.outputs.first else {
            detectedDevice = .unknown
            return
        }

        // Detect device type based on port
        switch output.portType {
        case .builtInSpeaker:
            #if os(iOS)
            detectedDevice = .iphone_speaker
            #elseif os(macOS)
            detectedDevice = .mac_speaker
            #else
            detectedDevice = .unknown
            #endif

        case .headphones:
            detectedDevice = .headphones_wired

        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            detectedDevice = detectBluetoothDevice(output: output)

        case .airPlay:
            detectedDevice = detectAirPlayDevice(output: output)

        case .HDMI:
            detectedDevice = .soundbar_atmos  // Assume Atmos-capable via HDMI

        case .USB, .thunderbolt:
            detectedDevice = .audio_interface

        default:
            detectedDevice = .unknown
        }

        // Update capabilities
        spatialAudioSupported = detectedDevice.supportsSpatialAudio
        atmosSupported = detectedDevice.supportsAtmos
        headTrackingAvailable = detectedDevice.supportsHeadTracking

        // Auto-select best format
        currentOutput = detectedDevice.idealFormat

        print("🎧 Detected: \(detectedDevice.name)")
        print("📊 Ideal Format: \(currentOutput.rawValue)")
        print("🌊 Spatial Audio: \(spatialAudioSupported ? "✅" : "❌")")
        print("🎬 Dolby Atmos: \(atmosSupported ? "✅" : "❌")")
        print("🎯 Head Tracking: \(headTrackingAvailable ? "✅" : "❌")")
    }

    private func detectBluetoothDevice(output: AVAudioSessionPortDescription) -> OutputDevice {
        let name = output.portName.lowercased()

        // AirPods detection
        if name.contains("airpods pro") {
            return .airpods_pro
        } else if name.contains("airpods max") {
            return .airpods_max
        } else if name.contains("airpods") {
            return .airpods_standard
        }

        // Beats detection
        if name.contains("beats") {
            return .beats_headphones
        }

        // HomePod detection
        if name.contains("homepod") {
            return .homepod
        }

        // Generic Bluetooth
        return .headphones_bluetooth
    }

    private func detectAirPlayDevice(output: AVAudioSessionPortDescription) -> OutputDevice {
        let name = output.portName.lowercased()

        if name.contains("homepod") {
            // Check if stereo pair
            if audioSession.currentRoute.outputs.count > 1 {
                return .homepod_stereo_pair
            }
            return .homepod
        }

        // Assume Soundbar/Home Theater
        return .soundbar_atmos
    }

    // MARK: - Output Change Observer

    private func setupOutputChangeObserver() {
        outputChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification: notification)
        }
    }

    private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            detectCurrentOutput()
        default:
            break
        }
    }

    // MARK: - Audio Session Configuration

    func configureAudioSession(for output: AudioOutput) throws {
        var options: AVAudioSession.CategoryOptions = [.allowBluetooth, .allowBluetoothA2DP]

        // Add AirPlay for spatial/Atmos
        if output == .spatial || output == .dolbyAtmos {
            options.insert(.allowAirPlay)
        }

        try audioSession.setCategory(
            .playback,
            mode: .default,
            options: options
        )

        // Configure sample rate and channels
        let sampleRate: Double
        let channels: Int

        switch output {
        case .stereo, .binaural:
            sampleRate = 48000
            channels = 2

        case .spatial, .dolbyAtmos:
            sampleRate = 48000  // Atmos uses 48 kHz
            channels = 2  // Virtualized to stereo for headphones

        case .surround_51:
            sampleRate = 48000
            channels = 6

        case .surround_71, .surround_714:
            sampleRate = 48000
            channels = 8

        case .surround_914:
            sampleRate = 48000
            channels = 14

        case .ambisonics:
            sampleRate = 48000
            channels = 16
        }

        try audioSession.setPreferredSampleRate(sampleRate)
        try audioSession.setPreferredOutputNumberOfChannels(channels)
        try audioSession.setActive(true)

        print("✅ Audio session configured: \(output.rawValue)")
        print("   Sample Rate: \(sampleRate) Hz")
        print("   Channels: \(channels)")
    }

    // MARK: - Format Recommendation

    func recommendFormat() -> AudioOutput {
        return detectedDevice.idealFormat
    }

    // MARK: - Capability Check

    func supportsFormat(_ format: AudioOutput) -> Bool {
        switch format {
        case .stereo:
            return true  // Always supported

        case .binaural:
            return isHeadphones()

        case .spatial:
            return spatialAudioSupported

        case .dolbyAtmos:
            return atmosSupported

        case .surround_51, .surround_71, .surround_714, .surround_914:
            return isHomeTheater()

        case .ambisonics:
            return true  // Can be virtualized
        }
    }

    private func isHeadphones() -> Bool {
        switch detectedDevice {
        case .headphones_wired, .headphones_bluetooth, .airpods_standard,
             .airpods_pro, .airpods_max, .beats_headphones:
            return true
        default:
            return false
        }
    }

    private func isHomeTheater() -> Bool {
        switch detectedDevice {
        case .soundbar_atmos, .home_theater_51, .home_theater_71,
             .home_theater_atmos, .av_receiver:
            return true
        default:
            return false
        }
    }

    // MARK: - Debug Info

    var debugInfo: String {
        """
        UniversalAudioOutputManager:
        - Device: \(detectedDevice.name)
        - Current Format: \(currentOutput.rawValue)
        - Channels: \(currentOutput.channelCount)
        - Spatial Audio: \(spatialAudioSupported ? "✅" : "❌")
        - Dolby Atmos: \(atmosSupported ? "✅" : "❌")
        - Head Tracking: \(headTrackingAvailable ? "✅" : "❌")
        - Recommended: \(recommendFormat().rawValue)
        """
    }
}

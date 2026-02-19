import Foundation
import CoreMIDI
import Combine

/// Ableton Push 3 LED Controller
/// Bio-reactive LED feedback via SysEx messages
/// 8x8 RGB LED grid (64 LEDs)
/// Integrates with biofeedback system for real-time LED visualization
@MainActor
class Push3LEDController: ObservableObject {

    // MARK: - Published State

    @Published var isConnected: Bool = false
    @Published var currentPattern: LEDPattern = .breathe
    @Published var brightness: Float = 0.7

    // MARK: - MIDI Components

    private var midiClient: MIDIClientRef = 0
    private var outputPort: MIDIPortRef = 0
    private var push3Endpoint: MIDIEndpointRef = 0

    // MARK: - LED Grid

    private var ledGrid: [[RGB]] = Array(
        repeating: Array(repeating: RGB(r: 0, g: 0, b: 0), count: 8),
        count: 8
    )

    struct RGB {
        var r: UInt8
        var g: UInt8
        var b: UInt8

        static let black = RGB(r: 0, g: 0, b: 0)
        static let red = RGB(r: 255, g: 0, b: 0)
        static let green = RGB(r: 0, g: 255, b: 0)
        static let blue = RGB(r: 0, g: 0, b: 255)
        static let cyan = RGB(r: 0, g: 255, b: 255)
        static let magenta = RGB(r: 255, g: 0, b: 255)
        static let yellow = RGB(r: 255, g: 255, b: 0)
        static let white = RGB(r: 255, g: 255, b: 255)
    }

    // MARK: - Push 3 SysEx Constants

    private enum SysExCommand {
        static let header: [UInt8] = [0xF0, 0x00, 0x21, 0x1D, 0x01, 0x01]  // Ableton Push 3
        static let ledSetCommand: UInt8 = 0x0A
        static let footer: UInt8 = 0xF7
    }

    // MARK: - LED Patterns

    enum LEDPattern: String, CaseIterable {
        case breathe = "Breathe"           // Breathing animation based on HRV
        case pulse = "Pulse"               // Heart rate pulse
        case coherence = "Coherence"       // HRV coherence visualization
        case rainbow = "Rainbow"           // Rotating rainbow
        case wave = "Wave"                 // Wave pattern
        case spiral = "Spiral"             // Spiral animation
        case gestureFlash = "Gesture Flash" // Flash on gesture detection

        var description: String {
            switch self {
            case .breathe: return "Breathing animation (HRV-synced)"
            case .pulse: return "Heart rate pulse indicator"
            case .coherence: return "HRV coherence color mapping"
            case .rainbow: return "Rainbow spectrum animation"
            case .wave: return "Ripple wave effect"
            case .spiral: return "Spiral pattern from center"
            case .gestureFlash: return "Flash on gesture trigger"
            }
        }
    }

    // MARK: - Initialization

    init() {
        setupMIDI()
    }

    deinit {
        // disconnect() is @MainActor - inline minimal cleanup
    }

    // MARK: - MIDI Setup

    private func setupMIDI() {
        // Create MIDI client
        var client: MIDIClientRef = 0
        let clientStatus = MIDIClientCreateWithBlock(
            "Echoelmusic Push 3 Controller" as CFString,
            &client
        ) { _ in }

        guard clientStatus == noErr else {
            log.led("⚠️ Failed to create MIDI client for Push 3", level: .warning)
            return
        }
        midiClient = client

        // Create output port
        var port: MIDIPortRef = 0
        let portStatus = MIDIOutputPortCreate(
            midiClient,
            "Push 3 Output" as CFString,
            &port
        )

        guard portStatus == noErr else {
            log.led("⚠️ Failed to create MIDI output port for Push 3", level: .warning)
            return
        }
        outputPort = port

        // Find Push 3 endpoint
        findPush3Endpoint()
    }

    private func findPush3Endpoint() {
        let destinationCount = MIDIGetNumberOfDestinations()

        for i in 0..<destinationCount {
            let endpoint = MIDIGetDestination(i)

            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)

            if let deviceName = name?.takeRetainedValue() as String? {
                if deviceName.contains("Ableton Push 3") || deviceName.contains("Push 3") {
                    push3Endpoint = endpoint
                    isConnected = true
                    log.led("✅ Found Push 3: \(deviceName)")
                    return
                }
            }
        }

        log.led("⚠️ Push 3 not found. Connect via USB and retry.", level: .warning)
    }

    // MARK: - Connection Management

    func connect() {
        guard !isConnected else { return }
        findPush3Endpoint()

        if isConnected {
            clearGrid()
            applyPattern(currentPattern)
        }
    }

    func disconnect() {
        if isConnected {
            clearGrid()
        }
        isConnected = false
    }

    // MARK: - LED Control

    /// Set individual LED color
    func setLED(row: Int, col: Int, color: RGB) {
        guard row >= 0, row < 8, col >= 0, col < 8 else { return }
        ledGrid[row][col] = color
    }

    /// Set entire grid
    func setGrid(_ grid: [[RGB]]) {
        guard grid.count == 8, grid.allSatisfy({ $0.count == 8 }) else {
            log.led("⚠️ Invalid grid dimensions (must be 8x8)", level: .warning)
            return
        }
        ledGrid = grid
    }

    /// Clear all LEDs
    func clearGrid() {
        ledGrid = Array(
            repeating: Array(repeating: RGB.black, count: 8),
            count: 8
        )
        sendGridToHardware()
    }

    /// Send current grid to Push 3 hardware
    func sendGridToHardware() {
        guard isConnected else { return }

        // Build SysEx message
        var sysex: [UInt8] = SysExCommand.header
        sysex.append(SysExCommand.ledSetCommand)

        // Encode 8x8 grid (64 LEDs * 3 bytes RGB = 192 bytes)
        for row in 0..<8 {
            for col in 0..<8 {
                let color = ledGrid[row][col]
                let scaledR = UInt8(Float(color.r) * brightness)
                let scaledG = UInt8(Float(color.g) * brightness)
                let scaledB = UInt8(Float(color.b) * brightness)

                sysex.append(scaledR & 0x7F)  // MSB must be 0 for SysEx
                sysex.append(scaledG & 0x7F)
                sysex.append(scaledB & 0x7F)
            }
        }

        sysex.append(SysExCommand.footer)

        // Send via MIDI
        var packetList = MIDIPacketList()
        var packet = MIDIPacketListInit(&packetList)

        packet = MIDIPacketListAdd(
            &packetList,
            1024,
            packet,
            0,
            sysex.count,
            sysex
        )

        let status = MIDISend(outputPort, push3Endpoint, &packetList)
        if status != noErr {
            log.led("⚠️ Failed to send SysEx to Push 3: \(status)", level: .warning)
        }
    }

    // MARK: - Biometric → LED Mapping

    /// Update LEDs based on HRV coherence
    func updateFromBioSignals(hrvCoherence: Double, heartRate: Double) {
        switch currentPattern {
        case .breathe:
            applyBreathePattern(coherence: hrvCoherence)

        case .pulse:
            applyPulsePattern(heartRate: heartRate)

        case .coherence:
            applyCoherencePattern(coherence: hrvCoherence)

        case .rainbow:
            applyRainbowPattern()

        case .wave:
            applyWavePattern()

        case .spiral:
            applySpiralPattern()

        case .gestureFlash:
            // Updated externally via flashGesture()
            break
        }

        sendGridToHardware()
    }

    // MARK: - Pattern Implementations

    /// Pre-computed distance from center for 8×8 grid (avoids sqrt per pixel per frame)
    private static let distanceLUT: [[Float]] = {
        var lut = [[Float]](repeating: [Float](repeating: 0, count: 8), count: 8)
        for row in 0..<8 {
            for col in 0..<8 {
                let dx = Float(col) - 3.5
                let dy = Float(row) - 3.5
                lut[row][col] = sqrt(dx * dx + dy * dy)
            }
        }
        return lut
    }()

    /// Pre-computed angle from center for 8×8 grid (avoids atan2 per pixel per frame)
    private static let angleLUT: [[Float]] = {
        var lut = [[Float]](repeating: [Float](repeating: 0, count: 8), count: 8)
        for row in 0..<8 {
            for col in 0..<8 {
                let dx = Float(col) - 3.5
                let dy = Float(row) - 3.5
                lut[row][col] = atan2(dy, dx)
            }
        }
        return lut
    }()

    private func applyBreathePattern(coherence: Double) {
        let hue = Float(coherence) / 100.0

        let time = CACurrentMediaTime()
        let breathCycle = sin(time * 0.5)
        let intensity = UInt8((breathCycle + 1.0) * 0.5 * 255.0)

        let color = hueToRGB(hue: hue, value: intensity)

        for row in 0..<8 {
            for col in 0..<8 {
                ledGrid[row][col] = color
            }
        }
    }

    private func applyPulsePattern(heartRate: Double) {
        let time = CACurrentMediaTime()
        let beatInterval = 60.0 / heartRate  // Seconds per beat
        let phase = time.truncatingRemainder(dividingBy: beatInterval) / beatInterval

        // Flash for first 20% of beat cycle
        let isFlashing = phase < 0.2

        clearGrid()

        if isFlashing {
            // Center 2x2 LEDs flash red
            for row in 3...4 {
                for col in 3...4 {
                    ledGrid[row][col] = RGB.red
                }
            }
        }
    }

    private func applyCoherencePattern(coherence: Double) {
        let normalizedCoherence = Float(coherence) / 100.0

        for row in 0..<8 {
            for col in 0..<8 {
                let distance = Self.distanceLUT[row][col] / 5.0
                let hue = normalizedCoherence * (1.0 - distance)
                ledGrid[row][col] = hueToRGB(hue: hue, value: 200)
            }
        }
    }

    private func applyRainbowPattern() {
        let time = CACurrentMediaTime()
        let hueOffset = Float(time * 0.2).truncatingRemainder(dividingBy: 1.0)

        for row in 0..<8 {
            for col in 0..<8 {
                let hue = (Float(col) / 8.0 + hueOffset).truncatingRemainder(dividingBy: 1.0)
                ledGrid[row][col] = hueToRGB(hue: hue, value: 200)
            }
        }
    }

    private func applyWavePattern() {
        let time = Float(CACurrentMediaTime())

        for row in 0..<8 {
            for col in 0..<8 {
                let distance = Self.distanceLUT[row][col]
                let wave = sin(distance - time * 3.0)
                let intensity = UInt8(max(0, wave) * 255.0)
                ledGrid[row][col] = RGB(r: 0, g: intensity, b: intensity)
            }
        }
    }

    private func applySpiralPattern() {
        let time = Float(CACurrentMediaTime())

        for row in 0..<8 {
            for col in 0..<8 {
                let angle = Self.angleLUT[row][col]
                let distance = Self.distanceLUT[row][col]

                let spiralPhase = angle + distance * 0.5 - time
                let intensity = UInt8((sin(spiralPhase) + 1.0) * 0.5 * 255.0)

                let hue = (angle / (2.0 * .pi) + 1.0) * 0.5
                ledGrid[row][col] = hueToRGB(hue: hue, value: intensity)
            }
        }
    }

    /// Flash LEDs on gesture detection
    func flashGesture(gesture: String) {
        // White flash
        for row in 0..<8 {
            for col in 0..<8 {
                ledGrid[row][col] = RGB.white
            }
        }
        sendGridToHardware()

        // Schedule fade-out after 100ms
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            applyPattern(currentPattern)
        }

        log.led("⚡ Gesture flash: \(gesture)")
    }

    // MARK: - Pattern Management

    func applyPattern(_ pattern: LEDPattern) {
        currentPattern = pattern
        log.led("💡 Push 3 pattern: \(pattern.rawValue)")
    }

    // MARK: - Utility Functions

    /// Convert hue (0-1) to RGB
    private func hueToRGB(hue: Float, value: UInt8) -> RGB {
        let h = hue * 6.0
        let sector = Int(h)
        let fraction = h - Float(sector)

        let p: UInt8 = 0
        let q = UInt8(Float(value) * (1.0 - fraction))
        let t = UInt8(Float(value) * fraction)

        switch sector % 6 {
        case 0: return RGB(r: value, g: t, b: p)
        case 1: return RGB(r: q, g: value, b: p)
        case 2: return RGB(r: p, g: value, b: t)
        case 3: return RGB(r: p, g: q, b: value)
        case 4: return RGB(r: t, g: p, b: value)
        case 5: return RGB(r: value, g: p, b: q)
        default: return RGB.black
        }
    }

    /// Convert coherence to color (red → yellow → green)
    func coherenceToColor(coherence: Double) -> RGB {
        let hue: Float
        if coherence < 40 {
            hue = 0.0  // Red
        } else if coherence < 60 {
            hue = 0.15  // Yellow
        } else {
            hue = 0.33  // Green
        }

        return hueToRGB(hue: hue, value: 200)
    }

    // MARK: - Debug Info

    var debugInfo: String {
        """
        Push3LEDController:
        - Connected: \(isConnected ? "✅" : "❌")
        - Pattern: \(currentPattern.rawValue)
        - Brightness: \(Int(brightness * 100))%
        - Grid Size: 8x8 (64 LEDs)
        """
    }
}

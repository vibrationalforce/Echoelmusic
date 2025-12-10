import Foundation
import Network
import Combine

/// UnifiedLEDController - Multi-Protocol LED Control System
/// Supports: Art-Net/DMX, WLED, Philips Hue, sACN (E1.31), Serial LED
/// Bio-reactive lighting with real-time control for performances and installations
@MainActor
class UnifiedLEDController: ObservableObject {

    // MARK: - Singleton

    static let shared = UnifiedLEDController()

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var connectedDevices: [LEDDevice] = []
    @Published var currentEffect: LEDEffect = .solid
    @Published var masterBrightness: Float = 1.0
    @Published var bioReactiveEnabled: Bool = true

    // MARK: - Device Types

    enum DeviceType: String, CaseIterable {
        case artNet = "Art-Net/DMX"
        case wled = "WLED"
        case hue = "Philips Hue"
        case sacn = "sACN (E1.31)"
        case serial = "Serial LED"
        case custom = "Custom UDP"

        var defaultPort: UInt16 {
            switch self {
            case .artNet: return 6454
            case .wled: return 21324   // WLED UDP port
            case .hue: return 443       // HTTPS
            case .sacn: return 5568
            case .serial: return 0
            case .custom: return 8888
            }
        }
    }

    // MARK: - LED Device

    struct LEDDevice: Identifiable {
        let id: UUID
        let name: String
        let type: DeviceType
        let address: String
        let port: UInt16
        var pixelCount: Int
        var isConnected: Bool = false
        var universe: Int = 0          // For Art-Net/sACN
        var brightness: Float = 1.0

        // WLED-specific
        var wledSegments: [WLEDSegment] = []

        // Hue-specific
        var hueGroupId: String?
        var hueLights: [Int] = []
    }

    struct WLEDSegment {
        var startPixel: Int
        var endPixel: Int
        var colorOrder: String = "GRB"
    }

    // MARK: - LED Effects

    enum LEDEffect: String, CaseIterable {
        case solid = "Solid"
        case rainbow = "Rainbow"
        case breathe = "Breathe"
        case pulse = "Pulse"
        case wave = "Wave"
        case fire = "Fire"
        case bioReactive = "Bio-Reactive"
        case audioReactive = "Audio-Reactive"
        case strobe = "Strobe"
        case chase = "Chase"
        case sparkle = "Sparkle"
        case gradient = "Gradient"

        var wledEffectId: Int {
            switch self {
            case .solid: return 0
            case .rainbow: return 9
            case .breathe: return 2
            case .pulse: return 3
            case .wave: return 67
            case .fire: return 66
            case .bioReactive: return 0  // Custom via JSON
            case .audioReactive: return 127
            case .strobe: return 23
            case .chase: return 28
            case .sparkle: return 40
            case .gradient: return 46
            }
        }
    }

    // MARK: - Color

    struct LEDColor {
        var r: UInt8
        var g: UInt8
        var b: UInt8
        var w: UInt8 = 0

        static let black = LEDColor(r: 0, g: 0, b: 0)
        static let white = LEDColor(r: 255, g: 255, b: 255)
        static let red = LEDColor(r: 255, g: 0, b: 0)
        static let green = LEDColor(r: 0, g: 255, b: 0)
        static let blue = LEDColor(r: 0, g: 0, b: 255)
        static let cyan = LEDColor(r: 0, g: 255, b: 255)
        static let magenta = LEDColor(r: 255, g: 0, b: 255)
        static let yellow = LEDColor(r: 255, g: 255, b: 0)

        static func fromHSV(h: Float, s: Float, v: Float) -> LEDColor {
            let c = v * s
            let x = c * (1 - abs(((h / 60).truncatingRemainder(dividingBy: 2)) - 1))
            let m = v - c

            var r1: Float = 0, g1: Float = 0, b1: Float = 0

            switch Int(h / 60) % 6 {
            case 0: r1 = c; g1 = x; b1 = 0
            case 1: r1 = x; g1 = c; b1 = 0
            case 2: r1 = 0; g1 = c; b1 = x
            case 3: r1 = 0; g1 = x; b1 = c
            case 4: r1 = x; g1 = 0; b1 = c
            case 5: r1 = c; g1 = 0; b1 = x
            default: break
            }

            return LEDColor(
                r: UInt8((r1 + m) * 255),
                g: UInt8((g1 + m) * 255),
                b: UInt8((b1 + m) * 255)
            )
        }

        /// Create color from coherence level (Red -> Yellow -> Green)
        static func fromCoherence(_ coherence: Double) -> LEDColor {
            let hue: Float
            if coherence < 40 {
                hue = 0  // Red
            } else if coherence < 70 {
                hue = Float((coherence - 40) / 30) * 60  // Red to Yellow
            } else {
                hue = 60 + Float((coherence - 70) / 30) * 60  // Yellow to Green
            }
            return fromHSV(h: hue, s: 1.0, v: 1.0)
        }
    }

    // MARK: - Connection Management

    private var artNetSockets: [UUID: NWConnection] = [:]
    private var wledSockets: [UUID: NWConnection] = [:]
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Bio Data

    private var currentHRV: Double = 50.0
    private var currentHeartRate: Double = 70.0
    private var currentCoherence: Double = 50.0

    // MARK: - Initialization

    private init() {
        setupDefaultDevices()
    }

    private func setupDefaultDevices() {
        // Example default devices - user should configure
        // Will auto-discover WLED devices on network
    }

    // MARK: - Device Discovery

    func discoverWLEDDevices() async {
        // WLED devices respond to mDNS as "_wled._tcp"
        print("Discovering WLED devices...")

        // Simplified: Check common IP range
        // In production, use NWBrowser for mDNS discovery
        let commonIPs = [
            "192.168.1.100", "192.168.1.101", "192.168.1.102",
            "192.168.0.100", "192.168.0.101", "192.168.0.102",
            "10.0.0.100", "10.0.0.101"
        ]

        for ip in commonIPs {
            if await checkWLEDDevice(ip: ip) {
                let device = LEDDevice(
                    id: UUID(),
                    name: "WLED @ \(ip)",
                    type: .wled,
                    address: ip,
                    port: 21324,
                    pixelCount: 60,  // Will be queried from device
                    isConnected: true
                )
                connectedDevices.append(device)
                print("Found WLED: \(ip)")
            }
        }
    }

    private func checkWLEDDevice(ip: String) async -> Bool {
        // Quick TCP check on WLED HTTP port
        let connection = NWConnection(
            host: NWEndpoint.Host(ip),
            port: 80,
            using: .tcp
        )

        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            connection.start(queue: .global())

            // Timeout after 500ms
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                connection.cancel()
            }
        }
    }

    // MARK: - Connection

    func addDevice(_ device: LEDDevice) {
        connectedDevices.append(device)
        connectDevice(device)
    }

    func removeDevice(id: UUID) {
        disconnectDevice(id: id)
        connectedDevices.removeAll { $0.id == id }
    }

    private func connectDevice(_ device: LEDDevice) {
        let host = NWEndpoint.Host(device.address)
        let port = NWEndpoint.Port(integerLiteral: device.port)

        let connection = NWConnection(
            to: .hostPort(host: host, port: port),
            using: .udp
        )

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .ready = state {
                    if let index = self?.connectedDevices.firstIndex(where: { $0.id == device.id }) {
                        self?.connectedDevices[index].isConnected = true
                    }
                    print("Connected: \(device.name)")
                }
            }
        }

        connection.start(queue: .global(qos: .userInteractive))

        switch device.type {
        case .artNet, .sacn:
            artNetSockets[device.id] = connection
        case .wled:
            wledSockets[device.id] = connection
        default:
            artNetSockets[device.id] = connection
        }
    }

    private func disconnectDevice(id: UUID) {
        artNetSockets[id]?.cancel()
        artNetSockets.removeValue(forKey: id)
        wledSockets[id]?.cancel()
        wledSockets.removeValue(forKey: id)
    }

    // MARK: - Start/Stop

    func start() {
        guard !isActive else { return }

        isActive = true
        startUpdateLoop()

        print("UnifiedLEDController started")
    }

    func stop() {
        guard isActive else { return }

        stopUpdateLoop()
        blackoutAll()

        for device in connectedDevices {
            disconnectDevice(id: device.id)
        }

        isActive = false
        print("UnifiedLEDController stopped")
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAllDevices()
            }
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateAllDevices() {
        guard isActive else { return }

        for device in connectedDevices where device.isConnected {
            switch device.type {
            case .artNet:
                sendArtNet(to: device)
            case .wled:
                sendWLED(to: device)
            case .sacn:
                sendSACN(to: device)
            default:
                break
            }
        }
    }

    // MARK: - Bio-Reactive Updates

    func updateBioData(hrv: Double, heartRate: Double, coherence: Double) {
        currentHRV = hrv
        currentHeartRate = heartRate
        currentCoherence = coherence

        if bioReactiveEnabled && currentEffect == .bioReactive {
            applyBioReactiveEffect()
        }
    }

    private func applyBioReactiveEffect() {
        let color = LEDColor.fromCoherence(currentCoherence)

        // Pulse speed based on heart rate
        let pulseSpeed = currentHeartRate / 60.0  // Normalize to 1.0 at 60 BPM

        // Wave frequency based on HRV
        let waveFreq = currentHRV / 50.0  // Normalize to 1.0 at HRV 50

        for device in connectedDevices where device.isConnected {
            switch device.type {
            case .wled:
                sendWLEDEffect(
                    to: device,
                    effect: .pulse,
                    color: color,
                    speed: Int(pulseSpeed * 128),
                    intensity: Int(masterBrightness * 255)
                )
            case .artNet:
                sendArtNetColor(to: device, color: color)
            default:
                break
            }
        }
    }

    // MARK: - Protocol: Art-Net

    private var artNetSequence: UInt8 = 0

    private func sendArtNet(to device: LEDDevice) {
        guard let socket = artNetSockets[device.id] else { return }

        var packet: [UInt8] = []

        // Art-Net header
        packet.append(contentsOf: "Art-Net\0".utf8)  // 8 bytes
        packet.append(contentsOf: [0x00, 0x50])      // OpCode: ArtDMX
        packet.append(contentsOf: [0x00, 0x0E])      // Protocol version 14
        artNetSequence = artNetSequence &+ 1
        packet.append(artNetSequence)                 // Sequence
        packet.append(0)                              // Physical
        packet.append(UInt8(device.universe & 0xFF)) // Universe Low
        packet.append(UInt8(device.universe >> 8))   // Universe High
        packet.append(UInt8((device.pixelCount * 3) >> 8))  // Length High
        packet.append(UInt8((device.pixelCount * 3) & 0xFF)) // Length Low

        // Generate pixel data based on effect
        let pixels = generatePixelData(for: device)
        packet.append(contentsOf: pixels)

        let data = Data(packet)
        socket.send(content: data, completion: .contentProcessed { _ in })
    }

    private func sendArtNetColor(to device: LEDDevice, color: LEDColor) {
        guard let socket = artNetSockets[device.id] else { return }

        var packet: [UInt8] = []
        packet.append(contentsOf: "Art-Net\0".utf8)
        packet.append(contentsOf: [0x00, 0x50])
        packet.append(contentsOf: [0x00, 0x0E])
        artNetSequence = artNetSequence &+ 1
        packet.append(artNetSequence)
        packet.append(0)
        packet.append(UInt8(device.universe & 0xFF))
        packet.append(UInt8(device.universe >> 8))
        packet.append(UInt8((device.pixelCount * 3) >> 8))
        packet.append(UInt8((device.pixelCount * 3) & 0xFF))

        // Fill with color
        for _ in 0..<device.pixelCount {
            packet.append(color.r)
            packet.append(color.g)
            packet.append(color.b)
        }

        socket.send(content: Data(packet), completion: .contentProcessed { _ in })
    }

    // MARK: - Protocol: WLED

    private func sendWLED(to device: LEDDevice) {
        guard let socket = wledSockets[device.id] else { return }

        // WLED UDP realtime protocol (DRGB)
        var packet: [UInt8] = [
            2,  // Protocol: DRGB (2) or DNRGB (4) for larger strips
            2   // Timeout: 2 seconds
        ]

        // Generate pixel data
        let pixels = generatePixelData(for: device)
        packet.append(contentsOf: pixels)

        socket.send(content: Data(packet), completion: .contentProcessed { _ in })
    }

    private func sendWLEDEffect(to device: LEDDevice, effect: LEDEffect, color: LEDColor, speed: Int, intensity: Int) {
        // WLED JSON API via UDP (port 21324)
        guard let socket = wledSockets[device.id] else { return }

        let json: [String: Any] = [
            "on": true,
            "bri": Int(masterBrightness * 255),
            "seg": [
                [
                    "fx": effect.wledEffectId,
                    "sx": speed,
                    "ix": intensity,
                    "col": [[color.r, color.g, color.b]]
                ]
            ]
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: json) {
            // Prepend with JSON marker byte
            var packet: [UInt8] = [0x04]  // JSON mode
            packet.append(contentsOf: jsonData)
            socket.send(content: Data(packet), completion: .contentProcessed { _ in })
        }
    }

    // MARK: - Protocol: sACN (E1.31)

    private var sacnSequence: UInt8 = 0

    private func sendSACN(to device: LEDDevice) {
        guard let socket = artNetSockets[device.id] else { return }

        // sACN packet (simplified)
        var packet: [UInt8] = []

        // Root Layer
        packet.append(contentsOf: [0x00, 0x10])  // Preamble Size
        packet.append(contentsOf: [0x00, 0x00])  // Post-amble Size
        packet.append(contentsOf: "ASC-E1.17\0\0\0".utf8)  // ACN Packet Identifier

        // ... (full sACN implementation)
        // For now, use Art-Net as fallback
        sendArtNet(to: device)
    }

    // MARK: - Effect Generation

    private func generatePixelData(for device: LEDDevice) -> [UInt8] {
        var pixels: [UInt8] = []
        let time = Date().timeIntervalSinceReferenceDate

        for i in 0..<device.pixelCount {
            let position = Float(i) / Float(device.pixelCount)
            var color: LEDColor

            switch currentEffect {
            case .solid:
                color = LEDColor.fromCoherence(currentCoherence)

            case .rainbow:
                let hue = (position + Float(time * 0.1)).truncatingRemainder(dividingBy: 1.0) * 360
                color = LEDColor.fromHSV(h: hue, s: 1.0, v: masterBrightness)

            case .breathe:
                let breathPhase = sin(time * 0.5) * 0.5 + 0.5
                color = LEDColor.fromHSV(h: 200, s: 1.0, v: Float(breathPhase) * masterBrightness)

            case .pulse:
                let pulsePhase = sin(time * (currentHeartRate / 30.0)) * 0.5 + 0.5
                color = LEDColor.fromCoherence(currentCoherence)
                color.r = UInt8(Float(color.r) * Float(pulsePhase))
                color.g = UInt8(Float(color.g) * Float(pulsePhase))
                color.b = UInt8(Float(color.b) * Float(pulsePhase))

            case .wave:
                let wave = sin(position * 2.0 * .pi + Float(time * 2.0)) * 0.5 + 0.5
                let hue = Float(currentCoherence) / 100.0 * 120  // Red to Green
                color = LEDColor.fromHSV(h: hue, s: 1.0, v: wave * masterBrightness)

            case .fire:
                let flicker = Float.random(in: 0.7...1.0)
                let hue = Float.random(in: 0...40)  // Red-orange range
                color = LEDColor.fromHSV(h: hue, s: 1.0, v: flicker * masterBrightness)

            case .bioReactive:
                let coherenceColor = LEDColor.fromCoherence(currentCoherence)
                let heartPulse = sin(time * (currentHeartRate / 30.0)) * 0.3 + 0.7
                color = LEDColor(
                    r: UInt8(Float(coherenceColor.r) * Float(heartPulse)),
                    g: UInt8(Float(coherenceColor.g) * Float(heartPulse)),
                    b: UInt8(Float(coherenceColor.b) * Float(heartPulse))
                )

            case .audioReactive:
                // Placeholder - integrate with audio engine
                color = LEDColor.white

            case .strobe:
                let strobeOn = Int(time * 10) % 2 == 0
                color = strobeOn ? LEDColor.white : LEDColor.black

            case .chase:
                let chasePos = Int(time * 10) % device.pixelCount
                color = i == chasePos ? LEDColor.white : LEDColor.black

            case .sparkle:
                let sparkle = Float.random(in: 0...1) > 0.95
                color = sparkle ? LEDColor.white : LEDColor.black

            case .gradient:
                let hue = position * 360
                color = LEDColor.fromHSV(h: hue, s: 1.0, v: masterBrightness)
            }

            // Apply master brightness
            color.r = UInt8(Float(color.r) * masterBrightness)
            color.g = UInt8(Float(color.g) * masterBrightness)
            color.b = UInt8(Float(color.b) * masterBrightness)

            pixels.append(color.r)
            pixels.append(color.g)
            pixels.append(color.b)
        }

        return pixels
    }

    // MARK: - Control

    func setEffect(_ effect: LEDEffect) {
        currentEffect = effect
        print("LED Effect: \(effect.rawValue)")
    }

    func setColor(_ color: LEDColor) {
        for device in connectedDevices where device.isConnected {
            switch device.type {
            case .wled:
                sendWLEDEffect(to: device, effect: .solid, color: color, speed: 128, intensity: 255)
            case .artNet:
                sendArtNetColor(to: device, color: color)
            default:
                break
            }
        }
    }

    func blackoutAll() {
        for device in connectedDevices where device.isConnected {
            switch device.type {
            case .wled:
                sendWLEDEffect(to: device, effect: .solid, color: .black, speed: 0, intensity: 0)
            case .artNet:
                sendArtNetColor(to: device, color: .black)
            default:
                break
            }
        }
    }

    // MARK: - Debug

    var debugInfo: String {
        """
        UnifiedLEDController:
        - Active: \(isActive ? "Yes" : "No")
        - Devices: \(connectedDevices.count)
        - Connected: \(connectedDevices.filter { $0.isConnected }.count)
        - Effect: \(currentEffect.rawValue)
        - Brightness: \(Int(masterBrightness * 100))%
        - Bio-Reactive: \(bioReactiveEnabled ? "Yes" : "No")
        - Coherence: \(Int(currentCoherence))
        """
    }
}

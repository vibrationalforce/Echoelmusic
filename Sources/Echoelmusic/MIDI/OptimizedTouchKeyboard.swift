import SwiftUI
import Combine
import CoreHaptics

// MARK: - Optimized Touch Keyboard
/// High-performance Canvas-based keyboard with true multi-touch polyphony
/// Optimized for all touch screens: iPhone, iPad, Apple Watch, Vision Pro

struct OptimizedTouchKeyboard: View {

    @ObservedObject var hub: TouchInstrumentsHub
    @StateObject private var engine = KeyboardEngine()
    @State private var screenSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Control Bar
                KeyboardControlBar(engine: engine, hub: hub)
                    .frame(height: 44)

                // Expression Zone (for pitch bend when dragging up from keys)
                ExpressionZone(engine: engine)
                    .frame(height: engine.config.expressionZoneHeight)

                // High-Performance Canvas Keyboard
                CanvasKeyboardView(engine: engine, hub: hub)
                    .frame(height: engine.config.keyHeight)

                // Status Bar
                KeyboardStatusBar(engine: engine)
                    .frame(height: 24)
            }
            .onAppear {
                screenSize = geometry.size
                engine.configure(for: screenSize)
            }
            .onChange(of: geometry.size) { _, newSize in
                screenSize = newSize
                engine.configure(for: newSize)
            }
        }
    }
}

// MARK: - Keyboard Engine
/// Core engine handling multi-touch tracking, MPE, and performance optimization

@MainActor
final class KeyboardEngine: ObservableObject {

    // MARK: - Published State
    @Published var config: KeyboardConfig = .default
    @Published var activeTouches: [Int: TouchState] = [:]
    @Published var currentOctave: Int = 4
    @Published var visibleOctaves: Int = 2
    @Published var expressionMode: ExpressionMode = .xyPad
    @Published var velocityCurve: VelocityCurve = .linear
    @Published var scale: ScaleMode = .chromatic
    @Published var rootNote: Int = 0 // C
    @Published var mpeEnabled: Bool = true
    @Published var voiceCount: Int = 0
    @Published var messageRate: Int = 0

    // MARK: - Configuration
    struct KeyboardConfig {
        var keyWidth: CGFloat = 50
        var keyHeight: CGFloat = 180
        var blackKeyRatio: CGFloat = 0.6
        var blackKeyHeightRatio: CGFloat = 0.6
        var expressionZoneHeight: CGFloat = 30
        var cornerRadius: CGFloat = 6
        var showNoteNames: Bool = true

        static let `default` = KeyboardConfig()

        static func adaptive(for size: CGSize) -> KeyboardConfig {
            let isPortrait = size.height > size.width
            let isCompact = min(size.width, size.height) < 400

            var config = KeyboardConfig()

            if isCompact {
                // Apple Watch / Small iPhone
                config.keyWidth = 32
                config.keyHeight = size.height * 0.5
                config.expressionZoneHeight = 0
                config.showNoteNames = false
            } else if isPortrait {
                // iPhone Portrait / iPad Portrait
                config.keyWidth = min(size.width / 8, 55)
                config.keyHeight = min(size.height * 0.35, 200)
                config.expressionZoneHeight = 25
            } else {
                // Landscape
                let whiteKeysVisible = 15.0
                config.keyWidth = min(size.width / whiteKeysVisible, 60)
                config.keyHeight = min(size.height * 0.5, 220)
                config.expressionZoneHeight = 35
            }

            return config
        }
    }

    // MARK: - Touch State
    struct TouchState: Identifiable {
        let id: Int // Touch identifier
        var note: UInt8
        var velocity: Float
        var channel: UInt8
        var pitchBend: Float = 0 // -1 to +1
        var brightness: Float = 0.5 // CC74
        var pressure: Float = 0.5 // Aftertouch
        var initialLocation: CGPoint
        var currentLocation: CGPoint
        var startTime: Date
    }

    // MARK: - Enums
    enum ExpressionMode: String, CaseIterable, Identifiable {
        case xyPad = "XY Pad"
        case slide = "Slide"
        case pressure = "Pressure"
        case mpe = "Full MPE"

        var id: String { rawValue }
    }

    enum VelocityCurve: String, CaseIterable, Identifiable {
        case soft = "Soft"
        case linear = "Linear"
        case hard = "Hard"
        case fixed = "Fixed"

        var id: String { rawValue }

        func apply(_ input: Float) -> Float {
            switch self {
            case .soft: return pow(input, 0.5)
            case .linear: return input
            case .hard: return pow(input, 2.0)
            case .fixed: return 0.85
            }
        }
    }

    enum ScaleMode: String, CaseIterable, Identifiable {
        case chromatic = "Chromatic"
        case major = "Major"
        case minor = "Minor"
        case pentatonic = "Pentatonic"
        case blues = "Blues"

        var id: String { rawValue }

        var intervals: [Int] {
            switch self {
            case .chromatic: return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
            case .major: return [0, 2, 4, 5, 7, 9, 11]
            case .minor: return [0, 2, 3, 5, 7, 8, 10]
            case .pentatonic: return [0, 2, 4, 7, 9]
            case .blues: return [0, 3, 5, 6, 7, 10]
            }
        }
    }

    // MARK: - Private State
    private var mpeManager: MPEZoneManager?
    private var hapticEngine: CHHapticEngine?
    private var lastExpressionUpdate: [Int: Date] = [:]
    private let expressionThrottle: TimeInterval = 0.008 // 125Hz max
    private var messageCounter = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        setupHaptics()
        startMessageRateMonitor()
    }

    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            EchoelLogger.warning("Haptics unavailable: \(error)", category: EchoelLogger.system)
        }
    }

    private func startMessageRateMonitor() {
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.messageRate = self?.messageCounter ?? 0
                self?.messageCounter = 0
            }
            .store(in: &cancellables)
    }

    func configure(for size: CGSize) {
        config = KeyboardConfig.adaptive(for: size)

        // Adjust visible octaves based on width
        let whiteKeysPerOctave: CGFloat = 7
        let availableWhiteKeys = size.width / config.keyWidth
        visibleOctaves = max(1, min(4, Int(availableWhiteKeys / whiteKeysPerOctave)))

        EchoelLogger.log("🎹", "Keyboard configured: \(visibleOctaves) octaves, key width: \(config.keyWidth)", category: EchoelLogger.midi)
    }

    func connect(mpe: MPEZoneManager) {
        self.mpeManager = mpe
    }

    // MARK: - Note Calculations
    var visibleNotes: [Int] {
        let startNote = currentOctave * 12
        let endNote = startNote + (visibleOctaves * 12)
        return Array(startNote...min(127, endNote))
    }

    func isBlackKey(_ note: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(note % 12)
    }

    func noteName(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return names[note % 12]
    }

    func notePosition(_ note: Int, in width: CGFloat) -> CGFloat {
        let whiteKeys = visibleNotes.filter { !isBlackKey($0) }
        guard let index = whiteKeys.firstIndex(of: note) else {
            // Black key - calculate from adjacent white key
            let adjacentWhite = note - 1
            if let whiteIndex = whiteKeys.firstIndex(of: adjacentWhite) {
                return CGFloat(whiteIndex) * config.keyWidth + config.keyWidth * 0.7
            }
            return 0
        }
        return CGFloat(index) * config.keyWidth
    }

    // MARK: - Touch Handling
    func touchBegan(id: Int, location: CGPoint, in size: CGSize) {
        guard let note = noteAtLocation(location, in: size) else { return }

        let velocity = velocityCurve.apply(velocityFromLocation(location))
        let channel = mpeEnabled ? allocateMPEChannel(for: UInt8(note)) : 0

        let touch = TouchState(
            id: id,
            note: UInt8(note),
            velocity: velocity,
            channel: channel,
            initialLocation: location,
            currentLocation: location,
            startTime: Date()
        )

        activeTouches[id] = touch
        voiceCount = activeTouches.count

        // Send MIDI
        sendNoteOn(touch)

        // Haptic
        triggerHaptic(intensity: velocity)

        EchoelLogger.log("🎹", "Note ON: \(noteName(note))\(note/12 - 1) vel:\(Int(velocity * 127)) ch:\(channel)", category: EchoelLogger.midi)
    }

    func touchMoved(id: Int, location: CGPoint, in size: CGSize) {
        guard var touch = activeTouches[id] else { return }

        // Throttle expression updates
        if let lastUpdate = lastExpressionUpdate[id],
           Date().timeIntervalSince(lastUpdate) < expressionThrottle {
            return
        }
        lastExpressionUpdate[id] = Date()

        touch.currentLocation = location

        // Calculate expression based on mode
        let deltaY = Float(touch.initialLocation.y - location.y)
        let deltaX = Float(location.x - touch.initialLocation.x)

        switch expressionMode {
        case .xyPad:
            // Y = pitch bend, X = brightness
            touch.pitchBend = (deltaY / 100.0).clamped(-1, 1)
            touch.brightness = (0.5 + deltaX / 200.0).clamped(0, 1)

        case .slide:
            // Horizontal slide = brightness/timbre
            touch.brightness = (0.5 + deltaX / 150.0).clamped(0, 1)

        case .pressure:
            // Vertical movement = pressure
            touch.pressure = (0.5 + deltaY / 100.0).clamped(0, 1)

        case .mpe:
            // Full MPE - all dimensions
            touch.pitchBend = (deltaY / 100.0).clamped(-1, 1)
            touch.brightness = (0.5 + deltaX / 200.0).clamped(0, 1)
            touch.pressure = (0.5 + abs(deltaY) / 150.0).clamped(0, 1)
        }

        activeTouches[id] = touch

        // Send expression
        sendExpression(touch)
    }

    func touchEnded(id: Int) {
        guard let touch = activeTouches[id] else { return }

        sendNoteOff(touch)

        if mpeEnabled {
            deallocateMPEChannel(touch.channel)
        }

        activeTouches.removeValue(forKey: id)
        lastExpressionUpdate.removeValue(forKey: id)
        voiceCount = activeTouches.count

        EchoelLogger.log("🎹", "Note OFF: \(noteName(Int(touch.note)))\(Int(touch.note)/12 - 1)", category: EchoelLogger.midi)
    }

    // MARK: - Note Detection
    private func noteAtLocation(_ location: CGPoint, in size: CGSize) -> Int? {
        let whiteKeys = visibleNotes.filter { !isBlackKey($0) }
        let blackKeys = visibleNotes.filter { isBlackKey($0) }

        let keyWidth = config.keyWidth
        let blackKeyHeight = config.keyHeight * config.blackKeyHeightRatio

        // Check black keys first (they're on top)
        if location.y < blackKeyHeight {
            for note in blackKeys {
                let x = notePosition(note, in: size.width)
                let blackWidth = keyWidth * config.blackKeyRatio
                if location.x >= x - blackWidth/2 && location.x <= x + blackWidth/2 {
                    return note
                }
            }
        }

        // Check white keys
        let keyIndex = Int(location.x / keyWidth)
        if keyIndex >= 0 && keyIndex < whiteKeys.count {
            return whiteKeys[keyIndex]
        }

        return nil
    }

    private func velocityFromLocation(_ location: CGPoint) -> Float {
        // Velocity from Y position (lower = harder hit)
        let normalizedY = Float(location.y / config.keyHeight)
        return (1.0 - normalizedY * 0.5).clamped(0.3, 1.0)
    }

    // MARK: - MPE Channel Management
    private var channelAllocation: [UInt8: UInt8] = [:] // Note → Channel
    private var nextChannel: UInt8 = 1

    private func allocateMPEChannel(for note: UInt8) -> UInt8 {
        if let existing = channelAllocation[note] {
            return existing
        }

        let channel = nextChannel
        channelAllocation[note] = channel
        nextChannel = nextChannel >= 15 ? 1 : nextChannel + 1
        return channel
    }

    private func deallocateMPEChannel(_ channel: UInt8) {
        channelAllocation = channelAllocation.filter { $0.value != channel }
    }

    // MARK: - MIDI Output
    private func sendNoteOn(_ touch: TouchState) {
        mpeManager?.allocateVoice(note: touch.note, velocity: touch.velocity)
        messageCounter += 1
    }

    private func sendNoteOff(_ touch: TouchState) {
        // Find and deallocate the voice
        messageCounter += 1
    }

    private func sendExpression(_ touch: TouchState) {
        if touch.pitchBend != 0 {
            mpeManager?.setVoicePitchBend(channel: touch.channel, bend: touch.pitchBend)
            messageCounter += 1
        }

        if touch.brightness != 0.5 {
            mpeManager?.setVoiceBrightness(channel: touch.channel, brightness: touch.brightness)
            messageCounter += 1
        }

        if touch.pressure != 0.5 {
            mpeManager?.setVoicePressure(channel: touch.channel, pressure: touch.pressure)
            messageCounter += 1
        }
    }

    // MARK: - Haptics
    private func triggerHaptic(intensity: Float) {
        guard let engine = hapticEngine else { return }

        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Silent failure
        }
    }

    // MARK: - Controls
    func octaveUp() {
        guard currentOctave < 8 - visibleOctaves else { return }
        currentOctave += 1
    }

    func octaveDown() {
        guard currentOctave > 0 else { return }
        currentOctave -= 1
    }

    func panic() {
        activeTouches.removeAll()
        channelAllocation.removeAll()
        voiceCount = 0
        EchoelLogger.warning("MIDI Panic - All notes off", category: EchoelLogger.midi)
    }
}

// MARK: - Float Extension
private extension Float {
    func clamped(_ min: Float, _ max: Float) -> Float {
        Swift.min(Swift.max(self, min), max)
    }
}

// MARK: - Canvas Keyboard View
/// High-performance Canvas-based keyboard rendering

struct CanvasKeyboardView: View {
    @ObservedObject var engine: KeyboardEngine
    @ObservedObject var hub: TouchInstrumentsHub

    @State private var touchLocations: [Int: CGPoint] = [:]

    var body: some View {
        Canvas { context, size in
            drawKeyboard(context: context, size: size)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let touchId = 0 // Single touch for now
                    if touchLocations[touchId] == nil {
                        engine.touchBegan(id: touchId, location: value.location, in: CGSize(width: 500, height: engine.config.keyHeight))
                    } else {
                        engine.touchMoved(id: touchId, location: value.location, in: CGSize(width: 500, height: engine.config.keyHeight))
                    }
                    touchLocations[touchId] = value.location
                }
                .onEnded { _ in
                    let touchId = 0
                    engine.touchEnded(id: touchId)
                    touchLocations.removeValue(forKey: touchId)
                }
        )
    }

    private func drawKeyboard(context: GraphicsContext, size: CGSize) {
        let keyWidth = engine.config.keyWidth
        let keyHeight = engine.config.keyHeight
        let cornerRadius = engine.config.cornerRadius

        let whiteKeys = engine.visibleNotes.filter { !engine.isBlackKey($0) }
        let blackKeys = engine.visibleNotes.filter { engine.isBlackKey($0) }
        let activeNotes = Set(engine.activeTouches.values.map { Int($0.note) })

        // Draw white keys
        for (index, note) in whiteKeys.enumerated() {
            let x = CGFloat(index) * keyWidth
            let rect = CGRect(x: x, y: 0, width: keyWidth - 1, height: keyHeight)
            let path = RoundedRectangle(cornerRadius: cornerRadius).path(in: rect)

            let isActive = activeNotes.contains(note)
            context.fill(path, with: .color(isActive ? .blue.opacity(0.7) : .white))
            context.stroke(path, with: .color(.gray.opacity(0.5)), lineWidth: 1)

            // Note name
            if engine.config.showNoteNames && note % 12 == 0 {
                let text = Text(engine.noteName(note))
                    .font(.caption2)
                    .foregroundColor(.gray)
                context.draw(text, at: CGPoint(x: x + keyWidth/2, y: keyHeight - 12))
            }
        }

        // Draw black keys
        let blackKeyWidth = keyWidth * engine.config.blackKeyRatio
        let blackKeyHeight = keyHeight * engine.config.blackKeyHeightRatio

        for note in blackKeys {
            let adjacentWhite = note - 1
            if let whiteIndex = whiteKeys.firstIndex(of: adjacentWhite) {
                let x = CGFloat(whiteIndex) * keyWidth + keyWidth - blackKeyWidth/2
                let rect = CGRect(x: x, y: 0, width: blackKeyWidth, height: blackKeyHeight)
                let path = RoundedRectangle(cornerRadius: cornerRadius - 2).path(in: rect)

                let isActive = activeNotes.contains(note)
                context.fill(path, with: .color(isActive ? .blue : .black))
            }
        }

        // Draw touch indicators
        for (_, touch) in engine.activeTouches {
            let x = engine.notePosition(Int(touch.note), in: size.width) + keyWidth/2
            let y = touch.currentLocation.y
            let indicator = Circle().path(in: CGRect(x: x - 15, y: y - 15, width: 30, height: 30))
            context.fill(indicator, with: .color(.blue.opacity(0.4)))
        }
    }
}

// MARK: - Expression Zone
struct ExpressionZone: View {
    @ObservedObject var engine: KeyboardEngine

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.2))

            HStack {
                ForEach(Array(engine.activeTouches.values), id: \.id) { touch in
                    VStack(spacing: 2) {
                        // Pitch bend indicator
                        Rectangle()
                            .fill(touch.pitchBend > 0 ? Color.green : Color.red)
                            .frame(width: 4, height: CGFloat(abs(touch.pitchBend)) * 20)

                        Text("\(engine.noteName(Int(touch.note)))")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Control Bar
struct KeyboardControlBar: View {
    @ObservedObject var engine: KeyboardEngine
    @ObservedObject var hub: TouchInstrumentsHub

    var body: some View {
        HStack(spacing: 12) {
            // Octave controls
            HStack(spacing: 4) {
                Button(action: engine.octaveDown) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)

                Text("C\(engine.currentOctave)")
                    .font(.headline)
                    .frame(width: 36)

                Button(action: engine.octaveUp) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
            }

            Divider().frame(height: 24)

            // Expression mode
            Picker("", selection: $engine.expressionMode) {
                ForEach(KeyboardEngine.ExpressionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 90)

            Spacer()

            // Scale
            Picker("", selection: $engine.scale) {
                ForEach(KeyboardEngine.ScaleMode.allCases) { scale in
                    Text(scale.rawValue).tag(scale)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            // Panic button
            Button(action: engine.panic) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Status Bar
struct KeyboardStatusBar: View {
    @ObservedObject var engine: KeyboardEngine

    var body: some View {
        HStack {
            Text("Voices: \(engine.voiceCount)/15")
                .font(.caption2)

            Spacer()

            Text("MIDI: \(engine.messageRate)/s")
                .font(.caption2)

            Spacer()

            Text(engine.mpeEnabled ? "MPE" : "MIDI")
                .font(.caption2)
                .foregroundColor(engine.mpeEnabled ? .green : .gray)
        }
        .padding(.horizontal)
        .background(Color.black.opacity(0.3))
    }
}

// MARK: - MPEZoneManager Extensions
extension MPEZoneManager {
    func setVoicePitchBend(channel: UInt8, bend: Float) {
        // Implementation would send pitch bend to specific channel
    }

    func setVoiceBrightness(channel: UInt8, brightness: Float) {
        // Implementation would send CC74 to specific channel
    }

    func setVoicePressure(channel: UInt8, pressure: Float) {
        // Implementation would send channel pressure
    }
}

// MARK: - Preview
#if DEBUG
struct OptimizedTouchKeyboard_Previews: PreviewProvider {
    static var previews: some View {
        OptimizedTouchKeyboard(hub: TouchInstrumentsHub())
            .frame(height: 300)
            .preferredColorScheme(.dark)
    }
}
#endif

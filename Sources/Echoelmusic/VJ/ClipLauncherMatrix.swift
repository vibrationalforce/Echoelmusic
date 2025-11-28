// ClipLauncherMatrix.swift
// Echoelmusic - Professional VJ Clip Launcher Matrix
// Rivals: Resolume Arena, VDMX, Modul8, GrandVJ

import SwiftUI
import AVFoundation
import Combine
import Metal
import MetalKit

// MARK: - VJ Data Models

/// Visual clip for VJ performance
struct VJClip: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: ClipType
    var sourceURL: URL?
    var thumbnailURL: URL?
    var duration: Double
    var isLooping: Bool = true
    var playbackSpeed: Double = 1.0
    var blendMode: BlendMode = .normal
    var opacity: Float = 1.0
    var transform: ClipTransform = ClipTransform()
    var colorAdjustments: ColorAdjustments = ColorAdjustments()
    var effects: [VJEffect] = []
    var triggerMode: TriggerMode = .toggle
    var beatSync: BeatSync = .free
    var audioReactivity: AudioReactivity = AudioReactivity()
    var state: PlayState = .stopped

    enum ClipType: String, Codable, CaseIterable {
        case video = "Video"
        case image = "Image"
        case generator = "Generator"
        case shader = "Shader"
        case composition = "Composition"
        case camera = "Camera"
        case ndi = "NDI"
        case syphon = "Syphon"
        case spout = "Spout"
    }

    enum BlendMode: String, Codable, CaseIterable {
        case normal = "Normal"
        case add = "Add"
        case multiply = "Multiply"
        case screen = "Screen"
        case overlay = "Overlay"
        case difference = "Difference"
        case exclusion = "Exclusion"
        case hardLight = "Hard Light"
        case softLight = "Soft Light"
        case colorDodge = "Color Dodge"
        case colorBurn = "Color Burn"
        case lighten = "Lighten"
        case darken = "Darken"
        case lumaKey = "Luma Key"
        case chromaKey = "Chroma Key"
    }

    struct ClipTransform: Codable {
        var positionX: Float = 0
        var positionY: Float = 0
        var scaleX: Float = 1.0
        var scaleY: Float = 1.0
        var rotation: Float = 0
        var anchorX: Float = 0.5
        var anchorY: Float = 0.5

        // 3D Transform
        var rotationX: Float = 0
        var rotationY: Float = 0
        var rotationZ: Float = 0
        var perspective: Float = 0
    }

    struct ColorAdjustments: Codable {
        var brightness: Float = 0
        var contrast: Float = 1.0
        var saturation: Float = 1.0
        var hue: Float = 0
        var temperature: Float = 0
        var tint: Float = 0
        var gamma: Float = 1.0
        var exposure: Float = 0
        var vibrance: Float = 0
    }

    enum TriggerMode: String, Codable, CaseIterable {
        case toggle = "Toggle"
        case gate = "Gate"
        case oneShot = "One Shot"
        case retrigger = "Retrigger"
        case random = "Random"
    }

    enum BeatSync: String, Codable, CaseIterable {
        case free = "Free"
        case beatSnap = "Beat Snap"
        case halfBar = "1/2 Bar"
        case oneBar = "1 Bar"
        case twoBar = "2 Bar"
        case fourBar = "4 Bar"
    }

    struct AudioReactivity: Codable {
        var isEnabled: Bool = false
        var frequencyBand: FrequencyBand = .full
        var sensitivity: Float = 1.0
        var smoothing: Float = 0.5
        var targetParameter: ReactiveParameter = .opacity

        enum FrequencyBand: String, Codable, CaseIterable {
            case full = "Full"
            case sub = "Sub (20-60Hz)"
            case bass = "Bass (60-250Hz)"
            case lowMid = "Low Mid (250-500Hz)"
            case mid = "Mid (500-2kHz)"
            case highMid = "High Mid (2k-4kHz)"
            case presence = "Presence (4k-6kHz)"
            case brilliance = "Brilliance (6k-20kHz)"
        }

        enum ReactiveParameter: String, Codable, CaseIterable {
            case opacity = "Opacity"
            case scale = "Scale"
            case rotation = "Rotation"
            case positionX = "Position X"
            case positionY = "Position Y"
            case brightness = "Brightness"
            case saturation = "Saturation"
            case hue = "Hue"
            case speed = "Speed"
            case effectParam = "Effect Param"
        }
    }

    enum PlayState: String, Codable {
        case stopped
        case playing
        case paused
        case triggered
        case fading
    }
}

/// VJ Effect
struct VJEffect: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: EffectType
    var isEnabled: Bool = true
    var isAudioReactive: Bool = false
    var parameters: [String: Float]

    enum EffectType: String, Codable, CaseIterable {
        // Blur & Distortion
        case blur = "Blur"
        case motionBlur = "Motion Blur"
        case radialBlur = "Radial Blur"
        case zoomBlur = "Zoom Blur"
        case pixelate = "Pixelate"
        case kaleidoscope = "Kaleidoscope"
        case mirror = "Mirror"
        case twirl = "Twirl"
        case sphere = "Sphere"
        case ripple = "Ripple"
        case wave = "Wave"
        case tunnel = "Tunnel"

        // Color
        case colorize = "Colorize"
        case invert = "Invert"
        case posterize = "Posterize"
        case threshold = "Threshold"
        case chromaShift = "Chroma Shift"
        case rgbSplit = "RGB Split"
        case vhs = "VHS"
        case filmGrain = "Film Grain"
        case halftone = "Halftone"

        // Glow & Light
        case glow = "Glow"
        case bloom = "Bloom"
        case godRays = "God Rays"
        case lensFlare = "Lens Flare"
        case vignette = "Vignette"

        // Edge & Detail
        case edge = "Edge Detect"
        case emboss = "Emboss"
        case sharpen = "Sharpen"
        case sketch = "Sketch"

        // Feedback
        case feedback = "Feedback"
        case echo = "Echo"
        case trails = "Trails"
        case infiniteZoom = "Infinite Zoom"

        // Generative
        case noise = "Noise"
        case plasma = "Plasma"
        case fractal = "Fractal"
        case particles = "Particles"
    }
}

/// VJ Layer/Deck
struct VJDeck: Identifiable, Codable {
    let id: UUID
    var name: String
    var clips: [[VJClip]] // Grid of clips (rows x columns)
    var activeClipId: UUID?
    var masterOpacity: Float = 1.0
    var blendMode: VJClip.BlendMode = .normal
    var crossfadePosition: Float = 0.5 // 0 = deck A, 1 = deck B
    var effects: [VJEffect] = []
    var isSolo: Bool = false
    var isBypassed: Bool = false
}

/// VJ Output configuration
struct VJOutput: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: OutputType
    var resolution: Resolution
    var isEnabled: Bool
    var isFullscreen: Bool
    var displayIndex: Int
    var outputMapping: OutputMapping?

    enum OutputType: String, Codable, CaseIterable {
        case preview = "Preview"
        case display = "Display"
        case ndi = "NDI"
        case syphon = "Syphon"
        case spout = "Spout"
        case virtualCamera = "Virtual Camera"
        case recording = "Recording"
    }

    struct Resolution: Codable {
        var width: Int
        var height: Int
        var frameRate: Double

        static let hd720 = Resolution(width: 1280, height: 720, frameRate: 60)
        static let hd1080 = Resolution(width: 1920, height: 1080, frameRate: 60)
        static let uhd4k = Resolution(width: 3840, height: 2160, frameRate: 60)
    }

    struct OutputMapping: Codable {
        var cornerPins: [CGPoint] // 4 corners for quad warping
        var edgeBlending: EdgeBlending?
        var colorCorrection: VJClip.ColorAdjustments?

        struct EdgeBlending: Codable {
            var leftBlend: Float
            var rightBlend: Float
            var topBlend: Float
            var bottomBlend: Float
            var gamma: Float
        }
    }
}

// MARK: - VJ Engine

@MainActor
class VJEngine: ObservableObject {
    // Decks
    @Published var deckA: VJDeck
    @Published var deckB: VJDeck
    @Published var masterDeck: VJDeck

    // Crossfader
    @Published var crossfaderPosition: Float = 0.5
    @Published var crossfaderCurve: CrossfaderCurve = .linear

    // Tempo
    @Published var tempo: Double = 120
    @Published var currentBeat: Double = 0
    @Published var isTapTempoActive: Bool = false

    // Audio Analysis
    @Published var audioLevel: Float = 0
    @Published var audioPeaks: [Float] = Array(repeating: 0, count: 8)
    @Published var beatDetected: Bool = false

    // Output
    @Published var outputs: [VJOutput] = []
    @Published var masterOutput: VJOutput

    // Selection
    @Published var selectedDeckId: UUID?
    @Published var selectedClipId: UUID?

    // Performance
    @Published var fps: Double = 60
    @Published var gpuUsage: Float = 0

    // Tap Tempo
    private var tapTimes: [Date] = []

    // Metal Rendering
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?

    enum CrossfaderCurve: String, CaseIterable {
        case linear = "Linear"
        case equal = "Equal Power"
        case cut = "Cut"
        case smooth = "Smooth"
    }

    init() {
        // Initialize Deck A
        deckA = VJDeck(
            id: UUID(),
            name: "Deck A",
            clips: VJEngine.createDefaultClipGrid()
        )

        // Initialize Deck B
        deckB = VJDeck(
            id: UUID(),
            name: "Deck B",
            clips: VJEngine.createDefaultClipGrid()
        )

        // Initialize Master
        masterDeck = VJDeck(
            id: UUID(),
            name: "Master",
            clips: []
        )

        // Initialize Master Output
        masterOutput = VJOutput(
            id: UUID(),
            name: "Main Output",
            type: .display,
            resolution: .hd1080,
            isEnabled: true,
            isFullscreen: false,
            displayIndex: 0
        )

        setupMetal()
        setupDefaultOutputs()
    }

    private static func createDefaultClipGrid() -> [[VJClip]] {
        var grid: [[VJClip]] = []
        let clipNames = [
            ["Tunnel", "Particles", "Waves", "Fractal"],
            ["Strobe", "Flash", "Pulse", "Beat"],
            ["Logo A", "Logo B", "Text 1", "Text 2"],
            ["Cam 1", "Cam 2", "NDI In", "Empty"],
        ]

        for (rowIndex, row) in clipNames.enumerated() {
            var clipRow: [VJClip] = []
            for (colIndex, name) in row.enumerated() {
                let clip = VJClip(
                    id: UUID(),
                    name: name,
                    type: rowIndex == 3 ? (colIndex < 2 ? .camera : colIndex == 2 ? .ndi : .generator) : .generator,
                    duration: 0,
                    isLooping: true
                )
                clipRow.append(clip)
            }
            grid.append(clipRow)
        }
        return grid
    }

    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        commandQueue = metalDevice?.makeCommandQueue()
    }

    private func setupDefaultOutputs() {
        outputs = [
            VJOutput(id: UUID(), name: "Preview", type: .preview, resolution: .hd720, isEnabled: true, isFullscreen: false, displayIndex: 0),
            masterOutput,
        ]
    }

    // MARK: - Clip Control

    func triggerClip(_ clipId: UUID, in deckId: UUID) {
        // Find and trigger clip
        if deckA.id == deckId {
            triggerClipInDeck(&deckA, clipId: clipId)
        } else if deckB.id == deckId {
            triggerClipInDeck(&deckB, clipId: clipId)
        }
    }

    private func triggerClipInDeck(_ deck: inout VJDeck, clipId: UUID) {
        for rowIndex in deck.clips.indices {
            for colIndex in deck.clips[rowIndex].indices {
                if deck.clips[rowIndex][colIndex].id == clipId {
                    let currentState = deck.clips[rowIndex][colIndex].state

                    switch deck.clips[rowIndex][colIndex].triggerMode {
                    case .toggle:
                        deck.clips[rowIndex][colIndex].state = currentState == .playing ? .stopped : .playing
                    case .gate:
                        deck.clips[rowIndex][colIndex].state = .playing
                    case .oneShot:
                        deck.clips[rowIndex][colIndex].state = .playing
                        // Will auto-stop at end
                    case .retrigger:
                        deck.clips[rowIndex][colIndex].state = .playing
                        // Reset playhead
                    case .random:
                        // Trigger random clip in same column
                        break
                    }

                    // Stop other clips in same column (exclusive mode)
                    if deck.clips[rowIndex][colIndex].state == .playing {
                        deck.activeClipId = clipId
                        for otherRow in deck.clips.indices {
                            if otherRow != rowIndex {
                                deck.clips[otherRow][colIndex].state = .stopped
                            }
                        }
                    }
                    return
                }
            }
        }
    }

    func stopClip(_ clipId: UUID, in deckId: UUID) {
        if deckA.id == deckId {
            stopClipInDeck(&deckA, clipId: clipId)
        } else if deckB.id == deckId {
            stopClipInDeck(&deckB, clipId: clipId)
        }
    }

    private func stopClipInDeck(_ deck: inout VJDeck, clipId: UUID) {
        for rowIndex in deck.clips.indices {
            for colIndex in deck.clips[rowIndex].indices {
                if deck.clips[rowIndex][colIndex].id == clipId {
                    deck.clips[rowIndex][colIndex].state = .stopped
                    if deck.activeClipId == clipId {
                        deck.activeClipId = nil
                    }
                    return
                }
            }
        }
    }

    func stopAllClips(in deckId: UUID) {
        if deckA.id == deckId {
            stopAllInDeck(&deckA)
        } else if deckB.id == deckId {
            stopAllInDeck(&deckB)
        }
    }

    private func stopAllInDeck(_ deck: inout VJDeck) {
        for rowIndex in deck.clips.indices {
            for colIndex in deck.clips[rowIndex].indices {
                deck.clips[rowIndex][colIndex].state = .stopped
            }
        }
        deck.activeClipId = nil
    }

    func triggerColumn(_ columnIndex: Int) {
        // Trigger first clip in column for each deck
        if columnIndex < deckA.clips.first?.count ?? 0 {
            for rowIndex in deckA.clips.indices {
                if deckA.clips[rowIndex][columnIndex].state != .playing {
                    let clipId = deckA.clips[rowIndex][columnIndex].id
                    triggerClip(clipId, in: deckA.id)
                    break
                }
            }
        }
    }

    // MARK: - Crossfader

    func setCrossfader(_ position: Float) {
        crossfaderPosition = max(0, min(1, position))
    }

    func crossfadeLeft() {
        setCrossfader(0)
    }

    func crossfadeRight() {
        setCrossfader(1)
    }

    func crossfadeCenter() {
        setCrossfader(0.5)
    }

    // MARK: - Tempo & Beat

    func setTempo(_ bpm: Double) {
        tempo = max(20, min(300, bpm))
    }

    func tapTempo() {
        let now = Date()
        tapTimes.append(now)

        // Keep only last 4 taps
        if tapTimes.count > 4 {
            tapTimes.removeFirst()
        }

        // Calculate tempo from taps
        if tapTimes.count >= 2 {
            var intervals: [TimeInterval] = []
            for i in 1..<tapTimes.count {
                intervals.append(tapTimes[i].timeIntervalSince(tapTimes[i-1]))
            }
            let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            let calculatedBPM = 60.0 / averageInterval
            setTempo(calculatedBPM)
        }

        isTapTempoActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isTapTempoActive = false
        }
    }

    func nudgeTempo(_ amount: Double) {
        setTempo(tempo + amount)
    }

    // MARK: - Effects

    func addEffect(to deckId: UUID, effect: VJEffect) {
        if deckA.id == deckId {
            deckA.effects.append(effect)
        } else if deckB.id == deckId {
            deckB.effects.append(effect)
        } else if masterDeck.id == deckId {
            masterDeck.effects.append(effect)
        }
    }

    func removeEffect(from deckId: UUID, effectId: UUID) {
        if deckA.id == deckId {
            deckA.effects.removeAll { $0.id == effectId }
        } else if deckB.id == deckId {
            deckB.effects.removeAll { $0.id == effectId }
        } else if masterDeck.id == deckId {
            masterDeck.effects.removeAll { $0.id == effectId }
        }
    }

    func toggleEffect(_ effectId: UUID, in deckId: UUID) {
        if deckA.id == deckId {
            if let index = deckA.effects.firstIndex(where: { $0.id == effectId }) {
                deckA.effects[index].isEnabled.toggle()
            }
        } else if deckB.id == deckId {
            if let index = deckB.effects.firstIndex(where: { $0.id == effectId }) {
                deckB.effects[index].isEnabled.toggle()
            }
        }
    }

    // MARK: - Output Control

    func toggleOutput(_ outputId: UUID) {
        if let index = outputs.firstIndex(where: { $0.id == outputId }) {
            outputs[index].isEnabled.toggle()
        }
    }

    func setOutputFullscreen(_ outputId: UUID, fullscreen: Bool) {
        if let index = outputs.firstIndex(where: { $0.id == outputId }) {
            outputs[index].isFullscreen = fullscreen
        }
    }

    func addNDIOutput() {
        let output = VJOutput(
            id: UUID(),
            name: "NDI Output \(outputs.count)",
            type: .ndi,
            resolution: .hd1080,
            isEnabled: true,
            isFullscreen: false,
            displayIndex: 0
        )
        outputs.append(output)
    }

    func addSyphonOutput() {
        let output = VJOutput(
            id: UUID(),
            name: "Syphon Output \(outputs.count)",
            type: .syphon,
            resolution: .hd1080,
            isEnabled: true,
            isFullscreen: false,
            displayIndex: 0
        )
        outputs.append(output)
    }
}

// MARK: - VJ Clip Launcher View

struct ClipLauncherMatrix: View {
    @StateObject private var engine = VJEngine()
    @State private var selectedTab: Int = 0
    @State private var showingEffectRack = false
    @State private var showingOutputSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar

            // Main Content
            HStack(spacing: 0) {
                // Deck A
                DeckView(deck: $engine.deckA, engine: engine, label: "A")

                // Crossfader & Master
                centerControls

                // Deck B
                DeckView(deck: $engine.deckB, engine: engine, label: "B")
            }

            // Bottom Bar - Master Effects & Output
            bottomBar
        }
        .background(Color.black)
        .sheet(isPresented: $showingEffectRack) {
            EffectRackView(engine: engine)
        }
        .sheet(isPresented: $showingOutputSettings) {
            OutputSettingsView(engine: engine)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            // Logo
            Text("ECHOELMUSIC VJ")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(.cyan)

            Divider().frame(height: 30)

            // Tempo Section
            HStack(spacing: 8) {
                // BPM Display
                VStack(spacing: 0) {
                    Text("\(Int(engine.tempo))")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                    Text("BPM")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(width: 60)

                // Tempo Controls
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Button("-1") { engine.nudgeTempo(-1) }
                            .buttonStyle(VJButtonStyle(size: .small))
                        Button("+1") { engine.nudgeTempo(1) }
                            .buttonStyle(VJButtonStyle(size: .small))
                    }
                    Button("TAP") { engine.tapTempo() }
                        .buttonStyle(VJButtonStyle(size: .small, isActive: engine.isTapTempoActive))
                }
            }

            // Beat Indicator
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { beat in
                    Circle()
                        .fill(Int(engine.currentBeat) % 4 == beat ? Color.green : Color(white: 0.3))
                        .frame(width: 12, height: 12)
                }
            }

            Spacer()

            // Audio Level
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { band in
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 8, height: CGFloat(engine.audioPeaks[band]) * 30)
                }
            }
            .frame(height: 30)

            Divider().frame(height: 30)

            // Performance
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(engine.fps)) FPS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(engine.fps > 55 ? .green : engine.fps > 45 ? .yellow : .red)
                Text("GPU \(Int(engine.gpuUsage * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }

            // Output Button
            Button(action: { showingOutputSettings = true }) {
                Label("OUTPUT", systemImage: "display")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(VJButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.08))
    }

    // MARK: - Center Controls

    private var centerControls: some View {
        VStack(spacing: 12) {
            // Preview
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)

                Text("PREVIEW")
                    .foregroundColor(.gray)
            }
            .frame(width: 200)
            .overlay(
                Rectangle().stroke(Color(white: 0.3), lineWidth: 1)
            )

            // Crossfader
            VStack(spacing: 8) {
                HStack {
                    Text("A")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(engine.crossfaderPosition < 0.5 ? .cyan : .gray)

                    Spacer()

                    Text("B")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(engine.crossfaderPosition > 0.5 ? .magenta : .gray)
                }

                Slider(value: $engine.crossfaderPosition, in: 0...1)
                    .tint(.white)

                HStack(spacing: 4) {
                    Button("A") { engine.crossfadeLeft() }
                        .buttonStyle(VJButtonStyle(size: .small))
                    Button("MID") { engine.crossfadeCenter() }
                        .buttonStyle(VJButtonStyle(size: .small))
                    Button("B") { engine.crossfadeRight() }
                        .buttonStyle(VJButtonStyle(size: .small))
                }
            }
            .padding(.horizontal, 8)

            // Master Opacity
            VStack(spacing: 4) {
                Text("MASTER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)

                Slider(value: $engine.masterDeck.masterOpacity, in: 0...1)
                    .tint(.white)
                    .frame(height: 100)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 30)
            }

            Spacer()

            // Master Effects Button
            Button(action: { showingEffectRack = true }) {
                Label("EFFECTS", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(VJButtonStyle())

            // Blackout
            Button("BLACKOUT") {
                engine.masterDeck.masterOpacity = engine.masterDeck.masterOpacity > 0 ? 0 : 1
            }
            .buttonStyle(VJButtonStyle(isDestructive: engine.masterDeck.masterOpacity == 0))
        }
        .frame(width: 200)
        .padding(.vertical, 12)
        .background(Color(white: 0.1))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Output indicators
            ForEach(engine.outputs) { output in
                HStack(spacing: 4) {
                    Circle()
                        .fill(output.isEnabled ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(output.name)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Quick Actions
            HStack(spacing: 8) {
                Button("FLASH") {}
                    .buttonStyle(VJButtonStyle())
                Button("STROBE") {}
                    .buttonStyle(VJButtonStyle())
                Button("FREEZE") {}
                    .buttonStyle(VJButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(white: 0.05))
    }
}

// MARK: - Deck View

struct DeckView: View {
    @Binding var deck: VJDeck
    @ObservedObject var engine: VJEngine
    let label: String

    private let clipSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            // Deck Header
            HStack {
                Text("DECK \(label)")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(label == "A" ? .cyan : .magenta)

                Spacer()

                // Deck Opacity
                HStack(spacing: 4) {
                    Text("\(Int(deck.masterOpacity * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                    Slider(value: $deck.masterOpacity, in: 0...1)
                        .frame(width: 60)
                }

                // Blend Mode
                Picker("", selection: $deck.blendMode) {
                    ForEach(VJClip.BlendMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 80)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(white: 0.12))

            // Clip Grid
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(deck.clips.indices, id: \.self) { rowIndex in
                        HStack(spacing: 4) {
                            // Row Label
                            Text("\(rowIndex + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                                .frame(width: 20)

                            // Clips
                            ForEach(deck.clips[rowIndex].indices, id: \.self) { colIndex in
                                VJClipButton(
                                    clip: $deck.clips[rowIndex][colIndex],
                                    engine: engine,
                                    deckId: deck.id
                                )
                                .frame(width: clipSize, height: clipSize)
                            }
                        }
                    }
                }
                .padding(8)
            }

            // Column Controls
            HStack(spacing: 4) {
                Rectangle().fill(Color.clear).frame(width: 20)
                ForEach(0..<(deck.clips.first?.count ?? 4), id: \.self) { col in
                    Button("\(col + 1)") {
                        // Trigger column
                    }
                    .buttonStyle(VJButtonStyle(size: .small))
                    .frame(width: clipSize)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            // Deck Effects
            HStack(spacing: 4) {
                ForEach(deck.effects) { effect in
                    Button(effect.name) {
                        engine.toggleEffect(effect.id, in: deck.id)
                    }
                    .buttonStyle(VJButtonStyle(isActive: effect.isEnabled))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(white: 0.08))
    }
}

// MARK: - VJ Clip Button

struct VJClipButton: View {
    @Binding var clip: VJClip
    @ObservedObject var engine: VJEngine
    let deckId: UUID

    @State private var isHovering = false

    var body: some View {
        Button(action: {
            engine.triggerClip(clip.id, in: deckId)
        }) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(clipBackgroundColor)

                // Content
                VStack(spacing: 4) {
                    // Thumbnail or Icon
                    if let _ = clip.thumbnailURL {
                        // Load thumbnail
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    } else {
                        Image(systemName: clipIcon)
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Name
                    Text(clip.name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(4)

                // State Indicator
                if clip.state == .playing {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.green, lineWidth: 3)

                    // Playing animation
                    VStack {
                        HStack {
                            Spacer()
                            PlayingIndicator()
                                .frame(width: 16, height: 16)
                        }
                        Spacer()
                    }
                    .padding(4)
                }

                if clip.state == .triggered {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.yellow.opacity(0.8), lineWidth: 2)
                }

                // Audio Reactive Indicator
                if clip.audioReactivity.isEnabled {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "waveform")
                                .font(.system(size: 8))
                                .foregroundColor(.cyan)
                            Spacer()
                        }
                    }
                    .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Edit Clip") {}
            Button("Duplicate") {}
            Divider()
            Menu("Trigger Mode") {
                ForEach(VJClip.TriggerMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) {
                        clip.triggerMode = mode
                    }
                }
            }
            Menu("Beat Sync") {
                ForEach(VJClip.BeatSync.allCases, id: \.self) { sync in
                    Button(sync.rawValue) {
                        clip.beatSync = sync
                    }
                }
            }
            Divider()
            Button("Clear", role: .destructive) {}
        }
    }

    private var clipBackgroundColor: Color {
        switch clip.state {
        case .playing:
            return Color.green.opacity(0.3)
        case .triggered:
            return Color.yellow.opacity(0.2)
        case .fading:
            return Color.orange.opacity(0.2)
        default:
            return isHovering ? Color(white: 0.25) : Color(white: 0.15)
        }
    }

    private var clipIcon: String {
        switch clip.type {
        case .video: return "film"
        case .image: return "photo"
        case .generator: return "sparkles"
        case .shader: return "cube.transparent"
        case .composition: return "square.stack.3d.up"
        case .camera: return "camera"
        case .ndi: return "network"
        case .syphon: return "arrow.left.arrow.right"
        case .spout: return "arrow.triangle.branch"
        }
    }
}

// MARK: - Playing Indicator

struct PlayingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 3)
                    .scaleEffect(y: isAnimating ? 1 : 0.3, anchor: .bottom)
                    .animation(
                        .easeInOut(duration: 0.3)
                        .repeatForever()
                        .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Effect Rack View

struct EffectRackView: View {
    @ObservedObject var engine: VJEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Master Effects") {
                    ForEach(engine.masterDeck.effects) { effect in
                        EffectRow(effect: effect)
                    }

                    Button("Add Effect") {
                        let newEffect = VJEffect(
                            id: UUID(),
                            name: "New Effect",
                            type: .blur,
                            parameters: [:]
                        )
                        engine.addEffect(to: engine.masterDeck.id, effect: newEffect)
                    }
                }

                Section("Available Effects") {
                    ForEach(VJEffect.EffectType.allCases, id: \.self) { effectType in
                        Button(effectType.rawValue) {
                            let effect = VJEffect(
                                id: UUID(),
                                name: effectType.rawValue,
                                type: effectType,
                                parameters: [:]
                            )
                            engine.addEffect(to: engine.masterDeck.id, effect: effect)
                        }
                    }
                }
            }
            .navigationTitle("Effect Rack")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct EffectRow: View {
    let effect: VJEffect

    var body: some View {
        HStack {
            Toggle(isOn: .constant(effect.isEnabled)) {
                Text(effect.name)
            }

            Spacer()

            if effect.isAudioReactive {
                Image(systemName: "waveform")
                    .foregroundColor(.cyan)
            }
        }
    }
}

// MARK: - Output Settings View

struct OutputSettingsView: View {
    @ObservedObject var engine: VJEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(engine.outputs) { output in
                    Section(output.name) {
                        Toggle("Enabled", isOn: .constant(output.isEnabled))
                        Toggle("Fullscreen", isOn: .constant(output.isFullscreen))

                        HStack {
                            Text("Resolution")
                            Spacer()
                            Text("\(output.resolution.width)x\(output.resolution.height)")
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section {
                    Button("Add NDI Output") {
                        engine.addNDIOutput()
                    }
                    Button("Add Syphon Output") {
                        engine.addSyphonOutput()
                    }
                }
            }
            .navigationTitle("Output Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - VJ Button Style

struct VJButtonStyle: ButtonStyle {
    enum Size {
        case small, medium, large
    }

    var size: Size = .medium
    var isActive: Bool = false
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }

    private var fontSize: CGFloat {
        switch size {
        case .small: return 9
        case .medium: return 11
        case .large: return 14
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 6
        case .medium: return 10
        case .large: return 14
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }

    private var foregroundColor: Color {
        if isDestructive {
            return .red
        }
        return isActive ? .black : .white
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isDestructive {
            return isPressed ? Color.red.opacity(0.4) : Color.red.opacity(0.2)
        }
        if isActive {
            return isPressed ? Color.cyan.opacity(0.8) : Color.cyan
        }
        return isPressed ? Color(white: 0.35) : Color(white: 0.25)
    }
}

// MARK: - Preview

#Preview {
    ClipLauncherMatrix()
        .preferredColorScheme(.dark)
        .frame(width: 1400, height: 900)
}

#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Accelerate

/// Analog saturation/tape/tube emulation node using ClassicAnalogEmulations DSP.
///
/// Wraps the existing AnalogConsole (SSL, Neve, Fairchild, 1176, LA-2A, etc.)
/// into the EchoelmusicNode graph for per-channel insert processing.
///
/// Implementation: Delegates to ClassicAnalogEmulations per-sample processors.
/// Supports all 8 hardware styles with one-knob "character" control.
///
/// EchoelCore Native - No external dependencies
@MainActor
class SaturationNode: BaseEchoelmusicNode {

    // MARK: - DSP State

    /// The analog console processor with all hardware emulations
    private var console: AnalogConsole

    /// Current sample rate
    private var currentSampleRate: Double = 48000.0

    // MARK: - Parameters

    private enum Params {
        static let drive = "drive"
        static let tone = "tone"
        static let output = "output"
        static let style = "style"
    }

    // MARK: - Initialization

    convenience init(style: AnalogConsole.HardwareStyle) {
        self.init()
        setStyle(style)
    }

    init() {
        self.console = AnalogConsole(sampleRate: 48000)

        super.init(name: "Analog Saturation", type: .effect)

        parameters = [
            NodeParameter(
                name: Params.drive,
                label: "Drive",
                value: 30.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 30.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.tone,
                label: "Tone",
                value: 50.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 50.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.output,
                label: "Output",
                value: 50.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 50.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.style,
                label: "Hardware Style",
                value: 0.0,
                min: 0.0,
                max: 7.0,
                defaultValue: 0.0,
                unit: nil,
                isAutomatable: false,
                type: .discrete
            )
        ]
    }

    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive else {
            return buffer
        }

        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = min(Int(buffer.format.channelCount), 2)

        // Sync parameters to console
        let drive = getParameter(name: Params.drive) ?? 30.0
        let output = getParameter(name: Params.output) ?? 50.0
        let styleIdx = Int(getParameter(name: Params.style) ?? 0)

        console.character = drive
        console.output = output

        let styles = AnalogConsole.HardwareStyle.allCases
        if styleIdx >= 0, styleIdx < styles.count {
            console.currentStyle = styles[styleIdx]
        }

        // Process each channel through the analog console
        for ch in 0..<channelCount {
            let ptr = channelData[ch]
            let channelSamples = Array(UnsafeBufferPointer(start: ptr, count: frameCount))

            // Process through analog emulation
            let processed = console.process(channelSamples)

            // Copy back using buffer pointer
            processed.withUnsafeBufferPointer { src in
                ptr.update(from: src.baseAddress!, count: frameCount)
            }
        }

        return buffer
    }

    // MARK: - Bio-Reactivity

    override var isBioReactive: Bool { true }

    override func react(to signal: BioSignal) {
        // Coherence → Drive (higher coherence = warmer, more saturated)
        let coherence = signal.coherence
        let targetDrive = 10.0 + Float(coherence / 100.0) * 50.0
        if let currentDrive = getParameter(name: Params.drive) {
            let smoothed = currentDrive * 0.95 + targetDrive * 0.05
            setParameter(name: Params.drive, value: smoothed)
        }
    }

    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        if abs(sampleRate - currentSampleRate) > 1.0 {
            currentSampleRate = sampleRate
            console = AnalogConsole(sampleRate: Float(sampleRate))
        }
    }

    override func start() {
        super.start()
        log.audio("SaturationNode started (AnalogConsole: \(console.currentStyle.rawValue))")
    }

    override func stop() {
        super.stop()
        log.audio("SaturationNode stopped")
    }

    override func reset() {
        super.reset()
        console = AnalogConsole(sampleRate: Float(currentSampleRate))
    }

    // MARK: - Style Control

    /// Set hardware emulation style by name
    func setStyle(_ style: AnalogConsole.HardwareStyle) {
        console.currentStyle = style
        let idx = AnalogConsole.HardwareStyle.allCases.firstIndex(of: style) ?? 0
        setParameter(name: Params.style, value: Float(idx))
    }
}
#endif

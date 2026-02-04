// CymaticsVisualizer.swift
// Echoelmusic
//
// Cymatics-inspired visual patterns synchronized to biophysical frequencies.
// Creates wave interference patterns, sacred geometry, and frequency-responsive
// visualizations for wellness meditation.
//
// Cymatics: The study of visible sound patterns, named by Hans Jenny (1967).
// Patterns emerge when materials vibrate at specific frequencies.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation

// MARK: - Cymatics State

/// State for cymatics visualization
public struct CymaticsState: Sendable {
    public var frequency: Double = 40.0
    public var amplitude: Double = 0.5
    public var pattern: CymaticsPattern = .geometric
    public var phase: Double = 0.0
    public var nodeCount: Int = 8
    public var colorMode: CymaticsColorMode = .coherence
    public var rotationSpeed: Double = 0.1
    public var symmetry: Int = 6
    public var waveSpeed: Double = 1.0
    public var damping: Double = 0.98
}

/// Color modes for cymatics visualization
public enum CymaticsColorMode: String, CaseIterable, Codable, Sendable {
    case coherence = "Coherence"       // Color based on coherence level
    case frequency = "Frequency"       // Color based on frequency
    case amplitude = "Amplitude"       // Color based on amplitude
    case rainbow = "Rainbow"           // Full spectrum cycling
    case monochrome = "Monochrome"     // Single color
    case thermal = "Thermal"           // Heat map style
}

// MARK: - Wave Node

/// Single node in the wave interference pattern
public struct WaveNode: Identifiable, Sendable {
    public let id = UUID()
    public var position: CGPoint
    public var phase: Double
    public var amplitude: Double
    public var frequency: Double

    /// Calculate wave height at given point
    public func waveHeight(at point: CGPoint, time: Double) -> Double {
        let distance = sqrt(
            pow(point.x - position.x, 2) +
            pow(point.y - position.y, 2)
        )
        let wavelength = 100.0 / frequency
        let k = 2.0 * .pi / wavelength
        let omega = 2.0 * .pi * frequency

        return amplitude * sin(k * distance - omega * time + phase)
    }
}

// MARK: - Cymatics Visualizer

/// Engine for creating cymatics-inspired visualizations
@MainActor
public final class CymaticsVisualizer: ObservableObject {

    // MARK: - Published Properties

    @Published public var state = CymaticsState()
    @Published public private(set) var waveNodes: [WaveNode] = []
    @Published public private(set) var interferenceGrid: [[Double]] = []
    @Published public private(set) var currentTime: Double = 0.0

    // MARK: - Private Properties

    private var displayLink: CADisplayLink?
    private let gridSize = 64
    private var isRunning = false

    // MARK: - Initialization

    public init() {
        setupWaveNodes()
        initializeGrid()
    }

    // MARK: - Setup

    private func setupWaveNodes() {
        waveNodes = createNodesForPattern(state.pattern, count: state.nodeCount)
    }

    private func initializeGrid() {
        interferenceGrid = Array(
            repeating: Array(repeating: 0.0, count: gridSize),
            count: gridSize
        )
    }

    /// Create wave nodes arranged for specific pattern
    private func createNodesForPattern(_ pattern: CymaticsPattern, count: Int) -> [WaveNode] {
        var nodes: [WaveNode] = []
        let center = CGPoint(x: 0.5, y: 0.5)
        let radius = 0.35

        switch pattern {
        case .hexagonal:
            // Hexagonal arrangement
            for i in 0..<6 {
                let angle = Double(i) * .pi / 3.0
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                nodes.append(WaveNode(
                    position: CGPoint(x: x, y: y),
                    phase: Double(i) * .pi / 3.0,
                    amplitude: state.amplitude,
                    frequency: state.frequency
                ))
            }
            // Center node
            nodes.append(WaveNode(
                position: center,
                phase: 0,
                amplitude: state.amplitude * 1.5,
                frequency: state.frequency
            ))

        case .muscularWave:
            // Linear wave pattern for muscle visualization
            for i in 0..<count {
                let x = 0.1 + 0.8 * Double(i) / Double(count - 1)
                nodes.append(WaveNode(
                    position: CGPoint(x: x, y: 0.5),
                    phase: Double(i) * .pi / 4.0,
                    amplitude: state.amplitude,
                    frequency: state.frequency
                ))
            }

        case .neural:
            // Distributed neural network pattern
            for i in 0..<count {
                let angle = Double(i) * 2.0 * .pi / Double(count)
                let r = radius * (0.5 + 0.5 * sin(Double(i) * 3.0))
                let x = center.x + r * cos(angle)
                let y = center.y + r * sin(angle)
                nodes.append(WaveNode(
                    position: CGPoint(x: x, y: y),
                    phase: Double(i) * .pi / Double(count),
                    amplitude: state.amplitude * (0.8 + 0.2 * sin(Double(i))),
                    frequency: state.frequency * (0.9 + 0.2 * sin(Double(i) * 2.0))
                ))
            }

        case .flowingWater:
            // Organic flowing pattern
            for i in 0..<count {
                let t = Double(i) / Double(count)
                let x = 0.2 + 0.6 * t + 0.1 * sin(t * .pi * 4.0)
                let y = 0.3 + 0.4 * sin(t * .pi * 2.0)
                nodes.append(WaveNode(
                    position: CGPoint(x: x, y: y),
                    phase: t * .pi * 2.0,
                    amplitude: state.amplitude * (0.7 + 0.3 * sin(t * .pi)),
                    frequency: state.frequency
                ))
            }

        case .vortex:
            // Spiral vortex pattern
            for i in 0..<count {
                let t = Double(i) / Double(count)
                let angle = t * 4.0 * .pi
                let r = 0.1 + 0.3 * t
                let x = center.x + r * cos(angle)
                let y = center.y + r * sin(angle)
                nodes.append(WaveNode(
                    position: CGPoint(x: x, y: y),
                    phase: angle,
                    amplitude: state.amplitude * (1.0 - 0.5 * t),
                    frequency: state.frequency * (1.0 + 0.3 * t)
                ))
            }

        case .geometric, .mandala, .cellular:
            // Regular polygon arrangement
            let symmetryCount = state.symmetry
            for i in 0..<symmetryCount {
                let angle = Double(i) * 2.0 * .pi / Double(symmetryCount)
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                nodes.append(WaveNode(
                    position: CGPoint(x: x, y: y),
                    phase: Double(i) * .pi / Double(symmetryCount),
                    amplitude: state.amplitude,
                    frequency: state.frequency
                ))
            }
        }

        return nodes
    }

    // MARK: - Public API

    /// Update visualization with new parameters
    public func update(frequency: Double, amplitude: Double, pattern: CymaticsPattern) {
        state.frequency = frequency
        state.amplitude = amplitude

        if state.pattern != pattern {
            state.pattern = pattern
            setupWaveNodes()
        }

        // Update node parameters
        for i in 0..<waveNodes.count {
            waveNodes[i].frequency = frequency
            waveNodes[i].amplitude = amplitude * (0.8 + 0.2 * sin(Double(i)))
        }
    }

    /// Start visualization animation
    public func start() {
        guard !isRunning else { return }
        isRunning = true

        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    /// Stop visualization animation
    public func stop() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Calculate interference pattern at point
    public func calculateInterference(at point: CGPoint) -> Double {
        var totalHeight = 0.0

        for node in waveNodes {
            totalHeight += node.waveHeight(at: point, time: currentTime)
        }

        // Apply damping
        return totalHeight * state.damping
    }

    // MARK: - Animation

    @objc private func updateAnimation() {
        currentTime += 1.0 / 60.0 * state.waveSpeed

        // Update phase
        state.phase += 2.0 * .pi * state.frequency / 60.0

        // Update interference grid (sampled for performance)
        updateInterferenceGrid()

        // Notify observers
        objectWillChange.send()
    }

    private func updateInterferenceGrid() {
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let point = CGPoint(
                    x: Double(x) / Double(gridSize),
                    y: Double(y) / Double(gridSize)
                )
                interferenceGrid[y][x] = calculateInterference(at: point)
            }
        }
    }

    // MARK: - Color Generation

    /// Get color for given coherence level
    public func colorForCoherence(_ coherence: Double) -> Color {
        switch state.colorMode {
        case .coherence:
            // Blue (low) -> Green (medium) -> Gold (high)
            if coherence < 0.33 {
                return Color(hue: 0.6, saturation: 0.8, brightness: 0.5 + coherence)
            } else if coherence < 0.66 {
                return Color(hue: 0.3, saturation: 0.8, brightness: 0.6 + coherence * 0.4)
            } else {
                return Color(hue: 0.12, saturation: 0.9, brightness: 0.7 + coherence * 0.3)
            }

        case .frequency:
            // Map frequency to hue (30 Hz = blue, 50 Hz = red)
            let normalizedFreq = (state.frequency - 30.0) / 20.0
            return Color(hue: 0.6 - normalizedFreq * 0.6, saturation: 0.8, brightness: 0.8)

        case .amplitude:
            return Color(hue: 0.3, saturation: state.amplitude, brightness: 0.5 + state.amplitude * 0.5)

        case .rainbow:
            return Color(hue: fmod(currentTime * 0.1, 1.0), saturation: 0.8, brightness: 0.8)

        case .monochrome:
            return Color(white: 0.3 + coherence * 0.7)

        case .thermal:
            // Cold (blue) to hot (red/white)
            if coherence < 0.5 {
                return Color(hue: 0.6 - coherence * 0.4, saturation: 0.9, brightness: 0.5 + coherence)
            } else {
                return Color(hue: 0.05, saturation: 1.0 - (coherence - 0.5) * 2, brightness: 0.8 + (coherence - 0.5) * 0.4)
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        stop()
    }
}

// MARK: - Cymatics SwiftUI View

/// SwiftUI view for rendering cymatics patterns
public struct CymaticsView: View {
    @ObservedObject var visualizer: CymaticsVisualizer
    var coherence: Double = 0.5

    public init(visualizer: CymaticsVisualizer, coherence: Double = 0.5) {
        self.visualizer = visualizer
        self.coherence = coherence
    }

    public var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let gridSize = visualizer.interferenceGrid.count
                guard gridSize > 0 else { return }

                let cellWidth = size.width / CGFloat(gridSize)
                let cellHeight = size.height / CGFloat(gridSize)

                // Draw interference pattern
                for y in 0..<gridSize {
                    for x in 0..<gridSize {
                        let value = visualizer.interferenceGrid[y][x]
                        let normalizedValue = (value + 1.0) / 2.0  // -1 to 1 -> 0 to 1

                        let rect = CGRect(
                            x: CGFloat(x) * cellWidth,
                            y: CGFloat(y) * cellHeight,
                            width: cellWidth + 1,
                            height: cellHeight + 1
                        )

                        let color = visualizer.colorForCoherence(normalizedValue * coherence)
                        context.fill(Path(rect), with: .color(color))
                    }
                }

                // Draw wave nodes as highlights
                for node in visualizer.waveNodes {
                    let center = CGPoint(
                        x: node.position.x * size.width,
                        y: node.position.y * size.height
                    )

                    let radius = 8.0 + 4.0 * sin(visualizer.currentTime * node.frequency * 0.1)

                    let nodePath = Path(ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))

                    context.fill(nodePath, with: .color(.white.opacity(0.8)))
                }
            }
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .onAppear {
            visualizer.start()
        }
        .onDisappear {
            visualizer.stop()
        }
    }
}

// MARK: - Biophysical Audio Generator

/// Audio generator for biophysical frequency tones
public final class BiophysicalAudioGenerator {

    private var audioEngine: AVAudioEngine?
    private var toneNode: AVAudioSourceNode?
    private var currentFrequency: Double = 40.0
    private var currentAmplitude: Double = 0.3
    private var phase: Double = 0.0
    private var isPlaying = false

    public init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else { return }

        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate

        toneNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let sample = Float(sin(self.phase) * self.currentAmplitude)

                self.phase += 2.0 * .pi * self.currentFrequency / sampleRate
                if self.phase >= 2.0 * .pi {
                    self.phase -= 2.0 * .pi
                }

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }

            return noErr
        }

        if let toneNode = toneNode {
            let format = engine.outputNode.outputFormat(forBus: 0)
            engine.attach(toneNode)
            engine.connect(toneNode, to: engine.mainMixerNode, format: format)
        }
    }

    /// Start tone at frequency
    public func startTone(frequency: Double, amplitude: Double = 0.3) {
        currentFrequency = frequency
        currentAmplitude = min(0.5, amplitude)  // Safety limit

        guard !isPlaying else { return }

        do {
            try audioEngine?.start()
            isPlaying = true
        } catch {
            log.error("BiophysicalAudio failed to start: \(error)")
        }
    }

    /// Stop tone
    public func stopTone() {
        audioEngine?.stop()
        isPlaying = false
    }

    /// Update frequency
    public func updateFrequency(_ frequency: Double) {
        currentFrequency = frequency
    }

    /// Update amplitude
    public func updateAmplitude(_ amplitude: Double) {
        currentAmplitude = min(0.5, amplitude)
    }

    deinit {
        stopTone()
    }
}

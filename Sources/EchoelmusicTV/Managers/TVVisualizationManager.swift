import Foundation
import SwiftUI

/// Manages visualization styles and parameters for Apple TV
/// Controls immersive visual experiences on large screens
@MainActor
class TVVisualizationManager: ObservableObject {

    // MARK: - Published Properties

    /// Current visualization style
    @Published var currentStyle: VisualizationStyle = .particles

    /// Visualization intensity (0.0 - 1.0)
    @Published var intensity: Double = 0.7

    /// Whether visualization is playing
    @Published private(set) var isPlaying: Bool = false

    /// Ambient mode active
    @Published private(set) var isAmbientMode: Bool = false

    /// Color palette
    @Published var colorPalette: ColorPalette = .aurora

    /// Animation speed multiplier
    @Published var animationSpeed: Double = 1.0

    // MARK: - Public Methods

    /// Set visualization style
    func setStyle(_ style: VisualizationStyle) {
        currentStyle = style
        print("[TVVisualization] 🎨 Style changed: \(style.name)")
    }

    /// Toggle play/pause
    func togglePlayPause() {
        isPlaying.toggle()
        print("[TVVisualization] \(isPlaying ? "▶️" : "⏸️") \(isPlaying ? "Playing" : "Paused")")
    }

    /// Start ambient mode
    func startAmbientMode() {
        isAmbientMode = true
        isPlaying = true
        intensity = 0.5
        animationSpeed = 0.3 // Slower for ambient

        print("[TVVisualization] ✨ Ambient mode started")
    }

    /// Stop ambient mode
    func stopAmbientMode() {
        isAmbientMode = false
        animationSpeed = 1.0

        print("[TVVisualization] ✨ Ambient mode stopped")
    }

    /// Adjust intensity based on coherence
    func adjustIntensity(basedOnCoherence coherence: Double) {
        // Map coherence (0-100) to intensity (0.3-1.0)
        // Higher coherence = more intense visuals
        let targetIntensity = 0.3 + (coherence / 100.0) * 0.7

        // Smooth transition
        withAnimation(.easeInOut(duration: 2.0)) {
            intensity = targetIntensity
        }
    }

    /// Cycle to next style
    func nextStyle() {
        let allStyles = VisualizationStyle.allCases
        if let currentIndex = allStyles.firstIndex(of: currentStyle) {
            let nextIndex = (currentIndex + 1) % allStyles.count
            setStyle(allStyles[nextIndex])
        }
    }

    /// Cycle to previous style
    func previousStyle() {
        let allStyles = VisualizationStyle.allCases
        if let currentIndex = allStyles.firstIndex(of: currentStyle) {
            let previousIndex = currentIndex > 0 ? currentIndex - 1 : allStyles.count - 1
            setStyle(allStyles[previousIndex])
        }
    }
}

// MARK: - Supporting Types

enum VisualizationStyle: String, CaseIterable {
    case particles
    case waves
    case mandala
    case aurora
    case breathing

    var name: String {
        switch self {
        case .particles:
            return "Particles"
        case .waves:
            return "Waves"
        case .mandala:
            return "Mandala"
        case .aurora:
            return "Aurora"
        case .breathing:
            return "Breathing"
        }
    }

    var icon: String {
        switch self {
        case .particles:
            return "sparkles"
        case .waves:
            return "waveform"
        case .mandala:
            return "circle.hexagongrid.fill"
        case .aurora:
            return "moon.stars.fill"
        case .breathing:
            return "wind"
        }
    }

    var description: String {
        switch self {
        case .particles:
            return "Floating particles reactive to biofeedback"
        case .waves:
            return "Flowing waves matching heart rhythm"
        case .mandala:
            return "Geometric mandala patterns"
        case .aurora:
            return "Northern lights ambient effect"
        case .breathing:
            return "Breathing circle guidance"
        }
    }
}

enum ColorPalette: String, CaseIterable {
    case aurora      // Blues, purples, teals
    case sunset      // Oranges, reds, pinks
    case forest      // Greens, teals, browns
    case ocean       // Blues, cyans, whites
    case fire        // Reds, oranges, yellows
    case monochrome  // Grays, whites, blacks

    var colors: [Color] {
        switch self {
        case .aurora:
            return [.blue, .purple, .cyan, .teal]
        case .sunset:
            return [.orange, .red, .pink, .yellow]
        case .forest:
            return [.green, .teal, .brown, .mint]
        case .ocean:
            return [.blue, .cyan, .white, .indigo]
        case .fire:
            return [.red, .orange, .yellow, .pink]
        case .monochrome:
            return [.gray, .white, .black]
        }
    }
}

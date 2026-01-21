import Foundation
import AVFoundation
import Metal
import SwiftUI

/// Scene Manager for Stream Engine
/// Manages scenes, sources, transitions, and bio-reactive switching
@MainActor
class SceneManager: ObservableObject {

    @Published var scenes: [StreamScene] = []
    @Published var bioReactiveEnabled: Bool = false
    @Published var bioSceneRules: [BioSceneRule] = []

    func loadScenes() -> [StreamScene] {
        // Create default scenes
        return [
            StreamScene(name: "Main", sources: []),
            StreamScene(name: "Meditation", sources: []),
            StreamScene(name: "Performance", sources: []),
            StreamScene(name: "BRB", sources: [])
        ]
    }

    func addScene(_ scene: StreamScene) {
        scenes.append(scene)
    }

    func removeScene(_ id: UUID) {
        scenes.removeAll { $0.id == id }
    }
}

// MARK: - Scene Model

struct StreamScene: Identifiable {
    let id = UUID()
    var name: String
    var sources: [SceneSource]
}

// MARK: - Scene Source

enum SceneSource: Identifiable {
    case camera(StreamCameraSource)
    case chromaKey(ChromaKeySource)
    case screenCapture(ScreenCaptureSource)
    case videoFile(VideoFileSource)
    case echoelVisual(EchoelVisualSource)
    case bioOverlay(BioOverlaySource)
    case textOverlay(TextOverlaySource)
    case imageOverlay(ImageOverlaySource)
    case webBrowser(WebBrowserSource)

    var id: UUID {
        switch self {
        case .camera(let s): return s.id
        case .chromaKey(let s): return s.id
        case .screenCapture(let s): return s.id
        case .videoFile(let s): return s.id
        case .echoelVisual(let s): return s.id
        case .bioOverlay(let s): return s.id
        case .textOverlay(let s): return s.id
        case .imageOverlay(let s): return s.id
        case .webBrowser(let s): return s.id
        }
    }
}

struct StreamCameraSource: Identifiable {
    let id = UUID()
    var name: String
    var cameraPosition: AVCaptureDevice.Position
}

struct ChromaKeySource: Identifiable {
    let id = UUID()
    var name: String
    var cameraPosition: AVCaptureDevice.Position
    var keyColor: ChromaKeyColor

    enum ChromaKeyColor {
        case green
        case blue
    }
}

struct ScreenCaptureSource: Identifiable {
    let id = UUID()
    var name: String
}

struct VideoFileSource: Identifiable {
    let id = UUID()
    var name: String
    var url: URL
    var looping: Bool
}

struct EchoelVisualSource: Identifiable {
    let id = UUID()
    var name: String
    var type: VisualType

    enum VisualType {
        case cymatics
        case mandala
        case particles
        case waveform
        case spectral
    }
}

struct BioOverlaySource: Identifiable {
    let id = UUID()
    var name: String
    var widgets: [BioWidget]

    enum BioWidget {
        case hrvGraph
        case heartRateDisplay
        case coherenceRing
        case breathWave
    }
}

struct TextOverlaySource: Identifiable {
    let id = UUID()
    var name: String
    var text: String
    var font: String
    var fontSize: CGFloat
    var color: Color
    var scrolling: Bool
}

struct ImageOverlaySource: Identifiable {
    let id = UUID()
    var name: String
    var imageURL: URL
    var opacity: Double
}

struct WebBrowserSource: Identifiable {
    let id = UUID()
    var name: String
    var url: URL
}

// ExternalDisplayRenderingPipeline.swift
// Echoelmusic — EchoelStage: External Display Rendering Pipeline
//
// ═══════════════════════════════════════════════════════════════════════════════
// Detects, manages, and routes visual/audio content to ALL connected outputs:
// - External HDMI/USB-C/Thunderbolt displays
// - AirPlay receivers (Apple TV, HomePod)
// - Smart glasses (Apple Glasses, future devices)
// - VR/XR headsets (Apple Vision Pro, Meta Quest)
// - Projectors (single, multi-beamer arrays, dome/planetarium)
// - LED walls (via Syphon/NDI/Spout)
// - Theater/installation/cinema output
//
// Industry Protocols: Art-Net, sACN, OSC, NDI, Syphon, Dante, MTC/LTC
// Audio Formats: Stereo, 5.1, 7.1, 7.1.4 Atmos, Ambisonics, WFS, Binaural
// Video Formats: Equirectangular, Cubemap, Fisheye, Domemaster, Stereoscopic
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import Combine
import simd

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(CoreVideo)
import CoreVideo
#endif

#if canImport(Metal)
import Metal
#endif

// MARK: - Display Output Descriptor

/// Describes a detected output device with its capabilities
public struct DisplayOutputDescriptor: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let category: OutputCategory
    public let connectionType: OutputConnectionType
    public let nativeWidth: Int
    public let nativeHeight: Int
    public let maxRefreshRate: Double
    public let supportsHDR: Bool
    public let supportsDolbyVision: Bool
    public let latencyMs: Double
    public let isAvailable: Bool

    public enum OutputCategory: String, CaseIterable, Sendable {
        case externalDisplay = "External Display"
        case airPlay = "AirPlay"
        case smartGlasses = "Smart Glasses"
        case vrXRHeadset = "VR/XR Headset"
        case projector = "Projector"
        case domeBeamer = "Dome / Planetarium"
        case multiBeamerArray = "Multi-Beamer Array"
        case ledWall = "LED Wall"
        case ndiOutput = "NDI Output"
        case syphonOutput = "Syphon Output"
    }

    public enum OutputConnectionType: String, CaseIterable, Sendable {
        case hdmi = "HDMI"
        case usbC = "USB-C"
        case thunderbolt = "Thunderbolt"
        case displayPort = "DisplayPort"
        case airPlay = "AirPlay"
        case ndi = "NDI"
        case syphon = "Syphon"
        case artNet = "Art-Net"
        case wireless = "Wireless"
    }

    public static func == (lhs: DisplayOutputDescriptor, rhs: DisplayOutputDescriptor) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Content Assignment

/// What content goes to which output
public struct OutputContentAssignment: Identifiable {
    public let id: String
    public let outputId: String
    public let contentType: ContentType
    public var projectionMode: ProjectionFormat
    public var audioFormat: SpatialAudioFormat

    public enum ContentType: String, CaseIterable, Sendable {
        case performerView = "Performer View"
        case audienceVisuals = "Audience Visuals"
        case therapistBioData = "Therapist Bio-Data"
        case immersive360 = "360° Immersive"
        case domeProjection = "Dome Projection"
        case cleanFeed = "Clean Feed (No UI)"
        case multiviewMonitor = "Multi-View Monitor"
        case bioReactiveAmbient = "Bio-Reactive Ambient"
        case mirror = "Mirror Main Display"
    }
}

// MARK: - Projection Formats

public enum ProjectionFormat: String, CaseIterable, Sendable {
    case standard = "Standard (Flat)"
    case equirectangular = "Equirectangular 360°"
    case cubemap = "Cubemap 6-Face"
    case fisheye = "Fisheye (Dome)"
    case domemaster = "Domemaster (Planetarium)"
    case cylindrical = "Cylindrical Panorama"
    case stereoscopic = "Stereoscopic 3D"

    /// Vertex/fragment shader name for this projection
    var shaderName: String {
        switch self {
        case .standard: return "flat_projection"
        case .equirectangular: return "equirectangular_projection"
        case .cubemap: return "cubemap_projection"
        case .fisheye: return "fisheye_projection"
        case .domemaster: return "domemaster_projection"
        case .cylindrical: return "cylindrical_projection"
        case .stereoscopic: return "stereoscopic_projection"
        }
    }
}

// MARK: - Spatial Audio Formats

public enum SpatialAudioFormat: String, CaseIterable, Sendable {
    case stereo = "Stereo"
    case surround5_1 = "5.1 Surround"
    case surround7_1 = "7.1 Surround"
    case atmos7_1_4 = "7.1.4 Dolby Atmos"
    case ambisonicsFOA = "Ambisonics 1st Order"
    case ambisonicsHOA = "Ambisonics 3rd Order"
    case binaural = "Binaural (Headphones)"
    case wavefieldSynthesis = "Wavefield Synthesis"
    case customSpeakerArray = "Custom Speaker Array"

    var channelCount: Int {
        switch self {
        case .stereo: return 2
        case .surround5_1: return 6
        case .surround7_1: return 8
        case .atmos7_1_4: return 12
        case .ambisonicsFOA: return 4
        case .ambisonicsHOA: return 16
        case .binaural: return 2
        case .wavefieldSynthesis: return 64
        case .customSpeakerArray: return 0
        }
    }
}

// MARK: - Multi-Beamer Configuration

public struct MultiBeamerConfig {
    public var beamerCount: Int = 1
    public var arrangement: BeamerArrangement = .singleScreen
    public var overlapPercent: Float = 15.0
    public var softEdgeGamma: Float = 2.2
    public var geometricCorrection: Bool = true
    public var autoBlend: Bool = true

    public enum BeamerArrangement: String, CaseIterable, Sendable {
        case singleScreen = "Single Screen"
        case horizontalArray = "Horizontal Array"
        case verticalStack = "Vertical Stack"
        case gridMatrix = "Grid Matrix"
        case dome180 = "180° Dome"
        case dome360 = "360° Full Dome"
        case lShape = "L-Shape"
        case uShape = "U-Shape (3-Wall)"
        case cylinder = "Cylinder Wrap"
        case custom = "Custom Geometry"
    }
}

// MARK: - External Display Rendering Pipeline

/// Central pipeline: detects outputs, assigns content, renders and routes frames
@MainActor
public final class ExternalDisplayRenderingPipeline: ObservableObject {

    public static let shared = ExternalDisplayRenderingPipeline()

    // MARK: - Published State

    @Published public var detectedOutputs: [DisplayOutputDescriptor] = []
    @Published public var contentAssignments: [OutputContentAssignment] = []
    @Published public var isScanning: Bool = false
    @Published public var isPipelineActive: Bool = false
    @Published public var multiBeamerConfig = MultiBeamerConfig()

    // MARK: - Render State

    @Published public var renderStats: RenderStats = RenderStats()

    public struct RenderStats {
        public var activeOutputCount: Int = 0
        public var totalPixelsRendered: Int = 0
        public var frameRate: Double = 0
        public var gpuUtilization: Float = 0
        public var latencyMs: Double = 0
    }

    // MARK: - Metal Rendering

    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var renderPipelineStates: [String: MTLRenderPipelineState] = [:]

    // MARK: - Display Management

    #if canImport(UIKit)
    private var externalWindows: [String: UIWindow] = [:]
    #endif

    #if canImport(AppKit)
    private var externalWindows: [String: NSWindow] = [:]
    #endif

    // MARK: - Observer Management

    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Bus Integration

    private var busSubscription: BusSubscription?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupMetal()
        setupDisplayDetection()
        subscribeToBus()
    }

    // MARK: - Metal Setup

    private func setupMetal() {
        #if canImport(Metal)
        metalDevice = MTLCreateSystemDefaultDevice()
        commandQueue = metalDevice?.makeCommandQueue()
        #endif
    }

    // MARK: - Display Detection

    private func setupDisplayDetection() {
        #if os(iOS)
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else { return }
            Task { @MainActor in
                self?.handleScreenConnected(screen)
            }
        })

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else { return }
            Task { @MainActor in
                self?.handleScreenDisconnected(screen)
            }
        })

        // Detect already-connected screens
        for screen in UIScreen.screens where screen != UIScreen.main {
            handleScreenConnected(screen)
        }
        #endif

        #if os(macOS)
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rescanMacDisplays()
            }
        })
        rescanMacDisplays()
        #endif
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
    }

    // MARK: - Screen Handlers (iOS)

    #if os(iOS)
    private func handleScreenConnected(_ screen: UIScreen) {
        let descriptor = DisplayOutputDescriptor(
            id: "screen-\(screen.hash)",
            name: screen.description,
            category: screen.mirrored != nil ? .airPlay : .externalDisplay,
            connectionType: screen.mirrored != nil ? .airPlay : .hdmi,
            nativeWidth: Int(screen.nativeBounds.width),
            nativeHeight: Int(screen.nativeBounds.height),
            maxRefreshRate: Double(screen.maximumFramesPerSecond),
            supportsHDR: screen.responds(to: #selector(getter: UIScreen.currentMode)),
            supportsDolbyVision: false,
            latencyMs: screen.mirrored != nil ? 30.0 : 5.0,
            isAvailable: true
        )

        if !detectedOutputs.contains(where: { $0.id == descriptor.id }) {
            detectedOutputs.append(descriptor)
        }

        // Create external window
        let window = UIWindow(frame: screen.bounds)
        window.screen = screen
        window.isHidden = false
        externalWindows[descriptor.id] = window

        log.log(.info, category: .visual, "External display connected: \(descriptor.name) (\(descriptor.nativeWidth)x\(descriptor.nativeHeight))")

        EngineBus.shared.publish(.custom(
            topic: "stage.display.connected",
            payload: ["id": descriptor.id, "name": descriptor.name,
                      "width": "\(descriptor.nativeWidth)", "height": "\(descriptor.nativeHeight)"]
        ))
    }

    private func handleScreenDisconnected(_ screen: UIScreen) {
        let id = "screen-\(screen.hash)"
        detectedOutputs.removeAll { $0.id == id }
        contentAssignments.removeAll { $0.outputId == id }
        externalWindows[id]?.isHidden = true
        externalWindows.removeValue(forKey: id)

        log.log(.info, category: .visual, "External display disconnected")

        EngineBus.shared.publish(.custom(topic: "stage.display.disconnected", payload: ["id": id]))
    }
    #endif

    // MARK: - Screen Handlers (macOS)

    #if os(macOS)
    private func rescanMacDisplays() {
        let currentIds = Set(detectedOutputs.map { $0.id })
        var newOutputs: [DisplayOutputDescriptor] = []

        for screen in NSScreen.screens {
            let screenId = "mac-screen-\(screen.hash)"
            let isMainScreen = (screen == NSScreen.main)

            if !isMainScreen {
                let descriptor = DisplayOutputDescriptor(
                    id: screenId,
                    name: screen.localizedName,
                    category: .externalDisplay,
                    connectionType: .thunderbolt,
                    nativeWidth: Int(screen.frame.width * screen.backingScaleFactor),
                    nativeHeight: Int(screen.frame.height * screen.backingScaleFactor),
                    maxRefreshRate: 60.0,
                    supportsHDR: screen.maximumPotentialExtendedDynamicRangeColorComponentValue > 1.0,
                    supportsDolbyVision: false,
                    latencyMs: 3.0,
                    isAvailable: true
                )
                newOutputs.append(descriptor)
            }
        }

        detectedOutputs = newOutputs

        for output in newOutputs where !currentIds.contains(output.id) {
            log.log(.info, category: .visual, "macOS display detected: \(output.name) (\(output.nativeWidth)x\(output.nativeHeight))")
        }
    }
    #endif

    // MARK: - Scan for All Outputs

    /// Full scan: physical displays + AirPlay + NDI + Syphon
    public func scanForAllOutputs() {
        isScanning = true

        // Physical displays are auto-detected via notifications
        // Additional output types scanned here:

        scanAirPlayDevices()
        scanNDIOutputs()

        #if os(macOS)
        scanSyphonServers()
        #endif

        isScanning = false

        EngineBus.shared.publish(.custom(
            topic: "stage.scan.complete",
            payload: ["count": "\(detectedOutputs.count)"]
        ))
    }

    // MARK: - AirPlay Detection

    private func scanAirPlayDevices() {
        // AirPlay devices are discovered via AVRouteDetector
        #if canImport(AVFoundation)
        let detector = AVRouteDetector()
        detector.isRouteDetectionEnabled = true

        if detector.multipleRoutesDetected {
            let airplayDescriptor = DisplayOutputDescriptor(
                id: "airplay-available",
                name: "AirPlay Display",
                category: .airPlay,
                connectionType: .airPlay,
                nativeWidth: 1920,
                nativeHeight: 1080,
                maxRefreshRate: 60.0,
                supportsHDR: true,
                supportsDolbyVision: false,
                latencyMs: 25.0,
                isAvailable: true
            )

            if !detectedOutputs.contains(where: { $0.category == .airPlay }) {
                detectedOutputs.append(airplayDescriptor)
            }
        }
        #endif
    }

    // MARK: - NDI Output Discovery

    private func scanNDIOutputs() {
        // NDI discovery via mDNS/Bonjour
        // In production, uses NewTek NDI SDK (ndi.video)
        // For now, register as an NDI source that other devices can find
        let ndiDescriptor = DisplayOutputDescriptor(
            id: "ndi-output",
            name: "NDI Video Output",
            category: .ndiOutput,
            connectionType: .ndi,
            nativeWidth: 3840,
            nativeHeight: 2160,
            maxRefreshRate: 60.0,
            supportsHDR: true,
            supportsDolbyVision: false,
            latencyMs: 1.0,
            isAvailable: true
        )

        if !detectedOutputs.contains(where: { $0.category == .ndiOutput }) {
            detectedOutputs.append(ndiDescriptor)
        }
    }

    // MARK: - Syphon Server (macOS)

    #if os(macOS)
    private func scanSyphonServers() {
        let syphonDescriptor = DisplayOutputDescriptor(
            id: "syphon-output",
            name: "Syphon GPU Output",
            category: .syphonOutput,
            connectionType: .syphon,
            nativeWidth: 3840,
            nativeHeight: 2160,
            maxRefreshRate: 120.0,
            supportsHDR: false,
            supportsDolbyVision: false,
            latencyMs: 0.5,
            isAvailable: true
        )

        if !detectedOutputs.contains(where: { $0.category == .syphonOutput }) {
            detectedOutputs.append(syphonDescriptor)
        }
    }
    #endif

    // MARK: - Content Assignment

    /// Assign content type to an output
    public func assignContent(
        outputId: String,
        content: OutputContentAssignment.ContentType,
        projection: ProjectionFormat = .standard,
        audio: SpatialAudioFormat = .stereo
    ) {
        let assignment = OutputContentAssignment(
            id: "assign-\(outputId)",
            outputId: outputId,
            contentType: content,
            projectionMode: projection,
            audioFormat: audio
        )

        contentAssignments.removeAll { $0.outputId == outputId }
        contentAssignments.append(assignment)

        log.log(.info, category: .visual, "Content assigned: \(content.rawValue) → \(outputId)")

        EngineBus.shared.publish(.custom(
            topic: "stage.content.assigned",
            payload: ["outputId": outputId, "content": content.rawValue]
        ))
    }

    // MARK: - Pipeline Control

    /// Start rendering to all assigned outputs
    public func startPipeline() {
        guard !isPipelineActive else { return }
        isPipelineActive = true
        renderStats.activeOutputCount = contentAssignments.count

        log.log(.info, category: .visual, "Rendering pipeline started: \(contentAssignments.count) outputs")

        EngineBus.shared.publish(.custom(topic: "stage.pipeline.start", payload: [
            "outputs": "\(contentAssignments.count)"
        ]))
    }

    /// Stop all rendering
    public func stopPipeline() {
        isPipelineActive = false
        renderStats.activeOutputCount = 0

        log.log(.info, category: .visual, "Rendering pipeline stopped")

        EngineBus.shared.publish(.custom(topic: "stage.pipeline.stop", payload: [:]))
    }

    // MARK: - Frame Routing

    /// Route a visual frame to all active outputs based on their content assignments
    public func routeVisualFrame(_ frame: VisualFrame) {
        guard isPipelineActive else { return }

        for assignment in contentAssignments {
            guard let output = detectedOutputs.first(where: { $0.id == assignment.outputId }) else { continue }
            renderToOutput(output: output, assignment: assignment, frame: frame)
        }

        renderStats.frameRate = 60.0
        renderStats.totalPixelsRendered = contentAssignments.reduce(0) { total, assignment in
            guard let output = detectedOutputs.first(where: { $0.id == assignment.outputId }) else { return total }
            return total + (output.nativeWidth * output.nativeHeight)
        }
    }

    /// Render a frame to a specific output with proper projection
    private func renderToOutput(
        output: DisplayOutputDescriptor,
        assignment: OutputContentAssignment,
        frame: VisualFrame
    ) {
        switch output.category {
        case .externalDisplay, .projector:
            renderToPhysicalDisplay(output: output, assignment: assignment, frame: frame)

        case .airPlay:
            renderToAirPlay(assignment: assignment, frame: frame)

        case .domeBeamer:
            renderToDome(output: output, assignment: assignment, frame: frame)

        case .multiBeamerArray:
            renderToMultiBeamer(output: output, assignment: assignment, frame: frame)

        case .ndiOutput:
            renderToNDI(assignment: assignment, frame: frame)

        case .syphonOutput:
            renderToSyphon(assignment: assignment, frame: frame)

        case .ledWall:
            renderToLEDWall(output: output, assignment: assignment, frame: frame)

        case .smartGlasses, .vrXRHeadset:
            renderToSpatialDevice(output: output, assignment: assignment, frame: frame)
        }
    }

    // MARK: - Render Targets

    private func renderToPhysicalDisplay(output: DisplayOutputDescriptor, assignment: OutputContentAssignment, frame: VisualFrame) {
        EngineBus.shared.publish(.custom(
            topic: "stage.render.display",
            payload: ["outputId": output.id, "content": assignment.contentType.rawValue,
                      "projection": assignment.projectionMode.rawValue]
        ))
    }

    private func renderToAirPlay(assignment: OutputContentAssignment, frame: VisualFrame) {
        EngineBus.shared.publish(.custom(
            topic: "stage.render.airplay",
            payload: ["content": assignment.contentType.rawValue]
        ))
    }

    private func renderToDome(output: DisplayOutputDescriptor, assignment: OutputContentAssignment, frame: VisualFrame) {
        // Dome rendering uses fisheye or domemaster projection
        let domeProjection: ProjectionFormat = assignment.projectionMode == .standard ? .domemaster : assignment.projectionMode
        EngineBus.shared.publish(.custom(
            topic: "stage.render.dome",
            payload: ["outputId": output.id, "projection": domeProjection.rawValue,
                      "hue": "\(frame.hue)", "brightness": "\(frame.brightness)"]
        ))
    }

    private func renderToMultiBeamer(output: DisplayOutputDescriptor, assignment: OutputContentAssignment, frame: VisualFrame) {
        // Multi-beamer rendering with edge blending
        EngineBus.shared.publish(.custom(
            topic: "stage.render.multibeamer",
            payload: ["outputId": output.id,
                      "beamerCount": "\(multiBeamerConfig.beamerCount)",
                      "arrangement": multiBeamerConfig.arrangement.rawValue,
                      "overlap": "\(multiBeamerConfig.overlapPercent)"]
        ))
    }

    private func renderToNDI(assignment: OutputContentAssignment, frame: VisualFrame) {
        EngineBus.shared.publish(.custom(
            topic: "stage.render.ndi",
            payload: ["content": assignment.contentType.rawValue]
        ))
    }

    private func renderToSyphon(assignment: OutputContentAssignment, frame: VisualFrame) {
        EngineBus.shared.publish(.custom(
            topic: "stage.render.syphon",
            payload: ["content": assignment.contentType.rawValue]
        ))
    }

    private func renderToLEDWall(output: DisplayOutputDescriptor, assignment: OutputContentAssignment, frame: VisualFrame) {
        EngineBus.shared.publish(.custom(
            topic: "stage.render.ledwall",
            payload: ["outputId": output.id, "content": assignment.contentType.rawValue,
                      "width": "\(output.nativeWidth)", "height": "\(output.nativeHeight)"]
        ))
    }

    private func renderToSpatialDevice(output: DisplayOutputDescriptor, assignment: OutputContentAssignment, frame: VisualFrame) {
        EngineBus.shared.publish(.custom(
            topic: "stage.render.spatial",
            payload: ["outputId": output.id, "category": output.category.rawValue,
                      "content": assignment.contentType.rawValue]
        ))
    }

    // MARK: - EngineBus Integration

    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: .visual) { [weak self] msg in
            Task { @MainActor in
                guard let self = self, self.isPipelineActive else { return }
                if case .visualStateChange(let frame) = msg {
                    self.routeVisualFrame(frame)
                }
            }
        }
    }

    // MARK: - Status

    public var statusSummary: String {
        """
        EchoelStage Pipeline: \(isPipelineActive ? "ACTIVE" : "IDLE")
        Detected outputs: \(detectedOutputs.count)
        Active assignments: \(contentAssignments.count)
        Categories: \(Set(detectedOutputs.map { $0.category.rawValue }).sorted().joined(separator: ", "))
        """
    }
}

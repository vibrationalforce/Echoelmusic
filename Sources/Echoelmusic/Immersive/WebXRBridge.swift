// WebXRBridge.swift
// Echoelmusic
//
// WebXR Bridge for Browser-Based Immersive Experiences
// Enables cross-platform VR/AR via web browsers (Chrome, Firefox, Edge, Safari)
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import Combine
#if canImport(WebKit)
import WebKit
#endif

// MARK: - WebXR Session Type

public enum WebXRSessionType: String, Codable {
    case immersiveVR = "immersive-vr"
    case immersiveAR = "immersive-ar"
    case inline = "inline"

    public var requiredFeatures: [String] {
        switch self {
        case .immersiveVR:
            return ["local-floor"]
        case .immersiveAR:
            return ["local-floor", "hit-test"]
        case .inline:
            return []
        }
    }

    public var optionalFeatures: [String] {
        switch self {
        case .immersiveVR:
            return ["bounded-floor", "hand-tracking", "layers"]
        case .immersiveAR:
            return ["bounded-floor", "hand-tracking", "light-estimation", "depth-sensing", "dom-overlay"]
        case .inline:
            return ["viewer"]
        }
    }
}

// MARK: - WebXR Reference Space

public enum WebXRReferenceSpace: String, Codable {
    case viewer = "viewer"
    case local = "local"
    case localFloor = "local-floor"
    case boundedFloor = "bounded-floor"
    case unbounded = "unbounded"
}

// MARK: - WebXR Input Source

public struct WebXRInputSource: Identifiable, Codable {
    public let id: String
    public var handedness: Handedness
    public var targetRayMode: TargetRayMode
    public var profiles: [String]
    public var gamepad: GamepadState?
    public var hand: HandJoints?

    public enum Handedness: String, Codable {
        case none, left, right
    }

    public enum TargetRayMode: String, Codable {
        case gaze, trackedPointer, screen, transientPointer
    }

    public struct GamepadState: Codable {
        public var buttons: [ButtonState]
        public var axes: [Float]

        public struct ButtonState: Codable {
            public var pressed: Bool
            public var touched: Bool
            public var value: Float
        }
    }

    public struct HandJoints: Codable {
        public var wrist: JointPose?
        public var thumbMetacarpal: JointPose?
        public var thumbProximal: JointPose?
        public var thumbDistal: JointPose?
        public var thumbTip: JointPose?
        public var indexMetacarpal: JointPose?
        public var indexProximal: JointPose?
        public var indexIntermediate: JointPose?
        public var indexDistal: JointPose?
        public var indexTip: JointPose?
        // ... other joints

        public struct JointPose: Codable {
            public var position: [Float] // x, y, z
            public var orientation: [Float] // x, y, z, w quaternion
            public var radius: Float
        }
    }
}

// MARK: - WebXR Frame Data

public struct WebXRFrameData: Codable {
    public var timestamp: Double
    public var viewerPose: ViewerPose?
    public var inputSources: [WebXRInputSource]
    public var hitTestResults: [HitTestResult]?

    public struct ViewerPose: Codable {
        public var position: [Float]
        public var orientation: [Float]
        public var views: [View]

        public struct View: Codable {
            public var eye: String // "left", "right", "none"
            public var projectionMatrix: [Float] // 4x4 matrix
            public var viewMatrix: [Float] // 4x4 matrix
            public var viewport: Viewport

            public struct Viewport: Codable {
                public var x: Int
                public var y: Int
                public var width: Int
                public var height: Int
            }
        }
    }

    public struct HitTestResult: Codable {
        public var position: [Float]
        public var orientation: [Float]
    }
}

// MARK: - WebXR Configuration

public struct WebXRConfiguration: Codable {
    public var sessionType: WebXRSessionType
    public var referenceSpace: WebXRReferenceSpace
    public var requiredFeatures: [String]
    public var optionalFeatures: [String]
    public var depthSensing: DepthSensingConfig?
    public var domOverlay: DOMOverlayConfig?

    public struct DepthSensingConfig: Codable {
        public var usagePreference: [String] // "cpu-optimized", "gpu-optimized"
        public var dataFormatPreference: [String] // "luminance-alpha", "float32"
    }

    public struct DOMOverlayConfig: Codable {
        public var root: String // CSS selector for overlay element
    }

    public static let immersiveVR = WebXRConfiguration(
        sessionType: .immersiveVR,
        referenceSpace: .localFloor,
        requiredFeatures: ["local-floor"],
        optionalFeatures: ["hand-tracking", "layers"]
    )

    public static let immersiveAR = WebXRConfiguration(
        sessionType: .immersiveAR,
        referenceSpace: .localFloor,
        requiredFeatures: ["local-floor", "hit-test"],
        optionalFeatures: ["hand-tracking", "light-estimation", "depth-sensing"]
    )
}

// MARK: - WebXR Bridge

@MainActor
public final class WebXRBridge: ObservableObject {
    public static let shared = WebXRBridge()

    // MARK: Published State

    @Published public private(set) var isSupported = false
    @Published public private(set) var isSessionActive = false
    @Published public private(set) var currentSessionType: WebXRSessionType?
    @Published public private(set) var currentFrameData: WebXRFrameData?
    @Published public private(set) var inputSources: [WebXRInputSource] = []
    @Published public private(set) var supportedFeatures: [String] = []
    @Published public private(set) var connectionState: ConnectionState = .disconnected

    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    // MARK: Callbacks

    public var onSessionStarted: (() -> Void)?
    public var onSessionEnded: (() -> Void)?
    public var onFrameUpdate: ((WebXRFrameData) -> Void)?
    public var onInputSourceAdded: ((WebXRInputSource) -> Void)?
    public var onInputSourceRemoved: ((String) -> Void)?
    public var onSelectStart: ((WebXRInputSource) -> Void)?
    public var onSelectEnd: ((WebXRInputSource) -> Void)?
    public var onSqueezeStart: ((WebXRInputSource) -> Void)?
    public var onSqueezeEnd: ((WebXRInputSource) -> Void)?

    // MARK: Private

    #if canImport(WebKit)
    private var webView: WKWebView?
    #endif
    private var messageHandler: WebXRMessageHandler?
    private var cancellables = Set<AnyCancellable>()

    // MARK: JavaScript Bridge Code

    private let webXRJavaScript = """
    // Echoelmusic WebXR Bridge
    // Provides bidirectional communication between Swift and WebXR

    class EchoelWebXRBridge {
        constructor() {
            this.session = null;
            this.referenceSpace = null;
            this.renderer = null;
            this.scene = null;
            this.camera = null;
            this.inputSources = new Map();
            this.hitTestSource = null;
            this.isPresenting = false;
        }

        // Check WebXR Support
        async checkSupport() {
            const result = {
                xrSupported: false,
                immersiveVR: false,
                immersiveAR: false,
                inline: true,
                features: []
            };

            if (!navigator.xr) {
                this.sendToSwift('supportChecked', result);
                return result;
            }

            result.xrSupported = true;

            try {
                result.immersiveVR = await navigator.xr.isSessionSupported('immersive-vr');
            } catch (e) {}

            try {
                result.immersiveAR = await navigator.xr.isSessionSupported('immersive-ar');
            } catch (e) {}

            // Check features
            const featuresToCheck = [
                'local-floor', 'bounded-floor', 'unbounded',
                'hand-tracking', 'hit-test', 'layers',
                'light-estimation', 'depth-sensing', 'dom-overlay'
            ];

            for (const feature of featuresToCheck) {
                try {
                    // Feature detection would require session request
                    result.features.push(feature);
                } catch (e) {}
            }

            this.sendToSwift('supportChecked', result);
            return result;
        }

        // Request Session
        async requestSession(config) {
            if (!navigator.xr) {
                throw new Error('WebXR not supported');
            }

            const sessionInit = {
                requiredFeatures: config.requiredFeatures || [],
                optionalFeatures: config.optionalFeatures || []
            };

            if (config.domOverlay) {
                sessionInit.domOverlay = { root: document.querySelector(config.domOverlay.root) };
            }

            try {
                this.session = await navigator.xr.requestSession(config.sessionType, sessionInit);

                // Set up session event listeners
                this.session.addEventListener('end', () => this.onSessionEnd());
                this.session.addEventListener('inputsourceschange', (e) => this.onInputSourcesChange(e));
                this.session.addEventListener('select', (e) => this.onSelect(e));
                this.session.addEventListener('selectstart', (e) => this.onSelectStart(e));
                this.session.addEventListener('selectend', (e) => this.onSelectEnd(e));
                this.session.addEventListener('squeeze', (e) => this.onSqueeze(e));
                this.session.addEventListener('squeezestart', (e) => this.onSqueezeStart(e));
                this.session.addEventListener('squeezeend', (e) => this.onSqueezeEnd(e));

                // Get reference space
                this.referenceSpace = await this.session.requestReferenceSpace(config.referenceSpace || 'local-floor');

                // Request hit test source if AR
                if (config.sessionType === 'immersive-ar') {
                    try {
                        this.hitTestSource = await this.session.requestHitTestSource({ space: this.referenceSpace });
                    } catch (e) {}
                }

                this.isPresenting = true;
                this.sendToSwift('sessionStarted', { sessionType: config.sessionType });

                // Start render loop
                this.session.requestAnimationFrame((time, frame) => this.onXRFrame(time, frame));

                return true;
            } catch (error) {
                this.sendToSwift('sessionError', { error: error.message });
                throw error;
            }
        }

        // End Session
        async endSession() {
            if (this.session) {
                await this.session.end();
            }
        }

        // XR Frame Handler
        onXRFrame(time, frame) {
            if (!this.session || !this.isPresenting) return;

            const pose = frame.getViewerPose(this.referenceSpace);

            const frameData = {
                timestamp: time,
                viewerPose: null,
                inputSources: [],
                hitTestResults: []
            };

            if (pose) {
                frameData.viewerPose = {
                    position: Array.from(pose.transform.position),
                    orientation: Array.from(pose.transform.orientation),
                    views: pose.views.map(view => ({
                        eye: view.eye,
                        projectionMatrix: Array.from(view.projectionMatrix),
                        viewMatrix: Array.from(view.transform.inverse.matrix),
                        viewport: {
                            x: 0, y: 0, // Would come from layer
                            width: 1920, height: 1080
                        }
                    }))
                };
            }

            // Input sources
            for (const source of this.session.inputSources) {
                const inputData = this.serializeInputSource(source, frame);
                if (inputData) {
                    frameData.inputSources.push(inputData);
                }
            }

            // Hit test results (AR)
            if (this.hitTestSource) {
                const results = frame.getHitTestResults(this.hitTestSource);
                for (const result of results) {
                    const pose = result.getPose(this.referenceSpace);
                    if (pose) {
                        frameData.hitTestResults.push({
                            position: Array.from(pose.transform.position),
                            orientation: Array.from(pose.transform.orientation)
                        });
                    }
                }
            }

            this.sendToSwift('frameUpdate', frameData);

            // Request next frame
            this.session.requestAnimationFrame((t, f) => this.onXRFrame(t, f));
        }

        // Serialize Input Source
        serializeInputSource(source, frame) {
            const data = {
                id: source.handedness + '_' + source.targetRayMode,
                handedness: source.handedness,
                targetRayMode: source.targetRayMode,
                profiles: source.profiles || [],
                gamepad: null,
                hand: null
            };

            // Gamepad state
            if (source.gamepad) {
                data.gamepad = {
                    buttons: source.gamepad.buttons.map(b => ({
                        pressed: b.pressed,
                        touched: b.touched,
                        value: b.value
                    })),
                    axes: Array.from(source.gamepad.axes)
                };
            }

            // Hand tracking
            if (source.hand) {
                data.hand = {};
                for (const [joint, jointSpace] of source.hand.entries()) {
                    const pose = frame.getJointPose(jointSpace, this.referenceSpace);
                    if (pose) {
                        const jointName = this.jointToName(joint);
                        data.hand[jointName] = {
                            position: Array.from(pose.transform.position),
                            orientation: Array.from(pose.transform.orientation),
                            radius: pose.radius
                        };
                    }
                }
            }

            return data;
        }

        jointToName(joint) {
            const names = {
                'wrist': 'wrist',
                'thumb-metacarpal': 'thumbMetacarpal',
                'thumb-phalanx-proximal': 'thumbProximal',
                'thumb-phalanx-distal': 'thumbDistal',
                'thumb-tip': 'thumbTip',
                'index-finger-metacarpal': 'indexMetacarpal',
                'index-finger-phalanx-proximal': 'indexProximal',
                'index-finger-phalanx-intermediate': 'indexIntermediate',
                'index-finger-phalanx-distal': 'indexDistal',
                'index-finger-tip': 'indexTip'
                // ... other joints
            };
            return names[joint] || joint;
        }

        // Event Handlers
        onSessionEnd() {
            this.isPresenting = false;
            this.session = null;
            this.sendToSwift('sessionEnded', {});
        }

        onInputSourcesChange(event) {
            for (const source of event.added) {
                this.sendToSwift('inputSourceAdded', this.serializeInputSource(source, null));
            }
            for (const source of event.removed) {
                this.sendToSwift('inputSourceRemoved', { id: source.handedness + '_' + source.targetRayMode });
            }
        }

        onSelect(event) {
            this.sendToSwift('select', { handedness: event.inputSource.handedness });
        }

        onSelectStart(event) {
            this.sendToSwift('selectStart', { handedness: event.inputSource.handedness });
        }

        onSelectEnd(event) {
            this.sendToSwift('selectEnd', { handedness: event.inputSource.handedness });
        }

        onSqueeze(event) {
            this.sendToSwift('squeeze', { handedness: event.inputSource.handedness });
        }

        onSqueezeStart(event) {
            this.sendToSwift('squeezeStart', { handedness: event.inputSource.handedness });
        }

        onSqueezeEnd(event) {
            this.sendToSwift('squeezeEnd', { handedness: event.inputSource.handedness });
        }

        // Communication with Swift
        sendToSwift(type, data) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.echoelWebXR) {
                window.webkit.messageHandlers.echoelWebXR.postMessage({
                    type: type,
                    data: data
                });
            }
        }
    }

    // Initialize bridge
    window.echoelWebXR = new EchoelWebXRBridge();
    window.echoelWebXR.checkSupport();
    """;

    // MARK: Initialization

    private init() {
        #if canImport(WebKit)
        setupWebView()
        #endif
    }

    // MARK: - WebView Setup

    #if canImport(WebKit)
    private func setupWebView() {
        let config = WKWebViewConfiguration()

        // Add message handler
        messageHandler = WebXRMessageHandler(bridge: self)
        config.userContentController.add(messageHandler!, name: "echoelWebXR")

        // Enable WebXR
        config.preferences.javaScriptEnabled = true

        webView = WKWebView(frame: .zero, configuration: config)

        // Inject bridge JavaScript
        let script = WKUserScript(
            source: webXRJavaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)
    }
    #endif

    // MARK: - Public API

    /// Check if WebXR is supported
    public func checkSupport() async -> Bool {
        #if canImport(WebKit)
        guard let webView = webView else { return false }

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("window.echoelWebXR.checkSupport()") { result, error in
                if let _ = error {
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
        #else
        return false
        #endif
    }

    /// Start WebXR session
    public func startSession(config: WebXRConfiguration = .immersiveVR) async throws {
        connectionState = .connecting

        #if canImport(WebKit)
        guard let webView = webView else {
            throw WebXRError.webViewNotAvailable
        }

        let configJSON = try JSONEncoder().encode(config)
        guard let configString = String(data: configJSON, encoding: .utf8) else {
            throw WebXRError.invalidConfiguration
        }

        let script = "window.echoelWebXR.requestSession(\(configString))"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        connectionState = .connected
        isSessionActive = true
        currentSessionType = config.sessionType
        #else
        throw WebXRError.platformNotSupported
        #endif
    }

    /// End WebXR session
    public func endSession() async {
        #if canImport(WebKit)
        guard let webView = webView else { return }

        webView.evaluateJavaScript("window.echoelWebXR.endSession()") { _, _ in }
        #endif

        isSessionActive = false
        currentSessionType = nil
        connectionState = .disconnected
    }

    /// Load immersive content in WebXR
    public func loadContent(_ content: ImmersiveContent) async throws {
        guard isSessionActive else {
            throw WebXRError.sessionNotActive
        }

        // Generate WebXR-compatible content
        let webContent = convertToWebXRContent(content)

        #if canImport(WebKit)
        guard let webView = webView else {
            throw WebXRError.webViewNotAvailable
        }

        let contentJSON = try JSONEncoder().encode(webContent)
        guard let contentString = String(data: contentJSON, encoding: .utf8) else {
            throw WebXRError.invalidContent
        }

        let script = "window.echoelWebXR.loadContent(\(contentString))"
        webView.evaluateJavaScript(script) { _, _ in }
        #endif
    }

    // MARK: - Content Conversion

    private func convertToWebXRContent(_ content: ImmersiveContent) -> WebXRContent {
        return WebXRContent(
            id: content.id.uuidString,
            title: content.title,
            videoURL: content.videoURL?.absoluteString,
            format: mapVideoFormat(content.videoFormat),
            audioFormat: mapAudioFormat(content.audioFormat),
            interactiveElements: content.interactiveElements.map { mapInteractiveElement($0) }
        )
    }

    private func mapVideoFormat(_ format: ImmersiveVideoFormat) -> String {
        switch format {
        case .equirectangular360: return "equirect360"
        case .equirectangular180: return "equirect180"
        case .cubemap: return "cubemap"
        case .stereoSideBySide: return "sbs3d"
        case .stereoTopBottom: return "tb3d"
        default: return "equirect360"
        }
    }

    private func mapAudioFormat(_ format: SpatialAudioFormat) -> String {
        switch format {
        case .stereo: return "stereo"
        case .ambisonicsFirstOrder: return "ambisonic1"
        case .ambisonicsSecondOrder: return "ambisonic2"
        case .ambisonicsThirdOrder: return "ambisonic3"
        case .resonanceAudio: return "resonance"
        default: return "stereo"
        }
    }

    private func mapInteractiveElement(_ element: InteractiveElement) -> WebXRInteractiveElement {
        return WebXRInteractiveElement(
            id: element.id.uuidString,
            type: element.type.rawValue,
            position: [element.position.x, element.position.y, element.position.z],
            size: [element.size.x, element.size.y],
            content: WebXRElementContent(
                title: element.content.title,
                text: element.content.text,
                imageURL: element.content.imageURL?.absoluteString
            )
        )
    }

    // MARK: - Message Handling

    func handleMessage(type: String, data: [String: Any]) {
        switch type {
        case "supportChecked":
            handleSupportChecked(data)

        case "sessionStarted":
            isSessionActive = true
            if let typeString = data["sessionType"] as? String {
                currentSessionType = WebXRSessionType(rawValue: typeString)
            }
            onSessionStarted?()

        case "sessionEnded":
            isSessionActive = false
            currentSessionType = nil
            connectionState = .disconnected
            onSessionEnded?()

        case "frameUpdate":
            if let frameData = parseFrameData(data) {
                currentFrameData = frameData
                onFrameUpdate?(frameData)
            }

        case "inputSourceAdded":
            if let source = parseInputSource(data) {
                inputSources.append(source)
                onInputSourceAdded?(source)
            }

        case "inputSourceRemoved":
            if let id = data["id"] as? String {
                inputSources.removeAll { $0.id == id }
                onInputSourceRemoved?(id)
            }

        case "selectStart":
            if let source = findInputSource(data) {
                onSelectStart?(source)
            }

        case "selectEnd":
            if let source = findInputSource(data) {
                onSelectEnd?(source)
            }

        case "squeezeStart":
            if let source = findInputSource(data) {
                onSqueezeStart?(source)
            }

        case "squeezeEnd":
            if let source = findInputSource(data) {
                onSqueezeEnd?(source)
            }

        case "sessionError":
            if let error = data["error"] as? String {
                connectionState = .error(error)
            }

        default:
            break
        }
    }

    private func handleSupportChecked(_ data: [String: Any]) {
        isSupported = data["xrSupported"] as? Bool ?? false

        if let features = data["features"] as? [String] {
            supportedFeatures = features
        }
    }

    private func parseFrameData(_ data: [String: Any]) -> WebXRFrameData? {
        guard let timestamp = data["timestamp"] as? Double else { return nil }

        var frameData = WebXRFrameData(
            timestamp: timestamp,
            inputSources: []
        )

        if let viewerPoseData = data["viewerPose"] as? [String: Any],
           let position = viewerPoseData["position"] as? [Float],
           let orientation = viewerPoseData["orientation"] as? [Float] {
            frameData.viewerPose = WebXRFrameData.ViewerPose(
                position: position,
                orientation: orientation,
                views: []
            )
        }

        return frameData
    }

    private func parseInputSource(_ data: [String: Any]) -> WebXRInputSource? {
        guard let id = data["id"] as? String,
              let handednessString = data["handedness"] as? String,
              let targetRayModeString = data["targetRayMode"] as? String else {
            return nil
        }

        return WebXRInputSource(
            id: id,
            handedness: WebXRInputSource.Handedness(rawValue: handednessString) ?? .none,
            targetRayMode: WebXRInputSource.TargetRayMode(rawValue: targetRayModeString) ?? .gaze,
            profiles: data["profiles"] as? [String] ?? []
        )
    }

    private func findInputSource(_ data: [String: Any]) -> WebXRInputSource? {
        if let handedness = data["handedness"] as? String {
            return inputSources.first { $0.handedness.rawValue == handedness }
        }
        return nil
    }
}

// MARK: - Message Handler

#if canImport(WebKit)
private class WebXRMessageHandler: NSObject, WKScriptMessageHandler {
    weak var bridge: WebXRBridge?

    init(bridge: WebXRBridge) {
        self.bridge = bridge
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String,
              let data = body["data"] as? [String: Any] else {
            return
        }

        Task { @MainActor in
            bridge?.handleMessage(type: type, data: data)
        }
    }
}
#endif

// MARK: - WebXR Content Types

public struct WebXRContent: Codable {
    public let id: String
    public let title: String
    public let videoURL: String?
    public let format: String
    public let audioFormat: String
    public let interactiveElements: [WebXRInteractiveElement]
}

public struct WebXRInteractiveElement: Codable {
    public let id: String
    public let type: String
    public let position: [Float]
    public let size: [Float]
    public let content: WebXRElementContent
}

public struct WebXRElementContent: Codable {
    public let title: String?
    public let text: String?
    public let imageURL: String?
}

// MARK: - WebXR Errors

public enum WebXRError: Error, LocalizedError {
    case platformNotSupported
    case webViewNotAvailable
    case sessionNotActive
    case invalidConfiguration
    case invalidContent
    case sessionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .platformNotSupported:
            return "WebXR is not supported on this platform"
        case .webViewNotAvailable:
            return "WebView is not available"
        case .sessionNotActive:
            return "No active WebXR session"
        case .invalidConfiguration:
            return "Invalid WebXR configuration"
        case .invalidContent:
            return "Invalid content format"
        case .sessionFailed(let reason):
            return "Session failed: \(reason)"
        }
    }
}

// MARK: - WebXR HTML Template

extension WebXRBridge {
    /// Generate HTML for WebXR experience
    public static func generateHTML(for content: ImmersiveContent) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(content.title) - Echoelmusic WebXR</title>
            <script src="https://aframe.io/releases/1.4.0/aframe.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/resonance-audio/build/resonance-audio.min.js"></script>
            <style>
                body { margin: 0; overflow: hidden; }
                #enterVR {
                    position: fixed;
                    bottom: 20px;
                    left: 50%;
                    transform: translateX(-50%);
                    padding: 15px 30px;
                    background: #6366F1;
                    color: white;
                    border: none;
                    border-radius: 25px;
                    font-size: 18px;
                    cursor: pointer;
                    z-index: 1000;
                }
                #enterVR:hover { background: #4F46E5; }
            </style>
        </head>
        <body>
            <button id="enterVR">Enter VR</button>
            <a-scene
                webxr="requiredFeatures: local-floor; optionalFeatures: hand-tracking"
                renderer="antialias: true; colorManagement: true; physicallyCorrectLights: true">

                <!-- 360 Video Sky -->
                <a-videosphere
                    src="\(content.videoURL?.absoluteString ?? "")"
                    rotation="0 -90 0">
                </a-videosphere>

                <!-- Spatial Audio -->
                <a-entity
                    resonance-audio-room="dimensions: 10 10 10; materials: acoustic-ceiling-tiles brick-painted curtain-heavy">
                </a-entity>

                <!-- Camera Rig -->
                <a-entity id="rig">
                    <a-camera
                        position="0 1.6 0"
                        look-controls="pointerLockEnabled: true">
                        <a-cursor
                            color="#6366F1"
                            fuse="true"
                            fuse-timeout="1500">
                        </a-cursor>
                    </a-camera>
                </a-entity>

                <!-- Hand Controllers -->
                <a-entity
                    id="leftHand"
                    hand-controls="hand: left"
                    laser-controls="hand: left">
                </a-entity>
                <a-entity
                    id="rightHand"
                    hand-controls="hand: right"
                    laser-controls="hand: right">
                </a-entity>

            </a-scene>

            <script>
                document.getElementById('enterVR').addEventListener('click', () => {
                    document.querySelector('a-scene').enterVR();
                });
            </script>
        </body>
        </html>
        """
    }
}

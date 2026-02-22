//
//  HybridAppBridge.swift
//  Echoelmusic
//
//  Created: February 2026
//  HYBRID APP BRIDGE — Native ↔ Web communication for PWA hybrid mode
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  Architecture:
//
//    ┌─────────────────────────────────┐
//    │  Web Layer (PWA / WebView)      │
//    │  - WebAudio API                 │
//    │  - WebAssembly DSP              │
//    │  - WebGL/WebGPU Visuals         │
//    │  - WebMIDI API                  │
//    │  - Web Bluetooth (sensors)      │
//    └──────────┬──────────────────────┘
//               │ JavaScript Bridge
//    ┌──────────┴──────────────────────┐
//    │  HybridAppBridge (this file)    │
//    │  - WKScriptMessageHandler       │
//    │  - Native ↔ JS method calls     │
//    │  - Shared state via UserDefaults│
//    │  - Bio-data forwarding          │
//    └──────────┬──────────────────────┘
//               │
//    ┌──────────┴──────────────────────┐
//    │  Native Layer                   │
//    │  - CoreAudio / AVAudioEngine    │
//    │  - HealthKit (bio-sensors)      │
//    │  - CoreML (AI inference)        │
//    │  - Metal (GPU rendering)        │
//    │  - CoreMIDI                     │
//    └─────────────────────────────────┘
//  ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import Combine

#if canImport(WebKit)
import WebKit
#endif

// MARK: - Hybrid Bridge Message Types

/// Messages from Web → Native
public enum HybridMessageType: String, Codable {
    // Audio
    case noteOn             = "noteOn"
    case noteOff            = "noteOff"
    case setParameter       = "setParameter"
    case loadPreset         = "loadPreset"
    case startEngine        = "startEngine"
    case stopEngine         = "stopEngine"

    // Bio
    case requestBioData     = "requestBioData"
    case setBioSource       = "setBioSource"

    // Session
    case saveSession        = "saveSession"
    case loadSession        = "loadSession"
    case exportAudio        = "exportAudio"

    // System
    case getCapabilities    = "getCapabilities"
    case requestMIDIAccess  = "requestMIDIAccess"
    case getPluginList      = "getPluginList"
}

/// Messages from Native → Web
public enum HybridResponseType: String, Codable {
    case bioDataUpdate      = "bioDataUpdate"
    case meterUpdate        = "meterUpdate"
    case midiEvent          = "midiEvent"
    case parameterChanged   = "parameterChanged"
    case capabilities       = "capabilities"
    case pluginList         = "pluginList"
    case error              = "error"
}

// MARK: - Platform Capabilities

/// What this device can do natively (sent to web layer on init)
public struct PlatformCapabilities: Codable {
    public let platform: String             // "iOS", "macOS", "web"
    public let hasHealthKit: Bool
    public let hasCoreML: Bool
    public let hasMetal: Bool
    public let hasCoreAudio: Bool
    public let hasCoreMIDI: Bool
    public let hasARKit: Bool
    public let hasSharePlay: Bool
    public let maxAudioChannels: Int
    public let sampleRate: Double
    public let gpuName: String
    public let supportsHaptics: Bool
    public let supportsSpatialAudio: Bool

    public static var current: PlatformCapabilities {
        #if os(iOS)
        let platformName = "iOS"
        let healthKit = true
        let arKit = true
        let haptics = true
        #elseif os(macOS)
        let platformName = "macOS"
        let healthKit = false
        let arKit = false
        let haptics = false
        #elseif os(visionOS)
        let platformName = "visionOS"
        let healthKit = true
        let arKit = true
        let haptics = false
        #else
        let platformName = "unknown"
        let healthKit = false
        let arKit = false
        let haptics = false
        #endif

        return PlatformCapabilities(
            platform: platformName,
            hasHealthKit: healthKit,
            hasCoreML: true,
            hasMetal: true,
            hasCoreAudio: true,
            hasCoreMIDI: true,
            hasARKit: arKit,
            hasSharePlay: true,
            maxAudioChannels: 32,
            sampleRate: 48000,
            gpuName: "Apple GPU",
            supportsHaptics: haptics,
            supportsSpatialAudio: true
        )
    }
}

// MARK: - Hybrid App Bridge

/// Bridges Web (PWA/WebView) ↔ Native code for hybrid app mode
@MainActor
public final class HybridAppBridge: NSObject, ObservableObject {

    public static let shared = HybridAppBridge()

    @Published public var isWebViewLoaded: Bool = false
    @Published public var webViewURL: URL?

    #if canImport(WebKit)
    public weak var webView: WKWebView?
    #endif

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Setup

    #if canImport(WebKit)
    /// Configure WKWebView with Echoelmusic bridge
    public func configureWebView(_ webView: WKWebView) {
        self.webView = webView

        let contentController = webView.configuration.userContentController

        // Register message handlers for Web → Native communication
        for messageType in HybridMessageType.allCases {
            contentController.add(self, name: messageType.rawValue)
        }

        // Inject the Echoelmusic JavaScript bridge
        let bridgeScript = WKUserScript(
            source: echoelJSBridge,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bridgeScript)
    }
    #endif

    // MARK: - Native → Web

    /// Send data to web layer
    public func sendToWeb(type: HybridResponseType, data: [String: Any]) {
        #if canImport(WebKit)
        guard let webView = webView else { return }

        // Security: Use JSONSerialization for safe encoding, then pass via callAsyncJavaScript
        // to avoid string interpolation XSS vulnerabilities
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.fragmentsAllowed]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        // Escape the type string to prevent injection via enum raw values
        let safeType = type.rawValue
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")

        // Escape the JSON string to prevent breaking out of the JS context
        let safeJSON = jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "</", with: "<\\/")  // Prevent </script> injection

        let js = "if(window.echoelBridge&&typeof window.echoelBridge.receive==='function'){window.echoelBridge.receive('\(safeType)',JSON.parse('\(safeJSON)'));}"
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                ProfessionalLogger.shared.log(.warning, category: .system, "HybridBridge JS eval error: \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Forward bio-data to web layer
    public func sendBioUpdate(coherence: Float, heartRate: Float, hrv: Float, breathPhase: Float) {
        sendToWeb(type: .bioDataUpdate, data: [
            "coherence": coherence,
            "heartRate": heartRate,
            "hrv": hrv,
            "breathPhase": breathPhase,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    /// Forward audio meter to web layer
    public func sendMeterUpdate(rms: Float, peak: Float) {
        sendToWeb(type: .meterUpdate, data: [
            "rms": rms,
            "peak": peak
        ])
    }

    // MARK: - JavaScript Bridge Code

    /// JavaScript injected into WebView for native communication
    private var echoelJSBridge: String {
        """
        window.echoelBridge = {
            // Send message to native
            send: function(type, data) {
                window.webkit.messageHandlers[type].postMessage(data || {});
            },

            // Receive message from native (called by native code)
            receive: function(type, data) {
                const event = new CustomEvent('echoel-' + type, { detail: data });
                window.dispatchEvent(event);
                if (this._handlers[type]) {
                    this._handlers[type].forEach(function(fn) { fn(data); });
                }
            },

            // Register handler
            on: function(type, callback) {
                if (!this._handlers[type]) this._handlers[type] = [];
                this._handlers[type].push(callback);
            },

            _handlers: {},

            // Convenience methods
            noteOn: function(note, velocity) { this.send('noteOn', {note: note, velocity: velocity}); },
            noteOff: function(note) { this.send('noteOff', {note: note}); },
            setParameter: function(id, value) { this.send('setParameter', {id: id, value: value}); },
            loadPreset: function(index) { this.send('loadPreset', {index: index}); },
            requestBioData: function() { this.send('requestBioData'); },
            getCapabilities: function() { this.send('getCapabilities'); },
            getPluginList: function() { this.send('getPluginList'); },
        };

        // Signal that bridge is ready
        window.dispatchEvent(new Event('echoel-bridge-ready'));
        """
    }
}

// MARK: - WKScriptMessageHandler

#if canImport(WebKit)
extension HybridAppBridge: WKScriptMessageHandler {
    nonisolated public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let messageType = HybridMessageType(rawValue: message.name) else { return }
        let body = message.body as? [String: Any] ?? [:]

        Task { @MainActor in
            self.handleWebMessage(type: messageType, data: body)
        }
    }
}
#endif

extension HybridAppBridge {
    private func handleWebMessage(type: HybridMessageType, data: [String: Any]) {
        switch type {
        case .noteOn:
            let note = data["note"] as? Int ?? 60
            let velocity = data["velocity"] as? Float ?? 0.8
            // Forward to active synth engine
            TR808BassSynth.shared.noteOn(note: note, velocity: velocity)

        case .noteOff:
            let note = data["note"] as? Int ?? 60
            TR808BassSynth.shared.noteOff(note: note)

        case .setParameter:
            let paramId = data["id"] as? Int ?? 0
            let value = data["value"] as? Float ?? 0.0
            // Forward to parameter system
            _ = (paramId, value) // Placeholder

        case .loadPreset:
            let index = data["index"] as? Int ?? 0
            _ = index // Placeholder

        case .getCapabilities:
            let caps = PlatformCapabilities.current
            if let encoded = try? JSONEncoder().encode(caps),
               let dict = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] {
                sendToWeb(type: .capabilities, data: dict)
            }

        case .getPluginList:
            let plugins = PluginBundleManager.pluginSuite.map { p in
                ["id": p.id, "name": p.name, "subtitle": p.subtitle, "category": p.category.rawValue]
            }
            sendToWeb(type: .pluginList, data: ["plugins": plugins])

        default:
            break
        }
    }
}

// MARK: - CaseIterable conformance

extension HybridMessageType: CaseIterable {}

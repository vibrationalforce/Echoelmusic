#if os(iOS) || os(macOS)
import Foundation
import AVFoundation
import Combine
import CoreImage
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreHaptics)
import CoreHaptics
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - EchoelMind Camera Assistant
// ═══════════════════════════════════════════════════════════════════════════════
//
// AI-powered camera assistant integrated with EchoelMind (intelligence layer)
// and EchoelField (visual layer).
//
// Designed for:
//   - Non-professionals: One-tap smart presets, AI scene detection
//   - Disabled users: VoiceOver guidance, voice control, haptic feedback,
//     Switch Control, large touch targets, audio descriptions
//   - Professionals: Deep film/photo technique presets with full manual override
//
// Photography Techniques:
//   Long Exposure, Light Painting, Star Trails, Silky Water, Light Trails,
//   Steel Wool, Golden Hour, Blue Hour, Night Portrait, Milky Way,
//   Infrared Look, HDR Bracketing, Focus Stacking, Panning Blur
//
// Film Techniques:
//   Timelapse, Hyperlapse, Slow Motion, Dolly Zoom (Vertigo),
//   Dutch Angle, Rack Focus, Day-for-Night, Magic Hour, Cinematic Bars
//
// Bio-Reactive Modes:
//   Coherence-driven auto-mood, breath-synced shutter, heart-rate timelapse
//
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
public final class EchoelMindCameraAssistant: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelMindCameraAssistant()

    // MARK: - Dependencies

    private weak var camera: CameraManager?

    // MARK: - Published State

    @Published public var activePreset: CreativePreset = .auto
    @Published public var sceneDetected: DetectedScene = .unknown
    @Published public var assistantMessage: String = ""
    @Published public var isAnalyzing: Bool = false
    @Published public var confidenceLevel: Float = 0.0

    // Bio-reactive
    @Published public var bioReactiveEnabled: Bool = true
    @Published public var currentCoherence: Float = 0.5
    @Published public var currentHeartRate: Float = 72.0

    // Accessibility
    @Published public var accessibilityMode: AccessibilityLevel = .standard
    @Published public var voiceGuidanceEnabled: Bool = false
    @Published public var hapticFeedbackEnabled: Bool = true
    @Published public var simplifiedUI: Bool = false

    // Technique state
    @Published public var longExposureActive: Bool = false
    @Published public var timelapseActive: Bool = false
    @Published public var focusStackCount: Int = 0

    // MARK: - Long Exposure Frame Accumulator

    private var accumulatedFrames: [CIImage] = []
    private var frameAccumulationCount: Int = 0
    private var longExposureDuration: TimeInterval = 2.0

    // MARK: - Subscriptions

    private var cancellables = Set<AnyCancellable>()
    private var busSubscription: BusSubscription?

    // =========================================================================
    // MARK: - Creative Presets — Deep Film & Photo Knowledge
    // =========================================================================

    public enum CreativePreset: String, CaseIterable, Sendable {

        // ── Smart Auto ──────────────────────────────────────────────────
        case auto = "Auto"

        // ── Photography Techniques ──────────────────────────────────────
        case longExposure = "Long Exposure"
        case lightPainting = "Light Painting"
        case starTrails = "Star Trails"
        case silkyWater = "Silky Water"
        case lightTrails = "Light Trails"
        case goldenHour = "Golden Hour"
        case blueHour = "Blue Hour"
        case nightPortrait = "Night Portrait"
        case milkyWay = "Milky Way"
        case hdrBracketing = "HDR Bracketing"
        case focusStacking = "Focus Stacking"
        case panningBlur = "Panning Blur"
        case bokehlicious = "Bokeh Master"
        case highKey = "High Key"
        case lowKey = "Low Key"
        case silhouette = "Silhouette"
        case doubleExposure = "Double Exposure"
        case infraredLook = "Infrared Look"

        // ── Film/Video Techniques ───────────────────────────────────────
        case timelapse = "Timelapse"
        case hyperlapse = "Hyperlapse"
        case slowMotion = "Slow Motion"
        case cinematic = "Cinematic"
        case dollyZoom = "Dolly Zoom"
        case dutchAngle = "Dutch Angle"
        case rackFocus = "Rack Focus"
        case dayForNight = "Day for Night"

        // ── Bio-Reactive ────────────────────────────────────────────────
        case bioMood = "Bio Mood"
        case breathSync = "Breath Sync"
        case heartRateLapse = "Heart Rate Lapse"
        case coherencePortrait = "Coherence Portrait"

        /// Human-readable description for accessibility
        public var accessibilityDescription: String {
            switch self {
            case .auto: return "Smart auto mode. The camera analyzes the scene and chooses the best settings automatically."
            case .longExposure: return "Long exposure. Keeps the shutter open longer for smooth water, light trails, and dreamy effects. Hold the device very still."
            case .lightPainting: return "Light painting. Use a light source like a phone flashlight to draw in the air. The camera captures the light trail."
            case .starTrails: return "Star trails. Captures the rotation of stars across the night sky. Requires a tripod and dark sky."
            case .silkyWater: return "Silky water. Makes waterfalls and rivers look smooth and silky. Best with a tripod."
            case .lightTrails: return "Light trails. Captures car headlights and taillights as smooth lines. Best shot from a bridge or overpass."
            case .goldenHour: return "Golden hour. Warm, soft light shortly after sunrise or before sunset. Enhances skin tones and landscapes."
            case .blueHour: return "Blue hour. Cool, blue-toned light just before sunrise or after sunset. Creates a calm, moody atmosphere."
            case .nightPortrait: return "Night portrait. Combines flash for the subject with a slow shutter for city lights behind."
            case .milkyWay: return "Milky Way photography. Maximum ISO, wide aperture, 20-second exposure for capturing the galaxy."
            case .hdrBracketing: return "HDR bracketing. Takes multiple photos at different exposures and combines them for maximum detail in shadows and highlights."
            case .focusStacking: return "Focus stacking. Takes multiple photos at different focus distances, then combines them for extreme depth of field. Great for macro photography."
            case .panningBlur: return "Panning blur. Follow a moving subject to keep it sharp while blurring the background for a sense of speed."
            case .bokehlicious: return "Bokeh master. Creates beautiful, smooth background blur. Uses the telephoto lens with widest aperture."
            case .highKey: return "High key. Bright, airy look with minimal shadows. Great for portraits and fashion."
            case .lowKey: return "Low key. Dark, dramatic look with deep shadows. Great for moody portraits and film noir style."
            case .silhouette: return "Silhouette. Exposes for the bright background, making the subject a dark outline."
            case .doubleExposure: return "Double exposure. Blends two images together for a creative, dreamy effect."
            case .infraredLook: return "Infrared look. Simulates infrared photography with white foliage and dark skies."
            case .timelapse: return "Timelapse. Records one frame every few seconds, then plays back at normal speed to show time passing quickly."
            case .hyperlapse: return "Hyperlapse. Like timelapse but while moving. Creates a smooth, accelerated journey through space."
            case .slowMotion: return "Slow motion. Records at 120 or 240 frames per second for dramatic slow-motion playback."
            case .cinematic: return "Cinematic mode. Film-like look with shallow depth of field, 24 frames per second, and letterbox bars."
            case .dollyZoom: return "Dolly zoom, also known as the Vertigo effect. Zooms in while moving the camera back, creating a disorienting perspective shift."
            case .dutchAngle: return "Dutch angle. Tilts the camera to create tension and unease. Used in thriller and horror films."
            case .rackFocus: return "Rack focus. Shifts focus from one subject to another within a single shot to guide the viewer's attention."
            case .dayForNight: return "Day for night. Shoots during the day with settings that make the footage look like nighttime."
            case .bioMood: return "Bio mood. The camera automatically adjusts warmth, saturation, and exposure based on your current emotional state from biometric data."
            case .breathSync: return "Breath sync. The shutter fires in sync with your breathing rhythm, capturing the moment of stillness between breaths."
            case .heartRateLapse: return "Heart rate timelapse. Capture frequency matches your heartbeat. Faster heart means faster timelapse."
            case .coherencePortrait: return "Coherence portrait. Waits for peak coherence to capture the most relaxed, natural expression."
            }
        }

        /// Short voice guidance for non-experts
        public var quickTip: String {
            switch self {
            case .auto: return "Point and shoot. I handle the rest."
            case .longExposure: return "Hold still or use a tripod. I'll keep the shutter open."
            case .lightPainting: return "Move a light source in the dark. I'll capture the trail."
            case .starTrails: return "Point at the stars. This takes a few minutes. Use a tripod."
            case .silkyWater: return "Point at flowing water. I'll make it silky smooth."
            case .lightTrails: return "Aim at a road at night. Car lights will become smooth lines."
            case .goldenHour: return "Best near sunrise or sunset. Everything looks warm and beautiful."
            case .blueHour: return "Best just after sunset. Cool blue tones everywhere."
            case .nightPortrait: return "I'll light your face and keep the city lights behind."
            case .milkyWay: return "Find a dark sky, no city lights. Point up. This is magic."
            case .hdrBracketing: return "Hold still. I'll take 3 shots at different brightnesses."
            case .focusStacking: return "Hold still. I'll take multiple shots at different focus points."
            case .panningBlur: return "Follow the moving subject. Swipe smoothly left or right."
            case .bokehlicious: return "Get close to your subject. The background will melt away."
            case .highKey: return "Best with light backgrounds. Bright, clean, airy look."
            case .lowKey: return "Best with dark backgrounds. Dramatic and moody."
            case .silhouette: return "Put your subject in front of a bright light or sky."
            case .doubleExposure: return "I'll blend two shots together. Art happens."
            case .infraredLook: return "Trees turn white, sky turns dark. Otherworldly."
            case .timelapse: return "Set the device down and wait. I'll speed up time."
            case .hyperlapse: return "Walk smoothly. I'll stabilize and speed it up."
            case .slowMotion: return "Action shots. Everything slows down beautifully."
            case .cinematic: return "Film look. Shallow focus, movie bars, 24fps."
            case .dollyZoom: return "Walk backward while I zoom in. Hitchcock's famous effect."
            case .dutchAngle: return "Tilt your phone for tension. Great for dramatic moments."
            case .rackFocus: return "Tap the new subject. Focus shifts dramatically."
            case .dayForNight: return "Shoot in daylight. I'll make it look like night."
            case .bioMood: return "Relax and breathe. Your body shapes the image."
            case .breathSync: return "Breathe naturally. I'll capture between breaths for maximum stillness."
            case .heartRateLapse: return "Your heartbeat controls the recording speed."
            case .coherencePortrait: return "Relax deeply. I'll capture your most natural expression."
            }
        }
    }

    // =========================================================================
    // MARK: - Scene Detection
    // =========================================================================

    public enum DetectedScene: String, CaseIterable, Sendable {
        case unknown = "Analyzing..."
        case portrait = "Portrait"
        case landscape = "Landscape"
        case night = "Night"
        case sunset = "Sunset/Golden Hour"
        case water = "Water"
        case macro = "Close-Up"
        case action = "Action/Sports"
        case indoor = "Indoor"
        case city = "City/Urban"
        case nature = "Nature"
        case stage = "Stage/Concert"
        case studio = "Studio"

        /// Recommended presets for this scene
        var recommendedPresets: [CreativePreset] {
            switch self {
            case .unknown: return [.auto]
            case .portrait: return [.bokehlicious, .highKey, .coherencePortrait, .cinematic]
            case .landscape: return [.goldenHour, .hdrBracketing, .silkyWater, .timelapse]
            case .night: return [.longExposure, .lightTrails, .milkyWay, .nightPortrait, .lightPainting]
            case .sunset: return [.goldenHour, .silhouette, .timelapse, .hdrBracketing]
            case .water: return [.silkyWater, .longExposure, .timelapse, .hdrBracketing]
            case .macro: return [.focusStacking, .bokehlicious, .highKey]
            case .action: return [.slowMotion, .panningBlur, .hyperlapse]
            case .indoor: return [.lowKey, .highKey, .bokehlicious, .cinematic]
            case .city: return [.lightTrails, .timelapse, .hyperlapse, .dutchAngle, .cinematic]
            case .nature: return [.goldenHour, .silkyWater, .infraredLook, .timelapse]
            case .stage: return [.slowMotion, .cinematic, .lowKey, .bioMood]
            case .studio: return [.highKey, .lowKey, .bokehlicious, .focusStacking]
            }
        }
    }

    // =========================================================================
    // MARK: - Accessibility Level
    // =========================================================================

    public enum AccessibilityLevel: String, CaseIterable, Sendable {
        case standard = "Standard"
        case assisted = "Assisted"
        case voiceGuided = "Voice Guided"
        case switchControl = "Switch Control"
        case fullAssist = "Full Assist"

        var description: String {
            switch self {
            case .standard: return "Standard controls"
            case .assisted: return "Larger buttons, simplified options, haptic feedback"
            case .voiceGuided: return "Voice descriptions of scene and settings changes"
            case .switchControl: return "Optimized for Switch Control and eye tracking"
            case .fullAssist: return "Maximum assistance: voice guidance, haptics, auto-everything, large targets"
            }
        }
    }

    // =========================================================================
    // MARK: - Initialization
    // =========================================================================

    private init() {
        setupBioSubscription()
        detectAccessibilityNeeds()
    }

    /// Connect to a CameraManager instance
    public func connect(camera: CameraManager) {
        self.camera = camera
        log.video("EchoelMindCameraAssistant: Connected to CameraManager")
    }

    // =========================================================================
    // MARK: - Apply Preset — Deep Film/Photo Knowledge
    // =========================================================================

    /// Apply a creative preset — configures all camera parameters based on
    /// deep knowledge of photography and cinematography techniques
    public func applyPreset(_ preset: CreativePreset) {
        guard let camera = camera else {
            assistantMessage = "Camera not connected"
            return
        }

        activePreset = preset

        switch preset {

        // ── Auto ────────────────────────────────────────────────────────
        case .auto:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.continuousAuto)
            camera.setWhiteBalanceMode(.auto)
            camera.setStabilizationMode(.auto)
            camera.setHDR(enabled: true)
            assistantMessage = "Auto mode — camera handles everything"

        // ── Long Exposure (2-30s, ISO 50, stabilized) ───────────────────
        case .longExposure:
            camera.setExposureMode(.custom)
            camera.setISO(camera.isoRange.lowerBound) // lowest ISO
            camera.setShutterSpeed(CMTime(value: 2, timescale: 1)) // 2 seconds
            camera.setFocusMode(.locked)
            camera.setStabilizationMode(.cinematic)
            camera.setHDR(enabled: false) // HDR interferes with long exposure
            longExposureActive = true
            assistantMessage = "Long exposure — hold very still or use a tripod"

        // ── Light Painting (bulb mode, darkest settings) ────────────────
        case .lightPainting:
            camera.setExposureMode(.custom)
            camera.setISO(camera.isoRange.lowerBound)
            camera.setShutterSpeed(CMTime(value: 4, timescale: 1)) // 4 seconds
            camera.setExposureCompensation(-2.0) // underexpose background
            camera.setFocusMode(.manual)
            camera.setFocusPosition(0.7) // mid-distance
            camera.setTorchMode(.off)
            longExposureActive = true
            assistantMessage = "Light painting — draw with light in the dark"

        // ── Star Trails (max exposure, lowest ISO, locked) ──────────────
        case .starTrails:
            camera.setExposureMode(.custom)
            camera.setISO(camera.isoRange.lowerBound)
            camera.setShutterSpeed(CMTime(value: 30, timescale: 1)) // 30 seconds
            camera.setFocusMode(.manual)
            camera.setFocusPosition(1.0) // infinity focus
            camera.setWhiteBalance(temperature: 4200, tint: 0) // slightly cool
            camera.setHDR(enabled: false)
            longExposureActive = true
            assistantMessage = "Star trails — point at the sky, use a tripod"

        // ── Silky Water (1/4s - 2s, low ISO) ───────────────────────────
        case .silkyWater:
            camera.setExposureMode(.custom)
            camera.setISO(camera.isoRange.lowerBound)
            camera.setShutterSpeed(CMTime(value: 1, timescale: 2)) // 0.5 seconds
            camera.setFocusMode(.continuousAuto)
            camera.setStabilizationMode(.cinematic)
            assistantMessage = "Silky water — waterfalls and rivers become smooth"

        // ── Light Trails (4-15s, cars at night) ─────────────────────────
        case .lightTrails:
            camera.setExposureMode(.custom)
            camera.setISO(camera.isoRange.lowerBound)
            camera.setShutterSpeed(CMTime(value: 8, timescale: 1)) // 8 seconds
            camera.setFocusMode(.locked)
            camera.setWhiteBalance(temperature: 3800, tint: 0) // warm for streetlights
            longExposureActive = true
            assistantMessage = "Light trails — cars become rivers of light"

        // ── Golden Hour (warm WB, slight overexpose) ────────────────────
        case .goldenHour:
            camera.setExposureMode(.auto)
            camera.setExposureCompensation(0.7) // slight overexposure for glow
            camera.setWhiteBalance(temperature: 5800, tint: 10) // warm
            camera.setFocusMode(.continuousAuto)
            camera.setHDR(enabled: true)
            assistantMessage = "Golden hour — warm, soft, magical light"

        // ── Blue Hour (cool WB, slight underexpose) ─────────────────────
        case .blueHour:
            camera.setExposureMode(.auto)
            camera.setExposureCompensation(-0.3)
            camera.setWhiteBalance(temperature: 7500, tint: -5) // cool blue
            camera.setFocusMode(.continuousAuto)
            assistantMessage = "Blue hour — cool, calm, twilight mood"

        // ── Night Portrait (balanced flash + ambient) ───────────────────
        case .nightPortrait:
            camera.setExposureMode(.custom)
            camera.setISO(800)
            camera.setShutterSpeed(CMTime(value: 1, timescale: 15)) // 1/15s
            camera.setFocusMode(.continuousAuto)
            camera.setWhiteBalance(temperature: 4500, tint: 5)
            camera.setStabilizationMode(.cinematic)
            assistantMessage = "Night portrait — face lit, city lights preserved"

        // ── Milky Way (ISO 3200+, 20s, widest lens) ─────────────────────
        case .milkyWay:
            camera.setExposureMode(.custom)
            camera.setISO(Swift.min(3200, camera.isoRange.upperBound))
            camera.setShutterSpeed(CMTime(value: 20, timescale: 1))
            camera.setFocusMode(.manual)
            camera.setFocusPosition(1.0) // infinity
            camera.setWhiteBalance(temperature: 3800, tint: 10)
            camera.setHDR(enabled: false)
            longExposureActive = true
            // Switch to ultra-wide for widest field of view
            Task {
                if camera.availableCameras.contains(.ultraWide) {
                    try? await camera.switchCamera(to: .ultraWide)
                }
            }
            assistantMessage = "Milky Way — find dark sky, tripod required"

        // ── HDR Bracketing (3 exposures: -2, 0, +2 EV) ─────────────────
        case .hdrBracketing:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.locked)
            camera.setStabilizationMode(.cinematic)
            camera.setHDR(enabled: true)
            assistantMessage = "HDR — hold still for 3 exposure brackets"

        // ── Focus Stacking (multiple focus distances) ───────────────────
        case .focusStacking:
            camera.setExposureMode(.locked) // lock exposure across stack
            camera.setFocusMode(.manual)
            camera.setStabilizationMode(.cinematic)
            focusStackCount = 0
            assistantMessage = "Focus stacking — I'll sweep focus near to far"

        // ── Panning Blur (slow shutter, follow subject) ─────────────────
        case .panningBlur:
            camera.setExposureMode(.custom)
            camera.setISO(camera.isoRange.lowerBound)
            camera.setShutterSpeed(CMTime(value: 1, timescale: 30)) // 1/30s
            camera.setFocusMode(.continuousAuto)
            camera.setStabilizationMode(.off) // intentional blur
            assistantMessage = "Panning — follow the subject smoothly"

        // ── Bokeh Master (telephoto, widest aperture) ───────────────────
        case .bokehlicious:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.continuousAuto)
            camera.setDepthEnabled(true) // depth for synthetic bokeh
            Task {
                if camera.availableCameras.contains(.telephoto) {
                    try? await camera.switchCamera(to: .telephoto)
                }
            }
            assistantMessage = "Bokeh — get close, background melts away"

        // ── High Key (overexpose, bright, airy) ─────────────────────────
        case .highKey:
            camera.setExposureMode(.auto)
            camera.setExposureCompensation(1.5)
            camera.setWhiteBalance(temperature: 6200, tint: 0)
            camera.setFocusMode(.continuousAuto)
            assistantMessage = "High key — bright, clean, minimal shadows"

        // ── Low Key (underexpose, dramatic, moody) ──────────────────────
        case .lowKey:
            camera.setExposureMode(.auto)
            camera.setExposureCompensation(-1.5)
            camera.setWhiteBalance(temperature: 4500, tint: 0)
            camera.setFocusMode(.continuousAuto)
            assistantMessage = "Low key — dark, dramatic, cinematic shadows"

        // ── Silhouette (meter for bright background) ────────────────────
        case .silhouette:
            camera.setExposureMode(.auto)
            camera.setExposureCompensation(-2.0) // heavy underexpose
            camera.setFocusMode(.continuousAuto)
            camera.setHDR(enabled: false) // HDR would ruin the silhouette
            assistantMessage = "Silhouette — subject against bright sky or light"

        // ── Double Exposure (frame accumulation) ────────────────────────
        case .doubleExposure:
            camera.setExposureMode(.auto)
            camera.setExposureCompensation(-1.0) // underexpose each frame
            camera.setFocusMode(.locked)
            accumulatedFrames.removeAll()
            assistantMessage = "Double exposure — I'll blend two shots together"

        // ── Infrared Look (white balance trick + post) ──────────────────
        case .infraredLook:
            camera.setExposureMode(.auto)
            camera.setExposureCompensation(0.5)
            // Extreme white balance creates the infrared illusion
            camera.setWhiteBalance(temperature: 2200, tint: -100)
            camera.setFocusMode(.continuousAuto)
            camera.setHDR(enabled: false)
            assistantMessage = "Infrared — trees turn white, sky turns dark"

        // ── Timelapse (1 frame every N seconds) ─────────────────────────
        case .timelapse:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.locked) // consistent focus
            camera.setWhiteBalanceMode(.locked) // consistent color
            camera.setStabilizationMode(.cinematic)
            timelapseActive = true
            assistantMessage = "Timelapse — set device down, time flies"

        // ── Hyperlapse (stabilized moving timelapse) ────────────────────
        case .hyperlapse:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.continuousAuto)
            camera.setStabilizationMode(.cinematicExtended)
            timelapseActive = true
            assistantMessage = "Hyperlapse — walk smoothly, I stabilize"

        // ── Slow Motion (120-240fps) ────────────────────────────────────
        case .slowMotion:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.continuousAuto)
            camera.setStabilizationMode(.standard)
            // Request highest frame rate
            Task {
                try? await camera.startCapture(frameRate: 240)
            }
            assistantMessage = "Slow motion — every moment stretches"

        // ── Cinematic (24fps, shallow DoF, letterbox) ───────────────────
        case .cinematic:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.continuousAuto)
            camera.setDepthEnabled(true)
            camera.setStabilizationMode(.cinematic)
            camera.setWhiteBalance(temperature: 5200, tint: 5)
            // 24fps for film cadence
            Task {
                try? await camera.startCapture(frameRate: 24)
            }
            assistantMessage = "Cinematic — 24fps film look with shallow depth"

        // ── Dolly Zoom (zoom while moving) ──────────────────────────────
        case .dollyZoom:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.locked) // lock focus on subject
            camera.setStabilizationMode(.standard)
            assistantMessage = "Dolly zoom — walk backward, I zoom in. Vertigo effect."

        // ── Dutch Angle ─────────────────────────────────────────────────
        case .dutchAngle:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.continuousAuto)
            camera.setExposureCompensation(-0.5) // slightly moody
            assistantMessage = "Dutch angle — tilt the device 15-30 degrees"

        // ── Rack Focus ──────────────────────────────────────────────────
        case .rackFocus:
            camera.setFocusMode(.manual)
            camera.setDepthEnabled(true)
            assistantMessage = "Rack focus — tap subjects to shift focus dramatically"

        // ── Day for Night (underexpose + cool WB) ───────────────────────
        case .dayForNight:
            camera.setExposureMode(.auto)
            camera.setExposureCompensation(-3.0) // heavy underexpose
            camera.setWhiteBalance(temperature: 10000, tint: -20) // extreme cool
            camera.setHDR(enabled: false)
            assistantMessage = "Day for night — daytime looks like moonlight"

        // ── Bio Mood (coherence → camera mood) ──────────────────────────
        case .bioMood:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.continuousAuto)
            bioReactiveEnabled = true
            applyBioMood()
            assistantMessage = "Bio mood — your body state shapes the image"

        // ── Breath Sync (shutter at exhale stillness) ───────────────────
        case .breathSync:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.continuousAuto)
            camera.setStabilizationMode(.cinematic)
            bioReactiveEnabled = true
            assistantMessage = "Breath sync — capturing between breaths for stillness"

        // ── Heart Rate Lapse ────────────────────────────────────────────
        case .heartRateLapse:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.locked)
            camera.setWhiteBalanceMode(.locked)
            bioReactiveEnabled = true
            timelapseActive = true
            assistantMessage = "Heart rate lapse — your heartbeat is the timer"

        // ── Coherence Portrait (waits for peak coherence) ───────────────
        case .coherencePortrait:
            camera.setExposureMode(.auto)
            camera.setFocusMode(.continuousAuto)
            camera.setStabilizationMode(.cinematic)
            bioReactiveEnabled = true
            assistantMessage = "Coherence portrait — relax deeply, I'll capture your best"
        }

        // Announce for accessibility
        announcePresetChange(preset)

        // Haptic confirmation
        provideHapticFeedback(.preset)

        log.video("EchoelMindCameraAssistant: Applied preset \(preset.rawValue)")
    }

    // =========================================================================
    // MARK: - Focus Stack Capture
    // =========================================================================

    /// Capture a focus stack (multiple images at different focus distances)
    public func captureFocusStack(steps: Int = 8) async throws -> [Data] {
        guard let camera = camera else { throw CameraError.captureSessionFailed }

        var stack: [Data] = []
        let stepSize: Float = 1.0 / Float(steps)

        for i in 0..<steps {
            let position = Float(i) * stepSize
            camera.setFocusPosition(position)

            // Wait for focus to settle
            try await Task.sleep(nanoseconds: 300_000_000)

            let data = try await camera.capturePhoto(format: .heif)
            stack.append(data)
            focusStackCount = i + 1

            announceVoice("Focus step \(i + 1) of \(steps) captured")
            provideHapticFeedback(.capture)
        }

        focusStackCount = 0
        announceVoice("Focus stack complete. \(steps) images captured.")
        return stack
    }

    // =========================================================================
    // MARK: - HDR Bracket Capture
    // =========================================================================

    /// Capture HDR bracket (3 exposures: -2 EV, 0 EV, +2 EV)
    public func captureHDRBracket() async throws -> [Data] {
        guard let camera = camera else { throw CameraError.captureSessionFailed }

        let evValues: [Float] = [-2.0, 0.0, 2.0]
        var bracket: [Data] = []

        for (i, ev) in evValues.enumerated() {
            camera.setExposureCompensation(ev)
            try await Task.sleep(nanoseconds: 200_000_000) // wait for AE to settle
            let data = try await camera.capturePhoto(format: .heif)
            bracket.append(data)
            announceVoice("Bracket \(i + 1) of 3 at \(ev > 0 ? "+" : "")\(Int(ev)) EV")
        }

        // Reset
        camera.setExposureCompensation(0)
        announceVoice("HDR bracket complete")
        return bracket
    }

    // =========================================================================
    // MARK: - Dolly Zoom Control
    // =========================================================================

    /// Smooth dolly zoom effect — call continuously while walking backward
    public func dollyZoomStep(direction: Float) {
        guard let camera = camera else { return }

        let currentZoom = camera.zoomFactor
        let step = CGFloat(direction) * 0.05
        let newZoom = currentZoom + step
        camera.setZoom(newZoom, animated: true, rate: 2.0)
    }

    // =========================================================================
    // MARK: - Bio-Reactive Camera
    // =========================================================================

    private func setupBioSubscription() {
        busSubscription = EngineBus.shared.subscribe(to: [.bio]) { [weak self] msg in
            Task { @MainActor in
                guard let self = self else { return }
                if case .bioUpdate(let bio) = msg {
                    self.currentCoherence = bio.coherence
                    self.currentHeartRate = bio.heartRate

                    if self.bioReactiveEnabled {
                        switch self.activePreset {
                        case .bioMood:
                            self.applyBioMood()
                        case .breathSync:
                            // Capture at exhale stillness (breath phase near 0.5)
                            if abs(bio.breathPhase - 0.5) < 0.05 {
                                self.provideHapticFeedback(.breathSync)
                            }
                        case .heartRateLapse:
                            // Timelapse interval = 60 / heartRate
                            break
                        case .coherencePortrait:
                            // Auto-capture at peak coherence
                            if bio.coherence > 0.85 {
                                self.provideHapticFeedback(.peakCoherence)
                                self.announceVoice("Peak coherence detected. Capturing now.")
                            }
                        default:
                            break
                        }
                    }
                }
            }
        }
    }

    private func applyBioMood() {
        guard let camera = camera else { return }

        // Coherence → warmth (high coherence = warm golden, low = cool blue)
        let temp: Float = 4000 + currentCoherence * 3000 // 4000K-7000K
        let tint: Float = (currentCoherence - 0.5) * 20   // -10..+10

        camera.setWhiteBalance(temperature: temp, tint: tint)

        // Heart rate → exposure energy (high HR = brighter, more contrast)
        let hrNorm = (currentHeartRate - 50) / 150 // normalize 50-200 BPM
        let ev: Float = (hrNorm - 0.5) * 1.0 // -0.5..+0.5 EV
        camera.setExposureCompensation(ev)
    }

    // =========================================================================
    // MARK: - AI Scene Detection
    // =========================================================================

    /// Analyze current camera frame to detect scene type
    public func analyzeScene() {
        guard let camera = camera, camera.isCapturing else { return }

        isAnalyzing = true

        // Use ambient light level + time of day as primary signals
        // (Full CoreML scene classifier would go here with Vision framework)
        let iso = camera.currentISO
        let shutterSeconds = camera.currentShutterSpeed.seconds

        // Heuristic scene detection based on exposure values
        let ev = Foundation.log2(100.0 / Double(iso)) + Foundation.log2(1.0 / shutterSeconds)

        if ev < 4 {
            sceneDetected = .night
            confidenceLevel = 0.8
        } else if ev > 13 {
            sceneDetected = .landscape
            confidenceLevel = 0.6
        } else if iso > 800 {
            sceneDetected = .indoor
            confidenceLevel = 0.7
        } else {
            sceneDetected = .portrait
            confidenceLevel = 0.5
        }

        isAnalyzing = false

        let recommended = sceneDetected.recommendedPresets.first ?? .auto
        assistantMessage = "Detected: \(sceneDetected.rawValue). Try \(recommended.rawValue)?"

        announceVoice("I detect a \(sceneDetected.rawValue) scene. I recommend \(recommended.rawValue) mode.")
    }

    // =========================================================================
    // MARK: - Accessibility — Voice Guidance
    // =========================================================================

    private func announcePresetChange(_ preset: CreativePreset) {
        if voiceGuidanceEnabled || accessibilityMode == .voiceGuided || accessibilityMode == .fullAssist {
            announceVoice(preset.quickTip)
        }

        #if canImport(UIKit)
        // VoiceOver announcement
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(preset.rawValue) mode activated. \(preset.quickTip)"
        )
        #endif
    }

    /// Speak text for voice-guided mode
    private func announceVoice(_ text: String) {
        guard voiceGuidanceEnabled || accessibilityMode == .voiceGuided || accessibilityMode == .fullAssist else { return }

        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: text)
        #endif

        assistantMessage = text
    }

    /// Get full accessibility description of current camera state
    public func describeCurrentState() -> String {
        guard let camera = camera else { return "Camera not connected" }

        var desc = "Camera: \(camera.currentCamera.rawValue). "
        desc += "Resolution: \(camera.currentResolution.rawValue). "
        desc += "Frame rate: \(camera.currentFrameRate) FPS. "

        if camera.isCapturing {
            desc += "Capturing. "
        }

        desc += "Mode: \(activePreset.rawValue). "
        desc += "ISO: \(Int(camera.currentISO)). "

        let shutterFraction = 1.0 / camera.currentShutterSpeed.seconds
        if shutterFraction > 1 {
            desc += "Shutter: 1/\(Int(shutterFraction)). "
        } else {
            desc += "Shutter: \(String(format: "%.1f", camera.currentShutterSpeed.seconds)) seconds. "
        }

        desc += "Zoom: \(String(format: "%.1fx", camera.zoomFactor)). "

        if camera.isRecording {
            desc += "Recording: \(String(format: "%.0f", camera.recordingDuration)) seconds. "
        }

        if bioReactiveEnabled {
            desc += "Bio-reactive on. Coherence: \(Int(currentCoherence * 100))%. "
        }

        return desc
    }

    // =========================================================================
    // MARK: - Accessibility — Haptic Feedback
    // =========================================================================

    public enum HapticEvent {
        case preset
        case capture
        case focusLocked
        case breathSync
        case peakCoherence
        case sceneDetected
        case error
    }

    private func provideHapticFeedback(_ event: HapticEvent) {
        guard hapticFeedbackEnabled else { return }

        #if canImport(UIKit)
        switch event {
        case .preset:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .capture:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .focusLocked:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .breathSync:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        case .peakCoherence:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .sceneDetected:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        #endif
    }

    // =========================================================================
    // MARK: - Accessibility — Auto-Detect Needs
    // =========================================================================

    private func detectAccessibilityNeeds() {
        #if canImport(UIKit)
        if UIAccessibility.isVoiceOverRunning {
            accessibilityMode = .voiceGuided
            voiceGuidanceEnabled = true
            simplifiedUI = true
        } else if UIAccessibility.isSwitchControlRunning {
            accessibilityMode = .switchControl
            simplifiedUI = true
        } else if UIAccessibility.isReduceMotionEnabled {
            simplifiedUI = true
        }
        #endif
    }

    // =========================================================================
    // MARK: - Voice Commands (for voice-controlled camera)
    // =========================================================================

    /// Process a voice command string
    public func processVoiceCommand(_ command: String) {
        let lower = command.lowercased().trimmingCharacters(in: .whitespaces)

        // Photo/capture commands
        if lower.contains("photo") || lower.contains("capture") || lower.contains("shoot") || lower.contains("snap") || lower.contains("foto") || lower.contains("aufnahme") {
            Task {
                do {
                    _ = try await camera?.capturePhoto()
                    announceVoice("Photo captured")
                    provideHapticFeedback(.capture)
                } catch {
                    announceVoice("Photo capture failed")
                    provideHapticFeedback(.error)
                }
            }
            return
        }

        // Recording commands
        if lower.contains("record") || lower.contains("video") || lower.contains("aufnehmen") {
            if camera?.isRecording == true {
                camera?.stopRecording()
                announceVoice("Recording stopped")
            } else {
                _ = try? camera?.startRecording()
                announceVoice("Recording started")
            }
            return
        }

        // Zoom commands
        if lower.contains("zoom in") || lower.contains("closer") || lower.contains("naeher") || lower.contains("näher") {
            let newZoom = (camera?.zoomFactor ?? 1.0) * 1.5
            camera?.setZoom(newZoom, animated: true)
            announceVoice("Zooming in to \(String(format: "%.1f", newZoom))x")
            return
        }
        if lower.contains("zoom out") || lower.contains("wider") || lower.contains("weiter") {
            let newZoom = (camera?.zoomFactor ?? 1.0) / 1.5
            camera?.setZoom(newZoom, animated: true)
            announceVoice("Zooming out to \(String(format: "%.1f", newZoom))x")
            return
        }

        // Camera switch
        if lower.contains("selfie") || lower.contains("front") || lower.contains("vorne") {
            Task { try? await camera?.switchCamera(to: .front) }
            announceVoice("Switched to front camera")
            return
        }
        if lower.contains("back") || lower.contains("rear") || lower.contains("hinten") {
            Task { try? await camera?.switchCamera(to: .back) }
            announceVoice("Switched to back camera")
            return
        }
        if lower.contains("wide") || lower.contains("weit") {
            Task { try? await camera?.switchCamera(to: .ultraWide) }
            announceVoice("Switched to ultra wide camera")
            return
        }

        // Torch
        if lower.contains("light on") || lower.contains("torch") || lower.contains("licht an") || lower.contains("flash") {
            camera?.setTorchMode(.on)
            announceVoice("Torch on")
            return
        }
        if lower.contains("light off") || lower.contains("licht aus") {
            camera?.setTorchMode(.off)
            announceVoice("Torch off")
            return
        }

        // Preset commands — check all presets
        for preset in CreativePreset.allCases {
            if lower.contains(preset.rawValue.lowercased()) {
                applyPreset(preset)
                return
            }
        }

        // Describe state
        if lower.contains("describe") || lower.contains("status") || lower.contains("what") || lower.contains("was") || lower.contains("beschreib") {
            let state = describeCurrentState()
            announceVoice(state)
            return
        }

        // Help
        if lower.contains("help") || lower.contains("hilfe") {
            announceVoice("Available commands: Photo, Record, Zoom in, Zoom out, Selfie, Back camera, Wide, Light on, Light off, Describe. Or say a preset name like Long Exposure, Cinematic, Slow Motion.")
            return
        }

        announceVoice("I didn't understand. Say Help for available commands.")
    }
}
#endif // os(iOS) || os(macOS)

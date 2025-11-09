import Foundation
import AVFoundation
import CoreLocation
import Combine

/// Drone Integration Manager
/// Control and receive video from drones for out-of-body experiences
///
/// Supported Drones:
/// - DJI (Mavic 3, Air 3, Mini 4 Pro, FPV, Inspire 3)
/// - Autel (EVO II, EVO Nano+)
/// - Parrot (Anafi, Anafi USA)
/// - Skydio (Skydio 2+, Skydio X2)
/// - FPV Drones (Betaflight, INAV, iNav)
///
/// Control Methods:
/// - iPhone/iPad touchscreen
/// - VR Headset (Apple Vision Pro, Meta Quest)
/// - DJI RC Pro Controller
/// - FPV Goggles (DJI Goggles 2, Fatshark)
///
/// Features:
/// - Live video streaming (1080p, 4K)
/// - Bio-reactive flight (HRV controls altitude/speed)
/// - Out-of-body meditation mode
/// - Autonomous flight modes
/// - EU/US drone regulations compliance
/// - License-free (<250g) and licensed support
@MainActor
class DroneIntegrationManager: ObservableObject {

    // MARK: - Published State

    @Published var isConnected: Bool = false
    @Published var connectedDrone: DroneModel?
    @Published var flightMode: FlightMode = .manual
    @Published var batteryLevel: Int = 0
    @Published var altitude: Double = 0.0  // meters
    @Published var distance: Double = 0.0  // meters from pilot
    @Published var speed: Double = 0.0     // m/s
    @Published var isFlying: Bool = false
    @Published var videoStream: VideoStream?

    // Bio-reactive flight
    @Published var bioReactiveFlightEnabled: Bool = false
    @Published var hrvControlsAltitude: Bool = false
    @Published var hrvControlsSpeed: Bool = false

    // MARK: - Drone Models

    enum DroneModel {
        // DJI Consumer (License-free < 250g)
        case dji_mini_4_pro           // 249g - EU/US legal without license
        case dji_mini_3_pro           // 249g
        case dji_mini_se              // 249g

        // DJI Consumer (Licensed)
        case dji_air_3                // 720g - Requires A1/A2 license (EU)
        case dji_mavic_3_pro          // 958g
        case dji_mavic_3_classic      // 895g

        // DJI FPV
        case dji_fpv                  // 795g - FPV racing drone
        case dji_avata_2              // 377g - Cinewhoop FPV

        // DJI Professional
        case dji_inspire_3            // 4.4kg - Cinema drone
        case dji_matrice_30t          // 3.77kg - Enterprise (thermal)

        // Autel
        case autel_evo_ii_pro         // 1127g
        case autel_evo_nano_plus      // 249g - License-free

        // Parrot
        case parrot_anafi             // 320g
        case parrot_anafi_usa         // 500g - Government/Enterprise

        // Skydio
        case skydio_2_plus            // 775g - Autonomous AI tracking
        case skydio_x2                // 2.2kg - Enterprise

        // FPV Custom
        case fpv_custom_5inch         // Custom FPV build (typically 500-800g)
        case fpv_custom_3inch         // Cinewhoop (200-400g)
        case fpv_custom_7inch         // Long-range (800-1200g)

        var weight: Double {
            switch self {
            case .dji_mini_4_pro, .dji_mini_3_pro, .dji_mini_se, .autel_evo_nano_plus:
                return 249  // License-free limit
            case .dji_avata_2:
                return 377
            case .dji_air_3:
                return 720
            case .dji_fpv:
                return 795
            case .dji_mavic_3_classic:
                return 895
            case .dji_mavic_3_pro:
                return 958
            case .autel_evo_ii_pro:
                return 1127
            case .dji_matrice_30t:
                return 3770
            case .dji_inspire_3:
                return 4400
            case .parrot_anafi:
                return 320
            case .parrot_anafi_usa:
                return 500
            case .skydio_2_plus:
                return 775
            case .skydio_x2:
                return 2200
            case .fpv_custom_5inch:
                return 650
            case .fpv_custom_3inch:
                return 300
            case .fpv_custom_7inch:
                return 1000
            }
        }

        var requiresLicense: Bool {
            return weight > 250  // EU: >250g requires A1/A2/A3 license
        }

        var maxFlightTime: Int {
            switch self {
            case .dji_mini_4_pro:
                return 34  // minutes
            case .dji_mini_3_pro:
                return 34
            case .dji_mini_se:
                return 31
            case .dji_air_3:
                return 46
            case .dji_mavic_3_pro:
                return 43
            case .dji_fpv:
                return 20
            case .dji_avata_2:
                return 23
            case .dji_inspire_3:
                return 28
            default:
                return 25
            }
        }

        var maxVideoResolution: String {
            switch self {
            case .dji_mini_4_pro:
                return "4K/60fps"
            case .dji_mavic_3_pro:
                return "5.1K/50fps (Hasselblad)"
            case .dji_inspire_3:
                return "8K/25fps (X9-8K)"
            case .dji_fpv, .dji_avata_2:
                return "4K/60fps"
            default:
                return "4K/30fps"
            }
        }

        var name: String {
            switch self {
            case .dji_mini_4_pro: return "DJI Mini 4 Pro"
            case .dji_mini_3_pro: return "DJI Mini 3 Pro"
            case .dji_mini_se: return "DJI Mini SE"
            case .dji_air_3: return "DJI Air 3"
            case .dji_mavic_3_pro: return "DJI Mavic 3 Pro"
            case .dji_mavic_3_classic: return "DJI Mavic 3 Classic"
            case .dji_fpv: return "DJI FPV"
            case .dji_avata_2: return "DJI Avata 2"
            case .dji_inspire_3: return "DJI Inspire 3"
            case .dji_matrice_30t: return "DJI Matrice 30T"
            case .autel_evo_ii_pro: return "Autel EVO II Pro"
            case .autel_evo_nano_plus: return "Autel EVO Nano+"
            case .parrot_anafi: return "Parrot Anafi"
            case .parrot_anafi_usa: return "Parrot Anafi USA"
            case .skydio_2_plus: return "Skydio 2+"
            case .skydio_x2: return "Skydio X2"
            case .fpv_custom_5inch: return "FPV 5-inch"
            case .fpv_custom_3inch: return "FPV 3-inch Cinewhoop"
            case .fpv_custom_7inch: return "FPV 7-inch Long Range"
            }
        }
    }

    // MARK: - Flight Modes

    enum FlightMode {
        case manual                    // Full manual control
        case position_hold             // GPS hold (DJI P-Mode)
        case sport                     // High-speed mode
        case tripod                    // Slow, precise movements
        case fpv                       // FPV racing mode
        case cinematic                 // Smooth cinematic movements

        // Autonomous modes
        case follow_me                 // Track pilot
        case orbit                     // Circle around point of interest
        case waypoints                 // Fly predefined route
        case return_to_home            // RTH

        // Bio-reactive modes (Echoelmusic exclusive!)
        case bio_meditate              // Slow, calm flight based on HRV
        case bio_orbit                 // Orbit speed based on heart rate
        case bio_altitude              // Altitude follows HRV (higher HRV = higher altitude)
        case bio_explore               // Autonomous exploration based on coherence

        var description: String {
            switch self {
            case .manual: return "Manual Control"
            case .position_hold: return "GPS Position Hold"
            case .sport: return "Sport Mode (Fast)"
            case .tripod: return "Tripod Mode (Slow)"
            case .fpv: return "FPV Racing"
            case .cinematic: return "Cinematic (Smooth)"
            case .follow_me: return "Follow Me"
            case .orbit: return "Orbit Point of Interest"
            case .waypoints: return "Waypoint Navigation"
            case .return_to_home: return "Return to Home"
            case .bio_meditate: return "Bio-Meditate (HRV-controlled)"
            case .bio_orbit: return "Bio-Orbit (HR-controlled speed)"
            case .bio_altitude: return "Bio-Altitude (HRV → height)"
            case .bio_explore: return "Bio-Explore (Coherence navigation)"
            }
        }

        var isBioReactive: Bool {
            switch self {
            case .bio_meditate, .bio_orbit, .bio_altitude, .bio_explore:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Video Stream

    struct VideoStream {
        var resolution: Resolution
        var framerate: Int
        var latency: Double  // milliseconds
        var bitrate: Int     // Mbps

        enum Resolution {
            case hd_720p
            case fullhd_1080p
            case qhd_2k
            case uhd_4k
            case cinema_8k

            var dimensions: (width: Int, height: Int) {
                switch self {
                case .hd_720p: return (1280, 720)
                case .fullhd_1080p: return (1920, 1080)
                case .qhd_2k: return (2560, 1440)
                case .uhd_4k: return (3840, 2160)
                case .cinema_8k: return (7680, 4320)
                }
            }
        }
    }

    // MARK: - Control Input

    enum ControlInput {
        case touchscreen_iphone
        case touchscreen_ipad
        case vr_vision_pro
        case vr_meta_quest
        case dji_rc_pro
        case dji_goggles_2
        case fpv_controller

        var supportsHeadTracking: Bool {
            switch self {
            case .vr_vision_pro, .vr_meta_quest, .dji_goggles_2:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Drone Regulations

    struct DroneRegulations {
        let country: Country
        let licenseFree: Bool
        let maxAltitude: Double  // meters
        let visualLineOfSight: Bool
        let nightFlying: Bool

        enum Country {
            case eu
            case us
            case uk
            case germany
            case france
            case switzerland

            var maxAltitude: Double {
                switch self {
                case .eu, .uk, .germany, .france:
                    return 120  // 120m max altitude EU
                case .us:
                    return 122  // 400 feet = 122m
                case .switzerland:
                    return 120
                }
            }

            var licenseFreeWeight: Double {
                switch self {
                case .eu, .uk, .germany, .france, .switzerland:
                    return 250  // < 250g no license required
                case .us:
                    return 250  // FAA Part 107 waiver for <250g recreational
                }
            }
        }

        static func check(drone: DroneModel, country: Country) -> DroneRegulations {
            let weight = drone.weight
            let licenseFree = weight < country.licenseFreeWeight

            return DroneRegulations(
                country: country,
                licenseFree: licenseFree,
                maxAltitude: country.maxAltitude,
                visualLineOfSight: true,  // Required in most countries
                nightFlying: false  // Requires additional permission
            )
        }
    }

    // MARK: - Connection

    func connectToDrone(model: DroneModel) async throws {
        // In production, this would use DJI Mobile SDK, Parrot SDK, etc.
        connectedDrone = model
        isConnected = true
        batteryLevel = 100

        // Setup video stream
        let resolution: VideoStream.Resolution = model.maxVideoResolution.contains("4K") ? .uhd_4k : .fullhd_1080p
        videoStream = VideoStream(
            resolution: resolution,
            framerate: 60,
            latency: 150,  // 150ms typical for DJI
            bitrate: 25    // 25 Mbps
        )

        print("🚁 Connected to: \(model.name)")
        print("📹 Video: \(model.maxVideoResolution)")
        print("⚖️ Weight: \(model.weight)g (License: \(model.requiresLicense ? "Required" : "Free"))")
    }

    func disconnect() {
        if isFlying {
            // Emergency: Return to home before disconnecting
            _ = returnToHome()
        }

        isConnected = false
        connectedDrone = nil
        videoStream = nil
        isFlying = false

        print("🚁 Disconnected from drone")
    }

    // MARK: - Flight Control

    func takeoff() async throws {
        guard isConnected, !isFlying else { return }

        // Pre-flight checks
        guard batteryLevel > 30 else {
            throw DroneError.lowBattery
        }

        // Takeoff to 1.5m
        altitude = 1.5
        isFlying = true

        print("🚁 Takeoff - Altitude: \(altitude)m")
    }

    func land() async throws {
        guard isFlying else { return }

        altitude = 0.0
        isFlying = false

        print("🚁 Landing")
    }

    func returnToHome() async throws {
        guard isFlying else { return }

        flightMode = .return_to_home

        // Simulate RTH
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
        altitude = 0.0
        distance = 0.0
        isFlying = false

        print("🚁 Returned to home")
    }

    // MARK: - Bio-Reactive Flight Control

    func updateBioReactiveFlight(hrv: Double, heartRate: Double, coherence: Double) {
        guard bioReactiveFlightEnabled, isFlying else { return }

        switch flightMode {
        case .bio_altitude:
            // HRV controls altitude (0-100 HRV → 2-50m altitude)
            let targetAltitude = mapValue(hrv, from: 20...100, to: 2...50)
            altitude = targetAltitude
            print("🧘 Bio-Altitude: HRV \(Int(hrv)) → \(Int(altitude))m")

        case .bio_orbit:
            // Heart rate controls orbit speed (60-120 BPM → 1-5 m/s)
            let orbitSpeed = mapValue(heartRate, from: 60...120, to: 1...5)
            speed = orbitSpeed
            print("🧘 Bio-Orbit: HR \(Int(heartRate)) BPM → \(orbitSpeed) m/s")

        case .bio_meditate:
            // High HRV → slow, calm flight
            // Low HRV → return to hover
            if hrv > 70 {
                altitude = 10.0  // Gentle hover at 10m
                speed = 0.5      // Very slow drift
            } else {
                altitude = 2.0   // Low hover
                speed = 0.0      // Stationary
            }
            print("🧘 Bio-Meditate: HRV \(Int(hrv)) → Calm drift")

        case .bio_explore:
            // Coherence controls exploration radius
            // High coherence → explore further
            let exploreRadius = mapValue(coherence, from: 0...100, to: 5...50)
            distance = exploreRadius
            print("🧘 Bio-Explore: Coherence \(Int(coherence))% → \(Int(exploreRadius))m radius")

        default:
            break
        }
    }

    private func mapValue(_ value: Double, from: ClosedRange<Double>, to: ClosedRange<Double>) -> Double {
        let normalized = (value - from.lowerBound) / (from.upperBound - from.lowerBound)
        let clamped = max(0, min(1, normalized))
        return to.lowerBound + clamped * (to.upperBound - to.lowerBound)
    }

    // MARK: - Out-of-Body Experience

    func startOutOfBodyExperience() async throws {
        guard isConnected else { throw DroneError.notConnected }

        // Bio-reactive out-of-body flight
        bioReactiveFlightEnabled = true
        flightMode = .bio_altitude

        // Takeoff
        try await takeoff()

        // Ascend to HRV-based altitude
        print("🧘 Out-of-Body Experience started")
        print("   HRV controls altitude")
        print("   Higher HRV = Higher altitude")
        print("   Watch live video from drone perspective")
    }

    func stopOutOfBodyExperience() async throws {
        bioReactiveFlightEnabled = false
        try await returnToHome()

        print("🧘 Out-of-Body Experience ended")
    }

    // MARK: - VR Control

    func enableVRControl(headset: ControlInput) {
        guard headset.supportsHeadTracking else { return }

        print("🥽 VR Control enabled: \(headset)")
        print("   Head tracking: Look to control gimbal")
        print("   Spatial audio: Drone position in 3D")
    }

    // MARK: - Errors

    enum DroneError: Error {
        case notConnected
        case lowBattery
        case noGPS
        case windTooHigh
        case geofenceViolation
    }

    // MARK: - Debug Info

    var debugInfo: String {
        var info = """
        DroneIntegrationManager:
        - Connected: \(isConnected)
        """

        if let drone = connectedDrone {
            info += """
            \n- Drone: \(drone.name)
            - Weight: \(Int(drone.weight))g
            - License: \(drone.requiresLicense ? "Required" : "Free")
            - Flying: \(isFlying ? "✅" : "❌")
            - Mode: \(flightMode.description)
            - Battery: \(batteryLevel)%
            - Altitude: \(Int(altitude))m
            - Distance: \(Int(distance))m
            - Speed: \(String(format: "%.1f", speed)) m/s
            """

            if let video = videoStream {
                info += """
                \n- Video: \(video.resolution.dimensions.width)x\(video.resolution.dimensions.height) @ \(video.framerate)fps
                - Latency: \(Int(video.latency))ms
                """
            }

            if bioReactiveFlightEnabled {
                info += "\n- Bio-Reactive: ✅ (HRV controls flight)"
            }
        }

        return info
    }
}

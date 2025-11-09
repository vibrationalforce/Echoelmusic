import Foundation
import AVFoundation
import CoreAudioTypes

/// Professional Venue Audio Manager
/// Supports cinema, club, and theater sound systems
///
/// Venue Types:
/// - Cinema (Dolby Atmos Cinema, IMAX, DTS:X Pro)
/// - Clubs & Live Music (Line Arrays, DJ Systems)
/// - Theater (Musical, Opera, Orchestra)
/// - Festival (Multi-stage, Delay Towers)
/// - Stadium (Large-scale PA systems)
///
/// Professional Protocols:
/// - Dante (Audio over IP)
/// - AES67 (RAVENNA)
/// - MADI (Multichannel Audio Digital Interface)
/// - AES/EBU (Professional Digital Audio)
/// - SMPTE Timecode Sync
/// - MIDI Show Control (MSC)
/// - OSC (Open Sound Control)
/// - Ableton Link (Tempo Sync)
@MainActor
class ProfessionalVenueAudioManager: ObservableObject {

    // MARK: - Published State

    @Published var currentVenue: VenueType = .studio
    @Published var outputProtocol: OutputProtocol = .coreAudio
    @Published var speakerConfig: SpeakerConfiguration?
    @Published var isConnected: Bool = false

    // MARK: - Venue Types

    enum VenueType {
        // Small Venues
        case studio
        case rehearsal_room
        case small_club

        // Medium Venues
        case cinema
        case theater
        case concert_hall
        case nightclub

        // Large Venues
        case festival_stage
        case arena
        case stadium
        case imax_cinema

        // Special Venues
        case planetarium
        case immersive_dome
        case outdoor_amphitheater

        var typicalSpeakerCount: ClosedRange<Int> {
            switch self {
            case .studio: return 2...8
            case .rehearsal_room: return 2...4
            case .small_club: return 4...16
            case .cinema: return 12...64
            case .theater: return 16...128
            case .concert_hall: return 32...256
            case .nightclub: return 16...64
            case .festival_stage: return 64...512
            case .arena: return 128...1024
            case .stadium: return 256...2048
            case .imax_cinema: return 64...128
            case .planetarium: return 32...128
            case .immersive_dome: return 64...256
            case .outdoor_amphitheater: return 32...256
            }
        }

        var recommendedFormat: String {
            switch self {
            case .cinema, .imax_cinema:
                return "Dolby Atmos Cinema (64+ speakers)"
            case .theater:
                return "Theater Surround + Wireless Mics"
            case .nightclub, .festival_stage, .arena, .stadium:
                return "Line Array + Sub Array + Delays"
            case .concert_hall:
                return "Orchestral Reinforcement"
            case .planetarium, .immersive_dome:
                return "Dome Ambisonics (32+ channels)"
            default:
                return "Multi-channel Surround"
            }
        }
    }

    // MARK: - Output Protocols

    enum OutputProtocol {
        case coreAudio              // macOS/iOS native
        case dante                  // Audio over IP (industry standard)
        case aes67                  // RAVENNA / AES67 standard
        case madi                   // Multichannel Audio Digital Interface
        case adat                   // Alesis Digital Audio Tape
        case aes_ebu                // Professional digital audio
        case smpte_st2110           // Professional IP media
        case avb                    // Audio Video Bridging
        case cobraNet               // Legacy audio networking
        case qlabOSC                // QLab theater control
        case midiShowControl        // MSC for automation
        case abletonLink            // Tempo sync

        var maxChannels: Int {
            switch self {
            case .coreAudio: return 128
            case .dante: return 512        // Dante supports 512x512
            case .aes67: return 512
            case .madi: return 64          // MADI supports 64 channels
            case .adat: return 8           // 8 channels per ADAT
            case .aes_ebu: return 2        // 2 channels per AES/EBU
            case .smpte_st2110: return 512
            case .avb: return 256
            case .cobraNet: return 64
            case .qlabOSC: return 128
            case .midiShowControl: return 128
            case .abletonLink: return 128
            }
        }

        var latency: String {
            switch self {
            case .coreAudio: return "2-10 ms"
            case .dante: return "< 1 ms (with PTP)"
            case .aes67: return "< 1 ms"
            case .madi: return "< 0.5 ms"
            case .adat: return "< 1 ms"
            case .aes_ebu: return "< 0.1 ms"
            case .smpte_st2110: return "< 1 ms"
            case .avb: return "< 2 ms"
            case .cobraNet: return "5-7 ms"
            case .qlabOSC: return "Variable"
            case .midiShowControl: return "Variable"
            case .abletonLink: return "< 10 ms"
            }
        }

        var isProfessional: Bool {
            switch self {
            case .coreAudio: return false
            default: return true
            }
        }
    }

    // MARK: - Speaker Configurations

    struct SpeakerConfiguration {
        var type: ConfigurationType
        var speakerCount: Int
        var zones: [SpeakerZone]
        var delays: [DelaySettings]

        enum ConfigurationType {
            // Cinema
            case dolbyAtmosCinema       // 7.1.4 to 64+ speakers
            case imaxEnhanced           // IMAX 12-channel
            case dtsXPro                // DTS:X Pro
            case auro3D                 // Auro 3D (11.1, 13.1)

            // Club / Live
            case lineArray              // L/R line arrays + subs
            case pointSource            // Traditional PA
            case distributedPA          // Multiple zones
            case djBooth                // DJ monitoring + main PA

            // Theater
            case musicalTheater         // Broadway-style
            case operaHouse             // Opera with orchestra
            case orchestralReinforcement // Subtle classical amplification
            case immersiveTheater       // 360° theater

            // Festival / Large
            case festivalMain           // Main stage + delays
            case multiStage             // Multiple stages with sync
            case stadium                // Large-scale with delay towers
            case outdoor                // Weather-resistant outdoor

            // Special
            case domeAmbisonics         // Planetarium / Dome
            case wavefieldSynthesis     // WFS (192+ speakers)
            case objectBased            // Custom object-based (like Atmos)
        }
    }

    struct SpeakerZone {
        var name: String
        var speakers: [SpeakerPosition]
        var delay: Double = 0.0  // In milliseconds
        var gain: Float = 1.0

        enum ZoneType {
            case main               // Main PA
            case fill              // Fill speakers
            case delay             // Delay towers
            case surround          // Surround speakers
            case height            // Height/ceiling speakers
            case subwoofer         // LFE/Subs
            case frontFill         // Front fill (near stage)
            case underBalcony      // Under balcony fill
        }
    }

    struct SpeakerPosition {
        var id: String
        var position: SIMD3<Float>  // X, Y, Z in meters
        var type: SpeakerType
        var channel: Int?

        enum SpeakerType {
            case fullRange
            case midHigh
            case subwoofer
            case lineArrayElement
            case pointSource
        }
    }

    struct DelaySettings {
        var zoneName: String
        var delayMs: Double
        var reason: String  // e.g., "Distance compensation", "Sync with video"

        static func calculate(distance: Double, speedOfSound: Double = 343.0) -> Double {
            // Calculate delay in milliseconds based on distance
            return (distance / speedOfSound) * 1000.0
        }
    }

    // MARK: - Cinema Systems

    func configureDolbyAtmosCinema(speakers: Int = 64) {
        let config = SpeakerConfiguration(
            type: .dolbyAtmosCinema,
            speakerCount: speakers,
            zones: [
                // Screen channels
                SpeakerZone(
                    name: "Screen Array",
                    speakers: createScreenArray(),
                    delay: 0.0,
                    gain: 1.0
                ),
                // Surround array
                SpeakerZone(
                    name: "Surround Array",
                    speakers: createSurroundArray(count: 32),
                    delay: 0.0,
                    gain: 0.9
                ),
                // Ceiling array
                SpeakerZone(
                    name: "Ceiling Array",
                    speakers: createCeilingArray(count: 16),
                    delay: 0.0,
                    gain: 0.85
                ),
                // Subwoofers
                SpeakerZone(
                    name: "Subwoofer Array",
                    speakers: createSubArray(count: 8),
                    delay: 0.0,
                    gain: 1.0
                )
            ],
            delays: []
        )

        speakerConfig = config
        currentVenue = .cinema
        print("🎬 Dolby Atmos Cinema configured: \(speakers) speakers")
    }

    func configureIMAX(enhanced: Bool = true) {
        // IMAX uses 12-channel proprietary format
        let channels = enhanced ? 12 : 6

        let config = SpeakerConfiguration(
            type: .imaxEnhanced,
            speakerCount: channels,
            zones: [
                SpeakerZone(
                    name: "IMAX Array",
                    speakers: createIMAXArray(channels: channels),
                    delay: 0.0,
                    gain: 1.0
                )
            ],
            delays: []
        )

        speakerConfig = config
        currentVenue = .imax_cinema
        print("🎬 IMAX Enhanced configured: \(channels) channels")
    }

    // MARK: - Club / Live Systems

    func configureLineArray(leftCount: Int = 12, rightCount: Int = 12, subs: Int = 8) {
        let config = SpeakerConfiguration(
            type: .lineArray,
            speakerCount: leftCount + rightCount + subs,
            zones: [
                // Left array
                SpeakerZone(
                    name: "Left Array",
                    speakers: createLineArray(count: leftCount, side: .left),
                    delay: 0.0,
                    gain: 1.0
                ),
                // Right array
                SpeakerZone(
                    name: "Right Array",
                    speakers: createLineArray(count: rightCount, side: .right),
                    delay: 0.0,
                    gain: 1.0
                ),
                // Sub array (center)
                SpeakerZone(
                    name: "Subwoofer Array",
                    speakers: createSubArray(count: subs),
                    delay: 0.0,
                    gain: 1.2
                )
            ],
            delays: []
        )

        speakerConfig = config
        currentVenue = .nightclub
        print("🎵 Line Array configured: L\(leftCount) + R\(rightCount) + \(subs) subs")
    }

    func configureFestivalStage(mainPA: Int = 32, delays: [(distance: Double, speakers: Int)] = [(50, 8), (100, 8)]) {
        var zones: [SpeakerZone] = []

        // Main PA
        zones.append(SpeakerZone(
            name: "Main PA",
            speakers: createLineArray(count: mainPA / 2, side: .left) +
                      createLineArray(count: mainPA / 2, side: .right),
            delay: 0.0,
            gain: 1.0
        ))

        // Delay towers
        var delaySettings: [DelaySettings] = []
        for (index, delayTower) in delays.enumerated() {
            let delayMs = DelaySettings.calculate(distance: delayTower.distance)
            let zoneName = "Delay Tower \(index + 1)"

            zones.append(SpeakerZone(
                name: zoneName,
                speakers: createDelayTower(count: delayTower.speakers, distance: delayTower.distance),
                delay: delayMs,
                gain: 0.8
            ))

            delaySettings.append(DelaySettings(
                zoneName: zoneName,
                delayMs: delayMs,
                reason: "Distance: \(delayTower.distance)m"
            ))
        }

        let config = SpeakerConfiguration(
            type: .festivalMain,
            speakerCount: mainPA + delays.reduce(0) { $0 + $1.speakers },
            zones: zones,
            delays: delaySettings
        )

        speakerConfig = config
        currentVenue = .festival_stage
        print("🎪 Festival Stage configured: \(mainPA) main + \(delays.count) delay towers")
    }

    // MARK: - Theater Systems

    func configureMusicalTheater(surrounds: Int = 16, heights: Int = 8) {
        let config = SpeakerConfiguration(
            type: .musicalTheater,
            speakerCount: surrounds + heights + 8,  // + screen channels + subs
            zones: [
                // Proscenium (stage speakers)
                SpeakerZone(
                    name: "Proscenium",
                    speakers: createTheaterScreen(),
                    delay: 0.0,
                    gain: 1.0
                ),
                // Surround array
                SpeakerZone(
                    name: "Audience Surround",
                    speakers: createTheaterSurrounds(count: surrounds),
                    delay: 0.0,
                    gain: 0.85
                ),
                // Heights
                SpeakerZone(
                    name: "Ceiling Heights",
                    speakers: createTheaterHeights(count: heights),
                    delay: 0.0,
                    gain: 0.8
                ),
                // Subs
                SpeakerZone(
                    name: "Subwoofers",
                    speakers: createSubArray(count: 4),
                    delay: 0.0,
                    gain: 1.0
                )
            ],
            delays: []
        )

        speakerConfig = config
        currentVenue = .theater
        print("🎭 Musical Theater configured: \(surrounds) surrounds + \(heights) heights")
    }

    // MARK: - Special Venues

    func configureDomeAmbisonics(order: Int = 3) {
        // Ambisonics order determines speaker count
        // 1st order = 4 speakers
        // 2nd order = 9 speakers
        // 3rd order = 16 speakers
        // 4th order = 25 speakers
        let speakerCount = (order + 1) * (order + 1)

        let config = SpeakerConfiguration(
            type: .domeAmbisonics,
            speakerCount: speakerCount,
            zones: [
                SpeakerZone(
                    name: "Dome Array",
                    speakers: createDomeArray(count: speakerCount),
                    delay: 0.0,
                    gain: 1.0
                )
            ],
            delays: []
        )

        speakerConfig = config
        currentVenue = .planetarium
        print("🌌 Dome Ambisonics configured: Order \(order) = \(speakerCount) speakers")
    }

    // MARK: - Helper Functions for Speaker Creation

    private func createScreenArray() -> [SpeakerPosition] {
        // Cinema screen array (L, C, R + surrounds)
        [
            SpeakerPosition(id: "L", position: SIMD3(-5, 2, 10), type: .fullRange, channel: 0),
            SpeakerPosition(id: "C", position: SIMD3(0, 2, 10), type: .fullRange, channel: 1),
            SpeakerPosition(id: "R", position: SIMD3(5, 2, 10), type: .fullRange, channel: 2),
        ]
    }

    private func createSurroundArray(count: Int) -> [SpeakerPosition] {
        var speakers: [SpeakerPosition] = []
        for i in 0..<count {
            let angle = (2.0 * .pi * Float(i)) / Float(count)
            let x = 10.0 * cos(angle)
            let z = 10.0 * sin(angle)
            speakers.append(SpeakerPosition(
                id: "Surr\(i)",
                position: SIMD3(x, 2, z),
                type: .fullRange,
                channel: i + 3
            ))
        }
        return speakers
    }

    private func createCeilingArray(count: Int) -> [SpeakerPosition] {
        var speakers: [SpeakerPosition] = []
        let gridSize = Int(sqrt(Double(count)))
        var index = 0
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = Float(col - gridSize / 2) * 3.0
                let z = Float(row - gridSize / 2) * 3.0
                speakers.append(SpeakerPosition(
                    id: "Ceil\(index)",
                    position: SIMD3(x, 5, z),
                    type: .fullRange,
                    channel: 35 + index
                ))
                index += 1
                if index >= count { break }
            }
            if index >= count { break }
        }
        return speakers
    }

    private func createSubArray(count: Int) -> [SpeakerPosition] {
        var speakers: [SpeakerPosition] = []
        for i in 0..<count {
            speakers.append(SpeakerPosition(
                id: "Sub\(i)",
                position: SIMD3(Float(i - count / 2) * 2, 0, 0),
                type: .subwoofer,
                channel: nil  // Summed LFE
            ))
        }
        return speakers
    }

    private func createIMAXArray(channels: Int) -> [SpeakerPosition] {
        // IMAX proprietary array (simplified)
        var speakers: [SpeakerPosition] = []
        // Screen channels
        speakers.append(contentsOf: createScreenArray())
        // Additional IMAX surrounds
        for i in 0..<(channels - 3) {
            speakers.append(SpeakerPosition(
                id: "IMAX\(i)",
                position: SIMD3(Float(i) * 2, 2, -5),
                type: .fullRange,
                channel: i + 3
            ))
        }
        return speakers
    }

    private func createLineArray(count: Int, side: Side) -> [SpeakerPosition] {
        enum Side { case left, right }
        var speakers: [SpeakerPosition] = []
        let xPos: Float = side == .left ? -8.0 : 8.0

        for i in 0..<count {
            let yPos = 5.0 - (Float(i) * 0.3)  // Curved downward
            speakers.append(SpeakerPosition(
                id: "\(side == .left ? "L" : "R")Array\(i)",
                position: SIMD3(xPos, yPos, 5),
                type: .lineArrayElement,
                channel: i
            ))
        }
        return speakers
    }

    private func createDelayTower(count: Int, distance: Double) -> [SpeakerPosition] {
        var speakers: [SpeakerPosition] = []
        for i in 0..<count {
            speakers.append(SpeakerPosition(
                id: "Delay\(i)",
                position: SIMD3(0, 4, Float(-distance)),
                type: .fullRange,
                channel: nil
            ))
        }
        return speakers
    }

    private func createTheaterScreen() -> [SpeakerPosition] {
        // Theater proscenium speakers
        createScreenArray()
    }

    private func createTheaterSurrounds(count: Int) -> [SpeakerPosition] {
        createSurroundArray(count: count)
    }

    private func createTheaterHeights(count: Int) -> [SpeakerPosition] {
        createCeilingArray(count: count)
    }

    private func createDomeArray(count: Int) -> [SpeakerPosition] {
        var speakers: [SpeakerPosition] = []
        // Fibonacci sphere distribution for dome
        let goldenRatio: Float = (1.0 + sqrt(5.0)) / 2.0
        for i in 0..<count {
            let t = Float(i) / Float(count)
            let theta = 2.0 * Float.pi * Float(i) / goldenRatio
            let phi = acos(1.0 - 2.0 * t)

            let radius: Float = 10.0
            let x = radius * sin(phi) * cos(theta)
            let y = radius * cos(phi)
            let z = radius * sin(phi) * sin(theta)

            speakers.append(SpeakerPosition(
                id: "Dome\(i)",
                position: SIMD3(x, y, z),
                type: .fullRange,
                channel: i
            ))
        }
        return speakers
    }

    // MARK: - Connection Methods

    func connectDante(ipAddress: String, channels: Int = 64) async throws {
        // In production, this would connect to Dante network
        outputProtocol = .dante
        isConnected = true
        print("🌐 Connected to Dante: \(ipAddress) (\(channels) channels)")
    }

    func connectMADI(device: String) async throws {
        // In production, this would connect to MADI interface
        outputProtocol = .madi
        isConnected = true
        print("🔌 Connected to MADI: \(device)")
    }

    func connectQLab(oscPort: Int = 53000) async throws {
        // In production, this would connect to QLab via OSC
        outputProtocol = .qlabOSC
        isConnected = true
        print("🎭 Connected to QLab on port \(oscPort)")
    }

    func connectAbletonLink() async throws {
        // In production, this would sync via Ableton Link
        outputProtocol = .abletonLink
        isConnected = true
        print("🎹 Connected to Ableton Link")
    }

    // MARK: - Debug Info

    var debugInfo: String {
        var info = """
        ProfessionalVenueAudioManager:
        - Venue: \(currentVenue)
        - Protocol: \(outputProtocol)
        - Connected: \(isConnected)
        """

        if let config = speakerConfig {
            info += """
            \n- Config: \(config.type)
            - Speakers: \(config.speakerCount)
            - Zones: \(config.zones.count)
            - Delays: \(config.delays.count)
            """
        }

        return info
    }
}

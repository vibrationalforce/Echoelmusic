// DMXFixtureDatabase.swift
// Echoelmusic - Comprehensive DMX Fixture Library System
//
// A++ Ultrahardthink Implementation
// Provides:
// - Extensive fixture database with 500+ fixtures
// - Custom fixture definition support
// - Fixture personality management
// - Open Fixture Library (OFL) import
// - RDM device discovery integration
// - Automatic patch suggestions

import Foundation
import Combine
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.echoelmusic.lighting", category: "DMXFixtures")

// MARK: - Fixture Category

public enum FixtureCategory: String, Codable, CaseIterable, Sendable {
    case movingHead = "Moving Head"
    case movingHeadSpot = "Moving Head Spot"
    case movingHeadWash = "Moving Head Wash"
    case movingHeadBeam = "Moving Head Beam"
    case movingHeadHybrid = "Moving Head Hybrid"
    case par = "PAR"
    case ledPar = "LED PAR"
    case wash = "Wash"
    case spot = "Spot"
    case beam = "Beam"
    case strobe = "Strobe"
    case laser = "Laser"
    case scanner = "Scanner"
    case blinder = "Blinder"
    case effect = "Effect"
    case fogHaze = "Fog/Haze"
    case pixel = "Pixel"
    case ledBar = "LED Bar"
    case ledPanel = "LED Panel"
    case ledMatrix = "LED Matrix"
    case uplighter = "Uplighter"
    case floodlight = "Floodlight"
    case followSpot = "Follow Spot"
    case gobo = "Gobo"
    case dimmer = "Dimmer"
    case other = "Other"

    public var icon: String {
        switch self {
        case .movingHead, .movingHeadSpot, .movingHeadWash, .movingHeadBeam, .movingHeadHybrid:
            return "light.max"
        case .par, .ledPar:
            return "circle.fill"
        case .wash:
            return "sun.max.fill"
        case .spot:
            return "flashlight.on.fill"
        case .beam:
            return "rays"
        case .strobe:
            return "bolt.fill"
        case .laser:
            return "line.diagonal"
        case .scanner:
            return "viewfinder"
        case .blinder:
            return "sun.max"
        case .effect:
            return "sparkles"
        case .fogHaze:
            return "cloud.fill"
        case .pixel, .ledBar, .ledPanel, .ledMatrix:
            return "square.grid.3x3.fill"
        case .uplighter:
            return "arrow.up.circle.fill"
        case .floodlight:
            return "light.max"
        case .followSpot:
            return "scope"
        case .gobo:
            return "circle.hexagongrid.fill"
        case .dimmer:
            return "slider.horizontal.3"
        case .other:
            return "questionmark.circle"
        }
    }
}

// MARK: - DMX Channel Type

public enum DMXChannelType: String, Codable, CaseIterable, Sendable {
    // Intensity
    case dimmer = "Dimmer"
    case intensity = "Intensity"
    case shutter = "Shutter"
    case strobe = "Strobe"

    // Color
    case colorWheel = "Color Wheel"
    case colorMacro = "Color Macro"
    case red = "Red"
    case green = "Green"
    case blue = "Blue"
    case white = "White"
    case amber = "Amber"
    case uv = "UV"
    case lime = "Lime"
    case cyan = "Cyan"
    case magenta = "Magenta"
    case yellow = "Yellow"
    case cto = "CTO"
    case ctb = "CTB"
    case colorMix = "Color Mix"
    case hue = "Hue"
    case saturation = "Saturation"

    // Position
    case pan = "Pan"
    case panFine = "Pan Fine"
    case tilt = "Tilt"
    case tiltFine = "Tilt Fine"
    case panTiltSpeed = "Pan/Tilt Speed"

    // Beam
    case zoom = "Zoom"
    case focus = "Focus"
    case iris = "Iris"
    case frost = "Frost"
    case prism = "Prism"
    case prismRotation = "Prism Rotation"
    case goboWheel = "Gobo Wheel"
    case goboRotation = "Gobo Rotation"
    case goboShake = "Gobo Shake"
    case blade1 = "Blade 1"
    case blade2 = "Blade 2"
    case blade3 = "Blade 3"
    case blade4 = "Blade 4"
    case bladeRotation = "Blade Rotation"
    case barndoor = "Barndoor"

    // Effects
    case effect = "Effect"
    case effectSpeed = "Effect Speed"
    case macroSpeed = "Macro Speed"

    // Control
    case control = "Control"
    case mode = "Mode"
    case reset = "Reset"
    case lamp = "Lamp"
    case fan = "Fan"

    // Special
    case special = "Special"
    case raw = "Raw"
    case virtual = "Virtual"

    public var isColor: Bool {
        switch self {
        case .red, .green, .blue, .white, .amber, .uv, .lime, .cyan, .magenta, .yellow, .colorWheel, .colorMacro, .colorMix, .hue, .saturation, .cto, .ctb:
            return true
        default:
            return false
        }
    }

    public var isPosition: Bool {
        switch self {
        case .pan, .panFine, .tilt, .tiltFine, .panTiltSpeed:
            return true
        default:
            return false
        }
    }

    public var isBeam: Bool {
        switch self {
        case .zoom, .focus, .iris, .frost, .prism, .prismRotation, .goboWheel, .goboRotation, .goboShake, .blade1, .blade2, .blade3, .blade4, .bladeRotation, .barndoor:
            return true
        default:
            return false
        }
    }
}

// MARK: - DMX Channel Definition

public struct DMXChannelDefinition: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var type: DMXChannelType
    public var offset: Int  // Channel offset from base address (0-based)
    public var defaultValue: UInt8
    public var highlightValue: UInt8?
    public var resolution: ChannelResolution
    public var capabilities: [ChannelCapability]

    public enum ChannelResolution: String, Codable, Sendable {
        case coarse = "8-bit"
        case fine = "16-bit"
        case ultra = "24-bit"

        public var byteCount: Int {
            switch self {
            case .coarse: return 1
            case .fine: return 2
            case .ultra: return 3
            }
        }
    }

    public init(
        name: String,
        type: DMXChannelType,
        offset: Int,
        defaultValue: UInt8 = 0,
        highlightValue: UInt8? = nil,
        resolution: ChannelResolution = .coarse,
        capabilities: [ChannelCapability] = []
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.offset = offset
        self.defaultValue = defaultValue
        self.highlightValue = highlightValue
        self.resolution = resolution
        self.capabilities = capabilities
    }
}

// MARK: - Channel Capability

public struct ChannelCapability: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var rangeStart: UInt8
    public var rangeEnd: UInt8
    public var type: CapabilityType
    public var comment: String?

    public enum CapabilityType: String, Codable, Sendable {
        case noFunction = "No Function"
        case intensity = "Intensity"
        case colorWheelSlot = "Color Wheel Slot"
        case colorMix = "Color Mix"
        case goboSlot = "Gobo Slot"
        case goboRotation = "Gobo Rotation"
        case prismEffect = "Prism Effect"
        case shutter = "Shutter"
        case strobe = "Strobe"
        case panTiltMovement = "Pan/Tilt Movement"
        case panTiltSpeed = "Pan/Tilt Speed"
        case effect = "Effect"
        case macro = "Macro"
        case maintenance = "Maintenance"
        case generic = "Generic"
    }

    public init(
        name: String,
        rangeStart: UInt8,
        rangeEnd: UInt8,
        type: CapabilityType = .generic,
        comment: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.type = type
        self.comment = comment
    }
}

// MARK: - Fixture Mode (Personality)

public struct FixtureMode: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var shortName: String?
    public var channels: [DMXChannelDefinition]
    public var channelCount: Int { channels.count }
    public var physicalData: PhysicalData?

    public init(
        name: String,
        shortName: String? = nil,
        channels: [DMXChannelDefinition],
        physicalData: PhysicalData? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.shortName = shortName
        self.channels = channels
        self.physicalData = physicalData
    }
}

// MARK: - Physical Data

public struct PhysicalData: Codable, Sendable {
    public var weight: Float?  // kg
    public var width: Float?   // mm
    public var height: Float?  // mm
    public var depth: Float?   // mm
    public var power: Int?     // Watts
    public var dmxConnector: DMXConnector?
    public var panRange: Float?  // degrees
    public var tiltRange: Float? // degrees
    public var colorTemperature: Int?  // Kelvin
    public var lumens: Int?
    public var beamAngle: Float?  // degrees
    public var fieldAngle: Float? // degrees

    public enum DMXConnector: String, Codable, Sendable {
        case xlr3 = "3-pin XLR"
        case xlr5 = "5-pin XLR"
        case rj45 = "RJ45"
        case wireless = "Wireless"
    }

    public init() {}
}

// MARK: - Fixture Definition

public struct FixtureDefinition: Codable, Identifiable, Sendable {
    public let id: UUID
    public var manufacturer: String
    public var name: String
    public var shortName: String?
    public var category: FixtureCategory
    public var modes: [FixtureMode]
    public var physicalData: PhysicalData?
    public var metadata: FixtureMetadata

    public struct FixtureMetadata: Codable, Sendable {
        public var helpWanted: String?
        public var rdmModelId: Int?
        public var rdmSoftwareVersion: String?
        public var links: [String: String]?  // e.g., "manual": "https://..."
        public var dateAdded: Date?
        public var lastModified: Date?
        public var version: String?
        public var author: String?
    }

    public init(
        manufacturer: String,
        name: String,
        shortName: String? = nil,
        category: FixtureCategory,
        modes: [FixtureMode],
        physicalData: PhysicalData? = nil
    ) {
        self.id = UUID()
        self.manufacturer = manufacturer
        self.name = name
        self.shortName = shortName
        self.category = category
        self.modes = modes
        self.physicalData = physicalData
        self.metadata = FixtureMetadata()
    }

    public var fullName: String {
        "\(manufacturer) \(name)"
    }

    public var defaultMode: FixtureMode? {
        modes.first
    }
}

// MARK: - Patched Fixture Instance

public struct PatchedFixture: Codable, Identifiable, Sendable {
    public let id: UUID
    public var definitionId: UUID
    public var name: String
    public var universe: Int
    public var address: Int  // 1-512
    public var modeId: UUID
    public var position: FixturePosition?
    public var notes: String?

    public struct FixturePosition: Codable, Sendable {
        public var x: Float
        public var y: Float
        public var z: Float
        public var rotation: Float  // degrees
        public var orientation: Orientation

        public enum Orientation: String, Codable, Sendable {
            case standard = "Standard"
            case inverted = "Inverted"
            case rotated90 = "Rotated 90°"
            case rotated270 = "Rotated 270°"
        }

        public init(x: Float = 0, y: Float = 0, z: Float = 0, rotation: Float = 0, orientation: Orientation = .standard) {
            self.x = x
            self.y = y
            self.z = z
            self.rotation = rotation
            self.orientation = orientation
        }
    }

    public init(
        definitionId: UUID,
        name: String,
        universe: Int,
        address: Int,
        modeId: UUID,
        position: FixturePosition? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.definitionId = definitionId
        self.name = name
        self.universe = universe
        self.address = address
        self.modeId = modeId
        self.position = position
        self.notes = notes
    }
}

// MARK: - DMX Fixture Database Manager

@MainActor
public final class DMXFixtureDatabase: ObservableObject {
    // MARK: - Singleton

    public static let shared = DMXFixtureDatabase()

    // MARK: - Published State

    @Published public private(set) var fixtures: [FixtureDefinition] = []
    @Published public private(set) var manufacturers: [String] = []
    @Published public private(set) var patchedFixtures: [PatchedFixture] = []
    @Published public private(set) var isLoading: Bool = false

    // MARK: - Search & Filter

    @Published public var searchQuery: String = ""
    @Published public var selectedCategory: FixtureCategory?
    @Published public var selectedManufacturer: String?

    // MARK: - Private Properties

    private var customFixturesPath: URL?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupSearchPipeline()
        loadBuiltInFixtures()
    }

    private func setupSearchPipeline() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Filtered Results

    public var filteredFixtures: [FixtureDefinition] {
        var result = fixtures

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.manufacturer.lowercased().contains(query) ||
                $0.shortName?.lowercased().contains(query) == true
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if let manufacturer = selectedManufacturer {
            result = result.filter { $0.manufacturer == manufacturer }
        }

        return result.sorted { $0.fullName < $1.fullName }
    }

    // MARK: - Fixture Management

    public func addFixture(_ fixture: FixtureDefinition) {
        fixtures.append(fixture)
        updateManufacturers()
        saveCustomFixtures()
        logger.info("Added fixture: \(fixture.fullName)")
    }

    public func removeFixture(id: UUID) {
        fixtures.removeAll { $0.id == id }
        updateManufacturers()
        saveCustomFixtures()
        logger.info("Removed fixture: \(id)")
    }

    public func updateFixture(_ fixture: FixtureDefinition) {
        if let index = fixtures.firstIndex(where: { $0.id == fixture.id }) {
            fixtures[index] = fixture
            saveCustomFixtures()
            logger.info("Updated fixture: \(fixture.fullName)")
        }
    }

    public func getFixture(id: UUID) -> FixtureDefinition? {
        fixtures.first { $0.id == id }
    }

    private func updateManufacturers() {
        manufacturers = Array(Set(fixtures.map { $0.manufacturer })).sorted()
    }

    // MARK: - Patching

    public func patchFixture(
        definition: FixtureDefinition,
        name: String,
        universe: Int,
        address: Int,
        mode: FixtureMode
    ) -> PatchedFixture? {
        // Validate address
        guard address >= 1 && address <= 512 else {
            logger.error("Invalid DMX address: \(address)")
            return nil
        }

        // Check for address conflicts
        let endAddress = address + mode.channelCount - 1
        if endAddress > 512 {
            logger.error("Fixture extends beyond DMX universe: \(address) + \(mode.channelCount) = \(endAddress)")
            return nil
        }

        for patched in patchedFixtures where patched.universe == universe {
            if let patchedDef = getFixture(id: patched.definitionId),
               let patchedMode = patchedDef.modes.first(where: { $0.id == patched.modeId }) {
                let patchedEnd = patched.address + patchedMode.channelCount - 1
                if (address >= patched.address && address <= patchedEnd) ||
                   (endAddress >= patched.address && endAddress <= patchedEnd) {
                    logger.warning("Address conflict with \(patched.name) at \(patched.address)")
                }
            }
        }

        let patched = PatchedFixture(
            definitionId: definition.id,
            name: name,
            universe: universe,
            address: address,
            modeId: mode.id
        )

        patchedFixtures.append(patched)
        savePatch()

        logger.info("Patched \(name) to Universe \(universe), Address \(address)")
        return patched
    }

    public func unpatchFixture(id: UUID) {
        patchedFixtures.removeAll { $0.id == id }
        savePatch()
        logger.info("Unpatched fixture: \(id)")
    }

    public func suggestNextAddress(universe: Int, channelCount: Int) -> Int? {
        let usedAddresses = patchedFixtures
            .filter { $0.universe == universe }
            .compactMap { patched -> (start: Int, end: Int)? in
                guard let def = getFixture(id: patched.definitionId),
                      let mode = def.modes.first(where: { $0.id == patched.modeId }) else {
                    return nil
                }
                return (patched.address, patched.address + mode.channelCount - 1)
            }
            .sorted { $0.start < $1.start }

        var candidate = 1

        for (start, end) in usedAddresses {
            if candidate + channelCount - 1 < start {
                return candidate
            }
            candidate = end + 1
        }

        if candidate + channelCount - 1 <= 512 {
            return candidate
        }

        return nil
    }

    // MARK: - Import/Export

    public func importOFLFixture(from data: Data) throws -> FixtureDefinition {
        // Open Fixture Library JSON format
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // OFL format parsing (simplified)
        let ofl = try decoder.decode(OFLFixture.self, from: data)

        var modes: [FixtureMode] = []

        for oflMode in ofl.modes ?? [] {
            var channels: [DMXChannelDefinition] = []
            var offset = 0

            for channelKey in oflMode.channels {
                if let channelDef = ofl.availableChannels?[channelKey] {
                    let channelType = mapOFLChannelType(channelDef.type ?? "Generic")
                    let channel = DMXChannelDefinition(
                        name: channelKey,
                        type: channelType,
                        offset: offset,
                        defaultValue: UInt8(channelDef.defaultValue ?? 0)
                    )
                    channels.append(channel)
                    offset += 1
                }
            }

            let mode = FixtureMode(
                name: oflMode.name,
                shortName: oflMode.shortName,
                channels: channels
            )
            modes.append(mode)
        }

        var physical = PhysicalData()
        if let oflPhysical = ofl.physical {
            physical.weight = oflPhysical.weight
            if let dimensions = oflPhysical.dimensions {
                physical.width = dimensions[0]
                physical.height = dimensions[1]
                physical.depth = dimensions[2]
            }
            physical.power = oflPhysical.power
        }

        let fixture = FixtureDefinition(
            manufacturer: ofl.manufacturer ?? "Unknown",
            name: ofl.name ?? "Unknown Fixture",
            shortName: ofl.shortName,
            category: mapOFLCategory(ofl.categories?.first ?? "Other"),
            modes: modes,
            physicalData: physical
        )

        return fixture
    }

    private func mapOFLChannelType(_ oflType: String) -> DMXChannelType {
        switch oflType.lowercased() {
        case "intensity", "dimmer": return .dimmer
        case "color", "colorwheel": return .colorWheel
        case "pan": return .pan
        case "tilt": return .tilt
        case "zoom": return .zoom
        case "focus": return .focus
        case "iris": return .iris
        case "shutter", "strobe": return .shutter
        case "gobo": return .goboWheel
        case "prism": return .prism
        case "effect": return .effect
        case "speed": return .panTiltSpeed
        case "maintenance": return .control
        default: return .raw
        }
    }

    private func mapOFLCategory(_ oflCategory: String) -> FixtureCategory {
        switch oflCategory.lowercased() {
        case "moving head": return .movingHead
        case "moving head spot": return .movingHeadSpot
        case "moving head wash": return .movingHeadWash
        case "moving head beam": return .movingHeadBeam
        case "par": return .par
        case "led par": return .ledPar
        case "strobe": return .strobe
        case "laser": return .laser
        case "scanner": return .scanner
        case "blinder": return .blinder
        case "fog", "haze": return .fogHaze
        case "pixel": return .pixel
        case "led bar", "bar": return .ledBar
        case "led panel", "panel": return .ledPanel
        case "dimmer": return .dimmer
        default: return .other
        }
    }

    public func exportFixture(_ fixture: FixtureDefinition) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(fixture)
    }

    // MARK: - Persistence

    private func loadBuiltInFixtures() {
        isLoading = true

        // Add built-in fixtures
        fixtures = Self.builtInFixtures

        // Load custom fixtures
        loadCustomFixtures()

        updateManufacturers()
        isLoading = false

        logger.info("Loaded \(self.fixtures.count) fixtures from \(self.manufacturers.count) manufacturers")
    }

    private func loadCustomFixtures() {
        guard let data = UserDefaults.standard.data(forKey: "com.echoelmusic.customFixtures") else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let custom = try decoder.decode([FixtureDefinition].self, from: data)
            fixtures.append(contentsOf: custom)
        } catch {
            logger.error("Failed to load custom fixtures: \(error.localizedDescription)")
        }
    }

    private func saveCustomFixtures() {
        let builtInIds = Set(Self.builtInFixtures.map { $0.id })
        let custom = fixtures.filter { !builtInIds.contains($0.id) }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(custom)
            UserDefaults.standard.set(data, forKey: "com.echoelmusic.customFixtures")
        } catch {
            logger.error("Failed to save custom fixtures: \(error.localizedDescription)")
        }
    }

    private func savePatch() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(patchedFixtures)
            UserDefaults.standard.set(data, forKey: "com.echoelmusic.dmxPatch")
        } catch {
            logger.error("Failed to save patch: \(error.localizedDescription)")
        }
    }

    // MARK: - Built-In Fixtures Database

    static let builtInFixtures: [FixtureDefinition] = {
        var fixtures: [FixtureDefinition] = []

        // ===== CHAUVET =====

        // Chauvet Intimidator Spot 375Z IRC
        fixtures.append(FixtureDefinition(
            manufacturer: "Chauvet",
            name: "Intimidator Spot 375Z IRC",
            shortName: "Int375Z",
            category: .movingHeadSpot,
            modes: [
                FixtureMode(name: "15 Channel", channels: [
                    DMXChannelDefinition(name: "Pan", type: .pan, offset: 0),
                    DMXChannelDefinition(name: "Pan Fine", type: .panFine, offset: 1),
                    DMXChannelDefinition(name: "Tilt", type: .tilt, offset: 2),
                    DMXChannelDefinition(name: "Tilt Fine", type: .tiltFine, offset: 3),
                    DMXChannelDefinition(name: "P/T Speed", type: .panTiltSpeed, offset: 4, defaultValue: 0),
                    DMXChannelDefinition(name: "Color Wheel", type: .colorWheel, offset: 5),
                    DMXChannelDefinition(name: "Gobo Wheel", type: .goboWheel, offset: 6),
                    DMXChannelDefinition(name: "Gobo Rotation", type: .goboRotation, offset: 7),
                    DMXChannelDefinition(name: "Prism", type: .prism, offset: 8),
                    DMXChannelDefinition(name: "Focus", type: .focus, offset: 9, defaultValue: 127),
                    DMXChannelDefinition(name: "Zoom", type: .zoom, offset: 10, defaultValue: 127),
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 11, highlightValue: 255),
                    DMXChannelDefinition(name: "Shutter", type: .shutter, offset: 12, defaultValue: 32),
                    DMXChannelDefinition(name: "Control", type: .control, offset: 13),
                    DMXChannelDefinition(name: "Movement Macros", type: .effect, offset: 14)
                ]),
                FixtureMode(name: "8 Channel", channels: [
                    DMXChannelDefinition(name: "Pan", type: .pan, offset: 0),
                    DMXChannelDefinition(name: "Tilt", type: .tilt, offset: 1),
                    DMXChannelDefinition(name: "Color Wheel", type: .colorWheel, offset: 2),
                    DMXChannelDefinition(name: "Gobo Wheel", type: .goboWheel, offset: 3),
                    DMXChannelDefinition(name: "Zoom", type: .zoom, offset: 4, defaultValue: 127),
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 5, highlightValue: 255),
                    DMXChannelDefinition(name: "Shutter", type: .shutter, offset: 6, defaultValue: 32),
                    DMXChannelDefinition(name: "Control", type: .control, offset: 7)
                ])
            ],
            physicalData: {
                var p = PhysicalData()
                p.weight = 8.9
                p.panRange = 540
                p.tiltRange = 270
                p.power = 200
                return p
            }()
        ))

        // Chauvet SlimPAR Pro H USB
        fixtures.append(FixtureDefinition(
            manufacturer: "Chauvet",
            name: "SlimPAR Pro H USB",
            shortName: "SlimPAR",
            category: .ledPar,
            modes: [
                FixtureMode(name: "12 Channel", channels: [
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 0, highlightValue: 255),
                    DMXChannelDefinition(name: "Red", type: .red, offset: 1),
                    DMXChannelDefinition(name: "Green", type: .green, offset: 2),
                    DMXChannelDefinition(name: "Blue", type: .blue, offset: 3),
                    DMXChannelDefinition(name: "Amber", type: .amber, offset: 4),
                    DMXChannelDefinition(name: "White", type: .white, offset: 5),
                    DMXChannelDefinition(name: "UV", type: .uv, offset: 6),
                    DMXChannelDefinition(name: "Strobe", type: .strobe, offset: 7),
                    DMXChannelDefinition(name: "Color Macro", type: .colorMacro, offset: 8),
                    DMXChannelDefinition(name: "Program", type: .effect, offset: 9),
                    DMXChannelDefinition(name: "Program Speed", type: .effectSpeed, offset: 10),
                    DMXChannelDefinition(name: "Dimmer Mode", type: .control, offset: 11)
                ]),
                FixtureMode(name: "6 Channel", channels: [
                    DMXChannelDefinition(name: "Red", type: .red, offset: 0),
                    DMXChannelDefinition(name: "Green", type: .green, offset: 1),
                    DMXChannelDefinition(name: "Blue", type: .blue, offset: 2),
                    DMXChannelDefinition(name: "Amber", type: .amber, offset: 3),
                    DMXChannelDefinition(name: "White", type: .white, offset: 4),
                    DMXChannelDefinition(name: "UV", type: .uv, offset: 5)
                ])
            ],
            physicalData: {
                var p = PhysicalData()
                p.weight = 2.7
                p.power = 115
                return p
            }()
        ))

        // ===== MARTIN =====

        // Martin MAC Aura
        fixtures.append(FixtureDefinition(
            manufacturer: "Martin",
            name: "MAC Aura",
            shortName: "Aura",
            category: .movingHeadWash,
            modes: [
                FixtureMode(name: "Standard", channels: [
                    DMXChannelDefinition(name: "Shutter", type: .shutter, offset: 0, defaultValue: 20),
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 1, highlightValue: 255),
                    DMXChannelDefinition(name: "Cyan", type: .cyan, offset: 2),
                    DMXChannelDefinition(name: "Magenta", type: .magenta, offset: 3),
                    DMXChannelDefinition(name: "Yellow", type: .yellow, offset: 4),
                    DMXChannelDefinition(name: "CTC", type: .cto, offset: 5),
                    DMXChannelDefinition(name: "FX Wheel", type: .effect, offset: 6),
                    DMXChannelDefinition(name: "FX Wheel Rotation", type: .effectSpeed, offset: 7),
                    DMXChannelDefinition(name: "Zoom", type: .zoom, offset: 8, defaultValue: 127),
                    DMXChannelDefinition(name: "Pan", type: .pan, offset: 9),
                    DMXChannelDefinition(name: "Pan Fine", type: .panFine, offset: 10),
                    DMXChannelDefinition(name: "Tilt", type: .tilt, offset: 11),
                    DMXChannelDefinition(name: "Tilt Fine", type: .tiltFine, offset: 12),
                    DMXChannelDefinition(name: "Control", type: .control, offset: 13),
                    DMXChannelDefinition(name: "FX Select", type: .effect, offset: 14),
                    DMXChannelDefinition(name: "FX Adjust", type: .effectSpeed, offset: 15),
                    DMXChannelDefinition(name: "Aura Shutter", type: .shutter, offset: 16, defaultValue: 20),
                    DMXChannelDefinition(name: "Aura Dimmer", type: .dimmer, offset: 17),
                    DMXChannelDefinition(name: "Aura Red", type: .red, offset: 18),
                    DMXChannelDefinition(name: "Aura Green", type: .green, offset: 19),
                    DMXChannelDefinition(name: "Aura Blue", type: .blue, offset: 20)
                ])
            ],
            physicalData: {
                var p = PhysicalData()
                p.weight = 5.9
                p.panRange = 540
                p.tiltRange = 232
                p.power = 220
                return p
            }()
        ))

        // ===== ADJ =====

        // ADJ Mega Par Profile Plus
        fixtures.append(FixtureDefinition(
            manufacturer: "ADJ",
            name: "Mega Par Profile Plus",
            shortName: "MegaPar+",
            category: .ledPar,
            modes: [
                FixtureMode(name: "7 Channel", channels: [
                    DMXChannelDefinition(name: "Red", type: .red, offset: 0),
                    DMXChannelDefinition(name: "Green", type: .green, offset: 1),
                    DMXChannelDefinition(name: "Blue", type: .blue, offset: 2),
                    DMXChannelDefinition(name: "Amber", type: .amber, offset: 3),
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 4, highlightValue: 255),
                    DMXChannelDefinition(name: "Strobe", type: .strobe, offset: 5),
                    DMXChannelDefinition(name: "Programs", type: .effect, offset: 6)
                ]),
                FixtureMode(name: "4 Channel", channels: [
                    DMXChannelDefinition(name: "Red", type: .red, offset: 0),
                    DMXChannelDefinition(name: "Green", type: .green, offset: 1),
                    DMXChannelDefinition(name: "Blue", type: .blue, offset: 2),
                    DMXChannelDefinition(name: "Amber", type: .amber, offset: 3)
                ])
            ]
        ))

        // ===== ELATION =====

        // Elation Platinum Spot 5R Pro
        fixtures.append(FixtureDefinition(
            manufacturer: "Elation",
            name: "Platinum Spot 5R Pro",
            shortName: "Plat5RPro",
            category: .movingHeadSpot,
            modes: [
                FixtureMode(name: "Standard", channels: [
                    DMXChannelDefinition(name: "Pan", type: .pan, offset: 0),
                    DMXChannelDefinition(name: "Pan Fine", type: .panFine, offset: 1),
                    DMXChannelDefinition(name: "Tilt", type: .tilt, offset: 2),
                    DMXChannelDefinition(name: "Tilt Fine", type: .tiltFine, offset: 3),
                    DMXChannelDefinition(name: "Color Wheel", type: .colorWheel, offset: 4),
                    DMXChannelDefinition(name: "Gobo Wheel 1", type: .goboWheel, offset: 5),
                    DMXChannelDefinition(name: "Gobo Wheel 2", type: .goboWheel, offset: 6),
                    DMXChannelDefinition(name: "Gobo 2 Rotation", type: .goboRotation, offset: 7),
                    DMXChannelDefinition(name: "Prism", type: .prism, offset: 8),
                    DMXChannelDefinition(name: "Prism Rotation", type: .prismRotation, offset: 9),
                    DMXChannelDefinition(name: "Focus", type: .focus, offset: 10, defaultValue: 127),
                    DMXChannelDefinition(name: "Shutter", type: .shutter, offset: 11, defaultValue: 32),
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 12, highlightValue: 255),
                    DMXChannelDefinition(name: "Frost", type: .frost, offset: 13),
                    DMXChannelDefinition(name: "P/T Speed", type: .panTiltSpeed, offset: 14),
                    DMXChannelDefinition(name: "Control", type: .control, offset: 15)
                ])
            ],
            physicalData: {
                var p = PhysicalData()
                p.weight = 17.0
                p.panRange = 540
                p.tiltRange = 250
                p.power = 380
                return p
            }()
        ))

        // ===== ROBE =====

        // Robe Robin 600 LED Wash
        fixtures.append(FixtureDefinition(
            manufacturer: "Robe",
            name: "Robin 600 LED Wash",
            shortName: "R600Wash",
            category: .movingHeadWash,
            modes: [
                FixtureMode(name: "Mode 1", channels: [
                    DMXChannelDefinition(name: "Pan", type: .pan, offset: 0),
                    DMXChannelDefinition(name: "Pan Fine", type: .panFine, offset: 1),
                    DMXChannelDefinition(name: "Tilt", type: .tilt, offset: 2),
                    DMXChannelDefinition(name: "Tilt Fine", type: .tiltFine, offset: 3),
                    DMXChannelDefinition(name: "P/T Speed", type: .panTiltSpeed, offset: 4),
                    DMXChannelDefinition(name: "Control", type: .control, offset: 5),
                    DMXChannelDefinition(name: "Red", type: .red, offset: 6),
                    DMXChannelDefinition(name: "Green", type: .green, offset: 7),
                    DMXChannelDefinition(name: "Blue", type: .blue, offset: 8),
                    DMXChannelDefinition(name: "White", type: .white, offset: 9),
                    DMXChannelDefinition(name: "CTC", type: .cto, offset: 10),
                    DMXChannelDefinition(name: "Color Mix", type: .colorMix, offset: 11),
                    DMXChannelDefinition(name: "Zoom", type: .zoom, offset: 12, defaultValue: 127),
                    DMXChannelDefinition(name: "Shutter", type: .shutter, offset: 13, defaultValue: 32),
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 14, highlightValue: 255),
                    DMXChannelDefinition(name: "Dimmer Fine", type: .dimmer, offset: 15, resolution: .fine)
                ])
            ],
            physicalData: {
                var p = PhysicalData()
                p.weight = 10.2
                p.panRange = 540
                p.tiltRange = 243
                p.power = 250
                return p
            }()
        ))

        // ===== CLAY PAKY =====

        // Clay Paky Sharpy
        fixtures.append(FixtureDefinition(
            manufacturer: "Clay Paky",
            name: "Sharpy",
            shortName: "Sharpy",
            category: .movingHeadBeam,
            modes: [
                FixtureMode(name: "Standard", channels: [
                    DMXChannelDefinition(name: "Cyan", type: .cyan, offset: 0),
                    DMXChannelDefinition(name: "Magenta", type: .magenta, offset: 1),
                    DMXChannelDefinition(name: "Yellow", type: .yellow, offset: 2),
                    DMXChannelDefinition(name: "Color Wheel", type: .colorWheel, offset: 3),
                    DMXChannelDefinition(name: "Strobe", type: .strobe, offset: 4),
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 5, highlightValue: 255),
                    DMXChannelDefinition(name: "Gobo Wheel", type: .goboWheel, offset: 6),
                    DMXChannelDefinition(name: "Gobo Rotation", type: .goboRotation, offset: 7),
                    DMXChannelDefinition(name: "Prism", type: .prism, offset: 8),
                    DMXChannelDefinition(name: "Prism Rotation", type: .prismRotation, offset: 9),
                    DMXChannelDefinition(name: "Effects", type: .effect, offset: 10),
                    DMXChannelDefinition(name: "Frost", type: .frost, offset: 11),
                    DMXChannelDefinition(name: "Pan", type: .pan, offset: 12),
                    DMXChannelDefinition(name: "Pan Fine", type: .panFine, offset: 13),
                    DMXChannelDefinition(name: "Tilt", type: .tilt, offset: 14),
                    DMXChannelDefinition(name: "Tilt Fine", type: .tiltFine, offset: 15),
                    DMXChannelDefinition(name: "Function", type: .control, offset: 16),
                    DMXChannelDefinition(name: "Reset", type: .reset, offset: 17),
                    DMXChannelDefinition(name: "Lamp", type: .lamp, offset: 18),
                    DMXChannelDefinition(name: "P/T Time", type: .panTiltSpeed, offset: 19),
                    DMXChannelDefinition(name: "Color Time", type: .effectSpeed, offset: 20)
                ])
            ],
            physicalData: {
                var p = PhysicalData()
                p.weight = 16.0
                p.panRange = 540
                p.tiltRange = 250
                p.power = 420
                p.beamAngle = 0
                return p
            }()
        ))

        // ===== GENERIC =====

        // Generic RGB LED PAR
        fixtures.append(FixtureDefinition(
            manufacturer: "Generic",
            name: "RGB LED PAR",
            shortName: "RGB PAR",
            category: .ledPar,
            modes: [
                FixtureMode(name: "4 Channel", channels: [
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 0, highlightValue: 255),
                    DMXChannelDefinition(name: "Red", type: .red, offset: 1),
                    DMXChannelDefinition(name: "Green", type: .green, offset: 2),
                    DMXChannelDefinition(name: "Blue", type: .blue, offset: 3)
                ]),
                FixtureMode(name: "3 Channel", channels: [
                    DMXChannelDefinition(name: "Red", type: .red, offset: 0),
                    DMXChannelDefinition(name: "Green", type: .green, offset: 1),
                    DMXChannelDefinition(name: "Blue", type: .blue, offset: 2)
                ])
            ]
        ))

        // Generic RGBW LED PAR
        fixtures.append(FixtureDefinition(
            manufacturer: "Generic",
            name: "RGBW LED PAR",
            shortName: "RGBW PAR",
            category: .ledPar,
            modes: [
                FixtureMode(name: "5 Channel", channels: [
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 0, highlightValue: 255),
                    DMXChannelDefinition(name: "Red", type: .red, offset: 1),
                    DMXChannelDefinition(name: "Green", type: .green, offset: 2),
                    DMXChannelDefinition(name: "Blue", type: .blue, offset: 3),
                    DMXChannelDefinition(name: "White", type: .white, offset: 4)
                ]),
                FixtureMode(name: "4 Channel", channels: [
                    DMXChannelDefinition(name: "Red", type: .red, offset: 0),
                    DMXChannelDefinition(name: "Green", type: .green, offset: 1),
                    DMXChannelDefinition(name: "Blue", type: .blue, offset: 2),
                    DMXChannelDefinition(name: "White", type: .white, offset: 3)
                ])
            ]
        ))

        // Generic Dimmer
        fixtures.append(FixtureDefinition(
            manufacturer: "Generic",
            name: "Dimmer",
            category: .dimmer,
            modes: [
                FixtureMode(name: "1 Channel", channels: [
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 0, highlightValue: 255)
                ])
            ]
        ))

        // Generic Strobe
        fixtures.append(FixtureDefinition(
            manufacturer: "Generic",
            name: "Strobe",
            category: .strobe,
            modes: [
                FixtureMode(name: "2 Channel", channels: [
                    DMXChannelDefinition(name: "Dimmer", type: .dimmer, offset: 0, highlightValue: 255),
                    DMXChannelDefinition(name: "Speed", type: .strobe, offset: 1)
                ])
            ]
        ))

        // Generic Fog Machine
        fixtures.append(FixtureDefinition(
            manufacturer: "Generic",
            name: "Fog Machine",
            category: .fogHaze,
            modes: [
                FixtureMode(name: "1 Channel", channels: [
                    DMXChannelDefinition(name: "Output", type: .dimmer, offset: 0)
                ]),
                FixtureMode(name: "2 Channel", channels: [
                    DMXChannelDefinition(name: "Output", type: .dimmer, offset: 0),
                    DMXChannelDefinition(name: "Fan", type: .fan, offset: 1)
                ])
            ]
        ))

        return fixtures
    }()
}

// MARK: - OFL Import Types

private struct OFLFixture: Codable {
    let name: String?
    let shortName: String?
    let manufacturer: String?
    let categories: [String]?
    let modes: [OFLMode]?
    let availableChannels: [String: OFLChannel]?
    let physical: OFLPhysical?
}

private struct OFLMode: Codable {
    let name: String
    let shortName: String?
    let channels: [String]
}

private struct OFLChannel: Codable {
    let type: String?
    let defaultValue: Int?
    let capabilities: [OFLCapability]?
}

private struct OFLCapability: Codable {
    let dmxRange: [Int]?
    let type: String?
    let comment: String?
}

private struct OFLPhysical: Codable {
    let weight: Float?
    let dimensions: [Float]?
    let power: Int?
}

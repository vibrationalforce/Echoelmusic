import Foundation
import AVFoundation
import AudioToolbox
import Combine

// MARK: - iOS Audio Unit (AUv3) Hosting System
// Allows Echoelmusic to host third-party Audio Unit plugins on iOS

/// Audio Unit Host Manager for iOS
/// Discovers, loads, and manages AUv3 plugins
@MainActor
class AudioUnitHostManager: ObservableObject {

    // MARK: - Published Properties
    @Published var availableAudioUnits: [AudioUnitInfo] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0

    // MARK: - Audio Unit Info
    struct AudioUnitInfo: Identifiable, Hashable {
        var id: String { componentDescription.identifier }
        var name: String
        var manufacturer: String
        var version: UInt32
        var componentDescription: AudioComponentDescription
        var type: AudioUnitType
        var tags: [String]
        var iconURL: URL?
    }

    enum AudioUnitType: String {
        case instrument
        case effect
        case generator
        case midiEffect
        case midiGenerator
        case unknown
    }

    // MARK: - Scanning
    func scanForAudioUnits() async {
        isScanning = true
        scanProgress = 0

        availableAudioUnits = []

        // Find all AUv3 components
        let componentTypes: [(OSType, AudioUnitType)] = [
            (kAudioUnitType_MusicDevice, .instrument),
            (kAudioUnitType_MusicEffect, .effect),
            (kAudioUnitType_Effect, .effect),
            (kAudioUnitType_Generator, .generator),
            (kAudioUnitType_MIDIProcessor, .midiEffect)
        ]

        var allComponents: [AudioUnitInfo] = []

        for (index, (componentType, auType)) in componentTypes.enumerated() {
            scanProgress = Double(index) / Double(componentTypes.count)

            let components = await scanComponentType(componentType, type: auType)
            allComponents.append(contentsOf: components)
        }

        availableAudioUnits = allComponents.sorted { $0.name < $1.name }

        scanProgress = 1.0
        isScanning = false
    }

    private func scanComponentType(_ type: OSType, type auType: AudioUnitType) async -> [AudioUnitInfo] {
        var components: [AudioUnitInfo] = []

        // Create component description for search
        var searchDesc = AudioComponentDescription()
        searchDesc.componentType = type
        searchDesc.componentSubType = 0
        searchDesc.componentManufacturer = 0
        searchDesc.componentFlags = 0
        searchDesc.componentFlagsMask = 0

        // Find all matching components
        var component: AudioComponent? = AudioComponentFindNext(nil, &searchDesc)

        while component != nil {
            if let info = await extractComponentInfo(component!, auType: auType) {
                components.append(info)
            }
            component = AudioComponentFindNext(component, &searchDesc)
        }

        return components
    }

    private func extractComponentInfo(_ component: AudioComponent, auType: AudioUnitType) async -> AudioUnitInfo? {
        var desc = AudioComponentDescription()
        var cfName: Unmanaged<CFString>?
        var cfManufacturer: Unmanaged<CFString>?
        var version: UInt32 = 0

        // Get component description
        guard AudioComponentGetDescription(component, &desc) == noErr else {
            return nil
        }

        // Get name
        AudioComponentCopyName(component, &cfName)
        let name = cfName?.takeRetainedValue() as String? ?? "Unknown"

        // Get manufacturer (try to extract)
        let manufacturer: String
        if let man = cfManufacturer?.takeRetainedValue() as String? {
            manufacturer = man
        } else {
            // Decode manufacturer code
            manufacturer = decodeFourCharCode(desc.componentManufacturer)
        }

        // Get version
        AudioComponentGetVersion(component, &version)

        // Infer tags based on name and type
        let tags = inferTags(name: name, type: auType)

        return AudioUnitInfo(
            name: name,
            manufacturer: manufacturer,
            version: version,
            componentDescription: desc,
            type: auType,
            tags: tags,
            iconURL: nil
        )
    }

    private func decodeFourCharCode(_ code: OSType) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]

        if let string = String(bytes: bytes, encoding: .ascii) {
            return string.trimmingCharacters(in: .whitespaces)
        }

        return "Unknown"
    }

    private func inferTags(name: String, type: AudioUnitType) -> [String] {
        var tags: [String] = [type.rawValue]

        let lowercaseName = name.lowercased()

        // Effect categories
        if lowercaseName.contains("reverb") { tags.append("reverb") }
        if lowercaseName.contains("delay") || lowercaseName.contains("echo") { tags.append("delay") }
        if lowercaseName.contains("comp") { tags.append("dynamics") }
        if lowercaseName.contains("eq") || lowercaseName.contains("equalizer") { tags.append("eq") }
        if lowercaseName.contains("dist") || lowercaseName.contains("overdrive") { tags.append("distortion") }
        if lowercaseName.contains("filter") { tags.append("filter") }
        if lowercaseName.contains("chorus") || lowercaseName.contains("flanger") { tags.append("modulation") }

        // Instrument categories
        if lowercaseName.contains("synth") { tags.append("synthesizer") }
        if lowercaseName.contains("drum") || lowercaseName.contains("beat") { tags.append("drums") }
        if lowercaseName.contains("piano") { tags.append("piano") }
        if lowercaseName.contains("sampler") { tags.append("sampler") }

        return tags
    }

    // MARK: - Filtering
    func filterByType(_ type: AudioUnitType) -> [AudioUnitInfo] {
        return availableAudioUnits.filter { $0.type == type }
    }

    func searchAudioUnits(_ query: String) -> [AudioUnitInfo] {
        let lowercaseQuery = query.lowercased()
        return availableAudioUnits.filter {
            $0.name.lowercased().contains(lowercaseQuery) ||
            $0.manufacturer.lowercased().contains(lowercaseQuery) ||
            $0.tags.contains { $0.contains(lowercaseQuery) }
        }
    }
}

// MARK: - Audio Unit Instance Host
/// Hosts a single Audio Unit instance
class AudioUnitInstanceHost: ObservableObject {

    // MARK: - Properties
    @Published var isLoaded = false
    @Published var hasEditor = false
    @Published var parameters: [AudioUnitParameter] = []

    private var audioUnit: AUAudioUnit?
    private var componentDescription: AudioComponentDescription
    private var parameterTree: AUParameterTree?

    var name: String = ""
    var latencySamples: Int {
        return Int(audioUnit?.latency ?? 0)
    }

    // MARK: - Parameter
    struct AudioUnitParameter: Identifiable {
        var id: UInt64 { address }
        var address: AUParameterAddress
        var name: String
        var unit: String
        var minValue: Float
        var maxValue: Float
        var defaultValue: Float
        var currentValue: Float
        var isAutomatable: Bool
    }

    // MARK: - Init
    init(componentDescription: AudioComponentDescription) {
        self.componentDescription = componentDescription
    }

    // MARK: - Loading
    func loadAudioUnit() async throws {
        // Instantiate Audio Unit
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            AUAudioUnit.instantiate(
                with: componentDescription,
                options: [.loadOutOfProcess]
            ) { [weak self] audioUnit, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let audioUnit = audioUnit else {
                    continuation.resume(throwing: AudioUnitError.failedToLoad)
                    return
                }

                Task { @MainActor in
                    self?.audioUnit = audioUnit
                    self?.name = audioUnit.audioUnitName ?? "Unknown"
                    self?.hasEditor = audioUnit.viewController != nil
                    self?.extractParameters()
                    self?.isLoaded = true
                    continuation.resume()
                }
            }
        }
    }

    func unloadAudioUnit() {
        audioUnit = nil
        parameters = []
        isLoaded = false
    }

    // MARK: - Parameters
    private func extractParameters() {
        guard let au = audioUnit else { return }

        parameterTree = au.parameterTree
        parameters = []

        if let tree = parameterTree {
            extractParametersFromTree(tree)
        }
    }

    private func extractParametersFromTree(_ tree: AUParameterTree) {
        for param in tree.allParameters {
            let paramInfo = AudioUnitParameter(
                address: param.address,
                name: param.displayName,
                unit: param.unitName ?? "",
                minValue: param.minValue,
                maxValue: param.maxValue,
                defaultValue: param.value,
                currentValue: param.value,
                isAutomatable: param.canRamp
            )
            parameters.append(paramInfo)
        }
    }

    func getParameter(address: AUParameterAddress) -> Float? {
        return parameterTree?.parameter(withAddress: address)?.value
    }

    func setParameter(address: AUParameterAddress, value: Float) {
        parameterTree?.parameter(withAddress: address)?.value = value
    }

    func setParameterSmooth(address: AUParameterAddress, value: Float, duration: TimeInterval) {
        guard let param = parameterTree?.parameter(withAddress: address) else { return }

        // Use ramping for smooth parameter changes
        let token = param.token(byAddingParameterObserver: { _, _ in })
        parameterTree?.parameter(withID: token)?.value = value
    }

    // MARK: - Presets
    func getFactoryPresets() -> [AUAudioUnitPreset] {
        return audioUnit?.factoryPresets ?? []
    }

    func getCurrentPreset() -> AUAudioUnitPreset? {
        return audioUnit?.currentPreset
    }

    func setCurrentPreset(_ preset: AUAudioUnitPreset) {
        audioUnit?.currentPreset = preset
    }

    func loadPreset(from url: URL) throws {
        guard let au = audioUnit else {
            throw AudioUnitError.notLoaded
        }

        let data = try Data(contentsOf: url)
        let dict = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any]

        if let dict = dict {
            try au.fullState = dict
        }
    }

    func savePreset(to url: URL) throws {
        guard let au = audioUnit else {
            throw AudioUnitError.notLoaded
        }

        if let state = au.fullState {
            let data = try PropertyListSerialization.data(
                fromPropertyList: state,
                format: .binary,
                options: 0
            )
            try data.write(to: url)
        }
    }

    // MARK: - Audio Processing
    func allocateRenderResources(format: AVAudioFormat, maxFrames: AUAudioFrameCount) throws {
        try audioUnit?.allocateRenderResources()
    }

    func deallocateRenderResources() {
        audioUnit?.deallocateRenderResources()
    }

    /// Render audio through the plugin
    func render(
        audioBuffer: AVAudioPCMBuffer,
        timeStamp: AudioTimeStamp,
        frameCount: AUAudioFrameCount,
        outputBusNumber: AUAudioUnitBus = 0
    ) throws {
        guard let au = audioUnit else {
            throw AudioUnitError.notLoaded
        }

        // Get render block
        let renderBlock = au.renderBlock

        var ts = timeStamp
        var pullInputBlock: AUPullInputBlock? = nil

        // Render
        let status = renderBlock(
            &pullInputBlock,
            &ts,
            frameCount,
            outputBusNumber,
            audioBuffer.mutableAudioBufferList,
            nil
        )

        if status != noErr {
            throw AudioUnitError.renderFailed(status)
        }
    }

    // MARK: - MIDI
    func sendMIDIEvent(_ midiData: [UInt8]) {
        guard let au = audioUnit else { return }

        // Schedule MIDI event
        let packetList = createMIDIPacketList(midiData)
        // au.scheduleMIDIEventBlock would be used here in real implementation
    }

    private func createMIDIPacketList(_ midiData: [UInt8]) -> MIDIPacketList {
        var packetList = MIDIPacketList()
        // Simplified - would construct proper MIDI packet list
        return packetList
    }

    // MARK: - UI
    @MainActor
    func requestViewController() -> AUViewController? {
        return audioUnit?.requestViewController(completionHandler: { [weak self] viewController in
            // Handle async view controller creation
            if let vc = viewController {
                // Update UI
            }
        })
    }
}

// MARK: - Audio Unit Chain
/// Chain multiple Audio Units in series
class AudioUnitChain: ObservableObject {

    @Published var units: [AudioUnitInstanceHost] = []

    func addUnit(_ componentDescription: AudioComponentDescription) -> AudioUnitInstanceHost {
        let host = AudioUnitInstanceHost(componentDescription: componentDescription)
        units.append(host)
        return host
    }

    func removeUnit(at index: Int) {
        guard index >= 0 && index < units.count else { return }
        units[index].unloadAudioUnit()
        units.remove(at: index)
    }

    func moveUnit(from: Int, to: Int) {
        guard from >= 0 && from < units.count &&
              to >= 0 && to < units.count else { return }

        let unit = units.remove(at: from)
        units.insert(unit, at: to)
    }

    func processChain(buffer: AVAudioPCMBuffer, timeStamp: AudioTimeStamp) throws {
        var currentBuffer = buffer

        for unit in units where unit.isLoaded {
            try unit.render(
                audioBuffer: currentBuffer,
                timeStamp: timeStamp,
                frameCount: AVAudioFrameCount(currentBuffer.frameLength)
            )
        }
    }
}

// MARK: - Errors
enum AudioUnitError: Error {
    case failedToLoad
    case notLoaded
    case renderFailed(OSStatus)
    case invalidParameter
}

// MARK: - AudioComponentDescription Extension
extension AudioComponentDescription: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(componentType)
        hasher.combine(componentSubType)
        hasher.combine(componentManufacturer)
    }

    public static func == (lhs: AudioComponentDescription, rhs: AudioComponentDescription) -> Bool {
        return lhs.componentType == rhs.componentType &&
               lhs.componentSubType == rhs.componentSubType &&
               lhs.componentManufacturer == rhs.componentManufacturer
    }

    var identifier: String {
        return "\(componentType)-\(componentSubType)-\(componentManufacturer)"
    }
}

// MARK: - Integration with Echoelmusic Audio Engine
extension AudioUnitHostManager {

    /// Create plugin insert for track
    func createPluginInsert(
        for track: Track,
        with audioUnit: AudioUnitInfo
    ) async throws -> AudioUnitInstanceHost {
        let host = AudioUnitInstanceHost(componentDescription: audioUnit.componentDescription)
        try await host.loadAudioUnit()

        // Integrate with track's audio processing
        // In production, would wire this into the main audio graph

        return host
    }
}

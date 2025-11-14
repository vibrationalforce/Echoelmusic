import Foundation

/// Bio-parameter mapping graph
/// Defines how biometric signals map to audio/visual parameters
public final class BioMappingGraph: @unchecked Sendable {

    /// Mapping entry: bio-signal → parameter
    public struct Mapping: Identifiable, Sendable {
        public let id = UUID()

        /// Source bio-signal
        public let bioSignal: BioSignalType

        /// Target parameter
        public let targetParameter: String

        /// Mapping function
        public let mappingCurve: MappingCurve

        /// Intensity (0-1)
        public let intensity: Double

        public init(
            bioSignal: BioSignalType,
            targetParameter: String,
            mappingCurve: MappingCurve = .linear,
            intensity: Double = 1.0
        ) {
            self.bioSignal = bioSignal
            self.targetParameter = targetParameter
            self.mappingCurve = mappingCurve
            self.intensity = intensity
        }
    }

    /// Bio-signal types
    public enum BioSignalType: String, Sendable, CaseIterable {
        case hrv = "HRV"
        case heartRate = "HeartRate"
        case coherence = "Coherence"
        case breathRate = "BreathRate"
        case audioLevel = "AudioLevel"
        case voicePitch = "VoicePitch"
    }

    /// Mapping curve types
    public enum MappingCurve: String, Sendable {
        case linear
        case exponential
        case logarithmic
        case sine
        case custom
    }

    private let lock = NSLock()
    private var mappings: [Mapping] = []

    public init() {}

    /// Add a bio-parameter mapping
    /// - Parameter mapping: Mapping to add
    public func addMapping(_ mapping: Mapping) {
        lock.lock()
        defer { lock.unlock() }
        mappings.append(mapping)
        print("✅ BioMappingGraph: Added mapping \(mapping.bioSignal) → \(mapping.targetParameter)")
    }

    /// Remove a mapping
    /// - Parameter id: Mapping ID
    public func removeMapping(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        mappings.removeAll { $0.id == id }
    }

    /// Get all mappings for a bio-signal
    /// - Parameter bioSignal: Bio-signal type
    /// - Returns: Array of mappings
    public func getMappings(for bioSignal: BioSignalType) -> [Mapping] {
        lock.lock()
        defer { lock.unlock() }
        return mappings.filter { $0.bioSignal == bioSignal }
    }

    /// Apply mappings to convert bio-values to parameters
    /// - Parameter bioValues: Dictionary of bio-signal values
    /// - Returns: Dictionary of parameter values
    public func applyMappings(bioValues: [BioSignalType: Double]) -> [String: Float] {
        lock.lock()
        let currentMappings = mappings
        lock.unlock()

        var parameters: [String: Float] = [:]

        for mapping in currentMappings {
            guard let bioValue = bioValues[mapping.bioSignal] else { continue }

            let mappedValue = applyMappingCurve(
                value: bioValue,
                curve: mapping.mappingCurve,
                intensity: mapping.intensity
            )

            parameters[mapping.targetParameter] = Float(mappedValue)
        }

        return parameters
    }

    private func applyMappingCurve(
        value: Double,
        curve: MappingCurve,
        intensity: Double
    ) -> Double {
        let normalizedValue = max(0.0, min(1.0, value))

        let curveValue: Double
        switch curve {
        case .linear:
            curveValue = normalizedValue
        case .exponential:
            curveValue = pow(normalizedValue, 2.0)
        case .logarithmic:
            curveValue = log10(1.0 + normalizedValue * 9.0) / log10(10.0)
        case .sine:
            curveValue = sin(normalizedValue * .pi / 2.0)
        case .custom:
            curveValue = normalizedValue // TODO: Custom curve support
        }

        return curveValue * intensity
    }
}

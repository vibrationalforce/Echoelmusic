import Foundation
import Combine
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// REAL-TIME SYNC PROTOCOL
// ═══════════════════════════════════════════════════════════════════════════════
//
// Advanced synchronization protocol features:
// • Precision time synchronization (NTP-style)
// • Latency compensation with prediction
// • Conflict resolution (OT/CRDT hybrid)
// • Visual state sync
// • Audio timeline synchronization
// • Bandwidth-adaptive streaming
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Time Synchronization

/// High-precision network time synchronization
public final class NetworkTimeSync {

    public static let shared = NetworkTimeSync()

    /// Synchronized server time
    public var serverTime: TimeInterval {
        return localTime + serverOffset
    }

    /// Current local time
    public var localTime: TimeInterval {
        return CACurrentMediaTime()
    }

    /// Offset from server time
    @Published public private(set) var serverOffset: TimeInterval = 0

    /// Round-trip time
    @Published public private(set) var roundTripTime: TimeInterval = 0

    /// Sync accuracy
    @Published public private(set) var accuracy: SyncAccuracy = .unknown

    public enum SyncAccuracy: String {
        case unknown = "Unknown"
        case poor = "Poor (>50ms)"
        case fair = "Fair (20-50ms)"
        case good = "Good (5-20ms)"
        case excellent = "Excellent (<5ms)"
    }

    // Internal
    private var syncSamples: [TimeSyncSample] = []
    private let maxSamples: Int = 20
    private var syncTimer: Timer?

    private struct TimeSyncSample {
        let localSendTime: TimeInterval
        let serverTime: TimeInterval
        let localReceiveTime: TimeInterval
        var rtt: TimeInterval { localReceiveTime - localSendTime }
        var offset: TimeInterval { serverTime - (localSendTime + localReceiveTime) / 2 }
    }

    private init() {}

    /// Start time synchronization
    public func startSync(interval: TimeInterval = 5.0) {
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performSync()
        }
        performSync()
    }

    /// Stop synchronization
    public func stopSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Record sync response
    public func recordSyncResponse(localSendTime: TimeInterval, serverTime: TimeInterval) {
        let sample = TimeSyncSample(
            localSendTime: localSendTime,
            serverTime: serverTime,
            localReceiveTime: localTime
        )

        syncSamples.append(sample)
        if syncSamples.count > maxSamples {
            syncSamples.removeFirst()
        }

        // Calculate offset using best samples (lowest RTT)
        let sortedSamples = syncSamples.sorted { $0.rtt < $1.rtt }
        let bestSamples = Array(sortedSamples.prefix(5))

        if !bestSamples.isEmpty {
            serverOffset = bestSamples.map { $0.offset }.reduce(0, +) / Double(bestSamples.count)
            roundTripTime = bestSamples.map { $0.rtt }.reduce(0, +) / Double(bestSamples.count)

            // Update accuracy
            if roundTripTime < 0.005 {
                accuracy = .excellent
            } else if roundTripTime < 0.020 {
                accuracy = .good
            } else if roundTripTime < 0.050 {
                accuracy = .fair
            } else {
                accuracy = .poor
            }
        }
    }

    private func performSync() {
        // Trigger sync request (actual implementation depends on connection)
        NotificationCenter.default.post(name: .timeSyncRequest, object: localTime)
    }
}

extension Notification.Name {
    static let timeSyncRequest = Notification.Name("com.echoelmusic.timeSyncRequest")
}

// MARK: - Latency Compensator

/// Compensates for network latency in sync operations
public final class LatencyCompensator {

    public static let shared = LatencyCompensator()

    /// Prediction window (how far ahead to predict)
    public var predictionWindow: TimeInterval = 0.1  // 100ms

    /// Smoothing factor for latency estimates
    public var smoothingFactor: Float = 0.3

    // State
    private var participantStates: [String: CompensatedState] = [:]
    private var latencyEstimates: [String: TimeInterval] = [:]

    private struct CompensatedState {
        var position: simd_float3
        var velocity: simd_float3
        var lastUpdate: TimeInterval
        var predictedPosition: simd_float3
    }

    private init() {}

    /// Update participant state with latency compensation
    public func updateState(
        participantId: String,
        position: simd_float3,
        velocity: simd_float3,
        sentTime: TimeInterval,
        receivedTime: TimeInterval
    ) {
        let latency = receivedTime - sentTime

        // Smooth latency estimate
        if let existingLatency = latencyEstimates[participantId] {
            latencyEstimates[participantId] = TimeInterval(smoothingFactor) * latency +
                TimeInterval(1 - smoothingFactor) * existingLatency
        } else {
            latencyEstimates[participantId] = latency
        }

        // Compensate position for latency
        let compensatedLatency = latencyEstimates[participantId] ?? latency
        let compensatedPosition = position + velocity * Float(compensatedLatency)

        // Predict future position
        let predictedPosition = compensatedPosition + velocity * Float(predictionWindow)

        participantStates[participantId] = CompensatedState(
            position: compensatedPosition,
            velocity: velocity,
            lastUpdate: receivedTime,
            predictedPosition: predictedPosition
        )
    }

    /// Get interpolated position at current time
    public func getInterpolatedPosition(participantId: String, at time: TimeInterval) -> simd_float3? {
        guard let state = participantStates[participantId] else { return nil }

        let elapsed = Float(time - state.lastUpdate)
        return state.position + state.velocity * elapsed
    }

    /// Get predicted position
    public func getPredictedPosition(participantId: String) -> simd_float3? {
        return participantStates[participantId]?.predictedPosition
    }

    /// Get estimated latency for participant
    public func getLatency(participantId: String) -> TimeInterval? {
        return latencyEstimates[participantId]
    }
}

// MARK: - Conflict Resolution

/// CRDT-based conflict resolution for collaborative state
public final class ConflictResolver {

    public static let shared = ConflictResolver()

    /// Conflict resolution strategy
    public enum Strategy {
        case lastWriteWins      // Timestamp-based
        case hostPriority       // Host always wins
        case merge              // Attempt to merge changes
        case custom((Any, Any) -> Any)
    }

    public var defaultStrategy: Strategy = .lastWriteWins

    // Vector clocks for causality tracking
    private var vectorClocks: [String: [String: UInt64]] = [:]

    // LWW-Register for simple values
    private var lwwRegisters: [String: LWWRegister] = [:]

    private struct LWWRegister {
        var value: Any
        var timestamp: TimeInterval
        var participantId: String
    }

    private init() {}

    // MARK: - Vector Clock Operations

    /// Increment local vector clock
    public func incrementClock(participantId: String, key: String) {
        if vectorClocks[key] == nil {
            vectorClocks[key] = [:]
        }
        vectorClocks[key]![participantId, default: 0] += 1
    }

    /// Merge vector clocks
    public func mergeClock(key: String, remoteClock: [String: UInt64]) {
        if vectorClocks[key] == nil {
            vectorClocks[key] = remoteClock
            return
        }

        for (participant, count) in remoteClock {
            vectorClocks[key]![participant] = max(
                vectorClocks[key]![participant, default: 0],
                count
            )
        }
    }

    /// Check if clock A happened before clock B
    public func happenedBefore(_ clockA: [String: UInt64], _ clockB: [String: UInt64]) -> Bool {
        var atLeastOneLess = false

        for (participant, countB) in clockB {
            let countA = clockA[participant, default: 0]
            if countA > countB { return false }
            if countA < countB { atLeastOneLess = true }
        }

        for (participant, _) in clockA {
            if clockB[participant] == nil { return false }
        }

        return atLeastOneLess
    }

    // MARK: - LWW Register Operations

    /// Set value with last-write-wins semantics
    public func setValue(
        _ value: Any,
        forKey key: String,
        participantId: String,
        timestamp: TimeInterval
    ) -> Bool {
        if let existing = lwwRegisters[key] {
            if timestamp > existing.timestamp {
                lwwRegisters[key] = LWWRegister(
                    value: value,
                    timestamp: timestamp,
                    participantId: participantId
                )
                return true
            }
            return false  // Older value, rejected
        }

        lwwRegisters[key] = LWWRegister(
            value: value,
            timestamp: timestamp,
            participantId: participantId
        )
        return true
    }

    /// Get current value
    public func getValue(forKey key: String) -> Any? {
        return lwwRegisters[key]?.value
    }

    // MARK: - Custom Merge Operations

    /// Resolve conflict between two values
    public func resolve(
        local: Any,
        remote: Any,
        localTime: TimeInterval,
        remoteTime: TimeInterval,
        remoteParticipantId: String,
        isHost: Bool,
        strategy: Strategy? = nil
    ) -> Any {
        let activeStrategy = strategy ?? defaultStrategy

        switch activeStrategy {
        case .lastWriteWins:
            return remoteTime > localTime ? remote : local

        case .hostPriority:
            return isHost ? remote : local

        case .merge:
            return mergeValues(local, remote)

        case .custom(let resolver):
            return resolver(local, remote)
        }
    }

    /// Attempt to merge two values
    private func mergeValues(_ a: Any, _ b: Any) -> Any {
        // Merge arrays
        if let arrayA = a as? [Any], let arrayB = b as? [Any] {
            return arrayA + arrayB
        }

        // Merge dictionaries
        if var dictA = a as? [String: Any], let dictB = b as? [String: Any] {
            for (key, value) in dictB {
                if let existingValue = dictA[key] {
                    dictA[key] = mergeValues(existingValue, value)
                } else {
                    dictA[key] = value
                }
            }
            return dictA
        }

        // Numeric average
        if let numA = a as? Float, let numB = b as? Float {
            return (numA + numB) / 2
        }

        // Default to newer (b)
        return b
    }
}

// MARK: - Visual State Sync

/// Synchronizes visual state across participants
public final class VisualStateSync {

    public static let shared = VisualStateSync()

    /// Visual state snapshot
    public struct VisualState: Codable, Sendable {
        public var colorPalette: [UInt32]          // RGBA colors
        public var particleConfig: ParticleConfig
        public var shaderParams: [String: Float]
        public var cameraPosition: SIMD3<Float>
        public var cameraRotation: SIMD4<Float>
        public var qualityTier: Int
        public var timestamp: TimeInterval
    }

    public struct ParticleConfig: Codable, Sendable {
        public var count: Int
        public var size: Float
        public var speed: Float
        public var colorMode: Int
        public var emitterType: Int
    }

    /// Current synced visual state
    @Published public private(set) var syncedState: VisualState?

    /// Local pending state
    private var pendingState: VisualState?

    /// Delta encoding for bandwidth efficiency
    public var useDeltaEncoding: Bool = true

    /// Sync interval
    public var syncInterval: TimeInterval = 1.0 / 15.0  // 15 Hz visual sync

    // State tracking
    private var lastSentState: VisualState?
    private var syncTimer: Timer?

    private init() {}

    /// Start visual sync
    public func startSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            self?.syncVisualState()
        }
    }

    /// Stop sync
    public func stopSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Update local visual state
    public func updateLocalState(_ state: VisualState) {
        pendingState = state
    }

    /// Receive remote visual state
    public func receiveRemoteState(_ state: VisualState) {
        // Apply with interpolation
        if let current = syncedState {
            syncedState = interpolateStates(from: current, to: state, factor: 0.3)
        } else {
            syncedState = state
        }
    }

    /// Encode state delta
    public func encodeDelta(from oldState: VisualState?, to newState: VisualState) -> Data? {
        guard useDeltaEncoding, let old = oldState else {
            return try? JSONEncoder().encode(newState)
        }

        var delta = StateDelta()

        // Check color palette changes
        if old.colorPalette != newState.colorPalette {
            delta.colorPalette = newState.colorPalette
        }

        // Check particle config changes
        if old.particleConfig.count != newState.particleConfig.count ||
           old.particleConfig.size != newState.particleConfig.size {
            delta.particleConfig = newState.particleConfig
        }

        // Check shader params (only changed values)
        var changedParams: [String: Float] = [:]
        for (key, value) in newState.shaderParams {
            if old.shaderParams[key] != value {
                changedParams[key] = value
            }
        }
        if !changedParams.isEmpty {
            delta.shaderParams = changedParams
        }

        // Camera (quantized delta)
        let posDelta = newState.cameraPosition - old.cameraPosition
        if simd_length(posDelta) > 0.001 {
            delta.cameraPosition = newState.cameraPosition
        }

        delta.timestamp = newState.timestamp

        return try? JSONEncoder().encode(delta)
    }

    private struct StateDelta: Codable {
        var colorPalette: [UInt32]?
        var particleConfig: ParticleConfig?
        var shaderParams: [String: Float]?
        var cameraPosition: SIMD3<Float>?
        var cameraRotation: SIMD4<Float>?
        var timestamp: TimeInterval = 0
    }

    private func syncVisualState() {
        guard let state = pendingState else { return }

        // Check if state changed significantly
        if let last = lastSentState, !stateChangedSignificantly(last, state) {
            return
        }

        // Encode and send
        if let data = encodeDelta(from: lastSentState, to: state) {
            NotificationCenter.default.post(
                name: .visualStateSyncSend,
                object: data
            )
            lastSentState = state
        }
    }

    private func stateChangedSignificantly(_ a: VisualState, _ b: VisualState) -> Bool {
        // Camera moved
        if simd_length(a.cameraPosition - b.cameraPosition) > 0.01 { return true }

        // Colors changed
        if a.colorPalette != b.colorPalette { return true }

        // Particles changed
        if a.particleConfig.count != b.particleConfig.count { return true }

        return false
    }

    private func interpolateStates(from a: VisualState, to b: VisualState, factor: Float) -> VisualState {
        var result = b
        result.cameraPosition = simd_mix(a.cameraPosition, b.cameraPosition, SIMD3<Float>(repeating: factor))
        return result
    }
}

extension Notification.Name {
    static let visualStateSyncSend = Notification.Name("com.echoelmusic.visualStateSyncSend")
}

// MARK: - Audio Timeline Sync

/// Synchronizes audio playback across participants
public final class AudioTimelineSync {

    public static let shared = AudioTimelineSync()

    /// Timeline state
    public struct TimelineState: Codable, Sendable {
        public var trackId: String
        public var position: TimeInterval       // Playback position
        public var tempo: Float                 // BPM
        public var beatPosition: Float          // Beat count
        public var isPlaying: Bool
        public var masterTimestamp: TimeInterval
    }

    /// Current synced timeline
    @Published public private(set) var timeline: TimelineState?

    /// Local playback offset from master
    @Published public private(set) var playbackOffset: TimeInterval = 0

    /// Sync quality
    @Published public private(set) var syncQuality: SyncQuality = .unknown

    public enum SyncQuality: String {
        case unknown = "Unknown"
        case poor = "Poor"
        case acceptable = "Acceptable"
        case good = "Good"
        case tight = "Tight"
    }

    // Internal
    private var targetOffset: TimeInterval = 0
    private var offsetSamples: [TimeInterval] = []

    private init() {}

    /// Update from master timeline
    public func receiveTimelineUpdate(_ state: TimelineState) {
        let networkTime = NetworkTimeSync.shared.serverTime
        let latency = networkTime - state.masterTimestamp

        // Calculate expected position now
        let expectedPosition = state.position + latency

        // Store timeline
        timeline = state

        // Calculate offset from local playback
        if let localPosition = getLocalPlaybackPosition() {
            let offset = expectedPosition - localPosition
            offsetSamples.append(offset)
            if offsetSamples.count > 10 {
                offsetSamples.removeFirst()
            }

            // Use median offset (robust to outliers)
            let sorted = offsetSamples.sorted()
            playbackOffset = sorted[sorted.count / 2]

            // Update sync quality
            let absOffset = abs(playbackOffset)
            if absOffset < 0.005 {
                syncQuality = .tight
            } else if absOffset < 0.020 {
                syncQuality = .good
            } else if absOffset < 0.050 {
                syncQuality = .acceptable
            } else {
                syncQuality = .poor
            }
        }
    }

    /// Get local playback position (override with actual player position)
    private func getLocalPlaybackPosition() -> TimeInterval? {
        // Placeholder - integrate with actual audio player
        return timeline?.position
    }

    /// Calculate beat-aligned sync point
    public func getNextBeatSyncPoint(beatsAhead: Int = 1) -> TimeInterval? {
        guard let tl = timeline, tl.tempo > 0 else { return nil }

        let beatDuration = 60.0 / Double(tl.tempo)
        let currentBeat = floor(Double(tl.beatPosition))
        let targetBeat = currentBeat + Double(beatsAhead)
        let beatsTilTarget = targetBeat - Double(tl.beatPosition)

        return NetworkTimeSync.shared.serverTime + beatsTilTarget * beatDuration
    }

    /// Generate timeline broadcast message
    public func createTimelineBroadcast(
        trackId: String,
        position: TimeInterval,
        tempo: Float,
        beatPosition: Float,
        isPlaying: Bool
    ) -> TimelineState {
        return TimelineState(
            trackId: trackId,
            position: position,
            tempo: tempo,
            beatPosition: beatPosition,
            isPlaying: isPlaying,
            masterTimestamp: NetworkTimeSync.shared.serverTime
        )
    }
}

// MARK: - Bandwidth Adaptive Streaming

/// Adapts sync quality based on available bandwidth
public final class AdaptiveSyncManager {

    public static let shared = AdaptiveSyncManager()

    /// Current bandwidth tier
    @Published public private(set) var bandwidthTier: BandwidthTier = .good

    public enum BandwidthTier: Int {
        case critical = 0   // < 50 kbps - minimal sync
        case poor = 1       // 50-200 kbps - basic sync
        case fair = 2       // 200-500 kbps - reduced sync
        case good = 3       // 500+ kbps - full sync
    }

    /// Sync rates by tier
    public struct SyncRates {
        public var bioSyncRate: TimeInterval
        public var visualSyncRate: TimeInterval
        public var audioSyncRate: TimeInterval
        public var parameterSyncRate: TimeInterval
    }

    /// Get current sync rates
    public var currentRates: SyncRates {
        switch bandwidthTier {
        case .critical:
            return SyncRates(
                bioSyncRate: 2.0,       // Every 2 seconds
                visualSyncRate: 0,      // Disabled
                audioSyncRate: 1.0,     // Every second
                parameterSyncRate: 1.0
            )
        case .poor:
            return SyncRates(
                bioSyncRate: 0.5,
                visualSyncRate: 0.5,
                audioSyncRate: 0.25,
                parameterSyncRate: 0.5
            )
        case .fair:
            return SyncRates(
                bioSyncRate: 0.2,
                visualSyncRate: 0.1,
                audioSyncRate: 0.1,
                parameterSyncRate: 0.2
            )
        case .good:
            return SyncRates(
                bioSyncRate: 0.1,
                visualSyncRate: 1.0/15.0,
                audioSyncRate: 0.05,
                parameterSyncRate: 0.1
            )
        }
    }

    // Bandwidth measurement
    private var bytesSent: Int = 0
    private var bytesReceived: Int = 0
    private var measurementStart: TimeInterval = 0
    private var bandwidthSamples: [Float] = []

    private init() {
        measurementStart = CACurrentMediaTime()
    }

    /// Record bytes sent/received
    public func recordTraffic(sent: Int, received: Int) {
        bytesSent += sent
        bytesReceived += received

        // Calculate bandwidth every second
        let elapsed = CACurrentMediaTime() - measurementStart
        if elapsed >= 1.0 {
            let totalBytes = bytesSent + bytesReceived
            let kbps = Float(totalBytes) * 8 / Float(elapsed) / 1000

            bandwidthSamples.append(kbps)
            if bandwidthSamples.count > 10 {
                bandwidthSamples.removeFirst()
            }

            // Use minimum recent bandwidth (conservative)
            let minBandwidth = bandwidthSamples.min() ?? kbps

            // Update tier
            if minBandwidth < 50 {
                bandwidthTier = .critical
            } else if minBandwidth < 200 {
                bandwidthTier = .poor
            } else if minBandwidth < 500 {
                bandwidthTier = .fair
            } else {
                bandwidthTier = .good
            }

            // Reset counters
            bytesSent = 0
            bytesReceived = 0
            measurementStart = CACurrentMediaTime()
        }
    }

    /// Should sync this type at current time?
    public func shouldSync(
        type: SyncType,
        lastSyncTime: TimeInterval,
        currentTime: TimeInterval
    ) -> Bool {
        let rates = currentRates
        let interval: TimeInterval

        switch type {
        case .bio: interval = rates.bioSyncRate
        case .visual: interval = rates.visualSyncRate
        case .audio: interval = rates.audioSyncRate
        case .parameter: interval = rates.parameterSyncRate
        }

        return interval > 0 && (currentTime - lastSyncTime) >= interval
    }

    public enum SyncType {
        case bio
        case visual
        case audio
        case parameter
    }
}

// MARK: - Sync Message Compression

/// Compresses sync messages for bandwidth efficiency
public final class SyncCompressor {

    public static let shared = SyncCompressor()

    /// Compression level
    public var compressionLevel: CompressionLevel = .balanced

    public enum CompressionLevel {
        case none           // No compression
        case fast           // LZ4-style fast compression
        case balanced       // Standard compression
        case maximum        // Maximum compression
    }

    private init() {}

    /// Compress data
    public func compress(_ data: Data) -> Data {
        guard compressionLevel != .none else { return data }

        // Use built-in compression
        let algorithm: NSData.CompressionAlgorithm
        switch compressionLevel {
        case .none:
            return data
        case .fast:
            algorithm = .lz4
        case .balanced:
            algorithm = .lzfse
        case .maximum:
            algorithm = .lzma
        }

        return (data as NSData).compressed(using: algorithm) as Data? ?? data
    }

    /// Decompress data
    public func decompress(_ data: Data) -> Data {
        // Try each algorithm
        for algorithm: NSData.CompressionAlgorithm in [.lz4, .lzfse, .lzma] {
            if let decompressed = (data as NSData).decompressed(using: algorithm) as Data? {
                return decompressed
            }
        }
        return data  // Assume uncompressed
    }

    /// Quantize float for reduced precision
    public func quantize(_ value: Float, bits: Int) -> UInt16 {
        let maxVal = Float((1 << bits) - 1)
        let clamped = max(0, min(1, value))
        return UInt16(clamped * maxVal)
    }

    /// Dequantize float
    public func dequantize(_ value: UInt16, bits: Int) -> Float {
        let maxVal = Float((1 << bits) - 1)
        return Float(value) / maxVal
    }
}

// MARK: - Sync Protocol Coordinator

/// Coordinates all sync protocols
public final class SyncProtocolCoordinator {

    public static let shared = SyncProtocolCoordinator()

    /// Protocol components
    public let timeSync = NetworkTimeSync.shared
    public let latencyCompensator = LatencyCompensator.shared
    public let conflictResolver = ConflictResolver.shared
    public let visualSync = VisualStateSync.shared
    public let audioSync = AudioTimelineSync.shared
    public let adaptiveManager = AdaptiveSyncManager.shared
    public let compressor = SyncCompressor.shared

    /// Overall sync status
    @Published public private(set) var syncStatus: SyncStatus = .disconnected

    public enum SyncStatus {
        case disconnected
        case connecting
        case syncing
        case synchronized
        case degraded
    }

    private var lastSyncTimes: [AdaptiveSyncManager.SyncType: TimeInterval] = [:]

    private init() {
        setupCallbacks()
    }

    /// Start all sync protocols
    public func startAllSync() {
        syncStatus = .connecting

        timeSync.startSync()
        visualSync.startSync()

        syncStatus = .syncing
    }

    /// Stop all sync protocols
    public func stopAllSync() {
        timeSync.stopSync()
        visualSync.stopSync()

        syncStatus = .disconnected
    }

    /// Process incoming sync message
    public func processIncomingMessage(type: String, data: Data, senderId: String, timestamp: TimeInterval) {
        // Decompress if needed
        let decompressed = compressor.decompress(data)

        // Record traffic
        adaptiveManager.recordTraffic(sent: 0, received: data.count)

        // Route to appropriate handler
        switch type {
        case "time_sync":
            handleTimeSync(decompressed, timestamp: timestamp)
        case "visual":
            handleVisualSync(decompressed)
        case "audio":
            handleAudioSync(decompressed)
        case "bio":
            handleBioSync(decompressed, senderId: senderId, timestamp: timestamp)
        default:
            break
        }
    }

    /// Create outgoing sync message
    public func createOutgoingMessage(
        type: AdaptiveSyncManager.SyncType,
        data: Data
    ) -> Data? {
        let currentTime = CACurrentMediaTime()
        let lastTime = lastSyncTimes[type] ?? 0

        // Check if we should sync based on bandwidth
        guard adaptiveManager.shouldSync(type: type, lastSyncTime: lastTime, currentTime: currentTime) else {
            return nil
        }

        lastSyncTimes[type] = currentTime

        // Compress and return
        let compressed = compressor.compress(data)
        adaptiveManager.recordTraffic(sent: compressed.count, received: 0)

        return compressed
    }

    private func setupCallbacks() {
        // Listen for time sync requests
        NotificationCenter.default.addObserver(
            forName: .timeSyncRequest,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleTimeSyncRequest(notification)
        }

        // Listen for visual state sends
        NotificationCenter.default.addObserver(
            forName: .visualStateSyncSend,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleVisualStateSend(notification)
        }
    }

    private func handleTimeSync(_ data: Data, timestamp: TimeInterval) {
        if let response = try? JSONDecoder().decode(TimeSyncResponse.self, from: data) {
            timeSync.recordSyncResponse(
                localSendTime: response.requestTimestamp,
                serverTime: response.serverTimestamp
            )

            // Update sync status based on accuracy
            switch timeSync.accuracy {
            case .excellent, .good:
                if syncStatus == .syncing {
                    syncStatus = .synchronized
                }
            case .fair:
                syncStatus = .syncing
            case .poor, .unknown:
                syncStatus = .degraded
            }
        }
    }

    private struct TimeSyncResponse: Codable {
        let requestTimestamp: TimeInterval
        let serverTimestamp: TimeInterval
    }

    private func handleVisualSync(_ data: Data) {
        if let state = try? JSONDecoder().decode(VisualStateSync.VisualState.self, from: data) {
            visualSync.receiveRemoteState(state)
        }
    }

    private func handleAudioSync(_ data: Data) {
        if let state = try? JSONDecoder().decode(AudioTimelineSync.TimelineState.self, from: data) {
            audioSync.receiveTimelineUpdate(state)
        }
    }

    private func handleBioSync(_ data: Data, senderId: String, timestamp: TimeInterval) {
        // Bio state handled by EchoelSync directly
    }

    private func handleTimeSyncRequest(_ notification: Notification) {
        // Actual implementation depends on connection layer
    }

    private func handleVisualStateSend(_ notification: Notification) {
        // Actual implementation depends on connection layer
    }
}

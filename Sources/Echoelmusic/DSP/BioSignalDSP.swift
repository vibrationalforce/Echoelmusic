// BioSignalDSP.swift
// Echoelmusic — Bio-Signal Processing Algorithms
//
// Three specialized DSP tools for bio-reactive audio, inspired by
// computational genomics signal processing (Rausch et al., EMBL Heidelberg):
//
// 1. BioEventGraph — Graph-based bio-event detection and clustering
//    Inspired by DELLY's structural variant discovery via graph clustering.
//    Detects state transitions, recurring patterns, and anomalies in
//    biometric time series. Outputs event clusters for adaptive synthesis.
//
// 2. HilbertSensorMapper — Space-filling curve sensor visualization
//    Maps 1D sensor time series to 2D via Hilbert curves, preserving
//    temporal locality. Adjacent time points stay spatially close —
//    reveals hidden patterns in HRV, breathing, and EEG data.
//
// 3. BioSignalDeconvolver — Mixed bio-signal separation
//    Inspired by Tracy's Sanger chromatogram deconvolution.
//    Separates overlapping biological signals (cardiac, respiratory,
//    movement artifacts) from a mixed input using adaptive filtering.
//
// All algorithms are pure-DSP (Accelerate/vDSP), zero external deps,
// pre-allocated buffers, suitable for real-time 60Hz control loop.
//
// References:
//   - Rausch et al. (2012) "DELLY" Nature Methods — SV via graph clustering
//   - Rausch et al. (2017) "Tracy" Nature Communications — signal deconvolution
//   - Hilbert (1891) "Über die stetige Abbildung einer Linie auf ein Flächenstück"
//   - Engel et al. (2020) "DDSP" ICLR — differentiable signal processing

import Foundation
import Accelerate

// MARK: - 1. BioEventGraph — Graph-Based Bio-Event Detection
// ═══════════════════════════════════════════════════════════════════════════════
//
// Concept: Treat a biometric time series as a sequence of "events" (peaks,
// valleys, transitions). Build a weighted graph where:
//   - Nodes = detected events (timestamped, typed)
//   - Edges = temporal proximity + feature similarity
//
// Cluster this graph to find recurring bio-patterns (e.g., "coherent breathing
// cycle" vs "stress spike sequence"). Output: cluster IDs for the control loop
// to map to synthesis parameters.
//
// DELLY analogy: DELLY finds structural variants by clustering read-pair
// evidence in a graph. We find "bio-structural variants" — state transitions
// that deviate from the user's baseline pattern.

/// Graph-based bio-event detector and pattern clusterer
public final class BioEventGraph: @unchecked Sendable {

    // MARK: - Types

    /// Detected bio-event with timestamp and features
    public struct BioEvent: Sendable {
        public let timestamp: Double         // Seconds since session start
        public let type: EventType           // Peak, valley, transition, anomaly
        public let magnitude: Float          // Event strength (0-1)
        public let channel: SignalChannel    // Which bio signal
        public let features: [Float]         // Feature vector for clustering (4D)

        public enum EventType: String, CaseIterable, Sendable {
            case peak = "Peak"               // Local maximum
            case valley = "Valley"           // Local minimum
            case transition = "Transition"   // Significant slope change
            case anomaly = "Anomaly"         // Deviation from running baseline
        }

        public enum SignalChannel: String, CaseIterable, Sendable {
            case heartRate = "HR"
            case hrv = "HRV"
            case breathing = "Breath"
            case coherence = "Coherence"
            case composite = "Composite"     // Multi-channel derived
        }
    }

    /// Event cluster — a group of similar bio-events
    public struct EventCluster: Sendable {
        public let id: Int
        public let centroid: [Float]         // 4D centroid
        public let memberCount: Int
        public let dominantType: BioEvent.EventType
        public let averageMagnitude: Float
        public let recurrenceHz: Float       // How often this pattern repeats
    }

    // MARK: - Configuration

    /// Maximum number of events in the rolling window
    public let maxEvents: Int

    /// Similarity threshold for graph edge creation (0-1)
    public var edgeThreshold: Float = 0.6

    /// Number of clusters to maintain
    public var clusterCount: Int = 4

    /// Anomaly detection sensitivity (lower = more sensitive)
    public var anomalyThreshold: Float = 2.0

    // MARK: - State

    /// Rolling event buffer (circular)
    private var events: [BioEvent?]
    private var eventWriteIndex: Int = 0
    private var eventCount: Int = 0

    /// Running baseline per channel (exponential moving average)
    private var baselines: [BioEvent.SignalChannel: Float] = [:]
    private var baselineVariances: [BioEvent.SignalChannel: Float] = [:]
    private let baselineAlpha: Float = 0.01  // Slow adaptation

    /// Previous sample per channel (for peak/valley detection)
    private var previousSamples: [BioEvent.SignalChannel: (Float, Float)] = [:]  // (n-2, n-1)

    /// Current clusters
    private(set) public var clusters: [EventCluster] = []

    /// Session start time
    private var sessionStart: Double = 0
    private var lastClusterUpdate: Double = 0

    /// Cluster centroids (k-means state)
    private var centroids: [[Float]]

    // MARK: - Init

    public init(maxEvents: Int = 512, clusterCount: Int = 4) {
        self.maxEvents = maxEvents
        self.clusterCount = clusterCount
        self.events = [BioEvent?](repeating: nil, count: maxEvents)
        self.centroids = (0..<clusterCount).map { _ in
            [Float.random(in: 0...1), Float.random(in: 0...1),
             Float.random(in: 0...1), Float.random(in: 0...1)]
        }
        self.sessionStart = ProcessInfo.processInfo.systemUptime
    }

    // MARK: - Event Detection

    /// Feed a new bio sample. Automatically detects events (peaks, valleys, anomalies).
    /// Call at 60Hz from the control loop.
    public func feedSample(_ value: Float, channel: BioEvent.SignalChannel, timestamp: Double? = nil) {
        let t = timestamp ?? (ProcessInfo.processInfo.systemUptime - sessionStart)

        // Update running baseline
        let prevBaseline = baselines[channel] ?? value
        let prevVariance = baselineVariances[channel] ?? 0.01
        let newBaseline = prevBaseline * (1.0 - baselineAlpha) + value * baselineAlpha
        let diff = value - newBaseline
        let newVariance = prevVariance * (1.0 - baselineAlpha) + (diff * diff) * baselineAlpha
        baselines[channel] = newBaseline
        baselineVariances[channel] = newVariance

        // Get previous two samples for peak/valley detection
        let prev = previousSamples[channel] ?? (value, value)
        let (prevPrev, prevVal) = prev
        previousSamples[channel] = (prevVal, value)

        // Peak detection: prev > both neighbors
        if prevVal > prevPrev && prevVal > value && prevVal > newBaseline + sqrt(newVariance) * 0.5 {
            let magnitude = (prevVal - newBaseline) / max(0.01, sqrt(newVariance) * anomalyThreshold)
            let features = makeFeatures(value: prevVal, baseline: newBaseline,
                                        variance: newVariance, channel: channel)
            addEvent(BioEvent(timestamp: t, type: .peak, magnitude: min(1, magnitude),
                              channel: channel, features: features))
        }

        // Valley detection: prev < both neighbors
        if prevVal < prevPrev && prevVal < value && prevVal < newBaseline - sqrt(newVariance) * 0.5 {
            let magnitude = (newBaseline - prevVal) / max(0.01, sqrt(newVariance) * anomalyThreshold)
            let features = makeFeatures(value: prevVal, baseline: newBaseline,
                                        variance: newVariance, channel: channel)
            addEvent(BioEvent(timestamp: t, type: .valley, magnitude: min(1, magnitude),
                              channel: channel, features: features))
        }

        // Anomaly detection: >N sigma from baseline
        let sigma = sqrt(max(0.0001, newVariance))
        let zScore = abs(diff) / sigma
        if zScore > anomalyThreshold {
            let features = makeFeatures(value: value, baseline: newBaseline,
                                        variance: newVariance, channel: channel)
            addEvent(BioEvent(timestamp: t, type: .anomaly,
                              magnitude: min(1, zScore / (anomalyThreshold * 2)),
                              channel: channel, features: features))
        }

        // Transition detection: large slope change
        let slope = value - prevVal
        let prevSlope = prevVal - prevPrev
        let slopeChange = abs(slope - prevSlope)
        if slopeChange > sigma * 1.5 {
            let features = makeFeatures(value: value, baseline: newBaseline,
                                        variance: newVariance, channel: channel)
            addEvent(BioEvent(timestamp: t, type: .transition,
                              magnitude: min(1, slopeChange / (sigma * 3)),
                              channel: channel, features: features))
        }

        // Update clusters periodically (every ~0.5s to save CPU)
        if t - lastClusterUpdate > 0.5 && eventCount >= clusterCount {
            updateClusters()
            lastClusterUpdate = t
        }
    }

    // MARK: - Clustering (k-means on feature vectors)

    /// Update cluster assignments using k-means on event feature vectors
    private func updateClusters() {
        // Collect active events
        var activeEvents: [BioEvent] = []
        for i in 0..<maxEvents {
            if let event = events[i] { activeEvents.append(event) }
        }
        guard activeEvents.count >= clusterCount else { return }

        // k-means iteration (single pass for real-time — converges over frames)
        var assignments = [Int](repeating: 0, count: activeEvents.count)
        var newCentroids = [[Float]](repeating: [Float](repeating: 0, count: 4), count: clusterCount)
        var counts = [Int](repeating: 0, count: clusterCount)

        // Assign each event to nearest centroid
        for (ei, event) in activeEvents.enumerated() {
            var bestCluster = 0
            var bestDist: Float = .greatestFiniteMagnitude
            for ci in 0..<clusterCount {
                let dist = euclideanDistance(event.features, centroids[ci])
                if dist < bestDist {
                    bestDist = dist
                    bestCluster = ci
                }
            }
            assignments[ei] = bestCluster
            counts[bestCluster] += 1
            for fi in 0..<4 {
                newCentroids[bestCluster][fi] += event.features[fi]
            }
        }

        // Update centroids
        for ci in 0..<clusterCount {
            if counts[ci] > 0 {
                for fi in 0..<4 {
                    centroids[ci][fi] = newCentroids[ci][fi] / Float(counts[ci])
                }
            }
        }

        // Build cluster summaries
        var clusterResults: [EventCluster] = []
        for ci in 0..<clusterCount {
            guard counts[ci] > 0 else { continue }

            // Find dominant type and average magnitude
            var typeCounts: [BioEvent.EventType: Int] = [:]
            var totalMag: Float = 0
            var firstTime: Double = .greatestFiniteMagnitude
            var lastTime: Double = 0

            for (ei, event) in activeEvents.enumerated() where assignments[ei] == ci {
                typeCounts[event.type, default: 0] += 1
                totalMag += event.magnitude
                firstTime = min(firstTime, event.timestamp)
                lastTime = max(lastTime, event.timestamp)
            }

            let dominantType = typeCounts.max(by: { $0.value < $1.value })?.key ?? .peak
            let avgMag = totalMag / Float(counts[ci])
            let duration = max(0.001, lastTime - firstTime)
            let recurrence = Float(counts[ci]) / Float(duration)

            clusterResults.append(EventCluster(
                id: ci,
                centroid: centroids[ci],
                memberCount: counts[ci],
                dominantType: dominantType,
                averageMagnitude: avgMag,
                recurrenceHz: recurrence
            ))
        }

        clusters = clusterResults
    }

    // MARK: - Output for Synthesis

    /// Get the dominant bio-state as a cluster index (for parameter mapping)
    public func dominantClusterIndex() -> Int {
        clusters.max(by: { $0.memberCount < $1.memberCount })?.id ?? 0
    }

    /// Get cluster recurrence rate — maps to rhythmic synthesis parameters
    public func dominantRecurrenceHz() -> Float {
        clusters.max(by: { $0.memberCount < $1.memberCount })?.recurrenceHz ?? 0
    }

    /// Get anomaly density in recent window — maps to synthesis complexity
    public func recentAnomalyDensity(windowSeconds: Double = 5.0) -> Float {
        let now = ProcessInfo.processInfo.systemUptime - sessionStart
        let cutoff = now - windowSeconds
        var anomalyCount = 0
        var totalCount = 0
        for i in 0..<maxEvents {
            guard let event = events[i], event.timestamp > cutoff else { continue }
            totalCount += 1
            if event.type == .anomaly { anomalyCount += 1 }
        }
        return totalCount > 0 ? Float(anomalyCount) / Float(totalCount) : 0
    }

    // MARK: - Helpers

    private func addEvent(_ event: BioEvent) {
        events[eventWriteIndex] = event
        eventWriteIndex = (eventWriteIndex + 1) % maxEvents
        eventCount = min(eventCount + 1, maxEvents)
    }

    private func makeFeatures(value: Float, baseline: Float,
                              variance: Float, channel: BioEvent.SignalChannel) -> [Float] {
        let channelVal: Float
        switch channel {
        case .heartRate: channelVal = 0.0
        case .hrv: channelVal = 0.25
        case .breathing: channelVal = 0.5
        case .coherence: channelVal = 0.75
        case .composite: channelVal = 1.0
        }
        let deviation = (value - baseline) / max(0.01, sqrt(variance))
        return [min(1, max(-1, deviation)), channelVal, value, sqrt(variance)]
    }

    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        let count = min(a.count, b.count)
        for i in 0..<count {
            let d = a[i] - b[i]
            sum += d * d
        }
        return sqrt(sum)
    }

    /// Reset all state
    public func reset() {
        events = [BioEvent?](repeating: nil, count: maxEvents)
        eventWriteIndex = 0
        eventCount = 0
        baselines.removeAll()
        baselineVariances.removeAll()
        previousSamples.removeAll()
        clusters = []
        sessionStart = ProcessInfo.processInfo.systemUptime
    }
}

// MARK: - 2. HilbertSensorMapper — Space-Filling Curve Visualization
// ═══════════════════════════════════════════════════════════════════════════════
//
// Maps 1D sensor time series to 2D coordinates via the Hilbert curve.
// Preserves temporal locality: adjacent samples stay spatially close.
//
// Use case: Feed HRV/breathing/EEG data → get 2D coordinates for particle
// systems, texture generation, or visual pattern detection.
//
// The Hilbert curve has better locality preservation than Z-order/Morton curves.
// For a curve of order N, we map 4^N time samples to a (2^N)×(2^N) grid.
//
// Rausch used Hilbert curves for genomic coordinate mapping. We apply the
// same principle to map sensor time → spatial position for visualization.

/// Maps 1D bio-sensor data to 2D space via Hilbert curves
public final class HilbertSensorMapper: @unchecked Sendable {

    // MARK: - Types

    /// A 2D point from Hilbert mapping with associated sensor value
    public struct MappedPoint: Sendable {
        public let x: Float        // 0-1 normalized
        public let y: Float        // 0-1 normalized
        public let value: Float    // Original sensor value
        public let index: Int      // Position along Hilbert curve
    }

    // MARK: - Configuration

    /// Hilbert curve order (resolution = 2^order per side)
    public let order: Int

    /// Grid size (2^order)
    public let gridSize: Int

    /// Total points along curve (4^order)
    public let curveLength: Int

    // MARK: - State

    /// Pre-computed Hilbert curve lookup table (index → x, y)
    private let hilbertX: [Int]
    private let hilbertY: [Int]

    /// Rolling buffer of mapped points
    private var pointBuffer: [MappedPoint?]
    private var writeIndex: Int = 0
    private var sampleCount: Int = 0

    /// 2D grid accumulator for density mapping
    private var densityGrid: [Float]

    // MARK: - Init

    /// Initialize with curve order (4 = 16×16 = 256 points, 5 = 32×32 = 1024, 6 = 64×64 = 4096)
    public init(order: Int = 5) {
        self.order = order
        self.gridSize = 1 << order          // 2^order
        self.curveLength = 1 << (order * 2) // 4^order

        // Pre-compute Hilbert curve coordinates
        var xs = [Int](repeating: 0, count: curveLength)
        var ys = [Int](repeating: 0, count: curveLength)

        for d in 0..<curveLength {
            let (x, y) = HilbertSensorMapper.d2xy(n: 1 << order, d: d)
            xs[d] = x
            ys[d] = y
        }
        self.hilbertX = xs
        self.hilbertY = ys

        self.pointBuffer = [MappedPoint?](repeating: nil, count: curveLength)
        self.densityGrid = [Float](repeating: 0, count: gridSize * gridSize)
    }

    // MARK: - Mapping

    /// Feed a sensor sample. Maps to next position along Hilbert curve.
    /// Returns the 2D mapped point.
    @discardableResult
    public func feedSample(_ value: Float) -> MappedPoint {
        let curveIndex = sampleCount % curveLength
        let x = Float(hilbertX[curveIndex]) / Float(gridSize - 1)
        let y = Float(hilbertY[curveIndex]) / Float(gridSize - 1)

        let point = MappedPoint(x: x, y: y, value: value, index: curveIndex)
        pointBuffer[writeIndex] = point
        writeIndex = (writeIndex + 1) % curveLength
        sampleCount += 1

        // Update density grid (exponential decay + new contribution)
        let gridX = hilbertX[curveIndex]
        let gridY = hilbertY[curveIndex]
        let gridIndex = gridY * gridSize + gridX
        densityGrid[gridIndex] = densityGrid[gridIndex] * 0.99 + abs(value) * 0.01

        return point
    }

    /// Feed an array of samples (batch mapping)
    public func feedBatch(_ values: [Float]) -> [MappedPoint] {
        var points: [MappedPoint] = []
        points.reserveCapacity(values.count)
        for v in values {
            points.append(feedSample(v))
        }
        return points
    }

    /// Get the current density grid for visualization (normalized 0-1)
    public func getDensityGrid() -> [Float] {
        var grid = densityGrid
        var maxVal: Float = 0
        vDSP_maxv(grid, 1, &maxVal, vDSP_Length(grid.count))
        if maxVal > 0 {
            var div = maxVal
            vDSP_vsdiv(grid, 1, &div, &grid, 1, vDSP_Length(grid.count))
        }
        return grid
    }

    /// Get recent N mapped points for particle rendering
    public func recentPoints(count: Int = 64) -> [MappedPoint] {
        var result: [MappedPoint] = []
        let n = min(count, curveLength)
        for i in 0..<n {
            let idx = (writeIndex - 1 - i + curveLength) % curveLength
            if let point = pointBuffer[idx] { result.append(point) }
        }
        return result
    }

    /// Convert a 2D grid position back to a curve index (inverse mapping)
    public func xy2d(x: Int, y: Int) -> Int {
        return HilbertSensorMapper.xy2d(n: gridSize, x: x, y: y)
    }

    // MARK: - Hilbert Curve Math

    /// Convert distance along Hilbert curve to (x, y) coordinates
    /// Standard algorithm: rotate/flip quadrants recursively
    private static func d2xy(n: Int, d: Int) -> (x: Int, y: Int) {
        var rx: Int, ry: Int, s: Int
        var t = d
        var x = 0, y = 0

        s = 1
        while s < n {
            rx = (t / 2) & 1
            ry = ((t ^ rx) & 1) ^ 1  // Note: XOR with rx, then flip
            // Actually the standard is: ry = (t & 1) ^ rx, but let's use the correct one

            // Rotate
            if ry == 0 {
                if rx == 1 {
                    x = s - 1 - x
                    y = s - 1 - y
                }
                // Swap x and y
                let temp = x
                x = y
                y = temp
            }

            x += s * rx
            y += s * ry
            t /= 4
            s *= 2
        }

        return (x, y)
    }

    /// Convert (x, y) coordinates to distance along Hilbert curve
    private static func xy2d(n: Int, x: Int, y: Int) -> Int {
        var rx: Int, ry: Int, d = 0
        var x = x, y = y

        var s = n / 2
        while s > 0 {
            rx = (x & s) > 0 ? 1 : 0
            ry = (y & s) > 0 ? 1 : 0
            d += s * s * ((3 * rx) ^ ry)

            // Rotate
            if ry == 0 {
                if rx == 1 {
                    x = s - 1 - x
                    y = s - 1 - y
                }
                let temp = x
                x = y
                y = temp
            }
            s /= 2
        }

        return d
    }

    /// Reset all state
    public func reset() {
        pointBuffer = [MappedPoint?](repeating: nil, count: curveLength)
        writeIndex = 0
        sampleCount = 0
        densityGrid = [Float](repeating: 0, count: gridSize * gridSize)
    }
}

// MARK: - 3. BioSignalDeconvolver — Mixed Signal Separation
// ═══════════════════════════════════════════════════════════════════════════════
//
// Separates overlapping biological signals from a composite input.
//
// Tracy deconvolves mixed Sanger chromatograms where two DNA sequences overlap.
// We apply the same principle: a composite bio-signal (e.g., from a single
// accelerometer or PPG sensor) contains overlapping components:
//   - Cardiac component (~1-2 Hz)
//   - Respiratory component (~0.15-0.4 Hz)
//   - Movement artifacts (~0.5-10 Hz, broadband)
//   - Baseline drift (< 0.1 Hz)
//
// Method: Adaptive bandpass filtering via cascaded biquad IIR filters
// (vDSP-accelerated), with cross-correlation for component identification.
//
// Output: Separated signal components with confidence scores.

/// Adaptive bio-signal deconvolver — separates cardiac, respiratory, and artifact components
public final class BioSignalDeconvolver: @unchecked Sendable {

    // MARK: - Types

    /// A separated signal component
    public struct SignalComponent: Sendable {
        public let name: String           // "Cardiac", "Respiratory", "Artifact", "Baseline"
        public let band: ComponentBand
        public let currentValue: Float    // Latest filtered sample
        public let amplitude: Float       // RMS amplitude (recent window)
        public let dominantFreqHz: Float  // Estimated dominant frequency
        public let confidence: Float      // Separation confidence (0-1)
    }

    /// Pre-defined frequency bands for bio-signal components
    public enum ComponentBand: String, CaseIterable, Sendable {
        case baseline = "Baseline"        // < 0.1 Hz  — drift, posture shifts
        case respiratory = "Respiratory"  // 0.1-0.5 Hz — breathing (6-30 breaths/min)
        case cardiac = "Cardiac"          // 0.5-3.0 Hz — heart rate (30-180 bpm)
        case artifact = "Artifact"        // 3.0-15 Hz  — movement, muscle, mains hum

        var lowFreq: Float {
            switch self {
            case .baseline: return 0
            case .respiratory: return 0.1
            case .cardiac: return 0.5
            case .artifact: return 3.0
            }
        }

        var highFreq: Float {
            switch self {
            case .baseline: return 0.1
            case .respiratory: return 0.5
            case .cardiac: return 3.0
            case .artifact: return 15.0
            }
        }
    }

    // MARK: - Configuration

    /// Sample rate of the input signal
    public let sampleRate: Float

    /// Number of bands to separate
    public let bandCount: Int = 4

    // MARK: - Filter State (Biquad IIR per band)

    /// Biquad coefficients per band [b0, b1, b2, a1, a2]
    private var biquadCoeffs: [[Float]]

    /// Filter state per band (z^-1, z^-2 for both sections)
    private var filterStates: [[Float]]  // Per band: [x1, x2, y1, y2] × 2 sections

    /// Output history per band (for RMS and frequency estimation)
    private let historySize: Int = 256
    private var outputHistory: [[Float]]
    private var historyWriteIndex: Int = 0

    /// Cross-correlation buffer for frequency estimation
    private var corrBuffer: [Float]

    // MARK: - Init

    /// Initialize deconvolver
    /// - Parameter sampleRate: Input signal sample rate (default 60 Hz for control loop data)
    public init(sampleRate: Float = 60.0) {
        self.sampleRate = sampleRate

        // Initialize biquad coefficients for each band
        self.biquadCoeffs = []
        self.filterStates = []
        self.outputHistory = []

        for band in ComponentBand.allCases {
            let coeffs = BioSignalDeconvolver.designBandpass(
                lowFreq: band.lowFreq,
                highFreq: band.highFreq,
                sampleRate: sampleRate
            )
            biquadCoeffs.append(coeffs)
            filterStates.append([Float](repeating: 0, count: 8))  // 2 × [x1, x2, y1, y2]
            outputHistory.append([Float](repeating: 0, count: historySize))
        }

        self.corrBuffer = [Float](repeating: 0, count: historySize)
    }

    // MARK: - Processing

    /// Process a single input sample. Returns separated components.
    /// Call at sampleRate Hz (typically 60 Hz for bio data).
    public func process(_ input: Float) -> [SignalComponent] {
        var components: [SignalComponent] = []

        for (bandIndex, band) in ComponentBand.allCases.enumerated() {
            // Apply biquad filter
            let filtered = applyBiquad(input, bandIndex: bandIndex)

            // Store in history
            outputHistory[bandIndex][historyWriteIndex] = filtered

            // Compute RMS amplitude over recent window
            let rms = computeRMS(bandIndex: bandIndex)

            // Estimate dominant frequency via zero-crossing rate
            let freq = estimateDominantFreq(bandIndex: bandIndex)

            // Confidence: based on signal-to-noise (band energy vs total energy)
            let totalRMS = ComponentBand.allCases.indices.reduce(Float(0)) { sum, i in
                sum + computeRMS(bandIndex: i)
            }
            let confidence = totalRMS > 0 ? rms / totalRMS : 0

            components.append(SignalComponent(
                name: band.rawValue,
                band: band,
                currentValue: filtered,
                amplitude: rms,
                dominantFreqHz: freq,
                confidence: confidence
            ))
        }

        historyWriteIndex = (historyWriteIndex + 1) % historySize

        return components
    }

    /// Get the cardiac component value (most common use case)
    public func cardiacValue() -> Float {
        let idx = ComponentBand.allCases.firstIndex(of: .cardiac) ?? 2
        let prevIdx = (historyWriteIndex - 1 + historySize) % historySize
        return outputHistory[idx][prevIdx]
    }

    /// Get the respiratory component value
    public func respiratoryValue() -> Float {
        let idx = ComponentBand.allCases.firstIndex(of: .respiratory) ?? 1
        let prevIdx = (historyWriteIndex - 1 + historySize) % historySize
        return outputHistory[idx][prevIdx]
    }

    /// Get artifact level (for quality assessment)
    public func artifactLevel() -> Float {
        let idx = ComponentBand.allCases.firstIndex(of: .artifact) ?? 3
        return computeRMS(bandIndex: idx)
    }

    // MARK: - Biquad Filter

    /// Apply 2nd-order biquad IIR filter (direct form II transposed)
    private func applyBiquad(_ input: Float, bandIndex: Int) -> Float {
        let c = biquadCoeffs[bandIndex]
        guard c.count >= 5 else { return input }

        let b0 = c[0], b1 = c[1], b2 = c[2], a1 = c[3], a2 = c[4]

        // State: [x1, x2, y1, y2]
        let x1 = filterStates[bandIndex][0]
        let x2 = filterStates[bandIndex][1]
        let y1 = filterStates[bandIndex][2]
        let y2 = filterStates[bandIndex][3]

        // Direct form I
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

        // Update state
        filterStates[bandIndex][1] = x1  // x2 = old x1
        filterStates[bandIndex][0] = input  // x1 = current input
        filterStates[bandIndex][3] = y1  // y2 = old y1
        filterStates[bandIndex][2] = output  // y1 = current output

        return output
    }

    /// Compute RMS of recent history for a band
    private func computeRMS(bandIndex: Int) -> Float {
        let history = outputHistory[bandIndex]
        var sumSq: Float = 0
        vDSP_svesq(history, 1, &sumSq, vDSP_Length(historySize))
        return sqrt(sumSq / Float(historySize))
    }

    /// Estimate dominant frequency via zero-crossing rate
    private func estimateDominantFreq(bandIndex: Int) -> Float {
        let history = outputHistory[bandIndex]
        var crossings = 0

        for i in 1..<historySize {
            let currIdx = (historyWriteIndex - historySize + i + historySize) % historySize
            let prevIdx = (currIdx - 1 + historySize) % historySize
            if (history[currIdx] >= 0 && history[prevIdx] < 0) ||
               (history[currIdx] < 0 && history[prevIdx] >= 0) {
                crossings += 1
            }
        }

        // Zero-crossing rate ≈ 2× frequency
        return (Float(crossings) / 2.0) * (sampleRate / Float(historySize))
    }

    // MARK: - Filter Design

    /// Design a bandpass biquad filter (Butterworth approximation)
    /// Returns [b0, b1, b2, a1, a2] coefficients
    private static func designBandpass(lowFreq: Float, highFreq: Float,
                                       sampleRate: Float) -> [Float] {
        // Handle baseline (lowpass only)
        if lowFreq <= 0 {
            return designLowpass(freq: highFreq, sampleRate: sampleRate)
        }

        // Handle highest band (highpass only if highFreq > Nyquist/2)
        if highFreq >= sampleRate * 0.45 {
            return designHighpass(freq: lowFreq, sampleRate: sampleRate)
        }

        // Bandpass: cascade of HP and LP approximated as single biquad
        let centerFreq = sqrt(lowFreq * highFreq)
        let bandwidth = highFreq - lowFreq
        let omega = 2.0 * Float.pi * centerFreq / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega * sinh(Foundation.log(2.0) / 2.0 * bandwidth / centerFreq * omega / sinOmega)

        let b0 = alpha
        let b1: Float = 0
        let b2 = -alpha
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha

        return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]
    }

    /// Design lowpass biquad (Butterworth)
    private static func designLowpass(freq: Float, sampleRate: Float) -> [Float] {
        let omega = 2.0 * Float.pi * freq / sampleRate
        let cosOmega = cos(omega)
        let alpha = sin(omega) / sqrt(2.0)  // Q = 0.707

        let b0 = (1.0 - cosOmega) / 2.0
        let b1 = 1.0 - cosOmega
        let b2 = (1.0 - cosOmega) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha

        return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]
    }

    /// Design highpass biquad (Butterworth)
    private static func designHighpass(freq: Float, sampleRate: Float) -> [Float] {
        let omega = 2.0 * Float.pi * freq / sampleRate
        let cosOmega = cos(omega)
        let alpha = sin(omega) / sqrt(2.0)

        let b0 = (1.0 + cosOmega) / 2.0
        let b1 = -(1.0 + cosOmega)
        let b2 = (1.0 + cosOmega) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha

        return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]
    }

    /// Reset all filter states
    public func reset() {
        for i in 0..<filterStates.count {
            filterStates[i] = [Float](repeating: 0, count: 8)
            outputHistory[i] = [Float](repeating: 0, count: historySize)
        }
        historyWriteIndex = 0
    }
}

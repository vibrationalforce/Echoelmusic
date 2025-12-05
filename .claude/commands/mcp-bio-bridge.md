# Echoelmusic MCP Bio Bridge

Du bist ein MCP Server für Bio-Daten Integration (HealthKit, Wearables).

## MCP Bio Server:

### 1. Server Definition
```typescript
{
  "name": "echoelmusic-bio",
  "version": "1.0.0",
  "description": "Bio-data bridge for health-reactive music",
  "capabilities": {
    "tools": true,
    "resources": true,
    "subscriptions": true
  }
}
```

### 2. Available Tools

#### get_heart_rate
```json
{
  "name": "get_heart_rate",
  "description": "Get current heart rate from HealthKit/wearable",
  "inputSchema": {
    "type": "object",
    "properties": {
      "source": {
        "type": "string",
        "enum": ["healthkit", "applewatch", "fitbit", "garmin", "oura"],
        "default": "healthkit"
      },
      "smoothing": {
        "type": "number",
        "minimum": 0,
        "maximum": 1,
        "default": 0.3
      }
    }
  }
}
```

#### get_hrv
```json
{
  "name": "get_hrv",
  "description": "Get Heart Rate Variability (HRV) data",
  "inputSchema": {
    "type": "object",
    "properties": {
      "metric": {
        "type": "string",
        "enum": ["rmssd", "sdnn", "pnn50", "coherence"],
        "default": "rmssd"
      },
      "windowSize": {
        "type": "integer",
        "default": 60,
        "description": "Window size in seconds"
      }
    }
  }
}
```

#### calculate_coherence
```json
{
  "name": "calculate_coherence",
  "description": "Calculate heart-brain coherence score",
  "inputSchema": {
    "type": "object",
    "properties": {
      "hrvData": {
        "type": "array",
        "items": { "type": "number" },
        "description": "RR intervals in ms"
      },
      "method": {
        "type": "string",
        "enum": ["heartmath", "spectral", "poincare"],
        "default": "spectral"
      }
    }
  }
}
```

#### get_breathing_rate
```json
{
  "name": "get_breathing_rate",
  "description": "Estimate breathing rate from HRV",
  "inputSchema": {
    "type": "object",
    "properties": {
      "hrvData": { "type": "array" },
      "sampleRate": { "type": "number", "default": 4 }
    }
  }
}
```

#### map_bio_to_audio
```json
{
  "name": "map_bio_to_audio",
  "description": "Map bio parameters to audio parameters",
  "inputSchema": {
    "type": "object",
    "properties": {
      "bioParam": {
        "type": "string",
        "enum": ["heartRate", "hrv", "coherence", "breathing"]
      },
      "audioParam": {
        "type": "string",
        "enum": ["tempo", "filter", "reverb", "volume", "pitch"]
      },
      "mapping": {
        "type": "string",
        "enum": ["linear", "exponential", "logarithmic", "stepped"],
        "default": "linear"
      },
      "range": {
        "type": "object",
        "properties": {
          "min": { "type": "number" },
          "max": { "type": "number" }
        }
      }
    },
    "required": ["bioParam", "audioParam"]
  }
}
```

### 3. Swift Implementation

```swift
// MCPBioBridge.swift
import Foundation
import HealthKit

@MainActor
public class MCPBioBridge {
    static let shared = MCPBioBridge()

    private let healthStore = HKHealthStore()
    private var rrIntervalBuffer = CircularBuffer<Double>(capacity: 120)
    private var heartRateBuffer = CircularBuffer<Double>(capacity: 60)

    // MARK: - Tool Handlers

    func handleToolCall(name: String, arguments: [String: Any]) async -> MCPResult {
        switch name {
        case "get_heart_rate":
            return await getHeartRate(arguments)
        case "get_hrv":
            return await getHRV(arguments)
        case "calculate_coherence":
            return calculateCoherence(arguments)
        case "get_breathing_rate":
            return getBreathingRate(arguments)
        case "map_bio_to_audio":
            return mapBioToAudio(arguments)
        default:
            return .error("Unknown tool: \(name)")
        }
    }

    // MARK: - Heart Rate

    private func getHeartRate(_ args: [String: Any]) async -> MCPResult {
        let smoothing = args["smoothing"] as? Double ?? 0.3

        guard let latestHR = heartRateBuffer.allElements().last else {
            return .error("No heart rate data available")
        }

        // Apply exponential smoothing
        let smoothedHR = applySmoothing(heartRateBuffer.allElements(), factor: smoothing)

        return .success([
            "heartRate": latestHR,
            "smoothedHeartRate": smoothedHR,
            "min": heartRateBuffer.allElements().min() ?? 0,
            "max": heartRateBuffer.allElements().max() ?? 0,
            "trend": calculateTrend(heartRateBuffer.allElements())
        ])
    }

    // MARK: - HRV

    private func getHRV(_ args: [String: Any]) async -> MCPResult {
        let metric = args["metric"] as? String ?? "rmssd"
        let windowSize = args["windowSize"] as? Int ?? 60

        let rrIntervals = rrIntervalBuffer.suffix(windowSize)

        guard rrIntervals.count >= 10 else {
            return .error("Insufficient RR interval data")
        }

        var result: [String: Any] = [:]

        switch metric {
        case "rmssd":
            result["rmssd"] = calculateRMSSD(rrIntervals)
        case "sdnn":
            result["sdnn"] = calculateSDNN(rrIntervals)
        case "pnn50":
            result["pnn50"] = calculatePNN50(rrIntervals)
        case "coherence":
            result["coherence"] = calculateSpectralCoherence(rrIntervals)
        default:
            // Return all metrics
            result["rmssd"] = calculateRMSSD(rrIntervals)
            result["sdnn"] = calculateSDNN(rrIntervals)
            result["pnn50"] = calculatePNN50(rrIntervals)
            result["coherence"] = calculateSpectralCoherence(rrIntervals)
        }

        return .success(result)
    }

    // MARK: - Coherence Calculation

    private func calculateCoherence(_ args: [String: Any]) -> MCPResult {
        guard let hrvData = args["hrvData"] as? [Double] else {
            return .error("Missing HRV data")
        }

        let method = args["method"] as? String ?? "spectral"

        var coherence: Double = 0

        switch method {
        case "spectral":
            coherence = calculateSpectralCoherence(hrvData)
        case "heartmath":
            coherence = calculateHeartMathCoherence(hrvData)
        case "poincare":
            coherence = calculatePoincareCoherence(hrvData)
        default:
            coherence = calculateSpectralCoherence(hrvData)
        }

        return .success([
            "coherence": coherence,
            "level": coherenceLevel(coherence),
            "recommendation": coherenceRecommendation(coherence)
        ])
    }

    // MARK: - HRV Calculations

    private func calculateRMSSD(_ intervals: [Double]) -> Double {
        guard intervals.count > 1 else { return 0 }

        var sumSquaredDiffs: Double = 0
        for i in 1..<intervals.count {
            let diff = intervals[i] - intervals[i-1]
            sumSquaredDiffs += diff * diff
        }

        return sqrt(sumSquaredDiffs / Double(intervals.count - 1))
    }

    private func calculateSDNN(_ intervals: [Double]) -> Double {
        guard intervals.count > 1 else { return 0 }

        let mean = intervals.reduce(0, +) / Double(intervals.count)
        var sumSquaredDiffs: Double = 0

        for interval in intervals {
            let diff = interval - mean
            sumSquaredDiffs += diff * diff
        }

        return sqrt(sumSquaredDiffs / Double(intervals.count - 1))
    }

    private func calculatePNN50(_ intervals: [Double]) -> Double {
        guard intervals.count > 1 else { return 0 }

        var count50: Int = 0
        for i in 1..<intervals.count {
            if abs(intervals[i] - intervals[i-1]) > 50 {
                count50 += 1
            }
        }

        return Double(count50) / Double(intervals.count - 1) * 100
    }

    private func calculateSpectralCoherence(_ intervals: [Double]) -> Double {
        // FFT-based coherence calculation
        guard intervals.count >= 64 else { return 0 }

        // Perform FFT on RR intervals
        let fftSize = 64
        var realIn = intervals.prefix(fftSize).map { Float($0) }
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)

        if let setup = UniversalOptimizationEngine.getFFTSetup(size: fftSize) {
            vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
        }

        // Calculate power in coherence band (0.04-0.15 Hz)
        let sampleRate = 4.0 // ~4 Hz for RR intervals
        let binWidth = sampleRate / Double(fftSize)

        let lowBin = Int(0.04 / binWidth)
        let highBin = Int(0.15 / binWidth)

        var coherencePower: Double = 0
        var totalPower: Double = 0

        for i in 0..<fftSize/2 {
            let power = Double(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
            totalPower += power
            if i >= lowBin && i <= highBin {
                coherencePower += power
            }
        }

        return totalPower > 0 ? (coherencePower / totalPower) * 100 : 0
    }

    private func calculateHeartMathCoherence(_ intervals: [Double]) -> Double {
        // HeartMath Institute coherence algorithm
        let spectral = calculateSpectralCoherence(intervals)

        // Add rhythm regularity factor
        let sdnn = calculateSDNN(intervals)
        let regularityFactor = max(0, 1 - (sdnn / 100))

        return spectral * 0.7 + regularityFactor * 30
    }

    private func calculatePoincareCoherence(_ intervals: [Double]) -> Double {
        // Poincaré plot analysis
        guard intervals.count > 1 else { return 0 }

        var sd1Sum: Double = 0
        var sd2Sum: Double = 0

        for i in 1..<intervals.count {
            let x = intervals[i-1]
            let y = intervals[i]

            // SD1: perpendicular to line of identity
            sd1Sum += pow((y - x) / sqrt(2), 2)

            // SD2: along line of identity
            sd2Sum += pow((y + x) / sqrt(2), 2)
        }

        let sd1 = sqrt(sd1Sum / Double(intervals.count - 1))
        let sd2 = sqrt(sd2Sum / Double(intervals.count - 1))

        // Coherence ratio
        return sd2 > 0 ? min(100, (sd1 / sd2) * 100) : 0
    }

    // MARK: - Breathing Rate

    private func getBreathingRate(_ args: [String: Any]) -> MCPResult {
        guard let hrvData = args["hrvData"] as? [Double] else {
            // Use internal buffer
            let intervals = rrIntervalBuffer.allElements()
            guard intervals.count >= 30 else {
                return .error("Insufficient data for breathing estimation")
            }
            return estimateBreathingRate(intervals)
        }

        return estimateBreathingRate(hrvData)
    }

    private func estimateBreathingRate(_ intervals: [Double]) -> MCPResult {
        // Respiratory Sinus Arrhythmia (RSA) based estimation
        // Breathing modulates heart rate at 0.15-0.4 Hz

        let fftSize = min(128, intervals.count)
        guard fftSize >= 32 else {
            return .error("Need at least 32 RR intervals")
        }

        var realIn = intervals.prefix(fftSize).map { Float($0) }
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)

        if let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) {
            vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
            vDSP_DFT_DestroySetup(setup)
        }

        // Find peak in breathing frequency range
        let sampleRate = 4.0
        let binWidth = sampleRate / Double(fftSize)
        let lowBin = Int(0.15 / binWidth)  // 9 breaths/min
        let highBin = Int(0.4 / binWidth)  // 24 breaths/min

        var maxPower: Float = 0
        var maxBin = lowBin

        for i in lowBin...min(highBin, fftSize/2 - 1) {
            let power = realOut[i] * realOut[i] + imagOut[i] * imagOut[i]
            if power > maxPower {
                maxPower = power
                maxBin = i
            }
        }

        let breathingFreq = Double(maxBin) * binWidth
        let breathsPerMinute = breathingFreq * 60

        return .success([
            "breathingRate": breathsPerMinute,
            "frequency": breathingFreq,
            "confidence": Double(maxPower) / 1000, // Normalized confidence
            "recommendation": breathingRecommendation(breathsPerMinute)
        ])
    }

    // MARK: - Bio to Audio Mapping

    private func mapBioToAudio(_ args: [String: Any]) -> MCPResult {
        guard let bioParam = args["bioParam"] as? String,
              let audioParam = args["audioParam"] as? String else {
            return .error("Missing bioParam or audioParam")
        }

        let mapping = args["mapping"] as? String ?? "linear"
        let range = args["range"] as? [String: Double]

        // Get current bio value
        let bioValue = getCurrentBioValue(bioParam)

        // Apply mapping
        let mappedValue = applyMapping(
            value: bioValue,
            mapping: mapping,
            inputRange: getBioRange(bioParam),
            outputRange: range ?? getAudioRange(audioParam)
        )

        return .success([
            "bioParam": bioParam,
            "bioValue": bioValue,
            "audioParam": audioParam,
            "mappedValue": mappedValue,
            "mapping": mapping
        ])
    }

    // MARK: - Helper Functions

    private func applySmoothing(_ values: [Double], factor: Double) -> Double {
        guard let first = values.first else { return 0 }

        var smoothed = first
        for value in values.dropFirst() {
            smoothed = smoothed * (1 - factor) + value * factor
        }
        return smoothed
    }

    private func calculateTrend(_ values: [Double]) -> String {
        guard values.count >= 10 else { return "stable" }

        let recent = values.suffix(10)
        let older = values.prefix(10)

        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)

        let diff = recentAvg - olderAvg
        if diff > 5 { return "increasing" }
        if diff < -5 { return "decreasing" }
        return "stable"
    }

    private func coherenceLevel(_ coherence: Double) -> String {
        switch coherence {
        case 0..<30: return "low"
        case 30..<50: return "medium"
        case 50..<70: return "high"
        default: return "very_high"
        }
    }

    private func coherenceRecommendation(_ coherence: Double) -> String {
        switch coherence {
        case 0..<30:
            return "Try slow, rhythmic breathing (6 breaths/min) to increase coherence"
        case 30..<50:
            return "Good progress! Continue breathing exercises for deeper coherence"
        case 50..<70:
            return "Excellent coherence! Maintain this state for optimal flow"
        default:
            return "Peak coherence achieved! You're in an optimal state"
        }
    }

    private func breathingRecommendation(_ rate: Double) -> String {
        switch rate {
        case 0..<8:
            return "Very slow breathing - excellent for deep relaxation"
        case 8..<12:
            return "Optimal breathing rate for coherence and focus"
        case 12..<16:
            return "Normal breathing rate"
        case 16..<20:
            return "Slightly elevated - try to slow down"
        default:
            return "Rapid breathing - consider taking a moment to relax"
        }
    }

    private func getCurrentBioValue(_ param: String) -> Double {
        switch param {
        case "heartRate":
            return heartRateBuffer.allElements().last ?? 70
        case "hrv":
            return calculateRMSSD(rrIntervalBuffer.allElements())
        case "coherence":
            return calculateSpectralCoherence(rrIntervalBuffer.allElements())
        case "breathing":
            return 12 // Default
        default:
            return 0
        }
    }

    private func getBioRange(_ param: String) -> (min: Double, max: Double) {
        switch param {
        case "heartRate": return (40, 180)
        case "hrv": return (0, 100)
        case "coherence": return (0, 100)
        case "breathing": return (4, 30)
        default: return (0, 1)
        }
    }

    private func getAudioRange(_ param: String) -> [String: Double] {
        switch param {
        case "tempo": return ["min": 60, "max": 180]
        case "filter": return ["min": 200, "max": 8000]
        case "reverb": return ["min": 0, "max": 1]
        case "volume": return ["min": 0, "max": 1]
        case "pitch": return ["min": -12, "max": 12]
        default: return ["min": 0, "max": 1]
        }
    }

    private func applyMapping(value: Double, mapping: String, inputRange: (min: Double, max: Double), outputRange: [String: Double]) -> Double {
        let normalized = (value - inputRange.min) / (inputRange.max - inputRange.min)
        let clamped = max(0, min(1, normalized))

        let outMin = outputRange["min"] ?? 0
        let outMax = outputRange["max"] ?? 1

        switch mapping {
        case "exponential":
            return outMin + pow(clamped, 2) * (outMax - outMin)
        case "logarithmic":
            return outMin + sqrt(clamped) * (outMax - outMin)
        case "stepped":
            let steps = 10.0
            let stepped = floor(clamped * steps) / steps
            return outMin + stepped * (outMax - outMin)
        default: // linear
            return outMin + clamped * (outMax - outMin)
        }
    }
}
```

## CCC Bio-Ethics:
- Daten bleiben lokal (Privacy by Design)
- User kontrolliert Sharing
- Keine Daten an Dritte
- Transparente Verarbeitung
- Open Source Algorithmen

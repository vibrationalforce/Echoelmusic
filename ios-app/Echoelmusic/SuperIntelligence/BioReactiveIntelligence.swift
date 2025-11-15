import Foundation
import AVFoundation
import HealthKit
import CoreImage
import Accelerate
import Combine

// MARK: - Bio-Reactive Intelligence Layer
/// Advanced biofeedback integration for music production
/// Phase 6.3+: Super Intelligence Tools
///
/// Biofeedback Sources:
/// 1. Camera-based HRV (PPG) - Like HRV4Training
/// 2. Apple Watch (HealthKit) - Real-time HR/HRV
/// 3. Oura Ring - Sleep & recovery data
/// 4. Advanced Biofeedback Tools - Commercial hardware
///
/// Applications:
/// - Heart rate-synced BPM
/// - HRV-based coherence mapping
/// - Stress-adaptive mixing
/// - Bio-reactive visual effects
class BioReactiveIntelligence: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var heartRate: Double = 0.0
    @Published var hrv: Double = 0.0           // RMSSD in ms
    @Published var coherenceScore: Double = 0.0  // 0-1
    @Published var respirationRate: Double = 0.0
    @Published var stressLevel: StressLevel = .neutral
    @Published var isMonitoring: Bool = false
    @Published var activeSource: BiofeedbackSource = .none

    // MARK: - Biofeedback Sources
    private var cameraHRV: CameraHRVDetector?
    private var healthKitMonitor: HealthKitMonitor?
    private var ouraIntegration: OuraIntegration?
    private var advancedBioTools: AdvancedBiofeedbackTools?

    // MARK: - Configuration
    var autoSyncBPM: Bool = true
    var coherenceMappingEnabled: Bool = true
    var latencyOptimization: Bool = true

    // MARK: - Private State
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    override init() {
        super.init()
        setupBiofeedbackSources()
    }

    private func setupBiofeedbackSources() {
        cameraHRV = CameraHRVDetector()
        healthKitMonitor = HealthKitMonitor(healthStore: healthStore)
        ouraIntegration = OuraIntegration()
        advancedBioTools = AdvancedBiofeedbackTools()

        // Subscribe to updates
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        // Camera HRV updates
        cameraHRV?.$heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                guard self?.activeSource == .camera else { return }
                self?.heartRate = hr
            }
            .store(in: &cancellables)

        cameraHRV?.$hrv
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hrvValue in
                guard self?.activeSource == .camera else { return }
                self?.hrv = hrvValue
                self?.updateCoherenceScore()
            }
            .store(in: &cancellables)

        // HealthKit updates
        healthKitMonitor?.$heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                guard self?.activeSource == .appleWatch else { return }
                self?.heartRate = hr
            }
            .store(in: &cancellables)

        healthKitMonitor?.$hrv
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hrvValue in
                guard self?.activeSource == .appleWatch else { return }
                self?.hrv = hrvValue
                self?.updateCoherenceScore()
            }
            .store(in: &cancellables)
    }

    // MARK: - Start/Stop Monitoring

    func startMonitoring(source: BiofeedbackSource) {
        stopMonitoring() // Stop any existing monitoring

        activeSource = source

        switch source {
        case .camera:
            cameraHRV?.startDetection()

        case .appleWatch:
            healthKitMonitor?.requestAuthorization { [weak self] success in
                if success {
                    self?.healthKitMonitor?.startMonitoring()
                }
            }

        case .ouraRing:
            ouraIntegration?.connect { [weak self] success in
                if success {
                    self?.ouraIntegration?.startMonitoring()
                }
            }

        case .advancedTools:
            advancedBioTools?.connect()

        case .none:
            break
        }

        isMonitoring = true
    }

    func stopMonitoring() {
        cameraHRV?.stopDetection()
        healthKitMonitor?.stopMonitoring()
        ouraIntegration?.stopMonitoring()
        advancedBioTools?.disconnect()

        isMonitoring = false
        activeSource = .none
    }

    // MARK: - Coherence Calculation

    private func updateCoherenceScore() {
        // HeartMath coherence algorithm
        // Based on HRV oscillation around 0.1 Hz (breathing rate)

        guard hrv > 0 else {
            coherenceScore = 0.0
            return
        }

        // Simplified coherence: higher HRV = better coherence
        // Real implementation would use spectral analysis
        let normalizedHRV = min(hrv / 100.0, 1.0) // Normalize to 0-1

        coherenceScore = normalizedHRV

        // Update stress level
        updateStressLevel()
    }

    private func updateStressLevel() {
        // Classify stress based on HRV and coherence
        if coherenceScore > 0.7 && hrv > 50 {
            stressLevel = .relaxed
        } else if coherenceScore > 0.5 && hrv > 30 {
            stressLevel = .neutral
        } else if coherenceScore > 0.3 && hrv > 20 {
            stressLevel = .moderate
        } else {
            stressLevel = .high
        }
    }

    // MARK: - Bio-Reactive Music Features

    /// Get BPM suggestion based on heart rate
    func suggestedBPM() -> Double {
        guard heartRate > 40 && heartRate < 200 else {
            return 120.0 // Default
        }

        if autoSyncBPM {
            // Sync to heart rate or harmonic
            return heartRate
        } else {
            // Suggest calming BPM if stressed
            if stressLevel == .high {
                return 60.0 // Calming
            } else if stressLevel == .relaxed {
                return 80.0 // Energetic
            } else {
                return 120.0 // Neutral
            }
        }
    }

    /// Map coherence to audio parameter (0.0-1.0)
    func coherenceMapping(for parameter: AudioParameter) -> Float {
        let coherence = Float(coherenceScore)

        switch parameter {
        case .volume:
            // Higher coherence = higher volume
            return coherence

        case .reverb:
            // Higher coherence = more reverb (spacious)
            return coherence * 0.8

        case .delay:
            // Moderate coherence = more delay
            return coherence * 0.6

        case .filter:
            // Higher coherence = brighter (higher cutoff)
            return coherence

        case .distortion:
            // Lower coherence = more distortion (stress)
            return (1.0 - coherence) * 0.5
        }
    }

    /// Generate visual effect parameters based on biofeedback
    func visualEffectParameters() -> VisualEffectParameters {
        let hue = Float(heartRate / 200.0) // HR maps to color
        let saturation = Float(coherenceScore)
        let brightness = Float(0.5 + coherenceScore * 0.5)
        let pulseBPM = heartRate

        return VisualEffectParameters(
            hue: hue,
            saturation: saturation,
            brightness: brightness,
            pulseBPM: pulseBPM
        )
    }
}

// MARK: - Camera-Based HRV Detection (PPG)

class CameraHRVDetector: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    @Published var heartRate: Double = 0.0
    @Published var hrv: Double = 0.0
    @Published var signalQuality: Float = 0.0

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?

    // PPG signal processing
    private var redChannelHistory: [Float] = []
    private let historySize = 300 // 10 seconds at 30fps
    private var peakDetector = PeakDetector()
    private var rrIntervals: [Double] = []

    func startDetection() {
        setupCamera()
        captureSession?.startRunning()
    }

    func stopDetection() {
        captureSession?.stopRunning()
        redChannelHistory.removeAll()
        rrIntervals.removeAll()
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .low // Low resolution for efficiency

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }

        // Enable torch for PPG
        if camera.hasTorch {
            try? camera.lockForConfiguration()
            camera.torchMode = .on
            camera.unlockForConfiguration()
        }

        captureSession?.addInput(input)

        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.echoel.ppg"))

        if let output = videoOutput {
            captureSession?.addOutput(output)
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Extract red channel intensity (PPG signal)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let redIntensity = extractRedChannelMean(from: ciImage)

        // Add to history
        redChannelHistory.append(redIntensity)
        if redChannelHistory.count > historySize {
            redChannelHistory.removeFirst()
        }

        // Process when we have enough data
        if redChannelHistory.count >= 90 { // 3 seconds at 30fps
            processPPGSignal()
        }
    }

    private func extractRedChannelMean(from image: CIImage) -> Float {
        // Extract red channel
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return 0.0
        }

        // Calculate mean red value (simplified)
        // Real implementation would sample center region
        return Float.random(in: 0...1) // Placeholder
    }

    private func processPPGSignal() {
        // Bandpass filter (0.75-4 Hz for heart rate)
        let filteredSignal = bandpassFilter(signal: redChannelHistory)

        // Detect peaks (heartbeats)
        let peaks = peakDetector.detectPeaks(in: filteredSignal, threshold: 0.3)

        // Calculate RR intervals
        if peaks.count >= 2 {
            for i in 1..<peaks.count {
                let rrInterval = Double(peaks[i] - peaks[i-1]) / 30.0 * 1000.0 // Convert to ms
                rrIntervals.append(rrInterval)
            }

            // Keep last 20 intervals
            if rrIntervals.count > 20 {
                rrIntervals.removeFirst(rrIntervals.count - 20)
            }

            // Calculate heart rate
            if let lastRR = rrIntervals.last {
                DispatchQueue.main.async {
                    self.heartRate = 60000.0 / lastRR
                }
            }

            // Calculate HRV (RMSSD)
            if rrIntervals.count >= 5 {
                let hrvValue = calculateRMSSD(intervals: rrIntervals)
                DispatchQueue.main.async {
                    self.hrv = hrvValue
                }
            }
        }
    }

    private func bandpassFilter(signal: [Float]) -> [Float] {
        // Simplified bandpass filter (0.75-4 Hz)
        // Real implementation would use proper DSP
        return signal
    }

    private func calculateRMSSD(intervals: [Double]) -> Double {
        guard intervals.count >= 2 else { return 0.0 }

        var sumSquaredDiffs: Double = 0.0

        for i in 1..<intervals.count {
            let diff = intervals[i] - intervals[i-1]
            sumSquaredDiffs += diff * diff
        }

        let meanSquaredDiff = sumSquaredDiffs / Double(intervals.count - 1)
        return sqrt(meanSquaredDiff)
    }
}

// MARK: - HealthKit Monitor (Apple Watch)

class HealthKitMonitor: ObservableObject {

    @Published var heartRate: Double = 0.0
    @Published var hrv: Double = 0.0

    private let healthStore: HKHealthStore
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
            completion(success)
        }
    }

    func startMonitoring() {
        startHeartRateQuery()
        startHRVQuery()
    }

    func stopMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        if let query = hrvQuery {
            healthStore.stop(query)
        }
    }

    private func startHeartRateQuery() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    private func startHRVQuery() {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let query = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHRVSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHRVSamples(samples)
        }

        healthStore.execute(query)
        hrvQuery = query
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }

        let hr = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        DispatchQueue.main.async {
            self.heartRate = hr
        }
    }

    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }

        let hrvValue = latest.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

        DispatchQueue.main.async {
            self.hrv = hrvValue
        }
    }
}

// MARK: - Oura Ring Integration

class OuraIntegration: ObservableObject {

    @Published var isConnected: Bool = false
    @Published var readinessScore: Double = 0.0
    @Published var sleepScore: Double = 0.0
    @Published var activityScore: Double = 0.0

    private var apiToken: String?

    func connect(completion: @escaping (Bool) -> Void) {
        // OAuth flow to get API token
        // Placeholder implementation
        apiToken = "placeholder_token"
        isConnected = true
        completion(true)
    }

    func startMonitoring() {
        // Fetch latest data from Oura API
        fetchLatestData()
    }

    func stopMonitoring() {
        isConnected = false
    }

    private func fetchLatestData() {
        // API call to Oura
        // Placeholder implementation
        readinessScore = 85.0
        sleepScore = 80.0
        activityScore = 75.0
    }
}

// MARK: - Advanced Biofeedback Tools

class AdvancedBiofeedbackTools: ObservableObject {

    @Published var isConnected: Bool = false
    @Published var devices: [BiofeedbackDevice] = []

    // Support for commercial biofeedback hardware
    // - HeartMath Inner Balance
    // - Muse headband
    // - Polar H10
    // - etc.

    func connect() {
        // Scan for Bluetooth biofeedback devices
        scanForDevices()
    }

    func disconnect() {
        isConnected = false
        devices.removeAll()
    }

    private func scanForDevices() {
        // Bluetooth scanning
        // Placeholder
    }
}

// MARK: - Supporting Types

enum BiofeedbackSource {
    case none
    case camera
    case appleWatch
    case ouraRing
    case advancedTools
}

enum StressLevel {
    case relaxed
    case neutral
    case moderate
    case high
}

enum AudioParameter {
    case volume
    case reverb
    case delay
    case filter
    case distortion
}

struct VisualEffectParameters {
    let hue: Float
    let saturation: Float
    let brightness: Float
    let pulseBPM: Double
}

struct BiofeedbackDevice {
    let name: String
    let type: DeviceType
    let isConnected: Bool

    enum DeviceType {
        case heartRate
        case eeg
        case gsr  // Galvanic skin response
        case temperature
    }
}

// MARK: - Peak Detector

class PeakDetector {

    func detectPeaks(in signal: [Float], threshold: Float) -> [Int] {
        var peaks: [Int] = []

        for i in 1..<(signal.count - 1) {
            // Local maximum
            if signal[i] > signal[i-1] && signal[i] > signal[i+1] && signal[i] > threshold {
                peaks.append(i)
            }
        }

        return peaks
    }
}

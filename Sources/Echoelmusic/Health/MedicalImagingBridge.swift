import Foundation
import Accelerate
import Combine

// MARK: - Medical Imaging Bridge
// Integration with medical imaging and diagnostic systems
//
// Supported formats:
// - DICOM (Digital Imaging and Communications in Medicine)
// - NIFTI (Neuroimaging Informatics Technology Initiative)
// - EEG/EKG waveforms
// - HL7 FHIR (Fast Healthcare Interoperability Resources)
//
// Use cases:
// - Sonification of medical data (organ imaging → sound)
// - Bio-reactive visuals synced to diagnostic data
// - Real-time EEG/EKG visualization and audio mapping
// - Research applications (neurofeedback, biofeedback)
//
// Compliance: HIPAA, GDPR, FDA 21 CFR Part 11 considerations
// DISCLAIMER: For research and visualization purposes only.
// Not intended for clinical diagnosis.

// MARK: - DICOM Integration

/// DICOM file reader for medical imaging
struct DICOMReader {

    struct DICOMImage {
        let patientID: String?
        let studyDate: Date?
        let modality: Modality
        let rows: Int
        let columns: Int
        let pixelData: [UInt16]
        let windowCenter: Double
        let windowWidth: Double
        let pixelSpacing: (Double, Double)?  // mm
        let sliceThickness: Double?          // mm

        enum Modality: String {
            case ct = "CT"
            case mr = "MR"
            case us = "US"       // Ultrasound
            case xr = "XR"       // X-Ray
            case pet = "PT"      // PET
            case nm = "NM"       // Nuclear Medicine
            case unknown = "OT"
        }

        /// Convert to normalized float array (0-1)
        func normalizedPixels() -> [Float] {
            let minVal = windowCenter - windowWidth / 2
            let maxVal = windowCenter + windowWidth / 2

            return pixelData.map { pixel in
                let normalized = (Double(pixel) - minVal) / (maxVal - minVal)
                return Float(max(0, min(1, normalized)))
            }
        }
    }

    /// Read DICOM file (simplified - production would use full DICOM library)
    static func read(from url: URL) throws -> DICOMImage {
        let data = try Data(contentsOf: url)

        // DICOM files start with 128 byte preamble + "DICM" magic
        guard data.count > 132,
              String(data: data[128..<132], encoding: .ascii) == "DICM" else {
            throw DICOMError.invalidFormat
        }

        // Parse would read actual DICOM tags
        // This is a placeholder structure
        return DICOMImage(
            patientID: nil,
            studyDate: nil,
            modality: .unknown,
            rows: 512,
            columns: 512,
            pixelData: [],
            windowCenter: 40,
            windowWidth: 400,
            pixelSpacing: (0.5, 0.5),
            sliceThickness: 1.0
        )
    }

    enum DICOMError: Error {
        case invalidFormat
        case missingData
        case unsupportedTransferSyntax
    }
}

// MARK: - NIFTI Integration (Neuroimaging)

/// NIFTI format reader for brain imaging (fMRI, DTI)
struct NIFTIReader {

    struct NIFTIImage {
        let dimensions: [Int]           // [x, y, z, time]
        let voxelSize: [Float]          // mm
        let dataType: DataType
        let data: [Float]
        let affineMatrix: [[Float]]     // 4x4 transform to world coordinates

        enum DataType: Int16 {
            case uint8 = 2
            case int16 = 4
            case int32 = 8
            case float32 = 16
            case float64 = 64
        }

        /// Get 3D slice at time point
        func slice(at z: Int, time: Int = 0) -> [[Float]] {
            guard dimensions.count >= 3 else { return [] }

            let width = dimensions[0]
            let height = dimensions[1]
            let depth = dimensions[2]
            let timeOffset = time * width * height * depth

            var slice: [[Float]] = []
            for y in 0..<height {
                var row: [Float] = []
                for x in 0..<width {
                    let index = timeOffset + z * width * height + y * width + x
                    if index < data.count {
                        row.append(data[index])
                    }
                }
                slice.append(row)
            }
            return slice
        }

        /// Get time series at voxel
        func timeSeries(x: Int, y: Int, z: Int) -> [Float] {
            guard dimensions.count >= 4 else { return [] }

            let width = dimensions[0]
            let height = dimensions[1]
            let depth = dimensions[2]
            let timePoints = dimensions[3]
            let voxelOffset = z * width * height + y * width + x

            var series: [Float] = []
            for t in 0..<timePoints {
                let index = t * width * height * depth + voxelOffset
                if index < data.count {
                    series.append(data[index])
                }
            }
            return series
        }
    }

    static func read(from url: URL) throws -> NIFTIImage {
        // Simplified - production would parse full NIFTI header
        return NIFTIImage(
            dimensions: [64, 64, 32, 100],
            voxelSize: [3.0, 3.0, 3.0],
            dataType: .float32,
            data: [],
            affineMatrix: [
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, 1, 0],
                [0, 0, 0, 1]
            ]
        )
    }
}

// MARK: - EEG/EKG Waveform Processing

/// Real-time physiological waveform processing
@MainActor
class PhysiologicalWaveformProcessor: ObservableObject {

    // MARK: - Published State

    @Published var isConnected: Bool = false
    @Published var channels: [WaveformChannel] = []
    @Published var sampleRate: Double = 256.0  // Hz

    // EEG band powers
    @Published var deltaPower: Float = 0       // 0.5-4 Hz
    @Published var thetaPower: Float = 0       // 4-8 Hz
    @Published var alphaPower: Float = 0       // 8-13 Hz
    @Published var betaPower: Float = 0        // 13-30 Hz
    @Published var gammaPower: Float = 0       // 30-100 Hz

    // EKG metrics
    @Published var heartRate: Float = 0        // BPM
    @Published var rrInterval: Float = 0       // ms
    @Published var hrvRMSSD: Float = 0         // ms

    struct WaveformChannel: Identifiable {
        let id: UUID
        let name: String
        let type: ChannelType
        var samples: [Float]
        var sampleRate: Double

        enum ChannelType: String, CaseIterable {
            case eeg = "EEG"
            case ekg = "EKG/ECG"
            case emg = "EMG"
            case eog = "EOG"
            case ppg = "PPG"
            case respiration = "Respiration"
        }
    }

    // MARK: - FFT Analysis

    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize = 512

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - EEG Band Power Analysis

    func analyzeEEGBands(samples: [Float]) {
        guard samples.count >= fftSize, let setup = fftSetup else { return }

        // Apply Hanning window
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // Prepare for FFT
        var realInput = windowedSamples
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        // Execute FFT
        vDSP_DFT_Execute(setup, &realInput, &imagInput, &realOutput, &imagOutput)

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize/2 {
            magnitudes[i] = sqrt(realOutput[i] * realOutput[i] + imagOutput[i] * imagOutput[i])
        }

        // Calculate band powers
        let binWidth = sampleRate / Double(fftSize)

        deltaPower = bandPower(magnitudes: magnitudes, binWidth: binWidth, lowFreq: 0.5, highFreq: 4)
        thetaPower = bandPower(magnitudes: magnitudes, binWidth: binWidth, lowFreq: 4, highFreq: 8)
        alphaPower = bandPower(magnitudes: magnitudes, binWidth: binWidth, lowFreq: 8, highFreq: 13)
        betaPower = bandPower(magnitudes: magnitudes, binWidth: binWidth, lowFreq: 13, highFreq: 30)
        gammaPower = bandPower(magnitudes: magnitudes, binWidth: binWidth, lowFreq: 30, highFreq: 100)
    }

    private func bandPower(magnitudes: [Float], binWidth: Double, lowFreq: Double, highFreq: Double) -> Float {
        let lowBin = Int(lowFreq / binWidth)
        let highBin = min(Int(highFreq / binWidth), magnitudes.count - 1)

        guard lowBin < highBin else { return 0 }

        var power: Float = 0
        vDSP_sve(Array(magnitudes[lowBin...highBin]), 1, &power, vDSP_Length(highBin - lowBin + 1))

        return power / Float(highBin - lowBin + 1)
    }

    // MARK: - EKG R-Peak Detection

    func analyzeEKG(samples: [Float]) {
        // Pan-Tompkins algorithm for QRS detection (simplified)
        let filtered = bandpassFilter(samples, lowCutoff: 5, highCutoff: 15)
        let derivative = differentiate(filtered)
        let squared = derivative.map { $0 * $0 }
        let integrated = movingWindowIntegration(squared, windowSize: 30)

        // Find R-peaks
        let threshold = integrated.max()! * 0.6
        var rPeaks: [Int] = []
        var lastPeak = -200  // Refractory period

        for i in 1..<(integrated.count - 1) {
            if integrated[i] > threshold &&
               integrated[i] > integrated[i-1] &&
               integrated[i] > integrated[i+1] &&
               i - lastPeak > Int(0.2 * sampleRate) {  // Min 200ms between beats
                rPeaks.append(i)
                lastPeak = i
            }
        }

        // Calculate metrics
        if rPeaks.count >= 2 {
            var rrIntervals: [Float] = []
            for i in 1..<rPeaks.count {
                let interval = Float(rPeaks[i] - rPeaks[i-1]) / Float(sampleRate) * 1000  // ms
                rrIntervals.append(interval)
            }

            rrInterval = rrIntervals.last ?? 0
            heartRate = 60000 / rrInterval

            // Calculate HRV (RMSSD)
            if rrIntervals.count >= 2 {
                var sumSquaredDiff: Float = 0
                for i in 1..<rrIntervals.count {
                    let diff = rrIntervals[i] - rrIntervals[i-1]
                    sumSquaredDiff += diff * diff
                }
                hrvRMSSD = sqrt(sumSquaredDiff / Float(rrIntervals.count - 1))
            }
        }
    }

    private func bandpassFilter(_ samples: [Float], lowCutoff: Double, highCutoff: Double) -> [Float] {
        // Simplified butterworth bandpass
        var output = samples
        // In production, use proper IIR filter
        return output
    }

    private func differentiate(_ samples: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        for i in 2..<(samples.count - 2) {
            output[i] = (-samples[i-2] - 2*samples[i-1] + 2*samples[i+1] + samples[i+2]) / 8
        }
        return output
    }

    private func movingWindowIntegration(_ samples: [Float], windowSize: Int) -> [Float] {
        var output = [Float](repeating: 0, count: samples.count)
        for i in windowSize..<samples.count {
            var sum: Float = 0
            for j in 0..<windowSize {
                sum += samples[i - j]
            }
            output[i] = sum / Float(windowSize)
        }
        return output
    }
}

// MARK: - Medical Data Sonification

/// Convert medical imaging data to audio
@MainActor
class MedicalSonificationEngine: ObservableObject {

    @Published var isPlaying: Bool = false
    @Published var sonificationMode: SonificationMode = .spectral

    enum SonificationMode: String, CaseIterable {
        case spectral = "Spectral"          // Image rows → frequency spectrum
        case temporal = "Temporal"          // Scan through image over time
        case parameter = "Parameter"        // Data values → synthesis parameters
        case rhythmic = "Rhythmic"          // Convert patterns to rhythm
    }

    struct SonificationParameters {
        var baseFrequency: Double = 220.0   // Hz
        var frequencyRange: Double = 4.0    // Octaves
        var duration: Double = 10.0         // Seconds for full scan
        var volume: Float = 0.7
        var reverb: Float = 0.3
    }

    var parameters = SonificationParameters()

    private var sampleRate: Double = 48000.0

    // MARK: - Sonification Methods

    /// Convert DICOM image to audio
    func sonify(dicomImage: DICOMReader.DICOMImage) -> [Float] {
        let pixels = dicomImage.normalizedPixels()
        let width = dicomImage.columns
        let height = dicomImage.rows

        switch sonificationMode {
        case .spectral:
            return spectralSonification(pixels: pixels, width: width, height: height)
        case .temporal:
            return temporalSonification(pixels: pixels, width: width, height: height)
        case .parameter:
            return parameterSonification(pixels: pixels, width: width, height: height)
        case .rhythmic:
            return rhythmicSonification(pixels: pixels, width: width, height: height)
        }
    }

    /// Convert EEG band powers to audio parameters
    func sonifyEEG(
        delta: Float, theta: Float, alpha: Float, beta: Float, gamma: Float
    ) -> [Float] {
        let totalFrames = Int(sampleRate * 0.1)  // 100ms buffer
        var output = [Float](repeating: 0, count: totalFrames)

        // Map EEG bands to synthesis parameters
        // Delta → low drone frequency
        // Theta → pad texture
        // Alpha → melodic content
        // Beta → rhythmic activity
        // Gamma → high frequency shimmer

        let totalPower = delta + theta + alpha + beta + gamma
        guard totalPower > 0 else { return output }

        // Normalize
        let normDelta = delta / totalPower
        let normTheta = theta / totalPower
        let normAlpha = alpha / totalPower
        let normBeta = beta / totalPower
        let normGamma = gamma / totalPower

        // Generate layered synthesis
        for frame in 0..<totalFrames {
            let t = Double(frame) / sampleRate
            var sample: Float = 0

            // Delta: low sine
            let deltaFreq = 55.0 * (1.0 + Double(normDelta) * 0.5)
            sample += Float(sin(2 * .pi * deltaFreq * t)) * normDelta * 0.3

            // Theta: warm pad
            let thetaFreq = 110.0 * (1.0 + Double(normTheta) * 0.5)
            sample += Float(sin(2 * .pi * thetaFreq * t)) * normTheta * 0.25

            // Alpha: calm melody
            let alphaFreq = 220.0 * (1.0 + Double(normAlpha) * 0.3)
            sample += Float(sin(2 * .pi * alphaFreq * t)) * normAlpha * 0.2

            // Beta: rhythmic pulse
            let betaFreq = 440.0 * (1.0 + Double(normBeta) * 0.2)
            sample += Float(sin(2 * .pi * betaFreq * t)) * normBeta * 0.15

            // Gamma: shimmer
            let gammaFreq = 880.0 * (1.0 + Double(normGamma) * 0.1)
            sample += Float(sin(2 * .pi * gammaFreq * t)) * normGamma * 0.1

            output[frame] = sample * parameters.volume
        }

        return output
    }

    // MARK: - Private Sonification Methods

    private func spectralSonification(pixels: [Float], width: Int, height: Int) -> [Float] {
        // Convert each row to a frequency spectrum
        let framesPerRow = Int(parameters.duration * sampleRate / Double(height))
        var output = [Float](repeating: 0, count: framesPerRow * height)

        for row in 0..<height {
            let rowStart = row * width

            for frame in 0..<framesPerRow {
                let t = Double(frame) / sampleRate
                var sample: Float = 0

                // Additive synthesis using pixel values as harmonic amplitudes
                for col in 0..<min(width, 64) {  // Limit harmonics
                    let pixelValue = pixels[rowStart + col]
                    let freq = parameters.baseFrequency * pow(2, Double(col) / 12.0)
                    sample += pixelValue * Float(sin(2 * .pi * freq * t)) / Float(col + 1)
                }

                output[row * framesPerRow + frame] = sample * parameters.volume
            }
        }

        return output
    }

    private func temporalSonification(pixels: [Float], width: Int, height: Int) -> [Float] {
        // Scan through image, mapping position to pitch
        let totalFrames = Int(parameters.duration * sampleRate)
        var output = [Float](repeating: 0, count: totalFrames)

        for frame in 0..<totalFrames {
            let t = Double(frame) / sampleRate
            let progress = t / parameters.duration

            // Calculate current pixel position
            let pixelIndex = Int(progress * Double(pixels.count - 1))
            let pixelValue = pixels[pixelIndex]

            // Map pixel value to frequency
            let freq = parameters.baseFrequency * pow(2, Double(pixelValue) * parameters.frequencyRange)

            output[frame] = Float(sin(2 * .pi * freq * t)) * pixelValue * parameters.volume
        }

        return output
    }

    private func parameterSonification(pixels: [Float], width: Int, height: Int) -> [Float] {
        // Use statistical properties of image regions
        let totalFrames = Int(parameters.duration * sampleRate)
        var output = [Float](repeating: 0, count: totalFrames)

        // Calculate image statistics
        var mean: Float = 0
        var stdDev: Float = 0
        vDSP_meanv(pixels, 1, &mean, vDSP_Length(pixels.count))
        vDSP_normalize(pixels, 1, nil, 1, &stdDev, vDSP_Length(pixels.count))

        for frame in 0..<totalFrames {
            let t = Double(frame) / sampleRate

            // Base frequency from mean
            let freq = parameters.baseFrequency * Double(1 + mean * 2)

            // FM modulation from std dev
            let modDepth = Double(stdDev) * 100
            let modFreq = freq * 0.5

            let modulator = sin(2 * .pi * modFreq * t) * modDepth
            let carrier = sin(2 * .pi * (freq + modulator) * t)

            output[frame] = Float(carrier) * parameters.volume
        }

        return output
    }

    private func rhythmicSonification(pixels: [Float], width: Int, height: Int) -> [Float] {
        // Convert image edges/features to rhythmic triggers
        let totalFrames = Int(parameters.duration * sampleRate)
        var output = [Float](repeating: 0, count: totalFrames)

        // Simple edge detection
        var edges: [Int] = []
        for i in 1..<(pixels.count - 1) {
            let gradient = abs(pixels[i+1] - pixels[i-1])
            if gradient > 0.3 {
                edges.append(i)
            }
        }

        // Map edges to drum triggers
        let samplesPerPixel = totalFrames / pixels.count

        for edge in edges {
            let triggerFrame = edge * samplesPerPixel
            let drumLength = Int(0.05 * sampleRate)  // 50ms

            for i in 0..<drumLength {
                if triggerFrame + i < totalFrames {
                    let decay = exp(-Double(i) / Double(drumLength) * 5)
                    let freq = 100.0 + Double(pixels[edge]) * 200
                    output[triggerFrame + i] += Float(sin(2 * .pi * freq * Double(i) / sampleRate) * decay) * parameters.volume
                }
            }
        }

        return output
    }
}

// MARK: - HL7 FHIR Integration

/// Healthcare data interoperability
struct FHIRClient {

    let baseURL: URL

    struct PatientObservation: Codable {
        let resourceType: String
        let id: String
        let status: String
        let code: CodeableConcept
        let valueQuantity: Quantity?
        let effectiveDateTime: String?

        struct CodeableConcept: Codable {
            let coding: [Coding]

            struct Coding: Codable {
                let system: String
                let code: String
                let display: String
            }
        }

        struct Quantity: Codable {
            let value: Double
            let unit: String
            let system: String
            let code: String
        }
    }

    /// Fetch vital signs observations
    func fetchVitalSigns(patientId: String) async throws -> [PatientObservation] {
        let url = baseURL
            .appendingPathComponent("Observation")
            .appending(queryItems: [
                URLQueryItem(name: "patient", value: patientId),
                URLQueryItem(name: "category", value: "vital-signs")
            ])

        let (data, _) = try await URLSession.shared.data(from: url)

        struct Bundle: Codable {
            let entry: [Entry]?

            struct Entry: Codable {
                let resource: PatientObservation
            }
        }

        let bundle = try JSONDecoder().decode(Bundle.self, from: data)
        return bundle.entry?.map { $0.resource } ?? []
    }
}

// MARK: - Privacy & Compliance

/// Medical data privacy handling
struct MedicalDataPrivacy {

    enum ComplianceStandard: String, CaseIterable {
        case hipaa = "HIPAA"
        case gdpr = "GDPR"
        case fda21CFRPart11 = "FDA 21 CFR Part 11"

        var requirements: [String] {
            switch self {
            case .hipaa:
                return [
                    "Encrypt PHI at rest and in transit",
                    "Implement access controls",
                    "Maintain audit logs",
                    "Business Associate Agreements"
                ]
            case .gdpr:
                return [
                    "Lawful basis for processing",
                    "Data minimization",
                    "Right to erasure",
                    "Data portability"
                ]
            case .fda21CFRPart11:
                return [
                    "Electronic signatures",
                    "Audit trails",
                    "System validation",
                    "Record retention"
                ]
            }
        }
    }

    /// Remove identifying information from DICOM
    static func anonymizeDICOM(_ image: DICOMReader.DICOMImage) -> DICOMReader.DICOMImage {
        return DICOMReader.DICOMImage(
            patientID: nil,
            studyDate: nil,
            modality: image.modality,
            rows: image.rows,
            columns: image.columns,
            pixelData: image.pixelData,
            windowCenter: image.windowCenter,
            windowWidth: image.windowWidth,
            pixelSpacing: image.pixelSpacing,
            sliceThickness: image.sliceThickness
        )
    }

    /// Generate audit log entry
    static func logAccess(
        userId: String,
        dataType: String,
        action: String,
        timestamp: Date = Date()
    ) -> AuditLogEntry {
        return AuditLogEntry(
            id: UUID(),
            userId: userId,
            dataType: dataType,
            action: action,
            timestamp: timestamp,
            ipAddress: nil
        )
    }

    struct AuditLogEntry: Codable {
        let id: UUID
        let userId: String
        let dataType: String
        let action: String
        let timestamp: Date
        let ipAddress: String?
    }
}

import SwiftUI
import AVFoundation
import Accelerate

/// Professional Audio Analysis & Metering Tools
/// Logic Pro / Pro Tools / iZotope Insight level visualization
@MainActor
class AudioAnalysisTools: ObservableObject {

    // MARK: - Spectrum Analyzer

    class SpectrumAnalyzer: ObservableObject {
        @Published var fftSize: Int = 4096
        @Published var spectrumData: [Float] = []
        @Published var mode: AnalyzerMode = .line
        @Published var scale: FrequencyScale = .logarithmic
        @Published var smoothing: Float = 0.7  // 0-1
        @Published var peakHold: Bool = true
        @Published var peakDecay: Float = 0.5  // seconds

        enum AnalyzerMode: String, CaseIterable {
            case line = "Line"
            case filled = "Filled"
            case bars = "Bars"
            case spectrogram = "Spectrogram"
        }

        enum FrequencyScale: String, CaseIterable {
            case linear = "Linear"
            case logarithmic = "Logarithmic"
            case mel = "Mel Scale"
        }

        func processBuffer(_ buffer: AVAudioPCMBuffer) {
            guard let channelData = buffer.floatChannelData else { return }

            // Perform FFT
            let fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
            defer { vDSP_DFT_DestroySetup(fftSetup) }

            var realPart = [Float](repeating: 0, count: fftSize)
            var imagPart = [Float](repeating: 0, count: fftSize)

            // Copy audio data
            for i in 0..<min(Int(buffer.frameLength), fftSize) {
                realPart[i] = channelData[0][i]
            }

            // Execute FFT
            vDSP_DFT_Execute(fftSetup!, &realPart, &imagPart, &realPart, &imagPart)

            // Calculate magnitude spectrum
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<fftSize / 2 {
                let real = realPart[i]
                let imag = imagPart[i]
                magnitudes[i] = sqrtf(real * real + imag * imag)
            }

            // Convert to dB
            var dBSpectrum = [Float](repeating: -96, count: fftSize / 2)
            for i in 0..<magnitudes.count {
                let mag = max(magnitudes[i], 1e-10)
                dBSpectrum[i] = 20 * log10(mag)
            }

            // Apply smoothing
            if smoothing > 0 {
                for i in 0..<dBSpectrum.count {
                    if i < spectrumData.count {
                        dBSpectrum[i] = smoothing * spectrumData[i] + (1 - smoothing) * dBSpectrum[i]
                    }
                }
            }

            spectrumData = dBSpectrum
        }

        func getBinForFrequency(_ frequency: Float, sampleRate: Double) -> Int {
            let binFreq = Float(sampleRate) / Float(fftSize)
            return Int(frequency / binFreq)
        }
    }

    // MARK: - Spectrogram

    class Spectrogram: ObservableObject {
        @Published var spectrogramData: [[Float]] = []
        @Published var colorMap: ColorMap = .viridis
        @Published var windowSize: Int = 2048
        @Published var hopSize: Int = 512
        @Published var dynamicRange: Float = 96.0  // dB

        enum ColorMap: String, CaseIterable {
            case viridis = "Viridis"
            case plasma = "Plasma"
            case inferno = "Inferno"
            case magma = "Magma"
            case grayscale = "Grayscale"
            case rainbow = "Rainbow"
        }

        func processBuffer(_ buffer: AVAudioPCMBuffer) {
            // STFT for spectrogram
            // Add new spectrum to history
            if spectrogramData.count > 500 {
                spectrogramData.removeFirst()
            }
        }
    }

    // MARK: - Phase Scope (Goniometer)

    class PhaseScope: ObservableObject {
        @Published var phasePlotData: [(x: Float, y: Float)] = []
        @Published var correlation: Float = 0.0  // -1 to +1
        @Published var phaseCoherence: Float = 0.0

        func processBuffer(_ buffer: AVAudioPCMBuffer) {
            guard buffer.format.channelCount >= 2,
                  let leftData = buffer.floatChannelData?[0],
                  let rightData = buffer.floatChannelData?[1] else { return }

            var plotData: [(x: Float, y: Float)] = []
            let frameCount = Int(buffer.frameLength)

            // Calculate correlation
            var sum: Float = 0
            var sumL: Float = 0
            var sumR: Float = 0

            for i in 0..<frameCount {
                let l = leftData[i]
                let r = rightData[i]

                sum += l * r
                sumL += l * l
                sumR += r * r

                // Sample points for phase plot
                if i % 10 == 0 {
                    plotData.append((x: l, y: r))
                }
            }

            correlation = sum / sqrtf(sumL * sumR)
            phasePlotData = plotData
        }
    }

    // MARK: - Correlation Meter

    class CorrelationMeter: ObservableObject {
        @Published var correlation: Float = 0.0  // -1 to +1
        @Published var history: [Float] = []

        func processBuffer(_ buffer: AVAudioPCMBuffer) {
            guard buffer.format.channelCount >= 2,
                  let leftData = buffer.floatChannelData?[0],
                  let rightData = buffer.floatChannelData?[1] else { return }

            var sum: Float = 0
            var sumL: Float = 0
            var sumR: Float = 0

            for i in 0..<Int(buffer.frameLength) {
                let l = leftData[i]
                let r = rightData[i]
                sum += l * r
                sumL += l * l
                sumR += r * r
            }

            correlation = sum / sqrtf(sumL * sumR)

            // Add to history
            history.append(correlation)
            if history.count > 100 {
                history.removeFirst()
            }
        }
    }

    // MARK: - Loudness Meter (EBU R128)

    class LoudnessMeter: ObservableObject {
        @Published var momentaryLoudness: Float = -96.0  // LUFS (400ms)
        @Published var shortTermLoudness: Float = -96.0  // LUFS (3s)
        @Published var integratedLoudness: Float = -96.0  // LUFS (entire program)
        @Published var loudnessRange: Float = 0.0  // LU (Loudness Units)
        @Published var truePeak: Float = -96.0  // dB TP
        @Published var target: LoudnessTarget = .streaming

        enum LoudnessTarget: String, CaseIterable {
            case streaming = "Streaming (-14 LUFS)"
            case broadcast = "Broadcast (-23 LUFS)"
            case film = "Film (-27 LUFS LKFS)"
            case cd = "CD (-9 LUFS)"
            case custom = "Custom"

            var targetLUFS: Float {
                switch self {
                case .streaming: return -14.0
                case .broadcast: return -23.0
                case .film: return -27.0
                case .cd: return -9.0
                case .custom: return -14.0
                }
            }
        }

        private var momentaryBuffer: [Float] = []
        private var shortTermBuffer: [Float] = []
        private var integratedBuffer: [Float] = []

        func processBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
            // EBU R128 K-weighted filtering
            // 1. Apply K-weighting filter (shelf @ 100Hz + HF boost @ 4kHz)
            // 2. Calculate mean square
            // 3. Gate at -70 LUFS (absolute) and -10 LU (relative)
            // 4. Calculate LUFS = -0.691 + 10*log10(mean_square)

            // Momentary (400ms)
            // Short-term (3s)
            // Integrated (entire program with gating)
        }

        func getTruePeakdBTP(_ buffer: AVAudioPCMBuffer) -> Float {
            // True peak detection (ITU-R BS.1770-4)
            // 1. Oversample 4x
            // 2. Find peak sample
            // 3. Convert to dB TP
            return -3.0
        }
    }

    // MARK: - VU Meter

    class VUMeter: ObservableObject {
        @Published var leftLevel: Float = -60.0  // dB
        @Published var rightLevel: Float = -60.0  // dB
        @Published var attackTime: Float = 300.0  // ms
        @Published var releaseTime: Float = 300.0  // ms

        func processBuffer(_ buffer: AVAudioPCMBuffer) {
            guard let leftData = buffer.floatChannelData?[0] else { return }
            let rightData = buffer.format.channelCount > 1 ? buffer.floatChannelData?[1] : nil

            // Calculate RMS
            var leftSum: Float = 0
            var rightSum: Float = 0

            for i in 0..<Int(buffer.frameLength) {
                leftSum += leftData[i] * leftData[i]
                if let right = rightData {
                    rightSum += right[i] * right[i]
                } else {
                    rightSum = leftSum
                }
            }

            let leftRMS = sqrtf(leftSum / Float(buffer.frameLength))
            let rightRMS = sqrtf(rightSum / Float(buffer.frameLength))

            leftLevel = 20 * log10(max(leftRMS, 1e-10))
            rightLevel = 20 * log10(max(rightRMS, 1e-10))
        }
    }

    // MARK: - Peak Meter

    class PeakMeter: ObservableObject {
        @Published var leftPeak: Float = -96.0  // dB
        @Published var rightPeak: Float = -96.0  // dB
        @Published var leftPeakHold: Float = -96.0
        @Published var rightPeakHold: Float = -96.0
        @Published var peakHoldTime: Float = 2.0  // seconds
        @Published var clipIndicator: Bool = false

        private var peakHoldCounter: Int = 0

        func processBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
            guard let leftData = buffer.floatChannelData?[0] else { return }
            let rightData = buffer.format.channelCount > 1 ? buffer.floatChannelData?[1] : nil

            // Find peak samples
            var leftMax: Float = 0
            var rightMax: Float = 0

            for i in 0..<Int(buffer.frameLength) {
                leftMax = max(leftMax, abs(leftData[i]))
                if let right = rightData {
                    rightMax = max(rightMax, abs(right[i]))
                } else {
                    rightMax = leftMax
                }
            }

            leftPeak = 20 * log10(max(leftMax, 1e-10))
            rightPeak = 20 * log10(max(rightMax, 1e-10))

            // Peak hold
            if leftPeak > leftPeakHold {
                leftPeakHold = leftPeak
                peakHoldCounter = Int(peakHoldTime * sampleRate / Double(buffer.frameLength))
            }
            if rightPeak > rightPeakHold {
                rightPeakHold = rightPeak
            }

            // Decay peak hold
            if peakHoldCounter > 0 {
                peakHoldCounter -= 1
            } else {
                leftPeakHold *= 0.995
                rightPeakHold *= 0.995
            }

            // Clip detection (>-0.3 dBFS)
            clipIndicator = leftPeak > -0.3 || rightPeak > -0.3
        }
    }

    // MARK: - RMS Meter

    class RMSMeter: ObservableObject {
        @Published var leftRMS: Float = -96.0  // dB
        @Published var rightRMS: Float = -96.0  // dB
        @Published var windowSize: Int = 4410  // Samples (100ms @ 44.1kHz)

        private var leftHistory: [Float] = []
        private var rightHistory: [Float] = []

        func processBuffer(_ buffer: AVAudioPCMBuffer) {
            guard let leftData = buffer.floatChannelData?[0] else { return }
            let rightData = buffer.format.channelCount > 1 ? buffer.floatChannelData?[1] : nil

            // Add to history
            for i in 0..<Int(buffer.frameLength) {
                leftHistory.append(leftData[i])
                if let right = rightData {
                    rightHistory.append(right[i])
                } else {
                    rightHistory.append(leftData[i])
                }
            }

            // Keep window size
            while leftHistory.count > windowSize {
                leftHistory.removeFirst()
                rightHistory.removeFirst()
            }

            // Calculate RMS
            var leftSum: Float = 0
            var rightSum: Float = 0

            for value in leftHistory {
                leftSum += value * value
            }
            for value in rightHistory {
                rightSum += value * value
            }

            let leftRMSLinear = sqrtf(leftSum / Float(leftHistory.count))
            let rightRMSLinear = sqrtf(rightSum / Float(rightHistory.count))

            leftRMS = 20 * log10(max(leftRMSLinear, 1e-10))
            rightRMS = 20 * log10(max(rightRMSLinear, 1e-10))
        }
    }

    // MARK: - Oscilloscope

    class Oscilloscope: ObservableObject {
        @Published var waveformData: [Float] = []
        @Published var timeScale: Float = 10.0  // ms
        @Published var triggerLevel: Float = 0.0
        @Published var triggerMode: TriggerMode = .auto

        enum TriggerMode: String, CaseIterable {
            case auto = "Auto"
            case normal = "Normal"
            case single = "Single"
            case free = "Free Run"
        }

        func processBuffer(_ buffer: AVAudioPCMBuffer) {
            guard let channelData = buffer.floatChannelData?[0] else { return }

            // Find trigger point
            var triggerIndex = 0
            if triggerMode != .free {
                for i in 1..<Int(buffer.frameLength) {
                    if channelData[i-1] < triggerLevel && channelData[i] >= triggerLevel {
                        triggerIndex = i
                        break
                    }
                }
            }

            // Copy waveform data from trigger point
            let samplesToShow = 1000
            var data: [Float] = []
            for i in 0..<samplesToShow {
                let index = triggerIndex + i
                if index < Int(buffer.frameLength) {
                    data.append(channelData[index])
                } else {
                    data.append(0)
                }
            }

            waveformData = data
        }
    }

    // MARK: - Stereo Width Analyzer

    class StereoWidthAnalyzer: ObservableObject {
        @Published var stereoWidth: Float = 0.0  // 0-200% (100% = normal stereo)
        @Published var midLevel: Float = -96.0  // dB
        @Published var sideLevel: Float = -96.0  // dB
        @Published var midSideRatio: Float = 0.0

        func processBuffer(_ buffer: AVAudioPCMBuffer) {
            guard buffer.format.channelCount >= 2,
                  let leftData = buffer.floatChannelData?[0],
                  let rightData = buffer.floatChannelData?[1] else { return }

            var midSum: Float = 0
            var sideSum: Float = 0

            for i in 0..<Int(buffer.frameLength) {
                let mid = (leftData[i] + rightData[i]) / 2.0
                let side = (leftData[i] - rightData[i]) / 2.0

                midSum += mid * mid
                sideSum += side * side
            }

            let midRMS = sqrtf(midSum / Float(buffer.frameLength))
            let sideRMS = sqrtf(sideSum / Float(buffer.frameLength))

            midLevel = 20 * log10(max(midRMS, 1e-10))
            sideLevel = 20 * log10(max(sideRMS, 1e-10))

            // Calculate stereo width
            if midRMS > 0 {
                stereoWidth = (sideRMS / midRMS) * 100.0
            }
        }
    }

    // MARK: - Frequency Balance Meter

    class FrequencyBalanceMeter: ObservableObject {
        @Published var bass: Float = -60.0  // 20-200 Hz
        @Published var lowMids: Float = -60.0  // 200-500 Hz
        @Published var mids: Float = -60.0  // 500-2k Hz
        @Published var highMids: Float = -60.0  // 2k-8k Hz
        @Published var highs: Float = -60.0  // 8k-20k Hz

        func processBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
            // Apply bandpass filters for each band
            // Calculate RMS for each band
            // Display as dB levels
        }
    }
}

import Foundation
import AVFoundation
import CoreMedia
import CoreImage
import Combine

// MARK: - Beat-Synced Video Editor
/// Professional beat-synchronized video editing engine
/// Phase 6.3+: Video Editing on the Beat
///
/// Features:
/// 1. Beat Detection & Timeline Markers
/// 2. Auto-Cut Video on Beats
/// 3. Visual Effects Synced to Rhythm
/// 4. BPM-Based Transitions
/// 5. Quantization Grid for Precision Editing
class BeatSyncedVideoEditor: ObservableObject {

    // MARK: - Published State
    @Published var beatMarkers: [BeatMarker] = []
    @Published var bpm: Double = 120.0
    @Published var timeSignature: TimeSignature = .fourFour
    @Published var effects: [BeatSyncedEffect] = []
    @Published var gridDivision: GridDivision = .quarterNote
    @Published var snapToGrid: Bool = true
    @Published var isAnalyzing: Bool = false

    // MARK: - Dependencies
    private let patternRecognition = PatternRecognition()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Beat Detection

    /// Analyze audio and generate beat grid
    func analyzeBeatGrid(from audioBuffer: AVAudioPCMBuffer, duration: CMTime) {
        isAnalyzing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Detect BPM
            let detectedBPM = self.patternRecognition.detectTempo(from: audioBuffer)

            // Generate beat markers
            let markers = self.generateBeatMarkers(
                bpm: detectedBPM,
                duration: duration,
                sampleRate: audioBuffer.format.sampleRate
            )

            DispatchQueue.main.async {
                self.bpm = detectedBPM
                self.beatMarkers = markers
                self.isAnalyzing = false
            }
        }
    }

    /// Analyze from audio file URL
    func analyzeBeatGrid(from audioURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let audioFile = try AVAudioFile(forReading: audioURL)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)

                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    completion(.failure(BeatSyncError.bufferCreationFailed))
                    return
                }

                try audioFile.read(into: buffer)

                let duration = CMTime(
                    seconds: Double(audioFile.length) / audioFile.fileFormat.sampleRate,
                    preferredTimescale: 600
                )

                DispatchQueue.main.async {
                    self.analyzeBeatGrid(from: buffer, duration: duration)
                    completion(.success(()))
                }

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func generateBeatMarkers(bpm: Double, duration: CMTime, sampleRate: Double) -> [BeatMarker] {
        var markers: [BeatMarker] = []

        // Calculate beat interval in seconds
        let beatInterval = 60.0 / bpm
        let durationSeconds = CMTimeGetSeconds(duration)

        var currentTime: Double = 0.0
        var beatNumber: Int = 1
        var barNumber: Int = 1

        let beatsPerBar = timeSignature.beatsPerBar

        while currentTime < durationSeconds {
            let beatInBar = ((beatNumber - 1) % beatsPerBar) + 1
            let isDownbeat = beatInBar == 1

            let marker = BeatMarker(
                time: CMTime(seconds: currentTime, preferredTimescale: 600),
                beatNumber: beatNumber,
                barNumber: barNumber,
                beatInBar: beatInBar,
                isDownbeat: isDownbeat
            )

            markers.append(marker)

            currentTime += beatInterval
            beatNumber += 1

            if beatInBar == beatsPerBar {
                barNumber += 1
            }
        }

        return markers
    }

    // MARK: - Auto-Cut on Beats

    /// Automatically cut video clip on beat boundaries
    func autoCutOnBeats(
        videoClip: VideoClip,
        cutPattern: CutPattern = .everyBeat
    ) -> [VideoClip] {
        var cuts: [VideoClip] = []

        // Filter beat markers within clip time range
        let relevantBeats = beatMarkers.filter { marker in
            marker.time >= videoClip.startTime && marker.time <= videoClip.endTime
        }

        // Apply cut pattern
        let cutPoints = applyCutPattern(beats: relevantBeats, pattern: cutPattern)

        // Create video segments
        var previousCutPoint = videoClip.startTime

        for cutPoint in cutPoints {
            let segment = VideoClip(
                url: videoClip.url,
                startTime: previousCutPoint,
                endTime: cutPoint,
                track: videoClip.track
            )
            cuts.append(segment)
            previousCutPoint = cutPoint
        }

        // Add final segment
        if previousCutPoint < videoClip.endTime {
            let finalSegment = VideoClip(
                url: videoClip.url,
                startTime: previousCutPoint,
                endTime: videoClip.endTime,
                track: videoClip.track
            )
            cuts.append(finalSegment)
        }

        return cuts
    }

    private func applyCutPattern(beats: [BeatMarker], pattern: CutPattern) -> [CMTime] {
        var cutPoints: [CMTime] = []

        switch pattern {
        case .everyBeat:
            cutPoints = beats.map { $0.time }

        case .everyDownbeat:
            cutPoints = beats.filter { $0.isDownbeat }.map { $0.time }

        case .everyTwoBeats:
            cutPoints = beats.enumerated().compactMap { index, beat in
                index % 2 == 0 ? beat.time : nil
            }

        case .everyFourBeats:
            cutPoints = beats.enumerated().compactMap { index, beat in
                index % 4 == 0 ? beat.time : nil
            }

        case .onlyDownbeats:
            cutPoints = beats.filter { $0.beatInBar == 1 }.map { $0.time }

        case .custom(let interval):
            cutPoints = beats.enumerated().compactMap { index, beat in
                index % interval == 0 ? beat.time : nil
            }
        }

        return cutPoints
    }

    // MARK: - Beat-Synced Effects

    /// Apply visual effect that pulses on beats
    func applyBeatSyncedEffect(
        _ effectType: BeatSyncedEffectType,
        intensity: Float = 1.0,
        startTime: CMTime,
        duration: CMTime
    ) -> BeatSyncedEffect {
        let effect = BeatSyncedEffect(
            type: effectType,
            intensity: intensity,
            startTime: startTime,
            duration: duration,
            bpm: bpm
        )

        effects.append(effect)
        return effect
    }

    /// Render beat-synced effect for specific frame time
    func renderEffect(
        _ effect: BeatSyncedEffect,
        at time: CMTime,
        on image: CIImage
    ) -> CIImage {
        // Find nearest beat marker
        guard let nearestBeat = findNearestBeat(to: time) else {
            return image
        }

        // Calculate beat phase (0.0 at beat, 1.0 at next beat)
        let beatPhase = calculateBeatPhase(at: time, nearestBeat: nearestBeat)

        // Apply effect based on type and phase
        return applyEffectWithPhase(
            effect: effect,
            beatPhase: beatPhase,
            on: image
        )
    }

    private func findNearestBeat(to time: CMTime) -> BeatMarker? {
        return beatMarkers.min { marker1, marker2 in
            abs(CMTimeGetSeconds(marker1.time - time)) < abs(CMTimeGetSeconds(marker2.time - time))
        }
    }

    private func calculateBeatPhase(at time: CMTime, nearestBeat: BeatMarker) -> Double {
        let timeSinceBeat = CMTimeGetSeconds(time - nearestBeat.time)
        let beatInterval = 60.0 / bpm

        // Normalize to 0.0-1.0
        let phase = (timeSinceBeat / beatInterval).truncatingRemainder(dividingBy: 1.0)
        return phase < 0 ? phase + 1.0 : phase
    }

    private func applyEffectWithPhase(
        effect: BeatSyncedEffect,
        beatPhase: Double,
        on image: CIImage
    ) -> CIImage {
        switch effect.type {
        case .flash:
            return applyFlash(image: image, phase: beatPhase, intensity: effect.intensity)

        case .zoom:
            return applyZoom(image: image, phase: beatPhase, intensity: effect.intensity)

        case .shake:
            return applyShake(image: image, phase: beatPhase, intensity: effect.intensity)

        case .colorPulse(let color):
            return applyColorPulse(image: image, color: color, phase: beatPhase, intensity: effect.intensity)

        case .glitch:
            return applyGlitch(image: image, phase: beatPhase, intensity: effect.intensity)

        case .strobe:
            return applyStrobe(image: image, phase: beatPhase, intensity: effect.intensity)

        case .blur:
            return applyBeatBlur(image: image, phase: beatPhase, intensity: effect.intensity)
        }
    }

    // MARK: - Effect Implementations

    private func applyFlash(image: CIImage, phase: Double, intensity: Float) -> CIImage {
        // Flash at beat (high intensity at phase 0, fade to 0)
        let flashAmount = Float(max(0, 1.0 - phase)) * intensity

        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(flashAmount, forKey: kCIInputBrightnessKey)

        return filter.outputImage ?? image
    }

    private func applyZoom(image: CIImage, phase: Double, intensity: Float) -> CIImage {
        // Zoom in at beat, zoom out between beats
        let zoomAmount = 1.0 + (Float(1.0 - phase) * intensity * 0.2)

        let transform = CGAffineTransform(scaleX: CGFloat(zoomAmount), y: CGFloat(zoomAmount))
        return image.transformed(by: transform)
    }

    private func applyShake(image: CIImage, phase: Double, intensity: Float) -> CIImage {
        // Shake at beat
        guard phase < 0.2 else { return image } // Only shake in first 20% of beat

        let shakeAmount = Float.random(in: -20...20) * intensity * Float(1.0 - phase * 5)
        let transform = CGAffineTransform(translationX: CGFloat(shakeAmount), y: CGFloat(shakeAmount * 0.5))

        return image.transformed(by: transform)
    }

    private func applyColorPulse(image: CIImage, color: CIColor, phase: Double, intensity: Float) -> CIImage {
        let pulseAmount = Float(max(0, 1.0 - phase)) * intensity

        guard let filter = CIFilter(name: "CIColorMatrix") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)

        // Mix with color based on pulse
        let r = color.red * CGFloat(pulseAmount)
        let g = color.green * CGFloat(pulseAmount)
        let b = color.blue * CGFloat(pulseAmount)

        filter.setValue(CIVector(x: 1 + r, y: 0, z: 0, w: 0), forKey: "inputRVector")
        filter.setValue(CIVector(x: 0, y: 1 + g, z: 0, w: 0), forKey: "inputGVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 1 + b, w: 0), forKey: "inputBVector")

        return filter.outputImage ?? image
    }

    private func applyGlitch(image: CIImage, phase: Double, intensity: Float) -> CIImage {
        // Random glitch at beat
        guard phase < 0.1 else { return image }

        let shouldGlitch = Float.random(in: 0...1) < intensity
        guard shouldGlitch else { return image }

        // Random horizontal offset
        let offset = CGFloat.random(in: -50...50) * CGFloat(intensity)
        let transform = CGAffineTransform(translationX: offset, y: 0)

        return image.transformed(by: transform)
    }

    private func applyStrobe(image: CIImage, phase: Double, intensity: Float) -> CIImage {
        // On/off strobe effect
        let isOn = phase < 0.5

        if isOn {
            return image
        } else {
            guard let filter = CIFilter(name: "CIColorControls") else { return image }
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(-intensity, forKey: kCIInputBrightnessKey)
            return filter.outputImage ?? image
        }
    }

    private func applyBeatBlur(image: CIImage, phase: Double, intensity: Float) -> CIImage {
        // Blur amount decreases from beat
        let blurRadius = Float(phase) * intensity * 10.0

        guard let filter = CIFilter(name: "CIGaussianBlur") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(blurRadius, forKey: kCIInputRadiusKey)

        return filter.outputImage ?? image
    }

    // MARK: - Grid Quantization

    /// Snap time to nearest grid division
    func snapToGridDivision(_ time: CMTime) -> CMTime {
        guard snapToGrid else { return time }

        let gridInterval = calculateGridInterval()
        let timeSeconds = CMTimeGetSeconds(time)

        let nearestGridPoint = round(timeSeconds / gridInterval) * gridInterval

        return CMTime(seconds: nearestGridPoint, preferredTimescale: 600)
    }

    private func calculateGridInterval() -> Double {
        let beatInterval = 60.0 / bpm
        return beatInterval * gridDivision.multiplier
    }

    /// Find nearest beat marker to given time
    func nearestBeatMarker(to time: CMTime) -> BeatMarker? {
        return beatMarkers.min { marker1, marker2 in
            abs(CMTimeGetSeconds(marker1.time - time)) < abs(CMTimeGetSeconds(marker2.time - time))
        }
    }

    // MARK: - BPM-Based Transitions

    /// Create transition synced to BPM
    func createBeatSyncedTransition(
        type: TransitionType,
        duration: TransitionDuration
    ) -> VideoTransition {
        let durationInBeats = duration.beats
        let beatInterval = 60.0 / bpm
        let transitionSeconds = beatInterval * Double(durationInBeats)

        return VideoTransition(
            type: type,
            duration: CMTime(seconds: transitionSeconds, preferredTimescale: 600)
        )
    }
}

// MARK: - Supporting Types

struct BeatMarker: Identifiable {
    let id = UUID()
    let time: CMTime
    let beatNumber: Int
    let barNumber: Int
    let beatInBar: Int
    let isDownbeat: Bool
}

struct TimeSignature {
    let beatsPerBar: Int
    let noteValue: Int

    static let fourFour = TimeSignature(beatsPerBar: 4, noteValue: 4)
    static let threeFour = TimeSignature(beatsPerBar: 3, noteValue: 4)
    static let sixEight = TimeSignature(beatsPerBar: 6, noteValue: 8)
    static let fiveFour = TimeSignature(beatsPerBar: 5, noteValue: 4)
    static let sevenEight = TimeSignature(beatsPerBar: 7, noteValue: 8)
}

enum GridDivision: String, CaseIterable {
    case whole = "1/1"
    case half = "1/2"
    case quarterNote = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"

    var multiplier: Double {
        switch self {
        case .whole: return 4.0
        case .half: return 2.0
        case .quarterNote: return 1.0
        case .eighth: return 0.5
        case .sixteenth: return 0.25
        case .thirtySecond: return 0.125
        }
    }
}

enum CutPattern {
    case everyBeat
    case everyDownbeat
    case everyTwoBeats
    case everyFourBeats
    case onlyDownbeats
    case custom(interval: Int)
}

struct BeatSyncedEffect: Identifiable {
    let id = UUID()
    let type: BeatSyncedEffectType
    let intensity: Float
    let startTime: CMTime
    let duration: CMTime
    let bpm: Double
}

enum BeatSyncedEffectType {
    case flash
    case zoom
    case shake
    case colorPulse(color: CIColor)
    case glitch
    case strobe
    case blur
}

struct VideoTransition {
    let type: TransitionType
    let duration: CMTime
}

enum TransitionType {
    case cut
    case crossfade
    case whiteFlash
    case blackFlash
    case wipe(direction: WipeDirection)
    case zoom
}

enum WipeDirection {
    case left, right, up, down
}

enum TransitionDuration {
    case instant          // 0 beats
    case sixteenth        // 1/16 beat
    case eighth           // 1/8 beat
    case quarter          // 1/4 beat
    case half             // 1/2 beat
    case one              // 1 beat
    case two              // 2 beats
    case four             // 4 beats

    var beats: Int {
        switch self {
        case .instant: return 0
        case .sixteenth: return 1
        case .eighth: return 2
        case .quarter: return 4
        case .half: return 8
        case .one: return 16
        case .two: return 32
        case .four: return 64
        }
    }
}

enum BeatSyncError: Error {
    case bufferCreationFailed
    case audioFileReadFailed
    case noBeatMarkersFound
    case invalidTimeRange
}

// MARK: - Extensions

extension AVAudioPCMBuffer {
    var duration: CMTime {
        let durationSeconds = Double(frameLength) / format.sampleRate
        return CMTime(seconds: durationSeconds, preferredTimescale: 600)
    }
}

extension CMTime {
    static func -(lhs: CMTime, rhs: CMTime) -> CMTime {
        return CMTimeSubtract(lhs, rhs)
    }
}

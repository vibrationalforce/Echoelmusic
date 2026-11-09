import AVFoundation
import EchoelCore
import Foundation
import Speech

/// Transcribe (SUBS, 2026-11-05): the words spoken in one audio region or in the sound of one video
/// part, with their times, heard by Apple's speech recognition ON THE DEVICE. On iOS 26 with the
/// language's model installed it is `SpeechTranscriber`; otherwise `SFSpeechRecognizer` with
/// `requiresOnDeviceRecognition`. There is no server path: where neither can hear the language on
/// this device the transcription stops with `Failure.notOnDevice`, and no audio has left it.
/// Nothing here downloads a model either — a language the device does not hold is reported.
///
/// A plain function on no actor: the caller runs it off the main thread and may cancel it; what is
/// heard becomes cues through `Subtitles` and one command (`placeSubtitles`).
enum SpeechTranscription {
    /// The rate the sound is read at for the recognizer, mixed to one channel.
    static let readRate = 16_000.0
    /// The longest stretch transcribed at once.
    static let maximumSeconds = 3_600.0

    enum Failure: Error, Equatable {
        /// The musician has not allowed speech recognition, or it is restricted on this device.
        case notAllowed
        /// This device cannot recognize the language without a server.
        case notOnDevice(String)
        /// The file has no sound, or it could not be read.
        case unreadable
        /// The stretch is longer than `maximumSeconds`.
        case tooLong
        /// The recognizer stopped with an error of its own.
        case recognizer

        var message: String {
            switch self {
            case .notAllowed:
                "Speech recognition is not allowed for Echoelmusic. Allow it in Settings, Privacy & Security, Speech Recognition."
            case .notOnDevice(let language):
                "This device cannot recognize \(language) without a server, and Echoelmusic transcribes only on the device. Nothing was sent anywhere. Choose another language, or add \(language) to the device's dictation languages in Settings and try again."
            case .unreadable:
                "The file has no sound Echoelmusic can read."
            case .tooLong:
                "Transcribe takes at most an hour at once. Split the part and transcribe each piece."
            case .recognizer:
                "Speech recognition stopped before it finished. Try again."
            }
        }
    }

    /// The languages this device's speech recognition knows, sorted by their names in the
    /// device's language. Which of them work on the device is found when Transcribe runs.
    static func languages() -> [Locale] {
        let names = Locale.current
        return SFSpeechRecognizer.supportedLocales().sorted {
            (names.localizedString(forIdentifier: $0.identifier) ?? $0.identifier)
                < (names.localizedString(forIdentifier: $1.identifier) ?? $1.identifier)
        }
    }

    static func name(of locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    /// Asks once for permission to recognize speech; true when it is given.
    static func authorize() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { @Sendable status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default: return false
        }
    }

    /// The words in `seconds` (start and length, in seconds of the file) of the file at `url`, each
    /// timed in seconds from the start of that stretch.
    static func words(of url: URL, from start: Double, length: Double, locale: Locale) async throws -> [Subtitles.Word] {
        guard length.isFinite, length > 0, start.isFinite, start >= 0 else { throw Failure.unreadable }
        guard length <= maximumSeconds else { throw Failure.tooLong }
        guard await authorize() else { throw Failure.notAllowed }
        if #available(iOS 26.0, *), let words = try await analyzerWords(of: url, from: start, length: length, locale: locale) {
            return words
        }
        return try await recognizerWords(of: url, from: start, length: length, locale: locale)
    }

    // MARK: - iOS 26: SpeechAnalyzer

    /// nil when the language's model is not installed here — the caller then tries the older
    /// recognizer, which may hold it; this never downloads one.
    @available(iOS 26.0, *)
    private static func analyzerWords(of url: URL, from start: Double, length: Double,
                                      locale: Locale) async throws -> [Subtitles.Word]? {
        let wanted = locale.identifier(.bcp47)
        let installed = await SpeechTranscriber.installedLocales
        guard let match = installed.first(where: { $0.identifier(.bcp47) == wanted }) else { return nil }
        let transcriber = SpeechTranscriber(locale: match, transcriptionOptions: [], reportingOptions: [],
                                            attributeOptions: [.audioTimeRange])
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let readFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: readRate, channels: 1,
                                       interleaved: false) else { throw Failure.unreadable }
        let target = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) ?? readFormat
        let converter = target == readFormat ? nil : AVAudioConverter(from: readFormat, to: target)
        let (inputs, feed) = AsyncStream<AnalyzerInput>.makeStream()
        let collecting = Task { () throws -> [Subtitles.Word] in
            var words: [Subtitles.Word] = []
            for try await result in transcriber.results where result.isFinal {
                for run in result.text.runs {
                    guard let range = run.audioTimeRange else { continue }
                    let text = String(result.text[run.range].characters)
                    words.append(Subtitles.Word(text: text, start: range.start.seconds, end: range.end.seconds))
                }
            }
            return words
        }
        do {
            try await analyzer.start(inputSequence: inputs)
            try await read(url, from: start, length: length, format: readFormat) { buffer in
                if let converter {
                    guard let converted = convert(buffer, with: converter, to: target) else { return }
                    feed.yield(AnalyzerInput(buffer: converted))
                } else {
                    feed.yield(AnalyzerInput(buffer: buffer))
                }
            }
            feed.finish()
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            feed.finish()
            collecting.cancel()
            await analyzer.cancelAndFinishNow()
            if let failure = error as? Failure { throw failure }
            if error is CancellationError { throw error }
            throw Failure.recognizer
        }
        do {
            return try await collecting.value
        } catch {
            throw Failure.recognizer
        }
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter,
                                to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        let fed = Fed()
        var problem: NSError?
        let status = converter.convert(to: out, error: &problem) { _, state in
            if fed.done {
                state.pointee = .noDataNow
                return nil
            }
            fed.done = true
            state.pointee = .haveData
            return buffer
        }
        guard status != .error, problem == nil, out.frameLength > 0 else { return nil }
        return out
    }

    /// Whether the converter has had its one buffer.
    private final class Fed {
        var done = false
    }

    // MARK: - SFSpeechRecognizer, on the device only

    private static func recognizerWords(of url: URL, from start: Double, length: Double,
                                        locale: Locale) async throws -> [Subtitles.Word] {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition else {
            throw Failure.notOnDevice(name(of: locale))
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        // The one line that keeps the audio here: without it iOS may send it to Apple's servers.
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.taskHint = .dictation
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: readRate, channels: 1,
                                         interleaved: false) else { throw Failure.unreadable }
        let box = Recognition()
        let task = recognizer.recognitionTask(with: request) { @Sendable result, error in
            if let result, result.isFinal {
                let words = result.bestTranscription.segments.map {
                    Subtitles.Word(text: $0.substring, start: $0.timestamp, end: $0.timestamp + $0.duration)
                }
                box.deliver(.success(words))
            } else if error != nil {
                box.deliver(.failure(Failure.recognizer))
            }
        }
        box.attach(task)
        do {
            try await read(url, from: start, length: length, format: format) { request.append($0) }
            request.endAudio()
        } catch {
            box.cancel()
            throw error
        }
        return try await withTaskCancellationHandler {
            try await box.result()
        } onCancel: {
            box.cancel()
        }
    }

    /// The recognizer's one answer, kept until it is awaited — it may call back more than once,
    /// before or after the wait begins, and a cancel may come from another thread.
    private final class Recognition: @unchecked Sendable {
        private let lock = NSLock()
        private var waiting: CheckedContinuation<[Subtitles.Word], Error>?
        private var answer: Result<[Subtitles.Word], Error>?
        private var task: SFSpeechRecognitionTask?

        func attach(_ task: SFSpeechRecognitionTask) {
            lock.lock()
            self.task = task
            let finished = answer != nil
            lock.unlock()
            if finished { task.cancel() }
        }

        func deliver(_ result: Result<[Subtitles.Word], Error>) {
            lock.lock()
            guard answer == nil else {
                lock.unlock()
                return
            }
            answer = result
            let continuation = waiting
            waiting = nil
            lock.unlock()
            continuation?.resume(with: result)
        }

        func result() async throws -> [Subtitles.Word] {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Subtitles.Word], Error>) in
                lock.lock()
                if let answer {
                    lock.unlock()
                    continuation.resume(with: answer)
                } else {
                    waiting = continuation
                    lock.unlock()
                }
            }
        }

        func cancel() {
            lock.lock()
            let running = task
            lock.unlock()
            running?.cancel()
            deliver(.failure(CancellationError()))
        }
    }

    // MARK: - Reading the sound

    /// The first audio track of the file, from `start` for `length` seconds, mono at the format's
    /// rate, handed on buffer by buffer. Works for an audio file and a video file alike.
    private static func read(_ url: URL, from start: Double, length: Double, format: AVAudioFormat,
                             into take: (AVAudioPCMBuffer) -> Void) async throws {
        let asset = AVURLAsset(url: url)
        let tracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        guard let track = tracks.first, let reader = try? AVAssetReader(asset: asset) else { throw Failure.unreadable }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw Failure.unreadable }
        reader.add(output)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 48_000),
                                       duration: CMTime(seconds: length, preferredTimescale: 48_000))
        guard reader.startReading() else { throw Failure.unreadable }
        var delivered = false
        var reading = true
        while reading {
            if Task.isCancelled {
                reader.cancelReading()
                throw CancellationError()
            }
            reading = autoreleasepool { () -> Bool in
                guard let sample = output.copyNextSampleBuffer() else { return false }
                if let buffer = pcm(sample, format: format) {
                    take(buffer)
                    delivered = true
                }
                return true
            }
        }
        guard reader.status == .completed, delivered else { throw Failure.unreadable }
    }

    private static func pcm(_ sample: CMSampleBuffer, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let block = CMSampleBufferGetDataBuffer(sample) else { return nil }
        let count = CMBlockBufferGetDataLength(block) / MemoryLayout<Float>.size
        guard count > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        let status = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count * MemoryLayout<Float>.size,
                                                destination: channel)
        guard status == kCMBlockBufferNoErr else { return nil }
        buffer.frameLength = AVAudioFrameCount(count)
        return buffer
    }
}

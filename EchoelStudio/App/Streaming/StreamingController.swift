import AVFoundation
import EchoelCore
import Foundation
import Observation
import UIKit
import os

/// Going live (wave W14): the one owner of a stream's life — the destinations the musician keeps
/// on this device, Go Live, Stop, and the end of a stream iOS forces. Off until Go Live: no
/// session, no tap, no picture before it, and nothing after Stop.
///
/// The picture is the Field (`FieldStreamSource`), the sound the master mix (`MasterAudioTap`),
/// the wire HaishinKit (`StreamPublisher`). The destinations' list (names, servers, shapes, bit
/// rates) is stored in `UserDefaults`; their keys only in the keychain (`StreamKeyStore`).
///
/// A stream ends cleanly when the app leaves the foreground (iOS refuses the GPU and the hardware
/// encoder there) and when a call or another app interrupts the audio — the page says why.
@MainActor
@Observable
final class StreamingController {
    private(set) var plan: StreamPlan
    private(set) var isLive = false
    private(set) var isStarting = false
    /// When the current stream went live; nil while off.
    private(set) var startedAt: Date?
    /// Why the last stream did not start or ended by itself, until the next Go Live.
    private(set) var notice: String?
    /// Each destination's reading while live. Changes about once a second: read it in a leaf.
    private(set) var reports: [UUID: StreamPublisher.Report] = [:]

    @ObservationIgnored private let publisher = StreamPublisher()
    @ObservationIgnored private var picture: FieldStreamSource?
    @ObservationIgnored private var sound: MasterAudioTap?
    @ObservationIgnored private weak var engine: AudioEngine?
    @ObservationIgnored private var pumps: [Task<Void, Never>] = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "streaming")

    private static let targetsKey = "streamTargets"
    private static let limitKey = "streamSimultaneousLimit"

    init() {
        let defaults = UserDefaults.standard
        let targets = defaults.data(forKey: Self.targetsKey)
            .flatMap { try? JSONDecoder().decode([StreamTarget].self, from: $0) } ?? []
        let limit = defaults.object(forKey: Self.limitKey) as? Int ?? 1
        plan = StreamPlan(targets: targets, simultaneousLimit: limit)
        observeTheSystem()
    }

    // MARK: - Destinations

    func add(_ platform: StreamPlatform) -> StreamTarget {
        let target = StreamTarget(platform: platform, isEnabled: plan.enabledTargets.isEmpty)
        plan.targets.append(target)
        save()
        return target
    }

    func update(_ target: StreamTarget) {
        guard let index = plan.targets.firstIndex(where: { $0.id == target.id }) else { return }
        plan.targets[index] = target
        save()
    }

    func remove(_ id: UUID) {
        plan.targets.removeAll { $0.id == id }
        StreamKeyStore.removeKey(for: id)
        save()
    }

    func setSimultaneousLimit(_ limit: Int) {
        plan.simultaneousLimit = limit
        save()
    }

    /// Whether `target` could be sent to now: its address builds with the stored key.
    func addressProblem(of target: StreamTarget) -> String? {
        do {
            _ = try target.publishURL(key: StreamKeyStore.key(for: target.id) ?? "")
            return nil
        } catch let failure as StreamTarget.AddressError {
            return failure.explanation
        } catch {
            return error.localizedDescription
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(plan.targets) { defaults.set(data, forKey: Self.targetsKey) }
        defaults.set(plan.simultaneousLimit, forKey: Self.limitKey)
    }

    // MARK: - Live

    /// Opens every turned-on destination with the Field and the master mix.
    func goLive(store: ProjectStore, engine: AudioEngine) async {
        guard !isLive, !isStarting else { return }
        notice = nil
        if let refusal = plan.refusal {
            notice = refusal.explanation
            return
        }
        var addresses: [(StreamTarget, URL)] = []
        for target in plan.enabledTargets {
            do {
                let url = try target.publishURL(key: StreamKeyStore.key(for: target.id) ?? "")
                addresses.append((target, url))
            } catch let failure as StreamTarget.AddressError {
                notice = "\(target.name): \(failure.explanation)"
                return
            } catch {
                notice = "\(target.name): \(error.localizedDescription)"
                return
            }
        }
        guard let picture = FieldStreamSource(store: store, engine: engine) else {
            notice = "This device cannot draw the Field for a stream (no Metal)."
            return
        }
        isStarting = true
        DiagnosticLog.app.note("stream: go live", [("destinations", Double(addresses.count))])
        let sound = MasterAudioTap()
        self.picture = picture
        self.sound = sound
        self.engine = engine
        engine.setStreamTap(sound)
        picture.start(formats: plan.enabledFormats)
        let publisher = publisher
        await publisher.setOnUpdate { [weak self] id, report in
            Task { @MainActor in self?.received(id, report) }
        }
        // Two ordered pumps off the main actor: every frame and every block in the order made.
        let frames = picture.frames
        let blocks = sound.blocks
        pumps = [
            Task.detached {
                for await frame in frames { await publisher.append(frame) }
            },
            Task.detached {
                for await block in blocks { await publisher.append(block) }
            },
        ]
        var opened = 0
        for (target, url) in addresses {
            log.info("stream: opening \(target.redactedServer, privacy: .public)")
            do {
                try await publisher.open(target, url: url)
                opened += 1
            } catch {
                log.error("stream: \(target.redactedServer, privacy: .public) refused")
            }
            // Stop was pressed (or the app left) while this destination connected.
            guard isStarting else { return }
        }
        isStarting = false
        guard opened > 0 else {
            await end(because: notice ?? "No destination accepted the stream.")
            return
        }
        isLive = true
        startedAt = Date()
        DiagnosticLog.app.note("stream: live", [("destinations", Double(opened))])
    }

    /// The musician's Stop.
    func stop() async {
        await end(because: nil)
    }

    private func end(because reason: String?) async {
        guard isLive || isStarting || picture != nil else { return }
        if reason == nil { DiagnosticLog.app.note("stream: stop") } else { DiagnosticLog.app.note("stream: ended") }
        isStarting = false
        isLive = false
        startedAt = nil
        if let reason { notice = reason }
        picture?.stop()
        picture = nil
        engine?.setStreamTap(nil)
        sound?.finish()
        sound = nil
        for pump in pumps { pump.cancel() }
        pumps = []
        await publisher.closeAll()
        await publisher.setOnUpdate(nil)
    }

    private func received(_ id: UUID, _ report: StreamPublisher.Report) {
        reports[id] = report
        if case .failed(let reason) = report.state, let name = plan.targets.first(where: { $0.id == id })?.name {
            notice = "\(name): \(reason)"
        }
        // Every destination that was live has dropped: the stream is over.
        guard isLive else { return }
        let stillLive = reports.values.contains { $0.state == .live || $0.state == .connecting }
        if !stillLive { Task { await end(because: notice ?? "The stream ended.") } }
    }

    // MARK: - What iOS forces

    private func observeTheSystem() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isLive || self.isStarting else { return }
                Task { await self.end(because: "The stream ended: Echoel left the screen, and iOS stops video in the background.") }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let began = raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began
            MainActor.assumeIsolated {
                guard began, let self, self.isLive || self.isStarting else { return }
                Task { await self.end(because: "The stream ended: a call or another app took the audio.") }
            }
        })
    }
}

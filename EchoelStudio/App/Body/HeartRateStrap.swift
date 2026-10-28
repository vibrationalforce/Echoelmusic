import CoreBluetooth
import EchoelCore
import EchoelDSP
import EchoelEngine
import Foundation
import Observation
import os

/// A Bluetooth chest strap (Heart Rate service 0x180D) as a body source: wave W1. Off until the
/// musician turns it on; only then does iOS ask for Bluetooth. This class is the ONE owner of the
/// strap's life — scan, connect, subscribe, stop — as the earlier app learned (a second owner
/// killed a running strap on an unrelated edit).
///
/// The pulse goes through a `BodyChannel`, so it is a value only while it is real: from the strap
/// of the current run, in order, with contact, between 40 and 200 bpm and no older than three
/// seconds. Nothing here invents a pulse; with no strap the value is nil.
@MainActor
@Observable
final class HeartRateStrap: NSObject {
    enum Status: Equatable {
        case off
        case unavailable
        case denied
        case searching
        case notFound
        case connecting(String)
        case connected(String)
        case lost(String)
    }

    private(set) var status: Status = .off
    /// The pulse channel: normalized 0 … 1 over 40 … 200 bpm, nil while not measured.
    private(set) var pulse = BodyChannel(maximumAgeMilliseconds: HeartRateStrap.freshMilliseconds)
    /// The last measured rate, only while `pulse` holds a value.
    private(set) var beatsPerMinute: Int?
    /// The newest beat-to-beat intervals, oldest first, at most `intervalCapacity`.
    private(set) var rrIntervalsMilliseconds: [Double] = []
    /// The sources that carry a value right now — what a route would actually follow. Changes
    /// only when a source starts or stops being measured, so a menu may read it (Law 6).
    private(set) var measuring: Set<ModulationSource> = []

    static let plausibleBeats = 40...200
    /// A strap sends about once a second; three missed packets and the pulse is no longer live.
    static let freshMilliseconds: Int64 = 3_000
    /// The scan gives up after this long without a strap, so the status says so.
    static let scanSeconds: Double = 20
    static let intervalCapacity = 64

    private static let service = CBUUID(string: "180D")
    private static let measurement = CBUUID(string: "2A37")

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var sequence: Int64 = 0
    @ObservationIgnored private var scanTimeout: Task<Void, Never>?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let started = ContinuousClock.now
    /// Where the pulse goes as the heart-rate modulation source (W2). It glides there over about
    /// `glideSeconds` instead of stepping once a second, and is absent the moment the pulse is.
    @ObservationIgnored var output: ModulationInputs?
    @ObservationIgnored private var glide: Task<Void, Never>?
    /// Where each source the strap feeds stands in its glide; absent sources are not in it.
    @ObservationIgnored private var gliding: [ModulationSource: Double] = [:]
    /// HRV and coherence from the newest intervals, nil while they cannot be stated.
    @ObservationIgnored private var derived = BeatDerivedSources.Readings(hrv: nil, coherence: nil)
    /// The sources the strap feeds.
    static let feeds: [ModulationSource] = [.heartRate, .hrv, .coherence]
    static let glideSeconds = 0.6
    static let glideStepSeconds = 1.0 / 30
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "body")

    var isOn: Bool { status != .off }

    /// The musician turned the strap on.
    func start() {
        guard !isOn else { return }
        apply(.start(.ble, Self.permission(CBCentralManager.authorization)))
        status = .searching
        rrIntervalsMilliseconds = []
        derived = BeatDerivedSources.Readings(hrv: nil, coherence: nil)
        if let central {
            centralChanged(central)
        } else {
            central = CBCentralManager(delegate: self, queue: nil)
        }
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.apply(.tick)
            }
        }
        glide = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.glideStepSeconds))
                self?.glideTowardsPulse()
            }
        }
    }

    /// One step of the glide: each source towards its measurement, or absent at once without
    /// one. HRV and coherence exist only while the pulse does — they come from its beats.
    private func glideTowardsPulse() {
        let factor = 1 - Foundation.exp(-Self.glideStepSeconds / Self.glideSeconds)
        let pulseValue = pulse.value
        for source in Self.feeds {
            let target: Double? = switch source {
            case .heartRate: pulseValue
            case .hrv: pulseValue == nil ? nil : derived.hrv
            case .coherence: pulseValue == nil ? nil : derived.coherence
            default: nil
            }
            guard let target else {
                if gliding.removeValue(forKey: source) != nil { output?.set(source, nil) }
                continue
            }
            let next = gliding[source].map { $0 + (target - $0) * factor } ?? target
            gliding[source] = next
            output?.set(source, next)
        }
        let now = Set(gliding.keys)
        if now != measuring { measuring = now }
    }

    /// The musician turned it off: the connection ends and the value is gone.
    func stop() {
        guard isOn else { return }
        scanTimeout?.cancel()
        ticker?.cancel()
        glide?.cancel()
        gliding = [:]
        measuring = []
        derived = BeatDerivedSources.Readings(hrv: nil, coherence: nil)
        for source in Self.feeds { output?.set(source, nil) }
        if let central {
            if central.isScanning { central.stopScan() }
            if let peripheral { central.cancelPeripheralConnection(peripheral) }
        }
        peripheral = nil
        apply(.stop)
        status = .off
        rrIntervalsMilliseconds = []
    }

    // MARK: - Steps

    private var nowMilliseconds: Int64 {
        let elapsed = ContinuousClock.now - started
        return elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000
    }

    private func apply(_ event: BodyChannel.Event) {
        do {
            _ = try pulse.step(event, at: nowMilliseconds)
        } catch {
            log.error("body clock went back — \(String(describing: error), privacy: .public)")
        }
        if pulse.value == nil { beatsPerMinute = nil }
    }

    private static func permission(_ authorization: CBManagerAuthorization) -> BodyChannel.Permission {
        switch authorization {
        case .allowedAlways: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .unknown
        @unknown default: .unknown
        }
    }

    private func centralChanged(_ central: CBCentralManager) {
        guard isOn else { return }
        let permission = Self.permission(CBCentralManager.authorization)
        apply(.permission(permission, source: .ble, epoch: pulse.epoch))
        switch central.state {
        case .poweredOn:
            guard peripheral == nil else { return }
            scan(central)
        case .unauthorized:
            status = .denied
        case .poweredOff, .unsupported:
            status = .unavailable
        default:
            break
        }
    }

    private func scan(_ central: CBCentralManager) {
        status = .searching
        // A strap already paired by another app is not advertising; ask the system first.
        if let known = central.retrieveConnectedPeripherals(withServices: [Self.service]).first {
            connect(known, with: central)
            return
        }
        central.scanForPeripherals(withServices: [Self.service])
        scanTimeout?.cancel()
        scanTimeout = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.scanSeconds))
            guard let self, !Task.isCancelled, self.status == .searching else { return }
            self.central?.stopScan()
            self.status = .notFound
        }
    }

    private func connect(_ found: CBPeripheral, with central: CBCentralManager) {
        scanTimeout?.cancel()
        if central.isScanning { central.stopScan() }
        peripheral = found
        found.delegate = self
        status = .connecting(found.name ?? "Heart rate strap")
        central.connect(found)
    }

    private func received(_ bytes: [UInt8]) {
        guard isOn else { return }
        sequence += 1
        let now = nowMilliseconds
        let packet = HeartRateMeasurement(bytes)
        let normalized = packet.flatMap { reading -> Double? in
            guard Self.plausibleBeats.contains(reading.beatsPerMinute) else { return nil }
            return Double(reading.beatsPerMinute - Self.plausibleBeats.lowerBound)
                / Double(Self.plausibleBeats.upperBound - Self.plausibleBeats.lowerBound)
        }
        // Contact reported is full quality; a strap that cannot report contact is trusted less,
        // still above the channel's floor. Off the skin there is no packet, so no value.
        let quality: Double? = packet.map { $0.contact == .detected ? 1 : 0.8 }
        apply(.sample(.init(source: .ble, epoch: pulse.epoch, sequence: sequence, capturedMilliseconds: now,
                            value: normalized, quality: quality)))
        if pulse.value != nil, let packet {
            beatsPerMinute = packet.beatsPerMinute
            rrIntervalsMilliseconds.append(contentsOf: packet.rrIntervalsMilliseconds)
            if rrIntervalsMilliseconds.count > Self.intervalCapacity {
                rrIntervalsMilliseconds.removeFirst(rrIntervalsMilliseconds.count - Self.intervalCapacity)
            }
            derived = BeatDerivedSources.readings(rrMs: rrIntervalsMilliseconds)
        }
    }
}

// MARK: - CoreBluetooth (delivered on the main queue: `queue: nil`)

// `@preconcurrency`: CoreBluetooth predates Swift concurrency, and its objects are not Sendable.
// The manager is created with `queue: nil`, so every callback arrives on the main queue; the
// conformance lets these methods stay main-actor isolated, and Swift checks that at entry.
// (`nonisolated` + `MainActor.assumeIsolated` failed the Xcode 26.2 gate: "sending 'central'
// risks causing data races".)
extension HeartRateStrap: @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralChanged(central)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard isOn, self.peripheral == nil else { return }
        connect(peripheral, with: central)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard isOn, peripheral == self.peripheral else { return }
        status = .connected(peripheral.name ?? "Heart rate strap")
        peripheral.discoverServices([Self.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard isOn, peripheral == self.peripheral else { return }
        self.peripheral = nil
        status = .lost(peripheral.name ?? "Heart rate strap")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        guard isOn, peripheral == self.peripheral else { return }
        self.peripheral = nil
        status = .lost(peripheral.name ?? "Heart rate strap")
        // The value ends with the strap; a new run starts when it is found again, and its
        // intervals do not continue the old run's — a gap is not a beat.
        rrIntervalsMilliseconds = []
        derived = BeatDerivedSources.Readings(hrv: nil, coherence: nil)
        apply(.suspend)
        apply(.resume)
        scan(central)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard isOn, peripheral == self.peripheral else { return }
        for service in peripheral.services ?? [] where service.uuid == Self.service {
            peripheral.discoverCharacteristics([Self.measurement], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard isOn, peripheral == self.peripheral else { return }
        for characteristic in service.characteristics ?? [] where characteristic.uuid == Self.measurement {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard isOn, peripheral == self.peripheral, let value = characteristic.value else { return }
        received([UInt8](value))
    }
}

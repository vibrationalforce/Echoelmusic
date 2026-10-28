import CoreBluetooth
import EchoelCore
import EchoelDSP
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
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "body")

    var isOn: Bool { status != .off }

    /// The musician turned the strap on.
    func start() {
        guard !isOn else { return }
        apply(.start(.ble, Self.permission(CBCentralManager.authorization)))
        status = .searching
        rrIntervalsMilliseconds = []
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
    }

    /// The musician turned it off: the connection ends and the value is gone.
    func stop() {
        guard isOn else { return }
        scanTimeout?.cancel()
        ticker?.cancel()
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
        }
    }
}

// MARK: - CoreBluetooth (delivered on the main queue: `queue: nil`)

extension HeartRateStrap: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated { centralChanged(central) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        MainActor.assumeIsolated {
            guard isOn, self.peripheral == nil else { return }
            connect(peripheral, with: central)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            guard isOn, peripheral == self.peripheral else { return }
            status = .connected(peripheral.name ?? "Heart rate strap")
            peripheral.discoverServices([Self.service])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        MainActor.assumeIsolated {
            guard isOn, peripheral == self.peripheral else { return }
            self.peripheral = nil
            status = .lost(peripheral.name ?? "Heart rate strap")
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        MainActor.assumeIsolated {
            guard isOn, peripheral == self.peripheral else { return }
            self.peripheral = nil
            status = .lost(peripheral.name ?? "Heart rate strap")
            // The value ends with the strap; a new run starts when it is found again.
            apply(.suspend)
            apply(.resume)
            scan(central)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            guard isOn, peripheral == self.peripheral else { return }
            for service in peripheral.services ?? [] where service.uuid == Self.service {
                peripheral.discoverCharacteristics([Self.measurement], for: service)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        MainActor.assumeIsolated {
            guard isOn, peripheral == self.peripheral else { return }
            for characteristic in service.characteristics ?? [] where characteristic.uuid == Self.measurement {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        let bytes = characteristic.value.map { [UInt8]($0) }
        MainActor.assumeIsolated {
            guard isOn, peripheral == self.peripheral, let bytes else { return }
            received(bytes)
        }
    }
}

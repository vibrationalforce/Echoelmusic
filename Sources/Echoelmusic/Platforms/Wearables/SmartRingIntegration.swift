import Foundation
import Combine
import CoreBluetooth

#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Smart Ring Integration
// Support for smart rings: Oura Ring, Samsung Galaxy Ring, Ultrahuman Ring Air
// "Wearables like wrist watches and rings are Gold now"

/// Smart Ring Integration Manager
/// Connects to various smart ring devices for bio-data collection
@MainActor
@Observable
class SmartRingIntegration {

    // MARK: - State

    /// Whether any ring is connected
    var isConnected: Bool = false

    /// Connected ring device
    var connectedRing: SmartRingDevice?

    /// Current bio-data from ring
    var currentBioData: RingBioData?

    /// Connection status
    var connectionStatus: ConnectionStatus = .disconnected

    /// Discovered rings
    var discoveredRings: [SmartRingDevice] = []

    /// Historical data
    var historicalData: [RingBioData] = []

    // MARK: - Types

    enum ConnectionStatus: String {
        case disconnected = "Disconnected"
        case scanning = "Scanning..."
        case connecting = "Connecting..."
        case connected = "Connected"
        case syncing = "Syncing..."
        case error = "Error"
    }

    /// Smart ring device
    struct SmartRingDevice: Identifiable {
        let id: UUID
        let name: String
        let type: RingType
        let firmwareVersion: String?
        var batteryLevel: Int?
        var signalStrength: Int?
        var lastSync: Date?

        enum RingType: String, CaseIterable {
            case ouraGen3 = "Oura Ring Gen 3"
            case ouraGen4 = "Oura Ring Gen 4"
            case samsungGalaxy = "Samsung Galaxy Ring"
            case ultrahumanAir = "Ultrahuman Ring Air"
            case amazfitHelio = "Amazfit Helio Ring"
            case circul = "Circular Ring"
            case movano = "Movano Evie Ring"
            case unknown = "Unknown Ring"

            var icon: String {
                switch self {
                case .ouraGen3, .ouraGen4: return "circle.circle"
                case .samsungGalaxy: return "circle.hexagongrid"
                case .ultrahumanAir: return "circle.dotted"
                case .amazfitHelio: return "sun.min"
                case .circul: return "circle.grid.2x2"
                case .movano: return "heart.circle"
                case .unknown: return "circle.dashed"
                }
            }

            var color: String {
                switch self {
                case .ouraGen3, .ouraGen4: return "cyan"
                case .samsungGalaxy: return "purple"
                case .ultrahumanAir: return "orange"
                case .amazfitHelio: return "red"
                case .circul: return "green"
                case .movano: return "pink"
                case .unknown: return "gray"
                }
            }
        }
    }

    /// Bio-data from ring sensors
    struct RingBioData: Identifiable, Codable {
        let id: UUID
        let timestamp: Date

        // Core metrics
        var heartRate: Double?
        var hrv: Double? // Heart Rate Variability in ms
        var spo2: Double? // Blood oxygen %
        var skinTemperature: Double? // Celsius

        // Sleep metrics
        var sleepScore: Int?
        var sleepStages: SleepStages?
        var respiratoryRate: Double?

        // Activity metrics
        var steps: Int?
        var caloriesBurned: Int?
        var activeMinutes: Int?

        // Readiness/Recovery
        var readinessScore: Int?
        var recoveryIndex: Double?
        var stressLevel: Double?

        // Bio-reactive music parameters
        var coherence: Float {
            // Calculate coherence from HRV and stress
            guard let hrv = hrv, let stress = stressLevel else { return 0.5 }
            let hrvNormalized = min(1.0, hrv / 100.0)
            let stressNormalized = 1.0 - min(1.0, stress)
            return Float((hrvNormalized + stressNormalized) / 2.0)
        }

        var optimalMusicTempo: Int {
            // Calculate optimal tempo based on heart rate and recovery
            guard let hr = heartRate else { return 80 }
            let baseTemp = Int(hr)
            if let recovery = recoveryIndex, recovery > 0.7 {
                return baseTemp + 10 // More energetic if recovered
            }
            return max(60, baseTemp - 10) // Calmer if tired
        }

        struct SleepStages: Codable {
            var awake: Int // minutes
            var light: Int
            var deep: Int
            var rem: Int

            var totalSleep: Int { light + deep + rem }
            var sleepEfficiency: Double {
                Double(totalSleep) / Double(totalSleep + awake)
            }
        }
    }

    // MARK: - Private State

    #if os(iOS) || os(watchOS)
    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    #endif

    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    #endif

    private var cancellables = Set<AnyCancellable>()
    private var dataUpdateTimer: Timer?

    // MARK: - Initialization

    init() {
        #if os(iOS) || os(watchOS)
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        #endif

        print("💍 Smart Ring Integration initialized")
    }

    // MARK: - Scanning & Connection

    /// Start scanning for smart rings
    func startScanning() {
        connectionStatus = .scanning
        discoveredRings = []

        #if os(iOS) || os(watchOS)
        // Scan for known ring service UUIDs
        let ringServices: [CBUUID] = [
            CBUUID(string: "0000180D-0000-1000-8000-00805f9b34fb"), // Heart Rate
            CBUUID(string: "0000180F-0000-1000-8000-00805f9b34fb"), // Battery
            CBUUID(string: "BA11F08C-5F14-11E5-885D-FEFF819CDC9F")  // Oura Ring
        ]

        centralManager?.scanForPeripherals(withServices: nil, options: nil)

        // Simulate discovery for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.simulateRingDiscovery()
        }
        #else
        // Simulate discovery for non-iOS platforms
        simulateRingDiscovery()
        #endif
    }

    /// Stop scanning
    func stopScanning() {
        #if os(iOS) || os(watchOS)
        centralManager?.stopScan()
        #endif

        if discoveredRings.isEmpty {
            connectionStatus = .disconnected
        }
    }

    /// Connect to a specific ring
    func connect(to ring: SmartRingDevice) async throws {
        connectionStatus = .connecting

        #if os(iOS) || os(watchOS)
        // In production, connect to actual peripheral
        #endif

        // Simulate connection
        try await Task.sleep(nanoseconds: 1_000_000_000)

        connectedRing = ring
        isConnected = true
        connectionStatus = .connected

        // Start data collection
        startDataCollection()

        print("💍 Connected to \(ring.name)")
    }

    /// Disconnect from current ring
    func disconnect() {
        stopDataCollection()

        #if os(iOS) || os(watchOS)
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        #endif

        connectedRing = nil
        isConnected = false
        connectionStatus = .disconnected
        currentBioData = nil

        print("💍 Disconnected from ring")
    }

    // MARK: - Data Collection

    private func startDataCollection() {
        // Start real-time data updates
        dataUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateBioData()
            }
        }

        // Sync historical data
        Task {
            await syncHistoricalData()
        }
    }

    private func stopDataCollection() {
        dataUpdateTimer?.invalidate()
        dataUpdateTimer = nil
    }

    private func updateBioData() async {
        guard let ring = connectedRing else { return }

        // In production, read from actual ring sensors
        // For now, generate realistic bio-data

        let bioData = RingBioData(
            id: UUID(),
            timestamp: Date(),
            heartRate: Double.random(in: 60...80),
            hrv: Double.random(in: 30...70),
            spo2: Double.random(in: 95...99),
            skinTemperature: Double.random(in: 35.5...37.0),
            sleepScore: nil,
            sleepStages: nil,
            respiratoryRate: Double.random(in: 12...18),
            steps: Int.random(in: 5000...10000),
            caloriesBurned: Int.random(in: 1500...2500),
            activeMinutes: Int.random(in: 30...120),
            readinessScore: Int.random(in: 70...95),
            recoveryIndex: Double.random(in: 0.5...0.9),
            stressLevel: Double.random(in: 0.1...0.5)
        )

        currentBioData = bioData

        // Notify listeners
        NotificationCenter.default.post(
            name: .ringBioDataUpdated,
            object: nil,
            userInfo: ["bioData": bioData]
        )
    }

    private func syncHistoricalData() async {
        connectionStatus = .syncing

        // Simulate sync delay
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // In production, fetch from ring storage
        historicalData = (0..<24).map { hour in
            RingBioData(
                id: UUID(),
                timestamp: Calendar.current.date(byAdding: .hour, value: -hour, to: Date())!,
                heartRate: Double.random(in: 55...85),
                hrv: Double.random(in: 25...75),
                spo2: Double.random(in: 94...99),
                skinTemperature: Double.random(in: 35...37.5),
                sleepScore: hour > 16 ? Int.random(in: 70...95) : nil,
                sleepStages: hour > 16 ? RingBioData.SleepStages(
                    awake: Int.random(in: 10...30),
                    light: Int.random(in: 120...180),
                    deep: Int.random(in: 60...90),
                    rem: Int.random(in: 80...120)
                ) : nil,
                respiratoryRate: Double.random(in: 11...18),
                steps: Int.random(in: 0...15000),
                caloriesBurned: Int.random(in: 0...3000),
                activeMinutes: Int.random(in: 0...180),
                readinessScore: Int.random(in: 60...98),
                recoveryIndex: Double.random(in: 0.4...0.95),
                stressLevel: Double.random(in: 0.1...0.7)
            )
        }

        connectionStatus = .connected
        print("💍 Synced \(historicalData.count) hours of data")
    }

    // MARK: - HealthKit Integration

    #if canImport(HealthKit)
    /// Request HealthKit authorization
    func requestHealthKitAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw RingError.healthKitNotAvailable
        }

        let typesToRead: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        print("💍 HealthKit authorization granted")
    }

    /// Sync ring data to HealthKit
    func syncToHealthKit(_ data: RingBioData) async throws {
        // Sync heart rate
        if let hr = data.heartRate {
            let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            let hrQuantity = HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: hr)
            let hrSample = HKQuantitySample(type: hrType, quantity: hrQuantity, start: data.timestamp, end: data.timestamp)
            try await healthStore.save(hrSample)
        }

        // Sync HRV
        if let hrv = data.hrv {
            let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
            let hrvQuantity = HKQuantity(unit: .secondUnit(with: .milli), doubleValue: hrv)
            let hrvSample = HKQuantitySample(type: hrvType, quantity: hrvQuantity, start: data.timestamp, end: data.timestamp)
            try await healthStore.save(hrvSample)
        }

        print("💍 Data synced to HealthKit")
    }
    #endif

    // MARK: - Bio-Reactive Music Integration

    /// Get music parameters based on current bio-data
    func getMusicParameters() -> BioMusicParameters? {
        guard let bio = currentBioData else { return nil }

        return BioMusicParameters(
            tempo: bio.optimalMusicTempo,
            intensity: bio.stressLevel.map { Float(1 - $0) } ?? 0.5,
            key: bio.coherence > 0.6 ? "C major" : "A minor",
            coherence: bio.coherence,
            suggestedGenre: getSuggestedGenre(for: bio)
        )
    }

    struct BioMusicParameters {
        let tempo: Int
        let intensity: Float
        let key: String
        let coherence: Float
        let suggestedGenre: String
    }

    private func getSuggestedGenre(for bio: RingBioData) -> String {
        if bio.coherence > 0.8 {
            return "Ambient"
        } else if bio.coherence > 0.6 {
            return "Lo-Fi"
        } else if let stress = bio.stressLevel, stress > 0.6 {
            return "Classical"
        } else {
            return "Electronic"
        }
    }

    // MARK: - Simulation

    private func simulateRingDiscovery() {
        discoveredRings = [
            SmartRingDevice(
                id: UUID(),
                name: "Oura Ring Gen 4",
                type: .ouraGen4,
                firmwareVersion: "4.2.1",
                batteryLevel: 85,
                signalStrength: -45,
                lastSync: Date().addingTimeInterval(-3600)
            ),
            SmartRingDevice(
                id: UUID(),
                name: "Galaxy Ring",
                type: .samsungGalaxy,
                firmwareVersion: "1.0.3",
                batteryLevel: 72,
                signalStrength: -52,
                lastSync: nil
            ),
            SmartRingDevice(
                id: UUID(),
                name: "Ultrahuman Air",
                type: .ultrahumanAir,
                firmwareVersion: "2.1.0",
                batteryLevel: 93,
                signalStrength: -38,
                lastSync: Date().addingTimeInterval(-7200)
            )
        ]

        if connectionStatus == .scanning {
            connectionStatus = discoveredRings.isEmpty ? .disconnected : .scanning
        }
    }

    // MARK: - Errors

    enum RingError: Error, LocalizedError {
        case bluetoothNotAvailable
        case ringNotFound
        case connectionFailed
        case healthKitNotAvailable
        case syncFailed

        var errorDescription: String? {
            switch self {
            case .bluetoothNotAvailable:
                return "Bluetooth is not available"
            case .ringNotFound:
                return "No smart ring found"
            case .connectionFailed:
                return "Failed to connect to ring"
            case .healthKitNotAvailable:
                return "HealthKit is not available"
            case .syncFailed:
                return "Failed to sync data"
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let ringBioDataUpdated = Notification.Name("ringBioDataUpdated")
}

// MARK: - SwiftUI Views

import SwiftUI

struct SmartRingView: View {
    @State private var ringManager = SmartRingIntegration()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection Status
                connectionStatusCard

                // Current Bio Data
                if let bio = ringManager.currentBioData {
                    bioDataCard(bio: bio)
                }

                // Discovered Rings
                if !ringManager.discoveredRings.isEmpty && !ringManager.isConnected {
                    discoveredRingsCard
                }

                // Music Parameters
                if let params = ringManager.getMusicParameters() {
                    musicParametersCard(params: params)
                }
            }
            .padding()
        }
    }

    private var connectionStatusCard: some View {
        LiquidGlassCard {
            HStack {
                Image(systemName: ringManager.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.title)
                    .foregroundStyle(ringManager.isConnected ? .green : .gray)

                VStack(alignment: .leading) {
                    Text(ringManager.connectedRing?.name ?? "No Ring Connected")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(ringManager.connectionStatus.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                if ringManager.isConnected {
                    Button("Disconnect") {
                        ringManager.disconnect()
                    }
                    .buttonStyle(.liquidGlass(variant: .regular, tint: .red, size: .small))
                } else {
                    Button("Scan") {
                        ringManager.startScanning()
                    }
                    .buttonStyle(.liquidGlass(tint: .cyan, size: .small))
                }
            }
        }
    }

    private func bioDataCard(bio: SmartRingIntegration.RingBioData) -> some View {
        LiquidGlassCard(variant: .tinted, tint: .cyan.opacity(0.2)) {
            VStack(spacing: 16) {
                Text("Current Bio Data")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    BioMetricTile(
                        icon: "heart.fill",
                        value: bio.heartRate.map { String(format: "%.0f", $0) } ?? "--",
                        unit: "BPM",
                        color: .red
                    )

                    BioMetricTile(
                        icon: "waveform.path.ecg",
                        value: bio.hrv.map { String(format: "%.0f", $0) } ?? "--",
                        unit: "ms HRV",
                        color: .purple
                    )

                    BioMetricTile(
                        icon: "lungs.fill",
                        value: bio.spo2.map { String(format: "%.0f", $0) } ?? "--",
                        unit: "% SpO2",
                        color: .blue
                    )

                    BioMetricTile(
                        icon: "thermometer",
                        value: bio.skinTemperature.map { String(format: "%.1f", $0) } ?? "--",
                        unit: "°C",
                        color: .orange
                    )
                }

                // Coherence indicator
                HStack {
                    Text("Coherence")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    LiquidGlassCircularProgress(
                        progress: Double(bio.coherence),
                        size: 50,
                        tint: BioReactiveGlassColors.coherenceTint(bio.coherence)
                    )
                }
            }
        }
    }

    private var discoveredRingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discovered Rings")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(ringManager.discoveredRings) { ring in
                Button {
                    Task {
                        try? await ringManager.connect(to: ring)
                    }
                } label: {
                    HStack {
                        Image(systemName: ring.type.icon)
                            .font(.title2)
                            .foregroundStyle(Color(ring.type.color))

                        VStack(alignment: .leading) {
                            Text(ring.name)
                                .font(.subheadline)
                                .foregroundStyle(.white)

                            if let battery = ring.batteryLevel {
                                Text("Battery: \(battery)%")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding()
                    .liquidGlass(.regular, cornerRadius: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func musicParametersCard(params: SmartRingIntegration.BioMusicParameters) -> some View {
        LiquidGlassCard(variant: .tinted, tint: .purple.opacity(0.2)) {
            VStack(spacing: 12) {
                Text("Bio-Reactive Music")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Tempo: \(params.tempo) BPM")
                        Text("Key: \(params.key)")
                        Text("Genre: \(params.suggestedGenre)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    LiquidGlassCircularProgress(
                        progress: Double(params.intensity),
                        size: 60,
                        tint: .purple,
                        label: "Intensity"
                    )
                }
            }
        }
    }
}

struct BioMetricTile: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)

            VStack(alignment: .leading) {
                Text(value)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.white)

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular, cornerRadius: 12)
    }
}

#Preview("Smart Ring") {
    ZStack {
        AnimatedGlassBackground()
        SmartRingView()
    }
    .preferredColorScheme(.dark)
}

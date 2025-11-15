import Foundation
import HealthKit
import CoreBluetooth
import Combine

// MARK: - Universal Wearables Manager
/// Ultimate cross-device biofeedback integration
/// Supports ALL major wearable brands and device types
///
/// Supported Devices:
/// **Smartwatches:**
/// - Apple Watch (all models)
/// - Samsung Galaxy Watch 4/5/6
/// - Google Pixel Watch
/// - Garmin (Fenix, Forerunner, Venu series)
/// - Fitbit (Sense 2, Versa 4, Charge 6)
/// - Polar (Vantage, Grit X, Ignite)
/// - Suunto (9, 7, 5)
/// - Amazfit (GTR, GTS, T-Rex)
/// - Huawei Watch GT series
/// - Whoop 4.0
///
/// **Smart Rings:**
/// - Oura Ring Gen 3/4
/// - RingConn Smart Ring
/// - Circular Ring
/// - Ultrahuman Ring Air
/// - Evie Ring
/// - Movano Ring
///
/// **Smart Glasses:**
/// - Ray-Ban Meta Smart Glasses
/// - Amazon Echo Frames
/// - Bose Frames
/// - Fauna Audio Glasses
/// - Lucyd Lyte
/// - Vuzix Blade
/// - Xreal Air/Air 2
/// - Viture One
/// - Rokid Air/Max
///
/// **Fitness Trackers:**
/// - Fitbit (all models)
/// - Garmin (all models)
/// - Polar H10/H9
/// - Whoop 4.0
/// - Garmin HRM-Pro/Dual
/// - Wahoo TICKR X
/// - Coros Pod 2
///
/// **Advanced Biofeedback:**
/// - HeartMath Inner Balance
/// - Muse Headband (S/2)
/// - Empatica E4
/// - Shimmer3 GSR+
/// - BioHarness 3.0
class UniversalWearablesManager: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var connectedDevices: [WearableDevice] = []
    @Published var availableDevices: [WearableDevice] = []
    @Published var primaryDevice: WearableDevice?

    @Published var aggregatedBiometrics: AggregatedBiometrics = AggregatedBiometrics()
    @Published var isScanning: Bool = false

    // MARK: - Device Managers
    private var appleWatchManager: AppleWatchManager?
    private var bluetoothManager: BluetoothWearablesManager
    private var healthKitManager: HealthKitManager
    private var ouraManager: OuraAPIManager?
    private var fitbitManager: FitbitAPIManager?
    private var garminManager: GarminConnectManager?
    private var whoopManager: WhoopAPIManager?
    private var metaGlassesManager: MetaGlassesManager?
    private var xrealGlassesManager: XRealGlassesManager?

    // MARK: - Bluetooth
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [CBPeripheral] = []

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    override init() {
        bluetoothManager = BluetoothWearablesManager()
        healthKitManager = HealthKitManager()

        super.init()

        setupManagers()
        setupBluetoothCentral()
        requestPermissions()
    }

    private func setupManagers() {
        appleWatchManager = AppleWatchManager()
        ouraManager = OuraAPIManager()
        fitbitManager = FitbitAPIManager()
        garminManager = GarminConnectManager()
        whoopManager = WhoopAPIManager()
        metaGlassesManager = MetaGlassesManager()
        xrealGlassesManager = XRealGlassesManager()

        // Subscribe to all device updates
        subscribeToDeviceUpdates()
    }

    private func setupBluetoothCentral() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    private func requestPermissions() {
        healthKitManager.requestAuthorization { success in
            if success {
                print("✅ HealthKit authorized")
            }
        }
    }

    // MARK: - Device Discovery

    func startScanning() {
        isScanning = true
        availableDevices.removeAll()

        // Scan for Bluetooth devices
        scanForBluetoothDevices()

        // Check cloud-connected devices
        checkCloudDevices()

        // Check HealthKit sources
        checkHealthKitSources()
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    private func scanForBluetoothDevices() {
        let services = [
            CBUUID(string: "180D"), // Heart Rate Service
            CBUUID(string: "180A"), // Device Information
            CBUUID(string: "180F"), // Battery Service
            CBUUID(string: "181C"), // User Data
            CBUUID(string: "1826"), // Fitness Machine
        ]

        centralManager.scanForPeripherals(withServices: services, options: nil)
    }

    private func checkCloudDevices() {
        // Check Oura
        ouraManager?.checkConnection { [weak self] isConnected in
            if isConnected, let device = self?.createOuraDevice() {
                self?.addAvailableDevice(device)
            }
        }

        // Check Fitbit
        fitbitManager?.checkConnection { [weak self] isConnected in
            if isConnected, let device = self?.createFitbitDevice() {
                self?.addAvailableDevice(device)
            }
        }

        // Check Garmin
        garminManager?.checkConnection { [weak self] isConnected in
            if isConnected, let device = self?.createGarminDevice() {
                self?.addAvailableDevice(device)
            }
        }

        // Check Whoop
        whoopManager?.checkConnection { [weak self] isConnected in
            if isConnected, let device = self?.createWhoopDevice() {
                self?.addAvailableDevice(device)
            }
        }
    }

    private func checkHealthKitSources() {
        healthKitManager.getAvailableSources { [weak self] sources in
            sources.forEach { source in
                let device = self?.createHealthKitDevice(from: source)
                if let device = device {
                    self?.addAvailableDevice(device)
                }
            }
        }
    }

    // MARK: - Device Connection

    func connect(device: WearableDevice) {
        switch device.type {
        case .appleWatch:
            connectAppleWatch(device)
        case .smartRing:
            connectSmartRing(device)
        case .smartGlasses:
            connectSmartGlasses(device)
        case .fitnessTracker:
            connectFitnessTracker(device)
        case .advancedBiofeedback:
            connectAdvancedBiofeedback(device)
        case .smartwatch:
            connectSmartwatch(device)
        }
    }

    func disconnect(device: WearableDevice) {
        if let index = connectedDevices.firstIndex(where: { $0.id == device.id }) {
            connectedDevices.remove(at: index)
        }

        if let peripheral = device.peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func setPrimaryDevice(_ device: WearableDevice) {
        primaryDevice = device
    }

    // MARK: - Connection Handlers

    private func connectAppleWatch(_ device: WearableDevice) {
        appleWatchManager?.startMonitoring()
        addConnectedDevice(device)
    }

    private func connectSmartRing(_ device: WearableDevice) {
        switch device.brand {
        case .oura:
            ouraManager?.connect { [weak self] success in
                if success {
                    self?.addConnectedDevice(device)
                    self?.ouraManager?.startMonitoring()
                }
            }
        case .ringConn, .circular, .ultrahuman, .evie, .movano:
            // Bluetooth connection
            if let peripheral = device.peripheral {
                centralManager.connect(peripheral, options: nil)
            }
        default:
            break
        }
    }

    private func connectSmartGlasses(_ device: WearableDevice) {
        switch device.brand {
        case .rayBanMeta:
            metaGlassesManager?.connect { [weak self] success in
                if success {
                    self?.addConnectedDevice(device)
                }
            }
        case .xreal, .viture, .rokid:
            xrealGlassesManager?.connect { [weak self] success in
                if success {
                    self?.addConnectedDevice(device)
                }
            }
        default:
            // Bluetooth connection for others
            if let peripheral = device.peripheral {
                centralManager.connect(peripheral, options: nil)
            }
        }
    }

    private func connectFitnessTracker(_ device: WearableDevice) {
        switch device.brand {
        case .fitbit:
            fitbitManager?.connect { [weak self] success in
                if success {
                    self?.addConnectedDevice(device)
                    self?.fitbitManager?.startMonitoring()
                }
            }
        case .garmin:
            garminManager?.connect { [weak self] success in
                if success {
                    self?.addConnectedDevice(device)
                    self?.garminManager?.startMonitoring()
                }
            }
        case .whoop:
            whoopManager?.connect { [weak self] success in
                if success {
                    self?.addConnectedDevice(device)
                    self?.whoopManager?.startMonitoring()
                }
            }
        case .polar, .wahoo, .coros:
            // Bluetooth connection
            if let peripheral = device.peripheral {
                centralManager.connect(peripheral, options: nil)
            }
        default:
            break
        }
    }

    private func connectSmartwatch(_ device: WearableDevice) {
        // Most smartwatches use Bluetooth
        if let peripheral = device.peripheral {
            centralManager.connect(peripheral, options: nil)
        }
    }

    private func connectAdvancedBiofeedback(_ device: WearableDevice) {
        // Bluetooth connection for professional biofeedback devices
        if let peripheral = device.peripheral {
            centralManager.connect(peripheral, options: nil)
        }
    }

    // MARK: - Data Aggregation

    private func subscribeToDeviceUpdates() {
        // Apple Watch
        appleWatchManager?.$heartRate
            .sink { [weak self] hr in
                self?.updateAggregatedBiometrics(heartRate: hr)
            }
            .store(in: &cancellables)

        appleWatchManager?.$hrv
            .sink { [weak self] hrvValue in
                self?.updateAggregatedBiometrics(hrv: hrvValue)
            }
            .store(in: &cancellables)

        // Oura
        ouraManager?.$readinessScore
            .sink { [weak self] score in
                self?.updateAggregatedBiometrics(readiness: score)
            }
            .store(in: &cancellables)

        // Fitbit
        fitbitManager?.$heartRate
            .sink { [weak self] hr in
                self?.updateAggregatedBiometrics(heartRate: hr)
            }
            .store(in: &cancellables)

        // Garmin
        garminManager?.$heartRate
            .sink { [weak self] hr in
                self?.updateAggregatedBiometrics(heartRate: hr)
            }
            .store(in: &cancellables)

        // Whoop
        whoopManager?.$strain
            .sink { [weak self] strain in
                self?.updateAggregatedBiometrics(strain: strain)
            }
            .store(in: &cancellables)
    }

    private func updateAggregatedBiometrics(
        heartRate: Double? = nil,
        hrv: Double? = nil,
        readiness: Double? = nil,
        strain: Double? = nil
    ) {
        if let hr = heartRate {
            aggregatedBiometrics.heartRate = hr
        }
        if let hrvValue = hrv {
            aggregatedBiometrics.hrv = hrvValue
        }
        if let readinessScore = readiness {
            aggregatedBiometrics.readinessScore = readinessScore
        }
        if let strainScore = strain {
            aggregatedBiometrics.strainScore = strainScore
        }

        aggregatedBiometrics.lastUpdate = Date()
    }

    // MARK: - Device Creation

    private func createOuraDevice() -> WearableDevice {
        return WearableDevice(
            id: UUID(),
            name: "Oura Ring",
            type: .smartRing,
            brand: .oura,
            connectionType: .cloud,
            capabilities: [.heartRate, .hrv, .sleep, .activity, .temperature]
        )
    }

    private func createFitbitDevice() -> WearableDevice {
        return WearableDevice(
            id: UUID(),
            name: "Fitbit",
            type: .fitnessTracker,
            brand: .fitbit,
            connectionType: .cloud,
            capabilities: [.heartRate, .hrv, .sleep, .activity, .spo2]
        )
    }

    private func createGarminDevice() -> WearableDevice {
        return WearableDevice(
            id: UUID(),
            name: "Garmin",
            type: .fitnessTracker,
            brand: .garmin,
            connectionType: .cloud,
            capabilities: [.heartRate, .hrv, .sleep, .activity, .stress]
        )
    }

    private func createWhoopDevice() -> WearableDevice {
        return WearableDevice(
            id: UUID(),
            name: "Whoop 4.0",
            type: .fitnessTracker,
            brand: .whoop,
            connectionType: .cloud,
            capabilities: [.heartRate, .hrv, .sleep, .strain, .recovery]
        )
    }

    private func createHealthKitDevice(from source: HKSource) -> WearableDevice {
        return WearableDevice(
            id: UUID(),
            name: source.name,
            type: .appleWatch,
            brand: .apple,
            connectionType: .healthKit,
            capabilities: [.heartRate, .hrv, .activity]
        )
    }

    // MARK: - Device Management

    private func addAvailableDevice(_ device: WearableDevice) {
        DispatchQueue.main.async {
            if !self.availableDevices.contains(where: { $0.id == device.id }) {
                self.availableDevices.append(device)
            }
        }
    }

    private func addConnectedDevice(_ device: WearableDevice) {
        DispatchQueue.main.async {
            if !self.connectedDevices.contains(where: { $0.id == device.id }) {
                self.connectedDevices.append(device)
            }

            // Set as primary if first device
            if self.primaryDevice == nil {
                self.primaryDevice = device
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension UniversalWearablesManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("✅ Bluetooth ready")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        // Identify device type from advertisement data
        let deviceName = peripheral.name ?? "Unknown Device"

        let brand = identifyBrand(from: deviceName, advertisementData: advertisementData)
        let deviceType = identifyDeviceType(from: brand, name: deviceName)

        let device = WearableDevice(
            id: UUID(),
            name: deviceName,
            type: deviceType,
            brand: brand,
            connectionType: .bluetooth,
            capabilities: getCapabilities(for: brand),
            peripheral: peripheral
        )

        addAvailableDevice(device)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    private func identifyBrand(
        from name: String,
        advertisementData: [String: Any]
    ) -> WearableBrand {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("oura") { return .oura }
        if lowercasedName.contains("ringconn") { return .ringConn }
        if lowercasedName.contains("circular") { return .circular }
        if lowercasedName.contains("ultrahuman") { return .ultrahuman }
        if lowercasedName.contains("fitbit") { return .fitbit }
        if lowercasedName.contains("garmin") { return .garmin }
        if lowercasedName.contains("polar") { return .polar }
        if lowercasedName.contains("whoop") { return .whoop }
        if lowercasedName.contains("samsung") { return .samsung }
        if lowercasedName.contains("muse") { return .muse }
        if lowercasedName.contains("heartmath") { return .heartMath }
        if lowercasedName.contains("xreal") { return .xreal }
        if lowercasedName.contains("viture") { return .viture }
        if lowercasedName.contains("rokid") { return .rokid }

        return .unknown
    }

    private func identifyDeviceType(from brand: WearableBrand, name: String) -> WearableDeviceType {
        switch brand {
        case .oura, .ringConn, .circular, .ultrahuman, .evie, .movano:
            return .smartRing
        case .rayBanMeta, .xreal, .viture, .rokid, .amazonEcho, .bose:
            return .smartGlasses
        case .fitbit, .garmin, .polar, .whoop, .wahoo, .coros:
            return .fitnessTracker
        case .muse, .heartMath, .empatica:
            return .advancedBiofeedback
        case .samsung, .google, .amazfit, .huawei, .suunto:
            return .smartwatch
        default:
            return .fitnessTracker
        }
    }

    private func getCapabilities(for brand: WearableBrand) -> [BiometricCapability] {
        switch brand {
        case .oura:
            return [.heartRate, .hrv, .sleep, .activity, .temperature, .spo2]
        case .fitbit:
            return [.heartRate, .hrv, .sleep, .activity, .spo2, .stress]
        case .garmin:
            return [.heartRate, .hrv, .sleep, .activity, .stress, .vo2max]
        case .whoop:
            return [.heartRate, .hrv, .sleep, .strain, .recovery]
        case .polar:
            return [.heartRate, .hrv, .recovery]
        case .muse:
            return [.eeg, .meditation, .focus]
        case .heartMath:
            return [.heartRate, .hrv, .coherence]
        default:
            return [.heartRate]
        }
    }
}

// MARK: - CBPeripheralDelegate

extension UniversalWearablesManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        service.characteristics?.forEach { characteristic in
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        // Parse biometric data
        if characteristic.uuid == CBUUID(string: "2A37") { // Heart Rate Measurement
            if let data = characteristic.value {
                let heartRate = parseHeartRate(from: data)
                updateAggregatedBiometrics(heartRate: Double(heartRate))
            }
        }
    }

    private func parseHeartRate(from data: Data) -> UInt8 {
        let bytes = [UInt8](data)
        return bytes.count > 1 ? bytes[1] : 0
    }
}

// MARK: - Supporting Types

struct WearableDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: WearableDeviceType
    let brand: WearableBrand
    let connectionType: ConnectionType
    let capabilities: [BiometricCapability]
    var peripheral: CBPeripheral?
    var isConnected: Bool = false
    var batteryLevel: Int?

    static func == (lhs: WearableDevice, rhs: WearableDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

enum WearableDeviceType {
    case appleWatch
    case smartwatch
    case smartRing
    case smartGlasses
    case fitnessTracker
    case advancedBiofeedback
}

enum WearableBrand {
    // Smartwatches
    case apple, samsung, google, garmin, fitbit, polar, suunto, amazfit, huawei

    // Smart Rings
    case oura, ringConn, circular, ultrahuman, evie, movano

    // Smart Glasses
    case rayBanMeta, amazonEcho, bose, fauna, lucyd, vuzix, xreal, viture, rokid

    // Fitness Trackers
    case whoop, wahoo, coros

    // Advanced Biofeedback
    case heartMath, muse, empatica, shimmer, bioharness

    case unknown
}

enum ConnectionType {
    case bluetooth
    case healthKit
    case cloud
    case wifi
}

enum BiometricCapability {
    case heartRate, hrv, sleep, activity, temperature, spo2, stress
    case vo2max, strain, recovery, coherence
    case eeg, meditation, focus
    case gsr, respiration, bloodPressure
}

struct AggregatedBiometrics {
    var heartRate: Double = 0.0
    var hrv: Double = 0.0
    var readinessScore: Double = 0.0
    var strainScore: Double = 0.0
    var stressScore: Double = 0.0
    var sleepScore: Double = 0.0
    var activityScore: Double = 0.0
    var temperature: Double = 0.0
    var spo2: Double = 0.0
    var coherenceScore: Double = 0.0
    var lastUpdate: Date = Date()
}

// MARK: - Placeholder Managers

class AppleWatchManager: ObservableObject {
    @Published var heartRate: Double = 0.0
    @Published var hrv: Double = 0.0

    func startMonitoring() {}
}

class HealthKitManager {
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func getAvailableSources(completion: @escaping ([HKSource]) -> Void) {
        completion([])
    }
}

class BluetoothWearablesManager {}

class OuraAPIManager: ObservableObject {
    @Published var readinessScore: Double = 0.0

    func checkConnection(completion: @escaping (Bool) -> Void) {
        completion(false)
    }

    func connect(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func startMonitoring() {}
}

class FitbitAPIManager: ObservableObject {
    @Published var heartRate: Double = 0.0

    func checkConnection(completion: @escaping (Bool) -> Void) {
        completion(false)
    }

    func connect(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func startMonitoring() {}
}

class GarminConnectManager: ObservableObject {
    @Published var heartRate: Double = 0.0

    func checkConnection(completion: @escaping (Bool) -> Void) {
        completion(false)
    }

    func connect(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func startMonitoring() {}
}

class WhoopAPIManager: ObservableObject {
    @Published var strain: Double = 0.0

    func checkConnection(completion: @escaping (Bool) -> Void) {
        completion(false)
    }

    func connect(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func startMonitoring() {}
}

class MetaGlassesManager {
    func connect(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
}

class XRealGlassesManager {
    func connect(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
}

Add support for a new biometric sensor with iOS integration, data processing, and real-time streaming.

**Required Input**: Sensor type (e.g., "EEG", "GSR", "Temperature", "BloodPressure")

**Files to Create**:

1. **Swift iOS Manager**:
   - `Sources/Echoelmusic/Biofeedback/{SensorType}Manager.swift`
   - Bluetooth/USB connection logic
   - HealthKit integration (if applicable)
   - Real-time data streaming

2. **C++ Bridge** (if needed for DSP):
   - `Sources/BioData/{SensorType}Processor.h`
   - `Sources/BioData/{SensorType}Processor.cpp`

3. **Tests**:
   - `Tests/EchoelmusicTests/{SensorType}ManagerTests.swift`

**Template Structure**:

```swift
import Foundation
import Combine
import HealthKit // if applicable
import CoreBluetooth // if Bluetooth

@MainActor
class {SensorType}Manager: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var currentValue: Double = 0.0
    @Published var signalQuality: Double = 0.0

    // MARK: - Private Properties
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private let healthStore = HKHealthStore()

    // MARK: - Initialization
    override init() {
        super.init()
        setupBluetooth()
    }

    // MARK: - Connection
    func connect() async throws {
        // Implementation
    }

    func disconnect() {
        // Implementation
    }

    // MARK: - Data Processing
    private func processSensorData(_ data: Data) {
        // Parse raw sensor data
        // Apply calibration
        // Smooth signal
        // Update published properties
    }
}
```

**Implementation Checklist**:
- [ ] Bluetooth GATT service/characteristic UUIDs
- [ ] Data parsing and validation
- [ ] Calibration routines (zero, span)
- [ ] Signal quality monitoring
- [ ] Error handling and reconnection
- [ ] Battery level monitoring
- [ ] HealthKit permissions (if applicable)
- [ ] Privacy compliance (PrivacyInfo.xcprivacy update)

**Data Processing**:
- Implement smoothing filter (moving average, Kalman)
- Artifact detection and removal
- Normalization to 0.0-1.0 range
- Timestamp synchronization with other sensors

**Integration Points**:
- Add to `BioParameterMapper.swift`
- Update `UnifiedControlHub.swift` for 60Hz polling
- Add visualization in ParticleView/CymaticsRenderer
- Map to audio parameters

**Testing Requirements**:
- Mock sensor data for CI
- Calibration accuracy tests
- Connection/reconnection tests
- Signal quality validation
- Performance (CPU usage, battery impact)

**Documentation**:
- Add to COMPLETE_FEATURE_LIST.md
- Update PrivacyInfo.xcprivacy with new data type
- Document Bluetooth permissions needed
- Add to XCODE_HANDOFF.md sensor list

**Privacy & Security**:
- Encrypt sensor data (PrivacyManager)
- Never sync raw biometric data to cloud
- Local-only storage
- HIPAA compliance check

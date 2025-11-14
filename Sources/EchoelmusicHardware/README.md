# EchoelmusicHardware

**Purpose:** Wearables and external device integration.

## Responsibilities

- Device discovery & management (BLE/USB)
- Device adapters (Apple Watch, Smart Ring, EEG, Motion)
- Stable, opt-in device connection lifecycle

## Getting Started

```swift
import EchoelmusicHardware

// Scan for devices
let manager = WearableManager()
try await manager.scanForDevices()

// Connect to device
let device = WearableDevice(
    name: "Apple Watch",
    type: .appleWatch
)
try await manager.connect(to: device)
```

## Testing

Device manager tests simulate connections (stubbed)

## Notes

- Real device integrations require explicit user permission
- All connections are opt-in
- Battery monitoring included

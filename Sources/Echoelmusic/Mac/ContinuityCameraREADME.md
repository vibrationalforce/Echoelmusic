# Continuity Camera Support 📷

**Use iPhone as wireless webcam for Mac face tracking**

---

## What is Continuity Camera?

**Continuity Camera** is a macOS 13+ and iOS 16+ feature that lets you use your iPhone as a wireless webcam for your Mac.

**Benefits for Echoelmusic:**
- Better camera quality than Mac webcam
- Wireless connection (no cables)
- Automatic device discovery
- Seamless integration
- Studio-quality face tracking

---

## Features

### Automatic Device Discovery

- Detects all available cameras
- Identifies iPhone/iPad via Continuity Camera
- Built-in Mac camera fallback
- External camera support

### Smart Device Selection

**Priority:**
1. iPhone (best quality)
2. iPad
3. Built-in Mac camera
4. External camera

### Connection Monitoring

- Automatic device connect/disconnect detection
- Auto-switch to iPhone when connected
- Fallback to Mac camera when iPhone disconnects
- Connection status display

### Camera Selection UI

- List all available cameras
- Device type icons (iPhone, iPad, Built-in, External)
- Current selection indicator
- Manual device switching
- Refresh button

---

## Requirements

### System Requirements

**Mac:**
- macOS 13 Ventura or later
- Mac with Apple Silicon or Intel (2018+)
- Bluetooth and Wi-Fi enabled

**iPhone:**
- iOS 16 or later
- iPhone XR or later
- Same Apple ID as Mac
- Bluetooth and Wi-Fi enabled

**Network:**
- Both devices on same Wi-Fi network (or nearby)
- Bluetooth enabled on both devices

### Continuity Requirements

- Same Apple ID on both devices
- Handoff enabled (System Settings > General > AirDrop & Handoff)
- Bluetooth and Wi-Fi enabled

---

## Setup

### macOS Setup

1. **System Settings → General → AirDrop & Handoff**
2. Enable **Handoff**
3. Sign in with same Apple ID as iPhone

### iPhone Setup

1. **Settings → General → AirPlay & Handoff**
2. Enable **Handoff**
3. Sign in with same Apple ID as Mac

### Echoelmusic Setup

**No additional setup required!**
- Continuity Camera automatically detected
- iPhone appears as camera option
- App auto-selects iPhone camera

---

## Usage

### Automatic Mode (Recommended)

1. Open Echoelmusic on Mac
2. iPhone automatically appears as camera option
3. App selects iPhone camera automatically
4. Start face tracking session

**That's it!** The app handles everything.

### Manual Camera Selection

1. Open Echoelmusic on Mac
2. Go to **Settings → Camera**
3. See list of available cameras
4. Select **iPhone** camera
5. Start session

### SwiftUI Integration

```swift
import SwiftUI

struct CameraSettingsView: View {
    @StateObject private var cameraManager = ContinuityCameraManager()

    var body: some View {
        VStack {
            // Camera device picker
            CameraDevicePickerView()

            // Connection status
            Text("Status: \(cameraManager.connectionStatus.displayName)")
                .foregroundColor(
                    cameraManager.isIPhoneConnected ? .green : .secondary
                )
        }
    }
}
```

### Programmatic Access

```swift
let cameraManager = ContinuityCameraManager()

// Get selected device
if let device = cameraManager.selectedDevice {
    print("Using: \(device.name)")
}

// Get AVCaptureDevice for camera input
if let avDevice = cameraManager.getSelectedAVDevice() {
    // Use with AVCaptureSession
    let input = try AVCaptureDeviceInput(device: avDevice)
    captureSession.addInput(input)
}

// Monitor camera changes
NotificationCenter.default.addObserver(
    forName: .cameraDeviceChanged,
    object: nil,
    queue: .main
) { notification in
    if let device = notification.object as? CameraDevice {
        print("Camera changed to: \(device.name)")
        // Reconfigure camera input
    }
}
```

---

## Integration with FaceTrackingManager

### Automatic Integration

```swift
@MainActor
class FaceTrackingManager: ObservableObject {
    private let cameraManager = ContinuityCameraManager()

    func startTracking() {
        // Use selected camera device
        guard let avDevice = cameraManager.getSelectedAVDevice() else {
            print("No camera available")
            return
        }

        // Configure AVCaptureSession with selected camera
        let input = try! AVCaptureDeviceInput(device: avDevice)
        captureSession.addInput(input)

        // If iPhone camera, higher quality possible
        if cameraManager.selectedDevice?.type == .iPhone {
            configureForHighQuality()
        }

        captureSession.startRunning()
    }

    private func configureForHighQuality() {
        // iPhone cameras support higher resolutions
        captureSession.sessionPreset = .high
        // Use 60 FPS if available
        // ...
    }
}
```

### Handle Camera Changes

```swift
// Monitor camera device changes
NotificationCenter.default.addObserver(
    forName: .cameraDeviceChanged,
    object: nil,
    queue: .main
) { [weak self] notification in
    // Stop current session
    self?.captureSession.stopRunning()

    // Reconfigure with new camera
    if let device = notification.object as? CameraDevice {
        self?.reconfigureCamera(device)
    }

    // Restart session
    self?.captureSession.startRunning()
}
```

---

## Device Types

### iPhone (Highest Priority)

**Advantages:**
- Best camera quality (12MP+)
- Wide-angle + ultra-wide options
- Better low-light performance
- Center Stage support (iPhone 12+)
- Cinematic mode

**Detection:**
- Name contains "iPhone"
- Appears as external camera
- Auto-selected when available

### iPad

**Advantages:**
- Good camera quality
- Center Stage support
- Large screen for monitoring

**Detection:**
- Name contains "iPad"
- Appears as external camera
- Auto-selected if no iPhone

### Built-in Mac Camera

**Advantages:**
- Always available
- No setup required
- Integrated into Mac

**Limitations:**
- Lower quality (720p-1080p)
- Limited low-light performance
- Fixed position

### External Camera

**Advantages:**
- Professional quality possible
- USB/Thunderbolt connection
- Flexible positioning

**Detection:**
- Any other external camera
- Auto-detected

---

## Connection Flow

### Initial Connection

1. Mac app launches
2. Camera discovery runs
3. iPhone detected via Continuity Camera
4. Auto-selected as primary camera
5. User sees "Using iPhone camera"

### Disconnection Handling

1. iPhone disconnects (moved too far, Bluetooth off, etc.)
2. App detects disconnection
3. Auto-fallback to Mac built-in camera
4. User sees "Using Built-in camera"
5. Face tracking continues (no interruption)

### Reconnection Handling

1. iPhone comes back into range
2. App detects reconnection
3. Auto-switch back to iPhone camera
4. User sees "Using iPhone camera"
5. Better quality restored

---

## Troubleshooting

### iPhone Not Appearing

**Check:**
- [ ] macOS 13+ and iOS 16+
- [ ] Same Apple ID on both devices
- [ ] Handoff enabled on both devices
- [ ] Bluetooth enabled on both devices
- [ ] Wi-Fi enabled on both devices
- [ ] Devices on same network (or nearby)

**Fix:**
1. Restart Bluetooth on both devices
2. Restart Wi-Fi on both devices
3. Sign out and back into iCloud
4. Restart both devices

### Poor Connection Quality

**Fix:**
- Move iPhone closer to Mac
- Ensure strong Wi-Fi signal
- Check for Bluetooth interference
- Close other apps using camera

### Camera Switching Not Working

**Fix:**
- Refresh device list (click refresh button)
- Restart app
- Restart camera discovery

### Face Tracking Not Working

**Fix:**
- Check camera permissions (System Settings → Privacy → Camera)
- Ensure good lighting
- Position iPhone at eye level
- Clean iPhone camera lens

---

## Best Practices

### Camera Positioning

**iPhone:**
- Mount at eye level
- 1-2 feet from face
- Good lighting in front of you
- Avoid backlighting

**Angle:**
- Slightly above eye level (flattering angle)
- Centered on face
- Landscape orientation recommended

### Performance Optimization

**For best performance:**
- Use iPhone 12 or later (Center Stage)
- Enable "High Quality" in settings
- Close unnecessary apps on iPhone
- Ensure good Wi-Fi/Bluetooth signal

### Battery Management

**iPhone will use battery:**
- Keep iPhone charged during long sessions
- Use iPhone with charger connected
- Enable Low Power Mode if needed

---

## Platform Support

| Feature | Availability |
|---------|-------------|
| Continuity Camera | macOS 13+ |
| iPhone Camera | iOS 16+ |
| Automatic Discovery | ✅ All |
| Device Selection UI | ✅ All |
| Hot-swapping | ✅ All |

**Coverage:**
- Mac: 100% (macOS 13+)
- iPhone: ~80% of devices (iPhone XR+, iOS 16+)

---

## Performance

### Camera Quality Comparison

| Device | Resolution | FPS | Quality |
|--------|-----------|-----|---------|
| iPhone 14 Pro | 12MP | 60 | ⭐⭐⭐⭐⭐ |
| iPhone 13 | 12MP | 60 | ⭐⭐⭐⭐ |
| iPhone XR | 12MP | 30 | ⭐⭐⭐ |
| MacBook Pro (2021+) | 1080p | 60 | ⭐⭐⭐ |
| MacBook Air (M1) | 720p | 30 | ⭐⭐ |

### Latency

- Bluetooth: ~50-100ms
- Wi-Fi: ~30-50ms
- USB (external): ~10-20ms

**Continuity Camera latency is acceptable for face tracking** (human perception threshold ~100ms)

---

## Privacy & Security

### Camera Access

**Permissions required:**
- Mac: Camera permission
- iPhone: No additional permissions (uses Continuity)

### Data Handling

**All processing is local:**
- Video never leaves devices
- No cloud processing
- No data stored
- Real-time processing only

### Handoff Security

**Encrypted connection:**
- Bluetooth LE encryption
- Wi-Fi Direct encryption
- TLS for data transfer
- Same Apple ID required

---

## Future Enhancements

- [ ] Manual camera position adjustment
- [ ] Save preferred camera selection
- [ ] Multiple iPhone camera switching (front/back)
- [ ] Ultra-wide camera support
- [ ] Cinematic mode integration
- [ ] Manual focus and exposure controls

---

## Resources

- [Continuity Camera Documentation](https://support.apple.com/en-us/HT213244)
- [AVFoundation Guide](https://developer.apple.com/documentation/avfoundation)
- [Continuity Requirements](https://support.apple.com/en-us/HT204681)

---

**Built with ❤️ for the seamless "Erlebnisbad" experience**

Studio-quality face tracking on Mac with your iPhone! 📷💚

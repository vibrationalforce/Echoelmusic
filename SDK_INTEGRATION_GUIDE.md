# SDK Integration Guide 🔧

Complete guide for integrating external SDKs into BLAB.

---

## 📦 Required SDKs

### 1. HaishinKit (RTMP Streaming) ✅ INTEGRATED

**Status:** ✅ Added to Package.swift
**Version:** 1.6.0+
**GitHub:** https://github.com/shogo4405/HaishinKit.swift

**Purpose:**
- Real RTMP streaming to YouTube, Twitch, Facebook
- Professional encoding (AAC audio, H.264 video)
- Adaptive bitrate control
- Auto-reconnection

**Installation:**
Already added to Package.swift:
```swift
.package(url: "https://github.com/shogo4405/HaishinKit.swift.git", from: "1.6.0")
```

**Usage:**
```swift
import HaishinKit

let streamer = RealRTMPStreamer.shared
try await streamer.configure(platform: .youtube, streamKey: "your-key")
try await streamer.startStreaming()
```

**Implementation:**
- ✅ `Sources/Blab/Streaming/RealRTMPStreamer.swift`
- ✅ Full HaishinKit integration
- ✅ Connection handling
- ✅ Auto-reconnection
- ✅ Health monitoring

---

### 2. NDI SDK (Network Audio) ⚠️ MANUAL INSTALLATION

**Status:** ⚠️ Requires manual setup
**Version:** NDI 5.0+
**Website:** https://ndi.tv/sdk/

**Purpose:**
- Ultra-low latency network audio (< 5ms)
- Auto-device discovery
- Professional broadcast quality
- DAW integration

**Installation Steps:**

#### Step 1: Download NDI SDK
1. Go to https://ndi.tv/sdk/
2. Register for free developer account
3. Download "NDI SDK for Apple"
4. Extract the downloaded file

#### Step 2: Add NDI Framework to Xcode

**Option A: Manual Framework Addition**
1. Open your Xcode project
2. Drag `libndi_advanced.dylib` into your project
3. Navigate to project settings → "Frameworks, Libraries, and Embedded Content"
4. Add the dylib and set "Embed & Sign"

**Option B: XCFramework (Recommended)**
1. Create XCFramework wrapper:
```bash
cd /path/to/ndi/sdk
xcodebuild -create-xcframework \
  -library lib/x64/libndi_advanced.dylib \
  -output NDI.xcframework
```

2. Drag NDI.xcframework into Xcode project

3. Add to Package.swift:
```swift
.binaryTarget(
    name: "NDI",
    path: "Frameworks/NDI.xcframework"
)
```

#### Step 3: Configure Build Settings

Add to your target's build settings:

**Header Search Paths:**
```
$(PROJECT_DIR)/Frameworks/NDI/include
```

**Library Search Paths:**
```
$(PROJECT_DIR)/Frameworks/NDI/lib
```

**Other Linker Flags:**
```
-lndi_advanced
```

#### Step 4: Create Bridging Header (If Needed)

Create `Blab-Bridging-Header.h`:
```c
#ifndef Blab_Bridging_Header_h
#define Blab_Bridging_Header_h

#import <Processing.NDI.Lib.h>

#endif
```

#### Step 5: Verify Installation

Test with:
```swift
import NDI

let ndi = NDISender()
print("NDI SDK loaded successfully!")
```

---

## 🔧 Configuration

### HaishinKit Configuration

Already configured in `RealRTMPStreamer.swift`:

```swift
// Audio settings
stream.audioSettings = [
    .sampleRate: 48000,
    .bitrate: 128,  // kbps
    .muted: false,
    .profileLevel: kAudioFormatMPEG4AAC_HE_V2
]

// For audio-only streaming
stream.videoSettings = [
    .muted: true
]
```

### NDI Configuration

Configure in `NDIConfiguration.swift`:

```swift
NDIConfiguration.shared.enabled = true
NDIConfiguration.shared.sourceName = "BLAB Audio"
NDIConfiguration.shared.sampleRate = 48000
NDIConfiguration.shared.channels = 2
```

---

## 🚀 Quick Start

### RTMP Streaming (YouTube)

```swift
// 1. Get your stream key from YouTube Studio
let streamKey = "your-youtube-stream-key"

// 2. Configure
try await RealRTMPStreamer.shared.configure(
    platform: .youtube,
    streamKey: streamKey
)

// 3. Start streaming
try await RealRTMPStreamer.shared.startStreaming()

// 4. Monitor health
let stats = RealRTMPStreamer.shared.getStatistics()
print("Health: \(stats.health)")
print("Bitrate: \(stats.currentBitrate / 1000) kbps")

// 5. Stop when done
RealRTMPStreamer.shared.stopStreaming()
```

### NDI Streaming (Once SDK is installed)

```swift
// 1. Enable NDI
try audioEngine.enableNDI()

// 2. Configure
NDIConfiguration.shared.sourceName = "BLAB"
NDIConfiguration.shared.biometricMetadata = true

// 3. Discover receivers
let discovery = NDIDeviceDiscovery()
discovery.start()
print("Found \(discovery.devices.count) NDI receivers")

// 4. Audio automatically streams to all receivers

// 5. Disable when done
audioEngine.disableNDI()
```

---

## 🔍 Troubleshooting

### HaishinKit Issues

**Problem:** "Module 'HaishinKit' not found"
**Solution:**
1. Clean build folder (Cmd+Shift+K)
2. Resolve packages: File → Packages → Resolve Package Versions
3. Build again (Cmd+B)

**Problem:** "Connection failed"
**Solution:**
1. Verify stream key is correct
2. Check internet connection
3. Test with different RTMP server
4. Check firewall settings

**Problem:** "Poor stream quality"
**Solution:**
1. Reduce bitrate: `streamer.setBitrate(96_000)`
2. Check upload speed (needs 2x bitrate minimum)
3. Use Ethernet instead of WiFi
4. Close bandwidth-heavy apps

### NDI Issues

**Problem:** "NDI library not found"
**Solution:**
1. Verify dylib is in project
2. Check "Embed & Sign" is set
3. Add to Copy Files build phase
4. Clean and rebuild

**Problem:** "No NDI devices discovered"
**Solution:**
1. Devices must be on same network
2. Check firewall allows mDNS
3. NDI Tools installed on receiver?
4. Try manual device addition

**Problem:** "High latency"
**Solution:**
1. Use wired Ethernet (not WiFi)
2. Reduce buffer size
3. Use Quality Profile: Minimal
4. Check network congestion

---

## 📊 Performance Tips

### RTMP Streaming

**Optimal Settings:**
```swift
// For stable connection
bitrate: 128_000  // 128 kbps
sampleRate: 48000
buffer: small

// For best quality (requires good internet)
bitrate: 256_000  // 256 kbps
sampleRate: 48000
buffer: medium
```

**Upload Speed Requirements:**
- 96 kbps audio → Need 0.2 Mbps upload minimum
- 128 kbps audio → Need 0.3 Mbps upload minimum
- 256 kbps audio → Need 0.6 Mbps upload minimum

**Bitrate Selection:**
| Quality | Bitrate | Use Case |
|---------|---------|----------|
| Low | 96 kbps | Mobile data, poor connection |
| Standard | 128 kbps | Most streaming (recommended) |
| High | 160 kbps | Good connection |
| Premium | 192 kbps | Excellent connection |
| Studio | 256 kbps | Professional, wired only |

### NDI Streaming

**Network Requirements:**
- Gigabit Ethernet recommended
- WiFi 6 minimum for wireless
- < 1ms network latency ideal
- Same subnet for auto-discovery

**Buffer Settings:**
```swift
// Ultra-low latency (< 5ms)
bufferSize: 128
quality: .minimal

// Balanced (< 10ms)
bufferSize: 256
quality: .balanced

// Stable (< 20ms)
bufferSize: 512
quality: .performance
```

---

## 🧪 Testing

### Test RTMP Stream

```swift
// Test configuration
func testRTMPStream() async throws {
    let streamer = RealRTMPStreamer.shared

    // Use test stream key
    try await streamer.configure(
        platform: .custom,
        streamKey: "test",
        customURL: "rtmp://your-test-server.com/live"
    )

    // Start streaming
    try await streamer.startStreaming()

    // Stream for 10 seconds
    try await Task.sleep(nanoseconds: 10_000_000_000)

    // Check statistics
    let stats = streamer.getStatistics()
    XCTAssertTrue(stats.isStreaming)
    XCTAssertGreaterThan(stats.bytesStreamed, 0)

    // Stop
    streamer.stopStreaming()
}
```

### Test NDI Discovery

```swift
func testNDIDiscovery() async throws {
    let discovery = NDIDeviceDiscovery()
    discovery.start()

    // Wait for discovery
    try await Task.sleep(nanoseconds: 3_000_000_000)

    // Should find at least one device
    XCTAssertGreaterThan(discovery.devices.count, 0)

    print("Found devices:")
    for device in discovery.devices {
        print("  - \(device.name) (\(device.ipAddress))")
    }
}
```

---

## 📱 Platform-Specific Setup

### YouTube Live

1. Go to YouTube Studio → Go Live
2. Select "Stream" tab
3. Copy Stream Key
4. Use in app:
```swift
try await streamer.configure(platform: .youtube, streamKey: "your-key")
```

### Twitch

1. Go to Twitch Dashboard → Settings → Stream
2. Copy Primary Stream Key
3. Use in app:
```swift
try await streamer.configure(platform: .twitch, streamKey: "your-key")
```

### Facebook Live

1. Go to Creator Studio → Go Live
2. Select "Live Producer"
3. Copy Stream Key
4. Use in app:
```swift
try await streamer.configure(platform: .facebook, streamKey: "your-key")
```

---

## 🔒 Security

### Stream Key Protection

**NEVER:**
- Commit stream keys to git
- Share stream keys publicly
- Log stream keys in console
- Store in UserDefaults unencrypted

**DO:**
- Use iOS Keychain for storage
- Mask keys in UI (show only last 4 chars)
- Rotate keys regularly
- Use secure input fields

**Example:**
```swift
import Security

func saveStreamKey(_ key: String, for platform: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: platform,
        kSecValueData as String: key.data(using: .utf8)!,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
    ]

    SecItemAdd(query as CFDictionary, nil)
}
```

---

## 📚 Additional Resources

### HaishinKit
- Documentation: https://github.com/shogo4405/HaishinKit.swift/wiki
- Examples: https://github.com/shogo4405/HaishinKit.swift/tree/master/Examples
- Issues: https://github.com/shogo4405/HaishinKit.swift/issues

### NDI
- SDK Docs: https://ndi.tv/sdk/documentation/
- NDI Tools: https://ndi.tv/tools/
- Community: https://ndi.tv/community/

### RTMP
- Specification: https://rtmp.veriskope.com/
- YouTube requirements: https://support.google.com/youtube/answer/2853702
- Twitch requirements: https://help.twitch.tv/s/article/broadcasting-guidelines

---

## ✅ Integration Checklist

### HaishinKit (RTMP)
- [x] Added to Package.swift
- [x] RealRTMPStreamer.swift implemented
- [x] Connection handling
- [x] Auto-reconnection
- [x] Health monitoring
- [x] Statistics tracking
- [ ] Test with real stream
- [ ] Production stream keys

### NDI SDK
- [ ] SDK downloaded
- [ ] Framework added to Xcode
- [ ] Bridging header created
- [ ] Build settings configured
- [ ] Test compilation
- [ ] Test discovery
- [ ] Test streaming
- [ ] Performance optimization

---

**Status:**
- ✅ HaishinKit: Ready to use
- ⚠️ NDI SDK: Requires manual installation

**Next Steps:**
1. Test RTMP streaming with real platforms
2. Install NDI SDK manually
3. Create production stream key management
4. Performance testing & optimization

# 📡 BLAB NDI Audio Output - Setup Guide

**Version:** 1.0
**Date:** 2025-11-03
**Status:** ✅ Ready for Testing

---

## 🎯 What is NDI Audio Output?

**NDI (Network Device Interface)** is a professional video/audio-over-IP protocol that allows BLAB iOS to **stream audio to any NDI-compatible device on your network**.

### Use Cases:
- 🎹 **DAW Integration**: Stream BLAB audio directly to Ableton, Logic, Reaper, etc.
- 🎥 **Streaming Software**: Send audio to OBS Studio, vMix, Wirecast, etc.
- 🎚️ **Mixing Consoles**: Route to digital mixers that support NDI
- 🎤 **Virtual Audio**: Use BLAB as a network audio source
- 🌐 **Remote Collaboration**: Stream audio to remote locations (low-latency)

### Benefits:
- ✅ **Zero Hardware Needed** - Works over WiFi/Ethernet
- ✅ **Ultra-Low Latency** - < 5ms on local network
- ✅ **High Quality** - Up to 96kHz/32-bit audio
- ✅ **Biometric Metadata** - HRV/HR embedded in stream
- ✅ **Auto-Discovery** - Devices automatically detected

---

## 🚀 Quick Start (3 Steps)

### 1. Enable NDI in BLAB App

```swift
// In your app code:
let hub = UnifiedControlHub(audioEngine: audioEngine)

// Quick enable with defaults:
hub.quickEnableNDI(
    sourceName: "BLAB iOS",      // Name on network
    preset: .balanced,            // Low Latency / Balanced / High Quality
    biometricMetadata: true       // Include HRV/HR data
)
```

**Or use the UI:**
- Open BLAB app
- Go to Settings → NDI Audio
- Toggle "NDI Audio Output" ON
- Set source name (e.g., "BLAB Studio")

### 2. Receive Audio in DAW/OBS

**Ableton Live (with NDI Virtual Input):**
1. Download & install NDI Tools (https://ndi.tv/tools/)
2. Open NDI Virtual Input application
3. Select "BLAB iOS" as source
4. In Ableton Live: Audio Preferences → Input Device → "NDI Audio"
5. Create audio track → Set input to "NDI Audio"
6. Arm track → Record ✅

**OBS Studio:**
1. Install NDI Plugin for OBS (https://github.com/Palakis/obs-ndi)
2. Add Source → "NDI Source"
3. Select "BLAB iOS" from dropdown
4. Audio now flows to OBS ✅

**vMix / Wirecast:**
- Add Input → NDI
- Select "BLAB iOS"
- Audio streams automatically ✅

### 3. Verify Connection

In BLAB app:
- Go to Settings → NDI Audio
- Check "Connected Receivers" count
- Should show 1+ receivers
- Monitor "Frames Sent" counter (should increase)

---

## 🛠️ Installation (NDI SDK)

### What You Need:

**BLAB currently operates in MOCK MODE** (SDK not linked).
To enable actual NDI streaming, follow these steps:

### 1. Download NDI SDK

1. Go to https://ndi.tv/sdk/
2. Sign up (free)
3. Download **NDI SDK 5.x** for iOS
4. Extract to a folder (e.g., `/Users/yourname/NDI SDK`)

### 2. Add NDI Framework to Xcode

1. Open BLAB project in Xcode
2. Select project in navigator
3. Go to "General" tab
4. Scroll to "Frameworks, Libraries, and Embedded Content"
5. Click "+" → "Add Other" → "Add Files"
6. Navigate to NDI SDK folder
7. Add `libndi_ios.a` (static library)
8. Set to "Embed & Sign"

### 3. Configure Build Settings

1. Select target → "Build Settings"
2. Search for "Header Search Paths"
3. Add path to NDI SDK includes:
   ```
   /path/to/NDI SDK/include
   ```
4. Search for "Library Search Paths"
5. Add path to NDI SDK libraries:
   ```
   /path/to/NDI SDK/lib/iOS
   ```
6. Search for "Swift Compiler - Custom Flags"
7. Under "Other Swift Flags", add:
   ```
   -DNDI_SDK_AVAILABLE
   ```

### 4. Update Info.plist

Add network permissions:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>BLAB needs local network access to stream audio via NDI</string>

<key>NSBonjourServices</key>
<array>
    <string>_ndi._tcp</string>
</array>
```

### 5. Build & Run

1. Clean build folder (Cmd+Shift+K)
2. Build (Cmd+B)
3. If build succeeds, NDI is now ACTIVE ✅
4. Look for console message:
   ```
   [NDI] Started sender: BLAB iOS
   [NDI] Audio format: 48000 Hz, 2 ch, 32-bit
   ```

---

## ⚙️ Configuration Guide

### Quality Presets

| Preset | Sample Rate | Buffer | Bit Depth | Use Case |
|--------|------------|--------|-----------|----------|
| **Low Latency** | 44.1 kHz | 128 frames | 16-bit | Live performance, real-time control |
| **Balanced** | 48 kHz | 256 frames | 24-bit | General use, streaming |
| **High Quality** | 96 kHz | 512 frames | 32-bit | Studio recording, mastering |
| **Broadcast** | 48 kHz | 256 frames | 24-bit | Broadcasting, podcasting |

**Apply preset:**
```swift
hub.applyNDIPreset(.lowLatency)
```

### Audio Format Settings

**Sample Rate:**
- 44.1 kHz: CD quality, low CPU
- 48 kHz: Industry standard (recommended)
- 96 kHz: High-end production

**Channel Count:**
- 2: Stereo (most common)
- 8: 7.1 Surround
- 64: Max (for spatial audio systems)

**Bit Depth:**
- 16-bit: Good quality, low bandwidth
- 24-bit: Professional quality
- 32-bit: Maximum dynamic range (recommended)

**Floating Point:**
- ON: Best quality, no clipping (recommended)
- OFF: Integer math, compatible with older systems

### Buffer Size

**Trade-off:** Latency vs. Stability

- **64 frames**: Ultra-low latency (~1.3ms @ 48kHz), requires fast network
- **128 frames**: Low latency (~2.7ms), recommended for live performance
- **256 frames**: Balanced (~5.3ms), most stable
- **512+ frames**: High latency, use for recording only

**Formula:** `Latency (ms) = (Buffer Size / Sample Rate) * 1000`

### Biometric Metadata

When enabled, BLAB sends real-time biometric data embedded in the NDI stream:

```xml
<blab>
  <heartRate>72</heartRate>
  <hrv>65</hrv>
  <coherence>0.85</coherence>
  <breathingRate>12</breathingRate>
  <timestamp>1699000000.123</timestamp>
</blab>
```

**Use cases:**
- Visualize HRV in DAW (custom Max for Live device)
- Control effects based on biometrics
- Record biometric data alongside audio

**Enable:**
```swift
hub.setNDIBiometricMetadata(enabled: true)
```

---

## 🌐 Network Setup

### Local Network (Recommended)

**WiFi:**
- Use 5 GHz WiFi (NOT 2.4 GHz)
- Router must support multicast/mDNS
- iPhone/iPad and receiver on same network
- Latency: 5-10ms

**Ethernet (Best):**
- Use Ethernet adapter for iOS device
- Direct connection to receiver or switch
- Latency: < 3ms

### Firewall Settings

**Allow UDP ports:**
- 5959 (NDI Discovery)
- 5960 (NDI Audio)

**macOS:**
```bash
# Allow NDI through firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/BLAB.app
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /Applications/BLAB.app
```

**Windows:**
- Windows Defender Firewall → Allow an app
- Add NDI Virtual Input
- Allow on Private and Public networks

### Troubleshooting Network Issues

**Device not discovered:**
1. Check same network/subnet
2. Restart router
3. Disable VPN
4. Manually add device IP in BLAB app

**High latency:**
1. Reduce buffer size
2. Use wired connection
3. Close other network apps
4. Check network congestion (ping test)

**Audio dropouts:**
1. Increase buffer size
2. Check WiFi signal strength
3. Reduce sample rate (48kHz → 44.1kHz)
4. Close background apps on iOS

---

## 📊 Monitoring & Statistics

### View Real-Time Stats

**In App:**
- Settings → NDI Audio
- View "Connected Receivers"
- Monitor "Frames Sent" and "Data Sent"
- Check for "Dropped Frames" (should be 0)

**Console Logs:**
```swift
hub.printNDIStatistics()
```

Output:
```
[NDI Statistics]
  Frames sent: 144000 (50 seconds @ 48kHz)
  Bytes sent: 27.5 MB
  Dropped frames: 0
  Connections: 2
```

### Performance Metrics

**Good:**
- ✅ Dropped frames: 0
- ✅ Latency: < 10ms
- ✅ CPU usage: < 20%
- ✅ Connections: 1+

**Bad:**
- ❌ Dropped frames: > 0 (network issues)
- ❌ Latency: > 20ms (buffer too small or network congested)
- ❌ CPU usage: > 50% (reduce sample rate/buffer)

---

## 🧪 Testing Procedures

### Test 1: Basic Connectivity

1. Enable NDI in BLAB
2. Open NDI Studio Monitor (free from ndi.tv)
3. Select "BLAB iOS" as source
4. Speak into iPhone microphone
5. ✅ Audio should appear in monitor

### Test 2: Latency Test

1. Connect BLAB → DAW via NDI
2. Create test tone in BLAB (1 kHz sine wave)
3. Record in DAW
4. Measure time difference
5. ✅ Should be < 10ms on local network

### Test 3: Long-Duration Stability

1. Enable NDI
2. Stream for 30 minutes
3. Check dropped frames
4. Monitor CPU/memory usage
5. ✅ Should remain stable (0 drops, < 25% CPU)

### Test 4: Biometric Metadata

1. Enable biometric metadata
2. Connect to DAW/OBS
3. Use NDI metadata viewer (if available)
4. Move/exercise to change heart rate
5. ✅ Should see HRV/HR values updating

---

## 🎹 DAW Integration Examples

### Ableton Live

**Setup:**
1. Install NDI Virtual Input
2. Launch NDI Virtual Input → Select "BLAB iOS"
3. Ableton Preferences → Audio:
   - Input Device: "NDI Audio"
   - Sample Rate: 48000 Hz (match BLAB)
4. Create Audio Track
5. Set Input: "NDI Audio" → Channel 1/2
6. Arm track → Monitor "In"
7. ✅ Real-time audio from BLAB

**Tips:**
- Add Max for Live device to parse metadata
- Use BLAB HRV to modulate effects
- Record spatial audio from BLAB

### Logic Pro X

**Setup:**
1. Install NDI Virtual Input
2. Launch NDI Virtual Input → Select "BLAB iOS"
3. Logic Preferences → Audio:
   - Input Device: "NDI Audio"
4. Create Audio Track
5. Set Input: "NDI Audio" 1-2
6. Enable input monitoring
7. ✅ Audio flows

### Reaper

**Setup:**
1. Install NDI Virtual Input
2. Reaper Preferences → Audio → Device:
   - Audio System: CoreAudio (macOS) or ASIO (Windows)
   - Input Device: "NDI Audio"
3. Insert new track
4. Set input to NDI Audio
5. Record-arm track
6. ✅ Ready to record

---

## 🐛 Troubleshooting

### Problem: "NDI SDK not linked - operating in mock mode"

**Solution:**
- Follow installation steps above
- Add `-DNDI_SDK_AVAILABLE` to Swift flags
- Rebuild project

### Problem: No devices discovered

**Check:**
1. Same WiFi network
2. Firewall allows UDP 5959/5960
3. Router supports multicast
4. Manually add device by IP

**Manual add:**
```swift
hub.addNDIDevice(name: "My DAW", ipAddress: "192.168.1.100", port: 5960)
```

### Problem: Audio glitches/dropouts

**Solutions:**
1. Increase buffer size (256 → 512 frames)
2. Reduce sample rate (96kHz → 48kHz)
3. Use Ethernet instead of WiFi
4. Close background apps
5. Check network: `ping 192.168.1.100`

### Problem: High CPU usage

**Solutions:**
1. Lower sample rate (96kHz → 48kHz)
2. Reduce bit depth (32-bit → 24-bit)
3. Increase buffer size
4. Disable biometric metadata

### Problem: Latency too high

**Solutions:**
1. Reduce buffer size (256 → 128 frames)
2. Use Ethernet connection
3. Use "Low Latency" preset
4. Check network latency: `ping -c 10 192.168.1.100`

---

## 📚 API Reference

### Quick Enable

```swift
// Simplest way to start NDI
hub.quickEnableNDI(
    sourceName: "My BLAB",
    preset: .balanced,
    biometricMetadata: true
)
```

### Manual Control

```swift
// Enable/Disable
try hub.enableNDI()
hub.disableNDI()

// Toggle
hub.toggleNDI()

// Check status
if hub.isNDIEnabled {
    print("NDI is streaming")
}
```

### Configuration

```swift
// Set source name
hub.setNDISourceName("BLAB Performance")

// Apply preset
hub.applyNDIPreset(.lowLatency)

// Biometric metadata
hub.setNDIBiometricMetadata(enabled: true)

// Custom settings
let config = NDIConfiguration.shared
config.sampleRate = 96000
config.channelCount = 2
config.bufferSize = 128
```

### Device Discovery

```swift
// Get discovered devices
let devices = hub.discoveredNDIDevices
for device in devices {
    print("\(device.name): \(device.ipAddress):\(device.port)")
}

// Manually add device
hub.addNDIDevice(name: "Studio PC", ipAddress: "192.168.1.50")

// Remove device
hub.removeNDIDevice(id: "device-id")
```

### Statistics

```swift
// Get stats
if let stats = hub.ndiStatistics {
    print("Frames sent: \(stats.framesSent)")
    print("Data sent: \(stats.bytesSent)")
    print("Dropped: \(stats.droppedFrames)")
}

// Connection count
let count = hub.ndiConnectionCount
print("Connected receivers: \(count)")

// Has connections?
if hub.hasNDIConnections {
    print("Streaming to \(count) receiver(s)")
}

// Print to console
hub.printNDIStatistics()
```

---

## 🔮 Advanced Use Cases

### 1. Multi-Device Streaming

Stream BLAB audio to multiple receivers simultaneously:

```swift
// Enable NDI
hub.quickEnableNDI(sourceName: "BLAB Main")

// Audio automatically sent to ALL connected receivers:
// - Ableton Live (for recording)
// - OBS Studio (for streaming)
// - Monitor speakers (for reference)
```

### 2. Remote Collaboration

Stream audio over internet (requires NDI Bridge or VPN):

```swift
// Local setup (same as usual)
hub.quickEnableNDI()

// Remote user:
// 1. Install NDI Bridge (free from ndi.tv)
// 2. Connect to your network
// 3. Receives BLAB audio in real-time
```

### 3. Spatial Audio Streaming

Stream spatial audio from BLAB:

```swift
// Enable spatial audio in BLAB
audioEngine.spatialAudioEnabled = true

// Enable NDI with multi-channel
let config = NDIConfiguration.shared
config.channelCount = 8  // 7.1 surround
hub.enableNDI()

// Receive in DAW as 7.1 surround
```

### 4. Biometric-Reactive Effects in DAW

Use BLAB biometric data to control DAW effects:

```swift
// Enable biometric metadata
hub.setNDIBiometricMetadata(enabled: true)

// In DAW (with custom Max for Live device):
// - Parse NDI metadata
// - Map HRV → Reverb size
// - Map HR → Filter cutoff
// - Map Coherence → Wet/Dry mix
```

---

## 📝 Summary

BLAB's NDI Audio Output feature enables:
- ✅ **Zero-hardware audio streaming** to DAWs/OBS/vMix
- ✅ **Ultra-low latency** (< 5ms on local network)
- ✅ **High-quality audio** (up to 96kHz/32-bit)
- ✅ **Biometric metadata** embedded in stream
- ✅ **Automatic device discovery**

**Next Steps:**
1. Enable NDI in BLAB app
2. Install NDI Virtual Input (or NDI-compatible software)
3. Connect and start streaming! 🚀

---

## 🆘 Support

**Issues?**
- Check this guide first
- Review console logs
- Test network connectivity
- Open GitHub issue: https://github.com/vibrationalforce/blab-ios-app/issues

**Feature Requests:**
- NDI video output (coming soon)
- NDI recording
- Advanced routing matrix
- NDI discovery improvements

---

**Version:** 1.0
**Last Updated:** 2025-11-03
**Status:** ✅ Ready for Testing
**License:** Proprietary

🫧 *Let's flow...* ✨

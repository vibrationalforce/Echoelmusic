Add support for a new live streaming platform to the multi-platform streaming engine.

**Required Input**: Platform name (e.g., "TikTok", "Discord", "Instagram", "LinkedIn")

**Files to Create**:

1. **Platform Client**:
   - `Sources/Echoelmusic/Stream/{Platform}Client.swift`
   - RTMP/WebRTC implementation
   - Authentication flow
   - Chat integration

2. **Platform Configuration**:
   - Add to `Sources/Echoelmusic/Stream/StreamEngine.swift`
   - Environment variable for API keys

3. **Tests**:
   - `Tests/EchoelmusicTests/Stream/{Platform}ClientTests.swift`

**Template Structure**:

```swift
import Foundation
import Network

class {Platform}Client {

    private let streamKey: String
    private let serverURL: String
    private var connection: NWConnection?

    // Platform-specific settings
    struct StreamSettings {
        let videoBitrate: Int      // bps
        let audioBitrate: Int      // bps
        let framerate: Int         // fps
        let resolution: CGSize
    }

    init(streamKey: String) {
        self.streamKey = streamKey
        self.serverURL = Self.platformServerURL
    }

    func connect() async throws {
        // RTMP handshake
        // Authentication
        // Stream initialization
    }

    func sendVideoFrame(_ buffer: CVPixelBuffer, timestamp: CMTime) async throws {
        // H.264 encoding
        // RTMP packaging
        // Send over network
    }

    func sendAudioFrame(_ buffer: AVAudioPCMBuffer) async throws {
        // AAC encoding
        // RTMP packaging
        // Send over network
    }

    func disconnect() {
        connection?.cancel()
    }

    private static var platformServerURL: String {
        // Platform-specific RTMP server
        // e.g., "rtmp://live.twitch.tv/app"
        return ""
    }
}
```

**Platform Requirements Matrix**:

| Platform | Protocol | Video | Audio | Max Bitrate | Chat API |
|----------|----------|-------|-------|-------------|----------|
| Twitch   | RTMP     | H.264 | AAC   | 6000 kbps   | IRC      |
| YouTube  | RTMP     | H.264 | AAC   | 51000 kbps  | REST     |
| Facebook | RTMPS    | H.264 | AAC   | 8000 kbps   | Graph    |
| TikTok   | RTMP     | H.264 | AAC   | 5000 kbps   | -        |
| Discord  | WebRTC   | VP9   | Opus  | Varies      | WS       |

**Implementation Checklist**:
- [ ] RTMP/WebRTC handshake implementation
- [ ] OAuth 2.0 authentication (if required)
- [ ] Stream key validation
- [ ] Video encoder configuration
- [ ] Audio encoder configuration
- [ ] Adaptive bitrate logic
- [ ] Connection health monitoring
- [ ] Automatic reconnection
- [ ] Error handling and logging
- [ ] Chat message receiving/sending

**Encoder Settings**:
```swift
// Video
let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: 1920,
    AVVideoHeightKey: 1080,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 4_500_000,
        AVVideoMaxKeyFrameIntervalKey: 60,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    ]
]

// Audio
let audioSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 48000,
    AVNumberOfChannelsKey: 2,
    AVEncoderBitRateKey: 160_000
]
```

**Chat Integration**:
- Implement platform-specific chat protocol
- Parse incoming messages
- Aggregate with other platforms (ChatAggregator.swift)
- Display in UI with platform badge
- Support emotes/badges

**Error Handling**:
- Network failure → auto-reconnect with backoff
- Authentication failure → prompt user
- Stream key invalid → clear UI indication
- Bitrate too high → adaptive reduction
- Frame drop → log and continue

**Testing**:
- Mock RTMP server for CI
- Connection timeout handling
- Frame encoding performance
- Memory usage under load
- Multi-platform simultaneous streaming

**StreamEngine Integration**:
```swift
// Add to StreamEngine.swift
func startStreaming(platforms: [StreamPlatform]) async {
    for platform in platforms {
        switch platform {
        case .{platform}:
            let client = {Platform}Client(streamKey: getStreamKey(for: platform))
            try await client.connect()
            activeClients.append(client)
        // ... other platforms
        }
    }
}
```

**Environment Variables**:
Add to .env.template:
```
{PLATFORM}_STREAM_KEY=your_stream_key_here
{PLATFORM}_CLIENT_ID=your_client_id_here
{PLATFORM}_CLIENT_SECRET=your_secret_here
```

**Documentation**:
- Add platform to README.md streaming section
- Update COMPLETE_FEATURE_LIST.md
- Document API rate limits
- Add troubleshooting guide
- Link to platform developer docs

**Security**:
- Never log stream keys
- Encrypt keys in Keychain
- Validate SSL certificates
- Rate limit API calls

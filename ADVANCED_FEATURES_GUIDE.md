# 💎 Echoelmusic Advanced Features Guide

**NFT Minting • Music Distribution • Multi-Streaming • Social Features**

This guide covers the advanced platform features that make Echoelmusic a complete music ecosystem.

---

## 📋 Table of Contents

1. [NFT Minting System](#1-nft-minting-system)
2. [Music Distribution](#2-music-distribution)
3. [Multi-Platform Streaming](#3-multi-platform-streaming)
4. [Social Features](#4-social-features)
5. [Integration Examples](#5-integration-examples)
6. [Pricing & Subscription Tiers](#6-pricing--subscription-tiers)

---

## 1. NFT Minting System

### Overview

Create and sell music NFTs with bio-reactive metadata stored on blockchain (Polygon/Ethereum).

### Features

- **IPFS Storage:** Audio files stored permanently on IPFS
- **Bio-Reactive NFTs:** Include HRV and gesture data as unique signature
- **ERC-721 Standard:** Compatible with OpenSea, Rarible, etc.
- **Royalty System:** Automatic creator royalties (default 10%)
- **Multi-Chain:** Supports Polygon (low fees) and Ethereum

### Workflow

```
1. Create NFT → Upload audio + cover art to IPFS
2. Add Bio-Data → Optional HRV snapshot + gesture data
3. Mint → Deploy to blockchain (Polygon recommended)
4. List → Set price and list on marketplace
5. Sell → Auto-royalties on future sales
```

### API Endpoints

#### Create NFT (Draft)

```bash
POST /api/nft/create
Content-Type: multipart/form-data

{
  "title": "Bio-Reactive Track #1",
  "description": "Created during deep meditation session",
  "audioFile": <binary>,
  "coverImage": <binary>,
  "price": 0.5,                    # MATIC or ETH
  "royaltyPercent": 10,
  "blockchain": "POLYGON",
  "hrvSnapshot": "{...}",           # HRV data JSON
  "gestureData": "{...}"            # Gesture data JSON
}

Response:
{
  "success": true,
  "data": {
    "id": "nft_abc123",
    "audioUrl": "https://ipfs.io/ipfs/Qm...",
    "coverImageUrl": "https://ipfs.io/ipfs/Qm...",
    "metadata": "https://ipfs.io/ipfs/Qm...",
    "status": "DRAFT"
  }
}
```

#### Mint NFT to Blockchain

```bash
POST /api/nft/mint

{
  "nftId": "nft_abc123",
  "walletAddress": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
}

Response:
{
  "success": true,
  "data": {
    "tokenId": "12345",
    "contractAddress": "0x...",
    "txHash": "0x...",
    "explorerUrl": "https://polygonscan.com/tx/0x...",
    "status": "MINTED"
  }
}
```

#### List NFT for Sale

```bash
POST /api/nft/list

{
  "nftId": "nft_abc123",
  "price": 0.5
}
```

#### Get Marketplace NFTs

```bash
GET /api/nft/marketplace?blockchain=POLYGON&page=1&limit=20

Response:
{
  "success": true,
  "data": [
    {
      "id": "nft_abc123",
      "title": "Bio-Reactive Track #1",
      "price": 0.5,
      "currency": "MATIC",
      "audioUrl": "https://ipfs.io/ipfs/Qm...",
      "user": {
        "name": "Artist Name",
        "username": "artist123"
      }
    }
  ],
  "pagination": { "page": 1, "total": 50, "totalPages": 3 }
}
```

### Desktop DAW Integration

```cpp
// In your Desktop DAW (C++/JUCE)
void uploadNFT() {
    // 1. Export audio file
    auto audioBuffer = exportCurrentProject();

    // 2. Get HRV snapshot (if biofeedback enabled)
    auto hrvData = biofeedbackEngine.getCurrentHRVSnapshot();

    // 3. Upload to backend
    HttpRequest request("POST", "https://api.echoelmusic.com/nft/create");
    request.setHeader("Authorization", "Bearer " + authToken);
    request.addFormData("title", projectTitle);
    request.addFormData("audioFile", audioBuffer);
    request.addFormData("hrvSnapshot", hrvData.toJSON());

    auto response = request.send();

    // 4. Get IPFS URLs
    auto nftId = response.data["id"];
    showNotification("NFT created! Mint it on the web dashboard.");
}
```

### Environment Variables

```env
# NFT Minting
NFT_CONTRACT_ADDRESS=0x... # Your deployed ERC-721 contract
MINTER_PRIVATE_KEY=0x... # Wallet private key for minting
POLYGON_RPC_URL=https://polygon-rpc.com
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
INFURA_KEY=your_infura_key

# IPFS (Infura)
IPFS_HOST=ipfs.infura.io
IPFS_PROJECT_ID=your_project_id
IPFS_PROJECT_SECRET=your_project_secret
```

---

## 2. Music Distribution

### Overview

Distribute your music to Spotify, Apple Music, YouTube Music, and more. Automated submission with analytics tracking.

### Supported Platforms

- ✅ Spotify
- ✅ Apple Music
- ✅ YouTube Music
- ✅ Amazon Music
- ✅ Tidal
- ✅ Deezer
- ✅ SoundCloud
- ✅ Bandcamp

### Features

- **Automated Submission:** One-click distribution to multiple platforms
- **UPC/ISRC Generation:** Automatic generation of industry-standard codes
- **Analytics Tracking:** Streams and revenue per platform
- **Royalty Management:** Track earnings across all platforms
- **Takedown Support:** Remove releases from all platforms

### Workflow

```
1. Create Release → Upload tracks + metadata
2. Review → Check all info (artist, title, genre, etc.)
3. Submit → Select platforms (Spotify, Apple Music, etc.)
4. Processing → Platforms review (typically 1-7 days)
5. Live → Track analytics (streams, revenue)
```

### API Endpoints

#### Create Release

```bash
POST /api/distribution/create
Content-Type: multipart/form-data

{
  "title": "My Album",
  "artistName": "Artist Name",
  "genre": "Electronic",
  "releaseDate": "2025-12-01",
  "copyrightYear": 2025,
  "copyrightHolder": "Artist Name",
  "label": "Independent",
  "albumArt": <binary>,
  "tracks": <binary array>,
  "tracksMetadata": "[
    {
      \"title\": \"Track 1\",
      \"artists\": \"Artist Name\",
      \"trackNumber\": 1
    },
    {
      \"title\": \"Track 2\",
      \"artists\": \"Artist Name, Feat. Other\",
      \"trackNumber\": 2
    }
  ]"
}

Response:
{
  "success": true,
  "data": {
    "id": "release_xyz789",
    "upc": "812345678901",
    "tracks": [
      {
        "title": "Track 1",
        "isrc": "US-XXX-25-00001"
      }
    ],
    "status": "DRAFT"
  }
}
```

#### Submit to Platforms

```bash
POST /api/distribution/submit

{
  "releaseId": "release_xyz789",
  "platforms": [
    { "platform": "SPOTIFY", "enabled": true },
    { "platform": "APPLE_MUSIC", "enabled": true },
    { "platform": "YOUTUBE_MUSIC", "enabled": true },
    { "platform": "AMAZON_MUSIC", "enabled": true },
    { "platform": "TIDAL", "enabled": false }
  ]
}

Response:
{
  "success": true,
  "message": "Release submitted to platforms",
  "data": {
    "status": "SUBMITTED",
    "distributions": [
      { "platform": "SPOTIFY", "status": "SUBMITTED" },
      { "platform": "APPLE_MUSIC", "status": "SUBMITTED" }
    ]
  }
}
```

#### Get Release Analytics

```bash
GET /api/distribution/releases/:id/analytics

Response:
{
  "success": true,
  "data": {
    "totalStreams": 15420,
    "totalRevenue": 45.32,
    "platforms": [
      {
        "platform": "SPOTIFY",
        "streams": 8500,
        "revenue": 28.90,
        "status": "LIVE"
      },
      {
        "platform": "APPLE_MUSIC",
        "streams": 6920,
        "revenue": 16.42,
        "status": "LIVE"
      }
    ]
  }
}
```

### Pricing

Distribution requires **Pro subscription** (€29/month).

**Revenue Split:**
- 100% of streaming royalties go to you
- No hidden fees
- No per-release charges

**Processing Time:**
- Spotify: 3-7 days
- Apple Music: 5-14 days
- Others: varies

---

## 3. Multi-Platform Streaming

### Overview

Stream live performances to Twitch, YouTube, Facebook, Instagram, and TikTok simultaneously.

### Features

- **Multi-Platform Restreaming:** One source → multiple destinations
- **RTMP Support:** Use OBS, Streamlabs, or any RTMP client
- **Bio-Reactive Streaming:** Log HRV data during live performances
- **Analytics:** Track viewers, peak concurrent, total watch time
- **Stream Management:** Start/stop, enable/disable destinations

### Supported Platforms

- Twitch
- YouTube Live
- Facebook Live
- Instagram Live
- TikTok Live
- Custom RTMP (any server)

### Workflow

```
1. Create Stream → Set title, destinations, schedule
2. Get RTMP Config → Server URL + Stream Key
3. Configure OBS → Use provided RTMP settings
4. Start Streaming → Automatically rebroadcast to all platforms
5. Analytics → Track viewers across all platforms
```

### API Endpoints

#### Create Stream

```bash
POST /api/streaming/create

{
  "title": "Live Bio-Reactive Performance",
  "description": "Performing with real-time HRV modulation",
  "destinations": [
    {
      "platform": "TWITCH",
      "platformKey": "live_123456789_abcdefghijk",
      "enabled": true
    },
    {
      "platform": "YOUTUBE",
      "platformKey": "xxxx-xxxx-xxxx-xxxx",
      "enabled": true
    },
    {
      "platform": "FACEBOOK",
      "platformKey": "FB-1234567890",
      "enabled": true
    }
  ],
  "hrvEnabled": true
}

Response:
{
  "success": true,
  "data": {
    "id": "stream_qwe456",
    "streamKey": "a1b2c3d4e5f6g7h8",
    "rtmpUrl": "rtmp://stream.echoelmusic.com:1935/live",
    "status": "SCHEDULED"
  }
}
```

#### Get RTMP Configuration

```bash
GET /api/streaming/:id/rtmp-config

Response:
{
  "success": true,
  "data": {
    "server": "rtmp://stream.echoelmusic.com:1935/live",
    "streamKey": "a1b2c3d4e5f6g7h8",
    "instructions": "
1. Open OBS Studio
2. Settings → Stream
3. Service: Custom
4. Server: rtmp://stream.echoelmusic.com:1935/live
5. Stream Key: a1b2c3d4e5f6g7h8
6. Click 'Start Streaming'
    "
  }
}
```

#### Start/Stop Stream

```bash
POST /api/streaming/:id/start
POST /api/streaming/:id/stop
```

#### Log Biometric Data During Stream

```bash
POST /api/streaming/biometrics

{
  "streamId": "stream_qwe456",
  "hrvData": {
    "heartRate": 72,
    "hrv": 45,
    "coherence": 75
  },
  "gestureData": {
    "leftHandPinch": 0.65,
    "rightHandSpread": 0.82
  }
}
```

### Desktop DAW Integration

```cpp
// Start streaming from Desktop DAW
void startLiveStream(String streamId) {
    // Get RTMP config from backend
    auto config = apiClient.get("/streaming/" + streamId + "/rtmp-config");

    // Start RTMP stream (using FFmpeg or similar)
    rtmpStreamer.setServer(config.server);
    rtmpStreamer.setStreamKey(config.streamKey);
    rtmpStreamer.start();

    // Send biometric data every second
    biofeedbackTimer.startTimer(1000);
}

void biofeedbackTimerCallback() {
    auto hrvData = biofeedbackEngine.getCurrentHRV();

    HttpRequest request("POST", "https://api.echoelmusic.com/streaming/biometrics");
    request.setJSON({
        "streamId": currentStreamId,
        "hrvData": hrvData.toJSON()
    });
    request.sendAsync();
}
```

### Pricing

Streaming requires **Pro subscription** (€29/month).

**Limits:**
- Free: Not available
- Pro: Up to 10 hours/month
- Studio: Unlimited streaming

---

## 4. Social Features

### Overview

Connect with other musicians, share projects, follow artists, and build your community.

### Features

- **User Profiles:** Username, bio, avatar
- **Posts:** Share music, projects, thoughts
- **Follow System:** Follow artists, build audience
- **Likes & Comments:** Engage with content
- **Feed:** See posts from followed artists
- **Notifications:** Real-time updates on follows, likes, comments

### API Endpoints

#### Create Post

```bash
POST /api/social/posts

{
  "content": "Just finished my new bio-reactive track! 🎵",
  "mediaUrl": "https://s3.amazonaws.com/track.mp3", # optional
  "projectId": "project_abc123" # optional - link to project
}
```

#### Get Feed

```bash
GET /api/social/feed?page=1&limit=20

Response:
{
  "success": true,
  "data": [
    {
      "id": "post_123",
      "content": "New track out now!",
      "createdAt": "2025-01-15T10:30:00Z",
      "user": {
        "name": "Artist Name",
        "username": "artist123",
        "avatar": "https://..."
      },
      "likesCount": 42,
      "commentsCount": 8
    }
  ]
}
```

#### Like/Unlike Post

```bash
POST /api/social/like
{ "postId": "post_123" }

POST /api/social/unlike
{ "postId": "post_123" }
```

#### Add Comment

```bash
POST /api/social/comments

{
  "postId": "post_123",
  "content": "Amazing track! Love the bio-reactive elements 🔥"
}
```

#### Follow/Unfollow User

```bash
POST /api/social/follow
{ "userId": "user_xyz" }

POST /api/social/unfollow
{ "userId": "user_xyz" }
```

#### Get Notifications

```bash
GET /api/social/notifications?unreadOnly=true

Response:
{
  "success": true,
  "data": [
    {
      "id": "notif_1",
      "type": "FOLLOW",
      "title": "New follower",
      "message": "Someone started following you",
      "read": false,
      "createdAt": "2025-01-15T09:00:00Z"
    },
    {
      "id": "notif_2",
      "type": "LIKE",
      "title": "New like",
      "message": "Someone liked your post",
      "linkUrl": "/posts/post_123",
      "read": false
    }
  ]
}
```

#### Update Profile

```bash
PUT /api/social/profile

{
  "username": "my_username",
  "bio": "Bio-reactive music producer | Experimental electronic",
  "avatar": "https://s3.amazonaws.com/avatar.jpg"
}
```

---

## 5. Integration Examples

### Desktop DAW → NFT Minting

```cpp
void mintCurrentProject() {
    // 1. Export audio
    auto audioData = exportAudio();

    // 2. Capture biometric snapshot
    auto biometrics = biofeedbackEngine.getSnapshot();

    // 3. Upload to backend
    apiClient.uploadNFT({
        title: projectName,
        audioFile: audioData,
        hrvSnapshot: biometrics.hrv,
        gestureData: biometrics.gestures
    });
}
```

### Desktop DAW → Music Distribution

```cpp
void distributeAlbum() {
    // 1. Export all tracks
    auto tracks = exportAllTracks();

    // 2. Create release
    auto release = apiClient.createRelease({
        title: "My Album",
        tracks: tracks,
        platforms: ["SPOTIFY", "APPLE_MUSIC"]
    });

    // 3. Show confirmation
    showDialog("Album submitted to Spotify & Apple Music!");
}
```

### iOS App → Live Streaming with Biometrics

```swift
func startBioReactiveStream() {
    // 1. Create stream
    let stream = api.createStream(
        title: "Live Bio-Reactive Performance",
        destinations: [.twitch, .youtube],
        hrvEnabled: true
    )

    // 2. Start HealthKit monitoring
    healthKitManager.startMonitoring()

    // 3. Send HRV data every second
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        let hrv = healthKitManager.getCurrentHRV()
        api.logBiometrics(streamId: stream.id, hrvData: hrv)
    }
}
```

---

## 6. Pricing & Subscription Tiers

### Free Tier
- ❌ NFT Minting: Not available
- ❌ Music Distribution: Not available
- ❌ Live Streaming: Not available
- ✅ Social Features: Full access

### Pro Tier (€29/month)
- ✅ NFT Minting: Unlimited
- ✅ Music Distribution: Unlimited releases
- ✅ Live Streaming: 10 hours/month
- ✅ Social Features: Full access
- ✅ Priority Support

### Studio Tier (€99/month)
- ✅ NFT Minting: Unlimited + featured marketplace
- ✅ Music Distribution: Unlimited + priority processing
- ✅ Live Streaming: Unlimited hours
- ✅ Social Features: Full access + verified badge
- ✅ Team Collaboration (coming soon)
- ✅ API Access (coming soon)
- ✅ Dedicated Support

---

## 🚀 Getting Started

### 1. Upgrade to Pro

```bash
# Via web dashboard
https://app.echoelmusic.com/dashboard → Upgrade to Pro

# Or via API
POST /api/payments/checkout
{
  "planKey": "PRO_MONTHLY",
  "successUrl": "https://app.echoelmusic.com/success",
  "cancelUrl": "https://app.echoelmusic.com/cancel"
}
```

### 2. Set Up Integrations

**For NFT Minting:**
1. Connect MetaMask wallet
2. Get MATIC for gas fees (Polygon network)
3. Start minting!

**For Music Distribution:**
1. Complete tax information
2. Add banking details for royalties
3. Upload your first release

**For Live Streaming:**
1. Get platform stream keys (Twitch, YouTube, etc.)
2. Add destinations to your stream
3. Configure OBS with our RTMP server

### 3. Build Your Audience

1. Complete your profile
2. Follow other artists
3. Share your first post
4. Engage with the community

---

## 📚 Additional Resources

- **API Documentation:** Full REST API reference
- **Smart Contract Code:** View our ERC-721 contract on GitHub
- **Example Projects:** Sample Desktop DAW integrations
- **Video Tutorials:** Step-by-step guides

---

## 💡 Support

- **Discord Community:** Join our Discord server
- **Email Support:** support@echoelmusic.com
- **Pro Support:** Priority response (< 4 hours)
- **Studio Support:** Dedicated support engineer

---

**Built for creators, by creators** ❤️

**Start monetizing your bio-reactive music today!** 🚀

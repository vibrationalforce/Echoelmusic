# Social Media API Setup Guide

Complete guide for setting up API access for all supported platforms.

---

## Overview

BLAB supports direct video upload to:
- **Instagram** (Reels & Stories)
- **TikTok**
- **YouTube** (Shorts & Videos)
- **Snapchat** (Spotlight)
- **Twitter/X**

Each platform requires API credentials and SDK integration. This guide walks you through the setup process for each platform.

---

## 📱 Instagram API Setup

### Prerequisites
- Facebook Developer Account
- Instagram Business or Creator Account
- App approved for Instagram Basic Display API

### Steps

1. **Create Facebook App**
   - Go to [developers.facebook.com](https://developers.facebook.com)
   - Click "Create App" → Choose "Consumer" type
   - Add Instagram Basic Display API product

2. **Configure Instagram Basic Display**
   - In App Dashboard → Products → Instagram Basic Display
   - Click "Create New App"
   - Configure OAuth Redirect URIs:
     ```
     blab://auth/instagram
     ```

3. **Get Credentials**
   ```
   Instagram App ID: YOUR_APP_ID
   Instagram App Secret: YOUR_APP_SECRET
   Redirect URI: blab://auth/instagram
   ```

4. **Add to Xcode**
   - In `Info.plist`, add:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>blab</string>
           </array>
       </dict>
   </array>

   <key>InstagramAppID</key>
   <string>YOUR_APP_ID</string>
   ```

5. **Required Scopes**
   - `instagram_content_publish` - Post photos/videos
   - `instagram_basic` - Read profile info

6. **Integration**
   - Uncomment Instagram code in `InstagramAdapter.swift`
   - Add Facebook SDK to Package.swift:
   ```swift
   .package(url: "https://github.com/facebook/facebook-ios-sdk.git", from: "16.0.0")
   ```

### API Documentation
- [Instagram Graph API](https://developers.facebook.com/docs/instagram-api)
- [Content Publishing](https://developers.facebook.com/docs/instagram-api/guides/content-publishing)

---

## 🎵 TikTok API Setup

### Prerequisites
- TikTok Developer Account
- App approved for Content Posting API (requires review)

### Steps

1. **Create TikTok App**
   - Go to [developers.tiktok.com](https://developers.tiktok.com)
   - Register as developer
   - Create new app
   - Request "Content Posting API" access (requires justification)

2. **Configure OAuth**
   - Add Redirect URI:
     ```
     blab://auth/tiktok
     ```

3. **Get Credentials**
   ```
   Client Key: YOUR_CLIENT_KEY
   Client Secret: YOUR_CLIENT_SECRET
   Redirect URI: blab://auth/tiktok
   ```

4. **Add to Xcode**
   - In `Info.plist`:
   ```xml
   <key>TikTokClientKey</key>
   <string>YOUR_CLIENT_KEY</string>
   ```

5. **Required Scopes**
   - `video.upload` - Upload video content
   - `video.publish` - Publish videos
   - `user.info.basic` - Read user profile

6. **Integration**
   - Uncomment TikTok code in `TikTokAdapter.swift`
   - Use native OAuth or TikTok SDK

### API Documentation
- [TikTok for Developers](https://developers.tiktok.com/doc/overview)
- [Content Posting API](https://developers.tiktok.com/doc/content-posting-api-get-started)

### Important Notes
- ⚠️ Content Posting API requires business justification
- ⚠️ Review process can take 1-2 weeks
- ⚠️ Rate limits: 100 posts per day per user

---

## ▶️ YouTube API Setup

### Prerequisites
- Google Cloud Account
- YouTube channel
- YouTube Data API v3 enabled

### Steps

1. **Create Google Cloud Project**
   - Go to [console.cloud.google.com](https://console.cloud.google.com)
   - Create new project: "BLAB"
   - Enable YouTube Data API v3

2. **Configure OAuth Consent Screen**
   - OAuth consent screen → External
   - Add scopes:
     ```
     https://www.googleapis.com/auth/youtube.upload
     https://www.googleapis.com/auth/youtube.readonly
     ```

3. **Create OAuth Client**
   - Credentials → Create Credentials → OAuth client ID
   - Type: iOS
   - Bundle ID: `com.yourcompany.blab`
   - Add redirect URI:
     ```
     com.googleusercontent.apps.YOUR_CLIENT_ID:/oauth2callback
     ```

4. **Get Credentials**
   ```
   Client ID: YOUR_CLIENT_ID.apps.googleusercontent.com
   iOS URL Scheme: com.googleusercontent.apps.YOUR_CLIENT_ID
   ```

5. **Add to Xcode**
   - In `Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
           </array>
       </dict>
   </array>

   <key>YouTubeClientID</key>
   <string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>
   ```

6. **Integration**
   - Add GoogleSignIn SDK:
   ```swift
   .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0")
   ```
   - Uncomment YouTube code in `YouTubeAdapter.swift`

### For YouTube Shorts
- Add `#Shorts` to video description
- Use vertical 9:16 aspect ratio
- Maximum 60 seconds duration

### API Documentation
- [YouTube Data API](https://developers.google.com/youtube/v3)
- [Upload Videos](https://developers.google.com/youtube/v3/guides/uploading_a_video)

### Rate Limits
- Default quota: 10,000 units/day
- Video upload costs: ~1,600 units
- Request quota increase if needed

---

## 👻 Snapchat API Setup

### Prerequisites
- Snapchat Developer Account
- Snap Kit enabled app

### Steps

1. **Create Snap App**
   - Go to [kit.snapchat.com](https://kit.snapchat.com)
   - Create new app
   - Enable Creative Kit

2. **Configure App**
   - Add OAuth Redirect URI:
     ```
     blab://auth/snapchat
     ```

3. **Get Credentials**
   ```
   OAuth Client ID: YOUR_CLIENT_ID
   Redirect URI: blab://auth/snapchat
   ```

4. **Add Snap Kit SDK**
   - Download Snap Kit SDK
   - Add to project via CocoaPods or SPM:
   ```ruby
   pod 'SnapSDK', :subspecs => ['SCSDKCreativeKit', 'SCSDKLoginKit']
   ```

5. **Add to Xcode**
   - In `Info.plist`:
   ```xml
   <key>LSApplicationQueriesSchemes</key>
   <array>
       <string>snapchat</string>
   </array>

   <key>SCSDKClientId</key>
   <string>YOUR_CLIENT_ID</string>

   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>YOUR_CLIENT_ID</string>
           </array>
       </dict>
   </array>
   ```

6. **Integration**
   - Import Snap Kit in `SnapchatAdapter.swift`
   ```swift
   import SCSDKLoginKit
   import SCSDKCreativeKit
   ```

### Snap Kit Features
- **Creative Kit**: Share to Snapchat (Stories, Spotlight)
- **Login Kit**: Authenticate users
- **Bitmoji Kit**: Access Bitmoji avatars (optional)

### API Documentation
- [Snap Kit](https://kit.snapchat.com/docs)
- [Creative Kit](https://docs.snap.com/snap-kit/creative-kit/overview)

### Important Notes
- Snapchat uses share sheet (not direct API upload)
- Videos must be under 60 seconds
- User controls final posting

---

## 🐦 Twitter/X API Setup

### Prerequisites
- Twitter Developer Account (elevated access)
- Twitter API v2 access

### Steps

1. **Apply for Developer Account**
   - Go to [developer.twitter.com](https://developer.twitter.com)
   - Apply for elevated access (required for media upload)
   - Create new app

2. **Get API Keys**
   - App Settings → Keys and tokens
   ```
   API Key (Consumer Key): YOUR_API_KEY
   API Secret (Consumer Secret): YOUR_API_SECRET
   Access Token: YOUR_ACCESS_TOKEN
   Access Token Secret: YOUR_ACCESS_SECRET
   ```

3. **Configure OAuth**
   - App Settings → User authentication settings
   - Enable OAuth 1.0a
   - Callback URL: `blab://auth/twitter`
   - Website URL: `https://yourwebsite.com`

4. **Add to Xcode**
   - In `Info.plist`:
   ```xml
   <key>TwitterAPIKey</key>
   <string>YOUR_API_KEY</string>

   <key>TwitterAPISecret</key>
   <string>YOUR_API_SECRET</string>
   ```

5. **Integration**
   - Implement OAuth 1.0a signing
   - Add chunked upload support
   - Uncomment Twitter code in `TwitterAdapter.swift`

### Video Upload Process
1. **INIT** - Initialize upload, get media_id
2. **APPEND** - Upload video in chunks (5MB each)
3. **FINALIZE** - Complete upload
4. **STATUS** - Check processing status
5. **Tweet** - Create tweet with media_id

### API Documentation
- [Twitter API v2](https://developer.twitter.com/en/docs/twitter-api)
- [Media Upload](https://developer.twitter.com/en/docs/twitter-api/v1/media/upload-media/overview)

### Rate Limits
- Media upload: 500 requests per 15 min
- Tweet creation: 200 requests per 15 min
- Video size limit: 512MB
- Video length limit: 2:20

---

## 🔐 Security Best Practices

### API Key Storage
- ✅ **DO**: Store API keys in Xcode configuration files (not committed to git)
- ✅ **DO**: Use environment variables for sensitive data
- ❌ **DON'T**: Hardcode API keys in source code
- ❌ **DON'T**: Commit API keys to version control

### Recommended Approach
1. Create `Config.xcconfig` (gitignored):
```
INSTAGRAM_APP_ID = your_app_id
INSTAGRAM_APP_SECRET = your_secret
TIKTOK_CLIENT_KEY = your_key
// ... etc
```

2. Reference in Info.plist:
```xml
<key>InstagramAppID</key>
<string>$(INSTAGRAM_APP_ID)</string>
```

3. Add to `.gitignore`:
```
Config.xcconfig
*.xcconfig
```

### OAuth Security
- Always use PKCE (Proof Key for Code Exchange) when available
- Implement state parameter for CSRF protection
- Store tokens in iOS Keychain (not UserDefaults)
- Refresh tokens before expiry

---

## 🧪 Testing

### Test Mode
All platform adapters return `isConfigured: false` by default. To enable:

1. Configure API credentials (see above)
2. Update adapter `isConfigured` property:
```swift
var isConfigured: Bool {
    return InstagramConfig.appID != nil // Check your config
}
```

3. Uncomment authentication and upload code

### Manual Testing
1. Build and run app
2. Open "Export → Video Export"
3. Select platform
4. Check authentication status
5. Test upload with short video (~5 seconds)

### Debugging
- Enable network logging in adapters
- Check OAuth redirect handling in AppDelegate
- Monitor API responses and rate limits
- Test with various video durations and formats

---

## 📋 Checklist

Before deploying to production:

### Instagram
- [ ] Facebook App created and configured
- [ ] Instagram Basic Display API added
- [ ] API credentials added to Xcode
- [ ] OAuth redirect handled
- [ ] Content Publishing tested

### TikTok
- [ ] TikTok Developer account approved
- [ ] Content Posting API access granted
- [ ] API credentials configured
- [ ] Upload tested with test account

### YouTube
- [ ] Google Cloud project created
- [ ] YouTube Data API enabled
- [ ] OAuth consent screen configured
- [ ] GoogleSignIn SDK integrated
- [ ] Upload quota sufficient

### Snapchat
- [ ] Snap Kit app created
- [ ] Creative Kit enabled
- [ ] Snap Kit SDK integrated
- [ ] Share sheet tested

### Twitter/X
- [ ] Developer account with elevated access
- [ ] API v2 access enabled
- [ ] Media upload implemented
- [ ] Chunked upload tested

### General
- [ ] All API keys stored securely
- [ ] Config files added to .gitignore
- [ ] OAuth redirects handled in AppDelegate
- [ ] Error handling implemented
- [ ] Rate limiting handled
- [ ] User authentication flows tested

---

## 🆘 Troubleshooting

### Common Issues

**"Not Configured" Error**
- Check API credentials in Info.plist
- Verify `isConfigured` returns true
- Ensure SDK is properly integrated

**OAuth Redirect Not Working**
- Check URL scheme in Info.plist matches redirect URI
- Verify AppDelegate handles URL
- Check OAuth callback implementation

**Upload Fails**
- Verify authentication token is valid
- Check video format and size limits
- Monitor network requests
- Check platform-specific error messages

**Rate Limited**
- Implement exponential backoff
- Check daily/hourly limits
- Consider request batching
- Monitor quota usage

---

## 📚 Additional Resources

- [SOCIAL_MEDIA_IMPLEMENTATION_PLAN.md](./SOCIAL_MEDIA_IMPLEMENTATION_PLAN.md) - Full implementation roadmap
- [VIDEO_EXPORT_USAGE_GUIDE.md](./VIDEO_EXPORT_USAGE_GUIDE.md) - Video export documentation
- Platform-specific documentation (linked in each section above)

---

## 🔄 Next Steps

After completing API setup:
1. Test authentication flow for each platform
2. Test video upload with sample content
3. Implement error handling and retry logic
4. Add user feedback (progress, success, errors)
5. Phase 3: AI Content Creation integration

---

**Last Updated**: October 2025
**Version**: 2.0 - Phase 2 Foundation

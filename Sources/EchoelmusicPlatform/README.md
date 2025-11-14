# EchoelmusicPlatform

**Purpose:** Platform-specific glue (iOS lifecycle, permissions).

## Responsibilities

- PermissionManager (microphone, camera, health, motion)
- App lifecycle hooks and device info helpers
- Platform-specific integrations (Xcode targets, entitlements)

## Getting Started

```swift
import EchoelmusicPlatform

// Request permissions
let manager = PermissionsManager()
let granted = await manager.request(.microphone)

// Request all required permissions
let allGranted = await manager.requestAllRequired()

// Check status
let status = manager.checkStatus(.camera)
```

## Testing

PermissionsManagerTests cover request flows

## Notes

- Bundle ID / signing changes must be handled manually in Xcode
- Info.plist usage descriptions required
- Entitlements configured per platform

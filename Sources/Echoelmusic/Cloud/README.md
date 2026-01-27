# Cloud Module

CloudKit integration for session sync and backup.

## Overview

This module provides cloud synchronization capabilities using Apple CloudKit, enabling users to sync their meditation sessions across devices and maintain automatic backups.

## Key Components

### CloudSyncManager

Main cloud synchronization manager:

```swift
let manager = CloudSyncManager()

// Enable/disable sync
try await manager.enableSync()  // Requires iCloud account
manager.disableSync()

// Check status
manager.syncEnabled    // Bool
manager.isSyncing      // Bool
manager.lastSyncDate   // Date?
manager.cloudSessions  // [CloudSession]
```

### Session Sync

**Save a session:**
```swift
let session = Session(
    name: "Morning Meditation",
    duration: 600,
    avgHRV: 55.5,
    avgCoherence: 0.85
)
try await manager.saveSession(session)
```

**Fetch sessions:**
```swift
let sessions = try await manager.fetchSessions()
for session in sessions {
    print("\(session.name): \(session.avgCoherence) coherence")
}
```

### Auto Backup

Automatic periodic backup of ongoing sessions:

```swift
// Enable (default: every 5 minutes)
manager.enableAutoBackup()
manager.enableAutoBackup(interval: 300)  // Custom interval

// Update with biometric data
manager.updateSessionData(hrv: 50, coherence: 0.8, heartRate: 72)

// Finalize session
try await manager.finalizeSession()

// Disable
manager.disableAutoBackup()
```

### CloudSession

Session data structure:

```swift
struct CloudSession: Identifiable {
    let id: UUID
    let name: String
    let duration: TimeInterval
    let avgHRV: Float
    let avgCoherence: Float
}
```

### SessionBackupData

Internal backup data structure:

```swift
struct SessionBackupData {
    var name: String
    var startTime: Date
    var hrvReadings: [Float]
    var coherenceReadings: [Float]
    var heartRateReadings: [Float]
    var currentDuration: TimeInterval
}
```

## CloudKit Configuration

### Container Identifier

```
iCloud.com.echoelmusic.app
```

### Record Types

**Session** (Complete sessions)
- `name: String`
- `duration: Double`
- `avgHRV: Double`
- `avgCoherence: Double`

**SessionBackup** (Partial backups)
- `name: String`
- `startTime: Date`
- `duration: Double`
- `avgHRV: Double`
- `avgCoherence: Double`
- `avgHeartRate: Double`
- `dataPointCount: Int64`
- `isPartialBackup: Bool`
- `backupDate: Date`
- `readings: Data` (JSON-encoded arrays)

## Error Handling

```swift
enum CloudError: LocalizedError {
    case iCloudNotAvailable  // User not signed in to iCloud
    case syncFailed          // Network or CloudKit error
}
```

Usage:
```swift
do {
    try await manager.enableSync()
} catch CloudError.iCloudNotAvailable {
    showSignInPrompt()
} catch CloudError.syncFailed {
    showRetryOption()
}
```

## Databases

| Database | Purpose |
|----------|---------|
| Private | User's own sessions (default) |
| Shared | Future: Collaborative sessions |

## Observable Properties

All sync state is observable for UI binding:

```swift
@Published var isSyncing: Bool
@Published var syncEnabled: Bool
@Published var lastSyncDate: Date?
@Published var cloudSessions: [CloudSession]
```

## Privacy

- All session data stored in user's private CloudKit container
- Data never shared with third parties
- Users can delete all cloud data at any time
- No tracking or analytics in cloud sync

## Files

| File | Description |
|------|-------------|
| `CloudSyncManager.swift` | Main CloudKit integration |
| `ServerInfrastructure.swift` | Server-side infrastructure |
| `WebSocketServer.swift` | Real-time sync (collaboration) |

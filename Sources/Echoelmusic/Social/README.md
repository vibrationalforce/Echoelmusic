# Social Module

Social features and group coherence functionality for Echoelmusic.

## Overview

The Social module enables multi-participant sessions, group coherence tracking, and social wellness experiences.

## Features

### Group Sessions

Connect with up to 1000+ participants for synchronized:
- Meditation sessions
- Coherence circles
- Music jams
- Research studies

### Group Metrics

Track collective biometric synchronization:
- Heart rate sync
- Breath sync
- HRV sync
- Entrainment level
- Group flow detection

### Quantum Entanglement Events

When group coherence reaches high synchronization (>90%), the system detects "quantum entanglement" moments.

## Key Components

### SocialCoherenceEngine

Main engine for group sessions:

```swift
let engine = SocialCoherenceEngine()

// Create session
engine.createSession(type: .coherenceCircle, maxParticipants: 100)

// Join session
engine.joinSession(sessionId: "abc123")

// Update own biometrics
engine.updateBioData(hrv: 55, coherence: 0.8, heartRate: 72)

// Get group state
let groupState = engine.currentGroupState
print("Group coherence: \(groupState.groupCoherence)")
print("Entrainment level: \(groupState.entrainmentLevel)")
```

### Session Types

| Type | Description |
|------|-------------|
| `openMeditation` | Open group meditation |
| `coherenceCircle` | Focused coherence training |
| `musicJam` | Collaborative music session |
| `researchStudy` | Scientific study session |

### Group State

```swift
struct GroupState {
    var participantCount: Int
    var groupCoherence: Float
    var heartRateSync: Float
    var breathSync: Float
    var hrvSync: Float
    var entrainmentLevel: Float
    var isFlowAchieved: Bool
    var entanglementEvents: [EntanglementEvent]
}
```

### Guided Exercises

Built-in group exercises:

- **Box Breathing** - 4-4-4-4 pattern
- **Coherence Breathing** - Optimal HRV pattern
- **Heart Meditation** - Focus on heart center

```swift
engine.startGuidedExercise(.coherenceBreathing)
```

## Privacy

- Biometric data is anonymized for group metrics
- Personal data never shared with other participants
- Option for fully anonymous participation
- Consent required for research sessions

## Network

Sessions use secure WebSocket connections for real-time synchronization with automatic reconnection and graceful degradation.

## Files

| File | Description |
|------|-------------|
| `SocialCoherenceEngine.swift` | Main social engine |
| `GroupSessionManager.swift` | Session management |

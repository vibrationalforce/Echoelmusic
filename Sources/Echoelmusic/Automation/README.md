# Automation Module

Intelligent automation and scripting for Echoelmusic.

## Overview

The Automation module provides intelligent automation capabilities, allowing the app to make context-aware decisions and automate complex workflows.

## Features

### Context-Aware Automation

The system considers:
- Time of day
- User activity patterns
- Biometric state
- Environmental factors
- Previous session data

### Automation Rules

Create custom automation rules:

```swift
let automation = AutomationEngine()

// Create rule
let rule = AutomationRule(
    trigger: .timeOfDay(hour: 7),
    conditions: [.isWeekday, .coherenceBelow(0.5)],
    action: .startMorningMeditation
)

automation.addRule(rule)
```

### Triggers

| Trigger | Description |
|---------|-------------|
| `.timeOfDay(hour:)` | Specific time |
| `.locationEnter(_:)` | Geofence entry |
| `.locationExit(_:)` | Geofence exit |
| `.coherenceThreshold(_:)` | Coherence level |
| `.heartRateThreshold(_:)` | Heart rate level |
| `.appForeground` | App becomes active |
| `.appBackground` | App enters background |
| `.watchConnected` | Watch connects |

### Conditions

| Condition | Description |
|-----------|-------------|
| `.isWeekday` | Monday-Friday |
| `.isWeekend` | Saturday-Sunday |
| `.coherenceAbove(_:)` | Coherence check |
| `.coherenceBelow(_:)` | Coherence check |
| `.sessionActive` | Session running |
| `.sessionInactive` | No session |
| `.timeRange(_:)` | Within time range |

### Actions

| Action | Description |
|--------|-------------|
| `.startSession(preset:)` | Start with preset |
| `.stopSession` | End current session |
| `.setVisualization(_:)` | Change visualization |
| `.adjustVolume(_:)` | Modify volume |
| `.sendNotification(_:)` | Local notification |
| `.logEvent(_:)` | Analytics event |

## Built-in Automations

### Morning Routine

Automatically starts calming session when:
- Morning time (6-9 AM)
- Low initial coherence
- Weekday

### Focus Mode

Activates focus-enhancing visuals when:
- Working hours detected
- Coherence drops below threshold
- No recent sessions

### Evening Wind-Down

Transitions to relaxing mode when:
- Evening time (8-10 PM)
- High activity earlier in day
- Approaching sleep time

## Scripting

Advanced users can write custom scripts:

```swift
// Example script
automation.runScript("""
    when coherence < 0.3 for 5 minutes:
        show breathing guide
        wait until coherence > 0.5
        show celebration
    end
""")
```

## Machine Learning

The automation system learns from:
- User behavior patterns
- Session outcomes
- Optimal timing preferences
- Effective intervention strategies

## Privacy

- All learning happens on-device
- No behavioral data shared
- User controls all automations
- Easy enable/disable

## Files

| File | Description |
|------|-------------|
| `AutomationEngine.swift` | Main automation logic |
| `AutomationRule.swift` | Rule definitions |
| `AutomationScript.swift` | Script interpreter |

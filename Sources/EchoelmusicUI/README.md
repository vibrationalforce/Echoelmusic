# EchoelmusicUI

**Purpose:** SwiftUI screens for Live and Editor modes.

## Responsibilities

- Provide LiveModeView, SessionEditor, Settings view
- Orientation handling (portrait & landscape)
- InputMode toggle (single/multi-touch)

## Getting Started

```swift
import EchoelmusicUI
import SwiftUI

struct ContentView: View {
    var body: some View {
        LiveModeView()
    }
}
```

## Testing

UI tests for orientation handling in `Tests/EchoelmusicUITests`

## Architecture

- **Screens/**: Top-level views (Live, Editor, Settings)
- **Components/**: Reusable UI components
- **LiveMode/**: Live performance interface
- **Editor/**: Session editing interface

## Notes

- Keep Views lightweight
- Connect to AppState/SessionState for data
- Dark theme optimized

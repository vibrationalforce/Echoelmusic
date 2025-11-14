# EchoelmusicCore

**Purpose:** Foundation layer - types, protocols, EventBus, StateGraph.

## Responsibilities

- Define cross-module contracts (AudioNodeProtocol, NodeParameter)
- Provide EventBus and StateGraph (pub/sub + state transitions)
- Keep core dependency-free (no module imports to Core)

## Getting Started

```swift
import EchoelmusicCore

// Use EventBus for inter-module communication
EventBus.shared.publish(MyEvent(source: "module"))
EventBus.shared.subscribe(to: MyEvent.self) { event in
    print("Received: \(event)")
}

// Use StateGraph for finite-state logic
let graph = StateGraph<AppState>(initialState: .idle)
graph.allow(from: .idle, to: .running)
graph.transition(to: .running)
```

## Testing

Unit tests for EventBus and StateGraph live in `Tests/EchoelmusicCoreTests`

## Architecture

- **Protocols/**: Core protocol definitions
- **Types/**: Shared type definitions
- **EventBus/**: Inter-module event system
- **StateGraph/**: State machine implementation

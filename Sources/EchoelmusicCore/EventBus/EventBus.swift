import Foundation
import Combine

/// Central event bus for inter-module communication
/// Provides pub/sub pattern for decoupled module coordination
@MainActor
public final class EventBus: ObservableObject {

    /// Shared singleton instance
    public static let shared = EventBus()

    /// Event subscribers
    private var subscribers: [String: [UUID: (any EventProtocol) -> Void]] = [:]

    /// Subject for publishing events
    private let eventSubject = PassthroughSubject<any EventProtocol, Never>()

    /// Cancellables
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupEventSubscription()
    }

    private func setupEventSubscription() {
        eventSubject
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    /// Publish an event to all subscribers
    /// - Parameter event: Event to publish
    public func publish<E: EventProtocol>(_ event: E) {
        eventSubject.send(event)
    }

    /// Subscribe to events of a specific type
    /// - Parameters:
    ///   - eventType: Type of event to subscribe to
    ///   - handler: Closure to handle events
    /// - Returns: Subscription ID for later unsubscribe
    @discardableResult
    public func subscribe<E: EventProtocol>(
        to eventType: E.Type,
        handler: @escaping (E) -> Void
    ) -> UUID {
        let id = UUID()
        let key = String(describing: eventType)

        var handlers = subscribers[key] ?? [:]
        handlers[id] = { event in
            if let typedEvent = event as? E {
                handler(typedEvent)
            }
        }
        subscribers[key] = handlers

        return id
    }

    /// Unsubscribe from events
    /// - Parameters:
    ///   - subscriptionID: ID returned from subscribe
    ///   - eventType: Type of event
    public func unsubscribe<E: EventProtocol>(
        subscriptionID: UUID,
        from eventType: E.Type
    ) {
        let key = String(describing: eventType)
        subscribers[key]?[subscriptionID] = nil
    }

    private func handleEvent(_ event: any EventProtocol) {
        let key = String(describing: type(of: event))
        subscribers[key]?.values.forEach { handler in
            handler(event)
        }
    }
}

/// Protocol for all events in the system
public protocol EventProtocol: Sendable {
    /// Event timestamp
    var timestamp: Date { get }

    /// Event source identifier
    var source: String { get }
}

/// Base event type
public struct BaseEvent: EventProtocol {
    public let timestamp: Date
    public let source: String

    public init(source: String) {
        self.timestamp = Date()
        self.source = source
    }
}

import Foundation

/// State graph for managing application state transitions
/// Provides finite state machine capabilities for audio/visual modes
public final class StateGraph<State: Hashable & Sendable>: @unchecked Sendable {

    /// Current state
    private var _currentState: State
    private let lock = NSLock()

    public var currentState: State {
        lock.lock()
        defer { lock.unlock() }
        return _currentState
    }

    /// Allowed state transitions
    private var transitions: [State: Set<State>] = [:]

    /// State enter/exit handlers
    private var enterHandlers: [State: [@Sendable () -> Void]] = [:]
    private var exitHandlers: [State: [@Sendable () -> Void]] = [:]

    public init(initialState: State) {
        self._currentState = initialState
    }

    /// Define allowed transition from one state to another
    /// - Parameters:
    ///   - from: Source state
    ///   - to: Destination state
    public func allow(from: State, to: State) {
        lock.lock()
        defer { lock.unlock() }

        var allowedStates = transitions[from] ?? Set<State>()
        allowedStates.insert(to)
        transitions[from] = allowedStates
    }

    /// Attempt to transition to a new state
    /// - Parameter newState: Target state
    /// - Returns: Whether transition was successful
    @discardableResult
    public func transition(to newState: State) -> Bool {
        lock.lock()
        let oldState = _currentState
        let allowedTransitions = transitions[oldState] ?? Set<State>()
        lock.unlock()

        guard allowedTransitions.contains(newState) else {
            print("⚠️ StateGraph: Transition from \(oldState) to \(newState) not allowed")
            return false
        }

        // Execute exit handlers for old state
        lock.lock()
        let exitHandlersToExecute = exitHandlers[oldState] ?? []
        lock.unlock()
        exitHandlersToExecute.forEach { $0() }

        // Update state
        lock.lock()
        _currentState = newState
        lock.unlock()

        // Execute enter handlers for new state
        lock.lock()
        let enterHandlersToExecute = enterHandlers[newState] ?? []
        lock.unlock()
        enterHandlersToExecute.forEach { $0() }

        print("✅ StateGraph: Transitioned from \(oldState) to \(newState)")
        return true
    }

    /// Register handler for entering a state
    /// - Parameters:
    ///   - state: State to watch
    ///   - handler: Closure to execute on enter
    public func onEnter(_ state: State, handler: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        var handlers = enterHandlers[state] ?? []
        handlers.append(handler)
        enterHandlers[state] = handlers
    }

    /// Register handler for exiting a state
    /// - Parameters:
    ///   - state: State to watch
    ///   - handler: Closure to execute on exit
    public func onExit(_ state: State, handler: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        var handlers = exitHandlers[state] ?? []
        handlers.append(handler)
        exitHandlers[state] = handlers
    }
}

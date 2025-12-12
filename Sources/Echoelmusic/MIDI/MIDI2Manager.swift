import Foundation
import CoreMIDI
import Combine

/// MIDI 2.0 Manager with Universal MIDI Packet (UMP) support
///
/// **Features:**
/// - MIDI 2.0 UMP packet encoding/decoding
/// - Virtual MIDI 2.0 source creation
/// - 32-bit parameter resolution
/// - Per-note controllers (PNC)
/// - Backwards compatible with MIDI 1.0
/// - Input validation for all parameters
/// - Result-based error handling
///
/// **Usage:**
/// ```swift
/// let midi2 = MIDI2Manager()
/// try await midi2.initialize()
///
/// // Send MIDI 2.0 note with validation
/// let result = midi2.sendNoteOnValidated(channel: 0, note: 60, velocity: 0.8)
/// switch result {
/// case .success: print("Note sent")
/// case .failure(let error): print("Error: \(error)")
/// }
/// ```
@MainActor
class MIDI2Manager: ObservableObject {

    // MARK: - Published State

    @Published var isInitialized: Bool = false
    @Published var connectedEndpoints: [MIDIEndpointRef] = []
    @Published var errorMessage: String?
    @Published var lastError: MIDI2Error?

    // MARK: - Delegate

    /// Delegate for MIDI events and errors
    weak var delegate: MIDI2ManagerDelegate?

    // MARK: - Private Properties

    private var midiClient: MIDIClientRef = 0
    private var virtualSource: MIDIEndpointRef = 0
    private var outputPort: MIDIPortRef = 0

    // Active notes tracking (for per-note controllers)
    private var activeNotes: Set<NoteIdentifier> = []

    // Message queue for when not initialized
    private var pendingMessages: [(UMPPacket64, Date)] = []
    private let maxPendingMessages = 100

    private struct NoteIdentifier: Hashable {
        let channel: UInt8
        let note: UInt8
    }

    // MARK: - Initialization

    init() {
        EchoelLogger.debug("MIDI2Manager created", category: EchoelLogger.midi)
    }

    /// Initialize MIDI 2.0 system
    func initialize() async throws {
        guard !isInitialized else { return }

        do {
            // Create MIDI client
            var client: MIDIClientRef = 0
            let clientStatus = MIDIClientCreateWithBlock("Echoelmusic_MIDI2_Client" as CFString, &client) { notification in
                // Handle MIDI notifications
                self.handleMIDINotification(notification)
            }

            guard clientStatus == noErr else {
                throw MIDI2Error.clientCreationFailed(Int(clientStatus))
            }

            midiClient = client

            // Create virtual MIDI 2.0 source
            var source: MIDIEndpointRef = 0
            let sourceStatus = MIDISourceCreateWithProtocol(
                midiClient,
                "Echoelmusic MIDI 2.0 Output" as CFString,
                ._2_0,  // MIDI 2.0 protocol
                &source
            )

            guard sourceStatus == noErr else {
                throw MIDI2Error.sourceCreationFailed(Int(sourceStatus))
            }

            virtualSource = source

            // Create output port
            var port: MIDIPortRef = 0
            let portStatus = MIDIOutputPortCreate(
                midiClient,
                "Echoelmusic_Output" as CFString,
                &port
            )

            guard portStatus == noErr else {
                throw MIDI2Error.portCreationFailed(Int(portStatus))
            }

            outputPort = port

            isInitialized = true
            EchoelLogger.success("MIDI 2.0 initialized (UMP protocol)", category: EchoelLogger.midi)

            // Process any pending messages
            processPendingMessages()

        } catch {
            let midi2Error = error as? MIDI2Error ?? MIDI2Error.notInitialized
            errorMessage = "MIDI 2.0 initialization failed: \(error.localizedDescription)"
            lastError = midi2Error
            delegate?.midi2Manager(self, didEncounterError: midi2Error)
            throw error
        }
    }

    /// Cleanup MIDI resources
    func cleanup() {
        if virtualSource != 0 {
            MIDIEndpointDispose(virtualSource)
            virtualSource = 0
        }

        if outputPort != 0 {
            MIDIPortDispose(outputPort)
            outputPort = 0
        }

        if midiClient != 0 {
            MIDIClientDispose(midiClient)
            midiClient = 0
        }

        isInitialized = false
        activeNotes.removeAll()
        pendingMessages.removeAll()
        EchoelLogger.info("MIDI 2.0 cleaned up", category: EchoelLogger.midi)
    }

    /// Process any messages that were queued while initializing
    private func processPendingMessages() {
        guard isInitialized else { return }

        let messages = pendingMessages
        pendingMessages.removeAll()

        for (packet, _) in messages {
            sendUMPPacket(packet)
        }

        if !messages.isEmpty {
            EchoelLogger.debug("Processed \(messages.count) pending MIDI messages", category: EchoelLogger.midi)
        }
    }

    // MARK: - MIDI Notification Handling

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        let notif = notification.pointee

        switch notif.messageID {
        case .msgSetupChanged:
            EchoelLogger.debug("MIDI setup changed", category: EchoelLogger.midi)
            scanEndpoints()

        case .msgObjectAdded:
            EchoelLogger.debug("MIDI object added", category: EchoelLogger.midi)
            scanEndpoints()
            delegate?.midi2ManagerDidUpdateEndpoints(self)

        case .msgObjectRemoved:
            EchoelLogger.debug("MIDI object removed", category: EchoelLogger.midi)
            scanEndpoints()
            delegate?.midi2ManagerDidUpdateEndpoints(self)

        case .msgPropertyChanged:
            break  // Ignore property changes

        default:
            break
        }
    }

    /// Scan for available MIDI endpoints
    private func scanEndpoints() {
        var endpoints: [MIDIEndpointRef] = []

        let destCount = MIDIGetNumberOfDestinations()
        for i in 0..<destCount {
            let endpoint = MIDIGetDestination(i)
            if endpoint != 0 {
                endpoints.append(endpoint)
            }
        }

        Task { @MainActor in
            self.connectedEndpoints = endpoints
        }
    }

    // MARK: - Note On/Off

    /// Send MIDI 2.0 Note On (convenience method)
    /// - Parameters:
    ///   - channel: MIDI channel (0-15)
    ///   - note: Note number (0-127)
    ///   - velocity: Velocity (0.0-1.0)
    func sendNoteOn(channel: UInt8, note: UInt8, velocity: Float) {
        _ = sendNoteOnValidated(channel: channel, note: note, velocity: velocity)
    }

    /// Send MIDI 2.0 Note On with validation and result
    /// - Parameters:
    ///   - channel: MIDI channel (0-15)
    ///   - note: Note number (0-127)
    ///   - velocity: Velocity (0.0-1.0)
    /// - Returns: Result indicating success or specific error
    @discardableResult
    func sendNoteOnValidated(channel: UInt8, note: UInt8, velocity: Float) -> Result<Void, MIDI2Error> {
        // Validate parameters
        guard MIDIConstants.isValidChannel(channel) else {
            let error = MIDI2Error.invalidChannel(channel)
            handleError(error)
            return .failure(error)
        }

        guard MIDIConstants.isValidNote(note) else {
            let error = MIDI2Error.invalidNote(note)
            handleError(error)
            return .failure(error)
        }

        guard isInitialized else {
            EchoelLogger.warning("MIDI 2.0 not initialized, queueing note on", category: EchoelLogger.midi)
            // Queue the message for later
            let clampedVelocity = MIDIConstants.clampVelocity(velocity)
            let packet = UMPPacket64.noteOn(channel: channel, note: note, velocity: clampedVelocity)
            queuePendingMessage(packet)
            return .failure(.notInitialized)
        }

        let clampedVelocity = MIDIConstants.clampVelocity(velocity)
        let packet = UMPPacket64.noteOn(channel: channel, note: note, velocity: clampedVelocity)
        sendUMPPacket(packet)

        // Track active note
        activeNotes.insert(NoteIdentifier(channel: channel, note: note))

        return .success(())
    }

    /// Send MIDI 2.0 Note Off (convenience method)
    func sendNoteOff(channel: UInt8, note: UInt8, velocity: Float = 0.0) {
        _ = sendNoteOffValidated(channel: channel, note: note, velocity: velocity)
    }

    /// Send MIDI 2.0 Note Off with validation and result
    @discardableResult
    func sendNoteOffValidated(channel: UInt8, note: UInt8, velocity: Float = 0.0) -> Result<Void, MIDI2Error> {
        guard MIDIConstants.isValidChannel(channel) else {
            return .failure(.invalidChannel(channel))
        }

        guard MIDIConstants.isValidNote(note) else {
            return .failure(.invalidNote(note))
        }

        guard isInitialized else {
            return .failure(.notInitialized)
        }

        let clampedVelocity = MIDIConstants.clampVelocity(velocity)
        let packet = UMPPacket64.noteOff(channel: channel, note: note, velocity: clampedVelocity)
        sendUMPPacket(packet)

        // Remove from active notes
        activeNotes.remove(NoteIdentifier(channel: channel, note: note))

        return .success(())
    }

    /// Queue a message for sending when initialized
    private func queuePendingMessage(_ packet: UMPPacket64) {
        if pendingMessages.count >= maxPendingMessages {
            pendingMessages.removeFirst()
        }
        pendingMessages.append((packet, Date()))
    }

    /// Handle and propagate an error
    private func handleError(_ error: MIDI2Error) {
        lastError = error
        errorMessage = error.errorDescription
        delegate?.midi2Manager(self, didEncounterError: error)
        EchoelLogger.warning(error.errorDescription ?? "Unknown MIDI error", category: EchoelLogger.midi)
    }

    // MARK: - Per-Note Controllers

    /// Send Per-Note Controller (MIDI 2.0 exclusive)
    /// - Parameters:
    ///   - channel: MIDI channel (0-15)
    ///   - note: Note number (0-127)
    ///   - controller: Controller type
    ///   - value: Controller value (0.0-1.0)
    @discardableResult
    func sendPerNoteController(channel: UInt8, note: UInt8,
                               controller: PerNoteController, value: Float) -> Result<Void, MIDI2Error> {
        guard isInitialized else {
            return .failure(.notInitialized)
        }

        guard MIDIConstants.isValidChannel(channel) else {
            return .failure(.invalidChannel(channel))
        }

        guard MIDIConstants.isValidNote(note) else {
            return .failure(.invalidNote(note))
        }

        // Check if note is active
        let noteId = NoteIdentifier(channel: channel, note: note)
        guard activeNotes.contains(noteId) else {
            EchoelLogger.debug("Per-note controller sent for inactive note \(note) on channel \(channel)", category: EchoelLogger.midi)
            return .failure(.noteNotActive(note: note, channel: channel))
        }

        let clampedValue = value.clamped(to: 0...1)
        let packet = UMPPacket64.perNoteController(
            channel: channel,
            note: note,
            controller: controller,
            value: clampedValue
        )

        sendUMPPacket(packet)
        return .success(())
    }

    /// Send Per-Note Pitch Bend (MIDI 2.0)
    /// - Parameters:
    ///   - channel: MIDI channel (0-15)
    ///   - note: Note number (0-127)
    ///   - bend: Pitch bend (-1.0 to +1.0, center = 0.0)
    @discardableResult
    func sendPerNotePitchBend(channel: UInt8, note: UInt8, bend: Float) -> Result<Void, MIDI2Error> {
        guard isInitialized else {
            return .failure(.notInitialized)
        }

        guard MIDIConstants.isValidChannel(channel) else {
            return .failure(.invalidChannel(channel))
        }

        guard MIDIConstants.isValidNote(note) else {
            return .failure(.invalidNote(note))
        }

        let noteId = NoteIdentifier(channel: channel, note: note)
        guard activeNotes.contains(noteId) else {
            EchoelLogger.debug("Per-note pitch bend sent for inactive note \(note)", category: EchoelLogger.midi)
            return .failure(.noteNotActive(note: note, channel: channel))
        }

        let clampedBend = MIDIConstants.clampPitchBend(bend)
        let packet = UMPPacket64.perNotePitchBend(channel: channel, note: note, bend: clampedBend)
        sendUMPPacket(packet)
        return .success(())
    }

    // MARK: - Channel Messages

    /// Send Channel Pressure (Aftertouch)
    func sendChannelPressure(channel: UInt8, pressure: Float) {
        guard isInitialized else { return }

        let packet = UMPPacket64.channelPressure(channel: channel, pressure: pressure)
        sendUMPPacket(packet)
    }

    /// Send Control Change (MIDI 2.0 32-bit resolution)
    func sendControlChange(channel: UInt8, controller: UInt8, value: Float) {
        guard isInitialized else { return }

        let packet = UMPPacket64.controlChange(channel: channel, controller: controller, value: value)
        sendUMPPacket(packet)
    }

    // MARK: - UMP Packet Sending

    /// Send a 64-bit UMP packet
    private func sendUMPPacket(_ packet: UMPPacket64) {
        guard virtualSource != 0 else {
            EchoelLogger.warning("Virtual source not created", category: EchoelLogger.midi)
            return
        }

        var packetList = MIDIEventList()
        packetList.protocol = ._2_0
        packetList.numPackets = 1

        // Create MIDIEventPacket for UMP
        withUnsafeMutablePointer(to: &packetList.packet) { packetPtr in
            packetPtr.pointee.timeStamp = 0  // Send immediately
            packetPtr.pointee.wordCount = 2  // 64-bit packet = 2 words

            // Copy packet bytes
            let bytes = packet.bytes
            withUnsafeMutableBytes(of: &packetPtr.pointee.words) { wordsPtr in
                for (index, byte) in bytes.enumerated() {
                    wordsPtr[index] = byte
                }
            }
        }

        // Send via virtual source
        let status = MIDIReceivedEventList(virtualSource, &packetList)
        if status != noErr {
            let error = MIDI2Error.sendFailed(Int(status))
            handleError(error)
        }
    }

    // MARK: - Utility

    /// Get info about connected MIDI 2.0 endpoints
    func getEndpointInfo() -> [String] {
        var info: [String] = []

        for endpoint in connectedEndpoints {
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)

            if let nameStr = name?.takeRetainedValue() as String? {
                info.append(nameStr)
            }
        }

        return info
    }

    /// Check if note is currently active
    func isNoteActive(channel: UInt8, note: UInt8) -> Bool {
        activeNotes.contains(NoteIdentifier(channel: channel, note: note))
    }

    /// Get count of active notes
    var activeNoteCount: Int {
        activeNotes.count
    }

    deinit {
        cleanup()
    }
}

// MARK: - Errors

enum MIDI2Error: Error, LocalizedError, Equatable {
    case clientCreationFailed(Int)
    case sourceCreationFailed(Int)
    case portCreationFailed(Int)
    case notInitialized
    case invalidChannel(UInt8)
    case invalidNote(UInt8)
    case invalidVelocity(Float)
    case noteNotActive(note: UInt8, channel: UInt8)
    case sendFailed(Int)

    var errorDescription: String? {
        switch self {
        case .clientCreationFailed(let code):
            return "MIDI client creation failed with code \(code)"
        case .sourceCreationFailed(let code):
            return "MIDI source creation failed with code \(code)"
        case .portCreationFailed(let code):
            return "MIDI port creation failed with code \(code)"
        case .notInitialized:
            return "MIDI 2.0 not initialized"
        case .invalidChannel(let channel):
            return "Invalid MIDI channel: \(channel) (must be 0-15)"
        case .invalidNote(let note):
            return "Invalid MIDI note: \(note) (must be 0-127)"
        case .invalidVelocity(let velocity):
            return "Invalid velocity: \(velocity) (must be 0.0-1.0)"
        case .noteNotActive(let note, let channel):
            return "Note \(note) is not active on channel \(channel)"
        case .sendFailed(let code):
            return "Failed to send MIDI packet with code \(code)"
        }
    }
}

// MARK: - Delegate Protocol

/// Delegate protocol for MIDI2Manager events
protocol MIDI2ManagerDelegate: AnyObject {
    /// Called when MIDI endpoints are added or removed
    func midi2ManagerDidUpdateEndpoints(_ manager: MIDI2Manager)

    /// Called when a MIDI error occurs
    func midi2Manager(_ manager: MIDI2Manager, didEncounterError error: MIDI2Error)

    /// Called when a MIDI message is received (for future input support)
    func midi2Manager(_ manager: MIDI2Manager, didReceiveNoteOn note: UInt8, velocity: Float, channel: UInt8)
    func midi2Manager(_ manager: MIDI2Manager, didReceiveNoteOff note: UInt8, velocity: Float, channel: UInt8)
    func midi2Manager(_ manager: MIDI2Manager, didReceiveControlChange controller: UInt8, value: Float, channel: UInt8)
}

// Default implementations for optional delegate methods
extension MIDI2ManagerDelegate {
    func midi2ManagerDidUpdateEndpoints(_ manager: MIDI2Manager) {}
    func midi2Manager(_ manager: MIDI2Manager, didEncounterError error: MIDI2Error) {}
    func midi2Manager(_ manager: MIDI2Manager, didReceiveNoteOn note: UInt8, velocity: Float, channel: UInt8) {}
    func midi2Manager(_ manager: MIDI2Manager, didReceiveNoteOff note: UInt8, velocity: Float, channel: UInt8) {}
    func midi2Manager(_ manager: MIDI2Manager, didReceiveControlChange controller: UInt8, value: Float, channel: UInt8) {}
}

import Foundation
#if canImport(Combine)
import Combine
#endif

// ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
// ║                                                                                                       ║
// ║   ███████╗ ██████╗██╗  ██╗ ██████╗ ██████╗  ██████╗  █████╗ ██████╗ ██████╗                           ║
// ║   ██╔════╝██╔════╝██║  ██║██╔═══██╗██╔══██╗██╔═══██╗██╔══██╗██╔══██╗██╔══██╗                          ║
// ║   █████╗  ██║     ███████║██║   ██║██████╔╝██║   ██║███████║██████╔╝██║  ██║                          ║
// ║   ██╔══╝  ██║     ██╔══██║██║   ██║██╔══██╗██║   ██║██╔══██║██╔══██╗██║  ██║                          ║
// ║   ███████╗╚██████╗██║  ██║╚██████╔╝██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝                          ║
// ║   ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝                          ║
// ║                                                                                                       ║
// ║   🎛️ ECHOBOARD - Unified Control Dashboard 🎛️                                                        ║
// ║                                                                                                       ║
// ║   Central Hub for ALL Connected Devices & Systems                                                    ║
// ║   Audio • Video • Lighting • Vehicles • Drones • Smart Home • Wearables                              ║
// ║                                                                                                       ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝

// MARK: - Device Category

public enum EchoboardCategory: String, CaseIterable, Codable {
    case audio = "Audio"
    case video = "Video"
    case lighting = "Lighting"
    case biometrics = "Biometrics"
    case smartHome = "Smart Home"
    case vehicles = "Vehicles"
    case drones = "Drones"
    case robots = "Robots"
    case vr = "VR/AR"
    case streaming = "Streaming"
    case collaboration = "Collaboration"
    case wellness = "Wellness"

    public var icon: String {
        switch self {
        case .audio: return "🎵"
        case .video: return "🎬"
        case .lighting: return "💡"
        case .biometrics: return "❤️"
        case .smartHome: return "🏠"
        case .vehicles: return "🚗"
        case .drones: return "🚁"
        case .robots: return "🤖"
        case .vr: return "🥽"
        case .streaming: return "📡"
        case .collaboration: return "👥"
        case .wellness: return "🧘"
        }
    }

    public var color: String {
        switch self {
        case .audio: return "#FF6B6B"
        case .video: return "#4ECDC4"
        case .lighting: return "#FFE66D"
        case .biometrics: return "#FF69B4"
        case .smartHome: return "#95E1D3"
        case .vehicles: return "#5D9CEC"
        case .drones: return "#A29BFE"
        case .robots: return "#636E72"
        case .vr: return "#00CEC9"
        case .streaming: return "#E17055"
        case .collaboration: return "#74B9FF"
        case .wellness: return "#55EFC4"
        }
    }
}

// MARK: - Device Connection Status

public enum ConnectionStatus: String, Codable {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"
    case paired = "Paired"
    case error = "Error"
    case sleeping = "Sleeping"
    case updating = "Updating..."

    public var icon: String {
        switch self {
        case .disconnected: return "⭕"
        case .connecting: return "🔄"
        case .connected: return "🟢"
        case .paired: return "🔗"
        case .error: return "🔴"
        case .sleeping: return "😴"
        case .updating: return "⬆️"
        }
    }
}

// MARK: - Connected Device

public struct ConnectedDevice: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var category: EchoboardCategory
    public var status: ConnectionStatus
    public var manufacturer: String
    public var model: String
    public var firmwareVersion: String
    public var batteryLevel: Float?
    public var signalStrength: Float?
    public var ipAddress: String?
    public var macAddress: String?
    public var lastSeen: Date
    public var capabilities: [String]
    public var customProperties: [String: String]
    public var isFavorite: Bool
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        category: EchoboardCategory,
        status: ConnectionStatus = .disconnected,
        manufacturer: String = "",
        model: String = "",
        firmwareVersion: String = "1.0",
        batteryLevel: Float? = nil,
        signalStrength: Float? = nil,
        ipAddress: String? = nil,
        macAddress: String? = nil,
        capabilities: [String] = [],
        customProperties: [String: String] = [:],
        isFavorite: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.status = status
        self.manufacturer = manufacturer
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.batteryLevel = batteryLevel
        self.signalStrength = signalStrength
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.lastSeen = Date()
        self.capabilities = capabilities
        self.customProperties = customProperties
        self.isFavorite = isFavorite
        self.isEnabled = isEnabled
    }

    public var displayBattery: String {
        guard let level = batteryLevel else { return "N/A" }
        let percentage = Int(level * 100)
        let icon: String
        if percentage > 80 { icon = "🔋" }
        else if percentage > 50 { icon = "🔋" }
        else if percentage > 20 { icon = "🪫" }
        else { icon = "🪫" }
        return "\(icon) \(percentage)%"
    }

    public var displaySignal: String {
        guard let strength = signalStrength else { return "N/A" }
        let bars = Int(strength * 4)
        return String(repeating: "▮", count: bars) + String(repeating: "▯", count: 4 - bars)
    }
}

// MARK: - Control Group

public struct ControlGroup: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var deviceIds: [UUID]
    public var color: String
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "📁",
        deviceIds: [UUID] = [],
        color: String = "#808080",
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.deviceIds = deviceIds
        self.color = color
        self.isActive = isActive
    }
}

// MARK: - Automation Rule

public struct AutomationRule: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var trigger: AutomationTrigger
    public var actions: [AutomationAction]
    public var isEnabled: Bool
    public var lastTriggered: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        trigger: AutomationTrigger,
        actions: [AutomationAction] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.actions = actions
        self.isEnabled = isEnabled
        self.lastTriggered = nil
    }
}

public enum AutomationTrigger: Codable {
    case hrvThreshold(above: Double?, below: Double?)
    case heartRateThreshold(above: Int?, below: Int?)
    case coherenceThreshold(above: Double?, below: Double?)
    case timeOfDay(hour: Int, minute: Int)
    case deviceConnected(category: EchoboardCategory)
    case deviceDisconnected(category: EchoboardCategory)
    case locationEnter(name: String)
    case locationExit(name: String)
    case gestureDetected(gesture: String)
    case voiceCommand(phrase: String)
    case beatDetected(bpm: Int?)
    case manual

    public var description: String {
        switch self {
        case .hrvThreshold(let above, let below):
            if let a = above { return "HRV > \(a)ms" }
            if let b = below { return "HRV < \(b)ms" }
            return "HRV threshold"
        case .heartRateThreshold(let above, let below):
            if let a = above { return "HR > \(a) BPM" }
            if let b = below { return "HR < \(b) BPM" }
            return "Heart rate threshold"
        case .coherenceThreshold(let above, _):
            return "Coherence > \(Int((above ?? 0) * 100))%"
        case .timeOfDay(let hour, let minute):
            return String(format: "%02d:%02d", hour, minute)
        case .deviceConnected(let category):
            return "\(category.icon) connected"
        case .deviceDisconnected(let category):
            return "\(category.icon) disconnected"
        case .locationEnter(let name):
            return "Enter \(name)"
        case .locationExit(let name):
            return "Exit \(name)"
        case .gestureDetected(let gesture):
            return "Gesture: \(gesture)"
        case .voiceCommand(let phrase):
            return "Voice: \"\(phrase)\""
        case .beatDetected(let bpm):
            return bpm.map { "Beat @ \($0) BPM" } ?? "Beat detected"
        case .manual:
            return "Manual trigger"
        }
    }
}

public enum AutomationAction: Codable {
    case setDeviceParameter(deviceId: UUID, parameter: String, value: String)
    case toggleDevice(deviceId: UUID, on: Bool)
    case setLightColor(deviceId: UUID, hue: Float, saturation: Float, brightness: Float)
    case playPreset(presetName: String)
    case sendNotification(message: String)
    case startRecording
    case stopRecording
    case startStreaming(platform: String)
    case stopStreaming
    case runShortcut(name: String)
    case setVolume(level: Float)
    case setBPM(bpm: Double)
    case triggerEffect(effectName: String)

    public var description: String {
        switch self {
        case .setDeviceParameter(_, let param, let value):
            return "Set \(param) = \(value)"
        case .toggleDevice(_, let on):
            return on ? "Turn on" : "Turn off"
        case .setLightColor(_, _, _, let brightness):
            return "Light @ \(Int(brightness * 100))%"
        case .playPreset(let name):
            return "Play: \(name)"
        case .sendNotification(let msg):
            return "Notify: \(msg)"
        case .startRecording:
            return "Start recording"
        case .stopRecording:
            return "Stop recording"
        case .startStreaming(let platform):
            return "Stream to \(platform)"
        case .stopStreaming:
            return "Stop streaming"
        case .runShortcut(let name):
            return "Run: \(name)"
        case .setVolume(let level):
            return "Volume: \(Int(level * 100))%"
        case .setBPM(let bpm):
            return "BPM: \(Int(bpm))"
        case .triggerEffect(let name):
            return "Effect: \(name)"
        }
    }
}

// MARK: - Dashboard Widget

public struct DashboardWidget: Identifiable, Codable {
    public var id: UUID
    public var type: WidgetType
    public var title: String
    public var position: WidgetPosition
    public var size: WidgetSize
    public var configuration: [String: String]
    public var isVisible: Bool

    public init(
        id: UUID = UUID(),
        type: WidgetType,
        title: String,
        position: WidgetPosition = WidgetPosition(row: 0, column: 0),
        size: WidgetSize = .medium,
        configuration: [String: String] = [:],
        isVisible: Bool = true
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.position = position
        self.size = size
        self.configuration = configuration
        self.isVisible = isVisible
    }
}

public enum WidgetType: String, CaseIterable, Codable {
    case coherenceMeter = "Coherence Meter"
    case heartRateGraph = "Heart Rate Graph"
    case hrvDisplay = "HRV Display"
    case audioSpectrum = "Audio Spectrum"
    case deviceList = "Device List"
    case lightControl = "Light Control"
    case transportControl = "Transport Control"
    case presetSelector = "Preset Selector"
    case automationList = "Automation List"
    case systemStatus = "System Status"
    case clock = "Clock"
    case weather = "Weather"
    case quickActions = "Quick Actions"
    case sessionTimer = "Session Timer"
    case streamStatus = "Stream Status"
    case droneControl = "Drone Control"
    case vehicleStatus = "Vehicle Status"
    case wellnessScore = "Wellness Score"
    case mealPlan = "Meal Plan"
    case calendar = "Calendar"

    public var icon: String {
        switch self {
        case .coherenceMeter: return "💓"
        case .heartRateGraph: return "📈"
        case .hrvDisplay: return "📊"
        case .audioSpectrum: return "🎵"
        case .deviceList: return "📱"
        case .lightControl: return "💡"
        case .transportControl: return "⏯️"
        case .presetSelector: return "🎛️"
        case .automationList: return "⚡"
        case .systemStatus: return "📡"
        case .clock: return "🕐"
        case .weather: return "🌤️"
        case .quickActions: return "⚡"
        case .sessionTimer: return "⏱️"
        case .streamStatus: return "📺"
        case .droneControl: return "🚁"
        case .vehicleStatus: return "🚗"
        case .wellnessScore: return "🧘"
        case .mealPlan: return "🍽️"
        case .calendar: return "📅"
        }
    }
}

public struct WidgetPosition: Codable, Equatable {
    public var row: Int
    public var column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

public enum WidgetSize: String, CaseIterable, Codable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"

    public var gridSpan: (rows: Int, columns: Int) {
        switch self {
        case .small: return (1, 1)
        case .medium: return (1, 2)
        case .large: return (2, 2)
        case .extraLarge: return (2, 4)
        }
    }
}

// MARK: - Echoboard State

public struct EchoboardState: Codable {
    public var masterVolume: Float
    public var masterMute: Bool
    public var globalBPM: Double
    public var isPlaying: Bool
    public var isRecording: Bool
    public var isStreaming: Bool
    public var currentPreset: String?
    public var coherence: Double
    public var heartRate: Int
    public var hrvMs: Double
    public var sessionDuration: TimeInterval
    public var activeAutomations: Int

    public init() {
        masterVolume = 0.8
        masterMute = false
        globalBPM = 120.0
        isPlaying = false
        isRecording = false
        isStreaming = false
        currentPreset = nil
        coherence = 0.0
        heartRate = 72
        hrvMs = 50.0
        sessionDuration = 0
        activeAutomations = 0
    }
}

// MARK: - Main Echoboard Engine

@MainActor
public class Echoboard: ObservableObject {

    // MARK: - Published State

    @Published public var devices: [ConnectedDevice] = []
    @Published public var groups: [ControlGroup] = []
    @Published public var automations: [AutomationRule] = []
    @Published public var widgets: [DashboardWidget] = []
    @Published public var state: EchoboardState = EchoboardState()
    @Published public var isScanning: Bool = false
    @Published public var lastError: String?

    // MARK: - Computed Properties

    public var connectedDevices: [ConnectedDevice] {
        devices.filter { $0.status == .connected || $0.status == .paired }
    }

    public var devicesByCategory: [EchoboardCategory: [ConnectedDevice]] {
        Dictionary(grouping: devices) { $0.category }
    }

    public var favoriteDevices: [ConnectedDevice] {
        devices.filter { $0.isFavorite }
    }

    public var activeAutomations: [AutomationRule] {
        automations.filter { $0.isEnabled }
    }

    public var systemHealth: String {
        let connected = connectedDevices.count
        let total = devices.count
        if total == 0 { return "No devices" }
        let percentage = Int(Double(connected) / Double(total) * 100)
        return "\(connected)/\(total) (\(percentage)%)"
    }

    // MARK: - Initialization

    public init() {
        loadDefaultConfiguration()
    }

    private func loadDefaultConfiguration() {
        // Default widgets
        widgets = [
            DashboardWidget(type: .coherenceMeter, title: "Coherence", position: WidgetPosition(row: 0, column: 0), size: .medium),
            DashboardWidget(type: .heartRateGraph, title: "Heart Rate", position: WidgetPosition(row: 0, column: 2), size: .medium),
            DashboardWidget(type: .transportControl, title: "Transport", position: WidgetPosition(row: 1, column: 0), size: .large),
            DashboardWidget(type: .deviceList, title: "Devices", position: WidgetPosition(row: 1, column: 2), size: .medium),
            DashboardWidget(type: .quickActions, title: "Quick Actions", position: WidgetPosition(row: 2, column: 0), size: .extraLarge)
        ]

        // Default groups
        groups = [
            ControlGroup(name: "Studio", icon: "🎙️", color: "#FF6B6B"),
            ControlGroup(name: "Living Room", icon: "🛋️", color: "#4ECDC4"),
            ControlGroup(name: "Meditation", icon: "🧘", color: "#55EFC4"),
            ControlGroup(name: "Performance", icon: "🎭", color: "#A29BFE")
        ]
    }

    // MARK: - Device Management

    /// Scan for available devices
    public func scanForDevices() async {
        isScanning = true
        lastError = nil

        // Simulate device discovery
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Add discovered devices (simulation)
        let discoveredDevices: [ConnectedDevice] = [
            ConnectedDevice(name: "Apple Watch", category: .biometrics, status: .connected,
                          manufacturer: "Apple", model: "Series 9", batteryLevel: 0.85,
                          capabilities: ["heartRate", "hrv", "activity"]),
            ConnectedDevice(name: "Hue Bridge", category: .smartHome, status: .connected,
                          manufacturer: "Philips", model: "Bridge v2", ipAddress: "192.168.1.100",
                          capabilities: ["lights", "scenes", "schedules"]),
            ConnectedDevice(name: "Ableton Push 3", category: .audio, status: .connected,
                          manufacturer: "Ableton", model: "Push 3",
                          capabilities: ["midi", "pads", "encoders", "display"]),
            ConnectedDevice(name: "Vision Pro", category: .vr, status: .paired,
                          manufacturer: "Apple", model: "Vision Pro", batteryLevel: 0.72,
                          capabilities: ["spatial", "handTracking", "eyeTracking"]),
            ConnectedDevice(name: "DJI Mini 4", category: .drones, status: .disconnected,
                          manufacturer: "DJI", model: "Mini 4 Pro", batteryLevel: 1.0,
                          capabilities: ["video4k", "gps", "followMe", "waypoints"]),
            ConnectedDevice(name: "Tesla Model S", category: .vehicles, status: .disconnected,
                          manufacturer: "Tesla", model: "Model S Plaid",
                          capabilities: ["audio", "climate", "navigation", "ambientLighting"])
        ]

        for device in discoveredDevices {
            if !devices.contains(where: { $0.name == device.name }) {
                devices.append(device)
            }
        }

        isScanning = false
    }

    /// Connect to a device
    public func connectDevice(_ device: ConnectedDevice) async -> Bool {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return false }

        devices[index].status = .connecting

        // Simulate connection
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        // 90% success rate simulation
        if Double.random(in: 0...1) < 0.9 {
            devices[index].status = .connected
            devices[index].lastSeen = Date()
            return true
        } else {
            devices[index].status = .error
            lastError = "Failed to connect to \(device.name)"
            return false
        }
    }

    /// Disconnect from a device
    public func disconnectDevice(_ device: ConnectedDevice) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index].status = .disconnected
    }

    /// Toggle device favorite
    public func toggleFavorite(_ device: ConnectedDevice) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index].isFavorite.toggle()
    }

    /// Remove device
    public func removeDevice(_ device: ConnectedDevice) {
        devices.removeAll { $0.id == device.id }
    }

    // MARK: - Group Management

    /// Create a new group
    public func createGroup(name: String, icon: String, deviceIds: [UUID]) {
        let group = ControlGroup(name: name, icon: icon, deviceIds: deviceIds)
        groups.append(group)
    }

    /// Add device to group
    public func addToGroup(deviceId: UUID, groupId: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        if !groups[index].deviceIds.contains(deviceId) {
            groups[index].deviceIds.append(deviceId)
        }
    }

    /// Remove device from group
    public func removeFromGroup(deviceId: UUID, groupId: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else { return }
        groups[index].deviceIds.removeAll { $0 == deviceId }
    }

    /// Get devices in group
    public func devicesInGroup(_ group: ControlGroup) -> [ConnectedDevice] {
        devices.filter { group.deviceIds.contains($0.id) }
    }

    // MARK: - Automation Management

    /// Create automation rule
    public func createAutomation(name: String, trigger: AutomationTrigger, actions: [AutomationAction]) {
        let rule = AutomationRule(name: name, trigger: trigger, actions: actions)
        automations.append(rule)
    }

    /// Enable/disable automation
    public func toggleAutomation(_ automation: AutomationRule) {
        guard let index = automations.firstIndex(where: { $0.id == automation.id }) else { return }
        automations[index].isEnabled.toggle()
    }

    /// Execute automation actions
    public func executeAutomation(_ automation: AutomationRule) async {
        guard let index = automations.firstIndex(where: { $0.id == automation.id }) else { return }

        for action in automation.actions {
            await executeAction(action)
        }

        automations[index].lastTriggered = Date()
    }

    private func executeAction(_ action: AutomationAction) async {
        switch action {
        case .setDeviceParameter(let deviceId, let parameter, let value):
            print("📝 Setting \(parameter) = \(value) on device \(deviceId)")
        case .toggleDevice(let deviceId, let on):
            print("🔌 \(on ? "Enabling" : "Disabling") device \(deviceId)")
        case .setLightColor(let deviceId, let hue, let sat, let brightness):
            print("💡 Light \(deviceId): H\(hue) S\(sat) B\(brightness)")
        case .playPreset(let name):
            state.currentPreset = name
            print("🎛️ Playing preset: \(name)")
        case .sendNotification(let message):
            print("📢 Notification: \(message)")
        case .startRecording:
            state.isRecording = true
        case .stopRecording:
            state.isRecording = false
        case .startStreaming(let platform):
            state.isStreaming = true
            print("📡 Streaming to \(platform)")
        case .stopStreaming:
            state.isStreaming = false
        case .runShortcut(let name):
            print("⚡ Running shortcut: \(name)")
        case .setVolume(let level):
            state.masterVolume = level
        case .setBPM(let bpm):
            state.globalBPM = bpm
        case .triggerEffect(let name):
            print("✨ Triggering effect: \(name)")
        }
    }

    // MARK: - Biometric Updates

    /// Update from biometric data
    public func updateBiometrics(heartRate: Int, hrvMs: Double, coherence: Double) {
        state.heartRate = heartRate
        state.hrvMs = hrvMs
        state.coherence = coherence

        // Check automation triggers
        for automation in activeAutomations {
            switch automation.trigger {
            case .hrvThreshold(let above, let below):
                if let a = above, hrvMs > a { Task { await executeAutomation(automation) } }
                if let b = below, hrvMs < b { Task { await executeAutomation(automation) } }
            case .heartRateThreshold(let above, let below):
                if let a = above, heartRate > a { Task { await executeAutomation(automation) } }
                if let b = below, heartRate < b { Task { await executeAutomation(automation) } }
            case .coherenceThreshold(let above, let below):
                if let a = above, coherence > a { Task { await executeAutomation(automation) } }
                if let b = below, coherence < b { Task { await executeAutomation(automation) } }
            default:
                break
            }
        }
    }

    // MARK: - Transport Controls

    /// Play/Pause toggle
    public func togglePlayback() {
        state.isPlaying.toggle()
    }

    /// Start recording
    public func startRecording() {
        state.isRecording = true
    }

    /// Stop recording
    public func stopRecording() {
        state.isRecording = false
    }

    /// Start streaming
    public func startStreaming() {
        state.isStreaming = true
    }

    /// Stop streaming
    public func stopStreaming() {
        state.isStreaming = false
    }

    /// Set master volume
    public func setMasterVolume(_ level: Float) {
        state.masterVolume = max(0, min(1, level))
    }

    /// Set BPM
    public func setBPM(_ bpm: Double) {
        state.globalBPM = max(20, min(300, bpm))
    }

    // MARK: - Widget Management

    /// Add widget
    public func addWidget(_ widget: DashboardWidget) {
        widgets.append(widget)
    }

    /// Remove widget
    public func removeWidget(_ widget: DashboardWidget) {
        widgets.removeAll { $0.id == widget.id }
    }

    /// Move widget
    public func moveWidget(_ widget: DashboardWidget, to position: WidgetPosition) {
        guard let index = widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        widgets[index].position = position
    }

    /// Resize widget
    public func resizeWidget(_ widget: DashboardWidget, to size: WidgetSize) {
        guard let index = widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        widgets[index].size = size
    }

    // MARK: - Quick Actions

    /// Execute quick action
    public func executeQuickAction(_ action: QuickAction) async {
        switch action {
        case .meditationMode:
            await activateMeditationMode()
        case .performanceMode:
            await activatePerformanceMode()
        case .sleepMode:
            await activateSleepMode()
        case .focusMode:
            await activateFocusMode()
        case .allLightsOff:
            await turnOffAllLights()
        case .allLightsOn:
            await turnOnAllLights()
        case .emergencyStop:
            await emergencyStop()
        }
    }

    public enum QuickAction: String, CaseIterable {
        case meditationMode = "Meditation Mode"
        case performanceMode = "Performance Mode"
        case sleepMode = "Sleep Mode"
        case focusMode = "Focus Mode"
        case allLightsOff = "All Lights Off"
        case allLightsOn = "All Lights On"
        case emergencyStop = "Emergency Stop"

        public var icon: String {
            switch self {
            case .meditationMode: return "🧘"
            case .performanceMode: return "🎭"
            case .sleepMode: return "😴"
            case .focusMode: return "🎯"
            case .allLightsOff: return "🌑"
            case .allLightsOn: return "☀️"
            case .emergencyStop: return "🛑"
            }
        }
    }

    private func activateMeditationMode() async {
        state.globalBPM = 60
        state.masterVolume = 0.4
        print("🧘 Meditation mode activated")
    }

    private func activatePerformanceMode() async {
        state.globalBPM = 120
        state.masterVolume = 0.9
        print("🎭 Performance mode activated")
    }

    private func activateSleepMode() async {
        state.globalBPM = 40
        state.masterVolume = 0.2
        state.isPlaying = false
        print("😴 Sleep mode activated")
    }

    private func activateFocusMode() async {
        state.globalBPM = 80
        state.masterVolume = 0.5
        print("🎯 Focus mode activated")
    }

    private func turnOffAllLights() async {
        let lights = devices.filter { $0.category == .lighting || $0.category == .smartHome }
        for light in lights {
            print("💡 Turning off: \(light.name)")
        }
    }

    private func turnOnAllLights() async {
        let lights = devices.filter { $0.category == .lighting || $0.category == .smartHome }
        for light in lights {
            print("💡 Turning on: \(light.name)")
        }
    }

    private func emergencyStop() async {
        state.isPlaying = false
        state.isRecording = false
        state.isStreaming = false
        state.masterMute = true
        print("🛑 EMERGENCY STOP - All systems halted")
    }

    // MARK: - Export/Import

    /// Export configuration
    public func exportConfiguration() -> Data? {
        let config = EchoboardConfiguration(
            devices: devices,
            groups: groups,
            automations: automations,
            widgets: widgets
        )
        return try? JSONEncoder().encode(config)
    }

    /// Import configuration
    public func importConfiguration(from data: Data) -> Bool {
        guard let config = try? JSONDecoder().decode(EchoboardConfiguration.self, from: data) else {
            return false
        }
        devices = config.devices
        groups = config.groups
        automations = config.automations
        widgets = config.widgets
        return true
    }
}

// MARK: - Configuration Export

private struct EchoboardConfiguration: Codable {
    var devices: [ConnectedDevice]
    var groups: [ControlGroup]
    var automations: [AutomationRule]
    var widgets: [DashboardWidget]
}

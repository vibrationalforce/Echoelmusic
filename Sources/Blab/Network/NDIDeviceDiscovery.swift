import Foundation
import Network
import Combine

/// NDI Device Discovery - Find NDI sources and receivers on the network
/// Uses mDNS/Bonjour for automatic device discovery
///
/// Features:
/// - Automatic discovery of NDI devices
/// - mDNS service browsing (_ndi._tcp)
/// - Real-time device list updates
/// - Connection status monitoring
///
/// Usage:
/// ```swift
/// let discovery = NDIDeviceDiscovery()
/// discovery.start()
/// discovery.$devices.sink { devices in
///     print("Found \(devices.count) NDI devices")
/// }
/// ```
@available(iOS 15.0, *)
public class NDIDeviceDiscovery: ObservableObject {

    // MARK: - Types

    public struct NDIDevice: Identifiable, Hashable {
        public let id: String
        public let name: String
        public let ipAddress: String
        public let port: UInt16
        public let groups: [String]
        public let isReceiver: Bool
        public let isSender: Bool

        public init(id: String, name: String, ipAddress: String, port: UInt16,
                    groups: [String] = [], isReceiver: Bool = false, isSender: Bool = true) {
            self.id = id
            self.name = name
            self.ipAddress = ipAddress
            self.port = port
            self.groups = groups
            self.isReceiver = isReceiver
            self.isSender = isSender
        }
    }

    // MARK: - Published Properties

    @Published public private(set) var devices: [NDIDevice] = []
    @Published public private(set) var isDiscovering: Bool = false

    // MARK: - Private Properties

    private var browser: NWBrowser?
    private var ndiFinderInstance: OpaquePointer?
    private let queue = DispatchQueue(label: "com.blab.ndi.discovery", qos: .utility)
    private var discoveryTimer: Timer?

    // MARK: - Initialization

    public init() {
        // Setup discovery
    }

    deinit {
        stop()
    }

    // MARK: - Discovery Control

    /// Start discovering NDI devices on the network
    public func start() {
        guard !isDiscovering else { return }

        isDiscovering = true

        #if NDI_SDK_AVAILABLE
        startNDIDiscovery()
        #else
        startMDNSDiscovery()
        #endif

        print("[NDI Discovery] Started")
    }

    /// Stop discovering NDI devices
    public func stop() {
        guard isDiscovering else { return }

        #if NDI_SDK_AVAILABLE
        stopNDIDiscovery()
        #else
        stopMDNSDiscovery()
        #endif

        isDiscovering = false
        print("[NDI Discovery] Stopped")
    }

    // MARK: - NDI SDK Discovery (when available)

    #if NDI_SDK_AVAILABLE
    private func startNDIDiscovery() {
        // Create NDI finder instance
        var finderCreate = NDIlib_find_create_t()
        finderCreate.show_local_sources = true
        finderCreate.p_groups = nil

        ndiFinderInstance = NDIlib_find_create_v2(&finderCreate)

        // Poll for sources on timer (30 Hz)
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.pollNDISources()
        }
    }

    private func stopNDIDiscovery() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil

        if let instance = ndiFinderInstance {
            NDIlib_find_destroy(instance)
            ndiFinderInstance = nil
        }
    }

    private func pollNDISources() {
        guard let instance = ndiFinderInstance else { return }

        var sourceCount: UInt32 = 0
        let sources = NDIlib_find_get_current_sources(instance, &sourceCount)

        guard let sources = sources, sourceCount > 0 else {
            DispatchQueue.main.async { [weak self] in
                self?.devices = []
            }
            return
        }

        var newDevices: [NDIDevice] = []

        for i in 0..<Int(sourceCount) {
            let source = sources[i]

            if let namePtr = source.p_ndi_name,
               let urlPtr = source.p_url_address {

                let name = String(cString: namePtr)
                let url = String(cString: urlPtr)

                // Parse IP and port from URL
                let (ip, port) = parseURL(url)

                let device = NDIDevice(
                    id: name,
                    name: name,
                    ipAddress: ip,
                    port: port,
                    groups: [],
                    isReceiver: false,
                    isSender: true
                )

                newDevices.append(device)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.devices = newDevices
        }
    }
    #endif

    // MARK: - mDNS Discovery (fallback)

    private func startMDNSDiscovery() {
        // Browse for _ndi._tcp service
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: "_ndi._tcp", domain: nil), using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("[NDI Discovery] mDNS browser ready")
            case .failed(let error):
                print("[NDI Discovery] ⚠️ mDNS browser failed: \(error)")
            default:
                break
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResults(results)
        }

        browser?.start(queue: queue)
    }

    private func stopMDNSDiscovery() {
        browser?.cancel()
        browser = nil
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var newDevices: [NDIDevice] = []

        for result in results {
            switch result.endpoint {
            case .service(let name, let type, let domain, let interface):
                // Resolve service to get IP address
                resolveService(name: name, type: type, domain: domain) { device in
                    if let device = device {
                        newDevices.append(device)
                    }
                }

            default:
                break
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.devices = newDevices
        }
    }

    private func resolveService(name: String, type: String, domain: String,
                                completion: @escaping (NDIDevice?) -> Void) {
        // Create connection to resolve endpoint
        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if case .hostPort(let host, let port) = connection.currentPath?.remoteEndpoint {
                    let ipAddress = "\(host)"
                    let device = NDIDevice(
                        id: name,
                        name: name,
                        ipAddress: ipAddress,
                        port: port.rawValue,
                        groups: [],
                        isReceiver: false,
                        isSender: true
                    )
                    completion(device)
                    connection.cancel()
                }
            case .failed:
                completion(nil)
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    // MARK: - Utilities

    private func parseURL(_ url: String) -> (ip: String, port: UInt16) {
        // Parse URL like "192.168.1.100:5960"
        let components = url.split(separator: ":")
        let ip = components.first.map(String.init) ?? "0.0.0.0"
        let port = components.count > 1 ? UInt16(components[1]) ?? 5960 : 5960
        return (ip, port)
    }

    // MARK: - Manual Device Addition

    /// Manually add an NDI device (useful when discovery doesn't work)
    public func addDevice(name: String, ipAddress: String, port: UInt16 = 5960) {
        let device = NDIDevice(
            id: "\(ipAddress):\(port)",
            name: name,
            ipAddress: ipAddress,
            port: port,
            groups: [],
            isReceiver: false,
            isSender: true
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.devices.contains(where: { $0.id == device.id }) {
                self.devices.append(device)
            }
        }

        print("[NDI Discovery] Manually added: \(name) at \(ipAddress):\(port)")
    }

    /// Remove a device from the list
    public func removeDevice(id: String) {
        DispatchQueue.main.async { [weak self] in
            self?.devices.removeAll { $0.id == id }
        }
    }

    /// Clear all devices
    public func clearDevices() {
        DispatchQueue.main.async { [weak self] in
            self?.devices = []
        }
    }
}

// MARK: - NDI SDK Stubs (when SDK not available)

#if !NDI_SDK_AVAILABLE

private struct NDIlib_find_create_t {
    var show_local_sources: Bool
    var p_groups: UnsafeMutablePointer<CChar>?
}

private struct NDIlib_source_t {
    var p_ndi_name: UnsafePointer<CChar>?
    var p_url_address: UnsafePointer<CChar>?
}

private func NDIlib_find_create_v2(_ settings: UnsafePointer<NDIlib_find_create_t>) -> OpaquePointer? {
    return nil
}

private func NDIlib_find_destroy(_ instance: OpaquePointer) {}

private func NDIlib_find_get_current_sources(_ instance: OpaquePointer, _ count: UnsafeMutablePointer<UInt32>) -> UnsafePointer<NDIlib_source_t>? {
    return nil
}

#endif

// AppleServicesIntegration.swift
// Echoelmusic - Ultimate Apple Ecosystem Integration
//
// Enterprise-Level Integration of ALL Apple Services
// Ralph Wiggum Lambda Loop Mode - Maximum Apple Integration
//
// Created: 2026-01-20

import Foundation
import SwiftUI
import Combine
import MapKit
import CoreLocation
import AuthenticationServices
import CloudKit
import StoreKit

#if canImport(WeatherKit)
import WeatherKit
#endif

/// Logger instance for Apple Services operations
private let log = Logger.shared

#if canImport(CallKit)
import CallKit
#endif

#if canImport(HomeKit)
import HomeKit
#endif

#if canImport(PassKit)
import PassKit
#endif

// MARK: - Apple Services Hub

/// Central hub for all Apple service integrations
/// Enterprise-grade, cross-platform within Apple ecosystem
@MainActor
public final class AppleServicesHub: ObservableObject {

    public static let shared = AppleServicesHub()

    // Sub-services
    @Published public private(set) var mapService: EchoelMapService
    @Published public private(set) var weatherService: EchoelWeatherService
    @Published public private(set) var callService: EchoelCallService
    @Published public private(set) var homeService: EchoelHomeService
    @Published public private(set) var walletService: EchoelWalletService
    @Published public private(set) var authService: EchoelAuthService

    // State
    @Published public var isFullyInitialized = false
    @Published public var availableServices: Set<AppleService> = []

    public enum AppleService: String, CaseIterable {
        case signInWithApple = "Sign in with Apple"
        case maps = "Apple Maps"
        case weather = "WeatherKit"
        case calls = "CallKit"
        case homeKit = "HomeKit"
        case wallet = "PassKit"
        case cloudKit = "CloudKit"
        case healthKit = "HealthKit"
        case sharePlay = "SharePlay"
        case storeKit = "StoreKit"
    }

    private init() {
        self.mapService = EchoelMapService()
        self.weatherService = EchoelWeatherService()
        self.callService = EchoelCallService()
        self.homeService = EchoelHomeService()
        self.walletService = EchoelWalletService()
        self.authService = EchoelAuthService()
    }

    /// Initialize all available Apple services
    public func initializeAllServices() async {
        // Check and initialize each service
        availableServices.insert(.signInWithApple)
        availableServices.insert(.maps)
        availableServices.insert(.cloudKit)
        availableServices.insert(.storeKit)

        #if canImport(WeatherKit)
        if await weatherService.checkAvailability() {
            availableServices.insert(.weather)
        }
        #endif

        #if canImport(CallKit)
        availableServices.insert(.calls)
        #endif

        #if canImport(HomeKit)
        if await homeService.checkAvailability() {
            availableServices.insert(.homeKit)
        }
        #endif

        #if canImport(PassKit) && !os(tvOS)
        if PKPassLibrary.isPassLibraryAvailable() {
            availableServices.insert(.wallet)
        }
        #endif

        isFullyInitialized = true

        log.info("Apple Services Hub initialized: \(availableServices.count) services available", category: .system)
    }
}

// MARK: - Map Service (Location Sharing, Events, Directions)

/// Apple Maps integration for Echoelmusic
/// - Location sharing in collaboration sessions
/// - Event venue mapping
/// - Directions to meditation spots, events
/// - Nearby Echoelmusic users discovery
@MainActor
public final class EchoelMapService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published public var currentLocation: CLLocationCoordinate2D?
    @Published public var nearbyUsers: [EchoelUser] = []
    @Published public var nearbyEvents: [EchoelEvent] = []
    @Published public var selectedVenue: EchoelVenue?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()

    public struct EchoelUser: Identifiable, Codable {
        public let id: UUID
        public let displayName: String
        public let coordinate: CLLocationCoordinate2D
        public let currentSession: String?
        public let coherenceLevel: Double
        public let isLive: Bool
        public let avatarURL: URL?

        enum CodingKeys: String, CodingKey {
            case id, displayName, latitude, longitude, currentSession, coherenceLevel, isLive, avatarURL
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            displayName = try container.decode(String.self, forKey: .displayName)
            let lat = try container.decode(Double.self, forKey: .latitude)
            let lon = try container.decode(Double.self, forKey: .longitude)
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            currentSession = try container.decodeIfPresent(String.self, forKey: .currentSession)
            coherenceLevel = try container.decode(Double.self, forKey: .coherenceLevel)
            isLive = try container.decode(Bool.self, forKey: .isLive)
            avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(displayName, forKey: .displayName)
            try container.encode(coordinate.latitude, forKey: .latitude)
            try container.encode(coordinate.longitude, forKey: .longitude)
            try container.encodeIfPresent(currentSession, forKey: .currentSession)
            try container.encode(coherenceLevel, forKey: .coherenceLevel)
            try container.encode(isLive, forKey: .isLive)
            try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        }

        public init(id: UUID, displayName: String, coordinate: CLLocationCoordinate2D,
                    currentSession: String?, coherenceLevel: Double, isLive: Bool, avatarURL: URL?) {
            self.id = id
            self.displayName = displayName
            self.coordinate = coordinate
            self.currentSession = currentSession
            self.coherenceLevel = coherenceLevel
            self.isLive = isLive
            self.avatarURL = avatarURL
        }
    }

    public struct EchoelEvent: Identifiable {
        public let id: UUID
        public let name: String
        public let description: String
        public let coordinate: CLLocationCoordinate2D
        public let venue: EchoelVenue?
        public let startDate: Date
        public let endDate: Date
        public let participantCount: Int
        public let maxParticipants: Int
        public let eventType: EventType
        public let isVirtual: Bool
        public let hostName: String
        public let imageURL: URL?

        public enum EventType: String, CaseIterable {
            case meditation = "Meditation"
            case breathwork = "Breathwork"
            case soundBath = "Sound Bath"
            case groupCoherence = "Group Coherence"
            case workshop = "Workshop"
            case concert = "Bio-Reactive Concert"
            case retreat = "Retreat"
        }
    }

    public struct EchoelVenue: Identifiable {
        public let id: UUID
        public let name: String
        public let address: String
        public let coordinate: CLLocationCoordinate2D
        public let venueType: VenueType
        public let rating: Double
        public let imageURL: URL?
        public let amenities: [String]
        public let capacity: Int

        public enum VenueType: String, CaseIterable {
            case studio = "Meditation Studio"
            case spa = "Wellness Spa"
            case outdoors = "Outdoor Space"
            case yogaStudio = "Yoga Studio"
            case retreatCenter = "Retreat Center"
            case home = "Private Home"
            case virtual = "Virtual"
        }
    }

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - Location Authorization

    public func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    public func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    public func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    public func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Location Sharing

    /// Share current location in a collaboration session
    public func shareLocation(in sessionId: UUID) async throws -> LocationShareResult {
        guard let location = currentLocation else {
            throw MapServiceError.locationNotAvailable
        }

        // Create shareable location message
        let shareMessage = LocationShareMessage(
            userId: UUID(), // Current user ID
            coordinate: location,
            timestamp: Date(),
            sessionId: sessionId,
            message: "Mein Standort"
        )

        // In production: Send to collaboration server
        // Note: Location coordinates redacted from logs for privacy

        return LocationShareResult(
            success: true,
            shareMessage: shareMessage,
            expiresAt: Date().addingTimeInterval(3600) // 1 hour
        )
    }

    public struct LocationShareMessage: Codable {
        public let userId: UUID
        public let coordinate: CLLocationCoordinate2D
        public let timestamp: Date
        public let sessionId: UUID
        public let message: String

        enum CodingKeys: String, CodingKey {
            case userId, latitude, longitude, timestamp, sessionId, message
        }

        public init(userId: UUID, coordinate: CLLocationCoordinate2D, timestamp: Date, sessionId: UUID, message: String) {
            self.userId = userId
            self.coordinate = coordinate
            self.timestamp = timestamp
            self.sessionId = sessionId
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            userId = try container.decode(UUID.self, forKey: .userId)
            let lat = try container.decode(Double.self, forKey: .latitude)
            let lon = try container.decode(Double.self, forKey: .longitude)
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            timestamp = try container.decode(Date.self, forKey: .timestamp)
            sessionId = try container.decode(UUID.self, forKey: .sessionId)
            message = try container.decode(String.self, forKey: .message)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(userId, forKey: .userId)
            try container.encode(coordinate.latitude, forKey: .latitude)
            try container.encode(coordinate.longitude, forKey: .longitude)
            try container.encode(timestamp, forKey: .timestamp)
            try container.encode(sessionId, forKey: .sessionId)
            try container.encode(message, forKey: .message)
        }
    }

    public struct LocationShareResult {
        public let success: Bool
        public let shareMessage: LocationShareMessage
        public let expiresAt: Date
    }

    // MARK: - Directions

    /// Get directions to a venue or event
    public func getDirections(to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .automobile) async throws -> MKRoute {
        guard let origin = currentLocation else {
            throw MapServiceError.locationNotAvailable
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw MapServiceError.noRouteFound
        }

        return route
    }

    /// Open Apple Maps with directions
    public func openInMaps(destination: CLLocationCoordinate2D, name: String) {
        let placemark = MKPlacemark(coordinate: destination)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    // MARK: - Nearby Discovery

    /// Find nearby Echoelmusic users
    public func discoverNearbyUsers(radius: CLLocationDistance = 5000) async throws -> [EchoelUser] {
        guard let location = currentLocation else {
            throw MapServiceError.locationNotAvailable
        }

        // In production: Query server for nearby users
        // For now: Return mock data
        let mockUsers: [EchoelUser] = [
            EchoelUser(
                id: UUID(),
                displayName: "MeditationMaster",
                coordinate: CLLocationCoordinate2D(
                    latitude: location.latitude + 0.01,
                    longitude: location.longitude + 0.01
                ),
                currentSession: "Deep Coherence",
                coherenceLevel: 0.85,
                isLive: true,
                avatarURL: nil
            ),
            EchoelUser(
                id: UUID(),
                displayName: "BreathworkPro",
                coordinate: CLLocationCoordinate2D(
                    latitude: location.latitude - 0.005,
                    longitude: location.longitude + 0.008
                ),
                currentSession: "Box Breathing",
                coherenceLevel: 0.72,
                isLive: true,
                avatarURL: nil
            )
        ]

        nearbyUsers = mockUsers
        return mockUsers
    }

    /// Find nearby events
    public func discoverNearbyEvents(radius: CLLocationDistance = 50000) async throws -> [EchoelEvent] {
        guard let location = currentLocation else {
            throw MapServiceError.locationNotAvailable
        }

        // In production: Query server for nearby events
        let mockEvents: [EchoelEvent] = [
            EchoelEvent(
                id: UUID(),
                name: "Sonntags-Meditation",
                description: "Wöchentliche Gruppen-Meditation mit HRV-Sync",
                coordinate: CLLocationCoordinate2D(
                    latitude: location.latitude + 0.02,
                    longitude: location.longitude - 0.01
                ),
                venue: nil,
                startDate: Date().addingTimeInterval(86400),
                endDate: Date().addingTimeInterval(86400 + 3600),
                participantCount: 12,
                maxParticipants: 30,
                eventType: .meditation,
                isVirtual: false,
                hostName: "Echoelmusic Community",
                imageURL: nil
            )
        ]

        nearbyEvents = mockEvents
        return mockEvents
    }

    public enum MapServiceError: LocalizedError {
        case locationNotAvailable
        case noRouteFound
        case authorizationDenied

        public var errorDescription: String? {
            switch self {
            case .locationNotAvailable:
                return "Standort nicht verfügbar. Bitte Standortdienste aktivieren."
            case .noRouteFound:
                return "Keine Route gefunden."
            case .authorizationDenied:
                return "Standortzugriff verweigert."
            }
        }
    }
}

// MARK: - Weather Service (Circadian Features)

/// WeatherKit integration for bio-reactive weather awareness
@MainActor
public final class EchoelWeatherService: ObservableObject {

    @Published public var currentWeather: WeatherData?
    @Published public var sunriseTime: Date?
    @Published public var sunsetTime: Date?
    @Published public var moonPhase: MoonPhase = .new
    @Published public var circadianRecommendation: CircadianRecommendation?

    public struct WeatherData {
        public let temperature: Double
        public let humidity: Double
        public let condition: WeatherCondition
        public let uvIndex: Int
        public let pressure: Double
        public let windSpeed: Double

        public enum WeatherCondition: String {
            case clear = "Klar"
            case cloudy = "Bewölkt"
            case rainy = "Regnerisch"
            case stormy = "Stürmisch"
            case snowy = "Schnee"
            case foggy = "Neblig"
        }
    }

    public enum MoonPhase: String, CaseIterable {
        case new = "Neumond"
        case waxingCrescent = "Zunehmende Sichel"
        case firstQuarter = "Erstes Viertel"
        case waxingGibbous = "Zunehmender Mond"
        case full = "Vollmond"
        case waningGibbous = "Abnehmender Mond"
        case lastQuarter = "Letztes Viertel"
        case waningCrescent = "Abnehmende Sichel"
    }

    public struct CircadianRecommendation {
        public let sessionType: RecommendedSession
        public let lightingPreset: String
        public let audioPreset: String
        public let reason: String

        public enum RecommendedSession: String {
            case energizing = "Energizing Morning"
            case focus = "Deep Focus"
            case relaxation = "Afternoon Relaxation"
            case windDown = "Evening Wind-Down"
            case sleep = "Sleep Preparation"
            case fullMoon = "Full Moon Meditation"
        }
    }

    public func checkAvailability() async -> Bool {
        #if canImport(WeatherKit)
        return true
        #else
        return false
        #endif
    }

    /// Fetch weather for location
    public func fetchWeather(for coordinate: CLLocationCoordinate2D) async throws {
        #if canImport(WeatherKit)
        let weatherService = WeatherService.shared
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let weather = try await weatherService.weather(for: location)

            currentWeather = WeatherData(
                temperature: weather.currentWeather.temperature.value,
                humidity: weather.currentWeather.humidity * 100,
                condition: mapCondition(weather.currentWeather.condition),
                uvIndex: weather.currentWeather.uvIndex.value,
                pressure: weather.currentWeather.pressure.value,
                windSpeed: weather.currentWeather.wind.speed.value
            )

            // Get sun events
            if let dailyForecast = weather.dailyForecast.first {
                sunriseTime = dailyForecast.sun.sunrise
                sunsetTime = dailyForecast.sun.sunset
                moonPhase = mapMoonPhase(dailyForecast.moon.phase)
            }

            // Generate circadian recommendation
            circadianRecommendation = generateCircadianRecommendation()

        } catch {
            log.error("WeatherKit error: \(error)", category: .system)
            throw error
        }
        #else
        // Fallback for simulators or unsupported platforms
        currentWeather = WeatherData(
            temperature: 18.0,
            humidity: 65.0,
            condition: .clear,
            uvIndex: 3,
            pressure: 1013.0,
            windSpeed: 12.0
        )

        let now = Date()
        let calendar = Calendar.current
        sunriseTime = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: now)
        sunsetTime = calendar.date(bySettingHour: 17, minute: 45, second: 0, of: now)

        circadianRecommendation = generateCircadianRecommendation()
        #endif
    }

    #if canImport(WeatherKit)
    private func mapCondition(_ condition: WeatherCondition) -> WeatherData.WeatherCondition {
        switch condition {
        case .clear, .mostlyClear:
            return .clear
        case .cloudy, .mostlyCloudy, .partlyCloudy:
            return .cloudy
        case .rain, .drizzle, .heavyRain:
            return .rainy
        case .snow, .heavySnow, .sleet:
            return .snowy
        case .foggy, .haze:
            return .foggy
        case .thunderstorms, .tropicalStorm:
            return .stormy
        default:
            return .clear
        }
    }

    private func mapMoonPhase(_ phase: MoonPhase) -> MoonPhase {
        switch phase {
        case .new:
            return .new
        case .waxingCrescent:
            return .waxingCrescent
        case .firstQuarter:
            return .firstQuarter
        case .waxingGibbous:
            return .waxingGibbous
        case .full:
            return .full
        case .waningGibbous:
            return .waningGibbous
        case .lastQuarter:
            return .lastQuarter
        case .waningCrescent:
            return .waningCrescent
        @unknown default:
            return .new
        }
    }
    #endif

    private func generateCircadianRecommendation() -> CircadianRecommendation {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<9:
            return CircadianRecommendation(
                sessionType: .energizing,
                lightingPreset: "Sunrise Warm",
                audioPreset: "Morning Awakening",
                reason: "Morgenzeit - Aktiviere deinen Körper mit energetisierenden Frequenzen"
            )
        case 9..<12:
            return CircadianRecommendation(
                sessionType: .focus,
                lightingPreset: "Bright Focus",
                audioPreset: "Beta Focus",
                reason: "Vormittag - Optimale Zeit für konzentrierte Arbeit"
            )
        case 12..<15:
            return CircadianRecommendation(
                sessionType: .relaxation,
                lightingPreset: "Neutral White",
                audioPreset: "Alpha Relaxation",
                reason: "Nachmittag - Kurze Entspannung für neue Energie"
            )
        case 15..<18:
            return CircadianRecommendation(
                sessionType: .focus,
                lightingPreset: "Warm Focus",
                audioPreset: "Theta Creativity",
                reason: "Spätnachmittag - Kreative Phase nutzen"
            )
        case 18..<21:
            return CircadianRecommendation(
                sessionType: .windDown,
                lightingPreset: "Sunset Orange",
                audioPreset: "Evening Calm",
                reason: "Abend - Melatonin-Produktion unterstützen"
            )
        default:
            return CircadianRecommendation(
                sessionType: .sleep,
                lightingPreset: "Night Red",
                audioPreset: "Delta Sleep",
                reason: "Nachtzeit - Tiefe Entspannung und Schlafvorbereitung"
            )
        }
    }
}

// MARK: - Call Service (Audio Collaboration)

/// CallKit integration for audio collaboration sessions
@MainActor
public final class EchoelCallService: NSObject, ObservableObject {

    @Published public var isInCall = false
    @Published public var currentCall: EchoelCall?
    @Published public var callHistory: [EchoelCall] = []

    #if canImport(CallKit) && !os(tvOS) && !os(watchOS)
    private var callController: CXCallController?
    private var provider: CXProvider?
    #endif

    public struct EchoelCall: Identifiable {
        public let id: UUID
        public let sessionId: UUID
        public let sessionName: String
        public let participants: [Participant]
        public let startTime: Date
        public var endTime: Date?
        public let callType: CallType

        public struct Participant: Identifiable {
            public let id: UUID
            public let displayName: String
            public let isMuted: Bool
            public let coherenceLevel: Double
        }

        public enum CallType: String {
            case meditation = "Meditation"
            case collaboration = "Collaboration"
            case workshop = "Workshop"
            case concert = "Concert"
        }
    }

    public override init() {
        super.init()
        #if canImport(CallKit) && !os(tvOS) && !os(watchOS)
        setupCallKit()
        #endif
    }

    #if canImport(CallKit) && !os(tvOS) && !os(watchOS)
    private func setupCallKit() {
        let configuration = CXProviderConfiguration()
        configuration.localizedName = "Echoelmusic"
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 50 // Group sessions
        configuration.supportedHandleTypes = [.generic]
        configuration.iconTemplateImageData = nil // Add app icon

        provider = CXProvider(configuration: configuration)
        provider?.setDelegate(self, queue: nil)
        callController = CXCallController()
    }

    /// Start an audio collaboration session
    public func startSession(name: String, type: EchoelCall.CallType) async throws -> EchoelCall {
        let callId = UUID()
        let sessionId = UUID()

        let call = EchoelCall(
            id: callId,
            sessionId: sessionId,
            sessionName: name,
            participants: [],
            startTime: Date(),
            endTime: nil,
            callType: type
        )

        // Report to CallKit
        let handle = CXHandle(type: .generic, value: sessionId.uuidString)
        let startCallAction = CXStartCallAction(call: callId, handle: handle)
        startCallAction.isVideo = false

        let transaction = CXTransaction(action: startCallAction)
        try await callController?.request(transaction)

        currentCall = call
        isInCall = true

        return call
    }

    /// End current session
    public func endSession() async throws {
        guard let call = currentCall else { return }

        let endCallAction = CXEndCallAction(call: call.id)
        let transaction = CXTransaction(action: endCallAction)
        try await callController?.request(transaction)

        var finishedCall = call
        finishedCall.endTime = Date()
        callHistory.append(finishedCall)

        currentCall = nil
        isInCall = false
    }
    #else
    public func startSession(name: String, type: EchoelCall.CallType) async throws -> EchoelCall {
        let call = EchoelCall(
            id: UUID(),
            sessionId: UUID(),
            sessionName: name,
            participants: [],
            startTime: Date(),
            endTime: nil,
            callType: type
        )
        currentCall = call
        isInCall = true
        return call
    }

    public func endSession() async throws {
        if var call = currentCall {
            call.endTime = Date()
            callHistory.append(call)
        }
        currentCall = nil
        isInCall = false
    }
    #endif
}

#if canImport(CallKit) && !os(tvOS) && !os(watchOS)
extension EchoelCallService: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        isInCall = false
        currentCall = nil
    }

    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
    }
}
#endif

// MARK: - Home Service (Smart Home Integration)

/// HomeKit integration for ambient environment control
@MainActor
public final class EchoelHomeService: NSObject, ObservableObject {

    @Published public var isAvailable = false
    @Published public var homes: [SmartHome] = []
    @Published public var lights: [SmartLight] = []
    @Published public var currentScene: HomeScene?

    #if canImport(HomeKit) && !os(tvOS)
    private var homeManager: HMHomeManager?
    #endif

    public struct SmartHome: Identifiable {
        public let id: UUID
        public let name: String
        public let rooms: [SmartRoom]
    }

    public struct SmartRoom: Identifiable {
        public let id: UUID
        public let name: String
        public let accessories: [SmartAccessory]
    }

    public struct SmartAccessory: Identifiable {
        public let id: UUID
        public let name: String
        public let type: AccessoryType
        public var isReachable: Bool

        public enum AccessoryType: String {
            case light = "Licht"
            case colorLight = "Farblicht"
            case speaker = "Lautsprecher"
            case thermostat = "Thermostat"
            case blind = "Jalousie"
        }
    }

    public struct SmartLight: Identifiable {
        public let id: UUID
        public let name: String
        public var isOn: Bool
        public var brightness: Double // 0-100
        public var hue: Double? // 0-360
        public var saturation: Double? // 0-100
    }

    public struct HomeScene: Identifiable {
        public let id: UUID
        public let name: String
        public let preset: ScenePreset

        public enum ScenePreset: String, CaseIterable {
            case meditation = "Meditation"
            case energize = "Energize"
            case focus = "Focus"
            case relax = "Relax"
            case sleep = "Sleep"
            case concert = "Concert Mode"
            case custom = "Custom"
        }
    }

    public func checkAvailability() async -> Bool {
        #if canImport(HomeKit) && !os(tvOS)
        return true
        #else
        return false
        #endif
    }

    #if canImport(HomeKit) && !os(tvOS)
    public func initialize() {
        homeManager = HMHomeManager()
        homeManager?.delegate = self
    }

    /// Sync lights with bio-reactive session
    public func syncWithSession(coherence: Double, heartRate: Double) async {
        // Map coherence to light settings
        let brightness = min(100, max(20, coherence * 80 + 20))

        // High coherence = warm, calm colors
        // Low coherence = cooler, more neutral
        let hue: Double = coherence > 0.7 ? 30 : 200 // Orange vs Blue
        let saturation = coherence * 50 + 30

        // Update all lights
        for light in lights {
            await setLight(id: light.id, brightness: brightness, hue: hue, saturation: saturation)
        }
    }

    public func setLight(id: UUID, brightness: Double, hue: Double? = nil, saturation: Double? = nil) async {
        // In production: Update via HomeKit API
        if let index = lights.firstIndex(where: { $0.id == id }) {
            lights[index].brightness = brightness
            lights[index].hue = hue
            lights[index].saturation = saturation
        }
    }

    /// Apply a preset scene
    public func applyScene(_ preset: HomeScene.ScenePreset) async {
        let scene = HomeScene(id: UUID(), name: preset.rawValue, preset: preset)
        currentScene = scene

        switch preset {
        case .meditation:
            for i in lights.indices {
                lights[i].brightness = 30
                lights[i].hue = 30 // Warm orange
                lights[i].saturation = 60
            }
        case .energize:
            for i in lights.indices {
                lights[i].brightness = 100
                lights[i].hue = 60 // Bright yellow
                lights[i].saturation = 80
            }
        case .focus:
            for i in lights.indices {
                lights[i].brightness = 80
                lights[i].hue = 200 // Cool blue
                lights[i].saturation = 30
            }
        case .relax:
            for i in lights.indices {
                lights[i].brightness = 50
                lights[i].hue = 280 // Purple
                lights[i].saturation = 40
            }
        case .sleep:
            for i in lights.indices {
                lights[i].brightness = 10
                lights[i].hue = 10 // Deep red
                lights[i].saturation = 90
            }
        case .concert:
            // Dynamic - handled by bio-reactive engine
            break
        case .custom:
            break
        }
    }
    #else
    public func initialize() {
        // Not available
    }

    public func syncWithSession(coherence: Double, heartRate: Double) async {
        // Not available
    }

    public func applyScene(_ preset: HomeScene.ScenePreset) async {
        // Not available
    }
    #endif
}

#if canImport(HomeKit) && !os(tvOS)
extension EchoelHomeService: HMHomeManagerDelegate {
    public func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        homes = manager.homes.map { home in
            SmartHome(
                id: UUID(),
                name: home.name,
                rooms: home.rooms.map { room in
                    SmartRoom(
                        id: UUID(),
                        name: room.name,
                        accessories: room.accessories.map { accessory in
                            SmartAccessory(
                                id: UUID(),
                                name: accessory.name,
                                type: .light, // Simplified
                                isReachable: accessory.isReachable
                            )
                        }
                    )
                }
            )
        }
        isAvailable = !homes.isEmpty
    }
}
#endif

// MARK: - Wallet Service (Event Tickets)

/// PassKit integration for Echoelmusic event tickets
@MainActor
public final class EchoelWalletService: ObservableObject {

    @Published public var passes: [EchoelPass] = []
    @Published public var isWalletAvailable = false

    public struct EchoelPass: Identifiable {
        public let id: UUID
        public let passType: PassType
        public let eventName: String
        public let eventDate: Date
        public let venueName: String
        public let ticketNumber: String
        public let qrCodeData: Data?

        public enum PassType: String {
            case eventTicket = "Event Ticket"
            case membershipCard = "Membership"
            case giftCard = "Gift Card"
            case coupon = "Coupon"
        }
    }

    public init() {
        #if canImport(PassKit) && !os(tvOS)
        isWalletAvailable = PKPassLibrary.isPassLibraryAvailable()
        #else
        isWalletAvailable = false
        #endif
    }

    #if canImport(PassKit) && !os(tvOS)
    /// Add event ticket to Apple Wallet
    public func addEventTicket(event: EchoelMapService.EchoelEvent) async throws -> EchoelPass {
        // In production: Generate .pkpass file from server
        let pass = EchoelPass(
            id: UUID(),
            passType: .eventTicket,
            eventName: event.name,
            eventDate: event.startDate,
            venueName: event.venue?.name ?? "Virtual",
            ticketNumber: generateTicketNumber(),
            qrCodeData: nil
        )

        passes.append(pass)
        return pass
    }

    /// Create membership card
    public func createMembershipCard(tier: String) async throws -> EchoelPass {
        let pass = EchoelPass(
            id: UUID(),
            passType: .membershipCard,
            eventName: "Echoelmusic \(tier)",
            eventDate: Date().addingTimeInterval(365 * 24 * 3600), // 1 year
            venueName: "Echoelmusic",
            ticketNumber: generateMemberNumber(),
            qrCodeData: nil
        )

        passes.append(pass)
        return pass
    }

    private func generateTicketNumber() -> String {
        "ECH-\(Int.random(in: 100000...999999))"
    }

    private func generateMemberNumber() -> String {
        "MEM-\(Int.random(in: 10000000...99999999))"
    }
    #endif
}

// MARK: - Auth Service (Sign in with Apple)

/// Sign in with Apple integration
@MainActor
public final class EchoelAuthService: NSObject, ObservableObject {

    @Published public var isAuthenticated = false
    @Published public var currentUser: AppleUser?
    @Published public var authError: AuthError?

    public struct AppleUser: Codable {
        public let userId: String
        public let email: String?
        public let fullName: PersonNameComponents?
        public let isPrivateEmail: Bool
        public let authorizationDate: Date

        public var displayName: String {
            if let name = fullName {
                return PersonNameComponentsFormatter().string(from: name)
            }
            return email ?? "Echoelmusic User"
        }
    }

    public enum AuthError: LocalizedError {
        case cancelled
        case failed(Error)
        case invalidCredentials
        case notAvailable

        public var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Anmeldung abgebrochen"
            case .failed(let error):
                return "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
            case .invalidCredentials:
                return "Ungültige Anmeldedaten"
            case .notAvailable:
                return "Sign in with Apple nicht verfügbar"
            }
        }
    }

    /// Sign in with Apple
    public func signInWithApple() async throws -> AppleUser {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let result = try await performAuthorization(request: request)

        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredentials
        }

        let user = AppleUser(
            userId: appleIDCredential.user,
            email: appleIDCredential.email,
            fullName: appleIDCredential.fullName,
            isPrivateEmail: appleIDCredential.email?.contains("privaterelay") ?? false,
            authorizationDate: Date()
        )

        currentUser = user
        isAuthenticated = true

        // Save to Keychain
        saveUserToKeychain(user)

        return user
    }

    /// Check existing authorization
    public func checkExistingAuthorization() async {
        guard let savedUser = loadUserFromKeychain() else { return }

        let provider = ASAuthorizationAppleIDProvider()
        let state = try? await provider.credentialState(forUserID: savedUser.userId)

        if state == .authorized {
            currentUser = savedUser
            isAuthenticated = true
        } else {
            // Clear invalid session
            clearUserFromKeychain()
        }
    }

    /// Sign out
    public func signOut() {
        currentUser = nil
        isAuthenticated = false
        clearUserFromKeychain()
    }

    // MARK: - Private Helpers

    private func performAuthorization(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AuthorizationDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.performRequests()

            // Keep delegate alive
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private func saveUserToKeychain(_ user: AppleUser) {
        guard let data = try? JSONEncoder().encode(user) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "echoelmusic_apple_user",
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadUserFromKeychain() -> AppleUser? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "echoelmusic_apple_user",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let user = try? JSONDecoder().decode(AppleUser.self, from: data) else {
            return nil
        }

        return user
    }

    private func clearUserFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "echoelmusic_apple_user"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// Authorization Delegate
private class AuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate {
    let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}

// MARK: - SwiftUI Views

/// Sign in with Apple Button
public struct SignInWithAppleButton: View {
    let onCompletion: (Result<EchoelAuthService.AppleUser, Error>) -> Void

    @StateObject private var authService = EchoelAuthService()

    public init(onCompletion: @escaping (Result<EchoelAuthService.AppleUser, Error>) -> Void) {
        self.onCompletion = onCompletion
    }

    public var body: some View {
        SignInWithAppleButtonView()
            .frame(height: 50)
            .onTapGesture {
                Task {
                    do {
                        let user = try await authService.signInWithApple()
                        onCompletion(.success(user))
                    } catch {
                        onCompletion(.failure(error))
                    }
                }
            }
    }
}

struct SignInWithAppleButtonView: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        ASAuthorizationAppleIDButton(type: .signIn, style: .black)
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}

/// Map View for nearby users and events
public struct EchoelMapView: View {
    @StateObject private var mapService = EchoelMapService()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405), // Berlin
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    public init() {}

    public var body: some View {
        Map(coordinateRegion: $region, annotationItems: mapService.nearbyUsers) { user in
            MapAnnotation(coordinate: user.coordinate) {
                VStack {
                    Image(systemName: user.isLive ? "waveform.circle.fill" : "person.circle.fill")
                        .font(.title)
                        .foregroundColor(user.isLive ? .green : .blue)
                    Text(user.displayName)
                        .font(.caption)
                }
            }
        }
        .onAppear {
            mapService.requestLocationAuthorization()
            Task {
                try? await mapService.discoverNearbyUsers()
            }
        }
    }
}

/// Weather-aware session recommendation view
public struct CircadianRecommendationView: View {
    @StateObject private var weatherService = EchoelWeatherService()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let recommendation = weatherService.circadianRecommendation {
                HStack {
                    Image(systemName: iconForSession(recommendation.sessionType))
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading) {
                        Text(recommendation.sessionType.rawValue)
                            .font(.headline)
                        Text(recommendation.reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Label(recommendation.lightingPreset, systemImage: "lightbulb.fill")
                    Spacer()
                    Label(recommendation.audioPreset, systemImage: "waveform")
                }
                .font(.subheadline)
            }

            if let weather = weatherService.currentWeather {
                HStack {
                    Text("\(Int(weather.temperature))°C")
                    Text(weather.condition.rawValue)
                    if let sunrise = weatherService.sunriseTime {
                        Text("☀️ \(sunrise, style: .time)")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private func iconForSession(_ type: EchoelWeatherService.CircadianRecommendation.RecommendedSession) -> String {
        switch type {
        case .energizing: return "sun.max.fill"
        case .focus: return "brain.head.profile"
        case .relaxation: return "leaf.fill"
        case .windDown: return "sunset.fill"
        case .sleep: return "moon.stars.fill"
        case .fullMoon: return "moon.fill"
        }
    }
}

// MARK: - Extension for CLLocationCoordinate2D Codable

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

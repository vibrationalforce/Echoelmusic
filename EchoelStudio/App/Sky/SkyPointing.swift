import EchoelCore
import Foundation
import Observation
import Synchronization
import os
import CoreLocation
import CoreMotion

/// Where the phone points and where it stands, for the sky view (sky source S2, founder
/// 2026-10-31). No setting for the musician: the view opens, the place is found once, and the
/// phone's attitude turns the sky; without the sensors a finger turns it.
///
/// - Attitude: CoreMotion device motion against true north (magnetic north where the phone
///   offers no true-north frame), 60 Hz. Pull-based: the drawing leaf calls `sample()` once per
///   frame and reads the motion manager's newest value — no callback, no actor hop per sample
///   (the 10.76.48 lesson). The vectors glide, so the picture does not tremble.
/// - Place: CoreLocation "when in use", reduced accuracy, ONE fix — the sky needs the town, not the
///   street. The fix is remembered rounded to 0.1° (about 10 km) so the next night works without
///   asking; a refused permission falls back to the remembered place or one the musician picks.
///   Nothing about the place leaves the device.
///
/// Observed properties change only when the mode or the place changes, so a view may read them
/// (Law 6). The pointing itself is not observable: it moves every frame and only the drawing leaf
/// reads it, in its own loop.
@MainActor
@Observable
final class SkyPointing {
    enum Steering: Equatable {
        /// The phone's attitude turns the sky.
        case sensors
        /// A finger turns it: no motion sensors, or the musician dragged.
        case finger
    }

    enum PlaceSource: Equatable {
        case located
        case remembered
        case chosen(String)
        /// Nothing yet: the view shows where it is looking from and asks for a place.
        case none
    }

    /// A few reference places for a musician who declines the location permission.
    nonisolated static let places: [(name: String, latitude: Double, longitude: Double)] = [
        ("Hamburg", 53.55, 9.99), ("Berlin", 52.52, 13.40), ("London", 51.51, -0.13),
        ("Paris", 48.86, 2.35), ("Barcelona", 41.39, 2.17), ("New York", 40.71, -74.01),
        ("Los Angeles", 34.05, -118.24), ("Mexico City", 19.43, -99.13), ("São Paulo", -23.55, -46.63),
        ("Cape Town", -33.92, 18.42), ("Bangkok", 13.76, 100.50), ("Tokyo", 35.68, 139.69),
        ("Sydney", -33.87, 151.21),
    ]

    nonisolated static let latitudeKey = "sky.place.latitude"
    nonisolated static let longitudeKey = "sky.place.longitude"
    /// How far one frame moves the shown direction towards the measured one (60 Hz): ~0.1 s to
    /// settle, enough to take out tremor, short enough not to lag a turn.
    nonisolated static let glidePerFrame = 0.25

    private(set) var steering: Steering = .finger
    private(set) var placeSource: PlaceSource = .none
    private(set) var latitude: Double?
    private(set) var longitude: Double?
    /// True while the location permission is refused or restricted.
    private(set) var locationDenied = false

    /// The direction the view looks, east · north · up, and the screen's up. Not observed.
    @ObservationIgnored private(set) var forward = SkyVector(Sky.Horizontal(altitude: 30, azimuth: 180))
    @ObservationIgnored private(set) var up = SkyVector(x: 0, y: 0, z: 1)
    /// The finger-turned centre, used while `steering == .finger`.
    @ObservationIgnored var fingerCentre = Sky.Horizontal(altitude: 30, azimuth: 180)
    /// The newest attitude for the camera queue's frame alignment.
    let shared = SharedPointing()

    @ObservationIgnored private var running = false
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "sky")
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private let location = CLLocationManager()
    @ObservationIgnored private var reader: LocationReader?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.latitudeKey) != nil {
            let lat = defaults.double(forKey: Self.latitudeKey), lon = defaults.double(forKey: Self.longitudeKey)
            if lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180 {
                latitude = lat
                longitude = lon
                placeSource = .remembered
            }
        }
    }

    // MARK: - On and off

    /// The sky view appeared: sensors on, one place fix asked for.
    func start() {
        guard !running else { return }
        running = true
        startMotion()
        askForPlace()
    }

    /// The sky view went away: sensors off.
    func stop() {
        guard running else { return }
        running = false
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        location.stopUpdatingLocation()
    }

    private func startMotion() {
        guard motion.isDeviceMotionAvailable else {
            steering = .finger
            return
        }
        let frames = CMMotionManager.availableAttitudeReferenceFrames()
        let frame: CMAttitudeReferenceFrame = frames.contains(.xTrueNorthZVertical) ? .xTrueNorthZVertical
            : (frames.contains(.xMagneticNorthZVertical) ? .xMagneticNorthZVertical : .xArbitraryCorrectedZVertical)
        guard frame != .xArbitraryCorrectedZVertical else {
            // Without a compass the attitude has no north; a sky turned by it would be wrong.
            log.notice("sky: no north reference on this device — finger steering")
            steering = .finger
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 60
        motion.startDeviceMotionUpdates(using: frame)
        steering = .sensors
    }

    /// The musician dragged: the finger steers until `followPhone()`.
    func steerByFinger() {
        fingerCentre = forward.horizontal
        steering = .finger
    }

    /// Back to the phone's attitude, when the sensors are there.
    func followPhone() {
        if motion.isDeviceMotionActive { steering = .sensors }
    }

    var canFollowPhone: Bool {
        motion.isDeviceMotionAvailable
    }

    // MARK: - Every frame

    /// One drawing frame: the newest attitude (or the finger's centre) into `forward`/`up`, glided.
    func sample() {
        var targetForward = SkyVector(fingerCentre)
        var targetUp = SkyVector(x: 0, y: 0, z: 1)
        if steering == .sensors, let measured = measuredVectors() {
            targetForward = measured.forward
            targetUp = measured.up
        } else if let level = SkyProjection(centre: fingerCentre, fieldOfView: 60) {
            targetUp = level.up
        }
        forward = forward.gliding(towards: targetForward, fraction: Self.glidePerFrame)
        up = up.gliding(towards: targetUp, fraction: Self.glidePerFrame)
        shared.store(forward: forward, up: up)
    }

    /// The back camera's direction and the screen's up from the device attitude, east · north · up.
    /// CoreMotion's frame is x north, y west, z up; its rotation matrix maps that frame into the
    /// device's, so a device axis in the frame is the matrix's row for that axis read as a column.
    private func measuredVectors() -> (forward: SkyVector, up: SkyVector)? {
        guard let attitude = motion.deviceMotion?.attitude else { return nil }
        let m = attitude.rotationMatrix
        // Device −z (out of the back camera) and device +y (top of the screen in portrait).
        let back = (north: -m.m31, west: -m.m32, up: -m.m33)
        let top = (north: m.m21, west: m.m22, up: m.m23)
        let look = SkyVector(x: -back.west, y: back.north, z: back.up)
        let screenUp = SkyVector(x: -top.west, y: top.north, z: top.up)
        guard let f = look.normalized, let u = screenUp.normalized else { return nil }
        return (f, u)
    }

    // MARK: - Place

    /// Choose a reference place by hand (the permission is refused, or the musician wants another sky).
    func choose(_ name: String) {
        guard let place = Self.places.first(where: { $0.name == name }) else { return }
        latitude = place.latitude
        longitude = place.longitude
        placeSource = .chosen(name)
    }

    private func askForPlace() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil else {
            log.error("sky: NSLocationWhenInUseUsageDescription missing — no location asked")
            return
        }
        if reader == nil {
            let reader = LocationReader(
                onPlace: { @Sendable [weak self] lat, lon in
                    Task { @MainActor [weak self] in self?.located(latitude: lat, longitude: lon) }
                },
                onAuthorization: { @Sendable [weak self] allowed, decided in
                    Task { @MainActor [weak self] in self?.authorizationChanged(allowed: allowed, decided: decided) }
                })
            self.reader = reader
            location.delegate = reader
            location.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        }
        switch location.authorizationStatus {
        case .notDetermined:
            location.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationDenied = false
            location.requestLocation()
        default:
            locationDenied = true
        }
    }

    private func authorizationChanged(allowed: Bool, decided: Bool) {
        guard decided else { return }
        locationDenied = !allowed
        if allowed, running { location.requestLocation() }
    }

    private func located(latitude lat: Double, longitude lon: Double) {
        guard lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180 else { return }
        // Rounded to 0.1°: the sky over a town, never the street.
        let roundedLatitude = (lat * 10).rounded() / 10, roundedLongitude = (lon * 10).rounded() / 10
        latitude = roundedLatitude
        longitude = roundedLongitude
        placeSource = .located
        UserDefaults.standard.set(roundedLatitude, forKey: Self.latitudeKey)
        UserDefaults.standard.set(roundedLongitude, forKey: Self.longitudeKey)
    }
}

/// The newest pointing for the camera's capture queue: two vectors behind one lock, written once a
/// frame on the main actor, read once per camera frame. No actor hop in either direction.
final class SharedPointing: Sendable {
    private let state = Mutex((forward: SkyVector(x: 0, y: 1, z: 0), up: SkyVector(x: 0, y: 0, z: 1)))

    func store(forward: SkyVector, up: SkyVector) {
        state.withLock { $0 = (forward, up) }
    }

    func load() -> (forward: SkyVector, up: SkyVector) {
        state.withLock { $0 }
    }
}

/// CoreLocation's delegate: hands the one fix and the permission decision over, nothing else.
private final class LocationReader: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    let onPlace: @Sendable (Double, Double) -> Void
    let onAuthorization: @Sendable (Bool, Bool) -> Void

    init(onPlace: @escaping @Sendable (Double, Double) -> Void,
         onAuthorization: @escaping @Sendable (Bool, Bool) -> Void) {
        self.onPlace = onPlace
        self.onAuthorization = onAuthorization
        super.init()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        onPlace(coordinate.latitude, coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // One fix that did not come: the remembered or chosen place stays.
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let allowed = status == .authorizedWhenInUse || status == .authorizedAlways
        onAuthorization(allowed, status != .notDetermined)
    }
}

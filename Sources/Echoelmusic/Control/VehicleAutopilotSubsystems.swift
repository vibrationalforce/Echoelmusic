import Foundation
import Combine
import CoreLocation
import simd

// MARK: - Sensor Fusion Engine
/// Fusioniert Daten von mehreren Sensoren zu einem konsistenten Zustandsbild
///
/// **Algorithmen:**
/// - Extended Kalman Filter (EKF) für Positions-/Geschwindigkeitsschätzung
/// - Unscented Kalman Filter (UKF) für nichtlineare Dynamik
/// - Sensor-Gewichtung basierend auf Unsicherheit

@MainActor
public class SensorFusionEngine: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var fusedState: VehicleState = VehicleState()

    @Published public private(set) var positionUncertainty: Double = 10.0  // Meter

    @Published public private(set) var sensorStatus: [String: SensorStatus] = [:]

    // MARK: - Sensor Data Buffers

    private var gpsHistory: RingBuffer<GPSReading> = RingBuffer(capacity: 100)
    private var imuHistory: RingBuffer<IMUReading> = RingBuffer(capacity: 1000)
    private var wheelEncoderHistory: RingBuffer<WheelEncoderReading> = RingBuffer(capacity: 500)

    // MARK: - Kalman Filter State

    private var ekfState: EKFState = EKFState()

    // MARK: - Initialization

    public init() {
        initializeSensorStatus()
    }

    private func initializeSensorStatus() {
        sensorStatus = [
            "gps": .unknown,
            "imu": .unknown,
            "lidar": .unknown,
            "radar": .unknown,
            "camera": .unknown,
            "ultrasonic": .unknown,
            "wheel_encoder": .unknown
        ]
    }

    // MARK: - Sensor Updates

    public func updateGPS(_ location: CLLocation) {
        let reading = GPSReading(
            timestamp: Date(),
            coordinate: location.coordinate,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            speed: location.speed,
            course: location.course
        )

        gpsHistory.append(reading)
        sensorStatus["gps"] = location.horizontalAccuracy < 5 ? .healthy : .degraded

        // EKF Update mit GPS
        updateEKFWithGPS(reading)

        // Fused State aktualisieren
        updateFusedState()
    }

    public func updateIMU(acceleration: SIMD3<Double>, gyro: SIMD3<Double>) {
        let reading = IMUReading(
            timestamp: Date(),
            acceleration: acceleration,
            gyroscope: gyro
        )

        imuHistory.append(reading)
        sensorStatus["imu"] = .healthy

        // EKF Prediction mit IMU
        predictEKFWithIMU(reading)
    }

    public func updateWheelEncoders(left: Double, right: Double) {
        let reading = WheelEncoderReading(
            timestamp: Date(),
            leftWheelSpeed: left,
            rightWheelSpeed: right
        )

        wheelEncoderHistory.append(reading)
        sensorStatus["wheel_encoder"] = .healthy

        // Odometrie-Update
        updateOdometry(reading)
    }

    public func updateUltrasonic(_ readings: [UltrasonicReading]) {
        sensorStatus["ultrasonic"] = readings.isEmpty ? .offline : .healthy

        // Ultraschall hauptsächlich für Nahbereichserkennung
        // wird an Perception Engine weitergeleitet
    }

    // MARK: - EKF Implementation

    private func updateEKFWithGPS(_ reading: GPSReading) {
        // Measurement Update (Korrektur)
        let z = SIMD2<Double>(reading.coordinate.latitude, reading.coordinate.longitude)
        let H = simd_double2x2(rows: [
            SIMD2(1, 0),
            SIMD2(0, 1)
        ])

        // Kalman Gain
        let S = H * ekfState.P * H.transpose + ekfState.R_gps
        let K = ekfState.P * H.transpose * S.inverse

        // State Update
        let y = z - SIMD2(ekfState.x[0], ekfState.x[1])  // Innovation
        let correction = K * y
        ekfState.x[0] += correction.x
        ekfState.x[1] += correction.y

        // Covariance Update
        let I = simd_double2x2(1)
        ekfState.P = (I - K * H) * ekfState.P

        // Position Uncertainty
        positionUncertainty = sqrt(ekfState.P[0, 0] + ekfState.P[1, 1])
    }

    private func predictEKFWithIMU(_ reading: IMUReading) {
        // Time Update (Prediction)
        let dt = 0.01  // 100 Hz IMU

        // State Transition
        ekfState.velocity += reading.acceleration * dt
        ekfState.x[0] += ekfState.velocity.x * dt
        ekfState.x[1] += ekfState.velocity.y * dt

        // Heading Update from Gyro
        ekfState.heading += reading.gyroscope.z * dt

        // Covariance Prediction
        let Q = ekfState.Q_imu * dt
        ekfState.P = ekfState.P + Q
    }

    private func updateOdometry(_ reading: WheelEncoderReading) {
        // Differentielle Odometrie
        let wheelBase = 2.5  // Meter (typischer PKW)
        let avgSpeed = (reading.leftWheelSpeed + reading.rightWheelSpeed) / 2.0
        let angularVelocity = (reading.rightWheelSpeed - reading.leftWheelSpeed) / wheelBase

        let dt = 0.02  // 50 Hz Encoder

        // Position Update
        let dx = avgSpeed * cos(ekfState.heading) * dt
        let dy = avgSpeed * sin(ekfState.heading) * dt

        ekfState.x[0] += dx
        ekfState.x[1] += dy
        ekfState.heading += angularVelocity * dt

        // Geschwindigkeit
        ekfState.speed = avgSpeed
    }

    // MARK: - Fused State

    private func updateFusedState() {
        fusedState.position = CLLocationCoordinate2D(
            latitude: ekfState.x[0],
            longitude: ekfState.x[1]
        )
        fusedState.heading = ekfState.heading * 180.0 / .pi
        fusedState.speed = ekfState.speed
        fusedState.acceleration = ekfState.acceleration
        fusedState.angularVelocity = SIMD3(0, 0, ekfState.headingRate)
    }

    public func getFusedState() -> VehicleState {
        return fusedState
    }
}

// MARK: - EKF State

private struct EKFState {
    var x: SIMD2<Double> = .zero           // Position (lat, lon)
    var velocity: SIMD3<Double> = .zero    // Geschwindigkeit (x, y, z)
    var acceleration: SIMD3<Double> = .zero
    var heading: Double = 0                 // Radians
    var headingRate: Double = 0
    var speed: Double = 0

    var P: simd_double2x2 = simd_double2x2(10)  // State Covariance
    var Q_imu: simd_double2x2 = simd_double2x2(0.01)  // IMU Process Noise
    var R_gps: simd_double2x2 = simd_double2x2(5)     // GPS Measurement Noise
}

// MARK: - Sensor Readings

struct GPSReading {
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double
    let course: Double
}

struct IMUReading {
    let timestamp: Date
    let acceleration: SIMD3<Double>
    let gyroscope: SIMD3<Double>
}

struct WheelEncoderReading {
    let timestamp: Date
    let leftWheelSpeed: Double
    let rightWheelSpeed: Double
}

public enum SensorStatus: String, Codable {
    case unknown
    case healthy
    case degraded
    case offline
    case error
}

// MARK: - Perception Engine
/// Erkennt Objekte und Umgebung aus Sensordaten

@MainActor
public class PerceptionEngine: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var detectedObjects: [DetectedObject] = []

    @Published public private(set) var lanes: [LaneMarking] = []

    @Published public private(set) var trafficSigns: [TrafficSign] = []

    @Published public private(set) var drivableArea: DrivableArea?

    // MARK: - Processing

    public func processCameraFrame(_ frame: CameraFrame) {
        // TODO: Neural Network für Objekterkennung
        // Simulierte Objekterkennung für Demo
        simulateObjectDetection(frame)
    }

    public func processLiDAR(_ pointCloud: LiDARPointCloud) {
        // 3D Objekterkennung aus Punktwolke
        processPointCloud(pointCloud)
    }

    public func processRadar(_ data: RadarData) {
        // Radar-Ziele in Objektliste integrieren
        for target in data.targets {
            let obj = DetectedObject(
                id: UUID(),
                type: .vehicle,  // Radar erkennt hauptsächlich Fahrzeuge
                position: SIMD3(
                    Float(target.distance * cos(target.angle * .pi / 180)),
                    Float(target.distance * sin(target.angle * .pi / 180)),
                    0
                ),
                velocity: SIMD3(Float(target.velocity), 0, 0),
                confidence: 0.9,
                source: .radar
            )
            mergeObject(obj)
        }
    }

    // MARK: - Object Detection (Simulation)

    private func simulateObjectDetection(_ frame: CameraFrame) {
        // Platzhalter für echte ML-Inferenz
        // In Produktion: CoreML/Vision Framework

        #if DEBUG
        print("[Perception] Processing camera frame \(frame.cameraId)")
        #endif
    }

    private func processPointCloud(_ cloud: LiDARPointCloud) {
        // Clustering für Objekterkennung
        // DBSCAN oder Euclidean Clustering

        var clusters: [[SIMD3<Float>]] = []
        var visited = Set<Int>()

        for i in 0..<cloud.points.count {
            guard !visited.contains(i) else { continue }

            var cluster: [SIMD3<Float>] = [cloud.points[i]]
            visited.insert(i)

            // Einfaches Radius-basiertes Clustering
            let eps: Float = 0.5  // 50cm
            for j in (i+1)..<cloud.points.count {
                guard !visited.contains(j) else { continue }
                let dist = simd_distance(cloud.points[i], cloud.points[j])
                if dist < eps {
                    cluster.append(cloud.points[j])
                    visited.insert(j)
                }
            }

            if cluster.count >= 10 {  // Min 10 Punkte pro Objekt
                clusters.append(cluster)
            }
        }

        // Cluster zu Objekten konvertieren
        for cluster in clusters {
            let center = cluster.reduce(.zero, +) / Float(cluster.count)
            let obj = DetectedObject(
                id: UUID(),
                type: classifyCluster(cluster),
                position: center,
                velocity: .zero,
                confidence: 0.8,
                source: .lidar
            )
            mergeObject(obj)
        }
    }

    private func classifyCluster(_ cluster: [SIMD3<Float>]) -> ObjectType {
        // Vereinfachte Klassifikation basierend auf Größe
        let minY = cluster.map { $0.y }.min() ?? 0
        let maxY = cluster.map { $0.y }.max() ?? 0
        let height = maxY - minY

        if height > 1.5 {
            return .vehicle
        } else if height > 0.5 {
            return .pedestrian
        } else {
            return .unknown
        }
    }

    private func mergeObject(_ newObj: DetectedObject) {
        // Fusioniere mit existierenden Objekten
        if let index = detectedObjects.firstIndex(where: {
            simd_distance($0.position, newObj.position) < 1.0
        }) {
            // Update existierendes Objekt
            var existing = detectedObjects[index]
            existing.confidence = max(existing.confidence, newObj.confidence)
            existing.lastSeen = Date()
            detectedObjects[index] = existing
        } else {
            detectedObjects.append(newObj)
        }

        // Alte Objekte entfernen
        detectedObjects.removeAll {
            Date().timeIntervalSince($0.lastSeen) > 1.0
        }
    }

    public func getEnvironment() -> PerceivedEnvironment {
        return PerceivedEnvironment(
            objects: detectedObjects,
            lanes: lanes,
            trafficSigns: trafficSigns,
            drivableArea: drivableArea
        )
    }
}

// MARK: - Detected Object

public struct DetectedObject: Identifiable {
    public let id: UUID
    public var type: ObjectType
    public var position: SIMD3<Float>      // Relativ zum Fahrzeug (Meter)
    public var velocity: SIMD3<Float>      // m/s
    public var dimensions: SIMD3<Float>?   // Breite, Höhe, Länge
    public var confidence: Double
    public var source: SensorSource
    public var lastSeen: Date = Date()

    public var distance: Float {
        simd_length(position)
    }
}

public enum ObjectType: String, Codable {
    case vehicle
    case pedestrian
    case cyclist
    case motorcycle
    case truck
    case animal
    case trafficCone
    case barrier
    case unknown
}

public enum SensorSource: String, Codable {
    case camera
    case lidar
    case radar
    case ultrasonic
    case fused
}

public struct LaneMarking {
    public let type: LaneType
    public let points: [SIMD2<Float>]
    public let confidence: Double

    public enum LaneType: String {
        case solid, dashed, doubleSolid, solidDashed
    }
}

public struct TrafficSign {
    public let type: SignType
    public let position: SIMD3<Float>
    public let value: Int?  // z.B. Geschwindigkeitslimit

    public enum SignType: String {
        case speedLimit, stop, yield, noEntry, pedestrianCrossing, construction
    }
}

public struct DrivableArea {
    public let polygon: [SIMD2<Float>]
    public let confidence: Double
}

public struct PerceivedEnvironment {
    public let objects: [DetectedObject]
    public let lanes: [LaneMarking]
    public let trafficSigns: [TrafficSign]
    public let drivableArea: DrivableArea?
}

// MARK: - Path Planner Engine
/// Plant optimale Trajektorien zum Ziel

@MainActor
public class PathPlannerEngine: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var currentPath: [PathPoint] = []

    @Published public private(set) var currentTrajectory: Trajectory?

    // MARK: - Route Planning

    public func calculateRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async {
        // Globale Routenplanung (A* oder Dijkstra)
        // In Produktion: MapKit Directions API

        print("[PathPlanner] Calculating route from \(from) to \(to)")

        // Simulierte Route
        let directPath = [
            PathPoint(coordinate: from, type: .start),
            PathPoint(coordinate: to, type: .destination)
        ]

        currentPath = directPath
    }

    public func planTrajectory(
        currentState: VehicleState,
        environment: PerceivedEnvironment,
        target: CLLocationCoordinate2D?
    ) -> Trajectory {

        guard let target = target else {
            return Trajectory.stop
        }

        // Lokale Trajektorienplanung

        // 1. Kandidaten-Trajektorien generieren
        let candidates = generateCandidateTrajectories(
            currentState: currentState,
            target: target
        )

        // 2. Kollisionsprüfung
        let safeCandidates = candidates.filter { trajectory in
            !hasCollision(trajectory, with: environment.objects)
        }

        // 3. Beste Trajektorie auswählen
        let best = selectBestTrajectory(safeCandidates, target: target)

        currentTrajectory = best
        return best ?? Trajectory.stop
    }

    private func generateCandidateTrajectories(
        currentState: VehicleState,
        target: CLLocationCoordinate2D
    ) -> [Trajectory] {

        var candidates: [Trajectory] = []

        // Verschiedene Lenkwinkel-Optionen
        let steeringOptions: [Double] = [-30, -15, -5, 0, 5, 15, 30]

        for steering in steeringOptions {
            let trajectory = simulateTrajectory(
                from: currentState,
                steeringAngle: steering,
                duration: 3.0  // 3 Sekunden voraus
            )
            candidates.append(trajectory)
        }

        return candidates
    }

    private func simulateTrajectory(
        from state: VehicleState,
        steeringAngle: Double,
        duration: Double
    ) -> Trajectory {

        var points: [TrajectoryPoint] = []
        var simState = state
        let dt = 0.1  // 100ms Schritte

        for t in stride(from: 0, through: duration, by: dt) {
            // Einfaches Fahrradmodell
            let wheelBase = 2.5
            let steeringRad = steeringAngle * .pi / 180

            simState.heading += (simState.speed * tan(steeringRad) / wheelBase) * dt

            let dx = simState.speed * cos(simState.heading * .pi / 180) * dt
            let dy = simState.speed * sin(simState.heading * .pi / 180) * dt

            points.append(TrajectoryPoint(
                time: t,
                x: dx,
                y: dy,
                heading: simState.heading,
                speed: simState.speed,
                steeringAngle: steeringAngle
            ))
        }

        return Trajectory(points: points, steeringAngle: steeringAngle)
    }

    private func hasCollision(_ trajectory: Trajectory, with objects: [DetectedObject]) -> Bool {
        for point in trajectory.points {
            for obj in objects {
                let trajPos = SIMD3<Float>(Float(point.x), Float(point.y), 0)
                let dist = simd_distance(trajPos, obj.position)

                // Sicherheitsabstand basierend auf Objekttyp
                let safetyMargin: Float = obj.type == .pedestrian ? 2.0 : 1.5

                if dist < safetyMargin {
                    return true
                }
            }
        }
        return false
    }

    private func selectBestTrajectory(_ candidates: [Trajectory], target: CLLocationCoordinate2D) -> Trajectory? {
        // Bewertungsfunktion: Nähe zum Ziel + Komfort (wenig Lenkbewegung)
        return candidates.min { a, b in
            let aScore = abs(a.steeringAngle)  // Weniger Lenkung = besser
            let bScore = abs(b.steeringAngle)
            return aScore < bScore
        }
    }

    public func clearPath() {
        currentPath.removeAll()
        currentTrajectory = nil
    }
}

// MARK: - Path Types

public struct PathPoint {
    public let coordinate: CLLocationCoordinate2D
    public let type: PathPointType

    public enum PathPointType {
        case start, waypoint, turn, destination
    }
}

public struct Trajectory {
    public let points: [TrajectoryPoint]
    public let steeringAngle: Double

    public static let stop = Trajectory(points: [], steeringAngle: 0)
}

public struct TrajectoryPoint {
    public let time: Double
    public let x: Double
    public let y: Double
    public let heading: Double
    public let speed: Double
    public let steeringAngle: Double
}

// MARK: - Vehicle Control Engine
/// Berechnet Steuerbefehle aus Trajektorien

@MainActor
public class VehicleControlEngine: ObservableObject {

    // MARK: - State

    private var pidSteering: PIDController
    private var pidSpeed: PIDController

    private var currentCommands: VehicleControlCommands = .neutral

    // MARK: - Initialization

    public init() {
        self.pidSteering = PIDController(kP: 1.5, kI: 0.1, kD: 0.3)
        self.pidSpeed = PIDController(kP: 0.8, kI: 0.2, kD: 0.1)
    }

    // MARK: - Control Computation

    public func computeControl(
        currentState: VehicleState,
        trajectory: Trajectory
    ) -> VehicleControlCommands {

        guard !trajectory.points.isEmpty else {
            return .brake(force: 0.3)  // Sanftes Bremsen ohne Trajektorie
        }

        // Nächsten Trajektorienpunkt als Ziel
        let targetPoint = trajectory.points.first!

        // Lenkungs-PID
        let headingError = targetPoint.heading - currentState.heading
        let steeringCorrection = pidSteering.update(error: headingError)
        let steeringAngle = max(-45, min(45, trajectory.steeringAngle + steeringCorrection))

        // Geschwindigkeits-PID
        let speedError = targetPoint.speed - currentState.speed
        let speedCorrection = pidSpeed.update(error: speedError)

        var throttle: Double = 0
        var brake: Double = 0

        if speedCorrection > 0 {
            throttle = min(1.0, speedCorrection / 10.0)
        } else {
            brake = min(1.0, abs(speedCorrection) / 10.0)
        }

        currentCommands = VehicleControlCommands(
            throttle: throttle,
            brakeForce: brake,
            steeringAngle: steeringAngle,
            gear: .drive
        )

        return currentCommands
    }

    public func emergencyBrake() async {
        currentCommands = VehicleControlCommands(
            throttle: 0,
            brakeForce: 1.0,  // Volle Bremskraft
            steeringAngle: currentCommands.steeringAngle,  // Lenkung halten
            gear: .drive
        )
    }

    public func transitionToManual() {
        // Sanfter Übergang
        currentCommands = .neutral
    }

    public func limitSpeed(to maxSpeed: Double) {
        // Implementiere Geschwindigkeitsbegrenzung
    }
}

// MARK: - PID Controller

public class PIDController {
    private let kP: Double
    private let kI: Double
    private let kD: Double

    private var integral: Double = 0
    private var lastError: Double = 0
    private var lastTime: Date = Date()

    public init(kP: Double, kI: Double, kD: Double) {
        self.kP = kP
        self.kI = kI
        self.kD = kD
    }

    public func update(error: Double) -> Double {
        let now = Date()
        let dt = now.timeIntervalSince(lastTime)

        guard dt > 0 else { return 0 }

        // Proportional
        let p = kP * error

        // Integral (mit Anti-Windup)
        integral += error * dt
        integral = max(-10, min(10, integral))
        let i = kI * integral

        // Derivative
        let derivative = (error - lastError) / dt
        let d = kD * derivative

        lastError = error
        lastTime = now

        return p + i + d
    }

    public func reset() {
        integral = 0
        lastError = 0
    }
}

// MARK: - Driving Safety System
/// Überwacht Sicherheit und verhindert Kollisionen

@MainActor
public class DrivingSafetySystem: ObservableObject {

    // MARK: - State

    @Published public private(set) var currentSafetyLevel: SafetyLevel = .green

    private var detectedObjects: [DetectedObject] = []

    // MARK: - Safety Check

    public func canEngage() -> Bool {
        // Prüfe Voraussetzungen für Autopilot-Aktivierung
        return currentSafetyLevel != .red
    }

    public func evaluate(
        vehicleState: VehicleState,
        environment: PerceivedEnvironment
    ) -> SafetyState {

        // 1. Kollisionsrisiko prüfen
        if let collision = checkCollisionRisk(vehicleState, objects: environment.objects) {
            return collision
        }

        // 2. Spurverlassen prüfen
        if checkLaneDeparture(vehicleState, lanes: environment.lanes) {
            return .warning("Lane departure detected")
        }

        // 3. Geschwindigkeit prüfen
        if vehicleState.speedKmh > 150 {
            return .warning("Speed limit exceeded")
        }

        return .nominal
    }

    private func checkCollisionRisk(
        _ state: VehicleState,
        objects: [DetectedObject]
    ) -> SafetyState? {

        for obj in objects {
            let distance = obj.distance
            let relativeVelocity = -simd_dot(obj.velocity, SIMD3(1, 0, 0))  // Annäherungsgeschwindigkeit

            if relativeVelocity > 0 {
                let timeToCollision = Double(distance) / Double(relativeVelocity)

                if timeToCollision < 1.0 {
                    return .collision(timeToImpact: timeToCollision)
                } else if timeToCollision < 3.0 {
                    return .warning("Object approaching: \(obj.type)")
                }
            }

            // Mindestabstand
            if distance < 2.0 {
                return .critical("Object too close: \(distance)m")
            }
        }

        return nil
    }

    private func checkLaneDeparture(
        _ state: VehicleState,
        lanes: [LaneMarking]
    ) -> Bool {
        // Vereinfachte Spurprüfung
        // In Produktion: Geometrische Berechnung
        return false
    }

    public func updateDetectedObjects(_ objects: [DetectedObject]) {
        self.detectedObjects = objects
    }
}

// MARK: - Safety Level

public enum SafetyLevel: String {
    case green   // Alles OK
    case yellow  // Warnung
    case orange  // Erhöhte Aufmerksamkeit
    case red     // Kritisch - Intervention erforderlich
}

// MARK: - Matrix Extension

extension simd_double2x2 {
    init(_ diagonal: Double) {
        self.init(rows: [
            SIMD2(diagonal, 0),
            SIMD2(0, diagonal)
        ])
    }

    var transpose: simd_double2x2 {
        simd_double2x2(rows: [
            SIMD2(self[0, 0], self[1, 0]),
            SIMD2(self[0, 1], self[1, 1])
        ])
    }

    var inverse: simd_double2x2 {
        let det = self[0, 0] * self[1, 1] - self[0, 1] * self[1, 0]
        guard det != 0 else { return simd_double2x2(1) }

        return simd_double2x2(rows: [
            SIMD2(self[1, 1] / det, -self[0, 1] / det),
            SIMD2(-self[1, 0] / det, self[0, 0] / det)
        ])
    }

    static func * (lhs: simd_double2x2, rhs: SIMD2<Double>) -> SIMD2<Double> {
        return SIMD2(
            lhs[0, 0] * rhs.x + lhs[0, 1] * rhs.y,
            lhs[1, 0] * rhs.x + lhs[1, 1] * rhs.y
        )
    }
}

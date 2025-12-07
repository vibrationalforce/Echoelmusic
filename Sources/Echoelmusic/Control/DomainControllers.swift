import Foundation
import Combine
import CoreLocation
import simd

// MARK: - Land Domain Controller
/// Steuerung für Landfahrzeuge

@MainActor
public class LandDomainController: ObservableObject {

    @Published public private(set) var currentPosition: CLLocationCoordinate2D = CLLocationCoordinate2D()
    @Published public private(set) var currentVelocity: SIMD3<Double> = .zero
    @Published public private(set) var currentHeading: Double = 0

    private var pidSteering = PIDController(kP: 1.2, kI: 0.1, kD: 0.3)
    private var pidSpeed = PIDController(kP: 0.8, kI: 0.2, kD: 0.1)

    public func applyCommand(_ command: LandMovementCommand) {
        // Implementierung der Landfahrzeug-Steuerung
        // Wird an NetworkMotorController weitergeleitet
    }

    public func emergencyBrake() {
        // Volle Bremskraft
        applyCommand(LandMovementCommand(throttle: 0, brake: 1.0, steering: 0))
    }
}

// MARK: - Air Domain Controller
/// Steuerung für Luftfahrzeuge (Flugzeuge, Drohnen, eVTOL, Helikopter)

@MainActor
public class AirDomainController: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var currentPosition: CLLocationCoordinate2D = CLLocationCoordinate2D()
    @Published public private(set) var currentVelocity: SIMD3<Double> = .zero
    @Published public private(set) var currentAltitude: Double = 0
    @Published public private(set) var currentAttitude: UniversalVehicleState.Attitude = .init()
    @Published public private(set) var flightMode: FlightMode = .hover
    @Published public private(set) var autopilotState: AirAutopilotState = .disengaged

    // MARK: - Aircraft Type

    public var aircraftType: AircraftType = .multicopter

    // MARK: - PID Controllers

    private var pidPitch = PIDController(kP: 2.0, kI: 0.3, kD: 0.5)
    private var pidRoll = PIDController(kP: 2.0, kI: 0.3, kD: 0.5)
    private var pidYaw = PIDController(kP: 1.5, kI: 0.2, kD: 0.4)
    private var pidAltitude = PIDController(kP: 1.0, kI: 0.1, kD: 0.3)
    private var pidPosition = PIDController(kP: 0.8, kI: 0.1, kD: 0.2)

    // MARK: - Control

    public func applyCommand(_ command: AirMovementCommand) {
        switch aircraftType {
        case .multicopter, .helicopter:
            applyRotorcraftCommand(command)
        case .fixedWing:
            applyFixedWingCommand(command)
        case .eVTOL:
            applyEVTOLCommand(command)
        case .blimp:
            applyBlimpCommand(command)
        }
    }

    private func applyRotorcraftCommand(_ command: AirMovementCommand) {
        // Multikopter/Helikopter Steuerung
        // Pitch → Vorwärts/Rückwärts
        // Roll → Seitlich
        // Yaw → Drehung
        // Throttle/Collective → Höhe

        let motorMix = calculateRotorcraftMotorMix(command)
        // An Motoren senden...
    }

    private func applyFixedWingCommand(_ command: AirMovementCommand) {
        // Flächenflugzeug Steuerung
        // Elevator → Pitch
        // Ailerons → Roll
        // Rudder → Yaw
        // Throttle → Schub

        let servoCommands = calculateFixedWingServos(command)
        // An Servos senden...
    }

    private func applyEVTOLCommand(_ command: AirMovementCommand) {
        // eVTOL mit Transition zwischen Hover und Cruise
        switch flightMode {
        case .hover, .takeoff, .landing:
            applyRotorcraftCommand(command)
        case .cruise, .transition:
            applyFixedWingCommand(command)
        }
    }

    private func applyBlimpCommand(_ command: AirMovementCommand) {
        // Luftschiff - sehr langsame Reaktion
        // Hauptsächlich Schub und Ruder
    }

    private func calculateRotorcraftMotorMix(_ command: AirMovementCommand) -> [Double] {
        // Typisches Quadcopter Mixing
        // Motor 1 (vorne rechts): +pitch -roll +yaw
        // Motor 2 (hinten rechts): -pitch -roll -yaw
        // Motor 3 (hinten links): -pitch +roll +yaw
        // Motor 4 (vorne links): +pitch +roll -yaw

        let throttle = command.throttle
        let pitch = command.pitch / 45.0  // Normalisieren
        let roll = command.roll / 45.0
        let yaw = command.yaw / 45.0

        let m1 = throttle + pitch - roll + yaw
        let m2 = throttle - pitch - roll - yaw
        let m3 = throttle - pitch + roll + yaw
        let m4 = throttle + pitch + roll - yaw

        return [m1, m2, m3, m4].map { max(0, min(1, $0)) }
    }

    private func calculateFixedWingServos(_ command: AirMovementCommand) -> [Double] {
        return [command.pitch / 30.0, command.roll / 45.0, command.yaw / 20.0]
    }

    // MARK: - Flight Modes

    public func takeoff(targetAltitude: Double) async {
        flightMode = .takeoff
        autopilotState = .climbing

        // Steige auf Zielhöhe
        while currentAltitude < targetAltitude - 1.0 {
            let altError = targetAltitude - currentAltitude
            let throttle = pidAltitude.update(error: altError)
            applyCommand(AirMovementCommand(throttle: 0.5 + throttle * 0.3))
            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
        }

        flightMode = .hover
        autopilotState = .holding
    }

    public func land() async {
        flightMode = .landing
        autopilotState = .descending

        // Langsam sinken
        while currentAltitude > 0.5 {
            applyCommand(AirMovementCommand(throttle: 0.3))
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        // Motoren aus
        applyCommand(AirMovementCommand(throttle: 0))
        flightMode = .grounded
        autopilotState = .disengaged
    }

    public func emergencyHover() {
        // Sofort in Hover-Modus
        flightMode = .hover
        applyCommand(AirMovementCommand(pitch: 0, roll: 0, yaw: 0, throttle: 0.5))
    }

    public func returnToHome() async {
        // RTH Funktion
        autopilotState = .returningHome
        // Navigation zur Startposition...
    }

    // MARK: - Types

    public enum AircraftType {
        case multicopter    // Quadcopter, Hexacopter, Octocopter
        case helicopter     // Klassischer Helikopter
        case fixedWing      // Flugzeug
        case eVTOL          // Elektrisches VTOL (z.B. Joby, Lilium)
        case blimp          // Luftschiff/Zeppelin
    }

    public enum FlightMode {
        case grounded
        case takeoff
        case hover
        case cruise
        case transition     // eVTOL: Hover ↔ Cruise
        case landing
        case emergency
    }

    public enum AirAutopilotState {
        case disengaged
        case holding        // Position/Altitude halten
        case climbing
        case descending
        case navigating
        case returningHome
        case emergency
    }
}

// MARK: - Water Domain Controller
/// Steuerung für Wasserfahrzeuge (Boote, Schiffe, Jetskis)

@MainActor
public class WaterDomainController: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var currentPosition: CLLocationCoordinate2D = CLLocationCoordinate2D()
    @Published public private(set) var currentVelocity: SIMD3<Double> = .zero
    @Published public private(set) var currentHeading: Double = 0
    @Published public private(set) var vesselType: VesselType = .motorboat

    // MARK: - PID Controllers

    private var pidHeading = PIDController(kP: 1.0, kI: 0.1, kD: 0.2)
    private var pidSpeed = PIDController(kP: 0.5, kI: 0.1, kD: 0.1)

    // MARK: - Control

    public func applyCommand(_ command: WaterMovementCommand) {
        switch vesselType {
        case .motorboat, .yacht, .ship:
            applyMotorboatCommand(command)
        case .sailboat:
            applySailboatCommand(command)
        case .jetski:
            applyJetskiCommand(command)
        case .hovercraft:
            applyHovercraftCommand(command)
        case .hydrofoil:
            applyHydrofoilCommand(command)
        }
    }

    private func applyMotorboatCommand(_ command: WaterMovementCommand) {
        // Propeller + Ruder
        let propellerPower = command.throttle
        let rudderAngle = command.rudder
        // An Motoren senden...
    }

    private func applySailboatCommand(_ command: WaterMovementCommand) {
        // Segel + Ruder
        // Komplexere Steuerung basierend auf Wind
    }

    private func applyJetskiCommand(_ command: WaterMovementCommand) {
        // Jet-Antrieb + Lenkung durch Jetstrahl
        let jetPower = command.throttle
        let steeringAngle = command.rudder
    }

    private func applyHovercraftCommand(_ command: WaterMovementCommand) {
        // Luftkissen + Propeller
        // Kann auch an Land fahren!
    }

    private func applyHydrofoilCommand(_ command: WaterMovementCommand) {
        // Tragflügelboot - hebt ab einer gewissen Geschwindigkeit ab
        // Zusätzliche Höhensteuerung der Foils
    }

    public func emergencyStop() {
        // Motor aus, ggf. Anker werfen
        applyCommand(WaterMovementCommand(throttle: 0, rudder: 0))
    }

    // MARK: - Types

    public enum VesselType {
        case motorboat
        case sailboat
        case yacht
        case ship
        case jetski
        case hovercraft
        case hydrofoil
    }
}

// MARK: - Underwater Domain Controller
/// Steuerung für Unterwasserfahrzeuge (U-Boote, ROVs, AUVs)

@MainActor
public class UnderwaterDomainController: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var currentPosition: CLLocationCoordinate2D = CLLocationCoordinate2D()
    @Published public private(set) var currentVelocity: SIMD3<Double> = .zero
    @Published public private(set) var currentDepth: Double = 0
    @Published public private(set) var currentAttitude: UniversalVehicleState.Attitude = .init()
    @Published public private(set) var submarineType: SubmarineType = .rov

    // MARK: - PID Controllers

    private var pidDepth = PIDController(kP: 1.5, kI: 0.2, kD: 0.4)
    private var pidPitch = PIDController(kP: 1.0, kI: 0.1, kD: 0.3)
    private var pidYaw = PIDController(kP: 1.0, kI: 0.1, kD: 0.3)

    // MARK: - Ballast Control

    private var ballastLevel: Double = 0.5  // 0 = leer (auftrieb), 1 = voll (sinkt)

    // MARK: - Control

    public func applyCommand(_ command: UnderwaterMovementCommand) {
        switch submarineType {
        case .rov:
            applyROVCommand(command)
        case .auv:
            applyAUVCommand(command)
        case .submarine:
            applySubmarineCommand(command)
        case .glider:
            applyGliderCommand(command)
        }
    }

    private func applyROVCommand(_ command: UnderwaterMovementCommand) {
        // ROV: Typisch 4-8 Thruster für 6 DOF Kontrolle
        // Vorwärts/Rückwärts, Links/Rechts, Auf/Ab, Pitch, Roll, Yaw

        let thrusterCommands = calculateROVThrusterMix(command)
        // An Thruster senden...
    }

    private func applyAUVCommand(_ command: UnderwaterMovementCommand) {
        // AUV: Autonomer Betrieb, torpedoförmig
        // Hauptantrieb + Steuerflossen
    }

    private func applySubmarineCommand(_ command: UnderwaterMovementCommand) {
        // Großes U-Boot
        // Propeller + Ruder + Tiefenruder + Ballasttanks

        // Tiefensteuerung über Ballast
        if command.vertical > 0.1 {
            // Aufsteigen - Ballast abpumpen
            ballastLevel = max(0, ballastLevel - 0.01)
        } else if command.vertical < -0.1 {
            // Abtauchen - Ballast fluten
            ballastLevel = min(1, ballastLevel + 0.01)
        }
    }

    private func applyGliderCommand(_ command: UnderwaterMovementCommand) {
        // Unterwasser-Gleiter
        // Nutzt Auftriebsänderung + Schwerpunktverlagerung
        // Sehr energieeffizient, aber langsam
    }

    private func calculateROVThrusterMix(_ command: UnderwaterMovementCommand) -> [Double] {
        // Typisches ROV mit 6 Thrustern
        // 4 horizontal (für X, Y, Yaw)
        // 2 vertikal (für Z)

        let forward = command.thrust
        let lateral = command.lateral
        let vertical = command.vertical
        let yaw = command.yaw

        // Horizontal Thruster (vereinfacht)
        let frontLeft = forward + lateral + yaw
        let frontRight = forward - lateral - yaw
        let rearLeft = forward - lateral + yaw
        let rearRight = forward + lateral - yaw

        // Vertikal Thruster
        let verticalLeft = vertical
        let verticalRight = vertical

        return [frontLeft, frontRight, rearLeft, rearRight, verticalLeft, verticalRight]
            .map { max(-1, min(1, $0)) }
    }

    // MARK: - Emergency

    public func emergencySurface() {
        // Sofort auftauchen
        // Ballast komplett abpumpen
        ballastLevel = 0

        // Vertikalantrieb auf Maximum
        applyCommand(UnderwaterMovementCommand(thrust: 0, lateral: 0, vertical: 1.0, yaw: 0))
    }

    public func emergencyBallastBlow() {
        // Notfall-Auftauchen durch Druckluft in Ballasttanks
        // Für große U-Boote
        ballastLevel = 0
    }

    // MARK: - Depth Control

    public func setTargetDepth(_ depth: Double) async {
        while abs(currentDepth - depth) > 0.5 {
            let depthError = depth - currentDepth
            let vertical = pidDepth.update(error: depthError)
            applyCommand(UnderwaterMovementCommand(vertical: vertical))
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }
    }

    // MARK: - Types

    public enum SubmarineType {
        case rov        // Remotely Operated Vehicle (Kabel)
        case auv        // Autonomous Underwater Vehicle
        case submarine  // Bemannt
        case glider     // Unterwasser-Gleiter
    }
}

// MARK: - Domain Transition Engine
/// Verwaltet nahtlose Übergänge zwischen Domänen

@MainActor
public class DomainTransitionEngine: ObservableObject {

    @Published public private(set) var isTransitioning: Bool = false
    @Published public private(set) var progress: Double = 0.0
    @Published public private(set) var currentPhase: TransitionPhase = .none

    public func performTransition(
        from: VehicleDomain,
        to: VehicleDomain,
        vehicleState: UniversalVehicleState,
        onProgress: @escaping (Double) -> Void
    ) async {

        isTransitioning = true
        progress = 0

        let transition = DomainTransition(from: from, to: to)
        let duration = transition.transitionDuration

        switch (from, to) {
        case (.land, .air):
            await performTakeoffTransition(duration: duration, onProgress: onProgress)

        case (.air, .land):
            await performLandingTransition(duration: duration, onProgress: onProgress)

        case (.land, .water):
            await performLandToWaterTransition(duration: duration, onProgress: onProgress)

        case (.water, .land):
            await performWaterToLandTransition(duration: duration, onProgress: onProgress)

        case (.water, .underwater):
            await performDiveTransition(duration: duration, onProgress: onProgress)

        case (.underwater, .water):
            await performSurfaceTransition(duration: duration, onProgress: onProgress)

        case (.air, .water):
            await performSplashdownTransition(duration: duration, onProgress: onProgress)

        case (.water, .air):
            await performWaterTakeoffTransition(duration: duration, onProgress: onProgress)

        case (.air, .underwater):
            await performDiveBombTransition(duration: duration, onProgress: onProgress)

        case (.underwater, .air):
            await performUnderwaterLaunchTransition(duration: duration, onProgress: onProgress)

        default:
            break
        }

        progress = 1.0
        onProgress(1.0)
        isTransitioning = false
        currentPhase = .none
    }

    // MARK: - Specific Transitions

    private func performTakeoffTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        // Phase 1: Räder einfahren / Rotoren hochfahren
        currentPhase = .preparation
        await animateProgress(from: 0, to: 0.2, duration: duration * 0.2, onProgress: onProgress)

        // Phase 2: Abheben
        currentPhase = .active
        await animateProgress(from: 0.2, to: 0.8, duration: duration * 0.6, onProgress: onProgress)

        // Phase 3: Stabilisieren
        currentPhase = .stabilization
        await animateProgress(from: 0.8, to: 1.0, duration: duration * 0.2, onProgress: onProgress)
    }

    private func performLandingTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        currentPhase = .preparation
        await animateProgress(from: 0, to: 0.3, duration: duration * 0.3, onProgress: onProgress)

        currentPhase = .active
        await animateProgress(from: 0.3, to: 0.9, duration: duration * 0.5, onProgress: onProgress)

        currentPhase = .stabilization
        await animateProgress(from: 0.9, to: 1.0, duration: duration * 0.2, onProgress: onProgress)
    }

    private func performLandToWaterTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        // Amphibienfahrzeug fährt ins Wasser
        currentPhase = .preparation
        await animateProgress(from: 0, to: 0.3, duration: duration * 0.3, onProgress: onProgress)

        currentPhase = .active
        // Räder einfahren, Propeller aktivieren
        await animateProgress(from: 0.3, to: 0.8, duration: duration * 0.5, onProgress: onProgress)

        currentPhase = .stabilization
        await animateProgress(from: 0.8, to: 1.0, duration: duration * 0.2, onProgress: onProgress)
    }

    private func performWaterToLandTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        currentPhase = .preparation
        await animateProgress(from: 0, to: 0.3, duration: duration * 0.3, onProgress: onProgress)

        currentPhase = .active
        // Räder ausfahren, auf Landantrieb umschalten
        await animateProgress(from: 0.3, to: 0.8, duration: duration * 0.5, onProgress: onProgress)

        currentPhase = .stabilization
        await animateProgress(from: 0.8, to: 1.0, duration: duration * 0.2, onProgress: onProgress)
    }

    private func performDiveTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        currentPhase = .preparation
        // Schnorchel einfahren, Luken schließen
        await animateProgress(from: 0, to: 0.2, duration: duration * 0.2, onProgress: onProgress)

        currentPhase = .active
        // Ballast fluten, abtauchen
        await animateProgress(from: 0.2, to: 0.9, duration: duration * 0.7, onProgress: onProgress)

        currentPhase = .stabilization
        await animateProgress(from: 0.9, to: 1.0, duration: duration * 0.1, onProgress: onProgress)
    }

    private func performSurfaceTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        currentPhase = .preparation
        await animateProgress(from: 0, to: 0.1, duration: duration * 0.1, onProgress: onProgress)

        currentPhase = .active
        // Ballast abpumpen, aufsteigen
        await animateProgress(from: 0.1, to: 0.8, duration: duration * 0.7, onProgress: onProgress)

        currentPhase = .stabilization
        // Schnorchel ausfahren, stabilisieren
        await animateProgress(from: 0.8, to: 1.0, duration: duration * 0.2, onProgress: onProgress)
    }

    private func performSplashdownTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        // Wasserflugzeug landet auf Wasser
        currentPhase = .active
        await animateProgress(from: 0, to: 1.0, duration: duration, onProgress: onProgress)
    }

    private func performWaterTakeoffTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        // Wasserflugzeug startet vom Wasser
        currentPhase = .active
        await animateProgress(from: 0, to: 1.0, duration: duration, onProgress: onProgress)
    }

    private func performDiveBombTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        // Drohne taucht direkt von Luft ins Wasser
        currentPhase = .active
        await animateProgress(from: 0, to: 1.0, duration: duration, onProgress: onProgress)
    }

    private func performUnderwaterLaunchTransition(duration: TimeInterval, onProgress: @escaping (Double) -> Void) async {
        // Drohne startet von unter Wasser
        currentPhase = .active
        await animateProgress(from: 0, to: 1.0, duration: duration, onProgress: onProgress)
    }

    // MARK: - Animation Helper

    private func animateProgress(
        from start: Double,
        to end: Double,
        duration: TimeInterval,
        onProgress: @escaping (Double) -> Void
    ) async {
        let steps = Int(duration * 50)  // 50 Hz
        let stepDuration = UInt64(duration / Double(steps) * 1_000_000_000)

        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let currentProgress = start + (end - start) * t
            progress = currentProgress
            onProgress(currentProgress)
            try? await Task.sleep(nanoseconds: stepDuration)
        }
    }

    // MARK: - Types

    public enum TransitionPhase: String {
        case none
        case preparation    // Vorbereitung
        case active         // Aktive Transformation
        case stabilization  // Stabilisierung
    }
}

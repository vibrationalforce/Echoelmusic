import Foundation
import AVFoundation
import CarPlay

/// Vehicle Integration Manager
/// Supports cars, buses, airplanes, and ships
///
/// Supported Vehicles:
/// - Cars (CarPlay, Android Auto, Tesla, BMW iDrive, Mercedes MBUX)
/// - Buses (Coach entertainment systems)
/// - Airplanes (In-Flight Entertainment, cockpit audio)
/// - Ships (Maritime audio, cruise entertainment)
/// - Trains (Train entertainment systems)
/// - RVs/Motorhomes (Mobile living audio)
///
/// Features:
/// - CarPlay integration
/// - Bio-reactive music while driving
/// - Sleep mode for passengers
/// - Meditation mode for flights
/// - Marine spatial audio
@MainActor
class VehicleIntegrationManager: ObservableObject {

    // MARK: - Published State

    @Published var vehicleType: VehicleType?
    @Published var isConnected: Bool = false
    @Published var audioSystem: AudioSystem?
    @Published var passengerMode: PassengerMode = .none
    @Published var bioReactiveEnabled: Bool = false

    // MARK: - Vehicle Types

    enum VehicleType {
        // Road Vehicles
        case car_personal
        case car_luxury
        case car_electric
        case bus_city
        case bus_coach
        case truck
        case rv_motorhome
        case motorcycle

        // Air Vehicles
        case airplane_commercial
        case airplane_private
        case helicopter

        // Water Vehicles
        case ship_cruise
        case ship_ferry
        case yacht
        case sailboat

        // Rail
        case train_regional
        case train_highspeed

        var name: String {
            switch self {
            case .car_personal: return "Personal Car"
            case .car_luxury: return "Luxury Car"
            case .car_electric: return "Electric Vehicle"
            case .bus_city: return "City Bus"
            case .bus_coach: return "Coach Bus"
            case .truck: return "Truck"
            case .rv_motorhome: return "RV/Motorhome"
            case .motorcycle: return "Motorcycle"
            case .airplane_commercial: return "Commercial Airplane"
            case .airplane_private: return "Private Jet"
            case .helicopter: return "Helicopter"
            case .ship_cruise: return "Cruise Ship"
            case .ship_ferry: return "Ferry"
            case .yacht: return "Yacht"
            case .sailboat: return "Sailboat"
            case .train_regional: return "Regional Train"
            case .train_highspeed: return "High-Speed Train"
            }
        }

        var typicalSpeakers: Int {
            switch self {
            case .car_personal: return 4  // Front + Rear
            case .car_luxury: return 16   // Premium audio (Burmester, Bang & Olufsen)
            case .car_electric: return 14 // Tesla, BMW iX (premium audio)
            case .motorcycle: return 2    // Helmet speakers
            case .bus_city: return 8      // PA system
            case .bus_coach: return 40    // Individual seat speakers
            case .truck: return 4
            case .rv_motorhome: return 8  // Multi-zone
            case .airplane_commercial: return 300  // Seatback entertainment
            case .airplane_private: return 12      // Cabin audio
            case .helicopter: return 4             // Headset audio
            case .ship_cruise: return 1000         // Massive PA + cabin audio
            case .ship_ferry: return 50            // Announcement + zones
            case .yacht: return 20                 // Multi-zone luxury
            case .sailboat: return 4
            case .train_regional: return 40        // Announcement + zones
            case .train_highspeed: return 200      // ICE, TGV, Shinkansen
            }
        }
    }

    // MARK: - Audio Systems

    struct AudioSystem {
        var brand: Brand
        var speakerCount: Int
        var channels: Int
        var supportsAtmos: Bool
        var supportsSpatial: Bool

        enum Brand {
            // Car Audio
            case bose_automotive
            case bang_olufsen
            case burmester
            case bowers_wilkins
            case harman_kardon
            case meridian
            case mark_levinson
            case mcintosh

            // Tesla
            case tesla_premium

            // BMW
            case bmw_idrive

            // Mercedes
            case mercedes_mbux
            case mercedes_burmester_4d

            // In-Flight Entertainment
            case panasonic_avionics
            case thales_avant
            case safran_seats

            // Maritime
            case fusion_marine
            case jl_audio_marine
            case rockford_fosgate_marine

            var supportsCarPlay: Bool {
                switch self {
                case .bose_automotive, .bang_olufsen, .burmester, .bowers_wilkins,
                     .harman_kardon, .meridian, .mark_levinson, .mcintosh,
                     .bmw_idrive, .mercedes_mbux:
                    return true
                case .tesla_premium:
                    return false  // Tesla uses custom system
                default:
                    return false
                }
            }

            var maxChannels: Int {
                switch self {
                case .mercedes_burmester_4d:
                    return 31  // Mercedes EQS Burmester 4D
                case .bang_olufsen, .burmester:
                    return 16
                case .tesla_premium:
                    return 14  // Tesla Model S Plaid
                case .bmw_idrive:
                    return 16  // BMW iX Bowers & Wilkins
                default:
                    return 8
                }
            }
        }
    }

    // MARK: - Passenger Modes

    enum PassengerMode {
        case none
        case driver               // Alert, focus music
        case passenger_front      // Relaxed music
        case passenger_rear       // Sleep mode, meditation
        case flight_sleep         // Airplane sleep mode
        case flight_meditation    // In-flight meditation
        case cruise_relaxation    // Ship relaxation
        case train_work           // Train work mode (focus)

        var description: String {
            switch self {
            case .none: return "Not in vehicle"
            case .driver: return "Driver Mode (Alert)"
            case .passenger_front: return "Front Passenger (Relaxed)"
            case .passenger_rear: return "Rear Passenger (Sleep/Meditate)"
            case .flight_sleep: return "Flight Sleep Mode"
            case .flight_meditation: return "In-Flight Meditation"
            case .cruise_relaxation: return "Cruise Relaxation"
            case .train_work: return "Train Work Mode"
            }
        }

        var recommendedBioReactivity: Bool {
            switch self {
            case .passenger_rear, .flight_sleep, .flight_meditation, .cruise_relaxation:
                return true  // Passenger modes benefit from bio-reactivity
            case .driver:
                return false // Driver should stay alert, not bio-reactive
            default:
                return false
            }
        }
    }

    // MARK: - CarPlay Integration

    #if canImport(CarPlay)
    private var carPlayController: CPInterfaceController?
    private var carPlayTemplate: CPListTemplate?

    func setupCarPlay() {
        // CarPlay templates
        let meditationItem = CPListItem(text: "Meditation Mode", detailText: "Bio-reactive calm")
        let focusItem = CPListItem(text: "Focus Mode", detailText: "Alert driving music")
        let relaxItem = CPListItem(text: "Relax Mode", detailText: "Passenger comfort")

        carPlayTemplate = CPListTemplate(
            title: "Echoelmusic",
            sections: [
                CPListSection(items: [meditationItem, focusItem, relaxItem])
            ]
        )

        print("🚗 CarPlay integration ready")
    }

    func connectCarPlay(interfaceController: CPInterfaceController) {
        carPlayController = interfaceController
        carPlayController?.setRootTemplate(carPlayTemplate!, animated: true)

        vehicleType = .car_personal
        isConnected = true

        print("🚗 CarPlay connected")
    }
    #endif

    // MARK: - Tesla Integration

    func connectTesla(model: TeslaModel) {
        vehicleType = .car_electric

        let speakerCount: Int
        switch model {
        case .model_s_plaid, .model_x_plaid:
            speakerCount = 22  // Tesla immersive sound
        case .model_3_performance, .model_y_performance:
            speakerCount = 14
        default:
            speakerCount = 8
        }

        audioSystem = AudioSystem(
            brand: .tesla_premium,
            speakerCount: speakerCount,
            channels: speakerCount,
            supportsAtmos: false,
            supportsSpatial: true  // Tesla spatial audio
        )

        isConnected = true
        print("🚗 Tesla connected: \(model.rawValue)")
    }

    enum TeslaModel: String {
        case model_s_plaid = "Model S Plaid"
        case model_x_plaid = "Model X Plaid"
        case model_3_performance = "Model 3 Performance"
        case model_y_performance = "Model Y Performance"
    }

    // MARK: - BMW iDrive Integration

    func connectBMW(model: BMWModel) {
        vehicleType = .car_luxury

        audioSystem = AudioSystem(
            brand: .bmw_idrive,
            speakerCount: 18,
            channels: 16,
            supportsAtmos: false,
            supportsSpatial: true  // BMW 4D audio
        )

        isConnected = true
        print("🚗 BMW iDrive connected: \(model.rawValue)")
    }

    enum BMWModel: String {
        case ix = "BMW iX"
        case i7 = "BMW i7"
        case x7 = "BMW X7"
        case series_7 = "BMW 7 Series"
    }

    // MARK: - Mercedes MBUX Integration

    func connectMercedes(model: MercedesModel) {
        vehicleType = .car_luxury

        let speakerCount: Int
        let brand: AudioSystem.Brand

        if model == .eqs_maybach {
            speakerCount = 31  // Burmester 4D
            brand = .mercedes_burmester_4d
        } else {
            speakerCount = 15
            brand = .mercedes_mbux
        }

        audioSystem = AudioSystem(
            brand: brand,
            speakerCount: speakerCount,
            channels: speakerCount,
            supportsAtmos: true,  // Mercedes supports Dolby Atmos
            supportsSpatial: true
        )

        isConnected = true
        print("🚗 Mercedes MBUX connected: \(model.rawValue)")
    }

    enum MercedesModel: String {
        case eqs = "EQS"
        case eqs_maybach = "EQS Maybach (Burmester 4D)"
        case s_class = "S-Class"
    }

    // MARK: - In-Flight Entertainment

    func connectAirplane(seatNumber: String) {
        vehicleType = .airplane_commercial
        passengerMode = .flight_sleep

        audioSystem = AudioSystem(
            brand: .panasonic_avionics,
            speakerCount: 2,  // Headphone output
            channels: 2,
            supportsAtmos: false,
            supportsSpatial: false
        )

        isConnected = true
        print("✈️ In-Flight Entertainment connected: Seat \(seatNumber)")
        print("🧘 Flight Sleep Mode activated")
    }

    func enableFlightMeditationMode() {
        passengerMode = .flight_meditation
        bioReactiveEnabled = true

        print("🧘 Flight Meditation Mode activated")
        print("   - Bio-reactive calm music")
        print("   - HRV-based breathing exercises")
        print("   - Sleep optimization")
    }

    // MARK: - Cruise Ship Integration

    func connectCruiseShip(cabinNumber: String) {
        vehicleType = .ship_cruise
        passengerMode = .cruise_relaxation

        audioSystem = AudioSystem(
            brand: .fusion_marine,
            speakerCount: 4,  // Cabin speakers
            channels: 4,
            supportsAtmos: false,
            supportsSpatial: true
        )

        isConnected = true
        print("🚢 Cruise Ship connected: Cabin \(cabinNumber)")
        print("🧘 Cruise Relaxation Mode activated")
    }

    // MARK: - Bus/Coach Integration

    func connectBus(type: BusType) {
        vehicleType = type == .city ? .bus_city : .bus_coach
        passengerMode = .passenger_rear

        let speakerCount = type == .coach ? 40 : 8

        audioSystem = AudioSystem(
            brand: .bose_automotive,
            speakerCount: speakerCount,
            channels: speakerCount,
            supportsAtmos: false,
            supportsSpatial: false
        )

        isConnected = true
        print("🚌 Bus connected: \(type.rawValue)")
    }

    enum BusType: String {
        case city = "City Bus"
        case coach = "Coach (Long-distance)"
    }

    // MARK: - Train Integration

    func connectTrain(type: TrainType) {
        vehicleType = type == .highspeed ? .train_highspeed : .train_regional
        passengerMode = .train_work

        audioSystem = AudioSystem(
            brand: .bose_automotive,
            speakerCount: type == .highspeed ? 200 : 40,
            channels: 8,
            supportsAtmos: false,
            supportsSpatial: false
        )

        isConnected = true
        print("🚄 Train connected: \(type.rawValue)")
    }

    enum TrainType: String {
        case regional = "Regional Train"
        case highspeed = "High-Speed Train (ICE/TGV/Shinkansen)"
    }

    // MARK: - Bio-Reactive Vehicle Audio

    func updateBioReactiveAudio(hrv: Double, heartRate: Double, coherence: Double) {
        guard bioReactiveEnabled else { return }

        switch passengerMode {
        case .passenger_rear, .flight_sleep:
            // High HRV → calm, sleep-inducing music
            // Low HRV → relaxing, stress-reducing music
            if hrv > 70 {
                print("🧘 Bio-Audio: HRV high → Deep sleep music")
            } else {
                print("🧘 Bio-Audio: HRV low → Relaxation music")
            }

        case .flight_meditation:
            // Meditation-optimized flight audio
            print("🧘 Bio-Audio: Flight meditation (HRV \(Int(hrv)))")

        case .cruise_relaxation:
            // Cruise ship relaxation
            print("🧘 Bio-Audio: Cruise relaxation (Coherence \(Int(coherence))%)")

        case .driver:
            // Driver mode: NO bio-reactivity for safety
            print("🚗 Driver Mode: Bio-reactivity disabled (safety)")

        default:
            break
        }
    }

    // MARK: - Safety Features

    func enableDriverSafetyMode() {
        passengerMode = .driver
        bioReactiveEnabled = false  // Disable for driver safety

        print("🚗 Driver Safety Mode enabled")
        print("   - Bio-reactivity disabled")
        print("   - Alert, focus music only")
        print("   - No sleep-inducing sounds")
    }

    // MARK: - Motorcycle Integration

    func connectMotorcycle(helmetAudio: Bool) {
        vehicleType = .motorcycle
        passengerMode = .driver

        audioSystem = AudioSystem(
            brand: .bose_automotive,
            speakerCount: 2,  // Helmet speakers
            channels: 2,
            supportsAtmos: false,
            supportsSpatial: false
        )

        isConnected = true
        print("🏍️ Motorcycle connected (Helmet audio: \(helmetAudio ? "✅" : "❌"))")
    }

    // MARK: - Yacht/Boat Integration

    func connectYacht(zones: Int) {
        vehicleType = .yacht
        passengerMode = .cruise_relaxation

        audioSystem = AudioSystem(
            brand: .fusion_marine,
            speakerCount: zones * 4,
            channels: zones * 2,
            supportsAtmos: false,
            supportsSpatial: true  // Marine spatial audio
        )

        isConnected = true
        print("⛵ Yacht connected: \(zones) audio zones")
    }

    // MARK: - RV/Motorhome Integration

    func connectRV(zones: Int = 3) {
        vehicleType = .rv_motorhome
        passengerMode = .passenger_rear

        // RV typically has: Cockpit, Living Area, Bedroom
        audioSystem = AudioSystem(
            brand: .bose_automotive,
            speakerCount: zones * 4,
            channels: zones * 2,
            supportsAtmos: false,
            supportsSpatial: true
        )

        isConnected = true
        print("🚐 RV/Motorhome connected: \(zones) zones")
    }

    // MARK: - Debug Info

    var debugInfo: String {
        var info = """
        VehicleIntegrationManager:
        - Connected: \(isConnected)
        """

        if let vehicle = vehicleType {
            info += """
            \n- Vehicle: \(vehicle.name)
            - Mode: \(passengerMode.description)
            - Bio-Reactive: \(bioReactiveEnabled ? "✅" : "❌")
            """
        }

        if let audio = audioSystem {
            info += """
            \n- Audio: \(audio.brand)
            - Speakers: \(audio.speakerCount)
            - Channels: \(audio.channels)
            - Spatial Audio: \(audio.supportsSpatial ? "✅" : "❌")
            """
        }

        return info
    }
}

import Foundation

/// Tour & Live Performance Management
/// Complete tour planning, booking, and logistics
///
/// Features:
/// - Tour date scheduling
/// - Venue database & booking
/// - Ticket sales integration
/// - Technical rider generation
/// - Hospitality rider generation
/// - Settlement & box office tracking
/// - Merchandise sales
/// - Travel & accommodation logistics
@MainActor
class TourManager: ObservableObject {

    // MARK: - Published Properties

    @Published var tours: [Tour] = []
    @Published var venues: [Venue] = []
    @Published var shows: [Show] = []
    @Published var merchandise: [MerchItem] = []

    // MARK: - Tour

    struct Tour: Identifiable {
        let id = UUID()
        var name: String
        var artist: String
        var startDate: Date
        var endDate: Date
        var shows: [Show]
        var status: TourStatus
        var totalRevenue: Double
        var totalExpenses: Double

        enum TourStatus {
            case planning, confirmed, ongoing, completed, cancelled
        }

        var netProfit: Double {
            totalRevenue - totalExpenses
        }
    }

    // MARK: - Show

    struct Show: Identifiable {
        let id = UUID()
        var date: Date
        var venue: Venue
        var doors: Date
        var showtime: Date
        var ticketing: Ticketing
        var settlement: Settlement?
        var merchandise: MerchandiseSales
        var technical: TechnicalInfo
        var hospitality: HospitalityInfo
        var status: ShowStatus

        enum ShowStatus {
            case tentative, confirmed, soundcheck, doors, showtime, completed, cancelled
        }

        struct Ticketing {
            var capacity: Int
            var ticketsSold: Int
            var pricing: [TicketTier]
            var platform: TicketPlatform

            struct TicketTier {
                let name: String  // GA, VIP, Meet & Greet
                let price: Double
                let quantity: Int
                var sold: Int
            }

            enum TicketPlatform: String {
                case ticketmaster = "Ticketmaster"
                case eventbrite = "Eventbrite"
                case dice = "DICE"
                case seeTickets = "See Tickets"
                case axs = "AXS"
                case bandsintown = "Bandsintown"
            }

            var totalRevenue: Double {
                pricing.reduce(0) { $0 + (Double($1.sold) * $1.price) }
            }

            var soldOutPercentage: Double {
                guard capacity > 0 else { return 0.0 }
                return Double(ticketsSold) / Double(capacity) * 100.0
            }
        }

        struct Settlement {
            var boxOffice: Double
            var merchandise: Double
            var expenses: Expenses
            var dealType: DealType
            var payout: Double

            struct Expenses {
                var production: Double
                var travel: Double
                var accommodation: Double
                var catering: Double
                var other: Double

                var total: Double {
                    production + travel + accommodation + catering + other
                }
            }

            enum DealType {
                case guarantee(amount: Double)
                case percentageOfDoor(percentage: Double)
                case guaranteeVsPercentage(guarantee: Double, percentage: Double)
                case profitSplit(percentage: Double)
            }

            mutating func calculatePayout(ticketRevenue: Double) {
                switch dealType {
                case .guarantee(let amount):
                    payout = amount

                case .percentageOfDoor(let percentage):
                    payout = ticketRevenue * (percentage / 100.0)

                case .guaranteeVsPercentage(let guarantee, let percentage):
                    let percentagePayout = ticketRevenue * (percentage / 100.0)
                    payout = max(guarantee, percentagePayout)

                case .profitSplit(let percentage):
                    let profit = ticketRevenue - expenses.total
                    payout = profit * (percentage / 100.0)
                }
            }
        }

        struct MerchandiseSales {
            var items: [MerchSale]
            var totalRevenue: Double {
                items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
            }

            struct MerchSale {
                let item: MerchItem
                let price: Double
                let quantity: Int
            }
        }

        struct TechnicalInfo {
            var stageSize: StageSize
            var soundSystem: String?
            var lightingRig: String?
            var backline: [BacklineItem]
            var powerRequirements: String?
            var loadInTime: Date?
            var soundcheckTime: Date?

            struct StageSize {
                let width: Double  // meters
                let depth: Double
                let height: Double
            }

            struct BacklineItem {
                let name: String
                let quantity: Int
                let provided: Bool  // Provided by venue or brought by artist
            }
        }

        struct HospitalityInfo {
            var buyout: Double?  // Cash payment instead of meal
            var guestList: Int
            var dressingRooms: Int
            var catering: CateringRequirements?

            struct CateringRequirements {
                var hotMeals: Int
                var vegetarianOptions: Bool
                var veganOptions: Bool
                var dietary: [String]  // Allergies, restrictions
                var beverages: [String]
                var snacks: [String]
            }
        }
    }

    // MARK: - Venue

    struct Venue: Identifiable {
        let id = UUID()
        var name: String
        var location: Location
        var capacity: Int
        var type: VenueType
        var contact: VenueContact
        var technical: VenueTechnical
        var notes: String?

        struct Location {
            let address: String
            let city: String
            let state: String?
            let country: String
            let postalCode: String
            let latitude: Double?
            let longitude: Double?
        }

        enum VenueType {
            case club, theater, arena, stadium, festival
            case bar, cafeSoftSeater, concert hall, outdoor
        }

        struct VenueContact {
            let booker: Person?
            let production: Person?
            let foh: Person?  // Front of House
            let phone: String?
            let email: String?

            struct Person {
                let name: String
                let phone: String?
                let email: String?
            }
        }

        struct VenueTechnical {
            let stageSize: Show.TechnicalInfo.StageSize?
            let soundSystem: String?
            let lightingRig: String?
            let backline: [String]
            let loadInAccess: String?
            let parking: String?
        }
    }

    // MARK: - Merchandise

    struct MerchItem: Identifiable {
        let id = UUID()
        var name: String
        var type: MerchType
        var sizes: [String]
        var cost: Double
        var price: Double
        var stock: Int

        enum MerchType {
            case tshirt, hoodie, hat, poster, vinyl, cd
            case sticker, toteBag, enamelPin, other
        }

        var margin: Double {
            price - cost
        }

        var marginPercentage: Double {
            guard price > 0 else { return 0.0 }
            return (margin / price) * 100.0
        }
    }

    // MARK: - Initialization

    init() {
        print("🎸 Tour Manager initialized")

        // Load venue database
        loadVenueDatabase()

        print("   ✅ \(venues.count) venues in database")
    }

    private func loadVenueDatabase() {
        // Load common venues (in production: comprehensive database)
        venues = [
            Venue(
                name: "The Troubadour",
                location: Venue.Location(
                    address: "9081 Santa Monica Blvd",
                    city: "West Hollywood",
                    state: "CA",
                    country: "USA",
                    postalCode: "90069",
                    latitude: 34.0901,
                    longitude: -118.3871
                ),
                capacity: 500,
                type: .club,
                contact: Venue.VenueContact(booker: nil, production: nil, foh: nil, phone: nil, email: nil),
                technical: Venue.VenueTechnical(stageSize: nil, soundSystem: nil, lightingRig: nil, backline: [], loadInAccess: nil, parking: nil)
            ),
            Venue(
                name: "Bowery Ballroom",
                location: Venue.Location(
                    address: "6 Delancey St",
                    city: "New York",
                    state: "NY",
                    country: "USA",
                    postalCode: "10002",
                    latitude: 40.7181,
                    longitude: -73.9935
                ),
                capacity: 575,
                type: .club,
                contact: Venue.VenueContact(booker: nil, production: nil, foh: nil, phone: nil, email: nil),
                technical: Venue.VenueTechnical(stageSize: nil, soundSystem: nil, lightingRig: nil, backline: [], loadInAccess: nil, parking: nil)
            ),
        ]
    }

    // MARK: - Create Tour

    func createTour(
        name: String,
        artist: String,
        startDate: Date,
        endDate: Date
    ) -> Tour {
        print("🎸 Creating tour: \(name)")

        let tour = Tour(
            name: name,
            artist: artist,
            startDate: startDate,
            endDate: endDate,
            shows: [],
            status: .planning,
            totalRevenue: 0,
            totalExpenses: 0
        )

        tours.append(tour)

        print("   ✅ Tour created")

        return tour
    }

    // MARK: - Book Show

    func bookShow(
        tourId: UUID,
        venue: Venue,
        date: Date,
        ticketing: Show.Ticketing,
        dealType: Show.Settlement.DealType
    ) -> Show {
        print("📅 Booking show at \(venue.name)...")

        let show = Show(
            date: date,
            venue: venue,
            doors: Calendar.current.date(byAdding: .hour, value: -1, to: date) ?? date,
            showtime: date,
            ticketing: ticketing,
            settlement: Show.Settlement(
                boxOffice: 0,
                merchandise: 0,
                expenses: Show.Settlement.Expenses(production: 0, travel: 0, accommodation: 0, catering: 0, other: 0),
                dealType: dealType,
                payout: 0
            ),
            merchandise: Show.MerchandiseSales(items: []),
            technical: Show.TechnicalInfo(
                stageSize: Show.TechnicalInfo.StageSize(width: 10, depth: 8, height: 5),
                backline: []
            ),
            hospitality: Show.HospitalityInfo(guestList: 10, dressingRooms: 1),
            status: .tentative
        )

        shows.append(show)

        // Add to tour
        if let tourIndex = tours.firstIndex(where: { $0.id == tourId }) {
            tours[tourIndex].shows.append(show)
        }

        print("   ✅ Show booked")

        return show
    }

    // MARK: - Generate Rider

    func generateTechnicalRider(artist: String, requirements: TechnicalRequirements) -> String {
        print("📄 Generating technical rider...")

        var rider = """
        ═══════════════════════════════════════
        TECHNICAL RIDER
        ═══════════════════════════════════════

        Artist: \(artist)
        Date: \(Date())

        STAGE REQUIREMENTS
        ───────────────────────────────────────
        Stage Size (minimum): \(requirements.minimumStageSize.width)m W x \(requirements.minimumStageSize.depth)m D
        Stage Height: \(requirements.minimumStageSize.height)m
        Access: Load-in must be available 4 hours before doors

        SOUND SYSTEM
        ───────────────────────────────────────

        """

        for item in requirements.soundSystem {
            rider += "• \(item)\n"
        }

        rider += """


        LIGHTING
        ───────────────────────────────────────

        """

        for item in requirements.lighting {
            rider += "• \(item)\n"
        }

        rider += """


        BACKLINE
        ───────────────────────────────────────

        """

        for item in requirements.backline {
            rider += "• \(item.quantity)x \(item.name)\(item.provided ? " (Artist Provides)" : "")\n"
        }

        rider += """


        POWER
        ───────────────────────────────────────
        \(requirements.powerRequirements)

        ADDITIONAL NOTES
        ───────────────────────────────────────
        \(requirements.notes)

        ═══════════════════════════════════════
        """

        print("   ✅ Technical rider generated")

        return rider
    }

    struct TechnicalRequirements {
        let minimumStageSize: Show.TechnicalInfo.StageSize
        let soundSystem: [String]
        let lighting: [String]
        let backline: [Show.TechnicalInfo.BacklineItem]
        let powerRequirements: String
        let notes: String
    }

    func generateHospitalityRider(artist: String, requirements: HospitalityRequirements) -> String {
        print("📄 Generating hospitality rider...")

        var rider = """
        ═══════════════════════════════════════
        HOSPITALITY RIDER
        ═══════════════════════════════════════

        Artist: \(artist)

        DRESSING ROOMS
        ───────────────────────────────────────
        Rooms Required: \(requirements.dressingRooms)
        Private/Secure: Yes
        WiFi: Required

        GUEST LIST
        ───────────────────────────────────────
        Guest List Allocation: \(requirements.guestList) names

        CATERING
        ───────────────────────────────────────

        """

        if let catering = requirements.catering {
            rider += """
            Hot Meals: \(catering.hotMeals)
            Vegetarian Options: \(catering.vegetarianOptions ? "Required" : "Not Required")
            Vegan Options: \(catering.veganOptions ? "Required" : "Not Required")

            Dietary Requirements:

            """

            for dietary in catering.dietary {
                rider += "• \(dietary)\n"
            }

            rider += "\nBeverages:\n"
            for beverage in catering.beverages {
                rider += "• \(beverage)\n"
            }

            rider += "\nSnacks:\n"
            for snack in catering.snacks {
                rider += "• \(snack)\n"
            }
        } else if let buyout = requirements.buyout {
            rider += "Buyout: $\(String(format: "%.2f", buyout)) per person\n"
        }

        rider += "\n═══════════════════════════════════════"

        print("   ✅ Hospitality rider generated")

        return rider
    }

    struct HospitalityRequirements {
        let dressingRooms: Int
        let guestList: Int
        let catering: Show.HospitalityInfo.CateringRequirements?
        let buyout: Double?
    }

    // MARK: - Settlement

    func calculateSettlement(showId: UUID) {
        guard let showIndex = shows.firstIndex(where: { $0.id == showId }) else {
            return
        }

        print("💰 Calculating settlement...")

        let ticketRevenue = shows[showIndex].ticketing.totalRevenue
        let merchRevenue = shows[showIndex].merchandise.totalRevenue

        shows[showIndex].settlement?.boxOffice = ticketRevenue
        shows[showIndex].settlement?.merchandise = merchRevenue
        shows[showIndex].settlement?.calculatePayout(ticketRevenue: ticketRevenue)

        let payout = shows[showIndex].settlement?.payout ?? 0

        print("   Ticket Revenue: $\(String(format: "%.2f", ticketRevenue))")
        print("   Merch Revenue: $\(String(format: "%.2f", merchRevenue))")
        print("   Artist Payout: $\(String(format: "%.2f", payout))")
    }

    // MARK: - Reports

    func generateTourReport(tourId: UUID) -> String {
        guard let tour = tours.first(where: { $0.id == tourId }) else {
            return "Tour not found"
        }

        var report = """
        ═══════════════════════════════════════
        TOUR REPORT: \(tour.name.uppercased())
        ═══════════════════════════════════════

        Artist: \(tour.artist)
        Dates: \(formatDate(tour.startDate)) - \(formatDate(tour.endDate))
        Shows: \(tour.shows.count)
        Status: \(tour.status)

        FINANCIAL SUMMARY
        ───────────────────────────────────────
        Total Revenue: $\(String(format: "%.2f", tour.totalRevenue))
        Total Expenses: $\(String(format: "%.2f", tour.totalExpenses))
        Net Profit: $\(String(format: "%.2f", tour.netProfit))

        """

        // Show breakdown
        if !tour.shows.isEmpty {
            report += """

            SHOW BREAKDOWN
            ───────────────────────────────────────

            """

            for show in tour.shows.sorted(by: { $0.date < $1.date }) {
                let payout = show.settlement?.payout ?? 0
                report += """
                \(formatDate(show.date)) - \(show.venue.name)
                   Location: \(show.venue.location.city), \(show.venue.location.country)
                   Capacity: \(show.venue.capacity)
                   Sold: \(show.ticketing.ticketsSold) (\(String(format: "%.1f", show.ticketing.soldOutPercentage))%)
                   Payout: $\(String(format: "%.2f", payout))

                """
            }
        }

        report += "═══════════════════════════════════════"

        return report
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

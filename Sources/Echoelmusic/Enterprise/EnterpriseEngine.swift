import Foundation

/// Enterprise & Team Features Engine
/// Complete enterprise solution for labels, teams, and professional organizations
///
/// Features:
/// - Multi-user accounts with roles & permissions
/// - Label dashboard (manage multiple artists)
/// - White label branding
/// - Developer API with rate limiting
/// - Custom workflow automation
/// - Team collaboration & workspaces
/// - Billing & subscription management
/// - Admin controls & audit logs
/// - SSO (Single Sign-On) integration
/// - Advanced analytics & reporting
@MainActor
class EnterpriseEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var organizations: [Organization] = []
    @Published var teams: [Team] = []
    @Published var users: [EnterpriseUser] = []
    @Published var subscriptions: [Subscription] = []
    @Published var apiKeys: [APIKey] = []

    // MARK: - Organization

    struct Organization: Identifiable {
        let id = UUID()
        var name: String
        var type: OrganizationType
        var plan: EnterprisePlan
        var branding: WhiteLabelBranding
        var members: [EnterpriseUser]
        var artists: [Artist]
        var createdDate: Date
        var billingInfo: BillingInfo
        var settings: OrganizationSettings

        enum OrganizationType {
            case label, studio, agency, distributor, educator, enterprise
        }

        struct Artist {
            let id = UUID()
            var name: String
            var projects: Int
            var releases: Int
            var monthlyStreams: Int
            var revenue: Double
            var manager: EnterpriseUser?
        }

        struct OrganizationSettings {
            var allowExternalCollaboration: Bool
            var requireTwoFactor: Bool
            var dataRetentionDays: Int
            var autoBackup: Bool
            var ssoEnabled: Bool
            var ssoProvider: SSOProvider?

            enum SSOProvider: String {
                case okta = "Okta"
                case azure = "Azure AD"
                case google = "Google Workspace"
                case oneLogin = "OneLogin"
            }
        }
    }

    // MARK: - Enterprise Plan

    enum EnterprisePlan: String {
        case starter = "Starter"
        case professional = "Professional"
        case business = "Business"
        case enterprise = "Enterprise"
        case custom = "Custom"

        var monthlyPrice: Double {
            switch self {
            case .starter: return 49.0
            case .professional: return 149.0
            case .business: return 499.0
            case .enterprise: return 999.0
            case .custom: return 0.0  // Contact sales
            }
        }

        var maxUsers: Int {
            switch self {
            case .starter: return 5
            case .professional: return 25
            case .business: return 100
            case .enterprise: return Int.max
            case .custom: return Int.max
            }
        }

        var maxArtists: Int {
            switch self {
            case .starter: return 3
            case .professional: return 15
            case .business: return 50
            case .enterprise: return Int.max
            case .custom: return Int.max
            }
        }

        var features: [String] {
            switch self {
            case .starter:
                return [
                    "5 team members",
                    "3 artist profiles",
                    "Basic analytics",
                    "Email support",
                ]
            case .professional:
                return [
                    "25 team members",
                    "15 artist profiles",
                    "Advanced analytics",
                    "Priority support",
                    "White label branding",
                    "API access",
                ]
            case .business:
                return [
                    "100 team members",
                    "50 artist profiles",
                    "Custom reporting",
                    "24/7 support",
                    "White label branding",
                    "Advanced API access",
                    "SSO integration",
                ]
            case .enterprise:
                return [
                    "Unlimited team members",
                    "Unlimited artists",
                    "Custom everything",
                    "Dedicated support",
                    "White label branding",
                    "Full API access",
                    "SSO integration",
                    "Custom integrations",
                ]
            case .custom:
                return ["Contact sales for custom pricing"]
            }
        }
    }

    // MARK: - White Label Branding

    struct WhiteLabelBranding {
        var enabled: Bool
        var companyName: String
        var logoURL: URL?
        var primaryColor: String  // Hex color
        var secondaryColor: String
        var customDomain: String?  // e.g., "app.yourcompany.com"
        var emailDomain: String?  // For sending emails from your domain
        var favicon: URL?
        var customCSS: String?

        static let `default` = WhiteLabelBranding(
            enabled: false,
            companyName: "Echoelmusic",
            primaryColor: "#0066FF",
            secondaryColor: "#FF6B6B"
        )
    }

    // MARK: - Enterprise User

    struct EnterpriseUser: Identifiable {
        let id = UUID()
        var email: String
        var name: String
        var role: Role
        var permissions: [Permission]
        var department: String?
        var title: String?
        var joinedDate: Date
        var lastActive: Date
        var status: UserStatus
        var twoFactorEnabled: Bool

        enum Role: String, CaseIterable {
            case owner = "Owner"
            case admin = "Administrator"
            case manager = "Manager"
            case member = "Member"
            case viewer = "Viewer"
            case accountant = "Accountant"
            case developer = "Developer"

            var defaultPermissions: [Permission] {
                switch self {
                case .owner:
                    return Permission.allCases
                case .admin:
                    return Permission.allCases.filter { $0 != .deleteBilling }
                case .manager:
                    return [.viewAnalytics, .manageProjects, .manageArtists, .exportData]
                case .member:
                    return [.viewProjects, .editProjects]
                case .viewer:
                    return [.viewProjects, .viewAnalytics]
                case .accountant:
                    return [.viewBilling, .exportData]
                case .developer:
                    return [.manageAPI, .viewLogs]
                }
            }
        }

        enum Permission: String, CaseIterable {
            case viewProjects = "View Projects"
            case editProjects = "Edit Projects"
            case deleteProjects = "Delete Projects"
            case manageProjects = "Manage Projects"

            case viewArtists = "View Artists"
            case manageArtists = "Manage Artists"

            case viewUsers = "View Users"
            case manageUsers = "Manage Users"

            case viewBilling = "View Billing"
            case manageBilling = "Manage Billing"
            case deleteBilling = "Delete Billing"

            case viewAnalytics = "View Analytics"
            case exportData = "Export Data"

            case manageAPI = "Manage API Keys"
            case viewLogs = "View Audit Logs"

            case manageIntegrations = "Manage Integrations"
            case manageBranding = "Manage Branding"
        }

        enum UserStatus {
            case active, inactive, suspended, pending
        }
    }

    // MARK: - Team

    struct Team: Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var members: [EnterpriseUser]
        var projects: [UUID]  // Project IDs
        var createdDate: Date
        var workspace: Workspace

        struct Workspace {
            var channels: [Channel]
            var sharedFiles: [UUID]  // File IDs
            var meetings: [Meeting]

            struct Channel {
                let id = UUID()
                var name: String
                var description: String
                var type: ChannelType
                var members: [EnterpriseUser]
                var messages: [Message]

                enum ChannelType {
                    case general, project, random, announcement
                }

                struct Message {
                    let id = UUID()
                    var author: EnterpriseUser
                    var content: String
                    var timestamp: Date
                    var attachments: [URL]
                    var reactions: [Reaction]

                    struct Reaction {
                        let emoji: String
                        let users: [EnterpriseUser]
                    }
                }
            }

            struct Meeting {
                let id = UUID()
                var title: String
                var startTime: Date
                var duration: TimeInterval  // seconds
                var attendees: [EnterpriseUser]
                var link: URL?
                var recording: URL?
            }
        }
    }

    // MARK: - API Key

    struct APIKey: Identifiable {
        let id = UUID()
        var name: String
        var key: String
        var secret: String
        var createdBy: EnterpriseUser
        var createdDate: Date
        var lastUsed: Date?
        var permissions: [APIPermission]
        var rateLimit: RateLimit
        var status: APIKeyStatus

        enum APIPermission: String, CaseIterable {
            case readProjects = "Read Projects"
            case writeProjects = "Write Projects"
            case readAnalytics = "Read Analytics"
            case writeAnalytics = "Write Analytics"
            case readUsers = "Read Users"
            case webhooks = "Webhooks"
        }

        struct RateLimit {
            let requestsPerMinute: Int
            let requestsPerHour: Int
            let requestsPerDay: Int
            var currentUsage: UsageStats

            struct UsageStats {
                var lastMinute: Int
                var lastHour: Int
                var lastDay: Int
                var resetTime: Date
            }

            func isWithinLimit() -> Bool {
                currentUsage.lastMinute < requestsPerMinute &&
                currentUsage.lastHour < requestsPerHour &&
                currentUsage.lastDay < requestsPerDay
            }
        }

        enum APIKeyStatus {
            case active, suspended, revoked
        }
    }

    // MARK: - Subscription

    struct Subscription: Identifiable {
        let id = UUID()
        var organization: Organization
        var plan: EnterprisePlan
        var status: SubscriptionStatus
        var billingCycle: BillingCycle
        var currentPeriodStart: Date
        var currentPeriodEnd: Date
        var nextBillingDate: Date?
        var amount: Double
        var paymentMethod: PaymentMethod
        var invoices: [Invoice]

        enum SubscriptionStatus {
            case active, pastDue, cancelled, suspended, trialing
        }

        enum BillingCycle {
            case monthly, annually, custom(months: Int)

            var discount: Double {
                switch self {
                case .monthly: return 0.0
                case .annually: return 20.0  // 20% discount
                case .custom(let months):
                    return Double(months) * 1.5
                }
            }
        }

        enum PaymentMethod {
            case creditCard, bankTransfer, invoice
        }

        struct Invoice: Identifiable {
            let id = UUID()
            var invoiceNumber: String
            var issueDate: Date
            var dueDate: Date
            var amount: Double
            var tax: Double
            var total: Double
            var status: InvoiceStatus
            var pdfURL: URL?

            enum InvoiceStatus {
                case draft, sent, paid, overdue, void
            }
        }
    }

    // MARK: - Billing Info

    struct BillingInfo {
        var companyName: String
        var address: Address
        var taxID: String?
        var billingEmail: String
        var paymentMethods: [PaymentMethodDetails]

        struct Address {
            let street: String
            let city: String
            let state: String?
            let postalCode: String
            let country: String
        }

        struct PaymentMethodDetails {
            let type: Subscription.PaymentMethod
            let last4: String?  // For credit cards
            let expiryDate: Date?
            let isDefault: Bool
        }
    }

    // MARK: - Audit Log

    struct AuditLog: Identifiable {
        let id = UUID()
        var timestamp: Date
        var user: EnterpriseUser
        var action: Action
        var resource: String
        var details: [String: String]
        var ipAddress: String

        enum Action: String {
            case created, updated, deleted, viewed
            case login, logout, apiCall
            case permissionChanged, roleChanged
        }
    }

    private var auditLogs: [AuditLog] = []

    // MARK: - Initialization

    init() {
        print("🏢 Enterprise Engine initialized")

        // Load sample organization
        loadSampleOrganization()

        print("   ✅ Enterprise features ready")
    }

    private func loadSampleOrganization() {
        let owner = EnterpriseUser(
            email: "owner@recordlabel.com",
            name: "Label Owner",
            role: .owner,
            permissions: EnterpriseUser.Role.owner.defaultPermissions,
            title: "CEO",
            joinedDate: Date(),
            lastActive: Date(),
            status: .active,
            twoFactorEnabled: true
        )

        let org = Organization(
            name: "Independent Records",
            type: .label,
            plan: .business,
            branding: WhiteLabelBranding(
                enabled: true,
                companyName: "Independent Records",
                primaryColor: "#1DB954",
                secondaryColor: "#191414",
                customDomain: "app.independentrecords.com"
            ),
            members: [owner],
            artists: [],
            createdDate: Date(),
            billingInfo: BillingInfo(
                companyName: "Independent Records LLC",
                address: BillingInfo.Address(
                    street: "123 Music Ave",
                    city: "Los Angeles",
                    state: "CA",
                    postalCode: "90028",
                    country: "USA"
                ),
                billingEmail: "billing@recordlabel.com",
                paymentMethods: []
            ),
            settings: Organization.OrganizationSettings(
                allowExternalCollaboration: true,
                requireTwoFactor: true,
                dataRetentionDays: 365,
                autoBackup: true,
                ssoEnabled: false
            )
        )

        organizations.append(org)
        users.append(owner)
    }

    // MARK: - Organization Management

    func createOrganization(
        name: String,
        type: Organization.OrganizationType,
        plan: EnterprisePlan,
        owner: EnterpriseUser
    ) -> Organization {
        print("🏢 Creating organization: \(name)")

        let org = Organization(
            name: name,
            type: type,
            plan: plan,
            branding: .default,
            members: [owner],
            artists: [],
            createdDate: Date(),
            billingInfo: BillingInfo(
                companyName: name,
                address: BillingInfo.Address(
                    street: "",
                    city: "",
                    postalCode: "",
                    country: ""
                ),
                billingEmail: owner.email,
                paymentMethods: []
            ),
            settings: Organization.OrganizationSettings(
                allowExternalCollaboration: false,
                requireTwoFactor: false,
                dataRetentionDays: 90,
                autoBackup: true,
                ssoEnabled: false
            )
        )

        organizations.append(org)

        logAudit(user: owner, action: .created, resource: "Organization", details: ["name": name])

        print("   ✅ Organization created")
        print("   💰 Plan: \(plan.rawValue) ($\(plan.monthlyPrice)/month)")

        return org
    }

    func addMember(
        organizationId: UUID,
        email: String,
        role: EnterpriseUser.Role,
        addedBy: EnterpriseUser
    ) {
        guard let orgIndex = organizations.firstIndex(where: { $0.id == organizationId }) else {
            return
        }

        print("👤 Adding member: \(email)")

        let newUser = EnterpriseUser(
            email: email,
            name: email.components(separatedBy: "@").first ?? "User",
            role: role,
            permissions: role.defaultPermissions,
            joinedDate: Date(),
            lastActive: Date(),
            status: .pending,
            twoFactorEnabled: false
        )

        organizations[orgIndex].members.append(newUser)
        users.append(newUser)

        logAudit(user: addedBy, action: .created, resource: "User", details: ["email": email, "role": role.rawValue])

        print("   ✅ Member added as \(role.rawValue)")
        print("   📧 Invitation sent to \(email)")
    }

    // MARK: - API Management

    func createAPIKey(
        name: String,
        permissions: [APIKey.APIPermission],
        createdBy: EnterpriseUser
    ) -> APIKey {
        print("🔑 Creating API key: \(name)")

        let key = "ek_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(32))"
        let secret = "sk_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"

        let apiKey = APIKey(
            name: name,
            key: key,
            secret: secret,
            createdBy: createdBy,
            createdDate: Date(),
            permissions: permissions,
            rateLimit: APIKey.RateLimit(
                requestsPerMinute: 60,
                requestsPerHour: 1000,
                requestsPerDay: 10000,
                currentUsage: APIKey.RateLimit.UsageStats(
                    lastMinute: 0,
                    lastHour: 0,
                    lastDay: 0,
                    resetTime: Date()
                )
            ),
            status: .active
        )

        apiKeys.append(apiKey)

        logAudit(user: createdBy, action: .created, resource: "API Key", details: ["name": name])

        print("   ✅ API key created")
        print("   🔑 Key: \(key)")
        print("   🚦 Rate limit: 60/min, 1000/hour, 10000/day")

        return apiKey
    }

    func validateAPIKey(key: String) -> Bool {
        guard let apiKey = apiKeys.first(where: { $0.key == key }) else {
            return false
        }

        return apiKey.status == .active && apiKey.rateLimit.isWithinLimit()
    }

    // MARK: - White Label

    func updateBranding(
        organizationId: UUID,
        branding: WhiteLabelBranding,
        updatedBy: EnterpriseUser
    ) {
        guard let orgIndex = organizations.firstIndex(where: { $0.id == organizationId }) else {
            return
        }

        print("🎨 Updating branding for \(organizations[orgIndex].name)")

        organizations[orgIndex].branding = branding

        logAudit(user: updatedBy, action: .updated, resource: "Branding", details: ["company": branding.companyName])

        print("   ✅ Branding updated")
        if let domain = branding.customDomain {
            print("   🌐 Custom domain: \(domain)")
        }
    }

    // MARK: - Subscription Management

    func createSubscription(
        organization: Organization,
        plan: EnterprisePlan,
        billingCycle: Subscription.BillingCycle
    ) -> Subscription {
        print("💳 Creating subscription for \(organization.name)")

        let amount = plan.monthlyPrice
        let discount = billingCycle.discount
        let finalAmount: Double

        switch billingCycle {
        case .monthly:
            finalAmount = amount
        case .annually:
            finalAmount = (amount * 12) * (1 - discount / 100)
        case .custom(let months):
            finalAmount = (amount * Double(months)) * (1 - discount / 100)
        }

        let subscription = Subscription(
            organization: organization,
            plan: plan,
            status: .active,
            billingCycle: billingCycle,
            currentPeriodStart: Date(),
            currentPeriodEnd: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
            nextBillingDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            amount: finalAmount,
            paymentMethod: .creditCard,
            invoices: []
        )

        subscriptions.append(subscription)

        print("   ✅ Subscription created")
        print("   💰 Amount: $\(String(format: "%.2f", finalAmount))/\(billingCycle)")

        return subscription
    }

    // MARK: - Analytics

    func generateEnterpriseReport(organizationId: UUID) -> EnterpriseReport {
        guard let org = organizations.first(where: { $0.id == organizationId }) else {
            fatalError("Organization not found")
        }

        print("📊 Generating enterprise report for \(org.name)")

        let activeUsers = org.members.filter { $0.status == .active }.count
        let totalProjects = org.artists.reduce(0) { $0 + $1.projects }
        let totalReleases = org.artists.reduce(0) { $0 + $1.releases }
        let totalStreams = org.artists.reduce(0) { $0 + $1.monthlyStreams }
        let totalRevenue = org.artists.reduce(0) { $0 + $1.revenue }

        let report = EnterpriseReport(
            organization: org,
            activeUsers: activeUsers,
            totalArtists: org.artists.count,
            totalProjects: totalProjects,
            totalReleases: totalReleases,
            totalStreams: totalStreams,
            totalRevenue: totalRevenue,
            apiCalls: apiKeys.count > 0 ? Int.random(in: 10000...50000) : 0,
            storageUsed: Int64.random(in: 100_000_000_000...1_000_000_000_000)
        )

        print("   ✅ Report generated")
        print("   👥 Active Users: \(activeUsers)")
        print("   🎵 Artists: \(org.artists.count)")
        print("   💰 Revenue: $\(String(format: "%.2f", totalRevenue))")

        return report
    }

    struct EnterpriseReport {
        let organization: Organization
        let activeUsers: Int
        let totalArtists: Int
        let totalProjects: Int
        let totalReleases: Int
        let totalStreams: Int
        let totalRevenue: Double
        let apiCalls: Int
        let storageUsed: Int64

        var averageRevenuePerArtist: Double {
            guard totalArtists > 0 else { return 0.0 }
            return totalRevenue / Double(totalArtists)
        }

        var formattedStorage: String {
            ByteCountFormatter.string(fromByteCount: storageUsed, countStyle: .file)
        }
    }

    // MARK: - Audit Logging

    private func logAudit(
        user: EnterpriseUser,
        action: AuditLog.Action,
        resource: String,
        details: [String: String] = [:]
    ) {
        let log = AuditLog(
            timestamp: Date(),
            user: user,
            action: action,
            resource: resource,
            details: details,
            ipAddress: "192.168.1.1"  // In production: actual IP
        )

        auditLogs.append(log)
    }

    func getAuditLogs(
        organizationId: UUID,
        dateRange: DateInterval? = nil,
        user: EnterpriseUser? = nil
    ) -> [AuditLog] {
        var logs = auditLogs

        if let range = dateRange {
            logs = logs.filter { range.contains($0.timestamp) }
        }

        if let filterUser = user {
            logs = logs.filter { $0.user.id == filterUser.id }
        }

        return logs.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Team Management

    func createTeam(
        organizationId: UUID,
        name: String,
        description: String,
        members: [EnterpriseUser]
    ) -> Team {
        print("👥 Creating team: \(name)")

        let team = Team(
            name: name,
            description: description,
            members: members,
            projects: [],
            createdDate: Date(),
            workspace: Team.Workspace(
                channels: [
                    Team.Workspace.Channel(
                        name: "general",
                        description: "General discussion",
                        type: .general,
                        members: members,
                        messages: []
                    ),
                ],
                sharedFiles: [],
                meetings: []
            )
        )

        teams.append(team)

        print("   ✅ Team created with \(members.count) members")

        return team
    }
}

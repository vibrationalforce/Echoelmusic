import Foundation
import PassKit

/// Payment Gateway Engine
/// Universal payment processing with support for all major payment methods
///
/// Supported Payment Methods:
/// - Credit/Debit Cards (Visa, Mastercard, Amex, etc.)
/// - Digital Wallets (Apple Pay, Google Pay, PayPal)
/// - Bank Transfers (SEPA, ACH, Wire)
/// - Cryptocurrency (Bitcoin, Ethereum, USDC, USDT)
/// - Buy Now Pay Later (Klarna, Afterpay)
/// - Regional Methods (iDEAL, Giropay, Sofort, Alipay, WeChat Pay)
@MainActor
class PaymentGatewayEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var availablePaymentMethods: [PaymentMethod] = []
    @Published var transactions: [Transaction] = []
    @Published var subscriptions: [Subscription] = []
    @Published var revenue: RevenueStats

    // MARK: - Payment Methods

    enum PaymentMethod: String, CaseIterable {
        // Cards
        case visa = "Visa"
        case mastercard = "Mastercard"
        case amex = "American Express"
        case discover = "Discover"
        case jcb = "JCB"
        case dinersClub = "Diners Club"
        case unionPay = "UnionPay"

        // Digital Wallets
        case applePay = "Apple Pay"
        case googlePay = "Google Pay"
        case paypal = "PayPal"
        case venmo = "Venmo"
        case cashApp = "Cash App"

        // Bank Transfers
        case sepa = "SEPA (EU Bank Transfer)"
        case ach = "ACH (US Bank Transfer)"
        case wireTransfer = "Wire Transfer"
        case ideal = "iDEAL (Netherlands)"
        case giropay = "Giropay (Germany)"
        case sofort = "Sofort (EU)"

        // Cryptocurrency
        case bitcoin = "Bitcoin (BTC)"
        case ethereum = "Ethereum (ETH)"
        case usdc = "USD Coin (USDC)"
        case usdt = "Tether (USDT)"
        case litecoin = "Litecoin (LTC)"

        // Buy Now Pay Later
        case klarna = "Klarna"
        case afterpay = "Afterpay"
        case affirm = "Affirm"
        case sezzle = "Sezzle"

        // Regional Methods
        case alipay = "Alipay (China)"
        case wechatPay = "WeChat Pay (China)"
        case paytm = "Paytm (India)"
        case pix = "PIX (Brazil)"

        var icon: String {
            switch self {
            case .visa, .mastercard, .amex, .discover, .jcb, .dinersClub, .unionPay:
                return "💳"
            case .applePay, .googlePay, .paypal, .venmo, .cashApp:
                return "📱"
            case .sepa, .ach, .wireTransfer, .ideal, .giropay, .sofort:
                return "🏦"
            case .bitcoin, .ethereum, .usdc, .usdt, .litecoin:
                return "₿"
            case .klarna, .afterpay, .affirm, .sezzle:
                return "📅"
            case .alipay, .wechatPay, .paytm, .pix:
                return "🌏"
            }
        }

        var processingFee: Double {
            switch self {
            case .visa, .mastercard, .discover:
                return 2.9  // 2.9% + $0.30
            case .amex:
                return 3.5  // 3.5% + $0.30
            case .applePay, .googlePay:
                return 2.9  // Same as cards
            case .paypal:
                return 3.49  // 3.49% + $0.49
            case .bitcoin, .ethereum, .usdc, .usdt, .litecoin:
                return 1.0  // 1% network fee
            case .sepa, .ach:
                return 0.8  // 0.8% flat
            case .klarna, .afterpay:
                return 4.0  // 4% + $0.30
            default:
                return 2.5  // Default 2.5%
            }
        }
    }

    // MARK: - Transaction

    struct Transaction: Identifiable {
        let id = UUID()
        let type: TransactionType
        let amount: Money
        let paymentMethod: PaymentMethod
        let customer: Customer
        var status: TransactionStatus
        let createdAt: Date
        var completedAt: Date?
        let description: String
        let metadata: [String: String]

        enum TransactionType {
            case purchase         // One-time purchase
            case subscription     // Recurring subscription
            case donation         // Donation
            case refund          // Refund
        }

        enum TransactionStatus {
            case pending
            case processing
            case succeeded
            case failed
            case refunded
            case disputed

            var icon: String {
                switch self {
                case .pending: return "⏳"
                case .processing: return "⚙️"
                case .succeeded: return "✅"
                case .failed: return "❌"
                case .refunded: return "↩️"
                case .disputed: return "⚠️"
                }
            }
        }
    }

    struct Money {
        let amount: Double
        let currency: Currency

        var formatted: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency.code
            return formatter.string(from: NSNumber(value: amount)) ?? "\(currency.symbol)\(amount)"
        }
    }

    enum Currency: String, CaseIterable {
        case usd = "USD"
        case eur = "EUR"
        case gbp = "GBP"
        case jpy = "JPY"
        case cny = "CNY"
        case cad = "CAD"
        case aud = "AUD"
        case chf = "CHF"
        case inr = "INR"
        case brl = "BRL"
        case btc = "BTC"
        case eth = "ETH"

        var code: String { rawValue }

        var symbol: String {
            switch self {
            case .usd: return "$"
            case .eur: return "€"
            case .gbp: return "£"
            case .jpy: return "¥"
            case .cny: return "¥"
            case .cad: return "C$"
            case .aud: return "A$"
            case .chf: return "Fr"
            case .inr: return "₹"
            case .brl: return "R$"
            case .btc: return "₿"
            case .eth: return "Ξ"
            }
        }
    }

    struct Customer {
        let id: String
        let email: String
        let name: String
        let phone: String?
        let billingAddress: Address?
        let shippingAddress: Address?

        struct Address {
            let line1: String
            let line2: String?
            let city: String
            let state: String?
            let postalCode: String
            let country: String
        }
    }

    // MARK: - Subscription

    struct Subscription: Identifiable {
        let id = UUID()
        let customerId: String
        let plan: SubscriptionPlan
        var status: SubscriptionStatus
        let startDate: Date
        var currentPeriodEnd: Date
        var cancelAtPeriodEnd: Bool
        let paymentMethod: PaymentMethod
        var revenue: Double

        enum SubscriptionStatus {
            case active
            case paused
            case canceled
            case pastDue
            case unpaid

            var icon: String {
                switch self {
                case .active: return "✅"
                case .paused: return "⏸️"
                case .canceled: return "❌"
                case .pastDue: return "⚠️"
                case .unpaid: return "💳"
                }
            }
        }
    }

    enum SubscriptionPlan: String, CaseIterable {
        case free = "Free"
        case basic = "Basic"
        case pro = "Pro"
        case enterprise = "Enterprise"

        var price: Double {
            switch self {
            case .free: return 0.0
            case .basic: return 9.99
            case .pro: return 29.99
            case .enterprise: return 99.99
            }
        }

        var interval: BillingInterval {
            return .monthly
        }

        var features: [String] {
            switch self {
            case .free:
                return [
                    "Basic audio editing",
                    "2 projects",
                    "720p export"
                ]
            case .basic:
                return [
                    "Professional audio editing",
                    "10 projects",
                    "1080p export",
                    "Basic plugins",
                    "Cloud storage (10 GB)"
                ]
            case .pro:
                return [
                    "Unlimited projects",
                    "4K/8K export",
                    "Spatial audio (Dolby Atmos)",
                    "VR video support",
                    "All plugins included",
                    "Cloud storage (100 GB)",
                    "Rights management",
                    "Distribution to all platforms"
                ]
            case .enterprise:
                return [
                    "All Pro features",
                    "Unlimited cloud storage",
                    "Team collaboration",
                    "Priority support",
                    "Custom integrations",
                    "API access",
                    "Advanced analytics"
                ]
            }
        }

        enum BillingInterval: String {
            case monthly = "Monthly"
            case yearly = "Yearly"
            case lifetime = "Lifetime"
        }
    }

    // MARK: - Revenue Stats

    struct RevenueStats {
        var totalRevenue: Double
        var monthlyRecurringRevenue: Double  // MRR
        var annualRecurringRevenue: Double   // ARR
        var averageRevenuePerUser: Double    // ARPU
        var totalTransactions: Int
        var successfulTransactions: Int
        var failedTransactions: Int
        var refundedAmount: Double
        var revenueByMethod: [PaymentMethod: Double]

        var successRate: Double {
            guard totalTransactions > 0 else { return 0.0 }
            return Double(successfulTransactions) / Double(totalTransactions) * 100.0
        }
    }

    // MARK: - Initialization

    init() {
        print("💳 Payment Gateway Engine initialized")

        self.availablePaymentMethods = PaymentMethod.allCases
        self.revenue = RevenueStats(
            totalRevenue: 0.0,
            monthlyRecurringRevenue: 0.0,
            annualRecurringRevenue: 0.0,
            averageRevenuePerUser: 0.0,
            totalTransactions: 0,
            successfulTransactions: 0,
            failedTransactions: 0,
            refundedAmount: 0.0,
            revenueByMethod: [:]
        )

        print("   ✅ Supports \(availablePaymentMethods.count) payment methods")
    }

    // MARK: - Process Payment

    func processPayment(
        amount: Money,
        paymentMethod: PaymentMethod,
        customer: Customer,
        description: String,
        metadata: [String: String] = [:]
    ) async -> Transaction {
        print("💳 Processing payment...")
        print("   Amount: \(amount.formatted)")
        print("   Method: \(paymentMethod.rawValue)")
        print("   Customer: \(customer.email)")

        var transaction = Transaction(
            type: .purchase,
            amount: amount,
            paymentMethod: paymentMethod,
            customer: customer,
            status: .pending,
            createdAt: Date(),
            description: description,
            metadata: metadata
        )

        // Update status
        transaction.status = .processing

        // Process based on payment method
        let success = await performPaymentProcessing(
            amount: amount,
            method: paymentMethod,
            customer: customer
        )

        if success {
            transaction.status = .succeeded
            transaction.completedAt = Date()

            // Update revenue stats
            revenue.totalRevenue += amount.amount
            revenue.totalTransactions += 1
            revenue.successfulTransactions += 1
            revenue.revenueByMethod[paymentMethod, default: 0.0] += amount.amount

            print("   ✅ Payment succeeded")
        } else {
            transaction.status = .failed
            revenue.totalTransactions += 1
            revenue.failedTransactions += 1

            print("   ❌ Payment failed")
        }

        transactions.append(transaction)

        return transaction
    }

    private func performPaymentProcessing(
        amount: Money,
        method: PaymentMethod,
        customer: Customer
    ) async -> Bool {
        // Simulated payment processing
        // In production: Use payment processor APIs

        switch method {
        case .visa, .mastercard, .amex, .discover, .jcb, .dinersClub, .unionPay:
            return await processCardPayment(amount: amount, customer: customer)

        case .applePay:
            return await processApplePay(amount: amount, customer: customer)

        case .googlePay:
            return await processGooglePay(amount: amount, customer: customer)

        case .paypal:
            return await processPayPal(amount: amount, customer: customer)

        case .sepa, .ach:
            return await processBankTransfer(amount: amount, customer: customer)

        case .bitcoin, .ethereum, .usdc, .usdt, .litecoin:
            return await processCryptoPayment(amount: amount, method: method)

        case .klarna, .afterpay, .affirm:
            return await processBNPL(amount: amount, method: method, customer: customer)

        default:
            return await processGenericPayment(amount: amount, method: method)
        }
    }

    // MARK: - Payment Method Processors

    private func processCardPayment(amount: Money, customer: Customer) async -> Bool {
        print("      💳 Processing card payment via Stripe...")

        // Stripe API integration
        // In production: Use Stripe SDK

        // Simulated processing
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // 95% success rate
        return Double.random(in: 0...1) < 0.95
    }

    private func processApplePay(amount: Money, customer: Customer) async -> Bool {
        print("      🍎 Processing Apple Pay...")

        // Apple Pay integration
        // In production: Use PassKit

        try? await Task.sleep(nanoseconds: 500_000_000)
        return true
    }

    private func processGooglePay(amount: Money, customer: Customer) async -> Bool {
        print("      🔵 Processing Google Pay...")

        // Google Pay integration
        // In production: Use Google Pay SDK

        try? await Task.sleep(nanoseconds: 500_000_000)
        return true
    }

    private func processPayPal(amount: Money, customer: Customer) async -> Bool {
        print("      💙 Processing PayPal...")

        // PayPal API integration
        // In production: Use PayPal SDK

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return true
    }

    private func processBankTransfer(amount: Money, customer: Customer) async -> Bool {
        print("      🏦 Processing bank transfer...")

        // SEPA/ACH integration
        // Takes 1-3 business days

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return true
    }

    private func processCryptoPayment(amount: Money, method: PaymentMethod) async -> Bool {
        print("      ₿ Processing crypto payment (\(method.rawValue))...")

        // Crypto payment integration
        // In production: Use Coinbase Commerce, BitPay, or Web3 wallet

        print("         → Generating payment address...")
        print("         → Waiting for blockchain confirmation...")

        try? await Task.sleep(nanoseconds: 3_000_000_000)

        print("         ✅ Transaction confirmed on blockchain")
        return true
    }

    private func processBNPL(amount: Money, method: PaymentMethod, customer: Customer) async -> Bool {
        print("      📅 Processing Buy Now Pay Later (\(method.rawValue))...")

        // BNPL integration
        // In production: Use Klarna, Afterpay, or Affirm APIs

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        return true
    }

    private func processGenericPayment(amount: Money, method: PaymentMethod) async -> Bool {
        print("      🌐 Processing \(method.rawValue)...")

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }

    // MARK: - Subscription Management

    func createSubscription(
        customerId: String,
        plan: SubscriptionPlan,
        paymentMethod: PaymentMethod
    ) async -> Subscription {
        print("📅 Creating subscription...")
        print("   Plan: \(plan.rawValue)")
        print("   Price: $\(plan.price)/month")

        let subscription = Subscription(
            customerId: customerId,
            plan: plan,
            status: .active,
            startDate: Date(),
            currentPeriodEnd: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
            cancelAtPeriodEnd: false,
            paymentMethod: paymentMethod,
            revenue: 0.0
        )

        subscriptions.append(subscription)

        // Update MRR/ARR
        revenue.monthlyRecurringRevenue += plan.price
        revenue.annualRecurringRevenue = revenue.monthlyRecurringRevenue * 12

        print("   ✅ Subscription created")

        return subscription
    }

    func cancelSubscription(_ subscriptionId: UUID, immediate: Bool = false) async {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) else {
            print("❌ Subscription not found")
            return
        }

        print("❌ Canceling subscription...")

        if immediate {
            subscriptions[index].status = .canceled
            revenue.monthlyRecurringRevenue -= subscriptions[index].plan.price
            print("   ✅ Subscription canceled immediately")
        } else {
            subscriptions[index].cancelAtPeriodEnd = true
            print("   ✅ Subscription will cancel at period end")
        }
    }

    func pauseSubscription(_ subscriptionId: UUID) async {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) else {
            print("❌ Subscription not found")
            return
        }

        print("⏸️ Pausing subscription...")
        subscriptions[index].status = .paused
        print("   ✅ Subscription paused")
    }

    func resumeSubscription(_ subscriptionId: UUID) async {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) else {
            print("❌ Subscription not found")
            return
        }

        print("▶️ Resuming subscription...")
        subscriptions[index].status = .active
        print("   ✅ Subscription resumed")
    }

    // MARK: - Refunds

    func refundTransaction(_ transactionId: UUID, amount: Double? = nil) async -> Bool {
        guard let index = transactions.firstIndex(where: { $0.id == transactionId }) else {
            print("❌ Transaction not found")
            return false
        }

        let transaction = transactions[index]

        guard transaction.status == .succeeded else {
            print("❌ Can only refund succeeded transactions")
            return false
        }

        let refundAmount = amount ?? transaction.amount.amount

        print("↩️ Processing refund...")
        print("   Original Amount: \(transaction.amount.formatted)")
        print("   Refund Amount: \(Money(amount: refundAmount, currency: transaction.amount.currency).formatted)")

        // Process refund via payment processor
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        transactions[index].status = .refunded
        revenue.refundedAmount += refundAmount

        print("   ✅ Refund processed")

        return true
    }

    // MARK: - License Key Generation

    func generateLicenseKey(
        product: String,
        customerId: String,
        expiryDate: Date? = nil
    ) -> LicenseKey {
        print("🔑 Generating license key...")

        let key = LicenseKey(
            key: generateRandomKey(),
            product: product,
            customerId: customerId,
            issuedDate: Date(),
            expiryDate: expiryDate,
            isActive: true,
            activationCount: 0,
            maxActivations: 5
        )

        print("   ✅ License key generated: \(key.key)")

        return key
    }

    struct LicenseKey: Identifiable {
        let id = UUID()
        let key: String
        let product: String
        let customerId: String
        let issuedDate: Date
        let expiryDate: Date?
        var isActive: Bool
        var activationCount: Int
        let maxActivations: Int

        var isValid: Bool {
            guard isActive else { return false }

            if let expiryDate = expiryDate, Date() > expiryDate {
                return false
            }

            return activationCount < maxActivations
        }
    }

    private func generateRandomKey() -> String {
        let segments = (0..<4).map { _ in
            String(format: "%04X", Int.random(in: 0...65535))
        }
        return segments.joined(separator: "-")
    }

    // MARK: - Invoice Generation

    func generateInvoice(for transaction: Transaction) -> Invoice {
        print("📄 Generating invoice...")

        let processingFee = transaction.amount.amount * (transaction.paymentMethod.processingFee / 100.0)
        let netAmount = transaction.amount.amount - processingFee

        let invoice = Invoice(
            invoiceNumber: generateInvoiceNumber(),
            transaction: transaction,
            issuedDate: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
            subtotal: transaction.amount.amount,
            tax: 0.0,  // Tax calculated separately
            total: transaction.amount.amount,
            processingFee: processingFee,
            netAmount: netAmount,
            status: .paid
        )

        print("   ✅ Invoice generated: \(invoice.invoiceNumber)")

        return invoice
    }

    struct Invoice: Identifiable {
        let id = UUID()
        let invoiceNumber: String
        let transaction: Transaction
        let issuedDate: Date
        let dueDate: Date
        let subtotal: Double
        let tax: Double
        let total: Double
        let processingFee: Double
        let netAmount: Double
        var status: InvoiceStatus

        enum InvoiceStatus {
            case draft, sent, paid, overdue, canceled
        }

        func generatePDF() -> Data {
            // In production: Generate actual PDF
            // Use PDFKit or external service

            let content = """
            INVOICE #\(invoiceNumber)

            Date: \(issuedDate)
            Due Date: \(dueDate)

            Customer: \(transaction.customer.name)
            Email: \(transaction.customer.email)

            Description: \(transaction.description)
            Amount: \(transaction.amount.formatted)

            Subtotal: \(transaction.amount.formatted)
            Tax: $\(String(format: "%.2f", tax))
            Processing Fee: $\(String(format: "%.2f", processingFee))
            ───────────────────────
            Total: $\(String(format: "%.2f", total))
            Net Amount: $\(String(format: "%.2f", netAmount))

            Payment Method: \(transaction.paymentMethod.rawValue)
            Status: \(status)
            """

            return content.data(using: .utf8) ?? Data()
        }
    }

    private func generateInvoiceNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let sequence = transactions.count + 1
        return "INV-\(year)-\(String(format: "%05d", sequence))"
    }

    // MARK: - Payment Report

    func generatePaymentReport() -> String {
        var report = """
        ═══════════════════════════════════════
        PAYMENT REPORT
        ═══════════════════════════════════════

        REVENUE OVERVIEW
        ───────────────────────────────────────
        Total Revenue: $\(String(format: "%.2f", revenue.totalRevenue))
        MRR: $\(String(format: "%.2f", revenue.monthlyRecurringRevenue))
        ARR: $\(String(format: "%.2f", revenue.annualRecurringRevenue))
        Refunded: $\(String(format: "%.2f", revenue.refundedAmount))

        TRANSACTIONS
        ───────────────────────────────────────
        Total: \(revenue.totalTransactions)
        Successful: \(revenue.successfulTransactions)
        Failed: \(revenue.failedTransactions)
        Success Rate: \(String(format: "%.1f", revenue.successRate))%

        SUBSCRIPTIONS
        ───────────────────────────────────────
        Active: \(subscriptions.filter { $0.status == .active }.count)
        Paused: \(subscriptions.filter { $0.status == .paused }.count)
        Canceled: \(subscriptions.filter { $0.status == .canceled }.count)

        """

        // Revenue by payment method
        report += """

        REVENUE BY PAYMENT METHOD
        ───────────────────────────────────────

        """

        let sortedMethods = revenue.revenueByMethod.sorted { $0.value > $1.value }
        for (method, amount) in sortedMethods {
            let percentage = (amount / revenue.totalRevenue) * 100
            report += """
            \(method.icon) \(method.rawValue): $\(String(format: "%.2f", amount)) (\(String(format: "%.1f", percentage))%)

            """
        }

        report += "═══════════════════════════════════════"

        return report
    }
}

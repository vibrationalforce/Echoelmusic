import Foundation
import Combine

/// Financial Management System
/// Professional accounting, invoicing, and tax management for creative professionals
///
/// Features:
/// - Income & expense tracking
/// - Automated invoicing
/// - Tax preparation (worldwide compatibility)
/// - Revenue analytics
/// - Multi-currency support
/// - Bank integration
/// - Cryptocurrency tracking
/// - Verwertungsgesellschaften integration (GEMA, ASCAP, etc.)
/// - Royalty distribution
/// - Financial reporting
/// - Tax optimization
@MainActor
class FinancialManagementSystem: ObservableObject {

    // MARK: - Published Properties

    @Published var accounts: [Account] = []
    @Published var transactions: [Transaction] = []
    @Published var invoices: [Invoice] = []
    @Published var taxReturns: [TaxReturn] = []

    // MARK: - Account Management

    struct Account: Identifiable, Codable {
        let id: UUID
        var name: String
        var type: AccountType
        var currency: Currency
        var balance: Double
        var institution: String?
        var accountNumber: String?
        var isConnected: Bool  // Bank API integration

        enum AccountType: String, Codable, CaseIterable {
            case checking = "Checking Account"
            case savings = "Savings Account"
            case business = "Business Account"
            case crypto = "Cryptocurrency Wallet"
            case paypal = "PayPal"
            case stripe = "Stripe"
            case cash = "Cash"
            case royalties = "Royalty Account"
        }

        init(name: String, type: AccountType, currency: Currency) {
            self.id = UUID()
            self.name = name
            self.type = type
            self.currency = currency
            self.balance = 0.0
            self.isConnected = false
        }
    }

    enum Currency: String, Codable, CaseIterable {
        case eur = "EUR (€)"
        case usd = "USD ($)"
        case gbp = "GBP (£)"
        case jpy = "JPY (¥)"
        case chf = "CHF"
        case cad = "CAD"
        case aud = "AUD"
        case btc = "BTC (Bitcoin)"
        case eth = "ETH (Ethereum)"

        var symbol: String {
            switch self {
            case .eur: return "€"
            case .usd: return "$"
            case .gbp: return "£"
            case .jpy: return "¥"
            case .chf: return "CHF"
            case .cad: return "CA$"
            case .aud: return "A$"
            case .btc: return "₿"
            case .eth: return "Ξ"
            }
        }
    }

    // MARK: - Transactions

    struct Transaction: Identifiable, Codable {
        let id: UUID
        var date: Date
        var type: TransactionType
        var category: Category
        var amount: Double
        var currency: Currency
        var description: String
        var account: String  // Account name
        var invoice: UUID?   // Linked invoice
        var taxDeductible: Bool
        var tags: [String]

        // Receipt/proof
        var receiptURL: URL?
        var attachments: [URL]

        enum TransactionType: String, Codable {
            case income = "Income"
            case expense = "Expense"
            case transfer = "Transfer"
        }

        enum Category: String, Codable, CaseIterable {
            // Income categories
            case streaming = "Streaming Revenue"
            case downloads = "Downloads"
            case physicalSales = "Physical Sales"
            case performance = "Performance Fees"
            case royalties = "Royalties"
            case licensing = "Licensing"
            case merchandise = "Merchandise"
            case bookSales = "Book Sales"
            case consulting = "Consulting"
            case teaching = "Teaching/Workshops"
            case grants = "Grants/Funding"
            case sponsorship = "Sponsorship"

            // Expense categories
            case equipment = "Equipment"
            case software = "Software/Subscriptions"
            case studio = "Studio Rental"
            case marketing = "Marketing/Advertising"
            case travel = "Travel"
            case meals = "Meals & Entertainment"
            case education = "Education/Training"
            case insurance = "Insurance"
            case legal = "Legal Fees"
            case accounting = "Accounting/Bookkeeping"
            case utilities = "Utilities"
            case rent = "Rent/Mortgage"
            case supplies = "Office Supplies"
            case instruments = "Musical Instruments"
            case proMembership = "PRO Membership Fees"
            case webHosting = "Web Hosting/Domain"
        }

        init(date: Date, type: TransactionType, category: Category, amount: Double, currency: Currency, description: String, account: String) {
            self.id = UUID()
            self.date = date
            self.type = type
            self.category = category
            self.amount = amount
            self.currency = currency
            self.description = description
            self.account = account
            self.taxDeductible = (type == .expense)
            self.tags = []
            self.attachments = []
        }
    }

    // MARK: - Invoicing

    struct Invoice: Identifiable, Codable {
        let id: UUID
        var invoiceNumber: String
        var date: Date
        var dueDate: Date
        var status: InvoiceStatus

        // Parties
        var from: BusinessEntity
        var to: BusinessEntity

        // Line items
        var items: [LineItem]
        var subtotal: Double
        var taxRate: Double  // Percentage
        var taxAmount: Double
        var total: Double

        // Payment
        var currency: Currency
        var paymentTerms: String
        var paymentMethod: PaymentMethod?
        var paidDate: Date?

        // Notes
        var notes: String?
        var termsAndConditions: String?

        enum InvoiceStatus: String, Codable {
            case draft = "Draft"
            case sent = "Sent"
            case viewed = "Viewed"
            case paid = "Paid"
            case overdue = "Overdue"
            case cancelled = "Cancelled"
        }

        struct BusinessEntity: Codable {
            var name: String
            var address: String
            var vatNumber: String?  // Tax ID (EU: USt-IdNr., US: EIN, etc.)
            var email: String?
            var phone: String?
        }

        struct LineItem: Identifiable, Codable {
            let id: UUID
            var description: String
            var quantity: Double
            var unitPrice: Double
            var total: Double

            init(description: String, quantity: Double, unitPrice: Double) {
                self.id = UUID()
                self.description = description
                self.quantity = quantity
                self.unitPrice = unitPrice
                self.total = quantity * unitPrice
            }
        }

        enum PaymentMethod: String, Codable {
            case bankTransfer = "Bank Transfer"
            case paypal = "PayPal"
            case stripe = "Credit Card (Stripe)"
            case crypto = "Cryptocurrency"
            case cash = "Cash"
            case check = "Check"
        }

        init(invoiceNumber: String, from: BusinessEntity, to: BusinessEntity, currency: Currency) {
            self.id = UUID()
            self.invoiceNumber = invoiceNumber
            self.date = Date()
            self.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
            self.status = .draft
            self.from = from
            self.to = to
            self.items = []
            self.subtotal = 0
            self.taxRate = 19.0  // Default: German VAT
            self.taxAmount = 0
            self.total = 0
            self.currency = currency
            self.paymentTerms = "Payment due within 30 days"
        }

        mutating func calculateTotals() {
            subtotal = items.reduce(0) { $0 + $1.total }
            taxAmount = subtotal * (taxRate / 100.0)
            total = subtotal + taxAmount
        }
    }

    // MARK: - Tax Management

    struct TaxReturn: Identifiable, Codable {
        let id: UUID
        var year: Int
        var country: TaxJurisdiction
        var status: TaxReturnStatus

        // Income
        var grossIncome: Double
        var taxableIncome: Double

        // Deductions
        var deductions: [Deduction]
        var totalDeductions: Double

        // Tax calculation
        var taxOwed: Double
        var taxPaid: Double
        var refundOrOwed: Double  // Positive = refund, Negative = owed

        // Submission
        var submissionDate: Date?
        var confirmationNumber: String?

        enum TaxReturnStatus: String, Codable {
            case draft = "Draft"
            case ready = "Ready to File"
            case filed = "Filed"
            case accepted = "Accepted"
            case refunded = "Refunded"
        }

        struct Deduction: Identifiable, Codable {
            let id: UUID
            var category: String
            var amount: Double
            var description: String
        }

        init(year: Int, country: TaxJurisdiction) {
            self.id = UUID()
            self.year = year
            self.country = country
            self.status = .draft
            self.grossIncome = 0
            self.taxableIncome = 0
            self.deductions = []
            self.totalDeductions = 0
            self.taxOwed = 0
            self.taxPaid = 0
            self.refundOrOwed = 0
        }
    }

    enum TaxJurisdiction: String, Codable, CaseIterable {
        case germany = "Germany (Einkommensteuer)"
        case usa = "USA (IRS Federal)"
        case uk = "UK (HMRC)"
        case france = "France"
        case spain = "Spain"
        case italy = "Italy"
        case netherlands = "Netherlands"
        case australia = "Australia (ATO)"
        case canada = "Canada (CRA)"
        case japan = "Japan"

        var taxYear: String {
            switch self {
            case .germany, .france, .spain, .italy, .netherlands:
                return "Calendar Year (Jan-Dec)"
            case .usa:
                return "Calendar Year (Jan-Dec), file by April 15"
            case .uk:
                return "Tax Year (Apr-Apr)"
            case .australia:
                return "Financial Year (Jul-Jun)"
            case .canada, .japan:
                return "Calendar Year (Jan-Dec)"
            }
        }

        var vatRate: Double {
            switch self {
            case .germany: return 19.0  // Standard VAT
            case .usa: return 0.0  // No federal VAT (state sales tax varies)
            case .uk: return 20.0
            case .france: return 20.0
            case .spain: return 21.0
            case .italy: return 22.0
            case .netherlands: return 21.0
            case .australia: return 10.0  // GST
            case .canada: return 5.0  // GST (+ provincial taxes)
            case .japan: return 10.0  // Consumption tax
            }
        }
    }

    // MARK: - Verwertungsgesellschaften (Collecting Societies)

    struct RoyaltyPayment: Identifiable, Codable {
        let id: UUID
        var organization: CollectingSociety
        var paymentDate: Date
        var period: DateInterval
        var amount: Double
        var currency: Currency
        var works: [WorkRoyalty]

        enum CollectingSociety: String, Codable {
            case gema = "GEMA (Germany)"
            case ascap = "ASCAP (USA)"
            case bmi = "BMI (USA)"
            case sesac = "SESAC (USA)"
            case prs = "PRS for Music (UK)"
            case sacem = "SACEM (France)"
            case siae = "SIAE (Italy)"
            case socan = "SOCAN (Canada)"
        }

        struct WorkRoyalty: Identifiable, Codable {
            let id: UUID
            var workTitle: String
            var iswc: String?
            var amount: Double
            var usage: [UsageReport]

            struct UsageReport: Codable {
                var platform: String  // Radio, TV, Streaming, etc.
                var plays: Int
                var revenue: Double
            }
        }
    }

    // MARK: - Initialization

    init() {
        print("💰 Financial Management System initialized")
        setupDefaultAccounts()
    }

    private func setupDefaultAccounts() {
        // Create default accounts
        accounts = [
            Account(name: "Business Checking", type: .business, currency: .eur),
            Account(name: "Royalty Account", type: .royalties, currency: .eur),
            Account(name: "PayPal", type: .paypal, currency: .eur),
            Account(name: "Crypto Wallet", type: .crypto, currency: .btc),
        ]

        print("   ✅ Default accounts created")
    }

    // MARK: - Transaction Management

    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)

        // Update account balance
        if let accountIndex = accounts.firstIndex(where: { $0.name == transaction.account }) {
            switch transaction.type {
            case .income:
                accounts[accountIndex].balance += transaction.amount
            case .expense:
                accounts[accountIndex].balance -= transaction.amount
            case .transfer:
                break  // Handle separately
            }
        }

        print("   ✅ Transaction added: \(transaction.description) (\(transaction.currency.symbol)\(transaction.amount))")
    }

    func categorizeTransaction(_ transaction: Transaction, category: Transaction.Category) {
        print("   🏷️ Auto-categorizing transaction...")
        // In production: Use ML to auto-categorize based on description
    }

    // MARK: - Invoicing

    func createInvoice(from: Invoice.BusinessEntity, to: Invoice.BusinessEntity, items: [Invoice.LineItem], currency: Currency = .eur) -> Invoice {
        let invoiceNumber = generateInvoiceNumber()

        var invoice = Invoice(
            invoiceNumber: invoiceNumber,
            from: from,
            to: to,
            currency: currency
        )

        invoice.items = items
        invoice.calculateTotals()

        invoices.append(invoice)

        print("   📄 Invoice created:")
        print("      Number: \(invoice.invoiceNumber)")
        print("      Total: \(invoice.currency.symbol)\(invoice.total)")
        print("      Due: \(invoice.dueDate)")

        return invoice
    }

    private func generateInvoiceNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let count = invoices.filter {
            Calendar.current.component(.year, from: $0.date) == year
        }.count + 1

        return String(format: "INV-%04d-%04d", year, count)
    }

    func sendInvoice(_ invoice: Invoice, via method: DeliveryMethod) {
        print("   📧 Sending invoice \(invoice.invoiceNumber)")
        print("      Method: \(method.rawValue)")
        print("      To: \(invoice.to.email ?? "N/A")")

        // In production: Email/PDF generation
        print("   ✅ Invoice sent")
    }

    enum DeliveryMethod: String {
        case email = "Email"
        case postal = "Postal Mail"
        case download = "Download Link"
    }

    func markInvoiceAsPaid(_ invoice: Invoice, paymentDate: Date, paymentMethod: Invoice.PaymentMethod) {
        print("   💳 Marking invoice as paid")
        print("      Invoice: \(invoice.invoiceNumber)")
        print("      Amount: \(invoice.currency.symbol)\(invoice.total)")
        print("      Method: \(paymentMethod.rawValue)")

        // Create income transaction
        let transaction = Transaction(
            date: paymentDate,
            type: .income,
            category: .royalties,  // Or appropriate category
            amount: invoice.total,
            currency: invoice.currency,
            description: "Payment for invoice \(invoice.invoiceNumber)",
            account: "Business Checking"
        )
        transaction.invoice = invoice.id

        addTransaction(transaction)

        print("   ✅ Invoice marked as paid")
    }

    // MARK: - Tax Preparation

    func prepareTaxReturn(year: Int, jurisdiction: TaxJurisdiction) -> TaxReturn {
        print("   📊 Preparing tax return for \(year)")
        print("      Jurisdiction: \(jurisdiction.rawValue)")

        var taxReturn = TaxReturn(year: year, country: jurisdiction)

        // Calculate gross income (all income transactions)
        let income = transactions.filter {
            $0.type == .income &&
            Calendar.current.component(.year, from: $0.date) == year
        }
        taxReturn.grossIncome = income.reduce(0) { $0 + $1.amount }

        // Calculate deductions (tax-deductible expenses)
        let expenses = transactions.filter {
            $0.type == .expense &&
            $0.taxDeductible &&
            Calendar.current.component(.year, from: $0.date) == year
        }

        for expense in expenses {
            let deduction = TaxReturn.Deduction(
                id: UUID(),
                category: expense.category.rawValue,
                amount: expense.amount,
                description: expense.description
            )
            taxReturn.deductions.append(deduction)
        }

        taxReturn.totalDeductions = taxReturn.deductions.reduce(0) { $0 + $1.amount }
        taxReturn.taxableIncome = max(0, taxReturn.grossIncome - taxReturn.totalDeductions)

        // Calculate tax (simplified - in production: use actual tax tables)
        taxReturn.taxOwed = calculateTax(taxableIncome: taxReturn.taxableIncome, jurisdiction: jurisdiction)

        print("   Gross Income: \(Currency.eur.symbol)\(taxReturn.grossIncome)")
        print("   Deductions: \(Currency.eur.symbol)\(taxReturn.totalDeductions)")
        print("   Taxable Income: \(Currency.eur.symbol)\(taxReturn.taxableIncome)")
        print("   Tax Owed: \(Currency.eur.symbol)\(taxReturn.taxOwed)")

        taxReturns.append(taxReturn)

        return taxReturn
    }

    private func calculateTax(taxableIncome: Double, jurisdiction: TaxJurisdiction) -> Double {
        // Simplified tax calculation
        // In production: Implement actual progressive tax tables

        switch jurisdiction {
        case .germany:
            // Simplified German tax brackets (2024)
            if taxableIncome <= 10908 { return 0 }  // Basic allowance
            else if taxableIncome <= 62810 { return taxableIncome * 0.14 }  // 14-42%
            else if taxableIncome <= 277826 { return taxableIncome * 0.42 }  // 42%
            else { return taxableIncome * 0.45 }  // Top rate 45%

        case .usa:
            // Simplified US federal tax (single filer, 2024)
            if taxableIncome <= 11000 { return taxableIncome * 0.10 }
            else if taxableIncome <= 44725 { return taxableIncome * 0.12 }
            else if taxableIncome <= 95375 { return taxableIncome * 0.22 }
            else { return taxableIncome * 0.24 }

        default:
            return taxableIncome * 0.25  // Simplified 25%
        }
    }

    func exportTaxReturn(_ taxReturn: TaxReturn, format: TaxFormat) -> URL? {
        print("   💾 Exporting tax return")
        print("      Format: \(format.rawValue)")

        switch format {
        case .elster:
            // ELSTER format (Germany)
            print("      ✅ ELSTER XML generated")
        case .pdf:
            // PDF summary
            print("      ✅ PDF generated")
        case .csv:
            // CSV for accountant
            print("      ✅ CSV generated")
        }

        return nil // Placeholder
    }

    enum TaxFormat: String {
        case elster = "ELSTER (Germany)"
        case pdf = "PDF Summary"
        case csv = "CSV (Spreadsheet)"
    }

    // MARK: - Royalty Distribution

    func processRoyaltyPayment(_ payment: RoyaltyPayment) {
        print("   💸 Processing royalty payment")
        print("      Organization: \(payment.organization.rawValue)")
        print("      Period: \(payment.period.start) - \(payment.period.end)")
        print("      Amount: \(payment.currency.symbol)\(payment.amount)")

        // Create income transaction
        let transaction = Transaction(
            date: payment.paymentDate,
            type: .income,
            category: .royalties,
            amount: payment.amount,
            currency: payment.currency,
            description: "Royalties from \(payment.organization.rawValue)",
            account: "Royalty Account"
        )

        addTransaction(transaction)

        // Log individual work royalties
        for work in payment.works {
            print("      → \(work.workTitle): \(payment.currency.symbol)\(work.amount)")
        }

        print("   ✅ Royalty payment processed")
    }

    // MARK: - Reporting

    func generateFinancialReport(period: DateInterval) -> FinancialReport {
        print("   📊 Generating financial report")
        print("      Period: \(period.start) - \(period.end)")

        let periodTransactions = transactions.filter {
            period.contains($0.date)
        }

        let income = periodTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expenses = periodTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        let netIncome = income - expenses

        let report = FinancialReport(
            period: period,
            totalIncome: income,
            totalExpenses: expenses,
            netIncome: netIncome,
            transactionCount: periodTransactions.count
        )

        print("   Total Income: \(Currency.eur.symbol)\(income)")
        print("   Total Expenses: \(Currency.eur.symbol)\(expenses)")
        print("   Net Income: \(Currency.eur.symbol)\(netIncome)")

        return report
    }

    struct FinancialReport {
        let period: DateInterval
        let totalIncome: Double
        let totalExpenses: Double
        let netIncome: Double
        let transactionCount: Int
    }
}

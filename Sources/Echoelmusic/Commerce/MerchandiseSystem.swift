import Foundation

/// Merchandise & E-Commerce System
/// Complete merch store with print-on-demand, inventory, and order fulfillment
///
/// Features:
/// - Print-on-Demand integration (Printful, Printify, SPOD)
/// - Inventory management
/// - Order fulfillment & shipping
/// - Custom products (Vinyl, USB, CDs, Apparel)
/// - Shopping cart & checkout
/// - Payment processing
/// - Merch analytics & insights
/// - Bulk ordering & discounts
/// - Limited editions & drops
@MainActor
class MerchandiseSystem: ObservableObject {

    // MARK: - Published Properties

    @Published var products: [Product] = []
    @Published var orders: [Order] = []
    @Published var inventory: [InventoryItem] = []
    @Published var campaigns: [MerchCampaign] = []

    // MARK: - Product

    struct Product: Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var category: ProductCategory
        var variants: [ProductVariant]
        var images: [String]
        var pricing: PricingStrategy
        var fulfillment: FulfillmentMethod
        var status: ProductStatus
        var tags: [String]
        var createdDate: Date

        enum ProductCategory {
            case apparel(type: ApparelType)
            case music(type: MusicType)
            case accessories
            case collectibles
            case digital
            case bundle

            enum ApparelType: String, CaseIterable {
                case tshirt = "T-Shirt"
                case hoodie = "Hoodie"
                case sweatshirt = "Sweatshirt"
                case tanktop = "Tank Top"
                case longsleeve = "Long Sleeve"
                case hat = "Hat"
                case beanie = "Beanie"
            }

            enum MusicType: String, CaseIterable {
                case vinyl = "Vinyl Record"
                case cd = "CD"
                case cassette = "Cassette"
                case usb = "USB Drive"
                case boxSet = "Box Set"
            }
        }

        enum ProductStatus {
            case draft, active, soldOut, archived, comingSoon
        }

        struct PricingStrategy {
            var basePrice: Double
            var costPrice: Double?  // Manufacturing cost
            var discountPrice: Double?
            var bulkDiscounts: [BulkDiscount]

            struct BulkDiscount {
                let minQuantity: Int
                let discountPercentage: Double
            }

            var margin: Double {
                guard let cost = costPrice else { return 0.0 }
                return basePrice - cost
            }

            var marginPercentage: Double {
                guard basePrice > 0 else { return 0.0 }
                return (margin / basePrice) * 100.0
            }
        }

        enum FulfillmentMethod {
            case printOnDemand(provider: PODProvider)
            case inHouse
            case dropship
            case digital

            enum PODProvider: String, CaseIterable {
                case printful = "Printful"
                case printify = "Printify"
                case spod = "Spreadshirt"
                case redbubble = "Redbubble"
                case teespring = "Spring (Teespring)"
                case customcat = "CustomCat"

                var commission: Double {
                    switch self {
                    case .printful: return 0.0  // No commission, just product cost
                    case .printify: return 0.0
                    case .spod: return 20.0
                    case .redbubble: return 20.0
                    case .teespring: return 0.0
                    case .customcat: return 0.0
                    }
                }
            }
        }
    }

    // MARK: - Product Variant

    struct ProductVariant: Identifiable {
        let id = UUID()
        var sku: String
        var size: String?
        var color: String?
        var material: String?
        var stock: Int
        var price: Double
        var weight: Double?  // kg for shipping
        var dimensions: Dimensions?

        struct Dimensions {
            let length: Double  // cm
            let width: Double
            let height: Double
        }

        var isInStock: Bool {
            stock > 0
        }
    }

    // MARK: - Order

    struct Order: Identifiable {
        let id = UUID()
        var orderNumber: String
        var customer: Customer
        var items: [OrderItem]
        var subtotal: Double
        var shipping: ShippingInfo
        var tax: Double
        var discount: Double
        var total: Double
        var payment: PaymentInfo
        var status: OrderStatus
        var placedDate: Date
        var fulfillmentDate: Date?
        var trackingNumber: String?
        var notes: String?

        enum OrderStatus: String {
            case pending = "Pending"
            case paid = "Paid"
            case processing = "Processing"
            case shipped = "Shipped"
            case delivered = "Delivered"
            case cancelled = "Cancelled"
            case refunded = "Refunded"

            var emoji: String {
                switch self {
                case .pending: return "⏳"
                case .paid: return "✅"
                case .processing: return "📦"
                case .shipped: return "🚚"
                case .delivered: return "✨"
                case .cancelled: return "❌"
                case .refunded: return "💸"
                }
            }
        }

        struct OrderItem: Identifiable {
            let id = UUID()
            let product: Product
            let variant: ProductVariant
            let quantity: Int
            let price: Double  // Price at time of order

            var subtotal: Double {
                Double(quantity) * price
            }
        }

        struct ShippingInfo {
            var method: ShippingMethod
            var cost: Double
            var estimatedDelivery: DateInterval?
            var address: ShippingAddress

            enum ShippingMethod: String {
                case standard = "Standard Shipping"
                case express = "Express Shipping"
                case overnight = "Overnight"
                case international = "International"
                case digitalDelivery = "Digital Delivery"

                var estimatedDays: Int {
                    switch self {
                    case .standard: return 5
                    case .express: return 2
                    case .overnight: return 1
                    case .international: return 14
                    case .digitalDelivery: return 0
                    }
                }
            }

            struct ShippingAddress {
                let name: String
                let street: String
                let city: String
                let state: String?
                let postalCode: String
                let country: String
                let phone: String?
            }
        }

        struct PaymentInfo {
            var method: PaymentMethod
            var status: PaymentStatus
            var transactionId: String?
            var processor: PaymentProcessor

            enum PaymentMethod: String {
                case creditCard = "Credit Card"
                case debitCard = "Debit Card"
                case paypal = "PayPal"
                case applePay = "Apple Pay"
                case googlePay = "Google Pay"
                case crypto = "Cryptocurrency"
                case bankTransfer = "Bank Transfer"
            }

            enum PaymentStatus {
                case pending, authorized, captured, failed, refunded
            }

            enum PaymentProcessor: String, CaseIterable {
                case stripe = "Stripe"
                case paypal = "PayPal"
                case square = "Square"
                case shopifyPayments = "Shopify Payments"
                case braintree = "Braintree"
                case adyen = "Adyen"

                var transactionFee: Double {
                    switch self {
                    case .stripe: return 2.9  // % + $0.30
                    case .paypal: return 3.49
                    case .square: return 2.9
                    case .shopifyPayments: return 2.9
                    case .braintree: return 2.9
                    case .adyen: return 3.0
                    }
                }
            }
        }
    }

    // MARK: - Customer

    struct Customer: Identifiable {
        let id = UUID()
        var email: String
        var name: String
        var phone: String?
        var shippingAddresses: [Order.ShippingInfo.ShippingAddress]
        var orderHistory: [UUID]  // Order IDs
        var totalSpent: Double
        var createdDate: Date
        var marketingOptIn: Bool

        var lifetimeValue: Double {
            totalSpent
        }

        var orderCount: Int {
            orderHistory.count
        }
    }

    // MARK: - Inventory Item

    struct InventoryItem: Identifiable {
        let id = UUID()
        var product: Product
        var variant: ProductVariant
        var location: WarehouseLocation
        var quantity: Int
        var reorderPoint: Int
        var reorderQuantity: Int
        var lastRestocked: Date

        enum WarehouseLocation: String {
            case main = "Main Warehouse"
            case secondary = "Secondary Warehouse"
            case pod = "Print-on-Demand"
            case dropship = "Dropshipper"
        }

        var needsRestock: Bool {
            quantity <= reorderPoint
        }
    }

    // MARK: - Merch Campaign

    struct MerchCampaign: Identifiable {
        let id = UUID()
        var name: String
        var type: CampaignType
        var products: [Product]
        var startDate: Date
        var endDate: Date?
        var salesGoal: Int?
        var currentSales: Int
        var limitedEdition: Bool
        var maxQuantity: Int?

        enum CampaignType {
            case preorder
            case limitedDrop
            case seasonal
            case tourExclusive
            case albumRelease
            case collaboration
        }

        var isActive: Bool {
            let now = Date()
            if let end = endDate {
                return now >= startDate && now <= end
            }
            return now >= startDate
        }

        var isSoldOut: Bool {
            guard let max = maxQuantity else { return false }
            return currentSales >= max
        }

        var salesProgress: Double {
            guard let goal = salesGoal, goal > 0 else { return 0.0 }
            return min(Double(currentSales) / Double(goal) * 100.0, 100.0)
        }
    }

    // MARK: - Initialization

    init() {
        print("🛍️ Merchandise System initialized")

        // Load sample products
        loadSampleProducts()

        print("   ✅ \(products.count) products loaded")
    }

    private func loadSampleProducts() {
        products = [
            Product(
                name: "Artist Logo T-Shirt",
                description: "Premium cotton tee with artist logo",
                category: .apparel(type: .tshirt),
                variants: [
                    ProductVariant(sku: "TSH-BLK-S", size: "S", color: "Black", stock: 50, price: 29.99, weight: 0.2),
                    ProductVariant(sku: "TSH-BLK-M", size: "M", color: "Black", stock: 100, price: 29.99, weight: 0.2),
                    ProductVariant(sku: "TSH-BLK-L", size: "L", color: "Black", stock: 80, price: 29.99, weight: 0.2),
                ],
                images: ["tshirt-front.jpg", "tshirt-back.jpg"],
                pricing: Product.PricingStrategy(
                    basePrice: 29.99,
                    costPrice: 12.00,
                    bulkDiscounts: [
                        Product.PricingStrategy.BulkDiscount(minQuantity: 3, discountPercentage: 10),
                        Product.PricingStrategy.BulkDiscount(minQuantity: 5, discountPercentage: 15),
                    ]
                ),
                fulfillment: .printOnDemand(provider: .printful),
                status: .active,
                tags: ["apparel", "tshirt", "logo"],
                createdDate: Date()
            ),
            Product(
                name: "Limited Edition Vinyl",
                description: "180g vinyl with bonus tracks and art print",
                category: .music(type: .vinyl),
                variants: [
                    ProductVariant(sku: "VNL-001-BLK", color: "Black", stock: 500, price: 34.99, weight: 0.3),
                    ProductVariant(sku: "VNL-001-CLR", color: "Clear", stock: 100, price: 39.99, weight: 0.3),
                ],
                images: ["vinyl-mockup.jpg"],
                pricing: Product.PricingStrategy(
                    basePrice: 34.99,
                    costPrice: 15.00,
                    bulkDiscounts: []
                ),
                fulfillment: .inHouse,
                status: .active,
                tags: ["vinyl", "music", "limited"],
                createdDate: Date()
            ),
        ]
    }

    // MARK: - Product Management

    func createProduct(
        name: String,
        description: String,
        category: Product.ProductCategory,
        basePrice: Double,
        fulfillment: Product.FulfillmentMethod
    ) -> Product {
        print("➕ Creating product: \(name)")

        let product = Product(
            name: name,
            description: description,
            category: category,
            variants: [],
            images: [],
            pricing: Product.PricingStrategy(
                basePrice: basePrice,
                bulkDiscounts: []
            ),
            fulfillment: fulfillment,
            status: .draft,
            tags: [],
            createdDate: Date()
        )

        products.append(product)

        print("   ✅ Product created (status: draft)")

        return product
    }

    func addProductVariant(
        productId: UUID,
        variant: ProductVariant
    ) {
        guard let productIndex = products.firstIndex(where: { $0.id == productId }) else {
            return
        }

        print("➕ Adding variant: \(variant.sku)")

        products[productIndex].variants.append(variant)

        print("   ✅ Variant added")
    }

    func updateStock(
        productId: UUID,
        variantId: UUID,
        newStock: Int
    ) {
        guard let productIndex = products.firstIndex(where: { $0.id == productId }),
              let variantIndex = products[productIndex].variants.firstIndex(where: { $0.id == variantId }) else {
            return
        }

        print("📦 Updating stock for \(products[productIndex].variants[variantIndex].sku)")

        let oldStock = products[productIndex].variants[variantIndex].stock
        products[productIndex].variants[variantIndex].stock = newStock

        print("   ✅ Stock updated: \(oldStock) → \(newStock)")
    }

    // MARK: - Order Processing

    func createOrder(
        customer: Customer,
        items: [Order.OrderItem],
        shippingMethod: Order.ShippingInfo.ShippingMethod,
        shippingAddress: Order.ShippingInfo.ShippingAddress,
        paymentMethod: Order.PaymentInfo.PaymentMethod
    ) -> Order {
        print("🛒 Creating order for \(customer.name)...")

        let subtotal = items.reduce(0) { $0 + $1.subtotal }
        let shippingCost = calculateShipping(method: shippingMethod, items: items)
        let tax = calculateTax(subtotal: subtotal, address: shippingAddress)
        let total = subtotal + shippingCost + tax

        let orderNumber = generateOrderNumber()

        let order = Order(
            orderNumber: orderNumber,
            customer: customer,
            items: items,
            subtotal: subtotal,
            shipping: Order.ShippingInfo(
                method: shippingMethod,
                cost: shippingCost,
                address: shippingAddress
            ),
            tax: tax,
            discount: 0,
            total: total,
            payment: Order.PaymentInfo(
                method: paymentMethod,
                status: .pending,
                processor: .stripe
            ),
            status: .pending,
            placedDate: Date()
        )

        orders.append(order)

        print("   ✅ Order #\(orderNumber) created")
        print("   💰 Total: $\(String(format: "%.2f", total))")

        return order
    }

    func processPayment(orderId: UUID) async -> Bool {
        guard let orderIndex = orders.firstIndex(where: { $0.id == orderId }) else {
            return false
        }

        print("💳 Processing payment for order #\(orders[orderIndex].orderNumber)...")

        // Simulate payment processing
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // 95% success rate simulation
        let success = Int.random(in: 1...100) <= 95

        if success {
            orders[orderIndex].payment.status = .captured
            orders[orderIndex].payment.transactionId = "txn_\(UUID().uuidString.prefix(12))"
            orders[orderIndex].status = .paid

            print("   ✅ Payment captured: $\(String(format: "%.2f", orders[orderIndex].total))")

            // Deduct inventory
            for item in orders[orderIndex].items {
                deductInventory(productId: item.product.id, variantId: item.variant.id, quantity: item.quantity)
            }

            return true
        } else {
            orders[orderIndex].payment.status = .failed
            orders[orderIndex].status = .cancelled

            print("   ❌ Payment failed")

            return false
        }
    }

    func fulfillOrder(orderId: UUID) async {
        guard let orderIndex = orders.firstIndex(where: { $0.id == orderId }) else {
            return
        }

        print("📦 Fulfilling order #\(orders[orderIndex].orderNumber)...")

        orders[orderIndex].status = .processing

        // Simulate fulfillment time
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        // Generate tracking number
        let trackingNumber = "TRK\(Int.random(in: 100000...999999))"
        orders[orderIndex].trackingNumber = trackingNumber
        orders[orderIndex].status = .shipped
        orders[orderIndex].fulfillmentDate = Date()

        print("   ✅ Order shipped")
        print("   📮 Tracking: \(trackingNumber)")
    }

    private func deductInventory(productId: UUID, variantId: UUID, quantity: Int) {
        guard let productIndex = products.firstIndex(where: { $0.id == productId }),
              let variantIndex = products[productIndex].variants.firstIndex(where: { $0.id == variantId }) else {
            return
        }

        products[productIndex].variants[variantIndex].stock -= quantity

        // Check if sold out
        let totalStock = products[productIndex].variants.reduce(0) { $0 + $1.stock }
        if totalStock == 0 {
            products[productIndex].status = .soldOut
            print("   ⚠️ Product sold out: \(products[productIndex].name)")
        }
    }

    // MARK: - Campaigns

    func createCampaign(
        name: String,
        type: MerchCampaign.CampaignType,
        products: [Product],
        startDate: Date,
        endDate: Date?,
        limitedEdition: Bool = false,
        maxQuantity: Int? = nil
    ) -> MerchCampaign {
        print("🎯 Creating campaign: \(name)")

        let campaign = MerchCampaign(
            name: name,
            type: type,
            products: products,
            startDate: startDate,
            endDate: endDate,
            currentSales: 0,
            limitedEdition: limitedEdition,
            maxQuantity: maxQuantity
        )

        campaigns.append(campaign)

        print("   ✅ Campaign created")
        if limitedEdition {
            print("   🌟 Limited edition: \(maxQuantity ?? 0) units")
        }

        return campaign
    }

    // MARK: - Print-on-Demand Integration

    func syncWithPODProvider(
        provider: Product.FulfillmentMethod.PODProvider,
        product: Product
    ) async -> Bool {
        print("🔄 Syncing with \(provider.rawValue)...")

        // Simulate API call
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        print("   ✅ Product synced with \(provider.rawValue)")
        print("   📊 \(product.variants.count) variants uploaded")

        return true
    }

    func createMockup(
        provider: Product.FulfillmentMethod.PODProvider,
        product: Product,
        design: URL
    ) async -> [URL] {
        print("🎨 Creating mockups with \(provider.rawValue)...")

        // Simulate mockup generation
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        let mockups = [
            URL(string: "https://mockup.com/front.jpg")!,
            URL(string: "https://mockup.com/back.jpg")!,
            URL(string: "https://mockup.com/detail.jpg")!,
        ]

        print("   ✅ \(mockups.count) mockups generated")

        return mockups
    }

    // MARK: - Analytics

    func generateSalesReport(period: DateInterval) -> SalesReport {
        print("📊 Generating sales report...")

        let relevantOrders = orders.filter { order in
            period.contains(order.placedDate)
        }

        let totalRevenue = relevantOrders.reduce(0) { $0 + $1.total }
        let totalOrders = relevantOrders.count
        let totalItems = relevantOrders.reduce(0) { $0 + $1.items.count }

        // Calculate top products
        var productSales: [UUID: (product: Product, quantity: Int, revenue: Double)] = [:]
        for order in relevantOrders {
            for item in order.items {
                let existing = productSales[item.product.id]
                productSales[item.product.id] = (
                    product: item.product,
                    quantity: (existing?.quantity ?? 0) + item.quantity,
                    revenue: (existing?.revenue ?? 0) + item.subtotal
                )
            }
        }

        let topProducts = productSales.values
            .sorted { $0.revenue > $1.revenue }
            .prefix(10)
            .map { TopProduct(product: $0.product, quantity: $0.quantity, revenue: $0.revenue) }

        let avgOrderValue = totalOrders > 0 ? totalRevenue / Double(totalOrders) : 0

        let report = SalesReport(
            period: period,
            totalRevenue: totalRevenue,
            totalOrders: totalOrders,
            totalItems: totalItems,
            averageOrderValue: avgOrderValue,
            topProducts: topProducts,
            ordersByStatus: calculateOrdersByStatus(orders: relevantOrders)
        )

        print("   ✅ Report generated")
        print("   💰 Total Revenue: $\(String(format: "%.2f", totalRevenue))")
        print("   📦 Total Orders: \(totalOrders)")
        print("   📊 Avg Order Value: $\(String(format: "%.2f", avgOrderValue))")

        return report
    }

    struct SalesReport {
        let period: DateInterval
        let totalRevenue: Double
        let totalOrders: Int
        let totalItems: Int
        let averageOrderValue: Double
        let topProducts: [TopProduct]
        let ordersByStatus: [Order.OrderStatus: Int]

        struct TopProduct {
            let product: Product
            let quantity: Int
            let revenue: Double
        }
    }

    private func calculateOrdersByStatus(orders: [Order]) -> [Order.OrderStatus: Int] {
        var statusCounts: [Order.OrderStatus: Int] = [:]
        for order in orders {
            statusCounts[order.status, default: 0] += 1
        }
        return statusCounts
    }

    // MARK: - Helper Methods

    private func calculateShipping(method: Order.ShippingInfo.ShippingMethod, items: [Order.OrderItem]) -> Double {
        switch method {
        case .standard:
            return 5.99
        case .express:
            return 12.99
        case .overnight:
            return 24.99
        case .international:
            return 29.99
        case .digitalDelivery:
            return 0.0
        }
    }

    private func calculateTax(subtotal: Double, address: Order.ShippingInfo.ShippingAddress) -> Double {
        // Simplified tax calculation (in production: use TaxJar, Avalara, etc.)
        let taxRate = 0.0825  // 8.25%
        return subtotal * taxRate
    }

    private func generateOrderNumber() -> String {
        let prefix = "EM"
        let number = String(format: "%06d", orders.count + 1)
        return "\(prefix)\(number)"
    }

    // MARK: - Bulk Operations

    func applyBulkDiscount(items: [Order.OrderItem]) -> Double {
        var totalDiscount = 0.0

        // Group by product
        var productQuantities: [UUID: Int] = [:]
        for item in items {
            productQuantities[item.product.id, default: 0] += item.quantity
        }

        for (productId, quantity) in productQuantities {
            guard let product = products.first(where: { $0.id == productId }) else {
                continue
            }

            // Find applicable discount
            let applicableDiscounts = product.pricing.bulkDiscounts
                .filter { $0.minQuantity <= quantity }
                .sorted { $0.discountPercentage > $1.discountPercentage }

            if let bestDiscount = applicableDiscounts.first {
                let itemsOfProduct = items.filter { $0.product.id == productId }
                let productSubtotal = itemsOfProduct.reduce(0) { $0 + $1.subtotal }
                totalDiscount += productSubtotal * (bestDiscount.discountPercentage / 100.0)
            }
        }

        return totalDiscount
    }

    // MARK: - Customer Management

    func getCustomerLifetimeValue(customerId: UUID) -> Double {
        guard let customer = findCustomer(id: customerId) else {
            return 0.0
        }

        let customerOrders = orders.filter { $0.customer.id == customerId }
        return customerOrders.reduce(0) { $0 + $1.total }
    }

    func getTopCustomers(limit: Int = 10) -> [Customer] {
        let allCustomers = Set(orders.map { $0.customer.id })
            .compactMap { findCustomer(id: $0) }

        return allCustomers
            .sorted { $0.totalSpent > $1.totalSpent }
            .prefix(limit)
            .map { $0 }
    }

    private func findCustomer(id: UUID) -> Customer? {
        return orders.first { $0.customer.id == id }?.customer
    }
}

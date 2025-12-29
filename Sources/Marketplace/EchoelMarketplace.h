/**
 * EchoelMarketplace.h
 *
 * Digital Marketplace for Presets, Samples, Plugins & More
 *
 * Complete e-commerce platform for music production:
 * - Preset & sound pack store
 * - Sample library marketplace
 * - Plugin extensions
 * - Template marketplace
 * - Creator storefronts
 * - Revenue sharing system
 * - Review & rating system
 * - Licensing management
 * - Bundle deals
 * - Wish lists & recommendations
 *
 * Part of Ralph Wiggum Quantum Sauce Mode - Phase 2
 * "When I grow up, I want to be a principal or a caterpillar" - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <functional>
#include <chrono>
#include <optional>
#include <variant>
#include <atomic>
#include <mutex>

namespace Echoel {

// ============================================================================
// Product Types
// ============================================================================

enum class ProductCategory {
    // Audio Content
    Preset,             // Synth/effect presets
    PresetPack,         // Collection of presets
    Sample,             // Individual samples
    SamplePack,         // Sample libraries
    Loop,               // Loop packs
    DrumKit,            // Drum sample kits
    SoundEffect,        // SFX libraries

    // Project Files
    Template,           // Project templates
    MIDIPack,           // MIDI patterns
    ProjectFile,        // Full project files

    // Extensions
    Plugin,             // VST/AU plugins
    Extension,          // App extensions
    Theme,              // UI themes
    Skin,               // Visual customizations

    // Education
    Tutorial,           // Video tutorials
    Course,             // Full courses
    Masterclass,        // Expert sessions
    EBook,              // Educational PDFs

    // Services
    Mixing,             // Mixing services
    Mastering,          // Mastering services
    Collaboration,      // Collaboration sessions
    Feedback,           // Professional feedback

    // Physical (future)
    Merchandise,        // Physical merch
    Hardware,           // Hardware bundles

    Custom
};

enum class LicenseType {
    // Royalty-Free
    RoyaltyFree,        // Use anywhere, no royalties
    RoyaltyFreeCommercial, // Commercial use included

    // Limited
    PersonalUse,        // Non-commercial only
    SingleProject,      // One project only
    MultiProject,       // Multiple projects
    Unlimited,          // Unlimited use

    // Subscription
    SubscriptionOnly,   // Requires active sub

    // Exclusive
    Exclusive,          // Exclusive rights
    BuyOut,             // Full ownership transfer

    // Creative Commons
    CC_BY,              // Attribution
    CC_BY_NC,           // Non-commercial
    CC_BY_SA,           // Share-alike
    CC0,                // Public domain

    Custom
};

enum class ContentRating {
    Everyone,           // E - All ages
    Teen,               // T - 13+
    Mature,             // M - 17+
    Explicit            // Explicit content warning
};

// ============================================================================
// Product Definition
// ============================================================================

struct ProductMedia {
    std::string id;

    enum class Type {
        Image,
        Video,
        Audio,
        Demo
    } type = Type::Image;

    std::string url;
    std::string thumbnailUrl;
    std::string caption;
    int sortOrder = 0;

    // For audio/video
    std::chrono::seconds duration{0};
    bool isPreview = true;
};

struct ProductFile {
    std::string id;
    std::string filename;
    std::string downloadUrl;

    int64_t fileSize = 0;  // bytes
    std::string checksum;   // SHA-256

    std::string format;     // "wav", "mid", "fxp", etc.
    std::string version;

    bool isMainFile = true;
    std::vector<std::string> requirements;  // Plugin requirements
};

struct ProductPricing {
    // Base price
    float basePrice = 0.0f;
    std::string currency = "USD";

    // Discounts
    float salePrice = 0.0f;
    bool isOnSale = false;
    std::chrono::system_clock::time_point saleEndDate;
    float discountPercent = 0.0f;

    // Subscription
    bool includedInSubscription = false;
    std::string requiredTier;

    // Bundle pricing
    float bundleDiscount = 0.0f;

    // Regional pricing
    std::map<std::string, float> regionalPrices;

    // Pay what you want
    bool payWhatYouWant = false;
    float minimumPrice = 0.0f;
    float suggestedPrice = 0.0f;
};

struct Product {
    std::string id;
    std::string sku;
    std::string name;
    std::string shortDescription;
    std::string fullDescription;

    ProductCategory category = ProductCategory::Preset;
    std::vector<std::string> tags;
    std::vector<std::string> genres;

    // Creator
    std::string creatorId;
    std::string creatorName;
    std::string brandName;

    // Media
    std::string coverImageUrl;
    std::vector<ProductMedia> media;

    // Files
    std::vector<ProductFile> files;
    int64_t totalSize = 0;

    // Pricing
    ProductPricing pricing;
    LicenseType license = LicenseType::RoyaltyFree;
    std::string licenseDetails;

    // Requirements
    std::string minimumAppVersion;
    std::vector<std::string> pluginRequirements;
    std::vector<std::string> platformSupport;  // "macOS", "Windows", "iOS"

    // Metadata
    ContentRating contentRating = ContentRating::Everyone;
    std::string language;
    int itemCount = 0;  // Number of presets/samples

    // Stats
    int downloadCount = 0;
    int purchaseCount = 0;
    int wishlistCount = 0;
    float averageRating = 0.0f;
    int reviewCount = 0;

    // Status
    bool isPublished = false;
    bool isFeatured = false;
    bool isNewRelease = false;
    bool isTopSeller = false;
    bool isExclusive = false;

    std::chrono::system_clock::time_point releaseDate;
    std::chrono::system_clock::time_point lastUpdated;

    // SEO
    std::string slug;
    std::string metaTitle;
    std::string metaDescription;
};

// ============================================================================
// Creator/Seller
// ============================================================================

struct CreatorProfile {
    std::string id;
    std::string displayName;
    std::string slug;
    std::string bio;

    std::string avatarUrl;
    std::string bannerUrl;
    std::string websiteUrl;

    // Social
    std::map<std::string, std::string> socialLinks;

    // Stats
    int productCount = 0;
    int totalSales = 0;
    float totalRevenue = 0.0f;
    int followerCount = 0;
    float averageRating = 0.0f;

    // Verification
    bool isVerified = false;
    bool isPremiumCreator = false;
    std::chrono::system_clock::time_point memberSince;

    // Payout
    std::string payoutMethod;
    float revenueShare = 0.7f;  // 70% to creator
    float pendingPayout = 0.0f;
};

struct CreatorStorefront {
    std::string creatorId;
    std::string themeName;
    std::string customCSS;

    // Featured products
    std::vector<std::string> featuredProductIds;
    std::vector<std::string> pinnedProductIds;

    // Collections
    struct Collection {
        std::string id;
        std::string name;
        std::string description;
        std::vector<std::string> productIds;
    };
    std::vector<Collection> collections;

    // Custom pages
    struct CustomPage {
        std::string slug;
        std::string title;
        std::string content;
    };
    std::vector<CustomPage> customPages;
};

// ============================================================================
// Reviews & Ratings
// ============================================================================

struct Review {
    std::string id;
    std::string productId;
    std::string userId;
    std::string userName;
    std::string userAvatarUrl;

    int rating = 5;  // 1-5 stars
    std::string title;
    std::string content;

    std::vector<std::string> pros;
    std::vector<std::string> cons;

    // Media
    std::vector<std::string> imageUrls;
    std::string audioPreviewUrl;

    // Verification
    bool isVerifiedPurchase = false;
    bool isFeatured = false;

    // Engagement
    int helpfulCount = 0;
    int reportCount = 0;

    // Response
    std::string creatorResponse;
    std::chrono::system_clock::time_point responseDate;

    std::chrono::system_clock::time_point createdAt;
    std::chrono::system_clock::time_point updatedAt;
};

// ============================================================================
// Orders & Purchases
// ============================================================================

struct CartItem {
    std::string productId;
    int quantity = 1;
    float unitPrice = 0.0f;
    float discount = 0.0f;
    std::string couponCode;
};

struct Cart {
    std::string id;
    std::string oderId;

    std::vector<CartItem> items;

    float subtotal = 0.0f;
    float discount = 0.0f;
    float tax = 0.0f;
    float total = 0.0f;

    std::string couponCode;
    float couponDiscount = 0.0f;

    std::chrono::system_clock::time_point createdAt;
    std::chrono::system_clock::time_point updatedAt;
};

struct Order {
    std::string id;
    std::string oderId;

    std::vector<CartItem> items;

    float subtotal = 0.0f;
    float discount = 0.0f;
    float tax = 0.0f;
    float total = 0.0f;

    std::string currency = "USD";
    std::string paymentMethod;
    std::string transactionId;

    enum class Status {
        Pending,
        Processing,
        Completed,
        Failed,
        Refunded,
        Disputed
    } status = Status::Pending;

    std::chrono::system_clock::time_point createdAt;
    std::chrono::system_clock::time_point completedAt;

    // Downloads
    std::vector<std::string> downloadUrls;
    int downloadsRemaining = 5;
    std::chrono::system_clock::time_point downloadExpiry;
};

struct PurchasedProduct {
    std::string productId;
    std::string orderId;
    std::string licenseKey;

    std::chrono::system_clock::time_point purchaseDate;

    int downloadsUsed = 0;
    int maxDownloads = 5;

    bool isInstalled = false;
    std::string installedVersion;

    bool hasUpdate = false;
    std::string latestVersion;
};

// ============================================================================
// Bundles & Deals
// ============================================================================

struct Bundle {
    std::string id;
    std::string name;
    std::string description;
    std::string coverImageUrl;

    std::vector<std::string> productIds;

    float originalPrice = 0.0f;  // Sum of individual prices
    float bundlePrice = 0.0f;    // Discounted bundle price
    float savings = 0.0f;
    float discountPercent = 0.0f;

    bool isLimitedTime = false;
    std::chrono::system_clock::time_point endDate;

    int purchaseLimit = 0;  // 0 = unlimited
    int purchaseCount = 0;
};

struct Coupon {
    std::string code;
    std::string description;

    enum class Type {
        Percentage,
        FixedAmount,
        FreeProduct,
        BuyOneGetOne
    } type = Type::Percentage;

    float value = 0.0f;
    float minimumPurchase = 0.0f;
    float maximumDiscount = 0.0f;

    std::vector<std::string> applicableProducts;
    std::vector<ProductCategory> applicableCategories;
    std::vector<std::string> excludedProducts;

    int usageLimit = 0;
    int usageCount = 0;
    int perUserLimit = 1;

    std::chrono::system_clock::time_point startDate;
    std::chrono::system_clock::time_point endDate;

    bool isActive = true;
};

// ============================================================================
// Wishlist & Recommendations
// ============================================================================

struct WishlistItem {
    std::string productId;
    std::chrono::system_clock::time_point addedAt;
    float priceWhenAdded = 0.0f;
    bool notifyOnSale = true;
    int priority = 0;
};

struct Recommendation {
    std::string productId;
    float score = 0.0f;

    enum class Reason {
        SimilarToPurchased,
        SimilarToWishlist,
        PopularInGenre,
        TrendingNow,
        SameCreator,
        FrequentlyBoughtTogether,
        PersonalizedForYou,
        EditorsPick,
        NewRelease
    } reason = Reason::PersonalizedForYou;

    std::string reasonText;
};

// ============================================================================
// Marketplace Manager
// ============================================================================

class MarketplaceManager {
public:
    static MarketplaceManager& getInstance() {
        static MarketplaceManager instance;
        return instance;
    }

    // ========================================================================
    // Product Browsing
    // ========================================================================

    std::vector<Product> searchProducts(
        const std::string& query,
        std::optional<ProductCategory> category = std::nullopt,
        const std::vector<std::string>& tags = {},
        int page = 1,
        int perPage = 20) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Product> results;
        std::string lowerQuery = query;
        std::transform(lowerQuery.begin(), lowerQuery.end(),
                       lowerQuery.begin(), ::tolower);

        for (const auto& [id, product] : products_) {
            if (!product.isPublished) continue;

            if (category && product.category != *category) continue;

            // Search in name and description
            std::string lowerName = product.name;
            std::transform(lowerName.begin(), lowerName.end(),
                           lowerName.begin(), ::tolower);

            if (lowerName.find(lowerQuery) == std::string::npos &&
                product.fullDescription.find(query) == std::string::npos) {
                continue;
            }

            results.push_back(product);
        }

        // Sort by relevance (simplified)
        std::sort(results.begin(), results.end(),
            [](const Product& a, const Product& b) {
                return a.purchaseCount > b.purchaseCount;
            });

        // Paginate
        int start = (page - 1) * perPage;
        if (start >= static_cast<int>(results.size())) {
            return {};
        }

        int end = std::min(start + perPage, static_cast<int>(results.size()));
        return std::vector<Product>(results.begin() + start, results.begin() + end);
    }

    std::vector<Product> getFeaturedProducts(int limit = 10) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Product> featured;
        for (const auto& [id, product] : products_) {
            if (product.isPublished && product.isFeatured) {
                featured.push_back(product);
            }
        }

        if (featured.size() > static_cast<size_t>(limit)) {
            featured.resize(limit);
        }

        return featured;
    }

    std::vector<Product> getNewReleases(int limit = 20) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Product> products;
        for (const auto& [id, product] : products_) {
            if (product.isPublished) {
                products.push_back(product);
            }
        }

        std::sort(products.begin(), products.end(),
            [](const Product& a, const Product& b) {
                return a.releaseDate > b.releaseDate;
            });

        if (products.size() > static_cast<size_t>(limit)) {
            products.resize(limit);
        }

        return products;
    }

    std::vector<Product> getTopSellers(int limit = 20) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Product> products;
        for (const auto& [id, product] : products_) {
            if (product.isPublished) {
                products.push_back(product);
            }
        }

        std::sort(products.begin(), products.end(),
            [](const Product& a, const Product& b) {
                return a.purchaseCount > b.purchaseCount;
            });

        if (products.size() > static_cast<size_t>(limit)) {
            products.resize(limit);
        }

        return products;
    }

    std::optional<Product> getProduct(const std::string& productId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = products_.find(productId);
        if (it != products_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // ========================================================================
    // Cart Management
    // ========================================================================

    void addToCart(const std::string& productId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto productIt = products_.find(productId);
        if (productIt == products_.end()) return;

        // Check if already in cart
        for (auto& item : cart_.items) {
            if (item.productId == productId) {
                return;  // Already in cart
            }
        }

        CartItem item;
        item.productId = productId;
        item.unitPrice = productIt->second.pricing.isOnSale ?
            productIt->second.pricing.salePrice :
            productIt->second.pricing.basePrice;

        cart_.items.push_back(item);
        recalculateCart();
    }

    void removeFromCart(const std::string& productId) {
        std::lock_guard<std::mutex> lock(mutex_);

        cart_.items.erase(
            std::remove_if(cart_.items.begin(), cart_.items.end(),
                [&](const CartItem& item) {
                    return item.productId == productId;
                }),
            cart_.items.end()
        );

        recalculateCart();
    }

    void clearCart() {
        std::lock_guard<std::mutex> lock(mutex_);
        cart_.items.clear();
        recalculateCart();
    }

    Cart getCart() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return cart_;
    }

    bool applyCoupon(const std::string& code) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = coupons_.find(code);
        if (it == coupons_.end()) return false;

        const auto& coupon = it->second;
        if (!coupon.isActive) return false;

        auto now = std::chrono::system_clock::now();
        if (now < coupon.startDate || now > coupon.endDate) return false;

        if (coupon.usageLimit > 0 && coupon.usageCount >= coupon.usageLimit) return false;

        cart_.couponCode = code;
        recalculateCart();

        return true;
    }

    // ========================================================================
    // Checkout
    // ========================================================================

    std::optional<Order> checkout(const std::string& paymentMethod) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (cart_.items.empty()) return std::nullopt;

        Order order;
        order.id = generateId("order");
        order.oderId = currentUserId_;
        order.items = cart_.items;
        order.subtotal = cart_.subtotal;
        order.discount = cart_.discount;
        order.tax = cart_.tax;
        order.total = cart_.total;
        order.paymentMethod = paymentMethod;
        order.status = Order::Status::Processing;
        order.createdAt = std::chrono::system_clock::now();

        // Process payment (would integrate with payment provider)
        // For now, simulate success
        order.status = Order::Status::Completed;
        order.completedAt = std::chrono::system_clock::now();
        order.transactionId = "txn_" + order.id;

        // Add to purchased products
        for (const auto& item : order.items) {
            PurchasedProduct purchased;
            purchased.productId = item.productId;
            purchased.orderId = order.id;
            purchased.licenseKey = generateLicenseKey();
            purchased.purchaseDate = std::chrono::system_clock::now();

            purchasedProducts_[purchased.productId] = purchased;

            // Update product stats
            auto productIt = products_.find(item.productId);
            if (productIt != products_.end()) {
                productIt->second.purchaseCount++;
            }
        }

        orders_[order.id] = order;

        // Clear cart
        cart_.items.clear();
        recalculateCart();

        return order;
    }

    std::vector<Order> getOrderHistory() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Order> result;
        for (const auto& [id, order] : orders_) {
            if (order.oderId == currentUserId_) {
                result.push_back(order);
            }
        }

        std::sort(result.begin(), result.end(),
            [](const Order& a, const Order& b) {
                return a.createdAt > b.createdAt;
            });

        return result;
    }

    // ========================================================================
    // Library (Purchased Products)
    // ========================================================================

    std::vector<PurchasedProduct> getLibrary() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<PurchasedProduct> result;
        for (const auto& [id, product] : purchasedProducts_) {
            result.push_back(product);
        }

        return result;
    }

    bool downloadProduct(const std::string& productId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = purchasedProducts_.find(productId);
        if (it == purchasedProducts_.end()) return false;

        if (it->second.downloadsUsed >= it->second.maxDownloads) return false;

        it->second.downloadsUsed++;

        // Would trigger actual download
        // downloadManager.startDownload(productId);

        return true;
    }

    bool isProductOwned(const std::string& productId) const {
        std::lock_guard<std::mutex> lock(mutex_);
        return purchasedProducts_.count(productId) > 0;
    }

    // ========================================================================
    // Wishlist
    // ========================================================================

    void addToWishlist(const std::string& productId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto productIt = products_.find(productId);
        if (productIt == products_.end()) return;

        WishlistItem item;
        item.productId = productId;
        item.addedAt = std::chrono::system_clock::now();
        item.priceWhenAdded = productIt->second.pricing.basePrice;

        wishlist_[productId] = item;

        productIt->second.wishlistCount++;
    }

    void removeFromWishlist(const std::string& productId) {
        std::lock_guard<std::mutex> lock(mutex_);
        wishlist_.erase(productId);
    }

    std::vector<WishlistItem> getWishlist() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<WishlistItem> result;
        for (const auto& [id, item] : wishlist_) {
            result.push_back(item);
        }

        return result;
    }

    bool isInWishlist(const std::string& productId) const {
        std::lock_guard<std::mutex> lock(mutex_);
        return wishlist_.count(productId) > 0;
    }

    // ========================================================================
    // Reviews
    // ========================================================================

    std::string submitReview(const std::string& productId, int rating,
                              const std::string& title, const std::string& content) {
        std::lock_guard<std::mutex> lock(mutex_);

        Review review;
        review.id = generateId("review");
        review.productId = productId;
        review.userId = currentUserId_;
        review.userName = currentUserName_;
        review.rating = std::clamp(rating, 1, 5);
        review.title = title;
        review.content = content;
        review.isVerifiedPurchase = isProductOwned(productId);
        review.createdAt = std::chrono::system_clock::now();

        reviews_[review.id] = review;

        // Update product rating
        updateProductRating(productId);

        return review.id;
    }

    std::vector<Review> getProductReviews(const std::string& productId,
                                           int page = 1, int perPage = 10) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Review> result;
        for (const auto& [id, review] : reviews_) {
            if (review.productId == productId) {
                result.push_back(review);
            }
        }

        std::sort(result.begin(), result.end(),
            [](const Review& a, const Review& b) {
                return a.createdAt > b.createdAt;
            });

        int start = (page - 1) * perPage;
        if (start >= static_cast<int>(result.size())) return {};

        int end = std::min(start + perPage, static_cast<int>(result.size()));
        return std::vector<Review>(result.begin() + start, result.begin() + end);
    }

    // ========================================================================
    // Recommendations
    // ========================================================================

    std::vector<Recommendation> getRecommendations(int limit = 10) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Recommendation> recs;

        // Based on purchased products
        std::set<std::string> purchasedCategories;
        std::set<std::string> purchasedCreators;

        for (const auto& [id, purchased] : purchasedProducts_) {
            auto productIt = products_.find(id);
            if (productIt != products_.end()) {
                purchasedCreators.insert(productIt->second.creatorId);
            }
        }

        // Find similar products
        for (const auto& [id, product] : products_) {
            if (purchasedProducts_.count(id) > 0) continue;  // Already owned

            Recommendation rec;
            rec.productId = id;

            if (purchasedCreators.count(product.creatorId) > 0) {
                rec.reason = Recommendation::Reason::SameCreator;
                rec.score = 0.8f;
            } else if (product.isFeatured) {
                rec.reason = Recommendation::Reason::EditorsPick;
                rec.score = 0.7f;
            } else if (product.isNewRelease) {
                rec.reason = Recommendation::Reason::NewRelease;
                rec.score = 0.6f;
            } else {
                rec.reason = Recommendation::Reason::PopularInGenre;
                rec.score = product.averageRating / 5.0f;
            }

            recs.push_back(rec);
        }

        std::sort(recs.begin(), recs.end(),
            [](const Recommendation& a, const Recommendation& b) {
                return a.score > b.score;
            });

        if (recs.size() > static_cast<size_t>(limit)) {
            recs.resize(limit);
        }

        return recs;
    }

    // ========================================================================
    // Creator Functions
    // ========================================================================

    std::string createProduct(const Product& product) {
        std::lock_guard<std::mutex> lock(mutex_);

        Product newProduct = product;
        newProduct.id = generateId("prod");
        newProduct.creatorId = currentUserId_;
        newProduct.releaseDate = std::chrono::system_clock::now();
        newProduct.lastUpdated = newProduct.releaseDate;

        products_[newProduct.id] = newProduct;

        return newProduct.id;
    }

    void updateProduct(const std::string& productId, const Product& updates) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = products_.find(productId);
        if (it == products_.end()) return;
        if (it->second.creatorId != currentUserId_) return;  // Not owner

        it->second.name = updates.name;
        it->second.shortDescription = updates.shortDescription;
        it->second.fullDescription = updates.fullDescription;
        it->second.pricing = updates.pricing;
        it->second.lastUpdated = std::chrono::system_clock::now();
    }

    void publishProduct(const std::string& productId, bool published) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = products_.find(productId);
        if (it != products_.end() && it->second.creatorId == currentUserId_) {
            it->second.isPublished = published;
        }
    }

    CreatorProfile getCreatorStats() const {
        std::lock_guard<std::mutex> lock(mutex_);

        CreatorProfile profile;
        profile.id = currentUserId_;

        for (const auto& [id, product] : products_) {
            if (product.creatorId == currentUserId_) {
                profile.productCount++;
                profile.totalSales += product.purchaseCount;
            }
        }

        return profile;
    }

private:
    MarketplaceManager() {
        cart_.id = generateId("cart");
    }
    ~MarketplaceManager() = default;

    MarketplaceManager(const MarketplaceManager&) = delete;
    MarketplaceManager& operator=(const MarketplaceManager&) = delete;

    std::string generateId(const std::string& prefix) {
        return prefix + "_" + std::to_string(nextId_++);
    }

    std::string generateLicenseKey() {
        // Would generate proper license key
        return "ECHOEL-" + std::to_string(nextId_++) + "-XXXX-XXXX";
    }

    void recalculateCart() {
        cart_.subtotal = 0;
        for (const auto& item : cart_.items) {
            cart_.subtotal += item.unitPrice * item.quantity;
        }

        // Apply coupon
        if (!cart_.couponCode.empty()) {
            auto it = coupons_.find(cart_.couponCode);
            if (it != coupons_.end()) {
                if (it->second.type == Coupon::Type::Percentage) {
                    cart_.couponDiscount = cart_.subtotal * (it->second.value / 100.0f);
                } else {
                    cart_.couponDiscount = it->second.value;
                }
            }
        }

        cart_.discount = cart_.couponDiscount;
        cart_.tax = (cart_.subtotal - cart_.discount) * 0.0f;  // Tax calculation
        cart_.total = cart_.subtotal - cart_.discount + cart_.tax;
        cart_.updatedAt = std::chrono::system_clock::now();
    }

    void updateProductRating(const std::string& productId) {
        float totalRating = 0;
        int count = 0;

        for (const auto& [id, review] : reviews_) {
            if (review.productId == productId) {
                totalRating += review.rating;
                count++;
            }
        }

        auto it = products_.find(productId);
        if (it != products_.end() && count > 0) {
            it->second.averageRating = totalRating / count;
            it->second.reviewCount = count;
        }
    }

    mutable std::mutex mutex_;

    std::map<std::string, Product> products_;
    std::map<std::string, CreatorProfile> creators_;
    std::map<std::string, Review> reviews_;
    std::map<std::string, Order> orders_;
    std::map<std::string, PurchasedProduct> purchasedProducts_;
    std::map<std::string, WishlistItem> wishlist_;
    std::map<std::string, Bundle> bundles_;
    std::map<std::string, Coupon> coupons_;

    Cart cart_;

    std::string currentUserId_ = "user_1";
    std::string currentUserName_ = "Producer";

    std::atomic<int> nextId_{1};
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Marketplace {

inline std::vector<Product> search(const std::string& query) {
    return MarketplaceManager::getInstance().searchProducts(query);
}

inline void addToCart(const std::string& productId) {
    MarketplaceManager::getInstance().addToCart(productId);
}

inline void addToWishlist(const std::string& productId) {
    MarketplaceManager::getInstance().addToWishlist(productId);
}

inline Cart cart() {
    return MarketplaceManager::getInstance().getCart();
}

inline std::optional<Order> checkout(const std::string& paymentMethod = "card") {
    return MarketplaceManager::getInstance().checkout(paymentMethod);
}

inline bool owned(const std::string& productId) {
    return MarketplaceManager::getInstance().isProductOwned(productId);
}

} // namespace Marketplace

} // namespace Echoel

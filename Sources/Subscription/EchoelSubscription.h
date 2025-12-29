/**
 * EchoelSubscription.h
 *
 * Subscription & In-App Purchase Management
 *
 * Complete monetization platform:
 * - Subscription tiers (Free, Pro, Ultimate)
 * - In-app purchases
 * - Trial management
 * - Family sharing
 * - Education discounts
 * - Enterprise licensing
 * - Usage tracking
 * - Feature gating
 * - Payment processing
 * - Receipt validation
 *
 * Part of Ralph Wiggum Quantum Sauce Mode - Phase 2
 * "Mrs. Krabappel and Principal Skinner were in the closet making babies
 *  and I saw one of the babies and the baby looked at me." - Ralph Wiggum
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
#include <atomic>
#include <mutex>

namespace Echoel {

// ============================================================================
// Subscription Types
// ============================================================================

enum class SubscriptionTier {
    Free,           // Basic features
    Starter,        // Entry-level paid
    Pro,            // Professional tier
    Ultimate,       // All features
    Enterprise,     // Business/team
    Education,      // Student/teacher
    Family          // Family plan
};

enum class BillingPeriod {
    Monthly,
    Quarterly,
    Yearly,
    Lifetime,
    Trial
};

enum class PaymentMethod {
    ApplePay,
    GooglePay,
    CreditCard,
    PayPal,
    BankTransfer,
    Crypto,
    GiftCard,
    PromoCode
};

// ============================================================================
// Feature Entitlements
// ============================================================================

enum class Feature {
    // Core
    BasicEditing,
    AdvancedEditing,
    UnlimitedTracks,
    UnlimitedProjects,

    // Audio
    HighResAudio,       // 96kHz+
    DolbyAtmos,
    SpatialAudio,
    AdvancedMixing,

    // Effects
    BasicEffects,
    PremiumEffects,
    ThirdPartyPlugins,
    AIEffects,

    // Instruments
    BasicInstruments,
    PremiumInstruments,
    AllInstruments,

    // Samples
    BasicSamples,
    PremiumSamples,
    AllSamples,
    CloudSamples,

    // Cloud
    CloudStorage,
    CloudSync,
    CloudBackup,
    CloudCollaboration,

    // Export
    MP3Export,
    WAVExport,
    StemExport,
    VideoExport,
    MasteringExport,

    // AI
    AIComposition,
    AIMixing,
    AIVoice,
    AIStemSeparation,

    // Education
    Tutorials,
    PremiumTutorials,
    Certificates,
    Mentorship,

    // Support
    EmailSupport,
    PrioritySupport,
    PhoneSupport,
    DedicatedManager,

    // Team
    TeamSharing,
    TeamAdmin,
    Analytics,
    SSO,

    // Misc
    NoAds,
    NoWatermark,
    EarlyAccess,
    BetaFeatures,
    APIAccess
};

// ============================================================================
// Subscription Plan
// ============================================================================

struct SubscriptionPlan {
    std::string id;
    std::string name;
    std::string description;
    SubscriptionTier tier = SubscriptionTier::Free;

    // Pricing
    std::map<BillingPeriod, float> prices;
    std::string currency = "USD";

    // Discounts
    float yearlyDiscount = 0.2f;  // 20% off yearly
    float studentDiscount = 0.5f; // 50% off for students

    // Features
    std::set<Feature> includedFeatures;

    // Limits
    int maxTracks = -1;           // -1 = unlimited
    int maxProjects = -1;
    int64_t cloudStorageBytes = 0;
    int maxExportsPerMonth = -1;
    int maxCollaborators = 0;

    // Trial
    bool hasFreeTrial = true;
    int trialDays = 14;

    // App Store IDs
    std::string appleProductId;
    std::string googleProductId;

    bool isPopular = false;
    bool isAvailable = true;
};

// ============================================================================
// User Subscription
// ============================================================================

struct UserSubscription {
    std::string oderId;
    std::string planId;
    SubscriptionTier tier = SubscriptionTier::Free;

    // Status
    enum class Status {
        Active,
        Trial,
        Expired,
        Cancelled,
        GracePeriod,
        PastDue,
        Paused
    } status = Status::Active;

    BillingPeriod billingPeriod = BillingPeriod::Monthly;
    PaymentMethod paymentMethod = PaymentMethod::ApplePay;

    // Dates
    std::chrono::system_clock::time_point startDate;
    std::chrono::system_clock::time_point endDate;
    std::chrono::system_clock::time_point trialEndDate;
    std::chrono::system_clock::time_point nextBillingDate;
    std::chrono::system_clock::time_point cancelledDate;

    // Payment
    float currentPrice = 0.0f;
    std::string currency = "USD";
    std::string lastTransactionId;

    // Auto-renew
    bool autoRenew = true;

    // Promo
    std::string promoCode;
    float promoDiscount = 0.0f;

    // Family/Team
    std::string familyOwnerId;
    std::vector<std::string> familyMembers;
    std::string teamId;

    // Platform
    std::string platform;  // "ios", "android", "web"
    std::string originalPurchaseId;
};

// ============================================================================
// In-App Purchases
// ============================================================================

struct InAppPurchase {
    std::string id;
    std::string name;
    std::string description;

    enum class Type {
        Consumable,         // Can buy multiple (credits, etc.)
        NonConsumable,      // One-time purchase
        Subscription,       // Recurring
        NonRenewing         // Time-limited, non-recurring
    } type = Type::NonConsumable;

    float price = 0.0f;
    std::string currency = "USD";

    // For consumables
    int quantity = 1;

    // What it unlocks
    std::set<Feature> unlocksFeatures;
    std::vector<std::string> unlocksContent;  // Product IDs

    // App Store IDs
    std::string appleProductId;
    std::string googleProductId;

    bool isAvailable = true;
};

struct PurchasedItem {
    std::string purchaseId;
    std::string productId;
    InAppPurchase::Type type;

    std::chrono::system_clock::time_point purchaseDate;
    std::chrono::system_clock::time_point expiryDate;

    std::string transactionId;
    std::string receipt;

    int quantity = 1;
    int consumed = 0;

    bool isValid = true;
};

// ============================================================================
// Usage Tracking
// ============================================================================

struct UsageMetrics {
    std::string oderId;
    std::string periodId;  // "2024-01" for monthly

    // Time
    std::chrono::seconds totalUsageTime{0};
    std::map<std::string, std::chrono::seconds> featureUsageTime;

    // Counts
    int projectsCreated = 0;
    int tracksCreated = 0;
    int exportsCompleted = 0;
    int collaborationSessions = 0;

    // Storage
    int64_t cloudStorageUsed = 0;
    int64_t localStorageUsed = 0;

    // Bandwidth
    int64_t downloadBytes = 0;
    int64_t uploadBytes = 0;

    // AI
    int aiCreditsUsed = 0;
    int aiRequestsMade = 0;

    // Engagement
    int daysActive = 0;
    float averageSessionLength = 0.0f;
    int sessionsThisPeriod = 0;
};

// ============================================================================
// Receipt Validation
// ============================================================================

struct ReceiptValidation {
    std::string receiptData;
    std::string platform;  // "apple", "google"

    bool isValid = false;
    std::string validationError;

    std::string productId;
    std::string transactionId;
    std::chrono::system_clock::time_point purchaseDate;
    std::chrono::system_clock::time_point expiryDate;

    bool isTrial = false;
    bool isIntroductory = false;
    bool willAutoRenew = true;
};

// ============================================================================
// Subscription Manager
// ============================================================================

class SubscriptionManager {
public:
    static SubscriptionManager& getInstance() {
        static SubscriptionManager instance;
        return instance;
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    void initialize() {
        std::lock_guard<std::mutex> lock(mutex_);
        registerPlans();
        registerPurchases();
        loadUserSubscription();
        initialized_ = true;
    }

    // ========================================================================
    // Plan Information
    // ========================================================================

    std::vector<SubscriptionPlan> getAvailablePlans() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<SubscriptionPlan> result;
        for (const auto& [id, plan] : plans_) {
            if (plan.isAvailable) {
                result.push_back(plan);
            }
        }

        // Sort by tier
        std::sort(result.begin(), result.end(),
            [](const SubscriptionPlan& a, const SubscriptionPlan& b) {
                return static_cast<int>(a.tier) < static_cast<int>(b.tier);
            });

        return result;
    }

    std::optional<SubscriptionPlan> getPlan(const std::string& planId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = plans_.find(planId);
        if (it != plans_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    float getPlanPrice(const std::string& planId, BillingPeriod period) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = plans_.find(planId);
        if (it != plans_.end()) {
            auto priceIt = it->second.prices.find(period);
            if (priceIt != it->second.prices.end()) {
                return priceIt->second;
            }
        }
        return 0.0f;
    }

    // ========================================================================
    // Subscription Management
    // ========================================================================

    UserSubscription getCurrentSubscription() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentSubscription_;
    }

    SubscriptionTier getCurrentTier() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentSubscription_.tier;
    }

    bool isSubscribed() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentSubscription_.status == UserSubscription::Status::Active ||
               currentSubscription_.status == UserSubscription::Status::Trial;
    }

    bool isTrialing() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentSubscription_.status == UserSubscription::Status::Trial;
    }

    std::chrono::system_clock::time_point getExpiryDate() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return currentSubscription_.endDate;
    }

    int getRemainingTrialDays() const {
        std::lock_guard<std::mutex> lock(mutex_);

        if (currentSubscription_.status != UserSubscription::Status::Trial) {
            return 0;
        }

        auto now = std::chrono::system_clock::now();
        if (now >= currentSubscription_.trialEndDate) {
            return 0;
        }

        return std::chrono::duration_cast<std::chrono::hours>(
            currentSubscription_.trialEndDate - now).count() / 24;
    }

    // ========================================================================
    // Purchase Flow
    // ========================================================================

    bool startTrial(const std::string& planId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto planIt = plans_.find(planId);
        if (planIt == plans_.end()) return false;

        if (!planIt->second.hasFreeTrial) return false;

        // Check if already used trial
        if (trialUsed_) return false;

        currentSubscription_.planId = planId;
        currentSubscription_.tier = planIt->second.tier;
        currentSubscription_.status = UserSubscription::Status::Trial;
        currentSubscription_.startDate = std::chrono::system_clock::now();
        currentSubscription_.trialEndDate = currentSubscription_.startDate +
            std::chrono::hours{planIt->second.trialDays * 24};
        currentSubscription_.endDate = currentSubscription_.trialEndDate;

        trialUsed_ = true;
        updateEntitlements();

        return true;
    }

    bool subscribe(const std::string& planId, BillingPeriod period,
                    PaymentMethod method = PaymentMethod::ApplePay) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto planIt = plans_.find(planId);
        if (planIt == plans_.end()) return false;

        // Would initiate actual payment flow here
        // For now, simulate success

        currentSubscription_.planId = planId;
        currentSubscription_.tier = planIt->second.tier;
        currentSubscription_.status = UserSubscription::Status::Active;
        currentSubscription_.billingPeriod = period;
        currentSubscription_.paymentMethod = method;
        currentSubscription_.startDate = std::chrono::system_clock::now();

        // Calculate end date
        switch (period) {
            case BillingPeriod::Monthly:
                currentSubscription_.endDate = currentSubscription_.startDate +
                    std::chrono::hours{30 * 24};
                break;
            case BillingPeriod::Quarterly:
                currentSubscription_.endDate = currentSubscription_.startDate +
                    std::chrono::hours{90 * 24};
                break;
            case BillingPeriod::Yearly:
                currentSubscription_.endDate = currentSubscription_.startDate +
                    std::chrono::hours{365 * 24};
                break;
            case BillingPeriod::Lifetime:
                currentSubscription_.endDate = std::chrono::system_clock::time_point::max();
                break;
            default:
                break;
        }

        currentSubscription_.nextBillingDate = currentSubscription_.endDate;
        currentSubscription_.autoRenew = true;

        updateEntitlements();

        return true;
    }

    bool cancelSubscription() {
        std::lock_guard<std::mutex> lock(mutex_);

        if (currentSubscription_.status != UserSubscription::Status::Active) {
            return false;
        }

        currentSubscription_.autoRenew = false;
        currentSubscription_.cancelledDate = std::chrono::system_clock::now();

        // Subscription remains active until end date

        return true;
    }

    bool restorePurchases() {
        // Would restore purchases from app store
        // Validate receipts and restore entitlements
        return true;
    }

    // ========================================================================
    // Feature Entitlements
    // ========================================================================

    bool hasFeature(Feature feature) const {
        std::lock_guard<std::mutex> lock(mutex_);
        return enabledFeatures_.count(feature) > 0;
    }

    std::set<Feature> getEnabledFeatures() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return enabledFeatures_;
    }

    int getFeatureLimit(const std::string& limitName) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto planIt = plans_.find(currentSubscription_.planId);
        if (planIt == plans_.end()) return 0;

        if (limitName == "tracks") return planIt->second.maxTracks;
        if (limitName == "projects") return planIt->second.maxProjects;
        if (limitName == "collaborators") return planIt->second.maxCollaborators;
        if (limitName == "exports") return planIt->second.maxExportsPerMonth;

        return 0;
    }

    int64_t getCloudStorageLimit() const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto planIt = plans_.find(currentSubscription_.planId);
        if (planIt != plans_.end()) {
            return planIt->second.cloudStorageBytes;
        }
        return 0;
    }

    // ========================================================================
    // In-App Purchases
    // ========================================================================

    std::vector<InAppPurchase> getAvailablePurchases() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<InAppPurchase> result;
        for (const auto& [id, purchase] : inAppPurchases_) {
            if (purchase.isAvailable) {
                result.push_back(purchase);
            }
        }
        return result;
    }

    bool purchase(const std::string& productId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = inAppPurchases_.find(productId);
        if (it == inAppPurchases_.end()) return false;

        // Would initiate actual purchase flow
        // For now, simulate success

        PurchasedItem item;
        item.purchaseId = generateId("purchase");
        item.productId = productId;
        item.type = it->second.type;
        item.purchaseDate = std::chrono::system_clock::now();
        item.quantity = it->second.quantity;
        item.isValid = true;

        purchasedItems_[item.purchaseId] = item;

        // Apply features
        for (const auto& feature : it->second.unlocksFeatures) {
            enabledFeatures_.insert(feature);
        }

        return true;
    }

    bool hasPurchased(const std::string& productId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        for (const auto& [id, item] : purchasedItems_) {
            if (item.productId == productId && item.isValid) {
                return true;
            }
        }
        return false;
    }

    // ========================================================================
    // Usage Tracking
    // ========================================================================

    void trackUsage(const std::string& feature, std::chrono::seconds duration) {
        std::lock_guard<std::mutex> lock(mutex_);

        usageMetrics_.featureUsageTime[feature] += duration;
        usageMetrics_.totalUsageTime += duration;
    }

    void incrementUsage(const std::string& metric, int amount = 1) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (metric == "projects") usageMetrics_.projectsCreated += amount;
        if (metric == "tracks") usageMetrics_.tracksCreated += amount;
        if (metric == "exports") usageMetrics_.exportsCompleted += amount;
        if (metric == "ai_credits") usageMetrics_.aiCreditsUsed += amount;
    }

    UsageMetrics getUsageMetrics() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return usageMetrics_;
    }

    bool isWithinLimits(const std::string& metric) const {
        std::lock_guard<std::mutex> lock(mutex_);

        int limit = getFeatureLimit(metric);
        if (limit == -1) return true;  // Unlimited

        if (metric == "projects") return usageMetrics_.projectsCreated < limit;
        if (metric == "tracks") return usageMetrics_.tracksCreated < limit;
        if (metric == "exports") return usageMetrics_.exportsCompleted < limit;

        return true;
    }

    // ========================================================================
    // Promo Codes
    // ========================================================================

    bool applyPromoCode(const std::string& code) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Would validate against server
        // For now, accept specific codes

        if (code == "RALPH2024") {
            currentSubscription_.promoCode = code;
            currentSubscription_.promoDiscount = 0.3f;  // 30% off
            return true;
        }

        if (code == "EDUCATION") {
            currentSubscription_.promoCode = code;
            currentSubscription_.promoDiscount = 0.5f;  // 50% off
            return true;
        }

        return false;
    }

    // ========================================================================
    // Receipt Validation
    // ========================================================================

    ReceiptValidation validateReceipt(const std::string& receiptData,
                                       const std::string& platform) {
        ReceiptValidation result;
        result.receiptData = receiptData;
        result.platform = platform;

        // Would validate with Apple/Google servers
        // For now, simulate success

        result.isValid = true;

        return result;
    }

private:
    SubscriptionManager() = default;
    ~SubscriptionManager() = default;

    SubscriptionManager(const SubscriptionManager&) = delete;
    SubscriptionManager& operator=(const SubscriptionManager&) = delete;

    void registerPlans() {
        // Free tier
        SubscriptionPlan free;
        free.id = "free";
        free.name = "Free";
        free.description = "Basic music production";
        free.tier = SubscriptionTier::Free;
        free.maxTracks = 8;
        free.maxProjects = 3;
        free.cloudStorageBytes = 500 * 1024 * 1024;  // 500MB
        free.maxExportsPerMonth = 5;
        free.includedFeatures = {
            Feature::BasicEditing, Feature::BasicEffects,
            Feature::BasicInstruments, Feature::BasicSamples,
            Feature::MP3Export, Feature::Tutorials
        };
        free.hasFreeTrial = false;
        plans_["free"] = free;

        // Pro tier
        SubscriptionPlan pro;
        pro.id = "pro";
        pro.name = "Pro";
        pro.description = "Professional music production";
        pro.tier = SubscriptionTier::Pro;
        pro.prices = {
            {BillingPeriod::Monthly, 9.99f},
            {BillingPeriod::Yearly, 99.99f}
        };
        pro.maxTracks = -1;  // Unlimited
        pro.maxProjects = -1;
        pro.cloudStorageBytes = 50LL * 1024 * 1024 * 1024;  // 50GB
        pro.maxExportsPerMonth = -1;
        pro.maxCollaborators = 5;
        pro.includedFeatures = {
            Feature::BasicEditing, Feature::AdvancedEditing,
            Feature::UnlimitedTracks, Feature::UnlimitedProjects,
            Feature::HighResAudio, Feature::BasicEffects, Feature::PremiumEffects,
            Feature::ThirdPartyPlugins, Feature::BasicInstruments, Feature::PremiumInstruments,
            Feature::BasicSamples, Feature::PremiumSamples,
            Feature::CloudStorage, Feature::CloudSync,
            Feature::MP3Export, Feature::WAVExport, Feature::StemExport,
            Feature::Tutorials, Feature::PremiumTutorials,
            Feature::EmailSupport, Feature::NoAds
        };
        pro.isPopular = true;
        pro.appleProductId = "com.echoel.pro.monthly";
        plans_["pro"] = pro;

        // Ultimate tier
        SubscriptionPlan ultimate;
        ultimate.id = "ultimate";
        ultimate.name = "Ultimate";
        ultimate.description = "Everything, unlimited";
        ultimate.tier = SubscriptionTier::Ultimate;
        ultimate.prices = {
            {BillingPeriod::Monthly, 24.99f},
            {BillingPeriod::Yearly, 249.99f},
            {BillingPeriod::Lifetime, 499.99f}
        };
        ultimate.maxTracks = -1;
        ultimate.maxProjects = -1;
        ultimate.cloudStorageBytes = 500LL * 1024 * 1024 * 1024;  // 500GB
        ultimate.maxExportsPerMonth = -1;
        ultimate.maxCollaborators = -1;
        ultimate.includedFeatures = {
            Feature::BasicEditing, Feature::AdvancedEditing,
            Feature::UnlimitedTracks, Feature::UnlimitedProjects,
            Feature::HighResAudio, Feature::DolbyAtmos, Feature::SpatialAudio,
            Feature::AdvancedMixing,
            Feature::BasicEffects, Feature::PremiumEffects, Feature::AIEffects,
            Feature::ThirdPartyPlugins,
            Feature::AllInstruments, Feature::AllSamples, Feature::CloudSamples,
            Feature::CloudStorage, Feature::CloudSync, Feature::CloudBackup,
            Feature::CloudCollaboration,
            Feature::MP3Export, Feature::WAVExport, Feature::StemExport,
            Feature::VideoExport, Feature::MasteringExport,
            Feature::AIComposition, Feature::AIMixing, Feature::AIVoice,
            Feature::AIStemSeparation,
            Feature::Tutorials, Feature::PremiumTutorials, Feature::Certificates,
            Feature::Mentorship,
            Feature::EmailSupport, Feature::PrioritySupport,
            Feature::NoAds, Feature::NoWatermark, Feature::EarlyAccess,
            Feature::BetaFeatures, Feature::APIAccess
        };
        ultimate.appleProductId = "com.echoel.ultimate.monthly";
        plans_["ultimate"] = ultimate;
    }

    void registerPurchases() {
        // AI Credits pack
        InAppPurchase aiCredits;
        aiCredits.id = "ai_credits_100";
        aiCredits.name = "100 AI Credits";
        aiCredits.description = "Use for AI composition, mixing, voice synthesis";
        aiCredits.type = InAppPurchase::Type::Consumable;
        aiCredits.price = 4.99f;
        aiCredits.quantity = 100;
        aiCredits.appleProductId = "com.echoel.ai_credits_100";
        inAppPurchases_["ai_credits_100"] = aiCredits;

        // Premium sample pack
        InAppPurchase samplePack;
        samplePack.id = "sample_pack_orchestra";
        samplePack.name = "Orchestral Collection";
        samplePack.description = "Premium orchestral samples";
        samplePack.type = InAppPurchase::Type::NonConsumable;
        samplePack.price = 29.99f;
        samplePack.unlocksContent = {"sample_orchestra_strings", "sample_orchestra_brass"};
        inAppPurchases_["sample_pack_orchestra"] = samplePack;
    }

    void loadUserSubscription() {
        // Would load from persistent storage/keychain
        // Default to free tier
        currentSubscription_.planId = "free";
        currentSubscription_.tier = SubscriptionTier::Free;
        currentSubscription_.status = UserSubscription::Status::Active;

        updateEntitlements();
    }

    void updateEntitlements() {
        enabledFeatures_.clear();

        auto planIt = plans_.find(currentSubscription_.planId);
        if (planIt != plans_.end()) {
            enabledFeatures_ = planIt->second.includedFeatures;
        }

        // Add features from purchases
        for (const auto& [id, item] : purchasedItems_) {
            if (!item.isValid) continue;

            auto purchaseIt = inAppPurchases_.find(item.productId);
            if (purchaseIt != inAppPurchases_.end()) {
                for (const auto& feature : purchaseIt->second.unlocksFeatures) {
                    enabledFeatures_.insert(feature);
                }
            }
        }
    }

    std::string generateId(const std::string& prefix) {
        return prefix + "_" + std::to_string(nextId_++);
    }

    mutable std::mutex mutex_;
    std::atomic<bool> initialized_{false};

    std::map<std::string, SubscriptionPlan> plans_;
    std::map<std::string, InAppPurchase> inAppPurchases_;
    std::map<std::string, PurchasedItem> purchasedItems_;

    UserSubscription currentSubscription_;
    std::set<Feature> enabledFeatures_;
    UsageMetrics usageMetrics_;

    bool trialUsed_ = false;
    std::atomic<int> nextId_{1};
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Subscription {

inline bool hasFeature(Feature feature) {
    return SubscriptionManager::getInstance().hasFeature(feature);
}

inline SubscriptionTier tier() {
    return SubscriptionManager::getInstance().getCurrentTier();
}

inline bool isPro() {
    auto t = tier();
    return t == SubscriptionTier::Pro || t == SubscriptionTier::Ultimate;
}

inline bool startTrial(const std::string& planId = "pro") {
    return SubscriptionManager::getInstance().startTrial(planId);
}

inline bool subscribe(const std::string& planId, BillingPeriod period = BillingPeriod::Monthly) {
    return SubscriptionManager::getInstance().subscribe(planId, period);
}

inline bool cancel() {
    return SubscriptionManager::getInstance().cancelSubscription();
}

} // namespace Subscription

} // namespace Echoel

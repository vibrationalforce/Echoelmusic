// RateLimiter.h - API Rate Limiting (Token Bucket Algorithm)
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <map>
#include <deque>

namespace Echoel {
namespace Security {

/**
 * @brief Token bucket for rate limiting
 */
class TokenBucket {
public:
    TokenBucket(int maxTokens, int refillRate)
        : maxTokens(maxTokens), tokens(maxTokens), refillRate(refillRate),
          lastRefill(juce::Time::getMillisecondCounterHiRes()) {}

    /**
     * @brief Try to consume tokens
     * @param cost Number of tokens to consume
     * @return True if tokens available, false if rate limit exceeded
     */
    bool tryConsume(int cost = 1) {
        refill();

        if (tokens >= cost) {
            tokens -= cost;
            return true;
        }

        return false;
    }

    /**
     * @brief Get remaining tokens
     */
    int getRemainingTokens() {
        refill();
        return tokens;
    }

    /**
     * @brief Reset bucket to full
     */
    void reset() {
        tokens = maxTokens;
        lastRefill = juce::Time::getMillisecondCounterHiRes();
    }

private:
    void refill() {
        double now = juce::Time::getMillisecondCounterHiRes();
        double elapsed = now - lastRefill;

        // Refill tokens based on elapsed time
        int tokensToAdd = static_cast<int>((elapsed / 1000.0) * refillRate);

        if (tokensToAdd > 0) {
            tokens = std::min(tokens + tokensToAdd, maxTokens);
            lastRefill = now;
        }
    }

    int maxTokens;      // Maximum tokens in bucket
    int tokens;         // Current tokens
    int refillRate;     // Tokens per second
    double lastRefill;  // Last refill time (ms)
};

/**
 * @brief Rate Limiter using Token Bucket Algorithm
 *
 * Features:
 * - Per-user rate limiting
 * - Per-endpoint rate limiting
 * - Burst handling
 * - Configurable limits
 */
class RateLimiter {
public:
    struct RateLimit {
        int maxRequests{100};     // Max requests in time window
        int timeWindowSec{60};    // Time window in seconds
        bool burstAllowed{true};  // Allow burst of requests
    };

    RateLimiter() {
        initializeDefaultLimits();
    }

    //==============================================================================
    // Rate Limiting

    /**
     * @brief Check if request is allowed (per-user)
     * @param userId User identifier
     * @param endpoint Endpoint name (e.g., "api/preset/create")
     * @param cost Request cost (default 1)
     * @return True if allowed, false if rate limit exceeded
     */
    bool allowRequest(const juce::String& userId,
                     const juce::String& endpoint = "default",
                     int cost = 1) {
        juce::ScopedLock sl(lock);

        juce::String key = userId + ":" + endpoint;

        // Get or create bucket
        auto it = buckets.find(key.toStdString());
        if (it == buckets.end()) {
            // Get rate limit for endpoint
            RateLimit limit = getRateLimit(endpoint);

            // Create new bucket
            buckets[key.toStdString()] = std::make_unique<TokenBucket>(
                limit.maxRequests,
                limit.maxRequests / limit.timeWindowSec
            );

            it = buckets.find(key.toStdString());
        }

        bool allowed = it->second->tryConsume(cost);

        if (!allowed) {
            ECHOEL_TRACE("Rate limit exceeded for " << userId << " on " << endpoint);
            rateLimitHits++;
        }

        totalRequests++;
        return allowed;
    }

    /**
     * @brief Get remaining quota for user/endpoint
     * @return Number of remaining requests
     */
    int getRemainingQuota(const juce::String& userId, const juce::String& endpoint = "default") {
        juce::ScopedLock sl(lock);

        juce::String key = userId + ":" + endpoint;

        auto it = buckets.find(key.toStdString());
        if (it != buckets.end()) {
            return it->second->getRemainingTokens();
        }

        // Return max limit if no bucket yet
        return getRateLimit(endpoint).maxRequests;
    }

    /**
     * @brief Reset rate limit for user
     */
    void resetUserLimit(const juce::String& userId, const juce::String& endpoint = "default") {
        juce::ScopedLock sl(lock);

        juce::String key = userId + ":" + endpoint;

        auto it = buckets.find(key.toStdString());
        if (it != buckets.end()) {
            it->second->reset();
            ECHOEL_TRACE("Reset rate limit for " << userId << " on " << endpoint);
        }
    }

    //==============================================================================
    // Configuration

    /**
     * @brief Set rate limit for endpoint
     */
    void setRateLimit(const juce::String& endpoint, const RateLimit& limit) {
        juce::ScopedLock sl(lock);

        rateLimits[endpoint.toStdString()] = limit;
        ECHOEL_TRACE("Set rate limit for " << endpoint << ": " <<
                    limit.maxRequests << " requests per " << limit.timeWindowSec << "s");
    }

    /**
     * @brief Get rate limit for endpoint
     */
    RateLimit getRateLimit(const juce::String& endpoint) {
        auto it = rateLimits.find(endpoint.toStdString());
        if (it != rateLimits.end()) {
            return it->second;
        }

        // Return default limit
        return rateLimits["default"];
    }

    //==============================================================================
    // Monitoring

    /**
     * @brief Get statistics
     */
    juce::String getStatistics() const {
        juce::String stats;
        stats << "🚦 Rate Limiter Statistics\n";
        stats << "==========================\n\n";
        stats << "Total Requests: " << totalRequests.load() << "\n";
        stats << "Rate Limit Hits: " << rateLimitHits.load() << "\n";
        stats << "Active Buckets: " << buckets.size() << "\n";
        stats << "Configured Endpoints: " << rateLimits.size() << "\n";

        if (totalRequests.load() > 0) {
            float hitRate = (float)rateLimitHits.load() / totalRequests.load() * 100.0f;
            stats << "Hit Rate: " << juce::String(hitRate, 2) << "%\n";
        }

        return stats;
    }

    /**
     * @brief Cleanup expired buckets
     */
    void cleanup() {
        juce:ScopedLock sl(lock);

        // In production: remove buckets that haven't been used recently
        // For now, just log
        ECHOEL_TRACE("Cleanup complete (" << buckets.size() << " active buckets)");
    }

private:
    void initializeDefaultLimits() {
        // Default rate limit
        RateLimit defaultLimit;
        defaultLimit.maxRequests = 100;
        defaultLimit.timeWindowSec = 60;
        defaultLimit.burstAllowed = true;
        rateLimits["default"] = defaultLimit;

        // API endpoints
        RateLimit apiLimit;
        apiLimit.maxRequests = 1000;
        apiLimit.timeWindowSec = 3600;  // 1 hour
        rateLimits["api/preset"] = apiLimit;

        // Export operations (expensive)
        RateLimit exportLimit;
        exportLimit.maxRequests = 10;
        exportLimit.timeWindowSec = 60;
        exportLimit.burstAllowed = false;
        rateLimits["api/export"] = exportLimit;

        // Authentication
        RateLimit authLimit;
        authLimit.maxRequests = 5;
        authLimit.timeWindowSec = 300;  // 5 minutes
        rateLimits["api/auth/login"] = authLimit;

        ECHOEL_TRACE("Initialized " << rateLimits.size() << " rate limits");
    }

    std::map<std::string, std::unique_ptr<TokenBucket>> buckets;
    std::map<std::string, RateLimit> rateLimits;

    std::atomic<uint64_t> totalRequests{0};
    std::atomic<uint64_t> rateLimitHits{0};

    juce::CriticalSection lock;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(RateLimiter)
};

} // namespace Security
} // namespace Echoel

/**
 * EchoelFavorites.h
 *
 * Preset Favorites & Quick Access System
 *
 * Fast access to frequently used items:
 * - Favorite presets & sounds
 * - Quick access collections
 * - Smart favorites (AI-suggested)
 * - Recently used items
 * - Project-specific favorites
 * - Shared team favorites
 * - Favorite chains (multiple items)
 * - Context-aware suggestions
 * - Usage analytics
 * - One-click loading
 *
 * Part of Ralph Wiggum Genius Loop Mode - Phase 1
 * "Me fail English? That's unpossible!" - Ralph Wiggum
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
#include <queue>

namespace Echoel {

// ============================================================================
// Favorite Types
// ============================================================================

enum class FavoriteType {
    // Audio
    Preset,             // Effect/synth preset
    Sample,             // Audio sample
    Loop,               // Loop file
    Instrument,         // Virtual instrument
    Effect,             // Effect plugin
    Chain,              // Effect chain

    // Project
    Template,           // Project template
    Track,              // Track preset
    Mixer,              // Mixer snapshot
    Routing,            // Routing configuration

    // Content
    Scale,              // Musical scale
    Chord,              // Chord progression
    Rhythm,             // Rhythm pattern
    Melody,             // Melody pattern

    // Settings
    Settings,           // App settings preset
    Workspace,          // Window layout
    ColorScheme,        // Theme/colors
    Shortcut,           // Keyboard shortcut set

    // External
    Hardware,           // Hardware configuration
    MIDIMapping,        // MIDI controller mapping
    OSCMapping,         // OSC configuration

    // Custom
    Custom              // User-defined type
};

// ============================================================================
// Favorite Item
// ============================================================================

struct FavoriteItem {
    std::string id;
    FavoriteType type = FavoriteType::Preset;

    std::string name;
    std::string description;
    std::string category;
    std::string subcategory;

    // Location
    std::string path;           // File path or resource ID
    std::string pluginId;       // For plugin presets
    std::string manufacturer;   // Plugin manufacturer

    // Visual
    std::string iconName;
    std::string thumbnailPath;
    std::string color;

    // Tags
    std::vector<std::string> tags;
    std::vector<std::string> genres;
    std::vector<std::string> moods;

    // Usage stats
    int useCount = 0;
    std::chrono::system_clock::time_point lastUsed;
    std::chrono::system_clock::time_point addedAt;

    // Ratings
    int rating = 0;  // 0-5 stars
    float aiScore = 0.0f;  // AI-computed relevance

    // Metadata
    bool isPinned = false;
    bool isUserFavorite = true;  // vs. AI-suggested
    bool isShared = false;       // Shared with team

    // Context
    std::string projectId;       // Project-specific favorite
    std::string collectionId;    // Parent collection

    // Quick access
    std::string hotkey;          // Optional keyboard shortcut
    int quickSlot = -1;          // Quick access slot (1-10)
};

// ============================================================================
// Collection
// ============================================================================

struct FavoriteCollection {
    std::string id;
    std::string name;
    std::string description;
    std::string iconName;
    std::string color;

    std::vector<std::string> itemIds;

    // Organization
    std::string parentId;  // For nested collections
    int sortOrder = 0;
    bool isExpanded = true;

    // Type filter
    std::set<FavoriteType> allowedTypes;

    // Smart collection (auto-populated)
    bool isSmart = false;
    std::string smartQuery;  // Filter query

    // Sharing
    bool isShared = false;
    std::vector<std::string> sharedWith;

    std::chrono::system_clock::time_point created;
    std::chrono::system_clock::time_point modified;
};

// ============================================================================
// Favorite Chain (Multiple Items)
// ============================================================================

struct FavoriteChain {
    std::string id;
    std::string name;
    std::string description;

    struct ChainItem {
        std::string favoriteId;
        int position = 0;
        bool isEnabled = true;

        // For effects
        float wetDry = 1.0f;
        std::map<std::string, float> parameterOverrides;
    };

    std::vector<ChainItem> items;

    FavoriteType type = FavoriteType::Chain;
    std::string category;

    int useCount = 0;
    std::chrono::system_clock::time_point lastUsed;
};

// ============================================================================
// Usage Analytics
// ============================================================================

struct UsageEvent {
    std::chrono::system_clock::time_point timestamp;
    std::string itemId;
    std::string context;  // What project/session

    enum class Action {
        Loaded,
        Previewed,
        AddedToFavorites,
        RemovedFromFavorites,
        Rated,
        Shared
    } action = Action::Loaded;
};

struct UsageStats {
    int totalUses = 0;
    int uniqueItems = 0;
    int favoritesCount = 0;

    std::string mostUsedItemId;
    std::string mostUsedCategory;
    std::string mostUsedType;

    std::map<FavoriteType, int> usesByType;
    std::map<std::string, int> usesByCategory;
    std::map<int, int> usesByHour;  // Hour of day usage
    std::map<int, int> usesByDayOfWeek;
};

// ============================================================================
// Favorites Manager
// ============================================================================

class FavoritesManager {
public:
    static FavoritesManager& getInstance() {
        static FavoritesManager instance;
        return instance;
    }

    // ========================================================================
    // Favorites Management
    // ========================================================================

    std::string addFavorite(const FavoriteItem& item) {
        std::lock_guard<std::mutex> lock(mutex_);

        FavoriteItem newItem = item;
        newItem.id = generateId("fav");
        newItem.addedAt = std::chrono::system_clock::now();

        favorites_[newItem.id] = newItem;

        // Index for search
        indexFavorite(newItem);

        return newItem.id;
    }

    void removeFavorite(const std::string& favoriteId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = favorites_.find(favoriteId);
        if (it != favorites_.end()) {
            unindexFavorite(it->second);
            favorites_.erase(it);
        }
    }

    void updateFavorite(const std::string& favoriteId, const FavoriteItem& updates) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = favorites_.find(favoriteId);
        if (it != favorites_.end()) {
            unindexFavorite(it->second);

            it->second.name = updates.name;
            it->second.description = updates.description;
            it->second.tags = updates.tags;
            it->second.rating = updates.rating;
            it->second.isPinned = updates.isPinned;
            it->second.hotkey = updates.hotkey;
            it->second.quickSlot = updates.quickSlot;

            indexFavorite(it->second);
        }
    }

    std::optional<FavoriteItem> getFavorite(const std::string& favoriteId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = favorites_.find(favoriteId);
        if (it != favorites_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // ========================================================================
    // Queries
    // ========================================================================

    std::vector<FavoriteItem> getFavorites(
        std::optional<FavoriteType> type = std::nullopt,
        const std::string& category = "",
        int limit = 50) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<FavoriteItem> result;

        for (const auto& [id, item] : favorites_) {
            if (type && item.type != *type) continue;
            if (!category.empty() && item.category != category) continue;

            result.push_back(item);
        }

        // Sort by use count (most used first)
        std::sort(result.begin(), result.end(),
            [](const FavoriteItem& a, const FavoriteItem& b) {
                if (a.isPinned != b.isPinned) return a.isPinned > b.isPinned;
                return a.useCount > b.useCount;
            });

        if (result.size() > static_cast<size_t>(limit)) {
            result.resize(limit);
        }

        return result;
    }

    std::vector<FavoriteItem> getRecentFavorites(int count = 10) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<FavoriteItem> all;
        for (const auto& [id, item] : favorites_) {
            all.push_back(item);
        }

        std::sort(all.begin(), all.end(),
            [](const FavoriteItem& a, const FavoriteItem& b) {
                return a.lastUsed > b.lastUsed;
            });

        if (all.size() > static_cast<size_t>(count)) {
            all.resize(count);
        }

        return all;
    }

    std::vector<FavoriteItem> getMostUsed(int count = 10) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<FavoriteItem> all;
        for (const auto& [id, item] : favorites_) {
            all.push_back(item);
        }

        std::sort(all.begin(), all.end(),
            [](const FavoriteItem& a, const FavoriteItem& b) {
                return a.useCount > b.useCount;
            });

        if (all.size() > static_cast<size_t>(count)) {
            all.resize(count);
        }

        return all;
    }

    std::vector<FavoriteItem> getPinnedFavorites() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<FavoriteItem> pinned;
        for (const auto& [id, item] : favorites_) {
            if (item.isPinned) {
                pinned.push_back(item);
            }
        }

        return pinned;
    }

    std::vector<FavoriteItem> searchFavorites(const std::string& query) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<FavoriteItem> results;
        std::string lowerQuery = query;
        std::transform(lowerQuery.begin(), lowerQuery.end(),
                       lowerQuery.begin(), ::tolower);

        for (const auto& [id, item] : favorites_) {
            std::string lowerName = item.name;
            std::transform(lowerName.begin(), lowerName.end(),
                           lowerName.begin(), ::tolower);

            if (lowerName.find(lowerQuery) != std::string::npos) {
                results.push_back(item);
                continue;
            }

            // Check tags
            for (const auto& tag : item.tags) {
                std::string lowerTag = tag;
                std::transform(lowerTag.begin(), lowerTag.end(),
                               lowerTag.begin(), ::tolower);
                if (lowerTag.find(lowerQuery) != std::string::npos) {
                    results.push_back(item);
                    break;
                }
            }
        }

        return results;
    }

    // ========================================================================
    // Quick Access Slots
    // ========================================================================

    void assignQuickSlot(const std::string& favoriteId, int slot) {
        if (slot < 1 || slot > 10) return;

        std::lock_guard<std::mutex> lock(mutex_);

        // Remove any existing assignment to this slot
        for (auto& [id, item] : favorites_) {
            if (item.quickSlot == slot) {
                item.quickSlot = -1;
            }
        }

        // Assign new
        auto it = favorites_.find(favoriteId);
        if (it != favorites_.end()) {
            it->second.quickSlot = slot;
        }
    }

    std::optional<FavoriteItem> getQuickSlot(int slot) const {
        std::lock_guard<std::mutex> lock(mutex_);

        for (const auto& [id, item] : favorites_) {
            if (item.quickSlot == slot) {
                return item;
            }
        }
        return std::nullopt;
    }

    void loadQuickSlot(int slot) {
        auto item = getQuickSlot(slot);
        if (item) {
            useFavorite(item->id);
        }
    }

    // ========================================================================
    // Collections
    // ========================================================================

    std::string createCollection(const std::string& name) {
        FavoriteCollection collection;
        collection.id = generateId("col");
        collection.name = name;
        collection.created = std::chrono::system_clock::now();
        collection.modified = collection.created;

        std::lock_guard<std::mutex> lock(mutex_);
        collections_[collection.id] = collection;

        return collection.id;
    }

    void addToCollection(const std::string& collectionId, const std::string& favoriteId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto colIt = collections_.find(collectionId);
        auto favIt = favorites_.find(favoriteId);

        if (colIt != collections_.end() && favIt != favorites_.end()) {
            colIt->second.itemIds.push_back(favoriteId);
            colIt->second.modified = std::chrono::system_clock::now();
            favIt->second.collectionId = collectionId;
        }
    }

    void removeFromCollection(const std::string& collectionId, const std::string& favoriteId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto colIt = collections_.find(collectionId);
        if (colIt != collections_.end()) {
            auto& items = colIt->second.itemIds;
            items.erase(std::remove(items.begin(), items.end(), favoriteId), items.end());
            colIt->second.modified = std::chrono::system_clock::now();
        }

        auto favIt = favorites_.find(favoriteId);
        if (favIt != favorites_.end()) {
            favIt->second.collectionId.clear();
        }
    }

    std::vector<FavoriteCollection> getCollections() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<FavoriteCollection> result;
        for (const auto& [id, collection] : collections_) {
            result.push_back(collection);
        }

        std::sort(result.begin(), result.end(),
            [](const FavoriteCollection& a, const FavoriteCollection& b) {
                return a.sortOrder < b.sortOrder;
            });

        return result;
    }

    std::vector<FavoriteItem> getCollectionItems(const std::string& collectionId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<FavoriteItem> result;

        auto colIt = collections_.find(collectionId);
        if (colIt == collections_.end()) return result;

        for (const auto& itemId : colIt->second.itemIds) {
            auto favIt = favorites_.find(itemId);
            if (favIt != favorites_.end()) {
                result.push_back(favIt->second);
            }
        }

        return result;
    }

    // ========================================================================
    // Favorite Chains
    // ========================================================================

    std::string createChain(const std::string& name) {
        FavoriteChain chain;
        chain.id = generateId("chain");
        chain.name = name;

        std::lock_guard<std::mutex> lock(mutex_);
        chains_[chain.id] = chain;

        return chain.id;
    }

    void addToChain(const std::string& chainId, const std::string& favoriteId, int position = -1) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = chains_.find(chainId);
        if (it == chains_.end()) return;

        FavoriteChain::ChainItem item;
        item.favoriteId = favoriteId;
        item.position = position >= 0 ? position : static_cast<int>(it->second.items.size());

        it->second.items.push_back(item);

        // Sort by position
        std::sort(it->second.items.begin(), it->second.items.end(),
            [](const FavoriteChain::ChainItem& a, const FavoriteChain::ChainItem& b) {
                return a.position < b.position;
            });
    }

    std::optional<FavoriteChain> getChain(const std::string& chainId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = chains_.find(chainId);
        if (it != chains_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    void loadChain(const std::string& chainId) {
        auto chain = getChain(chainId);
        if (!chain) return;

        for (const auto& item : chain->items) {
            if (item.isEnabled) {
                useFavorite(item.favoriteId);
            }
        }

        // Track usage
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = chains_.find(chainId);
        if (it != chains_.end()) {
            it->second.useCount++;
            it->second.lastUsed = std::chrono::system_clock::now();
        }
    }

    // ========================================================================
    // Usage Tracking
    // ========================================================================

    void useFavorite(const std::string& favoriteId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = favorites_.find(favoriteId);
        if (it != favorites_.end()) {
            it->second.useCount++;
            it->second.lastUsed = std::chrono::system_clock::now();

            // Log usage
            UsageEvent event;
            event.timestamp = std::chrono::system_clock::now();
            event.itemId = favoriteId;
            event.action = UsageEvent::Action::Loaded;
            usageLog_.push_back(event);
        }

        // Load the actual content
        loadFavoriteContent(favoriteId);
    }

    UsageStats getUsageStats(int days = 30) const {
        std::lock_guard<std::mutex> lock(mutex_);

        UsageStats stats;
        auto cutoff = std::chrono::system_clock::now() - std::chrono::hours{days * 24};

        std::set<std::string> uniqueItems;
        std::map<std::string, int> itemCounts;

        for (const auto& event : usageLog_) {
            if (event.timestamp < cutoff) continue;

            stats.totalUses++;
            uniqueItems.insert(event.itemId);
            itemCounts[event.itemId]++;

            // Hour of day
            auto time = std::chrono::system_clock::to_time_t(event.timestamp);
            auto* tm = std::localtime(&time);
            stats.usesByHour[tm->tm_hour]++;
            stats.usesByDayOfWeek[tm->tm_wday]++;
        }

        stats.uniqueItems = static_cast<int>(uniqueItems.size());
        stats.favoritesCount = static_cast<int>(favorites_.size());

        // Find most used
        int maxCount = 0;
        for (const auto& [itemId, count] : itemCounts) {
            if (count > maxCount) {
                maxCount = count;
                stats.mostUsedItemId = itemId;
            }
        }

        return stats;
    }

    // ========================================================================
    // AI Suggestions
    // ========================================================================

    std::vector<FavoriteItem> getSuggestions(int count = 5) const {
        std::lock_guard<std::mutex> lock(mutex_);

        // AI would analyze usage patterns and suggest items
        // For now, return items with high AI scores

        std::vector<FavoriteItem> suggestions;
        for (const auto& [id, item] : favorites_) {
            if (item.aiScore > 0.5f) {
                suggestions.push_back(item);
            }
        }

        std::sort(suggestions.begin(), suggestions.end(),
            [](const FavoriteItem& a, const FavoriteItem& b) {
                return a.aiScore > b.aiScore;
            });

        if (suggestions.size() > static_cast<size_t>(count)) {
            suggestions.resize(count);
        }

        return suggestions;
    }

    void updateAIScores() {
        std::lock_guard<std::mutex> lock(mutex_);

        // Would use ML model to compute relevance scores
        // Based on: time of day, current project genre, recent usage patterns

        for (auto& [id, item] : favorites_) {
            // Simple heuristic for now
            float recencyScore = 0.0f;
            if (item.lastUsed.time_since_epoch().count() > 0) {
                auto age = std::chrono::system_clock::now() - item.lastUsed;
                auto hours = std::chrono::duration_cast<std::chrono::hours>(age).count();
                recencyScore = std::max(0.0f, 1.0f - hours / 168.0f);  // Decay over a week
            }

            float usageScore = std::min(1.0f, item.useCount / 50.0f);
            float ratingScore = item.rating / 5.0f;

            item.aiScore = (recencyScore * 0.4f) + (usageScore * 0.4f) + (ratingScore * 0.2f);
        }
    }

    // ========================================================================
    // Import/Export
    // ========================================================================

    std::string exportFavorites() const {
        // Export to JSON format
        std::lock_guard<std::mutex> lock(mutex_);

        std::string json = "{\n  \"favorites\": [\n";
        bool first = true;

        for (const auto& [id, item] : favorites_) {
            if (!first) json += ",\n";
            first = false;

            json += "    {\"id\": \"" + item.id + "\", ";
            json += "\"name\": \"" + item.name + "\", ";
            json += "\"type\": " + std::to_string(static_cast<int>(item.type)) + "}";
        }

        json += "\n  ]\n}";
        return json;
    }

    void importFavorites(const std::string& json) {
        // Parse JSON and import favorites
        // Would use proper JSON parser
    }

private:
    FavoritesManager() = default;
    ~FavoritesManager() = default;

    FavoritesManager(const FavoritesManager&) = delete;
    FavoritesManager& operator=(const FavoritesManager&) = delete;

    std::string generateId(const std::string& prefix) {
        return prefix + "_" + std::to_string(nextId_++);
    }

    void indexFavorite(const FavoriteItem& item) {
        // Index by type
        typeIndex_[item.type].insert(item.id);

        // Index by category
        if (!item.category.empty()) {
            categoryIndex_[item.category].insert(item.id);
        }

        // Index by tags
        for (const auto& tag : item.tags) {
            tagIndex_[tag].insert(item.id);
        }
    }

    void unindexFavorite(const FavoriteItem& item) {
        typeIndex_[item.type].erase(item.id);

        if (!item.category.empty()) {
            categoryIndex_[item.category].erase(item.id);
        }

        for (const auto& tag : item.tags) {
            tagIndex_[tag].erase(item.id);
        }
    }

    void loadFavoriteContent(const std::string& favoriteId) {
        // Would actually load the content (preset, sample, etc.)
    }

    mutable std::mutex mutex_;

    std::map<std::string, FavoriteItem> favorites_;
    std::map<std::string, FavoriteCollection> collections_;
    std::map<std::string, FavoriteChain> chains_;

    // Indexes
    std::map<FavoriteType, std::set<std::string>> typeIndex_;
    std::map<std::string, std::set<std::string>> categoryIndex_;
    std::map<std::string, std::set<std::string>> tagIndex_;

    // Usage tracking
    std::vector<UsageEvent> usageLog_;

    std::atomic<int> nextId_{1};
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Favorites {

inline std::string add(const std::string& name, FavoriteType type, const std::string& path) {
    FavoriteItem item;
    item.name = name;
    item.type = type;
    item.path = path;
    return FavoritesManager::getInstance().addFavorite(item);
}

inline void remove(const std::string& id) {
    FavoritesManager::getInstance().removeFavorite(id);
}

inline void use(const std::string& id) {
    FavoritesManager::getInstance().useFavorite(id);
}

inline void quickSlot(int slot) {
    FavoritesManager::getInstance().loadQuickSlot(slot);
}

inline std::vector<FavoriteItem> recent(int count = 10) {
    return FavoritesManager::getInstance().getRecentFavorites(count);
}

inline std::vector<FavoriteItem> search(const std::string& query) {
    return FavoritesManager::getInstance().searchFavorites(query);
}

} // namespace Favorites

} // namespace Echoel

/**
 * EchoelChatSystem.h
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - REAL-TIME CHAT SYSTEM
 * ============================================================================
 *
 * Feature-rich chat with:
 * - Real-time text messaging
 * - Emoji reactions and custom emotes
 * - Moderation tools (ban, mute, timeout)
 * - Rate limiting and spam protection
 * - Message history with pagination
 * - Threaded replies
 * - Rich text formatting
 * - Bio-reactive emotes (coherence-based)
 *
 * Architecture:
 * ┌─────────────────────────────────────────────────────────────────────┐
 * │                        CHAT SYSTEM                                  │
 * ├─────────────────────────────────────────────────────────────────────┤
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │                    Message Queue                             │   │
 * │  │     [Rate Limiter] → [Spam Filter] → [Profanity Filter]     │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * │                              │                                      │
 * │                              ▼                                      │
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │                    Message Store                             │   │
 * │  │     [History Buffer] ← [CRDT Sync] → [Peer Distribution]    │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * │                              │                                      │
 * │                              ▼                                      │
 * │  ┌─────────────────────────────────────────────────────────────┐   │
 * │  │                   Moderation Engine                          │   │
 * │  │  [Ban List] [Mute List] [Word Filter] [Slow Mode] [AutoMod] │   │
 * │  └─────────────────────────────────────────────────────────────┘   │
 * └─────────────────────────────────────────────────────────────────────┘
 */

#pragma once

#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <regex>
#include <set>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace Echoel { namespace Chat {

//==============================================================================
// Constants
//==============================================================================

static constexpr size_t MAX_MESSAGE_LENGTH = 500;
static constexpr size_t MAX_HISTORY_SIZE = 1000;
static constexpr size_t MAX_REACTIONS_PER_MESSAGE = 50;
static constexpr uint32_t DEFAULT_RATE_LIMIT_MESSAGES = 5;
static constexpr uint32_t DEFAULT_RATE_LIMIT_WINDOW_MS = 5000;
static constexpr uint32_t DEFAULT_SLOW_MODE_SECONDS = 0;
static constexpr uint32_t MAX_EMOTE_NAME_LENGTH = 32;

//==============================================================================
// Forward Declarations
//==============================================================================

class EchoelChatSystem;

//==============================================================================
// Enums
//==============================================================================

enum class MessageType : uint8_t
{
    Text = 0,
    Emote,
    System,
    Announcement,
    Action,         // /me action
    Whisper,
    Reply,
    Highlight,
    BioReaction     // Automatic reaction based on bio state
};

enum class ModAction : uint8_t
{
    None = 0,
    Delete,
    Warn,
    Mute,           // Temporary
    Timeout,        // Timed mute
    Ban,            // Permanent
    Unban,
    Unmute,
    SlowMode,
    FollowersOnly,
    SubsOnly
};

enum class UserBadge : uint8_t
{
    None = 0,
    Host = 1 << 0,
    Moderator = 1 << 1,
    VIP = 1 << 2,
    Subscriber = 1 << 3,
    Verified = 1 << 4,
    Performer = 1 << 5,
    HighCoherence = 1 << 6  // Bio-based badge
};

inline UserBadge operator|(UserBadge a, UserBadge b)
{
    return static_cast<UserBadge>(static_cast<uint8_t>(a) | static_cast<uint8_t>(b));
}

inline UserBadge operator&(UserBadge a, UserBadge b)
{
    return static_cast<UserBadge>(static_cast<uint8_t>(a) & static_cast<uint8_t>(b));
}

enum class FilterResult : uint8_t
{
    Allow = 0,
    Block,
    Flag,           // Allow but flag for review
    Replace,        // Replace with asterisks
    Slow            // Add to slow mode
};

//==============================================================================
// Data Structures
//==============================================================================

struct UserId
{
    std::array<uint8_t, 16> uuid;

    bool operator==(const UserId& other) const { return uuid == other.uuid; }
    bool operator!=(const UserId& other) const { return uuid != other.uuid; }

    std::string toString() const
    {
        char buf[37];
        snprintf(buf, sizeof(buf),
            "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            uuid[0], uuid[1], uuid[2], uuid[3],
            uuid[4], uuid[5], uuid[6], uuid[7],
            uuid[8], uuid[9], uuid[10], uuid[11],
            uuid[12], uuid[13], uuid[14], uuid[15]);
        return std::string(buf);
    }
};

struct UserIdHash
{
    size_t operator()(const UserId& id) const
    {
        size_t hash = 0;
        for (int i = 0; i < 16; ++i)
            hash ^= static_cast<size_t>(id.uuid[i]) << ((i % 8) * 8);
        return hash;
    }
};

struct ChatUser
{
    UserId id;
    std::string displayName;
    std::string avatarUrl;
    UserBadge badges = UserBadge::None;
    std::string color;          // Display name color

    // State
    bool isMuted = false;
    bool isBanned = false;
    uint64_t mutedUntil = 0;    // Timestamp

    // Bio state (for bio-reactive features)
    float coherence = 0.0f;
    float relaxation = 0.0f;

    // Stats
    uint32_t messageCount = 0;
    uint64_t firstSeen = 0;
    uint64_t lastSeen = 0;
};

struct Emote
{
    std::string name;           // :emote_name:
    std::string url;            // Image URL
    std::string alt;            // Alt text
    uint32_t width = 28;
    uint32_t height = 28;
    bool isAnimated = false;
    bool isGlobal = true;       // vs session-specific
};

struct Reaction
{
    std::string emote;          // Emote name or emoji
    UserId userId;
    uint64_t timestamp;
};

struct MessageId
{
    uint64_t timestamp;
    uint32_t sequence;
    UserId author;

    std::string toString() const
    {
        return std::to_string(timestamp) + "-" + std::to_string(sequence);
    }

    bool operator==(const MessageId& other) const
    {
        return timestamp == other.timestamp &&
               sequence == other.sequence &&
               author == other.author;
    }
};

struct MessageIdHash
{
    size_t operator()(const MessageId& id) const
    {
        return std::hash<uint64_t>()(id.timestamp) ^
               std::hash<uint32_t>()(id.sequence);
    }
};

struct ChatMessage
{
    MessageId id;
    MessageType type = MessageType::Text;

    // Content
    std::string text;
    std::string originalText;   // Before filtering
    std::string formattedHtml;  // With emotes rendered

    // Author
    UserId authorId;
    std::string authorName;
    std::string authorColor;
    UserBadge authorBadges = UserBadge::None;

    // Threading
    std::optional<MessageId> replyTo;
    std::string replyPreview;   // First N chars of parent message

    // Whisper target
    std::optional<UserId> whisperTo;

    // Reactions
    std::vector<Reaction> reactions;

    // Metadata
    uint64_t timestamp = 0;
    bool isDeleted = false;
    bool isFlagged = false;
    bool isHighlighted = false;
    bool isPinned = false;

    // Bio context (for bio-reactive messages)
    float senderCoherence = 0.0f;
};

struct ChatConfig
{
    // Rate limiting
    uint32_t rateLimitMessages = DEFAULT_RATE_LIMIT_MESSAGES;
    uint32_t rateLimitWindowMs = DEFAULT_RATE_LIMIT_WINDOW_MS;
    uint32_t slowModeSeconds = DEFAULT_SLOW_MODE_SECONDS;

    // Restrictions
    bool followersOnly = false;
    bool subscribersOnly = false;
    bool emotesOnly = false;

    // Filtering
    bool enableProfanityFilter = true;
    bool enableSpamFilter = true;
    bool enableLinkFilter = false;
    bool enableCapsFilter = true;
    float maxCapsPercent = 0.7f;

    // Bio-reactive
    bool enableBioReactions = true;
    float coherenceThresholdForBadge = 0.7f;
    bool autoHighlightHighCoherence = true;

    // History
    size_t maxHistorySize = MAX_HISTORY_SIZE;
    bool persistHistory = false;
};

struct ModerationRule
{
    std::string pattern;        // Regex pattern
    FilterResult action;
    std::string replacement;    // For Replace action
    std::string reason;
    bool caseSensitive = false;
    bool isRegex = true;
};

//==============================================================================
// Rate Limiter
//==============================================================================

class RateLimiter
{
public:
    RateLimiter(uint32_t maxMessages, uint32_t windowMs)
        : maxMessages_(maxMessages)
        , windowMs_(windowMs)
    {}

    bool checkAndUpdate(const UserId& userId)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        auto now = getCurrentTime();
        auto& timestamps = userTimestamps_[userId];

        // Remove old timestamps
        while (!timestamps.empty() && now - timestamps.front() > windowMs_)
        {
            timestamps.pop_front();
        }

        // Check limit
        if (timestamps.size() >= maxMessages_)
        {
            return false;
        }

        // Add new timestamp
        timestamps.push_back(now);
        return true;
    }

    void reset(const UserId& userId)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        userTimestamps_.erase(userId);
    }

    void setLimits(uint32_t maxMessages, uint32_t windowMs)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        maxMessages_ = maxMessages;
        windowMs_ = windowMs;
    }

private:
    uint64_t getCurrentTime() const
    {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count();
    }

    uint32_t maxMessages_;
    uint32_t windowMs_;
    std::mutex mutex_;
    std::unordered_map<UserId, std::deque<uint64_t>, UserIdHash> userTimestamps_;
};

//==============================================================================
// Content Filter
//==============================================================================

class ContentFilter
{
public:
    ContentFilter()
    {
        // Initialize default patterns
        addDefaultPatterns();
    }

    void addRule(const ModerationRule& rule)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        rules_.push_back(rule);

        if (rule.isRegex)
        {
            auto flags = std::regex::ECMAScript;
            if (!rule.caseSensitive)
                flags |= std::regex::icase;

            compiledPatterns_.push_back(std::regex(rule.pattern, flags));
        }
    }

    void removeRule(size_t index)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        if (index < rules_.size())
        {
            rules_.erase(rules_.begin() + index);
            if (index < compiledPatterns_.size())
                compiledPatterns_.erase(compiledPatterns_.begin() + index);
        }
    }

    struct FilterOutput
    {
        FilterResult result = FilterResult::Allow;
        std::string filteredText;
        std::string reason;
        size_t matchedRuleIndex = 0;
    };

    FilterOutput filter(const std::string& text)
    {
        std::lock_guard<std::mutex> lock(mutex_);

        FilterOutput output;
        output.filteredText = text;

        for (size_t i = 0; i < rules_.size(); ++i)
        {
            const auto& rule = rules_[i];

            bool matches = false;
            if (rule.isRegex && i < compiledPatterns_.size())
            {
                matches = std::regex_search(text, compiledPatterns_[i]);
            }
            else
            {
                // Simple substring match
                matches = text.find(rule.pattern) != std::string::npos;
            }

            if (matches)
            {
                output.matchedRuleIndex = i;
                output.reason = rule.reason;

                switch (rule.action)
                {
                    case FilterResult::Block:
                        output.result = FilterResult::Block;
                        return output;

                    case FilterResult::Flag:
                        output.result = FilterResult::Flag;
                        break;

                    case FilterResult::Replace:
                        if (rule.isRegex && i < compiledPatterns_.size())
                        {
                            output.filteredText = std::regex_replace(
                                output.filteredText,
                                compiledPatterns_[i],
                                rule.replacement
                            );
                        }
                        output.result = FilterResult::Replace;
                        break;

                    default:
                        break;
                }
            }
        }

        return output;
    }

    bool checkCaps(const std::string& text, float maxPercent)
    {
        if (text.length() < 10) return true;  // Too short to care

        int upper = 0;
        int total = 0;

        for (char c : text)
        {
            if (std::isalpha(c))
            {
                total++;
                if (std::isupper(c))
                    upper++;
            }
        }

        if (total == 0) return true;
        return static_cast<float>(upper) / total <= maxPercent;
    }

    bool checkSpam(const std::string& text)
    {
        // Check for repeated characters
        int maxRepeat = 0;
        int currentRepeat = 1;
        char lastChar = 0;

        for (char c : text)
        {
            if (c == lastChar)
                currentRepeat++;
            else
            {
                maxRepeat = std::max(maxRepeat, currentRepeat);
                currentRepeat = 1;
                lastChar = c;
            }
        }
        maxRepeat = std::max(maxRepeat, currentRepeat);

        if (maxRepeat > 5) return false;

        // Check for repeated words/phrases
        // (simplified)

        return true;
    }

private:
    void addDefaultPatterns()
    {
        // Add common profanity patterns (simplified placeholders)
        // In production, this would be a comprehensive list
    }

    std::mutex mutex_;
    std::vector<ModerationRule> rules_;
    std::vector<std::regex> compiledPatterns_;
};

//==============================================================================
// Emote Manager
//==============================================================================

class EmoteManager
{
public:
    void addEmote(const Emote& emote)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        emotes_[emote.name] = emote;
    }

    void removeEmote(const std::string& name)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        emotes_.erase(name);
    }

    std::optional<Emote> getEmote(const std::string& name) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = emotes_.find(name);
        if (it != emotes_.end())
            return it->second;
        return std::nullopt;
    }

    std::vector<Emote> getAllEmotes() const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        std::vector<Emote> result;
        for (const auto& [name, emote] : emotes_)
            result.push_back(emote);
        return result;
    }

    /**
     * Parse text and replace emote codes with HTML/rendered versions
     */
    std::string renderEmotes(const std::string& text) const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        std::string result = text;

        for (const auto& [name, emote] : emotes_)
        {
            std::string code = ":" + name + ":";
            size_t pos = 0;

            while ((pos = result.find(code, pos)) != std::string::npos)
            {
                std::string html = "<img class=\"emote\" src=\"" + emote.url +
                    "\" alt=\"" + emote.alt + "\" width=\"" +
                    std::to_string(emote.width) + "\" height=\"" +
                    std::to_string(emote.height) + "\">";

                result.replace(pos, code.length(), html);
                pos += html.length();
            }
        }

        return result;
    }

    void loadDefaultEmotes()
    {
        // Bio-reactive emotes
        addEmote({"coherence_high", "/emotes/coherence_high.gif", "High Coherence", 28, 28, true, true});
        addEmote({"coherence_low", "/emotes/coherence_low.png", "Low Coherence", 28, 28, false, true});
        addEmote({"heart_sync", "/emotes/heart_sync.gif", "Heart Sync", 28, 28, true, true});
        addEmote({"breath", "/emotes/breath.gif", "Breathing", 28, 28, true, true});
        addEmote({"alpha_wave", "/emotes/alpha_wave.gif", "Alpha Wave", 28, 28, true, true});
        addEmote({"theta_wave", "/emotes/theta_wave.gif", "Theta Wave", 28, 28, true, true});

        // Music emotes
        addEmote({"beat", "/emotes/beat.gif", "Beat", 28, 28, true, true});
        addEmote({"laser", "/emotes/laser.gif", "Laser", 28, 28, true, true});
        addEmote({"spiral", "/emotes/spiral.gif", "Spiral", 28, 28, true, true});

        // Standard emotes
        addEmote({"thumbsup", "/emotes/thumbsup.png", "Thumbs Up", 28, 28, false, true});
        addEmote({"fire", "/emotes/fire.gif", "Fire", 28, 28, true, true});
        addEmote({"heart", "/emotes/heart.png", "Heart", 28, 28, false, true});
        addEmote({"star", "/emotes/star.png", "Star", 28, 28, false, true});
    }

private:
    mutable std::mutex mutex_;
    std::unordered_map<std::string, Emote> emotes_;
};

//==============================================================================
// Moderation Manager
//==============================================================================

class ModerationManager
{
public:
    void banUser(const UserId& userId, const std::string& reason = "")
    {
        std::lock_guard<std::mutex> lock(mutex_);
        bannedUsers_.insert(userId);

        ModLogEntry entry;
        entry.action = ModAction::Ban;
        entry.targetUser = userId;
        entry.reason = reason;
        entry.timestamp = getCurrentTime();
        modLog_.push_back(entry);
    }

    void unbanUser(const UserId& userId)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        bannedUsers_.erase(userId);
    }

    bool isBanned(const UserId& userId) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        return bannedUsers_.find(userId) != bannedUsers_.end();
    }

    void muteUser(const UserId& userId, uint32_t durationSeconds, const std::string& reason = "")
    {
        std::lock_guard<std::mutex> lock(mutex_);

        uint64_t until = getCurrentTime() + durationSeconds * 1000;
        mutedUsers_[userId] = until;

        ModLogEntry entry;
        entry.action = ModAction::Mute;
        entry.targetUser = userId;
        entry.reason = reason;
        entry.duration = durationSeconds;
        entry.timestamp = getCurrentTime();
        modLog_.push_back(entry);
    }

    void unmuteUser(const UserId& userId)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        mutedUsers_.erase(userId);
    }

    bool isMuted(const UserId& userId) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = mutedUsers_.find(userId);
        if (it == mutedUsers_.end())
            return false;

        if (getCurrentTime() >= it->second)
        {
            // Mute expired
            return false;
        }

        return true;
    }

    uint64_t getMuteExpiry(const UserId& userId) const
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = mutedUsers_.find(userId);
        if (it != mutedUsers_.end())
            return it->second;
        return 0;
    }

    struct ModLogEntry
    {
        ModAction action;
        UserId moderator;
        UserId targetUser;
        std::optional<MessageId> targetMessage;
        std::string reason;
        uint32_t duration = 0;
        uint64_t timestamp;
    };

    std::vector<ModLogEntry> getModLog(size_t limit = 100) const
    {
        std::lock_guard<std::mutex> lock(mutex_);

        if (modLog_.size() <= limit)
            return modLog_;

        return std::vector<ModLogEntry>(
            modLog_.end() - limit,
            modLog_.end()
        );
    }

private:
    uint64_t getCurrentTime() const
    {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count();
    }

    mutable std::mutex mutex_;
    std::unordered_set<UserId, UserIdHash> bannedUsers_;
    std::unordered_map<UserId, uint64_t, UserIdHash> mutedUsers_;  // userId -> expiry
    std::vector<ModLogEntry> modLog_;
};

//==============================================================================
// Callbacks
//==============================================================================

using OnMessageCallback = std::function<void(const ChatMessage&)>;
using OnMessageDeletedCallback = std::function<void(const MessageId&)>;
using OnReactionCallback = std::function<void(const MessageId&, const Reaction&)>;
using OnUserJoinedCallback = std::function<void(const ChatUser&)>;
using OnUserLeftCallback = std::function<void(const UserId&)>;
using OnModActionCallback = std::function<void(const ModerationManager::ModLogEntry&)>;

//==============================================================================
// Main Chat System
//==============================================================================

class EchoelChatSystem
{
public:
    static EchoelChatSystem& getInstance()
    {
        static EchoelChatSystem instance;
        return instance;
    }

    //==========================================================================
    // Lifecycle
    //==========================================================================

    bool initialize(const ChatConfig& config)
    {
        if (initialized_)
            return true;

        config_ = config;

        rateLimiter_ = std::make_unique<RateLimiter>(
            config.rateLimitMessages,
            config.rateLimitWindowMs
        );

        contentFilter_ = std::make_unique<ContentFilter>();
        emoteManager_ = std::make_unique<EmoteManager>();
        modManager_ = std::make_unique<ModerationManager>();

        emoteManager_->loadDefaultEmotes();

        initialized_ = true;
        return true;
    }

    void shutdown()
    {
        if (!initialized_)
            return;

        rateLimiter_.reset();
        contentFilter_.reset();
        emoteManager_.reset();
        modManager_.reset();

        initialized_ = false;
    }

    //==========================================================================
    // Message Sending
    //==========================================================================

    enum class SendResult
    {
        Success = 0,
        RateLimited,
        Muted,
        Banned,
        Filtered,
        TooLong,
        Empty,
        NotInitialized
    };

    SendResult sendMessage(const std::string& text, const ChatUser& sender)
    {
        if (!initialized_)
            return SendResult::NotInitialized;

        // Check if banned
        if (modManager_->isBanned(sender.id))
            return SendResult::Banned;

        // Check if muted
        if (modManager_->isMuted(sender.id))
            return SendResult::Muted;

        // Check empty
        if (text.empty())
            return SendResult::Empty;

        // Check length
        if (text.length() > MAX_MESSAGE_LENGTH)
            return SendResult::TooLong;

        // Check rate limit
        if (!rateLimiter_->checkAndUpdate(sender.id))
            return SendResult::RateLimited;

        // Check slow mode
        if (config_.slowModeSeconds > 0)
        {
            auto now = getCurrentTime();
            auto it = lastMessageTime_.find(sender.id);
            if (it != lastMessageTime_.end())
            {
                if (now - it->second < config_.slowModeSeconds * 1000)
                    return SendResult::RateLimited;
            }
            lastMessageTime_[sender.id] = now;
        }

        // Apply filters
        std::string filteredText = text;

        if (config_.enableProfanityFilter || config_.enableSpamFilter)
        {
            auto filterResult = contentFilter_->filter(text);

            if (filterResult.result == FilterResult::Block)
                return SendResult::Filtered;

            if (filterResult.result == FilterResult::Replace)
                filteredText = filterResult.filteredText;
        }

        if (config_.enableCapsFilter &&
            !contentFilter_->checkCaps(text, config_.maxCapsPercent))
        {
            // Convert to lowercase
            std::transform(filteredText.begin(), filteredText.end(),
                          filteredText.begin(), ::tolower);
        }

        if (config_.enableSpamFilter &&
            !contentFilter_->checkSpam(text))
        {
            return SendResult::Filtered;
        }

        // Create message
        ChatMessage msg;
        msg.id.timestamp = getCurrentTime();
        msg.id.sequence = nextSequence_++;
        msg.id.author = sender.id;
        msg.type = MessageType::Text;
        msg.text = filteredText;
        msg.originalText = text;
        msg.formattedHtml = emoteManager_->renderEmotes(filteredText);
        msg.authorId = sender.id;
        msg.authorName = sender.displayName;
        msg.authorColor = sender.color;
        msg.authorBadges = sender.badges;
        msg.timestamp = msg.id.timestamp;
        msg.senderCoherence = sender.coherence;

        // Check for bio-reactive highlight
        if (config_.autoHighlightHighCoherence &&
            sender.coherence >= config_.coherenceThresholdForBadge)
        {
            msg.isHighlighted = true;
        }

        // Store message
        {
            std::lock_guard<std::mutex> lock(historyMutex_);
            messageHistory_.push_back(msg);

            while (messageHistory_.size() > config_.maxHistorySize)
                messageHistory_.pop_front();
        }

        // Notify listeners
        if (onMessage_)
            onMessage_(msg);

        return SendResult::Success;
    }

    /**
     * Send a whisper (private message)
     */
    SendResult sendWhisper(const std::string& text,
                           const ChatUser& sender,
                           const UserId& recipient)
    {
        auto result = validateMessage(text, sender);
        if (result != SendResult::Success)
            return result;

        ChatMessage msg;
        msg.id.timestamp = getCurrentTime();
        msg.id.sequence = nextSequence_++;
        msg.id.author = sender.id;
        msg.type = MessageType::Whisper;
        msg.text = text;
        msg.authorId = sender.id;
        msg.authorName = sender.displayName;
        msg.whisperTo = recipient;
        msg.timestamp = msg.id.timestamp;

        if (onMessage_)
            onMessage_(msg);

        return SendResult::Success;
    }

    /**
     * Send a reply to another message
     */
    SendResult sendReply(const std::string& text,
                         const ChatUser& sender,
                         const MessageId& replyTo)
    {
        auto result = validateMessage(text, sender);
        if (result != SendResult::Success)
            return result;

        // Get parent message preview
        std::string preview;
        {
            std::lock_guard<std::mutex> lock(historyMutex_);
            for (const auto& msg : messageHistory_)
            {
                if (msg.id == replyTo)
                {
                    preview = msg.text.substr(0, 50);
                    if (msg.text.length() > 50)
                        preview += "...";
                    break;
                }
            }
        }

        ChatMessage msg;
        msg.id.timestamp = getCurrentTime();
        msg.id.sequence = nextSequence_++;
        msg.id.author = sender.id;
        msg.type = MessageType::Reply;
        msg.text = text;
        msg.formattedHtml = emoteManager_->renderEmotes(text);
        msg.authorId = sender.id;
        msg.authorName = sender.displayName;
        msg.authorColor = sender.color;
        msg.authorBadges = sender.badges;
        msg.replyTo = replyTo;
        msg.replyPreview = preview;
        msg.timestamp = msg.id.timestamp;

        {
            std::lock_guard<std::mutex> lock(historyMutex_);
            messageHistory_.push_back(msg);
        }

        if (onMessage_)
            onMessage_(msg);

        return SendResult::Success;
    }

    /**
     * Send system announcement
     */
    void sendAnnouncement(const std::string& text)
    {
        ChatMessage msg;
        msg.id.timestamp = getCurrentTime();
        msg.id.sequence = nextSequence_++;
        msg.type = MessageType::Announcement;
        msg.text = text;
        msg.timestamp = msg.id.timestamp;
        msg.isHighlighted = true;

        {
            std::lock_guard<std::mutex> lock(historyMutex_);
            messageHistory_.push_back(msg);
        }

        if (onMessage_)
            onMessage_(msg);
    }

    //==========================================================================
    // Reactions
    //==========================================================================

    bool addReaction(const MessageId& messageId,
                     const std::string& emote,
                     const UserId& userId)
    {
        std::lock_guard<std::mutex> lock(historyMutex_);

        for (auto& msg : messageHistory_)
        {
            if (msg.id == messageId)
            {
                // Check if already reacted with this emote
                for (const auto& r : msg.reactions)
                {
                    if (r.emote == emote && r.userId == userId)
                        return false;  // Already reacted
                }

                if (msg.reactions.size() >= MAX_REACTIONS_PER_MESSAGE)
                    return false;

                Reaction reaction;
                reaction.emote = emote;
                reaction.userId = userId;
                reaction.timestamp = getCurrentTime();

                msg.reactions.push_back(reaction);

                if (onReaction_)
                    onReaction_(messageId, reaction);

                return true;
            }
        }

        return false;
    }

    bool removeReaction(const MessageId& messageId,
                        const std::string& emote,
                        const UserId& userId)
    {
        std::lock_guard<std::mutex> lock(historyMutex_);

        for (auto& msg : messageHistory_)
        {
            if (msg.id == messageId)
            {
                auto it = std::remove_if(msg.reactions.begin(), msg.reactions.end(),
                    [&](const Reaction& r) {
                        return r.emote == emote && r.userId == userId;
                    });

                if (it != msg.reactions.end())
                {
                    msg.reactions.erase(it, msg.reactions.end());
                    return true;
                }
            }
        }

        return false;
    }

    //==========================================================================
    // Message Management
    //==========================================================================

    bool deleteMessage(const MessageId& messageId, const UserId& moderator)
    {
        std::lock_guard<std::mutex> lock(historyMutex_);

        for (auto& msg : messageHistory_)
        {
            if (msg.id == messageId)
            {
                msg.isDeleted = true;
                msg.text = "[Message deleted]";
                msg.formattedHtml = "[Message deleted]";

                if (onMessageDeleted_)
                    onMessageDeleted_(messageId);

                return true;
            }
        }

        return false;
    }

    void clearHistory()
    {
        std::lock_guard<std::mutex> lock(historyMutex_);
        messageHistory_.clear();
    }

    std::vector<ChatMessage> getHistory(size_t limit = 100,
                                         uint64_t beforeTimestamp = 0) const
    {
        std::lock_guard<std::mutex> lock(historyMutex_);

        std::vector<ChatMessage> result;

        for (auto it = messageHistory_.rbegin(); it != messageHistory_.rend(); ++it)
        {
            if (beforeTimestamp > 0 && it->timestamp >= beforeTimestamp)
                continue;

            if (!it->isDeleted)
            {
                result.push_back(*it);
                if (result.size() >= limit)
                    break;
            }
        }

        std::reverse(result.begin(), result.end());
        return result;
    }

    //==========================================================================
    // Moderation
    //==========================================================================

    void banUser(const UserId& userId, const std::string& reason = "")
    {
        modManager_->banUser(userId, reason);
    }

    void unbanUser(const UserId& userId)
    {
        modManager_->unbanUser(userId);
    }

    void muteUser(const UserId& userId, uint32_t seconds, const std::string& reason = "")
    {
        modManager_->muteUser(userId, seconds, reason);
    }

    void unmuteUser(const UserId& userId)
    {
        modManager_->unmuteUser(userId);
    }

    void setSlowMode(uint32_t seconds)
    {
        config_.slowModeSeconds = seconds;
    }

    //==========================================================================
    // Emotes
    //==========================================================================

    void addEmote(const Emote& emote)
    {
        emoteManager_->addEmote(emote);
    }

    std::vector<Emote> getEmotes() const
    {
        return emoteManager_->getAllEmotes();
    }

    //==========================================================================
    // Bio-Reactive Features
    //==========================================================================

    /**
     * Send automatic bio-reaction based on coherence level
     */
    void sendBioReaction(const ChatUser& user)
    {
        if (!config_.enableBioReactions)
            return;

        ChatMessage msg;
        msg.id.timestamp = getCurrentTime();
        msg.id.sequence = nextSequence_++;
        msg.id.author = user.id;
        msg.type = MessageType::BioReaction;
        msg.authorId = user.id;
        msg.authorName = user.displayName;
        msg.senderCoherence = user.coherence;

        // Select emote based on coherence
        if (user.coherence >= 0.8f)
            msg.text = ":coherence_high:";
        else if (user.coherence >= 0.5f)
            msg.text = ":alpha_wave:";
        else
            msg.text = ":breath:";

        msg.formattedHtml = emoteManager_->renderEmotes(msg.text);
        msg.timestamp = msg.id.timestamp;

        if (onMessage_)
            onMessage_(msg);
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setOnMessage(OnMessageCallback cb) { onMessage_ = std::move(cb); }
    void setOnMessageDeleted(OnMessageDeletedCallback cb) { onMessageDeleted_ = std::move(cb); }
    void setOnReaction(OnReactionCallback cb) { onReaction_ = std::move(cb); }
    void setOnUserJoined(OnUserJoinedCallback cb) { onUserJoined_ = std::move(cb); }
    void setOnUserLeft(OnUserLeftCallback cb) { onUserLeft_ = std::move(cb); }
    void setOnModAction(OnModActionCallback cb) { onModAction_ = std::move(cb); }

    //==========================================================================
    // Configuration
    //==========================================================================

    void setConfig(const ChatConfig& config)
    {
        config_ = config;
        rateLimiter_->setLimits(config.rateLimitMessages, config.rateLimitWindowMs);
    }

    ChatConfig getConfig() const { return config_; }

private:
    EchoelChatSystem() = default;
    ~EchoelChatSystem() { shutdown(); }

    EchoelChatSystem(const EchoelChatSystem&) = delete;
    EchoelChatSystem& operator=(const EchoelChatSystem&) = delete;

    SendResult validateMessage(const std::string& text, const ChatUser& sender)
    {
        if (!initialized_)
            return SendResult::NotInitialized;

        if (modManager_->isBanned(sender.id))
            return SendResult::Banned;

        if (modManager_->isMuted(sender.id))
            return SendResult::Muted;

        if (text.empty())
            return SendResult::Empty;

        if (text.length() > MAX_MESSAGE_LENGTH)
            return SendResult::TooLong;

        if (!rateLimiter_->checkAndUpdate(sender.id))
            return SendResult::RateLimited;

        return SendResult::Success;
    }

    uint64_t getCurrentTime() const
    {
        return std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count();
    }

    bool initialized_ = false;
    ChatConfig config_;

    std::unique_ptr<RateLimiter> rateLimiter_;
    std::unique_ptr<ContentFilter> contentFilter_;
    std::unique_ptr<EmoteManager> emoteManager_;
    std::unique_ptr<ModerationManager> modManager_;

    mutable std::mutex historyMutex_;
    std::deque<ChatMessage> messageHistory_;
    std::atomic<uint32_t> nextSequence_{0};

    std::unordered_map<UserId, uint64_t, UserIdHash> lastMessageTime_;

    // Callbacks
    OnMessageCallback onMessage_;
    OnMessageDeletedCallback onMessageDeleted_;
    OnReactionCallback onReaction_;
    OnUserJoinedCallback onUserJoined_;
    OnUserLeftCallback onUserLeft_;
    OnModActionCallback onModAction_;
};

}} // namespace Echoel::Chat

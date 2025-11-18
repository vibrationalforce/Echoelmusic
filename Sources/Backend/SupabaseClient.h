/**
 * Supabase Client for C++ (JUCE)
 * Provides REST API access to Supabase backend
 * Used by Desktop (Windows/Linux/macOS) and Android builds
 */

#pragma once

#include <JuceHeader.h>
#include <functional>
#include <memory>

namespace Echoelmusic {
namespace Backend {

/**
 * Supabase REST API Client
 * Handles authentication, database queries, and storage uploads
 */
class SupabaseClient
{
public:
    // Singleton access
    static SupabaseClient& getInstance();

    // Configuration
    struct Config
    {
        juce::String url;      // Supabase project URL
        juce::String anonKey;  // Supabase anon/public key
        juce::String schema = "public";
    };

    void initialize(const Config& config);
    bool isInitialized() const { return initialized; }

    // ========================================================================
    // AUTHENTICATION
    // ========================================================================

    struct AuthResponse
    {
        bool success;
        juce::String error;
        juce::String accessToken;
        juce::String refreshToken;
        juce::String userId;
        juce::String email;
    };

    using AuthCallback = std::function<void(const AuthResponse&)>;

    void signUp(
        const juce::String& email,
        const juce::String& password,
        const juce::var& metadata,
        AuthCallback callback
    );

    void signIn(
        const juce::String& email,
        const juce::String& password,
        AuthCallback callback
    );

    void signOut(std::function<void(bool)> callback);

    void refreshSession(AuthCallback callback);

    // Get current access token
    juce::String getAccessToken() const { return currentAccessToken; }
    juce::String getUserId() const { return currentUserId; }
    bool isAuthenticated() const { return !currentAccessToken.isEmpty(); }

    // ========================================================================
    // DATABASE (PostgreSQL REST)
    // ========================================================================

    struct QueryResponse
    {
        bool success;
        juce::String error;
        juce::var data; // JSON response
        int count = 0;  // Row count (if requested)
    };

    using QueryCallback = std::function<void(const QueryResponse&)>;

    // SELECT query
    void select(
        const juce::String& table,
        const juce::String& columns = "*",
        const juce::String& filter = "",
        const juce::String& orderBy = "",
        int limit = -1,
        QueryCallback callback = nullptr
    );

    // INSERT query
    void insert(
        const juce::String& table,
        const juce::var& data,
        QueryCallback callback = nullptr
    );

    // UPDATE query
    void update(
        const juce::String& table,
        const juce::var& data,
        const juce::String& filter,
        QueryCallback callback = nullptr
    );

    // DELETE query
    void deleteRows(
        const juce::String& table,
        const juce::String& filter,
        QueryCallback callback = nullptr
    );

    // RPC (Remote Procedure Call)
    void rpc(
        const juce::String& functionName,
        const juce::var& params,
        QueryCallback callback = nullptr
    );

    // ========================================================================
    // STORAGE
    // ========================================================================

    struct UploadResponse
    {
        bool success;
        juce::String error;
        juce::String url;    // Public URL
        juce::String path;   // Storage path
    };

    using UploadCallback = std::function<void(const UploadResponse&)>;

    void uploadFile(
        const juce::String& bucket,
        const juce::String& path,
        const juce::File& file,
        const juce::String& contentType = "application/octet-stream",
        UploadCallback callback = nullptr
    );

    void uploadData(
        const juce::String& bucket,
        const juce::String& path,
        const juce::MemoryBlock& data,
        const juce::String& contentType = "application/octet-stream",
        UploadCallback callback = nullptr
    );

    void downloadFile(
        const juce::String& bucket,
        const juce::String& path,
        std::function<void(bool success, juce::MemoryBlock data, juce::String error)> callback
    );

    juce::String getPublicURL(
        const juce::String& bucket,
        const juce::String& path
    );

    void deleteFile(
        const juce::String& bucket,
        const juce::StringArray& paths,
        std::function<void(bool success, juce::String error)> callback
    );

    // ========================================================================
    // REALTIME (WebSocket)
    // ========================================================================

    class RealtimeChannel
    {
    public:
        enum class Event
        {
            INSERT,
            UPDATE,
            DELETE,
            ALL
        };

        using ChangeCallback = std::function<void(const juce::var& payload)>;

        virtual ~RealtimeChannel() = default;
        virtual void subscribe() = 0;
        virtual void unsubscribe() = 0;
        virtual bool isSubscribed() const = 0;
    };

    std::unique_ptr<RealtimeChannel> createChannel(
        const juce::String& channelName,
        const juce::String& table,
        RealtimeChannel::Event event,
        const juce::String& filter,
        RealtimeChannel::ChangeCallback callback
    );

private:
    SupabaseClient() = default;
    ~SupabaseClient() = default;

    // Disable copy/move
    SupabaseClient(const SupabaseClient&) = delete;
    SupabaseClient& operator=(const SupabaseClient&) = delete;

    // Configuration
    Config config;
    bool initialized = false;

    // Auth state
    juce::String currentAccessToken;
    juce::String currentRefreshToken;
    juce::String currentUserId;
    juce::Time tokenExpiresAt;

    // HTTP helpers
    juce::URL buildURL(const juce::String& endpoint) const;

    juce::StringPairArray buildHeaders(bool includeAuth = true) const;

    void performRequest(
        const juce::URL& url,
        const juce::String& method,
        const juce::var& body,
        const juce::StringPairArray& extraHeaders,
        std::function<void(int statusCode, juce::String response)> callback
    );

    // Auth token management
    void saveTokens(const juce::String& accessToken, const juce::String& refreshToken, int expiresIn);
    void loadTokens();
    void clearTokens();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SupabaseClient)
};

} // namespace Backend
} // namespace Echoelmusic

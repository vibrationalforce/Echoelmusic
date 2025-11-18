#pragma once

#include <JuceHeader.h>
#include <functional>
#include <memory>

/**
 * Supabase Client - Backend Integration for Echoelmusic
 *
 * Provides cloud services:
 * - User authentication (sign up, sign in, OAuth)
 * - Project cloud storage and sync
 * - Preset marketplace (browse, purchase, download)
 * - Real-time collaboration (WebSocket)
 * - Analytics and telemetry
 * - Social features (share, like, comment)
 *
 * Uses JUCE networking for cross-platform compatibility.
 */
class SupabaseClient
{
public:
    //==============================================================================
    SupabaseClient(const juce::String& url, const juce::String& anonKey);
    ~SupabaseClient() = default;

    //==============================================================================
    // Authentication
    struct User {
        juce::String id;
        juce::String email;
        juce::String username;
        juce::String avatarUrl;
        juce::String subscriptionTier;  // free, pro, enterprise
        juce::var metadata;  // Custom user data
    };

    struct AuthResponse {
        bool success = false;
        juce::String error;
        User user;
        juce::String accessToken;
        juce::String refreshToken;
    };

    using AuthCallback = std::function<void(AuthResponse)>;

    void signUp(const juce::String& email, const juce::String& password, AuthCallback callback);
    void signIn(const juce::String& email, const juce::String& password, AuthCallback callback);
    void signOut();
    void refreshSession(AuthCallback callback);

    User getCurrentUser() const { return currentUser; }
    bool isAuthenticated() const { return !accessToken.isEmpty(); }
    juce::String getAccessToken() const { return accessToken; }

    //==============================================================================
    // Project Storage
    struct Project {
        juce::String id;
        juce::String userId;
        juce:String name;
        juce::String description;
        juce::var data;  // JSON serialized project
        juce::String thumbnailUrl;
        bool isPublic = false;
        juce::Time createdAt;
        juce::Time updatedAt;
    };

    using ProjectCallback = std::function<void(bool success, Project project, juce::String error)>;
    using ProjectListCallback = std::function<void(bool success, std::vector<Project> projects, juce::String error)>;

    void saveProject(const Project& project, ProjectCallback callback);
    void loadProject(const juce::String& projectId, ProjectCallback callback);
    void deleteProject(const juce::String& projectId, std::function<void(bool success, juce::String error)> callback);
    void listUserProjects(ProjectListCallback callback);
    void listPublicProjects(int limit, int offset, ProjectListCallback callback);

    //==============================================================================
    // Preset Marketplace
    struct Preset {
        juce::String id;
        juce::String creatorId;
        juce::String creatorName;
        juce::String instrumentType;  // "EchoelSynth", "Echoel808", etc.
        juce::String name;
        juce::String description;
        juce::var data;  // Preset parameters
        juce::String previewUrl;  // Audio preview
        float price = 0.0f;  // USD, 0 = free
        int downloads = 0;
        float rating = 0.0f;  // 0-5
        int numRatings = 0;
        juce::Time createdAt;
    };

    using PresetCallback = std::function<void(bool success, Preset preset, juce::String error)>;
    using PresetListCallback = std::function<void(bool success, std::vector<Preset> presets, juce::String error)>;

    void uploadPreset(const Preset& preset, PresetCallback callback);
    void downloadPreset(const juce::String& presetId, PresetCallback callback);
    void searchPresets(const juce::String& instrument, const juce::String& searchTerm,
                      int limit, PresetListCallback callback);
    void getTopPresets(const juce::String& instrument, int limit, PresetListCallback callback);
    void ratePreset(const juce::String& presetId, float rating,
                    std::function<void(bool success, juce::String error)> callback);
    void purchasePreset(const juce::String& presetId,
                       std::function<void(bool success, juce::String error)> callback);

    //==============================================================================
    // Real-time Collaboration
    class CollaborationSession
    {
    public:
        virtual ~CollaborationSession() = default;

        struct Change {
            juce::String userId;
            juce::String userName;
            juce::String changeType;  // "parameter", "track", "effect", etc.
            juce::var data;
            juce::Time timestamp;
        };

        using ChangeCallback = std::function<void(const Change&)>;

        virtual void sendChange(const Change& change) = 0;
        virtual void disconnect() = 0;
    };

    std::unique_ptr<CollaborationSession> joinCollaboration(
        const juce::String& projectId,
        CollaborationSession::ChangeCallback onChangeReceived
    );

    //==============================================================================
    // Analytics
    void trackEvent(const juce::String& eventName, const juce::var& properties);
    void trackScreenView(const juce::String& screenName);
    void trackError(const juce::String& errorMessage, const juce::var& context);

    // Usage statistics
    struct UsageStats {
        int projectsCreated = 0;
        int presetsDownloaded = 0;
        int collaborationSessions = 0;
        float totalPlayTime = 0.0f;  // hours
        juce::StringArray favoriteInstruments;
    };

    void getUsageStats(std::function<void(bool success, UsageStats stats, juce::String error)> callback);

    //==============================================================================
    // Social Features
    void shareProject(const juce::String& projectId, const juce::String& platform,
                     std::function<void(bool success, juce::String shareUrl, juce::String error)> callback);
    void likePreset(const juce::String& presetId, std::function<void(bool success)> callback);
    void commentOnPreset(const juce::String& presetId, const juce::String& comment,
                        std::function<void(bool success)> callback);

    //==============================================================================
    // File Storage (Supabase Storage)
    void uploadFile(const juce::File& file, const juce::String& bucket, const juce::String& path,
                   std::function<void(bool success, juce::String url, juce::String error)> callback);
    void downloadFile(const juce::String& url, const juce::File& destination,
                     std::function<void(bool success, juce::String error)> callback);

private:
    //==============================================================================
    // Configuration
    juce::String supabaseUrl;
    juce::String supabaseAnonKey;
    juce::String accessToken;
    User currentUser;

    //==============================================================================
    // HTTP Helper
    struct RequestOptions {
        juce::String method = "GET";
        juce::var body;
        bool requiresAuth = false;
        juce::StringPairArray headers;
    };

    void makeRequest(const juce::String& endpoint, const RequestOptions& options,
                    std::function<void(bool success, juce::var response, juce::String error)> callback);

    //==============================================================================
    // Endpoints
    juce::String authEndpoint() const { return supabaseUrl + "/auth/v1"; }
    juce::String restEndpoint() const { return supabaseUrl + "/rest/v1"; }
    juce::String storageEndpoint() const { return supabaseUrl + "/storage/v1"; }
    juce::String realtimeEndpoint() const { return supabaseUrl + "/realtime/v1"; }

    //==============================================================================
    // Real-time WebSocket
    class RealtimeConnection : public CollaborationSession,
                              private juce::WebSocket::Listener
    {
    public:
        RealtimeConnection(const juce::String& url, const juce::String& token,
                          const juce::String& projectId,
                          ChangeCallback callback);
        ~RealtimeConnection() override;

        void sendChange(const Change& change) override;
        void disconnect() override;

    private:
        void messageReceived(const juce::String& message) override;
        void connectionOpened() override;
        void connectionClosed(int status, const juce::String& reason) override;
        void connectionError(const juce::String& error) override;

        std::unique_ptr<juce::WebSocket> webSocket;
        juce::String projectId;
        ChangeCallback changeCallback;
    };

    //==============================================================================
    // Session Management
    juce::String sessionId;
    void generateSessionId();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SupabaseClient)
};

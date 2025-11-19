#pragma once

#include <JuceHeader.h>
#include <memory>
#include <functional>

/**
 * SessionSharing - QR Code + Link-Based Collaboration
 *
 * Inspired by: Flockdraw, Figma, Google Docs, Discord
 *
 * Features:
 * - Generate shareable session links (echoelmusic.app/join/ABC123)
 * - QR Code generation for mobile joining
 * - Instant join via link click (zero setup)
 * - Room-based collaboration (like flockdraw)
 * - Real-time presence indicators
 * - Host/Guest permissions
 * - Session expiry & cleanup
 *
 * Use Cases:
 * - Producer shares link → Friend joins instantly
 * - Live performance: Show QR on screen → Audience joins
 * - Teaching: Share link in chat → Students join session
 * - Jam session: Scan QR → Start playing together
 *
 * Technology:
 * - WebRTC for P2P connection (implemented in WebRTCTransport)
 * - Signaling server for initial handshake
 * - QR Code generation (libqrencode or custom)
 * - Deep linking (echoelmusic://)
 */
class SessionSharing
{
public:
    //==========================================================================
    // Session Info
    //==========================================================================

    struct Session
    {
        juce::String sessionId;         // "ABC123" (6-char random)
        juce::String hostName;          // "DJ Max"
        juce::String hostDeviceId;      // Unique device ID

        juce::String shareableLink;     // "https://echoelmusic.app/join/ABC123"
        juce::String deepLink;          // "echoelmusic://join/ABC123"

        juce::Time createdAt;
        juce::Time expiresAt;           // Default: 24 hours

        int maxParticipants = 8;        // Limit for free tier
        int currentParticipants = 0;

        enum class Permissions
        {
            ViewOnly,       // Watch only (like Twitch)
            Contribute,     // Can add tracks/effects
            FullControl     // Can control everything
        };

        Permissions defaultPermission = Permissions::Contribute;

        bool isPublic = true;           // Listed in public rooms
        bool requiresPassword = false;
        juce::String password;          // Optional

        // Room settings
        double tempo = 120.0;
        int timeSignature = 4;
        juce::String key = "C";         // Musical key

        // Bio-sync settings
        bool shareBioData = false;      // Share HRV/coherence
        bool groupCoherence = true;     // Calculate group coherence
    };

    //==========================================================================
    // Participant Info
    //==========================================================================

    struct Participant
    {
        juce::String userId;            // Unique ID
        juce::String displayName;       // "Sarah"
        juce::String deviceType;        // "iPhone 15 Pro", "Windows PC"

        juce::Colour avatarColor;       // Random color (like flockdraw)

        Session::Permissions permission;

        // Status
        bool isHost = false;
        bool isMuted = false;
        bool isOnline = true;

        juce::Time joinedAt;
        juce::Time lastSeenAt;

        // Cursor position (like Google Docs)
        int currentTrackIndex = -1;
        double currentTimeSeconds = 0.0;

        // Bio data (if shared)
        float hrv = 0.0f;
        float coherence = 0.0f;
    };

    //==========================================================================
    // QR Code Data
    //==========================================================================

    struct QRCode
    {
        juce::String data;              // URL or deep link
        juce::Image image;              // QR code as image
        int size = 512;                 // Pixels

        enum class ErrorCorrection
        {
            Low,        // 7% recovery
            Medium,     // 15% recovery
            Quartile,   // 25% recovery
            High        // 30% recovery
        };

        ErrorCorrection errorCorrection = ErrorCorrection::Medium;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SessionSharing();
    ~SessionSharing();

    //==========================================================================
    // Host - Create Session
    //==========================================================================

    /** Create new session and get shareable link */
    Session createSession(const juce::String& hostName,
                         Session::Permissions defaultPermission = Session::Permissions::Contribute);

    /** Generate QR code for current session */
    QRCode generateQRCode(int size = 512);

    /** Get shareable link */
    juce::String getShareableLink() const;

    /** Get deep link (for mobile apps) */
    juce::String getDeepLink() const;

    /** Copy link to clipboard */
    void copyLinkToClipboard();

    /** Close session */
    void closeSession();

    //==========================================================================
    // Guest - Join Session
    //==========================================================================

    /** Join session via link */
    bool joinSession(const juce::String& sessionLink,
                    const juce::String& displayName);

    /** Join session via QR code scan */
    bool joinSessionFromQRCode(const juce::String& qrData,
                              const juce::String& displayName);

    /** Join session by ID */
    bool joinSessionById(const juce::String& sessionId,
                        const juce::String& displayName);

    /** Leave session */
    void leaveSession();

    //==========================================================================
    // Session Management
    //==========================================================================

    /** Check if hosting a session */
    bool isHosting() const;

    /** Check if in a session */
    bool isInSession() const;

    /** Get current session info */
    Session getCurrentSession() const;

    /** Get list of participants */
    juce::Array<Participant> getParticipants() const;

    /** Kick participant (host only) */
    bool kickParticipant(const juce::String& userId);

    /** Change participant permission (host only) */
    bool setParticipantPermission(const juce::String& userId,
                                 Session::Permissions permission);

    /** Transfer host to another participant */
    bool transferHost(const juce::String& newHostUserId);

    //==========================================================================
    // Public Room Discovery (like flockdraw rooms list)
    //==========================================================================

    struct PublicRoom
    {
        juce::String sessionId;
        juce::String hostName;
        int participantCount;
        int maxParticipants;
        double tempo;
        juce::String musicalKey;
        juce::Time createdAt;
        bool hasPassword;
    };

    /** Get list of public rooms */
    juce::Array<PublicRoom> getPublicRooms();

    /** Join public room from list */
    bool joinPublicRoom(const juce::String& sessionId,
                       const juce::String& displayName,
                       const juce::String& password = "");

    //==========================================================================
    // Real-Time Updates
    //==========================================================================

    /** Callbacks for real-time events */
    std::function<void(const Participant&)> onParticipantJoined;
    std::function<void(const Participant&)> onParticipantLeft;
    std::function<void(const Participant&)> onParticipantUpdated;

    std::function<void(const Session&)> onSessionUpdated;
    std::function<void(const juce::String& message)> onChatMessage;

    // Cursor tracking (like Google Docs)
    std::function<void(const juce::String& userId, int trackIndex, double time)> onCursorMoved;

    //==========================================================================
    // Chat System
    //==========================================================================

    struct ChatMessage
    {
        juce::String userId;
        juce::String userName;
        juce::String message;
        juce::Time timestamp;
        juce::Colour userColor;
    };

    /** Send chat message */
    void sendChatMessage(const juce::String& message);

    /** Get chat history */
    juce::Array<ChatMessage> getChatHistory() const;

    //==========================================================================
    // Signaling Server Configuration
    //==========================================================================

    struct SignalingConfig
    {
        juce::String serverUrl = "wss://signaling.echoelmusic.app";
        int port = 443;
        bool useSSL = true;

        // For self-hosted
        juce::String customServerUrl;
    };

    void setSignalingConfig(const SignalingConfig& config);

    //==========================================================================
    // Analytics (Optional)
    //==========================================================================

    struct SessionStats
    {
        int totalParticipants = 0;
        juce::Time sessionDuration;
        int messagesExchanged = 0;
        int64_t bytesTransferred = 0;

        // Group metrics
        float averageGroupCoherence = 0.0f;
        float peakGroupCoherence = 0.0f;
    };

    SessionStats getSessionStats() const;

private:
    //==========================================================================
    // Internal Implementation
    //==========================================================================

    struct SignalingConnection;
    std::unique_ptr<SignalingConnection> signaling;

    Session currentSession;
    juce::Array<Participant> participants;
    juce::Array<ChatMessage> chatHistory;

    std::atomic<bool> isHost { false };
    std::atomic<bool> inSession { false };

    juce::String myUserId;
    juce::String myDisplayName;

    SessionStats stats;

    // QR Code generation
    juce::Image generateQRCodeImage(const juce::String& data, int size);

    // Session ID generation (6-char alphanumeric)
    juce::String generateSessionId();

    // Signaling
    void connectToSignalingServer();
    void disconnectFromSignalingServer();
    void sendSignalingMessage(const juce::var& message);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SessionSharing)
};

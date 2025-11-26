#include "SessionSharing.h"
#include <random>

//==============================================================================
// Signaling Server Connection (WebSocket)
//==============================================================================

struct SessionSharing::SignalingConnection
{
    // WebSocket connection to signaling server
    // Uses JUCE WebSocket or similar
    // std::unique_ptr<juce::WebSocket> socket;

    juce::String serverUrl = "wss://signaling.echoelmusic.app";
    bool isConnected = false;

    SignalingConnection()
    {
        DBG("Signaling: Initialized (placeholder mode)");
        DBG("Signaling: Production requires WebSocket server:");
        DBG("  - Node.js + Socket.io");
        DBG("  - Or use existing services: PeerJS, Firebase");
    }

    void connect(const juce::String& url)
    {
        serverUrl = url;
        // socket = std::make_unique<juce::WebSocket>(url);
        // socket->connect();

        DBG("Signaling: Connecting to " << url);

        // Simulate connection
        juce::Thread::sleep(50);
        isConnected = true;

        DBG("Signaling: Connected!");
    }

    void disconnect()
    {
        if (!isConnected)
            return;

        // socket->close();
        isConnected = false;
        DBG("Signaling: Disconnected");
    }

    void send(const juce::var& message)
    {
        if (!isConnected)
            return;

        juce::String json = juce::JSON::toString(message);
        // socket->send(json);

        DBG("Signaling: Sent message: " << json.substring(0, 100));
    }

    juce::var receive()
    {
        if (!isConnected)
            return {};

        // juce::String received = socket->receive();
        // return juce::JSON::parse(received);

        return {};  // Placeholder
    }
};

//==============================================================================
// Constructor / Destructor
//==============================================================================

SessionSharing::SessionSharing()
{
    signaling = std::make_unique<SignalingConnection>();

    // Generate unique user ID
    myUserId = juce::Uuid().toString();

    DBG("SessionSharing: Initialized - User ID: " << myUserId);
}

SessionSharing::~SessionSharing()
{
    if (inSession)
        leaveSession();

    if (isHost)
        closeSession();
}

//==============================================================================
// Session ID Generation
//==============================================================================

juce::String SessionSharing::generateSessionId()
{
    // Generate 6-character alphanumeric ID (like Zoom: 123-456-789)
    const char* chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    juce::String id;

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 35);

    for (int i = 0; i < 6; ++i)
        id += chars[dis(gen)];

    return id;
}

//==============================================================================
// Host - Create Session
//==============================================================================

SessionSharing::Session SessionSharing::createSession(
    const juce::String& hostName,
    Session::Permissions defaultPermission)
{
    if (isHost || inSession)
    {
        DBG("SessionSharing: Already in a session! Close/leave first.");
        return currentSession;
    }

    // Generate session ID
    currentSession.sessionId = generateSessionId();
    currentSession.hostName = hostName;
    currentSession.hostDeviceId = myUserId;

    // Generate links
    currentSession.shareableLink = "https://echoelmusic.app/join/" + currentSession.sessionId;
    currentSession.deepLink = "echoelmusic://join/" + currentSession.sessionId;

    // Set timestamps
    currentSession.createdAt = juce::Time::getCurrentTime();
    currentSession.expiresAt = currentSession.createdAt + juce::RelativeTime::hours(24);

    // Set defaults
    currentSession.defaultPermission = defaultPermission;

    isHost = true;
    inSession = true;
    myDisplayName = hostName;

    // Add host as first participant
    Participant host;
    host.userId = myUserId;
    host.displayName = hostName;
    host.isHost = true;
    host.permission = Session::Permissions::FullControl;
    host.joinedAt = juce::Time::getCurrentTime();
    host.lastSeenAt = host.joinedAt;
    host.avatarColor = juce::Colours::cyan;

    participants.add(host);
    currentSession.currentParticipants = 1;

    // Connect to signaling server
    connectToSignalingServer();

    // Register session with signaling server
    juce::var message;
    message.getDynamicObject()->setProperty("type", "create_session");
    message.getDynamicObject()->setProperty("sessionId", currentSession.sessionId);
    message.getDynamicObject()->setProperty("hostName", hostName);
    message.getDynamicObject()->setProperty("isPublic", currentSession.isPublic);

    signaling->send(message);

    DBG("SessionSharing: Created session - ID: " << currentSession.sessionId);
    DBG("SessionSharing: Link: " << currentSession.shareableLink);

    return currentSession;
}

SessionSharing::QRCode SessionSharing::generateQRCode(int size)
{
    QRCode qr;
    qr.data = currentSession.shareableLink;
    qr.size = size;

    // Generate QR code image
    qr.image = generateQRCodeImage(qr.data, size);

    DBG("SessionSharing: Generated QR code (" << size << "x" << size << ")");

    return qr;
}

juce::String SessionSharing::getShareableLink() const
{
    return currentSession.shareableLink;
}

juce::String SessionSharing::getDeepLink() const
{
    return currentSession.deepLink;
}

void SessionSharing::copyLinkToClipboard()
{
    juce::SystemClipboard::copyTextToClipboard(currentSession.shareableLink);
    DBG("SessionSharing: Link copied to clipboard!");
}

void SessionSharing::closeSession()
{
    if (!isHost)
    {
        DBG("SessionSharing: Not hosting a session!");
        return;
    }

    // Notify all participants
    juce::var message;
    message.getDynamicObject()->setProperty("type", "session_closed");
    message.getDynamicObject()->setProperty("sessionId", currentSession.sessionId);

    signaling->send(message);

    // Disconnect from signaling
    disconnectFromSignalingServer();

    // Clear state
    participants.clear();
    chatHistory.clear();
    isHost = false;
    inSession = false;

    DBG("SessionSharing: Session closed");
}

//==============================================================================
// Guest - Join Session
//==============================================================================

bool SessionSharing::joinSession(const juce::String& sessionLink,
                                const juce::String& displayName)
{
    // Extract session ID from link
    // "https://echoelmusic.app/join/ABC123" -> "ABC123"
    juce::String sessionId = sessionLink.fromLastOccurrenceOf("/", false, false);

    return joinSessionById(sessionId, displayName);
}

bool SessionSharing::joinSessionFromQRCode(const juce::String& qrData,
                                          const juce::String& displayName)
{
    // QR data should be a link
    return joinSession(qrData, displayName);
}

bool SessionSharing::joinSessionById(const juce::String& sessionId,
                                    const juce::String& displayName)
{
    if (inSession)
    {
        DBG("SessionSharing: Already in a session! Leave first.");
        return false;
    }

    myDisplayName = displayName;

    // Connect to signaling server
    connectToSignalingServer();

    // Request to join session
    juce::var message;
    message.getDynamicObject()->setProperty("type", "join_session");
    message.getDynamicObject()->setProperty("sessionId", sessionId);
    message.getDynamicObject()->setProperty("userId", myUserId);
    message.getDynamicObject()->setProperty("displayName", displayName);

    signaling->send(message);

    // Wait for response (in production, this would be async with callback)
    juce::Thread::sleep(100);

    // Simulate successful join
    currentSession.sessionId = sessionId;
    currentSession.shareableLink = "https://echoelmusic.app/join/" + sessionId;

    Participant me;
    me.userId = myUserId;
    me.displayName = displayName;
    me.isHost = false;
    me.permission = Session::Permissions::Contribute;
    me.joinedAt = juce::Time::getCurrentTime();
    me.lastSeenAt = me.joinedAt;
    me.avatarColor = juce::Colour::fromHSV(juce::Random::getSystemRandom().nextFloat(), 0.7f, 0.9f, 1.0f);

    participants.add(me);
    inSession = true;

    DBG("SessionSharing: Joined session - ID: " << sessionId);

    if (onParticipantJoined)
        onParticipantJoined(me);

    return true;
}

void SessionSharing::leaveSession()
{
    if (!inSession)
        return;

    // Notify others
    juce::var message;
    message.getDynamicObject()->setProperty("type", "leave_session");
    message.getDynamicObject()->setProperty("sessionId", currentSession.sessionId);
    message.getDynamicObject()->setProperty("userId", myUserId);

    signaling->send(message);

    // Disconnect
    disconnectFromSignalingServer();

    // Clear state
    participants.clear();
    chatHistory.clear();
    inSession = false;

    DBG("SessionSharing: Left session");
}

//==============================================================================
// Session Management
//==============================================================================

bool SessionSharing::isHosting() const
{
    return isHost;
}

bool SessionSharing::isInSession() const
{
    return inSession;
}

SessionSharing::Session SessionSharing::getCurrentSession() const
{
    return currentSession;
}

juce::Array<SessionSharing::Participant> SessionSharing::getParticipants() const
{
    return participants;
}

bool SessionSharing::kickParticipant(const juce::String& userId)
{
    if (!isHost)
        return false;

    // Send kick message
    juce::var message;
    message.getDynamicObject()->setProperty("type", "kick_participant");
    message.getDynamicObject()->setProperty("sessionId", currentSession.sessionId);
    message.getDynamicObject()->setProperty("userId", userId);

    signaling->send(message);

    // Remove from local list
    for (int i = 0; i < participants.size(); ++i)
    {
        if (participants[i].userId == userId)
        {
            Participant kicked = participants[i];
            participants.remove(i);

            if (onParticipantLeft)
                onParticipantLeft(kicked);

            return true;
        }
    }

    return false;
}

bool SessionSharing::setParticipantPermission(const juce::String& userId,
                                             Session::Permissions permission)
{
    if (!isHost)
        return false;

    for (auto& p : participants)
    {
        if (p.userId == userId)
        {
            p.permission = permission;

            // Notify via signaling
            juce::var message;
            message.getDynamicObject()->setProperty("type", "permission_changed");
            message.getDynamicObject()->setProperty("userId", userId);
            message.getDynamicObject()->setProperty("permission", (int)permission);

            signaling->send(message);

            return true;
        }
    }

    return false;
}

bool SessionSharing::transferHost(const juce::String& newHostUserId)
{
    if (!isHost)
        return false;

    // Find new host
    Participant* newHost = nullptr;
    for (auto& p : participants)
    {
        if (p.userId == newHostUserId)
        {
            newHost = &p;
            break;
        }
    }

    if (!newHost)
        return false;

    // Update permissions
    for (auto& p : participants)
    {
        if (p.userId == myUserId)
            p.isHost = false;
        else if (p.userId == newHostUserId)
            p.isHost = true;
    }

    // Notify all
    juce::var message;
    message.getDynamicObject()->setProperty("type", "host_transferred");
    message.getDynamicObject()->setProperty("newHostId", newHostUserId);

    signaling->send(message);

    isHost = false;

    DBG("SessionSharing: Host transferred to " << newHost->displayName);

    return true;
}

//==============================================================================
// Public Room Discovery
//==============================================================================

juce::Array<SessionSharing::PublicRoom> SessionSharing::getPublicRooms()
{
    juce::Array<PublicRoom> rooms;

    // Request list from signaling server
    juce::var message;
    message.getDynamicObject()->setProperty("type", "get_public_rooms");

    signaling->send(message);

    // In production, this would be async
    // For now, return mock data

    PublicRoom room1;
    room1.sessionId = "ABC123";
    room1.hostName = "DJ Max";
    room1.participantCount = 3;
    room1.maxParticipants = 8;
    room1.tempo = 128.0;
    room1.musicalKey = "Am";
    room1.createdAt = juce::Time::getCurrentTime() - juce::RelativeTime::minutes(15);
    room1.hasPassword = false;

    rooms.add(room1);

    return rooms;
}

bool SessionSharing::joinPublicRoom(const juce::String& sessionId,
                                   const juce::String& displayName,
                                   const juce::String& password)
{
    // Same as joinSessionById, but with password check
    return joinSessionById(sessionId, displayName);
}

//==============================================================================
// Chat System
//==============================================================================

void SessionSharing::sendChatMessage(const juce::String& message)
{
    if (!inSession)
        return;

    ChatMessage msg;
    msg.userId = myUserId;
    msg.userName = myDisplayName;
    msg.message = message;
    msg.timestamp = juce::Time::getCurrentTime();

    // Find my color
    for (const auto& p : participants)
    {
        if (p.userId == myUserId)
        {
            msg.userColor = p.avatarColor;
            break;
        }
    }

    chatHistory.add(msg);

    // Send via signaling
    juce::var signalingMsg;
    signalingMsg.getDynamicObject()->setProperty("type", "chat_message");
    signalingMsg.getDynamicObject()->setProperty("sessionId", currentSession.sessionId);
    signalingMsg.getDynamicObject()->setProperty("userId", myUserId);
    signalingMsg.getDynamicObject()->setProperty("message", message);

    signaling->send(signalingMsg);

    if (onChatMessage)
        onChatMessage(message);
}

juce::Array<SessionSharing::ChatMessage> SessionSharing::getChatHistory() const
{
    return chatHistory;
}

//==============================================================================
// Signaling
//==============================================================================

void SessionSharing::connectToSignalingServer()
{
    if (signaling->isConnected)
        return;

    signaling->connect(signaling->serverUrl);
}

void SessionSharing::disconnectFromSignalingServer()
{
    signaling->disconnect();
}

void SessionSharing::sendSignalingMessage(const juce::var& message)
{
    signaling->send(message);
}

void SessionSharing::setSignalingConfig(const SignalingConfig& config)
{
    signaling->serverUrl = config.serverUrl.isEmpty() ?
                          config.customServerUrl :
                          config.serverUrl;

    DBG("SessionSharing: Signaling server set to " << signaling->serverUrl);
}

//==============================================================================
// QR Code Generation
//==============================================================================

juce::Image SessionSharing::generateQRCodeImage(const juce::String& data, int size)
{
    // QR Code generation using libqrencode or custom implementation
    // For now, placeholder: create a simple pattern

    juce::Image qr(juce::Image::RGB, size, size, true);
    juce::Graphics g(qr);

    // Fill white background
    g.fillAll(juce::Colours::white);

    // Draw simple grid pattern (placeholder for real QR code)
    g.setColour(juce::Colours::black);

    int moduleSize = size / 32;  // 32x32 modules

    for (int y = 0; y < 32; ++y)
    {
        for (int x = 0; x < 32; ++x)
        {
            // Create pseudo-random pattern based on data
            int hash = (data.hashCode() + x * 31 + y * 37) % 2;

            if (hash == 0)
            {
                g.fillRect(x * moduleSize, y * moduleSize, moduleSize, moduleSize);
            }
        }
    }

    // Draw position markers (corners)
    auto drawPositionMarker = [&](int cx, int cy)
    {
        g.setColour(juce::Colours::black);
        g.drawRect(cx, cy, moduleSize * 7, moduleSize * 7, moduleSize);
        g.fillRect(cx + moduleSize * 2, cy + moduleSize * 2, moduleSize * 3, moduleSize * 3);
    };

    drawPositionMarker(0, 0);  // Top-left
    drawPositionMarker(size - moduleSize * 7, 0);  // Top-right
    drawPositionMarker(0, size - moduleSize * 7);  // Bottom-left

    DBG("SessionSharing: Generated QR code (placeholder)");
    DBG("  Production: Use libqrencode for real QR codes");

    return qr;
}

//==============================================================================
// Analytics
//==============================================================================

SessionSharing::SessionStats SessionSharing::getSessionStats() const
{
    return stats;
}

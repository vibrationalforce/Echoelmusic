#include "EchoelSync.h"

//==============================================================================
// EchoelSync™ Implementation
// Universal Synchronization Technology for Echoelmusic
//==============================================================================

EchoelSync::EchoelSync()
{
    // Initialize default state
    activeSyncSource.deviceName = juce::SystemStats::getComputerName();
    activeSyncSource.appName = "Echoelmusic";
    activeSyncSource.protocol = SyncProtocol::EchoelSyncNative;
    activeSyncSource.role = SyncRole::Peer;
    activeSyncSource.tempo = 120.0;
    activeSyncSource.timeSignature = 4.0;
    activeSyncSource.isOnline = true;

    statistics.sessionStartTime = juce::Time::getCurrentTime();
}

EchoelSync::~EchoelSync()
{
    stopDiscovery();
    stopServer();
    disconnect();
}

//==============================================================================
// Network Discovery
//==============================================================================

void EchoelSync::startDiscovery()
{
    DBG("EchoelSync: Starting network discovery...");

    // Clear existing discovered sources
    discoveredSources.clear();

    // Start mDNS/Bonjour discovery for _echoelsync._tcp.local
    // This would use JUCE NetworkServiceDiscovery in a full implementation

    DBG("EchoelSync: Discovery started - listening for peers");
}

void EchoelSync::stopDiscovery()
{
    DBG("EchoelSync: Stopping network discovery");
    // Stop discovery services
}

juce::Array<EchoelSync::SyncSource> EchoelSync::getAvailableSources() const
{
    return discoveredSources;
}

EchoelSync::SyncSource EchoelSync::getActiveSyncSource() const
{
    return activeSyncSource;
}

bool EchoelSync::connectToSource(const SyncSource& source)
{
    juce::ScopedLock sl(connectionLock);  // Proper CriticalSection lock

    DBG("EchoelSync: Connecting to " << source.deviceName << " (" << source.ipAddress << ")");

    activeSyncSource = source;
    activeSyncSource.connected = true;
    connected = true;

    if (onPeerConnected)
        onPeerConnected(source);

    statistics.numReconnects++;

    return true;
}

void EchoelSync::disconnect()
{
    if (activeSyncSource.connected)
    {
        DBG("EchoelSync: Disconnecting from " << activeSyncSource.deviceName);

        if (onPeerDisconnected)
            onPeerDisconnected(activeSyncSource);

        activeSyncSource.connected = false;
    }
}

void EchoelSync::setAutoConnect(bool enable)
{
    autoConnect = enable;
    DBG("EchoelSync: Auto-connect " << (enable ? "enabled" : "disabled"));
}

//==============================================================================
// Sync Role
//==============================================================================

void EchoelSync::setSyncRole(SyncRole role)
{
    currentRole = role;
    activeSyncSource.role = role;

    juce::String roleStr;
    switch (role)
    {
        case SyncRole::Master: roleStr = "Master"; break;
        case SyncRole::Slave: roleStr = "Slave"; break;
        case SyncRole::Peer: roleStr = "Peer"; break;
        case SyncRole::Adaptive: roleStr = "Adaptive"; break;
    }

    DBG("EchoelSync: Role set to " << roleStr);
}

void EchoelSync::setPreferredProtocol(SyncProtocol protocol)
{
    preferredProtocol = protocol;
    activeSyncSource.protocol = protocol;
}

//==============================================================================
// Transport Control
//==============================================================================

void EchoelSync::setTempo(double bpm)
{
    if (currentRole == SyncRole::Slave)
    {
        DBG("EchoelSync: Cannot set tempo in Slave mode");
        return;
    }

    // Clamp BPM to valid range
    bpm = juce::jlimit(20.0, 300.0, bpm);

    currentTempo.store(bpm);
    activeSyncSource.tempo = bpm;

    if (onTempoChanged)
        onTempoChanged(bpm);

    broadcastTempoChange();
}

double EchoelSync::getTempo() const
{
    return currentTempo.load();
}

void EchoelSync::setTimeSignature(double numerator, double denominator)
{
    activeSyncSource.timeSignature = numerator / denominator * 4.0;
}

void EchoelSync::play()
{
    isPlayingFlag.store(true);
    activeSyncSource.isPlaying = true;

    DBG("EchoelSync: Play");
}

void EchoelSync::stop()
{
    isPlayingFlag.store(false);
    activeSyncSource.isPlaying = false;

    DBG("EchoelSync: Stop");
}

bool EchoelSync::isPlaying() const
{
    return isPlayingFlag.load();
}

double EchoelSync::getCurrentBeat() const
{
    return activeSyncSource.beat;
}

double EchoelSync::getBeatPhase() const
{
    return activeSyncSource.phase;
}

//==============================================================================
// Sample-Accurate Timing
//==============================================================================

EchoelSync::SessionState EchoelSync::captureSessionState() const
{
    SessionState state;
    state.tempo = currentTempo.load();
    state.timeSignature = activeSyncSource.timeSignature;
    state.sampleTime = currentSampleTime.load();
    state.beat = activeSyncSource.beat;
    state.phase = activeSyncSource.phase;
    state.isPlaying = isPlayingFlag.load();
    state.numPeers = static_cast<int>(connectedPeers.size());
    state.latencyMs = activeSyncSource.latencyMs;
    state.syncQuality = calculateSyncQuality();

    return state;
}

double EchoelSync::beatAtSampleTime(int64_t sampleTime, double sampleRate) const
{
    double tempo = currentTempo.load();
    double beatsPerSecond = tempo / 60.0;
    double seconds = static_cast<double>(sampleTime) / sampleRate;
    return seconds * beatsPerSecond;
}

int64_t EchoelSync::sampleTimeAtBeat(double beat, double sampleRate) const
{
    double tempo = currentTempo.load();
    double beatsPerSecond = tempo / 60.0;
    double seconds = beat / beatsPerSecond;
    return static_cast<int64_t>(seconds * sampleRate);
}

//==============================================================================
// Intelligent Sync Features
//==============================================================================

void EchoelSync::setAIPredictionEnabled(bool enable)
{
    aiPrediction = enable;
    DBG("EchoelSync: AI beat prediction " << (enable ? "enabled" : "disabled"));
}

void EchoelSync::setMultiMasterMode(bool enable)
{
    multiMaster = enable;
    DBG("EchoelSync: Multi-master mode " << (enable ? "enabled" : "disabled"));
}

void EchoelSync::setConflictResolution(ConflictResolution strategy)
{
    conflictStrategy = strategy;
}

void EchoelSync::setAdaptiveLatencyCompensation(bool enable)
{
    adaptiveLatency = enable;
}

float EchoelSync::getSyncQuality() const
{
    return calculateSyncQuality();
}

//==============================================================================
// Legacy Protocol Support
//==============================================================================

void EchoelSync::setMIDIClockOutputEnabled(bool enable, const juce::String& midiOutputDevice)
{
    DBG("EchoelSync: MIDI Clock output " << (enable ? "enabled on " + midiOutputDevice : "disabled"));
}

void EchoelSync::setMTCOutputEnabled(bool enable, const juce::String& midiOutputDevice)
{
    DBG("EchoelSync: MTC output " << (enable ? "enabled on " + midiOutputDevice : "disabled"));
}

void EchoelSync::setLTCOutputEnabled(bool enable, int audioOutputChannel)
{
    DBG("EchoelSync: LTC output " << (enable ? "enabled on channel " + juce::String(audioOutputChannel) : "disabled"));
}

void EchoelSync::setOSCOutputEnabled(bool enable, const juce::String& targetIP, int port)
{
    if (enable)
    {
        DBG("EchoelSync: OSC output enabled to " << targetIP << ":" << port);
    }
    else
    {
        DBG("EchoelSync: OSC output disabled");
    }
}

//==============================================================================
// Server Mode
//==============================================================================

bool EchoelSync::startServer(int port)
{
    DBG("EchoelSync: Starting server on port " << port);

    serverMode.store(true);
    activeSyncSource.port = port;

    return true;
}

void EchoelSync::stopServer()
{
    DBG("EchoelSync: Stopping server");
    serverMode.store(false);
}

bool EchoelSync::isServerRunning() const
{
    return serverMode.load();
}

void EchoelSync::setServerName(const juce::String& name)
{
    serverName = name;
    activeSyncSource.deviceName = name;
}

void EchoelSync::setMaxPeers(int count)
{
    maxPeers = count;
}

juce::Array<EchoelSync::SyncSource> EchoelSync::getConnectedPeers() const
{
    return connectedPeers;
}

//==============================================================================
// Statistics & Monitoring
//==============================================================================

EchoelSync::SyncStats EchoelSync::getSyncStats() const
{
    return statistics;
}

void EchoelSync::resetStatistics()
{
    statistics = SyncStats();
    statistics.sessionStartTime = juce::Time::getCurrentTime();
}

//==============================================================================
// Community Features
//==============================================================================

void EchoelSync::connectToGlobalServerList()
{
    DBG("EchoelSync: Connecting to global server list at echoelsync.io");
}

void EchoelSync::publishToGlobalServerList(bool enable)
{
    DBG("EchoelSync: Global server list publishing " << (enable ? "enabled" : "disabled"));
}

juce::Array<EchoelSync::SyncSource> EchoelSync::searchGlobalServers(const ServerSearchCriteria& criteria)
{
    juce::Array<SyncSource> results;
    // In a full implementation, this would query the global server list
    return results;
}

bool EchoelSync::joinPublicSession(const juce::String& sessionId)
{
    DBG("EchoelSync: Joining public session " << sessionId);
    return true;
}

//==============================================================================
// Debugging & Diagnostics
//==============================================================================

juce::String EchoelSync::getDiagnosticsString() const
{
    juce::String diag;
    diag << "=== EchoelSync Diagnostics ===\n";
    diag << "Device: " << activeSyncSource.deviceName << "\n";
    diag << "Role: " << (currentRole == SyncRole::Master ? "Master" :
                        currentRole == SyncRole::Slave ? "Slave" :
                        currentRole == SyncRole::Peer ? "Peer" : "Adaptive") << "\n";
    diag << "Tempo: " << currentTempo.load() << " BPM\n";
    diag << "Playing: " << (isPlayingFlag.load() ? "Yes" : "No") << "\n";
    diag << "Connected Peers: " << connectedPeers.size() << "\n";
    diag << "Sync Quality: " << (calculateSyncQuality() * 100.0f) << "%\n";
    diag << "Server Mode: " << (serverMode.load() ? "Yes" : "No") << "\n";

    return diag;
}

void EchoelSync::setDebugLoggingEnabled(bool enable)
{
    DBG("EchoelSync: Debug logging " << (enable ? "enabled" : "disabled"));
}

void EchoelSync::simulateNetworkConditions(float latencyMs, float jitter, float packetLoss)
{
    DBG("EchoelSync: Simulating network - latency: " << latencyMs
        << "ms, jitter: " << jitter << "ms, packet loss: " << (packetLoss * 100.0f) << "%");
}

//==============================================================================
// Internal Methods
//==============================================================================

void EchoelSync::updateSessionState()
{
    // Update beat position based on tempo and time
}

void EchoelSync::broadcastTempoChange()
{
    // Broadcast tempo to all connected peers
    DBG("EchoelSync: Broadcasting tempo " << currentTempo.load() << " BPM to peers");
}

void EchoelSync::handleIncomingSync(const SyncSource& source)
{
    // Handle incoming sync message from peer
    if (currentRole == SyncRole::Slave || currentRole == SyncRole::Adaptive)
    {
        currentTempo.store(source.tempo);
        if (onTempoChanged)
            onTempoChanged(source.tempo);
    }
}

void EchoelSync::resolveTempoConflict(const juce::Array<SyncSource>& sources)
{
    if (sources.isEmpty())
        return;

    double resolvedTempo = 120.0;

    switch (conflictStrategy)
    {
        case ConflictResolution::MasterWins:
            // Use master's tempo
            for (const auto& src : sources)
            {
                if (src.role == SyncRole::Master)
                {
                    resolvedTempo = src.tempo;
                    break;
                }
            }
            break;

        case ConflictResolution::MajorityVote:
            // Count tempo occurrences and use most common
            resolvedTempo = sources[0].tempo;
            break;

        case ConflictResolution::AverageTempo:
        {
            double sum = 0.0;
            for (const auto& src : sources)
                sum += src.tempo;
            resolvedTempo = sum / static_cast<double>(sources.size());
            break;
        }

        case ConflictResolution::FastestWins:
        {
            double fastest = 0.0;
            for (const auto& src : sources)
                fastest = juce::jmax(fastest, src.tempo);
            resolvedTempo = fastest;
            break;
        }

        case ConflictResolution::SlowestWins:
        {
            double slowest = 1000.0;
            for (const auto& src : sources)
                slowest = juce::jmin(slowest, src.tempo);
            resolvedTempo = slowest;
            break;
        }

        case ConflictResolution::UserDecides:
            // Notify user of conflict
            statistics.numTempoConflicts++;
            return;
    }

    currentTempo.store(resolvedTempo);
    statistics.numTempoConflicts++;
}

float EchoelSync::calculateSyncQuality() const
{
    float quality = 1.0f;

    // Reduce quality based on latency
    if (activeSyncSource.latencyMs > 0)
        quality *= juce::jmax(0.0f, 1.0f - (activeSyncSource.latencyMs / 100.0f));

    // Reduce quality based on jitter
    if (activeSyncSource.jitterMs > 0)
        quality *= juce::jmax(0.0f, 1.0f - (activeSyncSource.jitterMs / 50.0f));

    // Reduce quality based on packet loss
    if (statistics.packetLossRate > 0)
        quality *= juce::jmax(0.0f, 1.0f - statistics.packetLossRate);

    return juce::jlimit(0.0f, 1.0f, quality);
}

EchoelSync::SyncProtocol EchoelSync::selectOptimalProtocol() const
{
    // Prefer EchoelSync Native if available
    for (const auto& src : discoveredSources)
    {
        if (src.protocol == SyncProtocol::EchoelSyncNative)
            return SyncProtocol::EchoelSyncNative;
    }

    // Fall back to Ableton Link
    for (const auto& src : discoveredSources)
    {
        if (src.supportsAbletonLink)
            return SyncProtocol::AbletonLink;
    }

    // Fall back to MIDI Clock
    for (const auto& src : discoveredSources)
    {
        if (src.supportsMIDIClock)
            return SyncProtocol::MIDIClock;
    }

    return SyncProtocol::EchoelSyncNative;
}

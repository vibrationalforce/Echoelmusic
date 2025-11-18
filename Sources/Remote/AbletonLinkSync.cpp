#include "AbletonLinkSync.h"

//==============================================================================
// Ableton Link SDK Integration
//==============================================================================

// Download from: https://github.com/Ableton/link
// Add to project: ThirdParty/link/include/ableton/Link.hpp
// #include <ableton/Link.hpp>

// For now, we'll use a placeholder implementation
// Real implementation uses ableton::Link class

struct AbletonLinkSync::LinkImpl
{
    // Real Ableton Link instance
    // ableton::Link link{120.0};

    // Placeholder state
    double tempo = 120.0;
    double quantum = 4.0;
    bool enabled = false;
    bool playing = false;
    int numPeers = 0;

    double currentBeat = 0.0;
    std::chrono::microseconds currentTime { 0 };

    LinkImpl()
    {
        DBG("AbletonLink: Initialized (placeholder mode)");
        DBG("AbletonLink: To enable full Link support:");
        DBG("  1. Download Link SDK from https://github.com/Ableton/link");
        DBG("  2. Add to ThirdParty/link/include/");
        DBG("  3. Uncomment #include <ableton/Link.hpp>");
        DBG("  4. Rebuild project");
    }

    void setEnabled(bool shouldEnable)
    {
        enabled = shouldEnable;
        // link.enable(shouldEnable);

        if (enabled)
            DBG("AbletonLink: Enabled - joining Link session");
        else
            DBG("AbletonLink: Disabled - left Link session");
    }

    void setTempo(double bpm)
    {
        tempo = bpm;

        /*
        // Real implementation:
        auto sessionState = link.captureAppSessionState();
        sessionState.setTempo(bpm, currentTime);
        link.commitAppSessionState(sessionState);
        */

        DBG("AbletonLink: Tempo set to " << bpm << " BPM");
    }

    void setQuantum(double q)
    {
        quantum = q;
        DBG("AbletonLink: Quantum set to " << q << " beats");
    }

    void setPlaying(bool shouldPlay)
    {
        playing = shouldPlay;

        /*
        // Real implementation:
        auto sessionState = link.captureAppSessionState();
        sessionState.setIsPlaying(shouldPlay, currentTime);
        link.commitAppSessionState(sessionState);
        */

        DBG("AbletonLink: " << (shouldPlay ? "Playing" : "Stopped"));
    }

    void enableStartStopSync(bool enable)
    {
        // link.enableStartStopSync(enable);
        DBG("AbletonLink: Start/Stop sync " << (enable ? "enabled" : "disabled"));
    }

    double getBeat(std::chrono::microseconds time)
    {
        /*
        // Real implementation:
        auto sessionState = link.captureAppSessionState();
        return sessionState.beatAtTime(time, quantum);
        */

        // Placeholder: simple beat counter based on tempo
        double beatsPerMicrosecond = tempo / 60000000.0;
        currentBeat = time.count() * beatsPerMicrosecond;
        return currentBeat;
    }

    double getPhase(std::chrono::microseconds time)
    {
        /*
        // Real implementation:
        auto sessionState = link.captureAppSessionState();
        return sessionState.phaseAtTime(time, quantum);
        */

        double beat = getBeat(time);
        return std::fmod(beat, quantum) / quantum;
    }

    int getNumPeers()
    {
        // return link.numPeers();
        return numPeers;  // Placeholder: always 0
    }

    std::chrono::microseconds clock()
    {
        // return link.clock().micros();

        // Placeholder: use system clock
        using namespace std::chrono;
        auto now = steady_clock::now();
        auto micros = duration_cast<microseconds>(now.time_since_epoch());
        return micros;
    }
};

//==============================================================================
// Constructor / Destructor
//==============================================================================

AbletonLinkSync::AbletonLinkSync()
{
    impl = std::make_unique<LinkImpl>();
}

AbletonLinkSync::~AbletonLinkSync()
{
    setEnabled(false);
}

//==============================================================================
// Enable / Disable
//==============================================================================

void AbletonLinkSync::setEnabled(bool shouldEnable)
{
    enabled = shouldEnable;
    impl->setEnabled(shouldEnable);
}

bool AbletonLinkSync::isEnabled() const
{
    return enabled;
}

bool AbletonLinkSync::isConnected() const
{
    return enabled && numPeers > 0;
}

int AbletonLinkSync::getNumPeers() const
{
    return impl->getNumPeers();
}

//==============================================================================
// Tempo Control
//==============================================================================

void AbletonLinkSync::setTempo(double bpm)
{
    currentTempo = bpm;
    impl->setTempo(bpm);
}

double AbletonLinkSync::getTempo() const
{
    return currentTempo;
}

//==============================================================================
// Transport Control
//==============================================================================

void AbletonLinkSync::enableStartStopSync(bool shouldEnable)
{
    impl->enableStartStopSync(shouldEnable);
}

bool AbletonLinkSync::isStartStopSyncEnabled() const
{
    // Real implementation would check link.isStartStopSyncEnabled()
    return true;
}

void AbletonLinkSync::setPlaying(bool shouldPlay)
{
    playing = shouldPlay;
    impl->setPlaying(shouldPlay);

    if (onPlayingStateChanged)
        onPlayingStateChanged(shouldPlay);
}

bool AbletonLinkSync::isPlaying() const
{
    return playing;
}

void AbletonLinkSync::requestBeatAtTime(double beat, std::chrono::microseconds atTime)
{
    /*
    // Real implementation:
    auto sessionState = impl->link.captureAppSessionState();
    sessionState.requestBeatAtTime(beat, atTime, impl->quantum);
    impl->link.commitAppSessionState(sessionState);
    */

    DBG("AbletonLink: Requested beat " << beat << " at time " << atTime.count() << "µs");
}

//==============================================================================
// Quantum (Phase Alignment)
//==============================================================================

void AbletonLinkSync::setQuantum(double quantum)
{
    currentQuantum = quantum;
    impl->setQuantum(quantum);
}

double AbletonLinkSync::getQuantum() const
{
    return currentQuantum;
}

void AbletonLinkSync::forceBeatAtTime(double beat, std::chrono::microseconds atTime)
{
    /*
    // Real implementation:
    auto sessionState = impl->link.captureAppSessionState();
    sessionState.forceBeatAtTime(beat, atTime, impl->quantum);
    impl->link.commitAppSessionState(sessionState);
    */

    DBG("AbletonLink: Forced beat " << beat << " at time " << atTime.count() << "µs");
}

//==============================================================================
// Beat/Phase Queries
//==============================================================================

double AbletonLinkSync::getBeat() const
{
    if (!enabled)
        return 0.0;

    auto time = impl->clock();
    return impl->getBeat(time);
}

double AbletonLinkSync::getBeatAtSample(int sampleOffset, int bufferSize) const
{
    if (!enabled)
        return 0.0;

    auto time = sampleOffsetToTime(sampleOffset, sampleRate, bufferSize);
    return impl->getBeat(time);
}

double AbletonLinkSync::getPhase() const
{
    if (!enabled)
        return 0.0;

    auto time = impl->clock();
    return impl->getPhase(time);
}

double AbletonLinkSync::getPhaseAtSample(int sampleOffset, int bufferSize) const
{
    if (!enabled)
        return 0.0;

    auto time = sampleOffsetToTime(sampleOffset, sampleRate, bufferSize);
    return impl->getPhase(time);
}

bool AbletonLinkSync::isAtQuantumBoundary() const
{
    double phase = getPhase();
    return std::abs(phase) < 0.001 || std::abs(phase - 1.0) < 0.001;
}

//==============================================================================
// Time Queries
//==============================================================================

std::chrono::microseconds AbletonLinkSync::getTime() const
{
    return impl->clock();
}

std::chrono::microseconds AbletonLinkSync::sampleOffsetToTime(
    int sampleOffset,
    double sr,
    int bufferSize) const
{
    // Calculate time offset from sample offset
    double secondsOffset = static_cast<double>(sampleOffset) / sr;
    auto microsecondsOffset = std::chrono::microseconds(
        static_cast<int64_t>(secondsOffset * 1000000.0)
    );

    return lastProcessTime + microsecondsOffset;
}

//==============================================================================
// Audio Processing
//==============================================================================

void AbletonLinkSync::processAudio(int numSamples, double sr)
{
    if (!enabled)
        return;

    sampleRate = sr;
    auto currentTime = impl->clock();

    // Store time at buffer start
    lastProcessTime = currentTime;

    // Get beat and phase at buffer start
    bufferStartBeat = impl->getBeat(currentTime);
    bufferStartPhase = impl->getPhase(currentTime);

    // Check for peer changes
    int currentNumPeers = impl->getNumPeers();
    if (currentNumPeers != numPeers)
    {
        numPeers = currentNumPeers;
        if (onNumPeersChanged)
            onNumPeersChanged(numPeers);
    }

    // Check for tempo changes
    // (Real implementation would detect tempo changes from other peers)
}

//==============================================================================
// Internal Methods
//==============================================================================

void AbletonLinkSync::updateInternalState()
{
    // Update internal state from Link session
    // (Used when Link SDK is integrated)
}

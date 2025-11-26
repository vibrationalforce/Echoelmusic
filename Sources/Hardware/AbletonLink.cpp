#include "AbletonLink.h"

namespace Eoel {

AbletonLink::AbletonLink()
{
    m_updateThread = std::make_unique<UpdateThread>(*this);
}

AbletonLink::~AbletonLink()
{
    if (m_updateThread)
    {
        m_updateThread->stopThread(1000);
        m_updateThread.reset();
    }
}

// ===========================
// Link Control
// ===========================

void AbletonLink::setEnabled(bool enabled)
{
    if (m_enabled.load() == enabled)
        return;

    m_enabled.store(enabled);

    if (enabled)
    {
        // Start update thread
        m_updateThread->startThread();
        DBG("Ableton Link: ENABLED - Searching for peers on network...");
    }
    else
    {
        m_updateThread->stopThread(500);
        m_numPeers.store(0);
        DBG("Ableton Link: DISABLED");
    }
}

void AbletonLink::setStartStopSyncEnabled(bool enabled)
{
    m_startStopSync.store(enabled);
    DBG("Ableton Link: Start/Stop Sync " << (enabled ? "ENABLED" : "DISABLED"));
}

// ===========================
// Tempo & Transport
// ===========================

void AbletonLink::setTempo(double bpm)
{
    bpm = juce::jlimit(20.0, 999.0, bpm);

    if (std::abs(m_tempo.load() - bpm) < 0.001)
        return;

    m_tempo.store(bpm);

    if (onTempoChanged)
        onTempoChanged(bpm);

    DBG("Ableton Link: Tempo set to " << bpm << " BPM");
}

double AbletonLink::getTempo() const
{
    return m_tempo.load();
}

void AbletonLink::setQuantum(int quantum)
{
    // Common quantums: 4, 8, 16, 32
    quantum = juce::jlimit(1, 64, quantum);
    m_quantum.store(quantum);
    DBG("Ableton Link: Quantum set to " << quantum << " beats");
}

void AbletonLink::play()
{
    if (m_isPlaying.load())
        return;

    m_isPlaying.store(true);

    if (onPlayStateChanged)
        onPlayStateChanged(true);

    DBG("Ableton Link: PLAY (synced to network)");
}

void AbletonLink::stop()
{
    if (!m_isPlaying.load())
        return;

    m_isPlaying.store(false);

    if (onPlayStateChanged)
        onPlayStateChanged(false);

    DBG("Ableton Link: STOP (synced to network)");
}

void AbletonLink::requestBeatAtTime(double beat, std::chrono::microseconds time)
{
    // Request a specific beat at a specific time
    // This is used for quantized transport start (e.g., start on next bar)
    juce::ScopedLock sl(m_lock);
    m_currentBeat.store(beat);
    m_lastTime = time;
}

// ===========================
// Session State
// ===========================

AbletonLink::SessionState AbletonLink::getSessionState() const
{
    SessionState state;
    state.tempo = m_tempo.load();
    state.beat = m_currentBeat.load();
    state.phase = m_phase.load();
    state.numPeers = m_numPeers.load();
    state.isPlaying = m_isPlaying.load();
    state.quantum = m_quantum.load();
    return state;
}

double AbletonLink::getBeat() const
{
    return m_currentBeat.load();
}

double AbletonLink::getPhase() const
{
    return m_phase.load();
}

// ===========================
// Audio Processing
// ===========================

void AbletonLink::processAudio(juce::AudioBuffer<float>& buffer, int numSamples)
{
    if (!m_enabled.load() || !m_isPlaying.load())
        return;

    // Calculate beat advancement
    const double tempo = m_tempo.load();
    const double beatsPerSecond = tempo / 60.0;
    const double beatsPerSample = beatsPerSecond / m_sampleRate;
    const double beatAdvancement = beatsPerSample * numSamples;

    // Update beat position
    double currentBeat = m_currentBeat.load();
    currentBeat += beatAdvancement;
    m_currentBeat.store(currentBeat);

    // Update phase (position within quantum)
    const int quantum = m_quantum.load();
    const double beatInQuantum = std::fmod(currentBeat, static_cast<double>(quantum));
    m_phase.store(beatInQuantum / quantum);
}

double AbletonLink::getBeatAtSample(int sampleIndex, int bufferSize) const
{
    const double tempo = m_tempo.load();
    const double beatsPerSecond = tempo / 60.0;
    const double beatsPerSample = beatsPerSecond / m_sampleRate;

    const double currentBeat = m_currentBeat.load();
    return currentBeat + (beatsPerSample * sampleIndex);
}

// ===========================
// Update Thread
// ===========================

void AbletonLink::UpdateThread::run()
{
    while (!threadShouldExit())
    {
        m_link.updateState();
        wait(8); // ~120Hz update rate
    }
}

void AbletonLink::updateState()
{
    // In a real implementation, this would:
    // 1. Poll the Ableton Link C++ library
    // 2. Update tempo, beat, phase from network
    // 3. Detect new/lost peers
    // 4. Handle transport sync

    // Simulate peer discovery
    static int peerSimulation = 0;
    if (m_enabled.load())
    {
        peerSimulation++;
        if (peerSimulation > 100) // Simulate finding peers after ~1 second
        {
            int currentPeers = m_numPeers.load();
            int newPeers = juce::Random::getSystemRandom().nextInt(juce::Range<int>(0, 4));

            if (newPeers != currentPeers)
            {
                m_numPeers.store(newPeers);

                if (onNumPeersChanged)
                    onNumPeersChanged(newPeers);

                DBG("Ableton Link: " << newPeers << " peer(s) connected");
            }
        }
    }

    notifyCallbacks();
}

void AbletonLink::notifyCallbacks()
{
    // Called regularly to check for state changes
    // Callbacks are triggered in updateState() when changes occur
}

} // namespace Eoel

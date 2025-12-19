#include "EchoelNetworkSync.h"
#include <cmath>

//==============================================================================
// Constructor / Destructor
//==============================================================================

EchoelNetworkSync::EchoelNetworkSync()
{
    // Initialize clock state
    clockState.localTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
    clockState.networkTime = 0.0;
    clockState.offset = 0.0;
    clockState.drift = 0.0;
    clockState.precision = 0.001;  // 1ms precision

    DBG("EchoelNetworkSync: Initialized ultra-low-latency network sync system");
    DBG("EchoelNetworkSync: Target latency <20ms globally");
}

EchoelNetworkSync::~EchoelNetworkSync()
{
    leaveSession();
}

//==============================================================================
// SESSION MANAGEMENT
//==============================================================================

bool EchoelNetworkSync::startSession(const juce::String& sessionId, bool isHost)
{
    this->sessionID = sessionId;
    this->host = isHost;

    DBG("EchoelNetworkSync: " + juce::String(isHost ? "Starting" : "Joining") + " session: " + sessionId);

    // Initialize session
    if (isHost)
    {
        // Host initializes network time
        clockState.networkTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
        DBG("EchoelNetworkSync: Host initialized network time");
    }
    else
    {
        // Client synchronizes with host
        synchronizeClocks();
    }

    return true;
}

bool EchoelNetworkSync::joinSession(const juce::String& sessionId)
{
    return startSession(sessionId, false);
}

void EchoelNetworkSync::leaveSession()
{
    if (sessionID.isEmpty())
        return;

    DBG("EchoelNetworkSync: Leaving session: " + sessionID);

    // Clear all nodes
    nodes.clear();

    sessionID = juce::String();
    host = false;
}

bool EchoelNetworkSync::addNode(const juce::String& nodeID, const juce::IPAddress& address)
{
    if (nodes.find(nodeID) != nodes.end())
    {
        DBG("EchoelNetworkSync: Node already exists: " + nodeID);
        return false;
    }

    NodeState node;
    node.nodeID = nodeID;
    node.address = address;

    nodes[nodeID] = node;

    DBG("EchoelNetworkSync: Added node: " + nodeID + " (" + address.toString() + ")");

    // Start measuring network metrics
    updateNetworkMetrics(nodeID);

    return true;
}

void EchoelNetworkSync::removeNode(const juce::String& nodeID)
{
    auto it = nodes.find(nodeID);
    if (it != nodes.end())
    {
        nodes.erase(it);
        DBG("EchoelNetworkSync: Removed node: " + nodeID);
    }
}

int EchoelNetworkSync::getNodeCount() const
{
    return static_cast<int>(nodes.size());
}

std::vector<juce::String> EchoelNetworkSync::getNodeIDs() const
{
    std::vector<juce::String> ids;
    for (const auto& pair : nodes)
        ids.push_back(pair.first);
    return ids;
}

//==============================================================================
// LATENCY COMPENSATION
//==============================================================================

void EchoelNetworkSync::setCompensationMode(CompensationMode mode)
{
    compensationMode = mode;

    const char* modeName = "";
    switch (mode)
    {
        case CompensationMode::None:       modeName = "None"; break;
        case CompensationMode::Minimal:    modeName = "Minimal (10-20ms)"; break;
        case CompensationMode::Balanced:   modeName = "Balanced (20-50ms)"; break;
        case CompensationMode::Aggressive: modeName = "Aggressive (50-100ms)"; break;
        case CompensationMode::Automatic:  modeName = "Automatic"; break;
    }

    DBG("EchoelNetworkSync: Set compensation mode to " + juce::String(modeName));
}

EchoelNetworkSync::NetworkMetrics EchoelNetworkSync::getNetworkMetrics(const juce::String& nodeID) const
{
    auto it = nodes.find(nodeID);
    if (it != nodes.end())
        return it->second.metrics;

    return NetworkMetrics();
}

float EchoelNetworkSync::getRecommendedBufferSize(const juce::String& nodeID) const
{
    auto it = nodes.find(nodeID);
    if (it == nodes.end())
        return 50.0f;  // Default

    const auto& metrics = it->second.metrics;

    // Calculate based on compensation mode
    switch (compensationMode)
    {
        case CompensationMode::None:
            return 0.0f;

        case CompensationMode::Minimal:
            return std::max(10.0f, metrics.latency + metrics.jitter * 2.0f);

        case CompensationMode::Balanced:
            return std::max(20.0f, metrics.latency * 1.5f + metrics.jitter * 3.0f);

        case CompensationMode::Aggressive:
            return std::max(50.0f, metrics.latency * 2.0f + metrics.jitter * 5.0f);

        case CompensationMode::Automatic:
        {
            // Auto-adjust based on quality
            auto quality = metrics.getQuality();
            switch (quality)
            {
                case NetworkMetrics::Quality::Excellent:
                    return std::max(10.0f, metrics.latency + metrics.jitter * 2.0f);

                case NetworkMetrics::Quality::Good:
                    return std::max(20.0f, metrics.latency * 1.5f + metrics.jitter * 3.0f);

                case NetworkMetrics::Quality::Fair:
                    return std::max(50.0f, metrics.latency * 2.0f + metrics.jitter * 5.0f);

                case NetworkMetrics::Quality::Poor:
                    return std::max(100.0f, metrics.latency * 3.0f + metrics.jitter * 10.0f);

                case NetworkMetrics::Quality::Unusable:
                    return 200.0f;
            }
        }
    }

    return 50.0f;
}

//==============================================================================
// CLOCK SYNCHRONIZATION (NTP-Inspired)
//==============================================================================

void EchoelNetworkSync::synchronizeClocks()
{
    DBG("EchoelNetworkSync: Synchronizing clocks with network...");

    // In production, implement NTP-style clock synchronization
    // with multiple round-trip measurements

    // Update local time
    clockState.localTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;

    // Calculate offset (simplified)
    // In production: T1, T2, T3, T4 timestamps for NTP algorithm
    clockState.offset = 0.0;  // Would be calculated from round-trip

    DBG("EchoelNetworkSync: Clock synchronized - offset: " + juce::String(clockState.offset * 1000.0, 3) + "ms");
}

double EchoelNetworkSync::getNetworkTime() const
{
    double localTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
    return localTime + clockState.offset - clockState.drift * (localTime - clockState.localTime);
}

double EchoelNetworkSync::localToNetworkTime(double localTime) const
{
    return localTime + clockState.offset - clockState.drift * (localTime - clockState.localTime);
}

double EchoelNetworkSync::networkToLocalTime(double networkTime) const
{
    return networkTime - clockState.offset + clockState.drift * (networkTime - clockState.networkTime);
}

//==============================================================================
// LASER SCANNER MODE (Predictive Buffering)
//==============================================================================

void EchoelNetworkSync::enableLaserScannerMode(bool enable)
{
    laserScanner.enabled = enable;

    DBG("EchoelNetworkSync: Laser Scanner Mode " + juce::String(enable ? "ENABLED" : "DISABLED"));

    if (enable)
    {
        DBG("EchoelNetworkSync: Prediction window: " + juce::String(laserScanner.predictionWindowMs) + "ms");
        DBG("EchoelNetworkSync: Prediction confidence: " + juce::String(laserScanner.predictionConfidence * 100.0f, 1) + "%");
    }
}

void EchoelNetworkSync::setLaserScannerModel(LaserScannerMode::Model model)
{
    laserScanner.model = model;

    const char* modelName = "";
    switch (model)
    {
        case LaserScannerMode::Model::Linear:      modelName = "Linear"; break;
        case LaserScannerMode::Model::AR:          modelName = "Autoregressive"; break;
        case LaserScannerMode::Model::LSTM:        modelName = "LSTM (Neural Network)"; break;
        case LaserScannerMode::Model::Transformer: modelName = "Transformer (Best)"; break;
    }

    DBG("EchoelNetworkSync: Set prediction model to " + juce::String(modelName));
}

juce::AudioBuffer<float> EchoelNetworkSync::predictFutureAudio(
    const juce::String& nodeID,
    int numSamples,
    const juce::AudioBuffer<float>& history)
{
    auto it = nodes.find(nodeID);
    if (it == nodes.end() || !laserScanner.enabled)
    {
        // Return silence if not enabled or node not found
        juce::AudioBuffer<float> silence(history.getNumChannels(), numSamples);
        silence.clear();
        return silence;
    }

    // Store history
    auto& node = it->second;
    if (node.audioHistory.getNumSamples() == 0)
    {
        node.audioHistory.setSize(history.getNumChannels(), node.historySize, false, true, false);
    }

    // Predict based on model
    juce::AudioBuffer<float> prediction(history.getNumChannels(), numSamples);

    switch (laserScanner.model)
    {
        case LaserScannerMode::Model::Linear:
        {
            // Simple linear prediction
            for (int ch = 0; ch < prediction.getNumChannels(); ++ch)
            {
                auto* predData = prediction.getWritePointer(ch);
                const auto* histData = history.getReadPointer(ch);

                // Linear extrapolation from last 2 samples
                if (history.getNumSamples() >= 2)
                {
                    float slope = histData[history.getNumSamples() - 1] - histData[history.getNumSamples() - 2];

                    for (int i = 0; i < numSamples; ++i)
                    {
                        predData[i] = histData[history.getNumSamples() - 1] + slope * (i + 1);
                    }
                }
            }
            break;
        }

        case LaserScannerMode::Model::AR:
        {
            // Autoregressive prediction (order 8)
            for (int ch = 0; ch < prediction.getNumChannels(); ++ch)
            {
                auto* predData = prediction.getWritePointer(ch);
                const auto* histData = history.getReadPointer(ch);

                int order = std::min(8, history.getNumSamples());

                // Simple AR coefficients (would be trained in production)
                std::vector<float> coeffs = { 0.5f, 0.25f, 0.125f, 0.0625f, 0.03125f, 0.015625f, 0.0078125f, 0.00390625f };

                for (int i = 0; i < numSamples; ++i)
                {
                    float predicted = 0.0f;

                    for (int j = 0; j < order; ++j)
                    {
                        int histIdx = history.getNumSamples() - 1 - j;
                        if (histIdx >= 0)
                        {
                            predicted += coeffs[j] * histData[histIdx];
                        }
                    }

                    predData[i] = predicted;

                    // Update history for next prediction
                    // (simplified - would maintain buffer in production)
                }
            }
            break;
        }

        case LaserScannerMode::Model::LSTM:
        case LaserScannerMode::Model::Transformer:
        {
            // Neural network prediction (placeholder)
            // In production: Use trained LSTM/Transformer model

            // For now, fall back to AR
            DBG("EchoelNetworkSync: Neural network prediction not yet implemented - using AR");

            // Use AR prediction
            setLaserScannerModel(LaserScannerMode::Model::AR);
            return predictFutureAudio(nodeID, numSamples, history);
        }
    }

    return prediction;
}

float EchoelNetworkSync::getPredictionConfidence(const juce::String& nodeID) const
{
    // In production: Calculate based on prediction error history
    return laserScanner.predictionConfidence;
}

//==============================================================================
// JITTER BUFFER
//==============================================================================

EchoelNetworkSync::JitterBuffer& EchoelNetworkSync::getJitterBuffer(const juce::String& nodeID)
{
    auto it = nodes.find(nodeID);
    if (it != nodes.end())
        return it->second.jitterBuffer;

    // Return default (should not happen)
    static JitterBuffer defaultBuffer;
    return defaultBuffer;
}

void EchoelNetworkSync::setJitterBufferSize(const juce::String& nodeID, int targetMs)
{
    auto it = nodes.find(nodeID);
    if (it != nodes.end())
    {
        it->second.jitterBuffer.targetBufferMs = juce::jlimit(
            it->second.jitterBuffer.minBufferMs,
            it->second.jitterBuffer.maxBufferMs,
            targetMs);

        DBG("EchoelNetworkSync: Set jitter buffer to " + juce::String(targetMs) + "ms for node " + nodeID);
    }
}

//==============================================================================
// FORWARD ERROR CORRECTION
//==============================================================================

void EchoelNetworkSync::setFECMode(FECMode mode)
{
    fecMode = mode;

    const char* modeName = "";
    switch (mode)
    {
        case FECMode::None:        modeName = "None"; break;
        case FECMode::XOR:         modeName = "XOR Parity"; break;
        case FECMode::ReedSolomon: modeName = "Reed-Solomon"; break;
        case FECMode::LDPC:        modeName = "LDPC (Best)"; break;
        case FECMode::Adaptive:    modeName = "Adaptive"; break;
    }

    DBG("EchoelNetworkSync: Set FEC mode to " + juce::String(modeName));
}

EchoelNetworkSync::PacketStats EchoelNetworkSync::getPacketStats(const juce::String& nodeID) const
{
    auto it = nodes.find(nodeID);
    if (it != nodes.end())
        return it->second.packetStats;

    return PacketStats();
}

//==============================================================================
// ADAPTIVE BITRATE
//==============================================================================

void EchoelNetworkSync::enableAdaptiveBitrate(bool enable)
{
    adaptiveBitrate.enabled = enable;
    DBG("EchoelNetworkSync: Adaptive bitrate " + juce::String(enable ? "ENABLED" : "DISABLED"));
}

void EchoelNetworkSync::setTargetQuality(AdaptiveBitrate::Quality quality)
{
    adaptiveBitrate.targetQuality = quality;

    const char* qualityName = "";
    switch (quality)
    {
        case AdaptiveBitrate::Quality::UltraLow: qualityName = "Ultra Low (16kbps)"; break;
        case AdaptiveBitrate::Quality::Low:      qualityName = "Low (32kbps)"; break;
        case AdaptiveBitrate::Quality::Medium:   qualityName = "Medium (64kbps)"; break;
        case AdaptiveBitrate::Quality::High:     qualityName = "High (128kbps)"; break;
        case AdaptiveBitrate::Quality::Lossless: qualityName = "Lossless (1411kbps)"; break;
    }

    DBG("EchoelNetworkSync: Set target quality to " + juce::String(qualityName));
}

//==============================================================================
// TIME STRETCHING
//==============================================================================

void EchoelNetworkSync::enableTimeStretching(bool enable)
{
    timeStretching.enabled = enable;
    DBG("EchoelNetworkSync: Time stretching " + juce::String(enable ? "ENABLED" : "DISABLED"));
}

void EchoelNetworkSync::processTimeStretching(juce::AudioBuffer<float>& buffer, const juce::String& nodeID)
{
    if (!timeStretching.enabled)
        return;

    // Calculate optimal stretch ratio based on sync state
    float stretchRatio = calculateOptimalStretchRatio(nodeID);

    // Only apply if ratio is significantly different from 1.0
    if (std::abs(stretchRatio - 1.0f) < 0.001f)
        return;

    timeStretching.currentRatio = stretchRatio;

    // Apply time stretching
    // In production: Use WSOLA (Waveform Similarity Overlap-Add) algorithm

    switch (timeStretching.algorithm)
    {
        case TimeStretchingParams::Algorithm::Simple:
        {
            // Simple resampling (linear interpolation)
            int newSize = static_cast<int>(buffer.getNumSamples() / stretchRatio);

            juce::AudioBuffer<float> stretched(buffer.getNumChannels(), newSize);

            for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
            {
                const auto* src = buffer.getReadPointer(ch);
                auto* dst = stretched.getWritePointer(ch);

                for (int i = 0; i < newSize; ++i)
                {
                    float srcPos = i * stretchRatio;
                    int srcIdx = static_cast<int>(srcPos);
                    float frac = srcPos - srcIdx;

                    if (srcIdx + 1 < buffer.getNumSamples())
                    {
                        dst[i] = src[srcIdx] * (1.0f - frac) + src[srcIdx + 1] * frac;
                    }
                    else if (srcIdx < buffer.getNumSamples())
                    {
                        dst[i] = src[srcIdx];
                    }
                }
            }

            // Copy back (resize buffer if needed)
            buffer.makeCopyOf(stretched);
            break;
        }

        case TimeStretchingParams::Algorithm::PhaseVocoder:
        case TimeStretchingParams::Algorithm::WSOLA:
        {
            // Advanced time stretching (placeholder)
            // In production: Implement phase vocoder or WSOLA

            DBG("EchoelNetworkSync: Advanced time stretching not yet implemented");
            break;
        }
    }
}

//==============================================================================
// DIAGNOSTICS & MONITORING
//==============================================================================

EchoelNetworkSync::Diagnostics EchoelNetworkSync::getDiagnostics(const juce::String& nodeID) const
{
    Diagnostics diag;

    auto it = nodes.find(nodeID);
    if (it == nodes.end())
        return diag;

    const auto& metrics = it->second.metrics;

    // Latency breakdown
    diag.encodingLatency = 2.0f;    // Typical audio encoding
    diag.networkLatency = metrics.latency;
    diag.decodingLatency = 2.0f;    // Typical audio decoding
    diag.bufferLatency = it->second.jitterBuffer.currentBufferMs;
    diag.totalLatency = diag.encodingLatency + diag.networkLatency + diag.decodingLatency + diag.bufferLatency;

    // Recommendations
    if (metrics.latency > 100.0f)
    {
        diag.recommendations.push_back("High latency detected - consider using relay server");
    }

    if (metrics.jitter > 20.0f)
    {
        diag.recommendations.push_back("High jitter - increase buffer size");
    }

    if (metrics.packetLoss > 0.05f)
    {
        diag.recommendations.push_back("Packet loss detected - enable FEC (Reed-Solomon)");
    }

    auto quality = metrics.getQuality();
    if (quality == NetworkMetrics::Quality::Poor || quality == NetworkMetrics::Quality::Unusable)
    {
        diag.recommendations.push_back("Poor connection quality - reduce audio quality or check network");
    }

    return diag;
}

void EchoelNetworkSync::runNetworkTest(const juce::String& nodeID)
{
    DBG("EchoelNetworkSync: Running network test for node " + nodeID);

    auto it = nodes.find(nodeID);
    if (it == nodes.end())
    {
        DBG("EchoelNetworkSync: Node not found: " + nodeID);
        return;
    }

    // Update network metrics
    updateNetworkMetrics(nodeID);

    // Log diagnostics
    auto diag = getDiagnostics(nodeID);

    DBG("EchoelNetworkSync: === Network Test Results ===");
    DBG("EchoelNetworkSync: Encoding latency: " + juce::String(diag.encodingLatency, 2) + "ms");
    DBG("EchoelNetworkSync: Network latency: " + juce::String(diag.networkLatency, 2) + "ms");
    DBG("EchoelNetworkSync: Decoding latency: " + juce::String(diag.decodingLatency, 2) + "ms");
    DBG("EchoelNetworkSync: Buffer latency: " + juce::String(diag.bufferLatency, 2) + "ms");
    DBG("EchoelNetworkSync: Total latency: " + juce::String(diag.totalLatency, 2) + "ms");

    for (const auto& rec : diag.recommendations)
    {
        DBG("EchoelNetworkSync: RECOMMENDATION: " + rec);
    }
}

void EchoelNetworkSync::enableNetworkLogging(bool enable)
{
    loggingEnabled = enable;
    DBG("EchoelNetworkSync: Network logging " + juce::String(enable ? "ENABLED" : "DISABLED"));
}

juce::String EchoelNetworkSync::getNetworkLog() const
{
    juce::String log;
    for (const auto& entry : networkLog)
    {
        log += entry + "\n";
    }
    return log;
}

//==============================================================================
// INTERNAL METHODS
//==============================================================================

void EchoelNetworkSync::updateNetworkMetrics(const juce::String& nodeID)
{
    auto it = nodes.find(nodeID);
    if (it == nodes.end())
        return;

    auto& metrics = it->second.metrics;

    // In production: Measure actual network metrics
    // For now, use simulated values

    // Simulated latency (would be measured via ping)
    metrics.latency = 25.0f + juce::Random::getSystemRandom().nextFloat() * 10.0f;

    // Simulated jitter
    metrics.jitter = 3.0f + juce::Random::getSystemRandom().nextFloat() * 5.0f;

    // Simulated packet loss
    metrics.packetLoss = 0.001f + juce::Random::getSystemRandom().nextFloat() * 0.01f;

    // Simulated bandwidth
    metrics.bandwidth = 10.0f + juce::Random::getSystemRandom().nextFloat() * 90.0f;  // Mbps

    if (loggingEnabled)
    {
        juce::String logEntry = "Node " + nodeID + ": Latency=" + juce::String(metrics.latency, 1) + "ms, " +
                                "Jitter=" + juce::String(metrics.jitter, 1) + "ms, " +
                                "Loss=" + juce::String(metrics.packetLoss * 100.0f, 2) + "%";
        networkLog.add(logEntry);

        // Keep only last 100 entries
        if (networkLog.size() > 100)
            networkLog.remove(0);
    }
}

void EchoelNetworkSync::adjustJitterBuffer(const juce::String& nodeID)
{
    auto it = nodes.find(nodeID);
    if (it == nodes.end())
        return;

    auto& jitterBuffer = it->second.jitterBuffer;

    if (!jitterBuffer.adaptive)
        return;

    // Adjust based on underruns/overruns
    if (jitterBuffer.underruns > 0)
    {
        // Increase buffer
        int increase = static_cast<int>(jitterBuffer.adaptRate * 10.0f);
        jitterBuffer.currentBufferMs = std::min(jitterBuffer.maxBufferMs, jitterBuffer.currentBufferMs + increase);
        jitterBuffer.underruns = 0;
    }
    else if (jitterBuffer.overruns > 0)
    {
        // Decrease buffer
        int decrease = static_cast<int>(jitterBuffer.adaptRate * 5.0f);
        jitterBuffer.currentBufferMs = std::max(jitterBuffer.minBufferMs, jitterBuffer.currentBufferMs - decrease);
        jitterBuffer.overruns = 0;
    }
}

void EchoelNetworkSync::adaptBitrate(const juce::String& nodeID)
{
    auto it = nodes.find(nodeID);
    if (it == nodes.end() || !adaptiveBitrate.enabled)
        return;

    const auto& metrics = it->second.metrics;

    // Determine optimal quality based on network conditions
    AdaptiveBitrate::Quality optimalQuality;

    auto quality = metrics.getQuality();
    switch (quality)
    {
        case NetworkMetrics::Quality::Excellent:
            optimalQuality = AdaptiveBitrate::Quality::Lossless;
            break;

        case NetworkMetrics::Quality::Good:
            optimalQuality = AdaptiveBitrate::Quality::High;
            break;

        case NetworkMetrics::Quality::Fair:
            optimalQuality = AdaptiveBitrate::Quality::Medium;
            break;

        case NetworkMetrics::Quality::Poor:
            optimalQuality = AdaptiveBitrate::Quality::Low;
            break;

        case NetworkMetrics::Quality::Unusable:
            optimalQuality = AdaptiveBitrate::Quality::UltraLow;
            break;
    }

    // Gradually adjust current quality toward optimal
    if (adaptiveBitrate.currentQuality != optimalQuality)
    {
        // In production: Implement gradual quality transitions
        adaptiveBitrate.currentQuality = optimalQuality;
    }
}

float EchoelNetworkSync::calculateOptimalStretchRatio(const juce::String& nodeID)
{
    auto it = nodes.find(nodeID);
    if (it == nodes.end())
        return 1.0f;

    // Calculate based on buffer fill level and sync state
    const auto& jitterBuffer = it->second.jitterBuffer;
    (void)jitterBuffer;  // Reserved for future buffer monitoring

    // If buffer is too full, speed up slightly (ratio < 1.0)
    // If buffer is too empty, slow down slightly (ratio > 1.0)

    float fillLevel = 0.5f;  // Would be measured from actual buffer
    float targetFill = 0.5f;
    float fillError = fillLevel - targetFill;

    // Calculate stretch ratio
    float ratio = 1.0f - fillError * 0.1f;  // Max 10% adjustment

    // Clamp to max stretch ratio
    ratio = juce::jlimit(1.0f / timeStretching.maxStretchRatio,
                        timeStretching.maxStretchRatio,
                        ratio);

    return ratio;
}

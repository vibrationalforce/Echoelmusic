#pragma once

/**
 * Echoelmusic Audio Engine for Android
 * Ultra-low-latency synthesis using Oboe (AAudio/OpenSL ES)
 *
 * Features:
 * - 16-voice polyphonic synthesizer
 * - TR-808 Bass with pitch glide
 * - Bio-reactive parameter modulation
 * - < 10ms latency on AAudio devices
 */

#include <oboe/Oboe.h>
#include <array>
#include <atomic>
#include <memory>
#include "Synth.h"
#include "TR808Engine.h"

namespace echoelmusic {

class EchoelmusicEngine : public oboe::AudioStreamCallback {
public:
    EchoelmusicEngine();
    ~EchoelmusicEngine();

    // Lifecycle
    bool create(int sampleRate, int framesPerBuffer);
    bool start();
    void stop();
    void destroy();

    // Latency info
    float getLatencyMs() const;

    // Synth control
    void noteOn(int note, int velocity);
    void noteOff(int note);
    void setParameter(int paramId, float value);

    // Bio-reactive
    void updateBioData(float heartRate, float hrv, float coherence);

    // TR-808
    void trigger808(int note, int velocity);
    void set808Parameter(int paramId, float value);

    // Oboe callback
    oboe::DataCallbackResult onAudioReady(
        oboe::AudioStream* stream,
        void* audioData,
        int32_t numFrames) override;

    void onErrorAfterClose(oboe::AudioStream* stream, oboe::Result error) override;

private:
    // Audio stream
    std::shared_ptr<oboe::AudioStream> mStream;
    int mSampleRate = 48000;
    int mFramesPerBuffer = 192;
    int mChannelCount = 2;

    // Engines
    std::unique_ptr<Synth> mSynth;
    std::unique_ptr<TR808Engine> m808;

    // Bio-reactive state
    std::atomic<float> mHeartRate{70.0f};
    std::atomic<float> mHRV{50.0f};
    std::atomic<float> mCoherence{0.5f};

    // Mixing buffer
    std::vector<float> mMixBuffer;

    // State
    std::atomic<bool> mIsRunning{false};

    // Stream setup
    oboe::Result createStream();
    void applyBioModulation();
};

} // namespace echoelmusic

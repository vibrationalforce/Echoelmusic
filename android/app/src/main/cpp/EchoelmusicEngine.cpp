#include "EchoelmusicEngine.h"
#include <android/log.h>
#include <cmath>

#define LOG_TAG "EchoelmusicEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace echoelmusic {

EchoelmusicEngine::EchoelmusicEngine() {
    LOGI("EchoelmusicEngine created");
}

EchoelmusicEngine::~EchoelmusicEngine() {
    destroy();
    LOGI("EchoelmusicEngine destroyed");
}

bool EchoelmusicEngine::create(int sampleRate, int framesPerBuffer) {
    mSampleRate = sampleRate;
    mFramesPerBuffer = framesPerBuffer;

    // Create synth engine
    mSynth = std::make_unique<Synth>();
    mSynth->setSampleRate(static_cast<float>(sampleRate));

    // Create 808 engine
    m808 = std::make_unique<TR808Engine>();
    m808->setSampleRate(static_cast<float>(sampleRate));

    // Pre-allocate mix buffers (stereo) - CRITICAL for real-time audio safety
    mMixBuffer.resize(framesPerBuffer * 2, 0.0f);
    m808Buffer.resize(framesPerBuffer * 2, 0.0f);

    LOGI("Engine created: %d Hz, %d frames/buffer (buffers pre-allocated)", sampleRate, framesPerBuffer);
    return true;
}

oboe::Result EchoelmusicEngine::createStream() {
    oboe::AudioStreamBuilder builder;

    builder.setDirection(oboe::Direction::Output)
           ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
           ->setSharingMode(oboe::SharingMode::Exclusive)
           ->setFormat(oboe::AudioFormat::Float)
           ->setChannelCount(mChannelCount)
           ->setSampleRate(mSampleRate)
           ->setFramesPerCallback(mFramesPerBuffer)
           ->setCallback(this)
           ->setUsage(oboe::Usage::Media)
           ->setContentType(oboe::ContentType::Music);

    oboe::Result result = builder.openStream(mStream);

    if (result != oboe::Result::OK) {
        LOGE("Failed to create stream: %s", oboe::convertToText(result));
        return result;
    }

    // Log actual stream parameters
    LOGI("Stream created:");
    LOGI("  Sample rate: %d", mStream->getSampleRate());
    LOGI("  Frames per burst: %d", mStream->getFramesPerBurst());
    LOGI("  Buffer capacity: %d", mStream->getBufferCapacityInFrames());
    LOGI("  Audio API: %s",
         mStream->getAudioApi() == oboe::AudioApi::AAudio ? "AAudio" : "OpenSL ES");

    return result;
}

bool EchoelmusicEngine::start() {
    if (mIsRunning) return true;

    oboe::Result result = createStream();
    if (result != oboe::Result::OK) {
        return false;
    }

    result = mStream->requestStart();
    if (result != oboe::Result::OK) {
        LOGE("Failed to start stream: %s", oboe::convertToText(result));
        return false;
    }

    mIsRunning = true;
    LOGI("Audio started");
    return true;
}

void EchoelmusicEngine::stop() {
    if (!mIsRunning) return;

    if (mStream) {
        mStream->requestStop();
        mStream->close();
        mStream.reset();
    }

    mIsRunning = false;
    LOGI("Audio stopped");
}

void EchoelmusicEngine::destroy() {
    stop();
    mSynth.reset();
    m808.reset();
}

float EchoelmusicEngine::getLatencyMs() const {
    if (!mStream) return 0.0f;

    auto latencyResult = mStream->calculateLatencyMillis();
    if (latencyResult) {
        return static_cast<float>(latencyResult.value());
    }
    return 0.0f;
}

void EchoelmusicEngine::noteOn(int note, int velocity) {
    if (mSynth) {
        mSynth->noteOn(note, velocity);
    }
}

void EchoelmusicEngine::noteOff(int note) {
    if (mSynth) {
        mSynth->noteOff(note);
    }
}

void EchoelmusicEngine::setParameter(int paramId, float value) {
    if (mSynth) {
        mSynth->setParameter(paramId, value);
    }
}

void EchoelmusicEngine::updateBioData(float heartRate, float hrv, float coherence) {
    mHeartRate.store(heartRate);
    mHRV.store(hrv);
    mCoherence.store(coherence);
}

void EchoelmusicEngine::trigger808(int note, int velocity) {
    if (m808) {
        m808->trigger(note, velocity);
    }
}

void EchoelmusicEngine::set808Parameter(int paramId, float value) {
    if (m808) {
        m808->setParameter(paramId, value);
    }
}

void EchoelmusicEngine::applyBioModulation() {
    float coherence = mCoherence.load();
    float hrv = mHRV.load();
    float hr = mHeartRate.load();

    // HRV affects filter cutoff (high HRV = brighter sound)
    float normalizedHRV = (hrv - 20.0f) / 80.0f; // Normalize 20-100ms to 0-1
    normalizedHRV = std::clamp(normalizedHRV, 0.0f, 1.0f);

    if (mSynth) {
        // Modulate filter based on HRV
        float baseFilter = mSynth->getParameter(10); // FILTER_CUTOFF
        float modulatedFilter = baseFilter * (0.7f + normalizedHRV * 0.6f);
        mSynth->setFilterCutoffDirect(modulatedFilter);

        // Modulate LFO rate based on heart rate
        float baseLFO = mSynth->getParameter(30); // LFO_RATE
        float hrNormalized = (hr - 60.0f) / 60.0f; // 60-120 bpm normalized
        float modulatedLFO = baseLFO * (0.8f + hrNormalized * 0.4f);
        mSynth->setLFORateDirect(modulatedLFO);
    }

    if (m808) {
        // Coherence affects 808 decay (high coherence = longer decay)
        float baseDecay = m808->getParameter(0);
        float modulatedDecay = baseDecay * (0.8f + coherence * 0.4f);
        m808->setDecayDirect(modulatedDecay);
    }
}

oboe::DataCallbackResult EchoelmusicEngine::onAudioReady(
    oboe::AudioStream* stream,
    void* audioData,
    int32_t numFrames) {

    auto* output = static_cast<float*>(audioData);

    // Apply bio-reactive modulation
    applyBioModulation();

    // Clear mix buffer
    std::fill(mMixBuffer.begin(), mMixBuffer.begin() + numFrames * 2, 0.0f);

    // Render synth
    if (mSynth) {
        mSynth->process(mMixBuffer.data(), numFrames);
    }

    // Render 808 and add to mix (using pre-allocated buffer for real-time safety)
    if (m808) {
        // Clear pre-allocated 808 buffer
        std::fill(m808Buffer.begin(), m808Buffer.begin() + numFrames * 2, 0.0f);
        m808->process(m808Buffer.data(), numFrames);

        // Mix 808 into main buffer
        for (int i = 0; i < numFrames * 2; i++) {
            mMixBuffer[i] += m808Buffer[i];
        }
    }

    // Soft clip and copy to output
    for (int i = 0; i < numFrames * 2; i++) {
        float sample = mMixBuffer[i];
        // Soft clipping
        if (sample > 1.0f) {
            sample = 1.0f - std::exp(-sample + 1.0f);
        } else if (sample < -1.0f) {
            sample = -1.0f + std::exp(sample + 1.0f);
        }
        output[i] = sample;
    }

    return oboe::DataCallbackResult::Continue;
}

void EchoelmusicEngine::onErrorAfterClose(oboe::AudioStream* stream, oboe::Result error) {
    LOGE("Audio error: %s", oboe::convertToText(error));
    mIsRunning = false;

    // Try to restart
    if (error == oboe::Result::ErrorDisconnected) {
        LOGI("Attempting to restart after disconnect...");
        start();
    }
}

} // namespace echoelmusic

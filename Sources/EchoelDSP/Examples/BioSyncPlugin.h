#pragma once
// ============================================================================
// EchoelDSP/Examples/BioSyncPlugin.h - Bio-Reactive Audio Plugin
// ============================================================================
// Example plugin demonstrating EchoelDSP capabilities
// Modulates audio based on HRV coherence and heart rate
// ============================================================================

#include "../EchoelDSP.h"
#include "../Plugin/PluginAPI.h"

namespace Echoel::Examples {

class BioSyncPlugin : public Plugin::PluginBase {
public:
    // Parameter IDs
    enum ParamID : uint32_t {
        kCoherence = 0,
        kHeartRate,
        kFilterAmount,
        kReverbAmount,
        kBioMix,
        kNumParams
    };

    BioSyncPlugin() {
        // Initialize filters
        lowPassFilter_.setParameters(DSP::BiquadFilter::Type::LowPass, 5000.0f, 48000.0f, 0.707f);
        highPassFilter_.setParameters(DSP::BiquadFilter::Type::HighPass, 80.0f, 48000.0f, 0.707f);
    }

    // ========================================================================
    // Plugin Info
    // ========================================================================

    Info getPluginInfo() const override {
        Info info;
        info.name = "BioSync";
        info.vendor = "Echoelmusic";
        info.version = "1.0.0";
        info.url = "https://echoelmusic.com";
        info.uniqueId = "com.echoelmusic.biosync";
        info.category = Plugin::PluginCategory::BioReactive;
        info.hasEditor = true;
        info.editorWidth = 600;
        info.editorHeight = 400;
        info.acceptsMidi = false;
        info.producesMidi = false;
        info.isSynth = false;
        info.wantsMidiInput = false;
        return info;
    }

    // ========================================================================
    // Parameters
    // ========================================================================

    std::vector<Plugin::ParameterInfo> getParameters() const override {
        std::vector<Plugin::ParameterInfo> params;

        params.push_back({
            kCoherence, "Coherence", "Coh", "", Plugin::ParameterType::Float,
            0.5f, 0.0f, 1.0f, 0.01f, {}, true, false, "Bio Input"
        });

        params.push_back({
            kHeartRate, "Heart Rate", "HR", "BPM", Plugin::ParameterType::Float,
            70.0f, 40.0f, 200.0f, 1.0f, {}, true, false, "Bio Input"
        });

        params.push_back({
            kFilterAmount, "Filter Depth", "Flt", "%", Plugin::ParameterType::Float,
            0.5f, 0.0f, 1.0f, 0.01f, {}, true, false, "Modulation"
        });

        params.push_back({
            kReverbAmount, "Reverb Depth", "Rev", "%", Plugin::ParameterType::Float,
            0.3f, 0.0f, 1.0f, 0.01f, {}, true, false, "Modulation"
        });

        params.push_back({
            kBioMix, "Bio Mix", "Mix", "%", Plugin::ParameterType::Float,
            0.5f, 0.0f, 1.0f, 0.01f, {}, true, false, "Output"
        });

        return params;
    }

    float getParameter(uint32_t id) const override {
        switch (id) {
            case kCoherence: return coherence_.load(std::memory_order_relaxed);
            case kHeartRate: return heartRate_.load(std::memory_order_relaxed);
            case kFilterAmount: return filterAmount_.load(std::memory_order_relaxed);
            case kReverbAmount: return reverbAmount_.load(std::memory_order_relaxed);
            case kBioMix: return bioMix_.load(std::memory_order_relaxed);
            default: return 0.0f;
        }
    }

    void setParameter(uint32_t id, float value) override {
        switch (id) {
            case kCoherence:
                coherence_.store(value, std::memory_order_relaxed);
                break;
            case kHeartRate:
                heartRate_.store(value, std::memory_order_relaxed);
                break;
            case kFilterAmount:
                filterAmount_.store(value, std::memory_order_relaxed);
                break;
            case kReverbAmount:
                reverbAmount_.store(value, std::memory_order_relaxed);
                break;
            case kBioMix:
                bioMix_.store(value, std::memory_order_relaxed);
                break;
        }
    }

    // ========================================================================
    // Audio Processing
    // ========================================================================

    void prepare(double sampleRate, int maxBlockSize) override {
        PluginBase::prepare(sampleRate, maxBlockSize);

        // Update filter coefficients
        lowPassFilter_.setParameters(DSP::BiquadFilter::Type::LowPass, 5000.0f, sampleRate, 0.707f);
        highPassFilter_.setParameters(DSP::BiquadFilter::Type::HighPass, 80.0f, sampleRate, 0.707f);

        // Prepare smoothers
        coherenceSmoother_.prepare(sampleRate, 50.0f);
        filterSmoother_.prepare(sampleRate, 10.0f);

        // Prepare delay for simple reverb
        reverbDelay_.prepare(static_cast<int>(sampleRate * 0.1)); // 100ms max delay
        reverbDelay_.setDelay(sampleRate * 0.05f); // 50ms delay
    }

    void process(DSP::AudioBuffer<float>& buffer, const Plugin::ProcessContext& context) override {
        // Read atomic parameters
        float coherence = coherence_.load(std::memory_order_relaxed);
        float heartRate = heartRate_.load(std::memory_order_relaxed);
        float filterAmount = filterAmount_.load(std::memory_order_relaxed);
        float reverbAmount = reverbAmount_.load(std::memory_order_relaxed);
        float bioMix = bioMix_.load(std::memory_order_relaxed);

        int numSamples = buffer.getNumSamples();
        int numChannels = buffer.getNumChannels();

        // Bio-reactive filter modulation
        // High coherence → brighter sound (higher cutoff)
        // Low coherence → darker sound (lower cutoff)
        float cutoffNormalized = 0.3f + coherence * 0.7f; // 30-100% of max
        float cutoffHz = 200.0f + cutoffNormalized * 18000.0f; // 200Hz - 18kHz
        cutoffHz = cutoffHz * (1.0f - filterAmount) + cutoffHz * filterAmount;

        // Update filter with smoothing
        filterSmoother_.setTarget(cutoffHz);

        for (int ch = 0; ch < numChannels; ++ch) {
            float* samples = buffer.getWritePointer(ch);

            // Copy dry signal
            std::vector<float> dry(samples, samples + numSamples);

            // Apply coherence-modulated filter
            float smoothedCutoff = filterSmoother_.getNext();
            lowPassFilter_.setParameters(DSP::BiquadFilter::Type::LowPass,
                                        smoothedCutoff, sampleRate_, 0.707f + coherence * 0.3f);
            lowPassFilter_.processBlock(samples, numSamples);

            // Apply high-pass to keep clarity
            highPassFilter_.processBlock(samples, numSamples);

            // Bio-reactive reverb (simple delay-based)
            // Heart rate modulates reverb time
            float delayMs = 30.0f + (1.0f - (heartRate - 40.0f) / 160.0f) * 70.0f; // 30-100ms
            reverbDelay_.setDelay(delayMs * sampleRate_ / 1000.0f);

            for (int i = 0; i < numSamples; ++i) {
                float delayedSample = reverbDelay_.processSample(samples[i]);
                samples[i] += delayedSample * reverbAmount * 0.5f;
            }

            // Mix dry/wet
            for (int i = 0; i < numSamples; ++i) {
                samples[i] = dry[i] * (1.0f - bioMix) + samples[i] * bioMix;
            }
        }
    }

    void reset() override {
        lowPassFilter_.reset();
        highPassFilter_.reset();
        reverbDelay_.reset();
        coherenceSmoother_.reset(0.5f);
        filterSmoother_.reset(5000.0f);
    }

    // ========================================================================
    // State
    // ========================================================================

    std::vector<uint8_t> getState() const override {
        std::vector<uint8_t> state(kNumParams * sizeof(float));
        float* data = reinterpret_cast<float*>(state.data());
        data[0] = coherence_.load();
        data[1] = heartRate_.load();
        data[2] = filterAmount_.load();
        data[3] = reverbAmount_.load();
        data[4] = bioMix_.load();
        return state;
    }

    void setState(const std::vector<uint8_t>& state) override {
        if (state.size() >= kNumParams * sizeof(float)) {
            const float* data = reinterpret_cast<const float*>(state.data());
            coherence_.store(data[0]);
            heartRate_.store(data[1]);
            filterAmount_.store(data[2]);
            reverbAmount_.store(data[3]);
            bioMix_.store(data[4]);
        }
    }

    int getLatencySamples() const override { return 0; }

private:
    // Atomic parameters (lock-free for audio thread)
    std::atomic<float> coherence_{0.5f};
    std::atomic<float> heartRate_{70.0f};
    std::atomic<float> filterAmount_{0.5f};
    std::atomic<float> reverbAmount_{0.3f};
    std::atomic<float> bioMix_{0.5f};

    // DSP components
    DSP::BiquadFilter lowPassFilter_;
    DSP::BiquadFilter highPassFilter_;
    DSP::DelayLine reverbDelay_;
    DSP::ParameterSmoother coherenceSmoother_;
    DSP::ParameterSmoother filterSmoother_;
};

// Register plugin
ECHOEL_REGISTER_PLUGIN(BioSyncPlugin)

} // namespace Echoel::Examples

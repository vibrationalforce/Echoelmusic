#pragma once
// ============================================================================
// EchoelDSP/AudioBuffer.h - Lock-Free Audio Buffer System
// ============================================================================
// Zero dependencies. Pure C++17. Real-time safe.
// Replaces JUCE AudioBuffer with superior lock-free design.
// ============================================================================

#include <cstdint>
#include <cstring>
#include <memory>
#include <atomic>
#include <cassert>
#include "SIMD.h"

namespace Echoel::DSP {

// ============================================================================
// MARK: - AudioBuffer (Multi-Channel, Cache-Aligned)
// ============================================================================

template<typename SampleType = float>
class AudioBuffer {
public:
    static constexpr size_t CacheLineSize = 64;

    AudioBuffer() = default;

    AudioBuffer(int numChannels, int numSamples)
        : numChannels_(numChannels), numSamples_(numSamples)
    {
        allocate(numChannels, numSamples);
    }

    ~AudioBuffer() {
        deallocate();
    }

    // Move semantics (no copy - audio buffers should not be copied in RT)
    AudioBuffer(AudioBuffer&& other) noexcept
        : data_(other.data_)
        , channels_(other.channels_)
        , numChannels_(other.numChannels_)
        , numSamples_(other.numSamples_)
        , allocatedSize_(other.allocatedSize_)
    {
        other.data_ = nullptr;
        other.channels_ = nullptr;
        other.numChannels_ = 0;
        other.numSamples_ = 0;
        other.allocatedSize_ = 0;
    }

    AudioBuffer& operator=(AudioBuffer&& other) noexcept {
        if (this != &other) {
            deallocate();
            data_ = other.data_;
            channels_ = other.channels_;
            numChannels_ = other.numChannels_;
            numSamples_ = other.numSamples_;
            allocatedSize_ = other.allocatedSize_;
            other.data_ = nullptr;
            other.channels_ = nullptr;
            other.numChannels_ = 0;
            other.numSamples_ = 0;
            other.allocatedSize_ = 0;
        }
        return *this;
    }

    // Disable copy (use move or explicit copy methods)
    AudioBuffer(const AudioBuffer&) = delete;
    AudioBuffer& operator=(const AudioBuffer&) = delete;

    // ========================================================================
    // Allocation
    // ========================================================================

    void setSize(int numChannels, int numSamples, bool keepExisting = false) {
        if (numChannels == numChannels_ && numSamples <= allocatedSize_ / numChannels_) {
            numSamples_ = numSamples;
            return;
        }

        AudioBuffer newBuffer(numChannels, numSamples);

        if (keepExisting && data_) {
            int channelsToCopy = std::min(numChannels, numChannels_);
            int samplesToCopy = std::min(numSamples, numSamples_);
            for (int ch = 0; ch < channelsToCopy; ++ch) {
                std::memcpy(newBuffer.getWritePointer(ch), getReadPointer(ch),
                           samplesToCopy * sizeof(SampleType));
            }
        }

        *this = std::move(newBuffer);
    }

    // ========================================================================
    // Accessors
    // ========================================================================

    int getNumChannels() const noexcept { return numChannels_; }
    int getNumSamples() const noexcept { return numSamples_; }

    const SampleType* getReadPointer(int channel) const noexcept {
        assert(channel >= 0 && channel < numChannels_);
        return channels_[channel];
    }

    SampleType* getWritePointer(int channel) noexcept {
        assert(channel >= 0 && channel < numChannels_);
        return channels_[channel];
    }

    const SampleType* const* getArrayOfReadPointers() const noexcept {
        return const_cast<const SampleType* const*>(channels_);
    }

    SampleType* const* getArrayOfWritePointers() noexcept {
        return channels_;
    }

    SampleType getSample(int channel, int sampleIndex) const noexcept {
        assert(channel >= 0 && channel < numChannels_);
        assert(sampleIndex >= 0 && sampleIndex < numSamples_);
        return channels_[channel][sampleIndex];
    }

    void setSample(int channel, int sampleIndex, SampleType value) noexcept {
        assert(channel >= 0 && channel < numChannels_);
        assert(sampleIndex >= 0 && sampleIndex < numSamples_);
        channels_[channel][sampleIndex] = value;
    }

    // ========================================================================
    // Operations (SIMD-optimized)
    // ========================================================================

    void clear() noexcept {
        for (int ch = 0; ch < numChannels_; ++ch) {
            std::memset(channels_[ch], 0, numSamples_ * sizeof(SampleType));
        }
    }

    void clear(int startSample, int numSamplesToClear) noexcept {
        for (int ch = 0; ch < numChannels_; ++ch) {
            std::memset(channels_[ch] + startSample, 0, numSamplesToClear * sizeof(SampleType));
        }
    }

    void applyGain(float gain) noexcept {
        for (int ch = 0; ch < numChannels_; ++ch) {
            Echoel::DSP::applyGain(channels_[ch], numSamples_, gain);
        }
    }

    void applyGain(int channel, float gain) noexcept {
        Echoel::DSP::applyGain(channels_[channel], numSamples_, gain);
    }

    void applyGainRamp(float startGain, float endGain) noexcept {
        float delta = (endGain - startGain) / numSamples_;
        for (int ch = 0; ch < numChannels_; ++ch) {
            float gain = startGain;
            for (int i = 0; i < numSamples_; ++i) {
                channels_[ch][i] *= gain;
                gain += delta;
            }
        }
    }

    void addFrom(int destChannel, int destStartSample,
                 const AudioBuffer& source, int sourceChannel,
                 int sourceStartSample, int numSamplesToAdd,
                 float gain = 1.0f) noexcept
    {
        const SampleType* src = source.getReadPointer(sourceChannel) + sourceStartSample;
        SampleType* dst = channels_[destChannel] + destStartSample;

        if (gain == 1.0f) {
            for (int i = 0; i < numSamplesToAdd; ++i) {
                dst[i] += src[i];
            }
        } else {
            for (int i = 0; i < numSamplesToAdd; ++i) {
                dst[i] += src[i] * gain;
            }
        }
    }

    void copyFrom(int destChannel, int destStartSample,
                  const AudioBuffer& source, int sourceChannel,
                  int sourceStartSample, int numSamplesToCopy) noexcept
    {
        const SampleType* src = source.getReadPointer(sourceChannel) + sourceStartSample;
        SampleType* dst = channels_[destChannel] + destStartSample;
        std::memcpy(dst, src, numSamplesToCopy * sizeof(SampleType));
    }

    float getRMSLevel(int channel, int startSample, int numSamplesToCheck) const noexcept {
        return computeRMS(channels_[channel] + startSample, numSamplesToCheck);
    }

    float getMagnitude(int channel, int startSample, int numSamplesToCheck) const noexcept {
        return computePeak(channels_[channel] + startSample, numSamplesToCheck);
    }

private:
    void allocate(int numChannels, int numSamples) {
        numChannels_ = numChannels;
        numSamples_ = numSamples;

        // Allocate channel pointers
        channels_ = new SampleType*[numChannels];

        // Calculate aligned size per channel
        size_t samplesPerChannel = ((numSamples * sizeof(SampleType) + CacheLineSize - 1)
                                   / CacheLineSize) * CacheLineSize / sizeof(SampleType);
        allocatedSize_ = samplesPerChannel * numChannels;

        // Allocate aligned memory block
        #if defined(_MSC_VER)
            data_ = static_cast<SampleType*>(_aligned_malloc(allocatedSize_ * sizeof(SampleType), CacheLineSize));
        #else
            data_ = static_cast<SampleType*>(std::aligned_alloc(CacheLineSize, allocatedSize_ * sizeof(SampleType)));
        #endif

        // Set up channel pointers
        for (int ch = 0; ch < numChannels; ++ch) {
            channels_[ch] = data_ + ch * samplesPerChannel;
        }

        // Zero the buffer
        std::memset(data_, 0, allocatedSize_ * sizeof(SampleType));
    }

    void deallocate() {
        if (data_) {
            #if defined(_MSC_VER)
                _aligned_free(data_);
            #else
                std::free(data_);
            #endif
            data_ = nullptr;
        }
        if (channels_) {
            delete[] channels_;
            channels_ = nullptr;
        }
    }

    SampleType* data_ = nullptr;
    SampleType** channels_ = nullptr;
    int numChannels_ = 0;
    int numSamples_ = 0;
    size_t allocatedSize_ = 0;
};

// ============================================================================
// MARK: - Ring Buffer (Lock-Free SPSC)
// ============================================================================

template<typename T, size_t Capacity>
class RingBuffer {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");

public:
    RingBuffer() : writePos_(0), readPos_(0) {
        std::memset(buffer_, 0, sizeof(buffer_));
    }

    bool push(const T& item) noexcept {
        size_t writePos = writePos_.load(std::memory_order_relaxed);
        size_t nextWrite = (writePos + 1) & (Capacity - 1);

        if (nextWrite == readPos_.load(std::memory_order_acquire)) {
            return false; // Full
        }

        buffer_[writePos] = item;
        writePos_.store(nextWrite, std::memory_order_release);
        return true;
    }

    bool pop(T& item) noexcept {
        size_t readPos = readPos_.load(std::memory_order_relaxed);

        if (readPos == writePos_.load(std::memory_order_acquire)) {
            return false; // Empty
        }

        item = buffer_[readPos];
        readPos_.store((readPos + 1) & (Capacity - 1), std::memory_order_release);
        return true;
    }

    size_t size() const noexcept {
        size_t write = writePos_.load(std::memory_order_relaxed);
        size_t read = readPos_.load(std::memory_order_relaxed);
        return (write - read + Capacity) & (Capacity - 1);
    }

    bool empty() const noexcept {
        return readPos_.load(std::memory_order_relaxed) ==
               writePos_.load(std::memory_order_relaxed);
    }

    void clear() noexcept {
        readPos_.store(0, std::memory_order_relaxed);
        writePos_.store(0, std::memory_order_relaxed);
    }

private:
    alignas(64) T buffer_[Capacity];
    alignas(64) std::atomic<size_t> writePos_;
    alignas(64) std::atomic<size_t> readPos_;
};

// ============================================================================
// MARK: - Audio Block (Fixed-Size for RT Processing)
// ============================================================================

template<int MaxChannels = 2, int MaxSamples = 512>
struct AudioBlock {
    alignas(64) float data[MaxChannels][MaxSamples];
    int numChannels = 0;
    int numSamples = 0;

    float* operator[](int channel) { return data[channel]; }
    const float* operator[](int channel) const { return data[channel]; }

    void clear() {
        std::memset(data, 0, sizeof(data));
    }

    void copyFrom(const AudioBuffer<float>& buffer) {
        numChannels = std::min(buffer.getNumChannels(), MaxChannels);
        numSamples = std::min(buffer.getNumSamples(), MaxSamples);
        for (int ch = 0; ch < numChannels; ++ch) {
            std::memcpy(data[ch], buffer.getReadPointer(ch), numSamples * sizeof(float));
        }
    }

    void copyTo(AudioBuffer<float>& buffer) const {
        for (int ch = 0; ch < std::min(numChannels, buffer.getNumChannels()); ++ch) {
            std::memcpy(buffer.getWritePointer(ch), data[ch],
                       std::min(numSamples, buffer.getNumSamples()) * sizeof(float));
        }
    }
};

} // namespace Echoel::DSP

#pragma once
/**
 * EchoelCore - SPSCQueue
 *
 * Lock-free, wait-free single-producer single-consumer queue.
 * Optimized for real-time audio thread communication.
 *
 * Based on research from:
 * - cameron314/readerwriterqueue
 * - rigtorp/SPSCQueue
 * - Moodycamel lock-free queue
 *
 * MIT License - Echoelmusic 2026
 */

#include <atomic>
#include <array>
#include <cstddef>
#include <type_traits>
#include <new>

namespace EchoelCore {

/**
 * Cache line size for padding to prevent false sharing.
 * Most modern CPUs use 64-byte cache lines.
 */
#ifdef __cpp_lib_hardware_interference_size
    constexpr size_t kCacheLineSize = std::hardware_destructive_interference_size;
#else
    constexpr size_t kCacheLineSize = 64;
#endif

/**
 * SPSCQueue - Single Producer Single Consumer Lock-Free Queue
 *
 * @tparam T Element type (must be trivially copyable for best performance)
 * @tparam Capacity Maximum number of elements (must be power of 2)
 *
 * Thread Safety:
 * - One thread may call push() (producer)
 * - One thread may call pop() (consumer)
 * - No locks, no memory allocation, wait-free
 *
 * Usage:
 *   SPSCQueue<ParamChange, 256> paramQueue;
 *
 *   // Audio thread (consumer)
 *   ParamChange change;
 *   while (paramQueue.pop(change)) {
 *       applyParamChange(change);
 *   }
 *
 *   // UI thread (producer)
 *   paramQueue.push({ParamID::FilterCutoff, 0.5f});
 */
template<typename T, size_t Capacity>
class SPSCQueue {
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");
    static_assert(Capacity >= 2, "Capacity must be at least 2");

public:
    SPSCQueue() noexcept : mHead(0), mTail(0) {
        // Zero-initialize the buffer
        for (size_t i = 0; i < Capacity; ++i) {
            new (&mBuffer[i]) T();
        }
    }

    ~SPSCQueue() = default;

    // Non-copyable, non-movable (atomic members)
    SPSCQueue(const SPSCQueue&) = delete;
    SPSCQueue& operator=(const SPSCQueue&) = delete;
    SPSCQueue(SPSCQueue&&) = delete;
    SPSCQueue& operator=(SPSCQueue&&) = delete;

    /**
     * Push an element to the queue.
     * ONLY call from producer thread.
     *
     * @param item The item to push
     * @return true if successful, false if queue is full
     */
    bool push(const T& item) noexcept {
        const size_t head = mHead.load(std::memory_order_relaxed);
        const size_t nextHead = (head + 1) & kMask;

        // Check if queue is full
        if (nextHead == mTail.load(std::memory_order_acquire)) {
            return false; // Queue full
        }

        mBuffer[head] = item;

        // Release ensures the write to mBuffer is visible before head update
        mHead.store(nextHead, std::memory_order_release);
        return true;
    }

    /**
     * Push an element using move semantics.
     * ONLY call from producer thread.
     */
    bool push(T&& item) noexcept {
        const size_t head = mHead.load(std::memory_order_relaxed);
        const size_t nextHead = (head + 1) & kMask;

        if (nextHead == mTail.load(std::memory_order_acquire)) {
            return false;
        }

        mBuffer[head] = std::move(item);
        mHead.store(nextHead, std::memory_order_release);
        return true;
    }

    /**
     * Pop an element from the queue.
     * ONLY call from consumer thread.
     *
     * @param item Output parameter for the popped item
     * @return true if successful, false if queue is empty
     */
    bool pop(T& item) noexcept {
        const size_t tail = mTail.load(std::memory_order_relaxed);

        // Check if queue is empty
        if (tail == mHead.load(std::memory_order_acquire)) {
            return false; // Queue empty
        }

        item = std::move(mBuffer[tail]);

        // Release ensures we've finished reading before updating tail
        mTail.store((tail + 1) & kMask, std::memory_order_release);
        return true;
    }

    /**
     * Peek at the front element without removing it.
     * ONLY call from consumer thread.
     */
    bool peek(T& item) const noexcept {
        const size_t tail = mTail.load(std::memory_order_relaxed);

        if (tail == mHead.load(std::memory_order_acquire)) {
            return false;
        }

        item = mBuffer[tail];
        return true;
    }

    /**
     * Check if queue is empty.
     * Can be called from any thread (approximate).
     */
    bool empty() const noexcept {
        return mHead.load(std::memory_order_acquire) ==
               mTail.load(std::memory_order_acquire);
    }

    /**
     * Get approximate size.
     * Can be called from any thread (approximate).
     */
    size_t size() const noexcept {
        const size_t head = mHead.load(std::memory_order_acquire);
        const size_t tail = mTail.load(std::memory_order_acquire);
        return (head - tail) & kMask;
    }

    /**
     * Get capacity.
     */
    static constexpr size_t capacity() noexcept {
        return Capacity - 1; // One slot reserved for full detection
    }

    /**
     * Clear all elements.
     * NOT thread-safe - only call when no other threads are accessing.
     */
    void clear() noexcept {
        mHead.store(0, std::memory_order_relaxed);
        mTail.store(0, std::memory_order_relaxed);
    }

private:
    static constexpr size_t kMask = Capacity - 1;

    // Separate cache lines to prevent false sharing
    alignas(kCacheLineSize) std::atomic<size_t> mHead;
    alignas(kCacheLineSize) std::atomic<size_t> mTail;
    alignas(kCacheLineSize) std::array<T, Capacity> mBuffer;
};

/**
 * Common queue types for Echoelmusic
 */

// Parameter change message
struct ParamChange {
    uint32_t paramId;
    float value;
    uint32_t sampleOffset; // For sample-accurate automation
};

// Spectrum data for visualization
struct SpectrumData {
    static constexpr size_t kBins = 64;
    std::array<float, kBins> magnitudes;
    float peakFrequency;
    float rmsLevel;
};

// Bio-reactive update
struct BioUpdate {
    float hrv;
    float coherence;
    float heartRate;
    float breathPhase;
    uint64_t timestamp;
};

// Pre-defined queue types
using ParamQueue = SPSCQueue<ParamChange, 256>;
using SpectrumQueue = SPSCQueue<SpectrumData, 4>;
using BioQueue = SPSCQueue<BioUpdate, 64>;

} // namespace EchoelCore

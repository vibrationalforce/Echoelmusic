// LockFreeRingBuffer.h - Lock-Free SPSC Ring Buffer for Real-Time Audio
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <atomic>
#include <array>

namespace Echoel {
namespace Audio {

/**
 * @brief Lock-free Single Producer Single Consumer (SPSC) ring buffer
 *
 * This class provides a wait-free ring buffer suitable for real-time audio processing.
 * It uses atomic operations and memory ordering to avoid locks, making it safe for
 * use in real-time threads where blocking is unacceptable.
 *
 * @par Thread Safety
 * - ONE producer thread (e.g., UI thread)
 * - ONE consumer thread (e.g., audio thread)
 * - NOT safe for multiple producers or consumers
 *
 * @par Performance
 * - Push: O(1) wait-free
 * - Pop: O(1) wait-free
 * - No dynamic memory allocation
 * - No locks or blocking
 * - Cache-line aligned atomics to prevent false sharing
 *
 * @par Real-Time Guarantees
 * - No locks (lock-free)
 * - No memory allocation
 * - No system calls
 * - Bounded execution time
 * - Safe for audio threads (SCHED_FIFO compatible)
 *
 * @tparam T Element type (must be trivially copyable)
 * @tparam Capacity Buffer capacity (must be power of 2 for optimal performance)
 *
 * @example
 * @code
 * // Create buffer for audio samples
 * LockFreeRingBuffer<float, 1024> audioBuffer;
 *
 * // Producer thread (UI)
 * audioBuffer.push(0.5f);
 *
 * // Consumer thread (Audio)
 * float sample;
 * if (audioBuffer.pop(sample)) {
 *     processAudio(sample);
 * }
 * @endcode
 *
 * @see https://en.cppreference.com/w/cpp/atomic/memory_order
 */
template<typename T, size_t Capacity>
class LockFreeRingBuffer {
    static_assert(std::is_trivially_copyable<T>::value,
                  "T must be trivially copyable for lock-free operation");
    static_assert((Capacity & (Capacity - 1)) == 0,
                  "Capacity must be power of 2 for optimal performance");

public:
    //==============================================================================
    /**
     * @brief Construct an empty ring buffer
     */
    LockFreeRingBuffer() noexcept
        : writePos(0), readPos(0) {
    }

    //==============================================================================
    // Write Operations (Producer Thread)

    /**
     * @brief Push an element onto the buffer (non-blocking)
     *
     * @param item Element to push
     * @return true if successful, false if buffer is full
     *
     * @par Thread Safety
     * Safe to call from producer thread only.
     *
     * @par Real-Time Safety
     * Wait-free, no locks, no allocation, bounded execution time.
     */
    bool push(const T& item) noexcept {
        const size_t currentWrite = writePos.load(std::memory_order_relaxed);
        const size_t nextWrite = (currentWrite + 1) & (Capacity - 1);

        // Check if buffer is full
        if (nextWrite == readPos.load(std::memory_order_acquire)) {
            return false;  // Buffer full
        }

        // Write data
        buffer[currentWrite] = item;

        // Publish write (release semantics ensures visibility)
        writePos.store(nextWrite, std::memory_order_release);

        return true;
    }

    /**
     * @brief Try to push, drop oldest if full (non-blocking, never fails)
     *
     * This variant will overwrite the oldest element if the buffer is full,
     * ensuring the push always succeeds. Use this when dropping old data
     * is acceptable (e.g., meter values, visual data).
     *
     * @param item Element to push
     */
    void pushOverwrite(const T& item) noexcept {
        const size_t currentWrite = writePos.load(std::memory_order_relaxed);
        const size_t nextWrite = (currentWrite + 1) & (Capacity - 1);

        // Write data
        buffer[currentWrite] = item;

        // If buffer is full, advance read position (drop oldest)
        if (nextWrite == readPos.load(std::memory_order_acquire)) {
            readPos.store((readPos.load(std::memory_order_relaxed) + 1) & (Capacity - 1),
                         std::memory_order_release);
        }

        // Publish write
        writePos.store(nextWrite, std::memory_order_release);
    }

    //==============================================================================
    // Read Operations (Consumer Thread)

    /**
     * @brief Pop an element from the buffer (non-blocking)
     *
     * @param item Output parameter to receive popped element
     * @return true if successful, false if buffer is empty
     *
     * @par Thread Safety
     * Safe to call from consumer thread only.
     *
     * @par Real-Time Safety
     * Wait-free, no locks, no allocation, bounded execution time.
     */
    bool pop(T& item) noexcept {
        const size_t currentRead = readPos.load(std::memory_order_relaxed);

        // Check if buffer is empty
        if (currentRead == writePos.load(std::memory_order_acquire)) {
            return false;  // Buffer empty
        }

        // Read data
        item = buffer[currentRead];

        // Publish read (release semantics ensures visibility)
        readPos.store((currentRead + 1) & (Capacity - 1), std::memory_order_release);

        return true;
    }

    /**
     * @brief Peek at next element without removing it
     *
     * @param item Output parameter to receive peeked element
     * @return true if successful, false if buffer is empty
     */
    bool peek(T& item) const noexcept {
        const size_t currentRead = readPos.load(std::memory_order_relaxed);

        if (currentRead == writePos.load(std::memory_order_acquire)) {
            return false;  // Buffer empty
        }

        item = buffer[currentRead];
        return true;
    }

    //==============================================================================
    // Query Operations (Safe from any thread)

    /**
     * @brief Check if buffer is empty
     *
     * @return true if buffer has no elements
     *
     * @note This is a snapshot - state may change immediately after call
     */
    bool isEmpty() const noexcept {
        return readPos.load(std::memory_order_acquire) ==
               writePos.load(std::memory_order_acquire);
    }

    /**
     * @brief Check if buffer is full
     *
     * @return true if buffer cannot accept more elements
     *
     * @note This is a snapshot - state may change immediately after call
     */
    bool isFull() const noexcept {
        const size_t nextWrite = (writePos.load(std::memory_order_acquire) + 1) & (Capacity - 1);
        return nextWrite == readPos.load(std::memory_order_acquire);
    }

    /**
     * @brief Get number of elements currently in buffer
     *
     * @return Number of elements (snapshot)
     *
     * @note This is a snapshot - state may change immediately after call
     */
    size_t size() const noexcept {
        const size_t write = writePos.load(std::memory_order_acquire);
        const size_t read = readPos.load(std::memory_order_acquire);

        if (write >= read) {
            return write - read;
        } else {
            return Capacity - (read - write);
        }
    }

    /**
     * @brief Get buffer capacity
     *
     * @return Maximum number of elements buffer can hold
     */
    size_t capacity() const noexcept {
        return Capacity - 1;  // One slot reserved for full/empty distinction
    }

    /**
     * @brief Clear all elements from buffer
     *
     * @warning NOT thread-safe! Only call when no other threads are accessing.
     */
    void reset() noexcept {
        readPos.store(0, std::memory_order_relaxed);
        writePos.store(0, std::memory_order_relaxed);
    }

private:
    //==============================================================================
    // Data members aligned to cache lines to prevent false sharing

    // Cache line size is typically 64 bytes on modern CPUs
    static constexpr size_t CACHE_LINE_SIZE = 64;

    // Write position (modified by producer)
    alignas(CACHE_LINE_SIZE) std::atomic<size_t> writePos;

    // Read position (modified by consumer)
    alignas(CACHE_LINE_SIZE) std::atomic<size_t> readPos;

    // Data buffer (power of 2 size for efficient modulo via bitwise AND)
    std::array<T, Capacity> buffer;

    // Note: We waste one slot to distinguish full from empty
    // (full: nextWrite == read, empty: write == read)
};

//==============================================================================
// Specialized versions for common audio types

/**
 * @brief Audio sample buffer (float)
 */
template<size_t Capacity>
using AudioSampleBuffer = LockFreeRingBuffer<float, Capacity>;

/**
 * @brief MIDI message buffer
 */
struct MIDIMessage {
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
    uint32_t timestamp;
};

template<size_t Capacity>
using MIDIMessageBuffer = LockFreeRingBuffer<MIDIMessage, Capacity>;

/**
 * @brief Parameter change buffer
 */
struct ParameterChange {
    int parameterId;
    float value;
};

template<size_t Capacity>
using ParameterChangeBuffer = LockFreeRingBuffer<ParameterChange, Capacity>;

} // namespace Audio
} // namespace Echoel

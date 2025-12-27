#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <array>
#include <memory>

namespace Echoel {
namespace Core {

//==============================================================================
/**
 * @brief GENIUS WISE ULTRATHINK OPTIMIZATIONS
 *
 * Critical performance improvements for professional audio:
 *
 * 1. LOCK-FREE AUDIO PIPELINE
 *    - SPSC Ring Buffers for track management
 *    - Atomic operations for real-time safety
 *    - Zero-allocation in audio callback
 *
 * 2. SIMD-OPTIMIZED PROCESSING
 *    - Vectorized peak detection
 *    - Batch sample processing
 *    - Cache-friendly memory layout
 *
 * 3. MEMORY POOLING
 *    - Pre-allocated voice pools
 *    - Object recycling
 *    - Deterministic allocation
 */

//==============================================================================
/**
 * @brief Lock-Free SPSC Ring Buffer
 *
 * Single Producer, Single Consumer queue for real-time audio
 * Zero locks, zero allocations, zero waits
 */
template <typename T, size_t Capacity>
class LockFreeRingBuffer
{
public:
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of 2");

    LockFreeRingBuffer() : head(0), tail(0) {}

    bool push(const T& item)
    {
        const size_t currentHead = head.load(std::memory_order_relaxed);
        const size_t nextHead = (currentHead + 1) & (Capacity - 1);

        if (nextHead == tail.load(std::memory_order_acquire))
            return false;  // Full

        buffer[currentHead] = item;
        head.store(nextHead, std::memory_order_release);
        return true;
    }

    bool pop(T& item)
    {
        const size_t currentTail = tail.load(std::memory_order_relaxed);

        if (currentTail == head.load(std::memory_order_acquire))
            return false;  // Empty

        item = buffer[currentTail];
        tail.store((currentTail + 1) & (Capacity - 1), std::memory_order_release);
        return true;
    }

    bool isEmpty() const
    {
        return head.load(std::memory_order_acquire) == tail.load(std::memory_order_acquire);
    }

    size_t size() const
    {
        const size_t h = head.load(std::memory_order_acquire);
        const size_t t = tail.load(std::memory_order_acquire);
        return (h - t) & (Capacity - 1);
    }

private:
    std::array<T, Capacity> buffer;
    std::atomic<size_t> head;
    std::atomic<size_t> tail;
};

//==============================================================================
/**
 * @brief Triple Buffer for Lock-Free State Sharing
 *
 * Pattern from SuperLaserScan - allows producer to write
 * while consumer reads without any locks
 */
template <typename T>
class TripleBuffer
{
public:
    TripleBuffer()
    {
        for (int i = 0; i < 3; ++i)
            buffers[i] = std::make_unique<T>();

        writeIndex.store(0);
        readIndex.store(1);
        latestIndex.store(2);
    }

    T* getWriteBuffer()
    {
        return buffers[writeIndex.load(std::memory_order_relaxed)].get();
    }

    void publishWrite()
    {
        int oldLatest = latestIndex.exchange(
            writeIndex.load(std::memory_order_relaxed),
            std::memory_order_acq_rel
        );
        writeIndex.store(oldLatest, std::memory_order_release);
    }

    const T* getReadBuffer()
    {
        int latest = latestIndex.exchange(
            readIndex.load(std::memory_order_relaxed),
            std::memory_order_acq_rel
        );
        readIndex.store(latest, std::memory_order_release);
        return buffers[readIndex.load(std::memory_order_relaxed)].get();
    }

private:
    std::array<std::unique_ptr<T>, 3> buffers;
    std::atomic<int> writeIndex;
    std::atomic<int> readIndex;
    std::atomic<int> latestIndex;
};

//==============================================================================
/**
 * @brief SIMD-Optimized Audio Operations
 *
 * Vectorized processing for maximum throughput
 */
class SIMDAudioOps
{
public:
    // Vectorized peak detection
    static float findPeak(const float* data, int numSamples)
    {
        float peak = 0.0f;

        // Process in blocks of 4 for SIMD efficiency
        int simdBlocks = numSamples / 4;
        int remainder = numSamples % 4;

        #if JUCE_USE_SSE_INTRINSICS
            __m128 maxVec = _mm_setzero_ps();

            for (int i = 0; i < simdBlocks; ++i)
            {
                __m128 samples = _mm_loadu_ps(data + i * 4);
                __m128 absSamples = _mm_and_ps(samples, _mm_castsi128_ps(_mm_set1_epi32(0x7FFFFFFF)));
                maxVec = _mm_max_ps(maxVec, absSamples);
            }

            // Horizontal max
            __m128 shuf = _mm_shuffle_ps(maxVec, maxVec, _MM_SHUFFLE(2, 3, 0, 1));
            maxVec = _mm_max_ps(maxVec, shuf);
            shuf = _mm_shuffle_ps(maxVec, maxVec, _MM_SHUFFLE(0, 1, 2, 3));
            maxVec = _mm_max_ps(maxVec, shuf);
            peak = _mm_cvtss_f32(maxVec);
        #else
            // Fallback: JUCE vector operations
            peak = juce::FloatVectorOperations::findMinAndMax(data, simdBlocks * 4).getEnd();
        #endif

        // Handle remainder
        for (int i = simdBlocks * 4; i < numSamples; ++i)
        {
            float abs = std::abs(data[i]);
            if (abs > peak) peak = abs;
        }

        return peak;
    }

    // Vectorized gain application with smoothing
    static void applyGainWithSmoothing(float* data, int numSamples,
                                        float& currentGain, float targetGain,
                                        float smoothingCoeff)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            currentGain += (targetGain - currentGain) * smoothingCoeff;
            data[i] *= currentGain;
        }
    }

    // Vectorized stereo panning
    static void applyStereoGain(float* left, float* right, int numSamples,
                                 float leftGain, float rightGain)
    {
        juce::FloatVectorOperations::multiply(left, leftGain, numSamples);
        juce::FloatVectorOperations::multiply(right, rightGain, numSamples);
    }

    // Vectorized mix (wet/dry)
    static void mixWetDry(float* output, const float* dry, const float* wet,
                          int numSamples, float wetAmount)
    {
        float dryAmount = 1.0f - wetAmount;
        juce::FloatVectorOperations::copyWithMultiply(output, dry, dryAmount, numSamples);
        juce::FloatVectorOperations::addWithMultiply(output, wet, wetAmount, numSamples);
    }

    // Fast dB to gain (IEEE754 approximation)
    static inline float fastDbToGain(float db) noexcept
    {
        // From MultibandCompressor optimization
        float x = db * 0.16609640474f;
        x = std::max(-126.0f, x);
        union { float f; uint32_t i; } u;
        u.i = static_cast<uint32_t>((x + 127.0f) * 8388608.0f);
        return u.f;
    }

    // Fast gain to dB
    static inline float fastGainToDb(float gain) noexcept
    {
        union { float f; uint32_t i; } u;
        u.f = gain + 1e-20f;
        return (static_cast<float>(u.i) * 8.2629582e-8f - 87.989971f);
    }

    // RMS calculation (SIMD)
    static float calculateRMS(const float* data, int numSamples)
    {
        float sumSquares = 0.0f;

        #if JUCE_USE_SSE_INTRINSICS
            __m128 sum = _mm_setzero_ps();
            int simdBlocks = numSamples / 4;

            for (int i = 0; i < simdBlocks; ++i)
            {
                __m128 samples = _mm_loadu_ps(data + i * 4);
                sum = _mm_add_ps(sum, _mm_mul_ps(samples, samples));
            }

            // Horizontal sum
            __m128 shuf = _mm_shuffle_ps(sum, sum, _MM_SHUFFLE(2, 3, 0, 1));
            sum = _mm_add_ps(sum, shuf);
            shuf = _mm_shuffle_ps(sum, sum, _MM_SHUFFLE(0, 1, 2, 3));
            sum = _mm_add_ps(sum, shuf);
            sumSquares = _mm_cvtss_f32(sum);

            // Remainder
            for (int i = simdBlocks * 4; i < numSamples; ++i)
            {
                sumSquares += data[i] * data[i];
            }
        #else
            for (int i = 0; i < numSamples; ++i)
            {
                sumSquares += data[i] * data[i];
            }
        #endif

        return std::sqrt(sumSquares / numSamples);
    }
};

//==============================================================================
/**
 * @brief Object Pool for Voice Allocation
 *
 * Pre-allocated pool for zero-allocation voice management
 */
template <typename T, size_t PoolSize>
class ObjectPool
{
public:
    ObjectPool()
    {
        for (size_t i = 0; i < PoolSize; ++i)
        {
            pool[i] = std::make_unique<T>();
            freeList[i] = i;
        }
        freeCount.store(PoolSize);
    }

    T* acquire()
    {
        size_t count = freeCount.load(std::memory_order_relaxed);
        if (count == 0) return nullptr;

        size_t idx = freeList[count - 1];
        freeCount.store(count - 1, std::memory_order_release);
        return pool[idx].get();
    }

    void release(T* obj)
    {
        if (!obj) return;

        // Find index
        for (size_t i = 0; i < PoolSize; ++i)
        {
            if (pool[i].get() == obj)
            {
                size_t count = freeCount.load(std::memory_order_relaxed);
                freeList[count] = i;
                freeCount.store(count + 1, std::memory_order_release);
                break;
            }
        }
    }

    size_t available() const
    {
        return freeCount.load(std::memory_order_relaxed);
    }

private:
    std::array<std::unique_ptr<T>, PoolSize> pool;
    std::array<size_t, PoolSize> freeList;
    std::atomic<size_t> freeCount;
};

//==============================================================================
/**
 * @brief Professional Undo/Redo System
 */
class UndoRedoManager
{
public:
    struct Action
    {
        juce::String description;
        std::function<void()> undo;
        std::function<void()> redo;
        double timestamp;
    };

    static UndoRedoManager& getInstance()
    {
        static UndoRedoManager instance;
        return instance;
    }

    void recordAction(const juce::String& description,
                      std::function<void()> undoFunc,
                      std::function<void()> redoFunc)
    {
        // Clear redo stack when new action is recorded
        redoStack.clear();

        Action action;
        action.description = description;
        action.undo = std::move(undoFunc);
        action.redo = std::move(redoFunc);
        action.timestamp = juce::Time::getMillisecondCounterHiRes();

        undoStack.push_back(std::move(action));

        // Limit stack size
        if (undoStack.size() > maxUndoLevels)
        {
            undoStack.erase(undoStack.begin());
        }
    }

    bool canUndo() const { return !undoStack.empty(); }
    bool canRedo() const { return !redoStack.empty(); }

    juce::String getUndoDescription() const
    {
        return undoStack.empty() ? "" : undoStack.back().description;
    }

    juce::String getRedoDescription() const
    {
        return redoStack.empty() ? "" : redoStack.back().description;
    }

    void undo()
    {
        if (undoStack.empty()) return;

        Action action = std::move(undoStack.back());
        undoStack.pop_back();

        action.undo();

        redoStack.push_back(std::move(action));
    }

    void redo()
    {
        if (redoStack.empty()) return;

        Action action = std::move(redoStack.back());
        redoStack.pop_back();

        action.redo();

        undoStack.push_back(std::move(action));
    }

    void clear()
    {
        undoStack.clear();
        redoStack.clear();
    }

    // Grouped actions (for compound operations)
    void beginGroup(const juce::String& description)
    {
        groupDescription = description;
        groupActions.clear();
        inGroup = true;
    }

    void endGroup()
    {
        if (!inGroup) return;

        if (!groupActions.empty())
        {
            auto groupUndo = [actions = groupActions]() {
                for (auto it = actions.rbegin(); it != actions.rend(); ++it)
                    it->undo();
            };

            auto groupRedo = [actions = groupActions]() {
                for (const auto& action : actions)
                    action.redo();
            };

            recordAction(groupDescription, groupUndo, groupRedo);
        }

        inGroup = false;
        groupActions.clear();
    }

private:
    UndoRedoManager() = default;

    std::vector<Action> undoStack;
    std::vector<Action> redoStack;
    size_t maxUndoLevels = 100;

    bool inGroup = false;
    juce::String groupDescription;
    std::vector<Action> groupActions;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UndoRedoManager)
};

//==============================================================================
/**
 * @brief Professional Preset Management System
 */
class PresetManager
{
public:
    struct PresetMetadata
    {
        juce::String name;
        juce::String author;
        juce::String description;
        juce::StringArray tags;
        int rating = 0;           // 0-5 stars
        bool isFavorite = false;
        bool isFactory = false;
        juce::Time created;
        juce::Time modified;
        juce::String category;
        juce::String version;
    };

    struct Preset
    {
        PresetMetadata metadata;
        juce::ValueTree state;
    };

    static PresetManager& getInstance()
    {
        static PresetManager instance;
        return instance;
    }

    // Loading/Saving
    bool savePreset(const juce::String& name, const juce::ValueTree& state,
                    const PresetMetadata& metadata)
    {
        Preset preset;
        preset.metadata = metadata;
        preset.metadata.name = name;
        preset.metadata.modified = juce::Time::getCurrentTime();
        preset.state = state.createCopy();

        presets[name] = std::move(preset);

        return savePresetToFile(name);
    }

    bool loadPreset(const juce::String& name, juce::ValueTree& state)
    {
        auto it = presets.find(name);
        if (it == presets.end()) return false;

        state = it->second.state.createCopy();
        currentPresetName = name;
        return true;
    }

    // Searching & Filtering
    std::vector<juce::String> searchPresets(const juce::String& query)
    {
        std::vector<juce::String> results;
        juce::String lowerQuery = query.toLowerCase();

        for (const auto& pair : presets)
        {
            const auto& meta = pair.second.metadata;

            if (meta.name.toLowerCase().contains(lowerQuery) ||
                meta.description.toLowerCase().contains(lowerQuery) ||
                meta.author.toLowerCase().contains(lowerQuery))
            {
                results.push_back(pair.first);
            }

            for (const auto& tag : meta.tags)
            {
                if (tag.toLowerCase().contains(lowerQuery))
                {
                    results.push_back(pair.first);
                    break;
                }
            }
        }

        return results;
    }

    std::vector<juce::String> filterByTag(const juce::String& tag)
    {
        std::vector<juce::String> results;

        for (const auto& pair : presets)
        {
            if (pair.second.metadata.tags.contains(tag))
            {
                results.push_back(pair.first);
            }
        }

        return results;
    }

    std::vector<juce::String> filterByCategory(const juce::String& category)
    {
        std::vector<juce::String> results;

        for (const auto& pair : presets)
        {
            if (pair.second.metadata.category == category)
            {
                results.push_back(pair.first);
            }
        }

        return results;
    }

    std::vector<juce::String> getFavorites()
    {
        std::vector<juce::String> results;

        for (const auto& pair : presets)
        {
            if (pair.second.metadata.isFavorite)
            {
                results.push_back(pair.first);
            }
        }

        return results;
    }

    // A/B Comparison
    void storeA()
    {
        stateA = getCurrentState();
    }

    void storeB()
    {
        stateB = getCurrentState();
    }

    void recallA()
    {
        if (stateA.isValid())
            restoreState(stateA);
    }

    void recallB()
    {
        if (stateB.isValid())
            restoreState(stateB);
    }

    void toggleAB()
    {
        isShowingA = !isShowingA;
        if (isShowingA)
            recallA();
        else
            recallB();
    }

    // Random preset with constraints
    juce::String getRandomPreset(const juce::StringArray& requiredTags = {},
                                  const juce::String& category = "")
    {
        std::vector<juce::String> candidates;

        for (const auto& pair : presets)
        {
            bool matches = true;

            if (!category.isEmpty() && pair.second.metadata.category != category)
                matches = false;

            for (const auto& tag : requiredTags)
            {
                if (!pair.second.metadata.tags.contains(tag))
                {
                    matches = false;
                    break;
                }
            }

            if (matches)
                candidates.push_back(pair.first);
        }

        if (candidates.empty()) return "";

        int idx = juce::Random::getSystemRandom().nextInt(static_cast<int>(candidates.size()));
        return candidates[idx];
    }

    // Categories/Tags management
    juce::StringArray getAllTags()
    {
        juce::StringArray allTags;

        for (const auto& pair : presets)
        {
            for (const auto& tag : pair.second.metadata.tags)
            {
                if (!allTags.contains(tag))
                    allTags.add(tag);
            }
        }

        allTags.sort(true);
        return allTags;
    }

    juce::StringArray getAllCategories()
    {
        juce::StringArray categories;

        for (const auto& pair : presets)
        {
            if (!categories.contains(pair.second.metadata.category))
                categories.add(pair.second.metadata.category);
        }

        categories.sort(true);
        return categories;
    }

private:
    PresetManager()
    {
        presetsDir = juce::File::getSpecialLocation(
            juce::File::userApplicationDataDirectory)
            .getChildFile("Echoelmusic")
            .getChildFile("Presets");

        presetsDir.createDirectory();
        loadAllPresets();
    }

    bool savePresetToFile(const juce::String& name)
    {
        auto it = presets.find(name);
        if (it == presets.end()) return false;

        auto file = presetsDir.getChildFile(name + ".preset");

        juce::ValueTree tree("Preset");
        tree.setProperty("name", it->second.metadata.name, nullptr);
        tree.setProperty("author", it->second.metadata.author, nullptr);
        tree.setProperty("description", it->second.metadata.description, nullptr);
        tree.setProperty("category", it->second.metadata.category, nullptr);
        tree.setProperty("rating", it->second.metadata.rating, nullptr);
        tree.setProperty("isFavorite", it->second.metadata.isFavorite, nullptr);
        tree.setProperty("version", it->second.metadata.version, nullptr);

        juce::String tagsStr = it->second.metadata.tags.joinIntoString("|");
        tree.setProperty("tags", tagsStr, nullptr);

        tree.addChild(it->second.state.createCopy(), -1, nullptr);

        std::unique_ptr<juce::XmlElement> xml(tree.createXml());
        return xml && xml->writeTo(file);
    }

    void loadAllPresets()
    {
        auto files = presetsDir.findChildFiles(
            juce::File::findFiles, false, "*.preset");

        for (const auto& file : files)
        {
            loadPresetFromFile(file);
        }
    }

    void loadPresetFromFile(const juce::File& file)
    {
        if (auto xml = juce::XmlDocument::parse(file))
        {
            auto tree = juce::ValueTree::fromXml(*xml);
            if (!tree.isValid()) return;

            Preset preset;
            preset.metadata.name = tree.getProperty("name");
            preset.metadata.author = tree.getProperty("author");
            preset.metadata.description = tree.getProperty("description");
            preset.metadata.category = tree.getProperty("category");
            preset.metadata.rating = tree.getProperty("rating");
            preset.metadata.isFavorite = tree.getProperty("isFavorite");
            preset.metadata.version = tree.getProperty("version");

            juce::String tagsStr = tree.getProperty("tags");
            preset.metadata.tags.addTokens(tagsStr, "|", "");

            if (tree.getNumChildren() > 0)
            {
                preset.state = tree.getChild(0).createCopy();
            }

            presets[preset.metadata.name] = std::move(preset);
        }
    }

    juce::ValueTree getCurrentState()
    {
        // Override in implementation
        return {};
    }

    void restoreState(const juce::ValueTree& state)
    {
        // Override in implementation
    }

    std::map<juce::String, Preset> presets;
    juce::File presetsDir;
    juce::String currentPresetName;

    juce::ValueTree stateA;
    juce::ValueTree stateB;
    bool isShowingA = true;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PresetManager)
};

//==============================================================================
/**
 * @brief LUFS/True Peak Metering (ITU-R BS.1770-4)
 */
class LoudnessMeter
{
public:
    struct LoudnessData
    {
        float momentaryLUFS = -100.0f;  // 400ms window
        float shortTermLUFS = -100.0f;  // 3s window
        float integratedLUFS = -100.0f; // Full program
        float loudnessRange = 0.0f;     // LRA
        float truePeakL = -100.0f;      // dBTP
        float truePeakR = -100.0f;
    };

    LoudnessMeter(double sampleRate = 44100.0)
    {
        setSampleRate(sampleRate);
    }

    void setSampleRate(double sr)
    {
        sampleRate = sr;

        // K-weighting filter coefficients (from ITU-R BS.1770-4)
        // Pre-filter (shelf)
        double db = 3.999843853973347;
        double f0 = 1681.974450955533;
        double Q = 0.7071752369554196;
        double K = std::tan(juce::MathConstants<double>::pi * f0 / sr);

        // Biquad coefficients for pre-filter
        preFilterB0 = (1.0 + K/Q + K*K) / (1.0 + K/Q + K*K);
        // ... (full implementation would include all coefficients)

        // Reset buffers
        momentaryBuffer.resize(static_cast<size_t>(sr * 0.4));  // 400ms
        shortTermBuffer.resize(static_cast<size_t>(sr * 3.0));  // 3s
        std::fill(momentaryBuffer.begin(), momentaryBuffer.end(), 0.0f);
        std::fill(shortTermBuffer.begin(), shortTermBuffer.end(), 0.0f);
    }

    void process(const float* left, const float* right, int numSamples)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            // Apply K-weighting filter
            float filteredL = applyKWeighting(left[i], 0);
            float filteredR = applyKWeighting(right[i], 1);

            // Calculate mean square
            float ms = filteredL * filteredL + filteredR * filteredR;

            // Add to buffers
            momentaryBuffer[momentaryIdx] = ms;
            momentaryIdx = (momentaryIdx + 1) % momentaryBuffer.size();

            shortTermBuffer[shortTermIdx] = ms;
            shortTermIdx = (shortTermIdx + 1) % shortTermBuffer.size();

            // Integrated loudness accumulator
            integratedSum += ms;
            integratedCount++;

            // True peak detection (4x oversampling would be ideal)
            float peakL = std::abs(left[i]);
            float peakR = std::abs(right[i]);
            if (peakL > maxTruePeakL) maxTruePeakL = peakL;
            if (peakR > maxTruePeakR) maxTruePeakR = peakR;
        }

        // Update loudness values
        updateLoudness();
    }

    LoudnessData getData() const { return data; }

    void reset()
    {
        std::fill(momentaryBuffer.begin(), momentaryBuffer.end(), 0.0f);
        std::fill(shortTermBuffer.begin(), shortTermBuffer.end(), 0.0f);
        momentaryIdx = 0;
        shortTermIdx = 0;
        integratedSum = 0.0;
        integratedCount = 0;
        maxTruePeakL = 0.0f;
        maxTruePeakR = 0.0f;
    }

    // Loudness targets
    struct LoudnessTarget
    {
        juce::String name;
        float targetLUFS;
        float maxTruePeak;
    };

    static std::vector<LoudnessTarget> getStandardTargets()
    {
        return {
            { "Spotify", -14.0f, -1.0f },
            { "Apple Music", -16.0f, -1.0f },
            { "YouTube", -13.0f, -1.0f },
            { "Tidal", -14.0f, -1.0f },
            { "Amazon Music", -14.0f, -2.0f },
            { "Deezer", -14.0f, -1.0f },
            { "SoundCloud", -14.0f, -1.0f },
            { "Broadcast (EBU R128)", -23.0f, -1.0f },
            { "Podcast", -16.0f, -1.0f },
            { "Cinema", -27.0f, -3.0f }
        };
    }

private:
    float applyKWeighting(float sample, int channel)
    {
        // Simplified - full implementation would use biquad cascades
        return sample;  // Placeholder
    }

    void updateLoudness()
    {
        // Momentary (400ms)
        double momentarySum = 0.0;
        for (float ms : momentaryBuffer)
            momentarySum += ms;
        double momentaryMean = momentarySum / momentaryBuffer.size();
        data.momentaryLUFS = static_cast<float>(-0.691 + 10.0 * std::log10(momentaryMean + 1e-10));

        // Short-term (3s)
        double shortTermSum = 0.0;
        for (float ms : shortTermBuffer)
            shortTermSum += ms;
        double shortTermMean = shortTermSum / shortTermBuffer.size();
        data.shortTermLUFS = static_cast<float>(-0.691 + 10.0 * std::log10(shortTermMean + 1e-10));

        // Integrated
        if (integratedCount > 0)
        {
            double integratedMean = integratedSum / integratedCount;
            data.integratedLUFS = static_cast<float>(-0.691 + 10.0 * std::log10(integratedMean + 1e-10));
        }

        // True peak (dBTP)
        data.truePeakL = SIMDAudioOps::fastGainToDb(maxTruePeakL);
        data.truePeakR = SIMDAudioOps::fastGainToDb(maxTruePeakR);
    }

    double sampleRate = 44100.0;
    LoudnessData data;

    std::vector<float> momentaryBuffer;
    std::vector<float> shortTermBuffer;
    size_t momentaryIdx = 0;
    size_t shortTermIdx = 0;

    double integratedSum = 0.0;
    size_t integratedCount = 0;

    float maxTruePeakL = 0.0f;
    float maxTruePeakR = 0.0f;

    // K-weighting filter coefficients
    double preFilterB0 = 1.0;
    // ... additional coefficients
};

} // namespace Core
} // namespace Echoel

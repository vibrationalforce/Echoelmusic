#pragma once

#include <JuceHeader.h>
#include <memory>
#include <vector>
#include <map>
#include <functional>

// Forward declarations for ONNX Runtime (avoid header dependency in public API)
namespace Ort {
    class Env;
    class Session;
    class SessionOptions;
    class Value;
    struct MemoryInfo;
}

/**
 * MLEngine - Machine Learning Inference Engine
 *
 * Manages neural network models and provides real-time inference
 * with automatic GPU/CPU fallback.
 *
 * Features:
 * - ONNX Runtime integration
 * - GPU acceleration (CUDA, Metal, OpenCL)
 * - Async inference with thread pool
 * - Performance monitoring
 * - Real-time safety (no allocations in audio thread)
 */
class MLEngine
{
public:
    //==========================================================================
    // Hardware Acceleration
    //==========================================================================

    enum class AccelerationType
    {
        CPU,            // CPU-only (slowest, most compatible)
        CUDA,           // NVIDIA GPU
        Metal,          // Apple GPU
        OpenCL,         // Generic GPU
        Auto            // Automatic selection
    };

    //==========================================================================
    // Model Management
    //==========================================================================

    struct ModelInfo
    {
        std::string name;
        std::string path;
        std::vector<int64_t> inputShape;
        std::vector<int64_t> outputShape;
        size_t modelSize = 0;           // Bytes
        bool isLoaded = false;
    };

    //==========================================================================
    // Performance Monitoring
    //==========================================================================

    struct PerformanceMetrics
    {
        float averageLatency = 0.0f;    // ms
        float peakLatency = 0.0f;       // ms
        int totalInferences = 0;
        bool isRealtime = true;         // < 20ms threshold
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    MLEngine();
    ~MLEngine();

    //==========================================================================
    // Initialization
    //==========================================================================

    /** Initialize with acceleration type */
    bool initialize(AccelerationType type = AccelerationType::Auto);

    /** Check if already initialized */
    bool isInitialized() const { return initialized; }

    /** Check if GPU is available */
    static bool isGPUAvailable();

    /** Get available acceleration type */
    static AccelerationType getAvailableAcceleration();

    /** Get current acceleration type */
    AccelerationType getCurrentAcceleration() const { return currentAcceleration; }

    //==========================================================================
    // Model Loading
    //==========================================================================

    /** Load ONNX model from file */
    bool loadModel(const juce::File& modelFile, const std::string& modelName);

    /** Load ONNX model from memory */
    bool loadModelFromMemory(const void* modelData, size_t modelSize, const std::string& modelName);

    /** Unload model */
    void unloadModel(const std::string& modelName);

    /** Check if model is loaded */
    bool isModelLoaded(const std::string& modelName) const;

    /** Get loaded model info */
    ModelInfo getModelInfo(const std::string& modelName) const;

    /** Get all loaded models */
    std::vector<std::string> getLoadedModelNames() const;

    //==========================================================================
    // Inference (Synchronous)
    //==========================================================================

    /** Run inference (blocking) */
    std::vector<float> runInference(
        const std::string& modelName,
        const std::vector<float>& inputData);

    /** Run inference with pre-allocated output buffer (real-time safe) */
    bool runInferenceInPlace(
        const std::string& modelName,
        const float* inputData,
        size_t inputSize,
        float* outputData,
        size_t outputSize);

    //==========================================================================
    // Inference (Asynchronous)
    //==========================================================================

    /** Run inference async (non-blocking, returns immediately) */
    void runInferenceAsync(
        const std::string& modelName,
        const std::vector<float>& inputData,
        std::function<void(const std::vector<float>&)> callback);

    //==========================================================================
    // Performance
    //==========================================================================

    /** Measure inference latency */
    float measureLatency(const std::string& modelName);

    /** Get performance metrics */
    PerformanceMetrics getPerformanceMetrics(const std::string& modelName) const;

    /** Reset performance metrics */
    void resetPerformanceMetrics(const std::string& modelName);

private:
    //==========================================================================
    // Internal Implementation
    //==========================================================================

    struct Impl;
    std::unique_ptr<Impl> impl;

    bool initialized = false;
    AccelerationType currentAcceleration = AccelerationType::CPU;

    //==========================================================================
    // Thread Pool for Async Inference
    //==========================================================================

    juce::ThreadPool inferenceThreadPool {4};  // 4 worker threads

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MLEngine)
};

/*
  ==============================================================================

    MLEngine.cpp

    Machine Learning Inference Engine for Echoelmusic

    Provides real-time neural network inference with automatic GPU/CPU fallback.
    Supports ONNX Runtime with CUDA, Metal, OpenCL acceleration.

  ==============================================================================
*/

#include "MLEngine.h"

//==============================================================================
// Constructor / Destructor
//==============================================================================

MLEngine::MLEngine()
{
    // ONNX Runtime environment will be initialized in initialize()
}

MLEngine::~MLEngine()
{
    // Clean up all loaded models
    loadedModels.clear();

    // ONNX Runtime cleanup handled by unique_ptr
}

//==============================================================================
// Initialization
//==============================================================================

bool MLEngine::initialize(AccelerationType type)
{
    try
    {
        // Create ONNX Runtime environment
        ortEnv = std::make_unique<Ort::Env>(ORT_LOGGING_LEVEL_WARNING, "EchoelMusicML");

        // Create session options
        sessionOptions = std::make_unique<Ort::SessionOptions>();

        // Set graph optimization level
        sessionOptions->SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);

        // Set intra-op parallelism (use 4 threads for CPU inference)
        sessionOptions->SetIntraOpNumThreads(4);

        // Set inter-op parallelism
        sessionOptions->SetInterOpNumThreads(2);

        // Configure acceleration based on type
        if (type == AccelerationType::Auto)
        {
            type = getAvailableAcceleration();
        }

        currentAcceleration = type;

        switch (type)
        {
            case AccelerationType::CUDA:
            {
                #ifdef ECHOELMUSIC_HAS_CUDA
                // Enable CUDA execution provider
                OrtCUDAProviderOptions cuda_options;
                cuda_options.device_id = 0;  // Use first GPU
                cuda_options.arena_extend_strategy = 0;
                cuda_options.gpu_mem_limit = SIZE_MAX;
                cuda_options.cudnn_conv_algo_search = OrtCudnnConvAlgoSearchExhaustive;
                cuda_options.do_copy_in_default_stream = 1;

                sessionOptions->AppendExecutionProvider_CUDA(cuda_options);

                DBG("MLEngine: Initialized with CUDA acceleration");
                #else
                DBG("MLEngine: CUDA not available, falling back to CPU");
                currentAcceleration = AccelerationType::CPU;
                #endif
                break;
            }

            case AccelerationType::Metal:
            {
                #ifdef ECHOELMUSIC_HAS_METAL
                // Enable CoreML execution provider (uses Metal on Apple Silicon)
                sessionOptions->AppendExecutionProvider_CoreML(0);

                DBG("MLEngine: Initialized with Metal acceleration");
                #else
                DBG("MLEngine: Metal not available, falling back to CPU");
                currentAcceleration = AccelerationType::CPU;
                #endif
                break;
            }

            case AccelerationType::OpenCL:
            {
                #ifdef ECHOELMUSIC_HAS_OPENCL
                // Enable OpenCL execution provider
                // Note: OpenCL support may require building ONNX Runtime from source
                DBG("MLEngine: OpenCL support requires custom ONNX build");
                currentAcceleration = AccelerationType::CPU;
                #else
                DBG("MLEngine: OpenCL not available, falling back to CPU");
                currentAcceleration = AccelerationType::CPU;
                #endif
                break;
            }

            case AccelerationType::CPU:
            default:
            {
                // CPU-only execution (default)
                DBG("MLEngine: Initialized with CPU-only execution");
                break;
            }
        }

        return true;
    }
    catch (const Ort::Exception& e)
    {
        DBG("MLEngine initialization failed: " + juce::String(e.what()));
        return false;
    }
}

bool MLEngine::isGPUAvailable()
{
    #if defined(ECHOELMUSIC_HAS_CUDA) || defined(ECHOELMUSIC_HAS_METAL)
    return true;
    #else
    return false;
    #endif
}

MLEngine::AccelerationType MLEngine::getAvailableAcceleration()
{
    #ifdef ECHOELMUSIC_HAS_CUDA
    return AccelerationType::CUDA;
    #elif defined(ECHOELMUSIC_HAS_METAL)
    return AccelerationType::Metal;
    #elif defined(ECHOELMUSIC_HAS_OPENCL)
    return AccelerationType::OpenCL;
    #else
    return AccelerationType::CPU;
    #endif
}

//==============================================================================
// Model Loading
//==============================================================================

bool MLEngine::loadModel(const juce::File& modelFile, const std::string& modelName)
{
    if (!ortEnv || !sessionOptions)
    {
        DBG("MLEngine not initialized. Call initialize() first.");
        return false;
    }

    if (!modelFile.existsAsFile())
    {
        DBG("Model file not found: " + modelFile.getFullPathName());
        return false;
    }

    try
    {
        ModelSession modelSession;

        // Create ONNX session from file
        #ifdef _WIN32
        // Windows requires wide string path
        auto widePath = modelFile.getFullPathName().toWideCharPointer();
        modelSession.session = std::make_unique<Ort::Session>(*ortEnv, widePath, *sessionOptions);
        #else
        // Unix-like systems use UTF-8 path
        auto path = modelFile.getFullPathName().toStdString();
        modelSession.session = std::make_unique<Ort::Session>(*ortEnv, path.c_str(), *sessionOptions);
        #endif

        // Get model metadata
        Ort::AllocatorWithDefaultOptions allocator;

        // Get input info
        size_t numInputs = modelSession.session->GetInputCount();
        if (numInputs > 0)
        {
            auto inputTypeInfo = modelSession.session->GetInputTypeInfo(0);
            auto tensorInfo = inputTypeInfo.GetTensorTypeAndShapeInfo();
            modelSession.info.inputShape = tensorInfo.GetShape();
        }

        // Get output info
        size_t numOutputs = modelSession.session->GetOutputCount();
        if (numOutputs > 0)
        {
            auto outputTypeInfo = modelSession.session->GetOutputTypeInfo(0);
            auto tensorInfo = outputTypeInfo.GetTensorTypeAndShapeInfo();
            modelSession.info.outputShape = tensorInfo.GetShape();
        }

        // Set model info
        modelSession.info.name = modelName;
        modelSession.info.path = modelFile.getFullPathName().toStdString();
        modelSession.info.modelSize = modelFile.getSize();
        modelSession.info.isLoaded = true;

        // Store model
        loadedModels[modelName] = std::move(modelSession);

        DBG("MLEngine: Loaded model '" + juce::String(modelName) + "' (" +
            juce::String(modelFile.getSize() / 1024) + " KB)");

        return true;
    }
    catch (const Ort::Exception& e)
    {
        DBG("Failed to load model: " + juce::String(e.what()));
        return false;
    }
}

void MLEngine::unloadModel(const std::string& modelName)
{
    auto it = loadedModels.find(modelName);
    if (it != loadedModels.end())
    {
        loadedModels.erase(it);
        DBG("MLEngine: Unloaded model '" + juce::String(modelName) + "'");
    }
}

MLEngine::ModelInfo MLEngine::getModelInfo(const std::string& modelName) const
{
    auto it = loadedModels.find(modelName);
    if (it != loadedModels.end())
    {
        return it->second.info;
    }

    return ModelInfo();  // Return empty info if not found
}

//==============================================================================
// Inference
//==============================================================================

std::vector<float> MLEngine::runInference(
    const std::string& modelName,
    const std::vector<float>& inputData)
{
    auto it = loadedModels.find(modelName);
    if (it == loadedModels.end())
    {
        DBG("Model not found: " + juce::String(modelName));
        return {};
    }

    auto& modelSession = it->second;

    try
    {
        // Start timing
        auto startTime = juce::Time::getMillisecondCounterHiRes();

        // Create allocator
        Ort::AllocatorWithDefaultOptions allocator;

        // Get input/output names
        auto inputName = modelSession.session->GetInputNameAllocated(0, allocator);
        auto outputName = modelSession.session->GetOutputNameAllocated(0, allocator);

        const char* inputNames[] = {inputName.get()};
        const char* outputNames[] = {outputName.get()};

        // Create input tensor
        Ort::MemoryInfo memoryInfo = Ort::MemoryInfo::CreateCpu(
            OrtAllocatorType::OrtArenaAllocator, OrtMemType::OrtMemTypeDefault);

        std::vector<int64_t> inputShape = modelSession.info.inputShape;

        // If first dimension is -1 (dynamic batch), set it to 1
        if (inputShape[0] == -1)
            inputShape[0] = 1;

        auto inputTensor = Ort::Value::CreateTensor<float>(
            memoryInfo,
            const_cast<float*>(inputData.data()),
            inputData.size(),
            inputShape.data(),
            inputShape.size());

        // Run inference
        auto outputTensors = modelSession.session->Run(
            Ort::RunOptions{nullptr},
            inputNames,
            &inputTensor,
            1,
            outputNames,
            1);

        // Get output data
        float* outputData = outputTensors[0].GetTensorMutableData<float>();
        auto outputShape = outputTensors[0].GetTensorTypeAndShapeInfo().GetShape();

        size_t outputSize = 1;
        for (auto dim : outputShape)
            outputSize *= dim;

        std::vector<float> output(outputData, outputData + outputSize);

        // End timing and update metrics
        auto endTime = juce::Time::getMillisecondCounterHiRes();
        float latency = static_cast<float>(endTime - startTime);

        modelSession.metrics.totalInferences++;
        modelSession.metrics.averageLatency =
            (modelSession.metrics.averageLatency * (modelSession.metrics.totalInferences - 1) + latency)
            / modelSession.metrics.totalInferences;
        modelSession.metrics.peakLatency = std::max(modelSession.metrics.peakLatency, latency);
        modelSession.metrics.isRealtime = (modelSession.metrics.averageLatency < 20.0f);

        return output;
    }
    catch (const Ort::Exception& e)
    {
        DBG("Inference failed: " + juce::String(e.what()));
        return {};
    }
}

void MLEngine::runInferenceAsync(
    const std::string& modelName,
    const std::vector<float>& inputData,
    std::function<void(const std::vector<float>&)> callback)
{
    // Run inference on thread pool (non-blocking)
    inferenceThreadPool.addJob([this, modelName, inputData, callback]()
    {
        auto output = runInference(modelName, inputData);

        // Call callback on message thread
        juce::MessageManager::callAsync([callback, output]()
        {
            callback(output);
        });
    });
}

float MLEngine::measureLatency(const std::string& modelName)
{
    auto it = loadedModels.find(modelName);
    if (it == loadedModels.end())
    {
        DBG("Model not found: " + juce::String(modelName));
        return -1.0f;
    }

    auto& modelSession = it->second;

    // Create dummy input with correct shape
    std::vector<int64_t> inputShape = modelSession.info.inputShape;

    size_t inputSize = 1;
    for (auto dim : inputShape)
    {
        if (dim > 0)
            inputSize *= dim;
    }

    std::vector<float> dummyInput(inputSize, 0.0f);

    // Run inference multiple times and average
    constexpr int numIterations = 10;
    float totalLatency = 0.0f;

    for (int i = 0; i < numIterations; ++i)
    {
        auto startTime = juce::Time::getMillisecondCounterHiRes();
        runInference(modelName, dummyInput);
        auto endTime = juce::Time::getMillisecondCounterHiRes();

        totalLatency += static_cast<float>(endTime - startTime);
    }

    float averageLatency = totalLatency / numIterations;

    DBG("MLEngine: Average latency for '" + juce::String(modelName) + "': " +
        juce::String(averageLatency, 2) + " ms");

    return averageLatency;
}

//==============================================================================
// Performance Monitoring
//==============================================================================

MLEngine::PerformanceMetrics MLEngine::getPerformanceMetrics(const std::string& modelName) const
{
    auto it = loadedModels.find(modelName);
    if (it != loadedModels.end())
    {
        return it->second.metrics;
    }

    return PerformanceMetrics();
}

#pragma once

#include <JuceHeader.h>
#include "PhotonicProcessor.h"
#include <vector>
#include <memory>
#include <random>
#include <cmath>

/**
 * PhotonicNeuralNetwork - Neural Networks for Photonic Hardware
 *
 * Neural network layers optimized for Q.ANT NPU 2:
 * - Dense layers via MZI (Mach-Zehnder Interferometer) mesh
 * - Native FP16 precision (perfect for inference)
 * - Nonlinear activations 1.5× FASTER than linear ops!
 * - 40% fewer parameters needed (optical efficiency)
 * - 50% fewer operations (native spectral transforms)
 *
 * Key insight from Q.ANT benchmarks:
 * - CIFAR-10: ~100k params vs ~300k digital baseline
 * - Operations: ~200k vs ~1M digital baseline
 * - Same accuracy with much less compute!
 *
 * Architecture innovations:
 * - Kolmogorov-Arnold Networks (KAN) native support
 * - Fourier Neural Operators (spectral layers)
 * - Heavy use of nonlinear layers (they're fast!)
 * - Designed for "too elegant to run on GPU" models
 *
 * Audio AI applications:
 * - Neural audio synthesis
 * - Stem separation inference
 * - Voice cloning
 * - Intelligent mixing
 * - Style transfer
 *
 * 2026 Photonic-Ready Architecture
 */

namespace Echoelmusic {
namespace Photonic {

//==============================================================================
// Photonic Layer Base
//==============================================================================

class PhotonicLayer
{
public:
    virtual ~PhotonicLayer() = default;
    virtual PhotonicTensor forward(const PhotonicTensor& input) = 0;
    virtual int getInputSize() const = 0;
    virtual int getOutputSize() const = 0;
    virtual std::string getName() const = 0;

    // Photonic layers report their computational profile
    struct ComputeProfile
    {
        int linearOps = 0;      // Matrix multiply, convolutions
        int nonlinearOps = 0;   // Activations (FAST on photonic!)
        int memoryOps = 0;      // Data movement
        float estimatedLatencyUs = 0.0f;
    };

    virtual ComputeProfile getProfile() const { return {}; }
};

//==============================================================================
// Photonic Dense Layer (MZI Mesh)
//==============================================================================

class PhotonicDenseLayer : public PhotonicLayer
{
public:
    PhotonicDenseLayer(int inputSize, int outputSize, bool useBias = true)
        : inSize(inputSize), outSize(outputSize), hasBias(useBias)
    {
        // Initialize weights (would be programmed into MZI mesh)
        weights.resize(inSize * outSize);
        bias.resize(outSize, 0.0f);

        // Xavier initialization
        std::random_device rd;
        std::mt19937 gen(rd());
        float scale = std::sqrt(2.0f / (inSize + outSize));
        std::normal_distribution<float> dist(0.0f, scale);

        for (float& w : weights)
            w = dist(gen);
    }

    PhotonicTensor forward(const PhotonicTensor& input) override
    {
        // Matrix multiplication via MZI mesh
        // On photonic hardware: light encodes input, interferes through mesh

        PhotonicTensor weightTensor({inSize, outSize});
        std::copy(weights.begin(), weights.end(), weightTensor.getData());

        PhotonicTensor output;

        if (PhotonicNPU.available())
        {
            output = PhotonicOps::matmul(input, weightTensor);
        }
        else
        {
            // CPU fallback
            output = PhotonicTensor({outSize});
            float* out = output.getData();
            const float* in = input.getData();

            for (int o = 0; o < outSize; ++o)
            {
                float sum = hasBias ? bias[o] : 0.0f;
                for (int i = 0; i < inSize; ++i)
                    sum += in[i] * weights[i * outSize + o];
                out[o] = sum;
            }
        }

        // Add bias
        if (hasBias)
        {
            float* out = output.getData();
            for (int i = 0; i < outSize; ++i)
                out[i] += bias[i];
        }

        return output;
    }

    int getInputSize() const override { return inSize; }
    int getOutputSize() const override { return outSize; }
    std::string getName() const override { return "Dense"; }

    ComputeProfile getProfile() const override
    {
        return {inSize * outSize, 0, inSize + outSize, 0.1f};
    }

    // Weight access for loading pre-trained models
    void setWeights(const std::vector<float>& w) { weights = w; }
    void setBias(const std::vector<float>& b) { bias = b; }

private:
    int inSize, outSize;
    bool hasBias;
    std::vector<float> weights;
    std::vector<float> bias;
};

//==============================================================================
// Photonic Activation Layers (1.5× FASTER than linear!)
//==============================================================================

class PhotonicActivation : public PhotonicLayer
{
public:
    enum class Type
    {
        ReLU,
        GELU,
        Sigmoid,
        Tanh,
        Swish,
        Mish
    };

    PhotonicActivation(Type t, int size) : type(t), layerSize(size) {}

    PhotonicTensor forward(const PhotonicTensor& input) override
    {
        // KEY INSIGHT: On Q.ANT NPU 2, nonlinear activations
        // are 1.5× FASTER than linear operations!
        // This flips neural network design - we can use
        // MORE nonlinear layers without penalty!

        if (PhotonicNPU.available())
        {
            switch (type)
            {
                case Type::ReLU:
                    return PhotonicOps::relu(input);
                case Type::GELU:
                    return PhotonicOps::gelu(input);
                case Type::Sigmoid:
                    return PhotonicOps::sigmoid(input);
                case Type::Tanh:
                    return PhotonicOps::tanh(input);
                case Type::Swish:
                    return swish(input);
                case Type::Mish:
                    return mish(input);
            }
        }

        // CPU fallback
        return cpuActivation(input);
    }

    int getInputSize() const override { return layerSize; }
    int getOutputSize() const override { return layerSize; }
    std::string getName() const override { return "Activation"; }

    ComputeProfile getProfile() const override
    {
        // Nonlinear ops are fast on photonic!
        return {0, layerSize, 0, 0.05f};  // Faster than linear!
    }

private:
    Type type;
    int layerSize;

    PhotonicTensor swish(const PhotonicTensor& input)
    {
        // Swish = x * sigmoid(x)
        auto sig = PhotonicOps::sigmoid(input);
        PhotonicTensor output(input.getShape());

        const float* in = input.getData();
        const float* s = sig.getData();
        float* out = output.getData();

        for (int i = 0; i < input.getSize(); ++i)
            out[i] = in[i] * s[i];

        return output;
    }

    PhotonicTensor mish(const PhotonicTensor& input)
    {
        // Mish = x * tanh(softplus(x))
        PhotonicTensor output(input.getShape());

        const float* in = input.getData();
        float* out = output.getData();

        for (int i = 0; i < input.getSize(); ++i)
        {
            float softplus = std::log(1.0f + std::exp(in[i]));
            out[i] = in[i] * std::tanh(softplus);
        }

        return output;
    }

    PhotonicTensor cpuActivation(const PhotonicTensor& input)
    {
        PhotonicTensor output(input.getShape());
        const float* in = input.getData();
        float* out = output.getData();

        for (int i = 0; i < input.getSize(); ++i)
        {
            switch (type)
            {
                case Type::ReLU:
                    out[i] = in[i] > 0 ? in[i] : 0;
                    break;
                case Type::GELU:
                    out[i] = 0.5f * in[i] * (1.0f + std::tanh(0.7978845608f *
                             (in[i] + 0.044715f * in[i] * in[i] * in[i])));
                    break;
                case Type::Sigmoid:
                    out[i] = 1.0f / (1.0f + std::exp(-in[i]));
                    break;
                case Type::Tanh:
                    out[i] = std::tanh(in[i]);
                    break;
                default:
                    out[i] = in[i];
            }
        }

        return output;
    }
};

//==============================================================================
// Photonic Spectral Layer (Native FFT)
//==============================================================================

class PhotonicSpectralLayer : public PhotonicLayer
{
public:
    PhotonicSpectralLayer(int size) : layerSize(size)
    {
        // Learnable spectral weights
        spectralWeights.resize(size, 1.0f);
    }

    PhotonicTensor forward(const PhotonicTensor& input) override
    {
        // Native photonic FFT - O(1) operation!
        // The math is physically encoded in the waveguide

        PhotonicTensor spectrum;

        if (PhotonicNPU.available())
        {
            spectrum = PhotonicOps::fft(input);
        }
        else
        {
            // CPU FFT fallback
            spectrum = input;  // Simplified
        }

        // Apply learnable spectral weights
        float* spec = spectrum.getData();
        for (int i = 0; i < layerSize; ++i)
            spec[i] *= spectralWeights[i];

        // IFFT back to time domain
        PhotonicTensor output;

        if (PhotonicNPU.available())
        {
            output = PhotonicOps::ifft(spectrum);
        }
        else
        {
            output = spectrum;
        }

        return output;
    }

    int getInputSize() const override { return layerSize; }
    int getOutputSize() const override { return layerSize; }
    std::string getName() const override { return "Spectral"; }

    ComputeProfile getProfile() const override
    {
        // FFT is O(1) on photonic hardware!
        return {0, 0, layerSize, 0.02f};  // Incredibly fast
    }

    void setSpectralWeights(const std::vector<float>& w)
    {
        spectralWeights = w;
    }

private:
    int layerSize;
    std::vector<float> spectralWeights;
};

//==============================================================================
// Kolmogorov-Arnold Network Layer (Native Photonic Support)
//==============================================================================

class PhotonicKANLayer : public PhotonicLayer
{
public:
    /**
     * Kolmogorov-Arnold Networks (KAN)
     *
     * Q.ANT showed these work especially well on photonic hardware.
     * KANs use learnable activation functions on edges rather than
     * fixed activations on nodes.
     *
     * On photonic hardware:
     * - Each B-spline is a programmable optical nonlinearity
     * - Nonlinear ops are 1.5× faster than linear
     * - Perfect match for KAN architecture!
     */

    PhotonicKANLayer(int inputSize, int outputSize, int gridSize = 5)
        : inSize(inputSize), outSize(outputSize), grid(gridSize)
    {
        // B-spline coefficients for each edge
        int numEdges = inSize * outSize;
        splineCoeffs.resize(numEdges * grid, 0.1f);

        // Initialize with small random values
        std::random_device rd;
        std::mt19937 gen(rd());
        std::normal_distribution<float> dist(0.0f, 0.1f);

        for (float& c : splineCoeffs)
            c = dist(gen);
    }

    PhotonicTensor forward(const PhotonicTensor& input) override
    {
        PhotonicTensor output({outSize});
        const float* in = input.getData();
        float* out = output.getData();

        std::fill(out, out + outSize, 0.0f);

        for (int i = 0; i < inSize; ++i)
        {
            float x = in[i];

            for (int o = 0; o < outSize; ++o)
            {
                // Evaluate B-spline for this edge
                // On photonic hardware: programmable optical nonlinearity
                int edgeIdx = i * outSize + o;
                float splineVal = evaluateBSpline(x, edgeIdx);

                out[o] += splineVal;
            }
        }

        return output;
    }

    int getInputSize() const override { return inSize; }
    int getOutputSize() const override { return outSize; }
    std::string getName() const override { return "KAN"; }

    ComputeProfile getProfile() const override
    {
        // KAN is mostly nonlinear ops - perfect for photonic!
        return {inSize * outSize, inSize * outSize * grid, inSize + outSize, 0.08f};
    }

private:
    int inSize, outSize, grid;
    std::vector<float> splineCoeffs;

    float evaluateBSpline(float x, int edgeIdx)
    {
        // Simplified B-spline evaluation
        // On photonic: implemented via programmable nonlinearity

        // Map x to grid position
        float gridPos = (x + 1.0f) * 0.5f * grid;
        int gridIdx = static_cast<int>(gridPos);
        float t = gridPos - gridIdx;

        gridIdx = std::clamp(gridIdx, 0, grid - 1);

        // Linear interpolation between spline coefficients
        int baseIdx = edgeIdx * grid + gridIdx;
        float c0 = splineCoeffs[baseIdx];
        float c1 = (gridIdx < grid - 1) ? splineCoeffs[baseIdx + 1] : c0;

        return c0 * (1.0f - t) + c1 * t;
    }
};

//==============================================================================
// Photonic Neural Network Model
//==============================================================================

class PhotonicNeuralNetwork
{
public:
    PhotonicNeuralNetwork(const std::string& name = "PhotonicNN")
        : modelName(name) {}

    void addLayer(std::shared_ptr<PhotonicLayer> layer)
    {
        layers.push_back(layer);
    }

    // Convenience methods for building networks
    void addDense(int outputSize)
    {
        int inputSize = layers.empty() ? 0 :
                        layers.back()->getOutputSize();
        layers.push_back(std::make_shared<PhotonicDenseLayer>(inputSize, outputSize));
    }

    void addActivation(PhotonicActivation::Type type)
    {
        int size = layers.empty() ? 0 : layers.back()->getOutputSize();
        layers.push_back(std::make_shared<PhotonicActivation>(type, size));
    }

    void addSpectral()
    {
        int size = layers.empty() ? 0 : layers.back()->getOutputSize();
        layers.push_back(std::make_shared<PhotonicSpectralLayer>(size));
    }

    void addKAN(int outputSize, int gridSize = 5)
    {
        int inputSize = layers.empty() ? 0 : layers.back()->getOutputSize();
        layers.push_back(std::make_shared<PhotonicKANLayer>(inputSize, outputSize, gridSize));
    }

    PhotonicTensor forward(const PhotonicTensor& input)
    {
        PhotonicTensor current = input;

        for (auto& layer : layers)
        {
            current = layer->forward(current);
        }

        return current;
    }

    // Inference for audio
    juce::AudioBuffer<float> processAudio(const juce::AudioBuffer<float>& input)
    {
        auto tensor = PhotonicTensor::fromAudio(input);
        auto output = forward(tensor);
        return output.toAudio();
    }

    // Model info
    struct ModelInfo
    {
        std::string name;
        int numLayers;
        int totalParams;
        int linearOps;
        int nonlinearOps;
        float estimatedLatencyUs;
        float photonicSpeedup;  // vs GPU
    };

    ModelInfo getInfo() const
    {
        ModelInfo info;
        info.name = modelName;
        info.numLayers = static_cast<int>(layers.size());
        info.totalParams = 0;
        info.linearOps = 0;
        info.nonlinearOps = 0;
        info.estimatedLatencyUs = 0;

        for (const auto& layer : layers)
        {
            auto profile = layer->getProfile();
            info.linearOps += profile.linearOps;
            info.nonlinearOps += profile.nonlinearOps;
            info.estimatedLatencyUs += profile.estimatedLatencyUs;
        }

        // Photonic speedup: nonlinear is 1.5× faster, plus FFT is O(1)
        float gpuLatency = info.linearOps * 0.001f + info.nonlinearOps * 0.002f;
        float photonicLatency = info.linearOps * 0.001f + info.nonlinearOps * 0.00067f;

        info.photonicSpeedup = gpuLatency / (photonicLatency + 0.001f);

        return info;
    }

private:
    std::string modelName;
    std::vector<std::shared_ptr<PhotonicLayer>> layers;
};

//==============================================================================
// Pre-built Audio AI Models
//==============================================================================

namespace Models {

// Stem Separator (optimized for photonic)
inline PhotonicNeuralNetwork createStemSeparator()
{
    PhotonicNeuralNetwork model("PhotonicStemSeparator");

    // Input: spectrogram (1024 frequency bins)
    model.addLayer(std::make_shared<PhotonicSpectralLayer>(1024));

    // Encoder
    model.addLayer(std::make_shared<PhotonicDenseLayer>(1024, 512));
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::GELU, 512));

    model.addLayer(std::make_shared<PhotonicDenseLayer>(512, 256));
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::GELU, 256));

    // Bottleneck with KAN (leverage fast nonlinear)
    model.addLayer(std::make_shared<PhotonicKANLayer>(256, 128, 8));
    model.addLayer(std::make_shared<PhotonicKANLayer>(128, 256, 8));

    // Decoder
    model.addLayer(std::make_shared<PhotonicDenseLayer>(256, 512));
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::GELU, 512));

    model.addLayer(std::make_shared<PhotonicDenseLayer>(512, 1024));
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::Sigmoid, 1024));  // Mask output

    return model;
}

// Neural Audio Synthesizer
inline PhotonicNeuralNetwork createNeuralSynth()
{
    PhotonicNeuralNetwork model("PhotonicNeuralSynth");

    // Input: latent vector (256)
    model.addLayer(std::make_shared<PhotonicDenseLayer>(256, 512));
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::Swish, 512));

    // Heavy use of nonlinear layers (fast on photonic!)
    model.addLayer(std::make_shared<PhotonicKANLayer>(512, 512, 12));
    model.addLayer(std::make_shared<PhotonicKANLayer>(512, 512, 12));

    // Spectral shaping
    model.addLayer(std::make_shared<PhotonicSpectralLayer>(512));

    // Output: audio samples
    model.addLayer(std::make_shared<PhotonicDenseLayer>(512, 1024));
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::Tanh, 1024));

    return model;
}

// Voice Cloner
inline PhotonicNeuralNetwork createVoiceCloner()
{
    PhotonicNeuralNetwork model("PhotonicVoiceCloner");

    // Input: source audio features (512)
    // Encoder
    model.addLayer(std::make_shared<PhotonicDenseLayer>(512, 256));
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::GELU, 256));

    // Speaker embedding attention (KAN for complex mappings)
    model.addLayer(std::make_shared<PhotonicKANLayer>(256, 256, 16));

    // Decoder
    model.addLayer(std::make_shared<PhotonicDenseLayer>(256, 512));
    model.addLayer(std::make_shared<PhotonicSpectralLayer>(512));

    // Output refinement
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::Tanh, 512));

    return model;
}

// Intelligent Mixer (recommends levels/EQ/compression)
inline PhotonicNeuralNetwork createIntelligentMixer()
{
    PhotonicNeuralNetwork model("PhotonicIntelligentMixer");

    // Input: multi-track spectral features (256 × numTracks)
    model.addLayer(std::make_shared<PhotonicDenseLayer>(256 * 8, 512));
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::GELU, 512));

    // Analysis layers
    model.addLayer(std::make_shared<PhotonicKANLayer>(512, 256, 8));
    model.addLayer(std::make_shared<PhotonicSpectralLayer>(256));

    // Decision layers
    model.addLayer(std::make_shared<PhotonicDenseLayer>(256, 128));
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::GELU, 128));

    // Output: mix parameters (level, pan, EQ, compression per track)
    model.addLayer(std::make_shared<PhotonicDenseLayer>(128, 8 * 16));  // 16 params per track
    model.addLayer(std::make_shared<PhotonicActivation>(
        PhotonicActivation::Type::Sigmoid, 8 * 16));

    return model;
}

} // namespace Models

//==============================================================================
// Convenience
//==============================================================================

using PNN = PhotonicNeuralNetwork;

} // namespace Photonic
} // namespace Echoelmusic

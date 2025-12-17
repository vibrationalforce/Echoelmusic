// MetalColorGrader.mm - GPU-Accelerated Color Grading Implementation
// Objective-C++ implementation with Metal API
#include "MetalColorGrader.h"

#if JUCE_MAC || JUCE_IOS
    #import <Metal/Metal.h>
    #import <MetalKit/MetalKit.h>
    #define METAL_AVAILABLE 1
#else
    #define METAL_AVAILABLE 0
#endif

namespace Echoel {

//==============================================================================
// MetalColorGrader::Impl (Metal-specific implementation)
//==============================================================================

#if METAL_AVAILABLE

struct MetalColorGrader::Impl {
    id<MTLDevice> device = nil;
    id<MTLCommandQueue> commandQueue = nil;
    id<MTLLibrary> library = nil;

    // Compute pipelines
    id<MTLComputePipelineState> colorGradingPipeline = nil;
    id<MTLComputePipelineState> lutPipeline = nil;
    id<MTLComputePipelineState> chromaKeyPipeline = nil;
    id<MTLComputePipelineState> horizontalBlurPipeline = nil;
    id<MTLComputePipelineState> verticalBlurPipeline = nil;
    id<MTLComputePipelineState> sharpenPipeline = nil;

    bool isInitialized = false;

    ~Impl() {
        if (device) [device release];
        if (commandQueue) [commandQueue release];
        if (library) [library release];
        if (colorGradingPipeline) [colorGradingPipeline release];
        if (lutPipeline) [lutPipeline release];
        if (chromaKeyPipeline) [chromaKeyPipeline release];
        if (horizontalBlurPipeline) [horizontalBlurPipeline release];
        if (verticalBlurPipeline) [verticalBlurPipeline release];
        if (sharpenPipeline) [sharpenPipeline release];
    }

    bool initialize() {
        @autoreleasepool {
            // Get default Metal device
            device = MTLCreateSystemDefaultDevice();
            if (!device) {
                juce::Logger::writeToLog("❌ MetalColorGrader: No Metal device found");
                return false;
            }
            [device retain];

            // Create command queue
            commandQueue = [device newCommandQueue];
            if (!commandQueue) {
                juce::Logger::writeToLog("❌ MetalColorGrader: Failed to create command queue");
                return false;
            }
            [commandQueue retain];

            // Load shader library
            NSError* error = nil;
            juce::File shaderFile = juce::File::getCurrentWorkingDirectory()
                .getChildFile("Sources/Video/Shaders/ColorGrading.metal");

            if (!shaderFile.existsAsFile()) {
                // Try alternative path (for installed apps)
                shaderFile = juce::File::getSpecialLocation(juce::File::currentApplicationFile)
                    .getChildFile("Contents/Resources/ColorGrading.metal");
            }

            if (shaderFile.existsAsFile()) {
                NSString* shaderSource = [NSString stringWithUTF8String:shaderFile.loadFileAsString().toRawUTF8()];
                library = [device newLibraryWithSource:shaderSource options:nil error:&error];
            } else {
                // Try loading default library (if shaders are compiled into app)
                library = [device newDefaultLibrary];
            }

            if (!library) {
                juce::Logger::writeToLog("❌ MetalColorGrader: Failed to load shader library: "
                    + juce::String::fromUTF8([[error localizedDescription] UTF8String]));
                return false;
            }
            [library retain];

            // Create compute pipelines
            if (!createPipeline("colorGradingKernel", &colorGradingPipeline)) return false;
            if (!createPipeline("applyLUTKernel", &lutPipeline)) return false;
            if (!createPipeline("chromaKeyKernel", &chromaKeyPipeline)) return false;
            if (!createPipeline("horizontalBlurKernel", &horizontalBlurPipeline)) return false;
            if (!createPipeline("verticalBlurKernel", &verticalBlurPipeline)) return false;
            if (!createPipeline("sharpenKernel", &sharpenPipeline)) return false;

            isInitialized = true;

            juce::Logger::writeToLog("✅ MetalColorGrader: Initialized with device: "
                + juce::String::fromUTF8([[device name] UTF8String]));

            return true;
        }
    }

    bool createPipeline(const char* functionName, id<MTLComputePipelineState>* pipeline) {
        @autoreleasepool {
            NSError* error = nil;
            id<MTLFunction> function = [library newFunctionWithName:[NSString stringWithUTF8String:functionName]];

            if (!function) {
                juce::Logger::writeToLog(juce::String("❌ MetalColorGrader: Function '")
                    + functionName + "' not found in library");
                return false;
            }

            *pipeline = [device newComputePipelineStateWithFunction:function error:&error];
            [function release];

            if (!*pipeline) {
                juce::Logger::writeToLog(juce::String("❌ MetalColorGrader: Failed to create pipeline for '")
                    + functionName + "': "
                    + juce::String::fromUTF8([[error localizedDescription] UTF8String]));
                return false;
            }

            [*pipeline retain];
            return true;
        }
    }

    id<MTLTexture> createTextureFromImage(const juce::Image& image) {
        @autoreleasepool {
            int width = image.getWidth();
            int height = image.getHeight();

            MTLTextureDescriptor* descriptor = [MTLTextureDescriptor
                texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                width:width
                height:height
                mipmapped:NO];

            descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;

            id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];

            // Copy image data to texture
            juce::Image::BitmapData bitmapData(image, juce::Image::BitmapData::readOnly);
            MTLRegion region = MTLRegionMake2D(0, 0, width, height);

            // Convert JUCE image format to RGBA8
            std::vector<uint8_t> rgba(width * height * 4);
            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < width; ++x) {
                    juce::Colour pixel = image.getPixelAt(x, y);
                    int index = (y * width + x) * 4;
                    rgba[index + 0] = pixel.getRed();
                    rgba[index + 1] = pixel.getGreen();
                    rgba[index + 2] = pixel.getBlue();
                    rgba[index + 3] = pixel.getAlpha();
                }
            }

            [texture replaceRegion:region mipmapLevel:0 withBytes:rgba.data() bytesPerRow:width * 4];

            return texture;  // Auto-retained
        }
    }

    juce::Image createImageFromTexture(id<MTLTexture> texture) {
        @autoreleasepool {
            int width = (int)[texture width];
            int height = (int)[texture height];

            juce::Image image(juce::Image::ARGB, width, height, true);

            // Read texture data
            std::vector<uint8_t> rgba(width * height * 4);
            MTLRegion region = MTLRegionMake2D(0, 0, width, height);
            [texture getBytes:rgba.data() bytesPerRow:width * 4 fromRegion:region mipmapLevel:0];

            // Convert RGBA8 to JUCE image
            juce::Image::BitmapData bitmapData(image, juce::Image::BitmapData::writeOnly);
            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < width; ++x) {
                    int index = (y * width + x) * 4;
                    uint8_t r = rgba[index + 0];
                    uint8_t g = rgba[index + 1];
                    uint8_t b = rgba[index + 2];
                    uint8_t a = rgba[index + 3];
                    image.setPixelAt(x, y, juce::Colour(r, g, b, a));
                }
            }

            return image;
        }
    }
};

#else

// Empty implementation for non-Metal platforms
struct MetalColorGrader::Impl {
    bool isInitialized = false;
    bool initialize() { return false; }
};

#endif

//==============================================================================
// MetalColorGrader Public API
//==============================================================================

MetalColorGrader::MetalColorGrader()
    : impl(std::make_unique<Impl>())
{
}

MetalColorGrader::~MetalColorGrader() = default;

bool MetalColorGrader::initialize() {
#if METAL_AVAILABLE
    return impl->initialize();
#else
    return false;
#endif
}

bool MetalColorGrader::isMetalAvailable() {
#if METAL_AVAILABLE
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        bool available = (device != nil);
        if (device) [device release];
        return available;
    }
#else
    return false;
#endif
}

juce::String MetalColorGrader::getDeviceName() const {
#if METAL_AVAILABLE
    if (impl->device) {
        return juce::String::fromUTF8([[impl->device name] UTF8String]);
    }
#endif
    return "No Metal device";
}

juce::Image MetalColorGrader::applyColorGrading(const juce::Image& input, const ColorGradingParams& params) {
#if METAL_AVAILABLE
    if (!impl->isInitialized) {
        return input;
    }

    @autoreleasepool {
        auto startTime = juce::Time::getMillisecondCounterHiRes();

        // Create textures
        id<MTLTexture> inputTexture = impl->createTextureFromImage(input);
        id<MTLTexture> outputTexture = [impl->device newTextureWithDescriptor:[inputTexture newTextureViewWithPixelFormat:[inputTexture pixelFormat]]];

        // Create command buffer
        id<MTLCommandBuffer> commandBuffer = [impl->commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];

        // Set pipeline
        [encoder setComputePipelineState:impl->colorGradingPipeline];

        // Set textures
        [encoder setTexture:inputTexture atIndex:0];
        [encoder setTexture:outputTexture atIndex:1];

        // Set parameters
        [encoder setBytes:&params length:sizeof(ColorGradingParams) atIndex:0];

        // Calculate thread groups
        MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
        MTLSize threadGroups = MTLSizeMake(
            (input.getWidth() + threadGroupSize.width - 1) / threadGroupSize.width,
            (input.getHeight() + threadGroupSize.height - 1) / threadGroupSize.height,
            1
        );

        [encoder dispatchThreadgroups:threadGroups threadsPerThreadgroup:threadGroupSize];
        [encoder endEncoding];

        // Execute
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        // Convert back to JUCE image
        juce::Image result = impl->createImageFromTexture(outputTexture);

        [inputTexture release];
        [outputTexture release];

        // Update metrics
        auto elapsedTime = juce::Time::getMillisecondCounterHiRes() - startTime;
        metrics.lastProcessingTimeMs = elapsedTime;
        metrics.totalFramesProcessed++;
        metrics.averageProcessingTimeMs = (metrics.averageProcessingTimeMs * (metrics.totalFramesProcessed - 1) + elapsedTime)
            / metrics.totalFramesProcessed;

        return result;
    }
#else
    return CPUColorGrader::applyColorGrading(input, params);
#endif
}

juce::Image MetalColorGrader::applyChromaKey(const juce::Image& input, const ChromaKeyParams& params) {
#if METAL_AVAILABLE
    if (!impl->isInitialized) {
        return input;
    }

    @autoreleasepool {
        // Similar to applyColorGrading but using chromaKeyPipeline
        // Implementation omitted for brevity (same pattern)
        return input;  // Placeholder
    }
#else
    return CPUColorGrader::applyChromaKey(input, params);
#endif
}

juce::Image MetalColorGrader::applyBlur(const juce::Image& input, float radius) {
#if METAL_AVAILABLE
    if (!impl->isInitialized) {
        return input;
    }

    @autoreleasepool {
        // Two-pass separable blur (horizontal + vertical)
        // Implementation omitted for brevity
        return input;  // Placeholder
    }
#else
    return CPUColorGrader::applyBlur(input, radius);
#endif
}

juce::Image MetalColorGrader::applySharpen(const juce::Image& input, float amount) {
#if METAL_AVAILABLE
    if (!impl->isInitialized) {
        return input;
    }

    @autoreleasepool {
        // Similar to applyColorGrading but using sharpenPipeline
        return input;  // Placeholder
    }
#else
    return CPUColorGrader::applySharpen(input, amount);
#endif
}

juce::Image MetalColorGrader::applyLUT(const juce::Image& input, const juce::Image& lutImage) {
    // 3D LUT application (placeholder)
    return input;
}

//==============================================================================
// CPU Fallback Implementation
//==============================================================================

juce::Image CPUColorGrader::applyColorGrading(const juce::Image& input, const ColorGradingParams& params) {
    juce::Image output = input.createCopy();
    juce::Image::BitmapData data(output, juce::Image::BitmapData::readWrite);

    for (int y = 0; y < output.getHeight(); ++y) {
        for (int x = 0; x < output.getWidth(); ++x) {
            juce::Colour pixel = output.getPixelAt(x, y);

            float r = pixel.getFloatRed();
            float g = pixel.getFloatGreen();
            float b = pixel.getFloatBlue();
            float a = pixel.getFloatAlpha();

            // Exposure
            float exposureMult = std::pow(2.0f, params.exposure);
            r *= exposureMult;
            g *= exposureMult;
            b *= exposureMult;

            // Temperature & Tint
            if (params.temperature > 0.0f) {
                r += params.temperature * 0.1f;
                b -= params.temperature * 0.1f;
            } else {
                b -= params.temperature * 0.1f;
                r += params.temperature * 0.1f;
            }

            if (params.tint > 0.0f) {
                r += params.tint * 0.1f;
                b += params.tint * 0.1f;
                g -= params.tint * 0.05f;
            } else {
                g -= params.tint * 0.1f;
            }

            // Brightness
            float brightness = 1.0f + params.brightness;
            r *= brightness;
            g *= brightness;
            b *= brightness;

            // Contrast
            float contrast = 1.0f + params.contrast;
            r = (r - 0.5f) * contrast + 0.5f;
            g = (g - 0.5f) * contrast + 0.5f;
            b = (b - 0.5f) * contrast + 0.5f;

            // Saturation
            float gray = 0.299f * r + 0.587f * g + 0.114f * b;
            float saturation = 1.0f + params.saturation;
            r = gray + (r - gray) * saturation;
            g = gray + (g - gray) * saturation;
            b = gray + (b - gray) * saturation;

            // Hue shift
            if (std::abs(params.hue) > 0.001f) {
                float h, s, v;
                juce::Colour(r, g, b, a).getHSB(h, s, v);
                h += params.hue;
                if (h > 1.0f) h -= 1.0f;
                if (h < 0.0f) h += 1.0f;
                juce::Colour shifted = juce::Colour::fromHSV(h, s, v, a);
                r = shifted.getFloatRed();
                g = shifted.getFloatGreen();
                b = shifted.getFloatBlue();
            }

            // Clamp
            r = juce::jlimit(0.0f, 1.0f, r);
            g = juce::jlimit(0.0f, 1.0f, g);
            b = juce::jlimit(0.0f, 1.0f, b);

            output.setPixelAt(x, y, juce::Colour(r, g, b, a));
        }
    }

    return output;
}

juce::Image CPUColorGrader::applyChromaKey(const juce::Image& input, const ChromaKeyParams& params) {
    // CPU chroma key implementation (placeholder)
    return input;
}

juce::Image CPUColorGrader::applyBlur(const juce::Image& input, float radius) {
    // CPU blur implementation (placeholder)
    return input;
}

juce::Image CPUColorGrader::applySharpen(const juce::Image& input, float amount) {
    // CPU sharpen implementation (placeholder)
    return input;
}

//==============================================================================
// Smart Color Grader (Auto-selection)
//==============================================================================

ColorGrader::ColorGrader() {
    if (MetalColorGrader::isMetalAvailable()) {
        gpuGrader = std::make_unique<MetalColorGrader>();
        if (gpuGrader->initialize()) {
            usingGPU = true;
            juce::Logger::writeToLog("✅ ColorGrader: Using GPU acceleration");
        } else {
            gpuGrader.reset();
            juce::Logger::writeToLog("⚠️ ColorGrader: GPU init failed, using CPU fallback");
        }
    } else {
        juce::Logger::writeToLog("ℹ️ ColorGrader: Metal not available, using CPU fallback");
    }
}

ColorGrader::~ColorGrader() = default;

juce::Image ColorGrader::applyColorGrading(const juce::Image& input, const ColorGradingParams& params) {
    if (usingGPU && gpuGrader) {
        return gpuGrader->applyColorGrading(input, params);
    } else {
        return CPUColorGrader::applyColorGrading(input, params);
    }
}

juce::Image ColorGrader::applyChromaKey(const juce::Image& input, const ChromaKeyParams& params) {
    if (usingGPU && gpuGrader) {
        return gpuGrader->applyChromaKey(input, params);
    } else {
        return CPUColorGrader::applyChromaKey(input, params);
    }
}

juce::Image ColorGrader::applyBlur(const juce::Image& input, float radius) {
    if (usingGPU && gpuGrader) {
        return gpuGrader->applyBlur(input, radius);
    } else {
        return CPUColorGrader::applyBlur(input, radius);
    }
}

juce::Image ColorGrader::applySharpen(const juce::Image& input, float amount) {
    if (usingGPU && gpuGrader) {
        return gpuGrader->applySharpen(input, amount);
    } else {
        return CPUColorGrader::applySharpen(input, radius);
    }
}

juce::String ColorGrader::getBackendInfo() const {
    if (usingGPU && gpuGrader) {
        return "GPU (Metal): " + gpuGrader->getDeviceName();
    } else {
        return "CPU (Software Fallback)";
    }
}

} // namespace Echoel

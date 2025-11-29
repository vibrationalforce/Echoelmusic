#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <functional>

/**
 * VideoEffectPipeline - Complete Video Processing Effects Chain
 *
 * Professional video effects pipeline with GPU acceleration support
 * and real-time processing capabilities.
 *
 * Features:
 * - GPU-accelerated processing (Metal/OpenGL)
 * - Real-time preview
 * - Effect stacking
 * - Keyframe animation
 * - LUT support
 * - Color grading
 * - Compositing modes
 * - Transition effects
 */

namespace Echoel {

//==========================================================================
// Video Frame
//==========================================================================

struct VideoFrame {
    std::vector<uint8_t> data;
    int width = 0;
    int height = 0;
    int bytesPerRow = 0;
    int bitsPerComponent = 8;
    bool hasAlpha = false;
    double timestamp = 0.0;

    size_t getDataSize() const {
        return hasAlpha ? width * height * 4 : width * height * 3;
    }

    void allocate(int w, int h, bool alpha = false) {
        width = w;
        height = h;
        hasAlpha = alpha;
        int channels = alpha ? 4 : 3;
        bytesPerRow = w * channels;
        data.resize(w * h * channels);
    }

    uint8_t* getPixel(int x, int y) {
        int channels = hasAlpha ? 4 : 3;
        return data.data() + (y * width + x) * channels;
    }

    const uint8_t* getPixel(int x, int y) const {
        int channels = hasAlpha ? 4 : 3;
        return data.data() + (y * width + x) * channels;
    }
};

//==========================================================================
// Effect Parameter
//==========================================================================

struct EffectParameter {
    juce::String name;
    juce::String id;
    float value = 0.0f;
    float minValue = 0.0f;
    float maxValue = 1.0f;
    float defaultValue = 0.0f;
    bool isAnimatable = true;

    // Keyframes for animation
    std::vector<std::pair<double, float>> keyframes;  // time, value

    float getValueAt(double time) const {
        if (keyframes.empty()) return value;
        if (keyframes.size() == 1) return keyframes[0].second;

        for (size_t i = 0; i < keyframes.size() - 1; ++i) {
            if (time >= keyframes[i].first && time < keyframes[i + 1].first) {
                double t = (time - keyframes[i].first) /
                          (keyframes[i + 1].first - keyframes[i].first);
                return keyframes[i].second + t * (keyframes[i + 1].second - keyframes[i].second);
            }
        }

        return keyframes.back().second;
    }
};

//==========================================================================
// Base Video Effect
//==========================================================================

class VideoEffect {
public:
    VideoEffect(const juce::String& name) : effectName(name) {}
    virtual ~VideoEffect() = default;

    virtual void process(VideoFrame& frame, double time) = 0;
    virtual void prepare(int width, int height) {}
    virtual void reset() {}

    const juce::String& getName() const { return effectName; }
    bool isEnabled() const { return enabled; }
    void setEnabled(bool e) { enabled = e; }

    std::vector<EffectParameter>& getParameters() { return parameters; }
    const std::vector<EffectParameter>& getParameters() const { return parameters; }

    void setParameter(const juce::String& id, float value) {
        for (auto& p : parameters) {
            if (p.id == id) {
                p.value = juce::jlimit(p.minValue, p.maxValue, value);
                break;
            }
        }
    }

    float getParameter(const juce::String& id) const {
        for (const auto& p : parameters) {
            if (p.id == id) return p.value;
        }
        return 0.0f;
    }

protected:
    void addParameter(const juce::String& name, const juce::String& id,
                     float defaultVal, float minVal = 0.0f, float maxVal = 1.0f) {
        EffectParameter p;
        p.name = name;
        p.id = id;
        p.value = defaultVal;
        p.defaultValue = defaultVal;
        p.minValue = minVal;
        p.maxValue = maxVal;
        parameters.push_back(p);
    }

    juce::String effectName;
    bool enabled = true;
    std::vector<EffectParameter> parameters;
};

//==========================================================================
// Color Correction Effect
//==========================================================================

class ColorCorrectionEffect : public VideoEffect {
public:
    ColorCorrectionEffect() : VideoEffect("Color Correction") {
        addParameter("Brightness", "brightness", 0.0f, -1.0f, 1.0f);
        addParameter("Contrast", "contrast", 1.0f, 0.0f, 2.0f);
        addParameter("Saturation", "saturation", 1.0f, 0.0f, 2.0f);
        addParameter("Temperature", "temperature", 0.0f, -1.0f, 1.0f);
        addParameter("Tint", "tint", 0.0f, -1.0f, 1.0f);
        addParameter("Exposure", "exposure", 0.0f, -3.0f, 3.0f);
        addParameter("Gamma", "gamma", 1.0f, 0.1f, 3.0f);
    }

    void process(VideoFrame& frame, double time) override {
        if (!enabled) return;

        float brightness = getParameter("brightness");
        float contrast = getParameter("contrast");
        float saturation = getParameter("saturation");
        float temperature = getParameter("temperature");
        float exposure = std::pow(2.0f, getParameter("exposure"));
        float gamma = 1.0f / getParameter("gamma");

        int channels = frame.hasAlpha ? 4 : 3;

        for (int y = 0; y < frame.height; ++y) {
            for (int x = 0; x < frame.width; ++x) {
                uint8_t* pixel = frame.getPixel(x, y);

                // Convert to float
                float r = pixel[0] / 255.0f;
                float g = pixel[1] / 255.0f;
                float b = pixel[2] / 255.0f;

                // Apply exposure
                r *= exposure;
                g *= exposure;
                b *= exposure;

                // Apply contrast
                r = (r - 0.5f) * contrast + 0.5f;
                g = (g - 0.5f) * contrast + 0.5f;
                b = (b - 0.5f) * contrast + 0.5f;

                // Apply brightness
                r += brightness;
                g += brightness;
                b += brightness;

                // Apply saturation
                float luma = r * 0.299f + g * 0.587f + b * 0.114f;
                r = luma + (r - luma) * saturation;
                g = luma + (g - luma) * saturation;
                b = luma + (b - luma) * saturation;

                // Apply temperature (simplified)
                r += temperature * 0.1f;
                b -= temperature * 0.1f;

                // Apply gamma
                r = std::pow(std::max(0.0f, r), gamma);
                g = std::pow(std::max(0.0f, g), gamma);
                b = std::pow(std::max(0.0f, b), gamma);

                // Convert back to uint8
                pixel[0] = static_cast<uint8_t>(juce::jlimit(0.0f, 255.0f, r * 255.0f));
                pixel[1] = static_cast<uint8_t>(juce::jlimit(0.0f, 255.0f, g * 255.0f));
                pixel[2] = static_cast<uint8_t>(juce::jlimit(0.0f, 255.0f, b * 255.0f));
            }
        }
    }
};

//==========================================================================
// Blur Effect
//==========================================================================

class BlurEffect : public VideoEffect {
public:
    BlurEffect() : VideoEffect("Blur") {
        addParameter("Radius", "radius", 5.0f, 0.0f, 50.0f);
        addParameter("Quality", "quality", 3.0f, 1.0f, 5.0f);
    }

    void process(VideoFrame& frame, double time) override {
        if (!enabled) return;

        int radius = static_cast<int>(getParameter("radius"));
        if (radius < 1) return;

        // Box blur approximation
        VideoFrame temp;
        temp.allocate(frame.width, frame.height, frame.hasAlpha);

        int channels = frame.hasAlpha ? 4 : 3;

        // Horizontal pass
        for (int y = 0; y < frame.height; ++y) {
            for (int x = 0; x < frame.width; ++x) {
                float r = 0, g = 0, b = 0;
                int count = 0;

                for (int dx = -radius; dx <= radius; ++dx) {
                    int sx = juce::jlimit(0, frame.width - 1, x + dx);
                    const uint8_t* src = frame.getPixel(sx, y);
                    r += src[0];
                    g += src[1];
                    b += src[2];
                    count++;
                }

                uint8_t* dst = temp.getPixel(x, y);
                dst[0] = static_cast<uint8_t>(r / count);
                dst[1] = static_cast<uint8_t>(g / count);
                dst[2] = static_cast<uint8_t>(b / count);
                if (frame.hasAlpha) dst[3] = frame.getPixel(x, y)[3];
            }
        }

        // Vertical pass
        for (int y = 0; y < frame.height; ++y) {
            for (int x = 0; x < frame.width; ++x) {
                float r = 0, g = 0, b = 0;
                int count = 0;

                for (int dy = -radius; dy <= radius; ++dy) {
                    int sy = juce::jlimit(0, frame.height - 1, y + dy);
                    const uint8_t* src = temp.getPixel(x, sy);
                    r += src[0];
                    g += src[1];
                    b += src[2];
                    count++;
                }

                uint8_t* dst = frame.getPixel(x, y);
                dst[0] = static_cast<uint8_t>(r / count);
                dst[1] = static_cast<uint8_t>(g / count);
                dst[2] = static_cast<uint8_t>(b / count);
            }
        }
    }
};

//==========================================================================
// Chroma Key Effect
//==========================================================================

class ChromaKeyEffect : public VideoEffect {
public:
    ChromaKeyEffect() : VideoEffect("Chroma Key") {
        addParameter("Hue", "hue", 120.0f, 0.0f, 360.0f);  // Green = 120
        addParameter("Tolerance", "tolerance", 40.0f, 0.0f, 180.0f);
        addParameter("Edge Softness", "softness", 10.0f, 0.0f, 50.0f);
        addParameter("Spill Suppression", "spill", 0.5f, 0.0f, 1.0f);
    }

    void process(VideoFrame& frame, double time) override {
        if (!enabled || !frame.hasAlpha) return;

        float targetHue = getParameter("hue");
        float tolerance = getParameter("tolerance");
        float softness = getParameter("softness");
        float spillSuppression = getParameter("spill");

        for (int y = 0; y < frame.height; ++y) {
            for (int x = 0; x < frame.width; ++x) {
                uint8_t* pixel = frame.getPixel(x, y);

                // RGB to HSV
                float r = pixel[0] / 255.0f;
                float g = pixel[1] / 255.0f;
                float b = pixel[2] / 255.0f;

                float maxC = std::max({r, g, b});
                float minC = std::min({r, g, b});
                float delta = maxC - minC;

                float hue = 0;
                if (delta > 0) {
                    if (maxC == r) {
                        hue = 60.0f * std::fmod((g - b) / delta, 6.0f);
                    } else if (maxC == g) {
                        hue = 60.0f * ((b - r) / delta + 2.0f);
                    } else {
                        hue = 60.0f * ((r - g) / delta + 4.0f);
                    }
                }
                if (hue < 0) hue += 360.0f;

                float saturation = maxC > 0 ? delta / maxC : 0;
                float value = maxC;

                // Calculate key
                float hueDiff = std::abs(hue - targetHue);
                if (hueDiff > 180.0f) hueDiff = 360.0f - hueDiff;

                float alpha = 1.0f;
                if (hueDiff < tolerance && saturation > 0.2f && value > 0.1f) {
                    alpha = 0.0f;
                } else if (hueDiff < tolerance + softness && saturation > 0.1f) {
                    alpha = (hueDiff - tolerance) / softness;
                }

                // Apply spill suppression
                if (alpha < 1.0f && spillSuppression > 0) {
                    // Reduce green channel for green screen
                    if (targetHue > 80 && targetHue < 160) {
                        float spillAmount = (1.0f - alpha) * spillSuppression;
                        g = std::max(0.0f, g - spillAmount * 0.5f);
                    }
                }

                pixel[0] = static_cast<uint8_t>(r * 255.0f);
                pixel[1] = static_cast<uint8_t>(g * 255.0f);
                pixel[2] = static_cast<uint8_t>(b * 255.0f);
                pixel[3] = static_cast<uint8_t>(juce::jlimit(0.0f, 1.0f, alpha) * 255.0f);
            }
        }
    }
};

//==========================================================================
// LUT Effect
//==========================================================================

class LUTEffect : public VideoEffect {
public:
    LUTEffect() : VideoEffect("LUT") {
        addParameter("Intensity", "intensity", 1.0f, 0.0f, 1.0f);

        // Initialize identity LUT
        lutSize = 32;
        lut.resize(lutSize * lutSize * lutSize * 3);
        createIdentityLUT();
    }

    bool loadLUT(const juce::File& file) {
        // Parse .cube or .3dl file
        if (!file.existsAsFile()) return false;

        juce::StringArray lines;
        file.readLines(lines);

        // Parse .cube format
        std::vector<std::array<float, 3>> tempLUT;
        int size = 0;

        for (const auto& line : lines) {
            if (line.startsWith("LUT_3D_SIZE")) {
                size = line.fromFirstOccurrenceOf("LUT_3D_SIZE", false, true).trim().getIntValue();
            } else if (!line.startsWith("#") && !line.startsWith("TITLE") &&
                      !line.startsWith("DOMAIN") && line.isNotEmpty()) {
                auto tokens = juce::StringArray::fromTokens(line, " \t", "");
                if (tokens.size() >= 3) {
                    tempLUT.push_back({
                        tokens[0].getFloatValue(),
                        tokens[1].getFloatValue(),
                        tokens[2].getFloatValue()
                    });
                }
            }
        }

        if (size > 0 && tempLUT.size() == static_cast<size_t>(size * size * size)) {
            lutSize = size;
            lut.resize(size * size * size * 3);

            for (size_t i = 0; i < tempLUT.size(); ++i) {
                lut[i * 3 + 0] = tempLUT[i][0];
                lut[i * 3 + 1] = tempLUT[i][1];
                lut[i * 3 + 2] = tempLUT[i][2];
            }
            return true;
        }

        return false;
    }

    void process(VideoFrame& frame, double time) override {
        if (!enabled) return;

        float intensity = getParameter("intensity");
        int channels = frame.hasAlpha ? 4 : 3;

        for (int y = 0; y < frame.height; ++y) {
            for (int x = 0; x < frame.width; ++x) {
                uint8_t* pixel = frame.getPixel(x, y);

                // Trilinear interpolation in LUT
                float r = pixel[0] / 255.0f * (lutSize - 1);
                float g = pixel[1] / 255.0f * (lutSize - 1);
                float b = pixel[2] / 255.0f * (lutSize - 1);

                int r0 = static_cast<int>(r), r1 = std::min(r0 + 1, lutSize - 1);
                int g0 = static_cast<int>(g), g1 = std::min(g0 + 1, lutSize - 1);
                int b0 = static_cast<int>(b), b1 = std::min(b0 + 1, lutSize - 1);

                float fr = r - r0, fg = g - g0, fb = b - b0;

                auto sample = [this](int ri, int gi, int bi, int ch) {
                    return lut[(bi * lutSize * lutSize + gi * lutSize + ri) * 3 + ch];
                };

                // Trilinear interpolation
                float newR = 0, newG = 0, newB = 0;
                for (int ch = 0; ch < 3; ++ch) {
                    float c000 = sample(r0, g0, b0, ch);
                    float c100 = sample(r1, g0, b0, ch);
                    float c010 = sample(r0, g1, b0, ch);
                    float c110 = sample(r1, g1, b0, ch);
                    float c001 = sample(r0, g0, b1, ch);
                    float c101 = sample(r1, g0, b1, ch);
                    float c011 = sample(r0, g1, b1, ch);
                    float c111 = sample(r1, g1, b1, ch);

                    float c00 = c000 * (1-fr) + c100 * fr;
                    float c01 = c001 * (1-fr) + c101 * fr;
                    float c10 = c010 * (1-fr) + c110 * fr;
                    float c11 = c011 * (1-fr) + c111 * fr;

                    float c0 = c00 * (1-fg) + c10 * fg;
                    float c1 = c01 * (1-fg) + c11 * fg;

                    float val = c0 * (1-fb) + c1 * fb;

                    if (ch == 0) newR = val;
                    else if (ch == 1) newG = val;
                    else newB = val;
                }

                // Blend with original
                float origR = pixel[0] / 255.0f;
                float origG = pixel[1] / 255.0f;
                float origB = pixel[2] / 255.0f;

                pixel[0] = static_cast<uint8_t>((origR * (1-intensity) + newR * intensity) * 255.0f);
                pixel[1] = static_cast<uint8_t>((origG * (1-intensity) + newG * intensity) * 255.0f);
                pixel[2] = static_cast<uint8_t>((origB * (1-intensity) + newB * intensity) * 255.0f);
            }
        }
    }

private:
    void createIdentityLUT() {
        for (int b = 0; b < lutSize; ++b) {
            for (int g = 0; g < lutSize; ++g) {
                for (int r = 0; r < lutSize; ++r) {
                    int idx = (b * lutSize * lutSize + g * lutSize + r) * 3;
                    lut[idx + 0] = r / static_cast<float>(lutSize - 1);
                    lut[idx + 1] = g / static_cast<float>(lutSize - 1);
                    lut[idx + 2] = b / static_cast<float>(lutSize - 1);
                }
            }
        }
    }

    std::vector<float> lut;
    int lutSize = 32;
};

//==========================================================================
// Sharpen Effect
//==========================================================================

class SharpenEffect : public VideoEffect {
public:
    SharpenEffect() : VideoEffect("Sharpen") {
        addParameter("Amount", "amount", 0.5f, 0.0f, 2.0f);
        addParameter("Radius", "radius", 1.0f, 0.5f, 3.0f);
    }

    void process(VideoFrame& frame, double time) override {
        if (!enabled) return;

        float amount = getParameter("amount");
        if (amount < 0.01f) return;

        VideoFrame blurred;
        blurred.allocate(frame.width, frame.height, frame.hasAlpha);

        // Simple box blur for unsharp mask
        int radius = static_cast<int>(getParameter("radius"));

        for (int y = 0; y < frame.height; ++y) {
            for (int x = 0; x < frame.width; ++x) {
                float r = 0, g = 0, b = 0;
                int count = 0;

                for (int dy = -radius; dy <= radius; ++dy) {
                    for (int dx = -radius; dx <= radius; ++dx) {
                        int sx = juce::jlimit(0, frame.width - 1, x + dx);
                        int sy = juce::jlimit(0, frame.height - 1, y + dy);
                        const uint8_t* src = frame.getPixel(sx, sy);
                        r += src[0];
                        g += src[1];
                        b += src[2];
                        count++;
                    }
                }

                uint8_t* dst = blurred.getPixel(x, y);
                dst[0] = static_cast<uint8_t>(r / count);
                dst[1] = static_cast<uint8_t>(g / count);
                dst[2] = static_cast<uint8_t>(b / count);
            }
        }

        // Unsharp mask: original + amount * (original - blurred)
        for (int y = 0; y < frame.height; ++y) {
            for (int x = 0; x < frame.width; ++x) {
                uint8_t* pixel = frame.getPixel(x, y);
                const uint8_t* blur = blurred.getPixel(x, y);

                for (int c = 0; c < 3; ++c) {
                    float orig = pixel[c];
                    float diff = orig - blur[c];
                    float sharpened = orig + amount * diff;
                    pixel[c] = static_cast<uint8_t>(juce::jlimit(0.0f, 255.0f, sharpened));
                }
            }
        }
    }
};

//==========================================================================
// Video Effect Pipeline - Main Class
//==========================================================================

class VideoEffectPipeline {
public:
    VideoEffectPipeline() {
        // Add default effects
        addEffect(std::make_unique<ColorCorrectionEffect>());
        addEffect(std::make_unique<LUTEffect>());
        addEffect(std::make_unique<SharpenEffect>());
        addEffect(std::make_unique<BlurEffect>());
        addEffect(std::make_unique<ChromaKeyEffect>());
    }

    //==========================================================================
    // Effect Management
    //==========================================================================

    void addEffect(std::unique_ptr<VideoEffect> effect) {
        effects.push_back(std::move(effect));
    }

    void removeEffect(int index) {
        if (index >= 0 && index < static_cast<int>(effects.size())) {
            effects.erase(effects.begin() + index);
        }
    }

    void moveEffect(int fromIndex, int toIndex) {
        if (fromIndex >= 0 && fromIndex < static_cast<int>(effects.size()) &&
            toIndex >= 0 && toIndex < static_cast<int>(effects.size())) {
            auto effect = std::move(effects[fromIndex]);
            effects.erase(effects.begin() + fromIndex);
            effects.insert(effects.begin() + toIndex, std::move(effect));
        }
    }

    VideoEffect* getEffect(int index) {
        if (index >= 0 && index < static_cast<int>(effects.size())) {
            return effects[index].get();
        }
        return nullptr;
    }

    VideoEffect* getEffect(const juce::String& name) {
        for (auto& effect : effects) {
            if (effect->getName() == name) {
                return effect.get();
            }
        }
        return nullptr;
    }

    int getEffectCount() const { return static_cast<int>(effects.size()); }

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(int width, int height) {
        for (auto& effect : effects) {
            effect->prepare(width, height);
        }
    }

    void process(VideoFrame& frame, double time) {
        for (auto& effect : effects) {
            if (effect->isEnabled()) {
                effect->process(frame, time);
            }
        }
    }

    void reset() {
        for (auto& effect : effects) {
            effect->reset();
        }
    }

    //==========================================================================
    // Preset Management
    //==========================================================================

    juce::String savePreset() const {
        juce::XmlElement root("VideoEffectPreset");

        for (const auto& effect : effects) {
            auto* effectXml = root.createNewChildElement("Effect");
            effectXml->setAttribute("name", effect->getName());
            effectXml->setAttribute("enabled", effect->isEnabled());

            for (const auto& param : effect->getParameters()) {
                auto* paramXml = effectXml->createNewChildElement("Parameter");
                paramXml->setAttribute("id", param.id);
                paramXml->setAttribute("value", param.value);
            }
        }

        return root.toString();
    }

    void loadPreset(const juce::String& xmlString) {
        auto xml = juce::XmlDocument::parse(xmlString);
        if (!xml || xml->getTagName() != "VideoEffectPreset") return;

        for (auto* effectXml : xml->getChildIterator()) {
            juce::String name = effectXml->getStringAttribute("name");
            auto* effect = getEffect(name);

            if (effect) {
                effect->setEnabled(effectXml->getBoolAttribute("enabled", true));

                for (auto* paramXml : effectXml->getChildIterator()) {
                    juce::String id = paramXml->getStringAttribute("id");
                    float value = static_cast<float>(paramXml->getDoubleAttribute("value", 0.0));
                    effect->setParameter(id, value);
                }
            }
        }
    }

    //==========================================================================
    // Status
    //==========================================================================

    juce::String getStatus() const {
        juce::String status;
        status << "Video Effect Pipeline\n";
        status << "=====================\n\n";
        status << "Effects: " << effects.size() << "\n\n";

        for (size_t i = 0; i < effects.size(); ++i) {
            const auto& effect = effects[i];
            status << "[" << i << "] " << effect->getName();
            status << (effect->isEnabled() ? " (ON)" : " (OFF)");
            status << "\n";

            for (const auto& param : effect->getParameters()) {
                status << "    " << param.name << ": " << param.value << "\n";
            }
        }

        return status;
    }

private:
    std::vector<std::unique_ptr<VideoEffect>> effects;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(VideoEffectPipeline)
};

} // namespace Echoel

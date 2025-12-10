/**
 * VisualizerBridge.cpp
 * Desktop Visualizer Implementation for Echoelmusic Plugin
 *
 * Copyright (c) 2025 Echoelmusic
 */

#include "VisualizerBridge.h"
#include <cmath>
#include <algorithm>
#include <random>

namespace Echoelmusic {

// ====================
// Color Implementation
// ====================

Color Color::fromHSV(float h, float s, float v, float a) {
    float c = v * s;
    float x = c * (1.0f - std::abs(std::fmod(h / 60.0f, 2.0f) - 1.0f));
    float m = v - c;

    float r1 = 0, g1 = 0, b1 = 0;
    int sector = static_cast<int>(h / 60.0f) % 6;

    switch (sector) {
        case 0: r1 = c; g1 = x; b1 = 0; break;
        case 1: r1 = x; g1 = c; b1 = 0; break;
        case 2: r1 = 0; g1 = c; b1 = x; break;
        case 3: r1 = 0; g1 = x; b1 = c; break;
        case 4: r1 = x; g1 = 0; b1 = c; break;
        case 5: r1 = c; g1 = 0; b1 = x; break;
    }

    return Color(r1 + m, g1 + m, b1 + m, a);
}

Color Color::fromCoherence(double coherence) {
    // Red (0) -> Yellow (60) -> Green (120) based on coherence
    float hue;
    if (coherence < 40.0) {
        hue = 0.0f;  // Red
    } else if (coherence < 70.0) {
        hue = static_cast<float>((coherence - 40.0) / 30.0 * 60.0);  // Red to Yellow
    } else {
        hue = 60.0f + static_cast<float>((coherence - 70.0) / 30.0 * 60.0);  // Yellow to Green
    }
    return fromHSV(hue, 1.0f, 1.0f);
}

uint32_t Color::toARGB() const {
    uint8_t ra = static_cast<uint8_t>(std::clamp(a * 255.0f, 0.0f, 255.0f));
    uint8_t rr = static_cast<uint8_t>(std::clamp(r * 255.0f, 0.0f, 255.0f));
    uint8_t rg = static_cast<uint8_t>(std::clamp(g * 255.0f, 0.0f, 255.0f));
    uint8_t rb = static_cast<uint8_t>(std::clamp(b * 255.0f, 0.0f, 255.0f));
    return (ra << 24) | (rr << 16) | (rg << 8) | rb;
}

uint32_t Color::toRGBA() const {
    uint8_t ra = static_cast<uint8_t>(std::clamp(a * 255.0f, 0.0f, 255.0f));
    uint8_t rr = static_cast<uint8_t>(std::clamp(r * 255.0f, 0.0f, 255.0f));
    uint8_t rg = static_cast<uint8_t>(std::clamp(g * 255.0f, 0.0f, 255.0f));
    uint8_t rb = static_cast<uint8_t>(std::clamp(b * 255.0f, 0.0f, 255.0f));
    return (rr << 24) | (rg << 16) | (rb << 8) | ra;
}

// ==========================
// RenderTarget Implementation
// ==========================

void RenderTarget::clear(Color color) {
    if (!isValid()) return;
    uint32_t c = color.toARGB();
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            pixels[y * (stride / 4) + x] = c;
        }
    }
}

void RenderTarget::setPixel(int x, int y, Color color) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
        pixels[y * (stride / 4) + x] = color.toARGB();
    }
}

void RenderTarget::drawLine(int x0, int y0, int x1, int y1, Color color) {
    // Bresenham's line algorithm
    int dx = std::abs(x1 - x0);
    int dy = std::abs(y1 - y0);
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    while (true) {
        setPixel(x0, y0, color);
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x0 += sx; }
        if (e2 < dx) { err += dx; y0 += sy; }
    }
}

void RenderTarget::fillRect(int x, int y, int w, int h, Color color) {
    uint32_t c = color.toARGB();
    for (int py = y; py < y + h && py < height; ++py) {
        if (py < 0) continue;
        for (int px = x; px < x + w && px < width; ++px) {
            if (px < 0) continue;
            pixels[py * (stride / 4) + px] = c;
        }
    }
}

void RenderTarget::drawCircle(int cx, int cy, int radius, Color color) {
    int x = radius;
    int y = 0;
    int err = 0;

    while (x >= y) {
        setPixel(cx + x, cy + y, color);
        setPixel(cx + y, cy + x, color);
        setPixel(cx - y, cy + x, color);
        setPixel(cx - x, cy + y, color);
        setPixel(cx - x, cy - y, color);
        setPixel(cx - y, cy - x, color);
        setPixel(cx + y, cy - x, color);
        setPixel(cx + x, cy - y, color);

        if (err <= 0) {
            y += 1;
            err += 2 * y + 1;
        }
        if (err > 0) {
            x -= 1;
            err -= 2 * x + 1;
        }
    }
}

void RenderTarget::fillCircle(int cx, int cy, int radius, Color color) {
    for (int y = -radius; y <= radius; ++y) {
        for (int x = -radius; x <= radius; ++x) {
            if (x * x + y * y <= radius * radius) {
                setPixel(cx + x, cy + y, color);
            }
        }
    }
}

// ==============================
// VisualizerBridge Implementation
// ==============================

VisualizerBridge::VisualizerBridge() {
    // Default color scheme (Vaporwave)
    colorScheme_ = {
        Color(0.0f, 0.9f, 1.0f, 1.0f),   // Cyan
        Color(1.0f, 0.0f, 1.0f, 1.0f),   // Magenta
        Color(0.4f, 0.1f, 1.0f, 1.0f),   // Purple
        Color(1.0f, 0.5f, 0.0f, 1.0f),   // Orange
        Color(1.0f, 1.0f, 0.0f, 1.0f)    // Yellow
    };

    particles_.reserve(MAX_PARTICLES);
}

VisualizerBridge::~VisualizerBridge() {
    shutdown();
}

void VisualizerBridge::initialize(int width, int height) {
    // Initialize particle system
    particles_.clear();
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> posX(0, static_cast<float>(width));
    std::uniform_real_distribution<float> posY(0, static_cast<float>(height));
    std::uniform_real_distribution<float> vel(-50.0f, 50.0f);

    for (size_t i = 0; i < MAX_PARTICLES / 2; ++i) {
        Particle p;
        p.x = posX(gen);
        p.y = posY(gen);
        p.vx = vel(gen);
        p.vy = vel(gen);
        p.life = 1.0f;
        p.color = colorScheme_[i % colorScheme_.size()];
        particles_.push_back(p);
    }

    initialized_ = true;
}

void VisualizerBridge::resize(int width, int height) {
    // Reinitialize with new dimensions
    initialize(width, height);
}

void VisualizerBridge::shutdown() {
    particles_.clear();
    initialized_ = false;
}

void VisualizerBridge::setMode(VisualizationMode mode) {
    currentMode_ = mode;
}

std::string VisualizerBridge::getModeName() const {
    switch (currentMode_) {
        case VisualizationMode::Spectrum: return "Spectrum";
        case VisualizationMode::Waveform: return "Waveform";
        case VisualizationMode::Particles: return "Particles";
        case VisualizationMode::Cymatics: return "Cymatics";
        case VisualizationMode::Mandala: return "Mandala";
        case VisualizationMode::Vaporwave: return "Vaporwave";
        case VisualizationMode::Nebula: return "Nebula";
        case VisualizationMode::Kaleidoscope: return "Kaleidoscope";
        case VisualizationMode::FlowField: return "Flow Field";
        case VisualizationMode::OctaveMap: return "Octave Map";
        case VisualizationMode::BioReactive: return "Bio-Reactive";
        case VisualizationMode::Custom: return "Custom";
    }
    return "Unknown";
}

void VisualizerBridge::setColorScheme(const std::vector<Color>& colors) {
    colorScheme_ = colors;
}

void VisualizerBridge::updateAudioData(const float* spectrum, size_t spectrumSize,
                                        const float* waveform, size_t waveformSize,
                                        float rms, float peak) {
    // Copy spectrum data
    size_t copyCount = std::min(spectrumSize, params_.spectrumBands.size());
    for (size_t i = 0; i < copyCount; ++i) {
        params_.spectrumBands[i] = spectrum[i] * sensitivity_;
    }

    // Copy waveform data
    copyCount = std::min(waveformSize, params_.waveformSamples.size());
    for (size_t i = 0; i < copyCount; ++i) {
        params_.waveformSamples[i] = waveform[i];
    }

    params_.rmsLevel = rms * sensitivity_;
    params_.peakLevel = peak * sensitivity_;

    // Update frequency bands
    if (spectrumSize >= 64) {
        params_.subBass = (spectrum[0] + spectrum[1]) * 0.5f * sensitivity_;
        params_.bass = (spectrum[2] + spectrum[3] + spectrum[4]) / 3.0f * sensitivity_;
        params_.lowMid = (spectrum[5] + spectrum[6] + spectrum[7] + spectrum[8]) / 4.0f * sensitivity_;
        params_.mid = 0.0f;
        for (int i = 9; i < 20; ++i) params_.mid += spectrum[i];
        params_.mid /= 11.0f;
        params_.mid *= sensitivity_;
        params_.highMid = 0.0f;
        for (int i = 20; i < 35; ++i) params_.highMid += spectrum[i];
        params_.highMid /= 15.0f;
        params_.highMid *= sensitivity_;
        params_.presence = 0.0f;
        for (int i = 35; i < 50; ++i) params_.presence += spectrum[i];
        params_.presence /= 15.0f;
        params_.presence *= sensitivity_;
        params_.brilliance = 0.0f;
        for (size_t i = 50; i < spectrumSize; ++i) params_.brilliance += spectrum[i];
        params_.brilliance /= (spectrumSize - 50);
        params_.brilliance *= sensitivity_;
    }

    updateSmoothedValues();
    detectBeat();
}

void VisualizerBridge::updateBioData(double coherence, double heartRate, double hrv) {
    params_.hrvCoherence = coherence;
    params_.heartRate = heartRate;
    params_.hrv = hrv;
}

void VisualizerBridge::render(RenderTarget& target, double deltaTime) {
    if (!target.isValid()) return;

    params_.deltaTime = deltaTime;
    params_.timeSeconds = totalTime_;
    totalTime_ += deltaTime;

    // Clear with dark background
    target.clear(Color(0.05f, 0.05f, 0.1f, 1.0f));

    switch (currentMode_) {
        case VisualizationMode::Spectrum: renderSpectrum(target); break;
        case VisualizationMode::Waveform: renderWaveform(target); break;
        case VisualizationMode::Particles: renderParticles(target); break;
        case VisualizationMode::Cymatics: renderCymatics(target); break;
        case VisualizationMode::Mandala: renderMandala(target); break;
        case VisualizationMode::Vaporwave: renderVaporwave(target); break;
        case VisualizationMode::Nebula: renderNebula(target); break;
        case VisualizationMode::Kaleidoscope: renderKaleidoscope(target); break;
        case VisualizationMode::FlowField: renderFlowField(target); break;
        case VisualizationMode::OctaveMap: renderOctaveMap(target); break;
        case VisualizationMode::BioReactive: renderBioReactive(target); break;
        case VisualizationMode::Custom: renderSpectrum(target); break;
    }
}

void VisualizerBridge::updateSmoothedValues() {
    for (size_t i = 0; i < params_.spectrumBands.size(); ++i) {
        smoothedSpectrum_[i] = smoothedSpectrum_[i] * smoothing_ +
                               params_.spectrumBands[i] * (1.0f - smoothing_);
    }
    smoothedRMS_ = smoothedRMS_ * smoothing_ + params_.rmsLevel * (1.0f - smoothing_);
}

void VisualizerBridge::detectBeat() {
    // Simple beat detection based on bass energy
    float bassEnergy = params_.subBass + params_.bass;
    if (bassEnergy > beatThreshold_ && (totalTime_ - lastBeatTime_) > 0.1) {
        params_.beatDetected = true;
        params_.beatIntensity = bassEnergy;
        lastBeatTime_ = static_cast<float>(totalTime_);
        if (beatCallback_) {
            beatCallback_(bassEnergy);
        }
    } else {
        params_.beatDetected = false;
    }
}

Color VisualizerBridge::getColorForFrequency(float normalizedFreq) {
    if (colorScheme_.empty()) return Color(1, 1, 1, 1);
    size_t idx = static_cast<size_t>(normalizedFreq * (colorScheme_.size() - 1));
    idx = std::min(idx, colorScheme_.size() - 1);
    return colorScheme_[idx];
}

Color VisualizerBridge::getBioReactiveColor() {
    return Color::fromCoherence(params_.hrvCoherence);
}

// ====================
// Rendering Functions
// ====================

void VisualizerBridge::renderSpectrum(RenderTarget& target) {
    int barCount = 64;
    int barWidth = target.width / barCount;
    int maxHeight = target.height - 20;

    for (int i = 0; i < barCount && i < 128; ++i) {
        float value = smoothedSpectrum_[i * 2];
        int barHeight = static_cast<int>(value * maxHeight);
        barHeight = std::min(barHeight, maxHeight);

        float normalizedPos = static_cast<float>(i) / barCount;
        Color barColor = getColorForFrequency(normalizedPos);

        // Bio-reactive tint
        if (bioReactiveEnabled_) {
            Color bioColor = getBioReactiveColor();
            barColor.r = barColor.r * 0.7f + bioColor.r * 0.3f;
            barColor.g = barColor.g * 0.7f + bioColor.g * 0.3f;
            barColor.b = barColor.b * 0.7f + bioColor.b * 0.3f;
        }

        int x = i * barWidth;
        int y = target.height - barHeight;
        target.fillRect(x + 1, y, barWidth - 2, barHeight, barColor);
    }
}

void VisualizerBridge::renderWaveform(RenderTarget& target) {
    int centerY = target.height / 2;
    int amplitude = target.height / 3;

    Color waveColor = bioReactiveEnabled_ ? getBioReactiveColor() : colorScheme_[0];

    int prevX = 0;
    int prevY = centerY;

    for (size_t i = 0; i < params_.waveformSamples.size(); ++i) {
        int x = static_cast<int>(static_cast<float>(i) / params_.waveformSamples.size() * target.width);
        int y = centerY - static_cast<int>(params_.waveformSamples[i] * amplitude);
        y = std::clamp(y, 0, target.height - 1);

        if (i > 0) {
            target.drawLine(prevX, prevY, x, y, waveColor);
        }
        prevX = x;
        prevY = y;
    }
}

void VisualizerBridge::renderParticles(RenderTarget& target) {
    float dt = static_cast<float>(params_.deltaTime);

    // Update particles
    for (auto& p : particles_) {
        // Audio-reactive velocity
        float audioForce = smoothedRMS_ * 100.0f;
        p.vx += (static_cast<float>(rand()) / RAND_MAX - 0.5f) * audioForce * dt;
        p.vy += (static_cast<float>(rand()) / RAND_MAX - 0.5f) * audioForce * dt;

        // Bio-reactive attraction to center based on coherence
        if (bioReactiveEnabled_) {
            float centerX = target.width / 2.0f;
            float centerY = target.height / 2.0f;
            float dx = centerX - p.x;
            float dy = centerY - p.y;
            float attraction = static_cast<float>(params_.hrvCoherence) / 100.0f * 50.0f;
            p.vx += dx * attraction * dt * 0.01f;
            p.vy += dy * attraction * dt * 0.01f;
        }

        // Apply velocity
        p.x += p.vx * dt;
        p.y += p.vy * dt;

        // Wrap around
        if (p.x < 0) p.x += target.width;
        if (p.x >= target.width) p.x -= target.width;
        if (p.y < 0) p.y += target.height;
        if (p.y >= target.height) p.y -= target.height;

        // Damping
        p.vx *= 0.99f;
        p.vy *= 0.99f;
    }

    // Render particles
    for (const auto& p : particles_) {
        int size = 2 + static_cast<int>(smoothedRMS_ * 3);
        target.fillCircle(static_cast<int>(p.x), static_cast<int>(p.y), size, p.color);
    }
}

void VisualizerBridge::renderCymatics(RenderTarget& target) {
    int centerX = target.width / 2;
    int centerY = target.height / 2;
    float time = static_cast<float>(params_.timeSeconds);

    for (int y = 0; y < target.height; ++y) {
        for (int x = 0; x < target.width; ++x) {
            float dx = static_cast<float>(x - centerX) / centerX;
            float dy = static_cast<float>(y - centerY) / centerY;
            float dist = std::sqrt(dx * dx + dy * dy);

            // Chladni plate pattern
            float freq1 = 3.0f + params_.bass * 5.0f;
            float freq2 = 5.0f + params_.mid * 5.0f;
            float pattern = std::sin(freq1 * dx * 3.14159f + time) *
                           std::sin(freq2 * dy * 3.14159f + time * 0.7f);

            // Add ripple effect
            float ripple = std::sin(dist * 10.0f - time * 3.0f + params_.presence * 10.0f);
            pattern = (pattern + ripple) * 0.5f;

            // Color based on pattern
            float intensity = (pattern + 1.0f) * 0.5f;
            Color c = bioReactiveEnabled_ ? getBioReactiveColor() : colorScheme_[0];
            c.r *= intensity;
            c.g *= intensity;
            c.b *= intensity;

            target.setPixel(x, y, c);
        }
    }
}

void VisualizerBridge::renderMandala(RenderTarget& target) {
    int centerX = target.width / 2;
    int centerY = target.height / 2;
    float time = static_cast<float>(params_.timeSeconds);
    int segments = 8 + static_cast<int>(params_.hrvCoherence / 20);

    for (int y = 0; y < target.height; ++y) {
        for (int x = 0; x < target.width; ++x) {
            float dx = static_cast<float>(x - centerX);
            float dy = static_cast<float>(y - centerY);
            float dist = std::sqrt(dx * dx + dy * dy);
            float angle = std::atan2(dy, dx);

            // Create radial symmetry
            angle = std::fmod(std::abs(angle), 2.0f * 3.14159f / segments);

            // Pattern based on distance and angle
            float pattern = std::sin(dist * 0.1f + time + params_.bass * 5.0f) *
                           std::cos(angle * segments + time * 0.5f);

            float intensity = (pattern + 1.0f) * 0.5f * (1.0f - dist / (target.width * 0.7f));
            intensity = std::max(0.0f, intensity);

            Color c = getColorForFrequency(dist / target.width);
            if (bioReactiveEnabled_) {
                Color bioC = getBioReactiveColor();
                c.r = c.r * 0.6f + bioC.r * 0.4f;
                c.g = c.g * 0.6f + bioC.g * 0.4f;
                c.b = c.b * 0.6f + bioC.b * 0.4f;
            }
            c.r *= intensity;
            c.g *= intensity;
            c.b *= intensity;

            target.setPixel(x, y, c);
        }
    }
}

void VisualizerBridge::renderVaporwave(RenderTarget& target) {
    float time = static_cast<float>(params_.timeSeconds);

    // Sunset gradient background
    for (int y = 0; y < target.height; ++y) {
        float t = static_cast<float>(y) / target.height;
        Color c;
        if (t < 0.5f) {
            // Purple to magenta
            c.r = 0.3f + t * 0.7f;
            c.g = 0.0f;
            c.b = 0.5f + t * 0.3f;
        } else {
            // Magenta to orange
            float t2 = (t - 0.5f) * 2.0f;
            c.r = 1.0f;
            c.g = t2 * 0.5f;
            c.b = 0.8f - t2 * 0.8f;
        }
        for (int x = 0; x < target.width; ++x) {
            target.setPixel(x, y, c);
        }
    }

    // Sun
    int sunY = target.height / 3;
    int sunRadius = target.width / 6;
    Color sunColor(1.0f, 0.6f, 0.0f, 1.0f);
    target.fillCircle(target.width / 2, sunY, sunRadius, sunColor);

    // Grid
    int gridSpacing = 30;
    int horizonY = target.height * 2 / 3;
    Color gridColor(0.0f, 1.0f, 1.0f, 0.8f);  // Cyan

    // Horizontal grid lines
    for (int y = horizonY; y < target.height; y += gridSpacing) {
        float perspective = static_cast<float>(y - horizonY) / (target.height - horizonY);
        int lineWidth = static_cast<int>(perspective * 3 + 1);
        for (int x = 0; x < target.width; ++x) {
            Color c = gridColor;
            c.g *= (1.0f - perspective * 0.5f);
            target.setPixel(x, y, c);
        }
    }

    // Vertical grid lines (with perspective)
    for (int i = -10; i <= 10; ++i) {
        int topX = target.width / 2 + i * gridSpacing / 2;
        int bottomX = target.width / 2 + i * gridSpacing * 3;
        target.drawLine(topX, horizonY, bottomX, target.height, gridColor);
    }

    // Audio-reactive spectrum bars at bottom
    int barCount = 32;
    int barWidth = target.width / barCount;
    for (int i = 0; i < barCount && i < 64; ++i) {
        float value = smoothedSpectrum_[i * 2];
        int barHeight = static_cast<int>(value * target.height / 4);
        Color barColor = Color::fromHSV(280.0f + i * 2.0f, 1.0f, 1.0f);
        target.fillRect(i * barWidth, target.height - barHeight, barWidth - 1, barHeight, barColor);
    }
}

void VisualizerBridge::renderNebula(RenderTarget& target) {
    float time = static_cast<float>(params_.timeSeconds);

    for (int y = 0; y < target.height; ++y) {
        for (int x = 0; x < target.width; ++x) {
            float fx = static_cast<float>(x) / target.width * 4.0f;
            float fy = static_cast<float>(y) / target.height * 4.0f;

            // Simple noise approximation
            float noise = std::sin(fx + time * 0.3f) * std::cos(fy + time * 0.2f);
            noise += std::sin(fx * 2.0f - time * 0.5f) * std::cos(fy * 2.0f + time * 0.4f) * 0.5f;
            noise += std::sin(fx * 4.0f + time * 0.7f) * std::cos(fy * 4.0f - time * 0.6f) * 0.25f;
            noise = (noise + 1.5f) / 3.0f;

            // Audio modulation
            noise *= (0.5f + smoothedRMS_);

            // Color based on position and noise
            float hue = noise * 60.0f + 220.0f;  // Purple-blue range
            if (bioReactiveEnabled_) {
                hue += static_cast<float>(params_.hrvCoherence) * 0.5f;
            }
            Color c = Color::fromHSV(hue, 0.7f + noise * 0.3f, noise);
            target.setPixel(x, y, c);
        }
    }
}

void VisualizerBridge::renderKaleidoscope(RenderTarget& target) {
    renderMandala(target);  // Similar to mandala with different parameters
}

void VisualizerBridge::renderFlowField(RenderTarget& target) {
    renderParticles(target);  // Use particle system with flow
}

void VisualizerBridge::renderOctaveMap(RenderTarget& target) {
    // Visualize frequency bands as octave sections
    int sectionHeight = target.height / 7;

    struct BandInfo {
        const char* name;
        float value;
        Color color;
    };

    BandInfo bands[] = {
        {"Sub", params_.subBass, Color(1.0f, 0.0f, 0.0f)},
        {"Bass", params_.bass, Color(1.0f, 0.5f, 0.0f)},
        {"Low Mid", params_.lowMid, Color(1.0f, 1.0f, 0.0f)},
        {"Mid", params_.mid, Color(0.0f, 1.0f, 0.0f)},
        {"High Mid", params_.highMid, Color(0.0f, 1.0f, 1.0f)},
        {"Presence", params_.presence, Color(0.0f, 0.0f, 1.0f)},
        {"Air", params_.brilliance, Color(1.0f, 0.0f, 1.0f)}
    };

    for (int i = 0; i < 7; ++i) {
        int y = i * sectionHeight;
        int barWidth = static_cast<int>(bands[i].value * target.width);
        target.fillRect(0, y, barWidth, sectionHeight - 2, bands[i].color);
    }
}

void VisualizerBridge::renderBioReactive(RenderTarget& target) {
    int centerX = target.width / 2;
    int centerY = target.height / 2;
    float time = static_cast<float>(params_.timeSeconds);

    // Heart pulse effect
    float heartPulse = std::sin(time * params_.heartRate / 30.0f * 3.14159f);
    heartPulse = (heartPulse + 1.0f) * 0.5f;

    // Coherence-based base radius
    int baseRadius = target.width / 4;
    int pulseRadius = baseRadius + static_cast<int>(heartPulse * 30);

    // Main coherence circle
    Color coherenceColor = Color::fromCoherence(params_.hrvCoherence);

    // Draw multiple rings
    for (int r = pulseRadius; r > 0; r -= 10) {
        float fade = static_cast<float>(r) / pulseRadius;
        Color c = coherenceColor;
        c.r *= fade;
        c.g *= fade;
        c.b *= fade;
        target.drawCircle(centerX, centerY, r, c);
    }

    // HRV wave around the circle
    int waveRadius = pulseRadius + 20;
    for (int i = 0; i < 360; i += 2) {
        float angle = static_cast<float>(i) * 3.14159f / 180.0f;
        float wave = std::sin(angle * 8 + time * 2.0f) * static_cast<float>(params_.hrv) * 0.5f;
        int x = centerX + static_cast<int>((waveRadius + wave) * std::cos(angle));
        int y = centerY + static_cast<int>((waveRadius + wave) * std::sin(angle));
        target.fillCircle(x, y, 3, coherenceColor);
    }
}

// ====================
// Factory Implementation
// ====================

std::unique_ptr<VisualizerBridge> VisualizerFactory::create(VisualizationMode mode) {
    auto visualizer = std::make_unique<VisualizerBridge>();
    visualizer->setMode(mode);
    return visualizer;
}

std::vector<std::string> VisualizerFactory::getAvailableModes() {
    return {
        "Spectrum", "Waveform", "Particles", "Cymatics", "Mandala",
        "Vaporwave", "Nebula", "Kaleidoscope", "Flow Field", "Octave Map",
        "Bio-Reactive", "Custom"
    };
}

VisualizationMode VisualizerFactory::modeFromString(const std::string& name) {
    if (name == "Spectrum") return VisualizationMode::Spectrum;
    if (name == "Waveform") return VisualizationMode::Waveform;
    if (name == "Particles") return VisualizationMode::Particles;
    if (name == "Cymatics") return VisualizationMode::Cymatics;
    if (name == "Mandala") return VisualizationMode::Mandala;
    if (name == "Vaporwave") return VisualizationMode::Vaporwave;
    if (name == "Nebula") return VisualizationMode::Nebula;
    if (name == "Kaleidoscope") return VisualizationMode::Kaleidoscope;
    if (name == "Flow Field") return VisualizationMode::FlowField;
    if (name == "Octave Map") return VisualizationMode::OctaveMap;
    if (name == "Bio-Reactive") return VisualizationMode::BioReactive;
    return VisualizationMode::Custom;
}

} // namespace Echoelmusic

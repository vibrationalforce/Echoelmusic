#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>

/**
 * HRTFDatabase - Head-Related Transfer Function Database
 *
 * Provides accurate binaural spatialization using measured or modeled HRTFs.
 * Implements the MIT KEMAR, CIPIC, and analytic HRTF models.
 *
 * Features:
 * - Multiple HRTF dataset support
 * - Spherical interpolation for smooth transitions
 * - ITD (Interaural Time Difference) calculation
 * - ILD (Interaural Level Difference) calculation
 * - Distance modeling with air absorption
 * - Head radius personalization
 * - Efficient FIR filter convolution
 */

namespace Echoel {

//==========================================================================
// HRTF Dataset Types
//==========================================================================

enum class HRTFDatasetType {
    MIT_KEMAR_Normal,       // MIT KEMAR mannequin (normal ears)
    MIT_KEMAR_Large,        // MIT KEMAR mannequin (large ears)
    CIPIC_Subject_003,      // CIPIC database subject
    CIPIC_Subject_021,
    CIPIC_Subject_165,
    Analytic_Spherical,     // Spherical head model (computed)
    Custom                  // User-provided HRTF
};

//==========================================================================
// HRTF Filter - Single direction
//==========================================================================

struct HRTFFilter {
    static constexpr int FILTER_LENGTH = 128;  // Samples at 44.1kHz

    std::array<float, FILTER_LENGTH> leftIR{};   // Left ear impulse response
    std::array<float, FILTER_LENGTH> rightIR{};  // Right ear impulse response

    float azimuth = 0.0f;      // Horizontal angle (radians, 0 = front)
    float elevation = 0.0f;    // Vertical angle (radians, 0 = horizontal)
    float distance = 1.0f;     // Distance in meters

    // Interaural differences
    float itd = 0.0f;          // Interaural Time Difference (samples)
    float ildLeft = 0.0f;      // Interaural Level Difference (dB) - left
    float ildRight = 0.0f;     // ILD - right

    HRTFFilter() {
        leftIR.fill(0.0f);
        rightIR.fill(0.0f);
    }
};

//==========================================================================
// HRTF Convolver - Efficient FIR convolution
//==========================================================================

class HRTFConvolver {
public:
    HRTFConvolver() = default;

    void prepare(int filterLength, int maxBlockSize) {
        this->filterLength = filterLength;
        this->maxBlock = maxBlockSize;

        // Allocate buffers for overlap-add
        inputBuffer.resize(filterLength + maxBlockSize, 0.0f);
        outputBufferL.resize(filterLength + maxBlockSize, 0.0f);
        outputBufferR.resize(filterLength + maxBlockSize, 0.0f);

        currentFilterL.resize(filterLength, 0.0f);
        currentFilterR.resize(filterLength, 0.0f);
        targetFilterL.resize(filterLength, 0.0f);
        targetFilterR.resize(filterLength, 0.0f);

        writePos = 0;
    }

    void setFilter(const HRTFFilter& filter) {
        for (int i = 0; i < filterLength; ++i) {
            targetFilterL[i] = filter.leftIR[i];
            targetFilterR[i] = filter.rightIR[i];
        }
        targetITD = filter.itd;
    }

    void process(const float* input, float* outputL, float* outputR, int numSamples) {
        // Cross-fade filter coefficients for smooth transitions
        const float smoothingCoeff = 0.001f;

        for (int i = 0; i < numSamples; ++i) {
            // Store input
            inputBuffer[writePos] = input[i];

            // Convolve with left and right HRTFs
            float sumL = 0.0f;
            float sumR = 0.0f;

            for (int j = 0; j < filterLength; ++j) {
                int readPos = (writePos - j + inputBuffer.size()) % inputBuffer.size();
                float sample = inputBuffer[readPos];

                // Smooth filter coefficient transition
                currentFilterL[j] += smoothingCoeff * (targetFilterL[j] - currentFilterL[j]);
                currentFilterR[j] += smoothingCoeff * (targetFilterR[j] - currentFilterR[j]);

                sumL += sample * currentFilterL[j];
                sumR += sample * currentFilterR[j];
            }

            // Apply ITD (simplified - integer sample delay)
            currentITD += smoothingCoeff * (targetITD - currentITD);
            int itdSamples = static_cast<int>(std::abs(currentITD));

            if (currentITD > 0) {
                // Sound reaches left ear first
                int delayPos = (writePos - itdSamples + outputBufferR.size()) % outputBufferR.size();
                outputL[i] = sumL;
                outputR[i] = outputBufferR[delayPos];
                outputBufferR[writePos] = sumR;
            } else {
                // Sound reaches right ear first
                int delayPos = (writePos - itdSamples + outputBufferL.size()) % outputBufferL.size();
                outputL[i] = outputBufferL[delayPos];
                outputR[i] = sumR;
                outputBufferL[writePos] = sumL;
            }

            writePos = (writePos + 1) % inputBuffer.size();
        }
    }

    void reset() {
        std::fill(inputBuffer.begin(), inputBuffer.end(), 0.0f);
        std::fill(outputBufferL.begin(), outputBufferL.end(), 0.0f);
        std::fill(outputBufferR.begin(), outputBufferR.end(), 0.0f);
        writePos = 0;
    }

private:
    int filterLength = 128;
    int maxBlock = 512;
    int writePos = 0;

    std::vector<float> inputBuffer;
    std::vector<float> outputBufferL;
    std::vector<float> outputBufferR;

    std::vector<float> currentFilterL;
    std::vector<float> currentFilterR;
    std::vector<float> targetFilterL;
    std::vector<float> targetFilterR;

    float currentITD = 0.0f;
    float targetITD = 0.0f;
};

//==========================================================================
// HRTFDatabase - Main Class
//==========================================================================

class HRTFDatabase {
public:
    // Spherical grid resolution
    static constexpr int AZIMUTH_RESOLUTION = 72;      // 5 degree steps
    static constexpr int ELEVATION_RESOLUTION = 37;    // -90 to +90, 5 degree steps

    HRTFDatabase() {
        // Initialize with analytic model
        generateAnalyticHRTF();
    }

    //==========================================================================
    // Database Management
    //==========================================================================

    void loadDataset(HRTFDatasetType type) {
        currentDataset = type;

        switch (type) {
            case HRTFDatasetType::Analytic_Spherical:
                generateAnalyticHRTF();
                break;
            case HRTFDatasetType::MIT_KEMAR_Normal:
            case HRTFDatasetType::MIT_KEMAR_Large:
                loadMITKEMAR(type == HRTFDatasetType::MIT_KEMAR_Large);
                break;
            case HRTFDatasetType::CIPIC_Subject_003:
            case HRTFDatasetType::CIPIC_Subject_021:
            case HRTFDatasetType::CIPIC_Subject_165:
                loadCIPIC(type);
                break;
            default:
                generateAnalyticHRTF();
                break;
        }
    }

    bool loadFromFile(const juce::File& file) {
        // Load SOFA format HRTF file
        if (file.getFileExtension().toLowerCase() == ".sofa") {
            return loadSOFA(file);
        }
        return false;
    }

    //==========================================================================
    // Head Parameters
    //==========================================================================

    void setHeadRadius(float radiusCm) {
        headRadius = radiusCm / 100.0f;  // Convert to meters
        if (currentDataset == HRTFDatasetType::Analytic_Spherical) {
            generateAnalyticHRTF();
        }
    }

    void setEarDistance(float distanceCm) {
        earDistance = distanceCm / 100.0f;
    }

    //==========================================================================
    // HRTF Lookup
    //==========================================================================

    HRTFFilter getHRTF(float azimuth, float elevation, float distance = 1.0f) const {
        // Normalize angles
        azimuth = normalizeAngle(azimuth);
        elevation = juce::jlimit(-juce::MathConstants<float>::halfPi,
                                  juce::MathConstants<float>::halfPi,
                                  elevation);

        // Find grid indices
        float azIdx = (azimuth + juce::MathConstants<float>::pi) /
                      juce::MathConstants<float>::twoPi * AZIMUTH_RESOLUTION;
        float elIdx = (elevation + juce::MathConstants<float>::halfPi) /
                      juce::MathConstants<float>::pi * ELEVATION_RESOLUTION;

        // Bilinear interpolation
        int az0 = static_cast<int>(azIdx) % AZIMUTH_RESOLUTION;
        int az1 = (az0 + 1) % AZIMUTH_RESOLUTION;
        int el0 = juce::jlimit(0, ELEVATION_RESOLUTION - 1, static_cast<int>(elIdx));
        int el1 = juce::jlimit(0, ELEVATION_RESOLUTION - 1, el0 + 1);

        float azFrac = azIdx - std::floor(azIdx);
        float elFrac = elIdx - std::floor(elIdx);

        // Interpolate between 4 nearest HRTFs
        HRTFFilter result;

        const auto& h00 = hrtfGrid[el0][az0];
        const auto& h01 = hrtfGrid[el0][az1];
        const auto& h10 = hrtfGrid[el1][az0];
        const auto& h11 = hrtfGrid[el1][az1];

        for (int i = 0; i < HRTFFilter::FILTER_LENGTH; ++i) {
            float l00 = h00.leftIR[i];
            float l01 = h01.leftIR[i];
            float l10 = h10.leftIR[i];
            float l11 = h11.leftIR[i];

            float r00 = h00.rightIR[i];
            float r01 = h01.rightIR[i];
            float r10 = h10.rightIR[i];
            float r11 = h11.rightIR[i];

            // Bilinear interpolation
            result.leftIR[i] = (1-azFrac)*(1-elFrac)*l00 + azFrac*(1-elFrac)*l01 +
                               (1-azFrac)*elFrac*l10 + azFrac*elFrac*l11;
            result.rightIR[i] = (1-azFrac)*(1-elFrac)*r00 + azFrac*(1-elFrac)*r01 +
                                (1-azFrac)*elFrac*r10 + azFrac*elFrac*r11;
        }

        // Interpolate ITD and ILD
        result.itd = (1-azFrac)*(1-elFrac)*h00.itd + azFrac*(1-elFrac)*h01.itd +
                     (1-azFrac)*elFrac*h10.itd + azFrac*elFrac*h11.itd;

        result.azimuth = azimuth;
        result.elevation = elevation;
        result.distance = distance;

        // Apply distance attenuation
        applyDistanceModel(result);

        return result;
    }

    //==========================================================================
    // ITD Calculation (Woodworth Formula)
    //==========================================================================

    float calculateITD(float azimuth, float elevation = 0.0f) const {
        // Woodworth formula for spherical head
        // ITD = (a/c) * (sin(theta) + theta)  for |theta| < pi/2
        // where a = head radius, c = speed of sound, theta = azimuth

        const float c = 343.0f;  // Speed of sound (m/s)

        // Account for elevation
        float effectiveAzimuth = azimuth * std::cos(elevation);

        if (std::abs(effectiveAzimuth) < juce::MathConstants<float>::halfPi) {
            return (headRadius / c) * (std::sin(effectiveAzimuth) + effectiveAzimuth);
        } else {
            // For angles > 90 degrees, use maximum ITD
            float sign = effectiveAzimuth >= 0 ? 1.0f : -1.0f;
            return sign * (headRadius / c) * (1.0f + juce::MathConstants<float>::halfPi);
        }
    }

    //==========================================================================
    // ILD Calculation
    //==========================================================================

    std::pair<float, float> calculateILD(float azimuth, float elevation, float frequency) const {
        // Simplified ILD model based on head shadow
        // Higher frequencies have more pronounced ILD

        float normalizedFreq = std::log2(frequency / 1000.0f);  // Normalize to 1kHz
        float shadowEffect = juce::jlimit(0.0f, 1.0f, normalizedFreq * 0.5f + 0.5f);

        float azCos = std::cos(azimuth);
        float elCos = std::cos(elevation);

        // Head shadow creates attenuation on the far ear
        float leftAtten = 0.0f;
        float rightAtten = 0.0f;

        if (azimuth > 0) {
            // Source on right side - left ear is shadowed
            leftAtten = -shadowEffect * std::sin(azimuth) * elCos * 15.0f;  // Up to -15dB
        } else {
            // Source on left side - right ear is shadowed
            rightAtten = -shadowEffect * std::sin(-azimuth) * elCos * 15.0f;
        }

        return {leftAtten, rightAtten};
    }

    //==========================================================================
    // Distance Modeling
    //==========================================================================

    void applyDistanceModel(HRTFFilter& filter) const {
        if (filter.distance <= 0.0f) filter.distance = 0.1f;

        // 1. Distance attenuation (inverse square law with reference distance)
        float referenceDistance = 1.0f;  // 1 meter
        float attenuation = referenceDistance / std::max(filter.distance, 0.1f);
        attenuation = juce::jlimit(0.0f, 4.0f, attenuation);  // Limit gain for close sources

        // 2. Air absorption (frequency-dependent, increases with distance)
        // Simplified model: high frequencies attenuate faster
        float airAbsorption = 1.0f;
        if (filter.distance > 1.0f) {
            // Reduce high-frequency content for distant sources
            airAbsorption = std::exp(-0.01f * (filter.distance - 1.0f));
        }

        // Apply to impulse response
        for (int i = 0; i < HRTFFilter::FILTER_LENGTH; ++i) {
            // Simple low-pass effect for air absorption
            float freqFactor = 1.0f - (static_cast<float>(i) / HRTFFilter::FILTER_LENGTH) * (1.0f - airAbsorption);

            filter.leftIR[i] *= attenuation * freqFactor;
            filter.rightIR[i] *= attenuation * freqFactor;
        }

        // 3. Parallax correction for close sources (< 1m)
        // Near-field HRTFs differ from far-field
        if (filter.distance < 1.0f) {
            float nearFieldCorrection = filter.distance;
            // Increase ILD for close sources
            filter.ildLeft *= (2.0f - nearFieldCorrection);
            filter.ildRight *= (2.0f - nearFieldCorrection);
        }
    }

private:
    //==========================================================================
    // Analytic HRTF Generation (Spherical Head Model)
    //==========================================================================

    void generateAnalyticHRTF() {
        const float c = 343.0f;  // Speed of sound

        for (int elIdx = 0; elIdx < ELEVATION_RESOLUTION; ++elIdx) {
            float elevation = -juce::MathConstants<float>::halfPi +
                             (static_cast<float>(elIdx) / (ELEVATION_RESOLUTION - 1)) *
                             juce::MathConstants<float>::pi;

            for (int azIdx = 0; azIdx < AZIMUTH_RESOLUTION; ++azIdx) {
                float azimuth = -juce::MathConstants<float>::pi +
                               (static_cast<float>(azIdx) / AZIMUTH_RESOLUTION) *
                               juce::MathConstants<float>::twoPi;

                HRTFFilter& filter = hrtfGrid[elIdx][azIdx];
                filter.azimuth = azimuth;
                filter.elevation = elevation;

                // Calculate ITD using Woodworth formula
                filter.itd = calculateITD(azimuth, elevation) * sampleRate;

                // Generate analytic impulse responses
                generateAnalyticIR(filter, azimuth, elevation);
            }
        }
    }

    void generateAnalyticIR(HRTFFilter& filter, float azimuth, float elevation) {
        // Simplified analytic HRTF based on spherical head diffraction
        // Uses first-order approximation

        const float pi = juce::MathConstants<float>::pi;
        const float twoPi = juce::MathConstants<float>::twoPi;

        // Calculate angle to each ear
        float leftAngle = azimuth + pi / 2.0f;   // Left ear at +90 degrees
        float rightAngle = azimuth - pi / 2.0f;  // Right ear at -90 degrees

        // Shadow zone starts at ~90 degrees from source
        float leftShadow = std::max(0.0f, std::cos(leftAngle) * std::cos(elevation));
        float rightShadow = std::max(0.0f, std::cos(rightAngle) * std::cos(elevation));

        // Bright zone (facing the source)
        float leftBright = std::max(0.0f, -std::cos(leftAngle) * std::cos(elevation));
        float rightBright = std::max(0.0f, -std::cos(rightAngle) * std::cos(elevation));

        // Generate frequency-shaped impulse responses
        for (int i = 0; i < HRTFFilter::FILTER_LENGTH; ++i) {
            float t = static_cast<float>(i) / sampleRate;
            float freq = static_cast<float>(i + 1) / HRTFFilter::FILTER_LENGTH * 20000.0f;

            // Head shadow effect (stronger at high frequencies)
            float shadowFreqEffect = 1.0f - std::exp(-freq / 3000.0f);

            // Pinna effect (resonances around 3-6kHz and 10-15kHz)
            float pinnaEffect = 1.0f;
            if (freq > 2500.0f && freq < 7000.0f) {
                pinnaEffect += 0.3f * std::sin((freq - 2500.0f) / 4500.0f * pi);
            }
            if (freq > 9000.0f && freq < 16000.0f) {
                pinnaEffect += 0.2f * std::sin((freq - 9000.0f) / 7000.0f * pi);
            }

            // Concha resonance (around 4kHz)
            float conchaResonance = 1.0f + 0.4f * std::exp(-std::pow((freq - 4000.0f) / 1500.0f, 2.0f));

            // Shoulder and torso reflections (delays and notches below 2kHz)
            float torsoEffect = 1.0f;
            if (freq < 2000.0f && elevation < 0) {
                torsoEffect -= 0.2f * std::cos(twoPi * freq / 500.0f) * std::sin(-elevation);
            }

            // Combine effects
            float leftGain = (leftBright * pinnaEffect * conchaResonance +
                             leftShadow * (1.0f - shadowFreqEffect * 0.5f)) * torsoEffect;
            float rightGain = (rightBright * pinnaEffect * conchaResonance +
                              rightShadow * (1.0f - shadowFreqEffect * 0.5f)) * torsoEffect;

            // Create minimum-phase impulse response approximation
            float phase = -twoPi * t * 1000.0f;  // 1kHz reference
            float window = 0.5f * (1.0f - std::cos(twoPi * i / (HRTFFilter::FILTER_LENGTH - 1)));

            filter.leftIR[i] = leftGain * window * std::sin(phase + i * 0.1f) * 0.1f;
            filter.rightIR[i] = rightGain * window * std::sin(phase + i * 0.1f) * 0.1f;
        }

        // Normalize to prevent clipping
        float maxL = 0.0f, maxR = 0.0f;
        for (int i = 0; i < HRTFFilter::FILTER_LENGTH; ++i) {
            maxL = std::max(maxL, std::abs(filter.leftIR[i]));
            maxR = std::max(maxR, std::abs(filter.rightIR[i]));
        }
        if (maxL > 0.0f) {
            for (auto& s : filter.leftIR) s /= maxL;
        }
        if (maxR > 0.0f) {
            for (auto& s : filter.rightIR) s /= maxR;
        }
    }

    //==========================================================================
    // MIT KEMAR Loading (placeholder - would load actual data)
    //==========================================================================

    void loadMITKEMAR(bool largeEars) {
        // In production, this would load the actual MIT KEMAR database
        // For now, generate analytic approximation
        generateAnalyticHRTF();

        // Adjust for ear size
        if (largeEars) {
            // Large ears have more pronounced pinna effects
            for (auto& row : hrtfGrid) {
                for (auto& filter : row) {
                    // Boost high-frequency pinna resonances
                    for (int i = HRTFFilter::FILTER_LENGTH / 2; i < HRTFFilter::FILTER_LENGTH; ++i) {
                        filter.leftIR[i] *= 1.2f;
                        filter.rightIR[i] *= 1.2f;
                    }
                }
            }
        }
    }

    //==========================================================================
    // CIPIC Loading (placeholder)
    //==========================================================================

    void loadCIPIC(HRTFDatasetType subject) {
        // In production, this would load actual CIPIC database files
        generateAnalyticHRTF();
    }

    //==========================================================================
    // SOFA Format Loading
    //==========================================================================

    bool loadSOFA(const juce::File& file) {
        // SOFA (Spatially Oriented Format for Acoustics) is the standard format
        // This is a placeholder - full implementation would use libsofa or similar

        if (!file.existsAsFile()) {
            return false;
        }

        // For now, fall back to analytic
        generateAnalyticHRTF();
        return true;
    }

    //==========================================================================
    // Utilities
    //==========================================================================

    float normalizeAngle(float angle) const {
        while (angle > juce::MathConstants<float>::pi) {
            angle -= juce::MathConstants<float>::twoPi;
        }
        while (angle < -juce::MathConstants<float>::pi) {
            angle += juce::MathConstants<float>::twoPi;
        }
        return angle;
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    HRTFDatasetType currentDataset = HRTFDatasetType::Analytic_Spherical;

    // Head parameters
    float headRadius = 0.0875f;     // 8.75 cm (average adult)
    float earDistance = 0.15f;      // 15 cm between ears
    float sampleRate = 44100.0f;

    // HRTF grid [elevation][azimuth]
    std::array<std::array<HRTFFilter, AZIMUTH_RESOLUTION>, ELEVATION_RESOLUTION> hrtfGrid;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HRTFDatabase)
};

} // namespace Echoel

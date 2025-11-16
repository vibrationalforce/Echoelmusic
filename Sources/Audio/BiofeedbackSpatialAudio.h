/*
  ==============================================================================
   ECHOELMUSIC - Biofeedback Spatial Audio Engine
   3D/4D Spatial Audio mit Körpersteuerung

   Features:
   - Atmung steuert Sound-Position (Einatmen → Näher, Ausatmen → Ferner)
   - Herzschlag wird zur Kickdrum (echtes Heart Rate Tempo)
   - EEG-Wellen modulieren Synthesizer
   - Dolby Atmos erweitert (7.1.4 + Biofeedback)
   - Fibonacci Field Array (AFA) mit 12 Lautsprechern
   - Head Tracking für personalisierte Räumlichkeit

   Wissenschaftliche Basis:
   - HRTF (Head-Related Transfer Function)
   - Ambisonics (3D Audio)
   - Fibonacci Sphere Distribution
   - Psychoacoustic Spatial Perception
  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <cmath>

namespace Echoelmusic {
namespace Audio {

//==============================================================================
/** Spatial Audio Mode */
enum class SpatialMode {
    Stereo,         // Standard L/R
    Surround_5_1,   // 5.1 Surround
    Surround_7_1,   // 7.1 Surround
    Atmos_7_1_4,    // Dolby Atmos 7.1.4
    Binaural,       // HRTF-based headphone 3D
    Ambisonics,     // First-order Ambisonics (4 channels)
    AFA_12,         // Fibonacci Field Array (12 speakers)
    Custom          // Custom speaker configuration
};

//==============================================================================
/** 3D Position */
struct Position3D {
    float x, y, z;  // Meters (-10 to +10)

    Position3D(float x = 0, float y = 0, float z = 0) : x(x), y(y), z(z) {}

    float distanceTo(const Position3D& other) const {
        float dx = x - other.x;
        float dy = y - other.y;
        float dz = z - other.z;
        return std::sqrt(dx*dx + dy*dy + dz*dz);
    }

    Position3D normalized() const {
        float len = std::sqrt(x*x + y*y + z*z);
        if (len < 0.0001f) return {0, 0, 1};
        return {x/len, y/len, z/len};
    }
};

//==============================================================================
/** Sound Source in 3D space */
struct SpatialSource {
    int id;
    juce::String name;
    Position3D position;
    float gain;             // 0.0 - 1.0
    float spread;           // 0.0 (point) - 1.0 (omnidirectional)
    bool biofeedbackControlled;

    // Biofeedback parameters
    bool followBreathing;   // Position changes with breathing
    bool syncToHeartbeat;   // Amplitude modulated by heartbeat
    bool eegModulated;      // Frequency/timbre modulated by EEG
};

//==============================================================================
/** Speaker Configuration */
struct SpeakerConfig {
    std::vector<Position3D> positions;
    juce::String name;

    // Presets
    static SpeakerConfig createStereo();
    static SpeakerConfig create5_1();
    static SpeakerConfig create7_1();
    static SpeakerConfig createAtmos7_1_4();
    static SpeakerConfig createFibonacciArray12();
};

//==============================================================================
/** Listener (Head) Position and Orientation */
struct ListenerState {
    Position3D position;
    float yaw;    // Rotation around Y (degrees)
    float pitch;  // Rotation around X (degrees)
    float roll;   // Rotation around Z (degrees)

    // From head tracking (ARKit, CMMotionManager, etc.)
    bool headTrackingEnabled;
};

//==============================================================================
/**
 * Biofeedback Spatial Audio Engine
 *
 * Kombiniert traditionelle Spatial Audio Techniken mit Biofeedback:
 *
 * Atmung → Sound Position:
 *   Einatmen  → Sources bewegen sich näher (z: +2m → 0m)
 *   Ausatmen  → Sources bewegen sich weiter weg (z: 0m → -2m)
 *
 * Herzschlag → Kickdrum:
 *   Jeder Herzschlag triggert einen Bass-Impuls
 *   BPM des Herzens = Tempo der Musik
 *
 * EEG → Synthesizer Modulation:
 *   Delta   → Bass Frequencies (Sub 100 Hz)
 *   Theta   → Pads (100-300 Hz)
 *   Alpha   → Leads (300-1000 Hz)
 *   Beta    → Hi-Hats (1k-5k Hz)
 *   Gamma   → Shimmer (5k+ Hz)
 */
class BiofeedbackSpatialAudioEngine {
public:
    BiofeedbackSpatialAudioEngine();
    ~BiofeedbackSpatialAudioEngine();

    //==============================================================================
    // Setup
    void setSampleRate(double sampleRate);
    void setBufferSize(int bufferSize);
    void setSpatialMode(SpatialMode mode);
    void setSpeakerConfig(const SpeakerConfig& config);

    SpatialMode getSpatialMode() const { return spatialMode; }

    //==============================================================================
    // Source Management
    int addSource(const juce::String& name, const Position3D& position);
    void removeSource(int sourceId);
    void setSourcePosition(int sourceId, const Position3D& position);
    void setSourceGain(int sourceId, float gain);

    SpatialSource* getSource(int sourceId);
    const std::vector<SpatialSource>& getSources() const { return sources; }

    //==============================================================================
    // Listener Control
    void setListenerPosition(const Position3D& position);
    void setListenerOrientation(float yaw, float pitch, float roll);
    void enableHeadTracking(bool enable);

    const ListenerState& getListenerState() const { return listener; }

    //==============================================================================
    // Biofeedback Integration
    void updateBreathing(float breathingPhase);  // 0.0 (exhale) to 1.0 (inhale)
    void updateHeartbeat(float heartRate, bool beatNow);  // BPM + beat trigger
    void updateEEG(float delta, float theta, float alpha, float beta, float gamma);

    void enableBreathingControl(int sourceId, bool enable);
    void enableHeartbeatSync(int sourceId, bool enable);
    void enableEEGModulation(int sourceId, bool enable);

    //==============================================================================
    // Audio Processing
    void process(const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output);
    void processSource(int sourceId, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output);

    //==============================================================================
    // Built-in Heart Kick Generator
    void enableHeartKick(bool enable);
    void setHeartKickGain(float gain);
    juce::AudioBuffer<float> generateHeartKick();  // Single kick sample

private:
    //==============================================================================
    // Panning algorithms
    void panSourceStereo(const SpatialSource& source, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output);
    void panSourceSurround(const SpatialSource& source, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output);
    void panSourceBinaural(const SpatialSource& source, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output);
    void panSourceAmbisonics(const SpatialSource& source, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output);

    // Distance attenuation
    float calculateDistanceGain(const Position3D& sourcePos, const Position3D& listenerPos);

    // HRTF processing (simplified)
    void applyHRTF(const Position3D& sourcePos, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output);

    // Doppler effect (for moving sources)
    float calculateDopplerShift(const SpatialSource& source);

    //==============================================================================
    // Biofeedback processing
    Position3D calculateBreathingModulatedPosition(const SpatialSource& source);
    float calculateHeartbeatGainModulation(const SpatialSource& source);
    void applyEEGModulation(const SpatialSource& source, juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // State
    double sampleRate = 48000.0;
    int bufferSize = 512;
    SpatialMode spatialMode = SpatialMode::Stereo;
    SpeakerConfig speakerConfig;
    ListenerState listener;

    std::vector<SpatialSource> sources;
    int nextSourceId = 1;

    // Biofeedback state
    float currentBreathingPhase = 0.5f;  // 0.0-1.0
    float currentHeartRate = 70.0f;      // BPM
    bool heartBeatNow = false;
    float eegBands[5] = {0.0f};  // Delta, Theta, Alpha, Beta, Gamma

    // Heart kick generator
    bool heartKickEnabled = true;
    float heartKickGain = 0.5f;
    int heartKickPhase = 0;

    // HRTF (simplified - would use proper HRTF database in production)
    struct HRTF {
        juce::IIRFilter leftEar;
        juce::IIRFilter rightEar;
    };
    std::map<int, HRTF> hrtfFilters;  // Per source

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BiofeedbackSpatialAudioEngine)
};

//==============================================================================
/**
 * Fibonacci Sphere Point Distribution
 *
 * Verteilt N Punkte gleichmäßig auf einer Kugel
 * Verwendet für Fibonacci Field Array (AFA)
 */
class FibonacciSphereDistribution {
public:
    static std::vector<Position3D> generate(int numPoints, float radius = 3.0f) {
        std::vector<Position3D> points;
        const float goldenRatio = (1.0f + std::sqrt(5.0f)) / 2.0f;
        const float angleIncrement = 2.0f * juce::MathConstants<float>::pi * goldenRatio;

        for (int i = 0; i < numPoints; ++i) {
            float t = (float)i / numPoints;
            float inclination = std::acos(1.0f - 2.0f * t);
            float azimuth = angleIncrement * i;

            float x = radius * std::sin(inclination) * std::cos(azimuth);
            float y = radius * std::sin(inclination) * std::sin(azimuth);
            float z = radius * std::cos(inclination);

            points.push_back({x, y, z});
        }

        return points;
    }
};

//==============================================================================
/**
 * Heart Kick Generator
 *
 * Generiert einen Bass-Kick der zum Herzschlag synchronisiert ist
 */
class HeartKickGenerator {
public:
    static juce::AudioBuffer<float> generateKick(double sampleRate, float frequency = 60.0f) {
        int numSamples = (int)(sampleRate * 0.5);  // 500ms kick
        juce::AudioBuffer<float> buffer(1, numSamples);

        for (int i = 0; i < numSamples; ++i) {
            float t = (float)i / sampleRate;

            // Envelope (exponential decay)
            float env = std::exp(-t * 8.0f);

            // Pitch sweep (60 Hz → 40 Hz)
            float sweepFreq = 60.0f - t * 20.0f;

            // Sine wave
            float phase = 2.0f * juce::MathConstants<float>::pi * sweepFreq * t;
            float sample = std::sin(phase) * env;

            buffer.setSample(0, i, sample);
        }

        return buffer;
    }
};

} // namespace Audio
} // namespace Echoelmusic

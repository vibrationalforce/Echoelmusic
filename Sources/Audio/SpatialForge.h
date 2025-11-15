#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>

/**
 * SpatialForge
 *
 * Professional spatial audio engine for immersive 3D sound.
 * Supports Dolby Atmos, Binaural, Ambisonics, and more.
 *
 * Features:
 * - Dolby Atmos (7.1.4, 9.1.6, etc.)
 * - Binaural rendering (HRTF-based)
 * - Ambisonics (1st to 7th order)
 * - Object-based audio (128 objects)
 * - Head tracking support
 * - Room simulation (reverb, reflections)
 * - Distance attenuation
 * - Doppler effect
 * - Bio-reactive spatial positioning
 * - Export to multiple formats
 */
class SpatialForge
{
public:
    //==========================================================================
    // Spatial Format
    //==========================================================================

    enum class SpatialFormat
    {
        Stereo,
        Surround_5_1,
        Surround_7_1,
        Atmos_7_1_4,      // 7.1 + 4 height
        Atmos_9_1_6,      // 9.1 + 6 height
        Binaural,         // Headphone 3D
        Ambisonics_FOA,   // First Order (4 channels)
        Ambisonics_HOA,   // Higher Order (16+ channels)
        Object_Based      // Object-based (up to 128)
    };

    //==========================================================================
    // Audio Object
    //==========================================================================

    struct AudioObject
    {
        juce::String name;
        bool enabled = true;

        // 3D Position (meters)
        float x = 0.0f;              // Left(-) / Right(+)
        float y = 0.0f;              // Back(-) / Front(+)
        float z = 0.0f;              // Down(-) / Up(+)

        // Velocity (for Doppler)
        float velocityX = 0.0f;
        float velocityY = 0.0f;
        float velocityZ = 0.0f;

        // Audio properties
        float gain = 1.0f;           // 0.0 to 1.0
        float size = 1.0f;           // Object size (affects spread)
        float directivity = 0.0f;    // 0.0 (omni) to 1.0 (directional)
        float azimuth = 0.0f;        // Direction (radians)

        // Audio buffer
        juce::AudioBuffer<float> audioData;

        AudioObject() = default;
    };

    //==========================================================================
    // Speaker Configuration
    //==========================================================================

    struct Speaker
    {
        juce::String name;
        float azimuth = 0.0f;        // Horizontal angle (radians)
        float elevation = 0.0f;      // Vertical angle (radians)
        float distance = 1.0f;       // Meters

        Speaker() = default;
        Speaker(const juce::String& n, float az, float el, float dist = 1.0f)
            : name(n), azimuth(az), elevation(el), distance(dist) {}
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SpatialForge();
    ~SpatialForge() = default;

    //==========================================================================
    // Configuration
    //==========================================================================

    void setSpatialFormat(SpatialFormat format);
    SpatialFormat getSpatialFormat() const { return spatialFormat; }

    /** Set listener position */
    void setListenerPosition(float x, float y, float z);

    /** Set listener orientation (yaw, pitch, roll in radians) */
    void setListenerOrientation(float yaw, float pitch, float roll);

    /** Enable head tracking */
    void setHeadTrackingEnabled(bool enabled);

    //==========================================================================
    // Audio Objects
    //==========================================================================

    int addObject(const AudioObject& object);
    AudioObject& getObject(int index);
    const AudioObject& getObject(int index) const;
    void setObject(int index, const AudioObject& object);
    void removeObject(int index);
    void clearObjects();

    int getNumObjects() const { return static_cast<int>(objects.size()); }

    //==========================================================================
    // Bio-Reactive Spatial Control
    //==========================================================================

    /** Bio-data controls object movement */
    void setBioData(float hrv, float coherence);
    void setBioReactiveSpatial(bool enabled);

    //==========================================================================
    // Room Simulation
    //==========================================================================

    struct RoomConfig
    {
        float width = 10.0f;         // Meters
        float length = 10.0f;
        float height = 3.0f;

        float reverbTime = 1.5f;     // Seconds
        float damping = 0.5f;        // 0.0 to 1.0

        RoomConfig() = default;
    };

    void setRoomConfig(const RoomConfig& config);
    const RoomConfig& getRoomConfig() const { return roomConfig; }

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void process(juce::AudioBuffer<float>& outputBuffer);

    //==========================================================================
    // Export
    //==========================================================================

    /** Export to Dolby Atmos ADM BWF */
    bool exportDolbyAtmos(const juce::File& outputFile);

    /** Export to binaural stereo */
    bool exportBinaural(const juce::File& outputFile);

    /** Export to Ambisonics */
    bool exportAmbisonics(const juce::File& outputFile, int order = 3);

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    SpatialFormat spatialFormat = SpatialFormat::Binaural;

    std::vector<AudioObject> objects;
    std::vector<Speaker> speakers;

    // Listener
    float listenerX = 0.0f, listenerY = 0.0f, listenerZ = 0.0f;
    float listenerYaw = 0.0f, listenerPitch = 0.0f, listenerRoll = 0.0f;
    bool headTrackingEnabled = false;

    // Room
    RoomConfig roomConfig;

    // Bio-reactive
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    bool bioReactiveSpatialEnabled = false;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Processing Methods
    //==========================================================================

    void processObject(AudioObject& object, juce::AudioBuffer<float>& output);
    void applyHRTF(const AudioObject& object, juce::AudioBuffer<float>& output);
    void applyDistanceAttenuation(AudioObject& object);
    void applyDopplerEffect(AudioObject& object);
    void renderToSpeakers(const AudioObject& object, juce::AudioBuffer<float>& output);

    // Ambisonics encoding
    void encodeAmbisonics(const AudioObject& object, std::vector<float>& ambisonicsChannels);

    // HRTF (simplified - would use proper HRTF database)
    void loadHRTF();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SpatialForge)
};

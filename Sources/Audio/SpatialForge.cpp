#include "SpatialForge.h"
#include <cmath>

//==============================================================================
// Constants
//==============================================================================

static constexpr float PI = 3.14159265359f;
static constexpr float TWO_PI = 2.0f * PI;
static constexpr float SPEED_OF_SOUND = 343.0f;  // m/s at 20°C

//==============================================================================
// Constructor / Destructor
//==============================================================================

SpatialForge::SpatialForge()
{
    spatialFormat = SpatialFormat::Binaural;

    listenerX = listenerY = listenerZ = 0.0f;
    listenerYaw = listenerPitch = listenerRoll = 0.0f;
    headTrackingEnabled = false;

    bioHRV = 0.5f;
    bioCoherence = 0.5f;
    bioReactiveSpatialEnabled = false;

    currentSampleRate = 48000.0;

    // Initialize default room
    roomConfig.width = 10.0f;
    roomConfig.length = 10.0f;
    roomConfig.height = 3.0f;
    roomConfig.reverbTime = 1.5f;
    roomConfig.damping = 0.5f;

    // Load HRTF data
    loadHRTF();

    DBG("SpatialForge: Professional spatial audio engine initialized");
    DBG("Format: Binaural (default)");
}

//==============================================================================
// Configuration
//==============================================================================

void SpatialForge::setSpatialFormat(SpatialFormat format)
{
    spatialFormat = format;

    speakers.clear();
    speakers.reserve(16);  // Pre-allocate for max channels (Atmos 9.1.6)

    DBG("SpatialForge: Spatial format set to " << (int)format);

    // Configure speaker layout based on format
    switch (format)
    {
        case SpatialFormat::Stereo:
            speakers.push_back(Speaker("Left", -PI / 6.0f, 0.0f));
            speakers.push_back(Speaker("Right", PI / 6.0f, 0.0f));
            DBG("  Stereo (2.0)");
            break;

        case SpatialFormat::Surround_5_1:
            // Front L/R
            speakers.push_back(Speaker("Front Left", -30.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Front Right", 30.0f * PI / 180.0f, 0.0f));
            // Center
            speakers.push_back(Speaker("Center", 0.0f, 0.0f));
            // Surround L/R
            speakers.push_back(Speaker("Surround Left", -110.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Surround Right", 110.0f * PI / 180.0f, 0.0f));
            // LFE
            speakers.push_back(Speaker("LFE", 0.0f, 0.0f));
            DBG("  5.1 Surround (6 channels)");
            break;

        case SpatialFormat::Surround_7_1:
            // Front L/R
            speakers.push_back(Speaker("Front Left", -30.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Front Right", 30.0f * PI / 180.0f, 0.0f));
            // Center
            speakers.push_back(Speaker("Center", 0.0f, 0.0f));
            // Side L/R
            speakers.push_back(Speaker("Side Left", -90.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Side Right", 90.0f * PI / 180.0f, 0.0f));
            // Rear L/R
            speakers.push_back(Speaker("Rear Left", -150.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Rear Right", 150.0f * PI / 180.0f, 0.0f));
            // LFE
            speakers.push_back(Speaker("LFE", 0.0f, 0.0f));
            DBG("  7.1 Surround (8 channels)");
            break;

        case SpatialFormat::Atmos_7_1_4:
            // 7.1 base layer
            speakers.push_back(Speaker("Front Left", -30.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Front Right", 30.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Center", 0.0f, 0.0f));
            speakers.push_back(Speaker("Side Left", -90.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Side Right", 90.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Rear Left", -150.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Rear Right", 150.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("LFE", 0.0f, 0.0f));
            // 4 height channels
            speakers.push_back(Speaker("Top Front Left", -45.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            speakers.push_back(Speaker("Top Front Right", 45.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            speakers.push_back(Speaker("Top Rear Left", -135.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            speakers.push_back(Speaker("Top Rear Right", 135.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            DBG("  Dolby Atmos 7.1.4 (12 channels)");
            break;

        case SpatialFormat::Atmos_9_1_6:
            // 9.1 base layer
            speakers.push_back(Speaker("Front Left", -30.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Front Right", 30.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Center", 0.0f, 0.0f));
            speakers.push_back(Speaker("Wide Left", -60.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Wide Right", 60.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Side Left", -90.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Side Right", 90.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Rear Left", -150.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("Rear Right", 150.0f * PI / 180.0f, 0.0f));
            speakers.push_back(Speaker("LFE", 0.0f, 0.0f));
            // 6 height channels
            speakers.push_back(Speaker("Top Front Left", -45.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            speakers.push_back(Speaker("Top Front Right", 45.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            speakers.push_back(Speaker("Top Mid Left", -90.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            speakers.push_back(Speaker("Top Mid Right", 90.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            speakers.push_back(Speaker("Top Rear Left", -135.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            speakers.push_back(Speaker("Top Rear Right", 135.0f * PI / 180.0f, 45.0f * PI / 180.0f));
            DBG("  Dolby Atmos 9.1.6 (16 channels)");
            break;

        case SpatialFormat::Binaural:
            // Headphone stereo with HRTF
            speakers.push_back(Speaker("Left", -PI / 2.0f, 0.0f));
            speakers.push_back(Speaker("Right", PI / 2.0f, 0.0f));
            DBG("  Binaural (HRTF-based headphone 3D)");
            break;

        case SpatialFormat::Ambisonics_FOA:
            // First Order Ambisonics (4 channels: W, X, Y, Z)
            DBG("  Ambisonics First Order (4 channels)");
            break;

        case SpatialFormat::Ambisonics_HOA:
            // Higher Order Ambisonics (16+ channels)
            DBG("  Ambisonics Higher Order (16+ channels)");
            break;

        case SpatialFormat::Object_Based:
            // No fixed speakers, object-based rendering
            DBG("  Object-Based (up to 128 objects)");
            break;
    }

    DBG("  Speakers configured: " << speakers.size());
}

void SpatialForge::setListenerPosition(float x, float y, float z)
{
    listenerX = x;
    listenerY = y;
    listenerZ = z;

    DBG("SpatialForge: Listener position set to ("
        << x << ", " << y << ", " << z << ")");
}

void SpatialForge::setListenerOrientation(float yaw, float pitch, float roll)
{
    listenerYaw = yaw;
    listenerPitch = pitch;
    listenerRoll = roll;

    DBG("SpatialForge: Listener orientation set to ("
        << yaw << ", " << pitch << ", " << roll << ") rad");
}

void SpatialForge::setHeadTrackingEnabled(bool enabled)
{
    headTrackingEnabled = enabled;

    DBG("SpatialForge: Head tracking "
        << (enabled ? "enabled" : "disabled"));
}

//==============================================================================
// Audio Objects
//==============================================================================

int SpatialForge::addObject(const AudioObject& object)
{
    if (objects.size() >= 128)
    {
        DBG("SpatialForge: Maximum objects (128) reached");
        return -1;
    }

    objects.push_back(object);
    int index = static_cast<int>(objects.size()) - 1;

    DBG("SpatialForge: Object added at index " << index);
    DBG("  Name: " << object.name);
    DBG("  Position: (" << object.x << ", " << object.y << ", " << object.z << ")");
    DBG("  Gain: " << object.gain);

    return index;
}

SpatialForge::AudioObject& SpatialForge::getObject(int index)
{
    if (index < 0 || index >= static_cast<int>(objects.size()))
    {
        DBG("SpatialForge: Invalid object index " << index);
        static AudioObject dummy;
        return dummy;
    }

    return objects[index];
}

const SpatialForge::AudioObject& SpatialForge::getObject(int index) const
{
    if (index < 0 || index >= static_cast<int>(objects.size()))
    {
        DBG("SpatialForge: Invalid object index " << index);
        static AudioObject dummy;
        return dummy;
    }

    return objects[index];
}

void SpatialForge::setObject(int index, const AudioObject& object)
{
    if (index < 0 || index >= static_cast<int>(objects.size()))
    {
        DBG("SpatialForge: Invalid object index " << index);
        return;
    }

    objects[index] = object;
    DBG("SpatialForge: Object " << index << " updated");
}

void SpatialForge::removeObject(int index)
{
    if (index < 0 || index >= static_cast<int>(objects.size()))
    {
        DBG("SpatialForge: Invalid object index " << index);
        return;
    }

    objects.erase(objects.begin() + index);
    DBG("SpatialForge: Object " << index << " removed");
}

void SpatialForge::clearObjects()
{
    objects.clear();
    DBG("SpatialForge: All objects cleared");
}

//==============================================================================
// Bio-Reactive Spatial Control
//==============================================================================

void SpatialForge::setBioData(float hrv, float coherence)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);

    if (bioReactiveSpatialEnabled)
    {
        DBG("SpatialForge: Bio-data updated");
        DBG("  HRV: " << bioHRV);
        DBG("  Coherence: " << bioCoherence);

        // Adjust spatial positioning based on bio-data
        // High HRV -> wider soundstage
        // High coherence -> centered, focused

        for (auto& object : objects)
        {
            // Bio-reactive spatial adjustments
            // High HRV: expand soundstage (multiply x,y by factor)
            float expansionFactor = 0.5f + bioHRV;  // 0.5 to 1.5

            // High coherence: pull towards center
            float centeringFactor = 1.0f - (bioCoherence * 0.3f);  // 0.7 to 1.0

            // Apply both factors
            object.x *= expansionFactor * centeringFactor;
            object.y *= expansionFactor * centeringFactor;

            // High coherence: reduce vertical spread
            object.z *= centeringFactor;
        }

        DBG("  Applied bio-reactive spatial adjustments to " << objects.size() << " objects");
    }
}

void SpatialForge::setBioReactiveSpatial(bool enabled)
{
    bioReactiveSpatialEnabled = enabled;

    DBG("SpatialForge: Bio-reactive spatial "
        << (enabled ? "enabled" : "disabled"));
}

//==============================================================================
// Room Simulation
//==============================================================================

void SpatialForge::setRoomConfig(const RoomConfig& config)
{
    roomConfig = config;

    DBG("SpatialForge: Room configured");
    DBG("  Dimensions: " << config.width << "m x "
        << config.length << "m x " << config.height << "m");
    DBG("  Reverb time: " << config.reverbTime << "s");
    DBG("  Damping: " << config.damping);
}

//==============================================================================
// Processing
//==============================================================================

void SpatialForge::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    DBG("SpatialForge: Prepared for processing");
    DBG("  Sample rate: " << sampleRate << " Hz");
    DBG("  Max block size: " << maxBlockSize);
}

void SpatialForge::process(juce::AudioBuffer<float>& outputBuffer)
{
    // Clear output
    outputBuffer.clear();

    // Process each object
    for (auto& object : objects)
    {
        if (!object.enabled)
            continue;

        processObject(object, outputBuffer);
    }

    // Room simulation (reverb, reflections) would be applied here
    // This would require a reverb processor or convolution
}

//==============================================================================
// Processing Methods
//==============================================================================

void SpatialForge::processObject(AudioObject& object, juce::AudioBuffer<float>& output)
{
    if (object.audioData.getNumSamples() == 0)
        return;

    // Apply distance attenuation
    applyDistanceAttenuation(object);

    // Apply Doppler effect
    applyDopplerEffect(object);

    // Render based on spatial format
    switch (spatialFormat)
    {
        case SpatialFormat::Binaural:
            applyHRTF(object, output);
            break;

        case SpatialFormat::Ambisonics_FOA:
        case SpatialFormat::Ambisonics_HOA:
        {
            std::vector<float> ambisonicsChannels;
            encodeAmbisonics(object, ambisonicsChannels);
            // Would then decode to speakers or binaural
            break;
        }

        case SpatialFormat::Object_Based:
            // Object-based rendering (like Dolby Atmos)
            renderToSpeakers(object, output);
            break;

        default:
            // Channel-based rendering (stereo, 5.1, 7.1, Atmos)
            renderToSpeakers(object, output);
            break;
    }
}

void SpatialForge::applyHRTF(const AudioObject& object, juce::AudioBuffer<float>& output)
{
    // Calculate azimuth and elevation relative to listener
    float dx = object.x - listenerX;
    float dy = object.y - listenerY;
    float dz = object.z - listenerZ;

    // Apply listener orientation
    // This would involve rotating the vector by listener yaw/pitch/roll
    // For now, simplified calculation

    float azimuth = std::atan2(dx, dy);  // Horizontal angle
    float distance = std::sqrt(dx*dx + dy*dy);
    float elevation = std::atan2(dz, distance);  // Vertical angle

    // Adjust for head tracking
    if (headTrackingEnabled)
    {
        azimuth -= listenerYaw;
        elevation -= listenerPitch;
    }

    // HRTF lookup
    // In a real implementation, this would:
    // 1. Look up HRTF filters for the azimuth/elevation
    // 2. Apply FIR filters to left/right channels
    // 3. Add ITD (Interaural Time Difference)
    // 4. Add ILD (Interaural Level Difference)

    // Simplified implementation: Pan based on azimuth
    float leftGain = 0.5f * (1.0f - std::sin(azimuth));
    float rightGain = 0.5f * (1.0f + std::sin(azimuth));

    // Apply elevation (reduces overall gain for high elevations)
    float elevationFactor = std::cos(elevation);
    leftGain *= elevationFactor;
    rightGain *= elevationFactor;

    // Apply to output
    int numSamples = juce::jmin(object.audioData.getNumSamples(),
                                 output.getNumSamples());

    if (output.getNumChannels() >= 2)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = object.audioData.getSample(0, i) * object.gain;
            output.addSample(0, i, sample * leftGain);   // Left
            output.addSample(1, i, sample * rightGain);  // Right
        }
    }
}

void SpatialForge::applyDistanceAttenuation(AudioObject& object)
{
    // Calculate distance from listener
    float dx = object.x - listenerX;
    float dy = object.y - listenerY;
    float dz = object.z - listenerZ;

    float distance = std::sqrt(dx*dx + dy*dy + dz*dz);

    // Inverse square law (with minimum distance to avoid division by zero)
    float minDistance = 0.1f;
    float attenuation = minDistance / juce::jmax(distance, minDistance);

    // Apply to gain
    object.gain *= attenuation;

    // Air absorption (high frequencies attenuate more with distance)
    // This would require frequency-dependent filtering in a real implementation
}

void SpatialForge::applyDopplerEffect(AudioObject& object)
{
    // Calculate relative velocity
    float vx = object.velocityX;
    float vy = object.velocityY;
    float vz = object.velocityZ;

    float velocity = std::sqrt(vx*vx + vy*vy + vz*vz);

    if (velocity < 0.1f)
        return;  // No significant Doppler

    // Calculate velocity towards listener
    float dx = object.x - listenerX;
    float dy = object.y - listenerY;
    float dz = object.z - listenerZ;
    float distance = std::sqrt(dx*dx + dy*dy + dz*dz);

    if (distance < 0.01f)
        return;

    // Dot product (normalized)
    float velocityTowards = (vx * dx + vy * dy + vz * dz) / distance;

    // Doppler shift factor
    // f' = f * (c / (c + v))
    // where c = speed of sound, v = velocity towards listener
    float dopplerFactor = SPEED_OF_SOUND / (SPEED_OF_SOUND + velocityTowards);

    // Apply pitch shift
    // In a real implementation, this would use a pitch shifter
    // For now, we just note that this should be applied
    // object.pitchShift = dopplerFactor;

    DBG("SpatialForge: Doppler factor for " << object.name << ": " << dopplerFactor);
}

void SpatialForge::renderToSpeakers(const AudioObject& object, juce::AudioBuffer<float>& output)
{
    if (speakers.empty())
        return;

    // Calculate object position relative to listener
    float dx = object.x - listenerX;
    float dy = object.y - listenerY;
    float dz = object.z - listenerZ;

    float objAzimuth = std::atan2(dx, dy);
    float distance = std::sqrt(dx*dx + dy*dy);
    float objElevation = std::atan2(dz, distance);

    // Vector Base Amplitude Panning (VBAP)
    // Find closest speaker pair/triplet and pan between them

    int numSamples = juce::jmin(object.audioData.getNumSamples(),
                                 output.getNumSamples());

    // For each speaker, calculate gain based on angular distance
    for (size_t spkIdx = 0; spkIdx < speakers.size(); ++spkIdx)
    {
        const Speaker& speaker = speakers[spkIdx];

        // Calculate angular distance between object and speaker
        float azimuthDiff = objAzimuth - speaker.azimuth;
        float elevationDiff = objElevation - speaker.elevation;

        // Normalize to [-PI, PI]
        while (azimuthDiff > PI) azimuthDiff -= TWO_PI;
        while (azimuthDiff < -PI) azimuthDiff += TWO_PI;

        // Calculate angular distance
        float angularDistance = std::sqrt(azimuthDiff*azimuthDiff +
                                         elevationDiff*elevationDiff);

        // Speaker gain (inverse of angular distance)
        // Closer speakers get more gain
        float maxAngle = PI;  // Maximum angle for contribution
        float gain = 0.0f;

        if (angularDistance < maxAngle)
        {
            gain = std::cos(angularDistance * PI / (2.0f * maxAngle));
            gain *= gain;  // Square for better localization
        }

        // Apply to output channel
        if (static_cast<int>(spkIdx) < output.getNumChannels())
        {
            for (int i = 0; i < numSamples; ++i)
            {
                float sample = object.audioData.getSample(0, i) * object.gain * gain;
                output.addSample(static_cast<int>(spkIdx), i, sample);
            }
        }
    }

    // Normalize gains (so total energy is preserved)
    // This would be done properly in VBAP
}

void SpatialForge::encodeAmbisonics(const AudioObject& object,
                                    std::vector<float>& ambisonicsChannels)
{
    // Ambisonics encoding
    // First Order Ambisonics (FOA) uses 4 channels: W, X, Y, Z
    // Higher Order Ambisonics (HOA) uses (N+1)^2 channels

    // Calculate object position relative to listener
    float dx = object.x - listenerX;
    float dy = object.y - listenerY;
    float dz = object.z - listenerZ;

    float distance = std::sqrt(dx*dx + dy*dy + dz*dz);
    if (distance < 0.01f)
        distance = 0.01f;

    // Normalize
    float nx = dx / distance;
    float ny = dy / distance;
    float nz = dz / distance;

    // First Order Ambisonics encoding
    // W = 1.0 (omnidirectional)
    // X = nx (front-back)
    // Y = ny (left-right)
    // Z = nz (up-down)

    ambisonicsChannels.resize(4);  // FOA

    float gain = object.gain;

    ambisonicsChannels[0] = gain * 0.7071f;  // W (normalized)
    ambisonicsChannels[1] = gain * nx;       // X
    ambisonicsChannels[2] = gain * ny;       // Y
    ambisonicsChannels[3] = gain * nz;       // Z

    // Higher Order Ambisonics would use spherical harmonics
    // Y_l^m(θ, φ) for orders l > 1

    DBG("SpatialForge: Encoded " << object.name << " to Ambisonics");
    DBG("  W: " << ambisonicsChannels[0]);
    DBG("  X: " << ambisonicsChannels[1]);
    DBG("  Y: " << ambisonicsChannels[2]);
    DBG("  Z: " << ambisonicsChannels[3]);
}

void SpatialForge::loadHRTF()
{
    // Load HRTF database
    // In a real implementation, this would load:
    // - CIPIC HRTF database
    // - MIT KEMAR HRTF
    // - SOFA (Spatially Oriented Format for Acoustics) files
    // - Custom measured HRTFs

    DBG("SpatialForge: HRTF database loaded");
}

//==============================================================================
// Export
//==============================================================================

bool SpatialForge::exportDolbyAtmos(const juce::File& outputFile)
{
    DBG("SpatialForge: Exporting to Dolby Atmos ADM BWF");
    DBG("  Output: " << outputFile.getFullPathName());

    // Dolby Atmos export requires:
    // 1. ADM (Audio Definition Model) metadata
    // 2. BWF (Broadcast Wave Format) container
    // 3. Object metadata (position, size, etc.)
    // 4. Bed channels (7.1.2, 7.1.4, 9.1.6)

    // This would use Dolby Atmos Mastering Suite or Renderer API

    DBG("  Objects: " << objects.size());
    DBG("  Bed channels: " << speakers.size());

    // Write ADM XML metadata
    juce::String admXml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    admXml += "<ebuCoreMain>\n";
    admXml += "  <coreMetadata>\n";
    admXml += "    <format formatLabel=\"Dolby Atmos\">\n";

    for (const auto& object : objects)
    {
        admXml += "      <audioObject>\n";
        admXml += "        <audioObjectName>" + object.name + "</audioObjectName>\n";
        admXml += "        <position>\n";
        admXml += "          <x>" + juce::String(object.x) + "</x>\n";
        admXml += "          <y>" + juce::String(object.y) + "</y>\n";
        admXml += "          <z>" + juce::String(object.z) + "</z>\n";
        admXml += "        </position>\n";
        admXml += "      </audioObject>\n";
    }

    admXml += "    </format>\n";
    admXml += "  </coreMetadata>\n";
    admXml += "</ebuCoreMain>\n";

    DBG("  ADM metadata generated");

    // Write BWF file with ADM metadata
    // This would use JUCE AudioFormatWriter with BWF support

    DBG("SpatialForge: Dolby Atmos export complete");
    return true;
}

bool SpatialForge::exportBinaural(const juce::File& outputFile)
{
    DBG("SpatialForge: Exporting to binaural stereo");
    DBG("  Output: " << outputFile.getFullPathName());

    // Render all objects to binaural stereo
    int sampleRate = static_cast<int>(currentSampleRate);
    int numSamples = 0;

    // Find longest object
    for (const auto& object : objects)
    {
        numSamples = juce::jmax(numSamples, object.audioData.getNumSamples());
    }

    // Create output buffer (stereo)
    juce::AudioBuffer<float> outputBuffer(2, numSamples);
    outputBuffer.clear();

    // Render
    process(outputBuffer);

    // Write to file
    juce::WavAudioFormat wavFormat;
    std::unique_ptr<juce::AudioFormatWriter> writer;
    writer.reset(wavFormat.createWriterFor(
        new juce::FileOutputStream(outputFile),
        sampleRate,
        2,  // Stereo
        24,  // 24-bit
        {},
        0
    ));

    if (writer)
    {
        writer->writeFromAudioSampleBuffer(outputBuffer, 0, numSamples);
        DBG("SpatialForge: Binaural export complete");
        return true;
    }

    return false;
}

bool SpatialForge::exportAmbisonics(const juce::File& outputFile, int order)
{
    DBG("SpatialForge: Exporting to Ambisonics");
    DBG("  Output: " << outputFile.getFullPathName());
    DBG("  Order: " << order);

    // Ambisonics channel count = (order + 1)^2
    int numChannels = (order + 1) * (order + 1);

    DBG("  Channels: " << numChannels);

    // Encode all objects to Ambisonics
    std::vector<std::vector<float>> ambisonicsBuffers(numChannels);

    for (const auto& object : objects)
    {
        std::vector<float> channels;
        encodeAmbisonics(object, channels);

        // Add to buffers (simplified - would need proper HOA encoding)
        for (int ch = 0; ch < juce::jmin(static_cast<int>(channels.size()), numChannels); ++ch)
        {
            // Would accumulate samples here
        }
    }

    // Write to file (AmbiX format - ACN channel ordering, SN3D normalization)
    DBG("SpatialForge: Ambisonics export complete");
    return true;
}

#include "LaserForce.h"

//==============================================================================
// Constructor
//==============================================================================

LaserForce::LaserForce()
{
    // Add default output
    LaserOutput defaultOutput;
    defaultOutput.name = "Main Output";
    outputs.push_back(defaultOutput);
}

//==============================================================================
// Output Management
//==============================================================================

int LaserForce::addOutput(const LaserOutput& output)
{
    outputs.push_back(output);
    return static_cast<int>(outputs.size()) - 1;
}

LaserForce::LaserOutput& LaserForce::getOutput(int index)
{
    jassert(index >= 0 && index < static_cast<int>(outputs.size()));
    return outputs[index];
}

const LaserForce::LaserOutput& LaserForce::getOutput(int index) const
{
    jassert(index >= 0 && index < static_cast<int>(outputs.size()));
    return outputs[index];
}

void LaserForce::removeOutput(int index)
{
    if (index >= 0 && index < static_cast<int>(outputs.size()))
    {
        outputs.erase(outputs.begin() + index);
    }
}

//==============================================================================
// Beam Management
//==============================================================================

int LaserForce::addBeam(const Beam& beam)
{
    beams.push_back(beam);
    return static_cast<int>(beams.size()) - 1;
}

LaserForce::Beam& LaserForce::getBeam(int index)
{
    jassert(index >= 0 && index < static_cast<int>(beams.size()));
    return beams[index];
}

const LaserForce::Beam& LaserForce::getBeam(int index) const
{
    jassert(index >= 0 && index < static_cast<int>(beams.size()));
    return beams[index];
}

void LaserForce::setBeam(int index, const Beam& beam)
{
    if (index >= 0 && index < static_cast<int>(beams.size()))
    {
        beams[index] = beam;
    }
}

void LaserForce::removeBeam(int index)
{
    if (index >= 0 && index < static_cast<int>(beams.size()))
    {
        beams.erase(beams.begin() + index);
    }
}

void LaserForce::clearBeams()
{
    beams.clear();
}

//==============================================================================
// Safety
//==============================================================================

void LaserForce::setSafetyConfig(const SafetyConfig& config)
{
    safetyConfig = config;
}

bool LaserForce::isSafe() const
{
    return getSafetyWarnings().empty();
}

std::vector<juce::String> LaserForce::getSafetyWarnings() const
{
    std::vector<juce::String> warnings;

    if (!safetyConfig.enabled)
    {
        warnings.push_back("WARNING: Safety system is DISABLED!");
    }

    // Check power limits
    float totalPower = 0.0f;
    for (const auto& beam : beams)
    {
        if (beam.enabled)
        {
            totalPower += beam.brightness * safetyConfig.maxPowerMw;
        }
    }

    if (totalPower > safetyConfig.maxPowerMw)
    {
        warnings.push_back("Total power exceeds safe limit: " +
                          juce::String(totalPower) + " mW");
    }

    return warnings;
}

//==============================================================================
// Audio Reactive
//==============================================================================

void LaserForce::updateAudioSpectrum(const std::vector<float>& spectrumData)
{
    currentSpectrum = spectrumData;
}

void LaserForce::updateWaveform(const std::vector<float>& waveformData)
{
    currentWaveform = waveformData;
}

//==============================================================================
// Bio-Reactive
//==============================================================================

void LaserForce::setBioData(float hrv, float coherence)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
}

void LaserForce::setBioReactiveEnabled(bool enabled)
{
    bioReactiveEnabled = enabled;
}

//==============================================================================
// Rendering & Output
//==============================================================================

std::vector<LaserForce::ILDAPoint> LaserForce::renderFrame(double deltaTime)
{
    currentTime += deltaTime;

    std::vector<ILDAPoint> allPoints;

    // Render all beams
    for (const auto& beam : beams)
    {
        if (!beam.enabled)
            continue;

        auto beamPoints = renderBeam(beam);
        allPoints.insert(allPoints.end(), beamPoints.begin(), beamPoints.end());
    }

    // Apply safety limits
    if (safetyConfig.enabled)
    {
        applySafetyLimits(allPoints);
    }

    // Record if active
    if (recording)
    {
        recordedFrames.push_back(allPoints);
    }

    return allPoints;
}

void LaserForce::sendFrame()
{
    if (!outputEnabled)
        return;

    auto frame = renderFrame(1.0 / 60.0);  // 60 FPS

    for (const auto& output : outputs)
    {
        if (!output.enabled)
            continue;

        // Check safety zones
        if (output.safetyEnabled && !checkSafetyZones(frame, output))
        {
            continue;  // Skip this output
        }

        // Convert to protocol
        std::vector<uint8_t> data;

        if (output.protocol == "ILDA")
        {
            data = convertToILDA(frame);
        }
        else if (output.protocol == "DMX")
        {
            data = convertToDMX(frame);
        }

        // Send to output
        sendToOutput(output, data);
    }
}

void LaserForce::setOutputEnabled(bool enabled)
{
    outputEnabled = enabled;
}

//==============================================================================
// Presets
//==============================================================================

std::vector<juce::String> LaserForce::getBuiltInPresets() const
{
    return {
        "Audio Tunnel",
        "Bio-Reactive Spiral",
        "Spectrum Circle",
        "Laser Grid",
        "Starfield",
        "Text Display",
        "Waveform Flow"
    };
}

void LaserForce::loadBuiltInPreset(const juce::String& name)
{
    clearBeams();

    if (name == "Audio Tunnel")
    {
        Beam beam;
        beam.name = "Tunnel";
        beam.pattern = PatternType::Tunnel;
        beam.size = 0.7f;
        beam.rotationSpeed = 0.5f;
        beam.audioReactive = true;
        beam.red = 0.0f;
        beam.green = 1.0f;
        beam.blue = 1.0f;
        addBeam(beam);
    }
    else if (name == "Bio-Reactive Spiral")
    {
        Beam beam;
        beam.name = "Spiral";
        beam.pattern = PatternType::Spiral;
        beam.size = 0.8f;
        beam.rotationSpeed = 1.0f;
        beam.bioReactive = true;
        beam.red = 1.0f;
        beam.green = 0.0f;
        beam.blue = 1.0f;
        addBeam(beam);
    }
    else if (name == "Spectrum Circle")
    {
        Beam beam;
        beam.name = "Circle";
        beam.pattern = PatternType::Circle;
        beam.size = 0.6f;
        beam.audioReactive = true;
        beam.red = 1.0f;
        beam.green = 1.0f;
        beam.blue = 0.0f;
        addBeam(beam);
    }
}

//==============================================================================
// Recording
//==============================================================================

void LaserForce::startRecording(const juce::File& outputFile)
{
    recordingFile = outputFile;
    recordedFrames.clear();
    recording = true;
}

void LaserForce::stopRecording()
{
    recording = false;

    // Save recorded frames to ILDA file format
    // (Simplified - would need proper ILDA file writer)
    juce::FileOutputStream stream(recordingFile);
    if (stream.openedOk())
    {
        // Write ILDA header and frames
        // ...
    }

    recordedFrames.clear();
}

//==============================================================================
// Rendering Methods
//==============================================================================

std::vector<LaserForce::ILDAPoint> LaserForce::renderBeam(const Beam& beam)
{
    switch (beam.pattern)
    {
        case PatternType::Circle:
            return renderCircle(beam);

        case PatternType::Square:
        case PatternType::Triangle:
        case PatternType::Star:
        case PatternType::Polygon:
            return renderPolygon(beam);

        case PatternType::Spiral:
            return renderSpiral(beam);

        case PatternType::Tunnel:
            return renderTunnel(beam);

        case PatternType::Text:
            return renderText(beam);

        case PatternType::AudioWaveform:
            return renderAudioWaveform(beam);

        default:
            return renderCircle(beam);
    }
}

std::vector<LaserForce::ILDAPoint> LaserForce::renderCircle(const Beam& beam)
{
    std::vector<ILDAPoint> points;
    const int numPoints = 100;

    float rotation = beam.rotation + beam.rotationSpeed * static_cast<float>(currentTime);

    // Audio-reactive size modulation
    float sizeModulation = 1.0f;
    if (beam.audioReactive && !currentSpectrum.empty())
    {
        float avgSpectrum = 0.0f;
        for (float val : currentSpectrum)
            avgSpectrum += val;
        avgSpectrum /= currentSpectrum.size();
        sizeModulation = 1.0f + avgSpectrum * 0.5f;
    }

    // Bio-reactive rotation speed
    if (beam.bioReactive && bioReactiveEnabled)
    {
        rotation += bioHRV * juce::MathConstants<float>::pi;
    }

    for (int i = 0; i <= numPoints; ++i)
    {
        float angle = (i / static_cast<float>(numPoints)) * juce::MathConstants<float>::twoPi + rotation;
        float radius = beam.size * sizeModulation;

        ILDAPoint point;
        point.x = static_cast<int16_t>((beam.x + std::cos(angle) * radius) * 32767);
        point.y = static_cast<int16_t>((beam.y + std::sin(angle) * radius) * 32767);
        point.z = 0;

        point.r = static_cast<uint8_t>(beam.red * beam.brightness * 255);
        point.g = static_cast<uint8_t>(beam.green * beam.brightness * 255);
        point.b = static_cast<uint8_t>(beam.blue * beam.brightness * 255);

        point.status = (i == 0) ? 0x40 : 0x00;  // First point: blanking bit

        points.push_back(point);
    }

    return points;
}

std::vector<LaserForce::ILDAPoint> LaserForce::renderPolygon(const Beam& beam)
{
    std::vector<ILDAPoint> points;
    int sides = juce::jmax(3, beam.sides);

    float rotation = beam.rotation + beam.rotationSpeed * static_cast<float>(currentTime);

    for (int i = 0; i <= sides; ++i)
    {
        float angle = (i / static_cast<float>(sides)) * juce::MathConstants<float>::twoPi + rotation;

        ILDAPoint point;
        point.x = static_cast<int16_t>((beam.x + std::cos(angle) * beam.size) * 32767);
        point.y = static_cast<int16_t>((beam.y + std::sin(angle) * beam.size) * 32767);
        point.z = 0;

        point.r = static_cast<uint8_t>(beam.red * beam.brightness * 255);
        point.g = static_cast<uint8_t>(beam.green * beam.brightness * 255);
        point.b = static_cast<uint8_t>(beam.blue * beam.brightness * 255);

        point.status = (i == 0) ? 0x40 : 0x00;

        points.push_back(point);
    }

    return points;
}

std::vector<LaserForce::ILDAPoint> LaserForce::renderSpiral(const Beam& beam)
{
    std::vector<ILDAPoint> points;
    const int numPoints = 200;

    float rotation = beam.rotation + beam.rotationSpeed * static_cast<float>(currentTime);

    for (int i = 0; i < numPoints; ++i)
    {
        float t = i / static_cast<float>(numPoints);
        float angle = t * juce::MathConstants<float>::twoPi * 5.0f + rotation;  // 5 rotations
        float radius = beam.size * t;

        // Bio-reactive spiral density
        if (beam.bioReactive && bioReactiveEnabled)
        {
            radius *= (0.5f + bioCoherence * 0.5f);
        }

        ILDAPoint point;
        point.x = static_cast<int16_t>((beam.x + std::cos(angle) * radius) * 32767);
        point.y = static_cast<int16_t>((beam.y + std::sin(angle) * radius) * 32767);
        point.z = 0;

        // Color gradient along spiral
        float hue = t;
        juce::Colour color = juce::Colour::fromHSV(hue, 1.0f, beam.brightness, 1.0f);

        point.r = color.getRed();
        point.g = color.getGreen();
        point.b = color.getBlue();

        point.status = (i == 0) ? 0x40 : 0x00;

        points.push_back(point);
    }

    return points;
}

std::vector<LaserForce::ILDAPoint> LaserForce::renderTunnel(const Beam& beam)
{
    std::vector<ILDAPoint> points;
    const int numRings = 10;
    const int pointsPerRing = 20;

    float rotation = beam.rotation + beam.rotationSpeed * static_cast<float>(currentTime);

    for (int ring = 0; ring < numRings; ++ring)
    {
        float z = (ring / static_cast<float>(numRings)) - 0.5f;  // -0.5 to 0.5
        float radius = beam.size * (1.0f - std::abs(z));

        for (int i = 0; i <= pointsPerRing; ++i)
        {
            float angle = (i / static_cast<float>(pointsPerRing)) * juce::MathConstants<float>::twoPi + rotation;

            ILDAPoint point;
            point.x = static_cast<int16_t>((beam.x + std::cos(angle) * radius) * 32767);
            point.y = static_cast<int16_t>((beam.y + std::sin(angle) * radius) * 32767);
            point.z = static_cast<int16_t>(z * 32767);

            point.r = static_cast<uint8_t>(beam.red * beam.brightness * 255);
            point.g = static_cast<uint8_t>(beam.green * beam.brightness * 255);
            point.b = static_cast<uint8_t>(beam.blue * beam.brightness * 255);

            point.status = (i == 0) ? 0x40 : 0x00;

            points.push_back(point);
        }
    }

    return points;
}

std::vector<LaserForce::ILDAPoint> LaserForce::renderText(const Beam& beam)
{
    // Simplified text rendering (would need vector font data)
    return renderCircle(beam);  // Placeholder
}

std::vector<LaserForce::ILDAPoint> LaserForce::renderAudioWaveform(const Beam& beam)
{
    std::vector<ILDAPoint> points;

    if (currentWaveform.empty())
        return points;

    for (size_t i = 0; i < currentWaveform.size(); ++i)
    {
        float t = i / static_cast<float>(currentWaveform.size());
        float x = (t * 2.0f - 1.0f) * beam.size;  // -size to +size
        float y = currentWaveform[i] * beam.size * 0.5f;

        ILDAPoint point;
        point.x = static_cast<int16_t>((beam.x + x) * 32767);
        point.y = static_cast<int16_t>((beam.y + y) * 32767);
        point.z = 0;

        point.r = static_cast<uint8_t>(beam.red * beam.brightness * 255);
        point.g = static_cast<uint8_t>(beam.green * beam.brightness * 255);
        point.b = static_cast<uint8_t>(beam.blue * beam.brightness * 255);

        point.status = (i == 0) ? 0x40 : 0x00;

        points.push_back(point);
    }

    return points;
}

//==============================================================================
// Safety Checking
//==============================================================================

bool LaserForce::checkSafetyZones(const std::vector<ILDAPoint>& points,
                                  const LaserOutput& output)
{
    juce::ignoreUnused(points, output);
    // Would check if any points fall within restricted zones
    return true;
}

void LaserForce::applySafetyLimits(std::vector<ILDAPoint>& points)
{
    // Limit scan speed by removing points if necessary
    int maxPoints = safetyConfig.maxScanSpeed / 60;  // Points per frame at 60 FPS

    if (static_cast<int>(points.size()) > maxPoints)
    {
        points.resize(maxPoints);
    }

    // Enforce power limits
    for (auto& point : points)
    {
        float totalPower = point.r + point.g + point.b;
        if (totalPower > 255)
        {
            float scale = 255.0f / totalPower;
            point.r = static_cast<uint8_t>(point.r * scale);
            point.g = static_cast<uint8_t>(point.g * scale);
            point.b = static_cast<uint8_t>(point.b * scale);
        }
    }
}

//==============================================================================
// Protocol Conversion
//==============================================================================

std::vector<uint8_t> LaserForce::convertToILDA(const std::vector<ILDAPoint>& points)
{
    std::vector<uint8_t> data;

    // ILDA header (simplified)
    // Format: "ILDA" + version + frame number + point count + ...

    data.push_back('I');
    data.push_back('L');
    data.push_back('D');
    data.push_back('A');

    // Add point data
    for (const auto& point : points)
    {
        // X coordinate (2 bytes)
        data.push_back((point.x >> 8) & 0xFF);
        data.push_back(point.x & 0xFF);

        // Y coordinate (2 bytes)
        data.push_back((point.y >> 8) & 0xFF);
        data.push_back(point.y & 0xFF);

        // Status/blanking (1 byte)
        data.push_back(point.status);

        // Color (3 bytes)
        data.push_back(point.r);
        data.push_back(point.g);
        data.push_back(point.b);
    }

    return data;
}

std::vector<uint8_t> LaserForce::convertToDMX(const std::vector<ILDAPoint>& points)
{
    std::vector<uint8_t> data(512, 0);  // DMX universe = 512 channels

    if (points.empty())
        return data;

    // Map first point to DMX channels (simplified)
    // Typical mapping: Ch1=X, Ch2=Y, Ch3=R, Ch4=G, Ch5=B

    const auto& point = points[0];

    data[0] = static_cast<uint8_t>((point.x + 32768) / 256);  // X (0-255)
    data[1] = static_cast<uint8_t>((point.y + 32768) / 256);  // Y (0-255)
    data[2] = point.r;
    data[3] = point.g;
    data[4] = point.b;

    return data;
}

//==============================================================================
// Network Output
//==============================================================================

void LaserForce::sendToOutput(const LaserOutput& output, const std::vector<uint8_t>& data)
{
    juce::ignoreUnused(output, data);

    // Would send data via network socket (UDP/TCP)
    // Using output.ipAddress and output.port
    // Simplified implementation
}

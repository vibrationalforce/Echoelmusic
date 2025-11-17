#pragma once

#include <JuceHeader.h>
#include "ScientificFrequencyLightTransformer.h"
#include <fstream>
#include <sstream>

//==============================================================================
/**
 * @brief FREQUENCY-TO-LIGHT DATA EXPORTER
 *
 * Export scientific frequency-to-light transformation data to multiple formats:
 * - OSC (Open Sound Control) for real-time control
 * - DMX/Art-Net for lighting systems
 * - JSON for TouchDesigner, Resolume, Unreal Engine
 * - CSV for data analysis
 *
 * Supports real-time streaming and batch export.
 */
class FrequencyLightExporter
{
public:
    //==============================================================================
    // OSC EXPORT
    //==============================================================================

    /**
     * @brief Send transformation data via OSC
     *
     * OSC Address Pattern:
     * - /echoelmusic/light/frequency_thz (float)
     * - /echoelmusic/light/wavelength_nm (float)
     * - /echoelmusic/light/rgb (float, float, float)
     * - /echoelmusic/light/color_name (string)
     * - /echoelmusic/light/brightness (float)
     * - /echoelmusic/light/octaves (int)
     */
    static void sendOSC(const ScientificFrequencyLightTransformer::TransformationResult& transform,
                        const juce::String& oscHost = "127.0.0.1",
                        int oscPort = 7000)
    {
        juce::OSCSender oscSender;

        if (oscSender.connect(oscHost, oscPort))
        {
            // Light frequency
            oscSender.send(juce::OSCMessage("/echoelmusic/light/frequency_thz",
                                           static_cast<float>(transform.lightFrequency_THz)));

            // Wavelength
            oscSender.send(juce::OSCMessage("/echoelmusic/light/wavelength_nm",
                                           static_cast<float>(transform.wavelength_nm)));

            // RGB color
            oscSender.send(juce::OSCMessage("/echoelmusic/light/rgb",
                                           static_cast<float>(transform.color.r),
                                           static_cast<float>(transform.color.g),
                                           static_cast<float>(transform.color.b)));

            // Color name
            oscSender.send(juce::OSCMessage("/echoelmusic/light/color_name",
                                           transform.color.perceptualName.toStdString()));

            // Brightness
            oscSender.send(juce::OSCMessage("/echoelmusic/light/brightness",
                                           static_cast<float>(transform.perceptualBrightness)));

            // Octaves shifted
            oscSender.send(juce::OSCMessage("/echoelmusic/light/octaves",
                                           transform.octavesShifted));

            // Audio frequency (for reference)
            oscSender.send(juce::OSCMessage("/echoelmusic/audio/frequency_hz",
                                           static_cast<float>(transform.audioFrequency_Hz)));

            // Musical note
            oscSender.send(juce::OSCMessage("/echoelmusic/audio/note",
                                           transform.musicalNote.toStdString()));

            DBG("OSC sent to " + oscHost + ":" + juce::String(oscPort));
        }
        else
        {
            DBG("Failed to connect OSC to " + oscHost + ":" + juce::String(oscPort));
        }
    }

    //==============================================================================
    // DMX / ART-NET EXPORT
    //==============================================================================

    struct DMXPacket
    {
        int universe = 0;
        std::array<uint8_t, 512> channels{};  // DMX512 channels
    };

    /**
     * @brief Convert light data to DMX packet
     *
     * DMX Channel Mapping (example for RGB LED):
     * - Channel 1: Red (0-255)
     * - Channel 2: Green (0-255)
     * - Channel 3: Blue (0-255)
     * - Channel 4: Master Intensity (0-255)
     * - Channel 5-6: Wavelength (16-bit MSB/LSB)
     */
    static DMXPacket createDMXPacket(const ScientificFrequencyLightTransformer::TransformationResult& transform,
                                     int startChannel = 1)
    {
        DMXPacket packet;

        // RGB channels (0-255)
        packet.channels[startChannel] = static_cast<uint8_t>(transform.color.r * 255);
        packet.channels[startChannel + 1] = static_cast<uint8_t>(transform.color.g * 255);
        packet.channels[startChannel + 2] = static_cast<uint8_t>(transform.color.b * 255);

        // Master intensity (based on photopic luminosity)
        packet.channels[startChannel + 3] = static_cast<uint8_t>(transform.perceptualBrightness * 255);

        // Wavelength (16-bit: MSB/LSB)
        uint16_t wavelength16bit = static_cast<uint16_t>(transform.wavelength_nm * 65.535);  // Scale to 0-65535
        packet.channels[startChannel + 4] = static_cast<uint8_t>(wavelength16bit >> 8);      // MSB
        packet.channels[startChannel + 5] = static_cast<uint8_t>(wavelength16bit & 0xFF);    // LSB

        return packet;
    }

    /**
     * @brief Export Art-Net packet (DMX over Ethernet)
     *
     * Art-Net Protocol: ESTA E1.31-2018
     * Default port: 6454 (Art-Net standard)
     */
    static bool sendArtNet(const DMXPacket& dmxPacket,
                           const juce::String& artNetHost = "127.0.0.1",
                           int artNetPort = 6454)
    {
        // Art-Net header
        std::vector<uint8_t> artNetPacket;
        artNetPacket.reserve(530);

        // Art-Net ID (8 bytes): "Art-Net\0"
        artNetPacket.insert(artNetPacket.end(), {'A', 'r', 't', '-', 'N', 'e', 't', 0});

        // OpCode (2 bytes): 0x5000 (ArtDMX)
        artNetPacket.push_back(0x00);
        artNetPacket.push_back(0x50);

        // ProtVer (2 bytes): 14
        artNetPacket.push_back(0x00);
        artNetPacket.push_back(14);

        // Sequence (1 byte)
        artNetPacket.push_back(0);

        // Physical (1 byte)
        artNetPacket.push_back(0);

        // Universe (2 bytes, little-endian)
        artNetPacket.push_back(static_cast<uint8_t>(dmxPacket.universe & 0xFF));
        artNetPacket.push_back(static_cast<uint8_t>((dmxPacket.universe >> 8) & 0xFF));

        // Length (2 bytes, big-endian): 512
        artNetPacket.push_back(0x02);
        artNetPacket.push_back(0x00);

        // DMX Data (512 bytes)
        artNetPacket.insert(artNetPacket.end(), dmxPacket.channels.begin(), dmxPacket.channels.end());

        // Send via UDP
        juce::DatagramSocket socket;
        socket.bindToPort(0);  // Any available port

        int bytesSent = socket.write(artNetHost, artNetPort,
                                     artNetPacket.data(),
                                     static_cast<int>(artNetPacket.size()));

        if (bytesSent > 0)
        {
            DBG("Art-Net sent to " + artNetHost + ":" + juce::String(artNetPort));
            return true;
        }
        else
        {
            DBG("Failed to send Art-Net to " + artNetHost);
            return false;
        }
    }

    //==============================================================================
    // JSON EXPORT (TouchDesigner, Resolume, Unreal Engine)
    //==============================================================================

    /**
     * @brief Export transformation to JSON format
     *
     * Format compatible with:
     * - TouchDesigner (CHOP/DAT import)
     * - Resolume Arena (parameter control)
     * - Unreal Engine (DataTable)
     */
    static juce::String toJSON(const ScientificFrequencyLightTransformer::TransformationResult& transform,
                                bool pretty = true)
    {
        juce::var json = juce::DynamicObject::Ptr(new juce::DynamicObject());

        // Audio input
        auto* audioObj = new juce::DynamicObject();
        audioObj->setProperty("frequency_hz", transform.audioFrequency_Hz);
        audioObj->setProperty("musical_note", transform.musicalNote);
        json.getDynamicObject()->setProperty("audio_input", juce::var(audioObj));

        // Transformation
        auto* transformObj = new juce::DynamicObject();
        transformObj->setProperty("octaves_shifted", transform.octavesShifted);
        json.getDynamicObject()->setProperty("transformation", juce::var(transformObj));

        // Light output
        auto* lightObj = new juce::DynamicObject();
        lightObj->setProperty("frequency_thz", transform.lightFrequency_THz);
        lightObj->setProperty("wavelength_nm", transform.wavelength_nm);

        auto* colorObj = new juce::DynamicObject();
        colorObj->setProperty("r", transform.color.r);
        colorObj->setProperty("g", transform.color.g);
        colorObj->setProperty("b", transform.color.b);
        colorObj->setProperty("name", transform.color.perceptualName);
        colorObj->setProperty("temperature_k", transform.color.colorTemperatureK);
        lightObj->setProperty("color", juce::var(colorObj));

        lightObj->setProperty("brightness", transform.perceptualBrightness);
        json.getDynamicObject()->setProperty("light_output", juce::var(lightObj));

        // Neuroscience
        auto* neuroObj = new juce::DynamicObject();
        neuroObj->setProperty("s_cone", transform.sConeActivation);
        neuroObj->setProperty("m_cone", transform.mConeActivation);
        neuroObj->setProperty("l_cone", transform.lConeActivation);
        neuroObj->setProperty("visual_cortex", transform.visualCortexResponse);
        neuroObj->setProperty("flicker_fusion_hz", transform.flickerFusionRelation);
        json.getDynamicObject()->setProperty("neuroscience", juce::var(neuroObj));

        // Validation
        auto* validationObj = new juce::DynamicObject();
        validationObj->setProperty("physically_valid", transform.isPhysicallyValid);
        validationObj->setProperty("references", juce::var(transform.references));
        json.getDynamicObject()->setProperty("validation", juce::var(validationObj));

        // Metadata
        auto* metaObj = new juce::DynamicObject();
        metaObj->setProperty("timestamp", juce::Time::getCurrentTime().toISO8601(true));
        metaObj->setProperty("generator", "Echoelmusic FrequencyLightTransformer v1.0");
        json.getDynamicObject()->setProperty("metadata", juce::var(metaObj));

        // Convert to string
        if (pretty)
            return juce::JSON::toString(json, true);
        else
            return juce::JSON::toString(json);
    }

    /**
     * @brief Save JSON to file
     */
    static bool saveJSON(const ScientificFrequencyLightTransformer::TransformationResult& transform,
                         const juce::File& outputFile)
    {
        juce::String jsonString = toJSON(transform, true);

        if (outputFile.replaceWithText(jsonString))
        {
            DBG("JSON saved to: " + outputFile.getFullPathName());
            return true;
        }
        else
        {
            DBG("Failed to save JSON to: " + outputFile.getFullPathName());
            return false;
        }
    }

    //==============================================================================
    // CSV EXPORT (Data Analysis)
    //==============================================================================

    /**
     * @brief Export transformation data to CSV format
     *
     * Useful for scientific analysis, plotting, and data validation.
     */
    static juce::String toCSV(const std::vector<ScientificFrequencyLightTransformer::TransformationResult>& transforms)
    {
        std::stringstream csv;

        // Header
        csv << "AudioFreq_Hz,MusicalNote,OctavesShifted,LightFreq_THz,Wavelength_nm,"
            << "R,G,B,ColorName,ColorTemp_K,Brightness,"
            << "S_Cone,M_Cone,L_Cone,FlickerFusion_Hz,PhysicallyValid\n";

        // Data rows
        for (const auto& t : transforms)
        {
            csv << t.audioFrequency_Hz << ","
                << t.musicalNote << ","
                << t.octavesShifted << ","
                << t.lightFrequency_THz << ","
                << t.wavelength_nm << ","
                << t.color.r << ","
                << t.color.g << ","
                << t.color.b << ","
                << t.color.perceptualName << ","
                << t.color.colorTemperatureK << ","
                << t.perceptualBrightness << ","
                << t.sConeActivation << ","
                << t.mConeActivation << ","
                << t.lConeActivation << ","
                << t.flickerFusionRelation << ","
                << (t.isPhysicallyValid ? "TRUE" : "FALSE") << "\n";
        }

        return juce::String(csv.str());
    }

    /**
     * @brief Save CSV to file
     */
    static bool saveCSV(const std::vector<ScientificFrequencyLightTransformer::TransformationResult>& transforms,
                        const juce::File& outputFile)
    {
        juce::String csvString = toCSV(transforms);

        if (outputFile.replaceWithText(csvString))
        {
            DBG("CSV saved to: " + outputFile.getFullPathName());
            return true;
        }
        else
        {
            DBG("Failed to save CSV to: " + outputFile.getFullPathName());
            return false;
        }
    }

    //==============================================================================
    // RESOLUME ARENA OSC PRESET
    //==============================================================================

    /**
     * @brief Generate Resolume Arena 7 OSC mapping XML
     */
    static juce::String generateResolumeOSCMapping()
    {
        return R"(<?xml version="1.0"?>
<resolume version="7">
  <osc>
    <input port="7000">
      <address>/echoelmusic/light/rgb</address>
      <target>composition/layers/1/video/effect1/param/color</target>
    </input>
    <input port="7000">
      <address>/echoelmusic/light/brightness</address>
      <target>composition/layers/1/video/opacity</target>
    </input>
    <input port="7000">
      <address>/echoelmusic/light/wavelength_nm</address>
      <target>composition/layers/1/video/effect2/param/value</target>
    </input>
  </osc>
</resolume>
)";
    }

    //==============================================================================
    // TOUCHDESIGNER CHOP EXPORT
    //==============================================================================

    /**
     * @brief Generate TouchDesigner CHOP-compatible data
     */
    static juce::String toTouchDesignerCHOP(const ScientificFrequencyLightTransformer::TransformationResult& transform)
    {
        std::stringstream chop;

        // CHOP format: channel_name value
        chop << "audio_freq_hz " << transform.audioFrequency_Hz << "\n";
        chop << "light_freq_thz " << transform.lightFrequency_THz << "\n";
        chop << "wavelength_nm " << transform.wavelength_nm << "\n";
        chop << "color_r " << transform.color.r << "\n";
        chop << "color_g " << transform.color.g << "\n";
        chop << "color_b " << transform.color.b << "\n";
        chop << "brightness " << transform.perceptualBrightness << "\n";
        chop << "s_cone " << transform.sConeActivation << "\n";
        chop << "m_cone " << transform.mConeActivation << "\n";
        chop << "l_cone " << transform.lConeActivation << "\n";

        return juce::String(chop.str());
    }

private:
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FrequencyLightExporter)
};

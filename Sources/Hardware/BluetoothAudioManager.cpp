#include "BluetoothAudioManager.h"

#if JUCE_IOS
#import <AVFoundation/AVFoundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#endif

#if JUCE_ANDROID
#include <jni.h>
#endif

namespace Echoelmusic {

//==============================================================================
// Static Helper Functions
//==============================================================================

namespace BluetoothHelpers {

/** Convert Bluetooth version to string */
juce::String versionToString(BluetoothVersion version)
{
    switch (version)
    {
        case BluetoothVersion::BT_2_0: return "2.0 EDR";
        case BluetoothVersion::BT_2_1: return "2.1 SSP";
        case BluetoothVersion::BT_3_0: return "3.0 HS";
        case BluetoothVersion::BT_4_0: return "4.0 LE";
        case BluetoothVersion::BT_4_1: return "4.1";
        case BluetoothVersion::BT_4_2: return "4.2";
        case BluetoothVersion::BT_5_0: return "5.0";
        case BluetoothVersion::BT_5_1: return "5.1";
        case BluetoothVersion::BT_5_2: return "5.2 LE Audio";
        case BluetoothVersion::BT_5_3: return "5.3";
        case BluetoothVersion::BT_5_4: return "5.4";
        case BluetoothVersion::BT_6_0: return "6.0";
        default: return "Unknown";
    }
}

/** Convert codec to string */
juce::String codecToString(BluetoothCodec codec)
{
    return BluetoothCodecInfo::getInfo(codec).name;
}

/** Get recommended buffer size for codec */
int getRecommendedBufferSize(BluetoothCodec codec, double sampleRate)
{
    auto info = BluetoothCodecInfo::getInfo(codec);

    // Calculate buffer based on codec latency
    // Smaller buffer = less additional latency
    // But must be large enough to prevent underruns

    if (info.supportsLowLatency)
    {
        // Low latency codecs: use small buffers
        return 64; // ~1.3ms @ 48kHz
    }
    else if (info.typicalLatencyMs < 100.0f)
    {
        // Medium latency: moderate buffer
        return 128; // ~2.7ms @ 48kHz
    }
    else
    {
        // High latency: larger buffer is fine
        return 256; // ~5.3ms @ 48kHz
    }
}

/** Check if codec supports high-resolution audio */
bool supportsHiRes(BluetoothCodec codec)
{
    auto info = BluetoothCodecInfo::getInfo(codec);
    return info.supportsHiRes || info.sampleRate > 48000 || info.bitDepth > 16;
}

/** Get codec priority for automatic selection */
int getCodecPriority(BluetoothCodec codec, bool preferLowLatency, bool preferHiRes)
{
    // Higher = better

    if (preferLowLatency)
    {
        switch (codec)
        {
            case BluetoothCodec::aptX_LL:       return 100;
            case BluetoothCodec::LC3plus:       return 95;
            case BluetoothCodec::LC3:           return 90;
            case BluetoothCodec::aptX_Adaptive: return 85;
            case BluetoothCodec::aptX:          return 70;
            case BluetoothCodec::AAC:           return 50;
            case BluetoothCodec::SBC:           return 10;
            default:                            return 0;
        }
    }
    else if (preferHiRes)
    {
        switch (codec)
        {
            case BluetoothCodec::aptX_Lossless: return 100;
            case BluetoothCodec::LDAC:          return 95;
            case BluetoothCodec::aptX_HD:       return 90;
            case BluetoothCodec::LC3plus:       return 85;
            case BluetoothCodec::aptX_Adaptive: return 80;
            case BluetoothCodec::aptX:          return 60;
            case BluetoothCodec::AAC:           return 50;
            case BluetoothCodec::SBC:           return 10;
            default:                            return 0;
        }
    }
    else
    {
        // Balanced
        switch (codec)
        {
            case BluetoothCodec::aptX_Adaptive: return 100;
            case BluetoothCodec::aptX_Lossless: return 95;
            case BluetoothCodec::LDAC:          return 90;
            case BluetoothCodec::aptX_HD:       return 85;
            case BluetoothCodec::aptX_LL:       return 80;
            case BluetoothCodec::aptX:          return 70;
            case BluetoothCodec::LC3plus:       return 75;
            case BluetoothCodec::LC3:           return 65;
            case BluetoothCodec::AAC:           return 50;
            case BluetoothCodec::SBC:           return 10;
            default:                            return 0;
        }
    }
}

} // namespace BluetoothHelpers

//==============================================================================
// Android JNI Implementation
//==============================================================================

#if JUCE_ANDROID

// JNI helper class for Android Bluetooth operations
class AndroidBluetoothHelper
{
public:
    static BluetoothCodec getActiveCodec(JNIEnv* env)
    {
        // Get BluetoothAdapter
        jclass bluetoothAdapterClass = env->FindClass("android/bluetooth/BluetoothAdapter");
        if (bluetoothAdapterClass == nullptr)
            return BluetoothCodec::Unknown;

        jmethodID getDefaultAdapter = env->GetStaticMethodID(
            bluetoothAdapterClass,
            "getDefaultAdapter",
            "()Landroid/bluetooth/BluetoothAdapter;"
        );

        jobject adapter = env->CallStaticObjectMethod(bluetoothAdapterClass, getDefaultAdapter);
        if (adapter == nullptr)
            return BluetoothCodec::Unknown;

        // Get BluetoothA2dp service
        // This requires BLUETOOTH_CONNECT permission on Android 12+

        // For now, return a default based on common Android behavior
        // Most modern Android devices support aptX at minimum
        return BluetoothCodec::aptX;
    }

    static void setPreferredCodec(JNIEnv* env, BluetoothCodec codec)
    {
        // Use BluetoothCodecConfig to set preferred codec
        // Requires BLUETOOTH_PRIVILEGED permission (system apps only)
        // For regular apps, we can only suggest via AudioManager

        DBG("Android: Requesting codec " << BluetoothHelpers::codecToString(codec));
    }

    static bool isA2dpConnected(JNIEnv* env)
    {
        // Check BluetoothProfile.A2DP connection state
        return false; // Placeholder
    }
};

#endif // JUCE_ANDROID

//==============================================================================
// macOS CoreBluetooth Implementation
//==============================================================================

#if JUCE_MAC

// macOS Bluetooth helper using IOBluetooth
class MacBluetoothHelper
{
public:
    static BluetoothCodec detectActiveCodec()
    {
        // Use IOBluetooth framework to detect A2DP codec
        // This requires entitlements and user permission

        // Check system audio output device
        // If it's a Bluetooth device, try to determine codec

        return BluetoothCodec::AAC; // Default for Apple devices
    }

    static juce::String getConnectedDeviceName()
    {
        // Query IOBluetoothDevice for connected A2DP devices
        return "Unknown Bluetooth Device";
    }
};

#endif // JUCE_MAC

//==============================================================================
// Windows Bluetooth Implementation
//==============================================================================

#if JUCE_WINDOWS

#include <bluetoothapis.h>
#pragma comment(lib, "Bthprops.lib")

class WindowsBluetoothHelper
{
public:
    static BluetoothCodec detectActiveCodec()
    {
        // Windows Bluetooth audio typically uses:
        // - SBC (universal fallback)
        // - aptX (if Qualcomm chipset)
        // - AAC (rare on Windows)

        // Query Windows.Devices.Bluetooth.BluetoothA2dp
        // or use legacy BTHENUM interface

        return BluetoothCodec::SBC; // Default fallback
    }

    static bool isBluetoothAudioActive()
    {
        // Check if default audio device is Bluetooth
        return false; // Placeholder
    }
};

#endif // JUCE_WINDOWS

//==============================================================================
// Linux BlueZ Implementation
//==============================================================================

#if JUCE_LINUX

class LinuxBluetoothHelper
{
public:
    static BluetoothCodec detectActiveCodec()
    {
        // Query PipeWire or PulseAudio for active Bluetooth codec
        // Via D-Bus: org.bluez interface

        // PipeWire: check /proc/asound or pipewire-cli
        // PulseAudio: pactl info

        // Modern Linux with PipeWire supports:
        // - SBC, SBC-XQ
        // - AAC
        // - aptX, aptX HD
        // - LDAC

        return BluetoothCodec::SBC; // Default
    }

    static juce::String runCommand(const juce::String& cmd)
    {
        // Execute shell command and return output
        juce::ChildProcess process;
        if (process.start(cmd))
        {
            return process.readAllProcessOutput();
        }
        return {};
    }

    static void setCodecViaPipeWire(BluetoothCodec codec)
    {
        // Use pw-cli or wpctl to set codec
        juce::String codecName;

        switch (codec)
        {
            case BluetoothCodec::LDAC:     codecName = "ldac"; break;
            case BluetoothCodec::aptX_HD:  codecName = "aptx_hd"; break;
            case BluetoothCodec::aptX:     codecName = "aptx"; break;
            case BluetoothCodec::AAC:      codecName = "aac"; break;
            default:                       codecName = "sbc"; break;
        }

        DBG("Linux: Requesting codec " << codecName << " via PipeWire");
    }
};

#endif // JUCE_LINUX

//==============================================================================
// Latency Measurement Utilities
//==============================================================================

class LatencyMeasurement
{
public:
    /** Generate a measurement pulse for latency detection */
    static void generatePulse(juce::AudioBuffer<float>& buffer, int channel, int sampleIndex)
    {
        if (channel < buffer.getNumChannels() && sampleIndex < buffer.getNumSamples())
        {
            // Short click pulse for round-trip measurement
            buffer.setSample(channel, sampleIndex, 1.0f);
            if (sampleIndex + 1 < buffer.getNumSamples())
                buffer.setSample(channel, sampleIndex + 1, -1.0f);
        }
    }

    /** Detect pulse in input buffer, returns sample index or -1 */
    static int detectPulse(const juce::AudioBuffer<float>& buffer, int channel, float threshold = 0.5f)
    {
        if (channel >= buffer.getNumChannels())
            return -1;

        const float* data = buffer.getReadPointer(channel);
        int numSamples = buffer.getNumSamples();

        for (int i = 0; i < numSamples - 1; ++i)
        {
            // Detect impulse pattern
            if (data[i] > threshold && data[i + 1] < -threshold * 0.5f)
            {
                return i;
            }
        }

        return -1;
    }

    /** Calculate latency from timestamps */
    static float calculateLatencyMs(int64_t startTicks, int64_t endTicks)
    {
        double seconds = juce::Time::highResolutionTicksToSeconds(endTicks - startTicks);
        return static_cast<float>(seconds * 1000.0);
    }
};

//==============================================================================
// Bluetooth Audio Quality Analyzer
//==============================================================================

class BluetoothQualityAnalyzer
{
public:
    struct QualityMetrics
    {
        float signalStrength = 0.0f;    // 0-100%
        float packetLoss = 0.0f;        // 0-100%
        float jitter = 0.0f;            // milliseconds
        float effectiveBitrate = 0.0f;  // kbps
        int dropouts = 0;               // count in last minute

        bool isStable() const
        {
            return packetLoss < 1.0f && jitter < 5.0f && dropouts < 3;
        }

        juce::String getQualityRating() const
        {
            if (packetLoss < 0.1f && jitter < 2.0f && dropouts == 0)
                return "Excellent";
            else if (packetLoss < 0.5f && jitter < 5.0f && dropouts < 2)
                return "Good";
            else if (packetLoss < 2.0f && jitter < 10.0f && dropouts < 5)
                return "Fair";
            else
                return "Poor";
        }
    };

    void analyzeBuffer(const juce::AudioBuffer<float>& buffer)
    {
        // Detect dropouts (sudden silence)
        detectDropouts(buffer);

        // Analyze jitter (timing variations)
        analyzeJitter();
    }

    QualityMetrics getMetrics() const { return currentMetrics; }

private:
    void detectDropouts(const juce::AudioBuffer<float>& buffer)
    {
        // Check for unexpected silence or glitches
        float maxLevel = buffer.getMagnitude(0, buffer.getNumSamples());

        if (maxLevel < 0.0001f && lastMaxLevel > 0.01f)
        {
            // Sudden dropout detected
            currentMetrics.dropouts++;
        }

        lastMaxLevel = maxLevel;
    }

    void analyzeJitter()
    {
        // Track callback timing variations
        int64_t currentTime = juce::Time::getHighResolutionTicks();

        if (lastCallbackTime > 0)
        {
            double intervalMs = juce::Time::highResolutionTicksToSeconds(
                currentTime - lastCallbackTime) * 1000.0;

            // Calculate jitter as deviation from expected interval
            float deviation = std::abs(static_cast<float>(intervalMs) - expectedIntervalMs);
            currentMetrics.jitter = currentMetrics.jitter * 0.9f + deviation * 0.1f;
        }

        lastCallbackTime = currentTime;
    }

    QualityMetrics currentMetrics;
    float lastMaxLevel = 0.0f;
    int64_t lastCallbackTime = 0;
    float expectedIntervalMs = 5.33f; // 256 samples @ 48kHz
};

} // namespace Echoelmusic

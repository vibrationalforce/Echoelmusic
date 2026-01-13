#pragma once
// ============================================================================
// EchoelDSP/Backends/CoreAudioBackend.h - Native Apple Audio
// ============================================================================
// Zero-latency Core Audio for macOS, iOS, visionOS, tvOS, watchOS
// Uses AudioUnit for maximum performance and minimum latency
// ============================================================================

#if defined(__APPLE__)

#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudio.h>
#include <functional>
#include <atomic>
#include <string>
#include <vector>
#include "../AudioBuffer.h"

namespace Echoel::DSP {

// ============================================================================
// MARK: - Audio Device Info
// ============================================================================

struct AudioDeviceInfo {
    uint32_t deviceID;
    std::string name;
    std::string manufacturer;
    int numInputChannels;
    int numOutputChannels;
    double sampleRate;
    uint32_t bufferSize;
    bool isDefault;
};

// ============================================================================
// MARK: - Core Audio Backend
// ============================================================================

class CoreAudioBackend {
public:
    using AudioCallback = std::function<void(const float* const* inputs, float* const* outputs,
                                             int numInputChannels, int numOutputChannels,
                                             int numSamples)>;

    CoreAudioBackend() = default;
    ~CoreAudioBackend() { stop(); }

    // ========================================================================
    // Device Management
    // ========================================================================

    std::vector<AudioDeviceInfo> getAvailableDevices() const {
        std::vector<AudioDeviceInfo> devices;

        #if TARGET_OS_OSX
        AudioObjectPropertyAddress propertyAddress = {
            kAudioHardwarePropertyDevices,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };

        UInt32 dataSize = 0;
        OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,
                                                         &propertyAddress, 0, nullptr, &dataSize);
        if (status != noErr) return devices;

        int numDevices = dataSize / sizeof(AudioDeviceID);
        std::vector<AudioDeviceID> deviceIDs(numDevices);

        status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress,
                                           0, nullptr, &dataSize, deviceIDs.data());
        if (status != noErr) return devices;

        for (AudioDeviceID deviceID : deviceIDs) {
            AudioDeviceInfo info;
            info.deviceID = deviceID;
            info.name = getDeviceName(deviceID);
            info.numOutputChannels = getChannelCount(deviceID, false);
            info.numInputChannels = getChannelCount(deviceID, true);
            info.sampleRate = getDeviceSampleRate(deviceID);
            devices.push_back(info);
        }
        #endif

        return devices;
    }

    // ========================================================================
    // Audio Stream Control
    // ========================================================================

    bool start(double sampleRate = 48000.0, int bufferSize = 256,
               int numInputChannels = 0, int numOutputChannels = 2)
    {
        if (running_.load()) return false;

        sampleRate_ = sampleRate;
        bufferSize_ = bufferSize;
        numInputChannels_ = numInputChannels;
        numOutputChannels_ = numOutputChannels;

        // Create Audio Component Description
        AudioComponentDescription desc = {};
        desc.componentType = kAudioUnitType_Output;
        #if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH || TARGET_OS_VISION
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
        #else
        desc.componentSubType = kAudioUnitSubType_HALOutput;
        #endif
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;

        AudioComponent component = AudioComponentFindNext(nullptr, &desc);
        if (!component) return false;

        OSStatus status = AudioComponentInstanceNew(component, &audioUnit_);
        if (status != noErr) return false;

        // Configure Audio Unit
        AudioStreamBasicDescription streamFormat = {};
        streamFormat.mSampleRate = sampleRate;
        streamFormat.mFormatID = kAudioFormatLinearPCM;
        streamFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
        streamFormat.mBitsPerChannel = 32;
        streamFormat.mChannelsPerFrame = numOutputChannels;
        streamFormat.mFramesPerPacket = 1;
        streamFormat.mBytesPerFrame = sizeof(float) * numOutputChannels;
        streamFormat.mBytesPerPacket = streamFormat.mBytesPerFrame;

        status = AudioUnitSetProperty(audioUnit_, kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input, 0,
                                     &streamFormat, sizeof(streamFormat));
        if (status != noErr) {
            AudioComponentInstanceDispose(audioUnit_);
            return false;
        }

        // Set render callback
        AURenderCallbackStruct callbackStruct = {};
        callbackStruct.inputProc = renderCallback;
        callbackStruct.inputProcRefCon = this;

        status = AudioUnitSetProperty(audioUnit_, kAudioUnitProperty_SetRenderCallback,
                                     kAudioUnitScope_Global, 0,
                                     &callbackStruct, sizeof(callbackStruct));
        if (status != noErr) {
            AudioComponentInstanceDispose(audioUnit_);
            return false;
        }

        // Set buffer size
        UInt32 bufferFrames = bufferSize;
        status = AudioUnitSetProperty(audioUnit_, kAudioDevicePropertyBufferFrameSize,
                                     kAudioUnitScope_Global, 0,
                                     &bufferFrames, sizeof(bufferFrames));

        // Initialize and start
        status = AudioUnitInitialize(audioUnit_);
        if (status != noErr) {
            AudioComponentInstanceDispose(audioUnit_);
            return false;
        }

        status = AudioOutputUnitStart(audioUnit_);
        if (status != noErr) {
            AudioUnitUninitialize(audioUnit_);
            AudioComponentInstanceDispose(audioUnit_);
            return false;
        }

        running_.store(true);
        return true;
    }

    void stop() {
        if (!running_.load()) return;

        running_.store(false);
        AudioOutputUnitStop(audioUnit_);
        AudioUnitUninitialize(audioUnit_);
        AudioComponentInstanceDispose(audioUnit_);
        audioUnit_ = nullptr;
    }

    bool isRunning() const { return running_.load(); }

    void setCallback(AudioCallback callback) {
        callback_ = std::move(callback);
    }

    // ========================================================================
    // Properties
    // ========================================================================

    double getSampleRate() const { return sampleRate_; }
    int getBufferSize() const { return bufferSize_; }
    int getNumInputChannels() const { return numInputChannels_; }
    int getNumOutputChannels() const { return numOutputChannels_; }

    float getCPULoad() const {
        if (!audioUnit_) return 0.0f;
        Float64 load = 0.0;
        UInt32 size = sizeof(load);
        AudioUnitGetProperty(audioUnit_, kAudioUnitProperty_CPULoad,
                            kAudioUnitScope_Global, 0, &load, &size);
        return static_cast<float>(load);
    }

private:
    static OSStatus renderCallback(void* inRefCon,
                                   AudioUnitRenderActionFlags* ioActionFlags,
                                   const AudioTimeStamp* inTimeStamp,
                                   UInt32 inBusNumber,
                                   UInt32 inNumberFrames,
                                   AudioBufferList* ioData)
    {
        auto* self = static_cast<CoreAudioBackend*>(inRefCon);

        if (!self->callback_) {
            // Silence
            for (UInt32 i = 0; i < ioData->mNumberBuffers; ++i) {
                memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
            }
            return noErr;
        }

        // Prepare output pointers
        std::vector<float*> outputs(self->numOutputChannels_);
        for (int ch = 0; ch < self->numOutputChannels_; ++ch) {
            if (ch < static_cast<int>(ioData->mNumberBuffers)) {
                outputs[ch] = static_cast<float*>(ioData->mBuffers[ch].mData);
            }
        }

        // Call user callback
        self->callback_(nullptr, outputs.data(),
                       0, self->numOutputChannels_,
                       static_cast<int>(inNumberFrames));

        return noErr;
    }

    #if TARGET_OS_OSX
    std::string getDeviceName(AudioDeviceID deviceID) const {
        CFStringRef name = nullptr;
        UInt32 size = sizeof(name);
        AudioObjectPropertyAddress prop = {
            kAudioDevicePropertyDeviceNameCFString,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        AudioObjectGetPropertyData(deviceID, &prop, 0, nullptr, &size, &name);

        if (name) {
            char buffer[256];
            CFStringGetCString(name, buffer, sizeof(buffer), kCFStringEncodingUTF8);
            CFRelease(name);
            return buffer;
        }
        return "Unknown";
    }

    int getChannelCount(AudioDeviceID deviceID, bool input) const {
        AudioObjectPropertyAddress prop = {
            kAudioDevicePropertyStreamConfiguration,
            input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
            kAudioObjectPropertyElementMain
        };

        UInt32 size = 0;
        AudioObjectGetPropertyDataSize(deviceID, &prop, 0, nullptr, &size);

        std::vector<uint8_t> buffer(size);
        AudioBufferList* bufferList = reinterpret_cast<AudioBufferList*>(buffer.data());
        AudioObjectGetPropertyData(deviceID, &prop, 0, nullptr, &size, bufferList);

        int channels = 0;
        for (UInt32 i = 0; i < bufferList->mNumberBuffers; ++i) {
            channels += bufferList->mBuffers[i].mNumberChannels;
        }
        return channels;
    }

    double getDeviceSampleRate(AudioDeviceID deviceID) const {
        Float64 sampleRate = 0;
        UInt32 size = sizeof(sampleRate);
        AudioObjectPropertyAddress prop = {
            kAudioDevicePropertyNominalSampleRate,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMain
        };
        AudioObjectGetPropertyData(deviceID, &prop, 0, nullptr, &size, &sampleRate);
        return sampleRate;
    }
    #endif

    AudioUnit audioUnit_ = nullptr;
    AudioCallback callback_;
    std::atomic<bool> running_{false};

    double sampleRate_ = 48000.0;
    int bufferSize_ = 256;
    int numInputChannels_ = 0;
    int numOutputChannels_ = 2;
};

} // namespace Echoel::DSP

#endif // __APPLE__

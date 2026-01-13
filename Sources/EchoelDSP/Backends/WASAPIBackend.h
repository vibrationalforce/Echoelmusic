#pragma once
// ============================================================================
// EchoelDSP/Backends/WASAPIBackend.h - Native Windows Audio
// ============================================================================
// Low-latency Windows Audio Session API (WASAPI) backend
// Supports exclusive mode for minimum latency
// ============================================================================

#if defined(_WIN32) || defined(_WIN64)

#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <functiondiscoverykeys_devpkey.h>
#include <functional>
#include <atomic>
#include <string>
#include <vector>
#include <thread>
#include <memory>
#include "../AudioBuffer.h"

// Link required libraries
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "avrt.lib")

namespace Echoel::DSP {

// ============================================================================
// MARK: - WASAPI Audio Device Info
// ============================================================================

struct WASAPIDeviceInfo {
    std::wstring deviceId;
    std::wstring name;
    int numChannels;
    int sampleRate;
    bool isDefault;
    bool isInput;
};

// ============================================================================
// MARK: - WASAPI Backend
// ============================================================================

class WASAPIBackend {
public:
    using AudioCallback = std::function<void(const float* const* inputs, float* const* outputs,
                                             int numInputChannels, int numOutputChannels,
                                             int numSamples)>;

    WASAPIBackend() {
        CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    }

    ~WASAPIBackend() {
        stop();
        CoUninitialize();
    }

    // ========================================================================
    // Device Management
    // ========================================================================

    std::vector<WASAPIDeviceInfo> getAvailableDevices() const {
        std::vector<WASAPIDeviceInfo> devices;

        IMMDeviceEnumerator* enumerator = nullptr;
        HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                      CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                                      (void**)&enumerator);
        if (FAILED(hr)) return devices;

        IMMDeviceCollection* collection = nullptr;
        hr = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &collection);
        if (FAILED(hr)) {
            enumerator->Release();
            return devices;
        }

        UINT count = 0;
        collection->GetCount(&count);

        for (UINT i = 0; i < count; ++i) {
            IMMDevice* device = nullptr;
            if (SUCCEEDED(collection->Item(i, &device))) {
                WASAPIDeviceInfo info;
                info.isInput = false;

                // Get device ID
                LPWSTR deviceId = nullptr;
                if (SUCCEEDED(device->GetId(&deviceId))) {
                    info.deviceId = deviceId;
                    CoTaskMemFree(deviceId);
                }

                // Get device name
                IPropertyStore* props = nullptr;
                if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, &props))) {
                    PROPVARIANT varName;
                    PropVariantInit(&varName);
                    if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &varName))) {
                        info.name = varName.pwszVal;
                        PropVariantClear(&varName);
                    }
                    props->Release();
                }

                devices.push_back(info);
                device->Release();
            }
        }

        collection->Release();
        enumerator->Release();

        return devices;
    }

    // ========================================================================
    // Audio Stream Control
    // ========================================================================

    bool start(double sampleRate = 48000.0, int bufferSize = 256,
               int numInputChannels = 0, int numOutputChannels = 2,
               bool exclusiveMode = false)
    {
        if (running_.load()) return false;

        sampleRate_ = sampleRate;
        bufferSize_ = bufferSize;
        numInputChannels_ = numInputChannels;
        numOutputChannels_ = numOutputChannels;
        exclusiveMode_ = exclusiveMode;

        // Get default audio endpoint
        IMMDeviceEnumerator* enumerator = nullptr;
        HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                      CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                                      (void**)&enumerator);
        if (FAILED(hr)) return false;

        hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device_);
        enumerator->Release();
        if (FAILED(hr)) return false;

        // Activate audio client
        hr = device_->Activate(__uuidof(IAudioClient), CLSCTX_ALL,
                              nullptr, (void**)&audioClient_);
        if (FAILED(hr)) {
            device_->Release();
            device_ = nullptr;
            return false;
        }

        // Set up format
        WAVEFORMATEXTENSIBLE wfx = {};
        wfx.Format.wFormatTag = WAVE_FORMAT_EXTENSIBLE;
        wfx.Format.nChannels = numOutputChannels;
        wfx.Format.nSamplesPerSec = static_cast<DWORD>(sampleRate);
        wfx.Format.wBitsPerSample = 32;
        wfx.Format.nBlockAlign = (wfx.Format.nChannels * wfx.Format.wBitsPerSample) / 8;
        wfx.Format.nAvgBytesPerSec = wfx.Format.nSamplesPerSec * wfx.Format.nBlockAlign;
        wfx.Format.cbSize = sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX);
        wfx.Samples.wValidBitsPerSample = 32;
        wfx.dwChannelMask = (numOutputChannels == 2) ? SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT : SPEAKER_FRONT_CENTER;
        wfx.SubFormat = KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;

        // Calculate buffer duration (in 100-nanosecond units)
        REFERENCE_TIME bufferDuration = static_cast<REFERENCE_TIME>(
            (10000000.0 * bufferSize) / sampleRate);

        DWORD flags = exclusiveMode_ ? 0 : AUDCLNT_STREAMFLAGS_EVENTCALLBACK;

        hr = audioClient_->Initialize(
            exclusiveMode_ ? AUDCLNT_SHAREMODE_EXCLUSIVE : AUDCLNT_SHAREMODE_SHARED,
            flags,
            bufferDuration,
            exclusiveMode_ ? bufferDuration : 0,
            reinterpret_cast<WAVEFORMATEX*>(&wfx),
            nullptr);

        if (FAILED(hr)) {
            audioClient_->Release();
            device_->Release();
            audioClient_ = nullptr;
            device_ = nullptr;
            return false;
        }

        // Get render client
        hr = audioClient_->GetService(__uuidof(IAudioRenderClient),
                                     (void**)&renderClient_);
        if (FAILED(hr)) {
            audioClient_->Release();
            device_->Release();
            audioClient_ = nullptr;
            device_ = nullptr;
            return false;
        }

        // Get buffer size
        UINT32 bufferFrameCount;
        audioClient_->GetBufferSize(&bufferFrameCount);
        actualBufferSize_ = bufferFrameCount;

        // Start audio thread
        running_.store(true);
        audioThread_ = std::thread(&WASAPIBackend::audioThreadProc, this);

        // Start audio client
        hr = audioClient_->Start();
        if (FAILED(hr)) {
            stop();
            return false;
        }

        return true;
    }

    void stop() {
        if (!running_.load()) return;

        running_.store(false);

        if (audioThread_.joinable()) {
            audioThread_.join();
        }

        if (audioClient_) {
            audioClient_->Stop();
            audioClient_->Release();
            audioClient_ = nullptr;
        }

        if (renderClient_) {
            renderClient_->Release();
            renderClient_ = nullptr;
        }

        if (device_) {
            device_->Release();
            device_ = nullptr;
        }
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
    int getActualBufferSize() const { return actualBufferSize_; }
    int getNumInputChannels() const { return numInputChannels_; }
    int getNumOutputChannels() const { return numOutputChannels_; }
    bool isExclusiveMode() const { return exclusiveMode_; }

private:
    void audioThreadProc() {
        // Boost thread priority for real-time audio
        HANDLE taskHandle = nullptr;
        DWORD taskIndex = 0;
        AvSetMmThreadCharacteristicsW(L"Pro Audio", &taskIndex);

        std::vector<float*> outputPtrs(numOutputChannels_);
        std::vector<float> interleavedBuffer(actualBufferSize_ * numOutputChannels_);

        while (running_.load()) {
            UINT32 paddingFrames = 0;
            audioClient_->GetCurrentPadding(&paddingFrames);

            UINT32 availableFrames = actualBufferSize_ - paddingFrames;
            if (availableFrames < static_cast<UINT32>(bufferSize_)) {
                Sleep(1);
                continue;
            }

            BYTE* data = nullptr;
            HRESULT hr = renderClient_->GetBuffer(bufferSize_, &data);
            if (FAILED(hr)) continue;

            float* floatData = reinterpret_cast<float*>(data);

            // Call user callback
            if (callback_) {
                // Deinterleave for callback
                for (int ch = 0; ch < numOutputChannels_; ++ch) {
                    outputPtrs[ch] = interleavedBuffer.data() + ch * bufferSize_;
                }

                callback_(nullptr, outputPtrs.data(),
                         0, numOutputChannels_, bufferSize_);

                // Interleave output
                for (int i = 0; i < bufferSize_; ++i) {
                    for (int ch = 0; ch < numOutputChannels_; ++ch) {
                        floatData[i * numOutputChannels_ + ch] = outputPtrs[ch][i];
                    }
                }
            } else {
                // Silence
                memset(data, 0, bufferSize_ * numOutputChannels_ * sizeof(float));
            }

            renderClient_->ReleaseBuffer(bufferSize_, 0);
        }

        if (taskHandle) {
            AvRevertMmThreadCharacteristics(taskHandle);
        }
    }

    IMMDevice* device_ = nullptr;
    IAudioClient* audioClient_ = nullptr;
    IAudioRenderClient* renderClient_ = nullptr;

    AudioCallback callback_;
    std::atomic<bool> running_{false};
    std::thread audioThread_;

    double sampleRate_ = 48000.0;
    int bufferSize_ = 256;
    int actualBufferSize_ = 256;
    int numInputChannels_ = 0;
    int numOutputChannels_ = 2;
    bool exclusiveMode_ = false;
};

} // namespace Echoel::DSP

#endif // _WIN32 || _WIN64

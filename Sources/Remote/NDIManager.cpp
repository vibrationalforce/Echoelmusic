#include "NDIManager.h"

//==============================================================================
// NDI SDK Integration
//==============================================================================

// Download NDI SDK from: https://ndi.tv/sdk/
// Add to project: ThirdParty/ndi/include/Processing.NDI.Lib.h
// #include <Processing.NDI.Lib.h>

struct NDIManager::NDIImpl
{
    // NDI library instances
    // NDIlib_find_instance_t finder = nullptr;
    // NDIlib_send_instance_t sender = nullptr;
    // NDIlib_recv_instance_t receiver = nullptr;

    juce::Array<NDISource> discoveredSources;
    bool isInitialized = false;

    NDIImpl()
    {
        DBG("NDI: Initialized (placeholder mode)");
        DBG("NDI: To enable full NDI support:");
        DBG("  1. Download NDI SDK from https://ndi.tv/sdk/");
        DBG("  2. Add to ThirdParty/ndi/include/");
        DBG("  3. Link NDI library (Processing.NDI.Lib.x64.lib on Windows)");
        DBG("  4. Rebuild project");
    }

    ~NDIImpl()
    {
        cleanup();
    }

    bool initialize()
    {
        /*
        // Real NDI initialization:
        if (!NDIlib_initialize())
        {
            DBG("NDI: Failed to initialize library");
            return false;
        }

        DBG("NDI: Library initialized - version " << NDIlib_version());
        isInitialized = true;
        return true;
        */

        // Placeholder
        DBG("NDI: Placeholder initialization successful");
        isInitialized = true;
        return true;
    }

    void startDiscovery()
    {
        /*
        // Real NDI discovery:
        NDIlib_find_create_t find_create;
        find_create.show_local_sources = true;
        find_create.p_groups = nullptr;
        find_create.p_extra_ips = nullptr;

        finder = NDIlib_find_create_v2(&find_create);

        // Wait for sources
        NDIlib_find_wait_for_sources(finder, 1000);
        */

        DBG("NDI: Started source discovery");

        // Simulate discovering sources
        discoveredSources.clear();
        discoveredSources.add({"OBS Studio (Computer-1)", "192.168.1.100:5960", "Computer-1", "OBS Studio", false});
        discoveredSources.add({"TouchDesigner Output", "192.168.1.101:5960", "Computer-2", "TouchDesigner", false});
    }

    void stopDiscovery()
    {
        /*
        if (finder)
        {
            NDIlib_find_destroy(finder);
            finder = nullptr;
        }
        */

        DBG("NDI: Stopped discovery");
    }

    bool createSender(const juce::String& name, const NDIManager::VideoFormat& format)
    {
        /*
        // Real NDI sender creation:
        NDIlib_send_create_t send_create;
        send_create.p_ndi_name = name.toRawUTF8();
        send_create.p_groups = nullptr;
        send_create.clock_video = true;
        send_create.clock_audio = true;

        sender = NDIlib_send_create(&send_create);

        if (!sender)
        {
            DBG("NDI: Failed to create sender");
            return false;
        }

        DBG("NDI: Sender created - " << name);
        return true;
        */

        DBG("NDI: Created sender '" << name << "' - " << format.width << "x" << format.height << " @ " << format.framerate << " fps");
        return true;
    }

    bool sendVideoFrame(const juce::Image& frame)
    {
        /*
        // Real NDI video send:
        NDIlib_video_frame_v2_t video_frame;
        video_frame.xres = frame.getWidth();
        video_frame.yres = frame.getHeight();
        video_frame.FourCC = NDIlib_FourCC_type_RGBA;
        video_frame.frame_rate_N = 60000;  // 60 fps
        video_frame.frame_rate_D = 1000;
        video_frame.picture_aspect_ratio = (float)frame.getWidth() / frame.getHeight();
        video_frame.frame_format_type = NDIlib_frame_format_type_progressive;
        video_frame.timecode = NDIlib_send_timecode_synthesize;
        video_frame.p_data = (uint8_t*)frame.getPixelData();
        video_frame.line_stride_in_bytes = frame.getWidth() * 4;  // RGBA

        NDIlib_send_send_video_v2(sender, &video_frame);
        return true;
        */

        // Placeholder
        return true;
    }

    bool connectToSource(const NDISource& source)
    {
        /*
        // Real NDI receiver:
        NDIlib_recv_create_v3_t recv_create;
        recv_create.source_to_connect_to = ...; // From finder
        recv_create.color_format = NDIlib_recv_color_format_RGBX_RGBA;
        recv_create.bandwidth = NDIlib_recv_bandwidth_highest;
        recv_create.allow_video_fields = false;

        receiver = NDIlib_recv_create_v3(&recv_create);

        if (!receiver)
        {
            DBG("NDI: Failed to create receiver");
            return false;
        }

        DBG("NDI: Connected to " << source.name);
        return true;
        */

        DBG("NDI: Connected to source '" << source.name << "'");
        return true;
    }

    bool receiveVideoFrame(juce::Image& frame, int timeoutMs)
    {
        /*
        // Real NDI video receive:
        NDIlib_video_frame_v2_t video_frame;
        NDIlib_frame_type_e frame_type = NDIlib_recv_capture_v2(
            receiver,
            &video_frame,
            nullptr,  // No audio
            nullptr,  // No metadata
            timeoutMs
        );

        if (frame_type == NDIlib_frame_type_video)
        {
            // Copy video data to juce::Image
            frame = juce::Image(juce::Image::ARGB, video_frame.xres, video_frame.yres, true);
            std::memcpy(frame.getPixelData(), video_frame.p_data, video_frame.xres * video_frame.yres * 4);

            NDIlib_recv_free_video_v2(receiver, &video_frame);
            return true;
        }

        return false;
        */

        // Placeholder: create empty frame
        frame = juce::Image(juce::Image::ARGB, 1920, 1080, true);
        return false;  // No frame available in placeholder mode
    }

    void cleanup()
    {
        /*
        if (sender)
        {
            NDIlib_send_destroy(sender);
            sender = nullptr;
        }

        if (receiver)
        {
            NDIlib_recv_destroy(receiver);
            receiver = nullptr;
        }

        if (finder)
        {
            NDIlib_find_destroy(finder);
            finder = nullptr;
        }

        if (isInitialized)
        {
            NDIlib_destroy();
            isInitialized = false;
        }
        */

        DBG("NDI: Cleaned up");
    }
};

//==============================================================================
// Constructor / Destructor
//==============================================================================

NDIManager::NDIManager()
{
    impl = std::make_unique<NDIImpl>();
}

NDIManager::~NDIManager()
{
    closeSender();
    disconnectSource();
}

//==============================================================================
// Initialization
//==============================================================================

bool NDIManager::initialize()
{
    bool success = impl->initialize();
    initialized = success;
    return success;
}

bool NDIManager::isAvailable() const
{
    return initialized;
}

juce::String NDIManager::getVersion() const
{
    // return juce::String(NDIlib_version());
    return "NDI 5.5 (Placeholder)";
}

//==============================================================================
// Source Discovery
//==============================================================================

void NDIManager::startDiscovery()
{
    impl->startDiscovery();
}

void NDIManager::stopDiscovery()
{
    impl->stopDiscovery();
}

juce::Array<NDIManager::NDISource> NDIManager::getDiscoveredSources() const
{
    return impl->discoveredSources;
}

//==============================================================================
// Sender (Output)
//==============================================================================

bool NDIManager::createSender(const juce::String& name, const VideoFormat& format)
{
    currentFormat = format;
    bool success = impl->createSender(name, format);
    sending = success;
    return success;
}

bool NDIManager::sendVideoFrame(const juce::Image& frame)
{
    if (!sending)
        return false;

    bool sent = impl->sendVideoFrame(frame);

    if (sent)
    {
        currentStats.videoFramesSent++;
    }

    return sent;
}

bool NDIManager::sendAudioBuffer(const juce::AudioBuffer<float>& buffer, int sampleRate)
{
    if (!sending)
        return false;

    // TODO: Implement NDI audio sending
    currentStats.audioFramesSent++;
    return true;
}

void NDIManager::closeSender()
{
    sending = false;
    DBG("NDI: Sender closed");
}

bool NDIManager::isSending() const
{
    return sending;
}

//==============================================================================
// Receiver (Input)
//==============================================================================

bool NDIManager::connectToSource(const NDISource& source)
{
    bool success = impl->connectToSource(source);
    receiving = success;
    currentStats.isConnected = success;
    return success;
}

void NDIManager::disconnectSource()
{
    receiving = false;
    currentStats.isConnected = false;
    DBG("NDI: Disconnected from source");
}

bool NDIManager::receiveVideoFrame(juce::Image& frame, int timeoutMs)
{
    if (!receiving)
        return false;

    bool received = impl->receiveVideoFrame(frame, timeoutMs);

    if (received)
    {
        currentStats.videoFramesReceived++;
    }

    return received;
}

bool NDIManager::receiveAudioBuffer(juce::AudioBuffer<float>& buffer, int timeoutMs)
{
    if (!receiving)
        return false;

    // TODO: Implement NDI audio receiving
    return false;
}

bool NDIManager::isReceiving() const
{
    return receiving;
}

//==============================================================================
// Stats
//==============================================================================

NDIManager::NetworkStats NDIManager::getStats() const
{
    return currentStats;
}

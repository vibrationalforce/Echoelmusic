// VideoSyncEngine.h - Real-time Video Synchronization with OSC
// Supports: Resolume Arena, TouchDesigner, MadMapper, VDMX, Millumin
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <atomic>
#include <memory>

namespace Echoel {

class VideoSyncEngine : public juce::Timer,
                        public juce::OSCSender,
                        public juce::OSCReceiver,
                        private juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback> {
public:
    // SMPTE Timecode
    struct SMPTETimecode {
        int hours{0};
        int minutes{0};
        int seconds{0};
        int frames{0};
        float frameRate{30.0f};

        juce::String toString() const {
            return juce::String::formatted("%02d:%02d:%02d:%02d @ %.2f fps",
                                          hours, minutes, seconds, frames, frameRate);
        }
    };

    // Video sync data structure
    struct VideoSyncData {
        double bpm{120.0};
        int framesPerBeat{30};
        SMPTETimecode smpte;
        juce::Colour dominantColor{juce::Colours::black};
        float brightness{0.0f};
        float audioLevel{0.0f};
        float dominantFrequency{440.0f};
        std::vector<float> audioFeatures;
        int currentClip{0};
        bool isPlaying{false};
    };

    VideoSyncEngine() {
        // Set default ports
        resolumePort = 7000;
        touchDesignerPort = 7001;
        madMapperPort = 8010;
        vdmxPort = 1234;
        milluminPort = 5010;

        // Start OSC sender
        if (!OSCSender::connect("127.0.0.1", resolumePort)) {
            ECHOEL_TRACE("Failed to connect OSC sender");
        }

        // Start OSC receiver
        if (!OSCReceiver::connect(9000)) {  // Listen on port 9000
            ECHOEL_TRACE("Failed to start OSC receiver");
        }

        OSCReceiver::addListener(this);

        // Start timer for periodic sync (30 FPS)
        startTimerHz(30);
    }

    ~VideoSyncEngine() override {
        stopTimer();
        OSCReceiver::removeListener(this);
        OSCReceiver::disconnect();
        OSCSender::disconnect();
    }

    // Update sync data from audio
    void updateFromAudio(float level, float frequency, const juce::Colour& color) {
        syncData.audioLevel = level;
        syncData.dominantFrequency = frequency;
        syncData.dominantColor = color;
        syncData.brightness = level;  // Map audio level to brightness
    }

    // Set BPM
    void setBPM(double bpm) {
        syncData.bpm = bpm;
        syncData.framesPerBeat = static_cast<int>((60.0 / bpm) * videoFrameRate.load());
    }

    // Set video frame rate
    void setFrameRate(double fps) {
        videoFrameRate = fps;
        syncData.smpte.frameRate = static_cast<float>(fps);
    }

    // Send to all video software
    void syncToAllTargets() {
        syncToResolume();
        syncToTouchDesigner();
        syncToMadMapper();
        syncToVDMX();
        syncToMillumin();
    }

    // SMPTE operations
    SMPTETimecode getCurrentSMPTE() const {
        return syncData.smpte;
    }

    void setSMPTE(int hours, int minutes, int seconds, int frames) {
        syncData.smpte.hours = hours;
        syncData.smpte.minutes = minutes;
        syncData.smpte.seconds = seconds;
        syncData.smpte.frames = frames;
    }

private:
    VideoSyncData syncData;
    std::atomic<double> videoFrameRate{30.0};
    std::atomic<int64_t> currentFrame{0};

    // OSC ports for different software
    int resolumePort;
    int touchDesignerPort;
    int madMapperPort;
    int vdmxPort;
    int milluminPort;

    // Timer callback - sends periodic updates
    void timerCallback() override {
        currentFrame++;
        updateSMPTEFromFrame();
        syncToAllTargets();
    }

    void updateSMPTEFromFrame() {
        const double fps = videoFrameRate.load();
        const int64_t frame = currentFrame.load();

        syncData.smpte.frames = static_cast<int>(frame % static_cast<int64_t>(fps));
        int totalSeconds = static_cast<int>(frame / fps);
        syncData.smpte.seconds = totalSeconds % 60;
        int totalMinutes = totalSeconds / 60;
        syncData.smpte.minutes = totalMinutes % 60;
        syncData.smpte.hours = totalMinutes / 60;
    }

    // ==================== RESOLUME ARENA ====================
    void syncToResolume() {
        if (!OSCSender::send("/resolume/composition/connect", 1)) {
            return;  // Failed to connect
        }

        // Layer 1 controls
        OSCSender::send("/resolume/layer1/clip1/connect", 1);
        OSCSender::send("/resolume/layer1/opacity", syncData.brightness);
        OSCSender::send("/resolume/layer1/volume", syncData.audioLevel);

        // Timecode
        OSCSender::send("/resolume/composition/tempocontroller/tempo", static_cast<float>(syncData.bpm));

        // Color controls
        OSCSender::send("/resolume/layer1/video/effects/colorize/color/red",
                       syncData.dominantColor.getFloatRed());
        OSCSender::send("/resolume/layer1/video/effects/colorize/color/green",
                       syncData.dominantColor.getFloatGreen());
        OSCSender::send("/resolume/layer1/video/effects/colorize/color/blue",
                       syncData.dominantColor.getFloatBlue());

        // Clip triggering based on audio features
        if (syncData.audioLevel > 0.7f) {
            OSCSender::send("/resolume/layer1/clip/select", syncData.currentClip);
        }
    }

    // ==================== TOUCHDESIGNER ====================
    void syncToTouchDesigner() {
        // Reconnect to TouchDesigner port
        OSCSender::disconnect();
        OSCSender::connect("127.0.0.1", touchDesignerPort);

        // Send audio analysis
        OSCSender::send("/td/audio/level", syncData.audioLevel);
        OSCSender::send("/td/audio/frequency", syncData.dominantFrequency);
        OSCSender::send("/td/audio/brightness", syncData.brightness);

        // Send color data
        OSCSender::send("/td/color/r", syncData.dominantColor.getFloatRed());
        OSCSender::send("/td/color/g", syncData.dominantColor.getFloatGreen());
        OSCSender::send("/td/color/b", syncData.dominantColor.getFloatBlue());

        // Send tempo
        OSCSender::send("/td/tempo/bpm", static_cast<float>(syncData.bpm));

        // Send SMPTE timecode
        OSCSender::send("/td/timecode/hours", syncData.smpte.hours);
        OSCSender::send("/td/timecode/minutes", syncData.smpte.minutes);
        OSCSender::send("/td/timecode/seconds", syncData.smpte.seconds);
        OSCSender::send("/td/timecode/frames", syncData.smpte.frames);

        // Reconnect to primary port
        OSCSender::disconnect();
        OSCSender::connect("127.0.0.1", resolumePort);
    }

    // ==================== MADMAPPER ====================
    void syncToMadMapper() {
        OSCSender::disconnect();
        OSCSender::connect("127.0.0.1", madMapperPort);

        // Surface controls
        OSCSender::send("/madmapper/surface/1/opacity", syncData.brightness);
        OSCSender::send("/madmapper/surface/1/color/r", syncData.dominantColor.getFloatRed());
        OSCSender::send("/madmapper/surface/1/color/g", syncData.dominantColor.getFloatGreen());
        OSCSender::send("/madmapper/surface/1/color/b", syncData.dominantColor.getFloatBlue());

        // Media control
        OSCSender::send("/madmapper/surface/1/media", syncData.currentClip);
        OSCSender::send("/madmapper/surface/1/volume", syncData.audioLevel);

        // BPM sync
        OSCSender::send("/madmapper/tempo", static_cast<float>(syncData.bpm));

        OSCSender::disconnect();
        OSCSender::connect("127.0.0.1", resolumePort);
    }

    // ==================== VDMX ====================
    void syncToVDMX() {
        OSCSender::disconnect();
        OSCSender::connect("127.0.0.1", vdmxPort);

        // Layer controls
        OSCSender::send("/vdmx/layer1/opacity", syncData.brightness);
        OSCSender::send("/vdmx/layer1/color",
                       syncData.dominantColor.getFloatRed(),
                       syncData.dominantColor.getFloatGreen(),
                       syncData.dominantColor.getFloatBlue());

        // Audio reactivity
        OSCSender::send("/vdmx/audio/level", syncData.audioLevel);
        OSCSender::send("/vdmx/audio/frequency", syncData.dominantFrequency);

        // BPM
        OSCSender::send("/vdmx/tempo/bpm", static_cast<float>(syncData.bpm));

        OSCSender::disconnect();
        OSCSender::connect("127.0.0.1", resolumePort);
    }

    // ==================== MILLUMIN ====================
    void syncToMillumin() {
        OSCSender::disconnect();
        OSCSender::connect("127.0.0.1", milluminPort);

        // Layer controls
        OSCSender::send("/millumin/layer/1/opacity", syncData.brightness);
        OSCSender::send("/millumin/layer/1/colorize",
                       syncData.dominantColor.getFloatRed(),
                       syncData.dominantColor.getFloatGreen(),
                       syncData.dominantColor.getFloatBlue());

        // Media selection
        OSCSender::send("/millumin/selectedColumn", syncData.currentClip);

        // Audio level
        OSCSender::send("/millumin/board/audio/level", syncData.audioLevel);

        OSCSender::disconnect();
        OSCSender::connect("127.0.0.1", resolumePort);
    }

    // OSC Receiver callback
    void oscMessageReceived(const juce::OSCMessage& message) override {
        auto address = message.getAddressPattern().toString();

        ECHOEL_TRACE("OSC received: " << address);

        // Handle incoming messages from video software
        if (address.startsWith("/echoel/")) {
            handleEchoelCommand(message);
        }
    }

    void handleEchoelCommand(const juce::OSCMessage& message) {
        auto address = message.getAddressPattern().toString();

        if (address == "/echoel/bpm" && message.size() >= 1) {
            if (message[0].isFloat32()) {
                setBPM(message[0].getFloat32());
            }
        } else if (address == "/echoel/clip" && message.size() >= 1) {
            if (message[0].isInt32()) {
                syncData.currentClip = message[0].getInt32();
            }
        } else if (address == "/echoel/play") {
            syncData.isPlaying = true;
        } else if (address == "/echoel/stop") {
            syncData.isPlaying = false;
        }
    }

public:
    // Get current sync state
    const VideoSyncData& getSyncData() const { return syncData; }

    // Configuration
    void setResolumePort(int port) { resolumePort = port; }
    void setTouchDesignerPort(int port) { touchDesignerPort = port; }
    void setMadMapperPort(int port) { madMapperPort = port; }
    void setVDMXPort(int port) { vdmxPort = port; }
    void setMilluminPort(int port) { milluminPort = port; }

    // Get configuration info
    juce::String getConfigurationInfo() const {
        juce::String info;
        info << "🎬 Video Sync Engine Configuration\n";
        info << "================================\n\n";
        info << "Resolume Arena: localhost:" << resolumePort << "\n";
        info << "TouchDesigner: localhost:" << touchDesignerPort << "\n";
        info << "MadMapper: localhost:" << madMapperPort << "\n";
        info << "VDMX: localhost:" << vdmxPort << "\n";
        info << "Millumin: localhost:" << milluminPort << "\n\n";
        info << "Current SMPTE: " << syncData.smpte.toString() << "\n";
        info << "BPM: " << syncData.bpm << "\n";
        info << "Frame Rate: " << videoFrameRate.load() << " fps\n";
        info << "Audio Level: " << syncData.audioLevel << "\n";
        info << "Dominant Freq: " << syncData.dominantFrequency << " Hz\n";
        return info;
    }
};

} // namespace Echoel

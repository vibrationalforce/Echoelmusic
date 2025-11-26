#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>

namespace Eoel {

/**
 * DJEquipmentIntegration - Professional DJ hardware integration
 *
 * Supported Pioneer DJ equipment:
 * - CDJ-3000, CDJ-2000NXS2, CDJ-900NXS
 * - XDJ-1000MK2, XDJ-RX3, XDJ-XZ
 * - DJM-V10, DJM-900NXS2, DJM-A9
 *
 * Supported Denon DJ:
 * - SC6000, SC5000, SC Live 4
 * - X1850 Prime mixer
 *
 * Supported Native Instruments:
 * - Traktor Kontrol S4/S8/S2
 * - Traktor Kontrol Z2 mixer
 *
 * Supported Rane:
 * - Seventy-Two, Twelve
 *
 * Features:
 * - Pro DJ Link (sync BPM, beat grid, waveform)
 * - HID mode (ultra-low latency control)
 * - DVS (Digital Vinyl System) - Serato, Traktor
 * - Beatport/Tidal streaming integration
 * - Rekordbox, Serato, Traktor library sync
 * - Auto-BPM detection
 * - Beat grid alignment
 * - Hot cues, loops, samples
 * - Effects send/return
 */
class DJEquipmentIntegration
{
public:
    enum class DeviceType
    {
        CDJPlayer,
        Mixer,
        Controller,
        DVSInterface
    };

    enum class SyncMode
    {
        Off,
        BPMOnly,           // Sync tempo only
        BeatSync,          // Sync tempo + beat grid
        QuantizeSync       // Sync + quantize to beats
    };

    struct DJDevice
    {
        juce::String name;
        juce::String identifier;
        DeviceType type;
        int channelNumber = 1;          // Deck/channel number
        bool proDJLinkEnabled = false;
        bool hidModeEnabled = false;
        juce::IPAddress ipAddress;      // For Pro DJ Link network
    };

    struct TrackInfo
    {
        juce::String title;
        juce::String artist;
        juce::String album;
        double bpm = 120.0;
        double duration = 0.0;
        int key = 0;                    // Camelot key (1-12)
        juce::String keyName;           // "8A", "5B", etc.
        juce::File audioFile;
    };

    struct DeckState
    {
        TrackInfo currentTrack;
        double playPosition = 0.0;      // Seconds
        double bpm = 120.0;
        double tempo = 0.0;             // Pitch fader (-8% to +8%)
        bool playing = false;
        bool cueing = false;
        SyncMode syncMode = SyncMode::Off;

        // Hot cues
        std::array<double, 8> hotCues;  // 8 hot cue points

        // Loop
        bool loopActive = false;
        double loopStart = 0.0;
        double loopEnd = 0.0;

        // Waveform
        std::vector<float> waveform;
        std::vector<float> beatGrid;
    };

    DJEquipmentIntegration();
    ~DJEquipmentIntegration();

    // ===========================
    // Device Management
    // ===========================

    /** Scan for DJ equipment on network and USB */
    void scanDevices();

    /** Get detected devices */
    std::vector<DJDevice> getDevices() const { return m_devices; }

    /** Enable device */
    void enableDevice(const juce::String& identifier);

    /** Disable device */
    void disableDevice(const juce::String& identifier);

    // ===========================
    // Pro DJ Link
    // ===========================

    /**
     * Enable Pioneer Pro DJ Link network sync
     * Allows multiple CDJs/XDJs to sync BPM, beat grid, etc.
     */
    void enableProDJLink(bool enable);

    /** Check if connected to Pro DJ Link network */
    bool isProDJLinkActive() const { return m_proDJLinkActive; }

    /** Get devices on Pro DJ Link network */
    std::vector<DJDevice> getProDJLinkDevices() const;

    /** Sync with Pro DJ Link master device */
    void syncWithMaster(int deckNumber);

    // ===========================
    // Deck Control
    // ===========================

    /** Load track to deck */
    void loadTrack(int deckNumber, const juce::File& audioFile);

    /** Play/pause */
    void play(int deckNumber, bool shouldPlay);

    /** Cue (jump to cue point) */
    void cue(int deckNumber);

    /** Set play position (seconds) */
    void setPlayPosition(int deckNumber, double positionSeconds);

    /** Set tempo (pitch) */
    void setTempo(int deckNumber, double tempoPercent); // -8.0 to +8.0

    /** Enable/disable sync */
    void setSync(int deckNumber, SyncMode mode);

    // ===========================
    // Hot Cues & Loops
    // ===========================

    /** Set hot cue point */
    void setHotCue(int deckNumber, int cueIndex, double positionSeconds);

    /** Trigger hot cue */
    void triggerHotCue(int deckNumber, int cueIndex);

    /** Delete hot cue */
    void deleteHotCue(int deckNumber, int cueIndex);

    /** Set loop in/out points */
    void setLoop(int deckNumber, double startSeconds, double endSeconds);

    /** Activate/deactivate loop */
    void activateLoop(int deckNumber, bool active);

    /** Auto-loop (1, 2, 4, 8, 16 beats) */
    void autoLoop(int deckNumber, int numBeats);

    // ===========================
    // Beat Grid & Analysis
    // ===========================

    /** Auto-detect BPM */
    double detectBPM(const juce::File& audioFile);

    /** Auto-detect key (Camelot) */
    juce::String detectKey(const juce::File& audioFile);

    /** Generate beat grid */
    std::vector<float> generateBeatGrid(const juce::File& audioFile, double bpm);

    /** Align beat grids between decks */
    void alignBeatGrids(int deck1, int deck2);

    // ===========================
    // Mixer Control
    // ===========================

    /** Set channel fader */
    void setChannelFader(int channel, float level); // 0.0 to 1.0

    /** Set crossfader */
    void setCrossfader(float position); // -1.0 (A) to +1.0 (B)

    /** Set EQ */
    void setEQ(int channel, float low, float mid, float high);

    /** Set filter */
    void setFilter(int channel, float filterValue); // -1.0 (HPF) to +1.0 (LPF)

    /** Send to FX */
    void sendToFX(int channel, int fxUnit, float amount);

    // ===========================
    // DVS (Digital Vinyl System)
    // ===========================

    /**
     * Enable DVS mode (control software with timecode vinyl/CD)
     * Compatible with Serato, Traktor timecode
     */
    void enableDVS(bool enable, const juce::String& timecodeType = "Serato");

    /** Calibrate DVS (detect vinyl/CD speed) */
    void calibrateDVS();

    // ===========================
    // Library Integration
    // ===========================

    /** Import Rekordbox library */
    void importRekordboxLibrary(const juce::File& rekordboxXML);

    /** Import Serato library */
    void importSeratoLibrary(const juce::File& seratoDirectory);

    /** Import Traktor library */
    void importTraktorLibrary(const juce::File& traktorNML);

    /** Export library */
    void exportLibrary(const juce::File& outputFile, const juce::String& format);

    // ===========================
    // Streaming Services
    // ===========================

    /** Connect to Beatport Streaming */
    void connectBeatport(const juce::String& username, const juce::String& password);

    /** Connect to Tidal */
    void connectTidal(const juce::String& accessToken);

    /** Search streaming catalog */
    std::vector<TrackInfo> searchStreaming(const juce::String& query);

    // ===========================
    // State
    // ===========================

    /** Get deck state */
    DeckState getDeckState(int deckNumber) const;

    /** Get master BPM (from sync master deck) */
    double getMasterBPM() const { return m_masterBPM; }

    // ===========================
    // Callbacks
    // ===========================

    std::function<void(int deck, const TrackInfo& track)> onTrackLoaded;
    std::function<void(int deck, bool playing)> onPlayStateChanged;
    std::function<void(int deck, double bpm)> onBPMChanged;
    std::function<void(int deck, double position)> onPlayPositionChanged;
    std::function<void(const DJDevice& device)> onDeviceConnected;
    std::function<void(const juce::String& identifier)> onDeviceDisconnected;

private:
    std::vector<DJDevice> m_devices;
    std::map<int, DeckState> m_deckStates;

    bool m_proDJLinkActive = false;
    bool m_dvsEnabled = false;
    juce::String m_timecodeType;

    double m_masterBPM = 120.0;
    int m_masterDeck = 1;

    juce::CriticalSection m_lock;

    // Pro DJ Link network
    std::unique_ptr<juce::DatagramSocket> m_proDJLinkSocket;
    void sendProDJLinkMessage(const juce::MemoryBlock& data);
    void processProDJLinkMessage(const juce::MemoryBlock& data);

    // HID communication
    std::map<juce::String, std::unique_ptr<juce::HIDDevice>> m_hidDevices;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(DJEquipmentIntegration)
};

} // namespace Eoel

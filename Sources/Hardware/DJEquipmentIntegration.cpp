#include "DJEquipmentIntegration.h"

namespace Echoelmusic {

DJEquipmentIntegration::DJEquipmentIntegration()
{
    scanDevices();
}

DJEquipmentIntegration::~DJEquipmentIntegration()
{
    enableProDJLink(false);
}

// ===========================
// Device Management
// ===========================

void DJEquipmentIntegration::scanDevices()
{
    juce::ScopedLock sl(m_lock);

    m_devices.clear();

    DBG("Scanning for DJ equipment...");

    // Scan for HID devices (controllers in HID mode)
    auto hidDevices = juce::HIDDevice::getAvailableDevices();
    for (const auto& device : hidDevices)
    {
        DJDevice djDevice;
        djDevice.name = device.name;
        djDevice.identifier = juce::String(device.vendorId) + ":" + juce::String(device.productId);

        // Detect device type
        juce::String name = device.name.toLowerCase();

        if (name.contains("cdj") || name.contains("xdj"))
        {
            djDevice.type = DeviceType::CDJPlayer;
        }
        else if (name.contains("djm") || name.contains("mixer"))
        {
            djDevice.type = DeviceType::Mixer;
        }
        else if (name.contains("traktor") || name.contains("kontrol") ||
                 name.contains("serato") || name.contains("rane"))
        {
            djDevice.type = DeviceType::Controller;
        }

        djDevice.hidModeEnabled = true;

        m_devices.push_back(djDevice);

        DBG("Found DJ device (HID): " << djDevice.name);
    }

    // Scan for Pro DJ Link devices on network (UDP broadcast)
    // Real implementation would scan UDP port 50000
    DBG("Scanning network for Pro DJ Link devices...");

    // Simulate network scan
    // In real implementation, would send UDP broadcasts and listen for responses

    DBG("DJ equipment scan complete: " << m_devices.size() << " device(s) found");
}

void DJEquipmentIntegration::enableDevice(const juce::String& identifier)
{
    juce::ScopedLock sl(m_lock);

    // Find device
    DJDevice* device = nullptr;
    for (auto& dev : m_devices)
    {
        if (dev.identifier == identifier)
        {
            device = &dev;
            break;
        }
    }

    if (!device)
        return;

    // Open HID connection
    if (device->hidModeEnabled)
    {
        // Parse vendor:product ID
        juce::StringArray parts = juce::StringArray::fromTokens(identifier, ":", "");
        if (parts.size() == 2)
        {
            int vendorId = parts[0].getIntValue();
            int productId = parts[1].getIntValue();

            auto hidDevice = juce::HIDDevice::openDevice(vendorId, productId);
            if (hidDevice)
            {
                m_hidDevices[identifier] = std::move(hidDevice);
                DBG("DJ device enabled (HID): " << device->name);

                if (onDeviceConnected)
                    onDeviceConnected(*device);
            }
        }
    }
}

void DJEquipmentIntegration::disableDevice(const juce::String& identifier)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_hidDevices.find(identifier);
    if (it != m_hidDevices.end())
    {
        m_hidDevices.erase(it);
        DBG("DJ device disabled: " << identifier);

        if (onDeviceDisconnected)
            onDeviceDisconnected(identifier);
    }
}

// ===========================
// Pro DJ Link
// ===========================

void DJEquipmentIntegration::enableProDJLink(bool enable)
{
    juce::ScopedLock sl(m_lock);

    if (enable && !m_proDJLinkActive)
    {
        // Create UDP socket for Pro DJ Link
        m_proDJLinkSocket = std::make_unique<juce::DatagramSocket>();

        if (m_proDJLinkSocket->bindToPort(50000)) // Pro DJ Link port
        {
            m_proDJLinkActive = true;
            DBG("Pro DJ Link ENABLED - Listening on port 50000");

            // Send announcement broadcast
            // Real implementation would send Pioneer-specific protocol messages
        }
        else
        {
            DBG("Failed to enable Pro DJ Link - port 50000 unavailable");
            m_proDJLinkSocket.reset();
        }
    }
    else if (!enable && m_proDJLinkActive)
    {
        m_proDJLinkSocket.reset();
        m_proDJLinkActive = false;
        DBG("Pro DJ Link DISABLED");
    }
}

std::vector<DJEquipmentIntegration::DJDevice> DJEquipmentIntegration::getProDJLinkDevices() const
{
    std::vector<DJDevice> proDJLinkDevices;

    for (const auto& device : m_devices)
    {
        if (device.proDJLinkEnabled)
            proDJLinkDevices.push_back(device);
    }

    return proDJLinkDevices;
}

void DJEquipmentIntegration::syncWithMaster(int deckNumber)
{
    juce::ScopedLock sl(m_lock);

    if (!m_proDJLinkActive)
        return;

    m_masterDeck = deckNumber;

    auto it = m_deckStates.find(deckNumber);
    if (it != m_deckStates.end())
    {
        m_masterBPM = it->second.bpm;
        DBG("Syncing to deck " << deckNumber << " - Master BPM: " << m_masterBPM);
    }
}

// ===========================
// Deck Control
// ===========================

void DJEquipmentIntegration::loadTrack(int deckNumber, const juce::File& audioFile)
{
    juce::ScopedLock sl(m_lock);

    DeckState& deck = m_deckStates[deckNumber];

    deck.currentTrack.audioFile = audioFile;
    deck.currentTrack.title = audioFile.getFileNameWithoutExtension();
    deck.playPosition = 0.0;
    deck.playing = false;

    // Auto-detect BPM
    deck.currentTrack.bpm = detectBPM(audioFile);
    deck.bpm = deck.currentTrack.bpm;

    // Auto-detect key
    deck.currentTrack.keyName = detectKey(audioFile);

    // Generate beat grid
    deck.beatGrid = generateBeatGrid(audioFile, deck.currentTrack.bpm);

    DBG("Track loaded on deck " << deckNumber << ": " << deck.currentTrack.title);
    DBG("  BPM: " << deck.currentTrack.bpm << ", Key: " << deck.currentTrack.keyName);

    if (onTrackLoaded)
        onTrackLoaded(deckNumber, deck.currentTrack);
}

void DJEquipmentIntegration::play(int deckNumber, bool shouldPlay)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end())
        return;

    it->second.playing = shouldPlay;

    DBG("Deck " << deckNumber << ": " << (shouldPlay ? "PLAY" : "PAUSE"));

    if (onPlayStateChanged)
        onPlayStateChanged(deckNumber, shouldPlay);
}

void DJEquipmentIntegration::cue(int deckNumber)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end())
        return;

    it->second.playing = false;
    it->second.playPosition = 0.0; // Jump to start (or last cue point)

    DBG("Deck " << deckNumber << ": CUE");
}

void DJEquipmentIntegration::setPlayPosition(int deckNumber, double positionSeconds)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end())
        return;

    it->second.playPosition = positionSeconds;

    if (onPlayPositionChanged)
        onPlayPositionChanged(deckNumber, positionSeconds);
}

void DJEquipmentIntegration::setTempo(int deckNumber, double tempoPercent)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end())
        return;

    tempoPercent = juce::jlimit(-8.0, 8.0, tempoPercent); // ±8% range
    it->second.tempo = tempoPercent;

    // Calculate adjusted BPM
    double adjustedBPM = it->second.currentTrack.bpm * (1.0 + tempoPercent / 100.0);
    it->second.bpm = adjustedBPM;

    DBG("Deck " << deckNumber << " tempo: " << tempoPercent << "% (BPM: " << adjustedBPM << ")");

    if (onBPMChanged)
        onBPMChanged(deckNumber, adjustedBPM);
}

void DJEquipmentIntegration::setSync(int deckNumber, SyncMode mode)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end())
        return;

    it->second.syncMode = mode;

    if (mode != SyncMode::Off)
    {
        // Sync to master BPM
        double targetBPM = m_masterBPM;
        double tempoPercent = ((targetBPM / it->second.currentTrack.bpm) - 1.0) * 100.0;
        setTempo(deckNumber, tempoPercent);

        DBG("Deck " << deckNumber << " SYNC enabled - matching BPM: " << targetBPM);
    }
    else
    {
        DBG("Deck " << deckNumber << " SYNC disabled");
    }
}

// ===========================
// Hot Cues & Loops
// ===========================

void DJEquipmentIntegration::setHotCue(int deckNumber, int cueIndex, double positionSeconds)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end() || cueIndex < 0 || cueIndex >= 8)
        return;

    it->second.hotCues[cueIndex] = positionSeconds;

    DBG("Deck " << deckNumber << " - Hot Cue " << (cueIndex + 1) << " set at " << positionSeconds << "s");
}

void DJEquipmentIntegration::triggerHotCue(int deckNumber, int cueIndex)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end() || cueIndex < 0 || cueIndex >= 8)
        return;

    double cuePosition = it->second.hotCues[cueIndex];
    if (cuePosition >= 0.0)
    {
        setPlayPosition(deckNumber, cuePosition);
        DBG("Deck " << deckNumber << " - Hot Cue " << (cueIndex + 1) << " triggered");
    }
}

void DJEquipmentIntegration::deleteHotCue(int deckNumber, int cueIndex)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end() || cueIndex < 0 || cueIndex >= 8)
        return;

    it->second.hotCues[cueIndex] = -1.0; // Invalid position
    DBG("Deck " << deckNumber << " - Hot Cue " << (cueIndex + 1) << " deleted");
}

void DJEquipmentIntegration::setLoop(int deckNumber, double startSeconds, double endSeconds)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end())
        return;

    it->second.loopStart = startSeconds;
    it->second.loopEnd = endSeconds;

    DBG("Deck " << deckNumber << " - Loop set: " << startSeconds << "s to " << endSeconds << "s");
}

void DJEquipmentIntegration::activateLoop(int deckNumber, bool active)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end())
        return;

    it->second.loopActive = active;

    DBG("Deck " << deckNumber << " - Loop " << (active ? "ACTIVE" : "INACTIVE"));
}

void DJEquipmentIntegration::autoLoop(int deckNumber, int numBeats)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it == m_deckStates.end())
        return;

    // Calculate loop length in seconds
    double beatDuration = 60.0 / it->second.bpm;
    double loopLength = beatDuration * numBeats;

    double currentPos = it->second.playPosition;
    setLoop(deckNumber, currentPos, currentPos + loopLength);
    activateLoop(deckNumber, true);

    DBG("Deck " << deckNumber << " - Auto-loop: " << numBeats << " beats");
}

// ===========================
// Beat Grid & Analysis
// ===========================

double DJEquipmentIntegration::detectBPM(const juce::File& audioFile)
{
    // Real implementation would use beat detection algorithm
    // For now, return default
    double bpm = 120.0;

    DBG("BPM detection for: " << audioFile.getFileName() << " → " << bpm << " BPM");

    return bpm;
}

juce::String DJEquipmentIntegration::detectKey(const juce::File& audioFile)
{
    // Real implementation would use key detection algorithm (Camelot wheel)
    // For now, return default
    juce::String key = "8A";

    DBG("Key detection for: " << audioFile.getFileName() << " → " << key);

    return key;
}

std::vector<float> DJEquipmentIntegration::generateBeatGrid(const juce::File& audioFile, double bpm)
{
    std::vector<float> beatGrid;

    // Real implementation would analyze audio and mark beat positions
    // For now, create regular grid

    double duration = 180.0; // Assume 3 minutes
    double beatInterval = 60.0 / bpm;

    for (double time = 0.0; time < duration; time += beatInterval)
    {
        beatGrid.push_back(static_cast<float>(time));
    }

    DBG("Beat grid generated: " << beatGrid.size() << " beats");

    return beatGrid;
}

void DJEquipmentIntegration::alignBeatGrids(int deck1, int deck2)
{
    juce::ScopedLock sl(m_lock);

    auto it1 = m_deckStates.find(deck1);
    auto it2 = m_deckStates.find(deck2);

    if (it1 == m_deckStates.end() || it2 == m_deckStates.end())
        return;

    // Align beat grids (phase sync)
    DBG("Aligning beat grids between deck " << deck1 << " and deck " << deck2);

    // Real implementation would adjust play positions to align beats
}

// ===========================
// Mixer Control
// ===========================

void DJEquipmentIntegration::setChannelFader(int channel, float level)
{
    level = juce::jlimit(0.0f, 1.0f, level);
    DBG("Channel " << channel << " fader: " << level);
}

void DJEquipmentIntegration::setCrossfader(float position)
{
    position = juce::jlimit(-1.0f, 1.0f, position);
    DBG("Crossfader: " << position);
}

void DJEquipmentIntegration::setEQ(int channel, float low, float mid, float high)
{
    low = juce::jlimit(0.0f, 1.0f, low);
    mid = juce::jlimit(0.0f, 1.0f, mid);
    high = juce::jlimit(0.0f, 1.0f, high);

    DBG("Channel " << channel << " EQ - L:" << low << " M:" << mid << " H:" << high);
}

void DJEquipmentIntegration::setFilter(int channel, float filterValue)
{
    filterValue = juce::jlimit(-1.0f, 1.0f, filterValue);
    DBG("Channel " << channel << " filter: " << filterValue);
}

void DJEquipmentIntegration::sendToFX(int channel, int fxUnit, float amount)
{
    amount = juce::jlimit(0.0f, 1.0f, amount);
    DBG("Channel " << channel << " → FX " << fxUnit << ": " << amount);
}

// ===========================
// DVS
// ===========================

void DJEquipmentIntegration::enableDVS(bool enable, const juce::String& timecodeType)
{
    m_dvsEnabled = enable;
    m_timecodeType = timecodeType;

    if (enable)
    {
        DBG("DVS ENABLED - Timecode: " << timecodeType);
        DBG("Connect turntables/CDJs with timecode vinyl/CD");
    }
    else
    {
        DBG("DVS DISABLED");
    }
}

void DJEquipmentIntegration::calibrateDVS()
{
    DBG("DVS calibration - Play timecode vinyl/CD at 33 1/3 RPM");
    // Real implementation would detect timecode signal and calibrate
}

// ===========================
// Library Integration
// ===========================

void DJEquipmentIntegration::importRekordboxLibrary(const juce::File& rekordboxXML)
{
    DBG("Importing Rekordbox library: " << rekordboxXML.getFullPathName());
    // Parse Rekordbox XML database
}

void DJEquipmentIntegration::importSeratoLibrary(const juce::File& seratoDirectory)
{
    DBG("Importing Serato library: " << seratoDirectory.getFullPathName());
    // Parse Serato database files
}

void DJEquipmentIntegration::importTraktorLibrary(const juce::File& traktorNML)
{
    DBG("Importing Traktor library: " << traktorNML.getFullPathName());
    // Parse Traktor NML file
}

void DJEquipmentIntegration::exportLibrary(const juce::File& outputFile, const juce::String& format)
{
    DBG("Exporting library to: " << outputFile.getFullPathName() << " (Format: " << format << ")");
}

// ===========================
// Streaming Services
// ===========================

void DJEquipmentIntegration::connectBeatport(const juce::String& username, const juce::String& password)
{
    DBG("Connecting to Beatport Streaming - User: " << username);
    // Real implementation would authenticate with Beatport API
}

void DJEquipmentIntegration::connectTidal(const juce::String& accessToken)
{
    DBG("Connecting to Tidal");
    // Real implementation would authenticate with Tidal API
}

std::vector<DJEquipmentIntegration::TrackInfo> DJEquipmentIntegration::searchStreaming(const juce::String& query)
{
    std::vector<TrackInfo> results;

    DBG("Searching streaming catalogs: " << query);

    // Real implementation would query Beatport/Tidal APIs

    return results;
}

// ===========================
// State
// ===========================

DJEquipmentIntegration::DeckState DJEquipmentIntegration::getDeckState(int deckNumber) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_deckStates.find(deckNumber);
    if (it != m_deckStates.end())
        return it->second;

    return DeckState();
}

// ===========================
// Pro DJ Link Protocol
// ===========================

void DJEquipmentIntegration::sendProDJLinkMessage(const juce::MemoryBlock& data)
{
    if (!m_proDJLinkSocket || !m_proDJLinkActive)
        return;

    // Send UDP message to Pro DJ Link network
    // Real implementation would use Pioneer protocol format
}

void DJEquipmentIntegration::processProDJLinkMessage(const juce::MemoryBlock& data)
{
    // Parse incoming Pro DJ Link messages
    // Real implementation would decode Pioneer protocol
}

} // namespace Echoelmusic

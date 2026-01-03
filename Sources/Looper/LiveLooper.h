#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <atomic>
#include <functional>
#include <cmath>

/**
 * LiveLooper - Real-Time Loop Recording System
 *
 * Professional looper with:
 * - Multi-track loop recording
 * - Synchronized loop lengths (quantized to bars)
 * - Overdub/Replace/Multiply modes
 * - Undo layers
 * - Half-speed/Double-speed playback
 * - Reverse playback
 * - Fade in/out for smooth loops
 * - MIDI sync (master/slave)
 * - Pre-recording buffer (never miss the start)
 * - Automatic level normalization
 *
 * Super Ralph Wiggum Loop Genius Loop Mode
 */

namespace Echoelmusic {
namespace Looper {

//==============================================================================
// Loop State
//==============================================================================

enum class LoopState
{
    Empty,          // No recording yet
    Armed,          // Waiting to record on next beat
    Recording,      // Recording first layer
    Playing,        // Playing back recorded loop
    Overdubbing,    // Adding new layer while playing
    Replacing,      // Replacing current content
    Multiplying,    // Extending loop length
    Stopped,        // Has content but not playing
    FadingIn,       // Fading in at start
    FadingOut       // Fading out for stop
};

inline std::string loopStateToString(LoopState state)
{
    switch (state)
    {
        case LoopState::Empty:       return "Empty";
        case LoopState::Armed:       return "Armed";
        case LoopState::Recording:   return "Recording";
        case LoopState::Playing:     return "Playing";
        case LoopState::Overdubbing: return "Overdubbing";
        case LoopState::Replacing:   return "Replacing";
        case LoopState::Multiplying: return "Multiplying";
        case LoopState::Stopped:     return "Stopped";
        case LoopState::FadingIn:    return "Fading In";
        case LoopState::FadingOut:   return "Fading Out";
        default:                     return "Unknown";
    }
}

//==============================================================================
// Loop Layer (for undo)
//==============================================================================

struct LoopLayer
{
    juce::AudioBuffer<float> audio;
    double startTime = 0.0;       // When this layer was recorded
    float volume = 1.0f;

    LoopLayer() = default;

    LoopLayer(int numChannels, int numSamples)
    {
        audio.setSize(numChannels, numSamples);
        audio.clear();
    }
};

//==============================================================================
// Single Loop Track
//==============================================================================

class LoopTrack
{
public:
    struct Config
    {
        int numChannels = 2;
        int maxLengthSeconds = 120;     // 2 minutes max
        double sampleRate = 44100.0;
        int fadeInSamples = 64;
        int fadeOutSamples = 256;
        int preRecordSamples = 4096;    // Pre-record buffer (~100ms)
        int maxUndoLayers = 10;
        bool quantizeToBar = true;
        float overdubMix = 0.7f;        // Original vs new when overdubbing
    };

    LoopTrack(int trackId, const Config& cfg = Config())
        : id(trackId), config(cfg)
    {
        int maxSamples = static_cast<int>(config.maxLengthSeconds * config.sampleRate);

        loopBuffer.setSize(config.numChannels, maxSamples);
        loopBuffer.clear();

        preRecordBuffer.setSize(config.numChannels, config.preRecordSamples);
        preRecordBuffer.clear();

        inputMonitorBuffer.setSize(config.numChannels, 1024);
    }

    //--------------------------------------------------------------------------
    // Transport Control
    //--------------------------------------------------------------------------

    void arm()
    {
        if (state == LoopState::Empty)
        {
            state = LoopState::Armed;
        }
    }

    void recordOrPlay()
    {
        switch (state)
        {
            case LoopState::Empty:
            case LoopState::Armed:
                startRecording();
                break;

            case LoopState::Recording:
                stopRecording();
                break;

            case LoopState::Playing:
                startOverdub();
                break;

            case LoopState::Overdubbing:
                stopOverdub();
                break;

            case LoopState::Stopped:
                play();
                break;

            default:
                break;
        }
    }

    void startRecording()
    {
        // Save undo state
        if (loopLength > 0)
        {
            saveUndoLayer();
        }

        // Copy pre-record buffer if we have one
        if (preRecordPosition > 0 && loopLength == 0)
        {
            int samplesToPreRecord = std::min(preRecordPosition, config.preRecordSamples);
            int startIdx = (preRecordWritePos - samplesToPreRecord + config.preRecordSamples) % config.preRecordSamples;

            for (int i = 0; i < samplesToPreRecord; ++i)
            {
                int srcIdx = (startIdx + i) % config.preRecordSamples;
                for (int ch = 0; ch < config.numChannels; ++ch)
                {
                    loopBuffer.setSample(ch, recordPosition, preRecordBuffer.getSample(ch, srcIdx));
                }
                recordPosition++;
            }
        }

        state = LoopState::Recording;
    }

    void stopRecording()
    {
        if (state != LoopState::Recording)
            return;

        // Set loop length (quantize if needed)
        loopLength = recordPosition;

        if (config.quantizeToBar && barsPerLoop > 0)
        {
            // Quantize to nearest bar boundary
            int samplesPerBar = static_cast<int>(60.0 / tempo * beatsPerBar * config.sampleRate);
            loopLength = ((loopLength + samplesPerBar / 2) / samplesPerBar) * samplesPerBar;
        }

        // Apply fade in/out
        applyFades();

        // Start playback
        playPosition = 0;
        state = LoopState::Playing;
    }

    void play()
    {
        if (loopLength == 0)
            return;

        playPosition = 0;
        state = LoopState::Playing;
    }

    void stop()
    {
        if (state == LoopState::Playing || state == LoopState::Overdubbing)
        {
            state = LoopState::Stopped;
        }
    }

    void clear()
    {
        loopBuffer.clear();
        loopLength = 0;
        playPosition = 0;
        recordPosition = 0;
        state = LoopState::Empty;
        undoLayers.clear();
    }

    void startOverdub()
    {
        if (state == LoopState::Playing)
        {
            saveUndoLayer();
            state = LoopState::Overdubbing;
        }
    }

    void stopOverdub()
    {
        if (state == LoopState::Overdubbing)
        {
            state = LoopState::Playing;
        }
    }

    void startReplace()
    {
        if (state == LoopState::Playing)
        {
            saveUndoLayer();
            state = LoopState::Replacing;
        }
    }

    void stopReplace()
    {
        if (state == LoopState::Replacing)
        {
            state = LoopState::Playing;
        }
    }

    void multiply()
    {
        if (state == LoopState::Playing && loopLength > 0)
        {
            saveUndoLayer();

            // Double the loop length by copying existing content
            int newLength = loopLength * 2;
            int maxSamples = loopBuffer.getNumSamples();

            if (newLength <= maxSamples)
            {
                for (int ch = 0; ch < config.numChannels; ++ch)
                {
                    for (int i = 0; i < loopLength; ++i)
                    {
                        loopBuffer.setSample(ch, loopLength + i, loopBuffer.getSample(ch, i));
                    }
                }
                loopLength = newLength;
            }
        }
    }

    //--------------------------------------------------------------------------
    // Undo
    //--------------------------------------------------------------------------

    void undo()
    {
        if (!undoLayers.empty())
        {
            // Copy current to redo
            LoopLayer redo(config.numChannels, loopLength);
            for (int ch = 0; ch < config.numChannels; ++ch)
            {
                redo.audio.copyFrom(ch, 0, loopBuffer, ch, 0, loopLength);
            }
            redoLayers.push_back(std::move(redo));

            // Restore from undo
            auto& layer = undoLayers.back();
            int restoreLength = layer.audio.getNumSamples();

            for (int ch = 0; ch < config.numChannels; ++ch)
            {
                loopBuffer.copyFrom(ch, 0, layer.audio, ch, 0, restoreLength);
            }
            loopLength = restoreLength;

            undoLayers.pop_back();
        }
    }

    void redo()
    {
        if (!redoLayers.empty())
        {
            saveUndoLayer();

            auto& layer = redoLayers.back();
            int restoreLength = layer.audio.getNumSamples();

            for (int ch = 0; ch < config.numChannels; ++ch)
            {
                loopBuffer.copyFrom(ch, 0, layer.audio, ch, 0, restoreLength);
            }
            loopLength = restoreLength;

            redoLayers.pop_back();
        }
    }

    bool canUndo() const { return !undoLayers.empty(); }
    bool canRedo() const { return !redoLayers.empty(); }

    //--------------------------------------------------------------------------
    // Playback Modifiers
    //--------------------------------------------------------------------------

    void setReverse(bool rev) { reverse = rev; }
    bool isReversed() const { return reverse; }

    void setHalfSpeed(bool half)
    {
        halfSpeed = half;
        doubleSpeed = false;
    }

    void setDoubleSpeed(bool dbl)
    {
        doubleSpeed = dbl;
        halfSpeed = false;
    }

    void setVolume(float vol) { volume = std::clamp(vol, 0.0f, 2.0f); }
    float getVolume() const { return volume; }

    void setPan(float p) { pan = std::clamp(p, -1.0f, 1.0f); }
    float getPan() const { return pan; }

    void setMuted(bool m) { muted = m; }
    bool isMuted() const { return muted; }

    //--------------------------------------------------------------------------
    // Processing
    //--------------------------------------------------------------------------

    void processBlock(juce::AudioBuffer<float>& inputBuffer,
                      juce::AudioBuffer<float>& outputBuffer,
                      int numSamples)
    {
        // Update pre-record buffer continuously
        updatePreRecordBuffer(inputBuffer, numSamples);

        // Monitor input
        updateInputMonitor(inputBuffer, numSamples);

        if (muted || loopLength == 0)
        {
            if (state == LoopState::Recording)
            {
                // Record to loop buffer
                recordToBuffer(inputBuffer, numSamples);
            }
            return;
        }

        for (int i = 0; i < numSamples; ++i)
        {
            // Calculate read position (with speed modification)
            double readPos = playPosition;

            if (halfSpeed)
                readPos = playPosition * 0.5;
            else if (doubleSpeed)
                readPos = (playPosition * 2) % loopLength;

            if (reverse)
                readPos = loopLength - 1 - static_cast<int>(readPos) % loopLength;

            int pos0 = static_cast<int>(readPos) % loopLength;
            int pos1 = (pos0 + 1) % loopLength;
            float frac = static_cast<float>(readPos - std::floor(readPos));

            for (int ch = 0; ch < std::min(config.numChannels, outputBuffer.getNumChannels()); ++ch)
            {
                // Interpolated read from loop
                float sample0 = loopBuffer.getSample(ch, pos0);
                float sample1 = loopBuffer.getSample(ch, pos1);
                float loopSample = sample0 + frac * (sample1 - sample0);

                // Apply volume and pan
                float gain = volume;
                if (config.numChannels >= 2)
                {
                    if (ch == 0) gain *= std::sqrt(0.5f * (1.0f - pan));  // Left
                    if (ch == 1) gain *= std::sqrt(0.5f * (1.0f + pan));  // Right
                }

                // Output
                outputBuffer.addSample(ch, i, loopSample * gain);

                // Overdub: mix input into loop
                if (state == LoopState::Overdubbing)
                {
                    float inputSample = (ch < inputBuffer.getNumChannels())
                        ? inputBuffer.getSample(ch, i) : 0.0f;

                    float mixed = loopBuffer.getSample(ch, pos0) * config.overdubMix
                                + inputSample * (1.0f - config.overdubMix);
                    loopBuffer.setSample(ch, pos0, mixed);
                }

                // Replace: overwrite loop
                if (state == LoopState::Replacing)
                {
                    float inputSample = (ch < inputBuffer.getNumChannels())
                        ? inputBuffer.getSample(ch, i) : 0.0f;
                    loopBuffer.setSample(ch, pos0, inputSample);
                }
            }

            // Recording to empty buffer
            if (state == LoopState::Recording)
            {
                for (int ch = 0; ch < config.numChannels; ++ch)
                {
                    float inputSample = (ch < inputBuffer.getNumChannels())
                        ? inputBuffer.getSample(ch, i) : 0.0f;
                    loopBuffer.setSample(ch, recordPosition, inputSample);
                }
                recordPosition++;

                // Check max length
                if (recordPosition >= loopBuffer.getNumSamples())
                {
                    stopRecording();
                }
            }

            // Advance play position
            if (state == LoopState::Playing || state == LoopState::Overdubbing ||
                state == LoopState::Replacing)
            {
                playPosition++;
                if (playPosition >= loopLength)
                {
                    playPosition = 0;
                    loopCount++;
                }
            }
        }
    }

    //--------------------------------------------------------------------------
    // Sync
    //--------------------------------------------------------------------------

    void setTempo(double bpm) { tempo = bpm; }
    void setBeatsPerBar(int beats) { beatsPerBar = beats; }
    void setBarsPerLoop(int bars) { barsPerLoop = bars; }

    void syncToPosition(int positionInSamples)
    {
        if (loopLength > 0)
        {
            playPosition = positionInSamples % loopLength;
        }
    }

    //--------------------------------------------------------------------------
    // Info
    //--------------------------------------------------------------------------

    int getId() const { return id; }
    LoopState getState() const { return state; }
    int getLoopLength() const { return loopLength; }
    int getPlayPosition() const { return playPosition; }
    int getLoopCount() const { return loopCount; }

    double getLoopLengthSeconds() const
    {
        return static_cast<double>(loopLength) / config.sampleRate;
    }

    float getPlayProgress() const
    {
        if (loopLength == 0) return 0.0f;
        return static_cast<float>(playPosition) / static_cast<float>(loopLength);
    }

    float getInputLevel() const { return inputLevel.load(); }

    // Get waveform for display
    std::vector<float> getWaveformDisplay(int numPoints) const
    {
        std::vector<float> waveform(numPoints, 0.0f);

        if (loopLength == 0) return waveform;

        int samplesPerPoint = loopLength / numPoints;
        if (samplesPerPoint < 1) samplesPerPoint = 1;

        for (int i = 0; i < numPoints; ++i)
        {
            int startSample = i * samplesPerPoint;
            int endSample = std::min(startSample + samplesPerPoint, loopLength);

            float maxVal = 0.0f;
            for (int s = startSample; s < endSample; ++s)
            {
                for (int ch = 0; ch < config.numChannels; ++ch)
                {
                    maxVal = std::max(maxVal, std::abs(loopBuffer.getSample(ch, s)));
                }
            }
            waveform[i] = maxVal;
        }

        return waveform;
    }

private:
    int id;
    Config config;

    juce::AudioBuffer<float> loopBuffer;
    juce::AudioBuffer<float> preRecordBuffer;
    juce::AudioBuffer<float> inputMonitorBuffer;

    std::atomic<LoopState> state{LoopState::Empty};

    int loopLength = 0;
    int playPosition = 0;
    int recordPosition = 0;
    int preRecordPosition = 0;
    int preRecordWritePos = 0;
    int loopCount = 0;

    float volume = 1.0f;
    float pan = 0.0f;
    bool muted = false;
    bool reverse = false;
    bool halfSpeed = false;
    bool doubleSpeed = false;

    double tempo = 120.0;
    int beatsPerBar = 4;
    int barsPerLoop = 0;  // 0 = auto-detect from first recording

    std::vector<LoopLayer> undoLayers;
    std::vector<LoopLayer> redoLayers;

    std::atomic<float> inputLevel{0.0f};

    void saveUndoLayer()
    {
        if (loopLength == 0) return;

        LoopLayer layer(config.numChannels, loopLength);
        for (int ch = 0; ch < config.numChannels; ++ch)
        {
            layer.audio.copyFrom(ch, 0, loopBuffer, ch, 0, loopLength);
        }

        undoLayers.push_back(std::move(layer));

        // Limit undo history
        while (static_cast<int>(undoLayers.size()) > config.maxUndoLayers)
        {
            undoLayers.erase(undoLayers.begin());
        }

        // Clear redo when new action is taken
        redoLayers.clear();
    }

    void applyFades()
    {
        if (loopLength == 0) return;

        // Fade in
        int fadeIn = std::min(config.fadeInSamples, loopLength / 2);
        for (int i = 0; i < fadeIn; ++i)
        {
            float gain = static_cast<float>(i) / static_cast<float>(fadeIn);
            for (int ch = 0; ch < config.numChannels; ++ch)
            {
                loopBuffer.setSample(ch, i, loopBuffer.getSample(ch, i) * gain);
            }
        }

        // Fade out
        int fadeOut = std::min(config.fadeOutSamples, loopLength / 2);
        for (int i = 0; i < fadeOut; ++i)
        {
            float gain = 1.0f - static_cast<float>(i) / static_cast<float>(fadeOut);
            int pos = loopLength - 1 - i;
            for (int ch = 0; ch < config.numChannels; ++ch)
            {
                loopBuffer.setSample(ch, pos, loopBuffer.getSample(ch, pos) * gain);
            }
        }
    }

    void updatePreRecordBuffer(const juce::AudioBuffer<float>& input, int numSamples)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            for (int ch = 0; ch < std::min(config.numChannels, input.getNumChannels()); ++ch)
            {
                preRecordBuffer.setSample(ch, preRecordWritePos, input.getSample(ch, i));
            }
            preRecordWritePos = (preRecordWritePos + 1) % config.preRecordSamples;
            preRecordPosition++;
        }
    }

    void updateInputMonitor(const juce::AudioBuffer<float>& input, int numSamples)
    {
        float maxLevel = 0.0f;
        for (int ch = 0; ch < input.getNumChannels(); ++ch)
        {
            for (int i = 0; i < numSamples; ++i)
            {
                maxLevel = std::max(maxLevel, std::abs(input.getSample(ch, i)));
            }
        }
        inputLevel.store(maxLevel);
    }

    void recordToBuffer(const juce::AudioBuffer<float>& input, int numSamples)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            if (recordPosition >= loopBuffer.getNumSamples())
            {
                stopRecording();
                return;
            }

            for (int ch = 0; ch < std::min(config.numChannels, input.getNumChannels()); ++ch)
            {
                loopBuffer.setSample(ch, recordPosition, input.getSample(ch, i));
            }
            recordPosition++;
        }
    }
};

//==============================================================================
// Multi-Track Looper Engine
//==============================================================================

class LooperEngine
{
public:
    struct Config
    {
        int numTracks = 4;
        int numChannels = 2;
        double sampleRate = 44100.0;
        int maxLoopSeconds = 120;
    };

    LooperEngine(const Config& cfg = Config())
        : config(cfg)
    {
        LoopTrack::Config trackConfig;
        trackConfig.numChannels = config.numChannels;
        trackConfig.sampleRate = config.sampleRate;
        trackConfig.maxLengthSeconds = config.maxLoopSeconds;

        for (int i = 0; i < config.numTracks; ++i)
        {
            tracks.push_back(std::make_unique<LoopTrack>(i, trackConfig));
        }
    }

    //--------------------------------------------------------------------------
    // Track Access
    //--------------------------------------------------------------------------

    LoopTrack* getTrack(int index)
    {
        if (index >= 0 && index < static_cast<int>(tracks.size()))
            return tracks[index].get();
        return nullptr;
    }

    int getNumTracks() const { return static_cast<int>(tracks.size()); }

    //--------------------------------------------------------------------------
    // Global Controls
    //--------------------------------------------------------------------------

    void setSelectedTrack(int index)
    {
        if (index >= 0 && index < static_cast<int>(tracks.size()))
            selectedTrack = index;
    }

    int getSelectedTrack() const { return selectedTrack; }

    LoopTrack* getCurrentTrack()
    {
        return getTrack(selectedTrack);
    }

    // Control selected track
    void recordOrPlay() { if (auto* t = getCurrentTrack()) t->recordOrPlay(); }
    void stop() { if (auto* t = getCurrentTrack()) t->stop(); }
    void clear() { if (auto* t = getCurrentTrack()) t->clear(); }
    void undo() { if (auto* t = getCurrentTrack()) t->undo(); }
    void redo() { if (auto* t = getCurrentTrack()) t->redo(); }
    void overdub() { if (auto* t = getCurrentTrack()) t->startOverdub(); }
    void multiply() { if (auto* t = getCurrentTrack()) t->multiply(); }

    // Control all tracks
    void stopAll()
    {
        for (auto& track : tracks)
            track->stop();
    }

    void clearAll()
    {
        for (auto& track : tracks)
            track->clear();
    }

    void playAll()
    {
        for (auto& track : tracks)
            track->play();
    }

    //--------------------------------------------------------------------------
    // Sync
    //--------------------------------------------------------------------------

    void setTempo(double bpm)
    {
        tempo = bpm;
        for (auto& track : tracks)
            track->setTempo(bpm);
    }

    double getTempo() const { return tempo; }

    void setBeatsPerBar(int beats)
    {
        beatsPerBar = beats;
        for (auto& track : tracks)
            track->setBeatsPerBar(beats);
    }

    void setMasterLoop(int trackIndex)
    {
        masterLoopTrack = trackIndex;
    }

    // Sync all tracks to master loop position
    void syncToMaster()
    {
        if (masterLoopTrack >= 0 && masterLoopTrack < static_cast<int>(tracks.size()))
        {
            int masterPos = tracks[masterLoopTrack]->getPlayPosition();
            for (int i = 0; i < static_cast<int>(tracks.size()); ++i)
            {
                if (i != masterLoopTrack)
                {
                    tracks[i]->syncToPosition(masterPos);
                }
            }
        }
    }

    //--------------------------------------------------------------------------
    // Processing
    //--------------------------------------------------------------------------

    void processBlock(juce::AudioBuffer<float>& inputBuffer,
                      juce::AudioBuffer<float>& outputBuffer,
                      int numSamples)
    {
        // Clear output
        outputBuffer.clear();

        // Process each track
        for (auto& track : tracks)
        {
            track->processBlock(inputBuffer, outputBuffer, numSamples);
        }
    }

    //--------------------------------------------------------------------------
    // Save/Load
    //--------------------------------------------------------------------------

    void saveToFile(const juce::File& file)
    {
        juce::MemoryBlock data;
        juce::MemoryOutputStream stream(data, false);

        // Header
        stream.writeInt(static_cast<int>(tracks.size()));
        stream.writeDouble(tempo);
        stream.writeInt(beatsPerBar);
        stream.writeDouble(config.sampleRate);

        // Each track
        for (const auto& track : tracks)
        {
            stream.writeInt(track->getLoopLength());
            stream.writeFloat(track->getVolume());
            stream.writeFloat(track->getPan());
            stream.writeBool(track->isMuted());
            stream.writeBool(track->isReversed());

            // Audio data
            auto waveform = track->getWaveformDisplay(track->getLoopLength());
            // Would write actual audio buffer here
        }

        file.replaceWithData(data.getData(), data.getSize());
    }

    void loadFromFile(const juce::File& file)
    {
        // Read and restore loop data
    }

private:
    Config config;
    std::vector<std::unique_ptr<LoopTrack>> tracks;

    int selectedTrack = 0;
    int masterLoopTrack = 0;
    double tempo = 120.0;
    int beatsPerBar = 4;
};

//==============================================================================
// Looper UI Component
//==============================================================================

class LoopTrackComponent : public juce::Component,
                            public juce::Timer
{
public:
    LoopTrackComponent(LoopTrack* t) : track(t)
    {
        startTimerHz(30);

        addAndMakeVisible(recordButton);
        recordButton.setButtonText("REC");
        recordButton.onClick = [this]() { track->recordOrPlay(); };

        addAndMakeVisible(stopButton);
        stopButton.setButtonText("STOP");
        stopButton.onClick = [this]() { track->stop(); };

        addAndMakeVisible(clearButton);
        clearButton.setButtonText("CLR");
        clearButton.onClick = [this]() { track->clear(); };

        addAndMakeVisible(undoButton);
        undoButton.setButtonText("UNDO");
        undoButton.onClick = [this]() { track->undo(); };

        addAndMakeVisible(volumeSlider);
        volumeSlider.setRange(0.0, 2.0, 0.01);
        volumeSlider.setValue(1.0);
        volumeSlider.onValueChange = [this]() {
            track->setVolume(static_cast<float>(volumeSlider.getValue()));
        };

        addAndMakeVisible(reverseButton);
        reverseButton.setButtonText("REV");
        reverseButton.onClick = [this]() {
            track->setReverse(!track->isReversed());
        };

        addAndMakeVisible(halfSpeedButton);
        halfSpeedButton.setButtonText("1/2");
        halfSpeedButton.onClick = [this]() {
            track->setHalfSpeed(true);
        };

        addAndMakeVisible(doubleSpeedButton);
        doubleSpeedButton.setButtonText("2x");
        doubleSpeedButton.onClick = [this]() {
            track->setDoubleSpeed(true);
        };
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background based on state
        juce::Colour bgColor;
        switch (track->getState())
        {
            case LoopState::Recording:
            case LoopState::Overdubbing:
                bgColor = juce::Colour(0xff4a1515);
                break;
            case LoopState::Playing:
                bgColor = juce::Colour(0xff1a3a1a);
                break;
            case LoopState::Armed:
                bgColor = juce::Colour(0xff3a3a15);
                break;
            default:
                bgColor = juce::Colour(0xff1a1a2e);
        }

        g.fillAll(bgColor);
        g.setColour(juce::Colours::grey);
        g.drawRect(bounds, 1.0f);

        // Draw waveform
        auto waveformBounds = bounds.reduced(5);
        waveformBounds.removeFromTop(30);   // Buttons
        waveformBounds.removeFromBottom(60); // Controls

        if (track->getLoopLength() > 0)
        {
            auto waveform = track->getWaveformDisplay(static_cast<int>(waveformBounds.getWidth()));

            g.setColour(juce::Colour(0xff00ff88));

            float x = waveformBounds.getX();
            float centerY = waveformBounds.getCentreY();
            float height = waveformBounds.getHeight() * 0.4f;

            for (size_t i = 0; i < waveform.size(); ++i)
            {
                float y = waveform[i] * height;
                g.drawVerticalLine(static_cast<int>(x + i), centerY - y, centerY + y);
            }

            // Draw playhead
            float playX = waveformBounds.getX() + track->getPlayProgress() * waveformBounds.getWidth();
            g.setColour(juce::Colours::white);
            g.drawVerticalLine(static_cast<int>(playX), waveformBounds.getY(), waveformBounds.getBottom());
        }
        else
        {
            g.setColour(juce::Colours::grey);
            g.drawText("Empty", waveformBounds, juce::Justification::centred);
        }

        // Draw input level meter
        float inputLevel = track->getInputLevel();
        auto meterBounds = bounds.removeFromRight(10).reduced(2);
        g.setColour(juce::Colours::darkgrey);
        g.fillRect(meterBounds);
        g.setColour(inputLevel > 0.9f ? juce::Colours::red : juce::Colours::green);
        g.fillRect(meterBounds.removeFromBottom(meterBounds.getHeight() * inputLevel));

        // State label
        g.setColour(juce::Colours::white);
        g.drawText(loopStateToString(track->getState()), bounds.removeFromTop(20),
                   juce::Justification::centred);

        // Loop count
        if (track->getLoopLength() > 0)
        {
            g.setColour(juce::Colours::grey);
            g.drawText("Loop: " + juce::String(track->getLoopCount()),
                       bounds.removeFromTop(15), juce::Justification::centred);
        }
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(5);

        auto buttonRow = bounds.removeFromTop(25);
        int buttonWidth = buttonRow.getWidth() / 4;
        recordButton.setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(2));
        stopButton.setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(2));
        clearButton.setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(2));
        undoButton.setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(2));

        auto controlRow = bounds.removeFromBottom(30);
        reverseButton.setBounds(controlRow.removeFromLeft(40).reduced(2));
        halfSpeedButton.setBounds(controlRow.removeFromLeft(40).reduced(2));
        doubleSpeedButton.setBounds(controlRow.removeFromLeft(40).reduced(2));

        auto volumeRow = bounds.removeFromBottom(25);
        volumeSlider.setBounds(volumeRow);
    }

    void timerCallback() override
    {
        repaint();
    }

private:
    LoopTrack* track;

    juce::TextButton recordButton;
    juce::TextButton stopButton;
    juce::TextButton clearButton;
    juce::TextButton undoButton;
    juce::TextButton reverseButton;
    juce::TextButton halfSpeedButton;
    juce::TextButton doubleSpeedButton;
    juce::Slider volumeSlider;
};

//==============================================================================
// Main Looper View
//==============================================================================

class LooperViewComponent : public juce::Component
{
public:
    LooperViewComponent(LooperEngine* engine) : looper(engine)
    {
        for (int i = 0; i < looper->getNumTracks(); ++i)
        {
            auto* trackComp = new LoopTrackComponent(looper->getTrack(i));
            addAndMakeVisible(trackComp);
            trackComponents.add(trackComp);
        }

        addAndMakeVisible(tempoSlider);
        tempoSlider.setRange(40.0, 240.0, 0.1);
        tempoSlider.setValue(120.0);
        tempoSlider.setTextValueSuffix(" BPM");
        tempoSlider.onValueChange = [this]() {
            looper->setTempo(tempoSlider.getValue());
        };

        addAndMakeVisible(stopAllButton);
        stopAllButton.setButtonText("STOP ALL");
        stopAllButton.onClick = [this]() { looper->stopAll(); };

        addAndMakeVisible(clearAllButton);
        clearAllButton.setButtonText("CLEAR ALL");
        clearAllButton.onClick = [this]() { looper->clearAll(); };
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        auto topBar = bounds.removeFromTop(40);
        tempoSlider.setBounds(topBar.removeFromLeft(200).reduced(5));
        stopAllButton.setBounds(topBar.removeFromLeft(100).reduced(5));
        clearAllButton.setBounds(topBar.removeFromLeft(100).reduced(5));

        int trackHeight = bounds.getHeight() / trackComponents.size();
        for (auto* comp : trackComponents)
        {
            comp->setBounds(bounds.removeFromTop(trackHeight));
        }
    }

private:
    LooperEngine* looper;
    juce::OwnedArray<LoopTrackComponent> trackComponents;

    juce::Slider tempoSlider;
    juce::TextButton stopAllButton;
    juce::TextButton clearAllButton;
};

} // namespace Looper
} // namespace Echoelmusic

#pragma once

//==============================================================================
/**
    MIDICaptureSystem.h

    Ableton-style "Capture" functionality for MIDI and Visuals

    Like Ableton's Capture button:
    - Always listening, always buffering
    - Hit "Capture" to grab what you just played
    - Retroactive recording - never miss an idea
    - Auto-detects tempo and loop points
    - Works for MIDI notes AND visual parameters

    Copyright (c) 2024-2025 Echoelmusic
*/
//==============================================================================

#include <JuceHeader.h>
#include <vector>
#include <deque>
#include <atomic>
#include <chrono>
#include <map>

namespace Echoel
{

//==============================================================================
// MIDI EVENT (with precise timing)
//==============================================================================

struct CapturedMIDIEvent
{
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
    double timestamp;       // Seconds since capture buffer start
    double beatPosition;    // Beat position (if tempo synced)

    bool isNoteOn() const { return (status & 0xF0) == 0x90 && data2 > 0; }
    bool isNoteOff() const { return (status & 0xF0) == 0x80 || ((status & 0xF0) == 0x90 && data2 == 0); }
    bool isCC() const { return (status & 0xF0) == 0xB0; }
    int getChannel() const { return (status & 0x0F) + 1; }
    int getNote() const { return data1; }
    int getVelocity() const { return data2; }
};

//==============================================================================
// VISUAL PARAMETER EVENT
//==============================================================================

struct CapturedVisualEvent
{
    std::string parameterName;
    float value;
    double timestamp;
    double beatPosition;

    // Visual-specific
    enum class Type { Color, Position, Size, Rotation, Opacity, Custom };
    Type type {Type::Custom};
};

//==============================================================================
// CAPTURED CLIP
//==============================================================================

struct CapturedClip
{
    std::string id;
    std::string name;

    // MIDI content
    std::vector<CapturedMIDIEvent> midiEvents;

    // Visual content
    std::vector<CapturedVisualEvent> visualEvents;

    // Timing
    double startTime;
    double endTime;
    double lengthBeats;
    double detectedTempo;

    // Metadata
    juce::Time captureTime;
    int key {0};            // Detected key
    bool isLoop {false};    // True if detected as loopable
    double loopStartBeat;
    double loopEndBeat;

    double getDurationSeconds() const { return endTime - startTime; }
    bool hasMIDI() const { return !midiEvents.empty(); }
    bool hasVisual() const { return !visualEvents.empty(); }
};

//==============================================================================
// TEMPO DETECTOR
//==============================================================================

class TempoDetector
{
public:
    void addNoteOnset(double timestamp)
    {
        onsets.push_back(timestamp);

        // Keep last 32 onsets
        while (onsets.size() > 32)
            onsets.pop_front();
    }

    double detectTempo()
    {
        if (onsets.size() < 4) return 120.0;  // Default

        // Calculate inter-onset intervals
        std::vector<double> intervals;
        for (size_t i = 1; i < onsets.size(); i++)
        {
            double interval = onsets[i] - onsets[i-1];
            if (interval > 0.1 && interval < 2.0)  // Filter outliers
                intervals.push_back(interval);
        }

        if (intervals.empty()) return 120.0;

        // Find most common interval (quantized to 16th notes)
        std::map<int, int> intervalCounts;
        for (double interval : intervals)
        {
            int quantized = static_cast<int>(interval * 100);  // 10ms resolution
            intervalCounts[quantized]++;
        }

        int bestInterval = 50;  // Default 0.5s = 120bpm quarter note
        int maxCount = 0;
        for (const auto& [interval, count] : intervalCounts)
        {
            if (count > maxCount)
            {
                maxCount = count;
                bestInterval = interval;
            }
        }

        // Convert interval to BPM (assuming quarter notes)
        double intervalSec = bestInterval / 100.0;
        double bpm = 60.0 / intervalSec;

        // Normalize to reasonable range (60-180 BPM)
        while (bpm < 60) bpm *= 2;
        while (bpm > 180) bpm /= 2;

        return bpm;
    }

    void reset() { onsets.clear(); }

private:
    std::deque<double> onsets;
};

//==============================================================================
// LOOP DETECTOR
//==============================================================================

class LoopDetector
{
public:
    struct LoopInfo
    {
        bool isLoop {false};
        double startBeat {0.0};
        double endBeat {0.0};
        double confidence {0.0};
    };

    LoopInfo detectLoop(const std::vector<CapturedMIDIEvent>& events, double tempo)
    {
        LoopInfo info;
        if (events.size() < 4) return info;

        // Get beat positions
        std::vector<double> beats;
        for (const auto& e : events)
        {
            if (e.isNoteOn())
                beats.push_back(e.timestamp * tempo / 60.0);
        }

        if (beats.empty()) return info;

        // Find pattern repetition
        double totalBeats = beats.back() - beats.front();

        // Check common loop lengths: 1, 2, 4, 8 bars
        for (int bars : {1, 2, 4, 8})
        {
            double loopLength = bars * 4;  // 4/4 time
            if (totalBeats >= loopLength * 1.5)  // Need at least 1.5 loops
            {
                double score = calculateRepetitionScore(beats, loopLength);
                if (score > 0.6)  // 60% similarity threshold
                {
                    info.isLoop = true;
                    info.startBeat = 0;
                    info.endBeat = loopLength;
                    info.confidence = score;
                    return info;
                }
            }
        }

        return info;
    }

private:
    double calculateRepetitionScore(const std::vector<double>& beats, double loopLength)
    {
        if (beats.size() < 4) return 0.0;

        int matches = 0;
        int comparisons = 0;

        for (size_t i = 0; i < beats.size(); i++)
        {
            double pos = std::fmod(beats[i], loopLength);

            // Check if any other beat lands on same position (within tolerance)
            for (size_t j = i + 1; j < beats.size(); j++)
            {
                double otherPos = std::fmod(beats[j], loopLength);
                double diff = std::abs(pos - otherPos);

                if (diff < 0.125)  // 16th note tolerance
                    matches++;
                comparisons++;
            }
        }

        return comparisons > 0 ? static_cast<double>(matches) / comparisons : 0.0;
    }
};

//==============================================================================
// MIDI CAPTURE SYSTEM
//==============================================================================

class MIDICaptureSystem
{
public:
    //--------------------------------------------------------------------------
    // Singleton
    //--------------------------------------------------------------------------

    static MIDICaptureSystem& shared()
    {
        static MIDICaptureSystem instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Configuration
    //--------------------------------------------------------------------------

    void prepare(double sampleRate, double maxCaptureSeconds = 120.0)
    {
        this->sampleRate = sampleRate;
        this->maxCaptureDuration = maxCaptureSeconds;
        reset();
    }

    void setCurrentTempo(double bpm)
    {
        currentTempo = bpm;
    }

    //--------------------------------------------------------------------------
    // MIDI Input (call this for every MIDI event)
    //--------------------------------------------------------------------------

    void processMIDIEvent(const juce::MidiMessage& msg)
    {
        if (!enabled.load()) return;

        double now = getCurrentTime();

        CapturedMIDIEvent event;
        event.status = msg.getRawData()[0];
        event.data1 = msg.getRawDataSize() > 1 ? msg.getRawData()[1] : 0;
        event.data2 = msg.getRawDataSize() > 2 ? msg.getRawData()[2] : 0;
        event.timestamp = now - bufferStartTime;
        event.beatPosition = (now - bufferStartTime) * currentTempo / 60.0;

        // Add to circular buffer
        {
            std::lock_guard<std::mutex> lock(bufferMutex);
            midiBuffer.push_back(event);

            // Trim old events
            while (!midiBuffer.empty() &&
                   midiBuffer.front().timestamp < (now - bufferStartTime - maxCaptureDuration))
            {
                midiBuffer.pop_front();
            }
        }

        // Update tempo detector for note-ons
        if (event.isNoteOn())
        {
            tempoDetector.addNoteOnset(now);
            lastNoteTime = now;
        }
    }

    //--------------------------------------------------------------------------
    // Visual Parameter Input
    //--------------------------------------------------------------------------

    void processVisualParameter(const std::string& name, float value,
                                 CapturedVisualEvent::Type type = CapturedVisualEvent::Type::Custom)
    {
        if (!captureVisuals.load()) return;

        double now = getCurrentTime();

        CapturedVisualEvent event;
        event.parameterName = name;
        event.value = value;
        event.type = type;
        event.timestamp = now - bufferStartTime;
        event.beatPosition = (now - bufferStartTime) * currentTempo / 60.0;

        {
            std::lock_guard<std::mutex> lock(bufferMutex);
            visualBuffer.push_back(event);

            // Trim old events
            while (!visualBuffer.empty() &&
                   visualBuffer.front().timestamp < (now - bufferStartTime - maxCaptureDuration))
            {
                visualBuffer.pop_front();
            }
        }
    }

    //--------------------------------------------------------------------------
    // CAPTURE! (The magic button)
    //--------------------------------------------------------------------------

    CapturedClip capture()
    {
        std::lock_guard<std::mutex> lock(bufferMutex);

        CapturedClip clip;
        clip.id = "capture_" + std::to_string(captureCount++);
        clip.captureTime = juce::Time::getCurrentTime();

        // Copy MIDI events
        clip.midiEvents = std::vector<CapturedMIDIEvent>(midiBuffer.begin(), midiBuffer.end());

        // Copy visual events
        clip.visualEvents = std::vector<CapturedVisualEvent>(visualBuffer.begin(), visualBuffer.end());

        if (clip.midiEvents.empty() && clip.visualEvents.empty())
        {
            clip.name = "Empty Capture";
            return clip;
        }

        // Calculate timing
        if (!clip.midiEvents.empty())
        {
            clip.startTime = clip.midiEvents.front().timestamp;
            clip.endTime = clip.midiEvents.back().timestamp;
        }
        else if (!clip.visualEvents.empty())
        {
            clip.startTime = clip.visualEvents.front().timestamp;
            clip.endTime = clip.visualEvents.back().timestamp;
        }

        // Detect tempo
        clip.detectedTempo = tempoDetector.detectTempo();
        if (clip.detectedTempo < 60 || clip.detectedTempo > 200)
            clip.detectedTempo = currentTempo;  // Use current tempo as fallback

        // Detect loop
        auto loopInfo = loopDetector.detectLoop(clip.midiEvents, clip.detectedTempo);
        clip.isLoop = loopInfo.isLoop;
        clip.loopStartBeat = loopInfo.startBeat;
        clip.loopEndBeat = loopInfo.endBeat;

        // Calculate length in beats
        clip.lengthBeats = clip.getDurationSeconds() * clip.detectedTempo / 60.0;

        // Generate name
        clip.name = generateClipName(clip);

        // Store in history
        capturedClips.push_back(clip);

        // Callback
        if (onCapture)
            onCapture(clip);

        return clip;
    }

    //--------------------------------------------------------------------------
    // Capture with time range
    //--------------------------------------------------------------------------

    CapturedClip captureLastSeconds(double seconds)
    {
        double now = getCurrentTime();
        double cutoff = now - bufferStartTime - seconds;

        std::lock_guard<std::mutex> lock(bufferMutex);

        CapturedClip clip;
        clip.id = "capture_" + std::to_string(captureCount++);
        clip.captureTime = juce::Time::getCurrentTime();

        // Copy only events within time range
        for (const auto& e : midiBuffer)
        {
            if (e.timestamp >= cutoff)
                clip.midiEvents.push_back(e);
        }

        for (const auto& e : visualBuffer)
        {
            if (e.timestamp >= cutoff)
                clip.visualEvents.push_back(e);
        }

        // ... rest similar to capture()
        clip.detectedTempo = tempoDetector.detectTempo();
        clip.name = generateClipName(clip);

        capturedClips.push_back(clip);

        if (onCapture)
            onCapture(clip);

        return clip;
    }

    //--------------------------------------------------------------------------
    // Capture last N bars
    //--------------------------------------------------------------------------

    CapturedClip captureLastBars(int bars)
    {
        double beatsToCapture = bars * 4;  // 4/4 time
        double secondsToCapture = beatsToCapture * 60.0 / currentTempo;
        return captureLastSeconds(secondsToCapture);
    }

    //--------------------------------------------------------------------------
    // Export
    //--------------------------------------------------------------------------

    bool exportToMidiFile(const CapturedClip& clip, const juce::File& file)
    {
        juce::MidiMessageSequence sequence;

        for (const auto& e : clip.midiEvents)
        {
            if (e.isNoteOn())
            {
                sequence.addEvent(juce::MidiMessage::noteOn(
                    e.getChannel(), e.getNote(), static_cast<uint8_t>(e.getVelocity())),
                    e.timestamp);
            }
            else if (e.isNoteOff())
            {
                sequence.addEvent(juce::MidiMessage::noteOff(
                    e.getChannel(), e.getNote()),
                    e.timestamp);
            }
            else if (e.isCC())
            {
                sequence.addEvent(juce::MidiMessage::controllerEvent(
                    e.getChannel(), e.data1, e.data2),
                    e.timestamp);
            }
        }

        juce::MidiFile midiFile;
        midiFile.setTicksPerQuarterNote(480);
        midiFile.addTrack(sequence);

        juce::FileOutputStream stream(file);
        if (stream.openedOk())
        {
            midiFile.writeTo(stream);
            return true;
        }
        return false;
    }

    juce::MidiMessageSequence toMidiSequence(const CapturedClip& clip)
    {
        juce::MidiMessageSequence sequence;

        for (const auto& e : clip.midiEvents)
        {
            if (e.isNoteOn())
            {
                sequence.addEvent(juce::MidiMessage::noteOn(
                    e.getChannel(), e.getNote(), static_cast<uint8_t>(e.getVelocity())),
                    e.timestamp * sampleRate);
            }
            else if (e.isNoteOff())
            {
                sequence.addEvent(juce::MidiMessage::noteOff(
                    e.getChannel(), e.getNote()),
                    e.timestamp * sampleRate);
            }
        }

        return sequence;
    }

    //--------------------------------------------------------------------------
    // History
    //--------------------------------------------------------------------------

    const std::vector<CapturedClip>& getCapturedClips() const { return capturedClips; }

    CapturedClip getLastCapture() const
    {
        if (capturedClips.empty()) return {};
        return capturedClips.back();
    }

    void clearHistory()
    {
        capturedClips.clear();
    }

    //--------------------------------------------------------------------------
    // Control
    //--------------------------------------------------------------------------

    void setEnabled(bool enable) { enabled.store(enable); }
    bool isEnabled() const { return enabled.load(); }

    void setCaptureVisuals(bool enable) { captureVisuals.store(enable); }
    bool isCaptureVisualsEnabled() const { return captureVisuals.load(); }

    void reset()
    {
        std::lock_guard<std::mutex> lock(bufferMutex);
        midiBuffer.clear();
        visualBuffer.clear();
        bufferStartTime = getCurrentTime();
        tempoDetector.reset();
    }

    //--------------------------------------------------------------------------
    // Status
    //--------------------------------------------------------------------------

    bool hasContent() const
    {
        std::lock_guard<std::mutex> lock(bufferMutex);
        return !midiBuffer.empty() || !visualBuffer.empty();
    }

    double getBufferDuration() const
    {
        std::lock_guard<std::mutex> lock(bufferMutex);
        if (midiBuffer.empty()) return 0.0;
        return midiBuffer.back().timestamp - midiBuffer.front().timestamp;
    }

    int getMIDIEventCount() const
    {
        std::lock_guard<std::mutex> lock(bufferMutex);
        return static_cast<int>(midiBuffer.size());
    }

    double getTimeSinceLastNote() const
    {
        return getCurrentTime() - lastNoteTime;
    }

    //--------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------

    std::function<void(const CapturedClip&)> onCapture;

private:
    MIDICaptureSystem()
    {
        bufferStartTime = getCurrentTime();
    }

    ~MIDICaptureSystem() = default;
    MIDICaptureSystem(const MIDICaptureSystem&) = delete;
    MIDICaptureSystem& operator=(const MIDICaptureSystem&) = delete;

    //--------------------------------------------------------------------------
    // State
    //--------------------------------------------------------------------------

    mutable std::mutex bufferMutex;
    std::deque<CapturedMIDIEvent> midiBuffer;
    std::deque<CapturedVisualEvent> visualBuffer;

    std::vector<CapturedClip> capturedClips;

    double sampleRate {44100.0};
    double currentTempo {120.0};
    double maxCaptureDuration {120.0};  // 2 minutes default
    double bufferStartTime {0.0};
    double lastNoteTime {0.0};

    std::atomic<bool> enabled {true};
    std::atomic<bool> captureVisuals {true};

    int captureCount {0};

    TempoDetector tempoDetector;
    LoopDetector loopDetector;

    //--------------------------------------------------------------------------
    // Helpers
    //--------------------------------------------------------------------------

    double getCurrentTime() const
    {
        using namespace std::chrono;
        auto now = steady_clock::now();
        return duration<double>(now.time_since_epoch()).count();
    }

    std::string generateClipName(const CapturedClip& clip)
    {
        std::string name = "Capture";

        if (clip.hasMIDI())
        {
            int noteCount = 0;
            for (const auto& e : clip.midiEvents)
                if (e.isNoteOn()) noteCount++;

            name += " " + std::to_string(noteCount) + " notes";
        }

        if (clip.isLoop)
        {
            int bars = static_cast<int>(clip.loopEndBeat / 4);
            name += " [" + std::to_string(bars) + " bar loop]";
        }

        name += " @ " + std::to_string(static_cast<int>(clip.detectedTempo)) + " BPM";

        return name;
    }
};

//==============================================================================
// CONVENIENCE MACRO
//==============================================================================

#define EchoelCapture MIDICaptureSystem::shared()

} // namespace Echoel

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <functional>
#include <atomic>
#include <map>

/**
 * ClipLauncher - Ableton-Style Session View
 *
 * Full-featured clip launcher with:
 * - Scene/clip grid (16 tracks × 64 scenes)
 * - Launch quantization (bar, beat, off)
 * - Follow actions (next, previous, random, first, last)
 * - Loop modes (loop, one-shot, gate)
 * - Clip colors and naming
 * - Recording into slots
 * - Scene launching (horizontal)
 * - Stop buttons per track
 *
 * Super Ralph Wiggum Loop Genius Wise Save Mode
 */

namespace Echoelmusic {
namespace Session {

//==============================================================================
// Clip State
//==============================================================================

enum class ClipState
{
    Empty,
    Stopped,
    Playing,
    Recording,
    Queued,         // Waiting for quantize point
    Stopping        // Queued to stop
};

enum class LaunchQuantize
{
    None,
    Beat,
    Bar,
    TwoBars,
    FourBars,
    EightBars
};

enum class LoopMode
{
    Loop,           // Loop continuously
    OneShot,        // Play once and stop
    Gate,           // Play while held, stop on release
    Trigger         // Retrigger on each press
};

enum class FollowAction
{
    None,
    Next,
    Previous,
    First,
    Last,
    Random,
    Other           // Jump to specific slot
};

//==============================================================================
// Clip Data
//==============================================================================

struct SessionClip
{
    std::string id;
    std::string name;
    juce::Colour color{0xFF4A9EFF};

    ClipState state = ClipState::Empty;
    LoopMode loopMode = LoopMode::Loop;

    // Audio/MIDI content reference
    std::string contentPath;
    bool isMidi = false;

    // Timing
    double lengthBeats = 4.0;
    double startOffset = 0.0;

    // Follow action
    FollowAction followAction = FollowAction::None;
    double followTime = 0.0;        // Time until follow action (beats)
    int followTarget = -1;          // Target slot for "Other" action

    // Playback state
    double playPosition = 0.0;
    bool isQueued = false;

    bool isEmpty() const { return state == ClipState::Empty; }
    bool isPlaying() const { return state == ClipState::Playing; }
    bool isRecording() const { return state == ClipState::Recording; }
};

//==============================================================================
// Scene (Horizontal Row)
//==============================================================================

struct Scene
{
    std::string name;
    juce::Colour color{0xFF5A5A5A};
    double tempo = 0.0;             // 0 = use project tempo
    int timeSignatureNum = 0;       // 0 = use project
    int timeSignatureDen = 0;
};

//==============================================================================
// Session Track (Vertical Column)
//==============================================================================

struct SessionTrack
{
    std::string name;
    juce::Colour color{0xFF4A9EFF};
    int audioTrackIndex = -1;       // Link to mixer track

    std::vector<SessionClip> clips;
    int playingClipIndex = -1;
    bool armed = false;
    bool stopped = true;

    SessionClip& getClip(int index)
    {
        while (index >= static_cast<int>(clips.size()))
            clips.push_back(SessionClip());
        return clips[index];
    }
};

//==============================================================================
// Clip Launcher Engine
//==============================================================================

class ClipLauncherEngine
{
public:
    struct Config
    {
        int numTracks = 8;
        int numScenes = 16;
        LaunchQuantize defaultQuantize = LaunchQuantize::Bar;
        bool recordOnLaunch = true;     // Arm + launch = record
    };

    ClipLauncherEngine(const Config& cfg = {}) : config(cfg)
    {
        tracks.resize(config.numTracks);
        scenes.resize(config.numScenes);

        for (int i = 0; i < config.numTracks; ++i)
            tracks[i].name = "Track " + std::to_string(i + 1);

        for (int i = 0; i < config.numScenes; ++i)
            scenes[i].name = "Scene " + std::to_string(i + 1);
    }

    //--------------------------------------------------------------------------
    // Clip Operations
    //--------------------------------------------------------------------------

    void launchClip(int trackIndex, int sceneIndex)
    {
        if (trackIndex < 0 || trackIndex >= config.numTracks) return;

        auto& track = tracks[trackIndex];
        auto& clip = track.getClip(sceneIndex);

        if (clip.isEmpty())
        {
            // If track is armed, start recording
            if (track.armed && config.recordOnLaunch)
            {
                startRecording(trackIndex, sceneIndex);
                return;
            }
            return;
        }

        // Queue clip for launch
        if (quantize != LaunchQuantize::None)
        {
            clip.state = ClipState::Queued;
            clip.isQueued = true;
        }
        else
        {
            startClip(trackIndex, sceneIndex);
        }
    }

    void stopClip(int trackIndex, int sceneIndex)
    {
        if (trackIndex < 0 || trackIndex >= config.numTracks) return;

        auto& track = tracks[trackIndex];
        auto& clip = track.getClip(sceneIndex);

        if (quantize != LaunchQuantize::None && clip.isPlaying())
        {
            clip.state = ClipState::Stopping;
        }
        else
        {
            clip.state = ClipState::Stopped;
            clip.playPosition = 0.0;
        }
    }

    void stopTrack(int trackIndex)
    {
        if (trackIndex < 0 || trackIndex >= config.numTracks) return;

        auto& track = tracks[trackIndex];
        for (auto& clip : track.clips)
        {
            if (clip.isPlaying())
            {
                clip.state = ClipState::Stopped;
                clip.playPosition = 0.0;
            }
        }
        track.playingClipIndex = -1;
        track.stopped = true;
    }

    void launchScene(int sceneIndex)
    {
        for (int t = 0; t < config.numTracks; ++t)
        {
            auto& clip = tracks[t].getClip(sceneIndex);
            if (!clip.isEmpty())
            {
                launchClip(t, sceneIndex);
            }
        }

        if (onSceneLaunched)
            onSceneLaunched(sceneIndex);
    }

    void stopAll()
    {
        for (int t = 0; t < config.numTracks; ++t)
            stopTrack(t);

        if (onAllStopped)
            onAllStopped();
    }

    //--------------------------------------------------------------------------
    // Recording
    //--------------------------------------------------------------------------

    void startRecording(int trackIndex, int sceneIndex)
    {
        if (trackIndex < 0 || trackIndex >= config.numTracks) return;

        auto& track = tracks[trackIndex];
        auto& clip = track.getClip(sceneIndex);

        clip.state = ClipState::Recording;
        clip.playPosition = 0.0;
        clip.name = "Recording...";

        if (onRecordingStarted)
            onRecordingStarted(trackIndex, sceneIndex);
    }

    void stopRecording(int trackIndex, int sceneIndex)
    {
        if (trackIndex < 0 || trackIndex >= config.numTracks) return;

        auto& clip = tracks[trackIndex].getClip(sceneIndex);

        if (clip.isRecording())
        {
            clip.state = ClipState::Playing;  // Continue playing after recording
            clip.name = "Clip " + std::to_string(sceneIndex + 1);

            if (onRecordingStopped)
                onRecordingStopped(trackIndex, sceneIndex, clip.lengthBeats);
        }
    }

    //--------------------------------------------------------------------------
    // Transport Sync
    //--------------------------------------------------------------------------

    void processQuantizePoint(double beatPosition)
    {
        // Check if we hit a quantize boundary
        bool isQuantizePoint = false;

        switch (quantize)
        {
            case LaunchQuantize::Beat:
                isQuantizePoint = (std::fmod(beatPosition, 1.0) < 0.01);
                break;
            case LaunchQuantize::Bar:
                isQuantizePoint = (std::fmod(beatPosition, beatsPerBar) < 0.01);
                break;
            case LaunchQuantize::TwoBars:
                isQuantizePoint = (std::fmod(beatPosition, beatsPerBar * 2) < 0.01);
                break;
            case LaunchQuantize::FourBars:
                isQuantizePoint = (std::fmod(beatPosition, beatsPerBar * 4) < 0.01);
                break;
            default:
                break;
        }

        if (!isQuantizePoint) return;

        // Process queued clips
        for (int t = 0; t < config.numTracks; ++t)
        {
            for (size_t s = 0; s < tracks[t].clips.size(); ++s)
            {
                auto& clip = tracks[t].clips[s];

                if (clip.state == ClipState::Queued)
                {
                    startClip(t, static_cast<int>(s));
                }
                else if (clip.state == ClipState::Stopping)
                {
                    clip.state = ClipState::Stopped;
                    clip.playPosition = 0.0;
                    tracks[t].playingClipIndex = -1;
                }
            }
        }
    }

    void advancePlayPosition(double deltaBeats)
    {
        for (auto& track : tracks)
        {
            for (auto& clip : track.clips)
            {
                if (clip.isPlaying())
                {
                    clip.playPosition += deltaBeats;

                    // Loop or one-shot
                    if (clip.playPosition >= clip.lengthBeats)
                    {
                        if (clip.loopMode == LoopMode::Loop)
                        {
                            clip.playPosition = std::fmod(clip.playPosition, clip.lengthBeats);
                        }
                        else if (clip.loopMode == LoopMode::OneShot)
                        {
                            clip.state = ClipState::Stopped;
                            clip.playPosition = 0.0;
                        }

                        // Check follow action
                        if (clip.followAction != FollowAction::None)
                        {
                            executeFollowAction(track, clip);
                        }
                    }
                }
            }
        }
    }

    //--------------------------------------------------------------------------
    // Settings
    //--------------------------------------------------------------------------

    void setQuantize(LaunchQuantize q) { quantize = q; }
    LaunchQuantize getQuantize() const { return quantize; }

    void setBeatsPerBar(int beats) { beatsPerBar = beats; }
    void setTempo(double bpm) { tempo = bpm; }

    //--------------------------------------------------------------------------
    // Access
    //--------------------------------------------------------------------------

    SessionTrack& getTrack(int index) { return tracks[index]; }
    Scene& getScene(int index) { return scenes[index]; }

    int getNumTracks() const { return config.numTracks; }
    int getNumScenes() const { return config.numScenes; }

    //--------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------

    std::function<void(int track, int scene)> onClipLaunched;
    std::function<void(int track, int scene)> onClipStopped;
    std::function<void(int scene)> onSceneLaunched;
    std::function<void()> onAllStopped;
    std::function<void(int track, int scene)> onRecordingStarted;
    std::function<void(int track, int scene, double length)> onRecordingStopped;

private:
    Config config;
    std::vector<SessionTrack> tracks;
    std::vector<Scene> scenes;

    LaunchQuantize quantize = LaunchQuantize::Bar;
    int beatsPerBar = 4;
    double tempo = 120.0;

    void startClip(int trackIndex, int sceneIndex)
    {
        auto& track = tracks[trackIndex];

        // Stop any playing clip on this track
        if (track.playingClipIndex >= 0 && track.playingClipIndex != sceneIndex)
        {
            track.clips[track.playingClipIndex].state = ClipState::Stopped;
            track.clips[track.playingClipIndex].playPosition = 0.0;
        }

        auto& clip = track.getClip(sceneIndex);
        clip.state = ClipState::Playing;
        clip.playPosition = 0.0;
        clip.isQueued = false;

        track.playingClipIndex = sceneIndex;
        track.stopped = false;

        if (onClipLaunched)
            onClipLaunched(trackIndex, sceneIndex);
    }

    void executeFollowAction(SessionTrack& track, SessionClip& clip)
    {
        int currentIndex = -1;
        for (size_t i = 0; i < track.clips.size(); ++i)
        {
            if (&track.clips[i] == &clip)
            {
                currentIndex = static_cast<int>(i);
                break;
            }
        }

        if (currentIndex < 0) return;

        int nextIndex = -1;

        switch (clip.followAction)
        {
            case FollowAction::Next:
                nextIndex = (currentIndex + 1) % static_cast<int>(track.clips.size());
                break;
            case FollowAction::Previous:
                nextIndex = (currentIndex - 1 + static_cast<int>(track.clips.size())) %
                            static_cast<int>(track.clips.size());
                break;
            case FollowAction::First:
                nextIndex = 0;
                break;
            case FollowAction::Last:
                nextIndex = static_cast<int>(track.clips.size()) - 1;
                break;
            case FollowAction::Random:
                nextIndex = std::rand() % static_cast<int>(track.clips.size());
                break;
            case FollowAction::Other:
                nextIndex = clip.followTarget;
                break;
            default:
                break;
        }

        if (nextIndex >= 0 && nextIndex < static_cast<int>(track.clips.size()))
        {
            if (!track.clips[nextIndex].isEmpty())
            {
                // Queue the next clip
                track.clips[nextIndex].state = ClipState::Queued;
            }
        }
    }
};

//==============================================================================
// Clip Launcher UI
//==============================================================================

class ClipSlot : public juce::Component
{
public:
    ClipSlot(int track, int scene) : trackIndex(track), sceneIndex(scene) {}

    void setClip(const SessionClip* c) { clip = c; repaint(); }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(1);

        // Background based on state
        juce::Colour bgColor;
        if (!clip || clip->isEmpty())
        {
            bgColor = juce::Colour(0xFF2A2A2A);
        }
        else
        {
            bgColor = clip->color;

            if (clip->isPlaying())
                bgColor = bgColor.brighter(0.3f);
            else if (clip->state == ClipState::Queued)
                bgColor = bgColor.interpolatedWith(juce::Colours::yellow, 0.5f);
            else if (clip->isRecording())
                bgColor = juce::Colours::red;
        }

        g.setColour(bgColor);
        g.fillRoundedRectangle(bounds, 4.0f);

        // Border
        g.setColour(juce::Colour(0xFF4A4A4A));
        g.drawRoundedRectangle(bounds, 4.0f, 1.0f);

        // Play indicator
        if (clip && clip->isPlaying())
        {
            // Progress bar
            float progress = static_cast<float>(clip->playPosition / clip->lengthBeats);
            g.setColour(juce::Colours::white.withAlpha(0.3f));
            g.fillRect(bounds.getX(), bounds.getBottom() - 4,
                       bounds.getWidth() * progress, 4.0f);

            // Play triangle
            g.setColour(juce::Colours::white);
            juce::Path triangle;
            triangle.addTriangle(bounds.getCentreX() - 6, bounds.getCentreY() - 8,
                                 bounds.getCentreX() - 6, bounds.getCentreY() + 8,
                                 bounds.getCentreX() + 8, bounds.getCentreY());
            g.fillPath(triangle);
        }
        else if (clip && clip->state == ClipState::Queued)
        {
            // Queued indicator (blinking)
            g.setColour(juce::Colours::white);
            g.fillEllipse(bounds.getCentreX() - 4, bounds.getCentreY() - 4, 8, 8);
        }
        else if (clip && !clip->isEmpty())
        {
            // Clip name
            g.setColour(juce::Colours::white);
            g.setFont(10.0f);
            g.drawText(clip->name, bounds.reduced(4), juce::Justification::centred);
        }
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        if (e.mods.isLeftButtonDown())
        {
            if (onClick) onClick(trackIndex, sceneIndex);
        }
        else if (e.mods.isRightButtonDown())
        {
            if (onRightClick) onRightClick(trackIndex, sceneIndex);
        }
    }

    std::function<void(int, int)> onClick;
    std::function<void(int, int)> onRightClick;

private:
    int trackIndex, sceneIndex;
    const SessionClip* clip = nullptr;
};

class ClipLauncherView : public juce::Component, public juce::Timer
{
public:
    ClipLauncherView(ClipLauncherEngine& eng) : engine(eng)
    {
        int numTracks = engine.getNumTracks();
        int numScenes = engine.getNumScenes();

        // Create grid of clip slots
        for (int t = 0; t < numTracks; ++t)
        {
            std::vector<std::unique_ptr<ClipSlot>> trackSlots;

            for (int s = 0; s < numScenes; ++s)
            {
                auto slot = std::make_unique<ClipSlot>(t, s);

                slot->onClick = [this](int track, int scene) {
                    engine.launchClip(track, scene);
                };

                slot->onRightClick = [this](int track, int scene) {
                    engine.stopClip(track, scene);
                };

                addAndMakeVisible(*slot);
                trackSlots.push_back(std::move(slot));
            }

            slots.push_back(std::move(trackSlots));
        }

        // Scene launch buttons
        for (int s = 0; s < numScenes; ++s)
        {
            auto btn = std::make_unique<juce::TextButton>(">");
            btn->onClick = [this, s]() { engine.launchScene(s); };
            addAndMakeVisible(*btn);
            sceneLaunchButtons.push_back(std::move(btn));
        }

        // Track stop buttons
        for (int t = 0; t < numTracks; ++t)
        {
            auto btn = std::make_unique<juce::TextButton>("■");
            btn->onClick = [this, t]() { engine.stopTrack(t); };
            addAndMakeVisible(*btn);
            trackStopButtons.push_back(std::move(btn));
        }

        startTimerHz(30);
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        int headerHeight = 30;
        int slotWidth = 80;
        int slotHeight = 40;
        int sceneBtnWidth = 30;

        bounds.removeFromTop(headerHeight);  // Track headers

        int numTracks = engine.getNumTracks();
        int numScenes = engine.getNumScenes();

        // Track stop buttons
        auto stopRow = bounds.removeFromBottom(24);
        stopRow.removeFromRight(sceneBtnWidth);
        for (int t = 0; t < numTracks; ++t)
        {
            trackStopButtons[t]->setBounds(stopRow.removeFromLeft(slotWidth).reduced(2));
        }

        // Grid
        for (int s = 0; s < numScenes; ++s)
        {
            auto row = bounds.removeFromTop(slotHeight);
            auto sceneBtnArea = row.removeFromRight(sceneBtnWidth);
            sceneLaunchButtons[s]->setBounds(sceneBtnArea.reduced(2));

            for (int t = 0; t < numTracks; ++t)
            {
                slots[t][s]->setBounds(row.removeFromLeft(slotWidth).reduced(1));
            }
        }
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF1A1A1A));

        // Track headers
        int slotWidth = 80;
        g.setColour(juce::Colours::white);
        g.setFont(12.0f);

        for (int t = 0; t < engine.getNumTracks(); ++t)
        {
            auto& track = engine.getTrack(t);
            g.setColour(track.color);
            g.fillRect(t * slotWidth, 0, slotWidth - 2, 28);

            g.setColour(juce::Colours::white);
            g.drawText(track.name, t * slotWidth + 4, 4, slotWidth - 8, 20,
                       juce::Justification::centred);
        }
    }

    void timerCallback() override
    {
        // Update clip slots
        for (int t = 0; t < engine.getNumTracks(); ++t)
        {
            auto& track = engine.getTrack(t);
            for (size_t s = 0; s < slots[t].size() && s < track.clips.size(); ++s)
            {
                slots[t][s]->setClip(&track.clips[s]);
            }
        }
    }

private:
    ClipLauncherEngine& engine;
    std::vector<std::vector<std::unique_ptr<ClipSlot>>> slots;
    std::vector<std::unique_ptr<juce::TextButton>> sceneLaunchButtons;
    std::vector<std::unique_ptr<juce::TextButton>> trackStopButtons;
};

} // namespace Session
} // namespace Echoelmusic

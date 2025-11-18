#pragma once

#include <JuceHeader.h>
#include "../Audio/AudioEngine.h"
#include "../Audio/Track.h"
#include <vector>

namespace echoelmusic {
namespace ui {

/**
 * @brief Main track view component showing waveforms and MIDI
 *
 * CRITICAL MVP UI COMPONENT - This is what users see when they open the DAW!
 *
 * Features:
 * - Waveform display for audio tracks
 * - Piano roll preview for MIDI tracks
 * - Zoom & scroll
 * - Selection & editing
 * - Playback cursor
 * - Time ruler
 * - Track management (add/remove/duplicate)
 * - Vaporwave aesthetic (cyan/magenta/purple)
 *
 * @author Claude Code (ULTRATHINK SUPER LASER MODE)
 * @date 2025-11-18
 */
class TrackView : public juce::Component,
                  public juce::Timer
{
public:
    /**
     * @brief Constructor
     *
     * @param audioEngine Reference to audio engine (for track management)
     */
    explicit TrackView(audio::AudioEngine& audioEngine);

    /**
     * @brief Destructor
     */
    ~TrackView() override;

    // ========================================================================
    // JUCE COMPONENT
    // ========================================================================

    void paint(juce::Graphics& g) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent& event) override;
    void mouseDrag(const juce::MouseEvent& event) override;
    void mouseUp(const juce::MouseEvent& event) override;
    void mouseWheelMove(const juce::MouseEvent& event, const juce::MouseWheelDetails& wheel) override;
    bool keyPressed(const juce::KeyPress& key) override;

    void timerCallback() override;

    // ========================================================================
    // TRACK MANAGEMENT
    // ========================================================================

    /**
     * @brief Add new track
     *
     * @param trackName Track name
     * @param isAudioTrack true = audio track, false = MIDI track
     */
    void addTrack(const juce::String& trackName, bool isAudioTrack);

    /**
     * @brief Remove track by index
     *
     * @param trackIndex Track index (0-based)
     */
    void removeTrack(int trackIndex);

    /**
     * @brief Select track
     *
     * @param trackIndex Track index to select
     */
    void selectTrack(int trackIndex);

    /**
     * @brief Duplicate track
     *
     * @param trackIndex Track to duplicate
     */
    void duplicateTrack(int trackIndex);

    // ========================================================================
    // ZOOM & SCROLL
    // ========================================================================

    /**
     * @brief Set zoom level
     *
     * @param pixelsPerSecond Pixels per second (100 = 1 second = 100 pixels)
     */
    void setZoom(double pixelsPerSecond);

    /**
     * @brief Zoom in (1.5x)
     */
    void zoomIn();

    /**
     * @brief Zoom out (1.5x)
     */
    void zoomOut();

    /**
     * @brief Zoom to fit entire project in view
     */
    void zoomToFit();

    /**
     * @brief Set horizontal scroll position
     *
     * @param pixels Scroll position in pixels
     */
    void setScrollPosition(double pixels);

    /**
     * @brief Get current zoom level
     *
     * @return Pixels per second
     */
    double getZoom() const;

    /**
     * @brief Get current scroll position
     *
     * @return Scroll position in pixels
     */
    double getScrollPosition() const;

    // ========================================================================
    // SELECTION
    // ========================================================================

    /**
     * @brief Delete selected audio/MIDI
     */
    void deleteSelection();

    /**
     * @brief Select all tracks/time
     */
    void selectAll();

    /**
     * @brief Clear selection
     */
    void clearSelection();

private:
    // ========================================================================
    // HELPERS
    // ========================================================================

    /**
     * @brief Convert time to pixel position
     */
    double timeToPixel(double timeSeconds) const;

    /**
     * @brief Convert pixel position to time
     */
    double pixelToTime(double pixel) const;

    /**
     * @brief Get track bounds rectangle
     */
    juce::Rectangle<int> getTrackBounds(int trackIndex) const;

    /**
     * @brief Get track index at Y position
     *
     * @return Track index, or -1 if not on track
     */
    int getTrackIndexAt(int y) const;

    // ========================================================================
    // PAINTING
    // ========================================================================

    void paintTimeRuler(juce::Graphics& g);
    void paintTrack(juce::Graphics& g, audio::Track* track, juce::Rectangle<int> bounds, int trackIndex);
    void paintWaveform(juce::Graphics& g, juce::Rectangle<int> bounds, const struct WaveformThumbnail& waveform);
    void paintPlaybackCursor(juce::Graphics& g);
    void paintSelection(juce::Graphics& g);

    // ========================================================================
    // WAVEFORM GENERATION
    // ========================================================================

    /**
     * @brief Waveform thumbnail for fast display
     */
    struct WaveformThumbnail
    {
        std::vector<float> samples;  // Downsampled audio for display
    };

    void regenerateWaveforms();
    void generateWaveformThumbnail(audio::Track* track, WaveformThumbnail& thumbnail);

    // ========================================================================
    // CONTEXT MENU
    // ========================================================================

    void showContextMenu(juce::Point<float> position);

private:
    // Audio engine reference
    audio::AudioEngine& m_audioEngine;

    // Zoom & scroll
    double m_pixelsPerSecond;  // Zoom level
    double m_scrollPosition;   // Horizontal scroll in pixels

    // Selection
    bool m_hasSelection = false;
    float m_selectionStart = 0.0f;
    float m_selectionEnd = 0.0f;
    bool m_isDraggingSelection = false;
    int m_draggedTrackIndex = -1;

    // Selected track
    int m_selectedTrackIndex = 0;

    // Waveform thumbnails (one per track)
    std::vector<WaveformThumbnail> m_waveformThumbnails;

    // Layout constants
    static constexpr int TIME_RULER_HEIGHT = 30;
    static constexpr int TIME_RULER_WIDTH = 150;  // Left sidebar for track names
    static constexpr int TRACK_HEIGHT = 100;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TrackView)
};

} // namespace ui
} // namespace echoelmusic

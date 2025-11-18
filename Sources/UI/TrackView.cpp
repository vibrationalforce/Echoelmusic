#include "TrackView.h"

namespace echoelmusic {
namespace ui {

// ============================================================================
// CONSTRUCTOR / DESTRUCTOR
// ============================================================================

TrackView::TrackView(audio::AudioEngine& audioEngine)
    : m_audioEngine(audioEngine)
{
    // Set up zoom/scroll
    m_pixelsPerSecond = 100.0;  // 100 pixels = 1 second (default zoom)
    m_scrollPosition = 0.0;

    // Set up viewport
    setSize(800, 600);
    setWantsKeyboardFocus(true);

    // Start timer for playback cursor animation (60 FPS)
    startTimer(1000 / 60);

    // Generate waveform thumbnails for all tracks
    regenerateWaveforms();
}

TrackView::~TrackView()
{
    stopTimer();
}

// ============================================================================
// JUCE COMPONENT
// ============================================================================

void TrackView::paint(juce::Graphics& g)
{
    // Background
    g.fillAll(juce::Colour(0xFF1A1A2E));  // Dark vaporwave background

    // Draw time ruler
    paintTimeRuler(g);

    // Draw tracks
    for (int i = 0; i < m_audioEngine.getNumTracks(); ++i)
    {
        auto track = m_audioEngine.getTrack(i);
        if (track != nullptr)
        {
            juce::Rectangle<int> trackBounds = getTrackBounds(i);
            paintTrack(g, track, trackBounds, i);
        }
    }

    // Draw playback cursor
    paintPlaybackCursor(g);

    // Draw selection
    if (m_hasSelection)
    {
        paintSelection(g);
    }
}

void TrackView::resized()
{
    // Recalculate track positions
    // (Done dynamically in getTrackBounds())
}

void TrackView::mouseDown(const juce::MouseEvent& event)
{
    if (event.mods.isLeftButtonDown())
    {
        // Start selection
        m_selectionStart = event.position.x;
        m_selectionEnd = event.position.x;
        m_hasSelection = true;
        m_isDraggingSelection = true;

        // Check if clicking on a track
        m_draggedTrackIndex = getTrackIndexAt(event.position.y);

        repaint();
    }
    else if (event.mods.isRightButtonDown())
    {
        // Context menu
        showContextMenu(event.position);
    }
}

void TrackView::mouseDrag(const juce::MouseEvent& event)
{
    if (m_isDraggingSelection)
    {
        m_selectionEnd = event.position.x;
        repaint();
    }
}

void TrackView::mouseUp(const juce::MouseEvent& event)
{
    m_isDraggingSelection = false;

    // If click (not drag), seek to position
    if (std::abs(m_selectionEnd - m_selectionStart) < 5)  // 5 pixel threshold
    {
        double clickTime = pixelToTime(event.position.x);
        m_audioEngine.setPosition(clickTime);
        m_hasSelection = false;
    }

    repaint();
}

void TrackView::mouseWheelMove(const juce::MouseEvent& event, const juce::MouseWheelDetails& wheel)
{
    if (event.mods.isCommandDown())
    {
        // Zoom with Cmd/Ctrl + Scroll
        double zoomFactor = 1.0 + wheel.deltaY * 0.5;
        setZoom(m_pixelsPerSecond * zoomFactor);
    }
    else
    {
        // Horizontal scroll
        double scrollDelta = wheel.deltaY * 100.0;  // pixels
        setScrollPosition(m_scrollPosition - scrollDelta);
    }

    repaint();
}

bool TrackView::keyPressed(const juce::KeyPress& key)
{
    // Spacebar = play/pause
    if (key == juce::KeyPress::spaceKey)
    {
        if (m_audioEngine.isPlaying())
            m_audioEngine.stop();
        else
            m_audioEngine.play();
        return true;
    }

    // Delete = delete selection
    if (key == juce::KeyPress::deleteKey || key == juce::KeyPress::backspaceKey)
    {
        deleteSelection();
        return true;
    }

    // Cmd+Z = Undo (TODO)
    if (key.isKeyCode(juce::KeyPress::returnKey) && key.getModifiers().isCommandDown())
    {
        // undo();
        return true;
    }

    return false;
}

void TrackView::timerCallback()
{
    // Update playback cursor position
    repaint();  // Redraw for cursor animation
}

// ============================================================================
// TRACK MANAGEMENT
// ============================================================================

void TrackView::addTrack(const juce::String& trackName, bool isAudioTrack)
{
    // Add track to audio engine
    auto track = std::make_unique<audio::Track>(trackName, isAudioTrack);
    m_audioEngine.addTrack(std::move(track));

    // Regenerate waveforms
    regenerateWaveforms();

    resized();
    repaint();
}

void TrackView::removeTrack(int trackIndex)
{
    if (trackIndex >= 0 && trackIndex < m_audioEngine.getNumTracks())
    {
        m_audioEngine.removeTrack(trackIndex);

        // Remove waveform thumbnail
        if (trackIndex < m_waveformThumbnails.size())
        {
            m_waveformThumbnails.erase(m_waveformThumbnails.begin() + trackIndex);
        }

        resized();
        repaint();
    }
}

void TrackView::selectTrack(int trackIndex)
{
    m_selectedTrackIndex = trackIndex;
    repaint();
}

void TrackView::duplicateTrack(int trackIndex)
{
    // TODO: Implement track duplication
    DBG("TODO: Duplicate track " + juce::String(trackIndex));
}

// ============================================================================
// ZOOM & SCROLL
// ============================================================================

void TrackView::setZoom(double pixelsPerSecond)
{
    m_pixelsPerSecond = juce::jlimit(10.0, 1000.0, pixelsPerSecond);
    repaint();
}

void TrackView::zoomIn()
{
    setZoom(m_pixelsPerSecond * 1.5);
}

void TrackView::zoomOut()
{
    setZoom(m_pixelsPerSecond / 1.5);
}

void TrackView::zoomToFit()
{
    // Zoom to show entire project
    double projectLength = m_audioEngine.getProjectLength();
    if (projectLength > 0)
    {
        m_pixelsPerSecond = (getWidth() - TIME_RULER_WIDTH) / projectLength;
        m_scrollPosition = 0.0;
        repaint();
    }
}

void TrackView::setScrollPosition(double pixels)
{
    m_scrollPosition = juce::jmax(0.0, pixels);
    repaint();
}

double TrackView::getZoom() const
{
    return m_pixelsPerSecond;
}

double TrackView::getScrollPosition() const
{
    return m_scrollPosition;
}

// ============================================================================
// SELECTION
// ============================================================================

void TrackView::deleteSelection()
{
    if (!m_hasSelection || m_draggedTrackIndex < 0)
        return;

    double startTime = pixelToTime(juce::jmin(m_selectionStart, m_selectionEnd));
    double endTime = pixelToTime(juce::jmax(m_selectionStart, m_selectionEnd));

    // TODO: Delete audio/MIDI in selection range for track
    DBG("Delete selection: track " + juce::String(m_draggedTrackIndex) +
        ", time " + juce::String(startTime, 2) + " - " + juce::String(endTime, 2));

    m_hasSelection = false;
    repaint();
}

void TrackView::selectAll()
{
    m_selectionStart = TIME_RULER_WIDTH;
    m_selectionEnd = timeToPixel(m_audioEngine.getProjectLength());
    m_hasSelection = true;
    repaint();
}

void TrackView::clearSelection()
{
    m_hasSelection = false;
    repaint();
}

// ============================================================================
// HELPERS
// ============================================================================

double TrackView::timeToPixel(double timeSeconds) const
{
    return TIME_RULER_WIDTH + (timeSeconds * m_pixelsPerSecond) - m_scrollPosition;
}

double TrackView::pixelToTime(double pixel) const
{
    return (pixel - TIME_RULER_WIDTH + m_scrollPosition) / m_pixelsPerSecond;
}

juce::Rectangle<int> TrackView::getTrackBounds(int trackIndex) const
{
    int y = TIME_RULER_HEIGHT + trackIndex * TRACK_HEIGHT;
    int width = getWidth();
    return juce::Rectangle<int>(0, y, width, TRACK_HEIGHT);
}

int TrackView::getTrackIndexAt(int y) const
{
    if (y < TIME_RULER_HEIGHT)
        return -1;

    int trackIndex = (y - TIME_RULER_HEIGHT) / TRACK_HEIGHT;

    if (trackIndex < m_audioEngine.getNumTracks())
        return trackIndex;

    return -1;
}

// ============================================================================
// PAINTING
// ============================================================================

void TrackView::paintTimeRuler(juce::Graphics& g)
{
    juce::Rectangle<int> rulerBounds(0, 0, getWidth(), TIME_RULER_HEIGHT);

    // Background
    g.setColour(juce::Colour(0xFF16213E));  // Slightly lighter than main background
    g.fillRect(rulerBounds);

    // Time markers
    g.setColour(juce::Colour(0xFF00E5FF));  // Cyan text
    g.setFont(12.0f);

    double startTime = pixelToTime(0);
    double endTime = pixelToTime(getWidth());

    // Calculate interval (show markers every 1, 5, 10, 30, 60 seconds depending on zoom)
    double interval = 1.0;
    if (m_pixelsPerSecond < 20.0)
        interval = 60.0;  // 1 minute
    else if (m_pixelsPerSecond < 50.0)
        interval = 30.0;  // 30 seconds
    else if (m_pixelsPerSecond < 100.0)
        interval = 10.0;  // 10 seconds
    else if (m_pixelsPerSecond < 200.0)
        interval = 5.0;   // 5 seconds

    int startMarker = (int)std::floor(startTime / interval);
    int endMarker = (int)std::ceil(endTime / interval);

    for (int i = startMarker; i <= endMarker; ++i)
    {
        double time = i * interval;
        float x = (float)timeToPixel(time);

        // Major tick
        g.drawLine(x, TIME_RULER_HEIGHT - 10, x, TIME_RULER_HEIGHT, 1.0f);

        // Time label (MM:SS format)
        int minutes = (int)(time / 60.0);
        int seconds = (int)time % 60;
        juce::String timeString = juce::String(minutes) + ":" + juce::String(seconds).paddedLeft('0', 2);

        g.drawText(timeString, (int)x - 30, 5, 60, TIME_RULER_HEIGHT - 15,
                   juce::Justification::centred, false);
    }

    // Border
    g.setColour(juce::Colour(0xFF651FFF));  // Purple border
    g.drawLine(0, TIME_RULER_HEIGHT, (float)getWidth(), TIME_RULER_HEIGHT, 2.0f);
}

void TrackView::paintTrack(juce::Graphics& g, audio::Track* track, juce::Rectangle<int> bounds, int trackIndex)
{
    // Track background (alternating colors)
    if (trackIndex % 2 == 0)
        g.setColour(juce::Colour(0xFF1A1A2E));
    else
        g.setColour(juce::Colour(0xFF16213E));
    g.fillRect(bounds);

    // Selected track highlight
    if (trackIndex == m_selectedTrackIndex)
    {
        g.setColour(juce::Colour(0xFF651FFF).withAlpha(0.2f));  // Purple highlight
        g.fillRect(bounds);
    }

    // Track name area (left sidebar)
    juce::Rectangle<int> nameArea = bounds.removeFromLeft(TIME_RULER_WIDTH);
    g.setColour(juce::Colour(0xFF16213E));
    g.fillRect(nameArea);

    // Track name
    g.setColour(juce::Colour(0xFF00E5FF));  // Cyan
    g.setFont(14.0f);
    g.drawText(track->getName(), nameArea.reduced(5), juce::Justification::centredLeft, true);

    // Waveform area
    juce::Rectangle<int> waveformArea = bounds.withTrimmedLeft(TIME_RULER_WIDTH);

    // Draw waveform
    if (track->isAudioTrack() && trackIndex < m_waveformThumbnails.size())
    {
        paintWaveform(g, waveformArea, m_waveformThumbnails[trackIndex]);
    }
    else if (!track->isAudioTrack())
    {
        // MIDI track - draw piano roll preview
        g.setColour(juce::Colour(0xFFFF00FF).withAlpha(0.3f));  // Magenta for MIDI
        g.drawText("MIDI Track (TODO: Piano Roll)", waveformArea, juce::Justification::centred, true);
    }

    // Track border
    g.setColour(juce::Colour(0xFF651FFF).withAlpha(0.3f));
    g.drawRect(bounds, 1);
}

void TrackView::paintWaveform(juce::Graphics& g, juce::Rectangle<int> bounds, const WaveformThumbnail& waveform)
{
    if (waveform.samples.empty())
    {
        // No audio yet
        g.setColour(juce::Colour(0xFF666666));
        g.drawText("No Audio", bounds, juce::Justification::centred, true);
        return;
    }

    // Draw waveform
    g.setColour(juce::Colour(0xFF00E5FF));  // Cyan waveform

    int numSamples = (int)waveform.samples.size();
    double samplesPerPixel = (double)numSamples / bounds.getWidth();

    for (int x = 0; x < bounds.getWidth(); ++x)
    {
        int sampleIndex = (int)(x * samplesPerPixel);
        if (sampleIndex >= numSamples)
            break;

        float sample = waveform.samples[sampleIndex];

        // Scale to bounds
        int centerY = bounds.getCentreY();
        int waveHeight = bounds.getHeight() / 2;
        int y = centerY - (int)(sample * waveHeight);

        // Draw vertical line from center to sample
        g.drawLine((float)(bounds.getX() + x), (float)centerY,
                   (float)(bounds.getX() + x), (float)y,
                   1.0f);
    }
}

void TrackView::paintPlaybackCursor(juce::Graphics& g)
{
    double currentTime = m_audioEngine.getCurrentPosition();
    float cursorX = (float)timeToPixel(currentTime);

    // Draw vertical line
    g.setColour(juce::Colour(0xFFFF00FF));  // Magenta cursor (vaporwave!)
    g.drawLine(cursorX, (float)TIME_RULER_HEIGHT, cursorX, (float)getHeight(), 2.0f);

    // Draw playhead triangle
    juce::Path triangle;
    triangle.addTriangle(cursorX - 6, TIME_RULER_HEIGHT,
                         cursorX + 6, TIME_RULER_HEIGHT,
                         cursorX, TIME_RULER_HEIGHT + 10);
    g.fillPath(triangle);
}

void TrackView::paintSelection(juce::Graphics& g)
{
    float left = juce::jmin(m_selectionStart, m_selectionEnd);
    float right = juce::jmax(m_selectionStart, m_selectionEnd);

    juce::Rectangle<float> selectionBounds(
        left, (float)TIME_RULER_HEIGHT,
        right - left, (float)(getHeight() - TIME_RULER_HEIGHT)
    );

    // Semi-transparent purple overlay
    g.setColour(juce::Colour(0xFF651FFF).withAlpha(0.3f));
    g.fillRect(selectionBounds);

    // Selection borders
    g.setColour(juce::Colour(0xFFFF00FF));  // Magenta borders
    g.drawRect(selectionBounds, 2.0f);
}

// ============================================================================
// WAVEFORM GENERATION
// ============================================================================

void TrackView::regenerateWaveforms()
{
    m_waveformThumbnails.clear();

    for (int i = 0; i < m_audioEngine.getNumTracks(); ++i)
    {
        auto track = m_audioEngine.getTrack(i);
        if (track != nullptr && track->isAudioTrack())
        {
            WaveformThumbnail thumbnail;
            generateWaveformThumbnail(track, thumbnail);
            m_waveformThumbnails.push_back(thumbnail);
        }
        else
        {
            // Empty thumbnail for MIDI tracks
            m_waveformThumbnails.push_back(WaveformThumbnail());
        }
    }
}

void TrackView::generateWaveformThumbnail(audio::Track* track, WaveformThumbnail& thumbnail)
{
    // Get audio buffer from track
    const auto& audioBuffer = track->getAudioBuffer();

    if (audioBuffer.getNumSamples() == 0)
    {
        thumbnail.samples.clear();
        return;
    }

    // Downsample for thumbnail (1 sample per pixel at default zoom)
    int targetSamples = (int)(audioBuffer.getNumSamples() / 100);  // ~1000 samples for thumbnail
    thumbnail.samples.resize(targetSamples);

    int samplesPerThumbnailSample = audioBuffer.getNumSamples() / targetSamples;

    for (int i = 0; i < targetSamples; ++i)
    {
        // Find RMS in this chunk
        float rms = 0.0f;
        int startSample = i * samplesPerThumbnailSample;
        int endSample = juce::jmin(startSample + samplesPerThumbnailSample, audioBuffer.getNumSamples());

        for (int ch = 0; ch < audioBuffer.getNumChannels(); ++ch)
        {
            const float* channelData = audioBuffer.getReadPointer(ch);

            for (int s = startSample; s < endSample; ++s)
            {
                rms += channelData[s] * channelData[s];
            }
        }

        rms = std::sqrt(rms / ((endSample - startSample) * audioBuffer.getNumChannels()));
        thumbnail.samples[i] = rms;
    }
}

// ============================================================================
// CONTEXT MENU
// ============================================================================

void TrackView::showContextMenu(juce::Point<float> position)
{
    juce::PopupMenu menu;

    menu.addItem(1, "Add Audio Track");
    menu.addItem(2, "Add MIDI Track");
    menu.addSeparator();
    menu.addItem(3, "Duplicate Track");
    menu.addItem(4, "Delete Track");
    menu.addSeparator();
    menu.addItem(5, "Zoom to Fit");
    menu.addItem(6, "Reset Zoom");

    int result = menu.show();

    switch (result)
    {
        case 1: addTrack("Audio " + juce::String(m_audioEngine.getNumTracks() + 1), true); break;
        case 2: addTrack("MIDI " + juce::String(m_audioEngine.getNumTracks() + 1), false); break;
        case 3: duplicateTrack(m_selectedTrackIndex); break;
        case 4: removeTrack(m_selectedTrackIndex); break;
        case 5: zoomToFit(); break;
        case 6: setZoom(100.0); break;
    }
}

} // namespace ui
} // namespace echoelmusic

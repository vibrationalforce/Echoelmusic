#pragma once

#include <JuceHeader.h>
#include "../Hardware/BluetoothAudioManager.h"

namespace Echoelmusic {

/**
 * BluetoothStatusPanel - Real-time Bluetooth Audio Status Display
 *
 * Shows:
 * - Connection status (Wired/Bluetooth)
 * - Active codec (SBC, aptX, LDAC, etc.)
 * - Estimated latency
 * - Quality indicators
 * - Warnings for high-latency situations
 */
class BluetoothStatusPanel : public juce::Component,
                              public juce::Timer
{
public:
    //==========================================================================
    // Constructor & Destructor
    //==========================================================================

    BluetoothStatusPanel(BluetoothAudioManager* btManager = nullptr)
        : bluetoothManager(btManager)
    {
        setSize(300, 80);

        // Start update timer
        startTimer(500);  // Update every 500ms
    }

    ~BluetoothStatusPanel() override
    {
        stopTimer();
    }

    //==========================================================================
    // Manager Reference
    //==========================================================================

    void setBluetoothManager(BluetoothAudioManager* manager)
    {
        bluetoothManager = manager;
        updateStatus();
        repaint();
    }

    //==========================================================================
    // Component Overrides
    //==========================================================================

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().reduced(4);

        // Background
        g.setColour(juce::Colour(0xFF1E1E1E));
        g.fillRoundedRectangle(bounds.toFloat(), 8.0f);

        // Border
        g.setColour(juce::Colour(0xFF3A3A3A));
        g.drawRoundedRectangle(bounds.toFloat(), 8.0f, 1.0f);

        auto contentBounds = bounds.reduced(12);

        // Icon area
        auto iconBounds = contentBounds.removeFromLeft(40);

        // Draw Bluetooth icon or wired icon
        drawIcon(g, iconBounds);

        contentBounds.removeFromLeft(8);

        // Status text
        g.setFont(juce::Font(14.0f).boldened());

        if (isBluetoothActive)
        {
            // Bluetooth active
            g.setColour(juce::Colour(0xFF4FC3F7));  // Light blue
            g.drawText(deviceName.isEmpty() ? "Bluetooth" : deviceName,
                      contentBounds.removeFromTop(20),
                      juce::Justification::centredLeft, true);

            // Codec and latency
            g.setFont(juce::Font(12.0f));
            g.setColour(juce::Colour(0xFFAAAAAA));

            juce::String codecInfo = codecName + " | " +
                                    juce::String(latencyMs, 0) + "ms | " +
                                    juce::String(bitrateKbps) + " kbps";

            g.drawText(codecInfo,
                      contentBounds.removeFromTop(18),
                      juce::Justification::centredLeft, true);

            // Quality indicator
            drawQualityIndicator(g, contentBounds.removeFromTop(20));
        }
        else
        {
            // Wired connection
            g.setColour(juce::Colour(0xFF81C784));  // Green
            g.drawText("Wired Audio",
                      contentBounds.removeFromTop(20),
                      juce::Justification::centredLeft, true);

            g.setFont(juce::Font(12.0f));
            g.setColour(juce::Colour(0xFFAAAAAA));
            g.drawText("Optimal latency | Direct connection",
                      contentBounds.removeFromTop(18),
                      juce::Justification::centredLeft, true);

            // Optimal indicator
            g.setColour(juce::Colour(0xFF81C784));
            g.fillEllipse(contentBounds.removeFromLeft(8).reduced(0, 6).toFloat());

            g.setColour(juce::Colour(0xFF81C784));
            g.drawText("Optimal for monitoring",
                      contentBounds.reduced(4, 0),
                      juce::Justification::centredLeft, true);
        }
    }

    void resized() override
    {
        // Layout handled in paint()
    }

    void timerCallback() override
    {
        updateStatus();
    }

private:
    //==========================================================================
    // Drawing Helpers
    //==========================================================================

    void drawIcon(juce::Graphics& g, juce::Rectangle<int> bounds)
    {
        auto center = bounds.getCentre().toFloat();
        float radius = juce::jmin(bounds.getWidth(), bounds.getHeight()) * 0.35f;

        if (isBluetoothActive)
        {
            // Bluetooth icon
            g.setColour(juce::Colour(0xFF4FC3F7));

            // Draw simplified Bluetooth rune
            juce::Path btPath;
            float x = center.x;
            float y = center.y;
            float h = radius * 1.8f;
            float w = radius * 0.8f;

            // Main vertical line
            btPath.startNewSubPath(x, y - h/2);
            btPath.lineTo(x, y + h/2);

            // Top arrow
            btPath.startNewSubPath(x - w, y - h/4);
            btPath.lineTo(x + w, y + h/4);
            btPath.lineTo(x, y - h/2);

            // Bottom arrow
            btPath.startNewSubPath(x - w, y + h/4);
            btPath.lineTo(x + w, y - h/4);
            btPath.lineTo(x, y + h/2);

            g.strokePath(btPath, juce::PathStrokeType(2.0f));

            // Connection indicator rings
            if (latencyMs < 50.0f)
            {
                g.setColour(juce::Colour(0xFF81C784).withAlpha(0.5f));
            }
            else if (latencyMs < 100.0f)
            {
                g.setColour(juce::Colour(0xFFFFEB3B).withAlpha(0.5f));
            }
            else
            {
                g.setColour(juce::Colour(0xFFEF5350).withAlpha(0.5f));
            }

            g.drawEllipse(center.x - radius * 1.3f, center.y - radius * 1.3f,
                         radius * 2.6f, radius * 2.6f, 1.5f);
        }
        else
        {
            // Wired headphone icon
            g.setColour(juce::Colour(0xFF81C784));

            // Headphone arc
            juce::Path hpPath;
            hpPath.addArc(center.x - radius, center.y - radius * 0.5f,
                         radius * 2, radius * 2,
                         juce::MathConstants<float>::pi,
                         juce::MathConstants<float>::twoPi, true);

            g.strokePath(hpPath, juce::PathStrokeType(2.5f));

            // Ear cups
            g.fillRoundedRectangle(center.x - radius - 3, center.y + radius * 0.3f,
                                  6, radius * 0.8f, 2.0f);
            g.fillRoundedRectangle(center.x + radius - 3, center.y + radius * 0.3f,
                                  6, radius * 0.8f, 2.0f);
        }
    }

    void drawQualityIndicator(juce::Graphics& g, juce::Rectangle<int> bounds)
    {
        juce::Colour indicatorColor;
        juce::String qualityText;

        if (latencyMs < 50.0f)
        {
            indicatorColor = juce::Colour(0xFF81C784);  // Green
            qualityText = "Low Latency - Good for monitoring";
        }
        else if (latencyMs < 100.0f)
        {
            indicatorColor = juce::Colour(0xFFFFEB3B);  // Yellow
            qualityText = "Moderate latency - Playback OK";
        }
        else
        {
            indicatorColor = juce::Colour(0xFFEF5350);  // Red
            qualityText = "High latency - Use wired for recording";
        }

        // Indicator dot
        auto dotBounds = bounds.removeFromLeft(12);
        g.setColour(indicatorColor);
        g.fillEllipse(dotBounds.reduced(2).toFloat());

        // Quality text
        g.setFont(juce::Font(11.0f));
        g.setColour(indicatorColor);
        g.drawText(qualityText, bounds.reduced(4, 0),
                  juce::Justification::centredLeft, true);
    }

    //==========================================================================
    // State Update
    //==========================================================================

    void updateStatus()
    {
        if (bluetoothManager == nullptr)
        {
            isBluetoothActive = false;
            repaint();
            return;
        }

        bool wasActive = isBluetoothActive;
        isBluetoothActive = bluetoothManager->isBluetoothActive();

        if (isBluetoothActive)
        {
            auto info = bluetoothManager->getCodecInfo();
            codecName = info.name;
            latencyMs = info.typicalLatencyMs;
            bitrateKbps = info.maxBitrate;
            supportsHiRes = info.supportsHiRes;
            supportsLowLatency = info.supportsLowLatency;
            deviceName = bluetoothManager->getDeviceName();
        }

        if (wasActive != isBluetoothActive)
        {
            repaint();
        }
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    BluetoothAudioManager* bluetoothManager = nullptr;

    // Cached state
    bool isBluetoothActive = false;
    juce::String codecName = "Unknown";
    float latencyMs = 0.0f;
    int bitrateKbps = 0;
    bool supportsHiRes = false;
    bool supportsLowLatency = false;
    juce::String deviceName;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BluetoothStatusPanel)
};

//==============================================================================
// Compact Bluetooth Status Indicator (for status bar)
//==============================================================================

class BluetoothStatusIndicator : public juce::Component,
                                  public juce::Timer
{
public:
    BluetoothStatusIndicator(BluetoothAudioManager* btManager = nullptr)
        : bluetoothManager(btManager)
    {
        setSize(24, 24);
        startTimer(1000);
    }

    ~BluetoothStatusIndicator() override
    {
        stopTimer();
    }

    void setBluetoothManager(BluetoothAudioManager* manager)
    {
        bluetoothManager = manager;
        repaint();
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        if (bluetoothManager && bluetoothManager->isBluetoothActive())
        {
            auto info = bluetoothManager->getCodecInfo();

            // Color based on latency
            juce::Colour color;
            if (info.typicalLatencyMs < 50.0f)
                color = juce::Colour(0xFF81C784);  // Green
            else if (info.typicalLatencyMs < 100.0f)
                color = juce::Colour(0xFFFFEB3B);  // Yellow
            else
                color = juce::Colour(0xFFEF5350);  // Red

            // Draw Bluetooth icon
            g.setColour(color);

            auto center = bounds.getCentre();
            float h = bounds.getHeight() * 0.6f;
            float w = bounds.getWidth() * 0.25f;
            float x = center.x;
            float y = center.y;

            juce::Path btPath;
            btPath.startNewSubPath(x, y - h/2);
            btPath.lineTo(x, y + h/2);
            btPath.startNewSubPath(x - w, y - h/4);
            btPath.lineTo(x + w, y + h/4);
            btPath.lineTo(x, y - h/2);
            btPath.startNewSubPath(x - w, y + h/4);
            btPath.lineTo(x + w, y - h/4);
            btPath.lineTo(x, y + h/2);

            g.strokePath(btPath, juce::PathStrokeType(1.5f));
        }
        else
        {
            // Wired indicator (green headphone)
            g.setColour(juce::Colour(0xFF81C784));

            auto center = bounds.getCentre();
            float radius = bounds.getWidth() * 0.3f;

            juce::Path hpPath;
            hpPath.addArc(center.x - radius, center.y - radius * 0.3f,
                         radius * 2, radius * 1.6f,
                         juce::MathConstants<float>::pi,
                         juce::MathConstants<float>::twoPi, true);

            g.strokePath(hpPath, juce::PathStrokeType(1.5f));

            g.fillRoundedRectangle(center.x - radius - 2, center.y + radius * 0.4f,
                                  4, radius * 0.5f, 1.0f);
            g.fillRoundedRectangle(center.x + radius - 2, center.y + radius * 0.4f,
                                  4, radius * 0.5f, 1.0f);
        }
    }

    void timerCallback() override
    {
        repaint();
    }

    // Tooltip with full status
    juce::String getTooltip()
    {
        if (bluetoothManager)
            return bluetoothManager->getStatusString();
        return "Audio Status";
    }

private:
    BluetoothAudioManager* bluetoothManager = nullptr;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BluetoothStatusIndicator)
};

} // namespace Echoelmusic

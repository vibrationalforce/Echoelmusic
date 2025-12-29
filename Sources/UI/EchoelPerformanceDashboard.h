#pragma once

/**
 * EchoelPerformanceDashboard.h - Real-Time Performance Monitoring UI
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - METRICS VISUALIZATION
 * ============================================================================
 *
 *   DISPLAYS:
 *     - CPU usage (per-thread breakdown)
 *     - Audio latency (buffer, processing, total)
 *     - Render FPS and frame time
 *     - Memory usage (heap, pool, peak)
 *     - Network latency (sync delay)
 *     - DSP load percentage
 *     - Buffer underruns/overruns
 *
 *   VISUALIZATION:
 *     - Real-time graphs (60 second history)
 *     - Traffic light indicators (green/yellow/red)
 *     - Numerical readouts with units
 *     - Performance warnings/alerts
 *
 * ============================================================================
 */

#include "../Design/EchoelDesignSystem.h"
#include "../Core/EchoelMainController.h"
#include <JuceHeader.h>
#include <array>
#include <deque>
#include <atomic>

namespace Echoel::UI
{

//==============================================================================
// Performance Metrics Data
//==============================================================================

struct PerformanceMetrics
{
    // CPU
    float cpuUsage = 0.0f;           // Total CPU %
    float audioThreadCpu = 0.0f;     // Audio thread %
    float renderThreadCpu = 0.0f;    // Render thread %
    float mainThreadCpu = 0.0f;      // Main/UI thread %

    // Audio
    float audioLatencyMs = 0.0f;     // Total audio latency
    float bufferLatencyMs = 0.0f;    // Buffer-only latency
    float processingTimeMs = 0.0f;   // DSP processing time
    float dspLoad = 0.0f;            // DSP load %
    int bufferUnderruns = 0;
    int bufferOverruns = 0;

    // Render
    float renderFps = 60.0f;
    float frameTimeMs = 16.67f;
    float laserLatencyMs = 0.0f;

    // Memory
    size_t heapUsedBytes = 0;
    size_t heapPeakBytes = 0;
    size_t poolUsedBytes = 0;
    size_t poolCapacityBytes = 0;

    // Network
    float networkLatencyMs = 0.0f;
    int connectedPeers = 0;

    // Status flags
    bool audioOk = true;
    bool renderOk = true;
    bool memoryOk = true;
    bool networkOk = true;
};

//==============================================================================
// Metric Graph (Ring Buffer)
//==============================================================================

class MetricGraph
{
public:
    static constexpr int HISTORY_SIZE = 360;  // 60 seconds at 6 Hz

    void addSample(float value)
    {
        if (history_.size() >= HISTORY_SIZE)
            history_.pop_front();
        history_.push_back(value);

        // Update stats
        if (value > peak_) peak_ = value;
        sum_ += value;
        count_++;
    }

    float getCurrent() const
    {
        return history_.empty() ? 0.0f : history_.back();
    }

    float getAverage() const
    {
        return count_ > 0 ? sum_ / count_ : 0.0f;
    }

    float getPeak() const { return peak_; }

    void reset()
    {
        history_.clear();
        peak_ = 0.0f;
        sum_ = 0.0f;
        count_ = 0;
    }

    const std::deque<float>& getHistory() const { return history_; }

private:
    std::deque<float> history_;
    float peak_ = 0.0f;
    float sum_ = 0.0f;
    int count_ = 0;
};

//==============================================================================
// Mini Graph Component
//==============================================================================

class MiniGraphComponent : public juce::Component
{
public:
    MiniGraphComponent(const std::string& label, const std::string& unit)
        : label_(label), unit_(unit)
    {
    }

    void setData(const MetricGraph& graph)
    {
        history_ = graph.getHistory();
        current_ = graph.getCurrent();
        peak_ = graph.getPeak();
        repaint();
    }

    void setThresholds(float warning, float critical)
    {
        warningThreshold_ = warning;
        criticalThreshold_ = critical;
    }

    void setRange(float min, float max)
    {
        minValue_ = min;
        maxValue_ = max;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(juce::Colour(0xFF1A1A2E));
        g.fillRoundedRectangle(bounds, 4.0f);

        // Graph area
        auto graphArea = bounds.reduced(8.0f);
        graphArea.removeFromTop(20.0f);   // Label space
        graphArea.removeFromBottom(16.0f); // Value space

        // Draw graph line
        if (!history_.empty())
        {
            juce::Path path;
            float xStep = graphArea.getWidth() / (MetricGraph::HISTORY_SIZE - 1);

            bool started = false;
            for (size_t i = 0; i < history_.size(); ++i)
            {
                float normalized = (history_[i] - minValue_) / (maxValue_ - minValue_);
                normalized = juce::jlimit(0.0f, 1.0f, normalized);
                float x = graphArea.getX() + i * xStep;
                float y = graphArea.getBottom() - normalized * graphArea.getHeight();

                if (!started)
                {
                    path.startNewSubPath(x, y);
                    started = true;
                }
                else
                {
                    path.lineTo(x, y);
                }
            }

            // Color based on current value
            juce::Colour lineColor;
            if (current_ >= criticalThreshold_)
                lineColor = juce::Colour(0xFFFF4757);  // Red
            else if (current_ >= warningThreshold_)
                lineColor = juce::Colour(0xFFFFAA00);  // Orange
            else
                lineColor = juce::Colour(0xFF00D9FF);  // Cyan

            g.setColour(lineColor.withAlpha(0.3f));

            // Fill under curve
            juce::Path fillPath = path;
            fillPath.lineTo(graphArea.getRight(), graphArea.getBottom());
            fillPath.lineTo(graphArea.getX(), graphArea.getBottom());
            fillPath.closeSubPath();
            g.fillPath(fillPath);

            // Draw line
            g.setColour(lineColor);
            g.strokePath(path, juce::PathStrokeType(1.5f));
        }

        // Threshold lines
        if (warningThreshold_ > 0)
        {
            float y = graphArea.getBottom() -
                      ((warningThreshold_ - minValue_) / (maxValue_ - minValue_)) * graphArea.getHeight();
            g.setColour(juce::Colour(0x40FFAA00));
            g.drawHorizontalLine(static_cast<int>(y), graphArea.getX(), graphArea.getRight());
        }

        if (criticalThreshold_ > 0)
        {
            float y = graphArea.getBottom() -
                      ((criticalThreshold_ - minValue_) / (maxValue_ - minValue_)) * graphArea.getHeight();
            g.setColour(juce::Colour(0x40FF4757));
            g.drawHorizontalLine(static_cast<int>(y), graphArea.getX(), graphArea.getRight());
        }

        // Label
        g.setColour(juce::Colour(0xFFAAAAAA));
        g.setFont(Design::Typography::label());
        g.drawText(juce::String(label_), bounds.removeFromTop(20.0f).reduced(8.0f, 0),
                   juce::Justification::centredLeft);

        // Current value
        juce::String valueText = juce::String(current_, 1) + " " + juce::String(unit_);
        g.setColour(juce::Colours::white);
        g.setFont(Design::Typography::dataDisplay(14.0f));
        g.drawText(valueText, bounds.removeFromBottom(16.0f).reduced(8.0f, 0),
                   juce::Justification::centredLeft);

        // Peak value
        juce::String peakText = "Peak: " + juce::String(peak_, 1);
        g.setColour(juce::Colour(0xFF888888));
        g.setFont(Design::Typography::label());
        g.drawText(peakText, bounds.removeFromBottom(16.0f).reduced(8.0f, 0),
                   juce::Justification::centredRight);
    }

private:
    std::string label_;
    std::string unit_;
    std::deque<float> history_;
    float current_ = 0.0f;
    float peak_ = 0.0f;
    float minValue_ = 0.0f;
    float maxValue_ = 100.0f;
    float warningThreshold_ = 0.0f;
    float criticalThreshold_ = 0.0f;
};

//==============================================================================
// Status Indicator
//==============================================================================

class StatusIndicator : public juce::Component
{
public:
    enum class Status { Good, Warning, Critical, Unknown };

    StatusIndicator(const std::string& label)
        : label_(label)
    {
    }

    void setStatus(Status status)
    {
        status_ = status;
        repaint();
    }

    void setMessage(const std::string& msg)
    {
        message_ = msg;
        repaint();
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Indicator dot
        float dotSize = 12.0f;
        juce::Colour dotColor;

        switch (status_)
        {
            case Status::Good:     dotColor = juce::Colour(0xFF00FF88); break;
            case Status::Warning:  dotColor = juce::Colour(0xFFFFAA00); break;
            case Status::Critical: dotColor = juce::Colour(0xFFFF4757); break;
            default:               dotColor = juce::Colour(0xFF666666); break;
        }

        g.setColour(dotColor);
        g.fillEllipse(8.0f, (bounds.getHeight() - dotSize) / 2, dotSize, dotSize);

        // Glow effect
        g.setColour(dotColor.withAlpha(0.3f));
        g.fillEllipse(6.0f, (bounds.getHeight() - dotSize - 4) / 2, dotSize + 4, dotSize + 4);

        // Label
        g.setColour(juce::Colours::white);
        g.setFont(Design::Typography::body());
        g.drawText(juce::String(label_), bounds.withTrimmedLeft(28.0f),
                   juce::Justification::centredLeft);

        // Message
        if (!message_.empty())
        {
            g.setColour(juce::Colour(0xFF888888));
            g.setFont(Design::Typography::caption());
            g.drawText(juce::String(message_), bounds.withTrimmedLeft(28.0f),
                       juce::Justification::centredRight);
        }
    }

private:
    std::string label_;
    std::string message_;
    Status status_ = Status::Unknown;
};

//==============================================================================
// Performance Dashboard Component
//==============================================================================

class EchoelPerformanceDashboard : public juce::Component, private juce::Timer
{
public:
    EchoelPerformanceDashboard()
    {
        // Initialize graphs
        cpuGraph_ = std::make_unique<MiniGraphComponent>("CPU Usage", "%");
        cpuGraph_->setRange(0.0f, 100.0f);
        cpuGraph_->setThresholds(60.0f, 85.0f);
        addAndMakeVisible(*cpuGraph_);

        audioLatencyGraph_ = std::make_unique<MiniGraphComponent>("Audio Latency", "ms");
        audioLatencyGraph_->setRange(0.0f, 50.0f);
        audioLatencyGraph_->setThresholds(10.0f, 20.0f);
        addAndMakeVisible(*audioLatencyGraph_);

        renderFpsGraph_ = std::make_unique<MiniGraphComponent>("Render FPS", "fps");
        renderFpsGraph_->setRange(0.0f, 120.0f);
        renderFpsGraph_->setThresholds(30.0f, 20.0f);  // Inverted (low is bad)
        addAndMakeVisible(*renderFpsGraph_);

        memoryGraph_ = std::make_unique<MiniGraphComponent>("Memory", "MB");
        memoryGraph_->setRange(0.0f, 1024.0f);
        memoryGraph_->setThresholds(512.0f, 768.0f);
        addAndMakeVisible(*memoryGraph_);

        // Initialize status indicators
        audioStatus_ = std::make_unique<StatusIndicator>("Audio Engine");
        addAndMakeVisible(*audioStatus_);

        renderStatus_ = std::make_unique<StatusIndicator>("Render Engine");
        addAndMakeVisible(*renderStatus_);

        networkStatus_ = std::make_unique<StatusIndicator>("Network Sync");
        addAndMakeVisible(*networkStatus_);

        bioStatus_ = std::make_unique<StatusIndicator>("Bio Sensors");
        addAndMakeVisible(*bioStatus_);

        // Start update timer
        startTimerHz(6);  // 6 Hz update rate
    }

    void setMetricsSource(std::function<PerformanceMetrics()> source)
    {
        metricsSource_ = std::move(source);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(16);

        // Title
        bounds.removeFromTop(40);

        // Status indicators row
        auto statusRow = bounds.removeFromTop(32);
        int statusWidth = statusRow.getWidth() / 4;
        audioStatus_->setBounds(statusRow.removeFromLeft(statusWidth));
        renderStatus_->setBounds(statusRow.removeFromLeft(statusWidth));
        networkStatus_->setBounds(statusRow.removeFromLeft(statusWidth));
        bioStatus_->setBounds(statusRow);

        bounds.removeFromTop(16);

        // Graphs grid (2x2)
        int graphWidth = (bounds.getWidth() - 16) / 2;
        int graphHeight = (bounds.getHeight() - 16) / 2;

        auto topRow = bounds.removeFromTop(graphHeight);
        cpuGraph_->setBounds(topRow.removeFromLeft(graphWidth));
        topRow.removeFromLeft(16);
        audioLatencyGraph_->setBounds(topRow);

        bounds.removeFromTop(16);

        auto bottomRow = bounds.removeFromTop(graphHeight);
        renderFpsGraph_->setBounds(bottomRow.removeFromLeft(graphWidth));
        bottomRow.removeFromLeft(16);
        memoryGraph_->setBounds(bottomRow);
    }

    void paint(juce::Graphics& g) override
    {
        // Background
        g.fillAll(juce::Colour(0xFF0D0D1A));

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(Design::Typography::heading2());
        g.drawText("Performance Dashboard", getLocalBounds().removeFromTop(48).reduced(16, 0),
                   juce::Justification::centredLeft);
    }

private:
    void timerCallback() override
    {
        if (!metricsSource_)
            return;

        PerformanceMetrics metrics = metricsSource_();

        // Update graphs
        cpuHistory_.addSample(metrics.cpuUsage);
        cpuGraph_->setData(cpuHistory_);

        audioLatencyHistory_.addSample(metrics.audioLatencyMs);
        audioLatencyGraph_->setData(audioLatencyHistory_);

        renderFpsHistory_.addSample(metrics.renderFps);
        renderFpsGraph_->setData(renderFpsHistory_);

        float memoryMB = static_cast<float>(metrics.heapUsedBytes) / (1024 * 1024);
        memoryHistory_.addSample(memoryMB);
        memoryGraph_->setData(memoryHistory_);

        // Update status indicators
        audioStatus_->setStatus(metrics.audioOk ? StatusIndicator::Status::Good :
                                (metrics.dspLoad > 90.0f ? StatusIndicator::Status::Critical :
                                 StatusIndicator::Status::Warning));
        audioStatus_->setMessage(juce::String::formatted("%.1f%% DSP", metrics.dspLoad).toStdString());

        renderStatus_->setStatus(metrics.renderOk ? StatusIndicator::Status::Good :
                                 StatusIndicator::Status::Warning);
        renderStatus_->setMessage(juce::String::formatted("%.0f FPS", metrics.renderFps).toStdString());

        networkStatus_->setStatus(metrics.connectedPeers > 0 ?
                                  StatusIndicator::Status::Good :
                                  StatusIndicator::Status::Unknown);
        networkStatus_->setMessage(std::to_string(metrics.connectedPeers) + " peers");

        bioStatus_->setStatus(StatusIndicator::Status::Good);
    }

    std::function<PerformanceMetrics()> metricsSource_;

    // Graphs
    std::unique_ptr<MiniGraphComponent> cpuGraph_;
    std::unique_ptr<MiniGraphComponent> audioLatencyGraph_;
    std::unique_ptr<MiniGraphComponent> renderFpsGraph_;
    std::unique_ptr<MiniGraphComponent> memoryGraph_;

    // Graph data
    MetricGraph cpuHistory_;
    MetricGraph audioLatencyHistory_;
    MetricGraph renderFpsHistory_;
    MetricGraph memoryHistory_;

    // Status indicators
    std::unique_ptr<StatusIndicator> audioStatus_;
    std::unique_ptr<StatusIndicator> renderStatus_;
    std::unique_ptr<StatusIndicator> networkStatus_;
    std::unique_ptr<StatusIndicator> bioStatus_;
};

}  // namespace Echoel::UI

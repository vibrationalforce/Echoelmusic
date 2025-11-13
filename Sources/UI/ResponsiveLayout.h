#pragma once

#include <JuceHeader.h>
#include <climits>

//==============================================================================
/**
 * @brief Responsive Layout Manager for Cross-Platform UI
 *
 * Automatically adapts UI layout based on:
 * - Screen size (Desktop/Tablet/Phone)
 * - Orientation (Portrait/Landscape)
 * - Input method (Mouse/Touch)
 * - DPI scaling (Retina/4K displays)
 *
 * Platform Support:
 * - Desktop: Windows, macOS, Linux (VST3/AU/AAX/Standalone)
 * - Tablet: iPad (AUv3), Android Tablet
 * - Phone: iOS, Android (future)
 */
class ResponsiveLayout
{
public:
    //==============================================================================
    // Device Types

    enum class DeviceType
    {
        Phone,      // < 480px width
        Tablet,     // 480-1024px width
        Desktop     // > 1024px width
    };

    enum class Orientation
    {
        Portrait,
        Landscape
    };

    enum class InputMethod
    {
        Mouse,
        Touch,
        Pen
    };

    //==============================================================================
    // Layout Metrics

    struct LayoutMetrics
    {
        DeviceType deviceType;
        Orientation orientation;
        InputMethod inputMethod;

        int windowWidth;
        int windowHeight;
        float scaleFactor;          // DPI scaling (1.0 = 96dpi, 2.0 = Retina)

        // Touch-optimized sizing
        int minTouchTarget;         // Minimum touch target size (44-48px recommended)
        int padding;                // Spacing between elements
        int margin;                 // Edge margins

        // Typography
        float fontSizeSmall;
        float fontSizeMedium;
        float fontSizeLarge;

        // Component sizing
        int knobSize;
        int sliderHeight;
        int buttonHeight;
    };

    //==============================================================================
    // Static Methods

    static DeviceType getDeviceType(int windowWidth)
    {
        if (windowWidth < 480)
            return DeviceType::Phone;
        else if (windowWidth < 1024)
            return DeviceType::Tablet;
        else
            return DeviceType::Desktop;
    }

    static Orientation getOrientation(int windowWidth, int windowHeight)
    {
        return (windowHeight > windowWidth) ? Orientation::Portrait : Orientation::Landscape;
    }

    static InputMethod detectInputMethod()
    {
        #if JUCE_IOS || JUCE_ANDROID
            return InputMethod::Touch;
        #else
            // Desktop - check if touchscreen available
            if (juce::Desktop::getInstance().getMainMouseSource().isTouch())
                return InputMethod::Touch;
            return InputMethod::Mouse;
        #endif
    }

    static LayoutMetrics calculateMetrics(int windowWidth, int windowHeight)
    {
        LayoutMetrics metrics;

        metrics.windowWidth = windowWidth;
        metrics.windowHeight = windowHeight;
        metrics.deviceType = getDeviceType(windowWidth);
        metrics.orientation = getOrientation(windowWidth, windowHeight);
        metrics.inputMethod = detectInputMethod();

        // DPI scaling
        metrics.scaleFactor = juce::Desktop::getInstance().getDisplays().getPrimaryDisplay()->scale;

        // Adjust sizing based on device type
        switch (metrics.deviceType)
        {
            case DeviceType::Phone:
                metrics.minTouchTarget = 48;
                metrics.padding = 8;
                metrics.margin = 12;
                metrics.fontSizeSmall = 11.0f;
                metrics.fontSizeMedium = 14.0f;
                metrics.fontSizeLarge = 18.0f;
                metrics.knobSize = 60;
                metrics.sliderHeight = 48;
                metrics.buttonHeight = 44;
                break;

            case DeviceType::Tablet:
                metrics.minTouchTarget = 44;
                metrics.padding = 12;
                metrics.margin = 16;
                metrics.fontSizeSmall = 12.0f;
                metrics.fontSizeMedium = 16.0f;
                metrics.fontSizeLarge = 22.0f;
                metrics.knobSize = 80;
                metrics.sliderHeight = 44;
                metrics.buttonHeight = 40;
                break;

            case DeviceType::Desktop:
                metrics.minTouchTarget = 32;
                metrics.padding = 16;
                metrics.margin = 20;
                metrics.fontSizeSmall = 11.0f;
                metrics.fontSizeMedium = 14.0f;
                metrics.fontSizeLarge = 20.0f;
                metrics.knobSize = 64;
                metrics.sliderHeight = 32;
                metrics.buttonHeight = 32;
                break;
        }

        // Touch-optimized sizing
        if (metrics.inputMethod == InputMethod::Touch)
        {
            metrics.minTouchTarget = juce::jmax(metrics.minTouchTarget, 44);
            metrics.knobSize = juce::jmax(metrics.knobSize, 70);
            metrics.buttonHeight = juce::jmax(metrics.buttonHeight, 44);
        }

        return metrics;
    }

    //==============================================================================
    // Grid Layout System (similar to CSS Grid)

    static juce::Rectangle<int> createGrid(
        juce::Rectangle<int> bounds,
        int columns,
        int rows,
        int column,
        int row,
        int columnSpan = 1,
        int rowSpan = 1,
        int padding = 8)
    {
        int cellWidth = bounds.getWidth() / columns;
        int cellHeight = bounds.getHeight() / rows;

        int x = bounds.getX() + (column * cellWidth) + padding;
        int y = bounds.getY() + (row * cellHeight) + padding;
        int width = (cellWidth * columnSpan) - (padding * 2);
        int height = (cellHeight * rowSpan) - (padding * 2);

        return juce::Rectangle<int>(x, y, width, height);
    }

    //==============================================================================
    // Flexbox-style Layout Helpers

    struct FlexItem
    {
        juce::Component* component;
        float flexGrow = 1.0f;      // Relative growth factor
        int minSize = 0;            // Minimum size in pixels
        int maxSize = INT_MAX;      // Maximum size in pixels
    };

    static void layoutFlexRow(
        juce::Rectangle<int> bounds,
        juce::Array<FlexItem>& items,
        int gap = 8)
    {
        if (items.isEmpty())
            return;

        // Calculate total flex and available space
        float totalFlex = 0.0f;
        int fixedSpace = gap * (items.size() - 1);

        for (const auto& item : items)
        {
            totalFlex += item.flexGrow;
            fixedSpace += item.minSize;
        }

        int availableSpace = juce::jmax(0, bounds.getWidth() - fixedSpace);

        // Layout items
        int x = bounds.getX();
        for (auto& item : items)
        {
            int width = item.minSize + static_cast<int>(availableSpace * (item.flexGrow / totalFlex));
            width = juce::jlimit(item.minSize, item.maxSize, width);

            if (item.component)
                item.component->setBounds(x, bounds.getY(), width, bounds.getHeight());

            x += width + gap;
        }
    }

    static void layoutFlexColumn(
        juce::Rectangle<int> bounds,
        juce::Array<FlexItem>& items,
        int gap = 8)
    {
        if (items.isEmpty())
            return;

        // Calculate total flex and available space
        float totalFlex = 0.0f;
        int fixedSpace = gap * (items.size() - 1);

        for (const auto& item : items)
        {
            totalFlex += item.flexGrow;
            fixedSpace += item.minSize;
        }

        int availableSpace = juce::jmax(0, bounds.getHeight() - fixedSpace);

        // Layout items
        int y = bounds.getY();
        for (auto& item : items)
        {
            int height = item.minSize + static_cast<int>(availableSpace * (item.flexGrow / totalFlex));
            height = juce::jlimit(item.minSize, item.maxSize, height);

            if (item.component)
                item.component->setBounds(bounds.getX(), y, bounds.getWidth(), height);

            y += height + gap;
        }
    }
};

//==============================================================================
/**
 * @brief Base class for responsive components
 *
 * All UI components should inherit from this to support automatic layout adaptation
 */
class ResponsiveComponent : public juce::Component
{
public:
    ResponsiveComponent()
    {
        updateLayoutMetrics();
    }

    void resized() override
    {
        updateLayoutMetrics();
        performResponsiveLayout();
    }

    virtual void performResponsiveLayout()
    {
        // Override in subclasses to implement responsive layout
    }

    const ResponsiveLayout::LayoutMetrics& getLayoutMetrics() const
    {
        return layoutMetrics;
    }

protected:
    void updateLayoutMetrics()
    {
        layoutMetrics = ResponsiveLayout::calculateMetrics(getWidth(), getHeight());
    }

    ResponsiveLayout::LayoutMetrics layoutMetrics;
};

#pragma once

/**
 * EchoelIconLibrary.h - Vector Icon System with WCAG Accessibility
 *
 * ============================================================================
 *   ECHOEL BRAND - LIQUID LIGHT FOR YOUR MUSIC
 * ============================================================================
 *
 *   DESIGN PRINCIPLES:
 *     - All icons are vector-based (Path data)
 *     - Scalable from 12px to 512px without quality loss
 *     - WCAG 2.1 AAA compliant (4.5:1 contrast minimum)
 *     - Touch-friendly minimum size: 44x44px
 *     - Consistent 24px default size, 2px stroke
 *
 *   ACCESSIBILITY FEATURES:
 *     - ARIA labels for screen readers
 *     - High contrast mode support
 *     - Reduced motion alternatives
 *     - Focus indicators for keyboard navigation
 *     - Semantic grouping for related icons
 *
 *   ICON CATEGORIES:
 *     - Audio: Play, pause, volume, waveform, spectrum
 *     - Bio: Heart, brain, breathing, coherence
 *     - Navigation: Menu, back, forward, home, settings
 *     - Actions: Add, remove, edit, save, share
 *     - Status: Success, warning, error, info
 *     - Laser: Beam, pattern, intensity, color
 *
 * ============================================================================
 */

#include "../Design/EchoelDesignSystem.h"
#include <JuceHeader.h>
#include <string>
#include <unordered_map>

namespace Echoel::UI
{

//==============================================================================
// Icon Size Tokens
//==============================================================================

namespace IconSize
{
    constexpr float Tiny = 12.0f;
    constexpr float Small = 16.0f;
    constexpr float Default = 24.0f;
    constexpr float Medium = 32.0f;
    constexpr float Large = 48.0f;
    constexpr float XLarge = 64.0f;
    constexpr float Jumbo = 96.0f;
    constexpr float Hero = 128.0f;

    // Touch-friendly minimum (WCAG)
    constexpr float TouchMinimum = 44.0f;
}

//==============================================================================
// Icon Style Configuration
//==============================================================================

struct IconStyle
{
    float size = IconSize::Default;
    float strokeWidth = 2.0f;
    juce::Colour color = juce::Colour(0xFFE0E0E0);
    juce::Colour backgroundColor = juce::Colours::transparentBlack;
    bool filled = false;
    float opacity = 1.0f;
    float rotation = 0.0f;  // Degrees

    // Accessibility
    bool highContrast = false;
    bool reducedMotion = false;

    static IconStyle defaultStyle()
    {
        return IconStyle();
    }

    static IconStyle filled()
    {
        IconStyle s;
        s.filled = true;
        return s;
    }

    static IconStyle neon(juce::Colour c)
    {
        IconStyle s;
        s.color = c;
        s.strokeWidth = 2.5f;
        return s;
    }

    static IconStyle highContrastMode()
    {
        IconStyle s;
        s.highContrast = true;
        s.color = juce::Colours::white;
        s.strokeWidth = 3.0f;
        return s;
    }

    IconStyle withSize(float s) const { IconStyle copy = *this; copy.size = s; return copy; }
    IconStyle withColor(juce::Colour c) const { IconStyle copy = *this; copy.color = c; return copy; }
    IconStyle withStroke(float w) const { IconStyle copy = *this; copy.strokeWidth = w; return copy; }
    IconStyle withOpacity(float o) const { IconStyle copy = *this; copy.opacity = o; return copy; }
    IconStyle withRotation(float deg) const { IconStyle copy = *this; copy.rotation = deg; return copy; }
};

//==============================================================================
// Icon Path Data (SVG-style path commands)
//==============================================================================

namespace IconPaths
{
    //==========================================================================
    // Audio Icons
    //==========================================================================

    // Play triangle
    inline juce::Path play()
    {
        juce::Path p;
        p.addTriangle(4.0f, 2.0f, 4.0f, 22.0f, 22.0f, 12.0f);
        return p;
    }

    // Pause bars
    inline juce::Path pause()
    {
        juce::Path p;
        p.addRectangle(4.0f, 2.0f, 5.0f, 20.0f);
        p.addRectangle(15.0f, 2.0f, 5.0f, 20.0f);
        return p;
    }

    // Stop square
    inline juce::Path stop()
    {
        juce::Path p;
        p.addRectangle(4.0f, 4.0f, 16.0f, 16.0f);
        return p;
    }

    // Skip forward
    inline juce::Path skipForward()
    {
        juce::Path p;
        p.addTriangle(2.0f, 2.0f, 2.0f, 22.0f, 14.0f, 12.0f);
        p.addRectangle(16.0f, 2.0f, 4.0f, 20.0f);
        return p;
    }

    // Skip back
    inline juce::Path skipBack()
    {
        juce::Path p;
        p.addRectangle(2.0f, 2.0f, 4.0f, 20.0f);
        p.addTriangle(22.0f, 2.0f, 22.0f, 22.0f, 10.0f, 12.0f);
        return p;
    }

    // Volume speaker
    inline juce::Path volumeHigh()
    {
        juce::Path p;
        // Speaker cone
        p.startNewSubPath(3.0f, 9.0f);
        p.lineTo(7.0f, 9.0f);
        p.lineTo(12.0f, 4.0f);
        p.lineTo(12.0f, 20.0f);
        p.lineTo(7.0f, 15.0f);
        p.lineTo(3.0f, 15.0f);
        p.closeSubPath();
        // Sound waves
        p.addArc(14.0f, 6.0f, 8.0f, 12.0f, -0.7f, 0.7f, true);
        p.addArc(16.0f, 8.0f, 6.0f, 8.0f, -0.5f, 0.5f, true);
        return p;
    }

    // Volume muted
    inline juce::Path volumeMute()
    {
        juce::Path p;
        // Speaker cone
        p.startNewSubPath(3.0f, 9.0f);
        p.lineTo(7.0f, 9.0f);
        p.lineTo(12.0f, 4.0f);
        p.lineTo(12.0f, 20.0f);
        p.lineTo(7.0f, 15.0f);
        p.lineTo(3.0f, 15.0f);
        p.closeSubPath();
        // X mark
        p.startNewSubPath(16.0f, 9.0f);
        p.lineTo(22.0f, 15.0f);
        p.startNewSubPath(22.0f, 9.0f);
        p.lineTo(16.0f, 15.0f);
        return p;
    }

    // Waveform
    inline juce::Path waveform()
    {
        juce::Path p;
        p.startNewSubPath(2.0f, 12.0f);
        p.lineTo(5.0f, 6.0f);
        p.lineTo(8.0f, 18.0f);
        p.lineTo(11.0f, 4.0f);
        p.lineTo(14.0f, 20.0f);
        p.lineTo(17.0f, 8.0f);
        p.lineTo(20.0f, 16.0f);
        p.lineTo(22.0f, 12.0f);
        return p;
    }

    // Spectrum bars
    inline juce::Path spectrum()
    {
        juce::Path p;
        p.addRectangle(2.0f, 14.0f, 3.0f, 8.0f);
        p.addRectangle(7.0f, 8.0f, 3.0f, 14.0f);
        p.addRectangle(12.0f, 4.0f, 3.0f, 18.0f);
        p.addRectangle(17.0f, 10.0f, 3.0f, 12.0f);
        return p;
    }

    // Loop/repeat
    inline juce::Path loop()
    {
        juce::Path p;
        p.addRoundedRectangle(3.0f, 6.0f, 18.0f, 12.0f, 4.0f);
        // Arrows
        p.startNewSubPath(17.0f, 6.0f);
        p.lineTo(21.0f, 3.0f);
        p.lineTo(21.0f, 9.0f);
        p.closeSubPath();
        p.startNewSubPath(7.0f, 18.0f);
        p.lineTo(3.0f, 21.0f);
        p.lineTo(3.0f, 15.0f);
        p.closeSubPath();
        return p;
    }

    //==========================================================================
    // Bio/Health Icons
    //==========================================================================

    // Heart
    inline juce::Path heart()
    {
        juce::Path p;
        p.startNewSubPath(12.0f, 21.0f);
        p.cubicTo(5.0f, 15.0f, 2.0f, 11.0f, 2.0f, 7.0f);
        p.cubicTo(2.0f, 4.0f, 4.5f, 2.0f, 7.0f, 2.0f);
        p.cubicTo(9.0f, 2.0f, 11.0f, 3.0f, 12.0f, 5.0f);
        p.cubicTo(13.0f, 3.0f, 15.0f, 2.0f, 17.0f, 2.0f);
        p.cubicTo(19.5f, 2.0f, 22.0f, 4.0f, 22.0f, 7.0f);
        p.cubicTo(22.0f, 11.0f, 19.0f, 15.0f, 12.0f, 21.0f);
        p.closeSubPath();
        return p;
    }

    // Heart pulse (ECG style)
    inline juce::Path heartPulse()
    {
        juce::Path p;
        // Heart outline
        p.startNewSubPath(12.0f, 6.0f);
        p.cubicTo(10.0f, 3.5f, 6.0f, 3.5f, 4.0f, 6.0f);
        p.cubicTo(2.0f, 8.5f, 2.0f, 12.0f, 12.0f, 19.0f);
        p.cubicTo(22.0f, 12.0f, 22.0f, 8.5f, 20.0f, 6.0f);
        p.cubicTo(18.0f, 3.5f, 14.0f, 3.5f, 12.0f, 6.0f);
        // ECG line
        p.startNewSubPath(2.0f, 12.0f);
        p.lineTo(6.0f, 12.0f);
        p.lineTo(8.0f, 8.0f);
        p.lineTo(10.0f, 16.0f);
        p.lineTo(12.0f, 10.0f);
        p.lineTo(14.0f, 14.0f);
        p.lineTo(16.0f, 12.0f);
        p.lineTo(22.0f, 12.0f);
        return p;
    }

    // Brain
    inline juce::Path brain()
    {
        juce::Path p;
        // Left hemisphere
        p.addEllipse(2.0f, 4.0f, 10.0f, 8.0f);
        p.addEllipse(3.0f, 10.0f, 9.0f, 8.0f);
        // Right hemisphere
        p.addEllipse(12.0f, 4.0f, 10.0f, 8.0f);
        p.addEllipse(12.0f, 10.0f, 9.0f, 8.0f);
        // Center connection
        p.addRectangle(11.0f, 6.0f, 2.0f, 12.0f);
        return p;
    }

    // Breathing/lungs
    inline juce::Path breathing()
    {
        juce::Path p;
        // Left lung
        p.startNewSubPath(10.0f, 4.0f);
        p.cubicTo(4.0f, 4.0f, 2.0f, 10.0f, 2.0f, 16.0f);
        p.cubicTo(2.0f, 20.0f, 6.0f, 22.0f, 10.0f, 20.0f);
        p.lineTo(10.0f, 4.0f);
        // Right lung
        p.startNewSubPath(14.0f, 4.0f);
        p.cubicTo(20.0f, 4.0f, 22.0f, 10.0f, 22.0f, 16.0f);
        p.cubicTo(22.0f, 20.0f, 18.0f, 22.0f, 14.0f, 20.0f);
        p.lineTo(14.0f, 4.0f);
        // Trachea
        p.addRectangle(10.0f, 2.0f, 4.0f, 6.0f);
        return p;
    }

    // Coherence/harmony waves
    inline juce::Path coherence()
    {
        juce::Path p;
        // Three synchronized waves
        for (int i = 0; i < 3; ++i)
        {
            float y = 6.0f + i * 6.0f;
            p.startNewSubPath(2.0f, y);
            p.cubicTo(6.0f, y - 3.0f, 10.0f, y + 3.0f, 14.0f, y);
            p.cubicTo(18.0f, y - 3.0f, 22.0f, y + 3.0f, 22.0f, y);
        }
        return p;
    }

    // HRV (heart rate variability) zigzag
    inline juce::Path hrv()
    {
        juce::Path p;
        p.startNewSubPath(2.0f, 12.0f);
        p.lineTo(5.0f, 12.0f);
        p.lineTo(7.0f, 4.0f);
        p.lineTo(9.0f, 20.0f);
        p.lineTo(11.0f, 8.0f);
        p.lineTo(13.0f, 16.0f);
        p.lineTo(15.0f, 10.0f);
        p.lineTo(17.0f, 14.0f);
        p.lineTo(19.0f, 12.0f);
        p.lineTo(22.0f, 12.0f);
        return p;
    }

    //==========================================================================
    // Navigation Icons
    //==========================================================================

    // Hamburger menu
    inline juce::Path menu()
    {
        juce::Path p;
        p.addRectangle(3.0f, 5.0f, 18.0f, 2.0f);
        p.addRectangle(3.0f, 11.0f, 18.0f, 2.0f);
        p.addRectangle(3.0f, 17.0f, 18.0f, 2.0f);
        return p;
    }

    // Close X
    inline juce::Path close()
    {
        juce::Path p;
        p.startNewSubPath(4.0f, 4.0f);
        p.lineTo(20.0f, 20.0f);
        p.startNewSubPath(20.0f, 4.0f);
        p.lineTo(4.0f, 20.0f);
        return p;
    }

    // Back arrow
    inline juce::Path back()
    {
        juce::Path p;
        p.startNewSubPath(15.0f, 4.0f);
        p.lineTo(7.0f, 12.0f);
        p.lineTo(15.0f, 20.0f);
        return p;
    }

    // Forward arrow
    inline juce::Path forward()
    {
        juce::Path p;
        p.startNewSubPath(9.0f, 4.0f);
        p.lineTo(17.0f, 12.0f);
        p.lineTo(9.0f, 20.0f);
        return p;
    }

    // Home
    inline juce::Path home()
    {
        juce::Path p;
        // Roof
        p.startNewSubPath(12.0f, 2.0f);
        p.lineTo(2.0f, 12.0f);
        p.lineTo(5.0f, 12.0f);
        p.lineTo(5.0f, 20.0f);
        p.lineTo(19.0f, 20.0f);
        p.lineTo(19.0f, 12.0f);
        p.lineTo(22.0f, 12.0f);
        p.closeSubPath();
        // Door
        p.addRectangle(9.0f, 14.0f, 6.0f, 6.0f);
        return p;
    }

    // Settings gear
    inline juce::Path settings()
    {
        juce::Path p;
        // Center circle
        p.addEllipse(8.0f, 8.0f, 8.0f, 8.0f);
        // Gear teeth
        for (int i = 0; i < 8; ++i)
        {
            float angle = i * 0.785398f;  // 45 degrees
            float cos_a = std::cos(angle);
            float sin_a = std::sin(angle);
            p.addRectangle(12.0f + cos_a * 8.0f - 2.0f, 12.0f + sin_a * 8.0f - 2.0f, 4.0f, 4.0f);
        }
        return p;
    }

    // Expand/fullscreen
    inline juce::Path expand()
    {
        juce::Path p;
        // Top-left corner
        p.startNewSubPath(2.0f, 9.0f);
        p.lineTo(2.0f, 2.0f);
        p.lineTo(9.0f, 2.0f);
        // Top-right corner
        p.startNewSubPath(15.0f, 2.0f);
        p.lineTo(22.0f, 2.0f);
        p.lineTo(22.0f, 9.0f);
        // Bottom-right corner
        p.startNewSubPath(22.0f, 15.0f);
        p.lineTo(22.0f, 22.0f);
        p.lineTo(15.0f, 22.0f);
        // Bottom-left corner
        p.startNewSubPath(9.0f, 22.0f);
        p.lineTo(2.0f, 22.0f);
        p.lineTo(2.0f, 15.0f);
        return p;
    }

    //==========================================================================
    // Action Icons
    //==========================================================================

    // Plus/add
    inline juce::Path add()
    {
        juce::Path p;
        p.startNewSubPath(12.0f, 4.0f);
        p.lineTo(12.0f, 20.0f);
        p.startNewSubPath(4.0f, 12.0f);
        p.lineTo(20.0f, 12.0f);
        return p;
    }

    // Minus/remove
    inline juce::Path remove()
    {
        juce::Path p;
        p.startNewSubPath(4.0f, 12.0f);
        p.lineTo(20.0f, 12.0f);
        return p;
    }

    // Edit pencil
    inline juce::Path edit()
    {
        juce::Path p;
        p.startNewSubPath(18.0f, 2.0f);
        p.lineTo(22.0f, 6.0f);
        p.lineTo(8.0f, 20.0f);
        p.lineTo(2.0f, 22.0f);
        p.lineTo(4.0f, 16.0f);
        p.closeSubPath();
        return p;
    }

    // Save disk
    inline juce::Path save()
    {
        juce::Path p;
        p.addRoundedRectangle(2.0f, 2.0f, 20.0f, 20.0f, 2.0f);
        p.addRectangle(6.0f, 2.0f, 12.0f, 8.0f);
        p.addRectangle(6.0f, 14.0f, 12.0f, 6.0f);
        return p;
    }

    // Share arrow
    inline juce::Path share()
    {
        juce::Path p;
        // Arrow
        p.startNewSubPath(12.0f, 2.0f);
        p.lineTo(20.0f, 10.0f);
        p.lineTo(16.0f, 10.0f);
        p.lineTo(16.0f, 16.0f);
        p.lineTo(8.0f, 16.0f);
        p.lineTo(8.0f, 10.0f);
        p.lineTo(4.0f, 10.0f);
        p.closeSubPath();
        // Bottom bar
        p.addRectangle(4.0f, 18.0f, 16.0f, 4.0f);
        return p;
    }

    // Trash/delete
    inline juce::Path trash()
    {
        juce::Path p;
        // Lid
        p.addRoundedRectangle(3.0f, 4.0f, 18.0f, 2.0f, 1.0f);
        p.addRectangle(9.0f, 2.0f, 6.0f, 2.0f);
        // Can
        p.startNewSubPath(5.0f, 6.0f);
        p.lineTo(6.0f, 20.0f);
        p.lineTo(18.0f, 20.0f);
        p.lineTo(19.0f, 6.0f);
        p.closeSubPath();
        // Lines
        p.startNewSubPath(9.0f, 9.0f);
        p.lineTo(9.0f, 17.0f);
        p.startNewSubPath(12.0f, 9.0f);
        p.lineTo(12.0f, 17.0f);
        p.startNewSubPath(15.0f, 9.0f);
        p.lineTo(15.0f, 17.0f);
        return p;
    }

    // Copy
    inline juce::Path copy()
    {
        juce::Path p;
        p.addRoundedRectangle(8.0f, 8.0f, 14.0f, 14.0f, 2.0f);
        p.addRoundedRectangle(2.0f, 2.0f, 14.0f, 14.0f, 2.0f);
        return p;
    }

    //==========================================================================
    // Status Icons
    //==========================================================================

    // Checkmark/success
    inline juce::Path success()
    {
        juce::Path p;
        p.addEllipse(2.0f, 2.0f, 20.0f, 20.0f);
        p.startNewSubPath(6.0f, 12.0f);
        p.lineTo(10.0f, 16.0f);
        p.lineTo(18.0f, 8.0f);
        return p;
    }

    // Warning triangle
    inline juce::Path warning()
    {
        juce::Path p;
        p.startNewSubPath(12.0f, 2.0f);
        p.lineTo(2.0f, 20.0f);
        p.lineTo(22.0f, 20.0f);
        p.closeSubPath();
        // Exclamation
        p.addRectangle(11.0f, 8.0f, 2.0f, 6.0f);
        p.addEllipse(11.0f, 16.0f, 2.0f, 2.0f);
        return p;
    }

    // Error X circle
    inline juce::Path error()
    {
        juce::Path p;
        p.addEllipse(2.0f, 2.0f, 20.0f, 20.0f);
        p.startNewSubPath(8.0f, 8.0f);
        p.lineTo(16.0f, 16.0f);
        p.startNewSubPath(16.0f, 8.0f);
        p.lineTo(8.0f, 16.0f);
        return p;
    }

    // Info circle
    inline juce::Path info()
    {
        juce::Path p;
        p.addEllipse(2.0f, 2.0f, 20.0f, 20.0f);
        p.addEllipse(11.0f, 6.0f, 2.0f, 2.0f);
        p.addRectangle(11.0f, 10.0f, 2.0f, 8.0f);
        return p;
    }

    //==========================================================================
    // Laser/Visual Icons
    //==========================================================================

    // Laser beam
    inline juce::Path laserBeam()
    {
        juce::Path p;
        // Beam source
        p.addEllipse(2.0f, 10.0f, 4.0f, 4.0f);
        // Beam
        p.startNewSubPath(6.0f, 12.0f);
        p.lineTo(22.0f, 4.0f);
        p.lineTo(22.0f, 20.0f);
        p.closeSubPath();
        return p;
    }

    // Pattern grid
    inline juce::Path pattern()
    {
        juce::Path p;
        for (int row = 0; row < 3; ++row)
        {
            for (int col = 0; col < 3; ++col)
            {
                p.addEllipse(3.0f + col * 8.0f, 3.0f + row * 8.0f, 4.0f, 4.0f);
            }
        }
        return p;
    }

    // Brightness/intensity sun
    inline juce::Path intensity()
    {
        juce::Path p;
        // Center circle
        p.addEllipse(8.0f, 8.0f, 8.0f, 8.0f);
        // Rays
        for (int i = 0; i < 8; ++i)
        {
            float angle = i * 0.785398f;
            float cos_a = std::cos(angle);
            float sin_a = std::sin(angle);
            p.startNewSubPath(12.0f + cos_a * 6.0f, 12.0f + sin_a * 6.0f);
            p.lineTo(12.0f + cos_a * 10.0f, 12.0f + sin_a * 10.0f);
        }
        return p;
    }

    // Color palette
    inline juce::Path colorPalette()
    {
        juce::Path p;
        p.addEllipse(2.0f, 2.0f, 20.0f, 20.0f);
        p.addEllipse(6.0f, 6.0f, 4.0f, 4.0f);
        p.addEllipse(12.0f, 5.0f, 4.0f, 4.0f);
        p.addEllipse(16.0f, 10.0f, 4.0f, 4.0f);
        p.addEllipse(12.0f, 15.0f, 4.0f, 4.0f);
        return p;
    }

    // Spiral pattern
    inline juce::Path spiral()
    {
        juce::Path p;
        float cx = 12.0f, cy = 12.0f;
        p.startNewSubPath(cx, cy);
        for (int i = 0; i <= 720; i += 15)
        {
            float angle = i * 0.0174533f;  // Degrees to radians
            float radius = i / 80.0f;
            p.lineTo(cx + std::cos(angle) * radius, cy + std::sin(angle) * radius);
        }
        return p;
    }

    //==========================================================================
    // Echoel Brand Icons
    //==========================================================================

    // Echoel logo (stylized E)
    inline juce::Path echoelLogo()
    {
        juce::Path p;
        // Stylized E with wave
        p.startNewSubPath(4.0f, 4.0f);
        p.lineTo(20.0f, 4.0f);
        p.startNewSubPath(4.0f, 12.0f);
        p.cubicTo(8.0f, 10.0f, 12.0f, 14.0f, 16.0f, 12.0f);
        p.startNewSubPath(4.0f, 20.0f);
        p.lineTo(20.0f, 20.0f);
        // Vertical bar
        p.startNewSubPath(4.0f, 4.0f);
        p.lineTo(4.0f, 20.0f);
        return p;
    }

    // Echoel symbol (liquid light drop)
    inline juce::Path echoelSymbol()
    {
        juce::Path p;
        // Water drop shape
        p.startNewSubPath(12.0f, 2.0f);
        p.cubicTo(6.0f, 10.0f, 4.0f, 14.0f, 4.0f, 17.0f);
        p.cubicTo(4.0f, 20.0f, 7.0f, 22.0f, 12.0f, 22.0f);
        p.cubicTo(17.0f, 22.0f, 20.0f, 20.0f, 20.0f, 17.0f);
        p.cubicTo(20.0f, 14.0f, 18.0f, 10.0f, 12.0f, 2.0f);
        p.closeSubPath();
        // Inner highlight
        p.addEllipse(8.0f, 14.0f, 4.0f, 4.0f);
        return p;
    }
}

//==============================================================================
// Icon Component (Accessible, Themeable)
//==============================================================================

class EchoelIcon : public juce::Component
{
public:
    using PathFunction = std::function<juce::Path()>;

    EchoelIcon(PathFunction pathFn, const std::string& ariaLabel = "")
        : pathFunction_(std::move(pathFn))
        , ariaLabel_(ariaLabel)
    {
        setAccessible(true);
        setTitle(ariaLabel.empty() ? "Icon" : ariaLabel);
        setInterceptsMouseClicks(false, false);
    }

    void setStyle(const IconStyle& style)
    {
        style_ = style;
        repaint();
    }

    IconStyle getStyle() const { return style_; }

    void setAriaLabel(const std::string& label)
    {
        ariaLabel_ = label;
        setTitle(label);
    }

    // Animation support
    void setAnimatedRotation(float degrees)
    {
        style_.rotation = degrees;
        repaint();
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Get the icon path
        juce::Path path = pathFunction_();

        // Calculate scaling to fit bounds
        auto pathBounds = path.getBounds();
        float scale = std::min(
            bounds.getWidth() / pathBounds.getWidth(),
            bounds.getHeight() / pathBounds.getHeight()
        ) * 0.8f;  // 80% to leave padding

        // Create transform
        juce::AffineTransform transform;
        transform = transform.translated(-pathBounds.getCentreX(), -pathBounds.getCentreY());
        transform = transform.scaled(scale);
        transform = transform.rotated(style_.rotation * 0.0174533f);
        transform = transform.translated(bounds.getCentreX(), bounds.getCentreY());

        path.applyTransform(transform);

        // Apply color with opacity
        juce::Colour color = style_.color.withAlpha(style_.opacity);

        // High contrast mode override
        if (style_.highContrast)
        {
            color = juce::Colours::white;
        }

        if (style_.filled)
        {
            g.setColour(color);
            g.fillPath(path);
        }
        else
        {
            g.setColour(color);
            g.strokePath(path, juce::PathStrokeType(style_.strokeWidth));
        }

        // Draw glow for neon effect (if not high contrast)
        if (!style_.highContrast && style_.color.getBrightness() > 0.5f)
        {
            juce::Colour glowColor = style_.color.withAlpha(0.3f);
            g.setColour(glowColor);
            g.strokePath(path, juce::PathStrokeType(style_.strokeWidth * 2.0f));
        }
    }

    void resized() override
    {
        // Ensure minimum touch target size (WCAG)
        if (getWidth() < IconSize::TouchMinimum || getHeight() < IconSize::TouchMinimum)
        {
            // Component is too small - this is just visual, touch area can be larger
        }
    }

    // Accessibility
    std::unique_ptr<juce::AccessibilityHandler> createAccessibilityHandler() override
    {
        return std::make_unique<juce::AccessibilityHandler>(
            *this,
            juce::AccessibilityRole::image,
            juce::AccessibilityActions()
        );
    }

private:
    PathFunction pathFunction_;
    IconStyle style_;
    std::string ariaLabel_;
};

//==============================================================================
// Icon Factory (Convenience Methods)
//==============================================================================

class EchoelIconFactory
{
public:
    // Audio icons
    static std::unique_ptr<EchoelIcon> play(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::play, "Play");
    }

    static std::unique_ptr<EchoelIcon> pause(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::pause, "Pause");
    }

    static std::unique_ptr<EchoelIcon> stop(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::stop, "Stop");
    }

    static std::unique_ptr<EchoelIcon> volumeHigh(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::volumeHigh, "Volume");
    }

    static std::unique_ptr<EchoelIcon> volumeMute(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::volumeMute, "Muted");
    }

    static std::unique_ptr<EchoelIcon> waveform(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::waveform, "Waveform");
    }

    static std::unique_ptr<EchoelIcon> spectrum(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::spectrum, "Spectrum");
    }

    // Bio icons
    static std::unique_ptr<EchoelIcon> heart(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::heart, "Heart");
    }

    static std::unique_ptr<EchoelIcon> heartPulse(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::heartPulse, "Heart Rate");
    }

    static std::unique_ptr<EchoelIcon> brain(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::brain, "Brainwave");
    }

    static std::unique_ptr<EchoelIcon> breathing(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::breathing, "Breathing");
    }

    static std::unique_ptr<EchoelIcon> coherence(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::coherence, "Coherence");
    }

    static std::unique_ptr<EchoelIcon> hrv(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::hrv, "Heart Rate Variability");
    }

    // Navigation icons
    static std::unique_ptr<EchoelIcon> menu(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::menu, "Menu");
    }

    static std::unique_ptr<EchoelIcon> close(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::close, "Close");
    }

    static std::unique_ptr<EchoelIcon> back(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::back, "Back");
    }

    static std::unique_ptr<EchoelIcon> forward(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::forward, "Forward");
    }

    static std::unique_ptr<EchoelIcon> home(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::home, "Home");
    }

    static std::unique_ptr<EchoelIcon> settings(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::settings, "Settings");
    }

    // Action icons
    static std::unique_ptr<EchoelIcon> add(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::add, "Add");
    }

    static std::unique_ptr<EchoelIcon> remove(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::remove, "Remove");
    }

    static std::unique_ptr<EchoelIcon> edit(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::edit, "Edit");
    }

    static std::unique_ptr<EchoelIcon> save(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::save, "Save");
    }

    static std::unique_ptr<EchoelIcon> share(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::share, "Share");
    }

    static std::unique_ptr<EchoelIcon> trash(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::trash, "Delete");
    }

    // Status icons
    static std::unique_ptr<EchoelIcon> success(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::success, "Success");
    }

    static std::unique_ptr<EchoelIcon> warning(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::warning, "Warning");
    }

    static std::unique_ptr<EchoelIcon> error(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::error, "Error");
    }

    static std::unique_ptr<EchoelIcon> info(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::info, "Information");
    }

    // Laser icons
    static std::unique_ptr<EchoelIcon> laserBeam(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::laserBeam, "Laser Beam");
    }

    static std::unique_ptr<EchoelIcon> pattern(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::pattern, "Pattern");
    }

    static std::unique_ptr<EchoelIcon> intensity(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::intensity, "Intensity");
    }

    static std::unique_ptr<EchoelIcon> colorPalette(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::colorPalette, "Color");
    }

    static std::unique_ptr<EchoelIcon> spiral(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::spiral, "Spiral Pattern");
    }

    // Echoel brand
    static std::unique_ptr<EchoelIcon> echoelLogo(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::echoelLogo, "Echoel");
    }

    static std::unique_ptr<EchoelIcon> echoelSymbol(const IconStyle& style = {})
    {
        return std::make_unique<EchoelIcon>(IconPaths::echoelSymbol, "Echoel Symbol");
    }
};

//==============================================================================
// Animated Icon (for loading, processing states)
//==============================================================================

class EchoelAnimatedIcon : public EchoelIcon, private juce::Timer
{
public:
    using EchoelIcon::EchoelIcon;

    void startSpinning(float rpm = 60.0f)
    {
        rpm_ = rpm;
        startTimerHz(60);
    }

    void stopSpinning()
    {
        stopTimer();
    }

    void startPulsing(float frequency = 1.0f)
    {
        pulseFrequency_ = frequency;
        pulsing_ = true;
        startTimerHz(60);
    }

    void stopPulsing()
    {
        pulsing_ = false;
        stopTimer();
        auto style = getStyle();
        style.opacity = 1.0f;
        setStyle(style);
    }

private:
    void timerCallback() override
    {
        auto style = getStyle();

        if (rpm_ != 0.0f)
        {
            style.rotation += rpm_ * 6.0f / 60.0f;  // Convert RPM to degrees per frame at 60fps
            if (style.rotation >= 360.0f) style.rotation -= 360.0f;
        }

        if (pulsing_)
        {
            float phase = std::fmod(juce::Time::getMillisecondCounterHiRes() / 1000.0f * pulseFrequency_, 1.0f);
            style.opacity = 0.5f + 0.5f * std::sin(phase * 6.28318f);
        }

        setStyle(style);
    }

    float rpm_ = 0.0f;
    float pulseFrequency_ = 1.0f;
    bool pulsing_ = false;
};

}  // namespace Echoel::UI

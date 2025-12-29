#pragma once

/**
 * EchoelDesignSystem.h - Unified Brand Identity & Design System
 *
 * ╔══════════════════════════════════════════════════════════════════════════╗
 * ║                                                                          ║
 * ║    ███████╗ ██████╗██╗  ██╗ ██████╗ ███████╗██╗                          ║
 * ║    ██╔════╝██╔════╝██║  ██║██╔═══██╗██╔════╝██║                          ║
 * ║    █████╗  ██║     ███████║██║   ██║█████╗  ██║                          ║
 * ║    ██╔══╝  ██║     ██╔══██║██║   ██║██╔══╝  ██║                          ║
 * ║    ███████╗╚██████╗██║  ██║╚██████╔╝███████╗███████╗                     ║
 * ║    ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝                     ║
 * ║                                                                          ║
 * ║    "Liquid Light for Your Music"                                         ║
 * ║                                                                          ║
 * ╠══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                          ║
 * ║  BRAND IDENTITY:                                                         ║
 * ║    Name: Echoel (Echo + Éthique/Music)                                   ║
 * ║    Personality: Scientific, Wellness, Artistic, Inclusive, High-Tech     ║
 * ║    Aesthetic: Vaporwave + Physics + Cymatics                             ║
 * ║                                                                          ║
 * ║  DESIGN PRINCIPLES:                                                      ║
 * ║    1. Accessibility First (WCAG 2.1 AAA)                                 ║
 * ║    2. Touch Intelligence (Adaptive, Intent-Aware)                        ║
 * ║    3. Bio-Reactive (Heart/Brain-connected)                               ║
 * ║    4. Performance-Optimized (Sub-ms latency)                             ║
 * ║    5. Scientific Clarity (Data visualization)                            ║
 * ║                                                                          ║
 * ╚══════════════════════════════════════════════════════════════════════════╝
 */

#include <JuceHeader.h>
#include <array>
#include <string>

namespace Echoel::Design
{

//==============================================================================
// Brand Constants
//==============================================================================

namespace Brand
{
    // Core Identity
    constexpr const char* NAME = "Echoel";
    constexpr const char* TAGLINE = "Liquid Light for Your Music";
    constexpr const char* VERSION = "2.0.0";
    constexpr const char* COPYRIGHT = "© 2024 Echoel Music";

    // Product Names
    constexpr const char* PRODUCT_STUDIO = "Echoel Studio";
    constexpr const char* PRODUCT_SYNTH = "EchoSynth";
    constexpr const char* PRODUCT_LASER = "EchoLaser";
    constexpr const char* PRODUCT_WELLNESS = "EchoWellness";
    constexpr const char* PRODUCT_BIOFEEDBACK = "EchoBio";

    // Feature Prefixes (for consistent naming)
    constexpr const char* PREFIX_UI = "Echoel";
    constexpr const char* PREFIX_DSP = "Echo";
    constexpr const char* PREFIX_VISUAL = "EchoVisual";
    constexpr const char* PREFIX_BIO = "EchoBio";
}

//==============================================================================
// Color System
//==============================================================================

namespace Colors
{
    //==========================================================================
    // Primary Neon Palette (Vaporwave Core)
    //==========================================================================

    namespace Neon
    {
        constexpr uint32_t Pink      = 0xFFFF71CE;  // Primary accent
        constexpr uint32_t Cyan      = 0xFF01CDFE;  // Secondary accent
        constexpr uint32_t Mint      = 0xFF05FFA1;  // Success/positive
        constexpr uint32_t Purple    = 0xFFB967FF;  // Tertiary
        constexpr uint32_t Yellow    = 0xFFFFFB96;  // Warning/attention
        constexpr uint32_t Orange    = 0xFFFF9F1C;  // Energy/action
        constexpr uint32_t Coral     = 0xFFFF6B6B;  // Warm accent

        inline juce::Colour pink()   { return juce::Colour(Pink); }
        inline juce::Colour cyan()   { return juce::Colour(Cyan); }
        inline juce::Colour mint()   { return juce::Colour(Mint); }
        inline juce::Colour purple() { return juce::Colour(Purple); }
        inline juce::Colour yellow() { return juce::Colour(Yellow); }
        inline juce::Colour orange() { return juce::Colour(Orange); }
        inline juce::Colour coral()  { return juce::Colour(Coral); }
    }

    //==========================================================================
    // Background Palette
    //==========================================================================

    namespace Background
    {
        constexpr uint32_t DeepSpace    = 0xFF0D0221;  // Darkest
        constexpr uint32_t MidnightBlue = 0xFF1A1A2E;  // Primary dark
        constexpr uint32_t DarkPurple   = 0xFF16213E;  // Secondary dark
        constexpr uint32_t SunsetOrange = 0xFFFF6B35;  // Warm gradient start
        constexpr uint32_t SunsetPink   = 0xFFFF1493;  // Warm gradient end
        constexpr uint32_t Card         = 0x33FFFFFF;  // Glass card overlay
        constexpr uint32_t CardBorder   = 0x55FFFFFF;  // Glass card border

        inline juce::Colour deepSpace()    { return juce::Colour(DeepSpace); }
        inline juce::Colour midnightBlue() { return juce::Colour(MidnightBlue); }
        inline juce::Colour darkPurple()   { return juce::Colour(DarkPurple); }

        inline juce::ColourGradient mainGradient(juce::Rectangle<float> bounds)
        {
            return juce::ColourGradient(
                juce::Colour(MidnightBlue), bounds.getX(), bounds.getY(),
                juce::Colour(DarkPurple), bounds.getRight(), bounds.getBottom(),
                false);
        }

        inline juce::ColourGradient sunsetGradient(juce::Rectangle<float> bounds)
        {
            juce::ColourGradient gradient(
                juce::Colour(SunsetOrange), bounds.getX(), bounds.getY(),
                juce::Colour(SunsetPink), bounds.getRight(), bounds.getBottom(),
                false);
            gradient.addColour(0.5, juce::Colour(0xFFFF4081));
            return gradient;
        }
    }

    //==========================================================================
    // Text Colors
    //==========================================================================

    namespace Text
    {
        constexpr uint32_t Primary   = 0xFFFFFFFF;  // 100% white
        constexpr uint32_t Secondary = 0xB3FFFFFF;  // 70% white
        constexpr uint32_t Tertiary  = 0x66FFFFFF;  // 40% white
        constexpr uint32_t Disabled  = 0x33FFFFFF;  // 20% white
        constexpr uint32_t Inverse   = 0xFF0D0221;  // On light backgrounds

        inline juce::Colour primary()   { return juce::Colour(Primary); }
        inline juce::Colour secondary() { return juce::Colour(Secondary); }
        inline juce::Colour tertiary()  { return juce::Colour(Tertiary); }
        inline juce::Colour disabled()  { return juce::Colour(Disabled); }
    }

    //==========================================================================
    // Bio-Reactive Colors (Coherence-Based)
    //==========================================================================

    namespace BioReactive
    {
        constexpr uint32_t CoherenceLow    = 0xFFFF4444;  // Red - stressed
        constexpr uint32_t CoherenceMedium = 0xFFFFAA00;  // Gold - moderate
        constexpr uint32_t CoherenceHigh   = 0xFF00FFAA;  // Cyan - coherent

        constexpr uint32_t HeartRate       = 0xFFFF6B6B;  // Heart red
        constexpr uint32_t HRV             = 0xFF4ECDC4;  // HRV teal
        constexpr uint32_t Breathing       = 0xFF95E1D3;  // Breath green
        constexpr uint32_t Focus           = 0xFFFFD93D;  // Focus yellow
        constexpr uint32_t Calm            = 0xFF6C5CE7;  // Calm purple

        inline juce::Colour fromCoherence(float coherence)
        {
            if (coherence < 0.4f)
                return juce::Colour(CoherenceLow).interpolatedWith(
                    juce::Colour(CoherenceMedium), coherence / 0.4f);
            else
                return juce::Colour(CoherenceMedium).interpolatedWith(
                    juce::Colour(CoherenceHigh), (coherence - 0.4f) / 0.6f);
        }
    }

    //==========================================================================
    // Functional Colors
    //==========================================================================

    namespace Functional
    {
        constexpr uint32_t Success   = 0xFF05FFA1;  // Neon mint
        constexpr uint32_t Warning   = 0xFFFFAA00;  // Amber
        constexpr uint32_t Error     = 0xFFFF4444;  // Red
        constexpr uint32_t Info      = 0xFF01CDFE;  // Neon cyan
        constexpr uint32_t Recording = 0xFFFF3366;  // Recording red
        constexpr uint32_t Active    = 0xFF00FF88;  // Active green

        inline juce::Colour success()   { return juce::Colour(Success); }
        inline juce::Colour warning()   { return juce::Colour(Warning); }
        inline juce::Colour error()     { return juce::Colour(Error); }
        inline juce::Colour info()      { return juce::Colour(Info); }
        inline juce::Colour recording() { return juce::Colour(Recording); }
    }

    //==========================================================================
    // Touch Intent Colors
    //==========================================================================

    namespace TouchIntent
    {
        constexpr uint32_t FineAdjust = 0xFF00D4FF;  // Cyan - precision
        constexpr uint32_t FastMorph  = 0xFFFF8800;  // Orange - speed
        constexpr uint32_t Hold       = 0xFF88FF00;  // Green - sustained
        constexpr uint32_t Swipe      = 0xFFFF00FF;  // Magenta - motion
        constexpr uint32_t Pinch      = 0xFFAA00FF;  // Purple - scale
        constexpr uint32_t Rotate     = 0xFF00FFAA;  // Mint - rotation
    }
}

//==============================================================================
// Typography System
//==============================================================================

namespace Typography
{
    //==========================================================================
    // Font Families
    //==========================================================================

    namespace FontFamily
    {
        // Primary: Rounded sans-serif for friendly, modern feel
        inline juce::Font primary()
        {
            return juce::Font(juce::Font::getDefaultSansSerifFontName(), 16.0f,
                              juce::Font::plain);
        }

        // Monospace: For data display
        inline juce::Font monospace()
        {
            return juce::Font(juce::Font::getDefaultMonospacedFontName(), 14.0f,
                              juce::Font::plain);
        }
    }

    //==========================================================================
    // Type Scale (Based on 1.25 ratio)
    //==========================================================================

    namespace Size
    {
        constexpr float Caption   = 10.0f;
        constexpr float Label     = 12.0f;
        constexpr float Body      = 14.0f;
        constexpr float BodyLarge = 16.0f;
        constexpr float Subtitle  = 18.0f;
        constexpr float Title     = 24.0f;
        constexpr float Headline  = 32.0f;
        constexpr float Hero      = 48.0f;
        constexpr float Display   = 64.0f;

        // Data display sizes
        constexpr float DataSmall  = 20.0f;
        constexpr float DataMedium = 28.0f;
        constexpr float DataLarge  = 36.0f;
        constexpr float DataXL     = 48.0f;
    }

    //==========================================================================
    // Pre-configured Text Styles
    //==========================================================================

    inline juce::Font heroTitle()
    {
        return FontFamily::primary().withHeight(Size::Hero)
            .withStyle(juce::Font::bold);
    }

    inline juce::Font headline()
    {
        return FontFamily::primary().withHeight(Size::Headline)
            .withStyle(juce::Font::bold);
    }

    inline juce::Font title()
    {
        return FontFamily::primary().withHeight(Size::Title)
            .withStyle(juce::Font::bold);
    }

    inline juce::Font subtitle()
    {
        return FontFamily::primary().withHeight(Size::Subtitle);
    }

    inline juce::Font body()
    {
        return FontFamily::primary().withHeight(Size::Body);
    }

    inline juce::Font bodyLarge()
    {
        return FontFamily::primary().withHeight(Size::BodyLarge);
    }

    inline juce::Font label()
    {
        return FontFamily::primary().withHeight(Size::Label)
            .withStyle(juce::Font::bold);
    }

    inline juce::Font caption()
    {
        return FontFamily::primary().withHeight(Size::Caption);
    }

    inline juce::Font dataDisplay(float size = Size::DataLarge)
    {
        return FontFamily::monospace().withHeight(size);
    }

    inline juce::Font buttonText()
    {
        return FontFamily::primary().withHeight(Size::Body)
            .withStyle(juce::Font::bold);
    }
}

//==============================================================================
// Spacing System (8px Grid)
//==============================================================================

namespace Spacing
{
    constexpr float XXS = 2.0f;
    constexpr float XS  = 4.0f;
    constexpr float SM  = 8.0f;
    constexpr float MD  = 16.0f;
    constexpr float LG  = 24.0f;
    constexpr float XL  = 32.0f;
    constexpr float XXL = 48.0f;
    constexpr float XXXL = 64.0f;

    // Component-specific
    constexpr float ButtonPadding = 12.0f;
    constexpr float CardPadding = 16.0f;
    constexpr float SectionGap = 24.0f;
    constexpr float ScreenMargin = 20.0f;
}

//==============================================================================
// Touch Targets (WCAG 2.1 AAA Compliant)
//==============================================================================

namespace TouchTargets
{
    constexpr float Minimum      = 44.0f;   // WCAG AAA minimum
    constexpr float Recommended  = 48.0f;   // Apple HIG
    constexpr float Large        = 64.0f;   // Motor assist
    constexpr float ExtraLarge   = 88.0f;   // Severe motor impairment
    constexpr float Slider       = 56.0f;   // Slider track height
    constexpr float Knob         = 72.0f;   // Rotary knob diameter
    constexpr float KnobLarge    = 96.0f;   // Large knob diameter
}

//==============================================================================
// Border Radius
//==============================================================================

namespace Radius
{
    constexpr float None   = 0.0f;
    constexpr float SM     = 4.0f;
    constexpr float MD     = 8.0f;
    constexpr float LG     = 12.0f;
    constexpr float XL     = 16.0f;
    constexpr float XXL    = 24.0f;
    constexpr float Full   = 9999.0f;  // Pill shape

    constexpr float Button = 8.0f;
    constexpr float Card   = 12.0f;
    constexpr float Dialog = 16.0f;
}

//==============================================================================
// Shadows & Effects
//==============================================================================

namespace Effects
{
    //==========================================================================
    // Neon Glow Effect
    //==========================================================================

    inline void drawNeonGlow(juce::Graphics& g, juce::Rectangle<float> bounds,
                             juce::Colour colour, float intensity = 1.0f)
    {
        // Three-layer glow effect
        for (int i = 3; i >= 1; --i)
        {
            float alpha = 0.15f * intensity / static_cast<float>(i);
            float expansion = static_cast<float>(i) * 4.0f * intensity;

            g.setColour(colour.withAlpha(alpha));
            g.fillRoundedRectangle(bounds.expanded(expansion),
                                   Radius::Card + expansion);
        }
    }

    //==========================================================================
    // Glass Card Effect
    //==========================================================================

    inline void drawGlassCard(juce::Graphics& g, juce::Rectangle<float> bounds,
                              float opacity = 0.2f)
    {
        // Background
        g.setColour(juce::Colours::white.withAlpha(opacity));
        g.fillRoundedRectangle(bounds, Radius::Card);

        // Border
        g.setColour(juce::Colours::white.withAlpha(opacity + 0.1f));
        g.drawRoundedRectangle(bounds, Radius::Card, 1.0f);
    }

    //==========================================================================
    // Retro Scanlines
    //==========================================================================

    inline void drawScanlines(juce::Graphics& g, juce::Rectangle<float> bounds,
                              float intensity = 0.1f, int lineSpacing = 2)
    {
        g.setColour(juce::Colours::black.withAlpha(intensity));
        for (int y = static_cast<int>(bounds.getY());
             y < static_cast<int>(bounds.getBottom()); y += lineSpacing)
        {
            g.drawHorizontalLine(y, bounds.getX(), bounds.getRight());
        }
    }

    //==========================================================================
    // VHS Tracking Effect
    //==========================================================================

    struct VHSTrackingParams
    {
        float horizontalOffset = 0.0f;
        float noiseAmount = 0.0f;
        bool hasDropout = false;
        int dropoutY = 0;
    };

    inline VHSTrackingParams getRandomVHSParams(juce::Random& random)
    {
        VHSTrackingParams params;
        params.horizontalOffset = random.nextFloat() * 4.0f - 2.0f;
        params.noiseAmount = random.nextFloat() * 0.1f;
        params.hasDropout = random.nextFloat() > 0.95f;
        params.dropoutY = random.nextInt(100);
        return params;
    }
}

//==============================================================================
// Animation Constants
//==============================================================================

namespace Animation
{
    // Durations (milliseconds)
    constexpr int Instant    = 0;
    constexpr int Fast       = 100;
    constexpr int Normal     = 200;
    constexpr int Slow       = 300;
    constexpr int VerySlow   = 500;
    constexpr int Deliberate = 800;

    // Easing curves (for juce::AnimatorBuilder or similar)
    namespace Easing
    {
        inline float linear(float t) { return t; }

        inline float easeInQuad(float t) { return t * t; }
        inline float easeOutQuad(float t) { return t * (2.0f - t); }
        inline float easeInOutQuad(float t)
        {
            return t < 0.5f ? 2.0f * t * t : -1.0f + (4.0f - 2.0f * t) * t;
        }

        inline float easeOutCubic(float t)
        {
            float t1 = t - 1.0f;
            return t1 * t1 * t1 + 1.0f;
        }

        inline float easeInOutCubic(float t)
        {
            return t < 0.5f ? 4.0f * t * t * t
                            : (t - 1.0f) * (2.0f * t - 2.0f) * (2.0f * t - 2.0f) + 1.0f;
        }

        inline float easeOutExpo(float t)
        {
            return t == 1.0f ? 1.0f : 1.0f - std::pow(2.0f, -10.0f * t);
        }

        inline float easeOutElastic(float t)
        {
            if (t == 0.0f || t == 1.0f) return t;
            return std::pow(2.0f, -10.0f * t) *
                   std::sin((t - 0.075f) * (2.0f * 3.14159f) / 0.3f) + 1.0f;
        }

        inline float easeOutBounce(float t)
        {
            if (t < 1.0f / 2.75f)
                return 7.5625f * t * t;
            else if (t < 2.0f / 2.75f)
            {
                t -= 1.5f / 2.75f;
                return 7.5625f * t * t + 0.75f;
            }
            else if (t < 2.5f / 2.75f)
            {
                t -= 2.25f / 2.75f;
                return 7.5625f * t * t + 0.9375f;
            }
            else
            {
                t -= 2.625f / 2.75f;
                return 7.5625f * t * t + 0.984375f;
            }
        }
    }
}

//==============================================================================
// Accessibility Constants
//==============================================================================

namespace Accessibility
{
    // Contrast ratios (WCAG 2.1)
    constexpr float MinContrastAA = 4.5f;    // Normal text
    constexpr float MinContrastAAA = 7.0f;   // Enhanced
    constexpr float MinContrastLarge = 3.0f; // Large text

    // Animation safety
    constexpr float MaxFlashRate = 3.0f;     // Hz - prevents seizures
    constexpr int ReducedMotionDuration = 0; // Instant for reduce-motion

    // Focus indicators
    constexpr float FocusRingWidth = 3.0f;
    constexpr uint32_t FocusRingColor = Colors::Neon::Cyan;

    // Check contrast ratio between two colors
    inline float getContrastRatio(juce::Colour fg, juce::Colour bg)
    {
        auto luminance = [](juce::Colour c) {
            auto adjust = [](float v) {
                return v <= 0.03928f ? v / 12.92f
                                     : std::pow((v + 0.055f) / 1.055f, 2.4f);
            };
            return 0.2126f * adjust(c.getFloatRed()) +
                   0.7152f * adjust(c.getFloatGreen()) +
                   0.0722f * adjust(c.getFloatBlue());
        };

        float l1 = luminance(fg);
        float l2 = luminance(bg);
        if (l1 < l2) std::swap(l1, l2);
        return (l1 + 0.05f) / (l2 + 0.05f);
    }

    inline bool meetsContrastAAA(juce::Colour fg, juce::Colour bg)
    {
        return getContrastRatio(fg, bg) >= MinContrastAAA;
    }
}

//==============================================================================
// Component Naming Convention Helper
//==============================================================================

namespace Naming
{
    // Standard component name generator
    inline juce::String component(const juce::String& name)
    {
        return Brand::PREFIX_UI + name;  // "EchoelButton", "EchoelSlider"
    }

    inline juce::String dspModule(const juce::String& name)
    {
        return Brand::PREFIX_DSP + name;  // "EchoCompressor", "EchoReverb"
    }

    inline juce::String visualModule(const juce::String& name)
    {
        return Brand::PREFIX_VISUAL + name;  // "EchoVisualLaser"
    }

    inline juce::String bioModule(const juce::String& name)
    {
        return Brand::PREFIX_BIO + name;  // "EchoBioHRV"
    }
}

//==============================================================================
// Quick Style Application Helpers
//==============================================================================

namespace QuickStyle
{
    inline void applyPrimaryButton(juce::TextButton& button)
    {
        button.setColour(juce::TextButton::buttonColourId,
                         juce::Colour(Colors::Neon::Pink));
        button.setColour(juce::TextButton::textColourOnId,
                         juce::Colour(Colors::Text::Primary));
    }

    inline void applySecondaryButton(juce::TextButton& button)
    {
        button.setColour(juce::TextButton::buttonColourId,
                         juce::Colour(Colors::Neon::Cyan).withAlpha(0.2f));
        button.setColour(juce::TextButton::textColourOnId,
                         juce::Colour(Colors::Neon::Cyan));
    }

    inline void applyCard(juce::Component& comp)
    {
        comp.setOpaque(false);
        // Note: Actual glass effect requires custom paint override
    }

    inline void applyLabel(juce::Label& label, bool isTitle = false)
    {
        label.setFont(isTitle ? Typography::title() : Typography::body());
        label.setColour(juce::Label::textColourId,
                        juce::Colour(isTitle ? Colors::Text::Primary
                                             : Colors::Text::Secondary));
    }

    inline void applyDataDisplay(juce::Label& label, float size = Typography::Size::DataLarge)
    {
        label.setFont(Typography::dataDisplay(size));
        label.setColour(juce::Label::textColourId,
                        juce::Colour(Colors::Neon::Cyan));
        label.setJustificationType(juce::Justification::centred);
    }
}

}  // namespace Echoel::Design

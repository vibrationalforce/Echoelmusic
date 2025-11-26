#pragma once

#include <JuceHeader.h>
#include <map>
#include <vector>

namespace Eoel {

/**
 * GlobalReachOptimizer - Maximum Global Accessibility & Reach
 *
 * Optimizations for reaching the maximum number of people worldwide:
 *
 * 1. ACCESSIBILITY (WCAG 2.2 AAA)
 *    - Screen reader support (JAWS, NVDA, VoiceOver)
 *    - Keyboard navigation (100% mouse-free)
 *    - High contrast modes
 *    - Adjustable font sizes
 *    - Color blindness support (8 types)
 *    - Reduced motion mode
 *    - Captions & transcripts
 *
 * 2. INTERNATIONALIZATION (50+ Languages)
 *    - RTL support (Arabic, Hebrew)
 *    - Character encoding (UTF-8, Unicode)
 *    - Date/time localization
 *    - Number formatting
 *    - Currency conversion
 *
 * 3. PERFORMANCE (Low-End Devices)
 *    - Lightweight mode (<500 MB RAM)
 *    - CPU optimization (works on Pentium 4)
 *    - GPU optional
 *    - Low bandwidth mode
 *
 * 4. OFFLINE SUPPORT
 *    - Full offline mode
 *    - Sync when online
 *    - Progressive Web App (PWA)
 *
 * 5. REGIONAL PRICING
 *    - Purchasing Power Parity (PPP)
 *    - Local payment methods
 *    - Educational discounts
 *
 * 6. SIMPLIFIED UI
 *    - Beginner mode
 *    - Advanced mode
 *    - Expert mode
 *    - Guided tutorials
 */
class GlobalReachOptimizer
{
public:
    // ===========================
    // 1. ACCESSIBILITY
    // ===========================

    enum class ColorBlindnessType
    {
        None,
        Protanopia,         // Red-blind
        Deuteranopia,       // Green-blind
        Tritanopia,         // Blue-blind
        Achromatopsia,      // Total color blindness
        Protanomaly,        // Red-weak
        Deuteranomaly,      // Green-weak
        Tritanomaly         // Blue-weak
    };

    struct AccessibilitySettings
    {
        // Screen Reader
        bool screenReaderEnabled = false;
        bool announceAllActions = true;
        bool verboseDescriptions = true;

        // Visual
        bool highContrastMode = false;
        float fontSize = 1.0f;              // 0.5 to 3.0 (50% to 300%)
        ColorBlindnessType colorBlindness = ColorBlindnessType::None;
        bool reducedMotion = false;
        bool flashingElementsOff = true;    // Prevent seizures
        float cursorSize = 1.0f;            // 1.0 to 5.0

        // Audio
        bool visualCaptions = false;
        bool audioDescriptions = false;
        bool monoAudio = false;             // For single-ear users

        // Input
        bool keyboardOnly = false;
        bool stickyKeys = false;            // Hold modifier keys
        bool slowKeys = false;              // Delay key press
        float doubleClickSpeed = 0.5f;      // seconds

        // Cognitive
        bool simplifiedUI = false;
        bool autoSave = true;
        int autoSaveInterval = 60;          // seconds
        bool confirmActions = true;
    };

    /** Set accessibility settings */
    void setAccessibilitySettings(const AccessibilitySettings& settings);

    /** Get current accessibility settings */
    AccessibilitySettings getAccessibilitySettings() const { return m_accessibilitySettings; }

    /** Adjust color for color blindness */
    juce::Colour adjustColorForColorBlindness(juce::Colour original) const;

    /** Generate screen reader announcement */
    juce::String generateScreenReaderText(const juce::String& action, const juce::String& target) const;

    // ===========================
    // 2. INTERNATIONALIZATION
    // ===========================

    enum class Language
    {
        // Top 50 languages by speakers
        English, Spanish, Mandarin, Hindi, Arabic,
        Portuguese, Bengali, Russian, Japanese, Punjabi,
        German, Javanese, Wu, Malay, Telugu,
        Vietnamese, Korean, French, Marathi, Tamil,
        Urdu, Turkish, Italian, Cantonese, Thai,
        Gujarati, Jin, Min_Nan, Persian, Polish,
        Pashto, Kannada, Xiang, Malayalam, Sundanese,
        Hausa, Odia, Burmese, Hakka, Ukrainian,
        Bhojpuri, Tagalog, Yoruba, Maithili, Uzbek,
        Sindhi, Amharic, Fula, Romanian, Oromo
    };

    struct LocalizationData
    {
        Language language;
        bool isRTL = false;                 // Right-to-left

        // Number formatting
        juce::String decimalSeparator = ".";
        juce::String thousandsSeparator = ",";

        // Date formatting
        juce::String dateFormat = "MM/DD/YYYY";
        juce::String timeFormat = "HH:MM:SS";

        // Currency
        juce::String currencySymbol = "$";
        juce::String currencyCode = "USD";
        float exchangeRate = 1.0f;

        // Translations
        std::map<juce::String, juce::String> translations;
    };

    /** Set current language */
    void setLanguage(Language language);

    /** Get current language */
    Language getLanguage() const { return m_currentLanguage; }

    /** Translate text */
    juce::String translate(const juce::String& key) const;

    /** Format number for current locale */
    juce::String formatNumber(double number, int decimals = 2) const;

    /** Format currency */
    juce::String formatCurrency(double amount) const;

    /** Format date */
    juce::String formatDate(juce::Time time) const;

    // ===========================
    // 3. PERFORMANCE OPTIMIZATION
    // ===========================

    enum class PerformanceMode
    {
        UltraLow,           // Pentium 4, 512 MB RAM
        Low,                // Core 2 Duo, 2 GB RAM
        Medium,             // Core i3, 4 GB RAM
        High,               // Core i5, 8 GB RAM
        Ultra               // Core i7+, 16+ GB RAM
    };

    struct PerformanceSettings
    {
        PerformanceMode mode = PerformanceMode::Medium;

        // Graphics
        bool gpuAcceleration = true;
        int maxFPS = 60;                    // 15, 30, 60, 120, 144
        bool antiAliasing = true;
        bool shadows = true;
        bool particleEffects = true;
        int visualQuality = 5;              // 1-10

        // Audio
        int bufferSize = 512;               // 64, 128, 256, 512, 1024
        int sampleRate = 44100;             // 44100, 48000, 96000
        int maxVoices = 128;                // Max simultaneous voices

        // General
        int maxUndoSteps = 50;
        bool preloadSamples = true;
        bool cacheEnabled = true;
        int cacheSize = 1024;               // MB
    };

    /** Set performance mode (auto-detects system) */
    void setPerformanceMode(PerformanceMode mode);

    /** Auto-detect optimal performance settings */
    PerformanceSettings detectOptimalSettings() const;

    /** Get system requirements */
    struct SystemInfo {
        int cpuCores = 0;
        int ramMB = 0;
        bool hasGPU = false;
        juce::String gpuModel;
        int vramMB = 0;
    };
    SystemInfo getSystemInfo() const;

    // ===========================
    // 4. OFFLINE SUPPORT
    // ===========================

    struct OfflineSettings
    {
        bool offlineMode = false;
        bool autoSync = true;
        int syncInterval = 300;             // seconds (5 min)

        // What to cache offline
        bool cacheProjects = true;
        bool cacheSamples = true;
        bool cachePlugins = true;
        bool cachePresets = true;

        int maxOfflineStorage = 5000;       // MB
    };

    /** Enable offline mode */
    void setOfflineMode(bool enabled);

    /** Check if online */
    bool isOnline() const;

    /** Sync when online */
    void syncWhenOnline();

    /** Get offline storage usage */
    int getOfflineStorageUsageMB() const;

    // ===========================
    // 5. REGIONAL PRICING
    // ===========================

    struct RegionalPricing
    {
        juce::String countryCode;          // ISO 3166-1 alpha-2
        juce::String currencyCode;         // ISO 4217

        // Purchasing Power Parity adjustment
        float pppMultiplier = 1.0f;

        // Base prices (USD)
        double freePrice = 0.0;
        double proPrice = 29.99;
        double agencyPrice = 99.99;
        double enterprisePrice = 499.99;

        // Local prices (adjusted)
        double localProPrice = 29.99;
        double localAgencyPrice = 99.99;
        double localEnterprisePrice = 499.99;

        // Discounts
        float studentDiscount = 0.50f;      // 50% off
        float educatorDiscount = 0.75f;     // 75% off
        float nonprofitDiscount = 0.90f;    // 90% off
    };

    /** Get pricing for user's country */
    RegionalPricing getPricingForCountry(const juce::String& countryCode) const;

    /** Calculate PPP-adjusted price */
    double calculatePPPPrice(double basePrice, const juce::String& countryCode) const;

    /** Check if eligible for educational discount */
    bool checkEducationalEligibility(const juce::String& email) const;

    // ===========================
    // 6. SIMPLIFIED UI MODES
    // ===========================

    enum class UIComplexity
    {
        Beginner,           // Simplified, guided
        Intermediate,       // Balanced
        Advanced,           // Full features
        Expert,             // Everything exposed
        Custom              // User-customized
    };

    struct UISettings
    {
        UIComplexity complexity = UIComplexity::Intermediate;

        // What to show
        bool showTooltips = true;
        bool showHints = true;
        bool showShortcuts = true;
        bool showAdvancedControls = false;

        // Layout
        bool compactMode = false;
        bool darkMode = true;
        juce::String theme = "Default";

        // Guided experience
        bool enableTutorials = true;
        bool showWelcomeScreen = true;
        bool contextualHelp = true;
    };

    /** Set UI complexity */
    void setUIComplexity(UIComplexity complexity);

    /** Get recommended UI for user level */
    UISettings getRecommendedUISettings(int userExperienceLevel) const;

    // ===========================
    // 7. EDUCATIONAL FEATURES
    // ===========================

    struct EducationalLicense
    {
        enum class Type {
            Student,            // Individual student
            Educator,           // Teacher/professor
            Classroom,          // 1-30 students
            School,             // Entire school
            University          // Entire university
        };

        Type type;
        int maxSeats = 1;
        juce::String institution;
        juce::Time expiryDate;
        bool verified = false;
    };

    /** Request educational license */
    bool requestEducationalLicense(const EducationalLicense& license);

    /** Verify educational email */
    bool verifyEducationalEmail(const juce::String& email) const;

    // ===========================
    // 8. COMMUNITY SUPPORT
    // ===========================

    /** Get help in user's language */
    juce::String getLocalizedHelp(const juce::String& topic) const;

    /** Find local community (country/language) */
    juce::String getLocalCommunityURL() const;

    /** Report issue with auto-translation */
    void reportIssue(const juce::String& description);

    // ===========================
    // Analytics (Privacy-Friendly)
    // ===========================

    /** Track feature usage (anonymous, opt-in) */
    void trackFeatureUsage(const juce::String& featureName);

    /** Get popular features in user's region */
    std::vector<juce::String> getPopularFeaturesInRegion() const;

    GlobalReachOptimizer();
    ~GlobalReachOptimizer();

private:
    AccessibilitySettings m_accessibilitySettings;
    Language m_currentLanguage = Language::English;
    LocalizationData m_localizationData;
    PerformanceSettings m_performanceSettings;
    OfflineSettings m_offlineSettings;
    UISettings m_uiSettings;

    // Translations database
    std::map<Language, std::map<juce::String, juce::String>> m_translations;

    // PPP data (World Bank, IMF data)
    std::map<juce::String, float> m_pppMultipliers;

    // Educational domain whitelist
    std::vector<juce::String> m_educationalDomains;

    void loadTranslations();
    void loadPPPData();
    void loadEducationalDomains();

    juce::CriticalSection m_lock;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GlobalReachOptimizer)
};

} // namespace Eoel

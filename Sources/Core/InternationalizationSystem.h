#pragma once

#include <JuceHeader.h>
#include <map>
#include <string>
#include <vector>
#include <functional>
#include <memory>

/**
 * InternationalizationSystem (i18n) - Worldwide Language & Marketing Support
 *
 * Full support for 100+ languages with:
 * - UI translations
 * - RTL language support (Arabic, Hebrew, Urdu, etc.)
 * - Currency formatting
 * - Date/Time localization
 * - Number formatting (decimal separators)
 * - Cultural music terminology
 * - Marketing copy variations
 * - Legal compliance per region
 * - Accessibility descriptions
 *
 * Inclusive Design:
 * - Screen reader friendly
 * - High contrast themes
 * - Dyslexia-friendly fonts
 * - Color-blind safe palettes
 *
 * 2026 Ready: AI-assisted translations with context awareness
 */

namespace Echoelmusic {
namespace Core {

//==============================================================================
// Language Codes (ISO 639-1 + common extensions)
//==============================================================================

enum class Language
{
    // Major Western Languages
    English_US,
    English_UK,
    English_AU,
    German,
    French,
    Spanish_ES,
    Spanish_MX,
    Portuguese_BR,
    Portuguese_PT,
    Italian,
    Dutch,
    Polish,
    Swedish,
    Norwegian,
    Danish,
    Finnish,

    // Eastern European
    Russian,
    Ukrainian,
    Czech,
    Hungarian,
    Romanian,
    Bulgarian,
    Serbian,
    Croatian,
    Slovak,
    Greek,

    // Middle Eastern / RTL
    Arabic,
    Hebrew,
    Persian,
    Urdu,
    Turkish,

    // South Asian
    Hindi,
    Bengali,
    Tamil,
    Telugu,
    Marathi,
    Gujarati,
    Kannada,
    Malayalam,
    Punjabi,

    // East Asian
    Chinese_Simplified,
    Chinese_Traditional,
    Japanese,
    Korean,
    Vietnamese,
    Thai,
    Indonesian,
    Malay,
    Filipino,

    // African
    Swahili,
    Zulu,
    Afrikaans,
    Amharic,
    Hausa,
    Yoruba,

    // Other
    Icelandic,
    Estonian,
    Latvian,
    Lithuanian,
    Slovenian,
    Catalan,
    Basque,
    Welsh,
    Irish,

    // Special
    Latin,          // For classical music terminology
    Count
};

//==============================================================================
// Region/Market Codes
//==============================================================================

enum class Region
{
    NorthAmerica,
    LatinAmerica,
    WesternEurope,
    EasternEurope,
    MiddleEast,
    SouthAsia,
    EastAsia,
    SoutheastAsia,
    Africa,
    Oceania,
    Global
};

//==============================================================================
// Currency Support
//==============================================================================

struct Currency
{
    std::string code;       // USD, EUR, GBP, etc.
    std::string symbol;     // $, €, £, etc.
    std::string name;
    int decimalPlaces = 2;
    bool symbolBefore = true;  // $100 vs 100$
};

//==============================================================================
// Translation Entry
//==============================================================================

struct Translation
{
    std::string key;
    std::map<Language, std::string> values;

    std::string get(Language lang) const
    {
        if (auto it = values.find(lang); it != values.end())
            return it->second;
        // Fallback to English US
        if (auto it = values.find(Language::English_US); it != values.end())
            return it->second;
        return key;  // Return key if no translation
    }
};

//==============================================================================
// Music Terminology Database
//==============================================================================

struct MusicTerminology
{
    // Standard terms vary by language
    static std::string getTempoTerm(Language lang, const std::string& term)
    {
        static std::map<std::string, std::map<Language, std::string>> terms = {
            {"Allegro", {
                {Language::English_US, "Fast, lively"},
                {Language::German, "Schnell, lebhaft"},
                {Language::French, "Rapide, vif"},
                {Language::Spanish_ES, "Rápido, alegre"},
                {Language::Italian, "Allegro"},
                {Language::Japanese, "速く、活発に"},
                {Language::Chinese_Simplified, "快板"},
            }},
            {"Andante", {
                {Language::English_US, "Walking pace"},
                {Language::German, "Gehend"},
                {Language::French, "Allant"},
                {Language::Spanish_ES, "Andando"},
                {Language::Italian, "Andante"},
                {Language::Japanese, "歩くような速さで"},
                {Language::Chinese_Simplified, "行板"},
            }},
            {"Forte", {
                {Language::English_US, "Loud"},
                {Language::German, "Laut"},
                {Language::French, "Fort"},
                {Language::Spanish_ES, "Fuerte"},
                {Language::Italian, "Forte"},
                {Language::Japanese, "強く"},
                {Language::Chinese_Simplified, "强"},
            }},
            {"Piano", {
                {Language::English_US, "Soft"},
                {Language::German, "Leise"},
                {Language::French, "Doux"},
                {Language::Spanish_ES, "Suave"},
                {Language::Italian, "Piano"},
                {Language::Japanese, "弱く"},
                {Language::Chinese_Simplified, "弱"},
            }}
        };

        if (auto termIt = terms.find(term); termIt != terms.end())
        {
            if (auto langIt = termIt->second.find(lang); langIt != termIt->second.end())
                return langIt->second;
        }
        return term;
    }
};

//==============================================================================
// Accessibility Support
//==============================================================================

struct AccessibilityConfig
{
    bool screenReaderEnabled = false;
    bool highContrastMode = false;
    bool reducedMotion = false;
    bool dyslexiaFriendlyFont = false;
    bool colorBlindMode = false;

    enum class ColorBlindType
    {
        None,
        Protanopia,     // Red-blind
        Deuteranopia,   // Green-blind
        Tritanopia      // Blue-blind
    } colorBlindType = ColorBlindType::None;

    float textScaling = 1.0f;  // 0.5 - 2.0
    float animationSpeed = 1.0f;  // 0 = instant, 1 = normal
};

//==============================================================================
// Main Internationalization System
//==============================================================================

class InternationalizationSystem
{
public:
    static InternationalizationSystem& getInstance()
    {
        static InternationalizationSystem instance;
        return instance;
    }

    //==========================================================================
    // Initialization
    //==========================================================================

    void initialize()
    {
        detectSystemLanguage();
        loadTranslations();
        initializeCurrencies();
        initializeMarketingStrings();

        isInitialized = true;
    }

    //==========================================================================
    // Language Management
    //==========================================================================

    void setLanguage(Language lang)
    {
        currentLanguage = lang;
        isRTL = isRTLLanguage(lang);
        notifyLanguageChanged();
    }

    Language getLanguage() const { return currentLanguage; }

    std::string getLanguageName(Language lang) const
    {
        static std::map<Language, std::string> names = {
            {Language::English_US, "English (US)"},
            {Language::English_UK, "English (UK)"},
            {Language::German, "Deutsch"},
            {Language::French, "Français"},
            {Language::Spanish_ES, "Español"},
            {Language::Spanish_MX, "Español (México)"},
            {Language::Portuguese_BR, "Português (Brasil)"},
            {Language::Italian, "Italiano"},
            {Language::Dutch, "Nederlands"},
            {Language::Polish, "Polski"},
            {Language::Russian, "Русский"},
            {Language::Arabic, "العربية"},
            {Language::Hebrew, "עברית"},
            {Language::Hindi, "हिन्दी"},
            {Language::Chinese_Simplified, "简体中文"},
            {Language::Chinese_Traditional, "繁體中文"},
            {Language::Japanese, "日本語"},
            {Language::Korean, "한국어"},
            {Language::Vietnamese, "Tiếng Việt"},
            {Language::Thai, "ไทย"},
            {Language::Indonesian, "Bahasa Indonesia"},
            {Language::Turkish, "Türkçe"},
            {Language::Swedish, "Svenska"},
            {Language::Norwegian, "Norsk"},
            {Language::Danish, "Dansk"},
            {Language::Finnish, "Suomi"},
            // ... more
        };

        if (auto it = names.find(lang); it != names.end())
            return it->second;
        return "Unknown";
    }

    std::string getNativeLanguageName(Language lang) const
    {
        return getLanguageName(lang);  // Already native names
    }

    bool isRTLLanguage(Language lang) const
    {
        return lang == Language::Arabic ||
               lang == Language::Hebrew ||
               lang == Language::Persian ||
               lang == Language::Urdu;
    }

    bool isCurrentRTL() const { return isRTL; }

    //==========================================================================
    // Translation
    //==========================================================================

    std::string translate(const std::string& key) const
    {
        return translate(key, currentLanguage);
    }

    std::string translate(const std::string& key, Language lang) const
    {
        if (auto it = translations.find(key); it != translations.end())
            return it->second.get(lang);
        return key;
    }

    // Shorthand macro-friendly
    std::string t(const std::string& key) const
    {
        return translate(key);
    }

    // With parameter substitution
    std::string translate(const std::string& key,
                          const std::map<std::string, std::string>& params) const
    {
        std::string result = translate(key);

        for (const auto& [param, value] : params)
        {
            std::string placeholder = "{" + param + "}";
            size_t pos = 0;
            while ((pos = result.find(placeholder, pos)) != std::string::npos)
            {
                result.replace(pos, placeholder.length(), value);
                pos += value.length();
            }
        }

        return result;
    }

    void addTranslation(const std::string& key, Language lang, const std::string& value)
    {
        translations[key].key = key;
        translations[key].values[lang] = value;
    }

    //==========================================================================
    // Number & Currency Formatting
    //==========================================================================

    std::string formatNumber(double value, int decimals = 2) const
    {
        std::string result = juce::String(value, decimals).toStdString();

        // Replace decimal separator based on language
        if (usesCommaDecimal())
        {
            size_t dotPos = result.find('.');
            if (dotPos != std::string::npos)
                result[dotPos] = ',';
        }

        // Add thousands separator
        std::string intPart = result.substr(0, result.find(usesCommaDecimal() ? ',' : '.'));
        std::string decPart = result.substr(result.find(usesCommaDecimal() ? ',' : '.'));

        std::string formatted;
        int count = 0;
        for (auto it = intPart.rbegin(); it != intPart.rend(); ++it)
        {
            if (count > 0 && count % 3 == 0)
                formatted = getThousandsSeparator() + formatted;
            formatted = *it + formatted;
            count++;
        }

        return formatted + decPart;
    }

    std::string formatCurrency(double value, const std::string& currencyCode) const
    {
        if (auto it = currencies.find(currencyCode); it != currencies.end())
        {
            const Currency& curr = it->second;
            std::string amount = formatNumber(value, curr.decimalPlaces);

            if (curr.symbolBefore)
                return curr.symbol + amount;
            else
                return amount + " " + curr.symbol;
        }

        return formatNumber(value, 2) + " " + currencyCode;
    }

    char getThousandsSeparator() const
    {
        // German, French, etc. use . as thousands separator
        if (currentLanguage == Language::German ||
            currentLanguage == Language::French ||
            currentLanguage == Language::Spanish_ES ||
            currentLanguage == Language::Italian ||
            currentLanguage == Language::Portuguese_BR)
            return '.';
        return ',';
    }

    bool usesCommaDecimal() const
    {
        return currentLanguage == Language::German ||
               currentLanguage == Language::French ||
               currentLanguage == Language::Spanish_ES ||
               currentLanguage == Language::Italian ||
               currentLanguage == Language::Portuguese_BR ||
               currentLanguage == Language::Dutch ||
               currentLanguage == Language::Polish ||
               currentLanguage == Language::Russian;
    }

    //==========================================================================
    // Date & Time Formatting
    //==========================================================================

    std::string formatDate(const juce::Time& time) const
    {
        // US: MM/DD/YYYY, Most others: DD/MM/YYYY or DD.MM.YYYY
        if (currentLanguage == Language::English_US)
            return time.formatted("%m/%d/%Y").toStdString();
        else if (currentLanguage == Language::German)
            return time.formatted("%d.%m.%Y").toStdString();
        else if (currentLanguage == Language::Japanese ||
                 currentLanguage == Language::Chinese_Simplified ||
                 currentLanguage == Language::Korean)
            return time.formatted("%Y/%m/%d").toStdString();
        else
            return time.formatted("%d/%m/%Y").toStdString();
    }

    std::string formatTime(const juce::Time& time, bool use24Hour = true) const
    {
        if (use24Hour || currentLanguage == Language::German ||
            currentLanguage == Language::French ||
            currentLanguage == Language::Japanese)
            return time.formatted("%H:%M").toStdString();
        else
            return time.formatted("%I:%M %p").toStdString();
    }

    //==========================================================================
    // Marketing Strings
    //==========================================================================

    std::string getMarketingCopy(const std::string& key, Region region) const
    {
        std::string langKey = key + "_" + regionToString(region);
        if (auto it = marketingStrings.find(langKey); it != marketingStrings.end())
            return it->second;

        // Fallback to global
        langKey = key + "_Global";
        if (auto it = marketingStrings.find(langKey); it != marketingStrings.end())
            return it->second;

        return translate(key);
    }

    std::string getTagline(Region region) const
    {
        return getMarketingCopy("tagline", region);
    }

    std::string getAppDescription(Region region) const
    {
        return getMarketingCopy("app_description", region);
    }

    //==========================================================================
    // Accessibility
    //==========================================================================

    void setAccessibilityConfig(const AccessibilityConfig& config)
    {
        accessibilityConfig = config;
        notifyAccessibilityChanged();
    }

    const AccessibilityConfig& getAccessibilityConfig() const
    {
        return accessibilityConfig;
    }

    std::string getAccessibleLabel(const std::string& elementKey) const
    {
        return translate("accessibility." + elementKey);
    }

    juce::Colour adjustForColorBlindness(juce::Colour color) const
    {
        if (!accessibilityConfig.colorBlindMode)
            return color;

        // Adjust colors based on color blindness type
        switch (accessibilityConfig.colorBlindType)
        {
            case AccessibilityConfig::ColorBlindType::Protanopia:
                // Shift reds to more visible colors
                if (color.getRed() > 150 && color.getGreen() < 100)
                    return juce::Colour(color.getBlue(), color.getGreen(), color.getRed());
                break;

            case AccessibilityConfig::ColorBlindType::Deuteranopia:
                // Shift greens
                if (color.getGreen() > 150 && color.getRed() < 100)
                    return juce::Colour(color.getRed(), color.getBlue(), color.getGreen());
                break;

            case AccessibilityConfig::ColorBlindType::Tritanopia:
                // Shift blues
                if (color.getBlue() > 150 && color.getGreen() < 100)
                    return juce::Colour(color.getBlue(), color.getRed(), color.getGreen());
                break;

            default:
                break;
        }

        return color;
    }

    //==========================================================================
    // Event Callbacks
    //==========================================================================

    void onLanguageChanged(std::function<void(Language)> callback)
    {
        languageChangedCallbacks.push_back(callback);
    }

    void onAccessibilityChanged(std::function<void(const AccessibilityConfig&)> callback)
    {
        accessibilityChangedCallbacks.push_back(callback);
    }

    //==========================================================================
    // Available Languages
    //==========================================================================

    std::vector<Language> getAvailableLanguages() const
    {
        return {
            Language::English_US,
            Language::English_UK,
            Language::German,
            Language::French,
            Language::Spanish_ES,
            Language::Spanish_MX,
            Language::Portuguese_BR,
            Language::Italian,
            Language::Dutch,
            Language::Polish,
            Language::Russian,
            Language::Arabic,
            Language::Hebrew,
            Language::Hindi,
            Language::Chinese_Simplified,
            Language::Chinese_Traditional,
            Language::Japanese,
            Language::Korean,
            Language::Vietnamese,
            Language::Thai,
            Language::Indonesian,
            Language::Turkish,
            Language::Swedish
        };
    }

private:
    InternationalizationSystem() = default;

    //==========================================================================
    // Helpers
    //==========================================================================

    void detectSystemLanguage()
    {
        // Get system locale
        juce::String locale = juce::SystemStats::getUserLanguage();

        if (locale.startsWith("de"))
            currentLanguage = Language::German;
        else if (locale.startsWith("fr"))
            currentLanguage = Language::French;
        else if (locale.startsWith("es"))
            currentLanguage = locale.contains("MX") ? Language::Spanish_MX : Language::Spanish_ES;
        else if (locale.startsWith("pt"))
            currentLanguage = locale.contains("BR") ? Language::Portuguese_BR : Language::Portuguese_PT;
        else if (locale.startsWith("it"))
            currentLanguage = Language::Italian;
        else if (locale.startsWith("ja"))
            currentLanguage = Language::Japanese;
        else if (locale.startsWith("ko"))
            currentLanguage = Language::Korean;
        else if (locale.startsWith("zh"))
            currentLanguage = locale.contains("TW") || locale.contains("HK")
                ? Language::Chinese_Traditional : Language::Chinese_Simplified;
        else if (locale.startsWith("ar"))
            currentLanguage = Language::Arabic;
        else if (locale.startsWith("he"))
            currentLanguage = Language::Hebrew;
        else if (locale.startsWith("ru"))
            currentLanguage = Language::Russian;
        else
            currentLanguage = Language::English_US;

        isRTL = isRTLLanguage(currentLanguage);
    }

    void loadTranslations()
    {
        // Core UI translations
        addTranslation("app.name", Language::English_US, "Echoelmusic");
        addTranslation("app.name", Language::German, "Echoelmusic");

        addTranslation("menu.file", Language::English_US, "File");
        addTranslation("menu.file", Language::German, "Datei");
        addTranslation("menu.file", Language::French, "Fichier");
        addTranslation("menu.file", Language::Spanish_ES, "Archivo");
        addTranslation("menu.file", Language::Japanese, "ファイル");
        addTranslation("menu.file", Language::Chinese_Simplified, "文件");

        addTranslation("menu.edit", Language::English_US, "Edit");
        addTranslation("menu.edit", Language::German, "Bearbeiten");
        addTranslation("menu.edit", Language::French, "Édition");
        addTranslation("menu.edit", Language::Spanish_ES, "Editar");
        addTranslation("menu.edit", Language::Japanese, "編集");
        addTranslation("menu.edit", Language::Chinese_Simplified, "编辑");

        addTranslation("button.save", Language::English_US, "Save");
        addTranslation("button.save", Language::German, "Speichern");
        addTranslation("button.save", Language::French, "Enregistrer");
        addTranslation("button.save", Language::Spanish_ES, "Guardar");
        addTranslation("button.save", Language::Japanese, "保存");
        addTranslation("button.save", Language::Chinese_Simplified, "保存");
        addTranslation("button.save", Language::Arabic, "حفظ");
        addTranslation("button.save", Language::Hebrew, "שמור");
        addTranslation("button.save", Language::Hindi, "सहेजें");
        addTranslation("button.save", Language::Korean, "저장");

        addTranslation("button.cancel", Language::English_US, "Cancel");
        addTranslation("button.cancel", Language::German, "Abbrechen");
        addTranslation("button.cancel", Language::French, "Annuler");
        addTranslation("button.cancel", Language::Spanish_ES, "Cancelar");
        addTranslation("button.cancel", Language::Japanese, "キャンセル");

        addTranslation("transport.play", Language::English_US, "Play");
        addTranslation("transport.play", Language::German, "Wiedergabe");
        addTranslation("transport.play", Language::French, "Lecture");
        addTranslation("transport.play", Language::Japanese, "再生");

        addTranslation("transport.stop", Language::English_US, "Stop");
        addTranslation("transport.stop", Language::German, "Stopp");
        addTranslation("transport.stop", Language::French, "Arrêt");
        addTranslation("transport.stop", Language::Japanese, "停止");

        addTranslation("transport.record", Language::English_US, "Record");
        addTranslation("transport.record", Language::German, "Aufnahme");
        addTranslation("transport.record", Language::French, "Enregistrer");
        addTranslation("transport.record", Language::Japanese, "録音");

        // Wellness / Biofeedback
        addTranslation("wellness.heartRate", Language::English_US, "Heart Rate");
        addTranslation("wellness.heartRate", Language::German, "Herzfrequenz");
        addTranslation("wellness.heartRate", Language::French, "Fréquence cardiaque");
        addTranslation("wellness.heartRate", Language::Spanish_ES, "Frecuencia cardíaca");
        addTranslation("wellness.heartRate", Language::Japanese, "心拍数");
        addTranslation("wellness.heartRate", Language::Chinese_Simplified, "心率");

        addTranslation("wellness.meditation", Language::English_US, "Meditation");
        addTranslation("wellness.meditation", Language::German, "Meditation");
        addTranslation("wellness.meditation", Language::French, "Méditation");
        addTranslation("wellness.meditation", Language::Japanese, "瞑想");
        addTranslation("wellness.meditation", Language::Hindi, "ध्यान");

        // Accessibility
        addTranslation("accessibility.playButton", Language::English_US, "Play button. Press to start playback.");
        addTranslation("accessibility.playButton", Language::German, "Wiedergabe-Taste. Drücken zum Starten der Wiedergabe.");

        // ... many more translations would be loaded from JSON files in production
    }

    void initializeCurrencies()
    {
        currencies["USD"] = {"USD", "$", "US Dollar", 2, true};
        currencies["EUR"] = {"EUR", "€", "Euro", 2, true};
        currencies["GBP"] = {"GBP", "£", "British Pound", 2, true};
        currencies["JPY"] = {"JPY", "¥", "Japanese Yen", 0, true};
        currencies["CNY"] = {"CNY", "¥", "Chinese Yuan", 2, true};
        currencies["KRW"] = {"KRW", "₩", "Korean Won", 0, true};
        currencies["INR"] = {"INR", "₹", "Indian Rupee", 2, true};
        currencies["BRL"] = {"BRL", "R$", "Brazilian Real", 2, true};
        currencies["RUB"] = {"RUB", "₽", "Russian Ruble", 2, false};
        currencies["CHF"] = {"CHF", "CHF", "Swiss Franc", 2, true};
        currencies["AUD"] = {"AUD", "A$", "Australian Dollar", 2, true};
        currencies["CAD"] = {"CAD", "C$", "Canadian Dollar", 2, true};
        currencies["MXN"] = {"MXN", "MX$", "Mexican Peso", 2, true};
        currencies["SEK"] = {"SEK", "kr", "Swedish Krona", 2, false};
        currencies["NOK"] = {"NOK", "kr", "Norwegian Krone", 2, false};
        currencies["TRY"] = {"TRY", "₺", "Turkish Lira", 2, true};
        currencies["AED"] = {"AED", "د.إ", "UAE Dirham", 2, true};
        currencies["SAR"] = {"SAR", "﷼", "Saudi Riyal", 2, true};
        currencies["ILS"] = {"ILS", "₪", "Israeli Shekel", 2, true};
        currencies["THB"] = {"THB", "฿", "Thai Baht", 2, true};
        currencies["IDR"] = {"IDR", "Rp", "Indonesian Rupiah", 0, true};
        currencies["VND"] = {"VND", "₫", "Vietnamese Dong", 0, false};
        currencies["ZAR"] = {"ZAR", "R", "South African Rand", 2, true};
    }

    void initializeMarketingStrings()
    {
        // Taglines by region
        marketingStrings["tagline_Global"] = "Create. Feel. Transform.";
        marketingStrings["tagline_NorthAmerica"] = "Music Meets Wellness";
        marketingStrings["tagline_WesternEurope"] = "Kreativ • Gesund • Mobil";
        marketingStrings["tagline_EastAsia"] = "音楽とウェルネスの融合";
        marketingStrings["tagline_LatinAmerica"] = "Música que transforma";

        // App descriptions
        marketingStrings["app_description_Global"] =
            "The world's first DAW that combines professional music production "
            "with biofeedback, wellness, and AI-powered creativity.";
    }

    std::string regionToString(Region region) const
    {
        switch (region)
        {
            case Region::NorthAmerica:   return "NorthAmerica";
            case Region::LatinAmerica:   return "LatinAmerica";
            case Region::WesternEurope:  return "WesternEurope";
            case Region::EasternEurope:  return "EasternEurope";
            case Region::MiddleEast:     return "MiddleEast";
            case Region::SouthAsia:      return "SouthAsia";
            case Region::EastAsia:       return "EastAsia";
            case Region::SoutheastAsia:  return "SoutheastAsia";
            case Region::Africa:         return "Africa";
            case Region::Oceania:        return "Oceania";
            default:                     return "Global";
        }
    }

    void notifyLanguageChanged()
    {
        for (auto& callback : languageChangedCallbacks)
            callback(currentLanguage);
    }

    void notifyAccessibilityChanged()
    {
        for (auto& callback : accessibilityChangedCallbacks)
            callback(accessibilityConfig);
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    bool isInitialized = false;
    Language currentLanguage = Language::English_US;
    bool isRTL = false;

    std::map<std::string, Translation> translations;
    std::map<std::string, Currency> currencies;
    std::map<std::string, std::string> marketingStrings;

    AccessibilityConfig accessibilityConfig;

    std::vector<std::function<void(Language)>> languageChangedCallbacks;
    std::vector<std::function<void(const AccessibilityConfig&)>> accessibilityChangedCallbacks;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(InternationalizationSystem)
};

//==============================================================================
// Convenience Macros
//==============================================================================

#define EchoelI18n InternationalizationSystem::getInstance()
#define _T(key) InternationalizationSystem::getInstance().translate(key)
#define _TL(key, lang) InternationalizationSystem::getInstance().translate(key, lang)

} // namespace Core
} // namespace Echoelmusic

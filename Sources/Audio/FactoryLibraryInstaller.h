#pragma once

#include <JuceHeader.h>
#include "SampleLibrary.h"

/**
 * FactoryLibraryInstaller - Install Factory Samples on First Launch
 *
 * Like Ableton Live, Logic Pro, FL Studio - ship with factory content!
 *
 * Echoelmusic Factory Library:
 * - Pre-processed samples (Echoelmusic Signature Sound applied)
 * - Organized categories (Drums, Bass, Synths, etc.)
 * - Metadata pre-generated (BPM, Key, Tags)
 * - Waveform thumbnails included
 * - Ready to use immediately!
 *
 * Factory Content Sources:
 * - User's FL Studio Mobile samples (with permission)
 * - Royalty-free sample packs
 * - Custom Echoelmusic recordings
 * - Community contributions
 *
 * Installation Methods:
 * - Bundled with app (Resources/FactoryLibrary/)
 * - Downloaded on first launch (smaller installer)
 * - Optional expansion packs
 *
 * Usage:
 * ```cpp
 * FactoryLibraryInstaller installer;
 * installer.setLibrary(&sampleLibrary);
 *
 * if (installer.needsInstallation())
 * {
 *     installer.installFactoryLibrary();
 * }
 * ```
 */
class FactoryLibraryInstaller
{
public:
    //==========================================================================
    // Factory Library Info
    //==========================================================================

    struct FactoryPackInfo
    {
        juce::String name;              // "Echoelmusic Essentials"
        juce::String description;       // "Core factory library"
        juce::String version;           // "1.0.0"
        int sampleCount = 0;
        int64_t totalSize = 0;
        bool isInstalled = false;
        bool isRequired = true;         // Must install

        juce::String installPath;       // Where pack is installed
        juce::File sourceArchive;       // .echopack file

        juce::StringArray categories;   // Drums, Bass, etc.
        juce::StringArray tags;         // Techno, House, etc.
    };

    //==========================================================================
    // Installation Result
    //==========================================================================

    struct InstallationResult
    {
        bool success = false;
        int packsInstalled = 0;
        int samplesInstalled = 0;
        int64_t totalSize = 0;

        juce::StringArray installedPacks;
        juce::StringArray errorMessages;

        juce::Time startTime;
        juce::Time endTime;

        juce::String getSummary() const;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    FactoryLibraryInstaller();
    ~FactoryLibraryInstaller();

    //==========================================================================
    // Setup
    //==========================================================================

    /** Set target sample library */
    void setLibrary(SampleLibrary* library) { sampleLibrary = library; }

    /** Get library */
    SampleLibrary* getLibrary() const { return sampleLibrary; }

    //==========================================================================
    // Installation Check
    //==========================================================================

    /** Check if factory library needs installation */
    bool needsInstallation();

    /** Check if specific pack is installed */
    bool isPackInstalled(const juce::String& packName);

    /** Get installation status */
    struct InstallationStatus
    {
        bool hasFactoryLibrary = false;
        int packsInstalled = 0;
        int packsAvailable = 0;
        int samplesInstalled = 0;
        int64_t totalSize = 0;
    };

    InstallationStatus getInstallationStatus();

    //==========================================================================
    // Installation
    //==========================================================================

    /** Install all factory packs */
    InstallationResult installFactoryLibrary();

    /** Install specific pack */
    bool installPack(const juce::String& packName);

    /** Install from directory (for development) */
    InstallationResult installFromDirectory(const juce::File& sourceDir);

    /** Install from FL Studio Mobile folder */
    InstallationResult installFromFLStudioMobile(const juce::File& flStudioFolder);

    /** Cancel installation */
    void cancelInstallation();

    //==========================================================================
    // Factory Pack Management
    //==========================================================================

    /** Get all available factory packs */
    juce::Array<FactoryPackInfo> getAvailablePacks();

    /** Get installed packs */
    juce::Array<FactoryPackInfo> getInstalledPacks();

    /** Get pack info */
    FactoryPackInfo getPackInfo(const juce::String& packName);

    //==========================================================================
    // Content Packaging (for distribution)
    //==========================================================================

    /** Package samples into .echopack file */
    bool packageSamples(const juce::File& sourceFolder,
                       const juce::File& outputPackFile,
                       const FactoryPackInfo& packInfo);

    /** Extract .echopack file */
    bool extractPack(const juce::File& packFile,
                    const juce::File& targetFolder);

    //==========================================================================
    // Migration from FL Studio Mobile
    //==========================================================================

    /** Convert FL Studio Mobile samples to Echoelmusic Factory Library */
    InstallationResult migrateFLStudioMobileSamples(
        const juce::File& flStudioFolder,
        const juce::String& factoryPackName = "Echoelmusic Essentials");

    //==========================================================================
    // Progress Tracking
    //==========================================================================

    /** Check if installation is running */
    bool isInstalling() const { return installing; }

    /** Get installation progress */
    float getProgress() const { return progress; }

    /** Get current operation */
    juce::String getCurrentOperation() const { return currentOperation; }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(int current, int total)> onProgress;
    std::function<void(const juce::String& operation)> onOperationChange;
    std::function<void(const juce::String& packName, bool success)> onPackInstalled;
    std::function<void(const InstallationResult& result)> onInstallationComplete;
    std::function<void(const juce::String& error)> onError;

private:
    //==========================================================================
    // Core Components
    //==========================================================================

    SampleLibrary* sampleLibrary = nullptr;

    //==========================================================================
    // Installation State
    //==========================================================================

    std::atomic<bool> installing { false };
    std::atomic<float> progress { 0.0f };
    std::atomic<bool> shouldCancel { false };
    juce::String currentOperation;

    //==========================================================================
    // Factory Paths
    //==========================================================================

    juce::File getFactoryLibraryPath();
    juce::File getFactoryPacksPath();
    juce::File getInstalledPacksPath();

    /** Get bundled factory content (shipped with app) */
    juce::File getBundledFactoryContent();

    //==========================================================================
    // Pack Detection
    //==========================================================================

    juce::Array<juce::File> findBundledPacks();
    juce::Array<juce::File> findDownloadedPacks();

    //==========================================================================
    // Installation Helpers
    //==========================================================================

    bool installPackFromArchive(const juce::File& packFile);
    bool installPackFromFolder(const juce::File& folder, const FactoryPackInfo& info);
    bool copyFactorySamples(const juce::File& source, const juce::File& target);
    bool registerFactoryPack(const FactoryPackInfo& info);

    //==========================================================================
    // Metadata
    //==========================================================================

    bool savePackManifest(const juce::File& packFolder, const FactoryPackInfo& info);
    FactoryPackInfo loadPackManifest(const juce::File& packFolder);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FactoryLibraryInstaller)
};

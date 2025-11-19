#include "FLStudioMobileImporter.h"

//==============================================================================
// Constructor / Destructor
//==============================================================================

FLStudioMobileImporter::FLStudioMobileImporter()
{
    DBG("FLStudioMobileImporter: Initialized");
}

FLStudioMobileImporter::~FLStudioMobileImporter()
{
}

//==============================================================================
// Setup
//==============================================================================

void FLStudioMobileImporter::setLibrary(SampleLibrary* library)
{
    pipeline.setLibrary(library);
}

//==============================================================================
// FL Studio Mobile Import
//==============================================================================

SampleImportPipeline::ImportResult FLStudioMobileImporter::importFromFLStudioMobile(
    SampleProcessor::TransformPreset preset)
{
    auto paths = detectFLStudioMobile();

    if (!paths.isValid())
    {
        SampleImportPipeline::ImportResult result;
        result.success = false;
        result.errorMessages.add("FL Studio Mobile not found on this system");
        DBG("FLStudioMobileImporter: FL Studio Mobile not detected");
        return result;
    }

    DBG("FLStudioMobileImporter: Found FL Studio Mobile at: " << paths.appDataFolder.getFullPathName());

    // Import from all detected folders
    auto allFolders = paths.getAllFolders();

    if (allFolders.isEmpty())
    {
        SampleImportPipeline::ImportResult result;
        result.success = false;
        result.errorMessages.add("No audio folders found in FL Studio Mobile");
        return result;
    }

    // Import from first available folder (prioritize Sample Bulk)
    juce::File targetFolder;

    if (paths.sampleBulkFolder.exists())
        targetFolder = paths.sampleBulkFolder;
    else if (paths.mySamplesFolder.exists())
        targetFolder = paths.mySamplesFolder;
    else if (paths.audioClipsFolder.exists())
        targetFolder = paths.audioClipsFolder;
    else
        targetFolder = allFolders[0];

    DBG("FLStudioMobileImporter: Importing from: " << targetFolder.getFullPathName());

    return importFromFolder(targetFolder, preset);
}

SampleImportPipeline::ImportResult FLStudioMobileImporter::importFromFLSubfolder(
    const juce::String& subfolderName,
    SampleProcessor::TransformPreset preset)
{
    auto flFolder = getFLStudioMobileFolder();

    if (!flFolder.exists())
    {
        SampleImportPipeline::ImportResult result;
        result.success = false;
        result.errorMessages.add("FL Studio Mobile folder not found");
        return result;
    }

    auto subfolder = flFolder.getChildFile(subfolderName);

    if (!subfolder.exists())
    {
        SampleImportPipeline::ImportResult result;
        result.success = false;
        result.errorMessages.add("Subfolder not found: " + subfolderName);
        return result;
    }

    return importFromFolder(subfolder, preset);
}

SampleImportPipeline::ImportResult FLStudioMobileImporter::importSampleBulk(
    SampleProcessor::TransformPreset preset)
{
    return importFromFLSubfolder("MySamples/Sample Bulk", preset);
}

//==============================================================================
// Generic Import
//==============================================================================

SampleImportPipeline::ImportResult FLStudioMobileImporter::importFromFolder(
    const juce::String& folderPath,
    SampleProcessor::TransformPreset preset)
{
    juce::File folder(folderPath);
    return importFromFolder(folder, preset);
}

SampleImportPipeline::ImportResult FLStudioMobileImporter::importFromFolder(
    const juce::File& folder,
    SampleProcessor::TransformPreset preset)
{
    if (!folder.exists())
    {
        SampleImportPipeline::ImportResult result;
        result.success = false;
        result.errorMessages.add("Folder not found: " + folder.getFullPathName());
        DBG("FLStudioMobileImporter: Folder not found: " << folder.getFullPathName());
        return result;
    }

    DBG("FLStudioMobileImporter: Importing from folder: " << folder.getFullPathName());

    // Configure import
    SampleImportPipeline::ImportConfig config;
    config.sourceFolder = folder;
    config.preset = preset;
    config.scanRecursive = true;
    config.enableTransformation = true;
    config.autoOrganize = true;
    config.createCollections = true;
    config.trimSilence = true;
    config.generateWaveforms = true;
    config.moveToProcessed = false;        // Don't move from FL Studio Mobile!
    config.preserveOriginal = true;        // Keep originals in FL Studio
    config.collectionName = folder.getFileName() + " Import " +
                           juce::Time::getCurrentTime().toString(false, true);

    return pipeline.importFromFolder(folder, config);
}

//==============================================================================
// Detection
//==============================================================================

FLStudioMobileImporter::FLStudioMobilePaths FLStudioMobileImporter::detectFLStudioMobile()
{
    FLStudioMobilePaths paths;

    // Try to find FL Studio Mobile folder
    auto flFolder = getFLStudioMobileFolder();

    if (!flFolder.exists())
    {
        DBG("FLStudioMobileImporter: FL Studio Mobile folder not found");
        return paths;
    }

    paths.appDataFolder = flFolder;

    // Look for common subfolders
    auto mySamples = flFolder.getChildFile("MySamples");
    if (mySamples.exists())
    {
        paths.mySamplesFolder = mySamples;

        // Check for Sample Bulk subfolder
        auto sampleBulk = mySamples.getChildFile("Sample Bulk");
        if (sampleBulk.exists())
            paths.sampleBulkFolder = sampleBulk;
    }

    auto audioClips = flFolder.getChildFile("Audio Clips");
    if (audioClips.exists())
        paths.audioClipsFolder = audioClips;

    auto recordings = flFolder.getChildFile("Recordings");
    if (recordings.exists())
        paths.recordingsFolder = recordings;

    // Scan for any other folders with audio files
    juce::DirectoryIterator iter(flFolder, false, "*", juce::File::findDirectories);

    while (iter.next())
    {
        auto folder = iter.getFile();

        // Skip already detected folders
        if (folder == paths.mySamplesFolder ||
            folder == paths.audioClipsFolder ||
            folder == paths.recordingsFolder)
            continue;

        // Check if folder contains audio files
        if (countAudioFiles(folder, false) > 0)
        {
            paths.customFolders.add(folder);
        }
    }

    DBG("FLStudioMobileImporter: Detected " << paths.getAllFolders().size() << " audio folders");

    return paths;
}

bool FLStudioMobileImporter::isFLStudioMobileInstalled()
{
    return getFLStudioMobileFolder().exists();
}

juce::File FLStudioMobileImporter::getFLStudioMobileFolder()
{
    // Try common paths first
    auto commonPaths = getCommonFLStudioMobilePaths();

    for (const auto& path : commonPaths)
    {
        if (path.exists())
        {
            DBG("FLStudioMobileImporter: Found FL Studio Mobile at: " << path.getFullPathName());
            return path;
        }
    }

    // Fallback: use default
    return getDefaultFLStudioMobileFolder();
}

juce::Array<juce::File> FLStudioMobileImporter::scanFLStudioMobileAudioFolders()
{
    auto paths = detectFLStudioMobile();
    return paths.getAllFolders();
}

//==============================================================================
// Statistics
//==============================================================================

int FLStudioMobileImporter::getFLStudioMobileSampleCount()
{
    auto paths = detectFLStudioMobile();
    int totalCount = 0;

    for (const auto& folder : paths.getAllFolders())
    {
        totalCount += countAudioFiles(folder, true);
    }

    return totalCount;
}

juce::Array<FLStudioMobileImporter::FolderStats> FLStudioMobileImporter::getFLStudioMobileFolderStats()
{
    juce::Array<FolderStats> stats;
    auto paths = detectFLStudioMobile();

    for (const auto& folder : paths.getAllFolders())
    {
        stats.add(analyzeFolderContents(folder));
    }

    return stats;
}

//==============================================================================
// Platform-Specific Paths
//==============================================================================

juce::File FLStudioMobileImporter::getDefaultFLStudioMobileFolder()
{
#if JUCE_WINDOWS
    // Windows: Documents/Image-Line/FL Studio Mobile
    auto documents = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory);
    return documents.getChildFile("Image-Line/FL Studio Mobile");

#elif JUCE_MAC
    // macOS: ~/Documents/FL Studio Mobile
    auto documents = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory);
    return documents.getChildFile("FL Studio Mobile");

#elif JUCE_ANDROID
    // Android: /sdcard/FL Studio Mobile
    return juce::File("/sdcard/FL Studio Mobile");

#elif JUCE_IOS
    // iOS: App Documents folder
    auto documents = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory);
    return documents.getChildFile("FL Studio Mobile");

#else
    // Linux/Other: ~/Documents/FL Studio Mobile
    auto documents = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory);
    return documents.getChildFile("FL Studio Mobile");
#endif
}

juce::Array<juce::File> FLStudioMobileImporter::getCommonFLStudioMobilePaths()
{
    juce::Array<juce::File> paths;

    // Add default path
    paths.add(getDefaultFLStudioMobileFolder());

#if JUCE_WINDOWS
    // Windows: Check all user drives
    auto documents = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory);
    paths.add(documents.getChildFile("Image-Line/FL Studio Mobile"));
    paths.add(documents.getChildFile("FL Studio Mobile"));

    // Check OneDrive locations
    auto userHome = juce::File::getSpecialLocation(juce::File::userHomeDirectory);
    paths.add(userHome.getChildFile("OneDrive/Documents/Image-Line/FL Studio Mobile"));
    paths.add(userHome.getChildFile("OneDrive/Documents/FL Studio Mobile"));

#elif JUCE_MAC
    // macOS: Check common locations
    auto documents = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory);
    paths.add(documents.getChildFile("FL Studio Mobile"));

    auto userHome = juce::File::getSpecialLocation(juce::File::userHomeDirectory);
    paths.add(userHome.getChildFile("Music/FL Studio Mobile"));
    paths.add(userHome.getChildFile("Documents/FL Studio Mobile"));

    // iCloud Drive
    paths.add(userHome.getChildFile("Library/Mobile Documents/com~apple~CloudDocs/FL Studio Mobile"));

#elif JUCE_ANDROID
    // Android: Check SD card and internal storage
    paths.add(juce::File("/sdcard/FL Studio Mobile"));
    paths.add(juce::File("/storage/emulated/0/FL Studio Mobile"));
    paths.add(juce::File("/mnt/sdcard/FL Studio Mobile"));

#elif JUCE_IOS
    // iOS: Documents folder
    auto documents = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory);
    paths.add(documents.getChildFile("FL Studio Mobile"));

#else
    // Linux: Common locations
    auto documents = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory);
    paths.add(documents.getChildFile("FL Studio Mobile"));

    auto userHome = juce::File::getSpecialLocation(juce::File::userHomeDirectory);
    paths.add(userHome.getChildFile("Music/FL Studio Mobile"));
#endif

    return paths;
}

//==============================================================================
// Helpers
//==============================================================================

FLStudioMobileImporter::FolderStats FLStudioMobileImporter::analyzeFolderContents(
    const juce::File& folder)
{
    FolderStats stats;
    stats.folder = folder;

    if (!folder.exists())
        return stats;

    juce::DirectoryIterator iter(folder, true, "*.wav;*.mp3;*.flac;*.ogg;*.aiff;*.m4a",
                                 juce::File::findFiles);

    juce::HashMap<juce::String, int> typeCount;

    while (iter.next())
    {
        auto file = iter.getFile();
        stats.sampleCount++;
        stats.totalSize += file.getSize();

        // Track file types
        auto ext = file.getFileExtension().toLowerCase();
        int* count = typeCount.contains(ext) ? &typeCount.getReference(ext) : nullptr;
        if (count)
            (*count)++;
        else
            typeCount.set(ext, 1);
    }

    // Convert type counts to string array
    for (auto it = typeCount.begin(); it != typeCount.end(); ++it)
    {
        stats.fileTypes.add(it.getKey() + " (" + juce::String(it.getValue()) + ")");
    }

    return stats;
}

int FLStudioMobileImporter::countAudioFiles(const juce::File& folder, bool recursive)
{
    if (!folder.exists())
        return 0;

    int count = 0;
    juce::DirectoryIterator iter(folder, recursive, "*.wav;*.mp3;*.flac;*.ogg;*.aiff;*.m4a",
                                 juce::File::findFiles);

    while (iter.next())
    {
        count++;
    }

    return count;
}

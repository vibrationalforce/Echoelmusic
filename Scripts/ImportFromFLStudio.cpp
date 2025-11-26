/**
 * ImportFromFLStudio.cpp
 *
 * DIRECT IMPORT FROM FL STUDIO MOBILE
 * Automatically finds your FL Studio Mobile/Sample Bulk folder and imports!
 *
 * No "MySamples" needed - just run this and it finds your samples!
 */

#include "../Sources/Audio/FLStudioMobileImporter.h"
#include "../Sources/Audio/SampleLibrary.h"
#include <JuceHeader.h>
#include <iostream>
#include <iomanip>

void showFLStudioFolders(FLStudioMobileImporter& importer)
{
    std::cout << "\n🔍 Scanning for FL Studio Mobile folders...\n\n";

    auto paths = importer.detectFLStudioMobile();

    if (!paths.isValid())
    {
        std::cout << "❌ FL Studio Mobile not found!\n";
        std::cout << "   Expected locations:\n";

#if JUCE_WINDOWS
        std::cout << "   - C:\\Users\\YourName\\Documents\\Image-Line\\FL Studio Mobile\\\n";
        std::cout << "   - C:\\Users\\YourName\\Documents\\FL Studio Mobile\\\n";
#elif JUCE_MAC
        std::cout << "   - ~/Documents/FL Studio Mobile/\n";
        std::cout << "   - ~/Music/FL Studio Mobile/\n";
#else
        std::cout << "   - ~/Documents/FL Studio Mobile/\n";
#endif

        return;
    }

    std::cout << "✅ Found FL Studio Mobile at:\n";
    std::cout << "   " << paths.appDataFolder.getFullPathName() << "\n\n";

    std::cout << "📁 Audio Folders Found:\n\n";

    auto allFolders = paths.getAllFolders();
    auto folderStats = importer.getFLStudioMobileFolderStats();

    for (int i = 0; i < allFolders.size(); ++i)
    {
        const auto& folder = allFolders[i];
        const auto& stats = folderStats[i];

        std::cout << "  [" << (i + 1) << "] " << folder.getFileName() << "\n";
        std::cout << "      Path: " << folder.getFullPathName() << "\n";
        std::cout << "      Samples: " << stats.sampleCount << "\n";
        std::cout << "      Size: " << juce::File::descriptionOfSizeInBytes(stats.totalSize).toStdString() << "\n";

        if (!stats.fileTypes.isEmpty())
        {
            std::cout << "      Types: " << stats.fileTypes.joinIntoString(", ").toStdString() << "\n";
        }

        std::cout << "\n";
    }

    std::cout << "Total: " << importer.getFLStudioMobileSampleCount() << " samples\n";
}

int main(int argc, char* argv[])
{
    juce::ScopedJuceInitialiser_GUI juceInit;

    std::cout << "========================================\n";
    std::cout << "  FL STUDIO MOBILE → ECHOELMUSIC\n";
    std::cout << "  Direct Import (Auto-Detection)\n";
    std::cout << "========================================\n";

    // Initialize components
    SampleLibrary library;
    FLStudioMobileImporter importer;

    // Set up library
    auto samplesRoot = juce::File::getCurrentWorkingDirectory().getChildFile("Samples");
    library.setRootDirectory(samplesRoot);
    importer.setLibrary(&library);

    // Show available FL Studio folders
    showFLStudioFolders(importer);

    auto paths = importer.detectFLStudioMobile();

    if (!paths.isValid())
    {
        std::cout << "\n👉 Please install FL Studio Mobile or specify folder manually:\n";
        std::cout << "   ./import_fl_studio \"/path/to/your/Sample Bulk\"\n\n";
        return 1;
    }

    // Ask user which folder to import
    std::cout << "\n========================================\n";
    std::cout << "  SELECT IMPORT SOURCE\n";
    std::cout << "========================================\n\n";

    auto allFolders = paths.getAllFolders();

    for (int i = 0; i < allFolders.size(); ++i)
    {
        std::cout << "  " << (i + 1) << ") " << allFolders[i].getFileName() << "\n";
    }

    std::cout << "  0) Custom folder (enter path)\n";
    std::cout << "\nSelect folder (default=1): ";

    int choice = 1;
    if (argc > 1)
    {
        // Folder path provided as argument
        juce::String customPath(argv[1]);
        std::cout << "\nUsing custom folder: " << customPath << "\n\n";

        auto result = importer.importFromFolder(customPath);
        std::cout << result.getSummary().toStdString();
        return result.success ? 0 : 1;
    }
    else
    {
        std::cin >> choice;
    }

    juce::File targetFolder;

    if (choice == 0)
    {
        std::cout << "\nEnter folder path: ";
        std::string pathStr;
        std::cin.ignore();
        std::getline(std::cin, pathStr);

        targetFolder = juce::File(pathStr);

        if (!targetFolder.exists())
        {
            std::cout << "\n❌ Folder not found: " << pathStr << "\n";
            return 1;
        }
    }
    else if (choice > 0 && choice <= allFolders.size())
    {
        targetFolder = allFolders[choice - 1];
    }
    else
    {
        targetFolder = allFolders[0];  // Default to first
    }

    std::cout << "\n✅ Selected: " << targetFolder.getFullPathName() << "\n\n";

    // Choose preset
    std::cout << "========================================\n";
    std::cout << "  TRANSFORMATION PRESET\n";
    std::cout << "========================================\n\n";

    std::cout << "  1) Dark & Deep (Dark Techno)\n";
    std::cout << "  2) Bright & Crispy (Modern House)\n";
    std::cout << "  3) Vintage & Warm (Lo-Fi)\n";
    std::cout << "  4) Glitchy & Modern (Experimental)\n";
    std::cout << "  5) Sub Bass (Bass Heavy)\n";
    std::cout << "  6) Airy & Ethereal (Ambient)\n";
    std::cout << "  7) Aggressive & Punchy (Hard Techno)\n";
    std::cout << "  8) Retro Vaporwave\n";
    std::cout << "  9) Random Light (10-30%)\n";
    std::cout << " 10) Random Medium (30-60%) [RECOMMENDED]\n";
    std::cout << " 11) Random Heavy (60-100%)\n";
    std::cout << "  0) No transformation (just import)\n";
    std::cout << "\nEnter number (default=10): ";

    int presetChoice = 10;
    std::cin >> presetChoice;
    std::cout << "\n";

    SampleProcessor::TransformPreset preset = SampleProcessor::TransformPreset::RandomMedium;

    switch (presetChoice)
    {
        case 1: preset = SampleProcessor::TransformPreset::DarkDeep; break;
        case 2: preset = SampleProcessor::TransformPreset::BrightCrispy; break;
        case 3: preset = SampleProcessor::TransformPreset::VintageWarm; break;
        case 4: preset = SampleProcessor::TransformPreset::GlitchyModern; break;
        case 5: preset = SampleProcessor::TransformPreset::SubBass; break;
        case 6: preset = SampleProcessor::TransformPreset::AiryEthereal; break;
        case 7: preset = SampleProcessor::TransformPreset::AggressivePunchy; break;
        case 8: preset = SampleProcessor::TransformPreset::RetroVaporwave; break;
        case 9: preset = SampleProcessor::TransformPreset::RandomLight; break;
        case 10: preset = SampleProcessor::TransformPreset::RandomMedium; break;
        case 11: preset = SampleProcessor::TransformPreset::RandomHeavy; break;
        default: preset = SampleProcessor::TransformPreset::RandomMedium; break;
    }

    std::string presetName = SampleProcessor::getPresetName(preset).toStdString();
    std::cout << "✅ Selected: " << presetName << "\n\n";

    // Set up progress callbacks
    importer.getPipeline()->onProgress = [](int current, int total)
    {
        float progress = (static_cast<float>(current) / total) * 100.0f;
        std::cout << "\r[" << current << "/" << total << "] "
                  << std::fixed << std::setprecision(1) << progress << "% "
                  << std::flush;
    };

    importer.getPipeline()->onSampleImported = [](const juce::String& sampleID, bool success)
    {
        if (success)
            std::cout << " ✅\n";
        else
            std::cout << " ❌\n";
    };

    importer.getPipeline()->onError = [](const juce::String& error)
    {
        std::cout << "\n❌ Error: " << error << "\n";
    };

    // START IMPORT!
    std::cout << "========================================\n";
    std::cout << "  IMPORTING...\n";
    std::cout << "========================================\n\n";

    auto result = importer.importFromFolder(targetFolder, preset);

    // Show results
    std::cout << "\n\n" << result.getSummary().toStdString();

    // Show library stats
    auto stats = library.getStatistics();
    std::cout << "\n📊 Library Stats (Updated):\n";
    std::cout << "   Total samples: " << stats.totalSamples << "\n";
    std::cout << "   Drums: " << stats.drums << "\n";
    std::cout << "   Bass: " << stats.bass << "\n";
    std::cout << "   Synths: " << stats.synths << "\n";
    std::cout << "   Loops: " << stats.loops << "\n";
    std::cout << "   FX: " << stats.fx << "\n\n";

    std::cout << "✨ Done! Your FL Studio Mobile samples are now in Echoelmusic!\n";
    std::cout << "   Collection: " << result.collectionName << "\n\n";

    return result.success ? 0 : 1;
}

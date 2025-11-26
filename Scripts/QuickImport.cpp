/**
 * QuickImport.cpp
 *
 * ONE-CLICK SAMPLE IMPORT - Ultrathink Style! 🚀
 *
 * Usage:
 * 1. Add samples to MySamples/ folder
 * 2. Run this script
 * 3. Samples are transformed + imported + ready!
 */

#include "../Sources/Audio/SampleImportPipeline.h"
#include <JuceHeader.h>

int main(int argc, char* argv[])
{
    juce::ScopedJuceInitialiser_GUI juceInit;

    std::cout << "========================================\n";
    std::cout << "  ECHOELMUSIC QUICK IMPORT\n";
    std::cout << "  Transform + Import + Ready!\n";
    std::cout << "========================================\n\n";

    // Initialize components
    SampleLibrary library;
    SampleImportPipeline pipeline;

    // Set up library
    auto samplesRoot = juce::File::getCurrentWorkingDirectory().getChildFile("Samples");
    library.setRootDirectory(samplesRoot);

    // Set library for pipeline
    pipeline.setLibrary(&library);

    // Check for samples in MySamples
    auto mySamplesFolder = pipeline.getMySamplesFolder();
    if (!mySamplesFolder.exists())
    {
        std::cout << "❌ MySamples folder not found!\n";
        std::cout << "   Creating: " << mySamplesFolder.getFullPathName() << "\n\n";
        mySamplesFolder.createDirectory();
        std::cout << "👉 Please add your samples to MySamples/ and run again.\n";
        return 1;
    }

    int unimported = pipeline.getUnimportedSampleCount();
    if (unimported == 0)
    {
        std::cout << "✅ No new samples found in MySamples/\n";
        std::cout << "   All samples already imported!\n\n";

        // Show library stats
        auto stats = library.getStatistics();
        std::cout << "📊 Library Stats:\n";
        std::cout << "   Total samples: " << stats.totalSamples << "\n";
        std::cout << "   Drums: " << stats.drums << "\n";
        std::cout << "   Bass: " << stats.bass << "\n";
        std::cout << "   Synths: " << stats.synths << "\n";
        std::cout << "   Loops: " << stats.loops << "\n\n";

        return 0;
    }

    std::cout << "📦 Found " << unimported << " new samples to import\n\n";

    // Choose preset
    std::cout << "Choose transformation preset:\n\n";
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
    std::cout << "  0) No transformation (just import)\n\n";

    std::cout << "Enter number (0-11, default=10): ";
    int choice = 10;
    std::cin >> choice;
    std::cout << "\n";

    // Map choice to preset
    SampleProcessor::TransformPreset preset = SampleProcessor::TransformPreset::RandomMedium;
    bool enableTransformation = true;

    switch (choice)
    {
        case 0: enableTransformation = false; break;
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

    // Configure import
    SampleImportPipeline::ImportConfig config;
    config.sourceFolder = mySamplesFolder;
    config.preset = preset;
    config.enableTransformation = enableTransformation;
    config.autoOrganize = true;
    config.createCollections = true;
    config.trimSilence = true;
    config.generateWaveforms = true;
    config.moveToProcessed = true;
    config.preserveOriginal = false;

    // Set up progress callback
    pipeline.onProgress = [](int current, int total)
    {
        float progress = (static_cast<float>(current) / total) * 100.0f;
        std::cout << "\r[" << current << "/" << total << "] "
                  << std::fixed << std::setprecision(1) << progress << "% "
                  << std::flush;
    };

    pipeline.onSampleImported = [](const juce::String& sampleID, bool success)
    {
        if (success)
            std::cout << " ✅\n";
        else
            std::cout << " ❌\n";
    };

    pipeline.onError = [](const juce::String& error)
    {
        std::cout << "\n❌ Error: " << error << "\n";
    };

    // START IMPORT!
    std::cout << "🚀 Starting import...\n\n";

    auto result = pipeline.importFromFolder(mySamplesFolder, config);

    // Show results
    std::cout << "\n\n" << result.getSummary().toStdString();

    // Show library stats
    auto stats = library.getStatistics();
    std::cout << "\n📊 Updated Library Stats:\n";
    std::cout << "   Total samples: " << stats.totalSamples << "\n";
    std::cout << "   Drums: " << stats.drums << "\n";
    std::cout << "   Bass: " << stats.bass << "\n";
    std::cout << "   Synths: " << stats.synths << "\n";
    std::cout << "   Loops: " << stats.loops << "\n";
    std::cout << "   FX: " << stats.fx << "\n\n";

    // Show import statistics
    auto importStats = pipeline.getStatistics();
    std::cout << "📈 Import Statistics:\n";
    std::cout << importStats.getReport().toStdString();

    std::cout << "\n✨ Done! Your samples are now ready in Echoelmusic!\n";
    std::cout << "   Open the app and check Sample Browser → " << result.collectionName << "\n\n";

    return result.success ? 0 : 1;
}

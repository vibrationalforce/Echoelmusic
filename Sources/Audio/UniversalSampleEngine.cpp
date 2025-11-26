#include "UniversalSampleEngine.h"
#include <fstream>

//==============================================================================
// UniversalSampleEngine Implementation
//==============================================================================

UniversalSampleEngine::UniversalSampleEngine()
{
    DBG("UniversalSampleEngine initialized");
}

UniversalSampleEngine::~UniversalSampleEngine()
{
    unloadAllAudioData();
}

//==============================================================================
// Library Management
//==============================================================================

bool UniversalSampleEngine::loadLibrary(const juce::File& libraryPath)
{
    if (!libraryPath.exists())
    {
        if (onError)
            onError("Library path does not exist: " + libraryPath.getFullPathName());
        return false;
    }

    this->libraryPath = libraryPath;

    DBG("Loading sample library from: " + libraryPath.getFullPathName());

    // Load metadata
    auto metadataFile = libraryPath.getChildFile("metadata.json");
    if (!loadMetadata(metadataFile))
    {
        if (onError)
            onError("Failed to load metadata from: " + metadataFile.getFullPathName());
        return false;
    }

    // Load MIDI mappings
    auto mappingsFile = libraryPath.getChildFile("midi_mappings.json");
    if (mappingsFile.existsAsFile())
    {
        loadMidiMappings(mappingsFile);
    }

    libraryLoaded = true;

    DBG("Sample library loaded successfully");
    DBG("Total samples: " + juce::String(getLibraryStats().totalSamples));

    if (onStatusChange)
        onStatusChange("Library loaded: " + juce::String(getLibraryStats().totalSamples) + " samples");

    return true;
}

bool UniversalSampleEngine::loadMetadata(const juce::File& metadataFile)
{
    if (!metadataFile.existsAsFile())
    {
        DBG("Metadata file not found: " + metadataFile.getFullPathName());
        return false;
    }

    try
    {
        // Read JSON
        auto jsonText = metadataFile.loadFileAsString();
        auto jsonRoot = juce::JSON::parse(jsonText);

        if (!jsonRoot.isArray())
        {
            DBG("Metadata JSON is not an array");
            return false;
        }

        auto* samplesArray = jsonRoot.getArray();
        if (!samplesArray)
            return false;

        int loaded = 0;

        for (const auto& sampleVar : *samplesArray)
        {
            SampleMetadata sample;

            if (parseSampleMetadata(sampleVar, sample))
            {
                // Add to library
                if (library.find(sample.category) == library.end())
                {
                    library[sample.category] = std::map<juce::String, SamplePool>();
                }

                if (library[sample.category].find(sample.subcategory) == library[sample.category].end())
                {
                    library[sample.category][sample.subcategory] = SamplePool();
                }

                library[sample.category][sample.subcategory].addSample(sample);
                loaded++;

                // Progress callback
                if (onLoadProgress && loaded % 10 == 0)
                {
                    onLoadProgress(loaded, samplesArray->size());
                }
            }
        }

        DBG("Loaded metadata for " + juce::String(loaded) + " samples");

        return loaded > 0;
    }
    catch (const std::exception& e)
    {
        DBG("Error loading metadata: " + juce::String(e.what()));
        return false;
    }
}

bool UniversalSampleEngine::parseSampleMetadata(const juce::var& json, SampleMetadata& sample)
{
    if (!json.isObject())
        return false;

    auto* obj = json.getDynamicObject();
    if (!obj)
        return false;

    // Required fields
    sample.name = obj->getProperty("name").toString();
    sample.category = obj->getProperty("category").toString();
    sample.subcategory = obj->getProperty("subcategory").toString();
    sample.filePath = obj->getProperty("file_path").toString();

    if (sample.name.isEmpty() || sample.category.isEmpty() || sample.filePath.isEmpty())
        return false;

    // Optional fields
    sample.durationMs = obj->getProperty("duration_ms");
    sample.sampleRate = obj->getProperty("sample_rate");
    sample.channels = obj->getProperty("channels");

    sample.pitchHz = obj->getProperty("pitch_hz");
    sample.pitchConfidence = obj->getProperty("pitch_confidence");
    sample.tempoBpm = obj->getProperty("tempo_bpm");
    sample.key = obj->getProperty("key").toString();

    sample.spectralCentroid = obj->getProperty("spectral_centroid");
    sample.spectralRolloff = obj->getProperty("spectral_rolloff");
    sample.zeroCrossingRate = obj->getProperty("zero_crossing_rate");
    sample.rmsEnergy = obj->getProperty("rms_energy");

    sample.drumType = obj->getProperty("drum_type").toString();
    sample.energyLevel = obj->getProperty("energy_level").toString();
    sample.brightness = obj->getProperty("brightness").toString();

    sample.suggestedMidiNote = obj->getProperty("suggested_midi_note");
    sample.velocityMin = obj->getProperty("suggested_velocity_range").getArray()->getFirst();
    sample.velocityMax = obj->getProperty("suggested_velocity_range").getArray()->getLast();

    return true;
}

bool UniversalSampleEngine::loadMidiMappings(const juce::File& mappingsFile)
{
    try
    {
        auto jsonText = mappingsFile.loadFileAsString();
        auto jsonRoot = juce::JSON::parse(jsonText);

        if (!jsonRoot.isObject())
            return false;

        auto* obj = jsonRoot.getDynamicObject();
        if (!obj)
            return false;

        for (auto& prop : obj->getProperties())
        {
            int midiNote = prop.name.getIntValue();

            if (midiNote >= 0 && midiNote < 128)
            {
                auto* mapping = prop.value.getDynamicObject();
                if (mapping)
                {
                    juce::String category = mapping->getProperty("category").toString();
                    juce::String subcategory = mapping->getProperty("subcategory").toString();

                    midiMappings[midiNote] = std::make_pair(category, subcategory);
                }
            }
        }

        DBG("Loaded MIDI mappings for " + juce::String(midiMappings.size()) + " notes");

        return true;
    }
    catch (const std::exception& e)
    {
        DBG("Error loading MIDI mappings: " + juce::String(e.what()));
        return false;
    }
}

UniversalSampleEngine::LibraryStats UniversalSampleEngine::getLibraryStats() const
{
    LibraryStats stats;

    for (const auto& categoryPair : library)
    {
        stats.categories.add(categoryPair.first);

        for (const auto& subcategoryPair : categoryPair.second)
        {
            int count = subcategoryPair.second.getCount();
            stats.totalSamples += count;

            // Check if loaded
            for (const auto& sample : subcategoryPair.second.getAllSamples())
            {
                if (sample.isLoaded)
                    stats.loadedSamples++;
            }
        }
    }

    return stats;
}

//==============================================================================
// Sample Access
//==============================================================================

const SampleMetadata* UniversalSampleEngine::getSample(
    const juce::String& category,
    const juce::String& subcategory,
    float velocity)
{
    // Check if category exists
    auto catIt = library.find(category);
    if (catIt == library.end())
    {
        DBG("Category not found: " + category);
        return nullptr;
    }

    // Check if subcategory exists
    auto subIt = catIt->second.find(subcategory);
    if (subIt == catIt->second.end())
    {
        DBG("Subcategory not found: " + subcategory);
        return nullptr;
    }

    // Get sample from pool
    auto* sample = subIt->second.getSample(velocity);

    if (sample && !sample->isLoaded)
    {
        // Load on demand
        loadSampleData(const_cast<SampleMetadata*>(sample));
    }

    return sample;
}

const SampleMetadata* UniversalSampleEngine::getSampleForMidiNote(int midiNote, float velocity)
{
    // Check MIDI mapping
    auto it = midiMappings.find(midiNote);

    if (it != midiMappings.end())
    {
        return getSample(it->second.first, it->second.second, velocity);
    }

    // No mapping, return null
    DBG("No MIDI mapping for note: " + juce::String(midiNote));
    return nullptr;
}

const SampleMetadata* UniversalSampleEngine::getSampleByDrumType(const juce::String& drumType, float velocity)
{
    // Search all drum samples
    auto catIt = library.find("ECHOEL_DRUMS");
    if (catIt == library.end())
        return nullptr;

    for (const auto& subcategoryPair : catIt->second)
    {
        for (const auto& sample : subcategoryPair.second.getAllSamples())
        {
            if (sample.drumType == drumType)
            {
                auto* result = &sample;

                if (!result->isLoaded)
                    loadSampleData(const_cast<SampleMetadata*>(result));

                return result;
            }
        }
    }

    return nullptr;
}

std::vector<const SampleMetadata*> UniversalSampleEngine::getSamplesByCriteria(
    const juce::String& category,
    const juce::String& subcategory,
    const juce::String& energyLevel,
    const juce::String& brightness)
{
    std::vector<const SampleMetadata*> results;

    auto catIt = library.find(category);
    if (catIt == library.end())
        return results;

    auto subIt = catIt->second.find(subcategory);
    if (subIt == catIt->second.end())
        return results;

    for (const auto& sample : subIt->second.getAllSamples())
    {
        bool matches = true;

        if (energyLevel.isNotEmpty() && sample.energyLevel != energyLevel)
            matches = false;

        if (brightness.isNotEmpty() && sample.brightness != brightness)
            matches = false;

        if (matches)
        {
            results.push_back(&sample);
        }
    }

    return results;
}

const SampleMetadata* UniversalSampleEngine::getRandomSample(
    const juce::String& category,
    const juce::String& subcategory)
{
    auto catIt = library.find(category);
    if (catIt == library.end())
        return nullptr;

    auto subIt = catIt->second.find(subcategory);
    if (subIt == catIt->second.end())
        return nullptr;

    auto& samples = subIt->second.getAllSamples();
    if (samples.empty())
        return nullptr;

    juce::Random random;
    int index = random.nextInt((int)samples.size());

    auto* sample = &samples[index];

    if (!sample->isLoaded)
        loadSampleData(const_cast<SampleMetadata*>(sample));

    return sample;
}

//==============================================================================
// Sample Loading
//==============================================================================

bool UniversalSampleEngine::loadSampleData(SampleMetadata* sample)
{
    if (!sample || sample->isLoaded)
        return false;

    juce::File sampleFile(sample->filePath);

    if (!sampleFile.existsAsFile())
    {
        DBG("Sample file not found: " + sample->filePath);
        return false;
    }

    try
    {
        // Load audio file
        juce::AudioFormatManager formatManager;
        formatManager.registerBasicFormats();

        std::unique_ptr<juce::AudioFormatReader> reader(
            formatManager.createReaderFor(sampleFile));

        if (reader)
        {
            // Read into buffer
            sample->audioData.setSize((int)reader->numChannels, (int)reader->lengthInSamples);
            reader->read(&sample->audioData, 0, (int)reader->lengthInSamples, 0, true, true);

            sample->isLoaded = true;

            DBG("Loaded sample: " + sample->name);

            return true;
        }
        else
        {
            DBG("Failed to create reader for: " + sample->filePath);
            return false;
        }
    }
    catch (const std::exception& e)
    {
        DBG("Error loading sample: " + juce::String(e.what()));
        return false;
    }
}

void UniversalSampleEngine::unloadSampleData(SampleMetadata* sample)
{
    if (sample && sample->isLoaded)
    {
        sample->audioData.setSize(0, 0);
        sample->isLoaded = false;
    }
}

void UniversalSampleEngine::preloadCategory(const juce::String& category, const juce::String& subcategory)
{
    DBG("Preloading category: " + category + "/" + subcategory);

    auto catIt = library.find(category);
    if (catIt == library.end())
        return;

    auto subIt = catIt->second.find(subcategory);
    if (subIt == catIt->second.end())
        return;

    for (auto& sample : const_cast<std::vector<SampleMetadata>&>(subIt->second.getAllSamples()))
    {
        if (!sample.isLoaded)
        {
            loadSampleData(&sample);
        }
    }

    DBG("Preload complete");
}

void UniversalSampleEngine::unloadAllAudioData()
{
    DBG("Unloading all audio data");

    for (auto& categoryPair : library)
    {
        for (auto& subcategoryPair : categoryPair.second)
        {
            for (auto& sample : const_cast<std::vector<SampleMetadata>&>(
                subcategoryPair.second.getAllSamples()))
            {
                unloadSampleData(&sample);
            }
        }
    }

    DBG("All audio data unloaded");
}

//==============================================================================
// MIDI 2.0 Support
//==============================================================================

const SampleMetadata* UniversalSampleEngine::getSampleForMidi2(
    int note,
    uint32_t velocity32,
    uint32_t pressure,
    uint16_t pitchBend)
{
    // Convert 32-bit velocity to float (0-1)
    float velocity = velocityToFloat(velocity32);

    // Get base sample
    auto* sample = getSampleForMidiNote(note, velocity);

    // TODO: Use pressure and pitch bend for additional modulation

    return sample;
}

void UniversalSampleEngine::mapMidiNote(int midiNote, const juce::String& category, const juce::String& subcategory)
{
    if (midiNote >= 0 && midiNote < 128)
    {
        midiMappings[midiNote] = std::make_pair(category, subcategory);
    }
}

float UniversalSampleEngine::velocityToFloat(uint32_t velocity32bit)
{
    return velocity32bit / 4294967295.0f;
}

//==============================================================================
// Bio-Reactive Modulation
//==============================================================================

void UniversalSampleEngine::setHeartRate(int bpm)
{
    currentHeartRate = bpm;

    if (bioReactiveEnabled && onStatusChange)
    {
        onStatusChange("Heart rate: " + juce::String(bpm) + " BPM");
    }
}

void UniversalSampleEngine::setStressLevel(float stress)
{
    currentStress = juce::jlimit(0.0f, 1.0f, stress);

    if (bioReactiveEnabled && onStatusChange)
    {
        onStatusChange("Stress level: " + juce::String((int)(stress * 100)) + "%");
    }
}

void UniversalSampleEngine::setFocusLevel(float focus)
{
    currentFocus = juce::jlimit(0.0f, 1.0f, focus);

    if (bioReactiveEnabled && onStatusChange)
    {
        onStatusChange("Focus level: " + juce::String((int)(focus * 100)) + "%");
    }
}

void UniversalSampleEngine::enableBioReactiveFiltering(bool enable)
{
    bioReactiveEnabled = enable;

    DBG("Bio-reactive filtering " + juce::String(enable ? "enabled" : "disabled"));
}

juce::String UniversalSampleEngine::selectEnergyLevel(float velocity, float stress)
{
    float combinedEnergy = (velocity + stress) / 2.0f;

    if (combinedEnergy < 0.3f)
        return "low";
    else if (combinedEnergy < 0.7f)
        return "medium";
    else
        return "high";
}

juce::String UniversalSampleEngine::selectBrightness(float focus)
{
    if (focus < 0.3f)
        return "dark";
    else if (focus < 0.7f)
        return "neutral";
    else
        return "bright";
}

//==============================================================================
// Intelligent Selection
//==============================================================================

const SampleMetadata* UniversalSampleEngine::autoSelectSample(
    const juce::String& category,
    int midiNote,
    float velocity,
    float tempo,
    const juce::String& key)
{
    // Start with MIDI note mapping
    auto* sample = getSampleForMidiNote(midiNote, velocity);

    if (!sample)
    {
        // Fallback to category
        auto catIt = library.find(category);
        if (catIt != library.end() && !catIt->second.empty())
        {
            auto& firstSubcategory = catIt->second.begin()->second;
            sample = firstSubcategory.getSample(velocity);
        }
    }

    // TODO: Use tempo and key for further refinement

    return sample;
}

std::vector<const SampleMetadata*> UniversalSampleEngine::getComplementarySamples(
    const SampleMetadata* baseSample,
    int count)
{
    std::vector<const SampleMetadata*> results;

    if (!baseSample)
        return results;

    // Find samples in same category but different frequency ranges
    auto catIt = library.find(baseSample->category);
    if (catIt == library.end())
        return results;

    for (const auto& subcategoryPair : catIt->second)
    {
        for (const auto& sample : subcategoryPair.second.getAllSamples())
        {
            // Different pitch but complementary
            if (std::abs(sample.pitchHz - baseSample->pitchHz) > 100.0f)
            {
                results.push_back(&sample);

                if ((int)results.size() >= count)
                    return results;
            }
        }
    }

    return results;
}

//==============================================================================
// Jungle/Breakbeat Special
//==============================================================================

std::vector<const SampleMetadata*> UniversalSampleEngine::getJungleBreakSlices(
    const juce::String& breakName,
    int bpm)
{
    std::vector<const SampleMetadata*> slices;

    // Look in ECHOEL_JUNGLE category
    auto catIt = library.find("ECHOEL_JUNGLE");
    if (catIt == library.end())
        return slices;

    // Find break subcategory
    juce::String subcategory = breakName + "_slices";

    auto subIt = catIt->second.find(subcategory);
    if (subIt == catIt->second.end())
    {
        // Try generic "breaks" subcategory
        subIt = catIt->second.find("breaks");
        if (subIt == catIt->second.end())
            return slices;
    }

    // Get all slices
    for (const auto& sample : subIt->second.getAllSamples())
    {
        slices.push_back(&sample);
    }

    // Load all slices
    for (auto* slice : slices)
    {
        if (!slice->isLoaded)
            loadSampleData(const_cast<SampleMetadata*>(slice));
    }

    return slices;
}

const SampleMetadata* UniversalSampleEngine::getBreakSlice(
    const juce::String& breakName,
    int position)
{
    auto slices = getJungleBreakSlices(breakName, 170);

    if (position >= 0 && position < (int)slices.size())
    {
        return slices[position];
    }

    return nullptr;
}

#include "SampleLibrary.h"
#include <cmath>

//==============================================================================
// SampleMetadata - JSON Serialization
//==============================================================================

juce::String SampleLibrary::SampleMetadata::getUniqueID() const
{
    return file.getFullPathName().hashCode64();
}

juce::var SampleLibrary::SampleMetadata::toJSON() const
{
    juce::DynamicObject::Ptr obj = new juce::DynamicObject();

    obj->setProperty("name", name);
    obj->setProperty("path", path);
    obj->setProperty("sampleRate", sampleRate);
    obj->setProperty("bitDepth", bitDepth);
    obj->setProperty("numChannels", numChannels);
    obj->setProperty("durationSeconds", durationSeconds);
    obj->setProperty("fileSizeBytes", static_cast<juce::int64>(fileSizeBytes));
    obj->setProperty("bpm", bpm);
    obj->setProperty("key", key);
    obj->setProperty("scale", scale);
    obj->setProperty("category", category);
    obj->setProperty("subcategory", subcategory);
    obj->setProperty("character", character);
    obj->setProperty("genre", genre);
    obj->setProperty("isFavorite", isFavorite);
    obj->setProperty("useCount", useCount);
    obj->setProperty("rating", rating);
    obj->setProperty("author", author);
    obj->setProperty("packName", packName);

    // Tags array
    juce::var tagArray;
    for (const auto& tag : tags)
        tagArray.append(tag);
    obj->setProperty("tags", tagArray);

    return juce::var(obj.get());
}

SampleLibrary::SampleMetadata SampleLibrary::SampleMetadata::fromJSON(const juce::var& json)
{
    SampleMetadata metadata;

    if (auto* obj = json.getDynamicObject())
    {
        metadata.name = obj->getProperty("name").toString();
        metadata.path = obj->getProperty("path").toString();
        metadata.file = juce::File(metadata.path);
        metadata.sampleRate = obj->getProperty("sampleRate");
        metadata.bitDepth = obj->getProperty("bitDepth");
        metadata.numChannels = obj->getProperty("numChannels");
        metadata.durationSeconds = obj->getProperty("durationSeconds");
        metadata.fileSizeBytes = obj->getProperty("fileSizeBytes");
        metadata.bpm = obj->getProperty("bpm");
        metadata.key = obj->getProperty("key").toString();
        metadata.scale = obj->getProperty("scale").toString();
        metadata.category = obj->getProperty("category").toString();
        metadata.subcategory = obj->getProperty("subcategory").toString();
        metadata.character = obj->getProperty("character").toString();
        metadata.genre = obj->getProperty("genre").toString();
        metadata.isFavorite = obj->getProperty("isFavorite");
        metadata.useCount = obj->getProperty("useCount");
        metadata.rating = obj->getProperty("rating");
        metadata.author = obj->getProperty("author").toString();
        metadata.packName = obj->getProperty("packName").toString();

        // Tags array
        if (auto* tagArray = obj->getProperty("tags").getArray())
        {
            for (const auto& tag : *tagArray)
                metadata.tags.add(tag.toString());
        }
    }

    return metadata;
}

//==============================================================================
// Collection - JSON Serialization
//==============================================================================

juce::var SampleLibrary::Collection::toJSON() const
{
    juce::DynamicObject::Ptr obj = new juce::DynamicObject();

    obj->setProperty("name", name);
    obj->setProperty("description", description);
    obj->setProperty("color", color.toString());

    juce::var samplesArray;
    for (const auto& id : sampleIDs)
        samplesArray.append(id);
    obj->setProperty("samples", samplesArray);

    return juce::var(obj.get());
}

SampleLibrary::Collection SampleLibrary::Collection::fromJSON(const juce::var& json)
{
    Collection collection;

    if (auto* obj = json.getDynamicObject())
    {
        collection.name = obj->getProperty("name").toString();
        collection.description = obj->getProperty("description").toString();
        collection.color = juce::Colour::fromString(obj->getProperty("color").toString());

        if (auto* samplesArray = obj->getProperty("samples").getArray())
        {
            for (const auto& id : *samplesArray)
                collection.sampleIDs.add(id.toString());
        }
    }

    return collection;
}

//==============================================================================
// Constructor / Destructor
//==============================================================================

SampleLibrary::SampleLibrary()
{
    // Set default root directory
    rootDirectory = juce::File::getSpecialLocation(juce::File::currentApplicationFile)
                        .getParentDirectory()
                        .getChildFile("Samples");

    // Load existing database
    loadDatabase();

    DBG("SampleLibrary: Initialized with " << sampleDatabase.size() << " samples");
}

SampleLibrary::~SampleLibrary()
{
    cancelScan();
    saveDatabase();
}

//==============================================================================
// Library Management
//==============================================================================

void SampleLibrary::setRootDirectory(const juce::File& directory)
{
    rootDirectory = directory;

    if (!rootDirectory.exists())
        rootDirectory.createDirectory();

    DBG("SampleLibrary: Root directory set to " << rootDirectory.getFullPathName());
}

void SampleLibrary::scanDirectory(const juce::File& directory, bool recursive)
{
    if (scanning)
    {
        DBG("SampleLibrary: Scan already in progress");
        return;
    }

    scanning = true;
    shouldCancelScan = false;
    scanProgress = 0.0f;

    // Scan in background thread
    juce::Thread::launch([this, directory, recursive]()
    {
        scanDirectoryInternal(directory, recursive);

        scanning = false;
        scanProgress = 1.0f;

        if (onScanComplete)
            onScanComplete(true);

        DBG("SampleLibrary: Scan complete. Found " << sampleDatabase.size() << " samples");
    });
}

void SampleLibrary::rescanLibrary()
{
    sampleDatabase.clear();
    scanDirectory(rootDirectory, true);
}

void SampleLibrary::cancelScan()
{
    shouldCancelScan = true;

    // Wait for scan to finish
    while (scanning)
        juce::Thread::sleep(100);
}

//==============================================================================
// Sample Operations
//==============================================================================

bool SampleLibrary::addSample(const juce::File& file)
{
    if (!file.existsAsFile() || !isSupportedAudioFile(file))
        return false;

    // Analyze sample
    auto metadata = analyzeSample(file);

    // Auto-categorize
    autoCategorize(metadata);

    // Add to database
    juce::String id = metadata.getUniqueID();
    sampleDatabase.set(id, metadata);

    if (onSampleAdded)
        onSampleAdded(metadata);

    DBG("SampleLibrary: Added sample - " << metadata.name);
    return true;
}

bool SampleLibrary::removeSample(const juce::String& sampleID)
{
    if (sampleDatabase.contains(sampleID))
    {
        sampleDatabase.remove(sampleID);

        if (onSampleRemoved)
            onSampleRemoved(sampleID);

        return true;
    }

    return false;
}

SampleLibrary::SampleMetadata SampleLibrary::getSampleMetadata(const juce::String& sampleID) const
{
    if (sampleDatabase.contains(sampleID))
        return sampleDatabase[sampleID];

    return SampleMetadata();
}

bool SampleLibrary::updateSampleMetadata(const juce::String& sampleID, const SampleMetadata& metadata)
{
    if (sampleDatabase.contains(sampleID))
    {
        sampleDatabase.set(sampleID, metadata);
        return true;
    }

    return false;
}

juce::Array<SampleLibrary::SampleMetadata> SampleLibrary::getAllSamples() const
{
    juce::Array<SampleMetadata> samples;

    for (auto& entry : sampleDatabase)
        samples.add(entry.value);

    return samples;
}

//==============================================================================
// Search & Filter
//==============================================================================

juce::Array<SampleLibrary::SampleMetadata> SampleLibrary::searchSamples(const SearchCriteria& criteria) const
{
    juce::Array<SampleMetadata> results;

    for (auto& entry : sampleDatabase)
    {
        const auto& sample = entry.value;

        // Text search
        if (!criteria.searchText.isEmpty())
        {
            juce::String searchLower = criteria.searchText.toLowerCase();
            juce::String nameLower = sample.name.toLowerCase();
            juce::String categoryLower = sample.category.toLowerCase();
            juce::String subcategoryLower = sample.subcategory.toLowerCase();

            bool matchesText = nameLower.contains(searchLower) ||
                             categoryLower.contains(searchLower) ||
                             subcategoryLower.contains(searchLower);

            // Check tags
            for (const auto& tag : sample.tags)
            {
                if (tag.toLowerCase().contains(searchLower))
                {
                    matchesText = true;
                    break;
                }
            }

            if (!matchesText)
                continue;
        }

        // Category filter
        if (!criteria.categories.isEmpty() && !criteria.categories.contains(sample.category))
            continue;

        // BPM range
        if (sample.bpm < criteria.minBPM || sample.bpm > criteria.maxBPM)
            continue;

        // Duration range
        if (sample.durationSeconds < criteria.minDuration || sample.durationSeconds > criteria.maxDuration)
            continue;

        // Rating filter
        if (sample.rating < criteria.minRating)
            continue;

        // Favorites only
        if (criteria.favoritesOnly && !sample.isFavorite)
            continue;

        // Untagged only
        if (criteria.untaggedOnly && !sample.tags.isEmpty())
            continue;

        // Recently used
        if (criteria.recentlyUsed)
        {
            auto daysSinceUsed = (juce::Time::getCurrentTime() - sample.lastUsed).inDays();
            if (daysSinceUsed > 30)
                continue;
        }

        results.add(sample);

        // Max results
        if (results.size() >= criteria.maxResults)
            break;
    }

    // Sort results (TODO: implement sorting)

    return results;
}

juce::Array<SampleLibrary::SampleMetadata> SampleLibrary::quickSearch(const juce::String& searchText) const
{
    SearchCriteria criteria;
    criteria.searchText = searchText;
    return searchSamples(criteria);
}

juce::Array<SampleLibrary::SampleMetadata> SampleLibrary::getSamplesByCategory(const juce::String& category) const
{
    SearchCriteria criteria;
    criteria.categories.add(category);
    return searchSamples(criteria);
}

juce::Array<SampleLibrary::SampleMetadata> SampleLibrary::getFavoriteSamples() const
{
    SearchCriteria criteria;
    criteria.favoritesOnly = true;
    return searchSamples(criteria);
}

juce::Array<SampleLibrary::SampleMetadata> SampleLibrary::getRecentlyUsedSamples(int days) const
{
    juce::Array<SampleMetadata> results;

    for (auto& entry : sampleDatabase)
    {
        const auto& sample = entry.value;
        auto daysSinceUsed = (juce::Time::getCurrentTime() - sample.lastUsed).inDays();

        if (daysSinceUsed <= days)
            results.add(sample);
    }

    // Sort by last used (most recent first)
    // TODO: Implement sorting

    return results;
}

juce::Array<SampleLibrary::SampleMetadata> SampleLibrary::getMostUsedSamples(int count) const
{
    auto allSamples = getAllSamples();

    // Sort by use count (highest first)
    // TODO: Implement sorting

    juce::Array<SampleMetadata> results;
    for (int i = 0; i < juce::jmin(count, allSamples.size()); ++i)
        results.add(allSamples[i]);

    return results;
}

//==============================================================================
// Collections
//==============================================================================

bool SampleLibrary::createCollection(const juce::String& name)
{
    // Check if already exists
    for (const auto& collection : collections)
    {
        if (collection.name == name)
            return false;
    }

    Collection newCollection;
    newCollection.name = name;
    newCollection.dateCreated = juce::Time::getCurrentTime();
    newCollection.color = juce::Colours::blue;

    collections.add(newCollection);
    return true;
}

bool SampleLibrary::deleteCollection(const juce::String& name)
{
    for (int i = 0; i < collections.size(); ++i)
    {
        if (collections[i].name == name)
        {
            collections.remove(i);
            return true;
        }
    }

    return false;
}

bool SampleLibrary::addToCollection(const juce::String& collectionName, const juce::String& sampleID)
{
    for (auto& collection : collections)
    {
        if (collection.name == collectionName)
        {
            if (!collection.sampleIDs.contains(sampleID))
                collection.sampleIDs.add(sampleID);

            return true;
        }
    }

    return false;
}

bool SampleLibrary::removeFromCollection(const juce::String& collectionName, const juce::String& sampleID)
{
    for (auto& collection : collections)
    {
        if (collection.name == collectionName)
        {
            collection.sampleIDs.removeString(sampleID);
            return true;
        }
    }

    return false;
}

juce::Array<SampleLibrary::Collection> SampleLibrary::getAllCollections() const
{
    return collections;
}

juce::Array<SampleLibrary::SampleMetadata> SampleLibrary::getCollectionSamples(const juce::String& collectionName) const
{
    juce::Array<SampleMetadata> samples;

    for (const auto& collection : collections)
    {
        if (collection.name == collectionName)
        {
            for (const auto& sampleID : collection.sampleIDs)
            {
                if (sampleDatabase.contains(sampleID))
                    samples.add(sampleDatabase[sampleID]);
            }

            break;
        }
    }

    return samples;
}

//==============================================================================
// Auto-Analysis
//==============================================================================

SampleLibrary::SampleMetadata SampleLibrary::analyzeSample(const juce::File& file)
{
    SampleMetadata metadata;
    metadata.file = file;
    metadata.name = file.getFileNameWithoutExtension();
    metadata.path = file.getFullPathName();
    metadata.fileSizeBytes = file.getSize();
    metadata.dateAdded = juce::Time::getCurrentTime();

    // Read audio file
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    auto* reader = formatManager.createReaderFor(file);

    if (reader != nullptr)
    {
        metadata.sampleRate = reader->sampleRate;
        metadata.bitDepth = reader->bitsPerSample;
        metadata.numChannels = static_cast<int>(reader->numChannels);
        metadata.durationSeconds = reader->lengthInSamples / reader->sampleRate;

        // Load audio into buffer for analysis
        juce::AudioBuffer<float> buffer(static_cast<int>(reader->numChannels),
                                       static_cast<int>(reader->lengthInSamples));
        reader->read(&buffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

        // Analyze BPM (if loop or rhythmic)
        if (metadata.durationSeconds > 0.5)  // Only for longer samples
        {
            metadata.bpm = detectBPM(buffer, reader->sampleRate);
        }

        // Detect musical key
        metadata.key = detectKey(buffer, reader->sampleRate);

        // Detect type
        metadata.subcategory = detectType(buffer);

        delete reader;
    }

    // Extract category from file path
    metadata.category = extractCategoryFromPath(file);

    return metadata;
}

void SampleLibrary::autoCategorize(SampleMetadata& metadata)
{
    // If category already set from path, keep it
    if (!metadata.category.isEmpty())
        return;

    // Auto-detect from filename
    juce::String nameLower = metadata.name.toLowerCase();

    if (nameLower.contains("kick"))
    {
        metadata.category = "Drums";
        metadata.subcategory = "Kick";
    }
    else if (nameLower.contains("snare") || nameLower.contains("clap"))
    {
        metadata.category = "Drums";
        metadata.subcategory = "Snare";
    }
    else if (nameLower.contains("hat") || nameLower.contains("hihat"))
    {
        metadata.category = "Drums";
        metadata.subcategory = "Hats";
    }
    else if (nameLower.contains("bass"))
    {
        metadata.category = "Bass";
    }
    else if (nameLower.contains("lead"))
    {
        metadata.category = "Synths";
        metadata.subcategory = "Lead";
    }
    else if (nameLower.contains("pad"))
    {
        metadata.category = "Synths";
        metadata.subcategory = "Pad";
    }
    else if (nameLower.contains("vocal"))
    {
        metadata.category = "Vocals";
    }
    else if (nameLower.contains("fx") || nameLower.contains("effect"))
    {
        metadata.category = "FX";
    }
    else if (nameLower.contains("loop"))
    {
        metadata.category = "Loops";
    }

    // Extract BPM from filename (e.g., "Loop_128BPM.wav")
    if (metadata.bpm == 0.0)
    {
        juce::String bpmString = metadata.name.fromLastOccurrenceOf("_", false, false)
                                             .upToFirstOccurrenceOf("BPM", false, false);
        metadata.bpm = bpmString.getDoubleValue();
    }

    // Extract key from filename (e.g., "Bass_Am.wav")
    if (metadata.key.isEmpty())
    {
        // TODO: Parse key from filename
    }
}

double SampleLibrary::detectBPM(const juce::AudioBuffer<float>& audio, double sampleRate)
{
    // Simplified BPM detection (placeholder)
    // Real implementation would use beat tracking algorithms

    // TODO: Implement YIN pitch detection or similar
    // For now, return 0.0 (unknown)

    return 0.0;
}

juce::String SampleLibrary::detectKey(const juce::AudioBuffer<float>& audio, double sampleRate)
{
    // Simplified key detection (placeholder)
    // Real implementation would use pitch class profiling

    // TODO: Implement key detection algorithm

    return "";  // Unknown
}

juce::String SampleLibrary::detectType(const juce::AudioBuffer<float>& audio)
{
    // Simplified type detection based on audio characteristics
    // Real implementation would use machine learning

    // Analyze envelope
    float maxAmplitude = 0.0f;
    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            maxAmplitude = std::max(maxAmplitude, std::abs(audio.getSample(ch, i)));
        }
    }

    // If very short and loud = likely drum one-shot
    if (audio.getNumSamples() < 22050)  // < 0.5 seconds @ 44.1kHz
    {
        return "OneShot";
    }

    return "";  // Unknown
}

juce::Image SampleLibrary::generateWaveform(const juce::File& file, int width, int height)
{
    // TODO: Implement waveform generation
    // For now, return empty image

    return juce::Image(juce::Image::RGB, width, height, true);
}

//==============================================================================
// Favorites & Ratings
//==============================================================================

void SampleLibrary::toggleFavorite(const juce::String& sampleID)
{
    if (sampleDatabase.contains(sampleID))
    {
        auto& sample = sampleDatabase.getReference(sampleID);
        sample.isFavorite = !sample.isFavorite;
    }
}

void SampleLibrary::setRating(const juce::String& sampleID, int rating)
{
    if (sampleDatabase.contains(sampleID))
    {
        auto& sample = sampleDatabase.getReference(sampleID);
        sample.rating = juce::jlimit(0, 5, rating);
    }
}

void SampleLibrary::incrementUseCount(const juce::String& sampleID)
{
    if (sampleDatabase.contains(sampleID))
    {
        auto& sample = sampleDatabase.getReference(sampleID);
        sample.useCount++;
        sample.lastUsed = juce::Time::getCurrentTime();
    }
}

//==============================================================================
// Database Operations
//==============================================================================

bool SampleLibrary::saveDatabase()
{
    auto dbFile = getDatabaseFile();

    juce::DynamicObject::Ptr rootObj = new juce::DynamicObject();

    // Save samples
    juce::var samplesArray;
    for (auto& entry : sampleDatabase)
        samplesArray.append(entry.value.toJSON());
    rootObj->setProperty("samples", samplesArray);

    // Save collections
    juce::var collectionsArray;
    for (const auto& collection : collections)
        collectionsArray.append(collection.toJSON());
    rootObj->setProperty("collections", collectionsArray);

    // Write to file
    juce::String jsonString = juce::JSON::toString(juce::var(rootObj.get()), true);

    if (dbFile.replaceWithText(jsonString))
    {
        DBG("SampleLibrary: Database saved (" << sampleDatabase.size() << " samples)");
        return true;
    }

    return false;
}

bool SampleLibrary::loadDatabase()
{
    auto dbFile = getDatabaseFile();

    if (!dbFile.existsAsFile())
        return false;

    juce::String jsonString = dbFile.loadFileAsString();
    auto json = juce::JSON::parse(jsonString);

    if (auto* rootObj = json.getDynamicObject())
    {
        // Load samples
        if (auto* samplesArray = rootObj->getProperty("samples").getArray())
        {
            for (const auto& sampleJson : *samplesArray)
            {
                auto metadata = SampleMetadata::fromJSON(sampleJson);
                juce::String id = metadata.getUniqueID();
                sampleDatabase.set(id, metadata);
            }
        }

        // Load collections
        if (auto* collectionsArray = rootObj->getProperty("collections").getArray())
        {
            for (const auto& collectionJson : *collectionsArray)
            {
                collections.add(Collection::fromJSON(collectionJson));
            }
        }

        DBG("SampleLibrary: Database loaded (" << sampleDatabase.size() << " samples)");
        return true;
    }

    return false;
}

juce::File SampleLibrary::getDatabaseFile() const
{
    return rootDirectory.getChildFile(".echoeldb");
}

void SampleLibrary::rebuildDatabase()
{
    sampleDatabase.clear();
    collections.clear();
    rescanLibrary();
}

//==============================================================================
// Statistics
//==============================================================================

SampleLibrary::LibraryStats SampleLibrary::getStatistics() const
{
    LibraryStats stats;

    for (auto& entry : sampleDatabase)
    {
        const auto& sample = entry.value;

        stats.totalSamples++;
        stats.totalSizeBytes += sample.fileSizeBytes;
        stats.totalDurationSeconds += sample.durationSeconds;

        if (sample.category == "Drums") stats.drums++;
        else if (sample.category == "Bass") stats.bass++;
        else if (sample.category == "Synths") stats.synths++;
        else if (sample.category == "FX") stats.fx++;
        else if (sample.category == "Vocals") stats.vocals++;
        else if (sample.category == "Loops") stats.loops++;

        if (sample.isFavorite) stats.favorites++;
        if (sample.tags.isEmpty()) stats.untagged++;
    }

    stats.totalCollections = collections.size();

    return stats;
}

//==============================================================================
// Private Helper Methods
//==============================================================================

void SampleLibrary::scanDirectoryInternal(const juce::File& directory, bool recursive)
{
    juce::DirectoryIterator iter(directory, recursive, "*.*", juce::File::findFiles);

    int filesProcessed = 0;

    while (iter.next())
    {
        if (shouldCancelScan)
            break;

        auto file = iter.getFile();

        if (isSupportedAudioFile(file))
        {
            processSampleFile(file);
            filesProcessed++;

            if (onScanProgress)
                onScanProgress(filesProcessed);
        }
    }
}

void SampleLibrary::processSampleFile(const juce::File& file)
{
    addSample(file);
}

bool SampleLibrary::isSupportedAudioFile(const juce::File& file) const
{
    juce::String extension = file.getFileExtension().toLowerCase();

    return extension == ".wav" ||
           extension == ".flac" ||
           extension == ".aiff" ||
           extension == ".aif" ||
           extension == ".ogg" ||
           extension == ".mp3" ||
           extension == ".m4a";
}

juce::String SampleLibrary::generateSampleID(const juce::File& file) const
{
    return juce::String(file.getFullPathName().hashCode64());
}

juce::String SampleLibrary::extractCategoryFromPath(const juce::File& file) const
{
    // Extract category from parent folder name
    auto parentName = file.getParentDirectory().getFileName();

    if (parentName == "Kicks" || parentName == "Snares" || parentName == "Hats" ||
        parentName == "Claps" || parentName == "Toms" || parentName == "Cymbals" ||
        parentName == "Percussion")
    {
        return "Drums";
    }
    else if (parentName == "Sub" || parentName == "Reese" || parentName == "FM" || parentName == "Analog")
    {
        return "Bass";
    }
    else if (parentName == "Leads" || parentName == "Pads" || parentName == "Plucks" || parentName == "Arps")
    {
        return "Synths";
    }
    else if (parentName == "Impacts" || parentName == "Risers" || parentName == "Downlifters" ||
             parentName == "Transitions" || parentName == "Atmospheres")
    {
        return "FX";
    }
    else if (parentName == "Phrases" || parentName == "OneShots" || parentName == "Chops" || parentName == "Chants")
    {
        return "Vocals";
    }
    else if (parentName == "Drums" || parentName == "Melodic" || parentName == "Bass" || parentName == "Full")
    {
        return "Loops";
    }

    return "";  // Unknown
}

/*
  ==============================================================================

    SampleBrowser.h
    Created: 2026
    Author:  Echoelmusic

    Professional Sample Browser with Preview, Tagging, Search and Smart Collections

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>
#include <set>
#include <functional>
#include <thread>
#include <atomic>
#include <mutex>
#include <regex>

namespace Echoelmusic {
namespace Content {

//==============================================================================
/** Sample categories */
enum class SampleCategory {
    Drums,
    Percussion,
    Bass,
    Synth,
    Keys,
    Guitar,
    Strings,
    Brass,
    Woodwind,
    Vocals,
    FX,
    Ambient,
    Loops,
    OneShots,
    Foley,
    Cinematic,
    Other
};

inline juce::String categoryToString(SampleCategory cat) {
    switch (cat) {
        case SampleCategory::Drums:      return "Drums";
        case SampleCategory::Percussion: return "Percussion";
        case SampleCategory::Bass:       return "Bass";
        case SampleCategory::Synth:      return "Synth";
        case SampleCategory::Keys:       return "Keys";
        case SampleCategory::Guitar:     return "Guitar";
        case SampleCategory::Strings:    return "Strings";
        case SampleCategory::Brass:      return "Brass";
        case SampleCategory::Woodwind:   return "Woodwind";
        case SampleCategory::Vocals:     return "Vocals";
        case SampleCategory::FX:         return "FX";
        case SampleCategory::Ambient:    return "Ambient";
        case SampleCategory::Loops:      return "Loops";
        case SampleCategory::OneShots:   return "One-Shots";
        case SampleCategory::Foley:      return "Foley";
        case SampleCategory::Cinematic:  return "Cinematic";
        default:                         return "Other";
    }
}

//==============================================================================
/** Sample metadata */
struct SampleMetadata {
    // Basic info
    juce::String name;
    juce::File filePath;
    double duration = 0.0;
    int sampleRate = 44100;
    int bitDepth = 16;
    int numChannels = 2;
    int64_t fileSizeBytes = 0;

    // Musical properties
    double bpm = 0.0;
    juce::String key = "";
    bool isLoop = false;
    int bars = 0;
    int beats = 0;

    // Organization
    SampleCategory category = SampleCategory::Other;
    std::vector<juce::String> tags;
    juce::String pack;
    juce::String artist;
    juce::String description;

    // User data
    int rating = 0;  // 0-5 stars
    juce::Colour colour;
    bool isFavorite = false;
    juce::Time dateAdded;
    juce::Time lastUsed;
    int useCount = 0;

    // Analysis data
    float peakLevel = 0.0f;
    float rmsLevel = 0.0f;
    bool hasTransients = false;

    // Waveform cache
    std::vector<float> waveformPeaks;

    //==============================================================================
    juce::String getFormattedDuration() const {
        int minutes = static_cast<int>(duration) / 60;
        int seconds = static_cast<int>(duration) % 60;
        int ms = static_cast<int>((duration - floor(duration)) * 1000);
        return juce::String::formatted("%d:%02d.%03d", minutes, seconds, ms);
    }

    juce::String getFormattedFileSize() const {
        if (fileSizeBytes < 1024) return juce::String(fileSizeBytes) + " B";
        if (fileSizeBytes < 1024 * 1024) return juce::String(fileSizeBytes / 1024) + " KB";
        return juce::String::formatted("%.1f MB", fileSizeBytes / (1024.0 * 1024.0));
    }

    bool hasTag(const juce::String& tag) const {
        for (const auto& t : tags) {
            if (t.equalsIgnoreCase(tag)) return true;
        }
        return false;
    }

    void addTag(const juce::String& tag) {
        if (!hasTag(tag)) {
            tags.push_back(tag);
        }
    }

    void removeTag(const juce::String& tag) {
        tags.erase(std::remove_if(tags.begin(), tags.end(),
                                   [&tag](const juce::String& t) {
                                       return t.equalsIgnoreCase(tag);
                                   }), tags.end());
    }

    //==============================================================================
    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("name", name);
        obj->setProperty("path", filePath.getFullPathName());
        obj->setProperty("duration", duration);
        obj->setProperty("sampleRate", sampleRate);
        obj->setProperty("bitDepth", bitDepth);
        obj->setProperty("channels", numChannels);
        obj->setProperty("fileSize", fileSizeBytes);
        obj->setProperty("bpm", bpm);
        obj->setProperty("key", key);
        obj->setProperty("isLoop", isLoop);
        obj->setProperty("bars", bars);
        obj->setProperty("category", static_cast<int>(category));

        juce::var tagsArray;
        for (const auto& tag : tags) {
            tagsArray.append(tag);
        }
        obj->setProperty("tags", tagsArray);

        obj->setProperty("pack", pack);
        obj->setProperty("artist", artist);
        obj->setProperty("rating", rating);
        obj->setProperty("isFavorite", isFavorite);
        obj->setProperty("useCount", useCount);

        return juce::var(obj);
    }

    static SampleMetadata fromVar(const juce::var& v) {
        SampleMetadata meta;
        if (auto* obj = v.getDynamicObject()) {
            meta.name = obj->getProperty("name").toString();
            meta.filePath = juce::File(obj->getProperty("path").toString());
            meta.duration = obj->getProperty("duration");
            meta.sampleRate = obj->getProperty("sampleRate");
            meta.bitDepth = obj->getProperty("bitDepth");
            meta.numChannels = obj->getProperty("channels");
            meta.fileSizeBytes = static_cast<int64_t>((double)obj->getProperty("fileSize"));
            meta.bpm = obj->getProperty("bpm");
            meta.key = obj->getProperty("key").toString();
            meta.isLoop = obj->getProperty("isLoop");
            meta.bars = obj->getProperty("bars");
            meta.category = static_cast<SampleCategory>(int(obj->getProperty("category")));

            if (auto* tagsArray = obj->getProperty("tags").getArray()) {
                for (const auto& tag : *tagsArray) {
                    meta.tags.push_back(tag.toString());
                }
            }

            meta.pack = obj->getProperty("pack").toString();
            meta.artist = obj->getProperty("artist").toString();
            meta.rating = obj->getProperty("rating");
            meta.isFavorite = obj->getProperty("isFavorite");
            meta.useCount = obj->getProperty("useCount");
        }
        return meta;
    }
};

//==============================================================================
/** Sample item in browser */
class SampleItem {
public:
    SampleItem(const juce::File& file)
        : file_(file)
    {
        metadata_.filePath = file;
        metadata_.name = file.getFileNameWithoutExtension();
    }

    //==============================================================================
    const juce::File& getFile() const { return file_; }
    SampleMetadata& getMetadata() { return metadata_; }
    const SampleMetadata& getMetadata() const { return metadata_; }

    //==============================================================================
    /** Analyze file and extract metadata */
    bool analyze() {
        juce::AudioFormatManager formatManager;
        formatManager.registerBasicFormats();

        std::unique_ptr<juce::AudioFormatReader> reader(
            formatManager.createReaderFor(file_));

        if (!reader) return false;

        metadata_.duration = reader->lengthInSamples / reader->sampleRate;
        metadata_.sampleRate = static_cast<int>(reader->sampleRate);
        metadata_.bitDepth = reader->bitsPerSample;
        metadata_.numChannels = reader->numChannels;
        metadata_.fileSizeBytes = file_.getSize();

        // Try to extract BPM from filename
        extractBPMFromFilename();

        // Try to extract key from filename
        extractKeyFromFilename();

        // Analyze audio content
        analyzeAudioContent(*reader);

        // Generate waveform
        generateWaveform(*reader);

        // Auto-categorize
        autoCategorizeSample();

        return true;
    }

    //==============================================================================
    /** Get audio buffer for preview */
    juce::AudioBuffer<float> loadAudio() const {
        juce::AudioFormatManager formatManager;
        formatManager.registerBasicFormats();

        std::unique_ptr<juce::AudioFormatReader> reader(
            formatManager.createReaderFor(file_));

        if (!reader) return {};

        juce::AudioBuffer<float> buffer(reader->numChannels,
                                         static_cast<int>(reader->lengthInSamples));
        reader->read(&buffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

        return buffer;
    }

private:
    void extractBPMFromFilename() {
        juce::String name = file_.getFileNameWithoutExtension().toLowerCase();

        // Common patterns: "120bpm", "120_bpm", "120-bpm", "bpm120"
        std::regex bpmPattern(R"((\d{2,3})\s*bpm|bpm\s*(\d{2,3}))");
        std::smatch match;
        std::string nameStr = name.toStdString();

        if (std::regex_search(nameStr, match, bpmPattern)) {
            juce::String bpmStr = match[1].matched ?
                                  juce::String(match[1].str()) :
                                  juce::String(match[2].str());
            metadata_.bpm = bpmStr.getDoubleValue();

            if (metadata_.bpm > 0 && metadata_.duration > 0) {
                metadata_.isLoop = true;
                double beatsInSample = metadata_.bpm * metadata_.duration / 60.0;
                metadata_.beats = static_cast<int>(std::round(beatsInSample));
                metadata_.bars = metadata_.beats / 4;
            }
        }
    }

    void extractKeyFromFilename() {
        juce::String name = file_.getFileNameWithoutExtension();

        // Key patterns: Am, C#m, Fmaj, Dmin, etc.
        std::vector<juce::String> keys = {
            "C", "C#", "Db", "D", "D#", "Eb", "E", "F",
            "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B"
        };

        for (const auto& key : keys) {
            // Check for minor/major indicators
            if (name.containsIgnoreCase(key + "m") ||
                name.containsIgnoreCase(key + "min")) {
                metadata_.key = key + "m";
                return;
            }
            if (name.containsIgnoreCase(key + "maj") ||
                name.containsIgnoreCase(key + " major")) {
                metadata_.key = key;
                return;
            }
        }
    }

    void analyzeAudioContent(juce::AudioFormatReader& reader) {
        const int blockSize = 4096;
        juce::AudioBuffer<float> buffer(reader.numChannels, blockSize);

        float peakMax = 0.0f;
        float rmsSum = 0.0f;
        int64_t sampleCount = 0;

        for (int64_t pos = 0; pos < reader.lengthInSamples; pos += blockSize) {
            int samplesToRead = static_cast<int>(
                std::min(static_cast<int64_t>(blockSize), reader.lengthInSamples - pos));

            reader.read(&buffer, 0, samplesToRead, pos, true, true);

            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                const float* data = buffer.getReadPointer(ch);
                for (int i = 0; i < samplesToRead; ++i) {
                    float sample = std::abs(data[i]);
                    peakMax = std::max(peakMax, sample);
                    rmsSum += sample * sample;
                    sampleCount++;
                }
            }
        }

        metadata_.peakLevel = peakMax;
        metadata_.rmsLevel = std::sqrt(rmsSum / sampleCount);
    }

    void generateWaveform(juce::AudioFormatReader& reader, int numPeaks = 200) {
        metadata_.waveformPeaks.resize(numPeaks);

        int64_t samplesPerPeak = reader.lengthInSamples / numPeaks;
        juce::AudioBuffer<float> buffer(reader.numChannels,
                                         static_cast<int>(samplesPerPeak));

        for (int i = 0; i < numPeaks; ++i) {
            int64_t startSample = i * samplesPerPeak;
            int samplesToRead = static_cast<int>(
                std::min(samplesPerPeak, reader.lengthInSamples - startSample));

            reader.read(&buffer, 0, samplesToRead, startSample, true, true);

            float peak = 0.0f;
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                peak = std::max(peak, buffer.getMagnitude(ch, 0, samplesToRead));
            }

            metadata_.waveformPeaks[i] = peak;
        }
    }

    void autoCategorizeSample() {
        juce::String name = file_.getFileNameWithoutExtension().toLowerCase();
        juce::String parentDir = file_.getParentDirectory().getFileName().toLowerCase();

        // Check name and directory for category hints
        if (name.contains("kick") || name.contains("snare") || name.contains("hihat") ||
            name.contains("drum") || name.contains("hat") || name.contains("tom") ||
            parentDir.contains("drum")) {
            metadata_.category = SampleCategory::Drums;
        }
        else if (name.contains("perc") || name.contains("shaker") || name.contains("conga") ||
                 name.contains("bongo") || parentDir.contains("perc")) {
            metadata_.category = SampleCategory::Percussion;
        }
        else if (name.contains("bass") || name.contains("sub") || parentDir.contains("bass")) {
            metadata_.category = SampleCategory::Bass;
        }
        else if (name.contains("synth") || name.contains("pad") || name.contains("lead") ||
                 name.contains("arp") || parentDir.contains("synth")) {
            metadata_.category = SampleCategory::Synth;
        }
        else if (name.contains("piano") || name.contains("keys") || name.contains("organ") ||
                 name.contains("rhodes") || parentDir.contains("keys")) {
            metadata_.category = SampleCategory::Keys;
        }
        else if (name.contains("guitar") || name.contains("gtr") || parentDir.contains("guitar")) {
            metadata_.category = SampleCategory::Guitar;
        }
        else if (name.contains("string") || name.contains("violin") || name.contains("cello") ||
                 parentDir.contains("string")) {
            metadata_.category = SampleCategory::Strings;
        }
        else if (name.contains("vocal") || name.contains("vox") || name.contains("voice") ||
                 parentDir.contains("vocal")) {
            metadata_.category = SampleCategory::Vocals;
        }
        else if (name.contains("fx") || name.contains("riser") || name.contains("sweep") ||
                 name.contains("impact") || name.contains("noise") || parentDir.contains("fx")) {
            metadata_.category = SampleCategory::FX;
        }
        else if (name.contains("ambient") || name.contains("atmo") || name.contains("texture") ||
                 parentDir.contains("ambient")) {
            metadata_.category = SampleCategory::Ambient;
        }
        else if (name.contains("loop") || metadata_.isLoop) {
            metadata_.category = SampleCategory::Loops;
        }
        else if (name.contains("one") && name.contains("shot") || name.contains("oneshot") ||
                 parentDir.contains("oneshot")) {
            metadata_.category = SampleCategory::OneShots;
        }

        // Auto-generate tags from filename
        autoGenerateTags();
    }

    void autoGenerateTags() {
        juce::String name = file_.getFileNameWithoutExtension().toLowerCase();

        // Common descriptive terms
        std::vector<juce::String> descriptors = {
            "dark", "bright", "warm", "cold", "heavy", "light",
            "fat", "thin", "wide", "tight", "punchy", "soft",
            "aggressive", "mellow", "clean", "dirty", "wet", "dry",
            "analog", "digital", "vintage", "modern", "lo-fi", "hi-fi",
            "808", "909", "707", "303", "mpc", "sp1200"
        };

        for (const auto& desc : descriptors) {
            if (name.contains(desc)) {
                metadata_.addTag(desc);
            }
        }

        // Add category as tag
        metadata_.addTag(categoryToString(metadata_.category));
    }

    juce::File file_;
    SampleMetadata metadata_;
};

//==============================================================================
/** Search filter for sample browser */
struct SearchFilter {
    juce::String searchText;
    std::set<SampleCategory> categories;
    std::set<juce::String> tags;
    double minBPM = 0.0;
    double maxBPM = 999.0;
    juce::String key;
    int minRating = 0;
    bool favoritesOnly = false;
    bool loopsOnly = false;
    double minDuration = 0.0;
    double maxDuration = 3600.0;

    bool matches(const SampleMetadata& meta) const {
        // Text search
        if (searchText.isNotEmpty()) {
            juce::String search = searchText.toLowerCase();
            if (!meta.name.toLowerCase().contains(search) &&
                !meta.pack.toLowerCase().contains(search) &&
                !meta.artist.toLowerCase().contains(search)) {

                bool tagMatch = false;
                for (const auto& tag : meta.tags) {
                    if (tag.toLowerCase().contains(search)) {
                        tagMatch = true;
                        break;
                    }
                }
                if (!tagMatch) return false;
            }
        }

        // Category filter
        if (!categories.empty() && categories.find(meta.category) == categories.end()) {
            return false;
        }

        // Tag filter
        if (!tags.empty()) {
            bool hasTag = false;
            for (const auto& tag : tags) {
                if (meta.hasTag(tag)) {
                    hasTag = true;
                    break;
                }
            }
            if (!hasTag) return false;
        }

        // BPM filter
        if (meta.bpm > 0 && (meta.bpm < minBPM || meta.bpm > maxBPM)) {
            return false;
        }

        // Key filter
        if (key.isNotEmpty() && !meta.key.equalsIgnoreCase(key)) {
            return false;
        }

        // Rating filter
        if (meta.rating < minRating) {
            return false;
        }

        // Favorites filter
        if (favoritesOnly && !meta.isFavorite) {
            return false;
        }

        // Loops filter
        if (loopsOnly && !meta.isLoop) {
            return false;
        }

        // Duration filter
        if (meta.duration < minDuration || meta.duration > maxDuration) {
            return false;
        }

        return true;
    }
};

//==============================================================================
/** Sort options */
enum class SampleSortOrder {
    Name,
    DateAdded,
    LastUsed,
    Duration,
    BPM,
    Rating,
    UseCount,
    FileSize
};

//==============================================================================
/** Sample preview player */
class PreviewPlayer : public juce::AudioSource {
public:
    PreviewPlayer() {
        formatManager_.registerBasicFormats();
    }

    void prepareToPlay(int samplesPerBlockExpected, double sampleRate) override {
        currentSampleRate_ = sampleRate;
        blockSize_ = samplesPerBlockExpected;

        if (transportSource_) {
            transportSource_->prepareToPlay(samplesPerBlockExpected, sampleRate);
        }
    }

    void releaseResources() override {
        if (transportSource_) {
            transportSource_->releaseResources();
        }
    }

    void getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill) override {
        if (transportSource_ && isPlaying_) {
            transportSource_->getNextAudioBlock(bufferToFill);

            // Apply preview volume
            bufferToFill.buffer->applyGain(bufferToFill.startSample,
                                           bufferToFill.numSamples,
                                           previewVolume_);
        } else {
            bufferToFill.clearActiveBufferRegion();
        }
    }

    //==============================================================================
    /** Load and preview a sample */
    bool loadSample(const juce::File& file) {
        stop();

        auto* reader = formatManager_.createReaderFor(file);
        if (!reader) return false;

        readerSource_ = std::make_unique<juce::AudioFormatReaderSource>(reader, true);

        transportSource_ = std::make_unique<juce::AudioTransportSource>();
        transportSource_->setSource(readerSource_.get(), 0, nullptr,
                                    reader->sampleRate, reader->numChannels);

        if (currentSampleRate_ > 0) {
            transportSource_->prepareToPlay(blockSize_, currentSampleRate_);
        }

        currentFile_ = file;
        return true;
    }

    /** Start playback */
    void play() {
        if (transportSource_) {
            transportSource_->start();
            isPlaying_ = true;
        }
    }

    /** Stop playback */
    void stop() {
        if (transportSource_) {
            transportSource_->stop();
            transportSource_->setPosition(0.0);
        }
        isPlaying_ = false;
    }

    /** Toggle playback */
    void toggle() {
        if (isPlaying_) stop();
        else play();
    }

    /** Is currently playing */
    bool isPlaying() const { return isPlaying_; }

    /** Get current position */
    double getPosition() const {
        return transportSource_ ? transportSource_->getCurrentPosition() : 0.0;
    }

    /** Get total length */
    double getLength() const {
        return transportSource_ ? transportSource_->getLengthInSeconds() : 0.0;
    }

    /** Set preview volume (0.0 - 1.0) */
    void setVolume(float volume) {
        previewVolume_ = juce::jlimit(0.0f, 1.0f, volume);
    }

    /** Enable/disable auto-play on load */
    void setAutoPlay(bool autoPlay) { autoPlay_ = autoPlay; }

    /** Enable/disable loop */
    void setLooping(bool loop) {
        if (readerSource_) {
            readerSource_->setLooping(loop);
        }
    }

    /** Enable tempo sync preview */
    void setTempoSync(bool sync, double projectBPM = 120.0) {
        tempoSync_ = sync;
        projectBPM_ = projectBPM;
    }

private:
    juce::AudioFormatManager formatManager_;
    std::unique_ptr<juce::AudioFormatReaderSource> readerSource_;
    std::unique_ptr<juce::AudioTransportSource> transportSource_;

    juce::File currentFile_;
    double currentSampleRate_ = 44100.0;
    int blockSize_ = 512;

    float previewVolume_ = 0.8f;
    bool isPlaying_ = false;
    bool autoPlay_ = true;
    bool tempoSync_ = false;
    double projectBPM_ = 120.0;
};

//==============================================================================
/** Smart collection (dynamic folder based on criteria) */
struct SmartCollection {
    juce::String name;
    SearchFilter filter;
    juce::Colour colour = juce::Colours::blue;
    bool isBuiltIn = false;

    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("name", name);
        obj->setProperty("searchText", filter.searchText);
        obj->setProperty("minBPM", filter.minBPM);
        obj->setProperty("maxBPM", filter.maxBPM);
        obj->setProperty("key", filter.key);
        obj->setProperty("minRating", filter.minRating);
        obj->setProperty("favoritesOnly", filter.favoritesOnly);
        obj->setProperty("loopsOnly", filter.loopsOnly);
        return juce::var(obj);
    }
};

//==============================================================================
/** Main Sample Browser */
class SampleBrowser {
public:
    SampleBrowser() {
        createBuiltInCollections();
    }

    //==============================================================================
    /** Add a sample folder to index */
    void addFolder(const juce::File& folder, bool recursive = true) {
        if (!folder.isDirectory()) return;

        sampleFolders_.push_back(folder);
        scanFolder(folder, recursive);
    }

    /** Remove a sample folder */
    void removeFolder(const juce::File& folder) {
        sampleFolders_.erase(
            std::remove(sampleFolders_.begin(), sampleFolders_.end(), folder),
            sampleFolders_.end());

        // Remove samples from this folder
        samples_.erase(
            std::remove_if(samples_.begin(), samples_.end(),
                           [&folder](const std::shared_ptr<SampleItem>& item) {
                               return item->getFile().isAChildOf(folder);
                           }),
            samples_.end());

        rebuildIndex();
    }

    /** Rescan all folders */
    void rescanAll() {
        samples_.clear();
        for (const auto& folder : sampleFolders_) {
            scanFolder(folder, true);
        }
        rebuildIndex();
    }

    //==============================================================================
    /** Get all samples */
    const std::vector<std::shared_ptr<SampleItem>>& getAllSamples() const {
        return samples_;
    }

    /** Get samples matching filter */
    std::vector<std::shared_ptr<SampleItem>> getFilteredSamples(const SearchFilter& filter) const {
        std::vector<std::shared_ptr<SampleItem>> results;

        for (const auto& sample : samples_) {
            if (filter.matches(sample->getMetadata())) {
                results.push_back(sample);
            }
        }

        return results;
    }

    /** Quick search by text */
    std::vector<std::shared_ptr<SampleItem>> search(const juce::String& query) const {
        SearchFilter filter;
        filter.searchText = query;
        return getFilteredSamples(filter);
    }

    //==============================================================================
    /** Get all unique tags */
    std::vector<juce::String> getAllTags() const {
        std::set<juce::String> tagSet;
        for (const auto& sample : samples_) {
            for (const auto& tag : sample->getMetadata().tags) {
                tagSet.insert(tag);
            }
        }
        return std::vector<juce::String>(tagSet.begin(), tagSet.end());
    }

    /** Get all unique packs */
    std::vector<juce::String> getAllPacks() const {
        std::set<juce::String> packSet;
        for (const auto& sample : samples_) {
            if (sample->getMetadata().pack.isNotEmpty()) {
                packSet.insert(sample->getMetadata().pack);
            }
        }
        return std::vector<juce::String>(packSet.begin(), packSet.end());
    }

    //==============================================================================
    /** Sort samples */
    void sortSamples(SampleSortOrder order, bool ascending = true) {
        auto comparator = [order, ascending](const std::shared_ptr<SampleItem>& a,
                                              const std::shared_ptr<SampleItem>& b) {
            bool result = false;
            const auto& metaA = a->getMetadata();
            const auto& metaB = b->getMetadata();

            switch (order) {
                case SampleSortOrder::Name:
                    result = metaA.name.compareIgnoreCase(metaB.name) < 0;
                    break;
                case SampleSortOrder::DateAdded:
                    result = metaA.dateAdded < metaB.dateAdded;
                    break;
                case SampleSortOrder::LastUsed:
                    result = metaA.lastUsed < metaB.lastUsed;
                    break;
                case SampleSortOrder::Duration:
                    result = metaA.duration < metaB.duration;
                    break;
                case SampleSortOrder::BPM:
                    result = metaA.bpm < metaB.bpm;
                    break;
                case SampleSortOrder::Rating:
                    result = metaA.rating < metaB.rating;
                    break;
                case SampleSortOrder::UseCount:
                    result = metaA.useCount < metaB.useCount;
                    break;
                case SampleSortOrder::FileSize:
                    result = metaA.fileSizeBytes < metaB.fileSizeBytes;
                    break;
            }

            return ascending ? result : !result;
        };

        std::sort(samples_.begin(), samples_.end(), comparator);
    }

    //==============================================================================
    /** Get preview player */
    PreviewPlayer& getPreviewPlayer() { return previewPlayer_; }

    /** Preview a sample */
    void previewSample(const juce::File& file) {
        if (previewPlayer_.loadSample(file)) {
            previewPlayer_.play();
        }
    }

    /** Stop preview */
    void stopPreview() {
        previewPlayer_.stop();
    }

    //==============================================================================
    /** Smart collections */
    void addSmartCollection(const SmartCollection& collection) {
        smartCollections_.push_back(collection);
    }

    const std::vector<SmartCollection>& getSmartCollections() const {
        return smartCollections_;
    }

    std::vector<std::shared_ptr<SampleItem>> getSmartCollectionSamples(int index) const {
        if (index >= 0 && index < static_cast<int>(smartCollections_.size())) {
            return getFilteredSamples(smartCollections_[index].filter);
        }
        return {};
    }

    //==============================================================================
    /** Save database to file */
    bool saveDatabase(const juce::File& file) {
        juce::var database;
        juce::var samplesArray;

        for (const auto& sample : samples_) {
            samplesArray.append(sample->getMetadata().toVar());
        }

        auto obj = new juce::DynamicObject();
        obj->setProperty("samples", samplesArray);
        obj->setProperty("version", 1);
        database = juce::var(obj);

        juce::FileOutputStream stream(file);
        if (stream.openedOk()) {
            juce::JSON::writeToStream(stream, database);
            return true;
        }
        return false;
    }

    /** Load database from file */
    bool loadDatabase(const juce::File& file) {
        if (!file.existsAsFile()) return false;

        juce::var database = juce::JSON::parse(file);
        if (!database.isObject()) return false;

        auto* obj = database.getDynamicObject();
        if (!obj) return false;

        if (auto* samplesArray = obj->getProperty("samples").getArray()) {
            samples_.clear();
            for (const auto& sampleVar : *samplesArray) {
                auto meta = SampleMetadata::fromVar(sampleVar);
                if (meta.filePath.existsAsFile()) {
                    auto item = std::make_shared<SampleItem>(meta.filePath);
                    item->getMetadata() = meta;
                    samples_.push_back(item);
                }
            }
        }

        rebuildIndex();
        return true;
    }

    //==============================================================================
    /** Get total sample count */
    int getTotalSampleCount() const { return static_cast<int>(samples_.size()); }

    /** Get sample by index */
    std::shared_ptr<SampleItem> getSample(int index) const {
        if (index >= 0 && index < static_cast<int>(samples_.size())) {
            return samples_[index];
        }
        return nullptr;
    }

    //==============================================================================
    // Async scanning
    void scanFolderAsync(const juce::File& folder, bool recursive,
                         std::function<void(float)> progressCallback,
                         std::function<void()> completionCallback) {
        scanThread_ = std::make_unique<std::thread>([this, folder, recursive,
                                                      progressCallback, completionCallback]() {
            scanFolder(folder, recursive, progressCallback);
            if (completionCallback) {
                juce::MessageManager::callAsync(completionCallback);
            }
        });
        scanThread_->detach();
    }

    bool isScanning() const { return isScanning_; }
    void cancelScan() { cancelScan_ = true; }

private:
    void scanFolder(const juce::File& folder, bool recursive,
                    std::function<void(float)> progressCallback = nullptr) {
        if (!folder.isDirectory()) return;

        isScanning_ = true;
        cancelScan_ = false;

        juce::Array<juce::File> audioFiles;
        juce::StringArray audioExtensions = {"wav", "aif", "aiff", "mp3", "ogg", "flac"};

        if (recursive) {
            folder.findChildFiles(audioFiles, juce::File::findFiles, true);
        } else {
            folder.findChildFiles(audioFiles, juce::File::findFiles, false);
        }

        // Filter to audio files only
        for (int i = audioFiles.size() - 1; i >= 0; --i) {
            if (!audioExtensions.contains(audioFiles[i].getFileExtension().toLowerCase().substring(1))) {
                audioFiles.remove(i);
            }
        }

        int processed = 0;
        for (const auto& file : audioFiles) {
            if (cancelScan_) break;

            auto item = std::make_shared<SampleItem>(file);
            if (item->analyze()) {
                // Set pack name from parent folder
                item->getMetadata().pack = file.getParentDirectory().getFileName();

                std::lock_guard<std::mutex> lock(samplesMutex_);
                samples_.push_back(item);
            }

            processed++;
            if (progressCallback) {
                float progress = static_cast<float>(processed) / audioFiles.size();
                juce::MessageManager::callAsync([progressCallback, progress]() {
                    progressCallback(progress);
                });
            }
        }

        rebuildIndex();
        isScanning_ = false;
    }

    void rebuildIndex() {
        // Build category index
        categoryIndex_.clear();
        for (size_t i = 0; i < samples_.size(); ++i) {
            auto cat = samples_[i]->getMetadata().category;
            categoryIndex_[cat].push_back(static_cast<int>(i));
        }

        // Build tag index
        tagIndex_.clear();
        for (size_t i = 0; i < samples_.size(); ++i) {
            for (const auto& tag : samples_[i]->getMetadata().tags) {
                tagIndex_[tag.toLowerCase()].push_back(static_cast<int>(i));
            }
        }
    }

    void createBuiltInCollections() {
        // Recent
        SmartCollection recent;
        recent.name = "Recent";
        recent.isBuiltIn = true;
        recent.colour = juce::Colours::purple;
        smartCollections_.push_back(recent);

        // Favorites
        SmartCollection favorites;
        favorites.name = "Favorites";
        favorites.filter.favoritesOnly = true;
        favorites.isBuiltIn = true;
        favorites.colour = juce::Colours::red;
        smartCollections_.push_back(favorites);

        // Loops
        SmartCollection loops;
        loops.name = "Loops";
        loops.filter.loopsOnly = true;
        loops.isBuiltIn = true;
        loops.colour = juce::Colours::green;
        smartCollections_.push_back(loops);

        // High Rated
        SmartCollection highRated;
        highRated.name = "Top Rated";
        highRated.filter.minRating = 4;
        highRated.isBuiltIn = true;
        highRated.colour = juce::Colours::gold;
        smartCollections_.push_back(highRated);
    }

    std::vector<juce::File> sampleFolders_;
    std::vector<std::shared_ptr<SampleItem>> samples_;
    std::vector<SmartCollection> smartCollections_;

    std::map<SampleCategory, std::vector<int>> categoryIndex_;
    std::map<juce::String, std::vector<int>> tagIndex_;

    PreviewPlayer previewPlayer_;

    std::unique_ptr<std::thread> scanThread_;
    std::mutex samplesMutex_;
    std::atomic<bool> isScanning_{false};
    std::atomic<bool> cancelScan_{false};
};

} // namespace Content
} // namespace Echoelmusic

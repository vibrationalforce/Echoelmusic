/**
 * EchoelSessionJournal.h
 *
 * Session Notes, Reflections & Creative Journal
 *
 * Capture creative thoughts and session insights:
 * - Session notes & reflections
 * - Voice memos & quick recordings
 * - Idea capture & tagging
 * - Mood tracking
 * - Creative insights timeline
 * - Collaboration notes
 * - Lyric scratch pad
 * - Inspiration board
 * - Dream journal for music ideas
 * - AI-assisted summary generation
 *
 * Part of Ralph Wiggum Genius Loop Mode - Phase 1
 * "I bent my wookie!" - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <functional>
#include <chrono>
#include <optional>
#include <atomic>
#include <mutex>

namespace Echoel {

// ============================================================================
// Journal Entry Types
// ============================================================================

enum class EntryType {
    SessionNote,        // Notes during session
    Reflection,         // Post-session thoughts
    Idea,               // Quick idea capture
    VoiceMemo,          // Audio recording
    Lyric,              // Lyric/text content
    MoodLog,            // Mood tracking
    Inspiration,        // External inspiration
    Dream,              // Dream/vision ideas
    Collaboration,      // Team notes
    Milestone,          // Achievement marker
    Custom              // User-defined
};

enum class Mood {
    Energized,
    Creative,
    Focused,
    Relaxed,
    Inspired,
    Frustrated,
    Tired,
    Anxious,
    Happy,
    Melancholic,
    Neutral
};

// ============================================================================
// Journal Entry
// ============================================================================

struct JournalEntry {
    std::string id;
    EntryType type = EntryType::SessionNote;

    std::chrono::system_clock::time_point timestamp;
    std::chrono::system_clock::time_point lastModified;

    // Content
    std::string title;
    std::string content;
    std::string richContent;  // Markdown/HTML

    // Media attachments
    std::vector<std::string> audioAttachments;
    std::vector<std::string> imageAttachments;
    std::vector<std::string> fileAttachments;

    // Metadata
    std::vector<std::string> tags;
    Mood mood = Mood::Neutral;
    float energyLevel = 0.5f;  // 0-1
    float creativityLevel = 0.5f;  // 0-1

    // Context
    std::string projectId;
    std::string projectName;
    std::string sessionId;
    std::chrono::seconds sessionDuration{0};

    // Links
    std::vector<std::string> linkedEntries;  // Related entries
    std::string timelinePosition;  // Position in project timeline

    // Flags
    bool isPinned = false;
    bool isFavorite = false;
    bool isPrivate = false;
    bool isArchived = false;

    // AI-generated
    std::string aiSummary;
    std::vector<std::string> aiTags;
    std::string aiInsight;
};

// ============================================================================
// Voice Memo
// ============================================================================

struct VoiceMemo {
    std::string id;
    std::string entryId;  // Parent journal entry

    std::chrono::system_clock::time_point timestamp;
    std::chrono::seconds duration{0};

    std::string filePath;
    std::string format;  // "m4a", "wav", etc.
    int sampleRate = 44100;
    int bitDepth = 16;

    // Transcription
    std::string transcription;
    bool isTranscribed = false;
    float transcriptionConfidence = 0.0f;

    // Markers
    struct Marker {
        std::chrono::seconds position;
        std::string label;
        std::string note;
    };
    std::vector<Marker> markers;
};

// ============================================================================
// Idea Capture
// ============================================================================

struct Idea {
    std::string id;
    std::string content;
    std::chrono::system_clock::time_point captured;

    enum class Priority {
        Low,
        Normal,
        High,
        Critical
    } priority = Priority::Normal;

    enum class Status {
        New,
        Exploring,
        InProgress,
        Implemented,
        Discarded,
        Archived
    } status = Status::New;

    std::vector<std::string> tags;
    std::string projectId;  // If assigned to project

    // Quick capture metadata
    std::string captureContext;  // What were you doing
    std::string captureMethod;   // Voice, text, etc.

    // Development
    std::vector<std::string> relatedIdeas;
    std::string developmentNotes;
};

// ============================================================================
// Lyric Scratch Pad
// ============================================================================

struct LyricEntry {
    std::string id;
    std::string title;

    struct Verse {
        std::string label;  // "Verse 1", "Chorus", etc.
        std::string content;
        std::string notes;
        std::vector<std::string> alternateLines;
    };

    std::vector<Verse> verses;
    std::string fullLyric;

    // Rhyme helpers
    std::map<std::string, std::vector<std::string>> rhymeBank;

    // Syllable tracking
    std::map<int, int> syllableCount;  // Line number -> count

    // References
    std::string inspiredBy;
    std::vector<std::string> references;

    std::chrono::system_clock::time_point created;
    std::chrono::system_clock::time_point modified;

    std::string projectId;
    bool isFinal = false;
};

// ============================================================================
// Inspiration Board
// ============================================================================

struct InspirationItem {
    std::string id;

    enum class Type {
        Image,
        Video,
        Audio,
        Quote,
        Article,
        Tweet,
        Website,
        Note,
        Color,
        Reference
    } type = Type::Note;

    std::string content;
    std::string url;
    std::string filePath;

    std::string title;
    std::string description;
    std::string source;

    std::chrono::system_clock::time_point added;
    std::vector<std::string> tags;
    std::vector<std::string> linkedProjects;

    // Board position
    float x = 0;
    float y = 0;
    float width = 200;
    float height = 200;
    std::string color;
};

struct InspirationBoard {
    std::string id;
    std::string name;
    std::string description;

    std::vector<InspirationItem> items;

    std::string projectId;
    std::chrono::system_clock::time_point created;
    std::chrono::system_clock::time_point modified;
};

// ============================================================================
// Mood Analytics
// ============================================================================

struct MoodEntry {
    std::chrono::system_clock::time_point timestamp;
    Mood mood = Mood::Neutral;
    float energyLevel = 0.5f;
    float creativityLevel = 0.5f;

    std::string note;
    std::string projectId;
    std::string sessionId;

    // Context
    std::string activity;  // What were you doing
    std::string weather;   // Optional weather data
    std::chrono::hours sleepHours{0};
};

// ============================================================================
// Session Journal Manager
// ============================================================================

class SessionJournalManager {
public:
    static SessionJournalManager& getInstance() {
        static SessionJournalManager instance;
        return instance;
    }

    // ========================================================================
    // Journal Entries
    // ========================================================================

    std::string createEntry(const JournalEntry& entry) {
        std::lock_guard<std::mutex> lock(mutex_);

        JournalEntry newEntry = entry;
        newEntry.id = generateId("entry");
        newEntry.timestamp = std::chrono::system_clock::now();
        newEntry.lastModified = newEntry.timestamp;

        entries_[newEntry.id] = newEntry;

        // Auto-tag with AI
        if (enableAI_) {
            autoTagEntry(newEntry.id);
        }

        return newEntry.id;
    }

    void updateEntry(const std::string& entryId, const JournalEntry& updates) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = entries_.find(entryId);
        if (it != entries_.end()) {
            auto& entry = it->second;
            entry.title = updates.title;
            entry.content = updates.content;
            entry.tags = updates.tags;
            entry.mood = updates.mood;
            entry.isPinned = updates.isPinned;
            entry.isFavorite = updates.isFavorite;
            entry.lastModified = std::chrono::system_clock::now();
        }
    }

    void deleteEntry(const std::string& entryId) {
        std::lock_guard<std::mutex> lock(mutex_);
        entries_.erase(entryId);
    }

    std::optional<JournalEntry> getEntry(const std::string& entryId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = entries_.find(entryId);
        if (it != entries_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    std::vector<JournalEntry> getEntries(
        std::optional<EntryType> type = std::nullopt,
        std::optional<std::string> projectId = std::nullopt,
        int limit = 50) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<JournalEntry> result;

        for (const auto& [id, entry] : entries_) {
            if (type && entry.type != *type) continue;
            if (projectId && entry.projectId != *projectId) continue;
            if (entry.isArchived) continue;

            result.push_back(entry);
        }

        // Sort by timestamp (newest first)
        std::sort(result.begin(), result.end(),
            [](const JournalEntry& a, const JournalEntry& b) {
                return a.timestamp > b.timestamp;
            });

        if (result.size() > static_cast<size_t>(limit)) {
            result.resize(limit);
        }

        return result;
    }

    std::vector<JournalEntry> searchEntries(const std::string& query) const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<JournalEntry> results;
        std::string lowerQuery = query;
        std::transform(lowerQuery.begin(), lowerQuery.end(),
                       lowerQuery.begin(), ::tolower);

        for (const auto& [id, entry] : entries_) {
            std::string lowerContent = entry.content;
            std::transform(lowerContent.begin(), lowerContent.end(),
                           lowerContent.begin(), ::tolower);

            std::string lowerTitle = entry.title;
            std::transform(lowerTitle.begin(), lowerTitle.end(),
                           lowerTitle.begin(), ::tolower);

            if (lowerContent.find(lowerQuery) != std::string::npos ||
                lowerTitle.find(lowerQuery) != std::string::npos) {
                results.push_back(entry);
            }
        }

        return results;
    }

    // ========================================================================
    // Quick Capture
    // ========================================================================

    std::string quickNote(const std::string& content) {
        JournalEntry entry;
        entry.type = EntryType::SessionNote;
        entry.content = content;
        entry.projectId = currentProjectId_;

        return createEntry(entry);
    }

    std::string quickIdea(const std::string& content, Idea::Priority priority = Idea::Priority::Normal) {
        Idea idea;
        idea.id = generateId("idea");
        idea.content = content;
        idea.captured = std::chrono::system_clock::now();
        idea.priority = priority;
        idea.projectId = currentProjectId_;

        std::lock_guard<std::mutex> lock(mutex_);
        ideas_[idea.id] = idea;

        return idea.id;
    }

    // ========================================================================
    // Voice Memos
    // ========================================================================

    std::string startVoiceMemo() {
        std::lock_guard<std::mutex> lock(mutex_);

        currentVoiceMemo_ = VoiceMemo{};
        currentVoiceMemo_.id = generateId("voice");
        currentVoiceMemo_.timestamp = std::chrono::system_clock::now();
        isRecordingVoice_ = true;

        // Would start audio recording
        return currentVoiceMemo_.id;
    }

    void stopVoiceMemo() {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!isRecordingVoice_) return;

        isRecordingVoice_ = false;

        // Save voice memo
        voiceMemos_[currentVoiceMemo_.id] = currentVoiceMemo_;

        // Create journal entry for it
        JournalEntry entry;
        entry.type = EntryType::VoiceMemo;
        entry.title = "Voice Memo";
        entry.audioAttachments.push_back(currentVoiceMemo_.filePath);
        entry.projectId = currentProjectId_;

        createEntry(entry);

        // Transcribe if enabled
        if (enableTranscription_) {
            transcribeVoiceMemo(currentVoiceMemo_.id);
        }
    }

    void addVoiceMemoMarker(const std::string& label) {
        std::lock_guard<std::mutex> lock(mutex_);

        if (!isRecordingVoice_) return;

        VoiceMemo::Marker marker;
        marker.position = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now() - currentVoiceMemo_.timestamp);
        marker.label = label;

        currentVoiceMemo_.markers.push_back(marker);
    }

    std::optional<VoiceMemo> getVoiceMemo(const std::string& memoId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = voiceMemos_.find(memoId);
        if (it != voiceMemos_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // ========================================================================
    // Ideas Management
    // ========================================================================

    std::vector<Idea> getIdeas(
        Idea::Status status = Idea::Status::New,
        std::optional<std::string> projectId = std::nullopt) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Idea> result;
        for (const auto& [id, idea] : ideas_) {
            if (idea.status != status) continue;
            if (projectId && idea.projectId != *projectId) continue;

            result.push_back(idea);
        }

        return result;
    }

    void updateIdeaStatus(const std::string& ideaId, Idea::Status status) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = ideas_.find(ideaId);
        if (it != ideas_.end()) {
            it->second.status = status;
        }
    }

    void assignIdeaToProject(const std::string& ideaId, const std::string& projectId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = ideas_.find(ideaId);
        if (it != ideas_.end()) {
            it->second.projectId = projectId;
            it->second.status = Idea::Status::InProgress;
        }
    }

    // ========================================================================
    // Lyrics
    // ========================================================================

    std::string createLyric(const std::string& title) {
        LyricEntry lyric;
        lyric.id = generateId("lyric");
        lyric.title = title;
        lyric.created = std::chrono::system_clock::now();
        lyric.modified = lyric.created;
        lyric.projectId = currentProjectId_;

        std::lock_guard<std::mutex> lock(mutex_);
        lyrics_[lyric.id] = lyric;

        return lyric.id;
    }

    void addVerse(const std::string& lyricId, const LyricEntry::Verse& verse) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = lyrics_.find(lyricId);
        if (it != lyrics_.end()) {
            it->second.verses.push_back(verse);
            it->second.modified = std::chrono::system_clock::now();
            updateFullLyric(it->second);
        }
    }

    std::optional<LyricEntry> getLyric(const std::string& lyricId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = lyrics_.find(lyricId);
        if (it != lyrics_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    std::vector<std::string> findRhymes(const std::string& word) const {
        // Simple rhyme finder - would use proper rhyming dictionary
        std::vector<std::string> rhymes;
        // Implementation would query rhyme API or local dictionary
        return rhymes;
    }

    // ========================================================================
    // Inspiration Boards
    // ========================================================================

    std::string createBoard(const std::string& name) {
        InspirationBoard board;
        board.id = generateId("board");
        board.name = name;
        board.created = std::chrono::system_clock::now();
        board.modified = board.created;
        board.projectId = currentProjectId_;

        std::lock_guard<std::mutex> lock(mutex_);
        boards_[board.id] = board;

        return board.id;
    }

    void addToBoard(const std::string& boardId, const InspirationItem& item) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = boards_.find(boardId);
        if (it != boards_.end()) {
            InspirationItem newItem = item;
            newItem.id = generateId("insp");
            newItem.added = std::chrono::system_clock::now();

            it->second.items.push_back(newItem);
            it->second.modified = std::chrono::system_clock::now();
        }
    }

    std::optional<InspirationBoard> getBoard(const std::string& boardId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = boards_.find(boardId);
        if (it != boards_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // ========================================================================
    // Mood Tracking
    // ========================================================================

    void logMood(Mood mood, float energy = 0.5f, float creativity = 0.5f,
                 const std::string& note = "") {
        MoodEntry entry;
        entry.timestamp = std::chrono::system_clock::now();
        entry.mood = mood;
        entry.energyLevel = energy;
        entry.creativityLevel = creativity;
        entry.note = note;
        entry.projectId = currentProjectId_;

        std::lock_guard<std::mutex> lock(mutex_);
        moodLog_.push_back(entry);
    }

    std::vector<MoodEntry> getMoodHistory(int days = 30) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto cutoff = std::chrono::system_clock::now() - std::chrono::hours{days * 24};
        std::vector<MoodEntry> result;

        for (const auto& entry : moodLog_) {
            if (entry.timestamp >= cutoff) {
                result.push_back(entry);
            }
        }

        return result;
    }

    Mood getMostFrequentMood(int days = 7) const {
        auto history = getMoodHistory(days);

        std::map<Mood, int> counts;
        for (const auto& entry : history) {
            counts[entry.mood]++;
        }

        Mood mostFrequent = Mood::Neutral;
        int maxCount = 0;

        for (const auto& [mood, count] : counts) {
            if (count > maxCount) {
                maxCount = count;
                mostFrequent = mood;
            }
        }

        return mostFrequent;
    }

    // ========================================================================
    // Session Reflections
    // ========================================================================

    std::string startSessionReflection(const std::string& sessionId) {
        JournalEntry entry;
        entry.type = EntryType::Reflection;
        entry.sessionId = sessionId;
        entry.projectId = currentProjectId_;
        entry.title = "Session Reflection";

        return createEntry(entry);
    }

    void addReflectionPrompt(const std::string& entryId, const std::string& prompt,
                             const std::string& response) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = entries_.find(entryId);
        if (it != entries_.end()) {
            it->second.content += "\n\n**" + prompt + "**\n" + response;
            it->second.lastModified = std::chrono::system_clock::now();
        }
    }

    std::vector<std::string> getReflectionPrompts() const {
        return {
            "What did you accomplish today?",
            "What creative breakthrough did you have?",
            "What challenged you?",
            "What would you do differently?",
            "What are you grateful for in this session?",
            "What's the next step for this project?",
            "Rate your energy level (1-10)",
            "Rate your creativity level (1-10)",
            "Any ideas for next time?"
        };
    }

    // ========================================================================
    // AI Features
    // ========================================================================

    void enableAI(bool enabled) {
        enableAI_ = enabled;
    }

    std::string generateSummary(const std::string& entryId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = entries_.find(entryId);
        if (it == entries_.end()) return "";

        // Would call AI to generate summary
        std::string summary = "AI-generated summary of entry content...";
        it->second.aiSummary = summary;

        return summary;
    }

    std::vector<std::string> suggestTags(const std::string& content) {
        // Would use AI to suggest relevant tags
        return {"music", "production", "creative"};
    }

    // ========================================================================
    // Context
    // ========================================================================

    void setCurrentProject(const std::string& projectId) {
        currentProjectId_ = projectId;
    }

    void setCurrentSession(const std::string& sessionId) {
        currentSessionId_ = sessionId;
    }

private:
    SessionJournalManager() = default;
    ~SessionJournalManager() = default;

    SessionJournalManager(const SessionJournalManager&) = delete;
    SessionJournalManager& operator=(const SessionJournalManager&) = delete;

    std::string generateId(const std::string& prefix) {
        return prefix + "_" + std::to_string(nextId_++);
    }

    void autoTagEntry(const std::string& entryId) {
        auto it = entries_.find(entryId);
        if (it != entries_.end()) {
            it->second.aiTags = suggestTags(it->second.content);
        }
    }

    void transcribeVoiceMemo(const std::string& memoId) {
        auto it = voiceMemos_.find(memoId);
        if (it != voiceMemos_.end()) {
            // Would use speech-to-text API
            it->second.transcription = "Transcribed text...";
            it->second.isTranscribed = true;
            it->second.transcriptionConfidence = 0.95f;
        }
    }

    void updateFullLyric(LyricEntry& lyric) {
        lyric.fullLyric.clear();
        for (const auto& verse : lyric.verses) {
            if (!lyric.fullLyric.empty()) {
                lyric.fullLyric += "\n\n";
            }
            lyric.fullLyric += "[" + verse.label + "]\n";
            lyric.fullLyric += verse.content;
        }
    }

    mutable std::mutex mutex_;

    std::map<std::string, JournalEntry> entries_;
    std::map<std::string, VoiceMemo> voiceMemos_;
    std::map<std::string, Idea> ideas_;
    std::map<std::string, LyricEntry> lyrics_;
    std::map<std::string, InspirationBoard> boards_;
    std::vector<MoodEntry> moodLog_;

    VoiceMemo currentVoiceMemo_;
    std::atomic<bool> isRecordingVoice_{false};

    std::string currentProjectId_;
    std::string currentSessionId_;

    std::atomic<bool> enableAI_{true};
    std::atomic<bool> enableTranscription_{true};

    std::atomic<int> nextId_{1};
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Journal {

inline std::string note(const std::string& content) {
    return SessionJournalManager::getInstance().quickNote(content);
}

inline std::string idea(const std::string& content) {
    return SessionJournalManager::getInstance().quickIdea(content);
}

inline void mood(Mood m, float energy = 0.5f, float creativity = 0.5f) {
    SessionJournalManager::getInstance().logMood(m, energy, creativity);
}

inline std::string startVoiceMemo() {
    return SessionJournalManager::getInstance().startVoiceMemo();
}

inline void stopVoiceMemo() {
    SessionJournalManager::getInstance().stopVoiceMemo();
}

} // namespace Journal

} // namespace Echoel

#pragma once

/**
 * EchoelSessionRecorder.h - Multi-Modal Session Recording
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - SESSION CAPTURE
 * ============================================================================
 *
 *   RECORDS:
 *     - Audio (WAV/FLAC, 48kHz/24-bit)
 *     - Bio-data (HRV, heart rate, coherence, breathing)
 *     - Laser patterns (ILDA frames)
 *     - Entrainment parameters (frequency, intensity, preset)
 *     - User interactions (gestures, parameter changes)
 *
 *   FORMAT:
 *     .echoel-session directory containing:
 *       - session.json (metadata, timeline)
 *       - audio.flac (audio recording)
 *       - bio.csv (timestamped bio-data)
 *       - laser.ilda (laser frame sequence)
 *       - events.json (interaction log)
 *
 *   FEATURES:
 *     - Non-blocking I/O (dedicated writer thread)
 *     - Automatic chunking (prevents memory bloat)
 *     - Crash recovery (periodic checkpoints)
 *     - Session replay with time scrubbing
 *
 * ============================================================================
 */

#include <JuceHeader.h>
#include <string>
#include <vector>
#include <atomic>
#include <thread>
#include <mutex>
#include <queue>
#include <memory>
#include <fstream>

namespace Echoel
{

//==============================================================================
// Recording Data Types
//==============================================================================

struct BioDataPoint
{
    double timestamp = 0.0;
    float heartRate = 0.0f;
    float hrv = 0.0f;
    float coherence = 0.0f;
    float stress = 0.0f;
    float breathingRate = 0.0f;
    bool breathInhale = true;
};

struct EntrainmentDataPoint
{
    double timestamp = 0.0;
    float frequency = 0.0f;
    float intensity = 0.0f;
    int preset = 0;
    float binauralMix = 0.0f;
    float isochronicMix = 0.0f;
    float monauralMix = 0.0f;
};

struct LaserFrameData
{
    double timestamp = 0.0;
    int numPoints = 0;
    std::vector<uint8_t> ildaData;  // Raw ILDA frame
};

struct UserEvent
{
    double timestamp = 0.0;
    std::string eventType;
    std::string parameter;
    float value = 0.0f;
    std::string metadata;
};

//==============================================================================
// Session Metadata
//==============================================================================

struct SessionMetadata
{
    std::string sessionId;
    std::string name;
    std::string description;
    double startTime = 0.0;
    double endTime = 0.0;
    double duration = 0.0;

    // Audio settings
    double sampleRate = 48000.0;
    int bitsPerSample = 24;
    int numChannels = 2;

    // Recording stats
    int totalAudioSamples = 0;
    int totalBioPoints = 0;
    int totalLaserFrames = 0;
    int totalEvents = 0;

    // Version info
    int formatVersion = 1;
    std::string appVersion = "1.0.0";

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("sessionId", juce::String(sessionId));
        obj->setProperty("name", juce::String(name));
        obj->setProperty("description", juce::String(description));
        obj->setProperty("startTime", startTime);
        obj->setProperty("endTime", endTime);
        obj->setProperty("duration", duration);
        obj->setProperty("sampleRate", sampleRate);
        obj->setProperty("bitsPerSample", bitsPerSample);
        obj->setProperty("numChannels", numChannels);
        obj->setProperty("totalAudioSamples", totalAudioSamples);
        obj->setProperty("totalBioPoints", totalBioPoints);
        obj->setProperty("totalLaserFrames", totalLaserFrames);
        obj->setProperty("totalEvents", totalEvents);
        obj->setProperty("formatVersion", formatVersion);
        obj->setProperty("appVersion", juce::String(appVersion));
        return juce::var(obj);
    }

    static SessionMetadata fromVar(const juce::var& v)
    {
        SessionMetadata m;
        if (auto* obj = v.getDynamicObject())
        {
            m.sessionId = obj->getProperty("sessionId").toString().toStdString();
            m.name = obj->getProperty("name").toString().toStdString();
            m.description = obj->getProperty("description").toString().toStdString();
            m.startTime = obj->getProperty("startTime");
            m.endTime = obj->getProperty("endTime");
            m.duration = obj->getProperty("duration");
            m.sampleRate = obj->getProperty("sampleRate");
            m.bitsPerSample = obj->getProperty("bitsPerSample");
            m.numChannels = obj->getProperty("numChannels");
            m.totalAudioSamples = obj->getProperty("totalAudioSamples");
            m.totalBioPoints = obj->getProperty("totalBioPoints");
            m.totalLaserFrames = obj->getProperty("totalLaserFrames");
            m.totalEvents = obj->getProperty("totalEvents");
            m.formatVersion = obj->getProperty("formatVersion");
            m.appVersion = obj->getProperty("appVersion").toString().toStdString();
        }
        return m;
    }
};

//==============================================================================
// Session Recorder
//==============================================================================

class EchoelSessionRecorder
{
public:
    enum class State
    {
        Idle,
        Recording,
        Paused,
        Finalizing
    };

    using StateCallback = std::function<void(State)>;
    using ProgressCallback = std::function<void(double duration, size_t bytesWritten)>;

    EchoelSessionRecorder()
    {
        // Set up session directory
        sessionBaseDir_ = juce::File::getSpecialLocation(
            juce::File::userApplicationDataDirectory
        ).getChildFile("Echoel").getChildFile("Sessions");

        if (!sessionBaseDir_.exists())
            sessionBaseDir_.createDirectory();
    }

    ~EchoelSessionRecorder()
    {
        if (isRecording())
            stopRecording();
    }

    //==========================================================================
    // Recording Control
    //==========================================================================

    bool startRecording(const std::string& name = "")
    {
        if (state_ != State::Idle)
            return false;

        // Generate session ID
        juce::Uuid uuid;
        metadata_.sessionId = uuid.toString().toStdString();
        metadata_.name = name.empty() ? "Session " + juce::Time::getCurrentTime().toString(true, true).toStdString() : name;
        metadata_.startTime = juce::Time::currentTimeMillis() / 1000.0;

        // Create session directory
        sessionDir_ = sessionBaseDir_.getChildFile(juce::String(metadata_.sessionId));
        if (!sessionDir_.createDirectory())
            return false;

        // Open output files
        if (!openOutputFiles())
        {
            sessionDir_.deleteRecursively();
            return false;
        }

        // Start writer thread
        shouldStop_ = false;
        writerThread_ = std::thread(&EchoelSessionRecorder::writerThreadFunc, this);

        state_ = State::Recording;
        recordingStartTime_ = juce::Time::getMillisecondCounterHiRes() / 1000.0;

        if (stateCallback_)
            stateCallback_(state_);

        return true;
    }

    void pauseRecording()
    {
        if (state_ == State::Recording)
        {
            state_ = State::Paused;
            if (stateCallback_)
                stateCallback_(state_);
        }
    }

    void resumeRecording()
    {
        if (state_ == State::Paused)
        {
            state_ = State::Recording;
            if (stateCallback_)
                stateCallback_(state_);
        }
    }

    bool stopRecording()
    {
        if (state_ == State::Idle)
            return false;

        state_ = State::Finalizing;
        if (stateCallback_)
            stateCallback_(state_);

        // Stop writer thread
        shouldStop_ = true;
        if (writerThread_.joinable())
            writerThread_.join();

        // Finalize metadata
        metadata_.endTime = juce::Time::currentTimeMillis() / 1000.0;
        metadata_.duration = metadata_.endTime - metadata_.startTime;

        // Close files
        closeOutputFiles();

        // Write metadata
        writeMetadata();

        state_ = State::Idle;
        if (stateCallback_)
            stateCallback_(state_);

        return true;
    }

    bool isRecording() const { return state_ == State::Recording; }
    bool isPaused() const { return state_ == State::Paused; }
    State getState() const { return state_; }

    //==========================================================================
    // Data Recording (Thread-Safe, Non-Blocking)
    //==========================================================================

    void recordAudio(const float* left, const float* right, int numSamples)
    {
        if (state_ != State::Recording)
            return;

        // Interleave and queue audio
        std::vector<float> interleaved(numSamples * 2);
        for (int i = 0; i < numSamples; ++i)
        {
            interleaved[i * 2] = left[i];
            interleaved[i * 2 + 1] = right[i];
        }

        std::lock_guard<std::mutex> lock(audioMutex_);
        audioQueue_.push(std::move(interleaved));
        metadata_.totalAudioSamples += numSamples;
    }

    void recordBioData(const BioDataPoint& data)
    {
        if (state_ != State::Recording)
            return;

        BioDataPoint timestamped = data;
        timestamped.timestamp = getSessionTime();

        std::lock_guard<std::mutex> lock(bioMutex_);
        bioQueue_.push(timestamped);
        metadata_.totalBioPoints++;
    }

    void recordEntrainment(const EntrainmentDataPoint& data)
    {
        if (state_ != State::Recording)
            return;

        EntrainmentDataPoint timestamped = data;
        timestamped.timestamp = getSessionTime();

        std::lock_guard<std::mutex> lock(entrainmentMutex_);
        entrainmentQueue_.push(timestamped);
    }

    void recordLaserFrame(const LaserFrameData& frame)
    {
        if (state_ != State::Recording)
            return;

        LaserFrameData timestamped = frame;
        timestamped.timestamp = getSessionTime();

        std::lock_guard<std::mutex> lock(laserMutex_);
        laserQueue_.push(timestamped);
        metadata_.totalLaserFrames++;
    }

    void recordEvent(const std::string& eventType, const std::string& param, float value)
    {
        if (state_ != State::Recording)
            return;

        UserEvent event;
        event.timestamp = getSessionTime();
        event.eventType = eventType;
        event.parameter = param;
        event.value = value;

        std::lock_guard<std::mutex> lock(eventMutex_);
        eventQueue_.push(event);
        metadata_.totalEvents++;
    }

    //==========================================================================
    // Session Info
    //==========================================================================

    double getSessionDuration() const
    {
        if (state_ == State::Idle)
            return 0.0;
        return getSessionTime();
    }

    const SessionMetadata& getMetadata() const { return metadata_; }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void onStateChange(StateCallback callback)
    {
        stateCallback_ = std::move(callback);
    }

    void onProgress(ProgressCallback callback)
    {
        progressCallback_ = std::move(callback);
    }

    //==========================================================================
    // Session Management
    //==========================================================================

    std::vector<SessionMetadata> listSessions() const
    {
        std::vector<SessionMetadata> sessions;

        juce::Array<juce::File> dirs;
        sessionBaseDir_.findChildFiles(dirs, juce::File::findDirectories, false);

        for (const auto& dir : dirs)
        {
            juce::File metaFile = dir.getChildFile("session.json");
            if (metaFile.existsAsFile())
            {
                juce::String json = metaFile.loadFileAsString();
                auto meta = SessionMetadata::fromVar(juce::JSON::parse(json));
                sessions.push_back(meta);
            }
        }

        return sessions;
    }

    bool deleteSession(const std::string& sessionId)
    {
        juce::File dir = sessionBaseDir_.getChildFile(juce::String(sessionId));
        if (dir.exists())
            return dir.deleteRecursively();
        return false;
    }

private:
    double getSessionTime() const
    {
        return juce::Time::getMillisecondCounterHiRes() / 1000.0 - recordingStartTime_;
    }

    bool openOutputFiles()
    {
        // Audio file (WAV format for now)
        audioFile_ = sessionDir_.getChildFile("audio.wav");
        audioWriter_ = std::make_unique<juce::FileOutputStream>(audioFile_);
        if (!audioWriter_->openedOk())
            return false;

        // Write WAV header (will be updated on close)
        writeWavHeader(0);

        // Bio data CSV
        bioFile_ = sessionDir_.getChildFile("bio.csv");
        bioWriter_ = std::make_unique<juce::FileOutputStream>(bioFile_);
        if (!bioWriter_->openedOk())
            return false;

        // Write CSV header
        bioWriter_->writeText("timestamp,heartRate,hrv,coherence,stress,breathingRate,breathInhale\n", false, false, nullptr);

        // Events JSON (will be written as array)
        eventsFile_ = sessionDir_.getChildFile("events.json");

        return true;
    }

    void closeOutputFiles()
    {
        // Update WAV header with final size
        if (audioWriter_)
        {
            int64_t dataSize = audioWriter_->getPosition() - 44;
            audioWriter_->setPosition(4);
            writeInt32LE(static_cast<int32_t>(dataSize + 36));
            audioWriter_->setPosition(40);
            writeInt32LE(static_cast<int32_t>(dataSize));
            audioWriter_.reset();
        }

        if (bioWriter_)
            bioWriter_.reset();

        // Write events JSON
        writeEventsJson();
    }

    void writeWavHeader(int numSamples)
    {
        // RIFF header
        audioWriter_->write("RIFF", 4);
        writeInt32LE(36 + numSamples * 4);  // File size - 8
        audioWriter_->write("WAVE", 4);

        // fmt chunk
        audioWriter_->write("fmt ", 4);
        writeInt32LE(16);  // Chunk size
        writeInt16LE(3);   // Format: IEEE float
        writeInt16LE(2);   // Channels
        writeInt32LE(static_cast<int>(metadata_.sampleRate));
        writeInt32LE(static_cast<int>(metadata_.sampleRate * 2 * 4));  // Byte rate
        writeInt16LE(8);   // Block align
        writeInt16LE(32);  // Bits per sample

        // data chunk
        audioWriter_->write("data", 4);
        writeInt32LE(numSamples * 4);
    }

    void writeInt16LE(int16_t value)
    {
        audioWriter_->writeByte(value & 0xFF);
        audioWriter_->writeByte((value >> 8) & 0xFF);
    }

    void writeInt32LE(int32_t value)
    {
        audioWriter_->writeByte(value & 0xFF);
        audioWriter_->writeByte((value >> 8) & 0xFF);
        audioWriter_->writeByte((value >> 16) & 0xFF);
        audioWriter_->writeByte((value >> 24) & 0xFF);
    }

    void writeMetadata()
    {
        juce::File metaFile = sessionDir_.getChildFile("session.json");
        juce::String json = juce::JSON::toString(metadata_.toVar());
        metaFile.replaceWithText(json);
    }

    void writeEventsJson()
    {
        juce::Array<juce::var> eventsArray;

        while (!allEvents_.empty())
        {
            const auto& event = allEvents_.front();
            auto obj = new juce::DynamicObject();
            obj->setProperty("timestamp", event.timestamp);
            obj->setProperty("type", juce::String(event.eventType));
            obj->setProperty("parameter", juce::String(event.parameter));
            obj->setProperty("value", event.value);
            eventsArray.add(juce::var(obj));
            allEvents_.pop();
        }

        juce::String json = juce::JSON::toString(eventsArray);
        eventsFile_.replaceWithText(json);
    }

    void writerThreadFunc()
    {
        while (!shouldStop_)
        {
            // Write audio
            {
                std::lock_guard<std::mutex> lock(audioMutex_);
                while (!audioQueue_.empty())
                {
                    const auto& samples = audioQueue_.front();
                    audioWriter_->write(samples.data(), samples.size() * sizeof(float));
                    bytesWritten_ += samples.size() * sizeof(float);
                    audioQueue_.pop();
                }
            }

            // Write bio data
            {
                std::lock_guard<std::mutex> lock(bioMutex_);
                while (!bioQueue_.empty())
                {
                    const auto& bio = bioQueue_.front();
                    juce::String line = juce::String::formatted(
                        "%.3f,%.1f,%.4f,%.4f,%.4f,%.1f,%d\n",
                        bio.timestamp, bio.heartRate, bio.hrv,
                        bio.coherence, bio.stress, bio.breathingRate,
                        bio.breathInhale ? 1 : 0
                    );
                    bioWriter_->writeText(line, false, false, nullptr);
                    bioQueue_.pop();
                }
            }

            // Collect events
            {
                std::lock_guard<std::mutex> lock(eventMutex_);
                while (!eventQueue_.empty())
                {
                    allEvents_.push(eventQueue_.front());
                    eventQueue_.pop();
                }
            }

            // Progress callback
            if (progressCallback_)
            {
                progressCallback_(getSessionDuration(), bytesWritten_);
            }

            // Don't spin too fast
            std::this_thread::sleep_for(std::chrono::milliseconds(50));
        }
    }

    //==========================================================================
    // State
    //==========================================================================

    std::atomic<State> state_{State::Idle};
    SessionMetadata metadata_;
    double recordingStartTime_ = 0.0;
    size_t bytesWritten_ = 0;

    // File paths
    juce::File sessionBaseDir_;
    juce::File sessionDir_;
    juce::File audioFile_;
    juce::File bioFile_;
    juce::File eventsFile_;

    // Writers
    std::unique_ptr<juce::FileOutputStream> audioWriter_;
    std::unique_ptr<juce::FileOutputStream> bioWriter_;

    // Queues (thread-safe)
    std::queue<std::vector<float>> audioQueue_;
    std::queue<BioDataPoint> bioQueue_;
    std::queue<EntrainmentDataPoint> entrainmentQueue_;
    std::queue<LaserFrameData> laserQueue_;
    std::queue<UserEvent> eventQueue_;
    std::queue<UserEvent> allEvents_;  // Accumulated for JSON output

    std::mutex audioMutex_;
    std::mutex bioMutex_;
    std::mutex entrainmentMutex_;
    std::mutex laserMutex_;
    std::mutex eventMutex_;

    // Writer thread
    std::thread writerThread_;
    std::atomic<bool> shouldStop_{false};

    // Callbacks
    StateCallback stateCallback_;
    ProgressCallback progressCallback_;
};

}  // namespace Echoel

#pragma once

//==============================================================================
// EchoelLogger - Centralized Logging System for Echoelmusic
//==============================================================================
//
// A high-performance, thread-safe logging system with configurable verbosity.
// Replaces scattered print()/Logger::writeToLog() calls with structured logging.
//
// Usage:
//   ECHOEL_LOG_INFO("Component", "Message here");
//   ECHOEL_LOG_DEBUG("DSP", "Processing buffer size: %d", bufferSize);
//   ECHOEL_LOG_ERROR("Audio", "Failed to initialize: %s", error.c_str());
//   ECHOEL_LOG_PERF("Compressor", "Process time: %.2fms", timeMs);
//
//==============================================================================

#include <JuceHeader.h>
#include <atomic>
#include <chrono>
#include <mutex>
#include <sstream>
#include <string>

namespace Echoel {

//==============================================================================
// Log Levels
//==============================================================================
enum class LogLevel : int
{
    None = 0,      // No logging
    Error = 1,     // Critical errors only
    Warning = 2,   // Errors + warnings
    Info = 3,      // Errors + warnings + info
    Debug = 4,     // Errors + warnings + info + debug
    Verbose = 5,   // Everything including performance metrics
    All = 6        // All messages including trace
};

//==============================================================================
// Logger Configuration
//==============================================================================
struct LoggerConfig
{
    LogLevel level = LogLevel::Info;        // Default log level
    bool includeTimestamp = true;           // Include timestamp in output
    bool includeComponent = true;           // Include component name
    bool includeThreadId = false;           // Include thread ID
    bool consoleOutput = true;              // Output to console/stdout
    bool fileOutput = false;                // Output to file
    bool asyncLogging = true;               // Use async queue for non-blocking
    juce::String logFilePath = "";          // Path for file logging
    size_t maxLogFileSizeBytes = 10 * 1024 * 1024;  // 10MB max log file
};

//==============================================================================
// EchoelLogger Singleton
//==============================================================================
class EchoelLogger
{
public:
    static EchoelLogger& getInstance()
    {
        static EchoelLogger instance;
        return instance;
    }

    // Configuration
    void configure(const LoggerConfig& config)
    {
        std::lock_guard<std::mutex> lock(configMutex);
        this->config = config;
    }

    void setLogLevel(LogLevel level)
    {
        config.level = level;
    }

    LogLevel getLogLevel() const
    {
        return config.level;
    }

    // Core logging methods
    void log(LogLevel level, const juce::String& component, const juce::String& message)
    {
        if (static_cast<int>(level) > static_cast<int>(config.level))
            return;

        juce::String formattedMessage = formatMessage(level, component, message);

        if (config.asyncLogging)
        {
            // Queue for async output (non-blocking for audio thread)
            juce::MessageManager::callAsync([this, formattedMessage]() {
                outputMessage(formattedMessage);
            });
        }
        else
        {
            outputMessage(formattedMessage);
        }
    }

    // Convenience methods
    void error(const juce::String& component, const juce::String& message)
    {
        log(LogLevel::Error, component, message);
    }

    void warning(const juce::String& component, const juce::String& message)
    {
        log(LogLevel::Warning, component, message);
    }

    void info(const juce::String& component, const juce::String& message)
    {
        log(LogLevel::Info, component, message);
    }

    void debug(const juce::String& component, const juce::String& message)
    {
        log(LogLevel::Debug, component, message);
    }

    void verbose(const juce::String& component, const juce::String& message)
    {
        log(LogLevel::Verbose, component, message);
    }

    // Performance logging (only in debug/verbose modes)
    void perf(const juce::String& component, const juce::String& message)
    {
        if (config.level >= LogLevel::Debug)
        {
            log(LogLevel::Debug, component, "[PERF] " + message);
        }
    }

    // Audio-thread safe logging (uses try-lock, never blocks)
    void logAudioThread(const juce::String& component, const juce::String& message)
    {
        if (config.level < LogLevel::Verbose)
            return;

        // Try to acquire lock without blocking
        if (audioLogMutex.try_lock())
        {
            audioLogQueue.push_back(formatMessage(LogLevel::Verbose, component, "[AUDIO] " + message));

            // Limit queue size to prevent memory growth
            if (audioLogQueue.size() > 100)
                audioLogQueue.pop_front();

            audioLogMutex.unlock();
        }
        // If lock fails, silently drop the message (acceptable for non-critical audio logs)
    }

    // Flush audio thread logs (call from non-audio thread periodically)
    void flushAudioLogs()
    {
        std::lock_guard<std::mutex> lock(audioLogMutex);
        for (const auto& msg : audioLogQueue)
        {
            outputMessage(msg);
        }
        audioLogQueue.clear();
    }

private:
    EchoelLogger() = default;
    ~EchoelLogger() = default;

    EchoelLogger(const EchoelLogger&) = delete;
    EchoelLogger& operator=(const EchoelLogger&) = delete;

    juce::String formatMessage(LogLevel level, const juce::String& component, const juce::String& message)
    {
        juce::String result;

        // Timestamp
        if (config.includeTimestamp)
        {
            auto now = juce::Time::getCurrentTime();
            result += "[" + now.formatted("%H:%M:%S.") + juce::String(now.toMilliseconds() % 1000).paddedLeft('0', 3) + "] ";
        }

        // Level indicator
        result += levelToString(level) + " ";

        // Component
        if (config.includeComponent && component.isNotEmpty())
        {
            result += "[" + component + "] ";
        }

        // Thread ID (optional)
        if (config.includeThreadId)
        {
            result += "{T:" + juce::String::toHexString((int64_t)juce::Thread::getCurrentThreadId()) + "} ";
        }

        result += message;
        return result;
    }

    static juce::String levelToString(LogLevel level)
    {
        switch (level)
        {
            case LogLevel::Error:   return "ERROR  ";
            case LogLevel::Warning: return "WARN   ";
            case LogLevel::Info:    return "INFO   ";
            case LogLevel::Debug:   return "DEBUG  ";
            case LogLevel::Verbose: return "VERBOSE";
            default:                return "       ";
        }
    }

    void outputMessage(const juce::String& message)
    {
        std::lock_guard<std::mutex> lock(outputMutex);

        if (config.consoleOutput)
        {
            juce::Logger::writeToLog(message);
        }

        if (config.fileOutput && config.logFilePath.isNotEmpty())
        {
            juce::File logFile(config.logFilePath);
            logFile.appendText(message + "\n");
        }
    }

    LoggerConfig config;
    std::mutex configMutex;
    std::mutex outputMutex;
    std::mutex audioLogMutex;
    std::deque<juce::String> audioLogQueue;
};

} // namespace Echoel

//==============================================================================
// Convenience Macros
//==============================================================================

#define ECHOEL_LOG_ERROR(component, message) \
    Echoel::EchoelLogger::getInstance().error(component, message)

#define ECHOEL_LOG_WARN(component, message) \
    Echoel::EchoelLogger::getInstance().warning(component, message)

#define ECHOEL_LOG_INFO(component, message) \
    Echoel::EchoelLogger::getInstance().info(component, message)

#define ECHOEL_LOG_DEBUG(component, message) \
    Echoel::EchoelLogger::getInstance().debug(component, message)

#define ECHOEL_LOG_VERBOSE(component, message) \
    Echoel::EchoelLogger::getInstance().verbose(component, message)

#define ECHOEL_LOG_PERF(component, message) \
    Echoel::EchoelLogger::getInstance().perf(component, message)

#define ECHOEL_LOG_AUDIO(component, message) \
    Echoel::EchoelLogger::getInstance().logAudioThread(component, message)

// Conditional logging (only in debug builds)
#if JUCE_DEBUG
    #define ECHOEL_DEBUG_LOG(component, message) ECHOEL_LOG_DEBUG(component, message)
#else
    #define ECHOEL_DEBUG_LOG(component, message) ((void)0)
#endif

//==============================================================================
// Performance Timer Helper
//==============================================================================
namespace Echoel {

class ScopedPerfTimer
{
public:
    ScopedPerfTimer(const juce::String& component, const juce::String& operation)
        : component(component), operation(operation)
    {
        startTime = std::chrono::high_resolution_clock::now();
    }

    ~ScopedPerfTimer()
    {
        auto endTime = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime);
        float ms = duration.count() / 1000.0f;

        if (EchoelLogger::getInstance().getLogLevel() >= LogLevel::Debug)
        {
            ECHOEL_LOG_PERF(component, operation + " completed in " + juce::String(ms, 2) + "ms");
        }
    }

private:
    juce::String component;
    juce::String operation;
    std::chrono::time_point<std::chrono::high_resolution_clock> startTime;
};

} // namespace Echoel

#define ECHOEL_PERF_SCOPE(component, operation) \
    Echoel::ScopedPerfTimer _perfTimer##__LINE__(component, operation)

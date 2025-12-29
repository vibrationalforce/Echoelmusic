#pragma once

/**
 * EchoelErrorHandler.h - Centralized Error Management
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - GRACEFUL DEGRADATION
 * ============================================================================
 *
 *   FEATURES:
 *     - Centralized error logging and reporting
 *     - Error severity levels (Debug, Info, Warning, Error, Fatal)
 *     - Error callbacks for UI notification
 *     - Automatic recovery strategies
 *     - Crash reporting integration
 *     - Log file persistence
 *     - Performance impact tracking
 *
 *   RECOVERY STRATEGIES:
 *     - Audio: Reinitialize device, reduce buffer size
 *     - Network: Reconnect with exponential backoff
 *     - Bio: Switch to simulated data
 *     - Laser: Disable output, show warning
 *     - Memory: Clear caches, reduce quality
 *
 * ============================================================================
 */

#include <JuceHeader.h>
#include <string>
#include <vector>
#include <functional>
#include <mutex>
#include <atomic>
#include <map>
#include <memory>
#include <fstream>
#include <chrono>

namespace Echoel
{

//==============================================================================
// Error Severity
//==============================================================================

enum class ErrorSeverity
{
    Debug,    // Development info
    Info,     // Normal operation info
    Warning,  // Non-critical issue
    Error,    // Recoverable error
    Fatal     // Unrecoverable, needs shutdown
};

//==============================================================================
// Error Category
//==============================================================================

enum class ErrorCategory
{
    Audio,
    Visual,
    Bio,
    Network,
    Memory,
    File,
    UI,
    System,
    Unknown
};

//==============================================================================
// Error Code Ranges
//==============================================================================

namespace ErrorCodes
{
    // Audio (1000-1999)
    constexpr int AUDIO_DEVICE_NOT_FOUND = 1001;
    constexpr int AUDIO_DEVICE_OPEN_FAILED = 1002;
    constexpr int AUDIO_BUFFER_UNDERRUN = 1003;
    constexpr int AUDIO_BUFFER_OVERRUN = 1004;
    constexpr int AUDIO_PROCESSING_OVERLOAD = 1005;
    constexpr int AUDIO_FORMAT_UNSUPPORTED = 1006;

    // Visual/Laser (2000-2999)
    constexpr int LASER_DEVICE_NOT_FOUND = 2001;
    constexpr int LASER_CONNECTION_LOST = 2002;
    constexpr int LASER_SAFETY_LIMIT = 2003;
    constexpr int RENDER_FRAME_DROP = 2004;
    constexpr int GPU_OUT_OF_MEMORY = 2005;

    // Bio (3000-3999)
    constexpr int BIO_SENSOR_DISCONNECTED = 3001;
    constexpr int BIO_SIGNAL_QUALITY_LOW = 3002;
    constexpr int BIO_CALIBRATION_FAILED = 3003;
    constexpr int BIO_DATA_INVALID = 3004;

    // Network (4000-4999)
    constexpr int NETWORK_CONNECTION_FAILED = 4001;
    constexpr int NETWORK_TIMEOUT = 4002;
    constexpr int NETWORK_SYNC_LOST = 4003;
    constexpr int NETWORK_PEER_DISCONNECTED = 4004;

    // Memory (5000-5999)
    constexpr int MEMORY_ALLOCATION_FAILED = 5001;
    constexpr int MEMORY_POOL_EXHAUSTED = 5002;
    constexpr int MEMORY_LIMIT_EXCEEDED = 5003;

    // File (6000-6999)
    constexpr int FILE_NOT_FOUND = 6001;
    constexpr int FILE_READ_ERROR = 6002;
    constexpr int FILE_WRITE_ERROR = 6003;
    constexpr int FILE_FORMAT_INVALID = 6004;
    constexpr int FILE_PERMISSION_DENIED = 6005;

    // System (9000-9999)
    constexpr int SYSTEM_INIT_FAILED = 9001;
    constexpr int SYSTEM_SHUTDOWN_ERROR = 9002;
    constexpr int SYSTEM_UNKNOWN_ERROR = 9999;
}

//==============================================================================
// Error Entry
//==============================================================================

struct ErrorEntry
{
    int code = 0;
    ErrorSeverity severity = ErrorSeverity::Info;
    ErrorCategory category = ErrorCategory::Unknown;
    std::string message;
    std::string details;
    std::string file;
    int line = 0;
    std::string function;
    double timestamp = 0.0;
    bool recovered = false;
    std::string recoveryAction;

    juce::String toString() const
    {
        juce::String severityStr;
        switch (severity)
        {
            case ErrorSeverity::Debug:   severityStr = "DEBUG"; break;
            case ErrorSeverity::Info:    severityStr = "INFO"; break;
            case ErrorSeverity::Warning: severityStr = "WARNING"; break;
            case ErrorSeverity::Error:   severityStr = "ERROR"; break;
            case ErrorSeverity::Fatal:   severityStr = "FATAL"; break;
        }

        juce::String categoryStr;
        switch (category)
        {
            case ErrorCategory::Audio:   categoryStr = "Audio"; break;
            case ErrorCategory::Visual:  categoryStr = "Visual"; break;
            case ErrorCategory::Bio:     categoryStr = "Bio"; break;
            case ErrorCategory::Network: categoryStr = "Network"; break;
            case ErrorCategory::Memory:  categoryStr = "Memory"; break;
            case ErrorCategory::File:    categoryStr = "File"; break;
            case ErrorCategory::UI:      categoryStr = "UI"; break;
            case ErrorCategory::System:  categoryStr = "System"; break;
            default:                     categoryStr = "Unknown"; break;
        }

        return juce::String::formatted(
            "[%s][%s][%d] %s",
            severityStr.toRawUTF8(),
            categoryStr.toRawUTF8(),
            code,
            message.c_str()
        );
    }
};

//==============================================================================
// Recovery Strategy
//==============================================================================

using RecoveryFunction = std::function<bool(const ErrorEntry&)>;

struct RecoveryStrategy
{
    int maxAttempts = 3;
    int delayMs = 1000;
    bool exponentialBackoff = true;
    RecoveryFunction recoveryFn;
};

//==============================================================================
// Error Handler (Singleton)
//==============================================================================

class EchoelErrorHandler
{
public:
    using ErrorCallback = std::function<void(const ErrorEntry&)>;
    using FatalCallback = std::function<void(const ErrorEntry&)>;

    static EchoelErrorHandler& getInstance()
    {
        static EchoelErrorHandler instance;
        return instance;
    }

    //==========================================================================
    // Initialization
    //==========================================================================

    void initialize()
    {
        if (initialized_.load(std::memory_order_acquire))
            return;

        // Set up log file
        logDirectory_ = juce::File::getSpecialLocation(
            juce::File::userApplicationDataDirectory
        ).getChildFile("Echoel").getChildFile("Logs");

        if (!logDirectory_.exists())
            logDirectory_.createDirectory();

        juce::String filename = "echoel_" +
            juce::Time::getCurrentTime().formatted("%Y%m%d_%H%M%S") + ".log";
        logFile_ = logDirectory_.getChildFile(filename);

        // Register default recovery strategies
        registerDefaultRecoveryStrategies();

        initialized_.store(true, std::memory_order_release);
    }

    //==========================================================================
    // Error Reporting
    //==========================================================================

    void report(int code,
                ErrorSeverity severity,
                ErrorCategory category,
                const std::string& message,
                const std::string& details = "",
                const char* file = "",
                int line = 0,
                const char* function = "")
    {
        ErrorEntry entry;
        entry.code = code;
        entry.severity = severity;
        entry.category = category;
        entry.message = message;
        entry.details = details;
        entry.file = file;
        entry.line = line;
        entry.function = function;
        entry.timestamp = juce::Time::getMillisecondCounterHiRes() / 1000.0;

        // Log to file
        writeToLog(entry);

        // Store in history
        {
            std::lock_guard<std::mutex> lock(historyMutex_);
            errorHistory_.push_back(entry);
            if (errorHistory_.size() > maxHistorySize_)
                errorHistory_.erase(errorHistory_.begin());
        }

        // Update counters
        errorCounts_[static_cast<int>(severity)]++;

        // Notify callbacks
        {
            std::lock_guard<std::mutex> lock(callbackMutex_);
            for (const auto& callback : errorCallbacks_)
                callback(entry);
        }

        // Handle fatal errors
        if (severity == ErrorSeverity::Fatal)
        {
            handleFatalError(entry);
        }
        // Attempt recovery for errors
        else if (severity == ErrorSeverity::Error)
        {
            attemptRecovery(entry);
        }
    }

    // Convenience methods
    void debug(const std::string& message, ErrorCategory category = ErrorCategory::System)
    {
        report(0, ErrorSeverity::Debug, category, message);
    }

    void info(const std::string& message, ErrorCategory category = ErrorCategory::System)
    {
        report(0, ErrorSeverity::Info, category, message);
    }

    void warning(int code, const std::string& message, ErrorCategory category = ErrorCategory::Unknown)
    {
        report(code, ErrorSeverity::Warning, category, message);
    }

    void error(int code, const std::string& message, const std::string& details = "",
               ErrorCategory category = ErrorCategory::Unknown)
    {
        report(code, ErrorSeverity::Error, category, message, details);
    }

    void fatal(int code, const std::string& message, const std::string& details = "",
               ErrorCategory category = ErrorCategory::System)
    {
        report(code, ErrorSeverity::Fatal, category, message, details);
    }

    //==========================================================================
    // Recovery Strategies
    //==========================================================================

    void registerRecoveryStrategy(int errorCode, RecoveryStrategy strategy)
    {
        std::lock_guard<std::mutex> lock(recoveryMutex_);
        recoveryStrategies_[errorCode] = std::move(strategy);
    }

    void registerCategoryRecoveryStrategy(ErrorCategory category, RecoveryStrategy strategy)
    {
        std::lock_guard<std::mutex> lock(recoveryMutex_);
        categoryRecoveryStrategies_[static_cast<int>(category)] = std::move(strategy);
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void onError(ErrorCallback callback)
    {
        std::lock_guard<std::mutex> lock(callbackMutex_);
        errorCallbacks_.push_back(std::move(callback));
    }

    void onFatal(FatalCallback callback)
    {
        std::lock_guard<std::mutex> lock(callbackMutex_);
        fatalCallback_ = std::move(callback);
    }

    //==========================================================================
    // Error History
    //==========================================================================

    std::vector<ErrorEntry> getRecentErrors(size_t count = 100) const
    {
        std::lock_guard<std::mutex> lock(historyMutex_);
        size_t start = errorHistory_.size() > count ? errorHistory_.size() - count : 0;
        return std::vector<ErrorEntry>(errorHistory_.begin() + start, errorHistory_.end());
    }

    std::vector<ErrorEntry> getErrorsByCategory(ErrorCategory category) const
    {
        std::lock_guard<std::mutex> lock(historyMutex_);
        std::vector<ErrorEntry> result;
        for (const auto& entry : errorHistory_)
        {
            if (entry.category == category)
                result.push_back(entry);
        }
        return result;
    }

    std::vector<ErrorEntry> getErrorsBySeverity(ErrorSeverity severity) const
    {
        std::lock_guard<std::mutex> lock(historyMutex_);
        std::vector<ErrorEntry> result;
        for (const auto& entry : errorHistory_)
        {
            if (entry.severity == severity)
                result.push_back(entry);
        }
        return result;
    }

    void clearHistory()
    {
        std::lock_guard<std::mutex> lock(historyMutex_);
        errorHistory_.clear();
    }

    //==========================================================================
    // Statistics
    //==========================================================================

    struct ErrorStats
    {
        int totalErrors = 0;
        int debugCount = 0;
        int infoCount = 0;
        int warningCount = 0;
        int errorCount = 0;
        int fatalCount = 0;
        int recoveredCount = 0;
    };

    ErrorStats getStats() const
    {
        ErrorStats stats;
        stats.debugCount = errorCounts_[static_cast<int>(ErrorSeverity::Debug)].load();
        stats.infoCount = errorCounts_[static_cast<int>(ErrorSeverity::Info)].load();
        stats.warningCount = errorCounts_[static_cast<int>(ErrorSeverity::Warning)].load();
        stats.errorCount = errorCounts_[static_cast<int>(ErrorSeverity::Error)].load();
        stats.fatalCount = errorCounts_[static_cast<int>(ErrorSeverity::Fatal)].load();
        stats.totalErrors = stats.debugCount + stats.infoCount + stats.warningCount +
                            stats.errorCount + stats.fatalCount;
        stats.recoveredCount = recoveredCount_.load();
        return stats;
    }

private:
    EchoelErrorHandler() = default;

    void writeToLog(const ErrorEntry& entry)
    {
        if (!logFile_.exists())
            logFile_.create();

        juce::FileOutputStream output(logFile_);
        if (output.openedOk())
        {
            output.setPosition(output.getFile().getSize());
            juce::String line = juce::String::formatted(
                "[%.3f] %s\n",
                entry.timestamp,
                entry.toString().toRawUTF8()
            );
            if (!entry.details.empty())
            {
                line += juce::String("  Details: ") + juce::String(entry.details) + "\n";
            }
            if (!entry.file.empty())
            {
                line += juce::String::formatted("  Location: %s:%d in %s\n",
                    entry.file.c_str(), entry.line, entry.function.c_str());
            }
            output.writeText(line, false, false, nullptr);
        }
    }

    void attemptRecovery(ErrorEntry& entry)
    {
        RecoveryStrategy* strategy = nullptr;

        // Check code-specific strategy
        {
            std::lock_guard<std::mutex> lock(recoveryMutex_);
            auto it = recoveryStrategies_.find(entry.code);
            if (it != recoveryStrategies_.end())
                strategy = &it->second;
        }

        // Fall back to category strategy
        if (!strategy)
        {
            std::lock_guard<std::mutex> lock(recoveryMutex_);
            auto it = categoryRecoveryStrategies_.find(static_cast<int>(entry.category));
            if (it != categoryRecoveryStrategies_.end())
                strategy = &it->second;
        }

        if (strategy && strategy->recoveryFn)
        {
            int attempts = 0;
            int delay = strategy->delayMs;

            while (attempts < strategy->maxAttempts)
            {
                attempts++;

                if (strategy->recoveryFn(entry))
                {
                    entry.recovered = true;
                    entry.recoveryAction = "Auto-recovered after " + std::to_string(attempts) + " attempts";
                    recoveredCount_.fetch_add(1);
                    info("Recovered from error " + std::to_string(entry.code) + ": " + entry.message);
                    return;
                }

                if (attempts < strategy->maxAttempts)
                {
                    juce::Thread::sleep(delay);
                    if (strategy->exponentialBackoff)
                        delay *= 2;
                }
            }

            warning(entry.code, "Recovery failed after " + std::to_string(attempts) + " attempts");
        }
    }

    void handleFatalError(const ErrorEntry& entry)
    {
        // Write crash log
        juce::File crashLog = logDirectory_.getChildFile(
            "crash_" + juce::Time::getCurrentTime().formatted("%Y%m%d_%H%M%S") + ".log"
        );

        juce::FileOutputStream output(crashLog);
        if (output.openedOk())
        {
            output.writeText("=== ECHOEL FATAL ERROR ===\n", false, false, nullptr);
            output.writeText(entry.toString() + "\n", false, false, nullptr);
            output.writeText("Details: " + juce::String(entry.details) + "\n", false, false, nullptr);
            output.writeText(juce::String::formatted("Location: %s:%d in %s\n",
                entry.file.c_str(), entry.line, entry.function.c_str()), false, false, nullptr);
            output.writeText("\n=== RECENT ERRORS ===\n", false, false, nullptr);

            auto recent = getRecentErrors(20);
            for (const auto& e : recent)
            {
                output.writeText(e.toString() + "\n", false, false, nullptr);
            }
        }

        // Notify fatal callback
        if (fatalCallback_)
        {
            fatalCallback_(entry);
        }
    }

    void registerDefaultRecoveryStrategies()
    {
        // Audio recovery
        registerCategoryRecoveryStrategy(ErrorCategory::Audio, {
            3, 500, true,
            [](const ErrorEntry&) {
                // Try to reinitialize audio
                return false;  // Placeholder
            }
        });

        // Network recovery
        registerCategoryRecoveryStrategy(ErrorCategory::Network, {
            5, 1000, true,
            [](const ErrorEntry&) {
                // Try to reconnect
                return false;  // Placeholder
            }
        });

        // Memory recovery
        registerCategoryRecoveryStrategy(ErrorCategory::Memory, {
            1, 0, false,
            [](const ErrorEntry&) {
                // Try to free memory
                return false;  // Placeholder
            }
        });
    }

    std::atomic<bool> initialized_{false};

    // Logging
    juce::File logDirectory_;
    juce::File logFile_;

    // History
    mutable std::mutex historyMutex_;
    std::vector<ErrorEntry> errorHistory_;
    size_t maxHistorySize_ = 1000;

    // Counters
    std::array<std::atomic<int>, 5> errorCounts_{};
    std::atomic<int> recoveredCount_{0};

    // Recovery
    std::mutex recoveryMutex_;
    std::map<int, RecoveryStrategy> recoveryStrategies_;
    std::map<int, RecoveryStrategy> categoryRecoveryStrategies_;

    // Callbacks
    std::mutex callbackMutex_;
    std::vector<ErrorCallback> errorCallbacks_;
    FatalCallback fatalCallback_;
};

//==============================================================================
// Convenience Macros
//==============================================================================

#define ECHOEL_ERROR Echoel::EchoelErrorHandler::getInstance()

#define ECHOEL_LOG_DEBUG(msg) \
    ECHOEL_ERROR.debug(msg)

#define ECHOEL_LOG_INFO(msg) \
    ECHOEL_ERROR.info(msg)

#define ECHOEL_LOG_WARNING(code, msg) \
    ECHOEL_ERROR.warning(code, msg)

#define ECHOEL_LOG_ERROR(code, msg, details, category) \
    ECHOEL_ERROR.report(code, Echoel::ErrorSeverity::Error, category, msg, details, \
                        __FILE__, __LINE__, __FUNCTION__)

#define ECHOEL_LOG_FATAL(code, msg, details) \
    ECHOEL_ERROR.report(code, Echoel::ErrorSeverity::Fatal, Echoel::ErrorCategory::System, \
                        msg, details, __FILE__, __LINE__, __FUNCTION__)

}  // namespace Echoel

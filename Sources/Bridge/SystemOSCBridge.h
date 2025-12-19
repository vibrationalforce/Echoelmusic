#pragma once

#include <JuceHeader.h>
#include "../Monitoring/HealthCheck.h"
#include "../Monitoring/PrometheusMetrics.h"
#include "../Hardware/OSCManager.h"

namespace Echoelmusic {

/**
 * @brief System Monitoring OSC Bridge
 *
 * Provides OSC access to system health, metrics, and monitoring data.
 * Integrates with HealthCheck and PrometheusMetrics systems.
 *
 * OSC Address Space:
 * /echoelmusic/system/health                  Get health status (JSON)
 * /echoelmusic/system/health/live             Liveness probe (0=dead, 1=alive)
 * /echoelmusic/system/health/ready            Readiness probe (0=not ready, 1=ready)
 * /echoelmusic/system/health/<component>      Get specific component health
 *
 * /echoelmusic/system/uptime                  Get application uptime (seconds)
 * /echoelmusic/system/version                 Get application version
 * /echoelmusic/system/platform                Get platform info (OS, architecture)
 *
 * /echoelmusic/system/metrics                 Get Prometheus metrics (text format)
 * /echoelmusic/system/metrics/reset           Reset all metrics (for testing)
 *
 * /echoelmusic/system/cpu                     Get CPU usage percentage
 * /echoelmusic/system/memory                  Get memory usage (MB)
 * /echoelmusic/system/threads                 Get active thread count
 *
 * Response Messages:
 * /echoelmusic/system/status/health [string]       JSON health report
 * /echoelmusic/system/status/uptime [int]          Uptime in seconds
 * /echoelmusic/system/status/live [int 0/1]        Liveness status
 * /echoelmusic/system/status/ready [int 0/1]       Readiness status
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class SystemOSCBridge
{
public:
    //==========================================================================
    SystemOSCBridge(OSCManager& oscManager)
        : oscManager(oscManager)
        , startTime(juce::Time::getMillisecondCounterHiRes())
    {
        setupOSCListeners();
    }

    ~SystemOSCBridge()
    {
        removeOSCListeners();
    }

    //==========================================================================
    /**
     * @brief Send system status via OSC
     */
    void sendSystemStatus()
    {
        using namespace Echoel::Monitoring;

        juce::String prefix = "/echoelmusic/system/status/";

        // Health status
        auto& healthCheck = HealthCheck::getInstance();
        oscManager.sendString(prefix + "health", healthCheck.toJSON());
        oscManager.sendInt(prefix + "live", healthCheck.isLive() ? 1 : 0);
        oscManager.sendInt(prefix + "ready", healthCheck.isReady() ? 1 : 0);

        // Uptime
        double uptimeSeconds = (juce::Time::getMillisecondCounterHiRes() - startTime) / 1000.0;
        oscManager.sendInt(prefix + "uptime", static_cast<int>(uptimeSeconds));

        // Version
        oscManager.sendString(prefix + "version", getVersion());

        // Platform
        oscManager.sendString(prefix + "platform", getPlatformInfo());

        // System resources (basic estimates)
        oscManager.sendFloat(prefix + "cpu", estimateCPUUsage());
        oscManager.sendFloat(prefix + "memory", estimateMemoryUsage());
        oscManager.sendInt(prefix + "threads", juce::Thread::getCurrentThreadId());
    }

    /**
     * @brief Get application version
     */
    static juce::String getVersion()
    {
        // Would be defined in build system
        return "1.0.0";
    }

    /**
     * @brief Get platform information
     */
    static juce::String getPlatformInfo()
    {
        juce::String platform;

        #if JUCE_WINDOWS
            platform << "Windows";
        #elif JUCE_MAC
            platform << "macOS";
        #elif JUCE_LINUX
            platform << "Linux";
        #elif JUCE_IOS
            platform << "iOS";
        #elif JUCE_ANDROID
            platform << "Android";
        #else
            platform << "Unknown";
        #endif

        #if JUCE_64BIT
            platform << " x64";
        #else
            platform << " x86";
        #endif

        #if JUCE_DEBUG
            platform << " (Debug)";
        #else
            platform << " (Release)";
        #endif

        return platform;
    }

private:
    //==========================================================================
    void setupOSCListeners()
    {
        using namespace Echoel::Monitoring;

        // Health status (JSON)
        oscManager.addListener("/echoelmusic/system/health",
            [this](const juce::OSCMessage&) {
                auto& healthCheck = HealthCheck::getInstance();
                oscManager.sendString("/echoelmusic/system/status/health",
                    healthCheck.toJSON());
            });

        // Liveness probe
        oscManager.addListener("/echoelmusic/system/health/live",
            [this](const juce::OSCMessage&) {
                auto& healthCheck = HealthCheck::getInstance();
                oscManager.sendInt("/echoelmusic/system/status/live",
                    healthCheck.isLive() ? 1 : 0);
            });

        // Readiness probe
        oscManager.addListener("/echoelmusic/system/health/ready",
            [this](const juce::OSCMessage&) {
                auto& healthCheck = HealthCheck::getInstance();
                oscManager.sendInt("/echoelmusic/system/status/ready",
                    healthCheck.isReady() ? 1 : 0);
            });

        // Specific component health
        oscManager.addListener("/echoelmusic/system/health/*",
            [this](const juce::OSCMessage& message) {
                handleComponentHealthQuery(message);
            });

        // Uptime
        oscManager.addListener("/echoelmusic/system/uptime",
            [this](const juce::OSCMessage&) {
                double uptimeSeconds = (juce::Time::getMillisecondCounterHiRes() - startTime) / 1000.0;
                oscManager.sendInt("/echoelmusic/system/status/uptime",
                    static_cast<int>(uptimeSeconds));
            });

        // Version
        oscManager.addListener("/echoelmusic/system/version",
            [this](const juce::OSCMessage&) {
                oscManager.sendString("/echoelmusic/system/status/version",
                    getVersion());
            });

        // Platform
        oscManager.addListener("/echoelmusic/system/platform",
            [this](const juce::OSCMessage&) {
                oscManager.sendString("/echoelmusic/system/status/platform",
                    getPlatformInfo());
            });

        // Prometheus metrics
        oscManager.addListener("/echoelmusic/system/metrics",
            [this](const juce::OSCMessage&) {
                auto& metrics = PrometheusMetrics::getInstance();
                oscManager.sendString("/echoelmusic/system/status/metrics",
                    metrics.exportMetrics());
            });

        // Reset metrics
        oscManager.addListener("/echoelmusic/system/metrics/reset",
            [this](const juce::OSCMessage&) {
                auto& metrics = PrometheusMetrics::getInstance();
                metrics.reset();
                DBG("OSC: Metrics reset");
                oscManager.sendString("/echoelmusic/system/status/message",
                    "Metrics reset successful");
            });

        // CPU usage
        oscManager.addListener("/echoelmusic/system/cpu",
            [this](const juce::OSCMessage&) {
                oscManager.sendFloat("/echoelmusic/system/status/cpu",
                    estimateCPUUsage());
            });

        // Memory usage
        oscManager.addListener("/echoelmusic/system/memory",
            [this](const juce::OSCMessage&) {
                oscManager.sendFloat("/echoelmusic/system/status/memory",
                    estimateMemoryUsage());
            });

        // Thread count
        oscManager.addListener("/echoelmusic/system/threads",
            [this](const juce::OSCMessage&) {
                // Basic thread info - would need platform-specific implementation
                oscManager.sendInt("/echoelmusic/system/status/threads",
                    juce::Thread::getCurrentThreadId());
            });

        // Full system status
        oscManager.addListener("/echoelmusic/system/status",
            [this](const juce::OSCMessage&) {
                sendSystemStatus();
            });
    }

    void removeOSCListeners()
    {
        oscManager.removeListener("/echoelmusic/system/health");
        oscManager.removeListener("/echoelmusic/system/health/live");
        oscManager.removeListener("/echoelmusic/system/health/ready");
        oscManager.removeListener("/echoelmusic/system/health/*");
        oscManager.removeListener("/echoelmusic/system/uptime");
        oscManager.removeListener("/echoelmusic/system/version");
        oscManager.removeListener("/echoelmusic/system/platform");
        oscManager.removeListener("/echoelmusic/system/metrics");
        oscManager.removeListener("/echoelmusic/system/metrics/reset");
        oscManager.removeListener("/echoelmusic/system/cpu");
        oscManager.removeListener("/echoelmusic/system/memory");
        oscManager.removeListener("/echoelmusic/system/threads");
        oscManager.removeListener("/echoelmusic/system/status");
    }

    //==========================================================================
    void handleComponentHealthQuery(const juce::OSCMessage& message)
    {
        using namespace Echoel::Monitoring;

        juce::String address = message.getAddressPattern().toString();

        // Parse component name from address
        auto parts = juce::StringArray::fromTokens(address, "/", "");
        if (parts.size() < 4) return;

        juce::String componentName = parts[parts.size() - 1];

        // Get health for specific component
        auto& healthCheck = HealthCheck::getInstance();
        auto allHealth = healthCheck.checkAll();

        if (allHealth.count(componentName.toStdString()) > 0)
        {
            const auto& health = allHealth[componentName.toStdString()];

            // Send component-specific status
            juce::String prefix = "/echoelmusic/system/status/health/" + componentName + "/";

            juce::String statusStr;
            switch (health.status)
            {
                case HealthCheck::Status::Healthy:   statusStr = "healthy"; break;
                case HealthCheck::Status::Degraded:  statusStr = "degraded"; break;
                case HealthCheck::Status::Unhealthy: statusStr = "unhealthy"; break;
            }

            oscManager.sendString(prefix + "status", statusStr);
            oscManager.sendString(prefix + "message", juce::String(health.message));
            oscManager.sendInt(prefix + "lastchecked", static_cast<int>(health.lastChecked));
            oscManager.sendInt(prefix + "responsetime", static_cast<int>(health.responseTimeMs));
        }
    }

    //==========================================================================
    // System resource estimation (basic - would use platform APIs for accuracy)

    float estimateCPUUsage() const
    {
        // Basic CPU usage estimate
        // Real implementation would use platform-specific APIs:
        // - Windows: GetSystemTimes()
        // - macOS: host_processor_info()
        // - Linux: /proc/stat
        return 25.0f;  // Placeholder
    }

    float estimateMemoryUsage() const
    {
        // Basic memory usage estimate in MB
        // Real implementation would use:
        // - Windows: GlobalMemoryStatusEx()
        // - macOS: vm_statistics64()
        // - Linux: /proc/meminfo
        return 512.0f;  // Placeholder
    }

    //==========================================================================
    OSCManager& oscManager;
    double startTime;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SystemOSCBridge)
};

} // namespace Echoelmusic

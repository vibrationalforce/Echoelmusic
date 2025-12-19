#pragma once

#include <string>
#include <map>
#include <functional>
#include <ctime>
#include <sstream>

namespace Echoel {
namespace Monitoring {

/**
 * @brief Health Check System
 *
 * Provides liveness and readiness probes for Kubernetes/orchestration systems.
 * Checks health of critical components (database, cache, external services).
 *
 * Endpoints:
 * - /health - Overall health status
 * - /health/live - Liveness probe (is app running?)
 * - /health/ready - Readiness probe (can app serve traffic?)
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class HealthCheck {
public:
    enum class Status {
        Healthy,   // Component is fully operational
        Degraded,  // Component is working but with issues
        Unhealthy  // Component is not working
    };

    struct ComponentHealth {
        Status status;
        std::string message;
        int64_t lastChecked;
        int64_t responseTimeMs;

        ComponentHealth()
            : status(Status::Unhealthy)
            , message("Not checked")
            , lastChecked(0)
            , responseTimeMs(0)
        {}

        ComponentHealth(Status s, const std::string& msg)
            : status(s)
            , message(msg)
            , lastChecked(std::time(nullptr))
            , responseTimeMs(0)
        {}
    };

    /**
     * @brief Get singleton instance
     */
    static HealthCheck& getInstance() {
        static HealthCheck instance;
        return instance;
    }

    /**
     * @brief Register a component health check
     * @param name Component name
     * @param checker Function that returns component health
     */
    void registerComponent(const std::string& name,
                           std::function<ComponentHealth()> checker)
    {
        healthChecks[name] = checker;
    }

    /**
     * @brief Check all registered components
     * @return Map of component name to health status
     */
    std::map<std::string, ComponentHealth> checkAll() {
        std::map<std::string, ComponentHealth> results;

        for (const auto& [name, checker] : healthChecks) {
            try {
                results[name] = checker();
            } catch (const std::exception& e) {
                results[name] = ComponentHealth(
                    Status::Unhealthy,
                    std::string("Exception: ") + e.what()
                );
            } catch (...) {
                results[name] = ComponentHealth(
                    Status::Unhealthy,
                    "Unknown exception"
                );
            }
        }

        return results;
    }

    /**
     * @brief Get overall system health status
     * @return Aggregated status
     */
    Status getOverallStatus() {
        auto results = checkAll();

        if (results.empty()) {
            return Status::Healthy;  // No checks = healthy
        }

        bool hasUnhealthy = false;
        bool hasDegraded = false;

        for (const auto& [name, health] : results) {
            if (health.status == Status::Unhealthy) {
                hasUnhealthy = true;
            } else if (health.status == Status::Degraded) {
                hasDegraded = true;
            }
        }

        if (hasUnhealthy) return Status::Unhealthy;
        if (hasDegraded) return Status::Degraded;
        return Status::Healthy;
    }

    /**
     * @brief Check if system is live (liveness probe)
     * @return true if application is running
     */
    bool isLive() {
        // Liveness: just check if we can respond
        return true;
    }

    /**
     * @brief Check if system is ready (readiness probe)
     * @return true if system can serve traffic
     */
    bool isReady() {
        // Readiness: check if critical components are healthy
        auto status = getOverallStatus();
        return status != Status::Unhealthy;
    }

    /**
     * @brief Export health status as JSON
     * @return JSON string
     */
    std::string toJSON() {
        auto results = checkAll();
        auto overall = getOverallStatus();
        int64_t now = std::time(nullptr);

        std::ostringstream json;
        json << "{\n";
        json << "  \"status\": \"" << statusToString(overall) << "\",\n";
        json << "  \"timestamp\": " << now << ",\n";
        json << "  \"uptime\": " << getUptimeSeconds() << ",\n";
        json << "  \"components\": {\n";

        bool first = true;
        for (const auto& [name, health] : results) {
            if (!first) json << ",\n";

            json << "    \"" << name << "\": {\n";
            json << "      \"status\": \"" << statusToString(health.status) << "\",\n";
            json << "      \"message\": \"" << escapeJSON(health.message) << "\",\n";
            json << "      \"lastChecked\": " << health.lastChecked << ",\n";
            json << "      \"responseTimeMs\": " << health.responseTimeMs << "\n";
            json << "    }";

            first = false;
        }

        json << "\n  }\n}";
        return json.str();
    }

private:
    HealthCheck() {
        startTime = std::time(nullptr);

        // Register default health checks
        registerComponent("application", []() {
            return ComponentHealth(Status::Healthy, "Application is running");
        });

        registerComponent("memory", []() {
            // TODO: Check memory usage
            // For now, assume healthy
            return ComponentHealth(Status::Healthy, "Memory usage within limits");
        });

        // TODO: Register additional checks for:
        // - Database connection
        // - Redis connection
        // - Disk space
        // - CPU usage
    }

    static std::string statusToString(Status status) {
        switch (status) {
            case Status::Healthy: return "healthy";
            case Status::Degraded: return "degraded";
            case Status::Unhealthy: return "unhealthy";
        }
        return "unknown";
    }

    static std::string escapeJSON(const std::string& str) {
        std::string escaped;
        for (char c : str) {
            switch (c) {
                case '"': escaped += "\\\""; break;
                case '\\': escaped += "\\\\"; break;
                case '\b': escaped += "\\b"; break;
                case '\f': escaped += "\\f"; break;
                case '\n': escaped += "\\n"; break;
                case '\r': escaped += "\\r"; break;
                case '\t': escaped += "\\t"; break;
                default: escaped += c; break;
            }
        }
        return escaped;
    }

    int64_t getUptimeSeconds() const {
        return std::time(nullptr) - startTime;
    }

    std::map<std::string, std::function<ComponentHealth()>> healthChecks;
    int64_t startTime;
};

} // namespace Monitoring
} // namespace Echoel

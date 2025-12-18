#pragma once

#include <string>
#include <map>
#include <vector>
#include <atomic>
#include <mutex>
#include <sstream>
#include <algorithm>
#include <cmath>

namespace Echoel {
namespace Monitoring {

/**
 * @brief Prometheus Metrics Exporter
 *
 * Provides Prometheus-compatible metrics for monitoring and alerting.
 * Supports counters, gauges, and histograms.
 *
 * Metric Types:
 * - Counter: Monotonically increasing value (e.g., requests_total)
 * - Gauge: Value that can go up or down (e.g., active_connections)
 * - Histogram: Distribution of values (e.g., request_duration_seconds)
 *
 * Endpoint: GET /metrics
 * Format: Prometheus text format
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class PrometheusMetrics {
public:
    /**
     * @brief Get singleton instance
     */
    static PrometheusMetrics& getInstance() {
        static PrometheusMetrics instance;
        return instance;
    }

    /**
     * @brief Increment a counter metric
     * @param name Metric name
     * @param value Value to add (default: 1.0)
     * @param labels Optional labels (e.g., {"method", "GET", "status", "200"})
     */
    void incrementCounter(
        const std::string& name,
        double value = 1.0,
        const std::map<std::string, std::string>& labels = {})
    {
        std::lock_guard<std::mutex> lock(mutex);
        std::string key = makeKey(name, labels);
        counters[key] += value;
    }

    /**
     * @brief Set a gauge metric
     * @param name Metric name
     * @param value Current value
     * @param labels Optional labels
     */
    void setGauge(
        const std::string& name,
        double value,
        const std::map<std::string, std::string>& labels = {})
    {
        std::lock_guard<std::mutex> lock(mutex);
        std::string key = makeKey(name, labels);
        gauges[key] = value;
    }

    /**
     * @brief Increment a gauge metric
     * @param name Metric name
     * @param value Value to add
     * @param labels Optional labels
     */
    void incrementGauge(
        const std::string& name,
        double value,
        const std::map<std::string, std::string>& labels = {})
    {
        std::lock_guard<std::mutex> lock(mutex);
        std::string key = makeKey(name, labels);
        gauges[key] += value;
    }

    /**
     * @brief Decrement a gauge metric
     * @param name Metric name
     * @param value Value to subtract
     * @param labels Optional labels
     */
    void decrementGauge(
        const std::string& name,
        double value,
        const std::map<std::string, std::string>& labels = {})
    {
        incrementGauge(name, -value, labels);
    }

    /**
     * @brief Record a histogram observation
     * @param name Metric name
     * @param value Observed value
     * @param labels Optional labels
     */
    void recordHistogram(
        const std::string& name,
        double value,
        const std::map<std::string, std::string>& labels = {})
    {
        std::lock_guard<std::mutex> lock(mutex);
        std::string key = makeKey(name, labels);
        histograms[key].push_back(value);
    }

    /**
     * @brief Export all metrics in Prometheus format
     * @return Prometheus text format metrics
     */
    std::string exportMetrics() {
        std::lock_guard<std::mutex> lock(mutex);
        std::ostringstream output;

        // Export counters
        std::map<std::string, std::vector<std::string>> countersByName;
        for (const auto& [key, value] : counters) {
            auto [name, labels] = parseKey(key);
            countersByName[name].push_back(formatMetric(name, labels, value));
        }

        for (const auto& [name, metrics] : countersByName) {
            output << "# HELP " << name << " Counter metric\n";
            output << "# TYPE " << name << " counter\n";
            for (const auto& metric : metrics) {
                output << metric << "\n";
            }
        }

        // Export gauges
        std::map<std::string, std::vector<std::string>> gaugesByName;
        for (const auto& [key, value] : gauges) {
            auto [name, labels] = parseKey(key);
            gaugesByName[name].push_back(formatMetric(name, labels, value));
        }

        for (const auto& [name, metrics] : gaugesByName) {
            output << "# HELP " << name << " Gauge metric\n";
            output << "# TYPE " << name << " gauge\n";
            for (const auto& metric : metrics) {
                output << metric << "\n";
            }
        }

        // Export histograms
        std::map<std::string, std::vector<std::pair<std::string, std::vector<double>>>>
            histogramsByName;

        for (const auto& [key, values] : histograms) {
            auto [name, labels] = parseKey(key);
            histogramsByName[name].push_back({labels, values});
        }

        for (const auto& [name, histos] : histogramsByName) {
            output << "# HELP " << name << " Histogram metric\n";
            output << "# TYPE " << name << " histogram\n";

            for (const auto& [labels, values] : histos) {
                if (values.empty()) continue;

                // Calculate statistics
                double sum = 0.0;
                for (double v : values) sum += v;
                size_t count = values.size();

                // Calculate quantiles
                auto sortedValues = values;
                std::sort(sortedValues.begin(), sortedValues.end());

                auto quantile = [&](double p) {
                    size_t idx = static_cast<size_t>(p * (count - 1));
                    return sortedValues[idx];
                };

                // Export bucket counts (for standard buckets)
                static const std::vector<double> buckets = {
                    0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5,
                    0.75, 1.0, 2.5, 5.0, 7.5, 10.0, std::numeric_limits<double>::infinity()
                };

                for (double bucket : buckets) {
                    size_t bucketCount = std::count_if(
                        values.begin(), values.end(),
                        [bucket](double v) { return v <= bucket; }
                    );

                    std::string bucketLabels = labels;
                    if (!bucketLabels.empty()) bucketLabels += ",";
                    bucketLabels += "le=\"";
                    if (std::isinf(bucket)) {
                        bucketLabels += "+Inf";
                    } else {
                        bucketLabels += std::to_string(bucket);
                    }
                    bucketLabels += "\"";

                    output << name << "_bucket{" << bucketLabels << "} "
                           << bucketCount << "\n";
                }

                // Export sum and count
                output << name << "_sum{" << labels << "} " << sum << "\n";
                output << name << "_count{" << labels << "} " << count << "\n";
            }
        }

        return output.str();
    }

    /**
     * @brief Reset all metrics (useful for testing)
     */
    void reset() {
        std::lock_guard<std::mutex> lock(mutex);
        counters.clear();
        gauges.clear();
        histograms.clear();
    }

private:
    PrometheusMetrics() = default;

    std::string makeKey(
        const std::string& name,
        const std::map<std::string, std::string>& labels)
    {
        std::string key = name;

        if (!labels.empty()) {
            key += "{";
            bool first = true;
            for (const auto& [k, v] : labels) {
                if (!first) key += ",";
                key += k + "=\"" + v + "\"";
                first = false;
            }
            key += "}";
        }

        return key;
    }

    std::pair<std::string, std::string> parseKey(const std::string& key) {
        size_t pos = key.find('{');
        if (pos == std::string::npos) {
            return {key, ""};
        }

        std::string name = key.substr(0, pos);
        std::string labels = key.substr(pos + 1, key.length() - pos - 2);
        return {name, labels};
    }

    std::string formatMetric(
        const std::string& name,
        const std::string& labels,
        double value)
    {
        std::ostringstream out;
        out << name;

        if (!labels.empty()) {
            out << "{" << labels << "}";
        }

        out << " " << value;
        return out.str();
    }

    std::mutex mutex;
    std::map<std::string, double> counters;
    std::map<std::string, double> gauges;
    std::map<std::string, std::vector<double>> histograms;
};

/**
 * @brief RAII wrapper for measuring histogram duration
 */
class HistogramTimer {
public:
    HistogramTimer(
        const std::string& name,
        const std::map<std::string, std::string>& labels = {})
        : metricName(name)
        , metricLabels(labels)
        , startTime(std::chrono::high_resolution_clock::now())
    {}

    ~HistogramTimer() {
        auto endTime = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
            endTime - startTime
        ).count();

        double seconds = duration / 1000000.0;
        PrometheusMetrics::getInstance().recordHistogram(
            metricName, seconds, metricLabels
        );
    }

private:
    std::string metricName;
    std::map<std::string, std::string> metricLabels;
    std::chrono::high_resolution_clock::time_point startTime;
};

} // namespace Monitoring
} // namespace Echoel

// Convenience macros
#define METRIC_COUNTER(name, ...) \
    Echoel::Monitoring::PrometheusMetrics::getInstance().incrementCounter(name, ##__VA_ARGS__)

#define METRIC_GAUGE(name, value, ...) \
    Echoel::Monitoring::PrometheusMetrics::getInstance().setGauge(name, value, ##__VA_ARGS__)

#define METRIC_HISTOGRAM(name, value, ...) \
    Echoel::Monitoring::PrometheusMetrics::getInstance().recordHistogram(name, value, ##__VA_ARGS__)

#define METRIC_TIMER(name, ...) \
    Echoel::Monitoring::HistogramTimer _timer_##__LINE__(name, ##__VA_ARGS__)

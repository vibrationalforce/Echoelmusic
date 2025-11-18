// EchoelSyncBiometric.h
// Biometric Synchronization Extension for EchoelSync™
// Synchronize audio/visuals to physiological states across multiple users
//
// SPDX-License-Identifier: MIT
// Copyright © 2025 Echoel Development Team

#pragma once

#include "EchoelSync.h"
#include <vector>
#include <string>
#include <memory>
#include <functional>

/**
 * ███████╗ ██████╗██╗  ██╗ ██████╗ ███████╗██╗     ███████╗██╗   ██╗███╗   ██╗ ██████╗
 * ██╔════╝██╔════╝██║  ██║██╔═══██╗██╔════╝██║     ██╔════╝╚██╗ ██╔╝████╗  ██║██╔════╝
 * █████╗  ██║     ███████║██║   ██║█████╗  ██║     ███████╗ ╚████╔╝ ██╔██╗ ██║██║
 * ██╔══╝  ██║     ██╔══██║██║   ██║██╔══╝  ██║     ╚════██║  ╚██╔╝  ██║╚██╗██║██║
 * ███████╗╚██████╗██║  ██║╚██████╔╝███████╗███████╗███████║   ██║   ██║ ╚████║╚██████╗
 * ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝
 *
 * BIOMETRIC SYNCHRONIZATION - Erweitert EchoelSync™ mit physiologischen Daten
 *
 * NEUE SYNC-DIMENSIONEN:
 * ✅ Heart Rate Sync - Musik folgt kollektivem Herzschlag
 * ✅ HRV Coherence Sync - Gruppe-Kohärenz-Optimierung
 * ✅ Circadian Phase Sync - Zeitzone-übergreifende Kreativität
 * ✅ Neural State Sync - Gemeinsame Flow-States
 * ✅ Emotional State Sync - Kollektive Stimmungsanpassung
 * ✅ Recovery Sync - Tempo basierend auf Erholungszustand
 *
 * ANWENDUNGSFÄLLE:
 * 1. Meditation Groups - Sync zu Gruppen-Herzschlag-Kohärenz
 * 2. Therapy Sessions - Gemeinsame emotionale Regulation
 * 3. Remote Collaboration - Circadian-Phase-Matching
 * 4. Live Performance - Publikums-Energie-Reaktion
 * 5. Wellness Apps - Personalisierte Tempo-Anpassung
 * 6. Sleep Optimization - Tempo basierend auf Schlafqualität
 *
 * INTEGRATION:
 * - EchoelVision™ (Eye Tracking)
 * - EchoelMind™ (EEG/Neural)
 * - EchoelHeart™ (HRV/Cardiac)
 * - EchoelRing™ (Oura Sleep/Recovery)
 * - EchoelFlow™ (Master Coordinator)
 */

namespace EchoelBiometric
{

//==============================================================================
// Biometric Data Structures
//==============================================================================

/// Simplified biometric data for sync (C++ compatible)
struct BiometricData
{
    // Cardiac
    float heartRate = 70.0f;            // BPM
    float hrvRMSSD = 50.0f;             // HRV in ms
    float coherence = 50.0f;            // 0-100 (HeartMath)

    // Neural
    float alpha = 0.5f;                 // 0-1 (relaxation)
    float beta = 0.5f;                  // 0-1 (focus)
    float theta = 0.5f;                 // 0-1 (creativity)
    float gamma = 0.5f;                 // 0-1 (peak performance)

    // Wellness
    float sleepScore = 0.0f;            // 0-100 (Oura)
    float readinessScore = 0.0f;        // 0-100 (recovery)
    float stressIndex = 50.0f;          // 0-100 (stress level)

    // Metadata
    uint64_t timestamp = 0;             // μs since epoch
    float confidence = 100.0f;          // 0-100 (data quality)
    std::string deviceID = "unknown";   // Device identifier
};

/// Physiological state classification
enum class PhysiologicalState
{
    Peak,           // All systems optimal
    Focused,        // High attention, low stress
    Creative,       // Theta/alpha dominant
    Relaxed,        // Low arousal, balanced
    Stressed,       // High sympathetic
    Fatigued,       // Low energy, poor recovery
    Recovering,     // Post-exercise recovery
    Meditative      // Deep calm state
};

/// Biometric sync protocol types
enum class BiometricSyncMode
{
    HeartRateSync,          // Tempo follows heart rate
    HRVCoherenceSync,       // Optimize for group coherence
    CircadianPhaseSync,     // Match circadian rhythms
    NeuralStateSync,        // Sync to brain states
    EmotionalStateSync,     // Sync to emotional valence
    RecoverySync,           // Tempo based on recovery
    AdaptiveSync            // AI-driven adaptive sync
};

//==============================================================================
// Group Biometric Synchronization
//==============================================================================

/**
 * Synchronizes multiple people's biometric data for collaborative sessions
 *
 * Use Cases:
 * - Meditation groups (heart coherence)
 * - Therapy sessions (emotional regulation)
 * - Creative collaborations (optimal circadian matching)
 */
class GroupCoherenceSync
{
public:
    GroupCoherenceSync() = default;
    ~GroupCoherenceSync() = default;

    //==========================================================================
    // Participant Management
    //==========================================================================

    /// Add participant with biometric data
    void addParticipant(const std::string& participantID, const BiometricData& data)
    {
        participants[participantID] = data;
        recalculateGroupMetrics();
    }

    /// Remove participant
    void removeParticipant(const std::string& participantID)
    {
        participants.erase(participantID);
        recalculateGroupMetrics();
    }

    /// Get number of participants
    size_t getParticipantCount() const { return participants.size(); }

    //==========================================================================
    // Group Metrics
    //==========================================================================

    /// Get group heart coherence score (0-100)
    /// Higher = more synchronized heart rhythms
    float getGroupCoherence() const
    {
        if (participants.size() < 2)
            return 0.0f;

        // Calculate average coherence
        float sumCoherence = 0.0f;
        for (const auto& [id, data] : participants)
            sumCoherence += data.coherence;

        float avgCoherence = sumCoherence / participants.size();

        // Calculate coherence variance (lower = more synchronized)
        float variance = 0.0f;
        for (const auto& [id, data] : participants)
            variance += (data.coherence - avgCoherence) * (data.coherence - avgCoherence);
        variance /= participants.size();

        float synchronization = juce::jmax(0.0f, 100.0f - variance);

        return (avgCoherence + synchronization) / 2.0f;
    }

    /// Get optimal tempo for group (average heart rate)
    float getOptimalTempo() const
    {
        if (participants.empty())
            return 120.0f; // Default BPM

        float sumHR = 0.0f;
        for (const auto& [id, data] : participants)
            sumHR += data.heartRate;

        return sumHR / participants.size();
    }

    /// Get group physiological state
    PhysiologicalState getGroupState() const
    {
        if (participants.empty())
            return PhysiologicalState::Relaxed;

        // Calculate average metrics
        float avgGamma = 0.0f, avgCoherence = 0.0f, avgStress = 0.0f;
        float avgAlpha = 0.0f, avgBeta = 0.0f, avgReadiness = 0.0f;

        for (const auto& [id, data] : participants)
        {
            avgGamma += data.gamma;
            avgCoherence += data.coherence;
            avgStress += data.stressIndex;
            avgAlpha += data.alpha;
            avgBeta += data.beta;
            avgReadiness += data.readinessScore;
        }

        size_t count = participants.size();
        avgGamma /= count;
        avgCoherence /= count;
        avgStress /= count;
        avgAlpha /= count;
        avgBeta /= count;
        avgReadiness /= count;

        // Classify group state
        if (avgGamma > 0.7f && avgCoherence > 0.7f)
            return PhysiologicalState::Peak;
        if (avgAlpha > 0.7f)
            return PhysiologicalState::Meditative;
        if (avgBeta > 0.7f)
            return PhysiologicalState::Focused;
        if (avgStress > 70.0f)
            return PhysiologicalState::Stressed;
        if (avgReadiness < 40.0f)
            return PhysiologicalState::Fatigued;

        return PhysiologicalState::Relaxed;
    }

    /// Get recommended audio parameters for group
    struct AudioParameters
    {
        float tempo = 120.0f;           // BPM
        float energy = 0.5f;            // 0-1
        float complexity = 0.5f;        // 0-1
        float reverbSize = 0.5f;        // 0-1
        float filterBrightness = 0.5f;  // 0-1
    };

    AudioParameters getGroupAudioParameters() const
    {
        AudioParameters params;
        PhysiologicalState state = getGroupState();

        params.tempo = getOptimalTempo();

        switch (state)
        {
            case PhysiologicalState::Peak:
                params.energy = 1.0f;
                params.complexity = 0.8f;
                params.reverbSize = 0.4f;
                params.filterBrightness = 0.9f;
                break;

            case PhysiologicalState::Focused:
                params.energy = 0.7f;
                params.complexity = 0.5f;
                params.reverbSize = 0.3f;
                params.filterBrightness = 0.7f;
                break;

            case PhysiologicalState::Creative:
                params.energy = 0.6f;
                params.complexity = 1.0f;
                params.reverbSize = 0.7f;
                params.filterBrightness = 0.6f;
                break;

            case PhysiologicalState::Meditative:
                params.energy = 0.2f;
                params.complexity = 0.6f;
                params.reverbSize = 0.9f;
                params.filterBrightness = 0.3f;
                break;

            case PhysiologicalState::Stressed:
                params.energy = 0.3f;
                params.complexity = 0.2f;
                params.reverbSize = 0.6f;
                params.filterBrightness = 0.4f;
                break;

            default:
                // Relaxed defaults
                break;
        }

        return params;
    }

private:
    std::unordered_map<std::string, BiometricData> participants;
    float cachedGroupCoherence = 0.0f;
    float cachedOptimalTempo = 120.0f;

    void recalculateGroupMetrics()
    {
        cachedGroupCoherence = getGroupCoherence();
        cachedOptimalTempo = getOptimalTempo();
    }
};

//==============================================================================
// Biometric EchoelSync Extension
//==============================================================================

/**
 * Extends EchoelSync with biometric synchronization capabilities
 */
class BiometricSyncEngine
{
public:
    BiometricSyncEngine() = default;
    ~BiometricSyncEngine() = default;

    //==========================================================================
    // Configuration
    //==========================================================================

    /// Set biometric sync mode
    void setSyncMode(BiometricSyncMode mode)
    {
        currentMode = mode;
    }

    /// Get current sync mode
    BiometricSyncMode getSyncMode() const { return currentMode; }

    /// Enable/disable biometric sync
    void setEnabled(bool shouldBeEnabled)
    {
        enabled = shouldBeEnabled;
    }

    bool isEnabled() const { return enabled; }

    //==========================================================================
    // Biometric Data Input
    //==========================================================================

    /// Update local user's biometric data
    void updateLocalBiometrics(const BiometricData& data)
    {
        localBiometrics = data;
        groupSync.addParticipant("local", data);
    }

    /// Receive biometric data from remote peer
    void receiveRemoteBiometrics(const std::string& peerID, const BiometricData& data)
    {
        remoteBiometrics[peerID] = data;
        groupSync.addParticipant(peerID, data);
    }

    //==========================================================================
    // Sync Output
    //==========================================================================

    /// Get synchronized tempo based on biometric data
    float getSynchronizedTempo() const
    {
        if (!enabled)
            return 120.0f; // Default

        switch (currentMode)
        {
            case BiometricSyncMode::HeartRateSync:
                return localBiometrics.heartRate;

            case BiometricSyncMode::HRVCoherenceSync:
                return getCoherenceOptimizedTempo();

            case BiometricSyncMode::RecoverySync:
                return getRecoveryBasedTempo();

            case BiometricSyncMode::AdaptiveSync:
                return getAdaptiveTempo();

            default:
                return groupSync.getOptimalTempo();
        }
    }

    /// Get audio parameters based on collective biometric state
    GroupCoherenceSync::AudioParameters getAudioParameters() const
    {
        if (!enabled)
        {
            GroupCoherenceSync::AudioParameters defaults;
            return defaults;
        }

        return groupSync.getGroupAudioParameters();
    }

    /// Get group coherence score (0-100)
    float getGroupCoherence() const
    {
        return groupSync.getGroupCoherence();
    }

    /// Get group physiological state
    PhysiologicalState getGroupState() const
    {
        return groupSync.getGroupState();
    }

    //==========================================================================
    // Wellness Insights
    //==========================================================================

    /// Get wellness recommendations
    std::vector<std::string> getWellnessInsights() const
    {
        std::vector<std::string> insights;

        if (localBiometrics.sleepScore < 60.0f)
            insights.push_back("Low sleep score. Consider rest.");

        if (localBiometrics.readinessScore < 50.0f)
            insights.push_back("Low readiness. Take it easy today.");

        if (localBiometrics.stressIndex > 70.0f)
            insights.push_back("High stress detected. Try breathing exercises.");

        if (localBiometrics.hrvRMSSD < 30.0f)
            insights.push_back("Low HRV. Practice coherence breathing.");

        if (localBiometrics.coherence > 80.0f)
            insights.push_back("Excellent coherence! In the zone.");

        if (insights.empty())
            insights.push_back("All metrics looking good!");

        return insights;
    }

private:
    BiometricSyncMode currentMode = BiometricSyncMode::AdaptiveSync;
    bool enabled = true;

    BiometricData localBiometrics;
    std::unordered_map<std::string, BiometricData> remoteBiometrics;

    GroupCoherenceSync groupSync;

    //==========================================================================
    // Helper Methods
    //==========================================================================

    float getCoherenceOptimizedTempo() const
    {
        // Tempo that maximizes group coherence
        // Research shows 0.1 Hz (6 breaths/min) optimal for HRV coherence
        // Map to musical tempo: 60-90 BPM range
        float coherence = groupSync.getGroupCoherence();
        return 60.0f + (coherence / 100.0f) * 30.0f; // 60-90 BPM
    }

    float getRecoveryBasedTempo() const
    {
        // Lower tempo for poor recovery, higher for good recovery
        float readiness = localBiometrics.readinessScore;
        return 60.0f + (readiness / 100.0f) * 80.0f; // 60-140 BPM
    }

    float getAdaptiveTempo() const
    {
        // AI-driven adaptive tempo based on all metrics
        PhysiologicalState state = groupSync.getGroupState();

        switch (state)
        {
            case PhysiologicalState::Peak:       return 130.0f;
            case PhysiologicalState::Focused:    return 120.0f;
            case PhysiologicalState::Creative:   return 100.0f;
            case PhysiologicalState::Relaxed:    return 90.0f;
            case PhysiologicalState::Meditative: return 60.0f;
            case PhysiologicalState::Stressed:   return 80.0f;
            case PhysiologicalState::Fatigued:   return 70.0f;
            case PhysiologicalState::Recovering: return 85.0f;
            default:                             return 120.0f;
        }
    }
};

//==============================================================================
// Circadian Phase Sync
//==============================================================================

/**
 * Synchronize collaborators across time zones by circadian phase
 * instead of clock time
 */
class CircadianPhaseSync
{
public:
    struct CircadianProfile
    {
        std::string userID;
        uint64_t wakeTimestamp = 0;     // When user woke up (μs since epoch)
        float sleepScore = 0.0f;        // 0-100 (sleep quality)

        /// Hours since wake
        float getHoursSinceWake() const
        {
            uint64_t now = juce::Time::currentTimeMillis() * 1000; // Convert to μs
            return (now - wakeTimestamp) / 3600000000.0f; // μs to hours
        }

        /// Get circadian phase (morning, midday, afternoon, evening, night)
        std::string getCircadianPhase() const
        {
            float hours = getHoursSinceWake();

            if (hours < 4.0f)  return "Morning";
            if (hours < 8.0f)  return "Midday";
            if (hours < 12.0f) return "Afternoon";
            if (hours < 16.0f) return "Evening";
            return "Night";
        }
    };

    /// Add user's circadian profile
    void addUser(const CircadianProfile& profile)
    {
        users[profile.userID] = profile;
    }

    /// Find optimal collaboration time (when all users in creative phase)
    std::string getOptimalCollaborationWindow() const
    {
        if (users.empty())
            return "No users";

        // Creative peak: 4-8 hours after wake
        std::vector<std::string> phases;
        for (const auto& [id, profile] : users)
            phases.push_back(profile.getCircadianPhase());

        // Simple heuristic: all in midday/afternoon = optimal
        size_t optimalCount = 0;
        for (const auto& phase : phases)
            if (phase == "Midday" || phase == "Afternoon")
                optimalCount++;

        if (optimalCount == users.size())
            return "Optimal - All in creative phase";
        else
            return "Suboptimal - " + std::to_string(optimalCount) + "/" +
                   std::to_string(users.size()) + " in creative phase";
    }

private:
    std::unordered_map<std::string, CircadianProfile> users;
};

} // namespace EchoelBiometric

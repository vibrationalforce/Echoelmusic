#pragma once

#include <JuceHeader.h>
#include "UniversalConsolePlatform.h"

namespace Echoel {
namespace Platform {

//==============================================================================
/**
 * @brief XR Spatial Audio Engine
 *
 * Raumklang für VR/AR Umgebungen:
 * - HRTF-basiertes 3D Audio
 * - Raumakustik-Simulation
 * - Object-Based Audio
 * - Ambisonics Support
 */
class XRSpatialAudio
{
public:
    struct AudioSource3D
    {
        juce::String id;
        float posX = 0.0f;
        float posY = 0.0f;
        float posZ = 0.0f;
        float volume = 1.0f;
        float innerRadius = 1.0f;   // Full volume
        float outerRadius = 10.0f;  // Fade to zero
        bool isLooping = false;
        bool isSpatial = true;
        float dopplerFactor = 1.0f;
    };

    struct ListenerState
    {
        float posX = 0.0f;
        float posY = 0.0f;
        float posZ = 0.0f;
        float forwardX = 0.0f;
        float forwardY = 0.0f;
        float forwardZ = -1.0f;
        float upX = 0.0f;
        float upY = 1.0f;
        float upZ = 0.0f;
    };

    static XRSpatialAudio& getInstance()
    {
        static XRSpatialAudio instance;
        return instance;
    }

    void initialize(PlatformType platform)
    {
        xrPlatform = platform;

        switch (platform)
        {
            case PlatformType::PlayStation5:
                initializeTempest3D();
                break;
            case PlatformType::MetaQuest2:
            case PlatformType::MetaQuest3:
            case PlatformType::MetaQuestPro:
                initializeMetaSpatialAudio();
                break;
            case PlatformType::AppleVisionPro:
                initializeAppleSpatialAudio();
                break;
            case PlatformType::XboxSeriesX:
                initializeWindowsSonic();
                break;
            default:
                initializeGenericHRTF();
                break;
        }
    }

    void updateListener(const ListenerState& listener)
    {
        currentListener = listener;
        updateAllSources();
    }

    void updateListenerFromXRFrame(const XRIntegrationLayer::XRFrame& frame)
    {
        currentListener.posX = frame.headPosX;
        currentListener.posY = frame.headPosY;
        currentListener.posZ = frame.headPosZ;
        // Quaternion to forward vector conversion would go here
        updateAllSources();
    }

    juce::String createSource(const AudioSource3D& source)
    {
        sources[source.id] = source;
        return source.id;
    }

    void updateSourcePosition(const juce::String& id, float x, float y, float z)
    {
        if (sources.find(id) != sources.end())
        {
            sources[id].posX = x;
            sources[id].posY = y;
            sources[id].posZ = z;
            recalculateSourceSpatials(id);
        }
    }

    void removeSource(const juce::String& id)
    {
        sources.erase(id);
    }

    // Room acoustics
    struct RoomProperties
    {
        float width = 10.0f;
        float height = 3.0f;
        float depth = 10.0f;
        float absorption = 0.5f;       // 0 = fully reflective, 1 = fully absorptive
        float reverbTime = 1.0f;       // RT60 in seconds
        float earlyReflections = 0.3f; // Mix level
        float lateReverb = 0.2f;       // Mix level
    };

    void setRoomProperties(const RoomProperties& room)
    {
        currentRoom = room;
        updateReverbFromRoom();
    }

    // Ambisonics
    void setAmbisonicsOrder(int order)
    {
        ambisonicsOrder = juce::jlimit(1, 3, order);
        // First order = 4 channels
        // Second order = 9 channels
        // Third order = 16 channels
    }

private:
    void initializeTempest3D()
    {
        // PS5 Tempest 3D AudioTech
        hrtfEnabled = true;
        maxSources = 512;
    }

    void initializeMetaSpatialAudio()
    {
        // Meta Spatial Audio SDK
        hrtfEnabled = true;
        maxSources = 64;
    }

    void initializeAppleSpatialAudio()
    {
        // Apple Spatial Audio with head tracking
        hrtfEnabled = true;
        maxSources = 256;
        headTrackingEnabled = true;
    }

    void initializeWindowsSonic()
    {
        // Windows Sonic / Dolby Atmos
        hrtfEnabled = true;
        maxSources = 128;
    }

    void initializeGenericHRTF()
    {
        // Generic HRTF processing
        hrtfEnabled = true;
        maxSources = 32;
    }

    void updateAllSources()
    {
        for (auto& pair : sources)
        {
            recalculateSourceSpatials(pair.first);
        }
    }

    void recalculateSourceSpatials(const juce::String& id)
    {
        auto& source = sources[id];

        // Calculate distance
        float dx = source.posX - currentListener.posX;
        float dy = source.posY - currentListener.posY;
        float dz = source.posZ - currentListener.posZ;
        float distance = std::sqrt(dx*dx + dy*dy + dz*dz);

        // Distance attenuation
        float attenuation = 1.0f;
        if (distance > source.innerRadius)
        {
            float range = source.outerRadius - source.innerRadius;
            float fadeDistance = distance - source.innerRadius;
            attenuation = 1.0f - juce::jlimit(0.0f, 1.0f, fadeDistance / range);
        }

        // Calculate azimuth and elevation for HRTF
        // (Would use actual HRTF processing here)
    }

    void updateReverbFromRoom()
    {
        // Calculate reverb parameters from room properties
        float volume = currentRoom.width * currentRoom.height * currentRoom.depth;
        float surfaceArea = 2.0f * (
            currentRoom.width * currentRoom.height +
            currentRoom.height * currentRoom.depth +
            currentRoom.depth * currentRoom.width
        );

        // Sabine equation for RT60
        float rt60 = 0.161f * volume / (surfaceArea * currentRoom.absorption);
        currentRoom.reverbTime = rt60;
    }

    PlatformType xrPlatform = PlatformType::Unknown;
    std::map<juce::String, AudioSource3D> sources;
    ListenerState currentListener;
    RoomProperties currentRoom;

    bool hrtfEnabled = false;
    bool headTrackingEnabled = false;
    int maxSources = 32;
    int ambisonicsOrder = 1;
};

//==============================================================================
/**
 * @brief XR Spatial UI System
 *
 * 3D User Interfaces für VR/AR:
 * - Floating Panels
 * - Gaze-based Interaction
 * - Hand-tracked Gestures
 * - World-anchored Elements
 */
class XRSpatialUI
{
public:
    struct Panel3D
    {
        juce::String id;

        // Transform
        float posX = 0.0f;
        float posY = 1.5f;  // Eye level
        float posZ = -1.0f; // In front
        float rotX = 0.0f;
        float rotY = 0.0f;
        float rotZ = 0.0f;

        // Size (in meters)
        float width = 0.4f;
        float height = 0.3f;

        // Appearance
        float cornerRadius = 0.02f;
        float opacity = 0.9f;
        bool hasBackdrop = true;
        float backdropBlur = 10.0f;

        // Behavior
        bool followsGaze = false;
        bool isGrabbable = true;
        bool worldAnchored = false;
        juce::String anchorId;

        // Content
        juce::Component* content = nullptr;
    };

    struct InteractionState
    {
        bool isHovering = false;
        bool isGazing = false;
        bool isPinching = false;
        bool isGrabbing = false;
        float hoverProgress = 0.0f;  // For dwell-based selection
        juce::String hoveredPanelId;
        juce::Point<float> interactionPoint;
    };

    static XRSpatialUI& getInstance()
    {
        static XRSpatialUI instance;
        return instance;
    }

    void createPanel(const Panel3D& panel)
    {
        panels[panel.id] = panel;
    }

    void removePanel(const juce::String& id)
    {
        panels.erase(id);
    }

    void updatePanelPosition(const juce::String& id, float x, float y, float z)
    {
        if (panels.find(id) != panels.end())
        {
            panels[id].posX = x;
            panels[id].posY = y;
            panels[id].posZ = z;
        }
    }

    void updateFromInput(const UnifiedInputState& input)
    {
        // Eye tracking interaction
        if (input.eyes.isTracked)
        {
            updateGazeInteraction(input.eyes.gazeX, input.eyes.gazeY, input.eyes.gazeZ);
        }

        // Hand tracking interaction
        if (input.leftHandTracking.isTracked)
        {
            updateHandInteraction(input.leftHandTracking, true);
        }
        if (input.rightHandTracking.isTracked)
        {
            updateHandInteraction(input.rightHandTracking, false);
        }

        // Controller interaction
        updateControllerInteraction(input);
    }

    InteractionState getInteractionState() const { return interaction; }

    // Preset layouts
    void createMixerLayout()
    {
        // Create a curved array of channel strips
        int numChannels = 8;
        float radius = 1.5f;
        float startAngle = -45.0f;
        float endAngle = 45.0f;

        for (int i = 0; i < numChannels; ++i)
        {
            float t = static_cast<float>(i) / (numChannels - 1);
            float angle = juce::degreesToRadians(startAngle + t * (endAngle - startAngle));

            Panel3D panel;
            panel.id = "channel_" + juce::String(i);
            panel.posX = std::sin(angle) * radius;
            panel.posY = 1.2f;
            panel.posZ = -std::cos(angle) * radius;
            panel.rotY = -angle;
            panel.width = 0.15f;
            panel.height = 0.5f;

            createPanel(panel);
        }
    }

    void createInstrumentLayout()
    {
        // Main instrument panel in front
        Panel3D mainPanel;
        mainPanel.id = "instrument_main";
        mainPanel.posX = 0.0f;
        mainPanel.posY = 1.0f;
        mainPanel.posZ = -0.8f;
        mainPanel.width = 0.8f;
        mainPanel.height = 0.4f;
        createPanel(mainPanel);

        // Controls on left
        Panel3D leftPanel;
        leftPanel.id = "instrument_controls";
        leftPanel.posX = -0.5f;
        leftPanel.posY = 1.2f;
        leftPanel.posZ = -0.6f;
        leftPanel.rotY = 0.3f;
        leftPanel.width = 0.3f;
        leftPanel.height = 0.4f;
        createPanel(leftPanel);

        // Presets on right
        Panel3D rightPanel;
        rightPanel.id = "instrument_presets";
        rightPanel.posX = 0.5f;
        rightPanel.posY = 1.2f;
        rightPanel.posZ = -0.6f;
        rightPanel.rotY = -0.3f;
        rightPanel.width = 0.3f;
        rightPanel.height = 0.4f;
        createPanel(rightPanel);
    }

    void createWellnessLayout()
    {
        // Immersive wellness space

        // Main visualization dome above
        Panel3D domePanel;
        domePanel.id = "wellness_visualization";
        domePanel.posY = 2.5f;
        domePanel.posZ = 0.0f;
        domePanel.width = 3.0f;
        domePanel.height = 3.0f;
        domePanel.opacity = 0.5f;
        createPanel(domePanel);

        // Biofeedback panel at eye level
        Panel3D bioPanel;
        bioPanel.id = "wellness_biofeedback";
        bioPanel.posX = 0.0f;
        bioPanel.posY = 1.4f;
        bioPanel.posZ = -1.0f;
        bioPanel.width = 0.5f;
        bioPanel.height = 0.3f;
        createPanel(bioPanel);

        // Breathing guide on floor
        Panel3D breathPanel;
        breathPanel.id = "wellness_breath";
        breathPanel.posX = 0.0f;
        breathPanel.posY = 0.1f;
        breathPanel.posZ = 0.0f;
        breathPanel.rotX = -1.57f;  // Facing up
        breathPanel.width = 1.0f;
        breathPanel.height = 1.0f;
        breathPanel.opacity = 0.3f;
        createPanel(breathPanel);
    }

private:
    void updateGazeInteraction(float gazeX, float gazeY, float gazeZ)
    {
        // Ray-cast from eyes to find hovered panel
        for (auto& pair : panels)
        {
            // Simplified hit test
            // Real implementation would do proper 3D intersection
            float dx = pair.second.posX - gazeX;
            float dy = pair.second.posY - gazeY;
            float dz = pair.second.posZ - gazeZ;

            if (std::abs(dx) < pair.second.width / 2 &&
                std::abs(dy) < pair.second.height / 2)
            {
                interaction.isGazing = true;
                interaction.hoveredPanelId = pair.first;

                // Dwell-based selection
                interaction.hoverProgress += 0.016f;  // ~60fps
                if (interaction.hoverProgress > 1.0f)
                {
                    onPanelSelected(pair.first);
                    interaction.hoverProgress = 0.0f;
                }
                return;
            }
        }

        interaction.isGazing = false;
        interaction.hoverProgress = 0.0f;
    }

    void updateHandInteraction(const UnifiedInputState::HandTracking& hand, bool isLeft)
    {
        if (hand.isPinching)
        {
            interaction.isPinching = true;
            if (!interaction.hoveredPanelId.isEmpty())
            {
                onPanelSelected(interaction.hoveredPanelId);
            }
        }

        if (hand.isGrabbing)
        {
            interaction.isGrabbing = true;
            // Panel dragging logic
        }
    }

    void updateControllerInteraction(const UnifiedInputState& input)
    {
        // Laser pointer from controller
        // Hit test against panels
    }

    void onPanelSelected(const juce::String& panelId)
    {
        // Trigger haptic feedback
        HapticFeedbackSystem::getInstance().triggerHaptic(
            HapticFeedbackSystem::HapticType::Selection
        );

        // Notify callback
        if (onPanelSelectedCallback)
            onPanelSelectedCallback(panelId);
    }

    std::map<juce::String, Panel3D> panels;
    InteractionState interaction;

public:
    std::function<void(const juce::String&)> onPanelSelectedCallback;
};

//==============================================================================
/**
 * @brief XR Embodiment System
 *
 * Avatar und Körper-Tracking für soziale VR
 */
class XREmbodiment
{
public:
    struct AvatarState
    {
        // Head
        float headPosX, headPosY, headPosZ;
        float headRotX, headRotY, headRotZ, headRotW;

        // Hands
        float leftHandPosX, leftHandPosY, leftHandPosZ;
        float leftHandRotX, leftHandRotY, leftHandRotZ, leftHandRotW;
        float rightHandPosX, rightHandPosY, rightHandPosZ;
        float rightHandRotX, rightHandRotY, rightHandRotZ, rightHandRotW;

        // Finger poses (per hand, 5 fingers x 4 joints)
        float leftFingers[20];
        float rightFingers[20];

        // Body (estimated)
        float torsoRotY;
        float shoulderWidth;

        // Expression (if face tracking)
        float mouthOpen;
        float smile;
        float browRaise;
        float eyesClosed;
    };

    static XREmbodiment& getInstance()
    {
        static XREmbodiment instance;
        return instance;
    }

    void updateFromInput(const UnifiedInputState& input, const XRIntegrationLayer::XRFrame& frame)
    {
        // Update avatar from tracking data
        avatar.headPosX = frame.headPosX;
        avatar.headPosY = frame.headPosY;
        avatar.headPosZ = frame.headPosZ;
        avatar.headRotX = frame.headRotX;
        avatar.headRotY = frame.headRotY;
        avatar.headRotZ = frame.headRotZ;
        avatar.headRotW = frame.headRotW;

        // Hand tracking
        if (input.leftHandTracking.isTracked)
        {
            // Update left hand pose
        }
        if (input.rightHandTracking.isTracked)
        {
            // Update right hand pose
        }

        // Controller-based hand pose
        avatar.leftHandPosX = input.leftHand.positionX;
        avatar.leftHandPosY = input.leftHand.positionY;
        avatar.leftHandPosZ = input.leftHand.positionZ;
    }

    AvatarState getAvatarState() const { return avatar; }

    // For multiplayer/social
    void setRemoteAvatar(const juce::String& odId, const AvatarState& state)
    {
        remoteAvatars[odId] = state;
    }

    std::map<juce::String, AvatarState> getRemoteAvatars() const
    {
        return remoteAvatars;
    }

private:
    AvatarState avatar;
    std::map<juce::String, AvatarState> remoteAvatars;
};

} // namespace Platform
} // namespace Echoel

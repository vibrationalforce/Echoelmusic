#pragma once

/**
 * AdvancedGestureProcessor.h - Optimized Gesture Recognition Engine
 *
 * ╔══════════════════════════════════════════════════════════════════════════╗
 * ║  RALPH WIGGUM LOOP MODE - ADVANCED GESTURE PROCESSING                    ║
 * ╠══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                          ║
 * ║  FEATURES:                                                               ║
 * ║    • Kalman-filtered hand/face tracking                                  ║
 * ║    • State machine gesture recognition                                   ║
 * ║    • Gesture velocity and acceleration tracking                          ║
 * ║    • Multi-hand coordination detection                                   ║
 * ║    • Gesture prediction for anticipatory audio response                  ║
 * ║    • Configurable gesture thresholds and timing                          ║
 * ║                                                                          ║
 * ║  LATENCY TARGETS:                                                        ║
 * ║    • Gesture detection: < 16ms (60 fps)                                  ║
 * ║    • Position filtering: < 1ms                                           ║
 * ║    • State machine update: < 0.5ms                                       ║
 * ║                                                                          ║
 * ╚══════════════════════════════════════════════════════════════════════════╝
 */

#include "BioGestureOptimizations.h"
#include <JuceHeader.h>
#include <array>
#include <deque>

namespace Echoel::Bio
{

//==============================================================================
// Hand Joint Indices (Vision Framework compatible)
//==============================================================================

enum class HandJoint
{
    Wrist = 0,
    ThumbCMC, ThumbMP, ThumbIP, ThumbTip,
    IndexMCP, IndexPIP, IndexDIP, IndexTip,
    MiddleMCP, MiddlePIP, MiddleDIP, MiddleTip,
    RingMCP, RingPIP, RingDIP, RingTip,
    LittleMCP, LittlePIP, LittleDIP, LittleTip,
    Count = 21
};

//==============================================================================
/**
 * @brief Hand Tracking Data with Kalman Filtering
 */
class BIO_CACHE_ALIGN OptimizedHandTracker
{
public:
    static constexpr int NUM_JOINTS = static_cast<int>(HandJoint::Count);
    static constexpr int HISTORY_SIZE = 5;

    struct HandData
    {
        // Filtered joint positions (x, y, confidence)
        std::array<float, NUM_JOINTS * 3> joints;

        // Derived metrics
        float handSpan = 0.0f;              // Wrist to middle tip distance
        float handOpenness = 0.0f;          // 0=closed, 1=open
        std::array<float, 5> fingerExtension; // Per-finger extension 0-1

        // 3D position estimate (normalized -1 to 1)
        float posX = 0.0f, posY = 0.0f, posZ = 0.0f;

        // Velocity (units per second)
        float velX = 0.0f, velY = 0.0f, velZ = 0.0f;

        // State
        bool isTracked = false;
        float confidence = 0.0f;
        int64_t lastUpdateMs = 0;
    };

    OptimizedHandTracker()
    {
        // Initialize Kalman filters for each joint
        for (int i = 0; i < NUM_JOINTS; ++i)
        {
            jointFiltersX[i] = KalmanFilter1D(0.01f, 0.1f);
            jointFiltersY[i] = KalmanFilter1D(0.01f, 0.1f);
        }
        positionFilter.setNoiseParameters(0.005f, 0.05f);
    }

    void reset()
    {
        leftHand = HandData();
        rightHand = HandData();
        for (int i = 0; i < NUM_JOINTS; ++i)
        {
            jointFiltersX[i].reset();
            jointFiltersY[i].reset();
        }
        positionFilter.reset();
        positionHistory.clear();
    }

    /**
     * Update hand tracking with raw joint positions
     * @param isLeft True for left hand, false for right
     * @param rawJoints Array of [x, y, confidence] * 21 joints
     */
    void updateHand(bool isLeft, const float* rawJoints, int numJoints)
    {
        if (numJoints != NUM_JOINTS)
            return;

        HandData& hand = isLeft ? leftHand : rightHand;
        int64_t now = juce::Time::currentTimeMillis();

        // Calculate delta time
        float dt = (hand.lastUpdateMs > 0) ?
            static_cast<float>(now - hand.lastUpdateMs) / 1000.0f : 0.016f;
        dt = juce::jlimit(0.001f, 0.1f, dt);

        // Store previous position for velocity calculation
        float prevX = hand.posX;
        float prevY = hand.posY;
        float prevZ = hand.posZ;

        // Apply Kalman filtering to each joint
        float totalConfidence = 0.0f;
        for (int i = 0; i < NUM_JOINTS; ++i)
        {
            float rawX = rawJoints[i * 3];
            float rawY = rawJoints[i * 3 + 1];
            float conf = rawJoints[i * 3 + 2];

            // Filter position
            float filteredX = jointFiltersX[i].update(rawX);
            float filteredY = jointFiltersY[i].update(rawY);

            hand.joints[i * 3] = filteredX;
            hand.joints[i * 3 + 1] = filteredY;
            hand.joints[i * 3 + 2] = conf;

            totalConfidence += conf;
        }

        hand.confidence = totalConfidence / static_cast<float>(NUM_JOINTS);
        hand.isTracked = hand.confidence > 0.3f;

        if (hand.isTracked)
        {
            // Calculate hand metrics
            calculateHandMetrics(hand);

            // Filter overall position
            auto filteredPos = positionFilter.update(hand.posX, hand.posY, hand.posZ);
            hand.posX = filteredPos.x;
            hand.posY = filteredPos.y;
            hand.posZ = filteredPos.z;

            // Calculate velocity
            hand.velX = (hand.posX - prevX) / dt;
            hand.velY = (hand.posY - prevY) / dt;
            hand.velZ = (hand.posZ - prevZ) / dt;

            // Store in history for prediction
            positionHistory.push_back({hand.posX, hand.posY, hand.posZ, now});
            if (positionHistory.size() > HISTORY_SIZE)
                positionHistory.pop_front();
        }

        hand.lastUpdateMs = now;
    }

    const HandData& getLeftHand() const { return leftHand; }
    const HandData& getRightHand() const { return rightHand; }

    /**
     * Predict hand position N milliseconds in the future
     */
    KalmanFilter3D::Position predictPosition(bool isLeft, int futureMs) const
    {
        const HandData& hand = isLeft ? leftHand : rightHand;
        float dt = static_cast<float>(futureMs) / 1000.0f;

        return {
            hand.posX + hand.velX * dt,
            hand.posY + hand.velY * dt,
            hand.posZ + hand.velZ * dt
        };
    }

private:
    HandData leftHand, rightHand;

    // Kalman filters for each joint (X and Y)
    std::array<KalmanFilter1D, NUM_JOINTS> jointFiltersX;
    std::array<KalmanFilter1D, NUM_JOINTS> jointFiltersY;

    // Overall position filter
    KalmanFilter3D positionFilter;

    // Position history for prediction
    struct PositionSample { float x, y, z; int64_t timeMs; };
    std::deque<PositionSample> positionHistory;

    void calculateHandMetrics(HandData& hand)
    {
        // Wrist position
        float wristX = hand.joints[0];
        float wristY = hand.joints[1];

        // Middle finger tip position
        int middleTipIdx = static_cast<int>(HandJoint::MiddleTip) * 3;
        float middleX = hand.joints[middleTipIdx];
        float middleY = hand.joints[middleTipIdx + 1];

        // Hand span
        float dx = middleX - wristX;
        float dy = middleY - wristY;
        hand.handSpan = std::sqrt(dx * dx + dy * dy);

        // 3D position from hand centroid
        float sumX = 0, sumY = 0;
        for (int i = 0; i < NUM_JOINTS; ++i)
        {
            sumX += hand.joints[i * 3];
            sumY += hand.joints[i * 3 + 1];
        }
        hand.posX = (sumX / NUM_JOINTS) * 2.0f - 1.0f;  // Normalize to -1..1
        hand.posY = (sumY / NUM_JOINTS) * 2.0f - 1.0f;
        hand.posZ = hand.handSpan * 2.0f;  // Depth from hand size

        // Calculate finger extension for each finger
        calculateFingerExtension(hand, HandJoint::ThumbCMC, HandJoint::ThumbTip, 0);
        calculateFingerExtension(hand, HandJoint::IndexMCP, HandJoint::IndexTip, 1);
        calculateFingerExtension(hand, HandJoint::MiddleMCP, HandJoint::MiddleTip, 2);
        calculateFingerExtension(hand, HandJoint::RingMCP, HandJoint::RingTip, 3);
        calculateFingerExtension(hand, HandJoint::LittleMCP, HandJoint::LittleTip, 4);

        // Overall hand openness
        hand.handOpenness = 0.0f;
        for (int i = 0; i < 5; ++i)
            hand.handOpenness += hand.fingerExtension[i];
        hand.handOpenness /= 5.0f;
    }

    void calculateFingerExtension(HandData& hand, HandJoint base, HandJoint tip, int fingerIdx)
    {
        int baseIdx = static_cast<int>(base) * 3;
        int tipIdx = static_cast<int>(tip) * 3;

        float dx = hand.joints[tipIdx] - hand.joints[baseIdx];
        float dy = hand.joints[tipIdx + 1] - hand.joints[baseIdx + 1];
        float distance = std::sqrt(dx * dx + dy * dy);

        // Normalize: ~0.1 = closed, ~0.3 = extended
        hand.fingerExtension[fingerIdx] = juce::jlimit(0.0f, 1.0f,
            (distance - 0.05f) / 0.25f);
    }
};

//==============================================================================
/**
 * @brief Face Expression Tracker with Smoothing
 */
class BIO_CACHE_ALIGN OptimizedFaceTracker
{
public:
    static constexpr int NUM_EXPRESSIONS = 13;

    struct FaceData
    {
        // Primary expressions (smoothed)
        float jawOpen = 0.0f;
        float mouthSmileLeft = 0.0f;
        float mouthSmileRight = 0.0f;
        float browInnerUp = 0.0f;
        float browOuterUpLeft = 0.0f;
        float browOuterUpRight = 0.0f;
        float eyeBlinkLeft = 0.0f;
        float eyeBlinkRight = 0.0f;
        float eyeWideLeft = 0.0f;
        float eyeWideRight = 0.0f;
        float mouthFunnel = 0.0f;
        float mouthPucker = 0.0f;
        float cheekPuff = 0.0f;

        // Derived expressions
        float smile = 0.0f;         // Average of left/right smile
        float browRaise = 0.0f;     // Average of brow expressions
        float eyeBlink = 0.0f;      // Average blink
        float eyeWide = 0.0f;       // Average eye wide

        // Head transform
        float headX = 0.0f, headY = 0.0f, headZ = 0.0f;
        float headPitch = 0.0f, headYaw = 0.0f, headRoll = 0.0f;

        // State
        bool isTracked = false;
        float trackingQuality = 0.0f;
        int64_t lastUpdateMs = 0;
    };

    OptimizedFaceTracker()
    {
        for (int i = 0; i < NUM_EXPRESSIONS; ++i)
            expressionFilters[i] = KalmanFilter1D(0.02f, 0.08f);
    }

    void reset()
    {
        faceData = FaceData();
        for (int i = 0; i < NUM_EXPRESSIONS; ++i)
            expressionFilters[i].reset();
    }

    /**
     * Update face tracking with blend shape values
     * @param blendShapes Array of expression values (0-1)
     */
    void updateFace(const float* blendShapes, int numShapes,
                    float quality, const float* headTransform = nullptr)
    {
        if (numShapes < NUM_EXPRESSIONS)
            return;

        int64_t now = juce::Time::currentTimeMillis();

        // Apply Kalman filtering to each expression
        faceData.jawOpen = expressionFilters[0].update(blendShapes[0]);
        faceData.mouthSmileLeft = expressionFilters[1].update(blendShapes[1]);
        faceData.mouthSmileRight = expressionFilters[2].update(blendShapes[2]);
        faceData.browInnerUp = expressionFilters[3].update(blendShapes[3]);
        faceData.browOuterUpLeft = expressionFilters[4].update(blendShapes[4]);
        faceData.browOuterUpRight = expressionFilters[5].update(blendShapes[5]);
        faceData.eyeBlinkLeft = expressionFilters[6].update(blendShapes[6]);
        faceData.eyeBlinkRight = expressionFilters[7].update(blendShapes[7]);
        faceData.eyeWideLeft = expressionFilters[8].update(blendShapes[8]);
        faceData.eyeWideRight = expressionFilters[9].update(blendShapes[9]);
        faceData.mouthFunnel = expressionFilters[10].update(blendShapes[10]);
        faceData.mouthPucker = expressionFilters[11].update(blendShapes[11]);
        faceData.cheekPuff = expressionFilters[12].update(blendShapes[12]);

        // Compute derived expressions
        faceData.smile = (faceData.mouthSmileLeft + faceData.mouthSmileRight) * 0.5f;
        faceData.browRaise = (faceData.browInnerUp + faceData.browOuterUpLeft +
                              faceData.browOuterUpRight) / 3.0f;
        faceData.eyeBlink = (faceData.eyeBlinkLeft + faceData.eyeBlinkRight) * 0.5f;
        faceData.eyeWide = (faceData.eyeWideLeft + faceData.eyeWideRight) * 0.5f;

        // Head transform if available
        if (headTransform)
        {
            faceData.headX = headTransform[0];
            faceData.headY = headTransform[1];
            faceData.headZ = headTransform[2];
            faceData.headPitch = headTransform[3];
            faceData.headYaw = headTransform[4];
            faceData.headRoll = headTransform[5];
        }

        faceData.trackingQuality = quality;
        faceData.isTracked = quality > 0.3f;
        faceData.lastUpdateMs = now;
    }

    const FaceData& getFaceData() const { return faceData; }

private:
    FaceData faceData;
    std::array<KalmanFilter1D, NUM_EXPRESSIONS> expressionFilters;
};

//==============================================================================
/**
 * @brief Unified Gesture-to-Audio Parameter Mapper
 */
class BIO_CACHE_ALIGN GestureAudioMapper
{
public:
    struct AudioParams
    {
        // From hand gestures
        float filterCutoffL = 1000.0f;   // Left hand → filter
        float filterCutoffR = 1000.0f;   // Right hand → filter
        float reverbSize = 0.5f;         // Spread gesture → reverb
        float reverbMix = 0.3f;          // Spread gesture → reverb
        float delayTime = 300.0f;        // Point gesture → delay

        // From face expressions
        float faceFilterCutoff = 1000.0f; // Jaw → filter
        float faceStereoWidth = 1.0f;     // Smile → stereo
        float faceReverbSize = 0.5f;      // Brow → reverb
        float faceResonance = 0.707f;     // Funnel → Q

        // MIDI triggers
        bool triggerNoteLeft = false;
        bool triggerNoteRight = false;
        int midiNoteLeft = 60;
        int midiNoteRight = 67;
        int midiVelocity = 100;
    };

    GestureAudioMapper()
    {
        lastTriggerTimeL = 0;
        lastTriggerTimeR = 0;
    }

    AudioParams mapGestures(const OptimizedHandTracker::HandData& leftHand,
                            const OptimizedHandTracker::HandData& rightHand,
                            const GestureStateMachine& gestureState,
                            const OptimizedFaceTracker::FaceData& face)
    {
        AudioParams params;
        auto& lut = BioParameterLUT::getInstance();
        int64_t now = juce::Time::currentTimeMillis();

        // ===== Hand Gesture Mapping =====

        auto leftState = gestureState.getState(GestureStateMachine::Hand::Left);
        auto rightState = gestureState.getState(GestureStateMachine::Hand::Right);

        // Pinch → Filter cutoff
        if (leftHand.isTracked)
        {
            float pinchAmount = 1.0f - leftHand.fingerExtension[1];  // Index finger
            params.filterCutoffL = lut.gestureToParameter(pinchAmount, 200.0f, 8000.0f);
        }

        if (rightHand.isTracked)
        {
            float pinchAmount = 1.0f - rightHand.fingerExtension[1];
            params.filterCutoffR = lut.gestureToParameter(pinchAmount, 200.0f, 8000.0f);
        }

        // Spread → Reverb
        if (leftHand.isTracked && leftState.gesture == GestureStateMachine::Gesture::Spread)
        {
            params.reverbSize = lut.gestureToParameter(leftHand.handOpenness, 0.0f, 1.0f);
        }

        if (rightHand.isTracked && rightState.gesture == GestureStateMachine::Gesture::Spread)
        {
            params.reverbMix = lut.gestureToParameter(rightHand.handOpenness, 0.0f, 1.0f);
        }

        // Fist → MIDI trigger (with cooldown)
        if (leftState.isConfirmed && leftState.gesture == GestureStateMachine::Gesture::Fist)
        {
            if (now - lastTriggerTimeL > 300)
            {
                params.triggerNoteLeft = true;
                lastTriggerTimeL = now;
            }
        }

        if (rightState.isConfirmed && rightState.gesture == GestureStateMachine::Gesture::Fist)
        {
            if (now - lastTriggerTimeR > 300)
            {
                params.triggerNoteRight = true;
                lastTriggerTimeR = now;
            }
        }

        // Point → Delay time
        if (rightHand.isTracked && rightState.gesture == GestureStateMachine::Gesture::Point)
        {
            params.delayTime = lut.gestureToParameter(rightHand.fingerExtension[1], 100.0f, 2000.0f);
        }

        // ===== Face Expression Mapping =====

        if (face.isTracked)
        {
            // Jaw → Filter cutoff (exponential)
            params.faceFilterCutoff = lut.jawToFilterCutoff(face.jawOpen);

            // Smile → Stereo width
            params.faceStereoWidth = lut.gestureToParameter(face.smile, 0.5f, 2.0f);

            // Brow raise → Reverb size
            params.faceReverbSize = lut.gestureToParameter(face.browRaise, 0.5f, 5.0f);

            // Mouth funnel → Filter resonance
            params.faceResonance = lut.gestureToParameter(face.mouthFunnel, 0.707f, 5.0f);
        }

        // Smooth all parameters
        params = smoothParameters(params);

        return params;
    }

private:
    AudioParams lastParams;
    int64_t lastTriggerTimeL, lastTriggerTimeR;

    AudioParams smoothParameters(const AudioParams& target)
    {
        constexpr float SMOOTH = 0.85f;
        AudioParams smoothed;

        smoothed.filterCutoffL = lastParams.filterCutoffL * SMOOTH + target.filterCutoffL * (1.0f - SMOOTH);
        smoothed.filterCutoffR = lastParams.filterCutoffR * SMOOTH + target.filterCutoffR * (1.0f - SMOOTH);
        smoothed.reverbSize = lastParams.reverbSize * SMOOTH + target.reverbSize * (1.0f - SMOOTH);
        smoothed.reverbMix = lastParams.reverbMix * SMOOTH + target.reverbMix * (1.0f - SMOOTH);
        smoothed.delayTime = lastParams.delayTime * SMOOTH + target.delayTime * (1.0f - SMOOTH);
        smoothed.faceFilterCutoff = lastParams.faceFilterCutoff * SMOOTH + target.faceFilterCutoff * (1.0f - SMOOTH);
        smoothed.faceStereoWidth = lastParams.faceStereoWidth * SMOOTH + target.faceStereoWidth * (1.0f - SMOOTH);
        smoothed.faceReverbSize = lastParams.faceReverbSize * SMOOTH + target.faceReverbSize * (1.0f - SMOOTH);
        smoothed.faceResonance = lastParams.faceResonance * SMOOTH + target.faceResonance * (1.0f - SMOOTH);

        // Triggers are not smoothed
        smoothed.triggerNoteLeft = target.triggerNoteLeft;
        smoothed.triggerNoteRight = target.triggerNoteRight;
        smoothed.midiNoteLeft = target.midiNoteLeft;
        smoothed.midiNoteRight = target.midiNoteRight;
        smoothed.midiVelocity = target.midiVelocity;

        lastParams = smoothed;
        return smoothed;
    }
};

}  // namespace Echoel::Bio

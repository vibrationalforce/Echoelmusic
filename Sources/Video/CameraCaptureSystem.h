/*
  ==============================================================================
   ECHOELMUSIC - Camera Capture System
   Professional camera capture with ML-powered white balance

   Features:
   - Professional White Balance Presets (Daylight 5778K, Tungsten 3200K, LED 5600K)
   - Auto-ML White Balance mit CoreML/TensorFlow Lite
   - Face Detection & Emotion Recognition (OpenCV/Vision)
   - Body Pose Tracking (OpenPose/MediaPipe)
   - Object Detection (YOLO v8)
   - Cross-Platform (iOS AVFoundation, Android Camera2, Desktop OpenCV)
  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>

namespace Echoelmusic {
namespace Video {

//==============================================================================
/** White Balance Presets basierend auf professionellen Standards */
struct WhiteBalancePreset {
    const char* name;
    float kelvin;           // Color temperature in Kelvin
    float tint;            // Green-Magenta tint (-1.0 to 1.0)
    float rGain;           // Red channel gain
    float gGain;           // Green channel gain
    float bGain;           // Blue channel gain
};

static const WhiteBalancePreset kWhiteBalancePresets[] = {
    { "Daylight (Sun)",     5778.0f,  0.0f,  1.00f, 1.00f, 1.15f },  // Sonnenlicht
    { "Cloudy",             6500.0f,  0.0f,  1.05f, 1.00f, 1.20f },  // Bewölkt
    { "Shade",              7500.0f,  0.0f,  1.10f, 1.00f, 1.25f },  // Schatten
    { "Tungsten",           3200.0f,  0.0f,  0.75f, 1.00f, 1.35f },  // Kunstlicht (Glühbirne)
    { "Fluorescent Cool",   4000.0f,  0.2f,  0.85f, 1.00f, 1.25f },  // Neonlicht kalt
    { "Fluorescent Warm",   3700.0f, -0.1f,  0.80f, 1.00f, 1.30f },  // Neonlicht warm
    { "LED 5600K",          5600.0f,  0.0f,  0.98f, 1.00f, 1.18f },  // LED Studio
    { "LED 3200K",          3200.0f,  0.0f,  0.76f, 1.00f, 1.34f },  // LED Warm
    { "Flash",              5500.0f,  0.0f,  0.97f, 1.00f, 1.17f },  // Blitzlicht
    { "Auto ML",            0.0f,     0.0f,  1.00f, 1.00f, 1.00f }   // ML-basiert (wird berechnet)
};

//==============================================================================
/** Face Detection Result */
struct FaceDetection {
    juce::Rectangle<float> boundingBox;  // Normalized 0-1
    float confidence;

    // Emotion Recognition (0.0 - 1.0)
    float happiness;
    float sadness;
    float anger;
    float surprise;
    float fear;
    float disgust;
    float neutral;

    // Face landmarks
    juce::Point<float> leftEye;
    juce::Point<float> rightEye;
    juce::Point<float> nose;
    juce::Point<float> mouth;
};

//==============================================================================
/** Body Pose Keypoint (25 points MediaPipe style) */
struct PoseKeypoint {
    juce::Point<float> position;  // Normalized 0-1
    float confidence;
    float visibility;
};

struct BodyPose {
    std::vector<PoseKeypoint> keypoints;  // 25 keypoints (MediaPipe Pose)
    float overallConfidence;
};

//==============================================================================
/** Object Detection Result (YOLO) */
struct ObjectDetection {
    juce::String className;
    juce::Rectangle<float> boundingBox;  // Normalized 0-1
    float confidence;
    int classId;
};

//==============================================================================
/**
 * Camera Capture System
 *
 * Cross-platform camera capture with professional features:
 * - White balance control (manual presets + auto ML)
 * - Real-time face detection & emotion recognition
 * - Body pose tracking (25 keypoints)
 * - Object detection (YOLO v8)
 */
class CameraCaptureSystem {
public:
    CameraCaptureSystem();
    ~CameraCaptureSystem();

    //==============================================================================
    // Camera Control
    void startCapture(int deviceIndex = 0);
    void stopCapture();
    bool isCapturing() const { return capturing; }

    void setResolution(int width, int height);
    void setFrameRate(int fps);

    //==============================================================================
    // White Balance Control
    void setWhiteBalancePreset(int presetIndex);
    void setWhiteBalanceKelvin(float kelvin);
    void setWhiteBalanceTint(float tint);  // -1.0 (green) to 1.0 (magenta)
    void enableAutoWhiteBalance(bool enable);

    const WhiteBalancePreset& getCurrentWhiteBalancePreset() const {
        return kWhiteBalancePresets[currentPresetIndex];
    }

    //==============================================================================
    // AI/ML Features
    void enableFaceDetection(bool enable);
    void enableEmotionRecognition(bool enable);
    void enableBodyPoseTracking(bool enable);
    void enableObjectDetection(bool enable);

    const std::vector<FaceDetection>& getDetectedFaces() const { return detectedFaces; }
    const BodyPose& getDetectedPose() const { return detectedPose; }
    const std::vector<ObjectDetection>& getDetectedObjects() const { return detectedObjects; }

    //==============================================================================
    // Frame Access
    juce::Image getCurrentFrame() const;
    juce::Image getCurrentFrameWithOverlays() const;  // With bounding boxes

    int getFrameWidth() const { return frameWidth; }
    int getFrameHeight() const { return frameHeight; }
    float getCurrentFPS() const { return currentFPS; }

    //==============================================================================
    // Callbacks
    std::function<void(const juce::Image&)> onFrameReceived;
    std::function<void(const std::vector<FaceDetection>&)> onFacesDetected;
    std::function<void(const BodyPose&)> onPoseDetected;
    std::function<void(const std::vector<ObjectDetection>&)> onObjectsDetected;

private:
    //==============================================================================
    // Internal processing
    void processFrame();
    void applyWhiteBalance(juce::Image& frame);
    void calculateAutoWhiteBalance(const juce::Image& frame);
    void detectFaces(const juce::Image& frame);
    void recognizeEmotions(const std::vector<FaceDetection>& faces);
    void trackBodyPose(const juce::Image& frame);
    void detectObjects(const juce::Image& frame);

    // Color temperature conversion
    void kelvinToRGB(float kelvin, float& r, float& g, float& b);

    //==============================================================================
    // State
    bool capturing = false;
    int frameWidth = 1920;
    int frameHeight = 1080;
    int targetFPS = 30;
    float currentFPS = 0.0f;

    // White balance
    int currentPresetIndex = 0;  // Daylight default
    bool autoWhiteBalance = false;
    float customKelvin = 5778.0f;
    float customTint = 0.0f;

    // AI features
    bool faceDetectionEnabled = false;
    bool emotionRecognitionEnabled = false;
    bool poseTrackingEnabled = false;
    bool objectDetectionEnabled = false;

    // Detection results
    std::vector<FaceDetection> detectedFaces;
    BodyPose detectedPose;
    std::vector<ObjectDetection> detectedObjects;

    // Current frame
    juce::Image currentFrame;
    juce::CriticalSection frameLock;

    // Platform-specific capture (would be implemented per platform)
#if JUCE_IOS || JUCE_MAC
    // AVFoundation capture session
    void* captureSession = nullptr;  // AVCaptureSession*
#elif JUCE_ANDROID
    // Android Camera2 API
    void* cameraDevice = nullptr;
#else
    // OpenCV VideoCapture (Desktop fallback)
    void* videoCapture = nullptr;
#endif

    // ML models (platform-specific)
    void* faceDetectionModel = nullptr;      // Platform-specific ML model
    void* emotionRecognitionModel = nullptr;
    void* poseTrackingModel = nullptr;
    void* objectDetectionModel = nullptr;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CameraCaptureSystem)
};

//==============================================================================
/**
 * Auto White Balance using Grey World Algorithm + ML enhancement
 *
 * Grey World Algorithm:
 * Annahme: Durchschnitt aller Farben in einem Bild sollte grau sein
 *
 * Formula:
 *   avgR = mean(red channel)
 *   avgG = mean(green channel)
 *   avgB = mean(blue channel)
 *
 *   rGain = avgG / avgR
 *   bGain = avgG / avgB
 *   gGain = 1.0
 */
class AutoWhiteBalanceML {
public:
    struct Result {
        float kelvin;
        float tint;
        float rGain;
        float gGain;
        float bGain;
        float confidence;  // 0.0 - 1.0
    };

    static Result calculate(const juce::Image& frame) {
        Result result;

        // Grey World Algorithm
        float avgR = 0.0f, avgG = 0.0f, avgB = 0.0f;
        int pixelCount = frame.getWidth() * frame.getHeight();

        juce::Image::BitmapData bitmap(frame, juce::Image::BitmapData::readOnly);

        for (int y = 0; y < frame.getHeight(); ++y) {
            for (int x = 0; x < frame.getWidth(); ++x) {
                juce::Colour pixel = bitmap.getPixelColour(x, y);
                avgR += pixel.getFloatRed();
                avgG += pixel.getFloatGreen();
                avgB += pixel.getFloatBlue();
            }
        }

        avgR /= pixelCount;
        avgG /= pixelCount;
        avgB /= pixelCount;

        // Calculate gains
        result.rGain = avgG / juce::jmax(avgR, 0.01f);
        result.gGain = 1.0f;
        result.bGain = avgG / juce::jmax(avgB, 0.01f);

        // Estimate Kelvin from RGB ratio
        float rbRatio = avgR / juce::jmax(avgB, 0.01f);
        result.kelvin = estimateKelvinFromRBRatio(rbRatio);
        result.tint = 0.0f;
        result.confidence = 0.85f;  // TODO: ML model would provide better confidence

        return result;
    }

private:
    static float estimateKelvinFromRBRatio(float rbRatio) {
        // Approximation: Higher R/B ratio = warmer (lower Kelvin)
        // 3200K (tungsten): R/B ≈ 0.56
        // 5778K (daylight): R/B ≈ 0.87
        // 6500K (cloudy): R/B ≈ 0.88

        if (rbRatio < 0.65f) return 3200.0f;
        if (rbRatio < 0.80f) return 4000.0f;
        if (rbRatio < 0.86f) return 5000.0f;
        if (rbRatio < 0.90f) return 5778.0f;
        if (rbRatio < 0.95f) return 6500.0f;
        return 7500.0f;
    }
};

} // namespace Video
} // namespace Echoelmusic

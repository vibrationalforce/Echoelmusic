/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║                    XY BIO-REACTIVE SURFACE                                 ║
 * ║                                                                            ║
 * ║     "Surf Your Biology Through Sound"                                      ║
 * ║                                                                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 *
 * Inspired by:
 * - Beatsurfing iOS App (draw-able MIDI controllers, surfing triggers)
 * - Beatsurfing RANDOM (AI randomization wheel, DEVIANCE/INSTABILITY)
 * - Beatsurfing Beatfader (fader-based drum triggering)
 * - Output Portal (XY morphing controls)
 *
 * Bio-Reactive XY Control Surface where:
 * - Bio-data drives the XY position and modulation
 * - Objects placed on the surface trigger sounds on collision
 * - Path trails create evolving patterns
 * - DEVIANCE/INSTABILITY controlled by HRV/Stress
 *
 * ══════════════════════════════════════════════════════════════════════════════
 *                         SURFACE OBJECTS
 * ══════════════════════════════════════════════════════════════════════════════
 *
 *     ╭──────────╮        ╔═══════╗        ┌─────────┐        ●────●
 *     │  Circle  │        ║ Rect  ║        │Polygon  │        │Line│
 *     │ Trigger  │        ║Trigger║        │ Trigger │        ●────●
 *     ╰──────────╯        ╚═══════╝        └─────────┘
 *
 *     Objects trigger when the bio-cursor collides with them
 *     Each object can control: Note, CC, Parameter, Sample Slice
 *
 * ══════════════════════════════════════════════════════════════════════════════
 *                      BIO-REACTIVE MAPPING
 * ══════════════════════════════════════════════════════════════════════════════
 *
 *     HRV ──────────────────► DEVIANCE (randomization amount)
 *     Coherence ────────────► Path Smoothness
 *     Heart Rate ───────────► Cursor Speed
 *     Breathing Phase ──────► X Position Oscillation
 *     Stress ───────────────► INSTABILITY (note-to-note variation)
 *     Breathing Rate ───────► Y Position Oscillation
 *
 * Features:
 * - Drawable trigger objects (circles, rectangles, polygons, lines)
 * - Bio-driven cursor movement
 * - Collision-based triggering
 * - Path recording and playback
 * - RANDOM-style deviance/instability
 * - Multi-touch/MPE support
 * - Velocity from collision speed
 * - Aftertouch from pressure/proximity
 */

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <memory>
#include <random>
#include <cmath>

class XYBioSurface
{
public:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int kMaxObjects = 64;
    static constexpr int kMaxPathPoints = 1024;
    static constexpr int kMaxTouchPoints = 16;

    //==========================================================================
    // Object Types (Beatsurfing-inspired)
    //==========================================================================

    enum class ObjectType
    {
        Circle,         // Circular trigger zone
        Rectangle,      // Rectangular trigger zone
        Polygon,        // Custom polygon shape
        Line,           // Line trigger (cross to trigger)
        Fader,          // Vertical/horizontal fader zone
        XYPad,          // Sub-XY control zone
        RandomWheel     // RANDOM-style parameter wheel
    };

    //==========================================================================
    // Trigger Mode
    //==========================================================================

    enum class TriggerMode
    {
        OnEnter,        // Trigger when cursor enters
        OnExit,         // Trigger when cursor exits
        OnCross,        // Trigger when crossing (lines)
        Continuous,     // Continuous output while inside
        Toggle,         // Toggle on/off
        Velocity,       // Velocity from movement speed
        Pressure        // Pressure from proximity to center
    };

    //==========================================================================
    // Output Type
    //==========================================================================

    enum class OutputType
    {
        MIDINote,       // Trigger MIDI note
        MIDIControlChange, // Send CC value
        Parameter,      // Internal parameter modulation
        SampleSlice,    // Trigger sample slice
        RandomSeed      // Seed the random generator
    };

    //==========================================================================
    // Surface Object
    //==========================================================================

    struct SurfaceObject
    {
        // Identity
        int id = -1;
        juce::String name;
        ObjectType type = ObjectType::Circle;
        bool enabled = true;

        // Geometry
        float centerX = 0.5f;
        float centerY = 0.5f;
        float width = 0.1f;
        float height = 0.1f;
        float rotation = 0.0f;
        std::vector<juce::Point<float>> polygonPoints;

        // Appearance
        juce::Colour color = juce::Colours::cyan;
        float opacity = 0.8f;

        // Behavior
        TriggerMode triggerMode = TriggerMode::OnEnter;
        OutputType outputType = OutputType::MIDINote;

        // Output values
        int midiNote = 60;
        int midiChannel = 1;
        int ccNumber = 74;
        float parameterMin = 0.0f;
        float parameterMax = 1.0f;

        // State
        bool isTriggered = false;
        bool cursorInside = false;
        float currentValue = 0.0f;

        // RANDOM-style parameters
        float deviance = 0.0f;      // Randomization amount (0-1)
        float instability = 0.0f;   // Note-to-note variation (0-1)

        SurfaceObject() = default;
    };

    //==========================================================================
    // Bio Cursor State
    //==========================================================================

    struct BioCursor
    {
        float x = 0.5f;
        float y = 0.5f;
        float velocityX = 0.0f;
        float velocityY = 0.0f;
        float speed = 0.0f;
        float pressure = 0.0f;

        // Trail
        std::vector<juce::Point<float>> trail;
        int maxTrailLength = 100;

        BioCursor() = default;
    };

    //==========================================================================
    // Bio State Input
    //==========================================================================

    struct BioState
    {
        float heartRate = 70.0f;
        float hrv = 0.5f;
        float coherence = 0.5f;
        float breathingRate = 12.0f;
        float breathingPhase = 0.0f;
        float stress = 0.5f;
    };

    //==========================================================================
    // Trigger Event
    //==========================================================================

    struct TriggerEvent
    {
        int objectId = -1;
        OutputType type = OutputType::MIDINote;
        int midiNote = 60;
        int midiChannel = 1;
        float velocity = 0.8f;
        float value = 0.0f;
        bool isNoteOn = true;

        TriggerEvent() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    XYBioSurface()
    {
        initializeDefaultObjects();
    }

    ~XYBioSurface() = default;

    //==========================================================================
    // Object Management
    //==========================================================================

    /** Add object to surface */
    int addObject(const SurfaceObject& obj)
    {
        if (objects.size() >= kMaxObjects)
            return -1;

        SurfaceObject newObj = obj;
        newObj.id = nextObjectId++;
        objects.push_back(newObj);
        return newObj.id;
    }

    /** Add circle trigger */
    int addCircle(float x, float y, float radius, int midiNote = 60)
    {
        SurfaceObject obj;
        obj.type = ObjectType::Circle;
        obj.centerX = x;
        obj.centerY = y;
        obj.width = radius * 2;
        obj.height = radius * 2;
        obj.midiNote = midiNote;
        obj.outputType = OutputType::MIDINote;
        return addObject(obj);
    }

    /** Add rectangle trigger */
    int addRectangle(float x, float y, float w, float h, int midiNote = 60)
    {
        SurfaceObject obj;
        obj.type = ObjectType::Rectangle;
        obj.centerX = x;
        obj.centerY = y;
        obj.width = w;
        obj.height = h;
        obj.midiNote = midiNote;
        obj.outputType = OutputType::MIDINote;
        return addObject(obj);
    }

    /** Add line trigger */
    int addLine(float x1, float y1, float x2, float y2, int midiNote = 60)
    {
        SurfaceObject obj;
        obj.type = ObjectType::Line;
        obj.centerX = (x1 + x2) / 2;
        obj.centerY = (y1 + y2) / 2;
        obj.polygonPoints.push_back({ x1, y1 });
        obj.polygonPoints.push_back({ x2, y2 });
        obj.triggerMode = TriggerMode::OnCross;
        obj.midiNote = midiNote;
        return addObject(obj);
    }

    /** Add RANDOM wheel (Beatsurfing-style) */
    int addRandomWheel(float x, float y, float radius)
    {
        SurfaceObject obj;
        obj.type = ObjectType::RandomWheel;
        obj.centerX = x;
        obj.centerY = y;
        obj.width = radius * 2;
        obj.height = radius * 2;
        obj.triggerMode = TriggerMode::Continuous;
        obj.outputType = OutputType::RandomSeed;
        obj.deviance = 0.5f;
        obj.instability = 0.3f;
        return addObject(obj);
    }

    /** Remove object */
    void removeObject(int id)
    {
        objects.erase(
            std::remove_if(objects.begin(), objects.end(),
                [id](const SurfaceObject& obj) { return obj.id == id; }),
            objects.end());
    }

    /** Clear all objects */
    void clearObjects()
    {
        objects.clear();
    }

    /** Get object reference */
    SurfaceObject* getObject(int id)
    {
        for (auto& obj : objects)
            if (obj.id == id) return &obj;
        return nullptr;
    }

    /** Get all objects */
    const std::vector<SurfaceObject>& getObjects() const
    {
        return objects;
    }

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    /** Update bio-data */
    void setBioState(const BioState& state)
    {
        bioState = state;

        // Update DEVIANCE/INSTABILITY from bio-data
        globalDeviance = bioState.hrv;          // HRV → randomization amount
        globalInstability = bioState.stress;    // Stress → note variation

        // Update cursor speed from heart rate
        float normalizedHR = (bioState.heartRate - 60.0f) / 60.0f;
        cursorSpeed = 0.5f + normalizedHR * 0.5f;

        // Update path smoothness from coherence
        pathSmoothness = bioState.coherence;
    }

    /** Enable/disable bio cursor control */
    void setBioCursorEnabled(bool enabled)
    {
        bioCursorEnabled = enabled;
    }

    //==========================================================================
    // Cursor Control
    //==========================================================================

    /** Set cursor position directly */
    void setCursorPosition(float x, float y)
    {
        cursor.velocityX = x - cursor.x;
        cursor.velocityY = y - cursor.y;
        cursor.speed = std::sqrt(cursor.velocityX * cursor.velocityX +
                                  cursor.velocityY * cursor.velocityY);

        cursor.x = std::clamp(x, 0.0f, 1.0f);
        cursor.y = std::clamp(y, 0.0f, 1.0f);

        // Add to trail
        cursor.trail.push_back({ cursor.x, cursor.y });
        if (cursor.trail.size() > cursor.maxTrailLength)
            cursor.trail.erase(cursor.trail.begin());
    }

    /** Get cursor position */
    std::pair<float, float> getCursorPosition() const
    {
        return { cursor.x, cursor.y };
    }

    /** Get cursor trail */
    const std::vector<juce::Point<float>>& getCursorTrail() const
    {
        return cursor.trail;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Process and get trigger events */
    std::vector<TriggerEvent> process()
    {
        std::vector<TriggerEvent> events;

        // Update bio cursor if enabled
        if (bioCursorEnabled)
        {
            updateBioCursor();
        }

        // Check collisions with all objects
        for (auto& obj : objects)
        {
            if (!obj.enabled) continue;

            bool wasInside = obj.cursorInside;
            obj.cursorInside = checkCollision(obj, cursor.x, cursor.y);

            // Generate events based on trigger mode
            TriggerEvent event;
            event.objectId = obj.id;
            event.type = obj.outputType;
            event.midiNote = obj.midiNote;
            event.midiChannel = obj.midiChannel;

            switch (obj.triggerMode)
            {
                case TriggerMode::OnEnter:
                    if (obj.cursorInside && !wasInside)
                    {
                        event.isNoteOn = true;
                        event.velocity = calculateVelocity(obj);
                        applyRandomization(event, obj);
                        events.push_back(event);
                        obj.isTriggered = true;
                    }
                    else if (!obj.cursorInside && wasInside && obj.isTriggered)
                    {
                        event.isNoteOn = false;
                        event.velocity = cursor.speed;
                        events.push_back(event);
                        obj.isTriggered = false;
                    }
                    break;

                case TriggerMode::OnExit:
                    if (!obj.cursorInside && wasInside)
                    {
                        event.isNoteOn = true;
                        event.velocity = calculateVelocity(obj);
                        applyRandomization(event, obj);
                        events.push_back(event);
                    }
                    break;

                case TriggerMode::Continuous:
                    if (obj.cursorInside)
                    {
                        float value = calculateContinuousValue(obj);
                        obj.currentValue = value;
                        event.value = value;
                        event.isNoteOn = true;
                        events.push_back(event);
                    }
                    break;

                case TriggerMode::Velocity:
                    if (obj.cursorInside)
                    {
                        event.velocity = std::clamp(cursor.speed * 5.0f, 0.0f, 1.0f);
                        event.isNoteOn = true;
                        applyRandomization(event, obj);
                        events.push_back(event);
                    }
                    break;

                case TriggerMode::Pressure:
                    if (obj.cursorInside)
                    {
                        float dist = calculateDistanceToCenter(obj);
                        event.velocity = 1.0f - std::clamp(dist * 2.0f, 0.0f, 1.0f);
                        event.isNoteOn = true;
                        applyRandomization(event, obj);
                        events.push_back(event);
                    }
                    break;

                default:
                    break;
            }
        }

        return events;
    }

    //==========================================================================
    // Path Recording & Playback
    //==========================================================================

    /** Start recording cursor path */
    void startRecordingPath()
    {
        recordedPath.clear();
        isRecordingPath = true;
    }

    /** Stop recording */
    void stopRecordingPath()
    {
        isRecordingPath = false;
    }

    /** Play back recorded path */
    void playPath(float speed = 1.0f)
    {
        isPlayingPath = true;
        pathPlaybackPosition = 0;
        pathPlaybackSpeed = speed;
    }

    /** Stop playback */
    void stopPath()
    {
        isPlayingPath = false;
    }

    //==========================================================================
    // Presets
    //==========================================================================

    enum class SurfacePreset
    {
        DrumGrid,       // 4x4 drum pad grid
        MelodicCircles, // Pentatonic circle arrangement
        XYMorph,        // Central XY pad with corner triggers
        BioReactiveKit, // Objects sized by bio-data
        RandomSurfing,  // RANDOM wheels with triggers
        HealingMandala  // Circular healing frequency layout
    };

    void loadPreset(SurfacePreset preset)
    {
        clearObjects();

        switch (preset)
        {
            case SurfacePreset::DrumGrid:
                createDrumGrid();
                break;

            case SurfacePreset::MelodicCircles:
                createMelodicCircles();
                break;

            case SurfacePreset::XYMorph:
                createXYMorphLayout();
                break;

            case SurfacePreset::BioReactiveKit:
                createBioReactiveKit();
                break;

            case SurfacePreset::RandomSurfing:
                createRandomSurfing();
                break;

            case SurfacePreset::HealingMandala:
                createHealingMandala();
                break;
        }
    }

    //==========================================================================
    // RANDOM Parameters (Beatsurfing-style)
    //==========================================================================

    /** Set global deviance (randomization amount) */
    void setGlobalDeviance(float deviance)
    {
        globalDeviance = std::clamp(deviance, 0.0f, 1.0f);
    }

    /** Set global instability (note-to-note variation) */
    void setGlobalInstability(float instability)
    {
        globalInstability = std::clamp(instability, 0.0f, 1.0f);
    }

    /** Get random value based on deviance */
    float getRandomValue()
    {
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        return dist(rng);
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    std::vector<SurfaceObject> objects;
    BioCursor cursor;
    BioState bioState;

    int nextObjectId = 0;
    bool bioCursorEnabled = true;

    // Bio-driven parameters
    float globalDeviance = 0.0f;
    float globalInstability = 0.0f;
    float cursorSpeed = 1.0f;
    float pathSmoothness = 0.5f;

    // Path recording
    std::vector<juce::Point<float>> recordedPath;
    bool isRecordingPath = false;
    bool isPlayingPath = false;
    int pathPlaybackPosition = 0;
    float pathPlaybackSpeed = 1.0f;

    // Random generator
    std::mt19937 rng{ std::random_device{}() };

    // Bio cursor state
    float bioCursorPhase = 0.0f;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeDefaultObjects()
    {
        // Start with a simple central circle
        addCircle(0.5f, 0.5f, 0.1f, 60);
    }

    void updateBioCursor()
    {
        // Bio-driven cursor movement
        bioCursorPhase += 0.01f * cursorSpeed;
        if (bioCursorPhase > 1.0f) bioCursorPhase -= 1.0f;

        // Breathing-based X oscillation
        float breathX = std::sin(bioState.breathingPhase * 2.0f * M_PI) * 0.3f;

        // Heart rate-based Y oscillation (more subtle)
        float heartY = std::sin(bioCursorPhase * bioState.heartRate / 10.0f) * 0.2f;

        // Coherence-based smoothing
        float smoothing = 0.9f + bioState.coherence * 0.09f;

        float targetX = 0.5f + breathX * (1.0f - bioState.coherence);
        float targetY = 0.5f + heartY * (1.0f - bioState.coherence);

        // Smooth movement
        float newX = cursor.x * smoothing + targetX * (1.0f - smoothing);
        float newY = cursor.y * smoothing + targetY * (1.0f - smoothing);

        // Add HRV-based randomness
        if (bioState.hrv > 0.3f)
        {
            std::uniform_real_distribution<float> dist(-0.02f, 0.02f);
            newX += dist(rng) * bioState.hrv;
            newY += dist(rng) * bioState.hrv;
        }

        setCursorPosition(newX, newY);

        // Record if enabled
        if (isRecordingPath)
        {
            recordedPath.push_back({ newX, newY });
        }

        // Playback if enabled
        if (isPlayingPath && !recordedPath.empty())
        {
            pathPlaybackPosition = static_cast<int>(pathPlaybackPosition + pathPlaybackSpeed) %
                                   recordedPath.size();
            auto point = recordedPath[pathPlaybackPosition];
            setCursorPosition(point.x, point.y);
        }
    }

    bool checkCollision(const SurfaceObject& obj, float x, float y)
    {
        switch (obj.type)
        {
            case ObjectType::Circle:
            case ObjectType::RandomWheel:
            {
                float dx = x - obj.centerX;
                float dy = y - obj.centerY;
                float radius = obj.width / 2;
                return (dx * dx + dy * dy) <= (radius * radius);
            }

            case ObjectType::Rectangle:
            case ObjectType::Fader:
            case ObjectType::XYPad:
            {
                float halfW = obj.width / 2;
                float halfH = obj.height / 2;
                return x >= obj.centerX - halfW && x <= obj.centerX + halfW &&
                       y >= obj.centerY - halfH && y <= obj.centerY + halfH;
            }

            case ObjectType::Line:
            {
                if (obj.polygonPoints.size() < 2) return false;

                // Check if cursor crossed the line
                auto& p1 = obj.polygonPoints[0];
                auto& p2 = obj.polygonPoints[1];

                // Simple line proximity check
                float lineLen = std::sqrt((p2.x - p1.x) * (p2.x - p1.x) +
                                          (p2.y - p1.y) * (p2.y - p1.y));
                if (lineLen < 0.001f) return false;

                float t = std::clamp(((x - p1.x) * (p2.x - p1.x) + (y - p1.y) * (p2.y - p1.y)) /
                                     (lineLen * lineLen), 0.0f, 1.0f);

                float closestX = p1.x + t * (p2.x - p1.x);
                float closestY = p1.y + t * (p2.y - p1.y);

                float dist = std::sqrt((x - closestX) * (x - closestX) +
                                       (y - closestY) * (y - closestY));

                return dist < 0.02f;  // 2% threshold
            }

            case ObjectType::Polygon:
            {
                // Point in polygon test
                return pointInPolygon(obj.polygonPoints, x, y);
            }

            default:
                return false;
        }
    }

    bool pointInPolygon(const std::vector<juce::Point<float>>& poly, float x, float y)
    {
        if (poly.size() < 3) return false;

        bool inside = false;
        int n = static_cast<int>(poly.size());

        for (int i = 0, j = n - 1; i < n; j = i++)
        {
            if (((poly[i].y > y) != (poly[j].y > y)) &&
                (x < (poly[j].x - poly[i].x) * (y - poly[i].y) / (poly[j].y - poly[i].y) + poly[i].x))
            {
                inside = !inside;
            }
        }

        return inside;
    }

    float calculateVelocity(const SurfaceObject& obj)
    {
        // Base velocity from cursor speed
        float velocity = std::clamp(0.5f + cursor.speed * 2.0f, 0.0f, 1.0f);

        // Modulate by bio-data
        velocity *= (0.5f + bioState.coherence * 0.5f);

        return velocity;
    }

    float calculateDistanceToCenter(const SurfaceObject& obj)
    {
        float dx = cursor.x - obj.centerX;
        float dy = cursor.y - obj.centerY;
        return std::sqrt(dx * dx + dy * dy);
    }

    float calculateContinuousValue(const SurfaceObject& obj)
    {
        // For XY pads and faders
        float relativeX = (cursor.x - (obj.centerX - obj.width / 2)) / obj.width;
        float relativeY = (cursor.y - (obj.centerY - obj.height / 2)) / obj.height;

        relativeX = std::clamp(relativeX, 0.0f, 1.0f);
        relativeY = std::clamp(relativeY, 0.0f, 1.0f);

        // For faders, use X or Y based on aspect ratio
        if (obj.type == ObjectType::Fader)
        {
            return obj.width > obj.height ? relativeX : relativeY;
        }

        // For XY pads, combine both
        return (relativeX + relativeY) / 2.0f;
    }

    void applyRandomization(TriggerEvent& event, const SurfaceObject& obj)
    {
        float totalDeviance = std::clamp(globalDeviance + obj.deviance, 0.0f, 1.0f);
        float totalInstability = std::clamp(globalInstability + obj.instability, 0.0f, 1.0f);

        // Apply DEVIANCE to note
        if (totalDeviance > 0.01f)
        {
            std::uniform_int_distribution<int> noteDist(-12, 12);
            int deviation = static_cast<int>(noteDist(rng) * totalDeviance);
            event.midiNote = std::clamp(event.midiNote + deviation, 0, 127);
        }

        // Apply INSTABILITY to velocity
        if (totalInstability > 0.01f)
        {
            std::uniform_real_distribution<float> velDist(-0.3f, 0.3f);
            event.velocity = std::clamp(event.velocity + velDist(rng) * totalInstability, 0.0f, 1.0f);
        }
    }

    //==========================================================================
    // Preset Generators
    //==========================================================================

    void createDrumGrid()
    {
        // 4x4 grid of drum pads
        int notes[] = { 36, 38, 42, 46, 37, 40, 43, 47, 39, 41, 44, 48, 35, 45, 49, 51 };
        int noteIdx = 0;

        for (int row = 0; row < 4; ++row)
        {
            for (int col = 0; col < 4; ++col)
            {
                float x = 0.15f + col * 0.23f;
                float y = 0.15f + row * 0.23f;
                addRectangle(x, y, 0.18f, 0.18f, notes[noteIdx++]);
            }
        }
    }

    void createMelodicCircles()
    {
        // Pentatonic scale in circular arrangement
        int pentatonic[] = { 60, 62, 64, 67, 69, 72, 74, 76 };

        for (int i = 0; i < 8; ++i)
        {
            float angle = i * 2.0f * M_PI / 8.0f;
            float radius = 0.35f;
            float x = 0.5f + std::cos(angle) * radius;
            float y = 0.5f + std::sin(angle) * radius;

            addCircle(x, y, 0.08f, pentatonic[i]);
        }

        // Center circle
        addCircle(0.5f, 0.5f, 0.1f, 48);
    }

    void createXYMorphLayout()
    {
        // Central XY pad
        SurfaceObject xyPad;
        xyPad.type = ObjectType::XYPad;
        xyPad.centerX = 0.5f;
        xyPad.centerY = 0.5f;
        xyPad.width = 0.5f;
        xyPad.height = 0.5f;
        xyPad.triggerMode = TriggerMode::Continuous;
        xyPad.outputType = OutputType::Parameter;
        addObject(xyPad);

        // Corner triggers
        addCircle(0.1f, 0.1f, 0.08f, 60);
        addCircle(0.9f, 0.1f, 0.08f, 64);
        addCircle(0.1f, 0.9f, 0.08f, 67);
        addCircle(0.9f, 0.9f, 0.08f, 72);
    }

    void createBioReactiveKit()
    {
        // Objects that grow/shrink based on bio-data
        for (int i = 0; i < 8; ++i)
        {
            float angle = i * 2.0f * M_PI / 8.0f;
            float radius = 0.3f;
            float x = 0.5f + std::cos(angle) * radius;
            float y = 0.5f + std::sin(angle) * radius;

            SurfaceObject obj;
            obj.type = ObjectType::Circle;
            obj.centerX = x;
            obj.centerY = y;
            obj.width = 0.05f + bioState.hrv * 0.1f;
            obj.height = obj.width;
            obj.midiNote = 48 + i * 2;
            obj.deviance = bioState.hrv;
            obj.instability = bioState.stress;
            addObject(obj);
        }
    }

    void createRandomSurfing()
    {
        // RANDOM wheels with triggers
        addRandomWheel(0.5f, 0.5f, 0.15f);

        // Surrounding triggers
        for (int i = 0; i < 12; ++i)
        {
            float angle = i * 2.0f * M_PI / 12.0f;
            float x = 0.5f + std::cos(angle) * 0.35f;
            float y = 0.5f + std::sin(angle) * 0.35f;

            SurfaceObject obj;
            obj.type = ObjectType::Circle;
            obj.centerX = x;
            obj.centerY = y;
            obj.width = 0.06f;
            obj.height = 0.06f;
            obj.midiNote = 48 + i;
            obj.deviance = 0.3f;
            obj.instability = 0.2f;
            addObject(obj);
        }
    }

    void createHealingMandala()
    {
        // Healing frequency-based circular layout
        // Based on Solfeggio frequencies mapped to notes
        int healingNotes[] = { 60, 62, 64, 65, 67, 69, 71, 72 };  // C major representing healing

        // Outer ring
        for (int i = 0; i < 8; ++i)
        {
            float angle = i * 2.0f * M_PI / 8.0f - M_PI / 2.0f;
            float x = 0.5f + std::cos(angle) * 0.4f;
            float y = 0.5f + std::sin(angle) * 0.4f;

            SurfaceObject obj;
            obj.type = ObjectType::Circle;
            obj.centerX = x;
            obj.centerY = y;
            obj.width = 0.1f;
            obj.height = 0.1f;
            obj.midiNote = healingNotes[i];
            obj.deviance = 0.0f;  // No randomization for healing tones
            obj.instability = 0.0f;
            obj.color = juce::Colour::fromHSV(i / 8.0f, 0.7f, 0.9f, 1.0f);
            addObject(obj);
        }

        // Inner ring
        for (int i = 0; i < 4; ++i)
        {
            float angle = i * 2.0f * M_PI / 4.0f;
            float x = 0.5f + std::cos(angle) * 0.2f;
            float y = 0.5f + std::sin(angle) * 0.2f;

            addCircle(x, y, 0.06f, healingNotes[i * 2] - 12);
        }

        // Center
        addCircle(0.5f, 0.5f, 0.08f, 36);  // Deep root note
    }

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(XYBioSurface)
};

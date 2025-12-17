#pragma once

#include <JuceHeader.h>
#include "EchoelQuantumCore.h"

/**
 * EchoelGameEngine - Game Engine Integration & Production Gamification
 *
 * Integrates with major game engines and gamifies the production workflow.
 *
 * SUPPORTED ENGINES:
 * - Unity (via OSC/WebSocket/Unity Plugin)
 * - Unreal Engine (via OSC/Blueprint Plugin)
 * - Godot (via GDNative/OSC)
 * - GameMaker Studio (via DLL/Extension)
 * - Custom engines (via API)
 *
 * USE CASES:
 * 1. Music Production as Game
 * 2. Interactive Music Games
 * 3. VR Music Creation
 * 4. Bio-reactive Game Audio
 * 5. Educational Music Games
 * 6. Therapeutic Audio Games
 * 7. Multiplayer Music Collaboration
 * 8. Live Performance Games
 */
class EchoelGameEngine
{
public:
    //==========================================================================
    // 1. GAME ENGINE INTEGRATION
    //==========================================================================

    /**
     * Supported game engines
     */
    enum class GameEngine
    {
        Unity,
        UnrealEngine,
        Godot,
        GameMaker,
        Custom
    };

    /**
     * Integration protocol
     */
    enum class IntegrationProtocol
    {
        OSC,             // Open Sound Control (recommended)
        WebSocket,       // Bi-directional web socket
        UDP,             // Fast, unreliable
        TCP,             // Reliable, slower
        Plugin,          // Native plugin (Unity/Unreal)
        SharedMemory,    // Ultra-low latency (same machine)
        MIDI             // MIDI protocol
    };

    /**
     * Initialize game engine connection
     */
    bool connectToGameEngine(GameEngine engine, IntegrationProtocol protocol, const juce::String& config);

    /**
     * Send audio to game engine
     */
    void sendAudioStream(const juce::AudioBuffer<float>& buffer);
    void sendAudioEvent(const juce::String& eventName, float value);

    /**
     * Receive game state from engine
     */
    struct GameState
    {
        // Player state
        juce::Point3D<float> playerPosition;
        juce::Point3D<float> playerRotation;
        float playerHealth = 100.0f;
        float playerEnergy = 100.0f;

        // Game state
        enum class GameMode { Menu, Playing, Paused, GameOver } gameMode = GameMode::Menu;
        int currentLevel = 1;
        float gameTime = 0.0f;

        // Environmental
        float ambientLight = 1.0f;
        juce::String currentScene;
        std::vector<juce::String> activeObjects;

        // Events
        std::vector<juce::String> triggeredEvents;
    };

    GameState getGameState() const { return currentGameState; }

    /**
     * Bidirectional parameter mapping
     */
    void mapGameParameterToAudio(const juce::String& gameParam, const juce::String& audioParam);
    void mapAudioParameterToGame(const juce::String& audioParam, const juce::String& gameParam);

    //==========================================================================
    // 2. PRODUCTION GAMIFICATION
    //==========================================================================

    /**
     * XP & Leveling System
     */
    struct PlayerStats
    {
        juce::String playerID;
        juce::String username;

        // Core stats
        int level = 1;
        int xp = 0;
        int xpToNextLevel = 100;

        // Skill trees
        struct SkillTree
        {
            int mixing = 0;          // 0-100
            int composition = 0;
            int soundDesign = 0;
            int mastering = 0;
            int performance = 0;
            int collaboration = 0;
        } skills;

        // Achievements
        std::vector<juce::String> unlockedAchievements;
        std::vector<juce::String> currentChallenges;

        // Bio-performance metrics
        float averageFlowState = 0.0f;
        float peakCoherence = 0.0f;
        float totalFlowHours = 0.0f;

        // Social
        int collaborations = 0;
        int projectsCompleted = 0;
        float communityRating = 0.0f;  // 0.0-5.0
    };

    void createPlayer(const juce::String& username);
    void addXP(int amount, const juce::String& category);
    void levelUp();

    /**
     * Achievement system
     */
    struct Achievement
    {
        juce::String achievementID;
        juce::String name;
        juce::String description;
        juce::String iconFile;

        enum class Category
        {
            Production,    // Production milestones
            Technical,     // Technical mastery
            Creative,      // Creative excellence
            Social,        // Collaboration
            BioPeak,       // Bio-reactive achievements
            Speed,         // Time-based
            Quality,       // Quality standards
            Special        // Rare/secret
        } category;

        // Requirements
        std::map<juce::String, float> requirements;

        // Rewards
        int xpReward = 100;
        std::vector<juce::String> unlockedFeatures;

        // Rarity
        enum class Rarity { Common, Uncommon, Rare, Epic, Legendary } rarity = Rarity::Common;

        // Progress
        float progress = 0.0f;  // 0.0-1.0
        bool unlocked = false;
        double unlockTimestamp = 0.0;
    };

    std::vector<Achievement> getAvailableAchievements() const;
    std::vector<Achievement> getUnlockedAchievements() const;
    void checkAchievements();  // Called periodically

    /**
     * Challenge system
     */
    struct Challenge
    {
        juce::String challengeID;
        juce::String name;
        juce::String description;

        enum class Type
        {
            TimeLimit,        // Complete track in 30min
            ToolLimit,        // Use only 3 effects
            GenreChallenge,   // Create in specific genre
            BioTarget,        // Achieve flow state for 20min
            Collaboration,    // Work with 3+ people
            Quality,          // Achieve specific LUFS
            Creativity,       // Use unusual techniques
            Remix,            // Remix provided stems
            Daily,            // Daily challenge
            Weekly,           // Weekly competition
            Community         // Community-voted challenges
        } type;

        // Parameters
        float timeLimit = 0.0f;          // Seconds (0 = no limit)
        std::vector<juce::String> allowedTools;
        std::vector<juce::String> requiredElements;
        float targetQuality = 0.0f;      // e.g., -14 LUFS

        // Rewards
        int xpReward = 200;
        std::vector<juce::String> badges;
        juce::String unlockedContent;    // Preset, sample pack, etc.

        // Progress
        float progress = 0.0f;
        bool completed = false;
        double expiryTime = 0.0;         // Unix timestamp
    };

    std::vector<Challenge> getActiveChallenges() const;
    void startChallenge(const juce::String& challengeID);
    void completeChallenge(const juce::String& challengeID);

    /**
     * Leaderboard system
     */
    struct LeaderboardEntry
    {
        juce::String playerID;
        juce::String username;
        int rank = 0;
        float score = 0.0f;

        // Context
        juce::String category;  // "Mixing", "Flow State", "Speed", etc.
        juce::String timeframe; // "Daily", "Weekly", "All Time"
    };

    std::vector<LeaderboardEntry> getLeaderboard(const juce::String& category, const juce::String& timeframe);

    //==========================================================================
    // 3. INTERACTIVE MUSIC GAMES
    //==========================================================================

    /**
     * Built-in music games
     */
    enum class MusicGame
    {
        RhythmMatch,      // Match rhythm patterns (Guitar Hero style)
        FrequencyHunter,  // Find frequencies by ear
        MixingChallenge,  // Balance a mix
        CompositionRace,  // Compose melody against time
        SoundMemory,      // Memory game with sounds
        EarTraining,      // Interval/chord recognition
        BeatMaker,        // Create beats (rhythm game)
        SampleFlip,       // Flip samples creatively
        FlowState,        // Maintain flow state longest
        BioBalance        // Balance bio-metrics
    };

    void startMusicGame(MusicGame game);
    float getGameScore() const;

    /**
     * Custom game creation
     */
    struct GameRule
    {
        juce::String ruleID;

        enum class RuleType
        {
            ScoreOnBeat,       // Score when hitting beat
            ScoreOnPitch,      // Score when matching pitch
            ScoreOnQuality,    // Score on mix quality
            ScoreOnCreativity, // AI judges creativity
            ScoreOnBioState,   // Score on bio-metrics
            LoseOnError,       // Lose points on mistakes
            TimeBonus,         // Bonus for speed
            ComboMultiplier    // Combo system
        } type;

        float pointValue = 10.0f;
        float multiplier = 1.0f;
    };

    void createCustomGame(const juce::String& gameName, const std::vector<GameRule>& rules);

    //==========================================================================
    // 4. VR/AR MUSIC CREATION
    //==========================================================================

    /**
     * VR/AR interface for music production
     */
    struct VRInterface
    {
        enum class Platform
        {
            MetaQuest,
            VisionPro,
            PSVR2,
            SteamVR,
            WebXR
        } platform = Platform::MetaQuest;

        // Hand tracking
        juce::Point3D<float> leftHandPosition;
        juce::Point3D<float> rightHandPosition;
        juce::Point3D<float> leftHandRotation;
        juce::Point3D<float> rightHandRotation;

        bool leftGrabbing = false;
        bool rightGrabbing = false;

        // Head tracking
        juce::Point3D<float> headPosition;
        juce::Point3D<float> headRotation;

        // Gestures
        enum class Gesture
        {
            None,
            Pinch,
            Grab,
            Point,
            Swipe,
            Twist,
            Push,
            Pull
        };

        Gesture leftGesture = Gesture::None;
        Gesture rightGesture = Gesture::None;
    };

    void enableVRMode(VRInterface::Platform platform);
    VRInterface getVRState() const;

    /**
     * Spatial UI in VR
     */
    struct VRUIElement
    {
        juce::String elementID;
        enum class Type
        {
            Knob3D,        // 3D knob you grab and twist
            Slider3D,      // 3D slider
            Button3D,      // 3D button
            Waveform3D,    // 3D waveform visualization
            Mixer3D,       // 3D mixing console
            Keyboard3D,    // 3D MIDI keyboard
            Pad3D          // 3D drum pads
        } type;

        juce::Point3D<float> position;
        juce::Point3D<float> scale;
        juce::Colour color;

        bool interactable = true;
        float value = 0.0f;
    };

    juce::String createVRUIElement(VRUIElement::Type type, const juce::Point3D<float>& position);
    void updateVRUIElement(const juce::String& elementID, float value);

    //==========================================================================
    // 5. MULTIPLAYER COLLABORATION GAMES
    //==========================================================================

    /**
     * Multiplayer game modes
     */
    enum class MultiplayerMode
    {
        CoopProduction,     // Collaborative track creation
        CompetitiveRemix,   // Compete to best remix
        BeatBattle,         // Beat-making battle
        MixChallenge,       // Mixing competition
        LiveJam,            // Live jamming session
        BioBattle,          // Compete on bio-metrics
        TeachingMode        // One teaches, one learns
    };

    void startMultiplayerSession(MultiplayerMode mode, int maxPlayers);
    void invitePlayer(const juce::String& playerID);

    /**
     * Multiplayer synchronization
     */
    void syncGameState();
    void sendPlayerAction(const juce::String& actionID, float value);

    //==========================================================================
    // 6. EDUCATIONAL GAMES
    //==========================================================================

    /**
     * Tutorial missions
     */
    struct Tutorial
    {
        juce::String tutorialID;
        juce::String name;
        juce::String description;

        enum class Difficulty { Beginner, Intermediate, Advanced, Expert } difficulty;

        // Steps
        struct Step
        {
            juce::String instruction;
            juce::String videoURL;     // Tutorial video
            juce::String audioExample; // Audio example

            // Validation
            std::function<bool()> validationFunction;
            juce::String successMessage;
            juce::String hint;
        };

        std::vector<Step> steps;

        // Progress
        int currentStep = 0;
        bool completed = false;
    };

    std::vector<Tutorial> getAvailableTutorials() const;
    void startTutorial(const juce::String& tutorialID);

    /**
     * Adaptive learning system
     */
    struct LearningProfile
    {
        juce::String playerID;

        // Skill assessments (0.0-1.0)
        float mixingSkill = 0.0f;
        float compositionSkill = 0.0f;
        float soundDesignSkill = 0.0f;
        float masteringSkill = 0.0f;

        // Learning preferences
        enum class LearningStyle { Visual, Auditory, Kinesthetic, Reading } preferredStyle;

        // Strengths & weaknesses
        std::vector<juce::String> strengths;
        std::vector<juce::String> weaknesses;

        // Recommended tutorials
        std::vector<juce::String> recommendedTutorials;
    };

    LearningProfile assessSkills();
    std::vector<juce::String> getRecommendedLearningPath();

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    EchoelGameEngine();
    ~EchoelGameEngine();

private:
    GameEngine currentEngine = GameEngine::Unity;
    IntegrationProtocol currentProtocol = IntegrationProtocol::OSC;
    GameState currentGameState;

    PlayerStats playerStats;
    std::vector<Achievement> achievements;
    std::vector<Challenge> challenges;
    std::vector<Tutorial> tutorials;

    VRInterface vrInterface;

    // Network
    std::unique_ptr<juce::OSCSender> oscSender;
    std::unique_ptr<juce::OSCReceiver> oscReceiver;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelGameEngine)
};

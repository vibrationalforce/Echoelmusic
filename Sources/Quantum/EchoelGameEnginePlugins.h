#pragma once

#include <JuceHeader.h>
#include "EchoelGameEngine.h"

/**
 * EchoelGameEnginePlugins - OSC/WebSocket Bridges for Unity/Unreal/Godot
 *
 * Provides integration plugins for major game engines:
 * - Unity (C# OSC client + native plugin)
 * - Unreal Engine (Blueprint nodes + C++ plugin)
 * - Godot (GDScript OSC client + GDNative module)
 * - GameMaker (GML extension)
 *
 * COMMUNICATION PROTOCOL:
 * - OSC (Open Sound Control) - Primary protocol
 * - WebSocket - Alternative for web games
 * - UDP - Low-latency events
 * - Shared Memory - Ultra-low latency (same machine)
 *
 * FEATURES:
 * - Bidirectional audio streaming
 * - Parameter synchronization
 * - Bio-data integration in games
 * - Spatial audio positioning
 * - Game event triggers
 */

//==============================================================================
// OSC MESSAGE PROTOCOL
//==============================================================================

/**
 * OSC Address Space:
 *
 * ECHOELMUSIC → GAME ENGINE:
 * /audio/stream <blob>         - Audio chunk (compressed)
 * /audio/event <string> <float> - Audio event (name, value)
 * /bio/hrv <float>             - Heart rate variability
 * /bio/coherence <float>       - Coherence score
 * /bio/stress <float>          - Stress level
 * /bio/alpha <float>           - Alpha brain waves
 * /bio/beta <float>            - Beta brain waves
 * /music/tempo <float>         - Current tempo (BPM)
 * /music/key <int>             - Current key (MIDI)
 * /music/beat <int>            - Beat number
 * /music/bar <int>             - Bar number
 *
 * GAME ENGINE → ECHOELMUSIC:
 * /game/player/position <float> <float> <float> - Player XYZ position
 * /game/player/rotation <float> <float> <float> - Player rotation
 * /game/player/health <float>   - Player health (0-1)
 * /game/player/energy <float>   - Player energy (0-1)
 * /game/event <string> <float>  - Game event trigger
 * /game/music/volume <float>    - Request volume change
 * /game/music/play <string>     - Play music track
 * /game/music/stop              - Stop music
 */

//==============================================================================
// UNITY PLUGIN
//==============================================================================

/**
 * Unity C# Integration
 *
 * USAGE IN UNITY:
 * ```csharp
 * using Echoelmusic;
 *
 * public class MusicController : MonoBehaviour
 * {
 *     private EchoelmusicClient client;
 *
 *     void Start()
 *     {
 *         client = new EchoelmusicClient("127.0.0.1", 8000);
 *         client.Connect();
 *
 *         // Subscribe to bio-data
 *         client.OnBioData += (hrv, coherence, stress) =>
 *         {
 *             Debug.Log($"HRV: {hrv}, Stress: {stress}");
 *             // Adjust game difficulty based on stress
 *             if (stress > 0.7f)
 *                 DifficultyManager.ReduceDifficulty();
 *         };
 *
 *         // Subscribe to music events
 *         client.OnBeat += (beatNumber) =>
 *         {
 *             // Trigger visual effect on beat
 *             VisualEffects.Flash();
 *         };
 *     }
 *
 *     void Update()
 *     {
 *         // Send player position to Echoelmusic for spatial audio
 *         client.SendPlayerPosition(transform.position);
 *
 *         // Send game event
 *         if (Input.GetKeyDown(KeyCode.Space))
 *         {
 *             client.SendGameEvent("jump", 1.0f);
 *         }
 *     }
 * }
 * ```
 */
class EchoelmusicUnityPlugin
{
public:
    /**
     * C# OSC Client (to be compiled to Unity .dll)
     */
    struct UnityBridge
    {
        // Connection
        bool connect(const juce::String& host, int port);
        void disconnect();
        bool isConnected() const;

        // Send to Echoelmusic
        void sendPlayerPosition(float x, float y, float z);
        void sendPlayerRotation(float x, float y, float z);
        void sendGameEvent(const juce::String& eventName, float value);
        void requestMusicPlay(const juce::String& trackName);
        void requestMusicStop();

        // Receive from Echoelmusic (callbacks)
        std::function<void(float hrv, float coherence, float stress)> onBioData;
        std::function<void(int beatNumber)> onBeat;
        std::function<void(int barNumber)> onBar;
        std::function<void(juce::String eventName, float value)> onAudioEvent;
        std::function<void(const juce::AudioBuffer<float>&)> onAudioStream;
    };

    /**
     * Generate Unity C# source code
     */
    static juce::String generateUnitySource();

    /**
     * Generate Unity .unitypackage
     */
    static bool createUnityPackage(const juce::File& outputFile);
};

//==============================================================================
// UNREAL ENGINE PLUGIN
//==============================================================================

/**
 * Unreal Engine Blueprint Integration
 *
 * USAGE IN UNREAL (Blueprint):
 * 1. Add "EchoelmusicClient" component to Actor
 * 2. Connect to Echoelmusic in BeginPlay
 * 3. Bind events to Blueprint nodes
 *
 * BLUEPRINT NODES:
 * - Connect to Echoelmusic (host, port)
 * - Send Player Position
 * - Send Game Event
 * - Get Bio Data (HRV, Coherence, Stress)
 * - On Beat Event
 * - On Bar Event
 *
 * USAGE IN UNREAL (C++):
 * ```cpp
 * #include "EchoelmusicClient.h"
 *
 * void AMyActor::BeginPlay()
 * {
 *     Client = NewObject<UEchoelmusicClient>();
 *     Client->Connect("127.0.0.1", 8000);
 *
 *     // Bind bio-data event
 *     Client->OnBioDataReceived.AddDynamic(this, &AMyActor::HandleBioData);
 *
 *     // Bind beat event
 *     Client->OnBeatReceived.AddDynamic(this, &AMyActor::HandleBeat);
 * }
 *
 * void AMyActor::Tick(float DeltaTime)
 * {
 *     // Send player position
 *     FVector PlayerPos = GetPlayerLocation();
 *     Client->SendPlayerPosition(PlayerPos);
 * }
 *
 * void AMyActor::HandleBioData(float HRV, float Coherence, float Stress)
 * {
 *     // Adjust game based on bio-data
 *     if (Stress > 0.7f)
 *     {
 *         GameDifficulty = FMath::Max(GameDifficulty - 0.1f, 0.0f);
 *     }
 * }
 * ```
 */
class EchoelmusicUnrealPlugin
{
public:
    /**
     * Unreal C++ Plugin Structure
     */
    struct UnrealBridge
    {
        // Blueprint-callable functions
        void connect(const juce::String& host, int port);
        void disconnect();
        bool isConnected() const;

        void sendPlayerPosition(float x, float y, float z);
        void sendGameEvent(const juce::String& eventName, float value);

        // Blueprint events (delegates)
        struct OnBioDataReceived { float hrv; float coherence; float stress; };
        struct OnBeatReceived { int beatNumber; };
        struct OnBarReceived { int barNumber; };
        struct OnAudioEvent { juce::String eventName; float value; };
    };

    /**
     * Generate Unreal plugin files
     */
    static bool createUnrealPlugin(const juce::File& outputDir);

    /**
     * Files to generate:
     * - EchoelmusicClient.h/.cpp (UObject with Blueprint nodes)
     * - Echoelmusic.uplugin (plugin descriptor)
     * - Echoelmusic.Build.cs (build configuration)
     */
};

//==============================================================================
// GODOT PLUGIN
//==============================================================================

/**
 * Godot GDScript Integration
 *
 * USAGE IN GODOT (GDScript):
 * ```gdscript
 * extends Node
 *
 * var echoelmusic = EchoelmusicClient.new()
 *
 * func _ready():
 *     echoelmusic.connect_to_host("127.0.0.1", 8000)
 *     echoelmusic.connect("bio_data_received", self, "_on_bio_data")
 *     echoelmusic.connect("beat_received", self, "_on_beat")
 *
 * func _process(delta):
 *     # Send player position
 *     var player_pos = $Player.global_transform.origin
 *     echoelmusic.send_player_position(player_pos)
 *
 * func _on_bio_data(hrv, coherence, stress):
 *     print("HRV: ", hrv, " Stress: ", stress)
 *     # Adjust game based on stress
 *     if stress > 0.7:
 *         difficulty_manager.reduce_difficulty()
 *
 * func _on_beat(beat_number):
 *     # Visual effect on beat
 *     $VisualEffects.flash()
 * ```
 */
class EchoelmusicGodotPlugin
{
public:
    /**
     * Godot GDNative Plugin
     */
    struct GodotBridge
    {
        // GDScript-callable methods
        void connect_to_host(const juce::String& host, int port);
        void disconnect();
        bool is_connected() const;

        void send_player_position(float x, float y, float z);
        void send_game_event(const juce::String& eventName, float value);

        // Godot signals
        void emit_bio_data_received(float hrv, float coherence, float stress);
        void emit_beat_received(int beatNumber);
        void emit_bar_received(int barNumber);
    };

    /**
     * Generate Godot plugin files
     */
    static bool createGodotPlugin(const juce::File& outputDir);

    /**
     * Files to generate:
     * - echoelmusic.gdnlib (GDNative library descriptor)
     * - echoelmusic.gdns (Native script)
     * - libechoelmusic.so/.dll/.dylib (compiled library)
     */
};

//==============================================================================
// GAMEMAKER PLUGIN
//==============================================================================

/**
 * GameMaker GML Extension
 *
 * USAGE IN GAMEMAKER (GML):
 * ```gml
 * // Create event
 * echoelmusic_connect("127.0.0.1", 8000);
 *
 * // Step event
 * // Send player position
 * echoelmusic_send_position(x, y, 0);
 *
 * // Check for bio-data
 * if (echoelmusic_has_bio_data())
 * {
 *     var hrv = echoelmusic_get_hrv();
 *     var stress = echoelmusic_get_stress();
 *
 *     // Adjust game difficulty
 *     if (stress > 0.7)
 *     {
 *         global.difficulty = max(global.difficulty - 0.1, 0);
 *     }
 * }
 *
 * // Check for beat
 * if (echoelmusic_on_beat())
 * {
 *     // Visual effect
 *     instance_create_layer(x, y, "Effects", obj_flash);
 * }
 * ```
 */
class EchoelmusicGameMakerPlugin
{
public:
    /**
     * GameMaker Extension Functions
     */
    struct GameMakerBridge
    {
        // Connection
        static bool echoelmusic_connect(const char* host, int port);
        static void echoelmusic_disconnect();
        static bool echoelmusic_is_connected();

        // Send data
        static void echoelmusic_send_position(float x, float y, float z);
        static void echoelmusic_send_event(const char* eventName, float value);

        // Receive data
        static bool echoelmusic_has_bio_data();
        static float echoelmusic_get_hrv();
        static float echoelmusic_get_coherence();
        static float echoelmusic_get_stress();

        // Music events
        static bool echoelmusic_on_beat();
        static bool echoelmusic_on_bar();
        static int echoelmusic_get_beat_number();
    };

    /**
     * Generate GameMaker extension files
     */
    static bool createGameMakerExtension(const juce::File& outputDir);

    /**
     * Files to generate:
     * - Echoelmusic.extension.gmx (extension descriptor)
     * - Echoelmusic.dll/.so/.dylib (native library)
     * - Echoelmusic.gml (helper scripts)
     */
};

//==============================================================================
// WEB GAMES (WebSocket Bridge)
//==============================================================================

/**
 * WebSocket Bridge for HTML5/WebGL Games
 *
 * USAGE IN JAVASCRIPT:
 * ```javascript
 * // Connect to Echoelmusic
 * const echoelmusic = new EchoelmusicClient('ws://localhost:8000');
 *
 * echoelmusic.onConnect = () => {
 *     console.log('Connected to Echoelmusic');
 * };
 *
 * // Subscribe to bio-data
 * echoelmusic.onBioData = (hrv, coherence, stress) => {
 *     console.log(`HRV: ${hrv}, Stress: ${stress}`);
 *     // Adjust game difficulty
 *     if (stress > 0.7) {
 *         game.reduceDifficulty();
 *     }
 * };
 *
 * // Subscribe to beat
 * echoelmusic.onBeat = (beatNumber) => {
 *     // Visual effect
 *     game.flashScreen();
 * };
 *
 * // Send player position
 * function update() {
 *     echoelmusic.sendPlayerPosition(player.x, player.y, player.z);
 * }
 * ```
 */
class EchoelmusicWebBridge
{
public:
    /**
     * Generate JavaScript client library
     */
    static juce::String generateJavaScriptClient();

    /**
     * Generate TypeScript definitions
     */
    static juce::String generateTypeScriptDefinitions();

    /**
     * Create npm package
     */
    static bool createNpmPackage(const juce::File& outputDir);
};

//==============================================================================
// PLUGIN FACTORY
//==============================================================================

class EchoelPluginFactory
{
public:
    /**
     * Generate all plugin packages
     */
    static bool generateAllPlugins(const juce::File& outputDir);

    /**
     * Generate specific plugin
     */
    enum class PluginType { Unity, Unreal, Godot, GameMaker, Web };
    static bool generatePlugin(PluginType type, const juce::File& outputDir);

    /**
     * Test plugin with sample game
     */
    static bool testPlugin(PluginType type, const juce::File& sampleGame);
};

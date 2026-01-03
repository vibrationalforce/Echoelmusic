#pragma once

#include <JuceHeader.h>
#include <memory>
#include <vector>
#include <map>
#include <functional>
#include <atomic>
#include <thread>
#include <queue>
#include <mutex>

/**
 * LLMComposer - Large Language Model Integration for Music
 *
 * Cutting-edge natural language to music generation:
 * - Text-to-MIDI: "Generate a sad jazz chord progression"
 * - Style description: "80s synthwave with minor key"
 * - Lyrics generation with rhyme/meter awareness
 * - Music explanation and teaching
 * - Context-aware composition suggestions
 *
 * Backends:
 * - Local: Ollama (llama2, mistral, mixtral)
 * - Cloud: OpenAI GPT-4, Claude 3, Gemini Pro
 * - Edge: TinyLlama, Phi-2 for low-latency
 *
 * 2026 AGI-Ready Architecture
 */

namespace Echoelmusic {
namespace AI {

//==============================================================================
// LLM Backend Types
//==============================================================================

enum class LLMBackend
{
    // Local (Ollama)
    Ollama_Llama2_7B,
    Ollama_Llama2_13B,
    Ollama_Mistral_7B,
    Ollama_Mixtral_8x7B,
    Ollama_CodeLlama,
    Ollama_DeepSeek,

    // Cloud APIs
    OpenAI_GPT4,
    OpenAI_GPT4_Turbo,
    OpenAI_GPT4o,
    Anthropic_Claude3_Opus,
    Anthropic_Claude3_Sonnet,
    Anthropic_Claude35_Sonnet,
    Google_Gemini_Pro,
    Google_Gemini_Ultra,

    // Edge/Lightweight
    TinyLlama_1B,
    Phi2_3B,
    StableLM_3B,

    // Music-Specialized
    MusicGen_Small,
    MusicGen_Medium,
    MusicGen_Large,
    AudioLDM,

    Auto  // Best available
};

//==============================================================================
// Music Theory Structures
//==============================================================================

struct Note
{
    int pitch;          // MIDI note number 0-127
    float velocity;     // 0.0-1.0
    double startBeat;   // Position in beats
    double duration;    // Length in beats

    std::string toString() const
    {
        static const char* noteNames[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
        int octave = (pitch / 12) - 1;
        int note = pitch % 12;
        return std::string(noteNames[note]) + std::to_string(octave);
    }
};

struct Chord
{
    std::string name;           // "Cmaj7", "Dm", "G7"
    std::vector<int> notes;     // MIDI pitches
    double startBeat;
    double duration;
    float intensity;            // 0.0-1.0
};

struct MusicTheoryContext
{
    std::string key = "C";
    std::string mode = "major";  // major, minor, dorian, phrygian, etc.
    int tempo = 120;
    std::string timeSignature = "4/4";
    std::string genre = "pop";
    std::string mood = "neutral";
    float energy = 0.5f;         // 0.0-1.0
    float complexity = 0.5f;     // 0.0-1.0
};

struct Composition
{
    std::vector<Note> melody;
    std::vector<Chord> chords;
    std::vector<Note> bassline;
    std::vector<Note> drums;
    MusicTheoryContext context;
    std::string description;
    double lengthBeats;
};

//==============================================================================
// LLM Configuration
//==============================================================================

struct LLMConfig
{
    LLMBackend backend = LLMBackend::Auto;

    // Ollama settings
    std::string ollamaHost = "http://localhost:11434";
    std::string ollamaModel = "llama2";

    // OpenAI settings
    std::string openaiApiKey;
    std::string openaiOrgId;

    // Anthropic settings
    std::string anthropicApiKey;

    // Google settings
    std::string googleApiKey;

    // Generation parameters
    float temperature = 0.7f;    // Creativity (0.0-2.0)
    int maxTokens = 2048;
    float topP = 0.9f;
    float frequencyPenalty = 0.0f;
    float presencePenalty = 0.0f;

    // Timeouts
    int connectionTimeoutMs = 5000;
    int requestTimeoutMs = 60000;
};

//==============================================================================
// Prompt Templates
//==============================================================================

class PromptTemplates
{
public:
    static std::string getMelodyPrompt(const std::string& description,
                                        const MusicTheoryContext& context)
    {
        return R"(You are a professional music composer. Generate a melody based on:

Description: )" + description + R"(
Key: )" + context.key + " " + context.mode + R"(
Tempo: )" + std::to_string(context.tempo) + R"( BPM
Genre: )" + context.genre + R"(
Energy: )" + std::to_string(static_cast<int>(context.energy * 100)) + R"(%

Output ONLY a JSON array of notes with format:
[{"pitch": 60, "velocity": 0.8, "start": 0.0, "duration": 1.0}, ...]
where pitch is MIDI (60=C4), velocity 0-1, start/duration in beats.
Generate 8-16 bars. NO explanation, ONLY JSON.)";
    }

    static std::string getChordProgressionPrompt(const std::string& description,
                                                  const MusicTheoryContext& context)
    {
        return R"(You are a professional music theorist. Generate a chord progression:

Description: )" + description + R"(
Key: )" + context.key + " " + context.mode + R"(
Genre: )" + context.genre + R"(
Mood: )" + context.mood + R"(

Output ONLY a JSON array:
[{"name": "Cmaj7", "notes": [60, 64, 67, 71], "start": 0.0, "duration": 4.0}, ...]
Generate 4-8 chords forming a complete progression. NO explanation, ONLY JSON.)";
    }

    static std::string getLyricsPrompt(const std::string& theme,
                                        const std::string& style,
                                        int numVerses = 2)
    {
        return R"(You are a professional songwriter. Write lyrics:

Theme: )" + theme + R"(
Style: )" + style + R"(
Structure: )" + std::to_string(numVerses) + R"( verses + chorus

Requirements:
- Natural rhyme scheme (ABAB or AABB)
- Consistent meter/syllable count
- Emotional depth
- Hook in chorus

Output format:
[Verse 1]
...
[Chorus]
...
[Verse 2]
...

Write compelling, original lyrics.)";
    }

    static std::string getMusicExplanationPrompt(const Composition& composition)
    {
        return R"(Analyze this musical composition and explain:

Key: )" + composition.context.key + " " + composition.context.mode + R"(
Tempo: )" + std::to_string(composition.context.tempo) + R"( BPM
Genre: )" + composition.context.genre + R"(
Number of notes: )" + std::to_string(composition.melody.size()) + R"(
Number of chords: )" + std::to_string(composition.chords.size()) + R"(

Explain:
1. The harmonic structure and chord functions
2. Melodic contour and motifs
3. Rhythmic patterns
4. How it creates the intended mood
5. Production suggestions)";
    }

    static std::string getStyleTransferPrompt(const std::string& sourceStyle,
                                               const std::string& targetStyle)
    {
        return R"(Transform this music from )" + sourceStyle + R"( style to )" + targetStyle + R"( style.

Describe the specific changes needed:
1. Harmonic modifications
2. Rhythmic adjustments
3. Melodic alterations
4. Instrumentation changes
5. Production techniques

Be specific with music theory terms.)";
    }
};

//==============================================================================
// LLM Response Parser
//==============================================================================

class LLMResponseParser
{
public:
    static std::vector<Note> parseMelody(const std::string& response)
    {
        std::vector<Note> notes;

        try
        {
            // Find JSON array in response
            size_t start = response.find('[');
            size_t end = response.rfind(']');

            if (start != std::string::npos && end != std::string::npos)
            {
                std::string jsonStr = response.substr(start, end - start + 1);
                auto json = juce::JSON::parse(jsonStr);

                if (json.isArray())
                {
                    for (int i = 0; i < json.size(); ++i)
                    {
                        auto noteObj = json[i];
                        Note note;
                        note.pitch = static_cast<int>(noteObj["pitch"]);
                        note.velocity = static_cast<float>(noteObj["velocity"]);
                        note.startBeat = static_cast<double>(noteObj["start"]);
                        note.duration = static_cast<double>(noteObj["duration"]);
                        notes.push_back(note);
                    }
                }
            }
        }
        catch (...)
        {
            // Fallback: generate simple melody
            for (int i = 0; i < 16; ++i)
            {
                Note note;
                note.pitch = 60 + (i % 8);
                note.velocity = 0.8f;
                note.startBeat = i;
                note.duration = 0.5;
                notes.push_back(note);
            }
        }

        return notes;
    }

    static std::vector<Chord> parseChords(const std::string& response)
    {
        std::vector<Chord> chords;

        try
        {
            size_t start = response.find('[');
            size_t end = response.rfind(']');

            if (start != std::string::npos && end != std::string::npos)
            {
                std::string jsonStr = response.substr(start, end - start + 1);
                auto json = juce::JSON::parse(jsonStr);

                if (json.isArray())
                {
                    for (int i = 0; i < json.size(); ++i)
                    {
                        auto chordObj = json[i];
                        Chord chord;
                        chord.name = chordObj["name"].toString().toStdString();
                        chord.startBeat = static_cast<double>(chordObj["start"]);
                        chord.duration = static_cast<double>(chordObj["duration"]);

                        auto notesArr = chordObj["notes"];
                        if (notesArr.isArray())
                        {
                            for (int j = 0; j < notesArr.size(); ++j)
                                chord.notes.push_back(static_cast<int>(notesArr[j]));
                        }

                        chords.push_back(chord);
                    }
                }
            }
        }
        catch (...)
        {
            // Fallback: I-IV-V-I
            chords.push_back({"C", {60, 64, 67}, 0, 4, 0.8f});
            chords.push_back({"F", {65, 69, 72}, 4, 4, 0.8f});
            chords.push_back({"G", {67, 71, 74}, 8, 4, 0.9f});
            chords.push_back({"C", {60, 64, 67}, 12, 4, 0.7f});
        }

        return chords;
    }
};

//==============================================================================
// LLM Composer Engine
//==============================================================================

class LLMComposer
{
public:
    static LLMComposer& getInstance()
    {
        static LLMComposer instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Configuration
    //--------------------------------------------------------------------------

    void configure(const LLMConfig& config)
    {
        this->config = config;
        detectBestBackend();
    }

    LLMBackend getActiveBackend() const { return activeBackend; }

    bool isAvailable() const { return backendAvailable; }

    //--------------------------------------------------------------------------
    // Music Generation
    //--------------------------------------------------------------------------

    using CompletionCallback = std::function<void(const std::string& response, bool success)>;
    using CompositionCallback = std::function<void(const Composition& result, bool success)>;

    void generateMelodyAsync(const std::string& description,
                             const MusicTheoryContext& context,
                             std::function<void(const std::vector<Note>&)> callback)
    {
        std::string prompt = PromptTemplates::getMelodyPrompt(description, context);

        sendRequestAsync(prompt, [callback](const std::string& response, bool success) {
            if (success)
            {
                auto notes = LLMResponseParser::parseMelody(response);
                callback(notes);
            }
            else
            {
                callback({});
            }
        });
    }

    std::vector<Note> generateMelodySync(const std::string& description,
                                          const MusicTheoryContext& context)
    {
        std::string prompt = PromptTemplates::getMelodyPrompt(description, context);
        std::string response = sendRequestSync(prompt);
        return LLMResponseParser::parseMelody(response);
    }

    void generateChordsAsync(const std::string& description,
                             const MusicTheoryContext& context,
                             std::function<void(const std::vector<Chord>&)> callback)
    {
        std::string prompt = PromptTemplates::getChordProgressionPrompt(description, context);

        sendRequestAsync(prompt, [callback](const std::string& response, bool success) {
            if (success)
            {
                auto chords = LLMResponseParser::parseChords(response);
                callback(chords);
            }
            else
            {
                callback({});
            }
        });
    }

    std::vector<Chord> generateChordsSync(const std::string& description,
                                           const MusicTheoryContext& context)
    {
        std::string prompt = PromptTemplates::getChordProgressionPrompt(description, context);
        std::string response = sendRequestSync(prompt);
        return LLMResponseParser::parseChords(response);
    }

    void generateLyricsAsync(const std::string& theme,
                             const std::string& style,
                             std::function<void(const std::string&)> callback)
    {
        std::string prompt = PromptTemplates::getLyricsPrompt(theme, style);

        sendRequestAsync(prompt, [callback](const std::string& response, bool success) {
            callback(success ? response : "");
        });
    }

    //--------------------------------------------------------------------------
    // Full Composition Generation
    //--------------------------------------------------------------------------

    void composeFromPromptAsync(const std::string& description,
                                CompositionCallback callback)
    {
        // Multi-step composition pipeline
        std::thread([this, description, callback]() {
            Composition comp;
            comp.description = description;

            // Step 1: Analyze prompt to extract context
            comp.context = analyzePromptContext(description);

            // Step 2: Generate chord progression
            comp.chords = generateChordsSync(description, comp.context);

            // Step 3: Generate melody based on chords
            comp.melody = generateMelodySync(description, comp.context);

            // Step 4: Generate bassline
            comp.bassline = generateBasslineFromChords(comp.chords);

            // Step 5: Calculate length
            if (!comp.chords.empty())
            {
                const auto& lastChord = comp.chords.back();
                comp.lengthBeats = lastChord.startBeat + lastChord.duration;
            }

            callback(comp, true);
        }).detach();
    }

    //--------------------------------------------------------------------------
    // Music Understanding
    //--------------------------------------------------------------------------

    void explainMusicAsync(const Composition& composition,
                           std::function<void(const std::string&)> callback)
    {
        std::string prompt = PromptTemplates::getMusicExplanationPrompt(composition);
        sendRequestAsync(prompt, [callback](const std::string& response, bool success) {
            callback(success ? response : "Unable to analyze composition.");
        });
    }

    void suggestImprovementsAsync(const Composition& composition,
                                   std::function<void(const std::string&)> callback)
    {
        std::string prompt = R"(Analyze this composition and suggest 5 specific improvements:

Key: )" + composition.context.key + " " + composition.context.mode + R"(
Genre: )" + composition.context.genre + R"(
Tempo: )" + std::to_string(composition.context.tempo) + R"( BPM

Provide actionable music theory suggestions for:
1. Harmonic richness
2. Melodic interest
3. Rhythmic variety
4. Dynamic contrast
5. Production polish)";

        sendRequestAsync(prompt, [callback](const std::string& response, bool success) {
            callback(success ? response : "");
        });
    }

    //--------------------------------------------------------------------------
    // Style Transfer
    //--------------------------------------------------------------------------

    void transferStyleAsync(const Composition& source,
                            const std::string& targetStyle,
                            CompositionCallback callback)
    {
        std::thread([this, source, targetStyle, callback]() {
            // Get style transfer instructions
            std::string transferPrompt = PromptTemplates::getStyleTransferPrompt(
                source.context.genre, targetStyle);
            std::string instructions = sendRequestSync(transferPrompt);

            // Apply style to create new context
            MusicTheoryContext newContext = source.context;
            newContext.genre = targetStyle;

            // Regenerate with new style
            std::string newDescription = source.description + " in " + targetStyle + " style";

            Composition result;
            result.context = newContext;
            result.chords = generateChordsSync(newDescription, newContext);
            result.melody = generateMelodySync(newDescription, newContext);
            result.bassline = generateBasslineFromChords(result.chords);
            result.description = newDescription;

            callback(result, true);
        }).detach();
    }

    //--------------------------------------------------------------------------
    // Chat Interface
    //--------------------------------------------------------------------------

    struct ChatMessage
    {
        enum Role { System, User, Assistant };
        Role role;
        std::string content;
    };

    void chatAsync(const std::vector<ChatMessage>& history,
                   const std::string& userMessage,
                   std::function<void(const std::string&)> callback)
    {
        std::string systemPrompt = R"(You are an expert music composer and producer assistant.
You help users create music, understand music theory, and improve their compositions.
Always be specific with music theory terminology.
When generating music, output JSON format for notes/chords.
Be creative but grounded in solid music theory.)";

        std::string fullPrompt = "System: " + systemPrompt + "\n\n";

        for (const auto& msg : history)
        {
            if (msg.role == ChatMessage::User)
                fullPrompt += "User: " + msg.content + "\n";
            else if (msg.role == ChatMessage::Assistant)
                fullPrompt += "Assistant: " + msg.content + "\n";
        }

        fullPrompt += "User: " + userMessage + "\nAssistant:";

        sendRequestAsync(fullPrompt, [callback](const std::string& response, bool success) {
            callback(success ? response : "I'm having trouble connecting. Please try again.");
        });
    }

private:
    LLMComposer() { detectBestBackend(); }

    LLMConfig config;
    LLMBackend activeBackend = LLMBackend::Auto;
    std::atomic<bool> backendAvailable{false};
    std::mutex requestMutex;

    void detectBestBackend()
    {
        // Try backends in order of preference
        if (tryOllama())
        {
            activeBackend = LLMBackend::Ollama_Llama2_7B;
            backendAvailable = true;
            return;
        }

        if (!config.openaiApiKey.empty())
        {
            activeBackend = LLMBackend::OpenAI_GPT4_Turbo;
            backendAvailable = true;
            return;
        }

        if (!config.anthropicApiKey.empty())
        {
            activeBackend = LLMBackend::Anthropic_Claude35_Sonnet;
            backendAvailable = true;
            return;
        }

        // Fallback to local tiny model
        activeBackend = LLMBackend::TinyLlama_1B;
        backendAvailable = false;
    }

    bool tryOllama()
    {
        // Check if Ollama is running
        juce::URL url(config.ollamaHost + "/api/tags");

        auto options = juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inAddress)
            .withConnectionTimeoutMs(config.connectionTimeoutMs);

        auto stream = url.createInputStream(options);
        return stream != nullptr;
    }

    void sendRequestAsync(const std::string& prompt, CompletionCallback callback)
    {
        std::thread([this, prompt, callback]() {
            std::string response = sendRequestSync(prompt);
            callback(response, !response.empty());
        }).detach();
    }

    std::string sendRequestSync(const std::string& prompt)
    {
        std::lock_guard<std::mutex> lock(requestMutex);

        switch (activeBackend)
        {
            case LLMBackend::Ollama_Llama2_7B:
            case LLMBackend::Ollama_Mistral_7B:
            case LLMBackend::Ollama_Mixtral_8x7B:
                return sendOllamaRequest(prompt);

            case LLMBackend::OpenAI_GPT4:
            case LLMBackend::OpenAI_GPT4_Turbo:
            case LLMBackend::OpenAI_GPT4o:
                return sendOpenAIRequest(prompt);

            case LLMBackend::Anthropic_Claude3_Opus:
            case LLMBackend::Anthropic_Claude3_Sonnet:
            case LLMBackend::Anthropic_Claude35_Sonnet:
                return sendAnthropicRequest(prompt);

            default:
                return "";
        }
    }

    std::string sendOllamaRequest(const std::string& prompt)
    {
        juce::DynamicObject::Ptr requestObj = new juce::DynamicObject();
        requestObj->setProperty("model", juce::String(config.ollamaModel));
        requestObj->setProperty("prompt", juce::String(prompt));
        requestObj->setProperty("stream", false);

        juce::DynamicObject::Ptr options = new juce::DynamicObject();
        options->setProperty("temperature", config.temperature);
        options->setProperty("num_predict", config.maxTokens);
        requestObj->setProperty("options", juce::var(options.get()));

        std::string body = juce::JSON::toString(juce::var(requestObj.get())).toStdString();

        juce::URL url(config.ollamaHost + "/api/generate");
        url = url.withPOSTData(body);

        auto options2 = juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
            .withExtraHeaders("Content-Type: application/json")
            .withConnectionTimeoutMs(config.requestTimeoutMs);

        auto stream = url.createInputStream(options2);

        if (stream)
        {
            auto response = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(response);
            return json["response"].toString().toStdString();
        }

        return "";
    }

    std::string sendOpenAIRequest(const std::string& prompt)
    {
        juce::DynamicObject::Ptr requestObj = new juce::DynamicObject();
        requestObj->setProperty("model", "gpt-4-turbo-preview");
        requestObj->setProperty("max_tokens", config.maxTokens);
        requestObj->setProperty("temperature", config.temperature);

        juce::Array<juce::var> messages;
        juce::DynamicObject::Ptr msg = new juce::DynamicObject();
        msg->setProperty("role", "user");
        msg->setProperty("content", juce::String(prompt));
        messages.add(juce::var(msg.get()));
        requestObj->setProperty("messages", messages);

        std::string body = juce::JSON::toString(juce::var(requestObj.get())).toStdString();

        juce::URL url("https://api.openai.com/v1/chat/completions");
        url = url.withPOSTData(body);

        auto options = juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
            .withExtraHeaders("Content-Type: application/json\r\nAuthorization: Bearer " + config.openaiApiKey)
            .withConnectionTimeoutMs(config.requestTimeoutMs);

        auto stream = url.createInputStream(options);

        if (stream)
        {
            auto response = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(response);
            return json["choices"][0]["message"]["content"].toString().toStdString();
        }

        return "";
    }

    std::string sendAnthropicRequest(const std::string& prompt)
    {
        juce::DynamicObject::Ptr requestObj = new juce::DynamicObject();
        requestObj->setProperty("model", "claude-3-5-sonnet-20241022");
        requestObj->setProperty("max_tokens", config.maxTokens);

        juce::Array<juce::var> messages;
        juce::DynamicObject::Ptr msg = new juce::DynamicObject();
        msg->setProperty("role", "user");
        msg->setProperty("content", juce::String(prompt));
        messages.add(juce::var(msg.get()));
        requestObj->setProperty("messages", messages);

        std::string body = juce::JSON::toString(juce::var(requestObj.get())).toStdString();

        juce::URL url("https://api.anthropic.com/v1/messages");
        url = url.withPOSTData(body);

        auto options = juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
            .withExtraHeaders("Content-Type: application/json\r\nx-api-key: " + config.anthropicApiKey +
                              "\r\nanthropic-version: 2023-06-01")
            .withConnectionTimeoutMs(config.requestTimeoutMs);

        auto stream = url.createInputStream(options);

        if (stream)
        {
            auto response = stream->readEntireStreamAsString();
            auto json = juce::JSON::parse(response);
            return json["content"][0]["text"].toString().toStdString();
        }

        return "";
    }

    MusicTheoryContext analyzePromptContext(const std::string& description)
    {
        MusicTheoryContext ctx;

        // Keyword-based context extraction
        std::string lower = description;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

        // Mood detection
        if (lower.find("sad") != std::string::npos || lower.find("melancholy") != std::string::npos)
        {
            ctx.mood = "sad";
            ctx.mode = "minor";
            ctx.energy = 0.3f;
        }
        else if (lower.find("happy") != std::string::npos || lower.find("upbeat") != std::string::npos)
        {
            ctx.mood = "happy";
            ctx.mode = "major";
            ctx.energy = 0.8f;
        }
        else if (lower.find("epic") != std::string::npos || lower.find("powerful") != std::string::npos)
        {
            ctx.mood = "epic";
            ctx.energy = 1.0f;
        }
        else if (lower.find("calm") != std::string::npos || lower.find("peaceful") != std::string::npos)
        {
            ctx.mood = "calm";
            ctx.energy = 0.2f;
        }

        // Genre detection
        if (lower.find("jazz") != std::string::npos) ctx.genre = "jazz";
        else if (lower.find("rock") != std::string::npos) ctx.genre = "rock";
        else if (lower.find("electronic") != std::string::npos) ctx.genre = "electronic";
        else if (lower.find("classical") != std::string::npos) ctx.genre = "classical";
        else if (lower.find("hip hop") != std::string::npos || lower.find("hiphop") != std::string::npos) ctx.genre = "hip-hop";
        else if (lower.find("ambient") != std::string::npos) ctx.genre = "ambient";
        else if (lower.find("synthwave") != std::string::npos || lower.find("80s") != std::string::npos) ctx.genre = "synthwave";

        // Tempo hints
        if (lower.find("slow") != std::string::npos) ctx.tempo = 70;
        else if (lower.find("fast") != std::string::npos) ctx.tempo = 140;
        else if (lower.find("upbeat") != std::string::npos) ctx.tempo = 128;

        return ctx;
    }

    std::vector<Note> generateBasslineFromChords(const std::vector<Chord>& chords)
    {
        std::vector<Note> bassline;

        for (const auto& chord : chords)
        {
            if (chord.notes.empty()) continue;

            // Root note, octave down
            Note bass;
            bass.pitch = chord.notes[0] - 12;
            bass.velocity = 0.9f;
            bass.startBeat = chord.startBeat;
            bass.duration = chord.duration / 2;
            bassline.push_back(bass);

            // Fifth on the "and" beats
            if (chord.notes.size() > 2)
            {
                Note fifth;
                fifth.pitch = chord.notes[2] - 12;
                fifth.velocity = 0.7f;
                fifth.startBeat = chord.startBeat + chord.duration / 2;
                fifth.duration = chord.duration / 2;
                bassline.push_back(fifth);
            }
        }

        return bassline;
    }
};

//==============================================================================
// Convenience
//==============================================================================

#define MusicLLM LLMComposer::getInstance()

} // namespace AI
} // namespace Echoelmusic

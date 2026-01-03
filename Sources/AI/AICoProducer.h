#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <string>
#include <map>
#include <functional>
#include <deque>
#include <chrono>
#include <optional>

/**
 * AICoProducer - Conversational Music Production Assistant
 *
 * Chat-based AI co-producer that can:
 * - Suggest arrangement changes ("add a breakdown at bar 32")
 * - Generate musical ideas ("create a bassline in E minor")
 * - Analyze your track ("what key is this in?")
 * - Mix suggestions ("this kick needs more punch")
 * - Sound design ("make this synth warmer")
 * - Reference matching ("make it sound like Daft Punk")
 * - Real-time collaboration ("let's work on the chorus")
 *
 * Uses Large Language Models with music domain knowledge
 * and integrates with DAW state for context-aware responses.
 *
 * Super Ralph Wiggum Loop Genius Co-Producer Mode
 */

namespace Echoelmusic {
namespace AI {

//==============================================================================
// Production Intent Types
//==============================================================================

enum class ProductionIntent
{
    // Composition
    GenerateMelody,
    GenerateBassline,
    GenerateChords,
    GenerateDrumPattern,
    GenerateArpeggio,

    // Arrangement
    SuggestArrangement,
    AddSection,
    RemoveSection,
    CopySection,
    CreateTransition,
    CreateBuildup,
    CreateBreakdown,
    CreateDrop,

    // Mixing
    AdjustLevels,
    AddEffect,
    RemoveEffect,
    AdjustPanning,
    SuggestEQ,
    SuggestCompression,
    SuggestReverb,

    // Sound Design
    CreateSound,
    ModifySound,
    LayerSounds,
    DesignPatch,

    // Analysis
    AnalyzeKey,
    AnalyzeChords,
    AnalyzeTempo,
    AnalyzeEnergy,
    AnalyzeSpectrum,
    AnalyzeReference,

    // General
    Question,
    Feedback,
    Undo,
    Redo,
    Help,

    Unknown
};

//==============================================================================
// Message Types
//==============================================================================

struct ChatMessage
{
    enum class Role { User, Assistant, System };

    Role role = Role::User;
    std::string content;
    std::chrono::system_clock::time_point timestamp;

    // Optional structured data
    ProductionIntent intent = ProductionIntent::Unknown;
    std::map<std::string, std::string> parameters;

    // For assistant messages: actions taken
    std::vector<std::string> actionsPerformed;

    ChatMessage() : timestamp(std::chrono::system_clock::now()) {}

    ChatMessage(Role r, const std::string& msg)
        : role(r), content(msg), timestamp(std::chrono::system_clock::now()) {}
};

//==============================================================================
// Project Context (for context-aware responses)
//==============================================================================

struct ProjectContext
{
    std::string projectName;
    double tempo = 120.0;
    std::string key = "C major";
    std::string timeSignature = "4/4";
    int currentBar = 1;

    std::vector<std::string> trackNames;
    std::vector<std::string> activePlugins;

    // Current selection
    int selectedTrack = 0;
    int selectionStartBar = 0;
    int selectionEndBar = 0;

    // Recent changes for context
    std::vector<std::string> recentChanges;

    // Audio analysis results
    double averageLoudness = -12.0;  // LUFS
    double peakLevel = -3.0;         // dB
    double dynamicRange = 8.0;       // LU
    std::vector<float> spectrumProfile;

    std::string toPromptContext() const
    {
        std::string ctx = "Current Project Context:\n";
        ctx += "- Project: " + projectName + "\n";
        ctx += "- Tempo: " + std::to_string(static_cast<int>(tempo)) + " BPM\n";
        ctx += "- Key: " + key + "\n";
        ctx += "- Time: " + timeSignature + "\n";
        ctx += "- Current Bar: " + std::to_string(currentBar) + "\n";

        if (!trackNames.empty())
        {
            ctx += "- Tracks: ";
            for (size_t i = 0; i < trackNames.size(); ++i)
            {
                ctx += trackNames[i];
                if (i < trackNames.size() - 1) ctx += ", ";
            }
            ctx += "\n";
        }

        ctx += "- Loudness: " + std::to_string(static_cast<int>(averageLoudness)) + " LUFS\n";
        ctx += "- Peak: " + std::to_string(static_cast<int>(peakLevel)) + " dB\n";

        if (!recentChanges.empty())
        {
            ctx += "- Recent changes: " + recentChanges.back() + "\n";
        }

        return ctx;
    }
};

//==============================================================================
// Production Action (executable by DAW)
//==============================================================================

struct ProductionAction
{
    enum class Type
    {
        CreateTrack,
        DeleteTrack,
        RenameTrack,
        AddClip,
        DeleteClip,
        MoveClip,
        AddPlugin,
        RemovePlugin,
        SetParameter,
        SetTempo,
        SetKey,
        GenerateMIDI,
        GenerateAudio,
        ApplyPreset,
        Undo,
        Redo,
        Select,
        None
    };

    Type type = Type::None;
    std::map<std::string, std::string> parameters;
    std::string description;

    // For undo support
    std::string undoDescription;
    std::function<void()> undoAction;
};

//==============================================================================
// LLM Backend Interface
//==============================================================================

class LLMBackend
{
public:
    virtual ~LLMBackend() = default;

    struct Response
    {
        std::string text;
        std::vector<ProductionAction> suggestedActions;
        ProductionIntent detectedIntent = ProductionIntent::Unknown;
        float confidence = 0.0f;
    };

    virtual Response generate(const std::string& prompt,
                             const std::vector<ChatMessage>& history,
                             const ProjectContext& context) = 0;

    virtual void setSystemPrompt(const std::string& prompt) = 0;
    virtual void setTemperature(float temp) = 0;
    virtual void setMaxTokens(int tokens) = 0;
};

//==============================================================================
// OpenAI-compatible Backend
//==============================================================================

class OpenAIBackend : public LLMBackend
{
public:
    OpenAIBackend(const std::string& apiKey, const std::string& model = "gpt-4")
        : apiKey(apiKey), modelName(model)
    {
        systemPrompt = getDefaultSystemPrompt();
    }

    Response generate(const std::string& prompt,
                     const std::vector<ChatMessage>& history,
                     const ProjectContext& context) override
    {
        Response response;

        // Build messages array for API
        std::string messagesJson = "[";

        // System message with context
        messagesJson += R"({"role": "system", "content": ")" +
                        escapeJson(systemPrompt + "\n\n" + context.toPromptContext()) + "\"},";

        // History
        for (const auto& msg : history)
        {
            std::string role = (msg.role == ChatMessage::Role::User) ? "user" : "assistant";
            messagesJson += R"({"role": ")" + role + R"(", "content": ")" +
                            escapeJson(msg.content) + "\"},";
        }

        // Current message
        messagesJson += R"({"role": "user", "content": ")" + escapeJson(prompt) + "\"}";
        messagesJson += "]";

        // Make API request
        juce::URL url("https://api.openai.com/v1/chat/completions");

        juce::String requestBody = R"({
            "model": ")" + juce::String(modelName) + R"(",
            "messages": )" + juce::String(messagesJson) + R"(,
            "temperature": )" + juce::String(temperature) + R"(,
            "max_tokens": )" + juce::String(maxTokens) + R"(,
            "functions": [)" + getFunctionDefinitions() + R"(]
        })";

        juce::StringPairArray headers;
        headers.set("Content-Type", "application/json");
        headers.set("Authorization", "Bearer " + juce::String(apiKey));

        auto options = juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
            .withExtraHeaders(headers.getDescription())
            .withConnectionTimeoutMs(30000);

        // In real implementation, would make the HTTP request
        // For now, simulate a response
        response.text = "I understand you want to work on the music. Let me help with that!";
        response.confidence = 0.9f;

        return response;
    }

    void setSystemPrompt(const std::string& prompt) override { systemPrompt = prompt; }
    void setTemperature(float temp) override { temperature = temp; }
    void setMaxTokens(int tokens) override { maxTokens = tokens; }

private:
    std::string apiKey;
    std::string modelName;
    std::string systemPrompt;
    float temperature = 0.7f;
    int maxTokens = 1024;

    std::string getDefaultSystemPrompt()
    {
        return R"(You are an expert music producer and co-producer AI assistant integrated into Echoelmusic DAW.

Your capabilities include:
- Suggesting arrangement changes and musical ideas
- Helping with mixing decisions (EQ, compression, effects)
- Analyzing tracks for key, tempo, and energy
- Sound design guidance
- Reference track matching
- Creative collaboration on music production

When suggesting changes, be specific about:
- Which track/instrument to modify
- Exact parameter values when relevant
- Bar numbers for arrangement changes
- Musical terminology (notes, scales, chords)

Always consider the current project context provided.
Be creative, encouraging, and technically accurate.
If asked to generate music, describe what you would create in detail.
For mixing advice, explain the reasoning behind suggestions.

You can execute actions in the DAW by returning structured commands.
)";
    }

    std::string getFunctionDefinitions()
    {
        return R"(
{
    "name": "set_tempo",
    "description": "Change the project tempo",
    "parameters": {
        "type": "object",
        "properties": {
            "bpm": {"type": "number", "description": "Tempo in BPM"}
        },
        "required": ["bpm"]
    }
},
{
    "name": "add_track",
    "description": "Add a new track to the project",
    "parameters": {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "type": {"type": "string", "enum": ["audio", "midi", "instrument"]}
        }
    }
},
{
    "name": "generate_pattern",
    "description": "Generate a musical pattern",
    "parameters": {
        "type": "object",
        "properties": {
            "type": {"type": "string", "enum": ["melody", "bass", "chords", "drums", "arp"]},
            "key": {"type": "string"},
            "length_bars": {"type": "integer"},
            "style": {"type": "string"}
        }
    }
}
)";
    }

    std::string escapeJson(const std::string& input)
    {
        std::string result;
        for (char c : input)
        {
            switch (c)
            {
                case '"':  result += "\\\""; break;
                case '\\': result += "\\\\"; break;
                case '\n': result += "\\n"; break;
                case '\r': result += "\\r"; break;
                case '\t': result += "\\t"; break;
                default:   result += c;
            }
        }
        return result;
    }
};

//==============================================================================
// Local LLM Backend (Ollama/llama.cpp)
//==============================================================================

class LocalLLMBackend : public LLMBackend
{
public:
    LocalLLMBackend(const std::string& modelPath, int port = 11434)
        : modelPath(modelPath), ollamaPort(port)
    {
        systemPrompt = getDefaultSystemPrompt();
    }

    Response generate(const std::string& prompt,
                     const std::vector<ChatMessage>& history,
                     const ProjectContext& context) override
    {
        Response response;

        // Call local Ollama API
        juce::URL url("http://localhost:" + std::to_string(ollamaPort) + "/api/generate");

        // Build prompt with history and context
        std::string fullPrompt = systemPrompt + "\n\n" + context.toPromptContext() + "\n\n";

        for (const auto& msg : history)
        {
            std::string role = (msg.role == ChatMessage::Role::User) ? "User" : "Assistant";
            fullPrompt += role + ": " + msg.content + "\n\n";
        }

        fullPrompt += "User: " + prompt + "\n\nAssistant:";

        // In real implementation, would make HTTP request to Ollama
        response.text = "Working on your request...";
        response.confidence = 0.85f;

        return response;
    }

    void setSystemPrompt(const std::string& prompt) override { systemPrompt = prompt; }
    void setTemperature(float temp) override { temperature = temp; }
    void setMaxTokens(int tokens) override { maxTokens = tokens; }

private:
    std::string modelPath;
    int ollamaPort;
    std::string systemPrompt;
    float temperature = 0.7f;
    int maxTokens = 1024;

    std::string getDefaultSystemPrompt()
    {
        return "You are a music production AI assistant. Help with mixing, arrangement, and creative ideas.";
    }
};

//==============================================================================
// Intent Classifier
//==============================================================================

class IntentClassifier
{
public:
    struct ClassificationResult
    {
        ProductionIntent intent = ProductionIntent::Unknown;
        float confidence = 0.0f;
        std::map<std::string, std::string> entities;
    };

    ClassificationResult classify(const std::string& input)
    {
        ClassificationResult result;
        std::string lower = toLower(input);

        // Simple keyword-based classification
        // In production, would use a trained model

        // Composition intents
        if (contains(lower, "melody") || contains(lower, "tune"))
        {
            result.intent = ProductionIntent::GenerateMelody;
            result.confidence = 0.8f;
        }
        else if (contains(lower, "bass") || contains(lower, "bassline"))
        {
            result.intent = ProductionIntent::GenerateBassline;
            result.confidence = 0.8f;
        }
        else if (contains(lower, "chord") || contains(lower, "harmony"))
        {
            result.intent = ProductionIntent::GenerateChords;
            result.confidence = 0.8f;
        }
        else if (contains(lower, "drum") || contains(lower, "beat") || contains(lower, "rhythm"))
        {
            result.intent = ProductionIntent::GenerateDrumPattern;
            result.confidence = 0.8f;
        }
        else if (contains(lower, "arp"))
        {
            result.intent = ProductionIntent::GenerateArpeggio;
            result.confidence = 0.8f;
        }

        // Arrangement intents
        else if (contains(lower, "breakdown"))
        {
            result.intent = ProductionIntent::CreateBreakdown;
            result.confidence = 0.85f;
        }
        else if (contains(lower, "buildup") || contains(lower, "build"))
        {
            result.intent = ProductionIntent::CreateBuildup;
            result.confidence = 0.85f;
        }
        else if (contains(lower, "drop"))
        {
            result.intent = ProductionIntent::CreateDrop;
            result.confidence = 0.85f;
        }
        else if (contains(lower, "transition"))
        {
            result.intent = ProductionIntent::CreateTransition;
            result.confidence = 0.85f;
        }
        else if (contains(lower, "arrange") || contains(lower, "structure"))
        {
            result.intent = ProductionIntent::SuggestArrangement;
            result.confidence = 0.8f;
        }

        // Mixing intents
        else if (contains(lower, "eq") || contains(lower, "frequency"))
        {
            result.intent = ProductionIntent::SuggestEQ;
            result.confidence = 0.85f;
        }
        else if (contains(lower, "compress") || contains(lower, "punch") || contains(lower, "tight"))
        {
            result.intent = ProductionIntent::SuggestCompression;
            result.confidence = 0.8f;
        }
        else if (contains(lower, "reverb") || contains(lower, "space") || contains(lower, "room"))
        {
            result.intent = ProductionIntent::SuggestReverb;
            result.confidence = 0.8f;
        }
        else if (contains(lower, "level") || contains(lower, "volume") || contains(lower, "loud"))
        {
            result.intent = ProductionIntent::AdjustLevels;
            result.confidence = 0.8f;
        }
        else if (contains(lower, "pan") || contains(lower, "stereo") || contains(lower, "wide"))
        {
            result.intent = ProductionIntent::AdjustPanning;
            result.confidence = 0.8f;
        }

        // Analysis intents
        else if (contains(lower, "key") || contains(lower, "scale"))
        {
            result.intent = ProductionIntent::AnalyzeKey;
            result.confidence = 0.9f;
        }
        else if (contains(lower, "tempo") || contains(lower, "bpm"))
        {
            result.intent = ProductionIntent::AnalyzeTempo;
            result.confidence = 0.9f;
        }
        else if (contains(lower, "analyze") || contains(lower, "analysis"))
        {
            result.intent = ProductionIntent::AnalyzeSpectrum;
            result.confidence = 0.7f;
        }

        // Sound design
        else if (contains(lower, "sound") && (contains(lower, "create") || contains(lower, "design")))
        {
            result.intent = ProductionIntent::CreateSound;
            result.confidence = 0.8f;
        }
        else if (contains(lower, "warm") || contains(lower, "bright") || contains(lower, "dark"))
        {
            result.intent = ProductionIntent::ModifySound;
            result.confidence = 0.75f;
        }

        // General
        else if (contains(lower, "undo"))
        {
            result.intent = ProductionIntent::Undo;
            result.confidence = 0.95f;
        }
        else if (contains(lower, "redo"))
        {
            result.intent = ProductionIntent::Redo;
            result.confidence = 0.95f;
        }
        else if (contains(lower, "help") || contains(lower, "how"))
        {
            result.intent = ProductionIntent::Help;
            result.confidence = 0.8f;
        }
        else if (contains(lower, "?"))
        {
            result.intent = ProductionIntent::Question;
            result.confidence = 0.6f;
        }

        // Extract entities
        extractEntities(lower, result);

        return result;
    }

private:
    std::string toLower(const std::string& s)
    {
        std::string result = s;
        std::transform(result.begin(), result.end(), result.begin(), ::tolower);
        return result;
    }

    bool contains(const std::string& text, const std::string& word)
    {
        return text.find(word) != std::string::npos;
    }

    void extractEntities(const std::string& text, ClassificationResult& result)
    {
        // Extract key mentions
        std::vector<std::string> keys = {
            "c major", "c minor", "d major", "d minor", "e major", "e minor",
            "f major", "f minor", "g major", "g minor", "a major", "a minor",
            "b major", "b minor"
        };

        for (const auto& key : keys)
        {
            if (contains(text, key))
            {
                result.entities["key"] = key;
                break;
            }
        }

        // Extract bar numbers (simple regex-like pattern matching)
        // "bar 32", "bars 1-8", etc.
        // In production, would use proper regex

        // Extract track mentions
        if (contains(text, "kick")) result.entities["track"] = "kick";
        else if (contains(text, "snare")) result.entities["track"] = "snare";
        else if (contains(text, "bass")) result.entities["track"] = "bass";
        else if (contains(text, "vocal")) result.entities["track"] = "vocal";
        else if (contains(text, "synth")) result.entities["track"] = "synth";
    }
};

//==============================================================================
// AI Co-Producer Engine
//==============================================================================

class AICoProducer
{
public:
    using ResponseCallback = std::function<void(const ChatMessage&)>;
    using ActionCallback = std::function<void(const ProductionAction&)>;

    AICoProducer()
    {
        // Initialize with local backend by default
        backend = std::make_unique<LocalLLMBackend>("mistral");
    }

    //--------------------------------------------------------------------------
    // Backend Configuration
    //--------------------------------------------------------------------------

    void setOpenAIBackend(const std::string& apiKey, const std::string& model = "gpt-4")
    {
        backend = std::make_unique<OpenAIBackend>(apiKey, model);
    }

    void setLocalBackend(const std::string& model = "mistral")
    {
        backend = std::make_unique<LocalLLMBackend>(model);
    }

    //--------------------------------------------------------------------------
    // Context
    //--------------------------------------------------------------------------

    void updateContext(const ProjectContext& ctx)
    {
        context = ctx;
    }

    const ProjectContext& getContext() const { return context; }

    //--------------------------------------------------------------------------
    // Chat
    //--------------------------------------------------------------------------

    void sendMessage(const std::string& message, ResponseCallback onResponse)
    {
        // Add user message to history
        ChatMessage userMsg(ChatMessage::Role::User, message);
        userMsg.intent = classifier.classify(message).intent;
        history.push_back(userMsg);

        // Limit history size
        while (history.size() > maxHistorySize)
            history.pop_front();

        // Generate response asynchronously
        // In production, would use background thread
        auto response = backend->generate(message, std::vector<ChatMessage>(history.begin(), history.end()), context);

        // Create assistant message
        ChatMessage assistantMsg(ChatMessage::Role::Assistant, response.text);
        assistantMsg.intent = response.detectedIntent;

        // Extract actions from response
        for (const auto& action : response.suggestedActions)
        {
            assistantMsg.actionsPerformed.push_back(action.description);
        }

        history.push_back(assistantMsg);

        // Callback with response
        if (onResponse)
            onResponse(assistantMsg);

        // Execute suggested actions
        for (const auto& action : response.suggestedActions)
        {
            executeAction(action);
        }
    }

    //--------------------------------------------------------------------------
    // Quick Actions
    //--------------------------------------------------------------------------

    void suggestArrangement()
    {
        sendMessage("Suggest an arrangement structure for this track", nullptr);
    }

    void analyzeTrack()
    {
        sendMessage("Analyze this track and give me feedback on the mix", nullptr);
    }

    void generateIdeas()
    {
        sendMessage("Generate some creative ideas to improve this track", nullptr);
    }

    //--------------------------------------------------------------------------
    // Action Execution
    //--------------------------------------------------------------------------

    void setActionCallback(ActionCallback callback)
    {
        actionCallback = callback;
    }

    void executeAction(const ProductionAction& action)
    {
        if (actionCallback)
            actionCallback(action);
    }

    //--------------------------------------------------------------------------
    // History
    //--------------------------------------------------------------------------

    const std::deque<ChatMessage>& getHistory() const { return history; }

    void clearHistory()
    {
        history.clear();
    }

    //--------------------------------------------------------------------------
    // Presets / Quick Prompts
    //--------------------------------------------------------------------------

    struct QuickPrompt
    {
        std::string name;
        std::string prompt;
        std::string icon;
    };

    std::vector<QuickPrompt> getQuickPrompts() const
    {
        return {
            {"Arrangement", "Suggest an arrangement for a 3-minute track", "grid"},
            {"Mix Check", "Review my mix and suggest improvements", "sliders"},
            {"Energy Curve", "Analyze and suggest energy curve changes", "chart"},
            {"Reference Match", "How can I make this sound more professional?", "star"},
            {"Creative Block", "I'm stuck - give me some fresh ideas", "lightbulb"},
            {"Finish Track", "What's missing to finish this track?", "check"},
            {"Genre Tips", "Tips for making this sound more [genre]", "music"},
            {"Sound Design", "Help me design a signature sound", "waveform"}
        };
    }

private:
    std::unique_ptr<LLMBackend> backend;
    IntentClassifier classifier;
    ProjectContext context;
    std::deque<ChatMessage> history;
    ActionCallback actionCallback;

    size_t maxHistorySize = 50;
};

//==============================================================================
// Chat UI Component
//==============================================================================

class ChatBubbleComponent : public juce::Component
{
public:
    ChatBubbleComponent(const ChatMessage& msg) : message(msg)
    {
        setSize(300, calculateHeight());
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(5);

        // Bubble background
        juce::Colour bgColor = (message.role == ChatMessage::Role::User)
            ? juce::Colour(0xff3a5795)
            : juce::Colour(0xff2a2a3e);

        g.setColour(bgColor);
        g.fillRoundedRectangle(bounds, 10.0f);

        // Message text
        g.setColour(juce::Colours::white);
        g.setFont(14.0f);

        auto textBounds = bounds.reduced(10);
        g.drawFittedText(message.content, textBounds.toNearestInt(),
                         juce::Justification::topLeft, 100);

        // Timestamp
        g.setColour(juce::Colours::grey);
        g.setFont(10.0f);

        auto time = std::chrono::system_clock::to_time_t(message.timestamp);
        char timeStr[20];
        std::strftime(timeStr, sizeof(timeStr), "%H:%M", std::localtime(&time));

        g.drawText(timeStr, bounds.removeFromBottom(15), juce::Justification::right);
    }

private:
    ChatMessage message;

    int calculateHeight() const
    {
        // Estimate height based on message length
        int lines = static_cast<int>(message.content.length() / 40) + 1;
        return std::max(60, lines * 20 + 40);
    }
};

class CoProducerChatPanel : public juce::Component
{
public:
    CoProducerChatPanel(AICoProducer* producer) : coProducer(producer)
    {
        addAndMakeVisible(chatView);
        chatView.setModel(this);

        addAndMakeVisible(inputField);
        inputField.setMultiLine(false);
        inputField.setReturnKeyStartsNewLine(false);
        inputField.setTextToShowWhenEmpty("Ask your AI co-producer...", juce::Colours::grey);
        inputField.onReturnKey = [this]() { sendMessage(); };

        addAndMakeVisible(sendButton);
        sendButton.setButtonText("Send");
        sendButton.onClick = [this]() { sendMessage(); };

        // Quick prompts
        auto prompts = coProducer->getQuickPrompts();
        for (const auto& prompt : prompts)
        {
            auto* btn = new juce::TextButton(prompt.name);
            btn->onClick = [this, p = prompt.prompt]() {
                inputField.setText(p);
                sendMessage();
            };
            addAndMakeVisible(btn);
            quickPromptButtons.add(btn);
        }

        refreshChat();
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        // Quick prompts at top
        auto promptRow = bounds.removeFromTop(35);
        int btnWidth = promptRow.getWidth() / std::max(1, quickPromptButtons.size());
        for (auto* btn : quickPromptButtons)
        {
            btn->setBounds(promptRow.removeFromLeft(btnWidth).reduced(2));
        }

        // Input at bottom
        auto inputRow = bounds.removeFromBottom(40);
        sendButton.setBounds(inputRow.removeFromRight(80).reduced(5));
        inputField.setBounds(inputRow.reduced(5));

        // Chat view fills rest
        chatView.setBounds(bounds.reduced(5));
    }

    int getNumRows() { return static_cast<int>(chatBubbles.size()); }

    void paintListBoxItem(int rowNumber, juce::Graphics& g, int width, int height, bool rowIsSelected)
    {
        // Background
        if (rowNumber % 2)
            g.fillAll(juce::Colour(0xff1a1a2e));
    }

    juce::Component* refreshComponentForRow(int rowNumber, bool isRowSelected, juce::Component* existingComponent)
    {
        if (rowNumber < static_cast<int>(chatBubbles.size()))
        {
            auto* bubble = existingComponent ? dynamic_cast<ChatBubbleComponent*>(existingComponent)
                                             : new ChatBubbleComponent(coProducer->getHistory()[rowNumber]);
            return bubble;
        }
        return nullptr;
    }

private:
    AICoProducer* coProducer;
    juce::ListBox chatView;
    juce::TextEditor inputField;
    juce::TextButton sendButton;
    juce::OwnedArray<juce::TextButton> quickPromptButtons;
    std::vector<std::unique_ptr<ChatBubbleComponent>> chatBubbles;

    void sendMessage()
    {
        auto text = inputField.getText().toStdString();
        if (text.empty()) return;

        inputField.clear();

        coProducer->sendMessage(text, [this](const ChatMessage& response)
        {
            juce::MessageManager::callAsync([this]()
            {
                refreshChat();
            });
        });

        refreshChat();
    }

    void refreshChat()
    {
        chatBubbles.clear();

        for (const auto& msg : coProducer->getHistory())
        {
            chatBubbles.push_back(std::make_unique<ChatBubbleComponent>(msg));
        }

        chatView.updateContent();
        chatView.scrollToEnsureRowIsOnscreen(static_cast<int>(chatBubbles.size()) - 1);
    }
};

//==============================================================================
// Floating Assistant Widget
//==============================================================================

class AssistantWidget : public juce::Component,
                        public juce::Timer
{
public:
    AssistantWidget(AICoProducer* producer) : coProducer(producer)
    {
        setSize(350, 500);

        addAndMakeVisible(chatPanel);

        addAndMakeVisible(collapseButton);
        collapseButton.setButtonText("-");
        collapseButton.onClick = [this]() { toggleCollapse(); };

        startTimerHz(1);  // For status updates
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff1a1a2e));
        g.setColour(juce::Colours::grey);
        g.drawRect(getLocalBounds());

        // Header
        auto header = getLocalBounds().removeFromTop(30);
        g.setColour(juce::Colour(0xff2a2a3e));
        g.fillRect(header);

        g.setColour(juce::Colours::white);
        g.setFont(14.0f);
        g.drawText("AI Co-Producer", header.reduced(10, 0), juce::Justification::centredLeft);

        // Status indicator
        g.setColour(isConnected ? juce::Colours::green : juce::Colours::red);
        g.fillEllipse(header.removeFromRight(30).reduced(8).toFloat());
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        auto header = bounds.removeFromTop(30);
        collapseButton.setBounds(header.removeFromRight(30).reduced(5));

        if (!isCollapsed)
        {
            chatPanel = std::make_unique<CoProducerChatPanel>(coProducer);
            addAndMakeVisible(chatPanel.get());
            chatPanel->setBounds(bounds);
        }
    }

    void timerCallback() override
    {
        // Could check connection status, update context, etc.
        repaint();
    }

private:
    AICoProducer* coProducer;
    std::unique_ptr<CoProducerChatPanel> chatPanel;
    juce::TextButton collapseButton;

    bool isCollapsed = false;
    bool isConnected = true;

    void toggleCollapse()
    {
        isCollapsed = !isCollapsed;

        if (isCollapsed)
        {
            setSize(getWidth(), 30);
            chatPanel.reset();
        }
        else
        {
            setSize(getWidth(), 500);
            chatPanel = std::make_unique<CoProducerChatPanel>(coProducer);
            addAndMakeVisible(chatPanel.get());
        }

        resized();
    }
};

} // namespace AI
} // namespace Echoelmusic

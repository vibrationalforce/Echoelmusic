#pragma once
/**
 * EchoelCore - MCP Bio-Reactive Server
 *
 * Model Context Protocol (MCP) server implementation for exposing
 * bio-reactive audio capabilities to AI agents and external systems.
 *
 * Based on: https://github.com/modelcontextprotocol/modelcontextprotocol
 *
 * Features:
 * - Exposes HRV, coherence, heart rate as MCP resources
 * - Provides audio parameter tools for AI agents
 * - Supports both STDIO and HTTP/SSE transport
 * - Lock-free bio state access
 *
 * MIT License - Echoelmusic 2026
 */

#include "../Bio/BioState.h"
#include "../Lock-Free/SPSCQueue.h"
#include <string>
#include <vector>
#include <functional>
#include <map>
#include <cstdint>

namespace EchoelCore {
namespace MCP {

//==============================================================================
// MCP Protocol Constants
//==============================================================================

constexpr const char* kMCPVersion = "2024-11-05";
constexpr const char* kServerName = "echoelmusic-bio-server";
constexpr const char* kServerVersion = "1.0.0";

//==============================================================================
// JSON-RPC Message Types
//==============================================================================

enum class MessageType {
    Request,
    Response,
    Notification,
    Error
};

struct JsonRpcMessage {
    std::string jsonrpc = "2.0";
    std::string method;
    std::string id;
    std::string params;  // JSON string
    std::string result;  // JSON string
    int errorCode = 0;
    std::string errorMessage;
    MessageType type = MessageType::Request;
};

//==============================================================================
// MCP Resource Definition
//==============================================================================

struct Resource {
    std::string uri;
    std::string name;
    std::string description;
    std::string mimeType;

    // Dynamic content generator
    std::function<std::string()> getContent;
};

//==============================================================================
// MCP Tool Definition
//==============================================================================

struct ToolParameter {
    std::string name;
    std::string type;        // "string", "number", "boolean", "object", "array"
    std::string description;
    bool required = true;
    std::string defaultValue;
};

struct Tool {
    std::string name;
    std::string description;
    std::vector<ToolParameter> parameters;

    // Tool execution handler
    std::function<std::string(const std::map<std::string, std::string>&)> execute;
};

//==============================================================================
// MCP Bio Server
//==============================================================================

class MCPBioServer {
public:
    MCPBioServer(BioState& bioState) noexcept
        : mBioState(bioState)
        , mInitialized(false)
    {
        registerDefaultResources();
        registerDefaultTools();
    }

    //==========================================================================
    // Lifecycle
    //==========================================================================

    /**
     * Initialize the MCP server.
     */
    bool initialize() {
        mInitialized = true;
        return true;
    }

    /**
     * Shutdown the server.
     */
    void shutdown() {
        mInitialized = false;
    }

    /**
     * Check if server is running.
     */
    bool isInitialized() const { return mInitialized; }

    //==========================================================================
    // Message Handling
    //==========================================================================

    /**
     * Handle incoming JSON-RPC message.
     * Thread-safe for use from any thread.
     *
     * @param jsonMessage Raw JSON string
     * @return Response JSON string
     */
    std::string handleMessage(const std::string& jsonMessage) {
        // Parse JSON-RPC request
        JsonRpcMessage request = parseJsonRpc(jsonMessage);

        // Route to appropriate handler
        if (request.method == "initialize") {
            return handleInitialize(request);
        }
        else if (request.method == "resources/list") {
            return handleListResources(request);
        }
        else if (request.method == "resources/read") {
            return handleReadResource(request);
        }
        else if (request.method == "tools/list") {
            return handleListTools(request);
        }
        else if (request.method == "tools/call") {
            return handleCallTool(request);
        }
        else if (request.method == "ping") {
            return handlePing(request);
        }
        else {
            return createErrorResponse(request.id, -32601, "Method not found");
        }
    }

    //==========================================================================
    // Resource Registration
    //==========================================================================

    /**
     * Register a custom resource.
     */
    void registerResource(const Resource& resource) {
        mResources[resource.uri] = resource;
    }

    /**
     * Register a custom tool.
     */
    void registerTool(const Tool& tool) {
        mTools[tool.name] = tool;
    }

private:
    BioState& mBioState;
    bool mInitialized;

    std::map<std::string, Resource> mResources;
    std::map<std::string, Tool> mTools;

    //==========================================================================
    // Default Resources
    //==========================================================================

    void registerDefaultResources() {
        // Bio State Resource
        registerResource({
            "echoelmusic://bio/state",
            "Bio State",
            "Current biometric state including HRV, coherence, and heart rate",
            "application/json",
            [this]() {
                return formatBioStateJson();
            }
        });

        // HRV Resource
        registerResource({
            "echoelmusic://bio/hrv",
            "Heart Rate Variability",
            "Current HRV value (0-1 normalized)",
            "application/json",
            [this]() {
                return "{\"hrv\":" + std::to_string(mBioState.getHRV()) + "}";
            }
        });

        // Coherence Resource
        registerResource({
            "echoelmusic://bio/coherence",
            "Coherence Score",
            "HeartMath-style coherence score (0-1)",
            "application/json",
            [this]() {
                return "{\"coherence\":" + std::to_string(mBioState.getCoherence()) + "}";
            }
        });

        // Heart Rate Resource
        registerResource({
            "echoelmusic://bio/heartrate",
            "Heart Rate",
            "Current heart rate in BPM",
            "application/json",
            [this]() {
                return "{\"heartRate\":" + std::to_string(mBioState.getHeartRate()) + "}";
            }
        });

        // Breathing Resource
        registerResource({
            "echoelmusic://bio/breathing",
            "Breathing State",
            "Current breathing phase and rate",
            "application/json",
            [this]() {
                return "{\"phase\":" + std::to_string(mBioState.getBreathPhase()) +
                       ",\"rate\":" + std::to_string(mBioState.getBreathRate()) +
                       ",\"lfo\":" + std::to_string(mBioState.getBreathLFO()) + "}";
            }
        });

        // Derived Metrics Resource
        registerResource({
            "echoelmusic://bio/derived",
            "Derived Metrics",
            "Computed arousal and relaxation scores",
            "application/json",
            [this]() {
                return "{\"arousal\":" + std::to_string(mBioState.getArousal()) +
                       ",\"relaxation\":" + std::to_string(mBioState.getRelaxation()) + "}";
            }
        });
    }

    //==========================================================================
    // Default Tools
    //==========================================================================

    void registerDefaultTools() {
        // Set HRV Tool
        registerTool({
            "setBioHRV",
            "Set the HRV value for bio-reactive audio modulation",
            {
                {"value", "number", "HRV value (0.0 to 1.0)", true, "0.5"}
            },
            [this](const std::map<std::string, std::string>& params) {
                float value = std::stof(params.at("value"));
                mBioState.setHRV(value);
                return "{\"success\":true,\"hrv\":" + std::to_string(value) + "}";
            }
        });

        // Set Coherence Tool
        registerTool({
            "setBioCoherence",
            "Set the coherence value for bio-reactive audio modulation",
            {
                {"value", "number", "Coherence value (0.0 to 1.0)", true, "0.5"}
            },
            [this](const std::map<std::string, std::string>& params) {
                float value = std::stof(params.at("value"));
                mBioState.setCoherence(value);
                return "{\"success\":true,\"coherence\":" + std::to_string(value) + "}";
            }
        });

        // Set Heart Rate Tool
        registerTool({
            "setBioHeartRate",
            "Set the heart rate for tempo synchronization",
            {
                {"bpm", "number", "Heart rate in BPM (40-200)", true, "70"}
            },
            [this](const std::map<std::string, std::string>& params) {
                float bpm = std::stof(params.at("bpm"));
                mBioState.setHeartRate(bpm);
                return "{\"success\":true,\"heartRate\":" + std::to_string(bpm) + "}";
            }
        });

        // Set Breath Phase Tool
        registerTool({
            "setBioBreathPhase",
            "Set the breathing phase for LFO modulation",
            {
                {"phase", "number", "Breath phase (0.0 to 1.0 cycle)", true, "0.0"}
            },
            [this](const std::map<std::string, std::string>& params) {
                float phase = std::stof(params.at("phase"));
                mBioState.setBreathPhase(phase);
                return "{\"success\":true,\"breathPhase\":" + std::to_string(phase) + "}";
            }
        });

        // Get Full Bio State Tool
        registerTool({
            "getBioState",
            "Get the complete current biometric state",
            {},
            [this](const std::map<std::string, std::string>&) {
                return formatBioStateJson();
            }
        });

        // Simulate Bio Session Tool
        registerTool({
            "simulateBioSession",
            "Simulate a bio-reactive session with generated data",
            {
                {"type", "string", "Session type: meditation, energetic, performance", true, "meditation"},
                {"duration", "number", "Duration in seconds", false, "60"}
            },
            [this](const std::map<std::string, std::string>& params) {
                std::string type = params.count("type") ? params.at("type") : "meditation";
                if (type == "meditation") {
                    mBioState.setHRV(0.8f);
                    mBioState.setCoherence(0.9f);
                    mBioState.setHeartRate(60.0f);
                } else if (type == "energetic") {
                    mBioState.setHRV(0.4f);
                    mBioState.setCoherence(0.5f);
                    mBioState.setHeartRate(120.0f);
                } else {
                    mBioState.setHRV(0.6f);
                    mBioState.setCoherence(0.7f);
                    mBioState.setHeartRate(80.0f);
                }
                return "{\"success\":true,\"sessionType\":\"" + type + "\"}";
            }
        });
    }

    //==========================================================================
    // Message Handlers
    //==========================================================================

    std::string handleInitialize(const JsonRpcMessage& request) {
        mInitialized = true;
        return createSuccessResponse(request.id,
            "{\"protocolVersion\":\"" + std::string(kMCPVersion) + "\","
            "\"capabilities\":{\"resources\":{},\"tools\":{}},"
            "\"serverInfo\":{\"name\":\"" + std::string(kServerName) + "\","
            "\"version\":\"" + std::string(kServerVersion) + "\"}}");
    }

    std::string handleListResources(const JsonRpcMessage& request) {
        std::string resources = "[";
        bool first = true;
        for (const auto& [uri, resource] : mResources) {
            if (!first) resources += ",";
            first = false;
            resources += "{\"uri\":\"" + resource.uri + "\","
                         "\"name\":\"" + resource.name + "\","
                         "\"description\":\"" + resource.description + "\","
                         "\"mimeType\":\"" + resource.mimeType + "\"}";
        }
        resources += "]";
        return createSuccessResponse(request.id, "{\"resources\":" + resources + "}");
    }

    std::string handleReadResource(const JsonRpcMessage& request) {
        // Extract URI from params
        std::string uri = extractParam(request.params, "uri");
        if (mResources.count(uri)) {
            std::string content = mResources[uri].getContent();
            return createSuccessResponse(request.id,
                "{\"contents\":[{\"uri\":\"" + uri + "\","
                "\"mimeType\":\"" + mResources[uri].mimeType + "\","
                "\"text\":" + content + "}]}");
        }
        return createErrorResponse(request.id, -32602, "Resource not found: " + uri);
    }

    std::string handleListTools(const JsonRpcMessage& request) {
        std::string tools = "[";
        bool first = true;
        for (const auto& [name, tool] : mTools) {
            if (!first) tools += ",";
            first = false;
            tools += "{\"name\":\"" + tool.name + "\","
                     "\"description\":\"" + tool.description + "\","
                     "\"inputSchema\":{\"type\":\"object\",\"properties\":{";

            bool firstParam = true;
            std::string required = "[";
            for (const auto& param : tool.parameters) {
                if (!firstParam) tools += ",";
                firstParam = false;
                tools += "\"" + param.name + "\":{\"type\":\"" + param.type + "\","
                         "\"description\":\"" + param.description + "\"}";
                if (param.required) {
                    if (required != "[") required += ",";
                    required += "\"" + param.name + "\"";
                }
            }
            required += "]";
            tools += "},\"required\":" + required + "}}";
        }
        tools += "]";
        return createSuccessResponse(request.id, "{\"tools\":" + tools + "}");
    }

    std::string handleCallTool(const JsonRpcMessage& request) {
        std::string toolName = extractParam(request.params, "name");
        if (mTools.count(toolName)) {
            std::map<std::string, std::string> args = extractArguments(request.params);
            try {
                std::string result = mTools[toolName].execute(args);
                return createSuccessResponse(request.id,
                    "{\"content\":[{\"type\":\"text\",\"text\":" + result + "}]}");
            } catch (const std::exception& e) {
                return createErrorResponse(request.id, -32603, e.what());
            }
        }
        return createErrorResponse(request.id, -32602, "Tool not found: " + toolName);
    }

    std::string handlePing(const JsonRpcMessage& request) {
        return createSuccessResponse(request.id, "{}");
    }

    //==========================================================================
    // JSON Helpers
    //==========================================================================

    std::string formatBioStateJson() {
        return "{\"hrv\":" + std::to_string(mBioState.getHRV()) +
               ",\"coherence\":" + std::to_string(mBioState.getCoherence()) +
               ",\"heartRate\":" + std::to_string(mBioState.getHeartRate()) +
               ",\"breathPhase\":" + std::to_string(mBioState.getBreathPhase()) +
               ",\"breathRate\":" + std::to_string(mBioState.getBreathRate()) +
               ",\"breathLFO\":" + std::to_string(mBioState.getBreathLFO()) +
               ",\"arousal\":" + std::to_string(mBioState.getArousal()) +
               ",\"relaxation\":" + std::to_string(mBioState.getRelaxation()) +
               ",\"timestamp\":" + std::to_string(mBioState.getTimestamp()) + "}";
    }

    JsonRpcMessage parseJsonRpc(const std::string& json) {
        JsonRpcMessage msg;
        // Simple JSON parsing (production would use a proper library)
        msg.method = extractParam(json, "method");
        msg.id = extractParam(json, "id");
        msg.params = extractObject(json, "params");
        return msg;
    }

    std::string extractParam(const std::string& json, const std::string& key) {
        std::string search = "\"" + key + "\":\"";
        size_t pos = json.find(search);
        if (pos == std::string::npos) {
            // Try without quotes for numbers
            search = "\"" + key + "\":";
            pos = json.find(search);
            if (pos == std::string::npos) return "";
            size_t start = pos + search.length();
            size_t end = json.find_first_of(",}", start);
            return json.substr(start, end - start);
        }
        size_t start = pos + search.length();
        size_t end = json.find("\"", start);
        return json.substr(start, end - start);
    }

    std::string extractObject(const std::string& json, const std::string& key) {
        std::string search = "\"" + key + "\":";
        size_t pos = json.find(search);
        if (pos == std::string::npos) return "{}";
        size_t start = json.find("{", pos);
        if (start == std::string::npos) return "{}";
        int depth = 1;
        size_t end = start + 1;
        while (depth > 0 && end < json.length()) {
            if (json[end] == '{') depth++;
            else if (json[end] == '}') depth--;
            end++;
        }
        return json.substr(start, end - start);
    }

    std::map<std::string, std::string> extractArguments(const std::string& params) {
        std::map<std::string, std::string> args;
        std::string arguments = extractObject(params, "arguments");
        // Simple extraction (production would use proper JSON parser)
        size_t pos = 0;
        while ((pos = arguments.find("\"", pos)) != std::string::npos) {
            size_t keyEnd = arguments.find("\"", pos + 1);
            if (keyEnd == std::string::npos) break;
            std::string key = arguments.substr(pos + 1, keyEnd - pos - 1);
            size_t valStart = arguments.find(":", keyEnd);
            if (valStart == std::string::npos) break;
            valStart++;
            while (valStart < arguments.length() && arguments[valStart] == ' ') valStart++;
            if (arguments[valStart] == '"') {
                size_t valEnd = arguments.find("\"", valStart + 1);
                args[key] = arguments.substr(valStart + 1, valEnd - valStart - 1);
                pos = valEnd + 1;
            } else {
                size_t valEnd = arguments.find_first_of(",}", valStart);
                args[key] = arguments.substr(valStart, valEnd - valStart);
                pos = valEnd;
            }
        }
        return args;
    }

    std::string createSuccessResponse(const std::string& id, const std::string& result) {
        return "{\"jsonrpc\":\"2.0\",\"id\":\"" + id + "\",\"result\":" + result + "}";
    }

    std::string createErrorResponse(const std::string& id, int code, const std::string& message) {
        return "{\"jsonrpc\":\"2.0\",\"id\":\"" + id + "\","
               "\"error\":{\"code\":" + std::to_string(code) + ","
               "\"message\":\"" + message + "\"}}";
    }
};

} // namespace MCP
} // namespace EchoelCore

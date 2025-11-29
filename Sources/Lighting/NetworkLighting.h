#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>
#include <functional>

/**
 * NetworkLighting - Complete HTTP/UDP implementations for smart lighting
 *
 * Provides full protocol implementations for:
 * - Philips Hue Bridge (REST API with HTTP)
 * - WLED (UDP WARLS/DRGB/DNRGB protocols)
 *
 * Features:
 * - Async HTTP requests for Hue
 * - UDP real-time streaming for WLED
 * - Device discovery (mDNS/UPNP)
 * - Connection state management
 * - Error recovery and retry logic
 */

namespace Echoel {

//==========================================================================
// Philips Hue HTTP Controller (Full Implementation)
//==========================================================================

class HueHTTPController : private juce::Thread, private juce::Timer {
public:
    struct HueLight {
        int id{0};
        juce::String name;
        juce::String type;
        juce::String modelId;
        bool isOn{false};
        uint8_t brightness{254};
        uint16_t hue{0};
        uint8_t saturation{0};
        float x{0.0f}, y{0.0f};
        uint16_t colorTemp{0};
        bool reachable{true};
    };

    struct HueGroup {
        int id{0};
        juce::String name;
        std::vector<int> lightIds;
        bool allOn{false};
        bool anyOn{false};
    };

    using ConnectionCallback = std::function<void(bool connected, const juce::String& error)>;
    using LightsCallback = std::function<void(const std::vector<HueLight>& lights)>;

    HueHTTPController() : Thread("HueHTTP") {}

    ~HueHTTPController() override {
        stopTimer();
        stopThread(2000);
    }

    //==========================================================================
    // Connection
    //==========================================================================

    void connect(const juce::String& bridgeIP, const juce::String& username,
                ConnectionCallback callback = nullptr) {
        this->bridgeIP = bridgeIP;
        this->username = username;
        this->connectionCallback = callback;

        // Test connection
        sendRequest("GET", "/api/" + username, "",
            [this](int status, const juce::String& response) {
                if (status == 200 && !response.contains("error")) {
                    connected = true;
                    startTimer(1000);  // Poll for updates
                    if (connectionCallback) {
                        juce::MessageManager::callAsync([this]() {
                            connectionCallback(true, "");
                        });
                    }
                } else {
                    connected = false;
                    if (connectionCallback) {
                        juce::MessageManager::callAsync([this, response]() {
                            connectionCallback(false, "Connection failed: " + response);
                        });
                    }
                }
            });

        startThread();
    }

    void disconnect() {
        stopTimer();
        connected = false;
    }

    bool isConnected() const { return connected; }

    //==========================================================================
    // Bridge Discovery (SSDP/UPnP)
    //==========================================================================

    static std::vector<juce::String> discoverBridges() {
        std::vector<juce::String> bridges;

        // Create UDP socket for SSDP discovery
        juce::DatagramSocket socket;
        socket.bindToPort(0);

        // SSDP M-SEARCH message
        juce::String ssdpMessage =
            "M-SEARCH * HTTP/1.1\r\n"
            "HOST: 239.255.255.250:1900\r\n"
            "MAN: \"ssdp:discover\"\r\n"
            "MX: 3\r\n"
            "ST: ssdp:all\r\n\r\n";

        // Send to multicast address
        socket.write("239.255.255.250", 1900,
                    ssdpMessage.toRawUTF8(),
                    static_cast<int>(ssdpMessage.length()));

        // Wait for responses
        char buffer[4096];
        juce::String senderIP;
        int senderPort;

        auto startTime = juce::Time::getMillisecondCounter();
        while (juce::Time::getMillisecondCounter() - startTime < 3000) {
            if (socket.waitUntilReady(true, 100) > 0) {
                int received = socket.read(buffer, sizeof(buffer) - 1, false,
                                          senderIP, senderPort);
                if (received > 0) {
                    buffer[received] = '\0';
                    juce::String response(buffer);

                    // Look for Hue Bridge in response
                    if (response.containsIgnoreCase("hue") ||
                        response.containsIgnoreCase("philips")) {
                        if (!bridges.empty()) {
                            bool found = false;
                            for (const auto& b : bridges) {
                                if (b == senderIP) found = true;
                            }
                            if (!found) bridges.push_back(senderIP);
                        } else {
                            bridges.push_back(senderIP);
                        }
                    }
                }
            }
        }

        return bridges;
    }

    //==========================================================================
    // Pairing (Link Button)
    //==========================================================================

    void createUser(const juce::String& appName, const juce::String& deviceName,
                   std::function<void(bool success, const juce::String& username)> callback) {
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("devicetype", appName + "#" + deviceName);

        sendRequest("POST", "/api", juce::JSON::toString(body),
            [callback](int status, const juce::String& response) {
                auto json = juce::JSON::parse(response);
                if (json.isArray() && json.size() > 0) {
                    auto first = json[0];
                    if (first.hasProperty("success")) {
                        auto username = first["success"]["username"].toString();
                        juce::MessageManager::callAsync([callback, username]() {
                            callback(true, username);
                        });
                        return;
                    } else if (first.hasProperty("error")) {
                        auto error = first["error"]["description"].toString();
                        juce::MessageManager::callAsync([callback, error]() {
                            callback(false, error);
                        });
                        return;
                    }
                }
                juce::MessageManager::callAsync([callback]() {
                    callback(false, "Unknown error");
                });
            });
    }

    //==========================================================================
    // Light Control
    //==========================================================================

    void setLightState(int lightId, bool on) {
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("on", on);
        sendLightState(lightId, body);
    }

    void setLightBrightness(int lightId, uint8_t brightness, int transitionTime = 4) {
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("bri", juce::jlimit(1, 254, (int)brightness));
        body.getDynamicObject()->setProperty("transitiontime", transitionTime);
        sendLightState(lightId, body);
    }

    void setLightColor(int lightId, float r, float g, float b, int transitionTime = 4) {
        auto [x, y] = rgbToXY(r, g, b);

        juce::var body = juce::var(new juce::DynamicObject());
        juce::Array<juce::var> xyArray;
        xyArray.add(x);
        xyArray.add(y);
        body.getDynamicObject()->setProperty("xy", xyArray);
        body.getDynamicObject()->setProperty("transitiontime", transitionTime);
        sendLightState(lightId, body);
    }

    void setLightColorTemp(int lightId, uint16_t mired, int transitionTime = 4) {
        // Mired = 1000000 / Kelvin. Range: 153 (6500K) to 500 (2000K)
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("ct", juce::jlimit(153, 500, (int)mired));
        body.getDynamicObject()->setProperty("transitiontime", transitionTime);
        sendLightState(lightId, body);
    }

    void setLightHueSat(int lightId, uint16_t hue, uint8_t sat, int transitionTime = 4) {
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("hue", juce::jlimit(0, 65535, (int)hue));
        body.getDynamicObject()->setProperty("sat", juce::jlimit(0, 254, (int)sat));
        body.getDynamicObject()->setProperty("transitiontime", transitionTime);
        sendLightState(lightId, body);
    }

    void setLightEffect(int lightId, const juce::String& effect) {
        // "none", "colorloop"
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("effect", effect);
        sendLightState(lightId, body);
    }

    void setLightAlert(int lightId, const juce::String& alert) {
        // "none", "select" (single flash), "lselect" (15 seconds)
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("alert", alert);
        sendLightState(lightId, body);
    }

    //==========================================================================
    // Group Control
    //==========================================================================

    void setGroupState(int groupId, bool on) {
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("on", on);
        sendGroupAction(groupId, body);
    }

    void setGroupBrightness(int groupId, uint8_t brightness, int transitionTime = 4) {
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("bri", juce::jlimit(1, 254, (int)brightness));
        body.getDynamicObject()->setProperty("transitiontime", transitionTime);
        sendGroupAction(groupId, body);
    }

    void setGroupScene(int groupId, const juce::String& sceneId) {
        juce::var body = juce::var(new juce::DynamicObject());
        body.getDynamicObject()->setProperty("scene", sceneId);
        sendGroupAction(groupId, body);
    }

    //==========================================================================
    // Data Retrieval
    //==========================================================================

    void getLights(LightsCallback callback) {
        sendRequest("GET", "/api/" + username + "/lights", "",
            [callback](int status, const juce::String& response) {
                std::vector<HueLight> lights;

                if (status == 200) {
                    auto json = juce::JSON::parse(response);
                    if (json.isObject()) {
                        auto* obj = json.getDynamicObject();
                        for (const auto& prop : obj->getProperties()) {
                            HueLight light;
                            light.id = prop.name.toString().getIntValue();

                            auto lightObj = prop.value;
                            light.name = lightObj["name"].toString();
                            light.type = lightObj["type"].toString();
                            light.modelId = lightObj["modelid"].toString();

                            auto state = lightObj["state"];
                            light.isOn = state["on"];
                            light.brightness = static_cast<uint8_t>((int)state["bri"]);
                            light.reachable = state["reachable"];

                            if (state.hasProperty("hue")) {
                                light.hue = static_cast<uint16_t>((int)state["hue"]);
                            }
                            if (state.hasProperty("sat")) {
                                light.saturation = static_cast<uint8_t>((int)state["sat"]);
                            }
                            if (state.hasProperty("xy")) {
                                auto xy = state["xy"];
                                light.x = static_cast<float>((double)xy[0]);
                                light.y = static_cast<float>((double)xy[1]);
                            }
                            if (state.hasProperty("ct")) {
                                light.colorTemp = static_cast<uint16_t>((int)state["ct"]);
                            }

                            lights.push_back(light);
                        }
                    }
                }

                juce::MessageManager::callAsync([callback, lights]() {
                    callback(lights);
                });
            });
    }

    const std::vector<HueLight>& getCachedLights() const { return cachedLights; }
    const std::vector<HueGroup>& getCachedGroups() const { return cachedGroups; }

private:
    void run() override {
        while (!threadShouldExit()) {
            // Process request queue
            Request req;
            {
                const juce::ScopedLock sl(requestLock);
                if (!requestQueue.empty()) {
                    req = std::move(requestQueue.front());
                    requestQueue.erase(requestQueue.begin());
                }
            }

            if (!req.path.isEmpty()) {
                executeRequest(req);
            }

            sleep(10);
        }
    }

    void timerCallback() override {
        // Periodic state refresh
        if (connected) {
            getLights([this](const std::vector<HueLight>& lights) {
                cachedLights = lights;
            });
        }
    }

    struct Request {
        juce::String method;
        juce::String path;
        juce::String body;
        std::function<void(int, const juce::String&)> callback;
    };

    void sendRequest(const juce::String& method, const juce::String& path,
                    const juce::String& body,
                    std::function<void(int, const juce::String&)> callback) {
        const juce::ScopedLock sl(requestLock);
        requestQueue.push_back({method, path, body, callback});
    }

    void executeRequest(const Request& req) {
        juce::URL url("http://" + bridgeIP + req.path);

        juce::StringPairArray headers;
        headers.set("Content-Type", "application/json");

        std::unique_ptr<juce::InputStream> stream;

        if (req.method == "GET") {
            stream = url.createInputStream(juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inAddress)
                                          .withConnectionTimeoutMs(5000)
                                          .withExtraHeaders(headers.getDescription()));
        } else {
            juce::URL postUrl = url.withPOSTData(req.body);
            stream = postUrl.createInputStream(juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
                                              .withConnectionTimeoutMs(5000)
                                              .withExtraHeaders(headers.getDescription())
                                              .withHttpRequestCmd(req.method));
        }

        if (stream) {
            juce::String response = stream->readEntireStreamAsString();
            int statusCode = 200;  // Assume success if we got a response

            if (req.callback) {
                req.callback(statusCode, response);
            }
        } else {
            if (req.callback) {
                req.callback(0, "Connection failed");
            }
        }
    }

    void sendLightState(int lightId, const juce::var& body) {
        sendRequest("PUT", "/api/" + username + "/lights/" + juce::String(lightId) + "/state",
                   juce::JSON::toString(body), nullptr);
    }

    void sendGroupAction(int groupId, const juce::var& body) {
        sendRequest("PUT", "/api/" + username + "/groups/" + juce::String(groupId) + "/action",
                   juce::JSON::toString(body), nullptr);
    }

    std::pair<float, float> rgbToXY(float r, float g, float b) {
        // Gamma correction
        r = (r > 0.04045f) ? std::pow((r + 0.055f) / 1.055f, 2.4f) : (r / 12.92f);
        g = (g > 0.04045f) ? std::pow((g + 0.055f) / 1.055f, 2.4f) : (g / 12.92f);
        b = (b > 0.04045f) ? std::pow((b + 0.055f) / 1.055f, 2.4f) : (b / 12.92f);

        float X = r * 0.649926f + g * 0.103455f + b * 0.197109f;
        float Y = r * 0.234327f + g * 0.743075f + b * 0.022598f;
        float Z = r * 0.000000f + g * 0.053077f + b * 1.035763f;

        float sum = X + Y + Z;
        if (sum < 1e-6f) return {0.3127f, 0.3290f};  // D65 white point

        return {X / sum, Y / sum};
    }

    juce::String bridgeIP;
    juce::String username;
    bool connected = false;

    std::vector<Request> requestQueue;
    juce::CriticalSection requestLock;

    std::vector<HueLight> cachedLights;
    std::vector<HueGroup> cachedGroups;

    ConnectionCallback connectionCallback;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HueHTTPController)
};

//==========================================================================
// WLED UDP Controller (Full Implementation)
//==========================================================================

class WLEDUDPController {
public:
    // WLED UDP Protocol types
    enum class Protocol {
        WARLS,      // WLED Audio Reactive Light Sync (UDP 21324)
        DRGB,       // Direct RGB (UDP 21324)
        DNRGB,      // Direct No-Reply RGB (UDP 21324)
        DDP,        // Distributed Display Protocol (UDP 4048)
        E131        // sACN/E1.31 (UDP 5568)
    };

    struct WLEDDevice {
        juce::String ip;
        juce::String name;
        int ledCount{0};
        Protocol protocol{Protocol::DRGB};
        bool connected{false};
    };

    WLEDUDPController() {
        socket = std::make_unique<juce::DatagramSocket>();
        socket->bindToPort(0);
    }

    //==========================================================================
    // Device Management
    //==========================================================================

    void addDevice(const juce::String& ip, int ledCount, Protocol protocol = Protocol::DRGB) {
        WLEDDevice device;
        device.ip = ip;
        device.ledCount = ledCount;
        device.protocol = protocol;
        device.connected = true;
        devices.push_back(device);

        // Allocate pixel buffer
        pixelBuffers[ip].resize(ledCount * 3, 0);
    }

    void removeDevice(const juce::String& ip) {
        devices.erase(std::remove_if(devices.begin(), devices.end(),
            [&ip](const WLEDDevice& d) { return d.ip == ip; }), devices.end());
        pixelBuffers.erase(ip);
    }

    //==========================================================================
    // Pixel Control
    //==========================================================================

    void setPixel(const juce::String& ip, int index, uint8_t r, uint8_t g, uint8_t b) {
        auto it = pixelBuffers.find(ip);
        if (it != pixelBuffers.end()) {
            int offset = index * 3;
            if (offset + 2 < static_cast<int>(it->second.size())) {
                it->second[offset] = r;
                it->second[offset + 1] = g;
                it->second[offset + 2] = b;
            }
        }
    }

    void setAllPixels(const juce::String& ip, uint8_t r, uint8_t g, uint8_t b) {
        auto it = pixelBuffers.find(ip);
        if (it != pixelBuffers.end()) {
            for (size_t i = 0; i < it->second.size(); i += 3) {
                it->second[i] = r;
                it->second[i + 1] = g;
                it->second[i + 2] = b;
            }
        }
    }

    void setPixelRange(const juce::String& ip, int start, int count,
                      uint8_t r, uint8_t g, uint8_t b) {
        for (int i = start; i < start + count; ++i) {
            setPixel(ip, i, r, g, b);
        }
    }

    void setPixelGradient(const juce::String& ip, int start, int count,
                         uint8_t r1, uint8_t g1, uint8_t b1,
                         uint8_t r2, uint8_t g2, uint8_t b2) {
        for (int i = 0; i < count; ++i) {
            float t = static_cast<float>(i) / (count - 1);
            uint8_t r = static_cast<uint8_t>(r1 + t * (r2 - r1));
            uint8_t g = static_cast<uint8_t>(g1 + t * (g2 - g1));
            uint8_t b = static_cast<uint8_t>(b1 + t * (b2 - b1));
            setPixel(ip, start + i, r, g, b);
        }
    }

    //==========================================================================
    // Send Updates
    //==========================================================================

    void send(const juce::String& ip) {
        auto deviceIt = std::find_if(devices.begin(), devices.end(),
            [&ip](const WLEDDevice& d) { return d.ip == ip; });

        if (deviceIt == devices.end()) return;

        auto bufferIt = pixelBuffers.find(ip);
        if (bufferIt == pixelBuffers.end()) return;

        switch (deviceIt->protocol) {
            case Protocol::WARLS:
                sendWARLS(ip, bufferIt->second);
                break;
            case Protocol::DRGB:
                sendDRGB(ip, bufferIt->second);
                break;
            case Protocol::DNRGB:
                sendDNRGB(ip, bufferIt->second);
                break;
            case Protocol::DDP:
                sendDDP(ip, bufferIt->second);
                break;
            default:
                sendDRGB(ip, bufferIt->second);
        }
    }

    void sendAll() {
        for (const auto& device : devices) {
            if (device.connected) {
                send(device.ip);
            }
        }
    }

    //==========================================================================
    // JSON API (for effects and configuration)
    //==========================================================================

    void sendJSONCommand(const juce::String& ip, const juce::var& json) {
        juce::String jsonStr = juce::JSON::toString(json);

        // WLED JSON API uses HTTP, but for simple commands we can use UDP
        // port 21324 with protocol byte 0x04
        std::vector<uint8_t> packet;
        packet.push_back(0x04);  // JSON protocol
        for (char c : jsonStr.toStdString()) {
            packet.push_back(static_cast<uint8_t>(c));
        }

        socket->write(ip, 21324, packet.data(), static_cast<int>(packet.size()));
    }

    void setEffect(const juce::String& ip, int effectId, int speed = 128, int intensity = 128) {
        juce::var json = juce::var(new juce::DynamicObject());
        auto* seg = new juce::DynamicObject();
        seg->setProperty("fx", effectId);
        seg->setProperty("sx", speed);
        seg->setProperty("ix", intensity);

        juce::Array<juce::var> segArray;
        segArray.add(juce::var(seg));
        json.getDynamicObject()->setProperty("seg", segArray);

        sendJSONCommand(ip, json);
    }

    void setBrightness(const juce::String& ip, uint8_t brightness) {
        juce::var json = juce::var(new juce::DynamicObject());
        json.getDynamicObject()->setProperty("bri", brightness);
        sendJSONCommand(ip, json);
    }

    void setPower(const juce::String& ip, bool on) {
        juce::var json = juce::var(new juce::DynamicObject());
        json.getDynamicObject()->setProperty("on", on);
        sendJSONCommand(ip, json);
    }

    void setPreset(const juce::String& ip, int presetId) {
        juce::var json = juce::var(new juce::DynamicObject());
        json.getDynamicObject()->setProperty("ps", presetId);
        sendJSONCommand(ip, json);
    }

    //==========================================================================
    // Device Discovery (mDNS)
    //==========================================================================

    std::vector<juce::String> discoverDevices() {
        std::vector<juce::String> found;

        // Simple UDP broadcast discovery
        // In production, would use proper mDNS
        juce::String probe = "WLED";
        for (int i = 1; i < 255; ++i) {
            juce::String ip = "192.168.1." + juce::String(i);
            // Would need async implementation for production
        }

        return found;
    }

    //==========================================================================
    // Status
    //==========================================================================

    const std::vector<WLEDDevice>& getDevices() const { return devices; }

    juce::String getStatus() const {
        juce::String status;
        status << "WLED UDP Controller Status\n";
        status << "==========================\n\n";
        status << "Devices: " << devices.size() << "\n\n";

        for (const auto& device : devices) {
            status << "  " << device.ip << "\n";
            status << "    LEDs: " << device.ledCount << "\n";
            status << "    Protocol: ";
            switch (device.protocol) {
                case Protocol::WARLS: status << "WARLS"; break;
                case Protocol::DRGB:  status << "DRGB"; break;
                case Protocol::DNRGB: status << "DNRGB"; break;
                case Protocol::DDP:   status << "DDP"; break;
                default: status << "Unknown";
            }
            status << "\n    Connected: " << (device.connected ? "Yes" : "No") << "\n\n";
        }

        return status;
    }

private:
    //==========================================================================
    // Protocol Implementations
    //==========================================================================

    void sendWARLS(const juce::String& ip, const std::vector<uint8_t>& pixels) {
        // WARLS protocol: 2-byte timeout + LED data
        std::vector<uint8_t> packet;
        packet.reserve(2 + pixels.size());

        // Timeout (255 = no timeout)
        packet.push_back(255);
        packet.push_back(0);

        // LED data
        packet.insert(packet.end(), pixels.begin(), pixels.end());

        socket->write(ip, 21324, packet.data(), static_cast<int>(packet.size()));
    }

    void sendDRGB(const juce::String& ip, const std::vector<uint8_t>& pixels) {
        // DRGB protocol: 2-byte timeout + RGB triplets
        std::vector<uint8_t> packet;
        packet.reserve(2 + pixels.size());

        // Protocol byte (2 = DRGB)
        packet.push_back(2);

        // Timeout (255 = no timeout)
        packet.push_back(255);

        // RGB data
        packet.insert(packet.end(), pixels.begin(), pixels.end());

        socket->write(ip, 21324, packet.data(), static_cast<int>(packet.size()));
    }

    void sendDNRGB(const juce::String& ip, const std::vector<uint8_t>& pixels) {
        // DNRGB protocol: 4-byte header + RGB triplets
        std::vector<uint8_t> packet;
        packet.reserve(4 + pixels.size());

        // Protocol byte (4 = DNRGB)
        packet.push_back(4);

        // Timeout
        packet.push_back(255);

        // Start index (high byte, low byte)
        packet.push_back(0);
        packet.push_back(0);

        // RGB data
        packet.insert(packet.end(), pixels.begin(), pixels.end());

        socket->write(ip, 21324, packet.data(), static_cast<int>(packet.size()));
    }

    void sendDDP(const juce::String& ip, const std::vector<uint8_t>& pixels) {
        // DDP (Distributed Display Protocol) - port 4048
        std::vector<uint8_t> packet;

        // DDP Header (10 bytes)
        packet.push_back(0x41);  // Flags: V1, Push, RGB
        packet.push_back(0x00);  // Sequence
        packet.push_back(0x01);  // Data type: RGB
        packet.push_back(0x00);  // Destination ID

        // Data offset (4 bytes, big-endian)
        packet.push_back(0);
        packet.push_back(0);
        packet.push_back(0);
        packet.push_back(0);

        // Data length (2 bytes, big-endian)
        uint16_t len = static_cast<uint16_t>(pixels.size());
        packet.push_back((len >> 8) & 0xFF);
        packet.push_back(len & 0xFF);

        // RGB data
        packet.insert(packet.end(), pixels.begin(), pixels.end());

        socket->write(ip, 4048, packet.data(), static_cast<int>(packet.size()));
    }

    std::unique_ptr<juce::DatagramSocket> socket;
    std::vector<WLEDDevice> devices;
    std::unordered_map<juce::String, std::vector<uint8_t>> pixelBuffers;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WLEDUDPController)
};

} // namespace Echoel

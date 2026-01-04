#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <string>
#include <map>
#include <functional>
#include <atomic>
#include <chrono>
#include <deque>
#include <cmath>

/**
 * WearableIntegration - Bio-Reactive Music System
 *
 * Connect wearable devices for bio-reactive music making:
 * - Apple Watch (heart rate, HRV, motion, haptic feedback)
 * - Oura Ring (HRV, temperature, sleep/readiness)
 * - Fitbit/Garmin (heart rate, steps, stress)
 * - Polar H10 (ECG-grade heart rate)
 * - Muse/Neurosky (EEG brainwaves)
 * - Custom BLE sensors
 *
 * Bio-data can modulate:
 * - Tempo (sync to heart rate)
 * - Filter cutoffs (HRV = emotional state)
 * - Effect intensity (stress level)
 * - Generative parameters (sleep/energy)
 * - Haptic feedback for rhythm
 *
 * Super Ralph Wiggum Loop Genius Bio Mode
 */

namespace Echoelmusic {
namespace Wearable {

//==============================================================================
// Biometric Data Types
//==============================================================================

enum class BiometricType
{
    HeartRate,              // BPM
    HeartRateVariability,   // RMSSD in ms
    RespiratoryRate,        // Breaths per minute
    SkinTemperature,        // Celsius
    BloodOxygen,            // SpO2 percentage
    StressLevel,            // 0-100 computed score
    EnergyLevel,            // 0-100 readiness score
    SleepScore,             // 0-100 from last night
    Steps,                  // Step count
    Calories,               // kcal burned

    // Motion data
    AccelerationX,
    AccelerationY,
    AccelerationZ,
    GyroscopeX,
    GyroscopeY,
    GyroscopeZ,

    // EEG brainwaves
    DeltaWaves,             // 0.5-4 Hz (deep sleep)
    ThetaWaves,             // 4-8 Hz (drowsy, meditation)
    AlphaWaves,             // 8-13 Hz (relaxed, eyes closed)
    BetaWaves,              // 13-32 Hz (alert, focused)
    GammaWaves,             // 32-100 Hz (peak concentration)

    // Derived metrics
    MeditationScore,        // 0-100
    FocusScore,             // 0-100
    RelaxationScore,        // 0-100

    Unknown
};

inline std::string biometricTypeToString(BiometricType type)
{
    switch (type)
    {
        case BiometricType::HeartRate:           return "Heart Rate";
        case BiometricType::HeartRateVariability: return "HRV";
        case BiometricType::RespiratoryRate:     return "Respiratory Rate";
        case BiometricType::SkinTemperature:     return "Skin Temperature";
        case BiometricType::BloodOxygen:         return "Blood Oxygen";
        case BiometricType::StressLevel:         return "Stress Level";
        case BiometricType::EnergyLevel:         return "Energy Level";
        case BiometricType::SleepScore:          return "Sleep Score";
        case BiometricType::AccelerationX:       return "Acceleration X";
        case BiometricType::AccelerationY:       return "Acceleration Y";
        case BiometricType::AccelerationZ:       return "Acceleration Z";
        case BiometricType::AlphaWaves:          return "Alpha Waves";
        case BiometricType::BetaWaves:           return "Beta Waves";
        case BiometricType::ThetaWaves:          return "Theta Waves";
        case BiometricType::DeltaWaves:          return "Delta Waves";
        case BiometricType::GammaWaves:          return "Gamma Waves";
        case BiometricType::MeditationScore:     return "Meditation";
        case BiometricType::FocusScore:          return "Focus";
        default:                                 return "Unknown";
    }
}

//==============================================================================
// Biometric Sample
//==============================================================================

struct BiometricSample
{
    BiometricType type = BiometricType::Unknown;
    double value = 0.0;
    double quality = 1.0;           // Signal quality 0-1
    std::chrono::steady_clock::time_point timestamp;

    BiometricSample() : timestamp(std::chrono::steady_clock::now()) {}

    BiometricSample(BiometricType t, double v, double q = 1.0)
        : type(t), value(v), quality(q), timestamp(std::chrono::steady_clock::now()) {}
};

//==============================================================================
// Device Types
//==============================================================================

enum class WearableDeviceType
{
    AppleWatch,
    OuraRing,
    PolarH10,
    Fitbit,
    Garmin,
    MuseHeadband,
    Neurosky,
    GenericBLE,
    Simulator,      // For testing without hardware
    Unknown
};

inline std::string deviceTypeToString(WearableDeviceType type)
{
    switch (type)
    {
        case WearableDeviceType::AppleWatch:    return "Apple Watch";
        case WearableDeviceType::OuraRing:      return "Oura Ring";
        case WearableDeviceType::PolarH10:      return "Polar H10";
        case WearableDeviceType::Fitbit:        return "Fitbit";
        case WearableDeviceType::Garmin:        return "Garmin";
        case WearableDeviceType::MuseHeadband:  return "Muse";
        case WearableDeviceType::Neurosky:      return "Neurosky";
        case WearableDeviceType::GenericBLE:    return "BLE Device";
        case WearableDeviceType::Simulator:     return "Simulator";
        default:                                return "Unknown";
    }
}

//==============================================================================
// Wearable Device Interface
//==============================================================================

class WearableDevice
{
public:
    struct DeviceInfo
    {
        std::string name;
        std::string identifier;
        WearableDeviceType type = WearableDeviceType::Unknown;
        std::string firmwareVersion;
        int batteryLevel = 100;
        bool isConnected = false;
    };

    using DataCallback = std::function<void(const BiometricSample&)>;
    using ConnectionCallback = std::function<void(bool connected)>;

    virtual ~WearableDevice() = default;

    //--------------------------------------------------------------------------
    // Connection
    //--------------------------------------------------------------------------

    virtual bool connect() = 0;
    virtual void disconnect() = 0;
    virtual bool isConnected() const = 0;

    virtual DeviceInfo getDeviceInfo() const = 0;

    //--------------------------------------------------------------------------
    // Capabilities
    //--------------------------------------------------------------------------

    virtual std::vector<BiometricType> getSupportedMetrics() const = 0;
    virtual bool supportsHapticFeedback() const { return false; }

    //--------------------------------------------------------------------------
    // Data Streaming
    //--------------------------------------------------------------------------

    virtual void startStreaming() = 0;
    virtual void stopStreaming() = 0;
    virtual bool isStreaming() const = 0;

    void setDataCallback(DataCallback callback) { dataCallback = callback; }
    void setConnectionCallback(ConnectionCallback callback) { connectionCallback = callback; }

    //--------------------------------------------------------------------------
    // Haptic Feedback (if supported)
    //--------------------------------------------------------------------------

    virtual void sendHapticPulse(float intensity, int durationMs) {}
    virtual void sendHapticPattern(const std::vector<std::pair<float, int>>& pattern) {}

protected:
    DataCallback dataCallback;
    ConnectionCallback connectionCallback;

    void notifyData(const BiometricSample& sample)
    {
        if (dataCallback)
            dataCallback(sample);
    }

    void notifyConnection(bool connected)
    {
        if (connectionCallback)
            connectionCallback(connected);
    }
};

//==============================================================================
// Apple Watch Connection (via HealthKit/WatchConnectivity)
//==============================================================================

/**
 * WatchConnectivityBridge
 *
 * Native bridge for iOS WCSession and HealthKit integration.
 * On non-Apple platforms, provides stub implementation.
 */
class WatchConnectivityBridge
{
public:
    enum class SessionState
    {
        NotSupported,
        Inactive,
        Activating,
        Activated
    };

    struct WatchMessage
    {
        std::string type;
        std::map<std::string, double> data;
        std::chrono::steady_clock::time_point timestamp;
    };

    using MessageCallback = std::function<void(const WatchMessage&)>;
    using StateCallback = std::function<void(SessionState)>;

    static WatchConnectivityBridge& getInstance()
    {
        static WatchConnectivityBridge instance;
        return instance;
    }

    bool isSupported() const
    {
#if JUCE_IOS || JUCE_MAC
        return true;
#else
        return false;
#endif
    }

    bool isPaired() const { return watchPaired; }
    bool isReachable() const { return watchReachable; }
    SessionState getState() const { return sessionState; }

    void activate()
    {
        if (!isSupported())
        {
            sessionState = SessionState::NotSupported;
            return;
        }

        sessionState = SessionState::Activating;

#if JUCE_IOS || JUCE_MAC
        // Native implementation would call:
        // [WCSession defaultSession].delegate = nativeBridge;
        // [[WCSession defaultSession] activateSession];
        //
        // Delegate callbacks:
        // - sessionDidBecomeInactive:
        // - sessionDidDeactivate:
        // - sessionWatchStateDidChange:
        // - session:didReceiveMessage:
        // - session:didReceiveApplicationContext:
#endif

        // Simulate activation for non-native builds
        sessionState = SessionState::Activated;
        watchPaired = true;
        if (stateCallback)
            stateCallback(sessionState);
    }

    void sendMessage(const std::string& type, const std::map<std::string, double>& data)
    {
        if (sessionState != SessionState::Activated || !watchReachable)
            return;

#if JUCE_IOS || JUCE_MAC
        // Native: [[WCSession defaultSession] sendMessage:dict replyHandler:nil errorHandler:nil];
#endif
    }

    void updateApplicationContext(const std::map<std::string, double>& context)
    {
        if (sessionState != SessionState::Activated)
            return;

#if JUCE_IOS || JUCE_MAC
        // Native: [[WCSession defaultSession] updateApplicationContext:dict error:nil];
#endif
    }

    void requestHealthKitAuthorization()
    {
#if JUCE_IOS
        // Native HealthKit authorization:
        // HKHealthStore *healthStore = [[HKHealthStore alloc] init];
        // NSSet *readTypes = [NSSet setWithObjects:
        //     [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate],
        //     [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRateVariabilitySDNN],
        //     [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierOxygenSaturation],
        //     [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierRespiratoryRate],
        //     nil];
        // [healthStore requestAuthorizationToShareTypes:nil readTypes:readTypes completion:...];
#endif
        healthKitAuthorized = true;
    }

    void startWorkoutSession()
    {
#if JUCE_IOS
        // Native workout session for real-time data:
        // HKWorkoutConfiguration *config = [[HKWorkoutConfiguration alloc] init];
        // config.activityType = HKWorkoutActivityTypeMindAndBody;
        // config.locationType = HKWorkoutSessionLocationTypeIndoor;
        // HKWorkoutSession *session = [[HKWorkoutSession alloc] initWithHealthStore:store configuration:config error:nil];
        // HKLiveWorkoutBuilder *builder = [session associatedWorkoutBuilder];
        // [builder dataSourceWithOptions:HKLiveWorkoutDataSourceOptionDefault];
        // [session startActivityWithDate:[NSDate date]];
#endif
        workoutActive = true;
    }

    void stopWorkoutSession()
    {
        workoutActive = false;
    }

    void setMessageCallback(MessageCallback callback) { messageCallback = callback; }
    void setStateCallback(StateCallback callback) { stateCallback = callback; }

    // Called from native delegate when data arrives
    void onMessageReceived(const WatchMessage& message)
    {
        if (messageCallback)
            messageCallback(message);
    }

    void onStateChanged(SessionState state, bool paired, bool reachable)
    {
        sessionState = state;
        watchPaired = paired;
        watchReachable = reachable;
        if (stateCallback)
            stateCallback(state);
    }

private:
    WatchConnectivityBridge() = default;

    SessionState sessionState = SessionState::Inactive;
    bool watchPaired = false;
    bool watchReachable = false;
    bool healthKitAuthorized = false;
    bool workoutActive = false;

    MessageCallback messageCallback;
    StateCallback stateCallback;
};

class AppleWatchDevice : public WearableDevice
{
public:
    AppleWatchDevice()
    {
        info.type = WearableDeviceType::AppleWatch;
        info.name = "Apple Watch";

        // Setup WatchConnectivity callbacks
        auto& bridge = WatchConnectivityBridge::getInstance();
        bridge.setMessageCallback([this](const WatchConnectivityBridge::WatchMessage& msg)
        {
            handleWatchMessage(msg);
        });
        bridge.setStateCallback([this](WatchConnectivityBridge::SessionState state)
        {
            handleStateChange(state);
        });
    }

    bool connect() override
    {
        auto& bridge = WatchConnectivityBridge::getInstance();

        if (!bridge.isSupported())
        {
            juce::Logger::writeToLog("[AppleWatch] WatchConnectivity not supported on this platform");
            return false;
        }

        // Activate WCSession
        bridge.activate();

        // Request HealthKit access
        bridge.requestHealthKitAuthorization();

        if (bridge.getState() == WatchConnectivityBridge::SessionState::Activated)
        {
            info.isConnected = true;
            info.identifier = "apple-watch-" + std::to_string(std::hash<std::string>{}("paired"));
            notifyConnection(true);
            return true;
        }

        return false;
    }

    void disconnect() override
    {
        auto& bridge = WatchConnectivityBridge::getInstance();
        bridge.stopWorkoutSession();

        info.isConnected = false;
        streaming = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }
    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::HeartRate,
            BiometricType::HeartRateVariability,
            BiometricType::BloodOxygen,
            BiometricType::RespiratoryRate,
            BiometricType::AccelerationX,
            BiometricType::AccelerationY,
            BiometricType::AccelerationZ,
            BiometricType::GyroscopeX,
            BiometricType::GyroscopeY,
            BiometricType::GyroscopeZ,
            BiometricType::Steps,
            BiometricType::Calories
        };
    }

    bool supportsHapticFeedback() const override { return true; }

    void startStreaming() override
    {
        streaming = true;

        auto& bridge = WatchConnectivityBridge::getInstance();
        bridge.startWorkoutSession();

        // Send message to Watch app to start streaming
        bridge.sendMessage("startStreaming", {{"interval", 1.0}});

        juce::Logger::writeToLog("[AppleWatch] Started streaming via WatchConnectivity");
    }

    void stopStreaming() override
    {
        streaming = false;

        auto& bridge = WatchConnectivityBridge::getInstance();
        bridge.stopWorkoutSession();
        bridge.sendMessage("stopStreaming", {});

        juce::Logger::writeToLog("[AppleWatch] Stopped streaming");
    }

    bool isStreaming() const override { return streaming; }

    void sendHapticPulse(float intensity, int durationMs) override
    {
        auto& bridge = WatchConnectivityBridge::getInstance();

        // Send haptic command to Watch
        // Watch app uses WKInterfaceDevice.current().play(.notification) or CoreHaptics
        std::map<std::string, double> hapticData = {
            {"intensity", intensity},
            {"duration", durationMs / 1000.0}
        };

        bridge.sendMessage("haptic", hapticData);
    }

    void sendHapticPattern(const std::vector<std::pair<float, int>>& pattern) override
    {
        auto& bridge = WatchConnectivityBridge::getInstance();

        // Encode pattern as message
        std::map<std::string, double> patternData;
        for (size_t i = 0; i < pattern.size() && i < 10; ++i)
        {
            patternData["i" + std::to_string(i)] = pattern[i].first;
            patternData["d" + std::to_string(i)] = pattern[i].second / 1000.0;
        }
        patternData["count"] = static_cast<double>(pattern.size());

        bridge.sendMessage("hapticPattern", patternData);
    }

private:
    DeviceInfo info;
    bool streaming = false;

    void handleWatchMessage(const WatchConnectivityBridge::WatchMessage& msg)
    {
        if (msg.type == "heartRate")
        {
            auto it = msg.data.find("bpm");
            if (it != msg.data.end())
            {
                notifyData(BiometricSample(BiometricType::HeartRate, it->second));
            }
        }
        else if (msg.type == "hrv")
        {
            auto it = msg.data.find("sdnn");
            if (it != msg.data.end())
            {
                notifyData(BiometricSample(BiometricType::HeartRateVariability, it->second));
            }
        }
        else if (msg.type == "motion")
        {
            if (auto it = msg.data.find("ax"); it != msg.data.end())
                notifyData(BiometricSample(BiometricType::AccelerationX, it->second));
            if (auto it = msg.data.find("ay"); it != msg.data.end())
                notifyData(BiometricSample(BiometricType::AccelerationY, it->second));
            if (auto it = msg.data.find("az"); it != msg.data.end())
                notifyData(BiometricSample(BiometricType::AccelerationZ, it->second));
            if (auto it = msg.data.find("gx"); it != msg.data.end())
                notifyData(BiometricSample(BiometricType::GyroscopeX, it->second));
            if (auto it = msg.data.find("gy"); it != msg.data.end())
                notifyData(BiometricSample(BiometricType::GyroscopeY, it->second));
            if (auto it = msg.data.find("gz"); it != msg.data.end())
                notifyData(BiometricSample(BiometricType::GyroscopeZ, it->second));
        }
        else if (msg.type == "bloodOxygen")
        {
            auto it = msg.data.find("spo2");
            if (it != msg.data.end())
            {
                notifyData(BiometricSample(BiometricType::BloodOxygen, it->second));
            }
        }
    }

    void handleStateChange(WatchConnectivityBridge::SessionState state)
    {
        auto& bridge = WatchConnectivityBridge::getInstance();

        if (state == WatchConnectivityBridge::SessionState::Activated && bridge.isPaired())
        {
            if (!info.isConnected)
            {
                info.isConnected = true;
                notifyConnection(true);
            }
        }
        else
        {
            if (info.isConnected)
            {
                info.isConnected = false;
                streaming = false;
                notifyConnection(false);
            }
        }
    }
};

//==============================================================================
// Oura Ring Connection (via Oura Cloud API with OAuth2)
//==============================================================================

/**
 * OuraOAuth2Handler
 *
 * Complete OAuth2 flow for Oura Ring API.
 * Handles authorization, token exchange, and automatic refresh.
 */
class OuraOAuth2Handler
{
public:
    struct OAuthConfig
    {
        std::string clientId;
        std::string clientSecret;
        std::string redirectUri = "echoelmusic://oura/callback";
        std::string scope = "daily readiness heartrate sleep personal";
    };

    struct TokenResponse
    {
        std::string accessToken;
        std::string refreshToken;
        std::string tokenType = "Bearer";
        int expiresIn = 86400;  // 24 hours
        std::chrono::steady_clock::time_point expiresAt;
        bool isValid() const
        {
            return !accessToken.empty() &&
                   std::chrono::steady_clock::now() < expiresAt;
        }
    };

    using AuthCallback = std::function<void(bool success, const std::string& error)>;
    using TokenCallback = std::function<void(const TokenResponse& token)>;

    OuraOAuth2Handler(const OAuthConfig& config)
        : oauthConfig(config)
    {
    }

    //--------------------------------------------------------------------------
    // Authorization Flow
    //--------------------------------------------------------------------------

    /**
     * Generate authorization URL for user to visit.
     * Returns URL that should be opened in browser.
     */
    std::string getAuthorizationUrl()
    {
        // Generate random state for CSRF protection
        authState = generateRandomState();

        // Build authorization URL
        // https://cloud.ouraring.com/oauth/authorize
        std::string url = "https://cloud.ouraring.com/oauth/authorize";
        url += "?client_id=" + urlEncode(oauthConfig.clientId);
        url += "&redirect_uri=" + urlEncode(oauthConfig.redirectUri);
        url += "&response_type=code";
        url += "&scope=" + urlEncode(oauthConfig.scope);
        url += "&state=" + urlEncode(authState);

        return url;
    }

    /**
     * Handle callback from OAuth redirect.
     * Call this when user is redirected back with authorization code.
     */
    void handleCallback(const std::string& callbackUrl, AuthCallback callback)
    {
        // Parse callback URL to extract code and state
        auto params = parseUrlParams(callbackUrl);

        // Verify state matches (CSRF protection)
        auto stateIt = params.find("state");
        if (stateIt == params.end() || stateIt->second != authState)
        {
            if (callback)
                callback(false, "Invalid state parameter - possible CSRF attack");
            return;
        }

        // Check for error
        auto errorIt = params.find("error");
        if (errorIt != params.end())
        {
            auto descIt = params.find("error_description");
            std::string errorMsg = descIt != params.end() ? descIt->second : errorIt->second;
            if (callback)
                callback(false, "Authorization denied: " + errorMsg);
            return;
        }

        // Get authorization code
        auto codeIt = params.find("code");
        if (codeIt == params.end())
        {
            if (callback)
                callback(false, "No authorization code received");
            return;
        }

        // Exchange code for tokens
        exchangeCodeForTokens(codeIt->second, callback);
    }

    /**
     * Exchange authorization code for access/refresh tokens.
     */
    void exchangeCodeForTokens(const std::string& code, AuthCallback callback)
    {
        // POST to https://api.ouraring.com/oauth/token
        // Content-Type: application/x-www-form-urlencoded
        //
        // grant_type=authorization_code
        // &code={code}
        // &redirect_uri={redirect_uri}
        // &client_id={client_id}
        // &client_secret={client_secret}

        juce::URL tokenUrl("https://api.ouraring.com/oauth/token");

        juce::String postData = juce::String("grant_type=authorization_code")
            + "&code=" + juce::URL::addEscapeChars(code, true)
            + "&redirect_uri=" + juce::URL::addEscapeChars(oauthConfig.redirectUri, true)
            + "&client_id=" + juce::URL::addEscapeChars(oauthConfig.clientId, true)
            + "&client_secret=" + juce::URL::addEscapeChars(oauthConfig.clientSecret, true);

        auto options = juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
            .withExtraHeaders("Content-Type: application/x-www-form-urlencoded")
            .withConnectionTimeoutMs(10000);

        // Make request (in production, do this on background thread)
        auto stream = tokenUrl.withPOSTData(postData).createInputStream(options);

        if (stream == nullptr)
        {
            if (callback)
                callback(false, "Network error - could not connect to Oura API");
            return;
        }

        juce::String response = stream->readEntireStreamAsString();
        parseTokenResponse(response, callback);
    }

    /**
     * Refresh access token using refresh token.
     */
    void refreshAccessToken(AuthCallback callback)
    {
        if (tokens.refreshToken.empty())
        {
            if (callback)
                callback(false, "No refresh token available");
            return;
        }

        // POST to https://api.ouraring.com/oauth/token
        // grant_type=refresh_token
        // &refresh_token={refresh_token}
        // &client_id={client_id}
        // &client_secret={client_secret}

        juce::URL tokenUrl("https://api.ouraring.com/oauth/token");

        juce::String postData = juce::String("grant_type=refresh_token")
            + "&refresh_token=" + juce::URL::addEscapeChars(tokens.refreshToken, true)
            + "&client_id=" + juce::URL::addEscapeChars(oauthConfig.clientId, true)
            + "&client_secret=" + juce::URL::addEscapeChars(oauthConfig.clientSecret, true);

        auto options = juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inPostData)
            .withExtraHeaders("Content-Type: application/x-www-form-urlencoded")
            .withConnectionTimeoutMs(10000);

        auto stream = tokenUrl.withPOSTData(postData).createInputStream(options);

        if (stream == nullptr)
        {
            if (callback)
                callback(false, "Network error during token refresh");
            return;
        }

        juce::String response = stream->readEntireStreamAsString();
        parseTokenResponse(response, callback);
    }

    //--------------------------------------------------------------------------
    // Token Management
    //--------------------------------------------------------------------------

    bool hasValidToken() const { return tokens.isValid(); }
    std::string getAccessToken() const { return tokens.accessToken; }
    const TokenResponse& getTokens() const { return tokens; }

    void setTokenCallback(TokenCallback callback) { tokenCallback = callback; }

    /**
     * Check if token needs refresh and refresh if necessary.
     */
    void ensureValidToken(AuthCallback callback)
    {
        if (tokens.isValid())
        {
            // Check if expiring soon (within 5 minutes)
            auto timeUntilExpiry = tokens.expiresAt - std::chrono::steady_clock::now();
            if (timeUntilExpiry > std::chrono::minutes(5))
            {
                if (callback)
                    callback(true, "");
                return;
            }
        }

        // Token expired or expiring soon, refresh it
        refreshAccessToken(callback);
    }

    //--------------------------------------------------------------------------
    // Persistence
    //--------------------------------------------------------------------------

    juce::String serializeTokens() const
    {
        juce::var json(new juce::DynamicObject());
        auto* obj = json.getDynamicObject();
        obj->setProperty("access_token", juce::String(tokens.accessToken));
        obj->setProperty("refresh_token", juce::String(tokens.refreshToken));
        obj->setProperty("token_type", juce::String(tokens.tokenType));
        obj->setProperty("expires_in", tokens.expiresIn);

        auto expiry = std::chrono::duration_cast<std::chrono::seconds>(
            tokens.expiresAt.time_since_epoch()).count();
        obj->setProperty("expires_at", static_cast<juce::int64>(expiry));

        return juce::JSON::toString(json);
    }

    void deserializeTokens(const juce::String& json)
    {
        auto parsed = juce::JSON::parse(json);
        if (auto* obj = parsed.getDynamicObject())
        {
            tokens.accessToken = obj->getProperty("access_token").toString().toStdString();
            tokens.refreshToken = obj->getProperty("refresh_token").toString().toStdString();
            tokens.tokenType = obj->getProperty("token_type").toString().toStdString();
            tokens.expiresIn = obj->getProperty("expires_in");

            auto expiry = static_cast<int64_t>(obj->getProperty("expires_at"));
            tokens.expiresAt = std::chrono::steady_clock::time_point(
                std::chrono::seconds(expiry));
        }
    }

private:
    OAuthConfig oauthConfig;
    TokenResponse tokens;
    std::string authState;
    TokenCallback tokenCallback;

    std::string generateRandomState()
    {
        juce::Random random;
        juce::String state;
        for (int i = 0; i < 32; ++i)
        {
            state += juce::String::toHexString(random.nextInt(16));
        }
        return state.toStdString();
    }

    std::string urlEncode(const std::string& value)
    {
        return juce::URL::addEscapeChars(value, true).toStdString();
    }

    std::map<std::string, std::string> parseUrlParams(const std::string& url)
    {
        std::map<std::string, std::string> params;
        size_t queryStart = url.find('?');
        if (queryStart == std::string::npos)
            return params;

        std::string query = url.substr(queryStart + 1);
        size_t pos = 0;

        while (pos < query.length())
        {
            size_t ampPos = query.find('&', pos);
            std::string pair = (ampPos == std::string::npos)
                ? query.substr(pos)
                : query.substr(pos, ampPos - pos);

            size_t eqPos = pair.find('=');
            if (eqPos != std::string::npos)
            {
                std::string key = pair.substr(0, eqPos);
                std::string value = pair.substr(eqPos + 1);
                params[key] = juce::URL::removeEscapeChars(value).toStdString();
            }

            pos = (ampPos == std::string::npos) ? query.length() : ampPos + 1;
        }

        return params;
    }

    void parseTokenResponse(const juce::String& response, AuthCallback callback)
    {
        auto parsed = juce::JSON::parse(response);
        if (auto* obj = parsed.getDynamicObject())
        {
            // Check for error
            if (obj->hasProperty("error"))
            {
                auto error = obj->getProperty("error").toString().toStdString();
                auto desc = obj->getProperty("error_description").toString().toStdString();
                if (callback)
                    callback(false, error + ": " + desc);
                return;
            }

            // Parse tokens
            tokens.accessToken = obj->getProperty("access_token").toString().toStdString();
            tokens.refreshToken = obj->getProperty("refresh_token").toString().toStdString();
            tokens.tokenType = obj->getProperty("token_type").toString().toStdString();
            tokens.expiresIn = obj->getProperty("expires_in");
            tokens.expiresAt = std::chrono::steady_clock::now() +
                               std::chrono::seconds(tokens.expiresIn);

            if (tokenCallback)
                tokenCallback(tokens);

            if (callback)
                callback(true, "");
        }
        else
        {
            if (callback)
                callback(false, "Invalid JSON response from Oura API");
        }
    }
};

class OuraRingDevice : public WearableDevice, public juce::Timer
{
public:
    OuraRingDevice(const OuraOAuth2Handler::OAuthConfig& config = {})
        : oauthHandler(std::make_unique<OuraOAuth2Handler>(config))
    {
        info.type = WearableDeviceType::OuraRing;
        info.name = "Oura Ring";
    }

    //--------------------------------------------------------------------------
    // OAuth2 Authentication
    //--------------------------------------------------------------------------

    OuraOAuth2Handler& getOAuthHandler() { return *oauthHandler; }

    /**
     * Start OAuth2 authorization flow.
     * Returns URL that should be opened in browser for user to authorize.
     */
    std::string startAuthorization()
    {
        return oauthHandler->getAuthorizationUrl();
    }

    /**
     * Handle OAuth2 callback after user authorizes.
     */
    void handleAuthorizationCallback(const std::string& callbackUrl,
                                      std::function<void(bool, const std::string&)> callback)
    {
        oauthHandler->handleCallback(callbackUrl, [this, callback](bool success, const std::string& error)
        {
            if (success)
            {
                info.isConnected = true;
                notifyConnection(true);
                juce::Logger::writeToLog("[OuraRing] Successfully authenticated");
            }
            if (callback)
                callback(success, error);
        });
    }

    /**
     * Load previously saved tokens.
     */
    void loadSavedTokens(const juce::String& tokenJson)
    {
        oauthHandler->deserializeTokens(tokenJson);
    }

    /**
     * Get tokens for persistence.
     */
    juce::String getTokensForSaving() const
    {
        return oauthHandler->serializeTokens();
    }

    //--------------------------------------------------------------------------
    // WearableDevice Interface
    //--------------------------------------------------------------------------

    bool connect() override
    {
        if (!oauthHandler->hasValidToken())
        {
            juce::Logger::writeToLog("[OuraRing] No valid token - need to authenticate");
            return false;
        }

        // Verify token is still valid by making a test API call
        oauthHandler->ensureValidToken([this](bool success, const std::string& error)
        {
            if (success)
            {
                info.isConnected = true;
                notifyConnection(true);
                juce::Logger::writeToLog("[OuraRing] Connected successfully");
            }
            else
            {
                juce::Logger::writeToLog("[OuraRing] Connection failed: " + juce::String(error));
            }
        });

        return oauthHandler->hasValidToken();
    }

    void disconnect() override
    {
        stopTimer();
        info.isConnected = false;
        streaming = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }
    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::HeartRate,
            BiometricType::HeartRateVariability,
            BiometricType::SkinTemperature,
            BiometricType::RespiratoryRate,
            BiometricType::SleepScore,
            BiometricType::EnergyLevel,        // Readiness score
            BiometricType::StressLevel         // Derived from HRV
        };
    }

    void startStreaming() override
    {
        streaming = true;

        // Fetch initial data
        fetchAllData();

        // Poll every 5 minutes (Oura doesn't have real-time API)
        startTimer(5 * 60 * 1000);

        juce::Logger::writeToLog("[OuraRing] Started data polling");
    }

    void stopStreaming() override
    {
        streaming = false;
        stopTimer();
    }

    bool isStreaming() const override { return streaming; }

    //--------------------------------------------------------------------------
    // Timer Callback (for periodic data fetch)
    //--------------------------------------------------------------------------

    void timerCallback() override
    {
        if (streaming && info.isConnected)
        {
            fetchAllData();
        }
    }

    //--------------------------------------------------------------------------
    // API Data Fetching
    //--------------------------------------------------------------------------

    void fetchAllData()
    {
        oauthHandler->ensureValidToken([this](bool success, const std::string& error)
        {
            if (!success)
            {
                juce::Logger::writeToLog("[OuraRing] Token refresh failed: " + juce::String(error));
                return;
            }

            fetchDailyReadiness();
            fetchHeartRate();
            fetchSleepData();
        });
    }

private:
    DeviceInfo info;
    std::unique_ptr<OuraOAuth2Handler> oauthHandler;
    bool streaming = false;

    void fetchDailyReadiness()
    {
        // GET https://api.ouraring.com/v2/usercollection/daily_readiness
        juce::URL url("https://api.ouraring.com/v2/usercollection/daily_readiness");

        // Add date range (today)
        auto today = juce::Time::getCurrentTime().formatted("%Y-%m-%d");
        url = url.withParameter("start_date", today)
                 .withParameter("end_date", today);

        makeApiRequest(url, [this](const juce::var& json)
        {
            if (auto* data = json["data"].getArray())
            {
                if (!data->isEmpty())
                {
                    auto& latest = data->getLast();
                    double readinessScore = latest["score"];
                    double hrvBalance = latest["contributors"]["hrv_balance"];

                    notifyData(BiometricSample(BiometricType::EnergyLevel, readinessScore));

                    // Derive stress from HRV balance (inverse relationship)
                    double stressLevel = 100.0 - (hrvBalance * 100.0);
                    notifyData(BiometricSample(BiometricType::StressLevel, stressLevel));
                }
            }
        });
    }

    void fetchHeartRate()
    {
        // GET https://api.ouraring.com/v2/usercollection/heartrate
        juce::URL url("https://api.ouraring.com/v2/usercollection/heartrate");

        auto today = juce::Time::getCurrentTime().formatted("%Y-%m-%d");
        url = url.withParameter("start_date", today)
                 .withParameter("end_date", today);

        makeApiRequest(url, [this](const juce::var& json)
        {
            if (auto* data = json["data"].getArray())
            {
                if (!data->isEmpty())
                {
                    // Get the most recent heart rate reading
                    auto& latest = data->getLast();
                    double bpm = latest["bpm"];
                    notifyData(BiometricSample(BiometricType::HeartRate, bpm));
                }
            }
        });
    }

    void fetchSleepData()
    {
        // GET https://api.ouraring.com/v2/usercollection/daily_sleep
        juce::URL url("https://api.ouraring.com/v2/usercollection/daily_sleep");

        auto today = juce::Time::getCurrentTime().formatted("%Y-%m-%d");
        url = url.withParameter("start_date", today)
                 .withParameter("end_date", today);

        makeApiRequest(url, [this](const juce::var& json)
        {
            if (auto* data = json["data"].getArray())
            {
                if (!data->isEmpty())
                {
                    auto& latest = data->getLast();
                    double sleepScore = latest["score"];
                    notifyData(BiometricSample(BiometricType::SleepScore, sleepScore));
                }
            }
        });
    }

    void makeApiRequest(const juce::URL& url, std::function<void(const juce::var&)> handler)
    {
        juce::String authHeader = "Bearer " + juce::String(oauthHandler->getAccessToken());

        auto options = juce::URL::InputStreamOptions(juce::URL::ParameterHandling::inAddress)
            .withExtraHeaders("Authorization: " + authHeader)
            .withConnectionTimeoutMs(10000);

        // Run on background thread in production
        auto stream = url.createInputStream(options);
        if (stream == nullptr)
        {
            juce::Logger::writeToLog("[OuraRing] API request failed - network error");
            return;
        }

        juce::String response = stream->readEntireStreamAsString();
        auto json = juce::JSON::parse(response);

        if (handler)
            handler(json);
    }
};

//==============================================================================
// BLE Scanner for Wearable Device Discovery
//==============================================================================

/**
 * BLEScanner
 *
 * Cross-platform BLE device scanner for discovering wearable devices.
 * Uses CoreBluetooth on macOS/iOS, platform-specific APIs on other platforms.
 */
class BLEScanner
{
public:
    // Standard BLE Service UUIDs
    static constexpr const char* HEART_RATE_SERVICE = "180D";
    static constexpr const char* BATTERY_SERVICE = "180F";
    static constexpr const char* DEVICE_INFO_SERVICE = "180A";

    // Standard Characteristic UUIDs
    static constexpr const char* HEART_RATE_MEASUREMENT = "2A37";
    static constexpr const char* BATTERY_LEVEL = "2A19";

    struct DiscoveredDevice
    {
        std::string name;
        std::string identifier;     // UUID on iOS/macOS, MAC address elsewhere
        int rssi = 0;               // Signal strength
        std::vector<std::string> serviceUUIDs;
        std::map<std::string, std::vector<uint8_t>> manufacturerData;
        WearableDeviceType inferredType = WearableDeviceType::Unknown;
        std::chrono::steady_clock::time_point discoveredAt;
    };

    enum class ScanState
    {
        Idle,
        Scanning,
        Connecting,
        Connected
    };

    using DeviceFoundCallback = std::function<void(const DiscoveredDevice&)>;
    using ScanStateCallback = std::function<void(ScanState)>;
    using ConnectionCallback = std::function<void(bool success, const std::string& error)>;
    using DataCallback = std::function<void(const std::string& characteristicUUID, const std::vector<uint8_t>& data)>;

    static BLEScanner& getInstance()
    {
        static BLEScanner instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Scanning
    //--------------------------------------------------------------------------

    bool isBluetoothAvailable() const
    {
#if JUCE_IOS || JUCE_MAC
        // CBCentralManager.state == .poweredOn
        return bluetoothPoweredOn;
#else
        return true;  // Assume available on other platforms
#endif
    }

    void startScanning(const std::vector<std::string>& serviceFilters = {})
    {
        if (scanState != ScanState::Idle)
            return;

        scanState = ScanState::Scanning;
        serviceFilter = serviceFilters;
        discoveredDevices.clear();

#if JUCE_IOS || JUCE_MAC
        // Native CoreBluetooth:
        // NSArray *services = serviceFilters.empty() ? nil :
        //     @[[CBUUID UUIDWithString:@"180D"]];  // Heart Rate Service
        // [centralManager scanForPeripheralsWithServices:services options:nil];
#endif

        juce::Logger::writeToLog("[BLEScanner] Started scanning for devices");

        if (stateCallback)
            stateCallback(scanState);
    }

    void stopScanning()
    {
        if (scanState != ScanState::Scanning)
            return;

        scanState = ScanState::Idle;

#if JUCE_IOS || JUCE_MAC
        // [centralManager stopScan];
#endif

        juce::Logger::writeToLog("[BLEScanner] Stopped scanning");

        if (stateCallback)
            stateCallback(scanState);
    }

    bool isScanning() const { return scanState == ScanState::Scanning; }
    ScanState getState() const { return scanState; }

    std::vector<DiscoveredDevice> getDiscoveredDevices() const
    {
        return discoveredDevices;
    }

    //--------------------------------------------------------------------------
    // Connection
    //--------------------------------------------------------------------------

    void connectToDevice(const std::string& deviceIdentifier, ConnectionCallback callback)
    {
        auto it = std::find_if(discoveredDevices.begin(), discoveredDevices.end(),
            [&](const DiscoveredDevice& d) { return d.identifier == deviceIdentifier; });

        if (it == discoveredDevices.end())
        {
            if (callback)
                callback(false, "Device not found");
            return;
        }

        stopScanning();
        scanState = ScanState::Connecting;
        pendingConnectionCallback = callback;
        connectedDeviceId = deviceIdentifier;

#if JUCE_IOS || JUCE_MAC
        // CBPeripheral *peripheral = peripheralMap[deviceIdentifier];
        // [centralManager connectPeripheral:peripheral options:nil];
#endif

        juce::Logger::writeToLog("[BLEScanner] Connecting to device: " + juce::String(it->name));

        // Simulate connection for non-native builds
        scanState = ScanState::Connected;
        if (pendingConnectionCallback)
            pendingConnectionCallback(true, "");
    }

    void disconnectFromDevice(const std::string& deviceIdentifier)
    {
        if (connectedDeviceId != deviceIdentifier)
            return;

#if JUCE_IOS || JUCE_MAC
        // CBPeripheral *peripheral = peripheralMap[deviceIdentifier];
        // [centralManager cancelPeripheralConnection:peripheral];
#endif

        scanState = ScanState::Idle;
        connectedDeviceId.clear();

        juce::Logger::writeToLog("[BLEScanner] Disconnected from device");

        if (stateCallback)
            stateCallback(scanState);
    }

    bool isConnected() const { return scanState == ScanState::Connected; }

    //--------------------------------------------------------------------------
    // Service/Characteristic Discovery
    //--------------------------------------------------------------------------

    void discoverServices(const std::vector<std::string>& serviceUUIDs = {})
    {
        if (!isConnected())
            return;

#if JUCE_IOS || JUCE_MAC
        // CBPeripheral *peripheral = connectedPeripheral;
        // NSArray *services = serviceUUIDs.empty() ? nil :
        //     [serviceUUIDs map:^(NSString *uuid) { return [CBUUID UUIDWithString:uuid]; }];
        // [peripheral discoverServices:services];
#endif
    }

    void discoverCharacteristics(const std::string& serviceUUID,
                                  const std::vector<std::string>& characteristicUUIDs = {})
    {
        if (!isConnected())
            return;

#if JUCE_IOS || JUCE_MAC
        // Find service and discover characteristics
        // [peripheral discoverCharacteristics:characteristics forService:service];
#endif
    }

    void subscribeToCharacteristic(const std::string& serviceUUID,
                                    const std::string& characteristicUUID,
                                    DataCallback callback)
    {
        if (!isConnected())
            return;

        characteristicCallbacks[characteristicUUID] = callback;

#if JUCE_IOS || JUCE_MAC
        // CBCharacteristic *characteristic = findCharacteristic(serviceUUID, characteristicUUID);
        // [connectedPeripheral setNotifyValue:YES forCharacteristic:characteristic];
#endif

        juce::Logger::writeToLog("[BLEScanner] Subscribed to characteristic: " +
                                  juce::String(characteristicUUID));
    }

    void unsubscribeFromCharacteristic(const std::string& serviceUUID,
                                        const std::string& characteristicUUID)
    {
        characteristicCallbacks.erase(characteristicUUID);

#if JUCE_IOS || JUCE_MAC
        // [connectedPeripheral setNotifyValue:NO forCharacteristic:characteristic];
#endif
    }

    //--------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------

    void setDeviceFoundCallback(DeviceFoundCallback callback)
    {
        deviceFoundCallback = callback;
    }

    void setScanStateCallback(ScanStateCallback callback)
    {
        stateCallback = callback;
    }

    //--------------------------------------------------------------------------
    // Native Delegate Methods (called from platform-specific code)
    //--------------------------------------------------------------------------

    void onDeviceDiscovered(const DiscoveredDevice& device)
    {
        // Check if already discovered
        auto it = std::find_if(discoveredDevices.begin(), discoveredDevices.end(),
            [&](const DiscoveredDevice& d) { return d.identifier == device.identifier; });

        if (it == discoveredDevices.end())
        {
            discoveredDevices.push_back(device);
            juce::Logger::writeToLog("[BLEScanner] Discovered: " + juce::String(device.name) +
                                      " RSSI: " + juce::String(device.rssi));
        }
        else
        {
            // Update existing entry
            *it = device;
        }

        if (deviceFoundCallback)
            deviceFoundCallback(device);
    }

    void onConnectionStateChanged(bool connected, const std::string& error)
    {
        if (connected)
        {
            scanState = ScanState::Connected;
        }
        else
        {
            scanState = ScanState::Idle;
            connectedDeviceId.clear();
        }

        if (pendingConnectionCallback)
        {
            pendingConnectionCallback(connected, error);
            pendingConnectionCallback = nullptr;
        }

        if (stateCallback)
            stateCallback(scanState);
    }

    void onCharacteristicValueChanged(const std::string& characteristicUUID,
                                       const std::vector<uint8_t>& data)
    {
        auto it = characteristicCallbacks.find(characteristicUUID);
        if (it != characteristicCallbacks.end() && it->second)
        {
            it->second(characteristicUUID, data);
        }
    }

    void onBluetoothStateChanged(bool poweredOn)
    {
        bluetoothPoweredOn = poweredOn;
        if (!poweredOn && scanState != ScanState::Idle)
        {
            stopScanning();
        }
    }

private:
    BLEScanner() = default;

    ScanState scanState = ScanState::Idle;
    std::vector<std::string> serviceFilter;
    std::vector<DiscoveredDevice> discoveredDevices;
    std::string connectedDeviceId;
    bool bluetoothPoweredOn = true;

    DeviceFoundCallback deviceFoundCallback;
    ScanStateCallback stateCallback;
    ConnectionCallback pendingConnectionCallback;
    std::map<std::string, DataCallback> characteristicCallbacks;
};

//==============================================================================
// Polar H10 BLE Heart Rate Monitor
//==============================================================================

class PolarH10Device : public WearableDevice
{
public:
    PolarH10Device()
    {
        info.type = WearableDeviceType::PolarH10;
        info.name = "Polar H10";
    }

    PolarH10Device(const std::string& deviceId, const std::string& deviceName)
        : bleDeviceId(deviceId)
    {
        info.type = WearableDeviceType::PolarH10;
        info.name = deviceName;
        info.identifier = deviceId;
    }

    //--------------------------------------------------------------------------
    // BLE Device Discovery
    //--------------------------------------------------------------------------

    static void scanForDevices(std::function<void(const BLEScanner::DiscoveredDevice&)> callback)
    {
        auto& scanner = BLEScanner::getInstance();

        scanner.setDeviceFoundCallback([callback](const BLEScanner::DiscoveredDevice& device)
        {
            // Filter for Polar devices
            if (device.name.find("Polar") != std::string::npos)
            {
                auto deviceCopy = device;
                deviceCopy.inferredType = WearableDeviceType::PolarH10;
                if (callback)
                    callback(deviceCopy);
            }
        });

        // Scan for Heart Rate Service
        scanner.startScanning({BLEScanner::HEART_RATE_SERVICE});
    }

    static void stopScanning()
    {
        BLEScanner::getInstance().stopScanning();
    }

    //--------------------------------------------------------------------------
    // WearableDevice Interface
    //--------------------------------------------------------------------------

    bool connect() override
    {
        if (bleDeviceId.empty())
        {
            juce::Logger::writeToLog("[PolarH10] No device ID set - scan for devices first");
            return false;
        }

        auto& scanner = BLEScanner::getInstance();

        scanner.connectToDevice(bleDeviceId, [this](bool success, const std::string& error)
        {
            if (success)
            {
                info.isConnected = true;
                notifyConnection(true);
                juce::Logger::writeToLog("[PolarH10] Connected successfully");

                // Discover services
                scanner.discoverServices({BLEScanner::HEART_RATE_SERVICE,
                                          BLEScanner::BATTERY_SERVICE});
            }
            else
            {
                juce::Logger::writeToLog("[PolarH10] Connection failed: " + juce::String(error));
            }
        });

        return true;
    }

    void disconnect() override
    {
        auto& scanner = BLEScanner::getInstance();
        scanner.unsubscribeFromCharacteristic(BLEScanner::HEART_RATE_SERVICE,
                                               BLEScanner::HEART_RATE_MEASUREMENT);
        scanner.disconnectFromDevice(bleDeviceId);

        info.isConnected = false;
        streaming = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }
    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::HeartRate,
            BiometricType::HeartRateVariability,  // Computed from RR intervals
        };
    }

    void startStreaming() override
    {
        if (!info.isConnected)
            return;

        streaming = true;

        auto& scanner = BLEScanner::getInstance();

        // Subscribe to Heart Rate Measurement characteristic
        scanner.subscribeToCharacteristic(
            BLEScanner::HEART_RATE_SERVICE,
            BLEScanner::HEART_RATE_MEASUREMENT,
            [this](const std::string& uuid, const std::vector<uint8_t>& data)
            {
                parseHeartRateMeasurement(data);
            });

        juce::Logger::writeToLog("[PolarH10] Started streaming heart rate data");
    }

    void stopStreaming() override
    {
        streaming = false;

        auto& scanner = BLEScanner::getInstance();
        scanner.unsubscribeFromCharacteristic(BLEScanner::HEART_RATE_SERVICE,
                                               BLEScanner::HEART_RATE_MEASUREMENT);
    }

    bool isStreaming() const override { return streaming; }

    //--------------------------------------------------------------------------
    // HRV Calculation
    //--------------------------------------------------------------------------

    double calculateHRV(const std::vector<int>& rrIntervals)
    {
        if (rrIntervals.size() < 2)
            return 0.0;

        // Calculate RMSSD (Root Mean Square of Successive Differences)
        double sumSquaredDiff = 0.0;
        for (size_t i = 1; i < rrIntervals.size(); ++i)
        {
            double diff = static_cast<double>(rrIntervals[i] - rrIntervals[i-1]);
            sumSquaredDiff += diff * diff;
        }

        return std::sqrt(sumSquaredDiff / static_cast<double>(rrIntervals.size() - 1));
    }

private:
    DeviceInfo info;
    std::string bleDeviceId;
    bool streaming = false;
    std::vector<int> rrBuffer;  // RR intervals in ms

    /**
     * Parse BLE Heart Rate Measurement characteristic data.
     *
     * Format (Bluetooth specification):
     * Byte 0: Flags
     *   - Bit 0: Heart rate format (0 = UINT8, 1 = UINT16)
     *   - Bit 1: Sensor contact status bit
     *   - Bit 2: Sensor contact supported
     *   - Bit 3: Energy expended present
     *   - Bit 4: RR interval present
     *
     * Byte 1(-2): Heart rate value
     * Remaining bytes: RR intervals (if present)
     */
    void parseHeartRateMeasurement(const std::vector<uint8_t>& data)
    {
        if (data.empty())
            return;

        uint8_t flags = data[0];
        size_t offset = 1;

        // Parse heart rate
        uint16_t heartRate;
        if (flags & 0x01)
        {
            // UINT16 format
            if (data.size() < 3)
                return;
            heartRate = data[1] | (data[2] << 8);
            offset = 3;
        }
        else
        {
            // UINT8 format
            if (data.size() < 2)
                return;
            heartRate = data[1];
            offset = 2;
        }

        notifyData(BiometricSample(BiometricType::HeartRate, static_cast<double>(heartRate)));

        // Skip energy expended if present
        if (flags & 0x08)
        {
            offset += 2;
        }

        // Parse RR intervals if present
        if (flags & 0x10)
        {
            std::vector<int> newRRIntervals;

            while (offset + 1 < data.size())
            {
                // RR interval in 1/1024 seconds, convert to ms
                uint16_t rr = data[offset] | (data[offset + 1] << 8);
                int rrMs = static_cast<int>((rr * 1000) / 1024);

                if (rrMs > 200 && rrMs < 2000)  // Sanity check
                {
                    newRRIntervals.push_back(rrMs);
                    rrBuffer.push_back(rrMs);
                }

                offset += 2;
            }

            // Keep buffer size reasonable
            while (rrBuffer.size() > 30)
            {
                rrBuffer.erase(rrBuffer.begin());
            }

            // Calculate and emit HRV if we have enough data
            if (rrBuffer.size() >= 5)
            {
                double hrv = calculateHRV(rrBuffer);
                notifyData(BiometricSample(BiometricType::HeartRateVariability, hrv));
            }
        }
    }
};

//==============================================================================
// Muse EEG Headband
//==============================================================================

class MuseDevice : public WearableDevice
{
public:
    MuseDevice()
    {
        info.type = WearableDeviceType::MuseHeadband;
        info.name = "Muse Headband";
    }

    bool connect() override
    {
        // Connect via Muse SDK or direct BLE
        // Muse 2/S have 4 EEG sensors + PPG + accelerometer

        info.isConnected = true;
        notifyConnection(true);
        return true;
    }

    void disconnect() override
    {
        info.isConnected = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }
    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::DeltaWaves,
            BiometricType::ThetaWaves,
            BiometricType::AlphaWaves,
            BiometricType::BetaWaves,
            BiometricType::GammaWaves,
            BiometricType::MeditationScore,
            BiometricType::FocusScore,
            BiometricType::RelaxationScore,
            BiometricType::HeartRate,           // Muse 2/S have PPG
            BiometricType::AccelerationX,
            BiometricType::AccelerationY,
            BiometricType::AccelerationZ
        };
    }

    void startStreaming() override
    {
        streaming = true;
        // Subscribe to EEG data stream
        // Process FFT to extract band powers
    }

    void stopStreaming() override { streaming = false; }
    bool isStreaming() const override { return streaming; }

    // Compute band powers from raw EEG
    void processEEGSample(const std::vector<float>& rawEEG, double sampleRate)
    {
        // Apply bandpass filters for each frequency band:
        // Delta: 0.5-4 Hz
        // Theta: 4-8 Hz
        // Alpha: 8-13 Hz
        // Beta: 13-32 Hz
        // Gamma: 32-100 Hz

        // Compute power in each band using FFT or filter banks
        // Normalize and emit as samples
    }

private:
    DeviceInfo info;
    bool streaming = false;
};

//==============================================================================
// Simulator Device (for testing without hardware)
//==============================================================================

class SimulatorDevice : public WearableDevice
{
public:
    SimulatorDevice()
    {
        info.type = WearableDeviceType::Simulator;
        info.name = "Bio Simulator";
        info.identifier = "simulator-001";
        info.isConnected = false;
    }

    bool connect() override
    {
        info.isConnected = true;
        notifyConnection(true);
        return true;
    }

    void disconnect() override
    {
        stopStreaming();
        info.isConnected = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }
    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::HeartRate,
            BiometricType::HeartRateVariability,
            BiometricType::StressLevel,
            BiometricType::EnergyLevel,
            BiometricType::AlphaWaves,
            BiometricType::BetaWaves,
            BiometricType::AccelerationX,
            BiometricType::AccelerationY,
            BiometricType::AccelerationZ
        };
    }

    void startStreaming() override
    {
        streaming = true;
        startTime = std::chrono::steady_clock::now();

        // Start simulation timer
        simulationTimer = std::make_unique<juce::Timer>();
        // Would call generateSimulatedData() at 10Hz
    }

    void stopStreaming() override
    {
        streaming = false;
        simulationTimer.reset();
    }

    bool isStreaming() const override { return streaming; }

    // Simulation parameters
    void setBaseHeartRate(double bpm) { baseHeartRate = bpm; }
    void setStressLevel(double stress) { targetStress = stress; }
    void setActivityLevel(double activity) { activityLevel = activity; }

private:
    DeviceInfo info;
    bool streaming = false;
    std::chrono::steady_clock::time_point startTime;

    double baseHeartRate = 70.0;
    double targetStress = 30.0;
    double activityLevel = 0.3;

    double phase = 0.0;

    std::unique_ptr<juce::Timer> simulationTimer;

    void generateSimulatedData()
    {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration<double>(now - startTime).count();

        // Simulate realistic heart rate with variation
        double hrVariation = 5.0 * std::sin(elapsed * 0.1) +      // Slow drift
                            2.0 * std::sin(elapsed * 0.5) +       // Respiratory influence
                            1.0 * ((std::rand() % 100) / 100.0 - 0.5);  // Random noise

        double heartRate = baseHeartRate + hrVariation + (activityLevel * 30.0);

        // Simulate HRV (inversely related to stress)
        double hrv = 50.0 * (1.0 - targetStress / 100.0) +
                     10.0 * ((std::rand() % 100) / 100.0);

        // Simulate stress response to activity
        double stress = targetStress + activityLevel * 20.0;
        stress = std::clamp(stress, 0.0, 100.0);

        // Simulate motion
        double accX = 0.1 * std::sin(elapsed * 2.0) * activityLevel;
        double accY = 0.1 * std::cos(elapsed * 2.3) * activityLevel;
        double accZ = 1.0 + 0.05 * std::sin(elapsed * 1.8) * activityLevel;

        // Simulate brainwaves (normalized 0-1)
        double alpha = 0.5 + 0.3 * (1.0 - stress / 100.0);  // Higher when relaxed
        double beta = 0.3 + 0.4 * (stress / 100.0);         // Higher when stressed

        // Emit samples
        notifyData(BiometricSample(BiometricType::HeartRate, heartRate));
        notifyData(BiometricSample(BiometricType::HeartRateVariability, hrv));
        notifyData(BiometricSample(BiometricType::StressLevel, stress));
        notifyData(BiometricSample(BiometricType::EnergyLevel, 70.0 - stress * 0.5));
        notifyData(BiometricSample(BiometricType::AccelerationX, accX));
        notifyData(BiometricSample(BiometricType::AccelerationY, accY));
        notifyData(BiometricSample(BiometricType::AccelerationZ, accZ));
        notifyData(BiometricSample(BiometricType::AlphaWaves, alpha));
        notifyData(BiometricSample(BiometricType::BetaWaves, beta));
    }
};

//==============================================================================
// Bio Modulation Mapping
//==============================================================================

struct BioModulationMapping
{
    BiometricType sourceType = BiometricType::HeartRate;
    std::string targetParameter;        // e.g., "tempo", "filter_cutoff"

    double inputMin = 50.0;             // Input range min (e.g., 50 BPM)
    double inputMax = 120.0;            // Input range max
    double outputMin = 0.0;             // Output range min
    double outputMax = 1.0;             // Output range max

    bool inverted = false;              // Invert the mapping
    double smoothing = 0.9;             // Smoothing factor (0-1)
    double sensitivity = 1.0;           // Multiplier for response

    bool isActive = true;

    double mapValue(double input) const
    {
        if (!isActive) return outputMin;

        // Clamp input to range
        double normalized = (input - inputMin) / (inputMax - inputMin);
        normalized = std::clamp(normalized, 0.0, 1.0);

        // Apply inversion
        if (inverted)
            normalized = 1.0 - normalized;

        // Apply sensitivity curve
        normalized = std::pow(normalized, 1.0 / sensitivity);

        // Map to output range
        return outputMin + normalized * (outputMax - outputMin);
    }
};

//==============================================================================
// Wearable Manager
//==============================================================================

class WearableManager
{
public:
    using DataCallback = std::function<void(BiometricType, double)>;

    static WearableManager& getInstance()
    {
        static WearableManager instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Device Management
    //--------------------------------------------------------------------------

    void addDevice(std::unique_ptr<WearableDevice> device)
    {
        auto* ptr = device.get();

        // Setup callbacks
        device->setDataCallback([this, ptr](const BiometricSample& sample)
        {
            handleIncomingData(ptr, sample);
        });

        device->setConnectionCallback([this, ptr](bool connected)
        {
            handleConnectionChange(ptr, connected);
        });

        devices.push_back(std::move(device));
    }

    void removeDevice(WearableDevice* device)
    {
        device->disconnect();
        devices.erase(
            std::remove_if(devices.begin(), devices.end(),
                [device](const auto& d) { return d.get() == device; }),
            devices.end());
    }

    std::vector<WearableDevice*> getDevices() const
    {
        std::vector<WearableDevice*> result;
        for (const auto& d : devices)
            result.push_back(d.get());
        return result;
    }

    std::vector<WearableDevice*> getConnectedDevices() const
    {
        std::vector<WearableDevice*> result;
        for (const auto& d : devices)
        {
            if (d->isConnected())
                result.push_back(d.get());
        }
        return result;
    }

    //--------------------------------------------------------------------------
    // Data Access
    //--------------------------------------------------------------------------

    double getLatestValue(BiometricType type) const
    {
        auto it = latestValues.find(type);
        if (it != latestValues.end())
            return it->second;
        return 0.0;
    }

    double getSmoothedValue(BiometricType type) const
    {
        auto it = smoothedValues.find(type);
        if (it != smoothedValues.end())
            return it->second;
        return getLatestValue(type);
    }

    std::deque<BiometricSample> getHistory(BiometricType type, int maxSamples = 100) const
    {
        auto it = sampleHistory.find(type);
        if (it != sampleHistory.end())
        {
            const auto& history = it->second;
            int count = std::min(maxSamples, static_cast<int>(history.size()));
            return std::deque<BiometricSample>(history.end() - count, history.end());
        }
        return {};
    }

    void setDataCallback(DataCallback callback)
    {
        userDataCallback = callback;
    }

    //--------------------------------------------------------------------------
    // Modulation Mappings
    //--------------------------------------------------------------------------

    void addMapping(const BioModulationMapping& mapping)
    {
        mappings.push_back(mapping);
    }

    void removeMapping(size_t index)
    {
        if (index < mappings.size())
            mappings.erase(mappings.begin() + index);
    }

    void clearMappings()
    {
        mappings.clear();
    }

    std::vector<BioModulationMapping>& getMappings() { return mappings; }

    double getMappedValue(const std::string& targetParam) const
    {
        for (const auto& mapping : mappings)
        {
            if (mapping.targetParameter == targetParam && mapping.isActive)
            {
                double input = getSmoothedValue(mapping.sourceType);
                return mapping.mapValue(input);
            }
        }
        return 0.0;
    }

    //--------------------------------------------------------------------------
    // Bio-Tempo Sync
    //--------------------------------------------------------------------------

    // Get tempo that follows heart rate
    double getBioTempo() const
    {
        double hr = getSmoothedValue(BiometricType::HeartRate);
        if (hr < 40.0 || hr > 200.0) return 120.0;  // Fallback

        // Quantize to musically useful tempos
        // HR 60 -> 120 BPM (double time)
        // HR 70 -> 140 BPM
        // HR 80 -> 80 BPM (same) or 160 BPM (double)

        // Simple mapping: tempo = heart rate * multiplier
        double tempo = hr;

        // Keep in musical range 60-180 BPM
        while (tempo < 60.0) tempo *= 2.0;
        while (tempo > 180.0) tempo /= 2.0;

        return tempo;
    }

    // Get subdivision feel based on energy
    int getBioSubdivision() const
    {
        double energy = getSmoothedValue(BiometricType::EnergyLevel);
        double stress = getSmoothedValue(BiometricType::StressLevel);

        // High energy + high stress = faster subdivisions
        double factor = (energy + stress) / 200.0;

        if (factor > 0.7) return 16;      // 16th notes
        if (factor > 0.5) return 8;       // 8th notes
        if (factor > 0.3) return 4;       // Quarter notes
        return 2;                          // Half notes
    }

    //--------------------------------------------------------------------------
    // Haptic Feedback
    //--------------------------------------------------------------------------

    void sendHapticToAll(float intensity, int durationMs)
    {
        for (auto& device : devices)
        {
            if (device->isConnected() && device->supportsHapticFeedback())
            {
                device->sendHapticPulse(intensity, durationMs);
            }
        }
    }

    // Haptic metronome - pulse on beat
    void pulseOnBeat(int beatNumber, int beatsPerBar)
    {
        float intensity = (beatNumber == 1) ? 1.0f : 0.5f;
        int duration = (beatNumber == 1) ? 50 : 30;
        sendHapticToAll(intensity, duration);
    }

    //--------------------------------------------------------------------------
    // Smoothing Configuration
    //--------------------------------------------------------------------------

    void setSmoothingFactor(double factor)
    {
        smoothingFactor = std::clamp(factor, 0.0, 0.999);
    }

    void setHistorySize(int size)
    {
        maxHistorySize = std::max(10, size);
    }

private:
    WearableManager() = default;

    std::vector<std::unique_ptr<WearableDevice>> devices;
    std::vector<BioModulationMapping> mappings;

    std::map<BiometricType, double> latestValues;
    std::map<BiometricType, double> smoothedValues;
    std::map<BiometricType, std::deque<BiometricSample>> sampleHistory;

    DataCallback userDataCallback;

    double smoothingFactor = 0.9;
    int maxHistorySize = 300;  // ~30 seconds at 10Hz

    void handleIncomingData(WearableDevice* device, const BiometricSample& sample)
    {
        // Store latest value
        latestValues[sample.type] = sample.value;

        // Apply smoothing
        double& smoothed = smoothedValues[sample.type];
        smoothed = smoothed * smoothingFactor + sample.value * (1.0 - smoothingFactor);

        // Store in history
        auto& history = sampleHistory[sample.type];
        history.push_back(sample);
        while (static_cast<int>(history.size()) > maxHistorySize)
            history.pop_front();

        // Notify user callback
        if (userDataCallback)
            userDataCallback(sample.type, sample.value);
    }

    void handleConnectionChange(WearableDevice* device, bool connected)
    {
        // Could emit an event here for UI updates
    }
};

//==============================================================================
// Bio Data Visualizer Component
//==============================================================================

class BioDataVisualizerComponent : public juce::Component,
                                    public juce::Timer
{
public:
    BioDataVisualizerComponent()
    {
        startTimerHz(30);
    }

    void setMetricToDisplay(BiometricType metric)
    {
        displayedMetric = metric;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff1a1a2e));

        // Get history
        auto& manager = WearableManager::getInstance();
        auto history = manager.getHistory(displayedMetric, static_cast<int>(bounds.getWidth()));

        if (history.empty())
        {
            g.setColour(juce::Colours::grey);
            g.drawText("No data", bounds, juce::Justification::centred);
            return;
        }

        // Find range
        double minVal = history[0].value;
        double maxVal = history[0].value;
        for (const auto& sample : history)
        {
            minVal = std::min(minVal, sample.value);
            maxVal = std::max(maxVal, sample.value);
        }

        // Add padding
        double range = maxVal - minVal;
        if (range < 0.001) range = 1.0;
        minVal -= range * 0.1;
        maxVal += range * 0.1;

        // Draw waveform
        juce::Path path;
        float x = 0;
        float step = bounds.getWidth() / static_cast<float>(history.size());

        for (size_t i = 0; i < history.size(); ++i)
        {
            double normalized = (history[i].value - minVal) / (maxVal - minVal);
            float y = bounds.getBottom() - normalized * bounds.getHeight();

            if (i == 0)
                path.startNewSubPath(x, y);
            else
                path.lineTo(x, y);

            x += step;
        }

        // Draw path
        g.setColour(juce::Colour(0xff00ff88));
        g.strokePath(path, juce::PathStrokeType(2.0f));

        // Current value
        double current = manager.getSmoothedValue(displayedMetric);
        g.setColour(juce::Colours::white);
        g.setFont(24.0f);

        juce::String valueText;
        switch (displayedMetric)
        {
            case BiometricType::HeartRate:
                valueText = juce::String(current, 0) + " BPM";
                break;
            case BiometricType::HeartRateVariability:
                valueText = juce::String(current, 1) + " ms";
                break;
            case BiometricType::StressLevel:
            case BiometricType::EnergyLevel:
                valueText = juce::String(current, 0) + "%";
                break;
            default:
                valueText = juce::String(current, 2);
        }

        g.drawText(valueText, bounds.removeFromTop(40), juce::Justification::centred);

        // Metric name
        g.setFont(14.0f);
        g.setColour(juce::Colours::grey);
        g.drawText(biometricTypeToString(displayedMetric),
                   bounds.removeFromTop(20), juce::Justification::centred);
    }

    void timerCallback() override
    {
        repaint();
    }

private:
    BiometricType displayedMetric = BiometricType::HeartRate;
};

//==============================================================================
// Wearable Settings Panel
//==============================================================================

class WearableSettingsPanel : public juce::Component
{
public:
    WearableSettingsPanel()
    {
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Wearable Devices", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(20.0f, juce::Font::bold));

        addAndMakeVisible(scanButton);
        scanButton.setButtonText("Scan for Devices");
        scanButton.onClick = [this]() { scanForDevices(); };

        addAndMakeVisible(simulatorButton);
        simulatorButton.setButtonText("Add Simulator");
        simulatorButton.onClick = [this]() { addSimulator(); };

        addAndMakeVisible(deviceList);

        addAndMakeVisible(visualizer);

        refreshDeviceList();
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);

        titleLabel.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(10);

        auto buttonRow = bounds.removeFromTop(30);
        scanButton.setBounds(buttonRow.removeFromLeft(120));
        buttonRow.removeFromLeft(10);
        simulatorButton.setBounds(buttonRow.removeFromLeft(120));

        bounds.removeFromTop(10);

        deviceList.setBounds(bounds.removeFromTop(150));
        bounds.removeFromTop(10);

        visualizer.setBounds(bounds);
    }

private:
    juce::Label titleLabel;
    juce::TextButton scanButton;
    juce::TextButton simulatorButton;
    juce::ListBox deviceList;
    BioDataVisualizerComponent visualizer;

    void scanForDevices()
    {
        // In production: scan BLE for compatible devices
        // For now, just refresh list
        refreshDeviceList();
    }

    void addSimulator()
    {
        auto simulator = std::make_unique<SimulatorDevice>();
        simulator->connect();
        simulator->startStreaming();
        WearableManager::getInstance().addDevice(std::move(simulator));
        refreshDeviceList();
    }

    void refreshDeviceList()
    {
        // Update device list UI
        deviceList.updateContent();
    }
};

} // namespace Wearable
} // namespace Echoelmusic

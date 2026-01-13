/**
 * EchoelCore Bridge - Objective-C++ Implementation
 *
 * Wraps C++ EchoelCore classes for Swift consumption.
 * All C++ objects are managed via unique_ptr to ensure proper cleanup.
 *
 * MIT License - Echoelmusic 2026
 */

#import "EchoelCoreBridge.h"

// C++ includes
#include "../EchoelCore.h"
#include <memory>

using namespace EchoelCore;
using namespace EchoelCore::Lambda;
using namespace EchoelCore::MCP;
using namespace EchoelCore::WebXR;
using namespace EchoelCore::Photonic;

//==============================================================================
// ECLambdaEvent Implementation
//==============================================================================

@implementation ECLambdaEvent
@end

//==============================================================================
// ECLambdaStats Implementation
//==============================================================================

@implementation ECLambdaStats
@end

//==============================================================================
// ECBioState Implementation
//==============================================================================

@implementation ECBioState {
    float _hrv;
    float _coherence;
    float _heartRate;
    float _breathPhase;
    float _breathRate;
    float _relaxation;
    float _arousal;
}

- (instancetype)initWithHRV:(float)hrv
                  coherence:(float)coherence
                  heartRate:(float)heartRate
                 breathPhase:(float)breathPhase
                  breathRate:(float)breathRate
                  relaxation:(float)relaxation
                     arousal:(float)arousal {
    self = [super init];
    if (self) {
        _hrv = hrv;
        _coherence = coherence;
        _heartRate = heartRate;
        _breathPhase = breathPhase;
        _breathRate = breathRate;
        _relaxation = relaxation;
        _arousal = arousal;
    }
    return self;
}

- (float)hrv { return _hrv; }
- (float)coherence { return _coherence; }
- (float)heartRate { return _heartRate; }
- (float)breathPhase { return _breathPhase; }
- (float)breathRate { return _breathRate; }
- (float)relaxation { return _relaxation; }
- (float)arousal { return _arousal; }

@end

//==============================================================================
// ECPhotonicStats Implementation
//==============================================================================

@implementation ECPhotonicStats
@end

//==============================================================================
// EchoelCoreBridge Implementation
//==============================================================================

@interface EchoelCoreBridge () {
    std::unique_ptr<LambdaLoop> _lambdaLoop;
    ECEventCallback _eventCallback;
}
@end

@implementation EchoelCoreBridge

- (instancetype)init {
    self = [super init];
    if (self) {
        _lambdaLoop = std::make_unique<LambdaLoop>();
    }
    return self;
}

- (void)dealloc {
    if (_lambdaLoop && _lambdaLoop->isRunning()) {
        _lambdaLoop->shutdown();
    }
}

//------------------------------------------------------------------------------
// Lifecycle
//------------------------------------------------------------------------------

- (BOOL)initialize {
    if (!_lambdaLoop) return NO;

    // Set up event callback bridge
    __weak typeof(self) weakSelf = self;
    _lambdaLoop->setEventCallback([weakSelf](const LambdaEvent& event) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf->_eventCallback) {
            ECLambdaEvent *ecEvent = [[ECLambdaEvent alloc] init];
            ecEvent.type = static_cast<ECLambdaEventType>(event.type);
            ecEvent.timestamp = event.timestamp;
            ecEvent.sourceId = event.sourceId;
            ecEvent.value1 = event.value1;
            ecEvent.value2 = event.value2;
            ecEvent.value3 = event.value3;
            ecEvent.value4 = event.value4;

            dispatch_async(dispatch_get_main_queue(), ^{
                strongSelf->_eventCallback(ecEvent);
            });
        }
    });

    return _lambdaLoop->initialize();
}

- (void)shutdown {
    if (_lambdaLoop) {
        _lambdaLoop->shutdown();
    }
}

- (void)start {
    if (_lambdaLoop) {
        _lambdaLoop->start();
    }
}

- (void)stop {
    if (_lambdaLoop) {
        _lambdaLoop->stop();
    }
}

- (BOOL)isRunning {
    return _lambdaLoop ? _lambdaLoop->isRunning() : NO;
}

//------------------------------------------------------------------------------
// Control Loop
//------------------------------------------------------------------------------

- (void)tick {
    if (_lambdaLoop) {
        _lambdaLoop->tick();
    }
}

//------------------------------------------------------------------------------
// Bio Data
//------------------------------------------------------------------------------

- (void)updateBioDataWithHRV:(float)hrv
                   coherence:(float)coherence
                   heartRate:(float)heartRate
                  breathPhase:(float)breathPhase {
    if (_lambdaLoop) {
        _lambdaLoop->updateBioData(hrv, coherence, heartRate, breathPhase);
    }
}

- (ECBioState *)getBioState {
    if (!_lambdaLoop) return nil;

    const BioState& bio = _lambdaLoop->getBioState();
    return [[ECBioState alloc] initWithHRV:bio.getHRV()
                                 coherence:bio.getCoherence()
                                 heartRate:bio.getHeartRate()
                                breathPhase:bio.getBreathPhase()
                                 breathRate:bio.getBreathRate()
                                 relaxation:bio.getRelaxation()
                                    arousal:bio.getArousal()];
}

//------------------------------------------------------------------------------
// Lambda State
//------------------------------------------------------------------------------

- (ECLambdaState)state {
    if (!_lambdaLoop) return ECLambdaStateDormant;
    return static_cast<ECLambdaState>(_lambdaLoop->getState());
}

- (float)lambdaScore {
    return _lambdaLoop ? _lambdaLoop->getLambdaScore() : 0.0f;
}

- (ECLambdaStats *)getStats {
    if (!_lambdaLoop) return nil;

    auto stats = _lambdaLoop->getStats();
    ECLambdaStats *ecStats = [[ECLambdaStats alloc] init];
    ecStats.state = static_cast<ECLambdaState>(stats.state);
    ecStats.lambdaScore = stats.lambdaScore;
    ecStats.tickCount = stats.tickCount;
    ecStats.avgTickTimeMs = stats.avgTickTimeMs;
    ecStats.numSubsystems = stats.numSubsystems;
    ecStats.readySubsystems = stats.readySubsystems;
    ecStats.systemLoad = stats.systemLoad;
    ecStats.coherenceTrend = stats.coherenceTrend;
    return ecStats;
}

+ (NSString *)stateNameForState:(ECLambdaState)state {
    switch (state) {
        case ECLambdaStateDormant: return @"Dormant";
        case ECLambdaStateInitializing: return @"Initializing";
        case ECLambdaStateCalibrating: return @"Calibrating";
        case ECLambdaStateActive: return @"Active";
        case ECLambdaStateFlowing: return @"Flowing";
        case ECLambdaStateTranscendent: return @"Transcendent (λ∞)";
        case ECLambdaStateDegrading: return @"Degrading";
        case ECLambdaStateShuttingDown: return @"Shutting Down";
        default: return @"Unknown";
    }
}

//------------------------------------------------------------------------------
// MCP Server
//------------------------------------------------------------------------------

- (NSString *)handleMCPMessage:(NSString *)jsonMessage {
    if (!_lambdaLoop) return @"{\"error\": \"Not initialized\"}";

    MCPBioServer* server = _lambdaLoop->getMcpServer();
    if (!server) return @"{\"error\": \"MCP server not available\"}";

    std::string response = server->handleMessage([jsonMessage UTF8String]);
    return [NSString stringWithUTF8String:response.c_str()];
}

//------------------------------------------------------------------------------
// WebXR Bridge
//------------------------------------------------------------------------------

- (BOOL)startXRSession:(ECXRSessionType)type {
    if (!_lambdaLoop) return NO;

    WebXRAudioBridge* bridge = _lambdaLoop->getWebXRBridge();
    if (!bridge) return NO;

    return bridge->startSession(static_cast<XRSessionType>(type));
}

- (void)endXRSession {
    if (!_lambdaLoop) return;

    WebXRAudioBridge* bridge = _lambdaLoop->getWebXRBridge();
    if (bridge) {
        bridge->endSession();
    }
}

- (BOOL)isXRSessionActive {
    if (!_lambdaLoop) return NO;

    WebXRAudioBridge* bridge = _lambdaLoop->getWebXRBridge();
    return bridge ? bridge->isSessionActive() : NO;
}

- (NSUInteger)spatialSourceCount {
    if (!_lambdaLoop) return 0;

    WebXRAudioBridge* bridge = _lambdaLoop->getWebXRBridge();
    return bridge ? bridge->getSourceCount() : 0;
}

- (uint32_t)addSpatialSourceAtX:(float)x y:(float)y z:(float)z {
    if (!_lambdaLoop) return 0;

    WebXRAudioBridge* bridge = _lambdaLoop->getWebXRBridge();
    if (!bridge) return 0;

    SpatialAudioSource source;
    source.position = Vec3(x, y, z);
    source.bioReactive = true;
    return bridge->addSource(source);
}

- (BOOL)removeSpatialSource:(uint32_t)sourceId {
    if (!_lambdaLoop) return NO;

    WebXRAudioBridge* bridge = _lambdaLoop->getWebXRBridge();
    return bridge ? bridge->removeSource(sourceId) : NO;
}

- (void)processSpatialAudioLeft:(float *)outputL
                          right:(float *)outputR
                         frames:(NSUInteger)numFrames {
    if (!_lambdaLoop) return;

    WebXRAudioBridge* bridge = _lambdaLoop->getWebXRBridge();
    if (bridge) {
        bridge->processAudio(outputL, outputR, numFrames);
    }
}

//------------------------------------------------------------------------------
// Photonic Processing
//------------------------------------------------------------------------------

- (ECPhotonicStats *)getPhotonicStats {
    if (!_lambdaLoop) return nil;

    PhotonicInterconnect* interconnect = _lambdaLoop->getPhotonicInterconnect();
    if (!interconnect) return nil;

    auto stats = interconnect->getStats();
    ECPhotonicStats *ecStats = [[ECPhotonicStats alloc] init];
    ecStats.processorType = static_cast<NSInteger>(stats.processorType);
    ecStats.latencyNs = stats.latencyNs;
    ecStats.throughputOps = stats.throughputOps;
    ecStats.activeChannels = stats.activeChannels;
    ecStats.coherenceLevel = stats.coherenceLevel;
    return ecStats;
}

- (void)processPhotonicAudioInput:(const float *)input
                           output:(float *)output
                            size:(NSUInteger)size {
    if (!_lambdaLoop) return;

    PhotonicInterconnect* interconnect = _lambdaLoop->getPhotonicInterconnect();
    if (interconnect) {
        interconnect->processBioAudio(input, output, size);
    }
}

- (void)computeSpectrumInput:(const float *)input
                   magnitude:(float *)magnitude
                        size:(NSUInteger)size {
    if (!_lambdaLoop) return;

    PhotonicInterconnect* interconnect = _lambdaLoop->getPhotonicInterconnect();
    if (interconnect) {
        interconnect->computeSpectrum(input, magnitude, size);
    }
}

//------------------------------------------------------------------------------
// Events
//------------------------------------------------------------------------------

- (void)setEventCallback:(ECEventCallback)callback {
    _eventCallback = [callback copy];
}

- (void)pushEventWithType:(ECLambdaEventType)type
                 sourceId:(uint32_t)sourceId
                   value1:(float)v1
                   value2:(float)v2
                   value3:(float)v3
                   value4:(float)v4 {
    if (!_lambdaLoop) return;

    LambdaEvent event;
    event.type = static_cast<LambdaEventType>(type);
    event.timestamp = 0; // Will be set by LambdaLoop
    event.sourceId = sourceId;
    event.value1 = v1;
    event.value2 = v2;
    event.value3 = v3;
    event.value4 = v4;

    _lambdaLoop->pushEvent(event);
}

@end

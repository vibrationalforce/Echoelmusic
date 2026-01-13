/**
 * EchoelCore Bridge - Swift ↔ C++ Interoperability Layer
 *
 * This Objective-C++ header provides the bridge between Swift code
 * and the C++ EchoelCore framework. It wraps all C++ classes in
 * Objective-C objects that Swift can directly consume.
 *
 * Usage from Swift:
 *   let bridge = EchoelCoreBridge()
 *   bridge.initialize()
 *   bridge.updateBioData(hrv: 0.7, coherence: 0.8, heartRate: 72, breathPhase: 0.5)
 *   bridge.tick() // Call at 60Hz
 *
 * MIT License - Echoelmusic 2026
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//==============================================================================
// Lambda State Enum (mirrors C++ LambdaState)
//==============================================================================

typedef NS_ENUM(NSInteger, ECLambdaState) {
    ECLambdaStateDormant = 0,
    ECLambdaStateInitializing,
    ECLambdaStateCalibrating,
    ECLambdaStateActive,
    ECLambdaStateFlowing,
    ECLambdaStateTranscendent,
    ECLambdaStateDegrading,
    ECLambdaStateShuttingDown
};

//==============================================================================
// XR Session Type (mirrors C++ XRSessionType)
//==============================================================================

typedef NS_ENUM(NSInteger, ECXRSessionType) {
    ECXRSessionTypeNone = 0,
    ECXRSessionTypeImmersiveVR,
    ECXRSessionTypeImmersiveAR,
    ECXRSessionTypeInline
};

//==============================================================================
// Lambda Event (mirrors C++ LambdaEvent)
//==============================================================================

typedef NS_ENUM(NSInteger, ECLambdaEventType) {
    ECLambdaEventTypeBioUpdate = 0,
    ECLambdaEventTypeCoherenceChanged,
    ECLambdaEventTypeHeartbeatDetected,
    ECLambdaEventTypeBreathCycleComplete,
    ECLambdaEventTypeStateTransition,
    ECLambdaEventTypeSubsystemConnected,
    ECLambdaEventTypeSubsystemDisconnected,
    ECLambdaEventTypePerformanceWarning,
    ECLambdaEventTypeMCPMessage,
    ECLambdaEventTypeXRSessionStart,
    ECLambdaEventTypeXRSessionEnd,
    ECLambdaEventTypePhotonicChannelReady,
    ECLambdaEventTypeSessionStart,
    ECLambdaEventTypeSessionEnd,
    ECLambdaEventTypePresetLoaded,
    ECLambdaEventTypeParameterChanged
};

@interface ECLambdaEvent : NSObject
@property (nonatomic, assign) ECLambdaEventType type;
@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) uint32_t sourceId;
@property (nonatomic, assign) float value1;
@property (nonatomic, assign) float value2;
@property (nonatomic, assign) float value3;
@property (nonatomic, assign) float value4;
@end

//==============================================================================
// Lambda Stats (mirrors C++ LambdaLoop::Stats)
//==============================================================================

@interface ECLambdaStats : NSObject
@property (nonatomic, assign) ECLambdaState state;
@property (nonatomic, assign) float lambdaScore;
@property (nonatomic, assign) uint64_t tickCount;
@property (nonatomic, assign) double avgTickTimeMs;
@property (nonatomic, assign) NSUInteger numSubsystems;
@property (nonatomic, assign) NSUInteger readySubsystems;
@property (nonatomic, assign) float systemLoad;
@property (nonatomic, assign) float coherenceTrend;
@end

//==============================================================================
// Bio State (read-only snapshot from C++)
//==============================================================================

@interface ECBioState : NSObject
@property (nonatomic, assign, readonly) float hrv;
@property (nonatomic, assign, readonly) float coherence;
@property (nonatomic, assign, readonly) float heartRate;
@property (nonatomic, assign, readonly) float breathPhase;
@property (nonatomic, assign, readonly) float breathRate;
@property (nonatomic, assign, readonly) float relaxation;
@property (nonatomic, assign, readonly) float arousal;
@end

//==============================================================================
// Photonic Stats
//==============================================================================

@interface ECPhotonicStats : NSObject
@property (nonatomic, assign) NSInteger processorType; // 0=Electronic, 1=FPGA, 2=Silicon, 3=Quantum
@property (nonatomic, assign) double latencyNs;
@property (nonatomic, assign) double throughputOps;
@property (nonatomic, assign) NSUInteger activeChannels;
@property (nonatomic, assign) float coherenceLevel;
@end

//==============================================================================
// Event Callback Block
//==============================================================================

typedef void (^ECEventCallback)(ECLambdaEvent *event);

//==============================================================================
// EchoelCore Bridge - Main Interface
//==============================================================================

@interface EchoelCoreBridge : NSObject

//------------------------------------------------------------------------------
// Lifecycle
//------------------------------------------------------------------------------

/// Initialize the Lambda Loop and all subsystems
- (BOOL)initialize;

/// Shutdown gracefully
- (void)shutdown;

/// Start the control loop
- (void)start;

/// Stop the control loop
- (void)stop;

/// Check if running
@property (nonatomic, assign, readonly) BOOL isRunning;

//------------------------------------------------------------------------------
// Control Loop (call at 60Hz from CADisplayLink or Timer)
//------------------------------------------------------------------------------

/// Process one tick of the Lambda Loop
- (void)tick;

//------------------------------------------------------------------------------
// Bio Data Input (call from HealthKit/sensor callbacks)
//------------------------------------------------------------------------------

/// Update bio-reactive state (thread-safe)
- (void)updateBioDataWithHRV:(float)hrv
                   coherence:(float)coherence
                   heartRate:(float)heartRate
                  breathPhase:(float)breathPhase;

/// Get current bio state snapshot
- (ECBioState *)getBioState;

//------------------------------------------------------------------------------
// Lambda State
//------------------------------------------------------------------------------

/// Get current Lambda state
@property (nonatomic, assign, readonly) ECLambdaState state;

/// Get Lambda score (0-1 unified coherence metric)
@property (nonatomic, assign, readonly) float lambdaScore;

/// Get full stats
- (ECLambdaStats *)getStats;

/// Get state name as string
+ (NSString *)stateNameForState:(ECLambdaState)state;

//------------------------------------------------------------------------------
// MCP Server (AI Agent Integration)
//------------------------------------------------------------------------------

/// Handle incoming MCP JSON-RPC message, returns response JSON
- (NSString *)handleMCPMessage:(NSString *)jsonMessage;

//------------------------------------------------------------------------------
// WebXR Bridge
//------------------------------------------------------------------------------

/// Start an XR session
- (BOOL)startXRSession:(ECXRSessionType)type;

/// End current XR session
- (void)endXRSession;

/// Check if XR session is active
@property (nonatomic, assign, readonly) BOOL isXRSessionActive;

/// Get number of spatial audio sources
@property (nonatomic, assign, readonly) NSUInteger spatialSourceCount;

/// Add a spatial audio source, returns source ID (0 on failure)
- (uint32_t)addSpatialSourceAtX:(float)x y:(float)y z:(float)z;

/// Remove a spatial source
- (BOOL)removeSpatialSource:(uint32_t)sourceId;

/// Process spatial audio (call from audio render callback)
- (void)processSpatialAudioLeft:(float *)outputL
                          right:(float *)outputR
                         frames:(NSUInteger)numFrames;

//------------------------------------------------------------------------------
// Photonic Processing
//------------------------------------------------------------------------------

/// Get photonic processor stats
- (ECPhotonicStats *)getPhotonicStats;

/// Process bio-reactive audio through photonic pipeline
- (void)processPhotonicAudioInput:(const float *)input
                           output:(float *)output
                            size:(NSUInteger)size;

/// Compute FFT spectrum for visualization
- (void)computeSpectrumInput:(const float *)input
                   magnitude:(float *)magnitude
                        size:(NSUInteger)size;

//------------------------------------------------------------------------------
// Events
//------------------------------------------------------------------------------

/// Set callback for Lambda events
- (void)setEventCallback:(ECEventCallback)callback;

/// Push a custom event
- (void)pushEventWithType:(ECLambdaEventType)type
                 sourceId:(uint32_t)sourceId
                   value1:(float)v1
                   value2:(float)v2
                   value3:(float)v3
                   value4:(float)v4;

@end

NS_ASSUME_NONNULL_END

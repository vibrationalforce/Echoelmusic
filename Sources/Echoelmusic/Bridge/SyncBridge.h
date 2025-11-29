//
//  SyncBridge.h
//  Echoelmusic
//
//  Objective-C wrapper for EchoelSync C++ class
//  Enables Swift to use universal sync technology
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Sync protocol types
typedef NS_ENUM(NSInteger, SyncProtocol) {
    SyncProtocolEchoelSyncNative = 0,
    SyncProtocolAbletonLink,
    SyncProtocolMIDIClock,
    SyncProtocolMIDITimeCode,
    SyncProtocolLinearTimeCode,
    SyncProtocolOSC,
    SyncProtocolAuto
};

/// Sync role types
typedef NS_ENUM(NSInteger, SyncRole) {
    SyncRoleMaster = 0,
    SyncRoleSlave,
    SyncRolePeer,
    SyncRoleAdaptive
};

/// Callback for tempo changes
typedef void (^TempoChangedCallback)(double bpm);

/// Callback for peer connections
typedef void (^PeerConnectionCallback)(NSString *peerName, BOOL connected);

/**
 * SyncBridge - Swift-accessible wrapper for C++ EchoelSync
 *
 * This class provides tempo synchronization across devices and applications.
 * Supports Ableton Link, MIDI Clock, MTC, LTC, and native EchoelSync protocol.
 *
 * Usage in Swift:
 * ```swift
 * let sync = SyncBridge()
 * sync.startDiscovery()
 * sync.setTempo(120.0)
 * sync.play()
 * ```
 */
@interface SyncBridge : NSObject

// MARK: - Tempo & Transport

/// Current tempo in BPM
@property (nonatomic) double tempo;

/// Current beat position
@property (nonatomic, readonly) double currentBeat;

/// Beat phase (0.0 - 1.0 within current beat)
@property (nonatomic, readonly) double beatPhase;

/// Whether playback is active
@property (nonatomic, readonly) BOOL isPlaying;

/// Current sync role
@property (nonatomic) SyncRole syncRole;

/// Preferred sync protocol
@property (nonatomic) SyncProtocol preferredProtocol;

// MARK: - Transport Control

/// Start playback (broadcasts to all peers)
- (void)play;

/// Stop playback
- (void)stop;

/// Set time signature
/// @param numerator Top number (e.g., 4 for 4/4)
/// @param denominator Bottom number (e.g., 4 for 4/4)
- (void)setTimeSignatureNumerator:(double)numerator denominator:(double)denominator;

// MARK: - Network Discovery

/// Start automatic discovery of sync sources
- (void)startDiscovery;

/// Stop discovery
- (void)stopDiscovery;

/// Get list of discovered sync sources
- (NSArray<NSString *> *)getAvailableSources;

/// Number of connected peers
@property (nonatomic, readonly) int numConnectedPeers;

// MARK: - Server Mode

/// Start as EchoelSync server
/// @param port UDP port (default: 20738)
/// @return YES if server started successfully
- (BOOL)startServerOnPort:(int)port;

/// Stop server
- (void)stopServer;

/// Whether server is running
@property (nonatomic, readonly) BOOL isServerRunning;

/// Server name (visible on network)
@property (nonatomic, copy) NSString *serverName;

// MARK: - Sync Quality

/// Get sync quality (0.0 = poor, 1.0 = perfect)
@property (nonatomic, readonly) float syncQuality;

/// Get latency to current sync source (ms)
@property (nonatomic, readonly) float latencyMs;

// MARK: - Callbacks

/// Set callback for tempo changes
- (void)setTempoChangedCallback:(TempoChangedCallback)callback;

/// Set callback for peer connections
- (void)setPeerConnectionCallback:(PeerConnectionCallback)callback;

// MARK: - Session State (for Audio Thread)

/// Capture current session state (thread-safe)
/// @return Dictionary with tempo, beat, phase, isPlaying, numPeers
- (NSDictionary *)captureSessionState;

/// Get beat at specific sample time
/// @param sampleTime Sample position
/// @param sampleRate Audio sample rate
/// @return Beat position at that sample
- (double)beatAtSampleTime:(int64_t)sampleTime sampleRate:(double)sampleRate;

// MARK: - Diagnostics

/// Get detailed diagnostics string
- (NSString *)getDiagnosticsString;

@end

NS_ASSUME_NONNULL_END

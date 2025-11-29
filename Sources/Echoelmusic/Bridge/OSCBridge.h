//
//  OSCBridge.h
//  Echoelmusic
//
//  Objective-C wrapper for OSCManager C++ class
//  Enables Swift to communicate with JUCE-based OSC implementation
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Callback type for received OSC messages
typedef void (^OSCMessageCallback)(NSString *address, NSArray *arguments);

/// Callback type for connection status changes
typedef void (^OSCConnectionCallback)(BOOL connected, NSString *endpoint);

/**
 * OSCBridge - Swift-accessible wrapper for C++ OSCManager
 *
 * This class provides a clean Objective-C interface to the JUCE-based
 * OSCManager, allowing Swift code to send and receive OSC messages
 * for communication between iOS and desktop applications.
 *
 * Usage in Swift:
 * ```swift
 * let osc = OSCBridge()
 * osc.startReceiver(port: 9000)
 * osc.addSender(name: "Desktop", host: "192.168.1.100", port: 8000)
 * osc.sendFloat("/bio/hrv/coherence", value: 75.0, sender: "Desktop")
 * ```
 */
@interface OSCBridge : NSObject

// MARK: - Connection Management

/// Start OSC receiver on specified UDP port
/// @param port The UDP port to listen on (default: 9000)
/// @return YES if receiver started successfully
- (BOOL)startReceiverOnPort:(int)port;

/// Stop OSC receiver
- (void)stopReceiver;

/// Add an OSC sender endpoint
/// @param name Unique name for this sender
/// @param host IP address or hostname
/// @param port UDP port
- (void)addSenderWithName:(NSString *)name host:(NSString *)host port:(int)port;

/// Remove an OSC sender
/// @param name Name of sender to remove
- (void)removeSenderWithName:(NSString *)name;

/// Check if receiver is active
@property (nonatomic, readonly) BOOL isReceiverActive;

/// Get receiver port
@property (nonatomic, readonly) int receiverPort;

// MARK: - Sending OSC Messages

/// Send a float value
/// @param address OSC address (e.g., "/bio/hrv/coherence")
/// @param value Float value to send
/// @param senderName Name of sender to use (nil = all senders)
- (void)sendFloat:(NSString *)address value:(float)value sender:(nullable NSString *)senderName;

/// Send an integer value
/// @param address OSC address
/// @param value Integer value to send
/// @param senderName Name of sender (nil = all)
- (void)sendInt:(NSString *)address value:(int)value sender:(nullable NSString *)senderName;

/// Send a string value
/// @param address OSC address
/// @param value String value to send
/// @param senderName Name of sender (nil = all)
- (void)sendString:(NSString *)address value:(NSString *)value sender:(nullable NSString *)senderName;

// MARK: - Receiving OSC Messages

/// Set callback for received OSC messages
/// @param callback Block called when OSC message is received
- (void)setMessageCallback:(OSCMessageCallback)callback;

/// Set callback for connection status changes
/// @param callback Block called when connection status changes
- (void)setConnectionCallback:(OSCConnectionCallback)callback;

// MARK: - Quick Setup

/// Configure for TouchOSC
/// @param ipAddress IP address of TouchOSC device
- (void)setupTouchOSC:(NSString *)ipAddress;

/// Configure for Resolume Arena
/// @param ipAddress IP address of Resolume computer
- (void)setupResolume:(NSString *)ipAddress;

/// Configure for TouchDesigner
/// @param ipAddress IP address of TouchDesigner computer
- (void)setupTouchDesigner:(NSString *)ipAddress;

// MARK: - Bio-Reactive Shortcuts

/// Send HRV coherence value (convenience method)
/// @param coherence Coherence value 0-100
- (void)sendHRVCoherence:(double)coherence;

/// Send heart rate value (convenience method)
/// @param bpm Heart rate in beats per minute
- (void)sendHeartRate:(double)bpm;

/// Send face expression values (convenience method)
/// @param jawOpen Jaw openness 0-1
/// @param smile Smile intensity 0-1
/// @param eyebrowRaise Eyebrow raise 0-1
- (void)sendFaceExpressionJawOpen:(float)jawOpen smile:(float)smile eyebrowRaise:(float)eyebrowRaise;

@end

NS_ASSUME_NONNULL_END

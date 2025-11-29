//
//  OSCBridge.mm
//  Echoelmusic
//
//  Objective-C++ implementation of OSCBridge
//  Wraps C++ OSCManager for Swift interoperability
//

#import "OSCBridge.h"

// For standalone iOS builds without JUCE, use a mock implementation
// When building as plugin with JUCE, include the real OSCManager
#if defined(JUCE_AVAILABLE) && JUCE_AVAILABLE
    #include "../../Hardware/OSCManager.h"
    #define USE_JUCE_OSC 1
#else
    #define USE_JUCE_OSC 0
#endif

#import <Network/Network.h>

@interface OSCBridge ()
{
#if USE_JUCE_OSC
    std::unique_ptr<Echoelmusic::OSCManager> _oscManager;
#endif
    nw_connection_t _udpConnection;
    nw_listener_t _udpListener;
    dispatch_queue_t _oscQueue;
}

@property (nonatomic, copy) OSCMessageCallback messageCallback;
@property (nonatomic, copy) OSCConnectionCallback connectionCallback;
@property (nonatomic, readwrite) BOOL isReceiverActive;
@property (nonatomic, readwrite) int receiverPort;

@end

@implementation OSCBridge

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _oscQueue = dispatch_queue_create("com.echoelmusic.osc", DISPATCH_QUEUE_SERIAL);
        _isReceiverActive = NO;
        _receiverPort = 0;

#if USE_JUCE_OSC
        _oscManager = std::make_unique<Echoelmusic::OSCManager>();
#endif

        NSLog(@"[OSCBridge] Initialized");
    }
    return self;
}

- (void)dealloc
{
    [self stopReceiver];

#if USE_JUCE_OSC
    _oscManager.reset();
#endif
}

// MARK: - Connection Management

- (BOOL)startReceiverOnPort:(int)port
{
#if USE_JUCE_OSC
    BOOL success = _oscManager->startReceiver(port);
    if (success)
    {
        _isReceiverActive = YES;
        _receiverPort = port;
        NSLog(@"[OSCBridge] Receiver started on port %d", port);
    }
    return success;
#else
    // Native Network.framework implementation for iOS
    NSString *portString = [NSString stringWithFormat:@"%d", port];

    nw_parameters_t parameters = nw_parameters_create_secure_udp(
        NW_PARAMETERS_DISABLE_PROTOCOL,
        NW_PARAMETERS_DEFAULT_CONFIGURATION
    );

    _udpListener = nw_listener_create_with_port([portString UTF8String], parameters);

    nw_listener_set_queue(_udpListener, _oscQueue);

    __weak typeof(self) weakSelf = self;
    nw_listener_set_new_connection_handler(_udpListener, ^(nw_connection_t connection) {
        [weakSelf handleNewConnection:connection];
    });

    nw_listener_set_state_changed_handler(_udpListener, ^(nw_listener_state_t state, nw_error_t error) {
        if (state == nw_listener_state_ready)
        {
            weakSelf.isReceiverActive = YES;
            weakSelf.receiverPort = port;
            NSLog(@"[OSCBridge] UDP listener ready on port %d", port);
        }
        else if (state == nw_listener_state_failed)
        {
            NSLog(@"[OSCBridge] UDP listener failed");
            weakSelf.isReceiverActive = NO;
        }
    });

    nw_listener_start(_udpListener);

    return YES;
#endif
}

- (void)stopReceiver
{
#if USE_JUCE_OSC
    _oscManager->stopReceiver();
#else
    if (_udpListener)
    {
        nw_listener_cancel(_udpListener);
        _udpListener = nil;
    }
#endif

    _isReceiverActive = NO;
    _receiverPort = 0;
    NSLog(@"[OSCBridge] Receiver stopped");
}

- (void)addSenderWithName:(NSString *)name host:(NSString *)host port:(int)port
{
#if USE_JUCE_OSC
    _oscManager->addSender(juce::String([name UTF8String]),
                          juce::String([host UTF8String]),
                          port);
#else
    // Store sender info for native implementation
    NSLog(@"[OSCBridge] Added sender: %@ -> %@:%d", name, host, port);
#endif

    if (_connectionCallback)
    {
        _connectionCallback(YES, [NSString stringWithFormat:@"%@:%d", host, port]);
    }
}

- (void)removeSenderWithName:(NSString *)name
{
#if USE_JUCE_OSC
    _oscManager->removeSender(juce::String([name UTF8String]));
#endif
    NSLog(@"[OSCBridge] Removed sender: %@", name);
}

// MARK: - Sending OSC Messages

- (void)sendFloat:(NSString *)address value:(float)value sender:(NSString *)senderName
{
#if USE_JUCE_OSC
    juce::String addr([address UTF8String]);
    juce::String sender = senderName ? juce::String([senderName UTF8String]) : juce::String();
    _oscManager->sendFloat(addr, value, sender);
#else
    [self sendOSCMessage:address withFloat:value];
#endif
}

- (void)sendInt:(NSString *)address value:(int)value sender:(NSString *)senderName
{
#if USE_JUCE_OSC
    juce::String addr([address UTF8String]);
    juce::String sender = senderName ? juce::String([senderName UTF8String]) : juce::String();
    _oscManager->sendInt(addr, value, sender);
#else
    [self sendOSCMessage:address withInt:value];
#endif
}

- (void)sendString:(NSString *)address value:(NSString *)value sender:(NSString *)senderName
{
#if USE_JUCE_OSC
    juce::String addr([address UTF8String]);
    juce::String val([value UTF8String]);
    juce::String sender = senderName ? juce::String([senderName UTF8String]) : juce::String();
    _oscManager->sendString(addr, val, sender);
#else
    [self sendOSCMessage:address withString:value];
#endif
}

// MARK: - Callbacks

- (void)setMessageCallback:(OSCMessageCallback)callback
{
    _messageCallback = [callback copy];

#if USE_JUCE_OSC
    __weak typeof(self) weakSelf = self;
    _oscManager->onMessageReceived = [weakSelf](const juce::OSCMessage& message)
    {
        if (weakSelf.messageCallback)
        {
            NSString *address = [NSString stringWithUTF8String:message.getAddressPattern().toString().toRawUTF8()];
            NSMutableArray *args = [NSMutableArray array];

            for (int i = 0; i < message.size(); ++i)
            {
                if (message[i].isFloat32())
                    [args addObject:@(message[i].getFloat32())];
                else if (message[i].isInt32())
                    [args addObject:@(message[i].getInt32())];
                else if (message[i].isString())
                    [args addObject:[NSString stringWithUTF8String:message[i].getString().toRawUTF8()]];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.messageCallback(address, args);
            });
        }
    };
#endif
}

- (void)setConnectionCallback:(OSCConnectionCallback)callback
{
    _connectionCallback = [callback copy];
}

// MARK: - Quick Setup

- (void)setupTouchOSC:(NSString *)ipAddress
{
#if USE_JUCE_OSC
    _oscManager->setupTouchOSC(juce::String([ipAddress UTF8String]));
#else
    [self startReceiverOnPort:8000];
    [self addSenderWithName:@"TouchOSC" host:ipAddress port:9000];
#endif
}

- (void)setupResolume:(NSString *)ipAddress
{
#if USE_JUCE_OSC
    _oscManager->setupResolume(juce::String([ipAddress UTF8String]));
#else
    [self startReceiverOnPort:7001];
    [self addSenderWithName:@"Resolume" host:ipAddress port:7000];
#endif
}

- (void)setupTouchDesigner:(NSString *)ipAddress
{
#if USE_JUCE_OSC
    _oscManager->setupTouchDesigner(juce::String([ipAddress UTF8String]));
#else
    [self startReceiverOnPort:7001];
    [self addSenderWithName:@"TouchDesigner" host:ipAddress port:7000];
#endif
}

// MARK: - Bio-Reactive Shortcuts

- (void)sendHRVCoherence:(double)coherence
{
    [self sendFloat:@"/bio/hrv/coherence" value:(float)coherence sender:nil];
}

- (void)sendHeartRate:(double)bpm
{
    [self sendFloat:@"/bio/heartrate" value:(float)bpm sender:nil];
}

- (void)sendFaceExpressionJawOpen:(float)jawOpen smile:(float)smile eyebrowRaise:(float)eyebrowRaise
{
    [self sendFloat:@"/face/jaw/open" value:jawOpen sender:nil];
    [self sendFloat:@"/face/smile" value:smile sender:nil];
    [self sendFloat:@"/face/eyebrow/raise" value:eyebrowRaise sender:nil];
}

// MARK: - Native OSC Implementation (iOS without JUCE)

#if !USE_JUCE_OSC

- (void)handleNewConnection:(nw_connection_t)connection
{
    nw_connection_set_queue(connection, _oscQueue);

    __weak typeof(self) weakSelf = self;
    nw_connection_receive(connection, 1, 65536, ^(dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_error_t error) {
        if (content)
        {
            [weakSelf parseOSCData:content];
        }

        if (!error && !is_complete)
        {
            [weakSelf handleNewConnection:connection];
        }
    });

    nw_connection_start(connection);
}

- (void)parseOSCData:(dispatch_data_t)data
{
    // Parse OSC message from data
    // This is a simplified parser - a full implementation would handle the OSC spec completely

    const void *buffer;
    size_t size;
    dispatch_data_t contiguous = dispatch_data_create_map(data, &buffer, &size);

    if (size < 4)
        return;

    // Extract address (null-terminated, padded to 4 bytes)
    NSString *address = [NSString stringWithUTF8String:(const char *)buffer];

    if (_messageCallback)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.messageCallback(address, @[]);
        });
    }
}

- (void)sendOSCMessage:(NSString *)address withFloat:(float)value
{
    // Create OSC message packet
    NSMutableData *packet = [NSMutableData data];

    // Address (null-terminated, padded to 4 bytes)
    NSData *addressData = [address dataUsingEncoding:NSUTF8StringEncoding];
    [packet appendData:addressData];
    [packet appendBytes:"\0" length:1];

    // Pad to 4-byte boundary
    while (packet.length % 4 != 0)
        [packet appendBytes:"\0" length:1];

    // Type tag
    [packet appendBytes:",f\0\0" length:4];

    // Float value (big-endian)
    uint32_t intValue = CFSwapInt32HostToBig(*(uint32_t *)&value);
    [packet appendBytes:&intValue length:4];

    // Send via UDP (would need active connection)
    NSLog(@"[OSCBridge] Sending OSC: %@ = %f", address, value);
}

- (void)sendOSCMessage:(NSString *)address withInt:(int)value
{
    NSLog(@"[OSCBridge] Sending OSC: %@ = %d", address, value);
}

- (void)sendOSCMessage:(NSString *)address withString:(NSString *)value
{
    NSLog(@"[OSCBridge] Sending OSC: %@ = %@", address, value);
}

#endif

@end

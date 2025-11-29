//
//  SyncBridge.mm
//  Echoelmusic
//
//  Objective-C++ implementation of SyncBridge
//  Wraps C++ EchoelSync for Swift interoperability
//

#import "SyncBridge.h"

#if defined(JUCE_AVAILABLE) && JUCE_AVAILABLE
    #include "../../Sync/EchoelSync.h"
    #define USE_JUCE_SYNC 1
#else
    #define USE_JUCE_SYNC 0
#endif

@interface SyncBridge ()
{
#if USE_JUCE_SYNC
    std::unique_ptr<EchoelSync> _echoelSync;
#endif
    double _internalTempo;
    double _internalBeat;
    BOOL _internalIsPlaying;
}

@property (nonatomic, copy) TempoChangedCallback tempoCallback;
@property (nonatomic, copy) PeerConnectionCallback peerCallback;

@end

@implementation SyncBridge

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _internalTempo = 120.0;
        _internalBeat = 0.0;
        _internalIsPlaying = NO;

#if USE_JUCE_SYNC
        _echoelSync = std::make_unique<EchoelSync>();
#endif

        NSLog(@"[SyncBridge] Initialized");
    }
    return self;
}

- (void)dealloc
{
#if USE_JUCE_SYNC
    _echoelSync.reset();
#endif
}

// MARK: - Tempo & Transport Properties

- (double)tempo
{
#if USE_JUCE_SYNC
    return _echoelSync->getTempo();
#else
    return _internalTempo;
#endif
}

- (void)setTempo:(double)tempo
{
    tempo = MAX(20.0, MIN(300.0, tempo));

#if USE_JUCE_SYNC
    _echoelSync->setTempo(tempo);
#else
    _internalTempo = tempo;
#endif

    NSLog(@"[SyncBridge] Tempo set to %.1f BPM", tempo);
}

- (double)currentBeat
{
#if USE_JUCE_SYNC
    return _echoelSync->getCurrentBeat();
#else
    return _internalBeat;
#endif
}

- (double)beatPhase
{
#if USE_JUCE_SYNC
    return _echoelSync->getBeatPhase();
#else
    return fmod(_internalBeat, 1.0);
#endif
}

- (BOOL)isPlaying
{
#if USE_JUCE_SYNC
    return _echoelSync->isPlaying();
#else
    return _internalIsPlaying;
#endif
}

- (SyncRole)syncRole
{
#if USE_JUCE_SYNC
    switch (_echoelSync->getSyncRole())
    {
        case EchoelSync::SyncRole::Master: return SyncRoleMaster;
        case EchoelSync::SyncRole::Slave: return SyncRoleSlave;
        case EchoelSync::SyncRole::Peer: return SyncRolePeer;
        case EchoelSync::SyncRole::Adaptive: return SyncRoleAdaptive;
    }
#endif
    return SyncRolePeer;
}

- (void)setSyncRole:(SyncRole)role
{
#if USE_JUCE_SYNC
    EchoelSync::SyncRole cppRole;
    switch (role)
    {
        case SyncRoleMaster: cppRole = EchoelSync::SyncRole::Master; break;
        case SyncRoleSlave: cppRole = EchoelSync::SyncRole::Slave; break;
        case SyncRolePeer: cppRole = EchoelSync::SyncRole::Peer; break;
        case SyncRoleAdaptive: cppRole = EchoelSync::SyncRole::Adaptive; break;
    }
    _echoelSync->setSyncRole(cppRole);
#endif
}

- (SyncProtocol)preferredProtocol
{
#if USE_JUCE_SYNC
    switch (_echoelSync->getPreferredProtocol())
    {
        case EchoelSync::SyncProtocol::EchoelSyncNative: return SyncProtocolEchoelSyncNative;
        case EchoelSync::SyncProtocol::AbletonLink: return SyncProtocolAbletonLink;
        case EchoelSync::SyncProtocol::MIDIClock: return SyncProtocolMIDIClock;
        case EchoelSync::SyncProtocol::MIDITimeCode: return SyncProtocolMIDITimeCode;
        case EchoelSync::SyncProtocol::LinearTimeCode: return SyncProtocolLinearTimeCode;
        case EchoelSync::SyncProtocol::OSC: return SyncProtocolOSC;
        default: return SyncProtocolAuto;
    }
#endif
    return SyncProtocolAuto;
}

- (void)setPreferredProtocol:(SyncProtocol)protocol
{
#if USE_JUCE_SYNC
    EchoelSync::SyncProtocol cppProtocol;
    switch (protocol)
    {
        case SyncProtocolEchoelSyncNative: cppProtocol = EchoelSync::SyncProtocol::EchoelSyncNative; break;
        case SyncProtocolAbletonLink: cppProtocol = EchoelSync::SyncProtocol::AbletonLink; break;
        case SyncProtocolMIDIClock: cppProtocol = EchoelSync::SyncProtocol::MIDIClock; break;
        case SyncProtocolMIDITimeCode: cppProtocol = EchoelSync::SyncProtocol::MIDITimeCode; break;
        case SyncProtocolLinearTimeCode: cppProtocol = EchoelSync::SyncProtocol::LinearTimeCode; break;
        case SyncProtocolOSC: cppProtocol = EchoelSync::SyncProtocol::OSC; break;
        default: cppProtocol = EchoelSync::SyncProtocol::Auto; break;
    }
    _echoelSync->setPreferredProtocol(cppProtocol);
#endif
}

// MARK: - Transport Control

- (void)play
{
#if USE_JUCE_SYNC
    _echoelSync->play();
#else
    _internalIsPlaying = YES;
#endif
    NSLog(@"[SyncBridge] Play");
}

- (void)stop
{
#if USE_JUCE_SYNC
    _echoelSync->stop();
#else
    _internalIsPlaying = NO;
    _internalBeat = 0.0;
#endif
    NSLog(@"[SyncBridge] Stop");
}

- (void)setTimeSignatureNumerator:(double)numerator denominator:(double)denominator
{
#if USE_JUCE_SYNC
    _echoelSync->setTimeSignature(numerator, denominator);
#endif
}

// MARK: - Network Discovery

- (void)startDiscovery
{
#if USE_JUCE_SYNC
    _echoelSync->startDiscovery();
#endif
    NSLog(@"[SyncBridge] Discovery started");
}

- (void)stopDiscovery
{
#if USE_JUCE_SYNC
    _echoelSync->stopDiscovery();
#endif
    NSLog(@"[SyncBridge] Discovery stopped");
}

- (NSArray<NSString *> *)getAvailableSources
{
    NSMutableArray *sources = [NSMutableArray array];

#if USE_JUCE_SYNC
    auto cppSources = _echoelSync->getAvailableSources();
    for (const auto& source : cppSources)
    {
        [sources addObject:[NSString stringWithUTF8String:source.deviceName.toRawUTF8()]];
    }
#endif

    return sources;
}

- (int)numConnectedPeers
{
#if USE_JUCE_SYNC
    return static_cast<int>(_echoelSync->getConnectedPeers().size());
#else
    return 0;
#endif
}

// MARK: - Server Mode

- (BOOL)startServerOnPort:(int)port
{
#if USE_JUCE_SYNC
    return _echoelSync->startServer(port);
#else
    NSLog(@"[SyncBridge] Server started on port %d (mock)", port);
    return YES;
#endif
}

- (void)stopServer
{
#if USE_JUCE_SYNC
    _echoelSync->stopServer();
#endif
    NSLog(@"[SyncBridge] Server stopped");
}

- (BOOL)isServerRunning
{
#if USE_JUCE_SYNC
    return _echoelSync->isServerRunning();
#else
    return NO;
#endif
}

- (NSString *)serverName
{
#if USE_JUCE_SYNC
    auto state = _echoelSync->getActiveSyncSource();
    return [NSString stringWithUTF8String:state.deviceName.toRawUTF8()];
#else
    return @"Echoelmusic";
#endif
}

- (void)setServerName:(NSString *)name
{
#if USE_JUCE_SYNC
    _echoelSync->setServerName(juce::String([name UTF8String]));
#endif
}

// MARK: - Sync Quality

- (float)syncQuality
{
#if USE_JUCE_SYNC
    return _echoelSync->getSyncQuality();
#else
    return 1.0f;
#endif
}

- (float)latencyMs
{
#if USE_JUCE_SYNC
    return _echoelSync->getActiveSyncSource().latencyMs;
#else
    return 0.0f;
#endif
}

// MARK: - Callbacks

- (void)setTempoChangedCallback:(TempoChangedCallback)callback
{
    _tempoCallback = [callback copy];

#if USE_JUCE_SYNC
    __weak typeof(self) weakSelf = self;
    _echoelSync->onTempoChanged = [weakSelf](double bpm)
    {
        if (weakSelf.tempoCallback)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.tempoCallback(bpm);
            });
        }
    };
#endif
}

- (void)setPeerConnectionCallback:(PeerConnectionCallback)callback
{
    _peerCallback = [callback copy];

#if USE_JUCE_SYNC
    __weak typeof(self) weakSelf = self;
    _echoelSync->onPeerConnected = [weakSelf](const EchoelSync::SyncSource& source)
    {
        if (weakSelf.peerCallback)
        {
            NSString *name = [NSString stringWithUTF8String:source.deviceName.toRawUTF8()];
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.peerCallback(name, YES);
            });
        }
    };

    _echoelSync->onPeerDisconnected = [weakSelf](const EchoelSync::SyncSource& source)
    {
        if (weakSelf.peerCallback)
        {
            NSString *name = [NSString stringWithUTF8String:source.deviceName.toRawUTF8()];
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.peerCallback(name, NO);
            });
        }
    };
#endif
}

// MARK: - Session State

- (NSDictionary *)captureSessionState
{
#if USE_JUCE_SYNC
    auto state = _echoelSync->captureSessionState();
    return @{
        @"tempo": @(state.tempo),
        @"beat": @(state.beat),
        @"phase": @(state.phase),
        @"isPlaying": @(state.isPlaying),
        @"numPeers": @(state.numPeers),
        @"latencyMs": @(state.latencyMs),
        @"syncQuality": @(state.syncQuality)
    };
#else
    return @{
        @"tempo": @(_internalTempo),
        @"beat": @(_internalBeat),
        @"phase": @(fmod(_internalBeat, 1.0)),
        @"isPlaying": @(_internalIsPlaying),
        @"numPeers": @(0),
        @"latencyMs": @(0.0f),
        @"syncQuality": @(1.0f)
    };
#endif
}

- (double)beatAtSampleTime:(int64_t)sampleTime sampleRate:(double)sampleRate
{
#if USE_JUCE_SYNC
    return _echoelSync->beatAtSampleTime(sampleTime, sampleRate);
#else
    double beatsPerSecond = _internalTempo / 60.0;
    double seconds = (double)sampleTime / sampleRate;
    return seconds * beatsPerSecond;
#endif
}

// MARK: - Diagnostics

- (NSString *)getDiagnosticsString
{
#if USE_JUCE_SYNC
    auto diagStr = _echoelSync->getDiagnosticsString();
    return [NSString stringWithUTF8String:diagStr.toRawUTF8()];
#else
    return [NSString stringWithFormat:
            @"=== SyncBridge Diagnostics ===\n"
            @"Mode: Standalone (no JUCE)\n"
            @"Tempo: %.1f BPM\n"
            @"Playing: %@\n"
            @"Beat: %.2f\n",
            _internalTempo,
            _internalIsPlaying ? @"Yes" : @"No",
            _internalBeat];
#endif
}

@end

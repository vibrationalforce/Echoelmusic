#import "BioDataBridge.h"
#include "../Plugin/PluginProcessor.h"
#include <mutex>

@implementation BioDataBridge
{
    EchoelmusicAudioProcessor* _pluginProcessor;
    std::mutex _mutex;

    // Cached bio-data
    float _cachedHRV;
    float _cachedCoherence;
    float _cachedHeartRate;
}

#pragma mark - Singleton

+ (instancetype)sharedInstance
{
    static BioDataBridge* instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[BioDataBridge alloc] init];
    });

    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _pluginProcessor = nullptr;
        _cachedHRV = 0.5f;
        _cachedCoherence = 0.5f;
        _cachedHeartRate = 70.0f;

        NSLog(@"[BioDataBridge] Initialized");
    }
    return self;
}

#pragma mark - Plugin Processor Management

- (void)setPluginProcessor:(void*)processor
{
    std::lock_guard<std::mutex> lock(_mutex);

    _pluginProcessor = static_cast<EchoelmusicAudioProcessor*>(processor);

    if (_pluginProcessor != nullptr)
    {
        NSLog(@"[BioDataBridge] Plugin processor connected");

        // Send cached bio-data to plugin
        _pluginProcessor->updateBioData(_cachedHRV, _cachedCoherence, _cachedHeartRate);
    }
}

- (BOOL)isPluginLoaded
{
    std::lock_guard<std::mutex> lock(_mutex);
    return _pluginProcessor != nullptr;
}

- (NSString*)getPluginVersion
{
    return @"1.0.0";
}

#pragma mark - Bio-Data Updates

- (void)updateBioDataWithHRV:(float)hrv
                   coherence:(float)coherence
                   heartRate:(float)heartRate
{
    // Validate ranges
    hrv = std::max(0.0f, std::min(1.0f, hrv));
    coherence = std::max(0.0f, std::min(1.0f, coherence));
    heartRate = std::max(30.0f, std::min(220.0f, heartRate));

    // Cache values
    _cachedHRV = hrv;
    _cachedCoherence = coherence;
    _cachedHeartRate = heartRate;

    // Update plugin if loaded
    std::lock_guard<std::mutex> lock(_mutex);

    if (_pluginProcessor != nullptr)
    {
        _pluginProcessor->updateBioData(hrv, coherence, heartRate);

        NSLog(@"[BioDataBridge] Bio-data updated - HRV: %.2f, Coherence: %.2f, HR: %.1f bpm",
              hrv, coherence, heartRate);
    }
    else
    {
        NSLog(@"[BioDataBridge] Bio-data cached (plugin not loaded) - HRV: %.2f, Coherence: %.2f, HR: %.1f bpm",
              hrv, coherence, heartRate);
    }
}

- (NSDictionary*)getCurrentBioData
{
    std::lock_guard<std::mutex> lock(_mutex);

    if (_pluginProcessor != nullptr)
    {
        auto bioData = _pluginProcessor->getCurrentBioData();

        return @{
            @"hrv": @(bioData.hrv),
            @"coherence": @(bioData.coherence),
            @"heartRate": @(bioData.heartRate),
            @"timestamp": @(bioData.timestamp)
        };
    }
    else
    {
        // Return cached data if plugin not loaded
        return @{
            @"hrv": @(_cachedHRV),
            @"coherence": @(_cachedCoherence),
            @"heartRate": @(_cachedHeartRate),
            @"timestamp": @([[NSDate date] timeIntervalSince1970] * 1000.0)
        };
    }
}

@end

//==============================================================================
// C++ Helper Functions (for plugin to register itself)
//==============================================================================

extern "C" {

/// Register plugin processor with bridge (called from plugin initialization)
void BioDataBridge_RegisterProcessor(void* processor)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[BioDataBridge sharedInstance] setPluginProcessor:processor];
    });
}

/// Unregister plugin processor
void BioDataBridge_UnregisterProcessor()
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[BioDataBridge sharedInstance] setPluginProcessor:nullptr];
    });
}

}

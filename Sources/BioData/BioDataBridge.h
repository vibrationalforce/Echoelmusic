#pragma once

#import <Foundation/Foundation.h>

/**
 * Bio-Data Bridge (Swift ↔️ C++/JUCE)
 *
 * Objective-C++ bridge that allows Swift code to communicate with the JUCE plugin.
 * This enables HealthKit data from Swift/watchOS to control JUCE audio parameters.
 *
 * Usage from Swift:
 * ```swift
 * let bridge = BioDataBridge.shared()
 * bridge.updateBioData(hrv: 0.75, coherence: 0.8, heartRate: 70.0)
 * ```
 */
@interface BioDataBridge : NSObject

/// Singleton instance
+ (instancetype)sharedInstance;

/// Update bio-data values (thread-safe)
/// @param hrv Heart Rate Variability (0.0 - 1.0)
/// @param coherence Coherence level (0.0 - 1.0)
/// @param heartRate Heart rate in BPM
- (void)updateBioDataWithHRV:(float)hrv
                   coherence:(float)coherence
                   heartRate:(float)heartRate;

/// Get current bio-data values
- (NSDictionary*)getCurrentBioData;

/// Set the plugin processor instance (called internally by plugin)
- (void)setPluginProcessor:(void*)processor;

/// Check if plugin is loaded
- (BOOL)isPluginLoaded;

/// Get plugin version
- (NSString*)getPluginVersion;

@end

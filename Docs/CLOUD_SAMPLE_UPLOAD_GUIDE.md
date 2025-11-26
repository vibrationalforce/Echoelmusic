# Cloud Sample Upload Guide 🌩️
## Echoelmusic Cloud Sample Manager - Complete Usage Instructions

> **GOAL:** Upload samples from iPhone 16 Pro Max (FL Studio Mobile) to cloud storage → Compress to save space → Make available in Echoelmusic with on-demand streaming

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Supported Cloud Providers](#supported-cloud-providers)
3. [Upload Methods](#upload-methods)
4. [Compression Options](#compression-options)
5. [On-Demand Streaming](#on-demand-streaming)
6. [Smart Caching](#smart-caching)
7. [Code Examples](#code-examples)

---

## 🚀 Quick Start

### Step 1: Initialize CloudSampleManager

```cpp
#include "CloudSampleManager.h"

CloudSampleManager cloudManager;

// Set sample library (optional)
cloudManager.setLibrary(&mySampleLibrary);
```

### Step 2: Authenticate with Cloud Provider

#### Option A: Google Drive
```cpp
cloudManager.authenticateProvider(
    CloudSampleManager::CloudProvider::GoogleDrive,
    "",  // API key (not needed for OAuth)
    "YOUR_CLIENT_ID",
    "YOUR_CLIENT_SECRET"
);
```

#### Option B: Dropbox
```cpp
cloudManager.authenticateProvider(
    CloudSampleManager::CloudProvider::Dropbox,
    "YOUR_DROPBOX_API_KEY"
);
```

#### Option C: WeTransfer (No Auth Needed!)
```cpp
cloudManager.authenticateProvider(
    CloudSampleManager::CloudProvider::WeTransfer
);
```

### Step 3: Upload Your Samples!

```cpp
// Upload entire FL Studio Mobile Sample Bulk folder
juce::File sampleBulkFolder("/path/to/FL Studio Mobile/MySamples/Sample Bulk");

CloudSampleManager::UploadConfig config;
config.provider = CloudSampleManager::CloudProvider::GoogleDrive;
config.enableCompression = true;
config.compressionFormat = "FLAC";  // 50% smaller, lossless!
config.folderPath = "Echoelmusic/Samples";

auto result = cloudManager.uploadFromFolder(sampleBulkFolder, true, config);

DBG("Uploaded: " << result.uploaded << " samples");
DBG("Space saved: " << result.totalSizeSaved / (1024*1024) << " MB");
```

---

## ☁️ Supported Cloud Providers

| Provider | Upload | Download | Sharing | Compression | Cost |
|----------|--------|----------|---------|-------------|------|
| **Google Drive** | ✅ | ✅ | ✅ | ✅ | 15GB Free |
| **Dropbox** | ✅ | ✅ | ✅ | ✅ | 2GB Free |
| **WeTransfer** | ✅ | ❌ | ✅ | ✅ | 2GB Free (7-day expiry) |
| **iCloud Drive** | ✅ | ✅ | ⚠️ | ✅ | 5GB Free |
| **OneDrive** | ✅ | ✅ | ✅ | ✅ | 5GB Free |

### Recommendation for Your Use Case

**For iPhone 16 Pro Max + FL Studio Mobile:**

1. **Best for permanent storage:** **Google Drive** (15GB free, good sharing)
2. **Best for quick sharing:** **WeTransfer** (super easy, no account needed)
3. **Best for Apple ecosystem:** **iCloud Drive** (automatic sync)

---

## 📤 Upload Methods

### Method 1: Upload Single Sample

```cpp
juce::File sample("/path/to/kick.wav");

CloudSampleManager::UploadConfig config;
config.provider = CloudSampleManager::CloudProvider::GoogleDrive;
config.enableCompression = true;
config.compressionFormat = "FLAC";
config.deleteLocalAfterUpload = false;  // Keep original on phone
config.generateShareLink = true;         // Get shareable URL

bool success = cloudManager.uploadSample(sample, config);
```

### Method 2: Upload Batch (Multiple Files)

```cpp
juce::Array<juce::File> samples;
samples.add(juce::File("/path/to/kick.wav"));
samples.add(juce::File("/path/to/snare.wav"));
samples.add(juce::File("/path/to/hihat.wav"));

auto result = cloudManager.uploadBatch(samples, config);

DBG("Success: " << result.uploaded);
DBG("Failed: " << result.failed);
DBG("Space saved: " << result.totalSizeSaved / 1024 << " KB");
```

### Method 3: Upload Entire Folder (FL Studio Mobile!)

```cpp
// Your exact use case!
juce::File flStudioSamples("/Users/YourName/Documents/FL Studio Mobile/MySamples/Sample Bulk");

CloudSampleManager::UploadConfig config;
config.provider = CloudSampleManager::CloudProvider::GoogleDrive;
config.enableCompression = true;
config.compressionFormat = "FLAC";
config.folderPath = "Echoelmusic/Factory/Samples";
config.uploadMetadata = true;  // Upload .json with BPM/Key info

// Recursive = true → upload all subfolders too!
auto result = cloudManager.uploadFromFolder(flStudioSamples, true, config);

// Show progress
cloudManager.onUploadProgress = [](const juce::String& sampleId, float progress) {
    DBG("Uploading: " << sampleId << " - " << (progress * 100) << "%");
};

cloudManager.onUploadComplete = [](const juce::String& sampleId, bool success) {
    if (success)
        DBG("✅ Uploaded: " << sampleId);
    else
        DBG("❌ Failed: " << sampleId);
};
```

### Method 4: Upload from URL (Download from Internet → Upload to Cloud)

```cpp
juce::URL sampleUrl("https://example.com/samples/808_kick.wav");

auto result = cloudManager.uploadFromURL(sampleUrl, config);
```

---

## 🗜️ Compression Options

### Why Compress?
- **Save 50-70% storage space**
- **Faster uploads** (smaller files)
- **Cheaper cloud costs** (less storage used)
- **On-demand download** (only download what you use)

### Option 1: FLAC (Lossless) - RECOMMENDED!

**Best for:** High-quality samples, drums, vocals, sound design

```cpp
config.enableCompression = true;
config.compressionFormat = "FLAC";
```

**Specs:**
- **Compression:** ~50% smaller
- **Quality:** 100% identical to original (lossless!)
- **Speed:** Fast encoding/decoding
- **Use case:** Professional production

**Example:**
- Original WAV: 10 MB → FLAC: 5 MB ✨
- 1000 samples @ 10MB each = 10GB → 5GB saved!

### Option 2: Opus (Lossy High Quality)

**Best for:** Loops, atmospheric sounds, textures

```cpp
config.enableCompression = true;
config.compressionFormat = "Opus";
config.opusQuality = 9;  // 0-10 (9 = ~128kbps, very high quality)
```

**Specs:**
- **Compression:** ~70% smaller
- **Quality:** Near-transparent at quality 9
- **Speed:** Very fast
- **Use case:** Bulk samples, effects

**Example:**
- Original WAV: 10 MB → Opus: 3 MB 🚀
- 1000 samples @ 10MB each = 10GB → 7GB saved!

### Comparison

| Format | Size | Quality | Best For |
|--------|------|---------|----------|
| **WAV (Original)** | 10 MB | 100% | Archival |
| **FLAC** | 5 MB | 100% | Professional production ✅ |
| **Opus (Q9)** | 3 MB | 99% | Bulk samples, FX |

**For your use case (FL Studio Mobile samples):**
- Use **FLAC** for drums, one-shots, vocals
- Use **Opus** for long loops, ambiences, textures

---

## 📥 On-Demand Streaming

### How It Works

1. **Upload samples to cloud** (compressed)
2. **Samples appear in Echoelmusic browser** (all samples visible!)
3. **User clicks sample → Auto-download**
4. **Cache locally** (frequently used samples stay)
5. **Save space:** Only used samples take up device storage!

### Example Workflow

```cpp
// 1. Upload 1000 samples to Google Drive
auto uploadResult = cloudManager.uploadFromFolder(sampleFolder, true, config);
DBG("Uploaded " << uploadResult.uploaded << " samples to cloud");

// 2. Browse all cloud samples (no need to download yet!)
auto allSamples = cloudManager.getAllCloudSamples();
DBG("Total cloud samples: " << allSamples.size());

// 3. User clicks sample in browser → Download on-demand
juce::File sample = cloudManager.downloadSample("sample_id_123", true);  // true = cache locally

// 4. Use sample immediately
if (sample.existsAsFile())
{
    // Load into sampler, chopper, etc.
    mySampler.loadSample(sample);
}
```

### Smart Download

```cpp
// Download favorites automatically (always available)
cloudManager.downloadAllFavorites();

// Preload samples in background (for upcoming session)
juce::StringArray upcomingSamples = {"sample_1", "sample_2", "sample_3"};
cloudManager.preloadSamples(upcomingSamples);

// Download entire collection
cloudManager.downloadCollection("Echoelmusic Essentials");
```

---

## 💾 Smart Caching

### Configuration

```cpp
CloudSampleManager::CacheConfig cacheConfig;

// Cache settings
cacheConfig.enableCaching = true;
cacheConfig.maxCacheSizeMB = 1000;  // Max 1GB cache on iPhone

// Auto-download rules
cacheConfig.autoDownloadFavorites = true;  // Favorites always local
cacheConfig.autoDownloadRecent = true;     // Recent samples
cacheConfig.keepRecentDays = 30;           // Keep last 30 days

// Smart caching (usage-based)
cacheConfig.smartCache = true;
cacheConfig.minAccessCount = 3;  // Used 3+ times = keep local

// Auto-cleanup
cacheConfig.autoClearUnused = true;
cacheConfig.unusedDays = 90;  // Not used in 90 days = delete from cache

cloudManager.setCacheConfig(cacheConfig);
```

### Monitor Cache

```cpp
auto stats = cloudManager.getCacheStats();

DBG("Total samples: " << stats.totalSamples);
DBG("Cached locally: " << stats.cachedSamples);
DBG("Cache size: " << stats.cacheSize << " MB / " << stats.maxCacheSize << " MB");
DBG("Most used: " << stats.mostUsedSamples);
DBG("Cache hit rate: " << (stats.cacheHitRate * 100) << "%");
```

### Manual Cache Management

```cpp
// Clear cache (free space on iPhone!)
cloudManager.clearCache(true);  // true = keep favorites

// Optimize cache (remove unused, keep frequently used)
cloudManager.optimizeCache();
```

---

## 💻 Code Examples

### Example 1: Upload FL Studio Mobile Samples from iPhone

```cpp
#include "CloudSampleManager.h"
#include "FLStudioMobileImporter.h"

// Step 1: Find FL Studio Mobile folder
FLStudioMobileImporter flImporter;
juce::File flFolder = flImporter.getDefaultFLStudioMobileFolder();
juce::File sampleBulk = flFolder.getChildFile("MySamples/Sample Bulk");

// Step 2: Setup cloud manager
CloudSampleManager cloudManager;

// Step 3: Authenticate with Google Drive
cloudManager.authenticateProvider(
    CloudSampleManager::CloudProvider::GoogleDrive,
    "",
    "YOUR_CLIENT_ID",
    "YOUR_CLIENT_SECRET"
);

// Step 4: Configure upload
CloudSampleManager::UploadConfig config;
config.provider = CloudSampleManager::CloudProvider::GoogleDrive;
config.enableCompression = true;
config.compressionFormat = "FLAC";  // Lossless, 50% smaller
config.folderPath = "Echoelmusic/Factory/iPhone_Samples";
config.deleteLocalAfterUpload = false;  // Keep on phone
config.generateShareLink = true;
config.uploadMetadata = true;

// Step 5: Upload all samples!
auto result = cloudManager.uploadFromFolder(sampleBulk, true, config);

// Step 6: Show results
juce::String message;
message << "✅ Upload Complete!\n";
message << "Uploaded: " << result.uploaded << " samples\n";
message << "Failed: " << result.failed << " samples\n";
message << "Space saved: " << (result.totalSizeSaved / (1024*1024)) << " MB\n";
message << "\nShare links:\n";
for (const auto& link : result.shareLinks)
    message << "- " << link << "\n";

DBG(message);
```

### Example 2: On-Demand Sample Browser

```cpp
// Browse all cloud samples
auto cloudSamples = cloudManager.getAllCloudSamples();

for (const auto& info : cloudSamples)
{
    DBG("Sample: " << info.name);
    DBG("  Provider: " << (int)info.provider);
    DBG("  Original size: " << info.originalSize / 1024 << " KB");
    DBG("  Compressed size: " << info.compressedSize / 1024 << " KB");
    DBG("  Compression: " << (info.compressionRatio * 100) << "%");
    DBG("  Cached: " << (info.isDownloaded ? "YES" : "NO"));
    DBG("  Access count: " << info.accessCount);
    DBG("");
}

// Search samples
auto results = cloudManager.searchCloud("kick");
DBG("Found " << results.size() << " kick samples");

// Download on-demand
if (!results.isEmpty())
{
    auto kickFile = cloudManager.downloadSample(results[0].sampleId, true);
    DBG("Downloaded: " << kickFile.getFullPathName());
}
```

### Example 3: WeTransfer Quick Upload (No Account Needed!)

```cpp
// Upload to WeTransfer (easiest, no auth!)
CloudSampleManager cloudManager;

// No authentication needed!
cloudManager.authenticateProvider(CloudSampleManager::CloudProvider::WeTransfer);

juce::Array<juce::File> samples;
samples.add(juce::File("/path/to/sample1.wav"));
samples.add(juce::File("/path/to/sample2.wav"));

auto result = cloudManager.uploadToWeTransfer(samples, "My iPhone Samples");

if (result.success)
{
    DBG("✅ Upload complete!");
    DBG("Download URL: " << result.downloadUrl);
    DBG("Expires: " << result.expiryTime.toString(true, true));
    DBG("Size: " << result.fileSize / (1024*1024) << " MB");
}
```

### Example 4: Share Sample Collection

```cpp
// Create shareable collection (like Splice pack!)
juce::StringArray sampleIds = {"sample_1", "sample_2", "sample_3"};

juce::String shareUrl = cloudManager.createSharedCollection(
    "My Echoelmusic Drum Pack",
    sampleIds
);

DBG("Share this link: " << shareUrl);

// Friend imports collection
cloudManager.importSharedCollection(shareUrl);
```

---

## 🎯 Recommended Workflow for Your iPhone 16 Pro Max

### Scenario: Upload FL Studio Mobile samples to Google Drive, compress with FLAC, make available in Echoelmusic

```cpp
// 1. Initialize
CloudSampleManager cloudManager;

// 2. Authenticate Google Drive
cloudManager.authenticateProvider(
    CloudSampleManager::CloudProvider::GoogleDrive,
    "", "YOUR_CLIENT_ID", "YOUR_CLIENT_SECRET"
);

// 3. Setup upload config
CloudSampleManager::UploadConfig config;
config.provider = CloudSampleManager::CloudProvider::GoogleDrive;
config.enableCompression = true;
config.compressionFormat = "FLAC";  // 50% smaller, lossless!
config.folderPath = "Echoelmusic/Factory/Samples";
config.deleteLocalAfterUpload = false;  // Keep on iPhone
config.generateShareLink = true;         // For sharing
config.uploadMetadata = true;            // BPM/Key info

// 4. Upload FL Studio Mobile samples
juce::File sampleBulk("/path/to/FL Studio Mobile/MySamples/Sample Bulk");
auto result = cloudManager.uploadFromFolder(sampleBulk, true, config);

// 5. Configure smart caching (save iPhone storage!)
CloudSampleManager::CacheConfig cacheConfig;
cacheConfig.maxCacheSizeMB = 500;  // Max 500MB on iPhone
cacheConfig.autoDownloadFavorites = true;
cacheConfig.smartCache = true;
cacheConfig.autoClearUnused = true;
cloudManager.setCacheConfig(cacheConfig);

// 6. Enable background sync
cloudManager.setBackgroundSyncEnabled(true);

// 7. Done! Samples now available in Echoelmusic browser
auto allSamples = cloudManager.getAllCloudSamples();
DBG("Total samples available: " << allSamples.size());
```

**Result:**
- ✅ All samples uploaded to Google Drive
- ✅ Compressed with FLAC (50% smaller)
- ✅ Available in Echoelmusic sample browser
- ✅ On-demand download (save iPhone storage!)
- ✅ Smart caching (frequently used = local)
- ✅ Share links for collaboration

---

## 📊 Space Savings Calculation

### Example: 1000 Samples

| Metric | Original WAV | FLAC Compressed | Opus Compressed |
|--------|--------------|-----------------|-----------------|
| **Size per sample** | 10 MB | 5 MB | 3 MB |
| **Total size (1000 samples)** | 10 GB | 5 GB | 3 GB |
| **Space saved** | - | **5 GB** ✨ | **7 GB** 🚀 |
| **iPhone storage used** | 10 GB | 500 MB (cache) | 500 MB (cache) |
| **Effective savings** | - | **9.5 GB!** | **9.5 GB!** |

**On-demand + caching = Massive space savings on iPhone!**

---

## 🔧 Integration with Existing Echoelmusic Components

### With SampleLibrary

```cpp
#include "SampleLibrary.h"
#include "CloudSampleManager.h"

SampleLibrary library;
CloudSampleManager cloudManager;

// Link them
cloudManager.setLibrary(&library);

// Upload samples → Automatically added to library
cloudManager.uploadFromFolder(sampleFolder, true, config);

// Browse in SampleLibrary (shows cloud + local)
auto allSamples = library.getAllSamples();  // Includes cloud samples!
```

### With SampleProcessor (Transform before upload)

```cpp
#include "SampleProcessor.h"
#include "CloudSampleManager.h"

SampleProcessor processor;
CloudSampleManager cloudManager;

// Transform sample with Echoelmusic signature
auto transformed = processor.transformSample(
    originalSample,
    SampleProcessor::TransformPreset::DarkDeep
);

// Upload transformed version
cloudManager.uploadSample(transformed, config);
```

### With FLStudioMobileImporter

```cpp
#include "FLStudioMobileImporter.h"
#include "CloudSampleManager.h"

FLStudioMobileImporter flImporter;
CloudSampleManager cloudManager;

// Import from FL Studio Mobile
auto sampleFolder = flImporter.getDefaultFLStudioMobileFolder()
    .getChildFile("MySamples/Sample Bulk");

// Upload to cloud
cloudManager.uploadFromFolder(sampleFolder, true, config);
```

---

## 🚀 Next Steps

1. **Get API credentials:**
   - Google Drive: https://console.cloud.google.com/
   - Dropbox: https://www.dropbox.com/developers/apps

2. **Test upload:**
   - Start with small batch (10 samples)
   - Verify compression works
   - Check cloud storage

3. **Upload main library:**
   - Upload FL Studio Mobile samples
   - Enable smart caching
   - Test on-demand download

4. **Production:**
   - Enable background sync
   - Configure auto-cleanup
   - Monitor cache stats

---

## ❓ FAQ

**Q: Which cloud provider should I use?**
A: Google Drive (15GB free) or iCloud Drive (automatic iPhone sync)

**Q: Should I use FLAC or Opus?**
A: FLAC for production-quality samples, Opus for bulk/FX samples

**Q: Will samples work offline?**
A: Yes! Cached samples work offline. Favorites auto-download.

**Q: How much iPhone storage do I need?**
A: Only for cache (500MB-1GB). Cloud holds everything else!

**Q: Can I share samples with friends?**
A: Yes! Generate share links or create shared collections.

**Q: What happens if I delete a sample from cloud?**
A: It's removed from Echoelmusic browser (cached copy remains until cleanup)

---

**Echoelmusic Cloud Sample Manager** - Upload less, create more! 🎵✨

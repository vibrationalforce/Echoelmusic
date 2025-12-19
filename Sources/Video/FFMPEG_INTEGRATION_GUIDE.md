# FFmpeg Integration Guide for VideoWeaver

## Current Status: 85% Complete (Placeholder Implementations)

VideoWeaver's architecture is production-ready but uses placeholder implementations for video decode/encode. This guide covers completing the final 15%.

---

## Missing Components

### 1. Video Decoding (Line 805-819 in VideoWeaver.cpp)

**Current Code:**
```cpp
// Placeholder colored rectangle
g.setColour(juce::Colours::blue);
g.fillRect(0, 0, projectWidth, projectHeight);
```

**Needed:**
```cpp
// Real video decoding with FFmpeg
AVFormatContext* formatCtx = nullptr;
AVCodecContext* codecCtx = nullptr;
AVFrame* frame = nullptr;
// ... decode frame at timestamp
```

### 2. Video Encoding (Line 723-724 in VideoWeaver.cpp)

**Current Code:**
```cpp
// Encode frame (would use FFmpeg or platform encoder)
// encoder.encodeFrame(frameImage);
```

**Needed:**
```cpp
// Real video encoding
encoder->encodeFrame(frameImage, frame);
writer->writeFrame(encodedData);
```

---

## Integration Options

### Option 1: FFmpeg Static Libraries (Recommended)

**Pros:**
- Full codec support (H.264, H.265, ProRes, VP9)
- Cross-platform (Windows, macOS, Linux)
- Battle-tested and widely used

**Cons:**
- Large binary size (~50 MB)
- GPL/LGPL licensing concerns
- Complex build process

**CMake Integration:**
```cmake
# In Sources/Video/CMakeLists.txt
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED
    libavcodec
    libavformat
    libavutil
    libswscale
    libswresample
)

target_link_libraries(VideoWeaver
    ${FFMPEG_LIBRARIES}
)

target_include_directories(VideoWeaver
    PRIVATE ${FFMPEG_INCLUDE_DIRS}
)
```

### Option 2: Platform-Native APIs

#### macOS/iOS: AVFoundation
```objc
// Objective-C++
AVAssetReader* reader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
AVAssetReaderTrackOutput* output = ...;
CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
```

#### Windows: Media Foundation
```cpp
IMFSourceReader* pReader = nullptr;
MFCreateSourceReaderFromURL(url, NULL, &pReader);
```

#### Linux: GStreamer
```cpp
GstElement* pipeline = gst_parse_launch("filesrc location=video.mp4 ! ...", NULL);
```

**Pros:**
- Smaller binary size
- Hardware acceleration
- No licensing concerns

**Cons:**
- Platform-specific code required
- Limited codec support on some platforms

### Option 3: Hybrid Approach (Best)

Use platform APIs where available, FFmpeg as fallback:

```cpp
#if JUCE_MAC || JUCE_IOS
    return decodeWithAVFoundation(file, timestamp);
#elif JUCE_WINDOWS
    return decodeWithMediaFoundation(file, timestamp);
#else
    return decodeWithFFmpeg(file, timestamp);
#endif
```

---

## Implementation Plan

### Phase 1: Video Decoder Class (6-8 hours)

Create `VideoDecoder.h/cpp`:

```cpp
class VideoDecoder
{
public:
    VideoDecoder();
    ~VideoDecoder();

    bool openFile(const juce::File& videoFile);
    void close();

    juce::Image decodeFrame(double timestamp);

    double getDuration() const;
    double getFrameRate() const;
    int getWidth() const;
    int getHeight() const;

private:
    struct Impl;  // Pimpl pattern
    std::unique_ptr<Impl> impl;
};
```

**Implementation Details:**
- Use FFmpeg's `av_seek_frame()` for timestamp seeking
- Cache decoded frames for performance
- Handle color space conversion (YUV → RGB)
- Support multiple video tracks

### Phase 2: Video Encoder Class (8-10 hours)

Create `VideoEncoder.h/cpp`:

```cpp
class VideoEncoder
{
public:
    enum class Codec
    {
        H264,
        H265_HEVC,
        ProRes422,
        ProRes4444,
        VP9,
        AV1
    };

    enum class Preset
    {
        Ultrafast,
        Fast,
        Medium,
        Slow,
        Veryslow
    };

    VideoEncoder();
    ~VideoEncoder();

    bool open(const juce::File& outputFile,
              int width, int height, double fps,
              Codec codec, Preset preset);

    bool encodeFrame(const juce::Image& frame);
    bool finish();

private:
    struct Impl;
    std::unique_ptr<Impl> impl;
};
```

**Implementation Details:**
- Support hardware acceleration (VideoToolbox, NVENC, QuickSync)
- Multi-threaded encoding
- Bitrate control (CBR/VBR)
- HDR metadata (HDR10, Dolby Vision)

### Phase 3: Integration (4-6 hours)

**Update VideoWeaver.cpp:**

```cpp
// Line 805: Replace placeholder
case Clip::Type::Video:
{
    if (!clip.decoder)
    {
        clip.decoder = std::make_unique<VideoDecoder>();
        clip.decoder->openFile(juce::File(clip.filePath));
    }

    double clipTime = inPoint + frameTime;
    return clip.decoder->decodeFrame(clipTime);
}

// Line 723: Replace placeholder
if (!encoder)
{
    encoder = std::make_unique<VideoEncoder>();
    encoder->open(outputFile, exportWidth, exportHeight,
                  exportFPS, VideoEncoder::Codec::H264,
                  VideoEncoder::Preset::Medium);
}

encoder->encodeFrame(frameImage);
```

---

## Minimal Working Implementation (2-3 hours)

For immediate testing, create minimal stubs:

```cpp
// VideoDecoder.cpp
juce::Image VideoDecoder::decodeFrame(double timestamp)
{
    // Generate test pattern
    juce::Image image(juce::Image::RGB, 1920, 1080, true);
    juce::Graphics g(image);

    g.fillAll(juce::Colour::fromHSV(timestamp / duration, 0.7f, 0.9f, 1.0f));
    g.setColour(juce::Colours::white);
    g.setFont(48.0f);
    g.drawText(juce::String(timestamp, 2) + "s",
               image.getBounds(), juce::Justification::centred);

    return image;
}

// VideoEncoder.cpp
bool VideoEncoder::encodeFrame(const juce::Image& frame)
{
    // Write as PNG sequence for now
    juce::File outputDir = outputFile.getParentDirectory();
    juce::String filename = juce::String::formatted("frame_%06d.png", frameCount++);

    juce::FileOutputStream stream(outputDir.getChildFile(filename));
    juce::PNGImageFormat pngFormat;
    pngFormat.writeImageToStream(frame, stream);

    return true;
}
```

This allows:
- Timeline functionality to work immediately
- Visual testing of effects and transitions
- Export as PNG sequence (can be converted to video with FFmpeg CLI)

---

## Testing Plan

1. **Unit Tests:**
   - Test VideoDecoder with various formats (MP4, MOV, MKV)
   - Test VideoEncoder with different codecs
   - Test seek accuracy (±1 frame)

2. **Integration Tests:**
   - Load video clip into timeline
   - Apply transitions and effects
   - Export to H.264
   - Verify output with FFprobe

3. **Performance Tests:**
   - 4K 60fps decode speed
   - Multi-clip timeline playback
   - Real-time preview performance

---

## Build Instructions

### Ubuntu/Debian:
```bash
sudo apt-get install \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev

cd build
cmake -DUSE_FFMPEG=ON ..
make
```

### macOS (Homebrew):
```bash
brew install ffmpeg

cd build
cmake -DUSE_FFMPEG=ON ..
make
```

### Windows (vcpkg):
```powershell
vcpkg install ffmpeg:x64-windows

cmake -DCMAKE_TOOLCHAIN_FILE=[vcpkg]/scripts/buildsystems/vcpkg.cmake ..
cmake --build .
```

---

## Licensing Considerations

**FFmpeg Licensing:**
- LGPL 2.1+ by default (allows dynamic linking)
- GPL if using GPL-only codecs (x264, x265)
- Patent concerns: H.264, H.265 (license from MPEG LA required for distribution)

**Alternatives:**
- VP9 (Google, royalty-free)
- AV1 (AOMedia, royalty-free)
- ProRes (Apple, licensed)

**Recommendation:**
- Use LGPL-licensed FFmpeg with dynamic linking
- Include royalty-free codecs (VP9, AV1, Opus)
- Let users install H.264/H.265 codecs separately

---

## Resources

**FFmpeg Documentation:**
- Official docs: https://ffmpeg.org/documentation.html
- Decoding example: https://ffmpeg.org/doxygen/trunk/decode_video_8c-example.html
- Encoding example: https://ffmpeg.org/doxygen/trunk/encode_video_8c-example.html

**JUCE Video Integration:**
- JUCE doesn't include video support natively
- Third-party: juce_video module (community)

**Alternative Libraries:**
- libav (FFmpeg fork)
- GStreamer (more complex but powerful)
- Media Foundation (Windows only)
- AVFoundation (Apple platforms only)

---

## Summary

**Current Status:**
- ✅ Timeline engine complete
- ✅ Effects and transitions complete
- ✅ Export framework complete
- ⚠️ Video decode: placeholder (15% missing)
- ⚠️ Video encode: placeholder (15% missing)

**To Reach 100%:**
1. Create VideoDecoder class (6-8 hours)
2. Create VideoEncoder class (8-10 hours)
3. Integrate into VideoWeaver (4-6 hours)
4. Testing and debugging (6-8 hours)

**Total Effort:** 24-32 hours (3-4 days)

**Quick Win (2-3 hours):**
- Implement PNG sequence export
- Use FFmpeg CLI for final video encoding
- Gets to "working" state immediately

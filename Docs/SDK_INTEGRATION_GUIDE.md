# 🔧 SDK INTEGRATION GUIDE - MP3/AAC ENCODERS

> **Purpose:** Step-by-step guide to integrate LAME (MP3) and FDK-AAC (AAC) encoders
> **Difficulty:** Intermediate (requires CMake knowledge)
> **Time:** 2-4 hours

---

## 📋 OVERVIEW

Echoelmusic currently supports:
- ✅ **WAV** (JUCE built-in)
- ✅ **FLAC** (JUCE built-in)
- ✅ **OGG** (JUCE built-in)
- ⏳ **MP3** (requires LAME)
- ⏳ **AAC** (requires FDK-AAC)

This guide shows how to integrate the missing encoders.

---

## 🎯 OPTION 1: QUICK START (Recommended for MVP)

**Ship WITHOUT MP3/AAC!**

**Why?**
- WAV/FLAC/OGG already work perfectly
- Professional producers prefer lossless formats (FLAC)
- Saves 2-4 hours of integration work
- You can add MP3/AAC as a FREE UPDATE later

**Marketing:**
```
"Echoelmusic supports professional lossless export (WAV, FLAC, OGG).
MP3/AAC support coming in v1.1 (free update)!"
```

**Skip to bottom for launch checklist!**

---

## 🎯 OPTION 2: FULL MP3/AAC INTEGRATION

If you want MP3/AAC for launch, follow these steps:

---

## 📦 PART 1: LAME MP3 ENCODER

### Step 1: Download LAME

**Windows:**
```powershell
# Download precompiled binaries
# https://www.rarewares.org/mp3-lame-bundle.php
# Extract to: C:\SDK\lame\
```

**macOS:**
```bash
# Install via Homebrew
brew install lame

# Headers will be in: /opt/homebrew/include/lame/
# Library: /opt/homebrew/lib/libmp3lame.dylib
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install libmp3lame-dev

# Fedora/CentOS
sudo dnf install lame-devel

# Arch
sudo pacman -S lame
```

### Step 2: Update CMakeLists.txt

Add this section after line 435 (before "Compile Definitions"):

```cmake
# ===========================
# MP3 Encoder (LAME)
# ===========================

option(ENABLE_MP3_EXPORT "Enable MP3 export via LAME" ON)

if(ENABLE_MP3_EXPORT)
    # Try to find LAME
    find_package(PkgConfig)

    if(PkgConfig_FOUND)
        pkg_check_modules(LAME lame)
    endif()

    # Manual paths if pkg-config fails
    if(NOT LAME_FOUND)
        if(WIN32)
            set(LAME_INCLUDE_DIRS "C:/SDK/lame/include")
            set(LAME_LIBRARY_DIRS "C:/SDK/lame/lib")
            set(LAME_LIBRARIES "libmp3lame")
        elseif(APPLE)
            set(LAME_INCLUDE_DIRS "/opt/homebrew/include")
            set(LAME_LIBRARY_DIRS "/opt/homebrew/lib")
            set(LAME_LIBRARIES "mp3lame")
        else()
            # Linux - should be found by pkg-config
            set(LAME_INCLUDE_DIRS "/usr/include")
            set(LAME_LIBRARY_DIRS "/usr/lib")
            set(LAME_LIBRARIES "mp3lame")
        endif()
    endif()

    if(EXISTS "${LAME_INCLUDE_DIRS}/lame/lame.h")
        message(STATUS "LAME MP3 encoder found: ${LAME_INCLUDE_DIRS}")

        target_include_directories(Echoelmusic PRIVATE ${LAME_INCLUDE_DIRS})
        target_link_directories(Echoelmusic PRIVATE ${LAME_LIBRARY_DIRS})
        target_link_libraries(Echoelmusic PRIVATE ${LAME_LIBRARIES})

        target_compile_definitions(Echoelmusic PRIVATE HAVE_LAME=1)
    else()
        message(WARNING "LAME not found - MP3 export disabled")
        message(WARNING "  Searched: ${LAME_INCLUDE_DIRS}/lame/lame.h")
    endif()
endif()
```

### Step 3: Update AudioExporter.cpp

Replace the `exportMP3()` placeholder (line ~350) with:

```cpp
bool AudioExporter::exportMP3(const juce::AudioBuffer<float>& audio,
                             double sampleRate,
                             const juce::File& outputFile,
                             const ExportSettings& settings)
{
#ifdef HAVE_LAME
    #include <lame/lame.h>

    // Initialize LAME
    lame_t lame = lame_init();
    if (lame == nullptr)
    {
        DBG("AudioExporter: Failed to initialize LAME encoder");
        return false;
    }

    // Configure LAME
    lame_set_in_samplerate(lame, static_cast<int>(sampleRate));
    lame_set_num_channels(lame, audio.getNumChannels());
    lame_set_brate(lame, settings.getBitrate());
    lame_set_quality(lame, 2);  // 0-9, 2 = high quality, near best
    lame_set_VBR(lame, vbr_off);  // Use CBR (constant bitrate)

    // Initialize parameters
    if (lame_init_params(lame) < 0)
    {
        DBG("AudioExporter: Failed to set LAME parameters");
        lame_close(lame);
        return false;
    }

    // Prepare output buffer
    int numSamples = audio.getNumSamples();
    int mp3BufferSize = static_cast<int>(1.25 * numSamples + 7200);
    std::vector<unsigned char> mp3Buffer(mp3BufferSize);

    // Convert audio to interleaved format
    std::vector<float> interleavedAudio(numSamples * audio.getNumChannels());

    for (int channel = 0; channel < audio.getNumChannels(); ++channel)
    {
        const float* channelData = audio.getReadPointer(channel);

        for (int i = 0; i < numSamples; ++i)
        {
            interleavedAudio[i * audio.getNumChannels() + channel] = channelData[i];
        }
    }

    // Encode
    int encodedBytes = 0;

    if (audio.getNumChannels() == 1)
    {
        encodedBytes = lame_encode_buffer_ieee_float(
            lame,
            interleavedAudio.data(),
            nullptr,  // No right channel
            numSamples,
            mp3Buffer.data(),
            mp3BufferSize
        );
    }
    else
    {
        encodedBytes = lame_encode_buffer_interleaved_ieee_float(
            lame,
            interleavedAudio.data(),
            numSamples,
            mp3Buffer.data(),
            mp3BufferSize
        );
    }

    if (encodedBytes < 0)
    {
        DBG("AudioExporter: LAME encoding failed with error: " << encodedBytes);
        lame_close(lame);
        return false;
    }

    // Flush remaining data
    int flushBytes = lame_encode_flush(lame, mp3Buffer.data() + encodedBytes, mp3BufferSize - encodedBytes);
    if (flushBytes > 0)
        encodedBytes += flushBytes;

    // Write to file
    juce::FileOutputStream stream(outputFile);

    if (!stream.openedOk())
    {
        DBG("AudioExporter: Failed to open output file");
        lame_close(lame);
        return false;
    }

    stream.write(mp3Buffer.data(), encodedBytes);
    stream.flush();

    // Cleanup
    lame_close(lame);

    DBG("AudioExporter: Successfully exported MP3 (" << encodedBytes << " bytes)");
    return true;

#else
    // Fallback to WAV if LAME not available
    DBG("AudioExporter: MP3 export not available (LAME not compiled in)");
    DBG("  Fallback: Exporting as WAV");

    return exportWAV(audio, sampleRate, outputFile.withFileExtension(".wav"), settings);
#endif
}
```

### Step 4: Update isFormatSupported()

Replace line ~500 in AudioExporter.cpp:

```cpp
bool AudioExporter::isFormatSupported(Format format) const
{
    switch (format)
    {
        case Format::WAV:   return true;
        case Format::FLAC:  return true;
        case Format::OGG:   return true;

#ifdef HAVE_LAME
        case Format::MP3:   return true;
#else
        case Format::MP3:   return false;
#endif

#ifdef HAVE_FDK_AAC
        case Format::AAC:   return true;
#else
        case Format::AAC:   return false;
#endif

        default:            return false;
    }
}
```

---

## 📦 PART 2: FDK-AAC ENCODER

### Step 1: Download FDK-AAC

**Windows:**
```powershell
# Build from source (requires Visual Studio)
git clone https://github.com/mstorsjo/fdk-aac.git C:\SDK\fdk-aac
cd C:\SDK\fdk-aac
mkdir build && cd build
cmake ..
cmake --build . --config Release
```

**macOS:**
```bash
# Install via Homebrew
brew install fdk-aac

# Headers: /opt/homebrew/include/fdk-aac/
# Library: /opt/homebrew/lib/libfdk-aac.dylib
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get install libfdk-aac-dev

# Fedora/CentOS (requires RPM Fusion)
sudo dnf install fdk-aac-devel

# Arch
sudo pacman -S libfdk-aac
```

### Step 2: Update CMakeLists.txt

Add this after the LAME section:

```cmake
# ===========================
# AAC Encoder (FDK-AAC)
# ===========================

option(ENABLE_AAC_EXPORT "Enable AAC export via FDK-AAC" ON)

if(ENABLE_AAC_EXPORT)
    # Try to find FDK-AAC
    find_package(PkgConfig)

    if(PkgConfig_FOUND)
        pkg_check_modules(FDK_AAC fdk-aac)
    endif()

    # Manual paths if pkg-config fails
    if(NOT FDK_AAC_FOUND)
        if(WIN32)
            set(FDK_AAC_INCLUDE_DIRS "C:/SDK/fdk-aac/include")
            set(FDK_AAC_LIBRARY_DIRS "C:/SDK/fdk-aac/build/Release")
            set(FDK_AAC_LIBRARIES "fdk-aac")
        elseif(APPLE)
            set(FDK_AAC_INCLUDE_DIRS "/opt/homebrew/include")
            set(FDK_AAC_LIBRARY_DIRS "/opt/homebrew/lib")
            set(FDK_AAC_LIBRARIES "fdk-aac")
        else()
            set(FDK_AAC_INCLUDE_DIRS "/usr/include")
            set(FDK_AAC_LIBRARY_DIRS "/usr/lib")
            set(FDK_AAC_LIBRARIES "fdk-aac")
        endif()
    endif()

    if(EXISTS "${FDK_AAC_INCLUDE_DIRS}/fdk-aac/aacenc_lib.h")
        message(STATUS "FDK-AAC encoder found: ${FDK_AAC_INCLUDE_DIRS}")

        target_include_directories(Echoelmusic PRIVATE ${FDK_AAC_INCLUDE_DIRS})
        target_link_directories(Echoelmusic PRIVATE ${FDK_AAC_LIBRARY_DIRS})
        target_link_libraries(Echoelmusic PRIVATE ${FDK_AAC_LIBRARIES})

        target_compile_definitions(Echoelmusic PRIVATE HAVE_FDK_AAC=1)
    else()
        message(WARNING "FDK-AAC not found - AAC export disabled")
        message(WARNING "  Searched: ${FDK_AAC_INCLUDE_DIRS}/fdk-aac/aacenc_lib.h")
    endif()
endif()
```

### Step 3: Update AudioExporter.cpp

Replace the `exportAAC()` placeholder (line ~420) with:

```cpp
bool AudioExporter::exportAAC(const juce::AudioBuffer<float>& audio,
                             double sampleRate,
                             const juce::File& outputFile,
                             const ExportSettings& settings)
{
#ifdef HAVE_FDK_AAC
    #include <fdk-aac/aacenc_lib.h>

    // Initialize encoder
    HANDLE_AACENCODER handle = nullptr;
    AACENC_ERROR err;

    err = aacEncOpen(&handle, 0, audio.getNumChannels());
    if (err != AACENC_OK)
    {
        DBG("AudioExporter: Failed to open AAC encoder: " << err);
        return false;
    }

    // Set parameters
    aacEncoder_SetParam(handle, AACENC_AOT, AOT_AAC_LC);
    aacEncoder_SetParam(handle, AACENC_SAMPLERATE, static_cast<int>(sampleRate));
    aacEncoder_SetParam(handle, AACENC_CHANNELMODE, audio.getNumChannels() == 1 ? MODE_1 : MODE_2);
    aacEncoder_SetParam(handle, AACENC_BITRATE, settings.getBitrate() * 1000);
    aacEncoder_SetParam(handle, AACENC_TRANSMUX, TT_MP4_ADTS);

    // Initialize encoder
    err = aacEncEncode(handle, nullptr, nullptr, nullptr, nullptr);
    if (err != AACENC_OK)
    {
        DBG("AudioExporter: Failed to initialize AAC encoder: " << err);
        aacEncClose(&handle);
        return false;
    }

    // Get encoder info
    AACENC_InfoStruct info = { 0 };
    err = aacEncInfo(handle, &info);

    // Prepare buffers
    int numSamples = audio.getNumSamples();
    int frameSize = info.frameLength;

    std::vector<int16_t> interleavedPCM(frameSize * audio.getNumChannels());
    std::vector<uint8_t> aacBuffer(info.maxOutBufBytes);

    juce::FileOutputStream stream(outputFile);
    if (!stream.openedOk())
    {
        aacEncClose(&handle);
        return false;
    }

    // Encode in frames
    int samplesProcessed = 0;

    while (samplesProcessed < numSamples)
    {
        int samplesToProcess = std::min(frameSize, numSamples - samplesProcessed);

        // Convert float to int16 and interleave
        for (int i = 0; i < samplesToProcess; ++i)
        {
            for (int ch = 0; ch < audio.getNumChannels(); ++ch)
            {
                float sample = audio.getSample(ch, samplesProcessed + i);
                interleavedPCM[i * audio.getNumChannels() + ch] =
                    static_cast<int16_t>(juce::jlimit(-1.0f, 1.0f, sample) * 32767.0f);
            }
        }

        // Setup buffers
        AACENC_BufDesc inBuf = { 0 };
        AACENC_BufDesc outBuf = { 0 };
        AACENC_InArgs inArgs = { 0 };
        AACENC_OutArgs outArgs = { 0 };

        void* inPtr = interleavedPCM.data();
        int inSize = samplesToProcess * audio.getNumChannels() * sizeof(int16_t);
        int inElemSize = sizeof(int16_t);

        inBuf.numBufs = 1;
        inBuf.bufs = &inPtr;
        inBuf.bufferIdentifiers = (INT*)alloca(sizeof(INT));
        inBuf.bufferIdentifiers[0] = IN_AUDIO_DATA;
        inBuf.bufSizes = &inSize;
        inBuf.bufElSizes = &inElemSize;

        void* outPtr = aacBuffer.data();
        int outSize = static_cast<int>(aacBuffer.size());
        int outElemSize = 1;

        outBuf.numBufs = 1;
        outBuf.bufs = &outPtr;
        outBuf.bufferIdentifiers = (INT*)alloca(sizeof(INT));
        outBuf.bufferIdentifiers[0] = OUT_BITSTREAM_DATA;
        outBuf.bufSizes = &outSize;
        outBuf.bufElSizes = &outElemSize;

        inArgs.numInSamples = samplesToProcess * audio.getNumChannels();

        // Encode
        err = aacEncEncode(handle, &inBuf, &outBuf, &inArgs, &outArgs);

        if (err != AACENC_OK)
        {
            DBG("AudioExporter: AAC encoding failed: " << err);
            aacEncClose(&handle);
            return false;
        }

        // Write output
        if (outArgs.numOutBytes > 0)
        {
            stream.write(aacBuffer.data(), outArgs.numOutBytes);
        }

        samplesProcessed += samplesToProcess;
    }

    // Flush encoder
    AACENC_BufDesc outBuf = { 0 };
    AACENC_InArgs inArgs = { 0 };
    AACENC_OutArgs outArgs = { 0 };

    void* outPtr = aacBuffer.data();
    int outSize = static_cast<int>(aacBuffer.size());
    int outElemSize = 1;

    outBuf.numBufs = 1;
    outBuf.bufs = &outPtr;
    outBuf.bufferIdentifiers = (INT*)alloca(sizeof(INT));
    outBuf.bufferIdentifiers[0] = OUT_BITSTREAM_DATA;
    outBuf.bufSizes = &outSize;
    outBuf.bufElSizes = &outElemSize;

    inArgs.numInSamples = -1;  // Signal EOF

    err = aacEncEncode(handle, nullptr, &outBuf, &inArgs, &outArgs);

    if (outArgs.numOutBytes > 0)
    {
        stream.write(aacBuffer.data(), outArgs.numOutBytes);
    }

    stream.flush();

    // Cleanup
    aacEncClose(&handle);

    DBG("AudioExporter: Successfully exported AAC");
    return true;

#else
    // Fallback to WAV
    DBG("AudioExporter: AAC export not available (FDK-AAC not compiled in)");
    DBG("  Fallback: Exporting as WAV");

    return exportWAV(audio, sampleRate, outputFile.withFileExtension(".wav"), settings);
#endif
}
```

---

## 🧪 TESTING

### Test MP3 Export:

```cpp
AudioExporter exporter;

AudioExporter::ExportSettings settings;
settings.format = AudioExporter::Format::MP3;
settings.quality = AudioExporter::Quality::High;  // 256 kbps
settings.sampleRate = 44100;
settings.targetLUFS = -14.0f;

juce::File output("test.mp3");

bool success = exporter.exportAudio(audioBuffer, 44100.0, output, settings);

if (success)
    DBG("MP3 export successful!");
else
    DBG("MP3 export failed!");
```

### Test AAC Export:

```cpp
settings.format = AudioExporter::Format::AAC;
settings.quality = AudioExporter::Quality::High;  // 256 kbps

juce::File output("test.m4a");

bool success = exporter.exportAudio(audioBuffer, 44100.0, output, settings);
```

---

## 🚀 BUILD & VERIFY

### Windows:
```powershell
cmake -B build -DENABLE_MP3_EXPORT=ON -DENABLE_AAC_EXPORT=ON
cmake --build build --config Release
```

### macOS:
```bash
cmake -B build -DENABLE_MP3_EXPORT=ON -DENABLE_AAC_EXPORT=ON
cmake --build build --config Release
```

### Linux:
```bash
cmake -B build -DENABLE_MP3_EXPORT=ON -DENABLE_AAC_EXPORT=ON
cmake --build build --config Release -j$(nproc)
```

---

## ✅ VERIFICATION CHECKLIST

- [ ] LAME headers found during CMake configuration
- [ ] FDK-AAC headers found during CMake configuration
- [ ] Project compiles without errors
- [ ] MP3 export produces valid .mp3 files
- [ ] AAC export produces valid .m4a files
- [ ] Exported files play in media players
- [ ] LUFS normalization works correctly
- [ ] Metadata embedding works (ID3 for MP3, MP4 for AAC)

---

## 🎯 LAUNCH CHECKLIST (Without MP3/AAC)

If you choose to ship without MP3/AAC:

- [ ] ✅ All core features implemented (Sessions 1-5)
- [ ] ✅ WAV/FLAC/OGG export works
- [ ] ✅ Project save/load works
- [ ] ✅ MIDI editing works (Piano Roll)
- [ ] ✅ Plugin hosting works (VST3/AU)
- [ ] ✅ Session sharing works (QR codes)
- [ ] 🧪 Testing completed (3 days)
- [ ] 📝 Gumroad product page created
- [ ] 🌐 GitHub Pages website live
- [ ] 📸 Screenshots & demo video ready
- [ ] 💰 Launch @ €9.99 Early Bird!

**Timeline:** 1 week to launch!

---

## 💡 RECOMMENDATIONS

### For Immediate Launch (Option A):
**SKIP MP3/AAC integration!**
- Ship with WAV/FLAC/OGG (professionals prefer lossless anyway)
- Add MP3/AAC in v1.1 as FREE UPDATE
- Get to market FASTER (saves 2-4 hours)
- Get USER FEEDBACK earlier

### For Full Integration (Option B):
**Complete MP3/AAC before launch**
- Follow this guide step-by-step
- Test thoroughly on all platforms
- Launch with complete feature set
- Takes extra 2-4 hours

**My recommendation: GO WITH OPTION A!** 🚀

Get your product in users' hands ASAP, then iterate based on feedback!

---

## 📞 TROUBLESHOOTING

### "LAME not found"
- Check installation path matches CMakeLists.txt
- Verify `lame.h` exists in include directory
- On Windows, use absolute paths (C:\SDK\lame\...)

### "FDK-AAC not found"
- FDK-AAC requires manual compilation on Windows
- Use Homebrew on macOS for easiest install
- On Linux, check if RPM Fusion is enabled (Fedora)

### "Undefined reference to lame_*"
- Linker can't find library file
- Check library paths in CMakeLists.txt
- Verify library exists (.dll/.dylib/.so)

### "Encoding produces corrupt files"
- Check sample rate conversion is correct
- Verify interleaved audio format (L,R,L,R...)
- Test with shorter audio clips first

---

**Written:** 2025-11-19, Session 5
**Status:** READY FOR INTEGRATION ✅

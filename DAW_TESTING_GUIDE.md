# 🎛️ ECHOELMUSIC DAW TESTING GUIDE

**Complete testing guide for all DAWs and platforms**

---

## 🚀 **QUICK START**

### 1. Build & Install

**Linux:**
```bash
./verify_build.sh
cp -r build/Echoelmusic_artefacts/Release/VST3/Echoelmusic.vst3 ~/.vst3/
```

**macOS:**
```bash
./build-macos.sh
cp -r build/Echoelmusic_artefacts/Release/VST3/Echoelmusic.vst3 ~/Library/Audio/Plug-Ins/VST3/
cp -r build/Echoelmusic_artefacts/Release/AU/Echoelmusic.component ~/Library/Audio/Plug-Ins/Components/
```

**Windows:**
```cmd
build-windows.bat
xcopy /E /I /Y build\Echoelmusic_artefacts\Release\VST3\Echoelmusic.vst3 "%COMMONPROGRAMFILES%\VST3\Echoelmusic.vst3"
```

### 2. Rescan Plugins in Your DAW

---

## 🎵 **DAW-SPECIFIC SETUP**

### **Ableton Live** (10+)

**Install:**
1. Copy VST3 to plugin folder (automatic on Windows/macOS)
2. Preferences → Plug-Ins → VST Plug-in Custom Folder (if needed)
3. Click "Rescan"

**Usage:**
1. Create new MIDI/Audio track
2. Browser → Plug-ins → Echoelmusic
3. Drag to track or double-click

**Testing:**
- ✅ Load as audio effect
- ✅ Load as MIDI effect
- ✅ Automation mapping
- ✅ Save/load presets
- ✅ CPU meter monitoring

---

### **Logic Pro X** (10.7+, macOS Only)

**Install:**
1. Copy AU to `~/Library/Audio/Plug-Ins/Components/`
2. Logic Pro → Preferences → Plug-In Manager
3. Click "Reset & Rescan Selection"

**Usage:**
1. Create track
2. Channel Strip → Audio FX → Echoel → Echoelmusic
3. Alternative: Mixer → Inserts → Echoelmusic

**Testing:**
- ✅ AU validation passes
- ✅ Automation works
- ✅ Presets save to Library
- ✅ Sidechain routing
- ✅ Latency compensation

---

### **Reaper** (6.0+, All Platforms)

**Install:**
1. Options → Preferences → VST
2. Add VST3 path if not auto-detected
3. Re-scan

**Usage:**
1. Insert → Virtual Instrument/Effect → VST3 → Echoelmusic
2. Alternative: Right-click track FX button

**Testing:**
- ✅ VST3 loads without errors
- ✅ Parameter automation
- ✅ Project save/load
- ✅ FX chain integration
- ✅ Real-time monitoring

---

### **Bitwig Studio** (4.0+, All Platforms)

**Install:**
1. Settings → Plug-ins → Locations
2. Add VST3 folder
3. Rescan

**Usage:**
1. Device Browser → Plug-ins → VST3 → Echoelmusic
2. Drag to device chain

**Testing:**
- ✅ Modulation support
- ✅ Preset browsing
- ✅ Bitwig Grid integration
- ✅ Multi-out support
- ✅ CLAP format (if built)

---

### **FL Studio** (21+, Windows/macOS)

**Install:**
1. Copy VST3 to plugin folder
2. Options → Manage plugins → Find plugins
3. Rescan

**Usage:**
1. Mixer → Insert slot → More → VST3 → Echoelmusic
2. Alternative: Browser → Plugin database → Effects → Echoelmusic

**Testing:**
- ✅ Plugin loads in mixer
- ✅ Automation clips work
- ✅ Project save/load
- ✅ Preset system
- ✅ CPU usage acceptable

---

### **Cubase/Nuendo** (12+, All Platforms)

**Install:**
1. Copy VST3 to Steinberg VST3 folder
2. Studio → VST Plug-in Manager → Update Plug-in Information

**Usage:**
1. Inspector → Inserts → Echoelmusic
2. Alternative: MixConsole → Insert slot

**Testing:**
- ✅ VST3 validation passes
- ✅ Control Room compatibility
- ✅ Automation tracks
- ✅ Quick Controls mapping
- ✅ Latency reporting

---

### **Studio One** (5+, All Platforms)

**Install:**
1. Copy VST3 to plugin folder
2. Options → Locations → VST Plug-ins
3. Scan for new plugins

**Usage:**
1. Browser → Effects → VST3 → Echoelmusic
2. Drag to track or mixer insert

**Testing:**
- ✅ Plugin loads successfully
- ✅ Macro controls work
- ✅ Multi-Instruments compatible
- ✅ Console Shaper integration
- ✅ Pipeline XT support

---

### **Ardour** (7.0+, Linux/macOS/Windows)

**Install:**
1. Copy VST3 to `~/.vst3/` (Linux) or standard paths
2. Edit → Preferences → Plugins
3. VST3 → Rescan

**Usage:**
1. Right-click track → Add Plugin
2. Search "Echoelmusic"
3. Click to insert

**Testing:**
- ✅ VST3 scanning succeeds
- ✅ Plugin state saves
- ✅ Automation lanes
- ✅ Low-latency mode
- ✅ Session restore

---

### **Pro Tools** (2023+, AAX Required)

**Install:**
1. Build with `-DBUILD_AAX=ON`
2. Copy AAX to Pro Tools plug-ins folder
3. Restart Pro Tools

**Usage:**
1. Track insert → Multi-channel Plug-in → Echoelmusic
2. Alternative: AudioSuite (offline)

**Testing:**
- ✅ AAX validation
- ✅ HD/Native compatibility
- ✅ RTAS migration
- ✅ Delay compensation
- ✅ Session compatibility

**Note:** Requires Avid AAX SDK and iLok licensing (not included by default)

---

### **Tracktion Waveform** (12+, All Platforms)

**Install:**
1. Settings → Plugins & Devices
2. Add VST3 folder
3. Scan for new plugins

**Usage:**
1. Browser → Plugins → VST3 → Echoelmusic
2. Drag to track

**Testing:**
- ✅ Loads in Waveform
- ✅ Automation works
- ✅ Preset management
- ✅ Plugin state recall
- ✅ Multi-out support

---

## ✅ **COMPREHENSIVE TEST CHECKLIST**

### **Phase 1: Basic Functionality**
- [ ] Plugin loads without errors
- [ ] UI displays correctly
- [ ] Audio passes through cleanly (bypass test)
- [ ] All parameters respond
- [ ] CPU usage < 20% (idle)
- [ ] No audio glitches or clicks

### **Phase 2: DSP Effects (46 Total)**
Test each effect category:

**Dynamics (7 effects):**
- [ ] Compressor (Transparent/Vintage/Aggressive modes)
- [ ] BrickWallLimiter (true-peak limiting)
- [ ] MultibandCompressor (4-band)
- [ ] FETCompressor (1176 emulation)
- [ ] OptoCompressor (LA-2A emulation)
- [ ] DeEsser (vocal sibilance)
- [ ] TransientDesigner (attack/sustain)

**EQ & Filtering (5 effects):**
- [ ] ParametricEQ (8-band)
- [ ] PassiveEQ (Pultec emulation)
- [ ] DynamicEQ (frequency-specific dynamics)
- [ ] FormantFilter (vowel morphing)
- [ ] ResonanceHealer (adaptive suppression)

**Modulation & Spatial (5 effects):**
- [ ] ModulationSuite (Chorus/Flanger/Phaser/Ring/Shift)
- [ ] StereoImager (M/S width)
- [ ] ShimmerReverb (Brian Eno-style)
- [ ] ConvolutionReverb (IR-based)
- [ ] TapeDelay (vintage emulation)

**MIDI Tools (5 tools):**
- [ ] ChordGenius (smart progressions)
- [ ] MelodyForge (AI generation)
- [ ] BasslineArchitect (groove creation)
- [ ] ArpWeaver (advanced arpeggiator)
- [ ] WorldMusicDatabase (global scales)

**Mastering (7 effects):**
- [ ] MasteringMentor (AI-powered)
- [ ] StyleAwareMastering (genre-specific)
- [ ] SpectrumMaster (visual learning)
- [ ] TonalBalanceAnalyzer
- [ ] PhaseAnalyzer (goniometer)
- [ ] PsychoacousticAnalyzer
- [ ] SpectralMaskingDetector

### **Phase 3: Automation**
- [ ] Parameter automation works
- [ ] Automation curves smooth
- [ ] Read/Write modes function
- [ ] Latch mode works
- [ ] Touch mode works
- [ ] Automation survives project reload

### **Phase 4: Presets**
- [ ] Factory presets load
- [ ] User presets can be saved
- [ ] Presets recall all parameters
- [ ] Preset browser works
- [ ] Import/export presets
- [ ] Cross-platform preset compatibility

### **Phase 5: Performance**
- [ ] CPU usage acceptable (< 30% under load)
- [ ] No audio dropouts
- [ ] Latency < 10ms (reported)
- [ ] Multi-instance stable (10+ instances)
- [ ] Memory usage reasonable (< 500 MB)
- [ ] No memory leaks (extended test)

### **Phase 6: Stability**
- [ ] Plugin doesn't crash DAW
- [ ] Project saves without errors
- [ ] Project loads without errors
- [ ] Session recall perfect
- [ ] No GUI freezes
- [ ] Works in freeze/bounce

### **Phase 7: Integration**
- [ ] Sidechain routing works (if supported)
- [ ] MIDI input works
- [ ] MIDI output works
- [ ] Multi-output routing (if needed)
- [ ] Plugin-to-plugin communication
- [ ] Host sync (tempo/transport)

### **Phase 8: Biofeedback (Special)**
- [ ] HRV input recognized
- [ ] Coherence monitoring works
- [ ] Heart rate display accurate
- [ ] Bio-reactive DSP responds
- [ ] HealthKit integration (iOS)

---

## 📊 **PERFORMANCE BENCHMARKS**

### Expected Performance

| Metric | Target | Acceptable | Poor |
|--------|--------|------------|------|
| **Latency** | < 1ms | < 10ms | > 10ms |
| **CPU Usage (Idle)** | < 5% | < 20% | > 20% |
| **CPU Usage (Load)** | < 15% | < 30% | > 30% |
| **Memory** | < 100 MB | < 500 MB | > 500 MB |
| **Load Time** | < 500ms | < 2s | > 2s |
| **UI Responsiveness** | 60 FPS | 30 FPS | < 30 FPS |

### Test Scenarios

**Scenario 1: Light Usage**
- 1 instance of Echoelmusic
- 2-3 effects active
- 44.1 kHz, 256 samples buffer
- Expected CPU: < 10%

**Scenario 2: Medium Usage**
- 5 instances of Echoelmusic
- 10+ effects active across instances
- 48 kHz, 128 samples buffer
- Expected CPU: < 25%

**Scenario 3: Heavy Usage**
- 10+ instances
- All effects active
- 96 kHz, 64 samples buffer
- Expected CPU: < 50%

**Scenario 4: Stress Test**
- 20+ instances
- Complex automation
- 192 kHz, 32 samples buffer
- Should not crash, but may struggle

---

## 🐛 **COMMON ISSUES & SOLUTIONS**

### Plugin Not Found

**Problem:** DAW doesn't see Echoelmusic

**Solutions:**
1. Verify installation path:
   - Linux: `ls ~/.vst3/Echoelmusic.vst3`
   - macOS: `ls ~/Library/Audio/Plug-Ins/VST3/`
   - Windows: `dir "%COMMONPROGRAMFILES%\VST3\"`

2. Check permissions:
   ```bash
   chmod -R 755 ~/.vst3/Echoelmusic.vst3
   ```

3. Rescan plugins in DAW

4. Check DAW plugin paths in preferences

---

### Audio Glitches/Clicks

**Problem:** Clicking, popping, or distortion

**Solutions:**
1. Increase buffer size (512 or 1024 samples)
2. Disable other plugins temporarily
3. Check CPU usage (< 80%)
4. Close background applications
5. Disable real-time virus scanning
6. Use dedicated audio interface

---

### High CPU Usage

**Problem:** CPU meter shows high usage

**Solutions:**
1. Disable unused effects
2. Freeze/bounce tracks
3. Increase buffer size
4. Close GUI when not needed
5. Check for infinite loops in automation
6. Update to latest version (optimizations)

---

### Plugin Crashes DAW

**Problem:** DAW crashes when loading plugin

**Solutions:**
1. Check crash log location:
   - macOS: `~/Library/Logs/DiagnosticReports/`
   - Linux: `dmesg` or `/var/log/`
   - Windows: Event Viewer

2. Try safe mode (if DAW supports)
3. Reinstall plugin
4. Check for conflicting plugins
5. Report issue on GitHub with crash log

---

### Automation Not Working

**Problem:** Parameters don't respond to automation

**Solutions:**
1. Check automation mode (Read/Write/Latch/Touch)
2. Verify automation lane is enabled
3. Check parameter is automatable
4. Restart DAW session
5. Re-record automation

---

### Presets Won't Load

**Problem:** Preset loading fails or incomplete

**Solutions:**
1. Check preset file format (.vstpreset for VST3)
2. Verify preset directory permissions
3. Try factory presets first
4. Check for corrupted preset files
5. Manually delete preset cache

---

## 📋 **REPORTING ISSUES**

### Required Information

When reporting issues, include:

1. **System Info:**
   - OS version
   - DAW version
   - Plugin version
   - CPU model
   - RAM amount

2. **Steps to Reproduce:**
   - Exact steps to trigger issue
   - Screenshots/videos if possible
   - Project file (if small)

3. **Logs:**
   - DAW crash log
   - Plugin log (if available)
   - Console output

4. **Expected vs Actual:**
   - What should happen
   - What actually happens

### Where to Report

- **GitHub Issues:** https://github.com/vibrationalforce/Echoelmusic/issues
- **Discussions:** https://github.com/vibrationalforce/Echoelmusic/discussions
- **Email:** (if private/security issue)

---

## 🎓 **ADVANCED TESTING**

### Latency Testing

```bash
# Use jack_iodelay (Linux/macOS)
jack_iodelay

# Or use DAW's built-in latency compensation test
```

### Memory Leak Testing

```bash
# Linux: Valgrind
valgrind --leak-check=full --show-leak-kinds=all \
  build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic

# macOS: Instruments
instruments -t Leaks Echoelmusic.app
```

### CPU Profiling

```bash
# Linux: perf
perf record -g ./Echoelmusic
perf report

# macOS: Instruments
instruments -t "Time Profiler" Echoelmusic.app
```

### Stress Testing

```bash
# Create test project with 50+ instances
# Run for 30+ minutes
# Monitor CPU, memory, audio glitches
```

---

## 🏆 **CERTIFICATION CHECKLIST**

Before marking as "Production Ready":

- [ ] **All Phase 1-8 tests passed**
- [ ] **Tested in 3+ DAWs minimum**
- [ ] **No critical bugs found**
- [ ] **Performance acceptable on target hardware**
- [ ] **Documentation complete**
- [ ] **User presets work cross-platform**
- [ ] **Automation 100% functional**
- [ ] **No crashes in 24-hour stress test**
- [ ] **Memory leaks < 1 MB/hour**
- [ ] **Latency compensation accurate**

---

## 📚 **RESOURCES**

- **JUCE Plugin Host:** Test without DAW
- **Plugin Doctor:** Analyze latency/phase
- **PluginVal:** Automated VST3 validation
- **MrsWatson:** Command-line testing

---

**Testing Guide Version:** 1.0.0
**Last Updated:** November 2025
**For:** Echoelmusic v1.0.0+

---

**Happy Testing! 🎉**

For questions or issues, open a GitHub issue or discussion.

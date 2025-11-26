# 📦 MYSSAMPLES - BULK SAMPLE PROCESSING

**Your personal sample processing folder**

---

## 🚀 QUICK START

### **1. ADD YOUR SAMPLES HERE**

Just drag & drop or copy your samples into this folder:

```bash
MySamples/
├── kick_808.wav
├── techno_loop_128bpm.wav
├── snare_acoustic.wav
├── bass_sub_Am.wav
└── ... (any audio files)
```

**Supported Formats:**
- WAV (preferred)
- FLAC
- AIFF
- OGG
- MP3

---

### **2. RUN BULK PROCESSING**

**Option A: Using C++ Script** (needs compilation)
```bash
cd Scripts
g++ ProcessMySamples.cpp -o process_samples
./process_samples
```

**Option B: Using Python** (coming soon!)
```bash
python Scripts/process_bulk.py
```

**Option C: Manual Processing**
- Load Echoelmusic
- Go to Sample Browser
- Click "Import from MySamples"
- Choose preset (Dark, Bright, Vintage, etc.)
- Click "Process All"

---

## ⚙️ WHAT HAPPENS DURING PROCESSING?

**1. Automatic Analysis:**
- BPM detection from filename (e.g., "loop_128bpm.wav" → 128 BPM)
- Key detection (e.g., "bass_Am.wav" → A Minor)
- Genre detection (e.g., "techno_kick.wav" → Techno)
- Character detection (e.g., "dark_lead.wav" → Dark)

**2. Echoelmusic Transformation:**
- Pitch shifting (±12 semitones)
- Time stretching (0.5x - 2x)
- Multi-effect chain (filter, compression, saturation, reverb, etc.)
- Silence trimming with micro-fades (saves space!)
- Legal safety (minimum 3 transformations for copyright)

**3. Creative Naming:**
```
Input:  kick_808_dark.wav
Output: EchoelDarkKick_001.wav

Input:  techno_loop_128bpm_Am.wav
Output: EchoelMidLoop_Techno_Am_128_042.wav

Input:  phone_recording_001.wav
Output: EchoelSoftShot_137.wav
```

**4. Auto-Organization:**
- Samples automatically categorized:
  - Drums → Samples/Drums/
  - Bass → Samples/Bass/
  - Synths → Samples/Synths/
  - FX → Samples/FX/
  - Loops → Samples/Loops/

---

## 🎨 TRANSFORMATION PRESETS

Choose a preset to apply Echoelmusic signature sound:

**1. Dark & Deep** (Dark Techno)
- Pitch down 4 semitones
- Dark low-pass filter (8kHz)
- Deep reverb
- Analog saturation

**2. Bright & Crispy** (Modern House)
- Pitch up 2 semitones
- High-pass filter (remove mud)
- Compression (punchy)
- Wide stereo

**3. Vintage & Warm** (Lo-Fi)
- Pitch down 1 semitone
- Tape saturation
- Bit crushing
- Vinyl noise & crackle

**4. Glitchy & Modern** (Experimental)
- Stutter effects
- Granular grain texture
- Chorus & phaser
- High randomization

**5. Sub Bass** (Bass Heavy)
- Pitch down octave (-12 semitones)
- Extreme low-pass (200Hz)
- Heavy compression
- Saturation for harmonics

**6. Airy & Ethereal** (Ambient)
- Pitch up 5th (+7 semitones)
- High-pass filter (airy)
- Huge reverb
- Wide stereo + chorus

**7. Aggressive & Punchy** (Hard Techno)
- Heavy compression
- Distortion/saturation
- Transient boost

**8. Retro Vaporwave**
- Pitch down 3 semitones
- Slow time stretch (0.8x)
- Lush chorus
- Dreamy delay + reverb

**9-11. Random** (Light/Medium/Heavy)
- Automatic variation
- Creates unique sounds every time

---

## 📝 NAMING CONVENTIONS

For best auto-detection, name your samples like this:

**Template:**
```
[Type]_[Content]_[Character]_[Key]_[BPM]BPM.wav
```

**Examples:**
```
Kick_808_Dark_C_130BPM.wav
Snare_Acoustic_Bright.wav
Lead_Saw_Techno_Am.wav
Vocal_Chop_Female_120BPM.wav
Loop_Drums_Techno_128BPM.wav
Bass_Reese_Dark_Dm_140BPM.wav
```

**What gets auto-detected:**
- **Type:** Kick, Snare, Lead, Bass, Loop, Vocal, FX
- **Content:** 808, Acoustic, Saw, Reese, etc.
- **Key:** C, Am, Dm, F#m, etc.
- **BPM:** Any number 60-200 followed by "BPM"
- **Genre:** Techno, House, Hip-Hop, Trap, etc.
- **Character:** Dark, Bright, Warm, Aggressive, etc.

---

## 🔄 BATCH PROCESSING WORKFLOW

**Step 1:** Add samples to MySamples/
**Step 2:** Run bulk processor
**Step 3:** Check output in Samples/Processed/
**Step 4:** Review & organize
**Step 5:** Use in your tracks!

**Example Output:**

```
Samples/Processed/
├── EchoelDarkKick_001.wav
├── EchoelDarkKick_002.wav
├── EchoelBrightSnare_003.wav
├── EchoelSubBass_Techno_140_004.wav
├── EchoelVintageLoop_House_Am_125_005.wav
└── ... (all processed samples)
```

---

## 📊 EXPECTED RESULTS

**Space Savings:**
- Silence trimming: ~20-50% reduction
- Example: 500 MB → 250-400 MB

**Legal Safety:**
- All samples legally transformed
- Minimum 3 significant changes
- Unrecognizable from source

**Quality:**
- 24-bit WAV output
- Professional mastering
- Peak normalization to -0.5 dBFS

**Speed:**
- ~1-2 seconds per sample (depends on preset)
- Multi-threaded processing
- Progress updates in real-time

---

## 🎯 NEXT STEPS

1. **Add your samples** to this folder
2. **Choose a preset** (or use Random Medium)
3. **Run bulk processing**
4. **Check output** in Samples/Processed/
5. **Import to library** (automatic or manual)
6. **Start creating!** 🎉

---

## 🐛 TROUBLESHOOTING

**Q: No samples found?**
A: Make sure files are .wav, .flac, .aiff, .ogg, or .mp3

**Q: Processing fails?**
A: Check file permissions, disk space, and file integrity

**Q: BPM not detected?**
A: Include "128BPM" or "_128_" in filename

**Q: Wrong category?**
A: Rename file with type keyword (kick, snare, bass, lead, etc.)

**Q: Output too quiet/loud?**
A: All samples are normalized to -0.5 dBFS (safe headroom)

**Q: Legal issues?**
A: All presets apply minimum 3 transformations for legal safety

---

**Last Updated:** 2025-11-19
**Status:** Ready for Bulk Processing! 🚀

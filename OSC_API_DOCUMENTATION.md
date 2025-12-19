# OSC API Documentation - Echoelmusic

**Version**: 2.0 (Evidence-Based)
**Last Updated**: 2025-12-16
**Protocol**: Open Sound Control (OSC) over UDP

---

## Overview

Echoelmusic broadcasts real-time biosignal and system state data via OSC (Open Sound Control) for integration with professional creative tools including:

- **DAWs**: Ableton Live, Logic Pro, Pro Tools, Reaper
- **Visual Tools**: TouchDesigner, Resolume, VDMX, Max/MSP
- **Game Engines**: Unity, Unreal Engine
- **Custom Applications**: Any OSC-capable software

---

## Scientific Compliance

All biosignal metrics are **Task Force ESC/NASPE (1996) compliant** for HRV analysis:

**Reference**: Task Force of the European Society of Cardiology and the North American Society of Pacing and Electrophysiology (1996). "Heart rate variability: standards of measurement, physiological interpretation, and clinical use." *Circulation* 93(5):1043-1065. DOI: 10.1161/01.CIR.93.5.1043

---

## OSC Address Space

### Core System State

#### `/echoelmusic/coherence`
- **Type**: Float (0.0 - 1.0)
- **Description**: Overall system coherence (bio + audio + visual sync)
- **Update Rate**: 60 Hz
- **Use Cases**: Master parameter for generative composition

#### `/echoelmusic/energy`
- **Type**: Float (0.0 - 1.0)
- **Description**: System energy level (audio amplitude + biofeedback)
- **Update Rate**: 60 Hz
- **Use Cases**: Visual intensity, LED brightness, filter resonance

#### `/echoelmusic/flow`
- **Type**: Float (0.0 - 1.0)
- **Description**: Flow state indicator (coherence + energy average)
- **Update Rate**: 60 Hz
- **Use Cases**: Automation curves, effect wet/dry

#### `/echoelmusic/creativity`
- **Type**: Float (0.0 - 1.0)
- **Description**: Generative creativity parameter
- **Update Rate**: 60 Hz
- **Use Cases**: Algorithmic composition, randomization amount

---

### Evidence-Based System State (NEW in v2.0)

#### `/echoelmusic/system/coherence`
- **Type**: Float (0.0 - 1.0)
- **Description**: Computational system coherence (phase sync across modules)
- **Scientific Basis**: Signal processing correlation coefficient
- **Update Rate**: 60 Hz
- **Use Cases**: Multi-device synchronization quality

#### `/echoelmusic/system/generative_complexity`
- **Type**: Float (0.0 - 1.0)
- **Description**: Algorithmic generative complexity (entropy measure)
- **Scientific Basis**: Shannon entropy / Kolmogorov complexity approximation
- **Update Rate**: 60 Hz
- **Use Cases**: Compositional diversity, pattern variation

#### `/echoelmusic/system/state_resolution`
- **Type**: Event (Bang on trigger)
- **Description**: State resolution event (algorithmic decision point)
- **Scientific Basis**: Decision-making event detection
- **Update Rate**: Event-driven
- **Use Cases**: Trigger note changes, scene transitions

---

### HRV Metrics (Task Force 1996 Compliant)

#### `/echoelmusic/hrv/rmssd`
- **Type**: Float (0.0 - 200.0)
- **Units**: milliseconds (ms)
- **Description**: Root Mean Square of Successive Differences
- **Scientific Basis**: Task Force ESC/NASPE (1996) - Time-domain HRV metric
- **Normal Range**: 20-100 ms (healthy adults), >100 ms (athletes)
- **Interpretation**:
  - Higher = Better parasympathetic function
  - Lower (<20 ms) = Stress, fatigue, overtraining
- **Update Rate**: 1 Hz (calculated from 30-120 RR intervals)
- **Use Cases**: Modulate reverb time, delay feedback, filter cutoff

#### `/echoelmusic/hrv/sdnn`
- **Type**: Float (0.0 - 200.0)
- **Units**: milliseconds (ms)
- **Description**: Standard Deviation of NN intervals
- **Scientific Basis**: Task Force ESC/NASPE (1996) - Overall HRV variability
- **Normal Range**: 50-100 ms (healthy), >100 ms (athletes), <50 ms (stressed)
- **Interpretation**:
  - Reflects all cyclic HRV components (circadian, respiration, baroreflex)
  - Gold standard for overall autonomic function
- **Update Rate**: 1 Hz
- **Use Cases**: Control LFO rate, oscillator detune amount, chorus depth

#### `/echoelmusic/hrv/pnn50`
- **Type**: Float (0.0 - 100.0)
- **Units**: percentage (%)
- **Description**: Percentage of successive RR intervals >50ms different
- **Scientific Basis**: Task Force ESC/NASPE (1996) - Parasympathetic indicator
- **Normal Range**: 5-20% (healthy), >20% (athletes), <5% (stressed)
- **Interpretation**:
  - Vagal tone indicator
  - Higher = Better stress resilience
- **Update Rate**: 1 Hz
- **Use Cases**: Probability of triggering generative events

#### `/echoelmusic/hrv/lf_power`
- **Type**: Float (0.0 - 10000.0)
- **Units**: ms² (milliseconds squared)
- **Description**: Low Frequency power (0.04-0.15 Hz)
- **Scientific Basis**: Task Force ESC/NASPE (1996), Akselrod et al. (1981)
- **Interpretation**:
  - Reflects sympathetic + parasympathetic activity
  - Baroreflex function
  - 10-second rhythms
- **Update Rate**: 1 Hz (requires 30+ RR intervals)
- **Use Cases**: Sub-bass oscillator frequency, drum pattern density

#### `/echoelmusic/hrv/hf_power`
- **Type**: Float (0.0 - 10000.0)
- **Units**: ms² (milliseconds squared)
- **Description**: High Frequency power (0.15-0.4 Hz)
- **Scientific Basis**: Task Force ESC/NASPE (1996), Respiratory Sinus Arrhythmia
- **Interpretation**:
  - Reflects parasympathetic (vagal) activity
  - Respiratory-linked HRV (2.5-7 second rhythms)
  - Higher = Better vagal tone
- **Update Rate**: 1 Hz
- **Use Cases**: Melody contour, arpeggio rate, pad shimmer

#### `/echoelmusic/hrv/lf_hf_ratio`
- **Type**: Float (0.0 - 10.0)
- **Units**: ratio (dimensionless)
- **Description**: LF/HF Ratio (autonomic balance)
- **Scientific Basis**: Task Force ESC/NASPE (1996) - Sympatho-vagal balance
- **Interpretation**:
  - **<1.0**: Parasympathetic dominance (relaxed, recovery, sleep)
  - **1.0-2.0**: Balanced autonomic state
  - **>2.0**: Sympathetic dominance (stressed, alert, exercise)
  - **>5.0**: High stress or pathological
- **Update Rate**: 1 Hz
- **Use Cases**:
  - Map to tension/release in composition
  - Control distortion amount (high ratio = more distortion)
  - Scene selection (calm vs intense)

#### `/echoelmusic/hrv/coherence`
- **Type**: Float (0.0 - 100.0)
- **Units**: score (0-100)
- **Description**: HeartMath-inspired coherence score
- **Scientific Basis**: Approximation based on McCraty et al. (2009)
- **⚠️ Disclaimer**: NOT the proprietary HeartMath algorithm. For validated HeartMath scores, use official devices (Inner Balance, emWave).
- **Interpretation**:
  - **0-40**: Low coherence (stress, anxiety)
  - **40-60**: Medium coherence (transitional)
  - **60-100**: High coherence (flow state potential)
- **Calculation Method**: Peak power in 0.04-0.26 Hz band / Total spectral power
- **Update Rate**: 1 Hz
- **Use Cases**:
  - Global effect wet/dry
  - Visual particle count
  - Harmonic complexity

---

### Respiration

#### `/echoelmusic/resp/rate`
- **Type**: Float (4.0 - 30.0)
- **Units**: breaths per minute (BPM)
- **Description**: Breathing rate derived from HRV spectral analysis
- **Scientific Basis**: Respiratory Sinus Arrhythmia (Hirsch & Bishop 1981)
- **Normal Range**: 12-20 BPM (resting), 6 BPM (coherent breathing)
- **Extraction Method**: FFT peak detection in respiratory band (0.15-0.4 Hz)
- **Update Rate**: 1 Hz
- **Use Cases**:
  - LFO frequency for tremolo/vibrato
  - Automatic tempo adjustment
  - Visual pulsation rate

#### `/echoelmusic/resp/phase`
- **Type**: Float (0.0 - 1.0)
- **Description**: Breath cycle phase (0 = start inhale, 0.5 = start exhale, 1.0 = cycle end)
- **Update Rate**: 60 Hz
- **Use Cases**:
  - Trigger notes on exhale start
  - Filter sweep synchronized to breathing
  - Visual expansion/contraction

#### `/echoelmusic/resp/depth`
- **Type**: Float (0.0 - 1.0)
- **Description**: Relative breath depth (amplitude of respiratory cycle)
- **Update Rate**: 60 Hz
- **Use Cases**:
  - Dynamic range control
  - Reverb size modulation

---

### Timing & Synchronization

#### `/echoelmusic/beat/phase`
- **Type**: Float (0.0 - 1.0)
- **Description**: Beat phase (0 = downbeat, 0.25 = 16th note, 1.0 = next downbeat)
- **Update Rate**: 60 Hz
- **Use Cases**: Visual sync, rhythm alignment

#### `/echoelmusic/breath/phase`
- **Type**: Float (0.0 - 1.0)
- **Description**: Breath cycle phase (same as `/echoelmusic/resp/phase`)
- **Update Rate**: 60 Hz
- **Note**: Duplicate for backward compatibility

---

## OSC Message Format

All messages use standard OSC format:

```
Address: /echoelmusic/hrv/sdnn
Type Tag: f (float)
Data: 65.3
```

### Example OSC Bundle (UDP):
```
/echoelmusic/hrv/rmssd, f 42.5
/echoelmusic/hrv/sdnn, f 65.3
/echoelmusic/hrv/lf_hf_ratio, f 1.8
/echoelmusic/coherence, f 0.73
```

---

## Integration Examples

### TouchDesigner

```python
# CHOP OSC In
oscin1 = op('oscin1')
hrv_sdnn = oscin1['/echoelmusic/hrv/sdnn']
lf_hf_ratio = oscin1['/echoelmusic/hrv/lf_hf_ratio']

# Map to visual parameters
particle_count = int(hrv_sdnn * 100)  # 0-200 particles
color_hue = lf_hf_ratio / 5.0  # 0.0-1.0 (calm=blue, stress=red)
```

### Max/MSP

```
[udpreceive 7000]
|
[oscparse]
|
[route /echoelmusic/hrv/coherence]
|
[scale 0. 100. 0. 1.]  // Normalize to 0-1
|
[*~ 0.5]  // Apply to audio signal
```

### Ableton Live (Max for Live)

```
[udpreceive 7000]
|
[oscparse]
|
[route /echoelmusic/hrv/lf_hf_ratio]
|
[live.remote~ "Track 1" "Device 1" "Frequency"]
```

### Unity (C#)

```csharp
using OscJack;

OscPort receiver = new OscPort(7000, "/echoelmusic/hrv/sdnn");
float hrvSDNN = receiver.GetValueFloat();

// Map to game parameter
float environmentComplexity = hrvSDNN / 100f;  // Normalize
```

---

## Network Configuration

### Default Settings
- **Protocol**: UDP
- **Port**: 7000 (send), 7001 (receive)
- **IP**: 127.0.0.1 (localhost) or 192.168.1.x (LAN)
- **Broadcast**: 255.255.255.255 (all devices on network)

### Performance Considerations
- **Bandwidth**: ~500 bytes/second (at 60 Hz)
- **Latency**: <5ms typical (local network)
- **Jitter**: <1ms (UDP best-effort delivery)

---

## Breaking Changes (v1 → v2)

### Removed (Pseudoscientific):
- ❌ `/echoelmusic/quantum/coherence`
- ❌ `/echoelmusic/quantum/creativity`
- ❌ `/echoelmusic/quantum/collapse`

### Added (Evidence-Based):
- ✅ `/echoelmusic/system/coherence`
- ✅ `/echoelmusic/system/generative_complexity`
- ✅ `/echoelmusic/system/state_resolution`
- ✅ `/echoelmusic/hrv/*` (7 new granular HRV metrics)
- ✅ `/echoelmusic/resp/*` (3 respiration metrics)

### Migration Guide:
```
OLD: /echoelmusic/quantum/coherence
NEW: /echoelmusic/system/coherence (computational coherence)
     OR /echoelmusic/hrv/coherence (HeartMath-inspired)

OLD: /echoelmusic/quantum/creativity
NEW: /echoelmusic/system/generative_complexity

OLD: /echoelmusic/quantum/collapse
NEW: /echoelmusic/system/state_resolution (event-driven)
```

---

## Research Data Export

For research use, prefer **CSV export** over OSC logging:

### CSV Export Format (9 columns):
```
Timestamp,HRV_RMSSD_ms,HRV_SDNN_ms,HRV_pNN50_%,HeartRate_BPM,Coherence_Score,BreathingRate_BPM,LF_Power_ms2,HF_Power_ms2,LF_HF_Ratio
1734393600.123,42.5,65.3,15.2,68,73.4,6.0,520.3,410.8,1.27
```

**Advantages**:
- Higher precision (double vs float)
- Timestamped samples
- No packet loss
- Statistical analysis-ready (R, Python, SPSS)

---

## Scientific Citations

1. **Task Force of the European Society of Cardiology and the North American Society of Pacing and Electrophysiology** (1996). "Heart rate variability: standards of measurement, physiological interpretation, and clinical use." *Circulation* 93(5):1043-1065. DOI: 10.1161/01.CIR.93.5.1043

2. **Akselrod, S., Gordon, D., Ubel, F. A., Shannon, D. C., Berger, A. C., & Cohen, R. J.** (1981). "Power spectrum analysis of heart rate fluctuation: a quantitative probe of beat-to-beat cardiovascular control." *Science* 213(4504):220-222. DOI: 10.1126/science.6166045

3. **McCraty, R., Atkinson, M., Tomasino, D., & Bradley, R. T.** (2009). "The coherent heart: Heart-brain interactions, psychophysiological coherence, and the emergence of system-wide order." *Integral Review* 5(2):10-115.

4. **Hirsch, J. A., & Bishop, B.** (1981). "Respiratory sinus arrhythmia in humans: how breathing pattern modulates heart rate." *American Journal of Physiology* 241(4):H620-H629.

5. **Berntson, G. G., Bigger, J. T., Eckberg, D. L., et al.** (1997). "Heart rate variability: Origins, methods, and interpretive caveats." *Psychophysiology* 34(6):623-648.

---

## Support & Contact

**Issue Tracker**: https://github.com/vibrationalforce/Echoelmusic/issues
**Email**: (provide if available)
**Documentation**: [ADVANCED_NEUROSCIENCE_EVIDENCE_BASE.md](ADVANCED_NEUROSCIENCE_EVIDENCE_BASE.md)

---

**Version**: 2.0 (Evidence-Based)
**Last Updated**: 2025-12-16
**License**: MIT
**Compliance**: Task Force ESC/NASPE (1996) HRV Standards

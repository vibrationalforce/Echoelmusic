# Organ Resonance Research: Scientific Foundation for CoherenceCore

## Executive Summary

This document synthesizes peer-reviewed research on biomechanical organ resonance detection using mobile consumer sensors. It establishes the scientific basis for CoherenceCore's EVM (Eulerian Video Magnification) and frequency analysis capabilities.

**Key Finding:** While direct organ scanning is not possible with current smartphone sensors, surface micro-vibration analysis combined with multi-sensor fusion enables valuable wellness screening and longitudinal monitoring.

---

## 1. Theoretical Foundations

### 1.1 Tissue Elastography Principles

Medical imaging uses the principle of **resonance** through elastography - quantifying tissue stiffness as a biomarker for pathological changes (fibrosis, inflammation, tumors).

**Physical Basis:**
- External mechanical vibrations (20-500 Hz) create shear waves
- Wave velocity correlates directly with tissue shear modulus
- Biological tissues behave as **viscoelastic media** (elastic + viscous components)

### 1.2 Organ Resonance Frequencies (Clinical Reference)

| Organ | Clinical Frequency (Hz) | Pathology Detected | Measurement Parameter |
|-------|-------------------------|--------------------|-----------------------|
| Liver | 60 | Fibrosis, Cirrhosis, Steatosis | Shear Modulus (kPa) |
| Heart | 80-140 | Myocardial Stiffness, HOCM | Myocardial Strain |
| Spleen | 100 | Portal Hypertension | Spleen Stiffness (SSM) |
| Brain | 25-62.5 | Neurodegenerative Processes | Viscoelasticity |

**Source:** MR Elastography clinical studies (PMC6223825, PMC3066083)

### 1.3 Body Eigenfrequencies

Human body eigenfrequencies in sitting/standing position: **1-20 Hz**
- Strongly dependent on posture and soft tissue damping
- Higher frequencies (cellular level) influenced by membrane tension

**Source:** FAA Technical Report AM63-30pt11

---

## 2. iPhone Sensor Capabilities

### 2.1 LiDAR Scanner (iPhone 12 Pro+)

| Specification | Value | Relevance for Resonance |
|---------------|-------|-------------------------|
| Resolution | 256 × 192 depth points | Spatial vibration distribution |
| **Effective Sampling Rate** | **15 Hz** (not 60 Hz as API suggests) | **Max detectable: 7.5 Hz (Nyquist)** |
| Range | 0.3-5m (optimal: 0.3-2m) | Measurement distance |
| Static Accuracy | ~1 cm | 3D reconstruction |

**Critical Limitation:** LiDAR cannot detect organ resonances (>20 Hz) due to sampling rate constraints.

**Source:** MDPI Sensors 23(18):7832 (PMC10537187)

### 2.2 CMOS Camera Sensors

| Specification | Value | Relevance for Resonance |
|---------------|-------|-------------------------|
| Resolution | Up to 48MP | Spatial detail |
| Frame Rate (4K) | 60 fps | **Max detectable: 30 Hz** |
| Frame Rate (1080p) | 120 fps | **Max detectable: 60 Hz** |
| Slow Motion | 240 fps | **Max detectable: 120 Hz** |

**Key Advantage:** Camera + EVM enables detection of clinically relevant frequencies (30-60 Hz).

### 2.3 Inertial Measurement Unit (IMU)

| Specification | Value | Relevance for Resonance |
|---------------|-------|-------------------------|
| Accelerometer Rate | ~100 Hz | Direct mechanical coupling |
| Gyroscope Rate | ~100 Hz | Orientation tracking |

**Application:** Active measurement with device contact enables 50 Hz detection range.

---

## 3. Eulerian Video Magnification (EVM)

### 3.1 Algorithm Overview

EVM amplifies invisible color/motion changes in standard video:

1. **Spatial Decomposition:** Laplacian pyramid breakdown
2. **Temporal Filtering:** Bandpass filter on pixel time series
3. **Amplification:** Magnify target frequency band
4. **Reconstruction:** Combine amplified signal with original

### 3.2 Validated Applications

- Contactless heart rate measurement (r=0.99 correlation with ECG)
- Pulse wave velocity detection
- Respiratory rate extraction
- Subtle motion visualization

**Source:** MIT CSAIL (people.csail.mit.edu/mrub/evm), IEEE 10392739

### 3.3 Implementation Constraints

| Factor | Constraint | Mitigation |
|--------|------------|------------|
| Computational Load | High (pyramids + filtering) | Metal/CoreML acceleration |
| Motion Artifacts | Camera shake amplified | IMU-based stabilization |
| Lighting | Inconsistent illumination | HDR, exposure lock |
| Distance | Signal strength decreases | Optimal range: 30-100cm |

---

## 4. Biophysical Challenges

### 4.1 Acoustic Impedance

The acoustic impedance (Z = ρv) determines energy transfer between tissue layers.

| Tissue Type | Density ρ (kg/m³) | Sound Velocity v (m/s) | Impedance Z (10⁶ kg/m²s) |
|-------------|-------------------|------------------------|--------------------------|
| Liver | 1050 | 1570 | 1.65 |
| Muscle | 1040 | 1580 | 1.64 |
| Fat | 925 | 1450 | 1.34 |
| Skin | 1100 | 1600 | 1.76 |
| **Air** | 1.2 | 343 | **0.0004** |

**Critical Issue:** ~100% reflection at skin-air interface without coupling medium.

### 4.2 Tissue Damping

Subcutaneous fat acts as a **mechanical low-pass filter**:
- Preferentially absorbs higher frequencies
- Reduces amplitude of deep organ vibrations
- Creates "folded" signal (organ + transmission path)

### 4.3 Individual Variability

| Factor | Impact | Range |
|--------|--------|-------|
| BMI | Fat layer thickness | 15-45 |
| Age | Skin/tissue elasticity | 18-90 years |
| Liver Mass | Resonance frequency | 670-2900g (male) |

**Implication:** Individual calibration required for absolute measurements.

---

## 5. Organ Mass Reference Data

| Organ | Male Average (g) | Female Average (g) | Variability Factors |
|-------|------------------|--------------------|--------------------|
| Heart | 365 | 312 | BMI, physical activity |
| Liver | 1677 | 1475 | Alcohol, fatty liver |
| Spleen | 115-170 | 108-162 | Infections, portal HTN |
| Kidney (L) | 162 | 135 | Hydration, age |
| Brain | 1224-1335 | 1114-1228 | Age, sex |

**Source:** PMC5932513, Zenodo 13959413

---

## 6. Recommended Architecture: Multi-Sensor Fusion

### 6.1 Sensor Roles

```
┌─────────────────────────────────────────────────────────────┐
│                  MULTI-SENSOR FUSION MODEL                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   CAMERA     │  │    LiDAR     │  │   HAPTIC     │       │
│  │  (60-120Hz)  │  │   (15Hz)     │  │  (100Hz+)    │       │
│  │              │  │              │  │              │       │
│  │  EVM-based   │  │  Breathing   │  │  Active      │       │
│  │  micro-      │  │  compen-     │  │  tissue      │       │
│  │  vibration   │  │  sation      │  │  excitation  │       │
│  │  detection   │  │  + position  │  │  + response  │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                 │                 │               │
│         └────────────┬────┴────────────────┘               │
│                      ▼                                      │
│         ┌──────────────────────────┐                       │
│         │     FUSION ENGINE        │                       │
│         │  - Blind Source Sep.     │                       │
│         │  - Kalman Filtering      │                       │
│         │  - ML Classification     │                       │
│         └────────────┬─────────────┘                       │
│                      ▼                                      │
│         ┌──────────────────────────┐                       │
│         │   BIOPHYSICAL MODEL      │                       │
│         │  - Age/BMI correction    │                       │
│         │  - Impedance modeling    │                       │
│         │  - Damping compensation  │                       │
│         └────────────┬─────────────┘                       │
│                      ▼                                      │
│         ┌──────────────────────────┐                       │
│         │    OUTPUT METRICS        │                       │
│         │  - Frequency spectrum    │                       │
│         │  - Coherence index       │                       │
│         │  - Trend analysis        │                       │
│         └──────────────────────────┘                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Measurement Modes

**Passive Mode:**
- Analyze natural vibrations (heartbeat, breathing)
- Camera-based EVM for surface motion
- Similar to seismocardiography

**Active Mode:**
- Use Taptic Engine to deliver chirp impulse (frequency sweep)
- IMU measures mechanical tissue response
- "Active palpation" with device as actuator + sensor

---

## 7. Clinical Validation Requirements

### 7.1 Regulatory Classification

- **FDA Class II** device for vital sign measurement
- Requires 510(k) clearance with clinical validation
- Reference standard: MRE or Ultrasound Elastography

### 7.2 Validation Metrics

| Metric | Target | Method |
|--------|--------|--------|
| Accuracy | r > 0.85 vs gold standard | Bland-Altman analysis |
| Precision | CV < 10% | Test-retest reliability |
| Sensitivity | > 80% | Pathology detection |
| Specificity | > 80% | False positive rate |

---

## 8. Differentiation from Pseudoscience

### 8.1 What This IS NOT

- **Bioresonance therapy** - No evidence beyond placebo (Wikipedia: Bioresonanztherapie)
- **Bioscan-SWA devices** - Cannot distinguish human from dead material in clinical tests
- **Energetic frequency diagnosis** - No physical basis

### 8.2 What This IS

- **Mechanical vibration analysis** - Physics-based measurement
- **Surface micro-motion detection** - Validated EVM methodology
- **Trend monitoring** - Longitudinal changes, not absolute diagnosis
- **Wellness screening tool** - NOT a medical diagnostic device

---

## 9. Implementation Priorities for CoherenceCore

### 9.1 High Priority (Scientifically Validated)

1. **EVM at 60fps** - Detect 30Hz micro-vibrations
2. **Breathing rate extraction** - 0.1-0.5 Hz band
3. **Heart rate variability** - 1-2 Hz band via ballistocardiography
4. **Coherence trending** - Longitudinal wellness monitoring

### 9.2 Medium Priority (Research-Backed)

1. **Active haptic measurement** - Taptic + IMU response analysis
2. **Multi-sensor fusion** - Camera + LiDAR + IMU integration
3. **Individual calibration** - BMI/age correction models

### 9.3 Future Research (Requires Clinical Validation)

1. **Tissue stiffness estimation** - Correlate with elastography
2. **Organ-specific frequency signatures** - Deep learning classification
3. **Pathology screening** - NAFLD, fibrosis progression

---

## 10. References

1. PMC6223825 - MR Elastography basic principles and clinical applications
2. PMC3066083 - Magnetic Resonance Elastography review
3. PMC10537187 - iPhone LiDAR vibration measurement characterization
4. MIT CSAIL - Eulerian Video Magnification (people.csail.mit.edu/mrub/evm)
5. IEEE 10392739 - Remote heart ailment detection using EVM
6. PMC5867366 - Wearable BCG and SCG systems
7. PMC5932513 - Internal organ weights correlation study
8. MDPI Sensors 23(18):7832 - iPhone LiDAR for modal analysis
9. FAA AM63-30pt11 - Cellular resonance frequencies
10. JMIR Formative Research e56921 - Light Heart mobile validation

---

## Disclaimer

**CoherenceCore is a wellness/informational tool, NOT a medical device.**

- No diagnostic claims are made
- Results should not replace professional medical evaluation
- Frequency-based wellness features are for relaxation and self-awareness only
- Consult healthcare professionals for medical concerns

---

*Document Version: 1.0*
*Last Updated: 2026-01-14*
*Based on: Deep Research - Biomechanische Analyse der Organresonanz*

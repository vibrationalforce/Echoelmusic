#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>

/**
 * BeatSlicer - Intelligent Transient-Aware Audio Slicer
 *
 * Advanced beat detection and slicing for breakbeats, drums, and loops.
 * Uses multi-band transient detection for accurate slice point placement.
 *
 * Features:
 * - Multi-band transient detection (low/mid/high frequency)
 * - Onset strength analysis
 * - Beat-grid snapping
 * - Zero-crossing alignment
 * - Slice quantization
 * - MIDI note assignment
 * - Export to sampler formats
 *
 * Inspired by: ReCycle, Serato Sample, Ableton Simpler
 */
class BeatSlicer
{
public:
    //==========================================================================
    // Slice Marker
    //==========================================================================

    struct SliceMarker
    {
        int samplePosition = 0;       // Sample position in audio
        float onsetStrength = 0.0f;   // 0.0 to 1.0 (transient intensity)
        float spectralCentroid = 0.0f; // Brightness of transient
        bool isOnBeat = false;        // True if aligned to beat grid
        int beatNumber = 0;           // Which beat (1, 2, 3, 4...)
        int midiNote = 36;            // Assigned MIDI note

        // Frequency content
        float lowEnergy = 0.0f;       // Sub/bass content
        float midEnergy = 0.0f;       // Mid content
        float highEnergy = 0.0f;      // High/cymbal content
    };

    //==========================================================================
    // Detection Mode
    //==========================================================================

    enum class DetectionMode
    {
        AllTransients,     // Detect all transients (snare, kick, hats, everything)
        KickFocused,       // Focus on low-frequency transients (kicks)
        SnareFocused,      // Focus on mid-frequency transients (snares)
        HiHatFocused,      // Focus on high-frequency transients (hats/cymbals)
        Percussive,        // All percussive elements
        Melodic,           // Melodic note onsets
        Combined           // Multi-band combined detection
    };

    //==========================================================================
    // Quantize Grid
    //==========================================================================

    enum class QuantizeGrid
    {
        Off,
        Quarter,           // 1/4 notes
        Eighth,            // 1/8 notes
        Sixteenth,         // 1/16 notes
        ThirtySecond,      // 1/32 notes
        Triplet8th,        // 1/8 triplets
        Triplet16th        // 1/16 triplets
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    BeatSlicer();
    ~BeatSlicer() = default;

    //==========================================================================
    // Audio Input
    //==========================================================================

    /** Load audio for slicing */
    void loadAudio(const juce::AudioBuffer<float>& buffer, double sampleRate);

    /** Load audio from file */
    bool loadAudioFromFile(const juce::File& audioFile);

    /** Set BPM for beat-grid alignment */
    void setBPM(float bpm);

    /** Get detected/set BPM */
    float getBPM() const { return bpm; }

    //==========================================================================
    // Detection Settings
    //==========================================================================

    /** Set detection mode */
    void setDetectionMode(DetectionMode mode);

    /** Set detection sensitivity (0.0 to 1.0) */
    void setSensitivity(float sensitivity);

    /** Set minimum slice length (ms) */
    void setMinSliceLength(float ms);

    /** Set maximum slice count */
    void setMaxSlices(int count);

    /** Set quantize grid */
    void setQuantizeGrid(QuantizeGrid grid);

    /** Set quantize strength (0.0 = off, 1.0 = hard quantize) */
    void setQuantizeStrength(float strength);

    /** Enable/disable zero-crossing alignment */
    void setZeroCrossingAlignment(bool enabled);

    //==========================================================================
    // Frequency Band Settings
    //==========================================================================

    /** Set low band range (Hz) */
    void setLowBandRange(float minHz, float maxHz);

    /** Set mid band range (Hz) */
    void setMidBandRange(float minHz, float maxHz);

    /** Set high band range (Hz) */
    void setHighBandRange(float minHz, float maxHz);

    /** Set band weights for detection */
    void setBandWeights(float lowWeight, float midWeight, float highWeight);

    //==========================================================================
    // Slicing Operations
    //==========================================================================

    /** Analyze and detect slice points */
    void analyze();

    /** Get slice markers */
    const std::vector<SliceMarker>& getSliceMarkers() const { return sliceMarkers; }

    /** Get slice count */
    int getSliceCount() const { return static_cast<int>(sliceMarkers.size()); }

    /** Add manual slice point */
    void addSlicePoint(int samplePosition);

    /** Remove slice at index */
    void removeSlice(int index);

    /** Move slice position */
    void moveSlice(int index, int newSamplePosition);

    /** Clear all slices */
    void clearSlices();

    /** Quantize all slices to grid */
    void quantizeAllSlices();

    /** Assign MIDI notes to slices (starting from baseNote) */
    void assignMIDINotes(int baseNote = 36);

    //==========================================================================
    // Slice Export
    //==========================================================================

    /** Get audio for specific slice */
    juce::AudioBuffer<float> getSliceAudio(int sliceIndex) const;

    /** Export all slices to folder */
    bool exportSlices(const juce::File& folder, const juce::String& baseName);

    /** Export slice map (for sampler import) */
    bool exportSliceMap(const juce::File& file);

    //==========================================================================
    // Visualization Data
    //==========================================================================

    /** Get onset detection function (for visualization) */
    const std::vector<float>& getOnsetFunction() const { return onsetFunction; }

    /** Get waveform peaks (for visualization) */
    const std::vector<float>& getWaveformPeaks() const { return waveformPeaks; }

    /** Get spectral flux (for visualization) */
    const std::vector<float>& getSpectralFlux() const { return spectralFlux; }

private:
    //==========================================================================
    // Audio Data
    //==========================================================================

    juce::AudioBuffer<float> audioBuffer;
    double sampleRate = 48000.0;
    float bpm = 0.0f;

    //==========================================================================
    // Detection Settings
    //==========================================================================

    DetectionMode detectionMode = DetectionMode::Combined;
    float sensitivity = 0.5f;
    float minSliceLengthMs = 50.0f;
    int maxSlices = 64;
    QuantizeGrid quantizeGrid = QuantizeGrid::Sixteenth;
    float quantizeStrength = 0.5f;
    bool zeroCrossingAlignment = true;

    // Band ranges (Hz)
    float lowBandMin = 20.0f, lowBandMax = 200.0f;
    float midBandMin = 200.0f, midBandMax = 4000.0f;
    float highBandMin = 4000.0f, highBandMax = 20000.0f;

    // Band weights
    float lowWeight = 1.0f;
    float midWeight = 1.0f;
    float highWeight = 0.8f;

    //==========================================================================
    // Analysis Results
    //==========================================================================

    std::vector<SliceMarker> sliceMarkers;
    std::vector<float> onsetFunction;
    std::vector<float> waveformPeaks;
    std::vector<float> spectralFlux;
    std::vector<float> lowBandEnergy;
    std::vector<float> midBandEnergy;
    std::vector<float> highBandEnergy;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void computeOnsetFunction();
    void computeSpectralFlux();
    void computeBandEnergies();
    void detectPeaks(std::vector<int>& peakPositions);
    void applyQuantization();
    void alignToZeroCrossings();
    float calculateSpectralCentroid(int position, int windowSize);
    int findNearestZeroCrossing(int position, int searchRange);
    int quantizeToGrid(int samplePosition);

    // FFT for spectral analysis
    static constexpr int fftOrder = 11;  // 2048 samples
    static constexpr int fftSize = 1 << fftOrder;
    juce::dsp::FFT fft{fftOrder};
    std::array<float, fftSize * 2> fftData;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BeatSlicer)
};

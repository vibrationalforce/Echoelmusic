#include "QuantumAudioEngine.h"
#include <cmath>

//==============================================================================
// SuperpositionSynthesizer Implementation
//==============================================================================

SuperpositionSynthesizer::SuperpositionSynthesizer()
{
}

juce::AudioBuffer<float> SuperpositionSynthesizer::createSuperposition(
    const juce::Array<QuantumState>& inputStates,
    double sampleRate)
{
    if (inputStates.isEmpty())
        return juce::AudioBuffer<float>(1, 0);

    // Find longest state
    int maxSamples = 0;
    for (const auto& state : inputStates)
        maxSamples = juce::jmax(maxSamples, state.waveFunction.getNumSamples());

    juce::AudioBuffer<float> result(1, maxSamples);
    result.clear();

    // Add all states together (superposition!)
    for (const auto& state : inputStates)
    {
        for (int i = 0; i < state.waveFunction.getNumSamples(); ++i)
        {
            result.setSample(0, i,
                result.getSample(0, i) +
                state.waveFunction.getSample(0, i) * state.amplitude);
        }
    }

    // Normalize
    result.applyGain(1.0f / juce::jmax(1.0f, (float)inputStates.size()));

    return result;
}

void SuperpositionSynthesizer::addState(const QuantumState& state)
{
    states.add(state);
}

void SuperpositionSynthesizer::removeState(int quantumNumber)
{
    for (int i = 0; i < states.size(); ++i)
    {
        if (states[i].quantumNumber == quantumNumber)
        {
            states.remove(i);
            break;
        }
    }
}

juce::Array<QuantumState> SuperpositionSynthesizer::getStates() const
{
    return states;
}

QuantumState SuperpositionSynthesizer::collapseWaveFunction()
{
    if (states.isEmpty())
        return QuantumState();

    // Weighted random selection based on amplitude (probability)
    float totalProbability = 0.0f;
    for (const auto& state : states)
        totalProbability += state.amplitude * state.amplitude;  // Probability = |amplitude|²

    float randomValue = random.nextFloat() * totalProbability;
    float cumulative = 0.0f;

    for (const auto& state : states)
    {
        cumulative += state.amplitude * state.amplitude;
        if (randomValue <= cumulative)
            return state;
    }

    return states[0];
}

//==============================================================================
// QuantumEntanglement Implementation
//==============================================================================

QuantumEntanglement::QuantumEntanglement()
{
}

QuantumEntanglement::EntangledPair QuantumEntanglement::entangleSignals(
    const juce::AudioBuffer<float>& signalA,
    const juce::AudioBuffer<float>& signalB,
    float entanglementStrength)
{
    EntangledPair pair;
    int numSamples = juce::jmin(signalA.getNumSamples(), signalB.getNumSamples());

    pair.signalA.setSize(1, numSamples);
    pair.signalB.setSize(1, numSamples);

    // Signal A modulates Signal B (and vice versa)
    for (int i = 0; i < numSamples; ++i)
    {
        float a = signalA.getSample(0, i);
        float b = signalB.getSample(0, i);

        // Cross-modulation
        pair.signalA.setSample(0, i, a + b * entanglementStrength);
        pair.signalB.setSample(0, i, b + a * entanglementStrength);
    }

    return pair;
}

juce::AudioBuffer<float> QuantumEntanglement::fmEntanglement(
    float carrierFreq,
    float modulatorFreq,
    float modulationIndex,
    double sampleRate,
    int numSamples)
{
    juce::AudioBuffer<float> result(1, numSamples);

    for (int i = 0; i < numSamples; ++i)
    {
        float time = i / (float)sampleRate;

        // Modulator
        float modulator = std::sin(2.0f * juce::MathConstants<float>::pi * modulatorFreq * time);

        // Carrier modulated by modulator (entangled!)
        float carrier = std::sin(2.0f * juce::MathConstants<float>::pi * carrierFreq * time +
                                modulationIndex * modulator);

        result.setSample(0, i, carrier);
    }

    return result;
}

juce::AudioBuffer<float> QuantumEntanglement::ringModulationEntanglement(
    const juce::AudioBuffer<float>& signalA,
    const juce::AudioBuffer<float>& signalB)
{
    int numSamples = juce::jmin(signalA.getNumSamples(), signalB.getNumSamples());
    juce::AudioBuffer<float> result(1, numSamples);

    // Ring modulation: multiply signals
    for (int i = 0; i < numSamples; ++i)
    {
        result.setSample(0, i,
            signalA.getSample(0, i) * signalB.getSample(0, i));
    }

    return result;
}

//==============================================================================
// HeisenbergUncertainty Implementation
//==============================================================================

HeisenbergUncertainty::HeisenbergUncertainty()
{
}

juce::AudioBuffer<float> HeisenbergUncertainty::uncertaintyGranular(
    const juce::AudioBuffer<float>& source,
    float uncertaintyAmount,
    double sampleRate)
{
    if (source.getNumSamples() == 0)
        return juce::AudioBuffer<float>(1, 0);

    juce::AudioBuffer<float> result(1, source.getNumSamples());
    result.clear();

    auto grains = generateGrains(source.getNumSamples(), sampleRate);

    // Apply each grain
    for (const auto& grain : grains)
    {
        int startSample = (int)(grain.position * source.getNumSamples());
        startSample = juce::jlimit(0, source.getNumSamples() - grain.length, startSample);

        for (int i = 0; i < grain.length && (startSample + i) < source.getNumSamples(); ++i)
        {
            // Window function (Hann window)
            float window = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * i / grain.length));

            float sample = source.getSample(0, startSample + i);
            result.setSample(0, startSample + i,
                result.getSample(0, startSample + i) + sample * window * grain.amplitude);
        }
    }

    return result;
}

void HeisenbergUncertainty::setGrainSize(int samples)
{
    grainSize = samples;
}

void HeisenbergUncertainty::setGrainDensity(float grainsPerSecond)
{
    grainDensity = grainsPerSecond;
}

void HeisenbergUncertainty::setPositionUncertainty(float amount)
{
    positionUncertainty = juce::jlimit(0.0f, 1.0f, amount);
}

void HeisenbergUncertainty::setFrequencyUncertainty(float amount)
{
    frequencyUncertainty = juce::jlimit(0.0f, 1.0f, amount);
}

juce::Array<HeisenbergUncertainty::Grain> HeisenbergUncertainty::generateGrains(
    int numSamples,
    double sampleRate)
{
    juce::Array<Grain> grains;

    float duration = numSamples / (float)sampleRate;
    int numGrains = (int)(grainDensity * duration);

    for (int i = 0; i < numGrains; ++i)
    {
        Grain grain;

        // Position with uncertainty
        grain.position = random.nextFloat();
        if (positionUncertainty > 0.0f)
            grain.position += (random.nextFloat() - 0.5f) * positionUncertainty;
        grain.position = juce::jlimit(0.0f, 1.0f, grain.position);

        // Frequency with uncertainty
        grain.frequency = 1.0f;
        if (frequencyUncertainty > 0.0f)
            grain.frequency += (random.nextFloat() - 0.5f) * frequencyUncertainty * 2.0f;

        grain.amplitude = 0.5f;
        grain.length = (int)(grainSize * grain.frequency);

        grains.add(grain);
    }

    return grains;
}

//==============================================================================
// QuantumTunneling Implementation
//==============================================================================

QuantumTunneling::QuantumTunneling() : fft(10)  // 2^10 = 1024 FFT size
{
}

juce::AudioBuffer<float> QuantumTunneling::spectralTunneling(
    const juce::AudioBuffer<float>& audio,
    float barrierFrequency,
    float tunnelingProbability,
    double sampleRate)
{
    // Simple implementation: frequencies can "tunnel" through barriers
    juce::AudioBuffer<float> result = audio;

    // Apply random spectral modifications (tunneling effect)
    for (int i = 0; i < result.getNumSamples(); ++i)
    {
        if (random.nextFloat() < tunnelingProbability)
        {
            // "Tunnel" to different frequency content
            result.setSample(0, i, result.getSample(0, i) * (1.0f + random.nextFloat() * 0.5f));
        }
    }

    return result;
}

juce::AudioBuffer<float> QuantumTunneling::crossFrequencyBarrier(
    const juce::AudioBuffer<float>& audio,
    float lowBarrier,
    float highBarrier,
    float tunnelingAmount,
    double sampleRate)
{
    // Placeholder - would do FFT-based frequency barrier crossing
    return spectralTunneling(audio, (lowBarrier + highBarrier) / 2.0f, tunnelingAmount, sampleRate);
}

//==============================================================================
// WaveInterference Implementation
//==============================================================================

WaveInterference::WaveInterference()
{
}

juce::AudioBuffer<float> WaveInterference::createInterferencePattern(
    const juce::AudioBuffer<float>& wave1,
    const juce::AudioBuffer<float>& wave2,
    float phaseOffset)
{
    int numSamples = juce::jmin(wave1.getNumSamples(), wave2.getNumSamples());
    juce::AudioBuffer<float> result(1, numSamples);

    for (int i = 0; i < numSamples; ++i)
    {
        float w1 = wave1.getSample(0, i);
        float w2 = wave2.getSample(0, i);

        // Interference: add waves with phase offset
        float interference = w1 + w2 * std::cos(phaseOffset);

        result.setSample(0, i, interference);
    }

    return result;
}

juce::AudioBuffer<float> WaveInterference::createStandingWave(
    float frequency,
    float amplitude,
    double sampleRate,
    int numSamples)
{
    juce::AudioBuffer<float> result(1, numSamples);

    // Standing wave = wave + reflected wave
    for (int i = 0; i < numSamples; ++i)
    {
        float time = i / (float)sampleRate;
        float wave = std::sin(2.0f * juce::MathConstants<float>::pi * frequency * time);
        float reflected = std::sin(2.0f * juce::MathConstants<float>::pi * frequency * time + juce::MathConstants<float>::pi);

        result.setSample(0, i, (wave + reflected) * amplitude * 0.5f);
    }

    return result;
}

juce::AudioBuffer<float> WaveInterference::diffractionSpread(
    const juce::AudioBuffer<float>& audio,
    float spreadAmount)
{
    juce::AudioBuffer<float> result = audio;

    // Simple diffraction: spread signal over time
    for (int i = 1; i < result.getNumSamples(); ++i)
    {
        float spread = result.getSample(0, i - 1) * spreadAmount;
        result.setSample(0, i, result.getSample(0, i) + spread);
    }

    return result;
}

float WaveInterference::calculateInterference(float amplitude1, float amplitude2, float phaseDiff)
{
    // Interference formula
    return std::sqrt(amplitude1 * amplitude1 + amplitude2 * amplitude2 +
                    2.0f * amplitude1 * amplitude2 * std::cos(phaseDiff));
}

//==============================================================================
// QuantumDecoherence Implementation
//==============================================================================

QuantumDecoherence::QuantumDecoherence() : delay(48000)
{
}

juce::AudioBuffer<float> QuantumDecoherence::applyDecoherence(
    const juce::AudioBuffer<float>& audio,
    float coherenceTime,
    double sampleRate)
{
    juce::AudioBuffer<float> result = audio;

    // Decoherence: gradual decay over time
    float decayRate = 1.0f / (coherenceTime * sampleRate);

    for (int i = 0; i < result.getNumSamples(); ++i)
    {
        float decay = std::exp(-decayRate * i);
        result.setSample(0, i, result.getSample(0, i) * decay);
    }

    return result;
}

juce::AudioBuffer<float> QuantumDecoherence::gradualCollapse(
    const juce::AudioBuffer<float>& audio,
    float collapseRate,
    double sampleRate)
{
    return applyDecoherence(audio, 1.0f / collapseRate, sampleRate);
}

//==============================================================================
// SchrodingersOscillator Implementation
//==============================================================================

SchrodingersOscillator::SchrodingersOscillator()
{
    waveforms.add("sine");
    waveforms.add("square");
    waveforms.add("sawtooth");
    waveforms.add("triangle");
}

juce::AudioBuffer<float> SchrodingersOscillator::probabilisticOscillator(
    float frequency,
    const juce::StringArray& possibleWaveforms,
    float measurementRate,
    double sampleRate,
    int numSamples)
{
    juce::AudioBuffer<float> result(1, numSamples);

    float phase = 0.0f;
    float phaseIncrement = frequency / (float)sampleRate;
    int measurementInterval = (int)(sampleRate / measurementRate);

    for (int i = 0; i < numSamples; ++i)
    {
        // "Measure" (collapse) every measurementInterval samples
        if (i % measurementInterval == 0)
        {
            currentWaveform = random.nextInt(possibleWaveforms.size());
        }

        float sample = generateWaveformSample(possibleWaveforms[currentWaveform], phase);
        result.setSample(0, i, sample);

        phase += phaseIncrement;
        if (phase >= 1.0f)
            phase -= 1.0f;
    }

    return result;
}

void SchrodingersOscillator::setPossibleWaveforms(const juce::StringArray& waveformList)
{
    waveforms = waveformList;
}

float SchrodingersOscillator::generateWaveformSample(const juce::String& waveform, float phase)
{
    if (waveform == "sine")
        return std::sin(2.0f * juce::MathConstants<float>::pi * phase);

    else if (waveform == "square")
        return phase < 0.5f ? 1.0f : -1.0f;

    else if (waveform == "sawtooth")
        return 2.0f * phase - 1.0f;

    else if (waveform == "triangle")
        return phase < 0.5f ? (4.0f * phase - 1.0f) : (3.0f - 4.0f * phase);

    return 0.0f;
}

//==============================================================================
// QuantumAudioEngine Implementation
//==============================================================================

QuantumAudioEngine::QuantumAudioEngine()
{
    DBG("QuantumAudioEngine initialized - Quantum-inspired audio processing");
    DBG(getEducationalDisclaimer());

    initializeExplanations();
}

QuantumAudioEngine::~QuantumAudioEngine()
{
}

juce::String QuantumAudioEngine::getEducationalDisclaimer() const
{
    return "⚠️ EDUCATIONAL ANALOGIES - NOT REAL QUANTUM COMPUTING! ⚠️\n\n"
           "This engine uses quantum physics CONCEPTS as creative inspiration for audio processing.\n"
           "These are NOT actual quantum computing algorithms.\n"
           "They are educational analogies that help understand complex audio processing through quantum metaphors.";
}

void QuantumAudioEngine::initializeExplanations()
{
    conceptExplanations["Superposition"] =
        "Quantum: Particle exists in multiple states simultaneously until measured.\n"
        "Audio: Multiple waveforms/frequencies exist together (additive synthesis).";

    conceptExplanations["Entanglement"] =
        "Quantum: Two particles correlated - measuring one affects the other.\n"
        "Audio: Cross-modulation, FM synthesis, sidechain - one signal affects another.";

    conceptExplanations["Uncertainty"] =
        "Quantum: Cannot know position AND momentum precisely.\n"
        "Audio: Granular synthesis with probabilistic grain placement and pitch.";

    conceptExplanations["Tunneling"] =
        "Quantum: Particle passes through energy barrier.\n"
        "Audio: Frequencies 'tunnel' between spectral bands.";

    conceptExplanations["Interference"] =
        "Quantum: Wave interference patterns.\n"
        "Audio: Phase relationships between signals creating constructive/destructive interference.";

    conceptExplanations["Decoherence"] =
        "Quantum: System loses coherence, becomes classical.\n"
        "Audio: Signal decay, reverb, detuning over time.";

    conceptExplanations["Wave Function Collapse"] =
        "Quantum: Superposition collapses to definite state when measured.\n"
        "Audio: Probabilistic selection from multiple processing options.";
}

//==========================================================================
// Main API Methods
//==========================================================================

juce::AudioBuffer<float> QuantumAudioEngine::superpositionSynth(
    float fundamentalFreq,
    int numStates,
    double sampleRate,
    int numSamples)
{
    juce::Array<QuantumState> states;

    // Create harmonic states
    for (int i = 0; i < numStates; ++i)
    {
        QuantumState state;
        state.quantumNumber = i;
        state.frequency = fundamentalFreq * (i + 1);
        state.amplitude = 1.0f / (i + 1);  // Harmonic series amplitude
        state.waveFunction.setSize(1, numSamples);

        // Generate sine wave
        for (int s = 0; s < numSamples; ++s)
        {
            float time = s / (float)sampleRate;
            float sample = std::sin(2.0f * juce::MathConstants<float>::pi * state.frequency * time);
            state.waveFunction.setSample(0, s, sample);
        }

        states.add(state);
    }

    return superposition.createSuperposition(states, sampleRate);
}

void QuantumAudioEngine::addQuantumState(const QuantumState& state)
{
    superposition.addState(state);
}

QuantumState QuantumAudioEngine::collapseWaveFunction()
{
    return superposition.collapseWaveFunction();
}

juce::AudioBuffer<float> QuantumAudioEngine::entangleSignals(
    const juce::AudioBuffer<float>& signalA,
    const juce::AudioBuffer<float>& signalB,
    float strength)
{
    auto pair = entanglement.entangleSignals(signalA, signalB, strength);
    return pair.signalA;  // Return entangled signal A
}

juce::AudioBuffer<float> QuantumAudioEngine::fmEntanglement(
    float carrierFreq,
    float modulatorFreq,
    float modIndex,
    double sampleRate,
    int numSamples)
{
    return entanglement.fmEntanglement(carrierFreq, modulatorFreq, modIndex, sampleRate, numSamples);
}

juce::AudioBuffer<float> QuantumAudioEngine::uncertaintyGranular(
    const juce::AudioBuffer<float>& source,
    float uncertaintyValue,
    double sampleRate)
{
    return uncertainty.uncertaintyGranular(source, uncertaintyValue, sampleRate);
}

void QuantumAudioEngine::setGranularParameters(int grainSize, float density)
{
    uncertainty.setGrainSize(grainSize);
    uncertainty.setGrainDensity(density);
}

juce::AudioBuffer<float> QuantumAudioEngine::spectralTunneling(
    const juce::AudioBuffer<float>& audio,
    float barrierFreq,
    float probability,
    double sampleRate)
{
    return tunneling.spectralTunneling(audio, barrierFreq, probability, sampleRate);
}

juce::AudioBuffer<float> QuantumAudioEngine::createInterference(
    const juce::AudioBuffer<float>& wave1,
    const juce::AudioBuffer<float>& wave2,
    float phaseOffset)
{
    return interference.createInterferencePattern(wave1, wave2, phaseOffset);
}

juce::AudioBuffer<float> QuantumAudioEngine::createStandingWave(
    float frequency,
    double sampleRate,
    int numSamples)
{
    return interference.createStandingWave(frequency, 1.0f, sampleRate, numSamples);
}

juce::AudioBuffer<float> QuantumAudioEngine::applyDecoherence(
    const juce::AudioBuffer<float>& audio,
    float coherenceTime,
    double sampleRate)
{
    return decoherence.applyDecoherence(audio, coherenceTime, sampleRate);
}

juce::AudioBuffer<float> QuantumAudioEngine::schrodingersOscillator(
    float frequency,
    double sampleRate,
    int numSamples)
{
    juce::StringArray waveforms = {"sine", "square", "sawtooth", "triangle"};
    return schrodingers.probabilisticOscillator(frequency, waveforms, 10.0f, sampleRate, numSamples);
}

juce::AudioBuffer<float> QuantumAudioEngine::applyQuantumEffect(
    const juce::AudioBuffer<float>& audio,
    const juce::String& effectName,
    double sampleRate)
{
    if (effectName == "superposition")
        return superpositionSynth(440.0f, 8, sampleRate, audio.getNumSamples());

    else if (effectName == "uncertainty")
        return uncertaintyGranular(audio, 0.5f, sampleRate);

    else if (effectName == "decoherence")
        return applyDecoherence(audio, 1.0f, sampleRate);

    else if (effectName == "tunneling")
        return spectralTunneling(audio, 1000.0f, 0.3f, sampleRate);

    return audio;
}

juce::StringArray QuantumAudioEngine::getAvailableQuantumEffects() const
{
    juce::StringArray effects;
    effects.add("superposition");
    effects.add("entanglement");
    effects.add("uncertainty");
    effects.add("tunneling");
    effects.add("interference");
    effects.add("decoherence");
    effects.add("schrodingers");

    return effects;
}

juce::String QuantumAudioEngine::getConceptExplanation(const juce::String& concept) const
{
    auto it = conceptExplanations.find(concept);
    if (it != conceptExplanations.end())
        return it->second;

    return "Concept not found.";
}

juce::StringArray QuantumAudioEngine::getAllConcepts() const
{
    juce::StringArray concepts;

    for (const auto& pair : conceptExplanations)
        concepts.add(pair.first);

    return concepts;
}

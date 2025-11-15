#include "FrequencyFusion.h"

//==============================================================================
// Constructor
//==============================================================================

FrequencyFusion::FrequencyFusion()
{
    // Initialize algorithms (DX7-style)
    initializeAlgorithms();

    // Add voices
    for (int i = 0; i < 16; ++i)
    {
        addVoice(new FrequencyFusionVoice(*this));
    }

    // Add sound
    addSound(new FrequencyFusionSound());
}

//==============================================================================
// Operator Management
//==============================================================================

FrequencyFusion::Operator& FrequencyFusion::getOperator(int index)
{
    jassert(index >= 0 && index < numOperators);
    return operators[index];
}

const FrequencyFusion::Operator& FrequencyFusion::getOperator(int index) const
{
    jassert(index >= 0 && index < numOperators);
    return operators[index];
}

void FrequencyFusion::setOperator(int index, const Operator& op)
{
    jassert(index >= 0 && index < numOperators);
    operators[index] = op;
}

//==============================================================================
// Algorithm Management
//==============================================================================

void FrequencyFusion::setAlgorithm(int algorithmIndex)
{
    currentAlgorithm = juce::jlimit(0, numAlgorithms - 1, algorithmIndex);
}

const FrequencyFusion::Algorithm& FrequencyFusion::getAlgorithm(int index) const
{
    jassert(index >= 0 && index < numAlgorithms);
    return algorithms[index];
}

void FrequencyFusion::setModulationMatrix(const std::array<std::array<float, numOperators>, numOperators>& matrix)
{
    algorithms[currentAlgorithm].matrix = matrix;
}

//==============================================================================
// LFO
//==============================================================================

FrequencyFusion::LFO& FrequencyFusion::getLFO()
{
    return lfo;
}

const FrequencyFusion::LFO& FrequencyFusion::getLFO() const
{
    return lfo;
}

void FrequencyFusion::setLFO(const LFO& newLFO)
{
    lfo = newLFO;
}

//==============================================================================
// Global Parameters
//==============================================================================

void FrequencyFusion::setMasterVolume(float volume)
{
    masterVolume = juce::jlimit(0.0f, 1.0f, volume);
}

void FrequencyFusion::setMasterTune(float cents)
{
    masterTune = juce::jlimit(-100.0f, 100.0f, cents);
}

void FrequencyFusion::setPitchBendRange(int semitones)
{
    pitchBendRange = juce::jlimit(0, 24, semitones);
}

void FrequencyFusion::setVoiceCount(int count)
{
    clearVoices();
    for (int i = 0; i < juce::jlimit(1, 32, count); ++i)
    {
        addVoice(new FrequencyFusionVoice(*this));
    }
}

//==============================================================================
// Bio-Reactive Modulation
//==============================================================================

void FrequencyFusion::setBioData(float hrv, float coherence)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
}

//==============================================================================
// Processing
//==============================================================================

void FrequencyFusion::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);
    currentSampleRate = sampleRate;
    setCurrentPlaybackSampleRate(sampleRate);
}

void FrequencyFusion::reset()
{
    allNotesOff(0, false);
}

//==============================================================================
// Algorithm Initialization
//==============================================================================

void FrequencyFusion::initializeAlgorithms()
{
    // Classic DX7 algorithms (simplified - 32 algorithms)
    // Matrix format: matrix[target][source] = modulation amount

    // Algorithm 1: 6→5→4→3→2→1 (Serial stack)
    createAlgorithm(0, "Serial Stack", {{
        {{0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 1: modulated by Op 2
        {{0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f}},  // Op 2: modulated by Op 3
        {{0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f}},  // Op 3: modulated by Op 4
        {{0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f}},  // Op 4: modulated by Op 5
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f}},  // Op 5: modulated by Op 6
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}}   // Op 6: carrier (output)
    }});

    // Algorithm 2: Parallel carriers (3 carriers, 3 modulators)
    createAlgorithm(1, "3 Carriers", {{
        {{0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f}},  // Op 1: modulated by Op 5
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f}},  // Op 2: modulated by Op 6
        {{0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f}},  // Op 3: modulated by Op 4
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 4: modulator
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 5: modulator
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}}   // Op 6: modulator
    }});

    // Algorithm 3: Classic E.Piano (2 stacks)
    createAlgorithm(2, "E.Piano", {{
        {{0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 1: modulated by Op 2
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 2: carrier
        {{0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f}},  // Op 3: modulated by Op 4
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 4: carrier
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 5: unused
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}}   // Op 6: unused
    }});

    // Algorithm 4: Bass (1→2→3, with 4 as carrier)
    createAlgorithm(3, "Bass", {{
        {{0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 1: modulated by Op 2
        {{0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f}},  // Op 2: modulated by Op 3
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 3: modulator
        {{1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 4: carrier (modulated by Op 1)
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}},  // Op 5: unused
        {{0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f}}   // Op 6: unused
    }});

    // Algorithm 5-32: Fill with variations (simplified)
    for (int i = 4; i < numAlgorithms; ++i)
    {
        std::array<std::array<float, numOperators>, numOperators> matrix;
        for (auto& row : matrix)
            row.fill(0.0f);

        // Create simple variations
        if (i % 4 == 0)
        {
            // Parallel carriers
            for (int op = 0; op < 3; ++op)
                matrix[op][op + 3] = 1.0f;
        }
        else if (i % 4 == 1)
        {
            // Serial chain
            for (int op = 0; op < 5; ++op)
                matrix[op][op + 1] = 1.0f;
        }
        else if (i % 4 == 2)
        {
            // Mixed
            matrix[0][1] = 1.0f;
            matrix[2][3] = 1.0f;
            matrix[4][5] = 1.0f;
        }
        else
        {
            // Additive
            // All carriers (no modulation)
        }

        createAlgorithm(i, "Algorithm " + juce::String(i + 1), matrix);
    }
}

void FrequencyFusion::createAlgorithm(int id, const juce::String& name,
                                      const std::array<std::array<float, numOperators>, numOperators>& matrix)
{
    if (id >= 0 && id < numAlgorithms)
    {
        algorithms[id].id = id;
        algorithms[id].name = name;
        algorithms[id].matrix = matrix;
    }
}

//==============================================================================
// Voice Implementation
//==============================================================================

FrequencyFusion::FrequencyFusionVoice::FrequencyFusionVoice(FrequencyFusion& parent)
    : owner(parent)
{
}

bool FrequencyFusion::FrequencyFusionVoice::canPlaySound(juce::SynthesiserSound* sound)
{
    return dynamic_cast<FrequencyFusionSound*>(sound) != nullptr;
}

void FrequencyFusion::FrequencyFusionVoice::startNote(int midiNoteNumber, float vel,
                                                       juce::SynthesiserSound*, int)
{
    currentNote = midiNoteNumber;
    velocity = vel;

    // Initialize operator states
    for (int i = 0; i < numOperators; ++i)
    {
        auto& opState = opStates[i];
        opState.phase = 0.0f;
        opState.output = 0.0f;
        opState.feedbackSample = 0.0f;
        opState.envelopeStage = 0;
        opState.envelopeValue = owner.operators[i].envelopeLevels[0];
        opState.envelopeTarget = owner.operators[i].envelopeLevels[1];
        opState.noteOn = true;

        // Calculate envelope increment
        const float sampleRate = static_cast<float>(getSampleRate());
        const float time = owner.operators[i].envelopeTimes[1];
        if (time > 0.0f)
        {
            opState.envelopeIncrement = (opState.envelopeTarget - opState.envelopeValue) /
                                        (time * sampleRate);
        }
        else
        {
            opState.envelopeIncrement = 1.0f;
        }
    }

    // Reset LFO
    lfoPhase = 0.0f;
    lfoValue = 0.0f;
    lfoFade = 0.0f;
}

void FrequencyFusion::FrequencyFusionVoice::stopNote(float, bool allowTailOff)
{
    if (allowTailOff)
    {
        // Move all envelopes to release stage
        for (auto& opState : opStates)
        {
            opState.noteOn = false;
            opState.envelopeStage = 6;  // Release stage
        }
    }
    else
    {
        clearCurrentNote();
    }
}

void FrequencyFusion::FrequencyFusionVoice::pitchWheelMoved(int newValue)
{
    pitchBend = (newValue - 8192) / 8192.0f;  // -1.0 to +1.0
}

void FrequencyFusion::FrequencyFusionVoice::controllerMoved(int controllerNumber, int newValue)
{
    if (controllerNumber == 1)  // Mod wheel
    {
        modWheel = newValue / 127.0f;
    }
}

void FrequencyFusion::FrequencyFusionVoice::renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                                                             int startSample, int numSamples)
{
    if (!isVoiceActive())
        return;

    const float sampleRate = static_cast<float>(getSampleRate());
    const float baseFreq = juce::MidiMessage::getMidiNoteInHertz(currentNote);

    for (int i = 0; i < numSamples; ++i)
    {
        // Update all envelopes
        for (int op = 0; op < numOperators; ++op)
        {
            updateEnvelope(op, sampleRate);
        }

        // Update LFO
        updateLFO(sampleRate);

        // Get current algorithm
        const auto& algorithm = owner.algorithms[owner.currentAlgorithm];

        // Calculate operator outputs (in reverse order for FM)
        std::array<float, numOperators> opOutputs;
        opOutputs.fill(0.0f);

        for (int op = numOperators - 1; op >= 0; --op)
        {
            if (!owner.operators[op].enabled)
                continue;

            // Calculate modulation input for this operator
            float modulation = 0.0f;
            for (int src = 0; src < numOperators; ++src)
            {
                modulation += opOutputs[src] * algorithm.matrix[op][src];
            }

            // Add feedback
            modulation += opStates[op].feedbackSample * owner.operators[op].feedback;

            // Apply bio-reactive FM depth modulation
            float bioMod = 1.0f + (owner.bioHRV - 0.5f) * 2.0f;  // 0.0 to 2.0
            modulation *= bioMod;

            // Render operator
            float output = renderOperator(op, modulation, sampleRate);
            opOutputs[op] = output;

            // Store for feedback
            opStates[op].feedbackSample = output;
        }

        // Mix carrier operators (operators with no targets)
        float finalOutput = 0.0f;
        int numCarriers = 0;

        for (int op = 0; op < numOperators; ++op)
        {
            // Check if this operator is a carrier (not modulating anyone)
            bool isCarrier = true;
            for (int target = 0; target < numOperators; ++target)
            {
                if (algorithm.matrix[target][op] > 0.0f)
                {
                    isCarrier = false;
                    break;
                }
            }

            if (isCarrier && owner.operators[op].enabled)
            {
                finalOutput += opOutputs[op];
                numCarriers++;
            }
        }

        // Normalize by number of carriers
        if (numCarriers > 0)
        {
            finalOutput /= std::sqrt(static_cast<float>(numCarriers));
        }

        // Apply master volume
        finalOutput *= owner.masterVolume * velocity;

        // Check if all envelopes are finished
        bool allEnvelopesFinished = true;
        for (const auto& opState : opStates)
        {
            if (opState.envelopeValue > 0.001f)
            {
                allEnvelopesFinished = false;
                break;
            }
        }

        if (allEnvelopesFinished)
        {
            clearCurrentNote();
            break;
        }

        // Write to output
        outputBuffer.addSample(0, startSample + i, finalOutput);
        if (outputBuffer.getNumChannels() > 1)
        {
            outputBuffer.addSample(1, startSample + i, finalOutput);
        }
    }
}

//==============================================================================
// Voice Helper Methods
//==============================================================================

float FrequencyFusion::FrequencyFusionVoice::renderOperator(int opIndex, float modulation,
                                                             float sampleRate)
{
    auto& op = owner.operators[opIndex];
    auto& state = opStates[opIndex];

    // Get operator frequency
    float baseFreq = juce::MidiMessage::getMidiNoteInHertz(currentNote);
    float opFreq = getOperatorFrequency(opIndex, baseFreq);

    // Apply pitch bend
    opFreq *= std::pow(2.0f, pitchBend * owner.pitchBendRange / 12.0f);

    // Apply LFO to pitch
    if (owner.lfo.enabled && owner.lfo.target == LFOTarget::Pitch)
    {
        opFreq *= std::pow(2.0f, lfoValue * owner.lfo.depth * 0.1f);  // ±10% max
    }

    // Phase modulation (FM synthesis)
    float modulatedPhase = state.phase + modulation;

    // Generate waveform
    float output = generateWaveform(op.waveform, modulatedPhase);

    // Apply envelope
    output *= state.envelopeValue;

    // Apply output level
    output *= op.outputLevel;

    // Apply velocity sensitivity
    output *= (1.0f - op.velocity + op.velocity * velocity);

    // Apply key scaling
    if (std::abs(op.keyScale) > 0.01f)
    {
        float keyScaleFactor = 1.0f + op.keyScale * (currentNote - 60) / 60.0f;
        output *= keyScaleFactor;
    }

    // Apply LFO to amplitude
    if (owner.lfo.enabled && owner.lfo.target == LFOTarget::Amplitude)
    {
        output *= (1.0f + lfoValue * owner.lfo.depth);
    }

    // Advance phase
    float phaseInc = opFreq / sampleRate;
    state.phase += phaseInc;
    while (state.phase >= 1.0f)
        state.phase -= 1.0f;

    state.output = output;
    return output;
}

float FrequencyFusion::FrequencyFusionVoice::getOperatorFrequency(int opIndex, float baseFreq)
{
    const auto& op = owner.operators[opIndex];

    if (op.fixed)
    {
        // Fixed frequency mode
        return op.fixedFreq;
    }
    else
    {
        // Ratio mode
        float ratio = static_cast<float>(op.coarse) + op.fine / 100.0f;
        if (ratio < 0.5f) ratio = 0.5f;

        float freq = baseFreq * ratio;

        // Apply detune
        freq *= std::pow(2.0f, op.detune / 1200.0f);

        // Apply master tune
        freq *= std::pow(2.0f, owner.masterTune / 1200.0f);

        return freq;
    }
}

float FrequencyFusion::FrequencyFusionVoice::generateWaveform(Waveform waveform, float phase)
{
    // Normalize phase
    while (phase >= 1.0f) phase -= 1.0f;
    while (phase < 0.0f) phase += 1.0f;

    const float twoPi = juce::MathConstants<float>::twoPi;
    float angle = phase * twoPi;

    switch (waveform)
    {
        case Waveform::Sine:
            return std::sin(angle);

        case Waveform::HalfSine:
            return (phase < 0.5f) ? std::sin(angle) : 0.0f;

        case Waveform::AbsSine:
            return std::abs(std::sin(angle));

        case Waveform::PulseSine:
            return (phase < 0.5f) ? std::sin(angle * 2.0f) : 0.0f;

        case Waveform::EvenSine:
            return std::sin(angle) + std::sin(angle * 2.0f) * 0.5f;

        case Waveform::OddSine:
            return std::sin(angle) + std::sin(angle * 3.0f) * 0.333f;

        case Waveform::SquareSine:
            return (std::sin(angle) > 0.0f) ? 1.0f : -1.0f;

        default:
            return std::sin(angle);
    }
}

void FrequencyFusion::FrequencyFusionVoice::updateEnvelope(int opIndex, float sampleRate)
{
    auto& state = opStates[opIndex];
    const auto& op = owner.operators[opIndex];

    // Update envelope value
    state.envelopeValue += state.envelopeIncrement;

    // Check if reached target
    bool reachedTarget = false;
    if (state.envelopeIncrement > 0.0f && state.envelopeValue >= state.envelopeTarget)
    {
        state.envelopeValue = state.envelopeTarget;
        reachedTarget = true;
    }
    else if (state.envelopeIncrement < 0.0f && state.envelopeValue <= state.envelopeTarget)
    {
        state.envelopeValue = state.envelopeTarget;
        reachedTarget = true;
    }

    // Move to next stage
    if (reachedTarget)
    {
        if (state.noteOn && state.envelopeStage < 5)
        {
            // Attack/Decay/Sustain stages
            state.envelopeStage++;

            if (state.envelopeStage < 8)
            {
                state.envelopeTarget = op.envelopeLevels[state.envelopeStage];
                float time = op.envelopeTimes[state.envelopeStage];

                if (time > 0.001f)
                {
                    state.envelopeIncrement = (state.envelopeTarget - state.envelopeValue) /
                                             (time * sampleRate);
                }
                else
                {
                    state.envelopeValue = state.envelopeTarget;
                    state.envelopeIncrement = 0.0f;
                }
            }
        }
        else if (!state.noteOn && state.envelopeStage >= 6)
        {
            // Release stage
            state.envelopeTarget = 0.0f;
            float time = op.envelopeTimes[7];  // Release time

            if (time > 0.001f)
            {
                state.envelopeIncrement = (state.envelopeTarget - state.envelopeValue) /
                                         (time * sampleRate);
            }
            else
            {
                state.envelopeValue = 0.0f;
                state.envelopeIncrement = 0.0f;
            }
        }
    }

    // Clamp
    state.envelopeValue = juce::jlimit(0.0f, 1.0f, state.envelopeValue);
}

void FrequencyFusion::FrequencyFusionVoice::updateLFO(float sampleRate)
{
    if (!owner.lfo.enabled)
        return;

    // Update LFO fade-in
    if (owner.lfo.delay > 0.0f)
    {
        lfoFade += 1.0f / (owner.lfo.delay * sampleRate);
        lfoFade = juce::jmin(lfoFade, 1.0f);
    }
    else
    {
        lfoFade = 1.0f;
    }

    // Calculate LFO value
    const float twoPi = juce::MathConstants<float>::twoPi;

    switch (owner.lfo.shape)
    {
        case LFOShape::Sine:
            lfoValue = std::sin(lfoPhase * twoPi);
            break;

        case LFOShape::Triangle:
            lfoValue = (lfoPhase < 0.5f) ? (4.0f * lfoPhase - 1.0f) : (3.0f - 4.0f * lfoPhase);
            break;

        case LFOShape::Saw:
            lfoValue = 2.0f * lfoPhase - 1.0f;
            break;

        case LFOShape::Square:
            lfoValue = (lfoPhase < 0.5f) ? 1.0f : -1.0f;
            break;

        case LFOShape::SampleAndHold:
            if (lfoPhase < 0.01f)
                lfoValue = (std::rand() / static_cast<float>(RAND_MAX)) * 2.0f - 1.0f;
            break;
    }

    // Apply fade-in
    lfoValue *= lfoFade;

    // Advance phase
    float phaseInc = owner.lfo.rate / sampleRate;
    lfoPhase += phaseInc;
    while (lfoPhase >= 1.0f)
        lfoPhase -= 1.0f;
}

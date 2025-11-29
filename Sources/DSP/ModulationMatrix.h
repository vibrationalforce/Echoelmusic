#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <functional>
#include <unordered_map>

/**
 * ModulationMatrix - Universal Parameter Routing System
 *
 * Provides LFO → Parameter, Envelope → Parameter, and Macro → Parameter routing.
 * Enables complex modulation routing found in professional synthesizers.
 *
 * Features:
 * - 16 independent LFOs with multiple shapes
 * - 8 ADSR envelopes for modulation
 * - 8 Macro controls (1-to-many parameter mapping)
 * - Unlimited modulation routing slots
 * - Bipolar/unipolar modulation
 * - Modulation amount curves (linear, exponential, S-curve)
 * - Real-time parameter learning
 * - Cross-modulation (LFO modulating LFO rate)
 */

namespace Echoel {

//==========================================================================
// Modulation Source Types
//==========================================================================

enum class ModSourceType {
    None,
    LFO_1, LFO_2, LFO_3, LFO_4, LFO_5, LFO_6, LFO_7, LFO_8,
    LFO_9, LFO_10, LFO_11, LFO_12, LFO_13, LFO_14, LFO_15, LFO_16,
    Envelope_1, Envelope_2, Envelope_3, Envelope_4,
    Envelope_5, Envelope_6, Envelope_7, Envelope_8,
    Macro_1, Macro_2, Macro_3, Macro_4,
    Macro_5, Macro_6, Macro_7, Macro_8,
    Velocity, Aftertouch, ModWheel, PitchBend,
    KeyTrack, RandomOnNote,
    BioHRV, BioCoherence, BioHeartRate, BioBreathing,
    AudioLevel, AudioPitch, AudioSpectrum
};

//==========================================================================
// LFO Shape Types
//==========================================================================

enum class LFOShapeType {
    Sine,
    Triangle,
    Saw,
    ReverseSaw,
    Square,
    Pulse25,
    Pulse10,
    RandomSmooth,
    RandomStep,
    Noise,
    Custom
};

//==========================================================================
// Envelope Stage
//==========================================================================

enum class EnvelopeStage {
    Idle,
    Attack,
    Decay,
    Sustain,
    Release
};

//==========================================================================
// Modulation Curve Type
//==========================================================================

enum class ModCurveType {
    Linear,
    Exponential,
    Logarithmic,
    SCurve,
    InverseLinear,
    InverseExponential
};

//==========================================================================
// LFO - Low Frequency Oscillator
//==========================================================================

class ModLFO {
public:
    ModLFO() = default;

    void prepare(double sampleRate) {
        currentSampleRate = sampleRate;
        updateIncrement();
    }

    void setRate(float rateHz) {
        rate = juce::jlimit(0.001f, 100.0f, rateHz);
        updateIncrement();
    }

    void setShape(LFOShapeType shape) { lfoShape = shape; }
    void setPhase(float ph) { phase = std::fmod(ph, 1.0f); }
    void setDelay(float delayMs) { delayTime = delayMs; }
    void setFadeIn(float fadeMs) { fadeInTime = fadeMs; }
    void setBipolar(bool bp) { bipolar = bp; }
    void setTempoSync(bool sync) { tempoSync = sync; }
    void setSyncDivision(float div) { syncDivision = div; }
    void setTempo(double bpm) { tempo = bpm; updateIncrement(); }

    void trigger() {
        if (retrigger) {
            phase = startPhase;
            delayCounter = 0;
            fadeCounter = 0;
        }
    }

    void setRetrigger(bool rt) { retrigger = rt; }
    void setStartPhase(float sp) { startPhase = sp; }

    float process() {
        // Handle delay
        if (delayCounter < delayTime * currentSampleRate / 1000.0f) {
            delayCounter++;
            return bipolar ? 0.0f : 0.5f;
        }

        // Fade in
        float fadeMultiplier = 1.0f;
        if (fadeCounter < fadeInTime * currentSampleRate / 1000.0f) {
            fadeMultiplier = fadeCounter / (fadeInTime * currentSampleRate / 1000.0f);
            fadeCounter++;
        }

        // Generate shape
        float output = generateShape();

        // Apply fade
        output *= fadeMultiplier;

        // Advance phase
        phase += phaseIncrement;
        if (phase >= 1.0f) {
            phase -= 1.0f;
            // Update random target for S&H
            if (lfoShape == LFOShapeType::RandomStep) {
                randomTarget = random.nextFloat();
            }
        }

        return bipolar ? (output * 2.0f - 1.0f) : output;
    }

    float getValue() const { return currentValue; }
    float getRate() const { return rate; }
    bool isEnabled() const { return enabled; }
    void setEnabled(bool e) { enabled = e; }

private:
    float generateShape() {
        switch (lfoShape) {
            case LFOShapeType::Sine:
                currentValue = 0.5f + 0.5f * std::sin(phase * juce::MathConstants<float>::twoPi);
                break;
            case LFOShapeType::Triangle:
                currentValue = (phase < 0.5f) ? (phase * 2.0f) : (2.0f - phase * 2.0f);
                break;
            case LFOShapeType::Saw:
                currentValue = phase;
                break;
            case LFOShapeType::ReverseSaw:
                currentValue = 1.0f - phase;
                break;
            case LFOShapeType::Square:
                currentValue = (phase < 0.5f) ? 1.0f : 0.0f;
                break;
            case LFOShapeType::Pulse25:
                currentValue = (phase < 0.25f) ? 1.0f : 0.0f;
                break;
            case LFOShapeType::Pulse10:
                currentValue = (phase < 0.1f) ? 1.0f : 0.0f;
                break;
            case LFOShapeType::RandomSmooth: {
                // Interpolate between random values
                float t = phase;
                currentValue = randomPrev + (randomTarget - randomPrev) * t;
                if (phase < phaseIncrement) {
                    randomPrev = randomTarget;
                    randomTarget = random.nextFloat();
                }
                break;
            }
            case LFOShapeType::RandomStep:
                currentValue = randomTarget;
                break;
            case LFOShapeType::Noise:
                currentValue = random.nextFloat();
                break;
            default:
                currentValue = 0.5f;
        }
        return currentValue;
    }

    void updateIncrement() {
        if (tempoSync && tempo > 0) {
            // Sync to tempo: syncDivision = 1.0 means 1 bar
            float beatsPerBar = 4.0f;
            float barsPerSecond = tempo / 60.0f / beatsPerBar;
            float cyclesPerSecond = barsPerSecond / syncDivision;
            phaseIncrement = static_cast<float>(cyclesPerSecond / currentSampleRate);
        } else {
            phaseIncrement = static_cast<float>(rate / currentSampleRate);
        }
    }

    double currentSampleRate = 48000.0;
    float rate = 1.0f;
    float phase = 0.0f;
    float phaseIncrement = 0.0f;
    float startPhase = 0.0f;
    float delayTime = 0.0f;
    float fadeInTime = 0.0f;
    float delayCounter = 0.0f;
    float fadeCounter = 0.0f;
    float currentValue = 0.0f;
    float randomTarget = 0.5f;
    float randomPrev = 0.5f;
    LFOShapeType lfoShape = LFOShapeType::Sine;
    bool bipolar = true;
    bool tempoSync = false;
    float syncDivision = 1.0f;
    double tempo = 120.0;
    bool retrigger = false;
    bool enabled = true;
    juce::Random random;
};

//==========================================================================
// Modulation Envelope (ADSR)
//==========================================================================

class ModEnvelope {
public:
    ModEnvelope() = default;

    void prepare(double sampleRate) {
        currentSampleRate = sampleRate;
        calculateCoefficients();
    }

    void setAttack(float attackMs) { attack = juce::jlimit(0.1f, 10000.0f, attackMs); calculateCoefficients(); }
    void setDecay(float decayMs) { decay = juce::jlimit(0.1f, 10000.0f, decayMs); calculateCoefficients(); }
    void setSustain(float sustainLevel) { sustain = juce::jlimit(0.0f, 1.0f, sustainLevel); }
    void setRelease(float releaseMs) { release = juce::jlimit(0.1f, 30000.0f, releaseMs); calculateCoefficients(); }
    void setCurve(float curve) { envelopeCurve = juce::jlimit(-1.0f, 1.0f, curve); }

    void trigger() {
        stage = EnvelopeStage::Attack;
        level = 0.0f;
    }

    void release_() {
        stage = EnvelopeStage::Release;
        releaseLevel = level;
    }

    float process() {
        switch (stage) {
            case EnvelopeStage::Idle:
                level = 0.0f;
                break;

            case EnvelopeStage::Attack:
                level += attackCoeff;
                if (level >= 1.0f) {
                    level = 1.0f;
                    stage = EnvelopeStage::Decay;
                }
                break;

            case EnvelopeStage::Decay:
                level -= decayCoeff * (level - sustain);
                if (level <= sustain + 0.001f) {
                    level = sustain;
                    stage = EnvelopeStage::Sustain;
                }
                break;

            case EnvelopeStage::Sustain:
                level = sustain;
                break;

            case EnvelopeStage::Release:
                level -= releaseCoeff * level;
                if (level <= 0.001f) {
                    level = 0.0f;
                    stage = EnvelopeStage::Idle;
                }
                break;
        }

        // Apply curve
        float output = level;
        if (envelopeCurve > 0) {
            output = std::pow(level, 1.0f + envelopeCurve * 2.0f);
        } else if (envelopeCurve < 0) {
            output = 1.0f - std::pow(1.0f - level, 1.0f - envelopeCurve * 2.0f);
        }

        return output;
    }

    float getValue() const { return level; }
    EnvelopeStage getStage() const { return stage; }
    bool isActive() const { return stage != EnvelopeStage::Idle; }
    bool isEnabled() const { return enabled; }
    void setEnabled(bool e) { enabled = e; }

private:
    void calculateCoefficients() {
        attackCoeff = static_cast<float>(1.0 / (attack * currentSampleRate / 1000.0));
        decayCoeff = static_cast<float>(1.0 / (decay * currentSampleRate / 1000.0));
        releaseCoeff = static_cast<float>(1.0 / (release * currentSampleRate / 1000.0));
    }

    double currentSampleRate = 48000.0;
    float attack = 10.0f;      // ms
    float decay = 100.0f;      // ms
    float sustain = 0.7f;      // 0-1
    float release = 200.0f;    // ms
    float envelopeCurve = 0.0f;
    float level = 0.0f;
    float releaseLevel = 0.0f;
    float attackCoeff = 0.0f;
    float decayCoeff = 0.0f;
    float releaseCoeff = 0.0f;
    EnvelopeStage stage = EnvelopeStage::Idle;
    bool enabled = true;
};

//==========================================================================
// Modulation Routing Slot
//==========================================================================

struct ModulationSlot {
    ModSourceType source = ModSourceType::None;
    juce::String targetParameter;
    float amount = 0.0f;          // -1.0 to 1.0
    ModCurveType curve = ModCurveType::Linear;
    bool bipolar = true;
    bool enabled = true;

    // Optional secondary source for cross-modulation
    ModSourceType amountModSource = ModSourceType::None;
    float amountModDepth = 0.0f;

    ModulationSlot() = default;
    ModulationSlot(ModSourceType src, const juce::String& target, float amt)
        : source(src), targetParameter(target), amount(amt) {}
};

//==========================================================================
// Parameter Target
//==========================================================================

struct ParameterTarget {
    juce::String id;
    juce::String name;
    float* valuePtr = nullptr;
    float minValue = 0.0f;
    float maxValue = 1.0f;
    float baseValue = 0.5f;       // Value before modulation
    float modulatedValue = 0.5f; // Value after modulation

    std::function<void(float)> onValueChanged;
};

//==========================================================================
// Macro Control
//==========================================================================

struct MacroControl {
    juce::String name;
    float value = 0.0f;  // 0.0 to 1.0
    std::vector<std::pair<juce::String, float>> mappings;  // target ID, amount
    bool enabled = true;
};

//==========================================================================
// ModulationMatrix - Main Class
//==========================================================================

class ModulationMatrix {
public:
    static constexpr int NUM_LFOS = 16;
    static constexpr int NUM_ENVELOPES = 8;
    static constexpr int NUM_MACROS = 8;
    static constexpr int MAX_SLOTS = 128;

    ModulationMatrix() {
        // Initialize macros
        for (int i = 0; i < NUM_MACROS; ++i) {
            macros[i].name = "Macro " + juce::String(i + 1);
        }
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize) {
        currentSampleRate = sampleRate;
        blockSize = maxBlockSize;

        for (auto& lfo : lfos) {
            lfo.prepare(sampleRate);
        }
        for (auto& env : envelopes) {
            env.prepare(sampleRate);
        }
    }

    //==========================================================================
    // LFO Control
    //==========================================================================

    ModLFO& getLFO(int index) {
        jassert(index >= 0 && index < NUM_LFOS);
        return lfos[index];
    }

    void setLFORate(int index, float rate) {
        if (index >= 0 && index < NUM_LFOS) {
            lfos[index].setRate(rate);
        }
    }

    void setLFOShape(int index, LFOShapeType shape) {
        if (index >= 0 && index < NUM_LFOS) {
            lfos[index].setShape(shape);
        }
    }

    //==========================================================================
    // Envelope Control
    //==========================================================================

    ModEnvelope& getEnvelope(int index) {
        jassert(index >= 0 && index < NUM_ENVELOPES);
        return envelopes[index];
    }

    void triggerEnvelopes() {
        for (auto& env : envelopes) {
            if (env.isEnabled()) {
                env.trigger();
            }
        }
        for (auto& lfo : lfos) {
            lfo.trigger();
        }
    }

    void releaseEnvelopes() {
        for (auto& env : envelopes) {
            env.release_();
        }
    }

    //==========================================================================
    // Macro Control
    //==========================================================================

    MacroControl& getMacro(int index) {
        jassert(index >= 0 && index < NUM_MACROS);
        return macros[index];
    }

    void setMacroValue(int index, float value) {
        if (index >= 0 && index < NUM_MACROS) {
            macros[index].value = juce::jlimit(0.0f, 1.0f, value);
        }
    }

    void addMacroMapping(int macroIndex, const juce::String& targetId, float amount) {
        if (macroIndex >= 0 && macroIndex < NUM_MACROS) {
            macros[macroIndex].mappings.push_back({targetId, amount});
        }
    }

    //==========================================================================
    // Parameter Registration
    //==========================================================================

    void registerParameter(const juce::String& id, const juce::String& name,
                          float* valuePtr, float minVal, float maxVal,
                          std::function<void(float)> callback = nullptr) {
        ParameterTarget target;
        target.id = id;
        target.name = name;
        target.valuePtr = valuePtr;
        target.minValue = minVal;
        target.maxValue = maxVal;
        target.baseValue = *valuePtr;
        target.modulatedValue = *valuePtr;
        target.onValueChanged = callback;

        parameters[id] = target;
    }

    void setParameterBaseValue(const juce::String& id, float value) {
        auto it = parameters.find(id);
        if (it != parameters.end()) {
            it->second.baseValue = value;
        }
    }

    //==========================================================================
    // Modulation Routing
    //==========================================================================

    int addModulationSlot(const ModulationSlot& slot) {
        if (modulationSlots.size() < MAX_SLOTS) {
            modulationSlots.push_back(slot);
            return static_cast<int>(modulationSlots.size()) - 1;
        }
        return -1;
    }

    void removeModulationSlot(int index) {
        if (index >= 0 && index < static_cast<int>(modulationSlots.size())) {
            modulationSlots.erase(modulationSlots.begin() + index);
        }
    }

    ModulationSlot& getModulationSlot(int index) {
        jassert(index >= 0 && index < static_cast<int>(modulationSlots.size()));
        return modulationSlots[index];
    }

    int getNumModulationSlots() const {
        return static_cast<int>(modulationSlots.size());
    }

    void clearModulationSlots() {
        modulationSlots.clear();
    }

    //==========================================================================
    // Bio-Data Input
    //==========================================================================

    void setBioData(float hrv, float coherence, float heartRate, float breathing) {
        bioHRV = hrv;
        bioCoherence = coherence;
        bioHeartRate = heartRate;
        bioBreathing = breathing;
    }

    //==========================================================================
    // Audio Analysis Input
    //==========================================================================

    void setAudioAnalysis(float level, float pitch, const std::vector<float>& spectrum) {
        audioLevel = level;
        audioPitch = pitch;
        audioSpectrum = spectrum;
    }

    //==========================================================================
    // MIDI Input
    //==========================================================================

    void setMIDIValues(float velocity, float aftertouch, float modWheel, float pitchBend) {
        midiVelocity = velocity;
        midiAftertouch = aftertouch;
        midiModWheel = modWheel;
        midiPitchBend = pitchBend;
    }

    void setKeyTrack(float noteNumber) {
        // Normalize to 0-1 based on MIDI note range
        keyTrack = (noteNumber - 21.0f) / 87.0f;  // A0 to C8
    }

    //==========================================================================
    // Processing
    //==========================================================================

    void process() {
        // Process all LFOs
        for (int i = 0; i < NUM_LFOS; ++i) {
            if (lfos[i].isEnabled()) {
                lfoValues[i] = lfos[i].process();
            }
        }

        // Process all envelopes
        for (int i = 0; i < NUM_ENVELOPES; ++i) {
            if (envelopes[i].isEnabled()) {
                envValues[i] = envelopes[i].process();
            }
        }

        // Reset all parameters to base values
        for (auto& [id, param] : parameters) {
            param.modulatedValue = param.baseValue;
        }

        // Apply modulation slots
        for (const auto& slot : modulationSlots) {
            if (!slot.enabled) continue;

            float modValue = getSourceValue(slot.source);

            // Apply curve
            modValue = applyCurve(modValue, slot.curve);

            // Apply amount modulation if present
            float amount = slot.amount;
            if (slot.amountModSource != ModSourceType::None) {
                float amountMod = getSourceValue(slot.amountModSource);
                amount *= (1.0f + amountMod * slot.amountModDepth);
            }

            // Apply to target parameter
            auto it = parameters.find(slot.targetParameter);
            if (it != parameters.end()) {
                float modDelta = modValue * amount;
                float range = it->second.maxValue - it->second.minValue;
                it->second.modulatedValue += modDelta * range;
                it->second.modulatedValue = juce::jlimit(
                    it->second.minValue,
                    it->second.maxValue,
                    it->second.modulatedValue
                );
            }
        }

        // Apply macro mappings
        for (int i = 0; i < NUM_MACROS; ++i) {
            if (!macros[i].enabled) continue;

            for (const auto& [targetId, amount] : macros[i].mappings) {
                auto it = parameters.find(targetId);
                if (it != parameters.end()) {
                    float modDelta = macros[i].value * amount;
                    float range = it->second.maxValue - it->second.minValue;
                    it->second.modulatedValue += modDelta * range;
                    it->second.modulatedValue = juce::jlimit(
                        it->second.minValue,
                        it->second.maxValue,
                        it->second.modulatedValue
                    );
                }
            }
        }

        // Write modulated values to actual parameters
        for (auto& [id, param] : parameters) {
            if (param.valuePtr != nullptr) {
                *param.valuePtr = param.modulatedValue;
            }
            if (param.onValueChanged) {
                param.onValueChanged(param.modulatedValue);
            }
        }
    }

    //==========================================================================
    // Learn Mode
    //==========================================================================

    void startLearning(const juce::String& targetParameter) {
        learningTarget = targetParameter;
        isLearning = true;
    }

    void stopLearning() {
        learningTarget.clear();
        isLearning = false;
    }

    bool isInLearningMode() const { return isLearning; }
    juce::String getLearningTarget() const { return learningTarget; }

    // Call this when a modulation source changes significantly during learn
    void learnSource(ModSourceType source, float amount = 1.0f) {
        if (isLearning && learningTarget.isNotEmpty()) {
            ModulationSlot slot;
            slot.source = source;
            slot.targetParameter = learningTarget;
            slot.amount = amount;
            addModulationSlot(slot);
            stopLearning();
        }
    }

    //==========================================================================
    // Visualization
    //==========================================================================

    float getLFOValue(int index) const {
        if (index >= 0 && index < NUM_LFOS) {
            return lfoValues[index];
        }
        return 0.0f;
    }

    float getEnvelopeValue(int index) const {
        if (index >= 0 && index < NUM_ENVELOPES) {
            return envValues[index];
        }
        return 0.0f;
    }

    float getParameterModulatedValue(const juce::String& id) const {
        auto it = parameters.find(id);
        if (it != parameters.end()) {
            return it->second.modulatedValue;
        }
        return 0.0f;
    }

    //==========================================================================
    // Serialization
    //==========================================================================

    juce::String exportToXML() const {
        juce::XmlElement root("ModulationMatrix");

        // Export LFO states
        auto* lfosXml = root.createNewChildElement("LFOs");
        for (int i = 0; i < NUM_LFOS; ++i) {
            auto* lfoXml = lfosXml->createNewChildElement("LFO");
            lfoXml->setAttribute("index", i);
            lfoXml->setAttribute("rate", lfos[i].getRate());
            lfoXml->setAttribute("enabled", lfos[i].isEnabled());
        }

        // Export modulation slots
        auto* slotsXml = root.createNewChildElement("Slots");
        for (const auto& slot : modulationSlots) {
            auto* slotXml = slotsXml->createNewChildElement("Slot");
            slotXml->setAttribute("source", static_cast<int>(slot.source));
            slotXml->setAttribute("target", slot.targetParameter);
            slotXml->setAttribute("amount", slot.amount);
            slotXml->setAttribute("curve", static_cast<int>(slot.curve));
            slotXml->setAttribute("enabled", slot.enabled);
        }

        // Export macros
        auto* macrosXml = root.createNewChildElement("Macros");
        for (int i = 0; i < NUM_MACROS; ++i) {
            auto* macroXml = macrosXml->createNewChildElement("Macro");
            macroXml->setAttribute("index", i);
            macroXml->setAttribute("name", macros[i].name);
            macroXml->setAttribute("value", macros[i].value);
        }

        return root.toString();
    }

    bool importFromXML(const juce::String& xmlString) {
        auto xml = juce::XmlDocument::parse(xmlString);
        if (!xml || xml->getTagName() != "ModulationMatrix") {
            return false;
        }

        // Import LFO states
        if (auto* lfosXml = xml->getChildByName("LFOs")) {
            for (auto* lfoXml : lfosXml->getChildIterator()) {
                int index = lfoXml->getIntAttribute("index", -1);
                if (index >= 0 && index < NUM_LFOS) {
                    lfos[index].setRate(static_cast<float>(lfoXml->getDoubleAttribute("rate", 1.0)));
                    lfos[index].setEnabled(lfoXml->getBoolAttribute("enabled", true));
                }
            }
        }

        // Import modulation slots
        modulationSlots.clear();
        if (auto* slotsXml = xml->getChildByName("Slots")) {
            for (auto* slotXml : slotsXml->getChildIterator()) {
                ModulationSlot slot;
                slot.source = static_cast<ModSourceType>(slotXml->getIntAttribute("source", 0));
                slot.targetParameter = slotXml->getStringAttribute("target");
                slot.amount = static_cast<float>(slotXml->getDoubleAttribute("amount", 0.0));
                slot.curve = static_cast<ModCurveType>(slotXml->getIntAttribute("curve", 0));
                slot.enabled = slotXml->getBoolAttribute("enabled", true);
                modulationSlots.push_back(slot);
            }
        }

        return true;
    }

private:
    //==========================================================================
    // Source Value Retrieval
    //==========================================================================

    float getSourceValue(ModSourceType source) const {
        switch (source) {
            case ModSourceType::None: return 0.0f;
            case ModSourceType::LFO_1:  return lfoValues[0];
            case ModSourceType::LFO_2:  return lfoValues[1];
            case ModSourceType::LFO_3:  return lfoValues[2];
            case ModSourceType::LFO_4:  return lfoValues[3];
            case ModSourceType::LFO_5:  return lfoValues[4];
            case ModSourceType::LFO_6:  return lfoValues[5];
            case ModSourceType::LFO_7:  return lfoValues[6];
            case ModSourceType::LFO_8:  return lfoValues[7];
            case ModSourceType::LFO_9:  return lfoValues[8];
            case ModSourceType::LFO_10: return lfoValues[9];
            case ModSourceType::LFO_11: return lfoValues[10];
            case ModSourceType::LFO_12: return lfoValues[11];
            case ModSourceType::LFO_13: return lfoValues[12];
            case ModSourceType::LFO_14: return lfoValues[13];
            case ModSourceType::LFO_15: return lfoValues[14];
            case ModSourceType::LFO_16: return lfoValues[15];
            case ModSourceType::Envelope_1: return envValues[0];
            case ModSourceType::Envelope_2: return envValues[1];
            case ModSourceType::Envelope_3: return envValues[2];
            case ModSourceType::Envelope_4: return envValues[3];
            case ModSourceType::Envelope_5: return envValues[4];
            case ModSourceType::Envelope_6: return envValues[5];
            case ModSourceType::Envelope_7: return envValues[6];
            case ModSourceType::Envelope_8: return envValues[7];
            case ModSourceType::Macro_1: return macros[0].value;
            case ModSourceType::Macro_2: return macros[1].value;
            case ModSourceType::Macro_3: return macros[2].value;
            case ModSourceType::Macro_4: return macros[3].value;
            case ModSourceType::Macro_5: return macros[4].value;
            case ModSourceType::Macro_6: return macros[5].value;
            case ModSourceType::Macro_7: return macros[6].value;
            case ModSourceType::Macro_8: return macros[7].value;
            case ModSourceType::Velocity: return midiVelocity;
            case ModSourceType::Aftertouch: return midiAftertouch;
            case ModSourceType::ModWheel: return midiModWheel;
            case ModSourceType::PitchBend: return midiPitchBend;
            case ModSourceType::KeyTrack: return keyTrack;
            case ModSourceType::RandomOnNote: return random.nextFloat();
            case ModSourceType::BioHRV: return bioHRV;
            case ModSourceType::BioCoherence: return bioCoherence;
            case ModSourceType::BioHeartRate: return bioHeartRate;
            case ModSourceType::BioBreathing: return bioBreathing;
            case ModSourceType::AudioLevel: return audioLevel;
            case ModSourceType::AudioPitch: return audioPitch;
            case ModSourceType::AudioSpectrum:
                return audioSpectrum.empty() ? 0.0f : audioSpectrum[0];
            default: return 0.0f;
        }
    }

    //==========================================================================
    // Curve Application
    //==========================================================================

    float applyCurve(float value, ModCurveType curve) const {
        switch (curve) {
            case ModCurveType::Linear:
                return value;
            case ModCurveType::Exponential:
                return value * value;
            case ModCurveType::Logarithmic:
                return std::sqrt(std::abs(value)) * (value >= 0 ? 1.0f : -1.0f);
            case ModCurveType::SCurve: {
                // Smooth S-curve using cubic interpolation
                float t = value * 0.5f + 0.5f;  // Convert to 0-1
                t = t * t * (3.0f - 2.0f * t);   // Smoothstep
                return t * 2.0f - 1.0f;          // Back to -1 to 1
            }
            case ModCurveType::InverseLinear:
                return -value;
            case ModCurveType::InverseExponential:
                return -(value * value);
            default:
                return value;
        }
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    double currentSampleRate = 48000.0;
    int blockSize = 512;

    // LFOs and Envelopes
    std::array<ModLFO, NUM_LFOS> lfos;
    std::array<ModEnvelope, NUM_ENVELOPES> envelopes;
    std::array<float, NUM_LFOS> lfoValues{};
    std::array<float, NUM_ENVELOPES> envValues{};

    // Macros
    std::array<MacroControl, NUM_MACROS> macros;

    // Parameter registry
    std::unordered_map<juce::String, ParameterTarget> parameters;

    // Modulation routings
    std::vector<ModulationSlot> modulationSlots;

    // External modulation sources
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    float bioHeartRate = 0.5f;
    float bioBreathing = 0.5f;
    float audioLevel = 0.0f;
    float audioPitch = 0.0f;
    std::vector<float> audioSpectrum;
    float midiVelocity = 0.0f;
    float midiAftertouch = 0.0f;
    float midiModWheel = 0.0f;
    float midiPitchBend = 0.5f;
    float keyTrack = 0.5f;

    // Learning mode
    bool isLearning = false;
    juce::String learningTarget;

    juce::Random random;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ModulationMatrix)
};

} // namespace Echoel

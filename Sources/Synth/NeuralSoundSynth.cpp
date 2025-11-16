/*
  ==============================================================================

    NeuralSoundSynth.cpp

    World's First Bio-Reactive Neural Synthesizer

    Revolutionary AI-powered synthesis using RAVE (Realtime Audio Variational
    autoEncoder) for real-time neural audio generation with bio-reactive control.

  ==============================================================================
*/

#include "NeuralSoundSynth.h"
#include "Sources/ML/MLEngine.h"
#include <cmath>
#include <random>

//==============================================================================
// Neural Engine (Private Implementation)
//==============================================================================

class NeuralSoundSynth::NeuralEngine
{
public:
    NeuralEngine()
    {
        // Initialize ML engine
        if (!mlEngine.initialize(MLEngine::AccelerationType::Auto))
        {
            DBG("NeuralEngine: Failed to initialize ML engine");
        }
    }

    bool loadModel(const juce::File& modelFile, const std::string& modelName)
    {
        if (!modelFile.existsAsFile())
        {
            DBG("NeuralEngine: Model file not found: " + modelFile.getFullPathName());
            return false;
        }

        // Load ONNX model
        if (!mlEngine.loadModel(modelFile, modelName))
        {
            DBG("NeuralEngine: Failed to load model: " + modelFile.getFullPathName());
            return false;
        }

        currentModelName = modelName;
        isModelLoaded = true;

        // Measure latency
        auto latency = mlEngine.measureLatency(modelName);
        DBG("NeuralEngine: Model latency = " + juce::String(latency, 2) + " ms");

        return true;
    }

    std::vector<float> synthesize(const NeuralSoundSynth::LatentVector& latent,
                                   int numSamples = 2048)
    {
        if (!isModelLoaded)
        {
            DBG("NeuralEngine: No model loaded");
            return std::vector<float>(numSamples, 0.0f);
        }

        // Convert latent vector to input format
        std::vector<float> input(latent.values.begin(), latent.values.end());

        // Run inference
        auto output = mlEngine.runInference(currentModelName, input);

        // Ensure output size matches requested samples
        if (output.size() < static_cast<size_t>(numSamples))
        {
            output.resize(numSamples, 0.0f);
        }
        else if (output.size() > static_cast<size_t>(numSamples))
        {
            output.resize(numSamples);
        }

        return output;
    }

    void synthesizeAsync(const NeuralSoundSynth::LatentVector& latent,
                        std::function<void(const std::vector<float>&)> callback)
    {
        if (!isModelLoaded)
        {
            callback(std::vector<float>(2048, 0.0f));
            return;
        }

        std::vector<float> input(latent.values.begin(), latent.values.end());
        mlEngine.runInferenceAsync(currentModelName, input, callback);
    }

    float getLatency() const
    {
        if (!isModelLoaded)
            return 0.0f;

        auto metrics = mlEngine.getPerformanceMetrics(currentModelName);
        return metrics.averageLatency;
    }

    bool isRealtime() const
    {
        if (!isModelLoaded)
            return false;

        auto metrics = mlEngine.getPerformanceMetrics(currentModelName);
        return metrics.isRealtime;
    }

private:
    MLEngine mlEngine;
    std::string currentModelName;
    bool isModelLoaded = false;
};

//==============================================================================
// LatentVector Methods
//==============================================================================

void NeuralSoundSynth::LatentVector::updateFromSemanticControls()
{
    // Map semantic controls to latent dimensions
    // This mapping would ideally come from model training, but we use heuristic mapping here

    // Brightness → high-frequency dimensions (64-95)
    for (int i = 64; i < 96; ++i)
        values[i] = brightness * 2.0f - 1.0f;

    // Warmth → mid-frequency dimensions (32-63)
    for (int i = 32; i < 64; ++i)
        values[i] = warmth * 2.0f - 1.0f;

    // Richness → harmonic content (96-111)
    for (int i = 96; i < 112; ++i)
        values[i] = richness * 2.0f - 1.0f;

    // Attack → temporal envelope (0-15)
    for (int i = 0; i < 16; ++i)
        values[i] = attack * 2.0f - 1.0f;

    // Texture → spectral complexity (16-31)
    for (int i = 16; i < 32; ++i)
        values[i] = texture * 2.0f - 1.0f;

    // Movement → modulation depth (112-119)
    for (int i = 112; i < 120; ++i)
        values[i] = movement * 2.0f - 1.0f;

    // Space → reverberation (120-123)
    for (int i = 120; i < 124; ++i)
        values[i] = space * 2.0f - 1.0f;

    // Character → nonlinearity (124-127)
    for (int i = 124; i < 128; ++i)
        values[i] = character * 2.0f - 1.0f;
}

void NeuralSoundSynth::LatentVector::randomize(float amount)
{
    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::normal_distribution<float> dist(0.0f, 1.0f);

    for (auto& value : values)
    {
        value = value * (1.0f - amount) + dist(gen) * amount;
        value = juce::jlimit(-2.0f, 2.0f, value);  // Clamp to reasonable range
    }
}

//==============================================================================
// Constructor / Destructor
//==============================================================================

NeuralSoundSynth::NeuralSoundSynth()
{
    // Create neural engine
    neuralEngine = std::make_unique<NeuralEngine>();

    // Add 16 voices for polyphony
    for (int i = 0; i < 16; ++i)
    {
        addVoice(new NeuralVoice(*this));
    }

    // Add dummy sound (required by JUCE Synthesiser)
    addSound(new juce::SynthesiserSound());

    // Initialize default latent vector
    latentVector.brightness = 0.5f;
    latentVector.warmth = 0.5f;
    latentVector.richness = 0.5f;
    latentVector.attack = 0.5f;
    latentVector.texture = 0.5f;
    latentVector.updateFromSemanticControls();
}

NeuralSoundSynth::~NeuralSoundSynth()
{
    neuralEngine.reset();
}

//==============================================================================
// Model Loading
//==============================================================================

bool NeuralSoundSynth::loadModel(const juce::File& modelFile)
{
    if (!neuralEngine)
        return false;

    // Load model
    auto modelName = modelFile.getFileNameWithoutExtension().toStdString();

    if (!neuralEngine->loadModel(modelFile, modelName))
        return false;

    // Update current model info
    currentModel.name = modelName;
    currentModel.description = "Neural model from " + modelFile.getFileName().toStdString();
    currentModel.modelPath = modelFile.getFullPathName().toStdString();
    currentModel.isLoaded = true;
    currentModel.latency = neuralEngine->getLatency();

    DBG("NeuralSoundSynth: Loaded model '" + juce::String(modelName) + "' (" +
        juce::String(currentModel.latency, 2) + " ms latency)");

    return true;
}

bool NeuralSoundSynth::loadPresetModel(InstrumentCategory category, const std::string& name)
{
    // Construct path to preset models
    // Models should be in: {AppData}/Echoelmusic/Models/{category}/{name}.onnx

    auto appData = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);
    auto modelsDir = appData.getChildFile("Echoelmusic").getChildFile("Models");

    std::string categoryName;
    switch (category)
    {
        case InstrumentCategory::Brass:      categoryName = "Brass"; break;
        case InstrumentCategory::Strings:    categoryName = "Strings"; break;
        case InstrumentCategory::Woodwinds:  categoryName = "Woodwinds"; break;
        case InstrumentCategory::Keyboards:  categoryName = "Keyboards"; break;
        case InstrumentCategory::Percussion: categoryName = "Percussion"; break;
        case InstrumentCategory::Synth:      categoryName = "Synth"; break;
        case InstrumentCategory::Vocal:      categoryName = "Vocal"; break;
        case InstrumentCategory::Guitar:     categoryName = "Guitar"; break;
        case InstrumentCategory::Bass:       categoryName = "Bass"; break;
        case InstrumentCategory::Ethnic:     categoryName = "Ethnic"; break;
        case InstrumentCategory::FX:         categoryName = "FX"; break;
        case InstrumentCategory::Custom:     categoryName = "Custom"; break;
        default:                            categoryName = "Synth"; break;
    }

    auto modelFile = modelsDir.getChildFile(categoryName).getChildFile(name + ".onnx");

    return loadModel(modelFile);
}

std::vector<NeuralSoundSynth::NeuralModel> NeuralSoundSynth::getAvailableModels() const
{
    std::vector<NeuralModel> models;

    // Scan models directory
    auto appData = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);
    auto modelsDir = appData.getChildFile("Echoelmusic").getChildFile("Models");

    if (!modelsDir.exists())
        return models;

    // Scan each category
    for (auto categoryDir : modelsDir.findChildFiles(juce::File::findDirectories, false))
    {
        // Find all .onnx files
        for (auto modelFile : categoryDir.findChildFiles(juce::File::findFiles, false, "*.onnx"))
        {
            NeuralModel model;
            model.name = modelFile.getFileNameWithoutExtension().toStdString();
            model.description = "Neural model";
            model.modelPath = modelFile.getFullPathName().toStdString();
            model.isLoaded = false;

            models.push_back(model);
        }
    }

    return models;
}

void NeuralSoundSynth::setGPUAcceleration(bool enabled)
{
    useGPU = enabled;
    // Re-initialize ML engine with GPU settings
    // (In production, you'd reload the model with new acceleration settings)
}

//==============================================================================
// Synthesis Mode
//==============================================================================

void NeuralSoundSynth::setSynthesisMode(SynthesisMode mode)
{
    currentMode = mode;
}

//==============================================================================
// Latent Space Control
//==============================================================================

void NeuralSoundSynth::setLatentVector(const LatentVector& latent)
{
    latentVector = latent;
}

void NeuralSoundSynth::setBrightness(float value)
{
    latentVector.brightness = juce::jlimit(0.0f, 1.0f, value);
    latentVector.updateFromSemanticControls();
}

void NeuralSoundSynth::setWarmth(float value)
{
    latentVector.warmth = juce::jlimit(0.0f, 1.0f, value);
    latentVector.updateFromSemanticControls();
}

void NeuralSoundSynth::setRichness(float value)
{
    latentVector.richness = juce::jlimit(0.0f, 1.0f, value);
    latentVector.updateFromSemanticControls();
}

void NeuralSoundSynth::setAttack(float value)
{
    latentVector.attack = juce::jlimit(0.0f, 1.0f, value);
    latentVector.updateFromSemanticControls();
}

void NeuralSoundSynth::setTexture(float value)
{
    latentVector.texture = juce::jlimit(0.0f, 1.0f, value);
    latentVector.updateFromSemanticControls();
}

void NeuralSoundSynth::setMovement(float value)
{
    latentVector.movement = juce::jlimit(0.0f, 1.0f, value);
    latentVector.updateFromSemanticControls();
}

void NeuralSoundSynth::setSpace(float value)
{
    latentVector.space = juce::jlimit(0.0f, 1.0f, value);
    latentVector.updateFromSemanticControls();
}

void NeuralSoundSynth::setCharacter(float value)
{
    latentVector.character = juce::jlimit(0.0f, 1.0f, value);
    latentVector.updateFromSemanticControls();
}

void NeuralSoundSynth::randomizeLatent(float amount)
{
    latentVector.randomize(amount);
}

void NeuralSoundSynth::interpolateLatent(const LatentVector& a, const LatentVector& b, float position)
{
    position = juce::jlimit(0.0f, 1.0f, position);

    for (int i = 0; i < LatentVector::dimensions; ++i)
    {
        latentVector.values[i] = a.values[i] * (1.0f - position) + b.values[i] * position;
    }

    // Interpolate semantic controls
    latentVector.brightness = a.brightness * (1.0f - position) + b.brightness * position;
    latentVector.warmth = a.warmth * (1.0f - position) + b.warmth * position;
    latentVector.richness = a.richness * (1.0f - position) + b.richness * position;
    latentVector.attack = a.attack * (1.0f - position) + b.attack * position;
    latentVector.texture = a.texture * (1.0f - position) + b.texture * position;
    latentVector.movement = a.movement * (1.0f - position) + b.movement * position;
    latentVector.space = a.space * (1.0f - position) + b.space * position;
    latentVector.character = a.character * (1.0f - position) + b.character * position;
}

//==============================================================================
// Timbre Transfer
//==============================================================================

void NeuralSoundSynth::setSourceAudio(const juce::AudioBuffer<float>& audio)
{
    sourceAudio = audio;

    // In production, you'd encode the audio to latent space using an encoder model
    // For now, we'll use the current latent vector
}

void NeuralSoundSynth::setTargetTimbre(const NeuralModel& model)
{
    // Load target timbre model
    loadModel(juce::File(model.modelPath));
}

void NeuralSoundSynth::setTransferAmount(float amount)
{
    transferAmount = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Style Transfer
//==============================================================================

void NeuralSoundSynth::setContentAudio(const juce::AudioBuffer<float>& audio)
{
    contentAudio = audio;
}

void NeuralSoundSynth::setStyleAudio(const juce::AudioBuffer<float>& audio)
{
    styleAudio = audio;
}

void NeuralSoundSynth::setStyleAmount(float amount)
{
    styleAmount = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Bio-Reactive Control
//==============================================================================

void NeuralSoundSynth::setBioReactiveEnabled(bool enabled)
{
    bioReactiveEnabled = enabled;
}

void NeuralSoundSynth::setBioData(float hrv, float coherence, float breath)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    bioBreath = juce::jlimit(0.0f, 1.0f, breath);

    if (bioReactiveEnabled)
    {
        updateLatentFromBioData();
    }
}

void NeuralSoundSynth::setBioMapping(const BioMapping& mapping)
{
    bioMapping = mapping;
}

void NeuralSoundSynth::updateLatentFromBioData()
{
    // Modulate latent dimensions based on bio data
    if (bioMapping.hrvDimension >= 0 && bioMapping.hrvDimension < LatentVector::dimensions)
    {
        float modulation = (bioHRV - 0.5f) * bioMapping.hrvAmount;
        latentVector.values[bioMapping.hrvDimension] += modulation;
        latentVector.values[bioMapping.hrvDimension] = juce::jlimit(-2.0f, 2.0f,
            latentVector.values[bioMapping.hrvDimension]);
    }

    if (bioMapping.coherenceDimension >= 0 && bioMapping.coherenceDimension < LatentVector::dimensions)
    {
        float modulation = (bioCoherence - 0.5f) * bioMapping.coherenceAmount;
        latentVector.values[bioMapping.coherenceDimension] += modulation;
        latentVector.values[bioMapping.coherenceDimension] = juce::jlimit(-2.0f, 2.0f,
            latentVector.values[bioMapping.coherenceDimension]);
    }

    if (bioMapping.breathDimension >= 0 && bioMapping.breathDimension < LatentVector::dimensions)
    {
        float modulation = (bioBreath - 0.5f) * bioMapping.breathAmount;
        latentVector.values[bioMapping.breathDimension] += modulation;
        latentVector.values[bioMapping.breathDimension] = juce::jlimit(-2.0f, 2.0f,
            latentVector.values[bioMapping.breathDimension]);
    }
}

void NeuralSoundSynth::applyBioReactiveModulation()
{
    if (!bioReactiveEnabled)
        return;

    updateLatentFromBioData();
}

//==============================================================================
// MPE Support
//==============================================================================

void NeuralSoundSynth::setMPEEnabled(bool enabled)
{
    mpeEnabled = enabled;
}

void NeuralSoundSynth::setMPEZone(int zone)
{
    mpeZone = juce::jlimit(0, 1, zone);
}

//==============================================================================
// Processing
//==============================================================================

void NeuralSoundSynth::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    // Prepare all voices
    setCurrentPlaybackSampleRate(sampleRate);
}

void NeuralSoundSynth::reset()
{
    // Reset all voices
    for (int i = 0; i < getNumVoices(); ++i)
    {
        if (auto* voice = dynamic_cast<NeuralVoice*>(getVoice(i)))
        {
            voice->stopNote(0.0f, false);
        }
    }
}

//==============================================================================
// Visualization & Analysis
//==============================================================================

NeuralSoundSynth::LatentPosition2D NeuralSoundSynth::getLatentPosition2D() const
{
    // Project 128D latent space to 2D using PCA approximation
    // For visualization purposes, we'll use the first two principal components

    LatentPosition2D pos;

    // Approximate 2D projection (simplified PCA)
    float sumX = 0.0f, sumY = 0.0f;

    for (int i = 0; i < 64; ++i)
        sumX += latentVector.values[i];

    for (int i = 64; i < 128; ++i)
        sumY += latentVector.values[i];

    pos.x = juce::jlimit(-1.0f, 1.0f, sumX / 64.0f);
    pos.y = juce::jlimit(-1.0f, 1.0f, sumY / 64.0f);

    return pos;
}

std::vector<float> NeuralSoundSynth::getCurrentSpectrum() const
{
    // Return spectral representation (would need FFT in production)
    // Placeholder: return zeros
    return std::vector<float>(512, 0.0f);
}

//==============================================================================
// Preset Management
//==============================================================================

void NeuralSoundSynth::savePreset(const std::string& name)
{
    // Save preset to file
    auto appData = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);
    auto presetsDir = appData.getChildFile("Echoelmusic").getChildFile("Presets");

    if (!presetsDir.exists())
        presetsDir.createDirectory();

    auto presetFile = presetsDir.getChildFile(name + ".echopreset");

    // Create XML
    juce::XmlElement preset("NeuralPreset");
    preset.setAttribute("name", name);
    preset.setAttribute("mode", static_cast<int>(currentMode));

    // Save latent vector
    auto* latentXml = preset.createNewChildElement("LatentVector");
    latentXml->setAttribute("brightness", latentVector.brightness);
    latentXml->setAttribute("warmth", latentVector.warmth);
    latentXml->setAttribute("richness", latentVector.richness);
    latentXml->setAttribute("attack", latentVector.attack);
    latentXml->setAttribute("texture", latentVector.texture);
    latentXml->setAttribute("movement", latentVector.movement);
    latentXml->setAttribute("space", latentVector.space);
    latentXml->setAttribute("character", latentVector.character);

    // Save to file
    preset.writeTo(presetFile);

    DBG("NeuralSoundSynth: Saved preset '" + juce::String(name) + "'");
}

void NeuralSoundSynth::loadPreset(const std::string& name)
{
    auto appData = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);
    auto presetFile = appData.getChildFile("Echoelmusic").getChildFile("Presets").getChildFile(name + ".echopreset");

    if (!presetFile.existsAsFile())
    {
        DBG("NeuralSoundSynth: Preset not found: " + presetFile.getFullPathName());
        return;
    }

    // Load XML
    auto preset = juce::XmlDocument::parse(presetFile);
    if (!preset)
    {
        DBG("NeuralSoundSynth: Failed to parse preset file");
        return;
    }

    // Load synthesis mode
    currentMode = static_cast<SynthesisMode>(preset->getIntAttribute("mode", 0));

    // Load latent vector
    if (auto* latentXml = preset->getChildByName("LatentVector"))
    {
        latentVector.brightness = latentXml->getDoubleAttribute("brightness", 0.5);
        latentVector.warmth = latentXml->getDoubleAttribute("warmth", 0.5);
        latentVector.richness = latentXml->getDoubleAttribute("richness", 0.5);
        latentVector.attack = latentXml->getDoubleAttribute("attack", 0.5);
        latentVector.texture = latentXml->getDoubleAttribute("texture", 0.5);
        latentVector.movement = latentXml->getDoubleAttribute("movement", 0.5);
        latentVector.space = latentXml->getDoubleAttribute("space", 0.5);
        latentVector.character = latentXml->getDoubleAttribute("character", 0.5);

        latentVector.updateFromSemanticControls();
    }

    DBG("NeuralSoundSynth: Loaded preset '" + juce::String(name) + "'");
}

std::vector<std::string> NeuralSoundSynth::getPresetNames() const
{
    std::vector<std::string> names;

    auto appData = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);
    auto presetsDir = appData.getChildFile("Echoelmusic").getChildFile("Presets");

    if (!presetsDir.exists())
        return names;

    for (auto presetFile : presetsDir.findChildFiles(juce::File::findFiles, false, "*.echopreset"))
    {
        names.push_back(presetFile.getFileNameWithoutExtension().toStdString());
    }

    return names;
}

//==============================================================================
// NeuralVoice Implementation
//==============================================================================

NeuralSoundSynth::NeuralVoice::NeuralVoice(NeuralSoundSynth& parent)
    : synth(parent)
{
    // Initialize inference buffer
    inferenceBuffer.resize(2048, 0.0f);
}

void NeuralSoundSynth::NeuralVoice::startNote(int midiNoteNumber,
                                              float velocity,
                                              juce::SynthesiserSound*,
                                              int currentPitchWheelPosition)
{
    currentNote = midiNoteNumber;
    currentVelocity = velocity;
    pitchBend = (currentPitchWheelPosition - 8192) / 8192.0f;

    // Initialize voice latent vector from synth
    voiceLatent = synth.latentVector;

    // Modulate latent based on MIDI note and velocity
    updateLatentFromMIDI();

    // Generate first block
    generateNextBlock();
}

void NeuralSoundSynth::NeuralVoice::stopNote(float velocity, bool allowTailOff)
{
    if (allowTailOff)
    {
        // Fade out over 50ms
        // In production, you'd use ADSR envelope
    }
    else
    {
        clearCurrentNote();
    }
}

void NeuralSoundSynth::NeuralVoice::pitchWheelMoved(int newPitchWheelValue)
{
    pitchBend = (newPitchWheelValue - 8192) / 8192.0f;
    updateLatentFromMIDI();
}

void NeuralSoundSynth::NeuralVoice::controllerMoved(int controllerNumber, int newControllerValue)
{
    // Handle MIDI CC
    float ccValue = newControllerValue / 127.0f;

    switch (controllerNumber)
    {
        case 1:  // Modulation wheel → texture
            voiceLatent.texture = ccValue;
            voiceLatent.updateFromSemanticControls();
            break;

        case 74: // Brightness
            voiceLatent.brightness = ccValue;
            voiceLatent.updateFromSemanticControls();
            break;

        case 71: // Resonance → richness
            voiceLatent.richness = ccValue;
            voiceLatent.updateFromSemanticControls();
            break;

        default:
            break;
    }
}

void NeuralSoundSynth::NeuralVoice::renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                                                    int startSample,
                                                    int numSamples)
{
    if (!isVoiceActive())
        return;

    // Copy from inference buffer
    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Check if we need to generate new block
        if (bufferReadPos >= static_cast<int>(inferenceBuffer.size()))
        {
            generateNextBlock();
            bufferReadPos = 0;
        }

        // Get sample from buffer
        float outputSample = inferenceBuffer[bufferReadPos++];

        // Apply velocity scaling
        outputSample *= currentVelocity;

        // Write to output (mono for now, duplicate to stereo)
        for (int channel = 0; channel < outputBuffer.getNumChannels(); ++channel)
        {
            outputBuffer.addSample(channel, startSample + sample, outputSample);
        }
    }
}

void NeuralSoundSynth::NeuralVoice::setMPEValues(float slide, float press, float lift)
{
    mpeSlide = slide;
    mpePress = press;
    mpeLift = lift;

    // Modulate latent based on MPE
    if (synth.isMPEEnabled())
    {
        // Slide → brightness
        voiceLatent.brightness = juce::jlimit(0.0f, 1.0f, 0.5f + mpeSlide);

        // Press → warmth
        voiceLatent.warmth = juce::jlimit(0.0f, 1.0f, mpePress);

        // Lift → attack
        voiceLatent.attack = juce::jlimit(0.0f, 1.0f, 1.0f - mpeLift);

        voiceLatent.updateFromSemanticControls();
    }
}

void NeuralSoundSynth::NeuralVoice::updateLatentFromMIDI()
{
    // Map MIDI note to pitch dimension (dimension 0-15)
    float pitchNorm = (currentNote - 60) / 60.0f;  // Normalize around middle C

    for (int i = 0; i < 16; ++i)
    {
        voiceLatent.values[i] = pitchNorm + pitchBend * 0.2f;
    }

    // Map velocity to dynamics (dimension 16-31)
    for (int i = 16; i < 32; ++i)
    {
        voiceLatent.values[i] = (currentVelocity - 0.5f) * 2.0f;
    }
}

void NeuralSoundSynth::NeuralVoice::generateNextBlock()
{
    if (!synth.neuralEngine)
        return;

    // Apply bio-reactive modulation
    if (synth.isBioReactiveEnabled())
    {
        synth.applyBioReactiveModulation();
    }

    // Synthesize audio from latent vector
    inferenceBuffer = synth.neuralEngine->synthesize(voiceLatent, 2048);

    bufferReadPos = 0;
}

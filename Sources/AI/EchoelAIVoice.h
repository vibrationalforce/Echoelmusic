#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <thread>
#include <mutex>
#include <cmath>
#include <optional>

namespace Echoel {
namespace AI {

// =============================================================================
// VOICE TYPES & ENUMS
// =============================================================================

enum class VoiceType {
    // Natural voices
    Soprano,
    MezzoSoprano,
    Contralto,
    Tenor,
    Baritone,
    Bass,

    // Character voices
    Child,
    Teen,
    YoungAdult,
    MiddleAged,
    Elderly,

    // Special voices
    Whisper,
    Breathy,
    Raspy,
    Robotic,
    Ethereal,
    Choir,

    // Genre-specific
    OperaSoprano,
    OperaTenor,
    RnBSoul,
    RockVocal,
    PopVocal,
    RapVocal,
    CountryVocal,
    JazzVocal,
    MetalScream,
    MetalGrowl,

    Custom
};

enum class VoiceGender {
    Male,
    Female,
    Neutral,
    Androgynous
};

enum class VoiceLanguage {
    English,
    German,
    French,
    Spanish,
    Italian,
    Portuguese,
    Japanese,
    Korean,
    Chinese,
    Russian,
    Arabic,
    Hindi,
    Swedish,
    Norwegian,
    Dutch,
    Polish,
    Universal  // Can sing in any language
};

enum class SingingStyle {
    Classical,
    Pop,
    Rock,
    Jazz,
    RnB,
    HipHop,
    Country,
    Electronic,
    Folk,
    Musical,
    Opera,
    Gospel,
    Metal,
    Indie,
    Acapella,
    Spoken
};

enum class VoiceExpression {
    Neutral,
    Happy,
    Sad,
    Angry,
    Tender,
    Passionate,
    Melancholic,
    Playful,
    Dramatic,
    Intimate,
    Powerful,
    Vulnerable,
    Mysterious,
    Euphoric
};

enum class VocalTechnique {
    Normal,
    Vibrato,
    Falsetto,
    HeadVoice,
    ChestVoice,
    MixedVoice,
    Belting,
    Breathy,
    Growl,
    Scream,
    Whistle,
    Fry,
    Trill,
    Riff,
    Run,
    Melisma,
    Portamento,
    Staccato,
    Legato
};

enum class PronunciationType {
    IPA,        // International Phonetic Alphabet
    ARPABET,    // American English
    SAMPA,      // Speech Assessment Methods
    XSampa,     // Extended SAMPA
    Pinyin,     // Chinese
    Romaji,     // Japanese
    Auto        // Automatic detection
};

enum class VoiceModelType {
    NeuralTTS,      // Text-to-speech neural model
    VocoderGAN,     // GAN-based vocoder
    Diffusion,      // Diffusion model
    Transformer,    // Transformer architecture
    Hybrid,         // Multi-model hybrid
    EchoelSing,     // Our singing synthesis
    EchoelSpeak,    // Our speech synthesis
    SVS,            // Singing Voice Synthesis
    Custom
};

// =============================================================================
// DATA STRUCTURES
// =============================================================================

struct AudioBuffer {
    std::vector<float> samples;
    int sampleRate = 44100;
    int channels = 1;
    double duration = 0.0;
};

struct Phoneme {
    std::string symbol;
    std::string ipa;
    double startTime = 0.0;
    double duration = 0.0;
    float stress = 0.5f;         // 0-1
    float emphasis = 0.5f;       // 0-1

    // Singing-specific
    int midiNote = 60;           // MIDI note number
    float pitchBend = 0.0f;      // Cents
    float velocity = 0.8f;       // 0-1
};

struct Word {
    std::string text;
    std::string pronunciation;   // IPA or ARPABET
    std::vector<Phoneme> phonemes;
    double startTime = 0.0;
    double duration = 0.0;
};

struct LyricLine {
    std::string text;
    std::vector<Word> words;
    double startTime = 0.0;
    double duration = 0.0;
    VoiceExpression expression = VoiceExpression::Neutral;
};

struct Lyrics {
    std::string title;
    std::vector<LyricLine> lines;
    VoiceLanguage language = VoiceLanguage::English;
    std::string rawText;

    double totalDuration() const {
        double max = 0.0;
        for (const auto& line : lines) {
            max = std::max(max, line.startTime + line.duration);
        }
        return max;
    }
};

struct Note {
    int midiNote = 60;
    double startTime = 0.0;
    double duration = 0.0;
    float velocity = 0.8f;
    std::string lyric;           // Syllable or word
    std::vector<VocalTechnique> techniques;
    float pitchBend = 0.0f;
    float vibrato = 0.0f;
    float breathiness = 0.0f;
};

struct VoiceMelody {
    std::vector<Note> notes;
    int bpm = 120;
    int timeSignatureNumerator = 4;
    int timeSignatureDenominator = 4;

    void addNote(int midiNote, double start, double duration, const std::string& lyric) {
        Note note;
        note.midiNote = midiNote;
        note.startTime = start;
        note.duration = duration;
        note.lyric = lyric;
        notes.push_back(note);
    }
};

struct VoiceProfile {
    std::string id;
    std::string name;
    VoiceType type = VoiceType::Soprano;
    VoiceGender gender = VoiceGender::Female;
    std::vector<VoiceLanguage> supportedLanguages;
    std::vector<SingingStyle> supportedStyles;

    // Voice characteristics
    float rangeLowestNote = 48;   // MIDI note (C3)
    float rangeHighestNote = 84;  // MIDI note (C6)
    float naturalBreathiness = 0.2f;
    float naturalVibrato = 0.5f;
    float vibratoRate = 5.5f;     // Hz
    float vibratoDepth = 0.3f;    // semitones
    float brightness = 0.5f;
    float warmth = 0.5f;
    float nasality = 0.2f;

    // Model info
    VoiceModelType modelType = VoiceModelType::EchoelSing;
    std::string modelPath;
    size_t modelSize = 0;
    float quality = 0.9f;

    bool canSingNote(int midiNote) const {
        return midiNote >= rangeLowestNote && midiNote <= rangeHighestNote;
    }
};

struct VoiceCloneData {
    std::string id;
    std::string name;
    std::vector<AudioBuffer> referenceSamples;
    double totalReferenceDuration = 0.0;
    VoiceProfile extractedProfile;
    float cloneQuality = 0.0f;
    std::string timestamp;
};

struct SynthesisParams {
    VoiceProfile voice;

    // Expression
    VoiceExpression expression = VoiceExpression::Neutral;
    float expressionIntensity = 0.7f;

    // Dynamics
    float dynamics = 0.7f;       // Overall loudness
    float dynamicRange = 0.5f;   // Variation in loudness

    // Pitch
    float pitchCorrection = 0.5f;  // 0 = natural, 1 = auto-tune
    float pitchShift = 0.0f;       // Semitones
    float formantShift = 0.0f;     // Semitones

    // Timing
    float tempo = 1.0f;            // Speed multiplier
    float attack = 0.5f;           // Note attack character
    float release = 0.5f;          // Note release character

    // Breath
    float breathiness = 0.2f;
    bool addBreaths = true;
    float breathIntensity = 0.5f;

    // Vibrato
    float vibrato = 0.5f;
    float vibratoRate = 5.5f;
    float vibratoDepth = 0.3f;
    float vibratoDelay = 0.3f;     // Seconds before vibrato starts

    // Effects
    float chorus = 0.0f;
    float harmonize = 0.0f;        // Add harmonies
    float reverb = 0.1f;

    // Quality
    int sampleRate = 44100;
    bool highQuality = true;
};

struct SynthesisResult {
    bool success = false;
    std::string error;
    AudioBuffer audio;
    double processingTime = 0.0;
    std::vector<Phoneme> phonemeTimings;
    std::vector<Word> wordTimings;
};

// =============================================================================
// PHONEME PROCESSOR
// =============================================================================

class PhonemeProcessor {
public:
    std::vector<Phoneme> textToPhonemes(const std::string& text,
                                        VoiceLanguage language,
                                        PronunciationType type = PronunciationType::Auto) {
        std::vector<Phoneme> phonemes;

        // Simple English phoneme mapping (simplified)
        static const std::map<char, std::string> basicMapping = {
            {'a', "æ"}, {'e', "ɛ"}, {'i', "ɪ"}, {'o', "ɑ"}, {'u', "ʌ"},
            {'b', "b"}, {'c', "k"}, {'d', "d"}, {'f', "f"}, {'g', "g"},
            {'h', "h"}, {'j', "dʒ"}, {'k', "k"}, {'l', "l"}, {'m', "m"},
            {'n', "n"}, {'p', "p"}, {'q', "k"}, {'r', "ɹ"}, {'s', "s"},
            {'t', "t"}, {'v', "v"}, {'w', "w"}, {'x', "ks"}, {'y', "j"}, {'z', "z"}
        };

        double currentTime = 0.0;
        for (char c : text) {
            if (c == ' ' || c == '\n') {
                currentTime += 0.1;  // Pause
                continue;
            }

            Phoneme p;
            char lower = std::tolower(c);
            auto it = basicMapping.find(lower);
            if (it != basicMapping.end()) {
                p.symbol = std::string(1, c);
                p.ipa = it->second;
                p.startTime = currentTime;
                p.duration = isVowel(lower) ? 0.15 : 0.08;
                phonemes.push_back(p);
                currentTime += p.duration;
            }
        }

        return phonemes;
    }

    std::vector<Word> parseWords(const std::string& text, VoiceLanguage language) {
        std::vector<Word> words;
        std::string currentWord;
        double currentTime = 0.0;

        for (size_t i = 0; i <= text.length(); i++) {
            char c = (i < text.length()) ? text[i] : ' ';

            if (c == ' ' || c == '\n' || c == ',' || c == '.') {
                if (!currentWord.empty()) {
                    Word w;
                    w.text = currentWord;
                    w.phonemes = textToPhonemes(currentWord, language);
                    w.startTime = currentTime;

                    for (const auto& p : w.phonemes) {
                        w.duration += p.duration;
                    }

                    words.push_back(w);
                    currentTime += w.duration + 0.05;  // Gap between words
                    currentWord.clear();
                }
            } else {
                currentWord += c;
            }
        }

        return words;
    }

    Lyrics parseLyrics(const std::string& text, VoiceLanguage language) {
        Lyrics lyrics;
        lyrics.rawText = text;
        lyrics.language = language;

        std::string currentLine;
        double currentTime = 0.0;

        for (size_t i = 0; i <= text.length(); i++) {
            char c = (i < text.length()) ? text[i] : '\n';

            if (c == '\n') {
                if (!currentLine.empty()) {
                    LyricLine line;
                    line.text = currentLine;
                    line.words = parseWords(currentLine, language);
                    line.startTime = currentTime;

                    for (const auto& w : line.words) {
                        line.duration += w.duration;
                    }

                    lyrics.lines.push_back(line);
                    currentTime += line.duration + 0.5;  // Gap between lines
                    currentLine.clear();
                }
            } else {
                currentLine += c;
            }
        }

        return lyrics;
    }

private:
    bool isVowel(char c) const {
        return c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u';
    }
};

// =============================================================================
// PITCH PROCESSOR
// =============================================================================

class PitchProcessor {
public:
    float midiToFrequency(int midiNote) const {
        return 440.0f * std::pow(2.0f, (midiNote - 69) / 12.0f);
    }

    int frequencyToMidi(float frequency) const {
        return static_cast<int>(69 + 12 * std::log2(frequency / 440.0f) + 0.5f);
    }

    std::vector<float> generatePitchCurve(const Note& note, int sampleRate) {
        int numSamples = static_cast<int>(note.duration * sampleRate);
        std::vector<float> curve(numSamples);

        float baseFreq = midiToFrequency(note.midiNote);

        for (int i = 0; i < numSamples; i++) {
            float t = static_cast<float>(i) / sampleRate;
            float freq = baseFreq;

            // Apply pitch bend
            freq *= std::pow(2.0f, note.pitchBend / 1200.0f);

            // Apply vibrato
            if (note.vibrato > 0 && t > 0.2f) {  // Delay vibrato
                float vibratoPhase = 2.0f * M_PI * 5.5f * t;  // 5.5 Hz vibrato
                float vibratoAmount = note.vibrato * 0.3f;  // Max 0.3 semitones
                freq *= std::pow(2.0f, vibratoAmount * std::sin(vibratoPhase) / 12.0f);
            }

            curve[i] = freq;
        }

        return curve;
    }

    std::vector<float> applyPitchCorrection(const std::vector<float>& pitchCurve,
                                             float strength) {
        std::vector<float> corrected = pitchCurve;

        for (auto& freq : corrected) {
            int nearestMidi = frequencyToMidi(freq);
            float nearestFreq = midiToFrequency(nearestMidi);

            // Interpolate between original and nearest note
            freq = freq + (nearestFreq - freq) * strength;
        }

        return corrected;
    }

    void shiftFormants(std::vector<float>& audio, float semitones, int sampleRate) {
        // Formant shifting using phase vocoder (simplified)
        float ratio = std::pow(2.0f, semitones / 12.0f);
        // In real implementation, would use PSOLA or vocoder
    }
};

// =============================================================================
// VOICE SYNTHESIS ENGINE
// =============================================================================

class VoiceSynthesizer {
public:
    bool loadVoice(const VoiceProfile& profile) {
        currentVoice_ = profile;
        voiceLoaded_ = true;
        return true;
    }

    SynthesisResult synthesizeFromMelody(const VoiceMelody& melody,
                                          const SynthesisParams& params) {
        SynthesisResult result;

        if (!voiceLoaded_) {
            result.success = false;
            result.error = "No voice loaded";
            return result;
        }

        auto startTime = std::chrono::high_resolution_clock::now();

        // Calculate total duration
        double duration = 0.0;
        for (const auto& note : melody.notes) {
            duration = std::max(duration, note.startTime + note.duration);
        }
        duration += 0.5;  // Add tail

        // Prepare audio buffer
        result.audio.sampleRate = params.sampleRate;
        result.audio.channels = 1;
        result.audio.duration = duration;
        result.audio.samples.resize(
            static_cast<size_t>(duration * params.sampleRate), 0.0f);

        // Synthesize each note
        for (const auto& note : melody.notes) {
            synthesizeNote(note, params, result.audio);

            // Store phoneme timings
            Phoneme p;
            p.symbol = note.lyric;
            p.startTime = note.startTime;
            p.duration = note.duration;
            p.midiNote = note.midiNote;
            result.phonemeTimings.push_back(p);
        }

        // Apply post-processing
        applyDynamics(result.audio, params);
        if (params.breathiness > 0) {
            addBreathiness(result.audio, params.breathiness);
        }
        if (params.chorus > 0) {
            applyChorus(result.audio, params.chorus);
        }
        if (params.reverb > 0) {
            applyReverb(result.audio, params.reverb);
        }

        // Normalize
        normalizeAudio(result.audio);

        auto endTime = std::chrono::high_resolution_clock::now();
        result.processingTime = std::chrono::duration<double>(endTime - startTime).count();
        result.success = true;

        return result;
    }

    SynthesisResult synthesizeFromLyrics(const Lyrics& lyrics,
                                          const VoiceMelody& melody,
                                          const SynthesisParams& params) {
        // Match lyrics to melody notes
        VoiceMelody alignedMelody = melody;
        alignLyricsToMelody(lyrics, alignedMelody);

        return synthesizeFromMelody(alignedMelody, params);
    }

    SynthesisResult textToSpeech(const std::string& text,
                                  const SynthesisParams& params) {
        SynthesisResult result;

        if (!voiceLoaded_) {
            result.success = false;
            result.error = "No voice loaded";
            return result;
        }

        // Parse text to phonemes
        PhonemeProcessor processor;
        auto words = processor.parseWords(text, VoiceLanguage::English);

        // Synthesize each word
        double duration = 0.0;
        for (const auto& word : words) {
            duration = std::max(duration, word.startTime + word.duration);
        }
        duration += 0.5;

        result.audio.sampleRate = params.sampleRate;
        result.audio.channels = 1;
        result.audio.duration = duration;
        result.audio.samples.resize(
            static_cast<size_t>(duration * params.sampleRate), 0.0f);

        // Synthesize phonemes (simplified - would use neural TTS in reality)
        for (const auto& word : words) {
            synthesizeWord(word, params, result.audio);
            result.wordTimings.push_back(word);
        }

        normalizeAudio(result.audio);
        result.success = true;

        return result;
    }

private:
    void synthesizeNote(const Note& note, const SynthesisParams& params,
                        AudioBuffer& output) {
        int startSample = static_cast<int>(note.startTime * params.sampleRate);
        int numSamples = static_cast<int>(note.duration * params.sampleRate);

        float freq = pitchProcessor_.midiToFrequency(note.midiNote);

        // Apply pitch shift
        freq *= std::pow(2.0f, params.pitchShift / 12.0f);

        // Generate basic waveform with formants
        for (int i = 0; i < numSamples && startSample + i < output.samples.size(); i++) {
            float t = static_cast<float>(i) / params.sampleRate;
            float phase = 2.0f * M_PI * freq * t;

            // Basic vowel synthesis with formants
            float sample = 0.0f;
            sample += std::sin(phase) * 0.5f;                    // Fundamental
            sample += std::sin(phase * 2.0f) * 0.25f;            // First harmonic
            sample += std::sin(phase * 3.0f) * 0.125f;           // Second harmonic

            // Apply vibrato
            if (params.vibrato > 0 && t > params.vibratoDelay) {
                float vibratoPhase = 2.0f * M_PI * params.vibratoRate * (t - params.vibratoDelay);
                float vibratoMod = std::sin(vibratoPhase) * params.vibratoDepth * params.vibrato;
                sample *= 1.0f + vibratoMod * 0.1f;
            }

            // Apply envelope
            float envelope = calculateEnvelope(t, note.duration, params.attack, params.release);
            sample *= envelope * note.velocity;

            output.samples[startSample + i] += sample;
        }
    }

    void synthesizeWord(const Word& word, const SynthesisParams& params,
                        AudioBuffer& output) {
        for (const auto& phoneme : word.phonemes) {
            int startSample = static_cast<int>(phoneme.startTime * params.sampleRate);
            int numSamples = static_cast<int>(phoneme.duration * params.sampleRate);

            // Simple phoneme synthesis (placeholder)
            float freq = 150.0f;  // Base frequency for speech
            if (currentVoice_.gender == VoiceGender::Female) {
                freq = 220.0f;
            }

            for (int i = 0; i < numSamples && startSample + i < output.samples.size(); i++) {
                float t = static_cast<float>(i) / params.sampleRate;
                float sample = std::sin(2.0f * M_PI * freq * t) * 0.3f;

                // Add noise for consonants
                if (phoneme.ipa == "s" || phoneme.ipa == "f" || phoneme.ipa == "h") {
                    sample = ((float)rand() / RAND_MAX - 0.5f) * 0.3f;
                }

                float envelope = calculateEnvelope(t, phoneme.duration, 0.1f, 0.1f);
                output.samples[startSample + i] += sample * envelope;
            }
        }
    }

    float calculateEnvelope(float t, float duration, float attack, float release) const {
        float attackTime = attack * 0.1f;
        float releaseTime = release * 0.1f;

        if (t < attackTime) {
            return t / attackTime;
        } else if (t > duration - releaseTime) {
            return (duration - t) / releaseTime;
        }
        return 1.0f;
    }

    void alignLyricsToMelody(const Lyrics& lyrics, VoiceMelody& melody) {
        // Align lyrics syllables to melody notes
        size_t noteIndex = 0;
        for (const auto& line : lyrics.lines) {
            for (const auto& word : line.words) {
                for (const auto& phoneme : word.phonemes) {
                    if (noteIndex < melody.notes.size()) {
                        melody.notes[noteIndex].lyric = phoneme.symbol;
                        noteIndex++;
                    }
                }
            }
        }
    }

    void applyDynamics(AudioBuffer& audio, const SynthesisParams& params) {
        float gain = params.dynamics;
        for (auto& sample : audio.samples) {
            sample *= gain;
        }
    }

    void addBreathiness(AudioBuffer& audio, float amount) {
        for (auto& sample : audio.samples) {
            float noise = ((float)rand() / RAND_MAX - 0.5f) * 2.0f;
            sample = sample * (1.0f - amount) + noise * amount * 0.1f;
        }
    }

    void applyChorus(AudioBuffer& audio, float amount) {
        // Simple chorus effect (placeholder)
        std::vector<float> delayed(audio.samples.size());
        int delaySamples = audio.sampleRate / 50;  // 20ms delay

        for (size_t i = delaySamples; i < audio.samples.size(); i++) {
            float modulation = std::sin(2.0f * M_PI * 0.5f * i / audio.sampleRate);
            int offset = static_cast<int>(modulation * 10);
            delayed[i] = audio.samples[i - delaySamples + offset];
        }

        for (size_t i = 0; i < audio.samples.size(); i++) {
            audio.samples[i] = audio.samples[i] * (1.0f - amount * 0.5f) +
                               delayed[i] * amount * 0.5f;
        }
    }

    void applyReverb(AudioBuffer& audio, float amount) {
        // Simple reverb (placeholder)
        std::vector<float> reverbed(audio.samples.size());
        int delaySamples = audio.sampleRate / 10;  // 100ms delay

        for (size_t i = delaySamples; i < audio.samples.size(); i++) {
            reverbed[i] = audio.samples[i - delaySamples] * 0.3f;
        }

        for (size_t i = 0; i < audio.samples.size(); i++) {
            audio.samples[i] += reverbed[i] * amount;
        }
    }

    void normalizeAudio(AudioBuffer& audio) {
        float maxAbs = 0.0f;
        for (const auto& sample : audio.samples) {
            maxAbs = std::max(maxAbs, std::abs(sample));
        }

        if (maxAbs > 0.0f) {
            float scale = 0.9f / maxAbs;
            for (auto& sample : audio.samples) {
                sample *= scale;
            }
        }
    }

    VoiceProfile currentVoice_;
    bool voiceLoaded_ = false;
    PitchProcessor pitchProcessor_;
};

// =============================================================================
// VOICE CLONING
// =============================================================================

class VoiceCloner {
public:
    VoiceCloneData analyzeVoice(const std::vector<AudioBuffer>& samples) {
        VoiceCloneData clone;
        clone.id = "clone_" + std::to_string(rand() % 1000000);
        clone.referenceSamples = samples;

        for (const auto& sample : samples) {
            clone.totalReferenceDuration += sample.duration;
        }

        // Analyze voice characteristics
        clone.extractedProfile = extractVoiceProfile(samples);
        clone.cloneQuality = calculateCloneQuality(samples);

        return clone;
    }

    VoiceProfile extractVoiceProfile(const std::vector<AudioBuffer>& samples) {
        VoiceProfile profile;
        profile.id = "extracted_" + std::to_string(rand() % 1000000);
        profile.modelType = VoiceModelType::Custom;

        // Analyze pitch range
        float minPitch = 1000.0f, maxPitch = 0.0f;
        for (const auto& sample : samples) {
            auto pitches = analyzePitch(sample);
            for (float pitch : pitches) {
                if (pitch > 50 && pitch < 2000) {
                    minPitch = std::min(minPitch, pitch);
                    maxPitch = std::max(maxPitch, pitch);
                }
            }
        }

        // Convert to MIDI notes
        profile.rangeLowestNote = 69 + 12 * std::log2(minPitch / 440.0f);
        profile.rangeHighestNote = 69 + 12 * std::log2(maxPitch / 440.0f);

        // Estimate gender from pitch range
        float avgPitch = (minPitch + maxPitch) / 2.0f;
        if (avgPitch > 180) {
            profile.gender = VoiceGender::Female;
            profile.type = VoiceType::Soprano;
        } else {
            profile.gender = VoiceGender::Male;
            profile.type = VoiceType::Baritone;
        }

        return profile;
    }

    bool trainClonedVoice(VoiceCloneData& clone,
                          std::function<void(float)> progressCallback = nullptr) {
        // Training would happen here in real implementation
        // Using neural networks to model the voice

        for (float progress = 0.0f; progress <= 1.0f; progress += 0.1f) {
            if (progressCallback) progressCallback(progress);
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }

        clone.cloneQuality = 0.85f + (float)(rand() % 10) / 100.0f;
        return true;
    }

private:
    std::vector<float> analyzePitch(const AudioBuffer& audio) {
        std::vector<float> pitches;
        // Simplified pitch detection (would use autocorrelation or YIN in reality)

        int windowSize = audio.sampleRate / 50;  // 20ms windows
        for (size_t i = 0; i + windowSize < audio.samples.size(); i += windowSize) {
            float zeroCrossings = 0;
            for (size_t j = i + 1; j < i + windowSize; j++) {
                if ((audio.samples[j] >= 0) != (audio.samples[j-1] >= 0)) {
                    zeroCrossings++;
                }
            }

            float freq = zeroCrossings * audio.sampleRate / (2.0f * windowSize);
            pitches.push_back(freq);
        }

        return pitches;
    }

    float calculateCloneQuality(const std::vector<AudioBuffer>& samples) {
        double totalDuration = 0.0;
        for (const auto& sample : samples) {
            totalDuration += sample.duration;
        }

        // Quality based on amount of training data
        if (totalDuration < 10) return 0.5f;
        if (totalDuration < 30) return 0.7f;
        if (totalDuration < 60) return 0.85f;
        return 0.95f;
    }
};

// =============================================================================
// HARMONY GENERATOR
// =============================================================================

class HarmonyGenerator {
public:
    enum class HarmonyType {
        Third,          // Major/minor third
        Fifth,          // Perfect fifth
        Octave,         // Octave
        ChoirUnison,    // Multiple voices on same note
        ThreePartClose, // Close harmony
        ThreePartOpen,  // Open harmony
        FourPart,       // SATB style
        Custom
    };

    struct HarmonyVoice {
        int interval = 0;       // Semitones from lead
        float volume = 0.7f;
        float pan = 0.0f;
        VoiceType voiceType = VoiceType::Soprano;
    };

    std::vector<VoiceMelody> generateHarmonies(const VoiceMelody& lead,
                                                HarmonyType type) {
        std::vector<VoiceMelody> harmonies;
        auto voices = getVoicesForType(type);

        for (const auto& voice : voices) {
            VoiceMelody harmony;
            harmony.bpm = lead.bpm;
            harmony.timeSignatureNumerator = lead.timeSignatureNumerator;
            harmony.timeSignatureDenominator = lead.timeSignatureDenominator;

            for (const auto& note : lead.notes) {
                Note harmNote = note;
                harmNote.midiNote += voice.interval;
                harmNote.velocity *= voice.volume;
                harmony.notes.push_back(harmNote);
            }

            harmonies.push_back(harmony);
        }

        return harmonies;
    }

private:
    std::vector<HarmonyVoice> getVoicesForType(HarmonyType type) const {
        switch (type) {
            case HarmonyType::Third:
                return {{4, 0.7f, 0.3f, VoiceType::MezzoSoprano}};
            case HarmonyType::Fifth:
                return {{7, 0.7f, -0.3f, VoiceType::Contralto}};
            case HarmonyType::Octave:
                return {{12, 0.5f, 0.0f, VoiceType::Soprano},
                        {-12, 0.5f, 0.0f, VoiceType::Bass}};
            case HarmonyType::ThreePartClose:
                return {{3, 0.7f, -0.3f, VoiceType::MezzoSoprano},
                        {7, 0.7f, 0.3f, VoiceType::Contralto}};
            case HarmonyType::FourPart:
                return {{-12, 0.6f, 0.0f, VoiceType::Bass},
                        {-5, 0.7f, -0.2f, VoiceType::Tenor},
                        {4, 0.7f, 0.2f, VoiceType::MezzoSoprano}};
            default:
                return {};
        }
    }
};

// =============================================================================
// VOICE MANAGER
// =============================================================================

class VoiceManager {
public:
    static VoiceManager& getInstance() {
        static VoiceManager instance;
        return instance;
    }

    // Voice Library
    std::vector<VoiceProfile> getAvailableVoices() const {
        return availableVoices_;
    }

    std::vector<VoiceProfile> getVoicesByType(VoiceType type) const {
        std::vector<VoiceProfile> filtered;
        for (const auto& voice : availableVoices_) {
            if (voice.type == type) {
                filtered.push_back(voice);
            }
        }
        return filtered;
    }

    std::vector<VoiceProfile> getVoicesByGender(VoiceGender gender) const {
        std::vector<VoiceProfile> filtered;
        for (const auto& voice : availableVoices_) {
            if (voice.gender == gender) {
                filtered.push_back(voice);
            }
        }
        return filtered;
    }

    std::optional<VoiceProfile> getVoice(const std::string& id) const {
        for (const auto& voice : availableVoices_) {
            if (voice.id == id) return voice;
        }
        return std::nullopt;
    }

    // Synthesis
    bool loadVoice(const std::string& voiceId) {
        auto voice = getVoice(voiceId);
        if (!voice) return false;
        return synthesizer_.loadVoice(*voice);
    }

    SynthesisResult synthesize(const VoiceMelody& melody,
                                const SynthesisParams& params) {
        return synthesizer_.synthesizeFromMelody(melody, params);
    }

    SynthesisResult synthesize(const Lyrics& lyrics,
                                const VoiceMelody& melody,
                                const SynthesisParams& params) {
        return synthesizer_.synthesizeFromLyrics(lyrics, melody, params);
    }

    SynthesisResult textToSpeech(const std::string& text,
                                  const SynthesisParams& params) {
        return synthesizer_.textToSpeech(text, params);
    }

    // Voice Cloning
    VoiceCloneData cloneVoice(const std::vector<AudioBuffer>& samples) {
        return cloner_.analyzeVoice(samples);
    }

    bool trainClone(VoiceCloneData& clone,
                    std::function<void(float)> progressCallback = nullptr) {
        return cloner_.trainClonedVoice(clone, progressCallback);
    }

    void registerClonedVoice(const VoiceCloneData& clone) {
        availableVoices_.push_back(clone.extractedProfile);
    }

    // Harmonies
    std::vector<SynthesisResult> synthesizeWithHarmonies(
        const VoiceMelody& melody,
        const SynthesisParams& params,
        HarmonyGenerator::HarmonyType harmonyType) {

        std::vector<SynthesisResult> results;

        // Synthesize lead
        results.push_back(synthesizer_.synthesizeFromMelody(melody, params));

        // Generate and synthesize harmonies
        auto harmonies = harmonyGenerator_.generateHarmonies(melody, harmonyType);
        for (const auto& harmony : harmonies) {
            results.push_back(synthesizer_.synthesizeFromMelody(harmony, params));
        }

        return results;
    }

    // Phoneme Processing
    Lyrics parseLyrics(const std::string& text, VoiceLanguage language) {
        return phonemeProcessor_.parseLyrics(text, language);
    }

    std::vector<Phoneme> textToPhonemes(const std::string& text,
                                         VoiceLanguage language) {
        return phonemeProcessor_.textToPhonemes(text, language);
    }

private:
    VoiceManager() {
        initializeDefaultVoices();
    }

    void initializeDefaultVoices() {
        // Add default voice library
        VoiceProfile soprano;
        soprano.id = "echoel_soprano_01";
        soprano.name = "Crystal";
        soprano.type = VoiceType::Soprano;
        soprano.gender = VoiceGender::Female;
        soprano.rangeLowestNote = 60;  // C4
        soprano.rangeHighestNote = 84; // C6
        soprano.supportedLanguages = {VoiceLanguage::English, VoiceLanguage::German};
        soprano.supportedStyles = {SingingStyle::Pop, SingingStyle::Classical};
        availableVoices_.push_back(soprano);

        VoiceProfile tenor;
        tenor.id = "echoel_tenor_01";
        tenor.name = "Marco";
        tenor.type = VoiceType::Tenor;
        tenor.gender = VoiceGender::Male;
        tenor.rangeLowestNote = 48;  // C3
        tenor.rangeHighestNote = 72; // C5
        tenor.supportedLanguages = {VoiceLanguage::English, VoiceLanguage::Italian};
        tenor.supportedStyles = {SingingStyle::Pop, SingingStyle::Rock, SingingStyle::Opera};
        availableVoices_.push_back(tenor);

        VoiceProfile alto;
        alto.id = "echoel_alto_01";
        alto.name = "Aria";
        alto.type = VoiceType::Contralto;
        alto.gender = VoiceGender::Female;
        alto.rangeLowestNote = 53;  // F3
        alto.rangeHighestNote = 77; // F5
        alto.supportedLanguages = {VoiceLanguage::Universal};
        alto.supportedStyles = {SingingStyle::Jazz, SingingStyle::RnB, SingingStyle::Gospel};
        availableVoices_.push_back(alto);

        VoiceProfile bass;
        bass.id = "echoel_bass_01";
        bass.name = "Thunder";
        bass.type = VoiceType::Bass;
        bass.gender = VoiceGender::Male;
        bass.rangeLowestNote = 40;  // E2
        bass.rangeHighestNote = 64; // E4
        bass.supportedLanguages = {VoiceLanguage::English};
        bass.supportedStyles = {SingingStyle::Classical, SingingStyle::Gospel, SingingStyle::Opera};
        availableVoices_.push_back(bass);

        VoiceProfile robotic;
        robotic.id = "echoel_robotic_01";
        robotic.name = "Circuit";
        robotic.type = VoiceType::Robotic;
        robotic.gender = VoiceGender::Neutral;
        robotic.rangeLowestNote = 36;
        robotic.rangeHighestNote = 96;
        robotic.supportedLanguages = {VoiceLanguage::Universal};
        robotic.supportedStyles = {SingingStyle::Electronic};
        availableVoices_.push_back(robotic);

        VoiceProfile ethereal;
        ethereal.id = "echoel_ethereal_01";
        ethereal.name = "Aurora";
        ethereal.type = VoiceType::Ethereal;
        ethereal.gender = VoiceGender::Androgynous;
        ethereal.rangeLowestNote = 48;
        ethereal.rangeHighestNote = 96;
        ethereal.naturalBreathiness = 0.4f;
        ethereal.supportedLanguages = {VoiceLanguage::Universal};
        ethereal.supportedStyles = {SingingStyle::Electronic, SingingStyle::Indie, SingingStyle::Folk};
        availableVoices_.push_back(ethereal);
    }

    std::vector<VoiceProfile> availableVoices_;
    VoiceSynthesizer synthesizer_;
    VoiceCloner cloner_;
    HarmonyGenerator harmonyGenerator_;
    PhonemeProcessor phonemeProcessor_;
    std::mutex mutex_;
};

// =============================================================================
// CONVENIENCE FUNCTIONS
// =============================================================================

inline SynthesisResult synthesizeMelody(const VoiceMelody& melody,
                                         const std::string& voiceId = "echoel_soprano_01") {
    auto& manager = VoiceManager::getInstance();
    manager.loadVoice(voiceId);

    auto voice = manager.getVoice(voiceId);
    SynthesisParams params;
    if (voice) params.voice = *voice;

    return manager.synthesize(melody, params);
}

inline SynthesisResult synthesizeLyrics(const std::string& lyrics,
                                         const VoiceMelody& melody,
                                         const std::string& voiceId = "echoel_soprano_01") {
    auto& manager = VoiceManager::getInstance();
    manager.loadVoice(voiceId);

    auto voice = manager.getVoice(voiceId);
    SynthesisParams params;
    if (voice) params.voice = *voice;

    auto parsedLyrics = manager.parseLyrics(lyrics, VoiceLanguage::English);
    return manager.synthesize(parsedLyrics, melody, params);
}

inline SynthesisResult speak(const std::string& text,
                              const std::string& voiceId = "echoel_tenor_01") {
    auto& manager = VoiceManager::getInstance();
    manager.loadVoice(voiceId);

    auto voice = manager.getVoice(voiceId);
    SynthesisParams params;
    if (voice) params.voice = *voice;

    return manager.textToSpeech(text, params);
}

} // namespace AI
} // namespace Echoel

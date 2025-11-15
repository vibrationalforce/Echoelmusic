#include "PatternGenerator.h"

//==============================================================================
// Constructor
//==============================================================================

PatternGenerator::PatternGenerator()
{
    // Initialize random generator with time-based seed
    randomGenerator.seed(static_cast<unsigned int>(juce::Time::currentTimeMillis()));

    // Initialize Markov chains for pattern generation
    initializeMarkovChains();
}

//==============================================================================
// Pattern Generation
//==============================================================================

PatternGenerator::Pattern PatternGenerator::generatePattern(Genre genre, float complexity, float density)
{
    complexity = juce::jlimit(0.0f, 1.0f, complexity);
    density = juce::jlimit(0.0f, 1.0f, density);

    switch (genre)
    {
        case Genre::House:
            return generateHousePattern(complexity, density);

        case Genre::Techno:
            return generateTechnoPattern(complexity, density);

        case Genre::HipHop:
            return generateHipHopPattern(complexity, density);

        case Genre::DrumAndBass:
            return generateDrumAndBassPattern(complexity, density);

        case Genre::Trap:
            return generateTrapPattern(complexity, density);

        default:
            return generateHousePattern(complexity, density);
    }
}

PatternGenerator::Pattern PatternGenerator::generateBioReactivePattern(Genre genre, float hrv, float coherence)
{
    // Map bio-data to musical parameters
    // HRV → Complexity (0-1)
    float complexity = juce::jmap(hrv, 0.0f, 1.0f, 0.3f, 0.9f);

    // Coherence → Density (higher coherence = more notes)
    float density = juce::jmap(coherence, 0.0f, 1.0f, 0.4f, 0.8f);

    return generatePattern(genre, complexity, density);
}

PatternGenerator::Pattern PatternGenerator::generateFill(const Pattern& basePattern, int fillLength)
{
    Pattern fill;
    fill.length = fillLength;
    fill.genre = basePattern.genre;
    fill.swing = basePattern.swing;

    // Fills typically have increased density and rolls
    for (int step = 0; step < fillLength; ++step)
    {
        // Add snare roll or tom fill
        if (step % 2 == 0 || random() > 0.5f)
        {
            fill.notes.emplace_back(step, 1, 0.7f + random() * 0.3f);  // Snare

            // Add tom hits
            if (random() > 0.7f)
            {
                fill.notes.emplace_back(step, 4 + randomInt(0, 2), 0.6f);  // Toms
            }
        }
    }

    humanizePattern(fill, 0.6f);
    return fill;
}

PatternGenerator::Pattern PatternGenerator::mutatePattern(const Pattern& pattern, float mutationAmount)
{
    Pattern mutated = pattern;

    for (auto& note : mutated.notes)
    {
        // Randomly mutate velocity
        if (random() < mutationAmount * 0.5f)
        {
            note.velocity += (random() - 0.5f) * 0.3f;
            note.velocity = juce::jlimit(0.3f, 1.0f, note.velocity);
        }

        // Randomly shift timing
        if (random() < mutationAmount * 0.3f)
        {
            note.timing += (random() - 0.5f) * 0.1f;
            note.timing = juce::jlimit(-0.1f, 0.1f, note.timing);
        }

        // Randomly add/remove notes
        if (random() < mutationAmount * 0.2f)
        {
            note.velocity = 0.0f;  // "Remove" note
        }
    }

    // Add new random notes
    if (random() < mutationAmount)
    {
        int newStep = randomInt(0, pattern.length - 1);
        int newDrum = randomInt(0, 11);
        mutated.notes.emplace_back(newStep, newDrum, 0.7f);
    }

    return mutated;
}

void PatternGenerator::humanizePattern(Pattern& pattern, float amount)
{
    for (auto& note : pattern.notes)
    {
        // Velocity humanization (slight random variations)
        float velocityVariation = (random() - 0.5f) * amount * 0.2f;
        note.velocity += velocityVariation;
        note.velocity = juce::jlimit(0.3f, 1.0f, note.velocity);

        // Timing humanization (micro-timing shifts)
        float timingVariation = (random() - 0.5f) * amount * 0.05f;
        note.timing += timingVariation;
        note.timing = juce::jlimit(-0.1f, 0.1f, note.timing);
    }
}

//==============================================================================
// Groove & Feel
//==============================================================================

void PatternGenerator::setSwing(float amount)
{
    swing = juce::jlimit(0.0f, 1.0f, amount);
}

void PatternGenerator::setHumanization(float amount)
{
    humanization = juce::jlimit(0.0f, 1.0f, amount);
}

void PatternGenerator::setSeed(unsigned int seed)
{
    randomGenerator.seed(seed);
}

//==============================================================================
// Genre Templates
//==============================================================================

std::pair<int, int> PatternGenerator::getBPMRange(Genre genre)
{
    switch (genre)
    {
        case Genre::House:          return {120, 130};
        case Genre::Techno:         return {125, 135};
        case Genre::HipHop:         return {80, 100};
        case Genre::DrumAndBass:    return {160, 180};
        case Genre::Trap:           return {130, 150};
        case Genre::Funk:           return {90, 110};
        case Genre::Ambient:        return {60, 90};
        case Genre::Rock:           return {110, 140};
        case Genre::Jazz:           return {120, 180};
        case Genre::Experimental:   return {60, 200};
        default:                    return {120, 130};
    }
}

std::vector<int> PatternGenerator::getGenreInstruments(Genre genre)
{
    switch (genre)
    {
        case Genre::House:
            return {0, 1, 2, 3};  // Kick, Snare, Closed Hat, Open Hat

        case Genre::Techno:
            return {0, 1, 2, 7};  // Kick, Snare, Closed Hat, Clap

        case Genre::HipHop:
            return {0, 1, 2, 3, 7};  // Kick, Snare, Hats, Clap

        case Genre::DrumAndBass:
            return {0, 1, 2, 3, 4, 5};  // Kick, Snare, Hats, Toms

        default:
            return {0, 1, 2, 3};
    }
}

//==============================================================================
// Pattern Analysis
//==============================================================================

float PatternGenerator::analyzeComplexity(const Pattern& pattern)
{
    if (pattern.notes.empty())
        return 0.0f;

    // Complexity based on:
    // - Number of unique drum types
    // - Syncopation (offbeat notes)
    // - Velocity variations

    std::set<int> uniqueDrums;
    int offbeatNotes = 0;

    for (const auto& note : pattern.notes)
    {
        uniqueDrums.insert(note.drum);

        if (note.step % 4 != 0)  // Not on downbeat
            offbeatNotes++;
    }

    float drumComplexity = static_cast<float>(uniqueDrums.size()) / 12.0f;
    float rhythmComplexity = static_cast<float>(offbeatNotes) / pattern.notes.size();

    return (drumComplexity + rhythmComplexity) * 0.5f;
}

float PatternGenerator::analyzeDensity(const Pattern& pattern)
{
    // Density = average notes per step
    if (pattern.length == 0)
        return 0.0f;

    return static_cast<float>(pattern.notes.size()) / pattern.length;
}

float PatternGenerator::analyzeSwing(const Pattern& pattern)
{
    // Detect swing by analyzing timing shifts on even steps
    float totalSwing = 0.0f;
    int swingNotes = 0;

    for (const auto& note : pattern.notes)
    {
        if (note.step % 2 == 1)  // Offbeat (8th note)
        {
            totalSwing += note.timing;
            swingNotes++;
        }
    }

    if (swingNotes == 0)
        return 0.0f;

    return juce::jlimit(0.0f, 1.0f, totalSwing / swingNotes + 0.5f);
}

//==============================================================================
// Genre-Specific Pattern Generators
//==============================================================================

PatternGenerator::Pattern PatternGenerator::generateHousePattern(float complexity, float density)
{
    Pattern pattern;
    pattern.genre = Genre::House;
    pattern.length = 16;
    pattern.complexity = complexity;
    pattern.density = density;

    // 4-on-floor kick (every quarter note)
    for (int step = 0; step < 16; step += 4)
    {
        pattern.notes.emplace_back(step, 0, 0.9f);  // Kick
    }

    // Snare on 2 and 4 (backbeat)
    pattern.notes.emplace_back(4, 1, 0.8f);   // Snare
    pattern.notes.emplace_back(12, 1, 0.8f);  // Snare

    // Hi-hats (8th notes)
    if (density > 0.3f)
    {
        for (int step = 0; step < 16; step += 2)
        {
            if (random() < density)
            {
                bool isOpenHat = (step == 6 || step == 14) && random() > 0.5f;
                int hat = isOpenHat ? 3 : 2;  // Open or Closed
                pattern.notes.emplace_back(step, hat, 0.6f + random() * 0.2f);
            }
        }
    }

    // Add complexity (percussion, offbeat elements)
    if (complexity > 0.5f)
    {
        addGrooveVariation(pattern, complexity);
        addSyncopation(pattern, complexity - 0.5f);
    }

    humanizePattern(pattern, humanization);
    return pattern;
}

PatternGenerator::Pattern PatternGenerator::generateTechnoPattern(float complexity, float density)
{
    Pattern pattern;
    pattern.genre = Genre::Techno;
    pattern.length = 16;

    // Driving kick (4-on-floor)
    for (int step = 0; step < 16; step += 4)
    {
        pattern.notes.emplace_back(step, 0, 1.0f);  // Strong kick
    }

    // Minimal hi-hats (16th notes or 8th notes)
    if (density > 0.4f)
    {
        for (int step = 0; step < 16; ++step)
        {
            if (random() < density * 0.7f)
            {
                pattern.notes.emplace_back(step, 2, 0.5f + random() * 0.3f);  // Closed hat
            }
        }
    }

    // Claps or snares (sparse)
    if (complexity > 0.3f)
    {
        pattern.notes.emplace_back(4, 7, 0.7f);   // Clap
        pattern.notes.emplace_back(12, 7, 0.7f);  // Clap
    }

    // Add hypnotic repetition and subtle variations
    if (complexity > 0.6f)
    {
        addGrooveVariation(pattern, complexity);
    }

    humanizePattern(pattern, humanization * 0.5f);  // Less humanization for techno
    return pattern;
}

PatternGenerator::Pattern PatternGenerator::generateHipHopPattern(float complexity, float density)
{
    Pattern pattern;
    pattern.genre = Genre::HipHop;
    pattern.length = 16;
    pattern.swing = 0.3f;  // Hip-hop swing

    // Kick pattern (boom-bap)
    pattern.notes.emplace_back(0, 0, 0.9f);   // Kick on 1
    pattern.notes.emplace_back(8, 0, 0.9f);   // Kick on 3

    if (density > 0.6f)
    {
        pattern.notes.emplace_back(6, 0, 0.7f);   // Extra kick
    }

    // Snare on 2 and 4
    pattern.notes.emplace_back(4, 1, 0.9f);
    pattern.notes.emplace_back(12, 1, 0.9f);

    // Hi-hats (8th notes with swing)
    for (int step = 0; step < 16; step += 2)
    {
        if (random() < density)
        {
            pattern.notes.emplace_back(step, 2, 0.5f + random() * 0.3f);
        }
    }

    // Ghost notes on snare
    if (complexity > 0.5f)
    {
        addGhostNotes(pattern, complexity);
    }

    humanizePattern(pattern, humanization * 1.2f);  // More humanization for hip-hop
    return pattern;
}

PatternGenerator::Pattern PatternGenerator::generateDrumAndBassPattern(float complexity, float density)
{
    Pattern pattern;
    pattern.genre = Genre::DrumAndBass;
    pattern.length = 16;

    // Fast kick pattern
    pattern.notes.emplace_back(0, 0, 0.9f);
    pattern.notes.emplace_back(10, 0, 0.8f);

    // Snare (syncopated)
    pattern.notes.emplace_back(4, 1, 0.9f);
    pattern.notes.emplace_back(12, 1, 0.9f);

    if (complexity > 0.5f)
    {
        pattern.notes.emplace_back(6, 1, 0.6f);
        pattern.notes.emplace_back(14, 1, 0.6f);
    }

    // Fast hi-hats (16th notes)
    for (int step = 0; step < 16; ++step)
    {
        if (random() < density * 0.8f)
        {
            pattern.notes.emplace_back(step, 2, 0.4f + random() * 0.4f);
        }
    }

    // Syncopation and rolls
    addSyncopation(pattern, complexity);

    humanizePattern(pattern, humanization * 0.7f);
    return pattern;
}

PatternGenerator::Pattern PatternGenerator::generateTrapPattern(float complexity, float density)
{
    Pattern pattern;
    pattern.genre = Genre::Trap;
    pattern.length = 16;

    // 808 kick pattern
    pattern.notes.emplace_back(0, 0, 1.0f);
    pattern.notes.emplace_back(6, 0, 0.7f);

    // Snare on 3 (trap signature)
    pattern.notes.emplace_back(8, 1, 0.9f);

    // Hi-hat rolls (fast 16th/32nd notes)
    for (int step = 0; step < 16; ++step)
    {
        if (step >= 12 && random() < density * 1.2f)  // Roll at end
        {
            pattern.notes.emplace_back(step, 2, 0.5f + random() * 0.3f);
        }
        else if (random() < density * 0.5f)
        {
            pattern.notes.emplace_back(step, 2, 0.4f + random() * 0.3f);
        }
    }

    // Add complexity (triplet rolls, snare rolls)
    if (complexity > 0.6f)
    {
        addGrooveVariation(pattern, complexity);
    }

    humanizePattern(pattern, humanization);
    return pattern;
}

//==============================================================================
// Pattern Building Helpers
//==============================================================================

void PatternGenerator::addGrooveVariation(Pattern& pattern, float complexity)
{
    // Add percussion, rim shots, or extra hits
    for (int step = 0; step < pattern.length; ++step)
    {
        if (random() < complexity * 0.3f)
        {
            int drum = randomInt(7, 11);  // Percussion range
            pattern.notes.emplace_back(step, drum, 0.5f + random() * 0.3f);
        }
    }
}

void PatternGenerator::addSyncopation(Pattern& pattern, float amount)
{
    // Add offbeat notes for syncopation
    for (int step = 1; step < pattern.length; step += 4)
    {
        if (random() < amount)
        {
            int drum = randomInt(0, 2);  // Kick, snare, or hat
            pattern.notes.emplace_back(step, drum, 0.6f);
        }
    }
}

void PatternGenerator::addGhostNotes(Pattern& pattern, float amount)
{
    // Add quiet snare hits between main beats
    for (int step = 0; step < pattern.length; ++step)
    {
        if (step % 4 != 0 && random() < amount * 0.4f)
        {
            pattern.notes.emplace_back(step, 1, 0.3f + random() * 0.2f);  // Quiet snare
        }
    }
}

//==============================================================================
// Markov Chain Initialization
//==============================================================================

void PatternGenerator::initializeMarkovChains()
{
    // Initialize simple Markov chains for each genre
    // In a full implementation, this would be trained on real drum patterns

    // House: Kick → Hi-Hat (high probability)
    markovChains[Genre::House][0][0].nextProbabilities = {{2, 0.7f}, {3, 0.2f}, {1, 0.1f}};
    markovChains[Genre::House][2][0].nextProbabilities = {{0, 0.5f}, {2, 0.3f}, {1, 0.2f}};

    // More chains would be added for complete implementation...
}

int PatternGenerator::selectNextDrum(Genre genre, int currentDrum)
{
    if (markovChains.find(genre) != markovChains.end())
    {
        const auto& genreChain = markovChains[genre];
        if (genreChain.find(currentDrum) != genreChain.end())
        {
            const auto& state = genreChain.at(currentDrum)[0];
            float r = random();
            float cumulative = 0.0f;

            for (const auto& [nextDrum, probability] : state.nextProbabilities)
            {
                cumulative += probability;
                if (r < cumulative)
                    return nextDrum;
            }
        }
    }

    return randomInt(0, 11);  // Fallback to random
}

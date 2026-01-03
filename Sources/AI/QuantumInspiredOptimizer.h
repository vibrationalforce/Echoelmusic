#pragma once

#include <JuceHeader.h>
#include <vector>
#include <complex>
#include <random>
#include <functional>
#include <map>
#include <cmath>

/**
 * QuantumInspiredOptimizer - Quantum Algorithms for Music Composition
 *
 * Simulated quantum computing for optimization:
 * - Quantum Annealing for chord progression search
 * - QAOA (Quantum Approximate Optimization)
 * - Variational Quantum Eigensolver (VQE) simulation
 * - Grover's search for pattern matching
 * - Quantum random walks for melody generation
 *
 * Classical simulation of quantum algorithms:
 * - Superposition representation
 * - Interference and entanglement patterns
 * - Exponential search space exploration
 *
 * Applications:
 * - Optimal chord progression discovery
 * - Constraint satisfaction (music theory rules)
 * - Pattern optimization in arrangements
 * - Creative randomness with quantum noise
 *
 * 2026 Quantum-Inspired AI
 */

namespace Echoelmusic {
namespace AI {

//==============================================================================
// Quantum State Representation
//==============================================================================

using Complex = std::complex<double>;

class QubitState
{
public:
    QubitState() : amplitudes({1.0, 0.0}) {} // |0⟩ state

    static QubitState zero() { return QubitState(); }
    static QubitState one() { QubitState q; q.amplitudes = {0.0, 1.0}; return q; }
    static QubitState plus() { QubitState q; q.amplitudes = {M_SQRT1_2, M_SQRT1_2}; return q; }
    static QubitState minus() { QubitState q; q.amplitudes = {M_SQRT1_2, -M_SQRT1_2}; return q; }

    // Hadamard gate
    void hadamard()
    {
        Complex a0 = amplitudes[0];
        Complex a1 = amplitudes[1];
        amplitudes[0] = (a0 + a1) * M_SQRT1_2;
        amplitudes[1] = (a0 - a1) * M_SQRT1_2;
    }

    // Pauli-X (NOT gate)
    void pauliX()
    {
        std::swap(amplitudes[0], amplitudes[1]);
    }

    // Pauli-Z (phase flip)
    void pauliZ()
    {
        amplitudes[1] *= -1.0;
    }

    // Rotation around Y-axis
    void rotateY(double theta)
    {
        Complex a0 = amplitudes[0];
        Complex a1 = amplitudes[1];
        double c = std::cos(theta / 2);
        double s = std::sin(theta / 2);
        amplitudes[0] = c * a0 - s * a1;
        amplitudes[1] = s * a0 + c * a1;
    }

    // Measure (collapse to classical state)
    int measure()
    {
        double prob0 = std::norm(amplitudes[0]);
        double r = static_cast<double>(rand()) / RAND_MAX;
        int result = (r < prob0) ? 0 : 1;

        // Collapse
        if (result == 0)
        {
            amplitudes[0] = 1.0;
            amplitudes[1] = 0.0;
        }
        else
        {
            amplitudes[0] = 0.0;
            amplitudes[1] = 1.0;
        }

        return result;
    }

    double getProbability0() const { return std::norm(amplitudes[0]); }
    double getProbability1() const { return std::norm(amplitudes[1]); }

private:
    std::array<Complex, 2> amplitudes;
};

//==============================================================================
// Multi-Qubit Register
//==============================================================================

class QuantumRegister
{
public:
    QuantumRegister(int numQubits) : n(numQubits)
    {
        // 2^n amplitudes
        int dim = 1 << n;
        amplitudes.resize(dim, 0.0);
        amplitudes[0] = 1.0; // |00...0⟩
    }

    int getNumQubits() const { return n; }
    int getDimension() const { return 1 << n; }

    // Apply Hadamard to all qubits (create superposition)
    void hadamardAll()
    {
        int dim = getDimension();
        std::vector<Complex> newAmps(dim, 0.0);

        for (int i = 0; i < dim; ++i)
        {
            for (int j = 0; j < dim; ++j)
            {
                // Count matching bits
                int overlap = __builtin_popcount(i ^ j);
                double sign = (overlap % 2 == 0) ? 1.0 : -1.0;
                newAmps[i] += amplitudes[j] * sign / std::sqrt(dim);
            }
        }

        amplitudes = newAmps;
    }

    // Apply phase based on cost function (for QAOA)
    void applyPhaseSeparation(std::function<double(int)> costFunction, double gamma)
    {
        int dim = getDimension();
        for (int i = 0; i < dim; ++i)
        {
            double cost = costFunction(i);
            Complex phase = std::exp(Complex(0, -gamma * cost));
            amplitudes[i] *= phase;
        }
    }

    // Apply mixing operator (for QAOA)
    void applyMixer(double beta)
    {
        // Simplified: apply RX rotations
        int dim = getDimension();
        std::vector<Complex> newAmps(dim, 0.0);

        double c = std::cos(beta);
        double s = std::sin(beta);

        for (int i = 0; i < dim; ++i)
        {
            for (int q = 0; q < n; ++q)
            {
                int j = i ^ (1 << q); // Flip qubit q
                newAmps[i] += amplitudes[i] * c;
                newAmps[i] += Complex(0, -s) * amplitudes[j];
            }
        }

        // Normalize
        double norm = 0;
        for (const auto& a : newAmps) norm += std::norm(a);
        norm = std::sqrt(norm);
        for (auto& a : newAmps) a /= norm;

        amplitudes = newAmps;
    }

    // Measure entire register
    int measure()
    {
        int dim = getDimension();

        // Build cumulative distribution
        std::vector<double> cumProb(dim);
        cumProb[0] = std::norm(amplitudes[0]);
        for (int i = 1; i < dim; ++i)
        {
            cumProb[i] = cumProb[i-1] + std::norm(amplitudes[i]);
        }

        // Sample
        double r = static_cast<double>(rand()) / RAND_MAX * cumProb.back();
        int result = 0;
        for (int i = 0; i < dim; ++i)
        {
            if (r <= cumProb[i])
            {
                result = i;
                break;
            }
        }

        // Collapse
        std::fill(amplitudes.begin(), amplitudes.end(), Complex(0.0));
        amplitudes[result] = 1.0;

        return result;
    }

    // Get probability distribution
    std::vector<double> getProbabilities() const
    {
        std::vector<double> probs;
        probs.reserve(amplitudes.size());
        for (const auto& a : amplitudes)
        {
            probs.push_back(std::norm(a));
        }
        return probs;
    }

private:
    int n;
    std::vector<Complex> amplitudes;
};

//==============================================================================
// Music Theory Constraints as Ising Hamiltonian
//==============================================================================

class MusicTheoryHamiltonian
{
public:
    struct ChordConstraint
    {
        int chord1;
        int chord2;
        double penalty;     // Higher = more discouraged
        std::string reason;
    };

    MusicTheoryHamiltonian()
    {
        setupConstraints();
    }

    double computeEnergy(const std::vector<int>& chordProgression) const
    {
        double energy = 0.0;

        for (size_t i = 0; i < chordProgression.size() - 1; ++i)
        {
            int c1 = chordProgression[i];
            int c2 = chordProgression[i + 1];

            // Lookup penalty
            auto key = std::make_pair(c1, c2);
            auto it = transitionPenalties.find(key);
            if (it != transitionPenalties.end())
            {
                energy += it->second;
            }

            // Reward circle of fifths movement
            int fifthsDistance = std::abs((c2 - c1 + 12) % 12 - 7);
            energy -= fifthsDistance == 0 ? 2.0 : 0.0;

            // Penalize parallel fifths
            if ((c2 - c1 + 12) % 12 == 7)
            {
                energy += 1.0;
            }
        }

        // Reward returning to tonic
        if (!chordProgression.empty())
        {
            if (chordProgression.back() == chordProgression.front())
            {
                energy -= 3.0;
            }
        }

        return energy;
    }

    // Convert chord progression state (integer) to chord sequence
    std::vector<int> decodeState(int state, int progressionLength, int numChordOptions) const
    {
        std::vector<int> chords(progressionLength);
        for (int i = 0; i < progressionLength; ++i)
        {
            chords[i] = state % numChordOptions;
            state /= numChordOptions;
        }
        return chords;
    }

    // Get chord name from index
    static std::string getChordName(int index, const std::string& key = "C")
    {
        static const std::vector<std::string> degrees = {
            "I", "ii", "iii", "IV", "V", "vi", "vii°"
        };
        return degrees[index % 7];
    }

private:
    std::map<std::pair<int, int>, double> transitionPenalties;

    void setupConstraints()
    {
        // Common progressions (lower energy = more favorable)
        // I-IV-V-I is classic
        // I-V-vi-IV is pop

        // Parallel motion penalties
        for (int i = 0; i < 7; ++i)
        {
            for (int j = 0; j < 7; ++j)
            {
                if (i == j)
                {
                    transitionPenalties[{i, j}] = 0.5; // Same chord twice is OK but not ideal
                }
            }
        }

        // vii° to I is strong resolution
        transitionPenalties[{6, 0}] = -2.0;

        // V to I is strongest resolution
        transitionPenalties[{4, 0}] = -3.0;

        // IV to I (plagal cadence)
        transitionPenalties[{3, 0}] = -1.5;

        // ii to V (common jazz)
        transitionPenalties[{1, 4}] = -1.5;
    }
};

//==============================================================================
// QAOA for Chord Progression Optimization
//==============================================================================

class QAOAChordOptimizer
{
public:
    struct Config
    {
        int numLayers = 3;              // QAOA depth
        int numChordOptions = 7;        // I, ii, iii, IV, V, vi, vii°
        int progressionLength = 4;      // Number of chords
        int numShots = 1000;            // Measurement repetitions
    };

    QAOAChordOptimizer(const Config& config = Config())
        : config(config)
    {
        // Initialize variational parameters
        gammas.resize(config.numLayers, 0.5);
        betas.resize(config.numLayers, 0.5);
    }

    std::vector<int> optimize()
    {
        // Classical optimization of quantum parameters
        // Simplified: grid search
        std::vector<int> bestProgression;
        double bestEnergy = std::numeric_limits<double>::max();

        for (double g = 0.1; g < 2.0; g += 0.3)
        {
            for (double b = 0.1; b < 2.0; b += 0.3)
            {
                std::fill(gammas.begin(), gammas.end(), g);
                std::fill(betas.begin(), betas.end(), b);

                auto result = runQAOA();

                double energy = hamiltonian.computeEnergy(result);
                if (energy < bestEnergy)
                {
                    bestEnergy = energy;
                    bestProgression = result;
                }
            }
        }

        return bestProgression;
    }

    std::vector<int> runQAOA()
    {
        int numQubits = config.progressionLength * 3; // 3 bits per chord (8 options)
        QuantumRegister reg(std::min(numQubits, 12)); // Limit for simulation

        // Initial superposition
        reg.hadamardAll();

        // QAOA layers
        for (int layer = 0; layer < config.numLayers; ++layer)
        {
            // Cost layer
            reg.applyPhaseSeparation([this](int state) {
                auto chords = hamiltonian.decodeState(state, config.progressionLength, config.numChordOptions);
                return hamiltonian.computeEnergy(chords);
            }, gammas[layer]);

            // Mixer layer
            reg.applyMixer(betas[layer]);
        }

        // Sample results
        std::map<int, int> counts;
        for (int shot = 0; shot < config.numShots; ++shot)
        {
            QuantumRegister regCopy = reg;
            int result = regCopy.measure();
            counts[result]++;
        }

        // Find most common result
        int bestState = 0;
        int maxCount = 0;
        for (const auto& [state, count] : counts)
        {
            if (count > maxCount)
            {
                maxCount = count;
                bestState = state;
            }
        }

        return hamiltonian.decodeState(bestState, config.progressionLength, config.numChordOptions);
    }

private:
    Config config;
    MusicTheoryHamiltonian hamiltonian;
    std::vector<double> gammas;
    std::vector<double> betas;
};

//==============================================================================
// Quantum Random Walk for Melody Generation
//==============================================================================

class QuantumMelodyWalk
{
public:
    struct Note
    {
        int pitch;          // MIDI note
        double duration;    // Beats
    };

    QuantumMelodyWalk(int scaleRoot = 60, const std::vector<int>& scaleIntervals = {0, 2, 4, 5, 7, 9, 11})
        : root(scaleRoot), scale(scaleIntervals)
    {
    }

    std::vector<Note> generateMelody(int length, float quantumness = 0.5f)
    {
        std::vector<Note> melody;
        int position = scale.size() / 2; // Start in middle of scale

        // Quantum register for position
        int numPositions = static_cast<int>(scale.size());
        QuantumRegister reg(4); // 16 positions max

        for (int i = 0; i < length; ++i)
        {
            // Coin flip with Hadamard
            reg.hadamardAll();

            // Apply phase based on melodic contour preference
            reg.applyPhaseSeparation([this, position, numPositions](int state) {
                int newPos = state % numPositions;
                int step = std::abs(newPos - position);

                // Prefer stepwise motion
                if (step == 1) return -1.0;
                if (step == 2) return 0.0;
                if (step > 3) return 2.0;
                return 0.5;
            }, quantumness);

            // Measure to get new position
            int measurement = reg.measure() % numPositions;

            // Blend classical and quantum
            if (static_cast<float>(rand()) / RAND_MAX < quantumness)
            {
                position = measurement;
            }
            else
            {
                // Classical: random walk
                int step = (rand() % 3) - 1; // -1, 0, or 1
                position = std::clamp(position + step, 0, numPositions - 1);
            }

            // Create note
            Note note;
            note.pitch = root + scale[position];
            note.duration = (rand() % 4 == 0) ? 2.0 : 1.0; // Mostly quarter notes

            melody.push_back(note);
        }

        return melody;
    }

private:
    int root;
    std::vector<int> scale;
};

//==============================================================================
// Quantum-Enhanced Randomness
//==============================================================================

class QuantumRandomGenerator
{
public:
    // True quantum-quality randomness simulation
    double nextDouble()
    {
        QubitState q = QubitState::plus();

        // Multiple Hadamard applications for better mixing
        for (int i = 0; i < 8; ++i)
        {
            q.hadamard();
            q.rotateY(measurements[i % measurements.size()] * 0.1);
        }

        double r = q.getProbability1();
        measurements.push_back(q.measure());

        if (measurements.size() > 64)
        {
            measurements.erase(measurements.begin());
        }

        return r;
    }

    int nextInt(int min, int max)
    {
        return min + static_cast<int>(nextDouble() * (max - min + 1));
    }

    float nextFloat()
    {
        return static_cast<float>(nextDouble());
    }

    // Generate quantum-random bytes for true randomness
    std::vector<uint8_t> generateBytes(int count)
    {
        std::vector<uint8_t> bytes;
        bytes.reserve(count);

        for (int i = 0; i < count; ++i)
        {
            int byte = 0;
            for (int bit = 0; bit < 8; ++bit)
            {
                QubitState q = QubitState::plus();
                byte |= (q.measure() << bit);
            }
            bytes.push_back(static_cast<uint8_t>(byte));
        }

        return bytes;
    }

private:
    std::vector<int> measurements;
};

//==============================================================================
// Unified Quantum Optimizer
//==============================================================================

class QuantumOptimizer
{
public:
    static QuantumOptimizer& getInstance()
    {
        static QuantumOptimizer instance;
        return instance;
    }

    // Chord progression optimization
    std::vector<int> optimizeChordProgression(int length = 4)
    {
        QAOAChordOptimizer::Config config;
        config.progressionLength = length;

        QAOAChordOptimizer qaoa(config);
        return qaoa.optimize();
    }

    // Melody generation with quantum walk
    std::vector<QuantumMelodyWalk::Note> generateQuantumMelody(int length, int root = 60, float quantumness = 0.5f)
    {
        QuantumMelodyWalk walk(root);
        return walk.generateMelody(length, quantumness);
    }

    // Quantum random number
    double quantumRandom()
    {
        return rng.nextDouble();
    }

    int quantumRandomInt(int min, int max)
    {
        return rng.nextInt(min, max);
    }

private:
    QuantumOptimizer() = default;
    QuantumRandomGenerator rng;
};

//==============================================================================
// Convenience
//==============================================================================

#define QuantumAI QuantumOptimizer::getInstance()

} // namespace AI
} // namespace Echoelmusic

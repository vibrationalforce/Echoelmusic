#pragma once

//==============================================================================
/**
    EchoelTypeSystem.h

    "Think in Types" - Boris Cherny Style

    Design Philosophy:
    1. Make illegal states unrepresentable
    2. Use discriminated unions (tagged types)
    3. Types as documentation
    4. Compile-time safety over runtime checks
    5. Phantom types for compile-time guarantees

    "A type system is like a proof assistant for your code."
    - Boris Cherny, Programming TypeScript

    Copyright (c) 2024-2025 Echoelmusic
*/
//==============================================================================

#include <variant>
#include <optional>
#include <string>
#include <vector>
#include <functional>
#include <type_traits>
#include <chrono>

namespace Echoel
{
namespace Types
{

//==============================================================================
// PHANTOM TYPES - Compile-time unit safety
//==============================================================================

// Prevent mixing up BPM, Hz, milliseconds, etc.
template<typename T, typename Tag>
struct Tagged
{
    T value;

    explicit constexpr Tagged(T v) : value(v) {}

    constexpr T get() const { return value; }

    // Only allow operations with same tag
    constexpr Tagged operator+(Tagged other) const { return Tagged(value + other.value); }
    constexpr Tagged operator-(Tagged other) const { return Tagged(value - other.value); }
    constexpr Tagged operator*(T scalar) const { return Tagged(value * scalar); }
    constexpr Tagged operator/(T scalar) const { return Tagged(value / scalar); }

    constexpr bool operator<(Tagged other) const { return value < other.value; }
    constexpr bool operator>(Tagged other) const { return value > other.value; }
    constexpr bool operator==(Tagged other) const { return value == other.value; }
    constexpr bool operator!=(Tagged other) const { return value != other.value; }
};

// Unit tags
struct BPMTag {};
struct HzTag {};
struct MillisecondsTag {};
struct SecondsTag {};
struct SamplesTag {};
struct DecibelTag {};
struct NormalizedTag {};  // 0.0 - 1.0
struct MIDINoteTag {};
struct VelocityTag {};
struct BeatsTag {};

// Type aliases with phantom types
using BPM = Tagged<double, BPMTag>;
using Hz = Tagged<double, HzTag>;
using Milliseconds = Tagged<double, MillisecondsTag>;
using Seconds = Tagged<double, SecondsTag>;
using Samples = Tagged<int64_t, SamplesTag>;
using Decibel = Tagged<float, DecibelTag>;
using Normalized = Tagged<float, NormalizedTag>;  // 0.0 - 1.0
using MIDINote = Tagged<uint8_t, MIDINoteTag>;
using Velocity = Tagged<uint8_t, VelocityTag>;
using Beats = Tagged<double, BeatsTag>;

// User-defined literals for clarity
constexpr BPM operator""_bpm(long double v) { return BPM(static_cast<double>(v)); }
constexpr Hz operator""_hz(long double v) { return Hz(static_cast<double>(v)); }
constexpr Milliseconds operator""_ms(long double v) { return Milliseconds(static_cast<double>(v)); }
constexpr Seconds operator""_sec(long double v) { return Seconds(static_cast<double>(v)); }
constexpr Decibel operator""_db(long double v) { return Decibel(static_cast<float>(v)); }

// Conversions (explicit, type-safe)
constexpr Milliseconds toMs(Seconds s) { return Milliseconds(s.get() * 1000.0); }
constexpr Seconds toSec(Milliseconds ms) { return Seconds(ms.get() / 1000.0); }
constexpr Samples toSamples(Seconds s, Hz sampleRate) {
    return Samples(static_cast<int64_t>(s.get() * sampleRate.get()));
}

//==============================================================================
// BOUNDED TYPES - Make illegal values unrepresentable
//==============================================================================

template<typename T, T Min, T Max>
struct Bounded
{
    static_assert(Min <= Max, "Min must be <= Max");

private:
    T value;

public:
    constexpr Bounded() : value(Min) {}

    // Factory - returns optional (can fail)
    static constexpr std::optional<Bounded> make(T v)
    {
        if (v >= Min && v <= Max)
            return Bounded(v);
        return std::nullopt;
    }

    // Factory - clamps (never fails)
    static constexpr Bounded clamp(T v)
    {
        if (v < Min) return Bounded(Min);
        if (v > Max) return Bounded(Max);
        return Bounded(v);
    }

    constexpr T get() const { return value; }
    constexpr operator T() const { return value; }

private:
    constexpr explicit Bounded(T v) : value(v) {}
};

// Common bounded types
using Percentage = Bounded<float, 0.0f, 100.0f>;
using UnitInterval = Bounded<float, 0.0f, 1.0f>;      // [0, 1]
using SignedUnit = Bounded<float, -1.0f, 1.0f>;       // [-1, 1]
using MIDIChannel = Bounded<uint8_t, 1, 16>;
using MIDINoteNumber = Bounded<uint8_t, 0, 127>;
using MIDIVelocity = Bounded<uint8_t, 0, 127>;
using Coherence = Bounded<float, 0.0f, 1.0f>;         // HeartMath coherence
using StressLevel = Bounded<float, 0.0f, 1.0f>;

//==============================================================================
// NON-EMPTY TYPES - Prevent empty collection errors
//==============================================================================

template<typename T>
class NonEmpty
{
    std::vector<T> items;

public:
    // Can only construct with at least one item
    explicit NonEmpty(T first) : items{std::move(first)} {}

    NonEmpty(T first, std::vector<T> rest)
        : items{std::move(first)}
    {
        items.insert(items.end(), rest.begin(), rest.end());
    }

    // Always safe - guaranteed non-empty
    const T& head() const { return items.front(); }
    T& head() { return items.front(); }

    // Safe access
    const T& operator[](size_t i) const { return items[i]; }
    size_t size() const { return items.size(); }

    void push_back(T item) { items.push_back(std::move(item)); }

    auto begin() const { return items.begin(); }
    auto end() const { return items.end(); }
};

//==============================================================================
// DISCRIMINATED UNIONS - Tagged variants
//==============================================================================

// Bio-data source - exactly one of these
namespace BioSource
{
    struct AppleWatch { std::string deviceId; };
    struct PolarH10 { std::string bleAddress; };
    struct OuraRing { std::string accessToken; };
    struct Simulator { float baseHeartRate; };
}

using BioDataSource = std::variant<
    BioSource::AppleWatch,
    BioSource::PolarH10,
    BioSource::OuraRing,
    BioSource::Simulator
>;

// Connection state - exactly one
namespace ConnectionState
{
    struct Disconnected {};
    struct Connecting { std::chrono::steady_clock::time_point startedAt; };
    struct Connected { std::chrono::steady_clock::time_point connectedAt; };
    struct Error { std::string message; int code; };
}

using DeviceConnectionState = std::variant<
    ConnectionState::Disconnected,
    ConnectionState::Connecting,
    ConnectionState::Connected,
    ConnectionState::Error
>;

// Playback state - exactly one
namespace PlayState
{
    struct Stopped {};
    struct Playing { Beats position; BPM tempo; };
    struct Paused { Beats position; };
    struct Recording { Beats position; BPM tempo; };
}

using PlaybackState = std::variant<
    PlayState::Stopped,
    PlayState::Playing,
    PlayState::Paused,
    PlayState::Recording
>;

// Musical suggestion - exactly one type
namespace Suggestion
{
    struct Chord {
        MIDINoteNumber root;
        std::vector<MIDINoteNumber> notes;
        std::string name;  // "Cmaj7"
    };

    struct Progression {
        NonEmpty<Chord> chords;
        Beats duration;
    };

    struct Melody {
        NonEmpty<MIDINoteNumber> notes;
        std::vector<Beats> rhythm;
    };

    struct Rhythm {
        std::vector<UnitInterval> pattern;  // 0 = silent, 1 = full
        Beats length;
    };

    struct TakeBreak {
        Seconds suggestedDuration;
        std::string reason;
    };
}

using MusicalSuggestion = std::variant<
    Suggestion::Chord,
    Suggestion::Progression,
    Suggestion::Melody,
    Suggestion::Rhythm,
    Suggestion::TakeBreak
>;

//==============================================================================
// RESULT TYPE - No exceptions, explicit error handling
//==============================================================================

template<typename T, typename E = std::string>
class Result
{
    std::variant<T, E> data;

public:
    // Success
    static Result ok(T value) { return Result(std::move(value)); }

    // Failure
    static Result err(E error) { return Result(std::move(error), false); }

    bool isOk() const { return std::holds_alternative<T>(data); }
    bool isErr() const { return std::holds_alternative<E>(data); }

    // Safe access
    const T& value() const { return std::get<T>(data); }
    const E& error() const { return std::get<E>(data); }

    // Monadic operations
    template<typename F>
    auto map(F f) const -> Result<decltype(f(std::declval<T>())), E>
    {
        if (isOk())
            return Result<decltype(f(value())), E>::ok(f(value()));
        return Result<decltype(f(value())), E>::err(error());
    }

    template<typename F>
    auto flatMap(F f) const -> decltype(f(std::declval<T>()))
    {
        if (isOk())
            return f(value());
        return decltype(f(value()))::err(error());
    }

    // Pattern matching
    template<typename OnOk, typename OnErr>
    auto match(OnOk onOk, OnErr onErr) const
    {
        if (isOk())
            return onOk(value());
        return onErr(error());
    }

private:
    explicit Result(T value) : data(std::move(value)) {}
    Result(E error, bool) : data(std::move(error)) {}
};

//==============================================================================
// ASYNC RESULT - For async operations
//==============================================================================

template<typename T>
class AsyncResult
{
public:
    struct Pending {};
    struct Loading { float progress; };  // 0-1
    struct Success { T value; };
    struct Failure { std::string error; };

private:
    std::variant<Pending, Loading, Success, Failure> state;

public:
    static AsyncResult pending() { return AsyncResult(Pending{}); }
    static AsyncResult loading(float progress) { return AsyncResult(Loading{progress}); }
    static AsyncResult success(T value) { return AsyncResult(Success{std::move(value)}); }
    static AsyncResult failure(std::string error) { return AsyncResult(Failure{std::move(error)}); }

    bool isPending() const { return std::holds_alternative<Pending>(state); }
    bool isLoading() const { return std::holds_alternative<Loading>(state); }
    bool isSuccess() const { return std::holds_alternative<Success>(state); }
    bool isFailure() const { return std::holds_alternative<Failure>(state); }

    float getProgress() const {
        if (auto* l = std::get_if<Loading>(&state)) return l->progress;
        if (isSuccess()) return 1.0f;
        return 0.0f;
    }

    std::optional<T> getValue() const {
        if (auto* s = std::get_if<Success>(&state)) return s->value;
        return std::nullopt;
    }

    std::optional<std::string> getError() const {
        if (auto* f = std::get_if<Failure>(&state)) return f->error;
        return std::nullopt;
    }

private:
    template<typename S>
    explicit AsyncResult(S s) : state(std::move(s)) {}
};

//==============================================================================
// BUILDER PATTERN WITH TYPES - Required vs Optional fields
//==============================================================================

// Phantom types for builder state
struct HasKey {};
struct NoKey {};
struct HasTempo {};
struct NoTempo {};

template<typename KeyState, typename TempoState>
class SessionBuilder
{
    std::optional<MIDINoteNumber> key;
    std::optional<BPM> tempo;
    std::optional<std::string> name;

public:
    SessionBuilder() = default;

    // Set key (required) - changes type
    auto withKey(MIDINoteNumber k) &&
    {
        key = k;
        SessionBuilder<HasKey, TempoState> next;
        next.key = key;
        next.tempo = tempo;
        next.name = name;
        return next;
    }

    // Set tempo (required) - changes type
    auto withTempo(BPM t) &&
    {
        tempo = t;
        SessionBuilder<KeyState, HasTempo> next;
        next.key = key;
        next.tempo = tempo;
        next.name = name;
        return next;
    }

    // Set name (optional) - same type
    auto withName(std::string n) &&
    {
        name = std::move(n);
        return std::move(*this);
    }

    // Only available when both required fields are set
    template<typename K = KeyState, typename T = TempoState,
             std::enable_if_t<std::is_same_v<K, HasKey> && std::is_same_v<T, HasTempo>, int> = 0>
    auto build()
    {
        struct Session {
            MIDINoteNumber key;
            BPM tempo;
            std::string name;
        };
        return Session{*key, *tempo, name.value_or("Untitled")};
    }

    template<typename, typename> friend class SessionBuilder;
};

//==============================================================================
// EVENT TYPES - Type-safe event system
//==============================================================================

namespace Events
{
    // Bio events
    struct HeartRateChanged { float bpm; };
    struct HRVChanged { float rmssd; };
    struct CoherenceChanged { Coherence level; };
    struct StressChanged { StressLevel level; };

    // Musical events
    struct NoteOn { MIDINoteNumber note; MIDIVelocity velocity; MIDIChannel channel; };
    struct NoteOff { MIDINoteNumber note; MIDIChannel channel; };
    struct KeyChanged { MIDINoteNumber root; std::string scaleName; };
    struct TempoChanged { BPM tempo; };

    // UI events
    struct FeatureUnlocked { std::string featureId; };
    struct SuggestionShown { std::string suggestionId; };
    struct SuggestionAccepted { std::string suggestionId; };

    // System events
    struct SessionStarted { std::string sessionId; };
    struct SessionEnded { std::string sessionId; Seconds duration; };
    struct SnapshotCreated { std::string snapshotId; };
}

using BioEvent = std::variant<
    Events::HeartRateChanged,
    Events::HRVChanged,
    Events::CoherenceChanged,
    Events::StressChanged
>;

using MusicEvent = std::variant<
    Events::NoteOn,
    Events::NoteOff,
    Events::KeyChanged,
    Events::TempoChanged
>;

using UIEvent = std::variant<
    Events::FeatureUnlocked,
    Events::SuggestionShown,
    Events::SuggestionAccepted
>;

using SystemEvent = std::variant<
    Events::SessionStarted,
    Events::SessionEnded,
    Events::SnapshotCreated
>;

using AnyEvent = std::variant<BioEvent, MusicEvent, UIEvent, SystemEvent>;

//==============================================================================
// TYPE-SAFE VISITOR PATTERN
//==============================================================================

template<typename... Fs>
struct Overload : Fs... { using Fs::operator()...; };

template<typename... Fs>
Overload(Fs...) -> Overload<Fs...>;

// Usage: std::visit(Overload{...}, variant)

//==============================================================================
// EXAMPLE USAGE
//==============================================================================

/*
// Type-safe units - can't accidentally mix BPM and Hz
void setTempo(BPM tempo);        // Only accepts BPM
void setSampleRate(Hz rate);     // Only accepts Hz

setTempo(120.0_bpm);             // ✅ Works
setTempo(44100.0_hz);            // ❌ Compile error!

// Bounded types - invalid values impossible
auto velocity = MIDIVelocity::make(150);  // Returns std::nullopt
auto velocity = MIDIVelocity::clamp(150); // Returns MIDIVelocity(127)

// Discriminated unions - exhaustive matching
std::visit(Overload{
    [](const PlayState::Stopped&) { showStopButton(); },
    [](const PlayState::Playing& p) { showPosition(p.position); },
    [](const PlayState::Paused& p) { showPausedAt(p.position); },
    [](const PlayState::Recording& r) { showRecording(r.position); }
}, playbackState);

// Result type - explicit error handling
Result<Session, std::string> loadSession(const std::string& path);

loadSession("project.ech")
    .map([](auto& s) { return s.name; })
    .match(
        [](const std::string& name) { showSession(name); },
        [](const std::string& err) { showError(err); }
    );

// Builder with required fields
auto session = SessionBuilder<NoKey, NoTempo>{}
    .withKey(*MIDINoteNumber::make(60))
    .withTempo(120.0_bpm)
    .withName("My Song")
    .build();  // Only compiles if withKey AND withTempo called
*/

} // namespace Types
} // namespace Echoel

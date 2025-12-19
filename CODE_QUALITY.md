# Code Quality Standards for Echoelmusic

## 📋 Overview

This document defines the code quality standards, tools, and practices for the Echoelmusic project. Following these standards ensures consistent, maintainable, and production-ready code across Swift and C++ codebases.

## 🎯 Goals

1. **Consistency**: Uniform code style across all files and contributors
2. **Quality**: Catch bugs and antipatterns before they reach production
3. **Performance**: Maintain audio-grade performance requirements
4. **Security**: Prevent common vulnerabilities and security issues
5. **Maintainability**: Write code that's easy to understand and modify

## 🛠️ Tools

### Swift Tools

#### SwiftLint
**Purpose**: Static analysis and style enforcement for Swift code

**Configuration**: `.swiftlint.yml`

**Key Rules**:
- Line length: 120 characters (warning), 200 (error)
- Function body length: 60 lines (warning), 100 (error)
- Type body length: 300 lines (warning), 500 (error)
- Cyclomatic complexity: 15 (warning), 25 (error)
- Force unwrapping: Warning (not error, for development flexibility)
- Missing docs: Public declarations must be documented

**Custom Rules**:
- `no_print`: Use Logger instead of `print()`
- `no_force_cast`: Use safe casting (`as?` or `guard let`)
- `todo_with_ticket`: TODOs must reference tickets
- `swiftui_preview`: Views should include PreviewProvider

**Usage**:
```bash
# Lint all files
swiftlint lint

# Strict mode (warnings as errors)
swiftlint lint --strict

# Auto-fix violations
swiftlint autocorrect

# Lint specific path
swiftlint lint --path Sources/Echoelmusic/DSP

# Generate HTML report
swiftlint lint --reporter html > swiftlint-report.html
```

#### swift-format
**Purpose**: Automatic code formatting

**Configuration**: `.swift-format`

**Key Settings**:
- Line length: 120 characters
- Indentation: 4 spaces
- Maximum blank lines: 2
- All public declarations must have documentation

**Usage**:
```bash
# Check formatting
swift-format lint --recursive Sources/

# Auto-format
swift-format format --in-place --recursive Sources/

# Format specific file
swift-format format --in-place Sources/DSP/AdvancedDSPEffects.swift
```

### C++ Tools

#### clang-tidy
**Purpose**: Static analysis for C++ code

**Configuration**: `.clang-tidy`

**Enabled Check Groups**:
- `bugprone-*`: Detect common bugs
- `cert-*`: CERT secure coding guidelines
- `clang-analyzer-*`: Deep static analysis
- `cppcoreguidelines-*`: C++ Core Guidelines
- `hicpp-*`: High Integrity C++ guidelines
- `modernize-*`: C++11/17 best practices
- `performance-*`: Performance optimizations
- `readability-*`: Code readability

**Relaxed Rules for DSP Code**:
- Magic numbers allowed (audio constants like 44100, 48000)
- Single-letter variables allowed (x, y, z for math)
- Pointer arithmetic allowed (SIMD operations)
- C arrays allowed (fixed-size audio buffers)

**Usage**:
```bash
# Analyze specific file
clang-tidy Sources/DSP/BioReactiveDSP.cpp -- -std=c++17

# Analyze all DSP files
find Sources/DSP -name "*.cpp" -exec clang-tidy {} -- -std=c++17 \;

# Auto-fix issues
clang-tidy --fix Sources/DSP/Compressor.cpp -- -std=c++17
```

#### clang-format
**Purpose**: Automatic code formatting for C++

**Configuration**: `.clang-format`

**Key Settings**:
- Line length: 120 characters
- Indentation: 4 spaces
- Brace style: K&R (compact for DSP loops)
- Pointer alignment: Left (`int* ptr`)
- Include sorting: Enabled

**Usage**:
```bash
# Check formatting
clang-format --dry-run --Werror Sources/DSP/OptoCompressor.cpp

# Auto-format
clang-format -i Sources/DSP/OptoCompressor.cpp

# Format all C++ files
find Sources/DSP -name "*.cpp" -o -name "*.h" | xargs clang-format -i
```

## 📐 Coding Standards

### Swift Standards

#### Naming Conventions

**Types**: `CamelCase`
```swift
class AudioEngine { }
struct BioMetrics { }
enum ProcessingMode { }
```

**Functions and Variables**: `camelCase`
```swift
func processAudioBuffer() { }
var sampleRate: Double
let bufferSize: Int
```

**Constants**: `kCamelCase`
```swift
let kDefaultSampleRate = 44100.0
let kMaxBufferSize = 4096
```

**Private Properties**: No prefix
```swift
private var audioEngine: AudioEngine
```

#### Code Organization

Use MARK comments to organize code:
```swift
// MARK: - Lifecycle

override func viewDidLoad() { }

// MARK: - Audio Processing

func processBuffer() { }

// MARK: - HealthKit Integration

func fetchHeartRate() { }
```

#### Documentation

All public APIs must be documented:
```swift
/// Processes audio buffer with bio-reactive modulation
///
/// - Parameters:
///   - buffer: The audio buffer to process
///   - heartRate: Current heart rate in BPM
/// - Returns: Processed audio buffer
/// - Throws: `AudioError` if processing fails
func processWithBioReactivity(
    buffer: AVAudioPCMBuffer,
    heartRate: Double
) throws -> AVAudioPCMBuffer {
    // Implementation
}
```

#### SwiftUI Best Practices

1. **Extract subviews** when body exceeds ~20 lines
2. **Use @State properly** (only for view-local state)
3. **Prefer @StateObject** over @ObservedObject for ownership
4. **Include PreviewProvider** for all views

```swift
struct WaveformView: View {
    @StateObject private var audioEngine = AudioEngine()
    @State private var amplitude: Double = 0.0

    var body: some View {
        // Keep body concise
    }
}

struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        WaveformView()
    }
}
```

### C++ Standards

#### Naming Conventions

**Types**: `CamelCase`
```cpp
class BioReactiveDSP { };
struct FilterCoefficients { };
enum ProcessingMode { };
```

**Functions**: `camelCase`
```cpp
void processAudioBuffer() { }
float calculateFilterCoefficient(float frequency);
```

**Variables**: `camelCase`
```cpp
float sampleRate = 44100.0f;
int bufferSize = 512;
```

**Constants**: `kCamelCase`
```cpp
constexpr int kDefaultBufferSize = 512;
constexpr float kNyquistFactor = 0.5f;
```

**Member Variables**: `camelCase` (no prefix)
```cpp
class Compressor {
private:
    float threshold;
    float ratio;
    float attackTime;
};
```

#### Memory Management

**Prefer RAII** (Resource Acquisition Is Initialization):
```cpp
// Good
std::unique_ptr<float[]> buffer(new float[size]);

// Better
std::vector<float> buffer(size);

// Avoid raw pointers for ownership
float* buffer = new float[size];  // ❌ Manual management
```

**SIMD Code Exception**: Raw pointers OK for performance:
```cpp
// OK for SIMD operations
void processSIMD(const float* input, float* output, int numSamples) {
    __m256 vecData = _mm256_loadu_ps(input);
    // SIMD processing...
}
```

#### Error Handling

**Use exceptions for exceptional cases**:
```cpp
if (sampleRate <= 0) {
    throw std::invalid_argument("Sample rate must be positive");
}
```

**Use return codes for expected failures**:
```cpp
bool tryAllocateBuffer(int size) {
    if (size > maxSize) return false;
    // Allocate...
    return true;
}
```

#### Performance Best Practices

1. **Mark const what can be const**:
```cpp
void process(const float* input, float* output, int numSamples) const;
```

2. **Pass by const reference for large objects**:
```cpp
void applyFilter(const FilterCoefficients& coeffs);
```

3. **Use inline for hot code paths**:
```cpp
inline float fastAbs(float x) {
    int i = *(int*)&x;
    i &= 0x7FFFFFFF;
    return *(float*)&i;
}
```

4. **Prefer stack allocation** for small buffers:
```cpp
float tempBuffer[256];  // Stack allocation (fast)
```

## 🔒 Security Standards

### Common Vulnerabilities to Avoid

#### 1. Hardcoded Credentials
```swift
// ❌ BAD
let apiKey = "sk_live_abc123def456"

// ✅ GOOD
let apiKey = ProcessInfo.processInfo.environment["API_KEY"]
```

#### 2. Force Unwrapping
```swift
// ❌ BAD (can crash)
let value = dictionary["key"]!

// ✅ GOOD
guard let value = dictionary["key"] else {
    log.error("Missing required key")
    return
}
```

#### 3. Insecure C Functions
```cpp
// ❌ BAD (buffer overflow risk)
char buffer[100];
strcpy(buffer, userInput);

// ✅ GOOD
char buffer[100];
strncpy(buffer, userInput, sizeof(buffer) - 1);
buffer[sizeof(buffer) - 1] = '\0';

// ✅ BETTER
std::string buffer = userInput;
```

#### 4. Integer Overflow
```cpp
// ❌ BAD (can overflow)
int bufferSize = userSize * sizeof(float);

// ✅ GOOD
if (userSize > INT_MAX / sizeof(float)) {
    throw std::overflow_error("Buffer size too large");
}
int bufferSize = userSize * sizeof(float);
```

### Security Checklist

- [ ] No hardcoded credentials (API keys, passwords, tokens)
- [ ] No force unwrapping in production code paths
- [ ] No insecure C functions (strcpy, sprintf, gets)
- [ ] Input validation for all user-provided data
- [ ] Bounds checking for array access
- [ ] Integer overflow protection
- [ ] Proper error handling (no swallowed exceptions)
- [ ] Secure random number generation (not rand())
- [ ] HTTPS for all network requests
- [ ] Data sanitization before logging

## 🚀 CI/CD Integration

### Automated Checks

All PRs must pass these checks:

1. **SwiftLint** (BLOCKING)
   - All warnings must be fixed
   - Custom rules must pass
   - Runs on every push

2. **swift-format** (BLOCKING)
   - Code must be properly formatted
   - Use `swift-format format --in-place` to fix

3. **clang-tidy** (WARNING)
   - C++ static analysis
   - Currently warning-only
   - Will become blocking in future

4. **clang-format** (WARNING)
   - C++ formatting check
   - Currently warning-only
   - Will become blocking in future

5. **Security Scan** (BLOCKING)
   - Checks for hardcoded credentials
   - Scans for insecure functions
   - Detects force unwrapping

6. **Performance Tests** (BLOCKING)
   - Validates 43-68% CPU reduction
   - Prevents performance regressions
   - See [PERFORMANCE_TESTING.md](Tests/PERFORMANCE_TESTING.md)

### Local Pre-commit Checks

Run these before committing:

```bash
# Swift linting
swiftlint lint --strict

# Swift formatting
swift-format lint --recursive Sources/

# C++ linting (if applicable)
find Sources/DSP -name "*.cpp" -exec clang-tidy {} -- -std=c++17 \;

# C++ formatting (if applicable)
find Sources/DSP -name "*.cpp" -o -name "*.h" | xargs clang-format --dry-run --Werror

# Run tests
xcodebuild test -scheme Echoelmusic
```

### Fixing Violations

#### SwiftLint Violations

```bash
# Auto-fix what can be fixed
swiftlint autocorrect

# Review remaining issues
swiftlint lint

# Fix manually or add exceptions
// swiftlint:disable force_unwrapping
let value = dict["key"]!
// swiftlint:enable force_unwrapping
```

#### Formatting Violations

```bash
# Auto-format Swift
swift-format format --in-place --recursive Sources/

# Auto-format C++
find Sources/DSP -name "*.cpp" -o -name "*.h" | xargs clang-format -i
```

## 📊 Metrics

### Code Quality Metrics

Track these metrics:

- **SwiftLint Warnings**: Target 0
- **Force Unwrapping Count**: Minimize
- **Test Coverage**: Target 80%+
- **Function Complexity**: Keep < 15
- **File Length**: Keep < 500 lines
- **Documentation Coverage**: 100% for public APIs

### Performance Metrics

See [PERFORMANCE_TESTING.md](Tests/PERFORMANCE_TESTING.md) for:
- CPU usage targets
- Memory allocation limits
- Latency requirements
- Throughput benchmarks

## 🎓 Best Practices

### General

1. **Write self-documenting code**: Clear names over comments
2. **Keep functions small**: Single responsibility principle
3. **Avoid premature optimization**: Profile first
4. **Test your code**: Unit tests for business logic
5. **Handle errors gracefully**: No silent failures
6. **Log appropriately**: Use structured logging
7. **Review your own code**: Before requesting review

### Audio-Specific

1. **Avoid allocations in audio thread**: Prepare buffers upfront
2. **Use SIMD when possible**: 2-8x performance gains
3. **Profile on real devices**: Simulators don't represent performance
4. **Test with various buffer sizes**: 64, 128, 256, 512, 1024 samples
5. **Measure latency**: Audio apps need < 10ms total latency
6. **Handle denormals**: Can cause severe CPU spikes
7. **Use atomic operations**: For lock-free audio thread communication

### SwiftUI

1. **Minimize state changes**: Redraws are expensive
2. **Use Instruments**: Profile UI performance
3. **Lazy load views**: Use `LazyVStack`/`LazyHStack`
4. **Optimize images**: Use appropriate resolutions
5. **Debounce user input**: Don't update on every keystroke

## 🔧 Tooling Setup

### macOS

```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Swift tools
brew install swiftlint swift-format

# Install C++ tools
brew install llvm

# Add LLVM to PATH (add to ~/.zshrc or ~/.bash_profile)
export PATH="/usr/local/opt/llvm/bin:$PATH"

# Verify installations
swiftlint version
swift-format --version
clang-tidy --version
clang-format --version
```

### Xcode Integration

#### SwiftLint

Add a "Run Script" build phase:
```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

#### swift-format

Add a "Run Script" build phase:
```bash
if which swift-format >/dev/null; then
  swift-format lint --recursive Sources/
else
  echo "warning: swift-format not installed"
fi
```

### VS Code Integration

Install extensions:
- Swift for VS Code
- SwiftLint
- C/C++
- clangd

`.vscode/settings.json`:
```json
{
  "swift.linter.swiftlint.enable": true,
  "swift.format.enable": true,
  "C_Cpp.clang_format_style": "file",
  "editor.formatOnSave": true
}
```

## 📚 Resources

### Swift

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [Swift Documentation](https://swift.org/documentation/)

### C++

- [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
- [clang-tidy Checks](https://clang.llvm.org/extra/clang-tidy/checks/list.html)
- [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html)

### Audio Development

- [JUCE Best Practices](https://docs.juce.com/master/tutorial_audio_performance.html)
- [IPlug2 Documentation](https://iplug2.github.io/)
- [Apple Core Audio](https://developer.apple.com/documentation/coreaudio)

## 🤝 Contributing

When submitting code:

1. **Run all linters locally** before pushing
2. **Fix all SwiftLint warnings** (use `autocorrect`)
3. **Format code** with swift-format and clang-format
4. **Add tests** for new features
5. **Update documentation** for API changes
6. **Check performance** if touching DSP code
7. **Review security** if handling user data

## ❓ FAQ

**Q: Why is SwiftLint blocking but clang-tidy only warning?**
A: SwiftLint rules are well-established for the Swift codebase. clang-tidy is being phased in gradually for C++ code.

**Q: Can I disable a rule for a specific file?**
A: Yes, but document why:
```swift
// swiftlint:disable force_unwrapping
// REASON: Dictionary is guaranteed to contain key from enum
let value = config[.sampleRate]!
// swiftlint:enable force_unwrapping
```

**Q: What if a rule conflicts with audio performance requirements?**
A: Document the exception and add it to the configuration. Audio performance is priority #1.

**Q: How strict should code reviews be?**
A: Linters catch style issues. Reviews focus on:
- Correctness
- Performance
- Security
- API design
- Test coverage

---

**Last Updated**: 2025-12-15
**Version**: 1.0.0
**Maintainers**: Echoelmusic Team

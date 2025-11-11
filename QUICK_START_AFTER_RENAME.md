# 🚀 Echoelmusic Quick Start Guide

**Post-Rename Developer Workflow & Setup**

---

## 📋 Table of Contents

1. [Development Setup](#development-setup)
2. [Repository Clone](#repository-clone)
3. [Common Tasks](#common-tasks)
4. [Testing](#testing)
5. [Building](#building)
6. [Git Workflow](#git-workflow)
7. [Troubleshooting](#troubleshooting)

---

## 🛠️ Development Setup

### **Requirements**

| Tool | Minimum Version | Recommended | Installation |
|------|----------------|-------------|--------------|
| **Xcode** | 15.0+ | 15.4+ | App Store or developer.apple.com |
| **Swift** | 5.9+ | 5.10+ | Included with Xcode |
| **iOS Target** | 15.0+ | 17.0+ | Xcode Settings |
| **macOS** | 13.0 Ventura+ | 14.0 Sonoma+ | System Preferences |
| **Git** | 2.30+ | 2.40+ | `brew install git` |

---

### **Quick Setup (5 Minutes)**

```bash
# 1. Clone repository
git clone https://github.com/vibrationalforce/echoelmusic.git
cd echoelmusic

# 2. Open in Xcode
open Package.swift
# OR
open Echoelmusic.xcodeproj  # If using Xcode project

# 3. Select target device
# Xcode → Select "Echoelmusic" scheme → Choose iPhone simulator or physical device

# 4. Build and run
# Xcode → Product → Run (⌘R)
```

**Expected Result:**
- App launches in simulator
- You see the main Echoelmusic interface
- No build errors

---

## 📥 Repository Clone

### **HTTPS (Recommended)**

```bash
git clone https://github.com/vibrationalforce/echoelmusic.git
cd echoelmusic
```

### **SSH (If you have SSH keys configured)**

```bash
git clone git@github.com:vibrationalforce/echoelmusic.git
cd echoelmusic
```

### **Verify Clone**

```bash
# Check remote URL
git remote -v
# Should show:
# origin  https://github.com/vibrationalforce/echoelmusic.git (fetch)
# origin  https://github.com/vibrationalforce/echoelmusic.git (push)

# Check branch
git branch
# Should show:
# * main

# Check files
ls -la
# Should see: Package.swift, Sources/, Tests/, README.md, etc.
```

---

## ✅ Common Tasks

### **1. Create a Feature Branch**

```bash
# Always branch from main
git checkout main
git pull origin main

# Create feature branch (use descriptive names)
git checkout -b feature/add-new-visualization-mode

# Verify you're on the new branch
git branch
# Should show: * feature/add-new-visualization-mode
```

**Branch Naming Conventions:**
- `feature/description` - New features
- `fix/description` - Bug fixes
- `refactor/description` - Code refactoring
- `docs/description` - Documentation updates
- `test/description` - Test additions
- `perf/description` - Performance improvements

---

### **2. Make Changes**

```swift
// Example: Add a new visualization mode
// File: Sources/Echoelmusic/Visual/VisualizationMode.swift

enum VisualizationMode: String, CaseIterable {
    case particles = "Particles"
    case cymatics = "Cymatics"
    case waveform = "Waveform"
    case spectral = "Spectral"
    case mandala = "Mandala"
    case myNewMode = "My New Mode"  // ← Your addition
}
```

---

### **3. Run Tests**

```bash
# Run all tests
swift test

# OR in Xcode
# Product → Test (⌘U)

# Run specific test
swift test --filter UnifiedControlHubTests

# Run with coverage
swift test --enable-code-coverage
```

**Expected Output:**
```
Test Suite 'All tests' started at 2025-11-11 08:00:00.000
Test Suite 'EchoelmusicTests' started at 2025-11-11 08:00:00.000
Test Case '-[EchoelmusicTests.PitchDetectorTests testYINAlgorithm]' started.
Test Case '-[EchoelmusicTests.PitchDetectorTests testYINAlgorithm]' passed (0.123 seconds).
...
Test Suite 'EchoelmusicTests' passed at 2025-11-11 08:00:05.000.
     Executed 24 tests, with 0 failures (0 unexpected) in 5.234 (5.234) seconds
```

---

### **4. Build for Release**

```bash
# Build in Release configuration
swift build -c release

# OR in Xcode
# Product → Scheme → Edit Scheme → Run → Build Configuration → Release
# Product → Build (⌘B)
```

---

### **5. Format Code (SwiftLint)**

```bash
# Check for linting issues
swiftlint lint

# Auto-fix issues (where possible)
swiftlint lint --fix

# Lint specific file
swiftlint lint --path Sources/Echoelmusic/Audio/AudioEngine.swift
```

**Common SwiftLint Rules:**
- Line length ≤120 characters
- Force unwrapping (`!`) discouraged
- Sorted imports
- MARK comments for organization

---

### **6. Commit Changes**

```bash
# Check status
git status

# Stage changes
git add Sources/Echoelmusic/Visual/VisualizationMode.swift

# Commit with descriptive message
git commit -m "feat: Add MyNewMode visualization

- Implement MyNewMode enum case
- Add icon and description
- Update VisualizationModePicker UI
- Add unit tests for new mode"

# Push to remote
git push origin feature/add-new-visualization-mode
```

**Commit Message Format:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `style:` Formatting
- `refactor:` Code restructuring
- `test:` Adding tests
- `perf:` Performance improvement
- `chore:` Maintenance

---

### **7. Create Pull Request**

```bash
# Open GitHub in browser
open https://github.com/vibrationalforce/echoelmusic/pull/new/feature/add-new-visualization-mode

# OR use GitHub CLI
gh pr create --title "Add MyNewMode visualization" --body "Description of changes"
```

**PR Checklist:**
- [ ] Code builds without errors
- [ ] All tests pass
- [ ] SwiftLint passes
- [ ] Documentation updated (if needed)
- [ ] Screenshots added (for UI changes)
- [ ] Performance tested (for performance-sensitive code)

---

## 🧪 Testing

### **Unit Tests**

```bash
# Run all unit tests
swift test

# Run specific test suite
swift test --filter EchoelmusicTests

# Run specific test case
swift test --filter EchoelmusicTests.PitchDetectorTests
```

---

### **Performance Tests**

```swift
// Example: Measure HRV calculation performance
// File: Tests/EchoelmusicTests/HealthKitManagerPerformanceTests.swift

func testHRVCalculationPerformance() {
    let healthKit = HealthKitManager()
    let samples = generateMockHRVSamples(count: 1000)

    measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
        let hrv = healthKit.calculateHRVCoherence(from: samples)
        XCTAssertGreaterThan(hrv, 0)
    }
}
```

**Run Performance Tests:**
```bash
swift test --filter PerformanceTests
```

**Expected Benchmarks:**
- HRV calculation: <5ms for 1000 samples
- FFT (4096 points): <1ms
- Gesture recognition: <10ms per frame

---

### **Integration Tests**

```bash
# Run integration tests (if separated)
swift test --filter IntegrationTests
```

---

## 🏗️ Building

### **Debug Build**

```bash
# Build for debugging (includes symbols, no optimizations)
swift build -c debug

# OR in Xcode
# Product → Build for → Running (⌘B)
```

**Output:** `.build/debug/Echoelmusic`

---

### **Release Build**

```bash
# Build for release (optimized, stripped symbols)
swift build -c release

# OR in Xcode
# Product → Build for → Profiling (⌘⌥B)
```

**Output:** `.build/release/Echoelmusic`

**Optimizations Enabled:**
- `-O` (Whole Module Optimization)
- Dead code elimination
- Inlining

---

### **Archive for App Store**

```bash
# In Xcode only (not via command line)
# 1. Product → Archive
# 2. Organizer opens automatically
# 3. Select archive → Distribute App → App Store Connect
# 4. Follow upload wizard
```

---

## 🔄 Git Workflow

### **Daily Workflow**

```bash
# Morning: Start fresh
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/my-feature

# Work on feature (commit frequently)
git add .
git commit -m "feat: Add feature part 1"

# Push to remote (backs up your work)
git push origin feature/my-feature

# End of day: Push final changes
git add .
git commit -m "feat: Complete feature implementation"
git push origin feature/my-feature
```

---

### **Syncing with Main**

```bash
# Your feature branch is behind main? Rebase!
git checkout main
git pull origin main

git checkout feature/my-feature
git rebase main

# If conflicts occur:
# 1. Resolve conflicts in files
# 2. git add <resolved-files>
# 3. git rebase --continue

# Force push (rebase rewrites history)
git push origin feature/my-feature --force-with-lease
```

---

### **Merging a Pull Request**

```bash
# After PR approval, merge via GitHub web interface
# OR via command line:

git checkout main
git pull origin main

git merge feature/my-feature --no-ff
git push origin main

# Delete feature branch (cleanup)
git branch -d feature/my-feature
git push origin --delete feature/my-feature
```

---

## 🐛 Troubleshooting

### **Issue: Build Fails with "Module Not Found"**

**Solution:**
```bash
# Clean build folder
rm -rf .build/

# Clean derived data (Xcode)
# Xcode → Product → Clean Build Folder (⌘⌥⇧K)

# Rebuild
swift build
```

---

### **Issue: Git Remote URL is Wrong**

**Symptom:**
```bash
git push
# fatal: repository 'https://github.com/old-name/blab.git' not found
```

**Solution:**
```bash
# Check current remote
git remote -v

# Update remote URL
git remote set-url origin https://github.com/vibrationalforce/echoelmusic.git

# Verify
git remote -v
```

---

### **Issue: SwiftLint Errors**

**Symptom:**
```
error: Line Length Violation: Line should be 120 characters or less
```

**Solution:**
```bash
# Auto-fix (where possible)
swiftlint lint --fix

# Manually fix remaining issues
# Break long lines into multiple lines
```

---

### **Issue: Tests Fail on CI but Pass Locally**

**Possible Causes:**
1. Different Xcode versions
2. Missing dependencies
3. Hardcoded paths

**Solution:**
```bash
# Match CI environment
# Check .github/workflows/ci.yml for Xcode version

# Run tests in same configuration as CI
swift test --configuration release
```

---

### **Issue: Xcode Indexing Stuck**

**Solution:**
```bash
# Delete derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Restart Xcode
killall Xcode
open Package.swift
```

---

### **Issue: HealthKit Authorization Not Working in Simulator**

**Solution:**
- HealthKit requires a physical device (iPhone/Apple Watch)
- Simulators do not support HealthKit
- Use a real device for testing bio-feedback features

---

### **Issue: Metal Shaders Not Compiling**

**Solution:**
```bash
# Check Metal file syntax
# File: Sources/Echoelmusic/Visual/Shaders/ChromaKey.metal

# Ensure Metal is enabled in Build Settings
# Xcode → Target → Build Settings → Metal Compiler Options
```

---

## 📚 Additional Resources

### **Documentation**
- [README.md](README.md) - Project overview
- [XCODE_HANDOFF.md](XCODE_HANDOFF.md) - Xcode development guide
- [PERFORMANCE_OPTIMIZATION_GUIDE.md](PERFORMANCE_OPTIMIZATION_GUIDE.md) - Performance best practices
- [BLUE_ZONES_LONGEVITY_RESEARCH.md](BLUE_ZONES_LONGEVITY_RESEARCH.md) - Wellness research
- [PRIVACY_POLICY.md](PRIVACY_POLICY.md) - Privacy policy

### **Code Examples**
- `Sources/Echoelmusic/Audio/AudioEngine.swift` - Audio engine setup
- `Sources/Echoelmusic/Unified/UnifiedControlHub.swift` - Input orchestration
- `Sources/Echoelmusic/Biofeedback/HealthKitManager.swift` - HealthKit integration

### **External Links**
- [Swift.org](https://swift.org/documentation/) - Swift documentation
- [Apple Developer](https://developer.apple.com) - iOS development guides
- [GitHub Docs](https://docs.github.com) - Git and GitHub help

---

## 🎯 Quick Reference

### **Essential Commands**

```bash
# Build
swift build

# Test
swift test

# Run (simulator)
# Use Xcode: Product → Run (⌘R)

# Clean
rm -rf .build/
# OR: Xcode → Product → Clean Build Folder (⌘⌥⇧K)

# Git basics
git status              # Check status
git add <file>          # Stage file
git commit -m "message" # Commit
git push                # Push to remote
git pull                # Pull from remote

# SwiftLint
swiftlint lint          # Check issues
swiftlint lint --fix    # Auto-fix
```

---

### **File Structure**

```
Echoelmusic/
├── Sources/
│   └── Echoelmusic/
│       ├── EchoelmusicApp.swift       # App entry point
│       ├── ContentView.swift          # Main UI
│       ├── Audio/                     # Audio subsystem
│       ├── Spatial/                   # Spatial audio
│       ├── Visual/                    # Visualizations
│       ├── Biofeedback/               # HealthKit
│       ├── Unified/                   # Control hub
│       ├── LED/                       # LED control
│       ├── MIDI/                      # MIDI system
│       ├── Recording/                 # Recording engine
│       ├── Gamification/              # Achievements
│       ├── Chroma/                    # Chroma key
│       └── Video/                     # Color engine
├── Tests/
│   └── EchoelmusicTests/              # Unit tests
├── Package.swift                       # Swift package manifest
├── README.md                           # Project overview
└── .swiftlint.yml                      # SwiftLint config
```

---

## ✅ Checklist for New Contributors

- [ ] Clone repository successfully
- [ ] Open project in Xcode
- [ ] Build succeeds (⌘B)
- [ ] All tests pass (⌘U)
- [ ] SwiftLint passes
- [ ] Create feature branch
- [ ] Make a small change (e.g., fix a typo in README)
- [ ] Commit and push
- [ ] Open a practice pull request
- [ ] Read main documentation files

---

## 🎉 You're Ready!

You've completed the quick start guide. You should now be able to:
- ✅ Clone and build Echoelmusic
- ✅ Run tests
- ✅ Create feature branches
- ✅ Commit and push changes
- ✅ Open pull requests

**Happy coding!** 🎵

---

**Questions?**
- Open an issue: https://github.com/vibrationalforce/echoelmusic/issues
- Contact: dev@echoelmusic.com

**Last Updated:** 2025-11-11
**Version:** 1.0

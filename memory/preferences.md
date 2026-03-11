# Preferences

User preferences for development workflow, communication, and tooling.

## Development Style
- **Protocol:** Ralph Wiggum Lambda -- one fix per cycle, no batching
- **Commits:** Conventional commits (feat:, fix:, docs:, etc.)
- **Testing:** TDD when adding new functionality
- **Logging:** os_log only, never print()
- **Concurrency:** Swift 6 strict concurrency, async/await + @MainActor

## Communication
- **Tone:** Direct, no filler, no emojis unless requested
- **Science only:** No esoteric terminology, evidence-based claims only
- **Branding:** "Echoelmusic" -- never "BLAB" or "Vibrational Force"

## Tooling
- **CI:** GitHub Actions (testflight.yml primary)
- **Build:** Tuist + Fastlane + Codemagic
- **Dependencies:** Zero external dependencies policy
- **SDK Target:** iOS 26 (deadline April 28, 2026)

## Session Workflow
- Read scratchpads/SESSION_LOG.md and memory/ at session start
- Update memory/ at session end with new discoveries
- 4-phase workflow: Plan -> Implement (TDD) -> Verify -> Ship

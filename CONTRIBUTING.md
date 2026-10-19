# Contributing to Echoelmusic

Thank you for looking. This file says how the repository is laid out, how to build and
test each half, what a contribution needs, and what we will not merge. It is short on
purpose; the detailed engineering law lives next to the code (`CLAUDE.md`,
`EchoelStudio/CLAUDE.md`, `.claude/rules/`).

## Two codebases, one licence

| | Path | Build and test |
|---|---|---|
| **Echoel Studio** (the workstation, new) | `EchoelStudio/` — packages `Core/`, `DSP/`, `Engine/`; app in `App/`; Audio Unit extension in `Plugins/` | `swift test --package-path EchoelStudio/Core` (same for `DSP`, `Engine`); app: `xcodegen generate --spec EchoelStudio/project.yml`, then build the `EchoelStudio` scheme in Xcode 26 |
| **Echoelmusic** (the legacy bio-reactive instrument) | `Sources/Echoelmusic/`, tests in `Tests/` | `xcodegen generate` at the root, then Xcode; the blocking guards are `Tests/CISmoke` (read `Tests/CISmoke/CLAUDE.md` before adding one) |

Everything is MIT (`LICENSE`). By contributing you agree that your contribution is
licensed the same way (inbound = outbound). The packages are where contributions help
most: they are pure Swift, have no dependencies, and their tests run with `swift test`
on a Mac today; a Linux run is planned and not yet measured.

## Before you open a pull request

1. **One change per pull request**, described in the commit body: what changed and
   *why* (the architectural reason, not only the symptom). Conventional prefixes:
   `feat:`, `fix:`, `test:`, `refactor:`, `docs:`, `chore:`, `perf:`.
2. **Tests test behaviour.** Add or extend a test for what you changed. In
   `EchoelStudio/` a test never reads source text or prose.
3. **No new dependencies.** The packages and the apps ship zero third-party code; a
   proposal to add one is a discussion first, not a pull request.
4. **Audio thread rules are absolute** (`.claude/rules/swift-audio.md`): no allocation,
   no locks, no Objective-C, no I/O, no dispatch in any render path.
5. **No force unwraps, no `print()`**, `os_log` only, Swift 6 strict concurrency.
6. **Copy that reaches users** (app, website in `docs/`, store text) claims only what
   ships — `ContentPipeline/CLAIMS.md` is the list — and never uses wellness, healing
   or esoteric framing. Physiology here is a modulation source for an instrument, not a
   health product.
7. **Protected code:** `BioEventGraph`, `HilbertSensorMapper` and `BioSignalDeconvolver`
   (`Sources/Echoelmusic/Bio/`) are not simplified or rewritten without the maintainer's
   explicit agreement.

## How this repository is developed

The maintainer develops with AI assistance under human review: architecture, scope,
tests and every change are decided and taken responsibility for by a person; the
commit trailers say when a model helped write a change. If you use the same kind of
tooling, say so in your commit the same way, and review what you submit as if you had
typed it — you are its author.

## Reporting a bug

Use the issue template. **Do not paste the app's diagnostics text into a public
issue:** it contains heart-rate values from the session it was shared from. Describe the
steps and the build number instead; the maintainer will ask for the log privately if
it is needed.

## Security

Vulnerabilities go to the contact in `SECURITY.md`, not into a public issue.

## Questions

Open an issue with the `question` label, or write to the address in `SECURITY.md`.

# Cross-platform path for a Swift-only Apple music workstation and its instrument plugins (after Apple: Windows, Linux, Android, Web) — status as of 2026-10-19

Method note: licence statements below were read from the licence files themselves (downloaded from `raw.githubusercontent.com` on 2026-10-19) unless marked otherwise. Several primary hosts could not be reached from this sandbox (cleveraudio.org, en.wikipedia.org, developer.avid.com, librearts.org: DNS or proxy refusal). Where a claim depends on those, it is marked UNVERIFIED or rests on secondary sources, and the source type is named. No social-media-clip URLs and no zazencodes.com were used.

## 1. Plugin formats: licence, host adoption 2025–2026, widest reach for the least licence risk

### Takeaway
Since **VST 3.8 (29 Oct 2025) the VST3 SDK is MIT-only**. GPLv3 and the Steinberg proprietary agreement are both gone, so a closed-source VST3 needs no signed agreement any more. **CLAP is MIT** and has been a pure C ABI since 2022. Together they are the widest-reach, lowest-licence-risk pair outside Apple. VST3 is what Cubase, Ableton Live and Studio One load. CLAP is native in Bitwig, REAPER, FL Studio (2024) and reportedly Studio One 7. LV2 (ISC) adds Linux hosts. **AAX is the only format with real gatekeeping**: PACE/iLok signing, an NDA and Avid's own SDK terms.

### Cited Findings
**VST3**
- The current `LICENSE.txt` in the official repo is the plain MIT text, "Copyright (c) 2026, Steinberg Media Technologies GmbH". — [vst3sdk LICENSE.txt](https://github.com/steinbergmedia/vst3sdk/blob/master/LICENSE.txt)
- The repo README says verbatim: "**VST 3 SDK** is under MIT license" and "Licensing under **GPLv3** and the **Steinberg proprietary license** is no longer available." It continues: "Code licensed under MIT license can be used, modified, and redistributed freely — including in commercial products". — [vst3sdk README §License & Usage guidelines](https://github.com/steinbergmedia/vst3sdk/blob/master/README.md)
- Trademark: under the README, using the "VST" name or logo "is optional under MIT license, but if used, must comply with Steinberg's official trademark rules"; non-compliance "does not affect your MIT rights (but may result in trademark violations)". — [vst3sdk README](https://github.com/steinbergmedia/vst3sdk/blob/master/README.md)
- Date: Steinberg's press release is dated **2025-10-29** ("VST 3.8"). Coverage says VST 3.8 moved the SDK to MIT and also improved MIDI 2.0 support. ASIO was relicensed at the same time, with GPLv3 offered as an option. — [Steinberg press release PDF 2025-10-29](https://ocl-steinberg-live.steinberg.net/_storage/asset/819253/storage/master/Press%20Release%20-%202025-10-29%20-%20VST%203.8%20-%20EN.pdf); [Sonicstate 2025-10-30](https://sonicstate.com/news/2025/10/30/vst-3-now-available-under-mit-license)
- Before that the SDK was dual-licensed, GPLv3 or the proprietary Steinberg agreement. CDM notes the change "has been updated from GPLv3 to a more permissive MIT license". — [CDM](https://cdm.link/open-steinberg-vst3-and-asio/)
- JUCE 8.0.11 (Dec 2025) switched its bundled VST3 SDK to MIT. — [KVR: JUCE 8.0.11](https://www.kvraudio.com/news/juce-8-0-11-now-available-65579)
- The SDK's own build uses **CMake** (`cmake.exe -G "Visual Studio 17 2022" ...`). It supports Windows 11 (x86, x86_64, arm64, arm64EC) and Linux (Ubuntu 24.04, GCC 13.3+). — [vst3sdk README](https://github.com/steinbergmedia/vst3sdk/blob/master/README.md)
- A single-file **VST3 C API** header (`vst3_c_api.h`) exists. CPLUG's changelog says it updated to "the new MIT licensed one". — [CPLUG README](https://github.com/Tremus/CPLUG)

**CLAP**
- Licence: MIT, "Copyright (c) 2021 Alexandre BIQUE". — [clap LICENSE](https://github.com/free-audio/clap/blob/main/LICENSE)
- CLAP "provides a stable ABI": "a plugin binary compiled with CLAP 1.x can be loaded by any other" 1.x host. The reference code is C (`src/plugin-template.c`). — [free-audio/clap README](https://github.com/free-audio/clap)
- **FL Studio**: Image-Line's own FL Studio 2024 page lists "CLever Audio Plug-in (CLAP) plugin support" (released around June 2024; Gearnews calls it 2024.1). — [Image-Line: FL Studio 2024](https://www.image-line.com/news/fl-studio-2024); [Gearnews](https://gearnews.com/fl-studio-daw-software)
- **Studio One**: CLAP arrived with Studio One 7, not 6.5. Sources are secondary only: a Renoise forum post, a dubspot spec page listing "VST2/VST3, AU, CLAP", and Auburn Sounds (Jan 2025), which says CLAP is "available from REAPER, Studio One and FL Studio". No official PreSonus/Fender release note was found. Fender's plug-in-extensions doc lists VST2/VST3/AU only. — [Renoise forum](https://forum.renoise.com/t/clap-new-plugins-standard/65880?page=3); [dubspot Studio One 7](https://blog.dubspot.com/plugins/studio-one-7); [Auburn Sounds 2025-01-30](https://www.auburnsounds.com/blog/CLAP-Support-And-Other-Goodies.html); [presonus-plugin-extensions](https://github.com/fenderdigital/presonus-plugin-extensions)
- **Bitwig, REAPER, MultitrackStudio, Zrythm** are listed as CLAP hosts (Sweetwater, undated, older). — [Sweetwater InSync](https://www.sweetwater.com/insync/clap-the-new-clever-audio-plug-in-format/)
- **Cubase 15**: no evidence of CLAP. Launch coverage talks only about VST, and CLAP appears only on a user wishlist. — [MusicTech Cubase 15](https://musictech.com/news/music/cubase-15-everything-you-need-to-know/); [Steinberg forum wishlist](https://forums.steinberg.net/t/cubase-15-wishlist/948753?page=6)
- **Ableton Live**: no CLAP support. There are feature-request threads, but no commitment. — [Ableton forum](https://forum.ableton.com/viewtopic.php?p=1806181); [Antares blog, 2026-07-27](https://www.antarestech.com/blog/vst3-au-aax-clap-plugin-formats-2026)
- CONFLICT: the Antares blog (July 2026) names only Bitwig and Reaper as CLAP hosts and says FL Studio does not support CLAP. Image-Line's own page contradicts this. Treat Antares as incomplete. — [Antares](https://www.antarestech.com/blog/vst3-au-aax-clap-plugin-formats-2026) vs. [Image-Line](https://www.image-line.com/news/fl-studio-2024)
- Antares does list VST3 as the format for Cubase, FL Studio and Studio One. — [Antares](https://www.antarestech.com/blog/vst3-au-aax-clap-plugin-formats-2026)

**clap-wrapper**
- MIT, "Copyright (c) 2022 defiantnerd". It projects one CLAP into **VST3, AUv2, AUv3 (macOS and iOS), AAX and a standalone**. Its build uses CMake (`cmake -B build -DCLAP_SDK_ROOT=... -DVST3_SDK_ROOT=...`). — [clap-wrapper LICENSE](https://github.com/free-audio/clap-wrapper/blob/main/LICENSE); [clap-wrapper README](https://github.com/free-audio/clap-wrapper)

**LV2**
- `COPYING` is ISC-style ("Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted…"). — [lv2 COPYING](https://github.com/lv2/lv2/blob/main/COPYING)

**AAX** (official pages unreachable here, so these points are secondary)
- Every AAX plugin must be signed with **PACE EDEN**, or it will not load in commercial Pro Tools. A signing-only EDEN licence is reportedly free once you join Avid's developer programme (contact audiosdk@avid.com); PACE then sends an **NDA**. Source: HISE forum, about 2023, older item, UNVERIFIED against Avid. — [HISE forum](https://forum.hise.audio/post/60655); [HISE forum](https://forum.hise.audio/post/60685)
- JUCE 8.0.11 bundles AAX SDK 2.9.0. The AAX SDK stays under Avid's own terms; no GPL/MIT option from Avid was found. — [KVR: JUCE 8.0.11](https://www.kvraudio.com/news/juce-8-0-11-now-available-65579); [JUCE forum "AAX open source release"](https://forum.juce.com/t/aax-open-source-release/44017)

### Inferences
- **Widest reach for the least licence risk is CLAP plus VST3, both MIT.** CLAP is the cleaner engineering target for a non-C++ core: it is one C header set with a stable ABI. VST3 is the format every large non-Apple DAW loads, including Cubase and Live, which have no CLAP. With VST3 now MIT, the reason to prefer CLAP over VST3 is technical (C ABI, no COM-style C++), not legal.
- **AAX should come last.** It is the only format whose licence path involves an NDA, a third-party signing service and terms Avid controls.
- **Project-rule conflict:** clap-wrapper and the VST3 SDK examples are CMake projects. A "no CMake" Echoel would need either (a) a hand-written VST3 shell on the single-file MIT VST3 C API, as CPLUG does, or (b) a council exception for CMake confined to the shell repo.
- These formats do not exist on iOS or Android. The desktop formats only matter for macOS, Windows and Linux. On iOS the format stays AUv3, and on Android it would be AAP (see §3).

### Gaps
- The official CLAP host list (cleveraudio.org/hosts-and-plug-ins) and clapdb.tech could not be fetched. Studio One 7's CLAP support has no first-party confirmation here.
- Avid's current AAX developer agreement text (developer.avid.com) could not be fetched. Whether the free EDEN signing licence still applies in 2026 is UNVERIFIED.
- Logic Pro and Pro Tools CLAP status: only the Antares blog's negative statement. No first-party source.

## 2. Swift beyond Apple: Windows, Linux, Android, WebAssembly, and a C ABI into a CLAP/VST3 shell

### Takeaway
All four targets now have **official** Swift support:
- **Linux and Windows**: Swift.org lists both as "Deployment and Development".
- **Wasm**: official since **Swift 6.2 (15 Sep 2025)**.
- **Android**: preview from **24 Oct 2025**; the first official SDK came with **Swift 6.3 (24 Mar 2026)**.
- **C ABI**: Swift 6.3 formalised exporting functions to C with **`@c` (SE-0495)**. A Swift DSP core behind a C ABI inside a CLAP shell is therefore technically direct.

The hard blocker for Echoel is not the language. It is **Accelerate, which exists only on Apple platforms**, plus the Apple-only `Network`/`AVFoundation`/`CoreMIDI` stack around the DSP. No production Swift CLAP or VST3 plugin was found.

### Cited Findings
- swift.org platform table:
  - Windows (min 10.0): "Deployment and Development", with debugger, SwiftPM and SourceKit-LSP but no REPL.
  - Linux: Ubuntu 22.04, Debian 12, Fedora 41, Amazon Linux 2023, RHEL UBI 9, all Dev+Deployment.
  - Android: listed only with a minimum deployment version of "9 (API 28)".
  - Quote: "Every platform is expected to have core runtime, Standard Library support, and core libraries". — [swift.org/platform-support](https://www.swift.org/platform-support/)
- Foundation: since Swift 6, Linux and Windows use the same Swift-native swift-foundation as Apple platforms ("If you import Foundation on Linux or Windows today, you will be using the new implementation"). Some legacy types are not yet ported (CharacterSet is the example given). — [Swift Forums: swift-foundation now available](https://forums.swift.org/t/swift-foundation-now-available/73530)
- **Accelerate (and vDSP) list only Apple platforms**: iOS, iPadOS, Mac Catalyst, macOS, tvOS, visionOS, watchOS. — [Apple: Accelerate](https://developer.apple.com/documentation/accelerate); [Apple: vDSP](https://developer.apple.com/documentation/accelerate/vdsp) (read via Apple's documentation JSON, 2026-10-19)
- **Wasm**: "Swift 6.2 gains support for WebAssembly", announced 2025-09-15. — [swift.org: Swift 6.2 released](https://www.swift.org/blog/swift-6.2-released/)
  - The getting-started guide installs Swift SDKs that Swift.org distributes: one full SDK and one Embedded SDK. Cross-compiling from Windows hosts is not supported yet. — [swift.org: Getting Started with Swift SDKs for WebAssembly](https://swift.org/documentation/articles/wasm-getting-started.html)
  - The full and embedded SDKs share a target triple, so select by SDK ID. — [Swift Forums](https://forums.swift.org/t/webassembly-swift-sdk-selection-in-swift-6-2/82267)
- **Android**:
  - Nightly preview SDK announced **2025-10-24**. The Android workgroup is "an open group, free for anyone to join". "Over 25% of packages in the Swift Package Index" already built for Android. — [swift.org: nightly Swift SDK for Android](https://www.swift.org/blog/nightly-swift-sdk-for-android/)
  - Swift 6.3 (released 2026-03-24) is the "first official release of the Swift SDK for Android". It integrates with Kotlin/Java apps through Swift Java and Swift Java JNI Core. — [swift.org: Swift 6.3 released](https://www.swift.org/blog/swift-6.3-released/); [Thurrott](https://www.thurrott.com/dev/334219/swift-6-3-brings-first-sdk-for-android)
  - The current getting-started page names **Android NDK LTS r30**, `x86_64` and `aarch64` (armv7 is not mentioned), and Swift **6.4.1**, with host toolchain and SDK versions required to match exactly. Hosts are macOS or Linux; Windows is not mentioned. Swift is built into per-ABI `.so` files inside the APK, called from Java/Kotlin through swift-java (JNI), and needs `libc++_shared.so`. — [swift.org: Swift SDK for Android getting started](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)
  - CONFLICT: the example triples use `android23`, while the platform table lists a minimum of API 28. — same page vs. [platform-support](https://www.swift.org/platform-support/)
  - swift-java offers `jextract --mode=ffm` (JDK 22+ FFM API; validated against JDK 25) and `--mode=jni`. — [swiftlang/swift-java README](https://github.com/swiftlang/swift-java)
- **C ABI export**: Swift 6.3's `@c` "lets you expose Swift functions and enums to C code", generates the C header declaration, and supports `@c` + `@implementation` for functions declared in a C header. — [swift.org: Swift 6.3 released](https://www.swift.org/blog/swift-6.3-released/)
  - SE-0495 ("C-compatible functions and enums") was accepted after review ended 9 Oct 2025. It replaces the underscored `@_cdecl`. — [Swift Forums: [Accepted] SE-0495](https://forums.swift.org/t/accepted-se-0495-c-compatible-functions-and-enums/82833)
- Embedded Swift gained the full `String` API, `InlineArray` and `Span` in 6.2. Swift/C++ interop can use `Span`. — [swift.org: Swift 6.2 released](https://www.swift.org/blog/swift-6.2-released/)
- Searching for a CLAP plugin written in Swift returned only C/C++/Rust tooling (CPLUG, clap-juce-extensions, clap-validator). No Swift implementation was found. — [cleveraudio.org developers page (search result only)](https://cleveraudio.org/developers-getting-started/)

### Inferences
- **Architecture that fits Echoel's rules:**
  - Keep the DSP core in pure Swift.
  - Give every Accelerate call a portable fallback behind `#if canImport(Accelerate)`. The repo already uses this guard pattern; per `.claude/rules/swift-audio.md`, 7 of 41 DSP files take Accelerate.
  - Export a small C ABI with `@c`: create, process(block), set-param, state, MIDI/UMP in.
  - Put a thin C shell around it (CLAP natively; VST3 through the MIT VST3 C API or clap-wrapper).
- This is a rough engineering inference, not something sourced: the DSP port is mostly about replacing vDSP. Most of the risk sits in shipping the Swift runtime inside a DLL/.so that a host loads, which can mean several Swift plugins in one process, runtime version clashes, and static versus dynamic runtime linkage on Windows. No source was found confirming that Windows DAWs host Swift-runtime DLLs well. Treat this as a **technical spike to run first**.
- Linux is the cheapest non-Apple target for that spike: official toolchain, swift-foundation, no signing, and Bitwig/REAPER both host CLAP on Linux.
- Android is real but young: the first official SDK is 7 months old, and the doc already names Swift 6.4.1. Wasm is official, but audio-thread Swift in an AudioWorklet is unproven (§3).
- The repo's OSC and ADM-OSC run on Apple's `Network` framework (CLAUDE.md tech-stack table). That layer needs a portable socket layer on every non-Apple OS (see §4).

### Gaps
- No public Swift-in-CLAP or Swift-in-VST3 project was found, so whether the Swift runtime behaves inside a third-party host process on Windows is UNVERIFIED.
- The release date of Swift 6.4, named on the Android getting-started page, was not verified.
- Windows ARM64 Swift toolchain status was not found on the platform-support page.
- Whether Swift Embedded or full Wasm can run allocation-free inside an `AudioWorkletProcessor`: no evidence found.

## 3. Non-Swift alternatives for the shell only: iPlug2, nih-plug, DPF, WAM 2.0, the Android audio stack, AAP

### Takeaway
Every candidate shell has a permissive licence: iPlug2 (zlib-like), DPF (ISC), CPLUG (MIT/Unlicense), WAM (MIT), Oboe (Apache-2.0), AAP (MIT). The one exception is **nih-plug's VST3 path, which still forces GPLv3** through its Rust VST3 bindings. All of them except nih-plug (Rust) are C/C++. A "shell only" use therefore means accepting a contained C/C++ dependency, which is exactly the council-approval case in the project rules. For Android, **AAudio/Oboe is the audio I/O** and **AAP is the only Android-native plugin format**, and AAP is experimental.

### Cited Findings
- **iPlug2**:
  - Licence is zlib-style: "Permission is granted to anyone to use this software for any purpose, including commercial applications…". It includes Cockos WDL ("Zlib-like license"). — [iPlug2 LICENSE.txt](https://github.com/iPlug2/iPlug2/blob/master/LICENSE.txt)
  - Targets "CLAP, VST2, VST3, AUv2, AUv3, AAX (Native) and the Web Audio Module (WAM v1)". It builds standalone win32/macOS apps and compiles to WebAssembly through emscripten. Minimums: Windows 8, macOS 10.13, visionOS 26.0, iOS 15. Supports Windows ARM64EC. Written in C++. — [iPlug2 README](https://github.com/iPlug2/iPlug2)
- **nih-plug (Rust)**: "The framework, its libraries, and the example plugins … are all licensed under the ISC license. However, the VST3 bindings used by `nih_export_vst3!()` are licensed under the GPLv3 license … any VST3 plugins built with NIH-plug need to be able to comply with the terms of the GPLv3 license." `Cargo.toml` still pulls `vst3-sys` from a fork. — [nih-plug README §Licensing](https://github.com/robbert-vdh/nih-plug); [nih-plug Cargo.toml](https://github.com/robbert-vdh/nih-plug/blob/master/Cargo.toml)
- **DPF**: ISC-style licence, "Copyright (C) 2012-2025 Filipe Coelho". Builds "LADSPA, DSSI, LV2, VST2, VST3 and CLAP" plus a JACK/standalone mode. Both Makefile and CMake CI exist. — [DPF LICENSE](https://github.com/DISTRHO/DPF/blob/main/LICENSE); [DPF README](https://github.com/DISTRHO/DPF)
- **CPLUG**: a C99 wrapper for VST3, AUv2 and CLAP with "no extra dependancies outside of the C APIs". Format files are about 900 lines (CLAP), 1,700 (AUv2) and 2,700 (VST3). Licence: "ALTERNATIVE A - MIT License" or "ALTERNATIVE B - Public Domain (www.unlicense.org)". AUv2 and standalone builds need macros set in CMakeLists.txt. — [CPLUG README](https://github.com/Tremus/CPLUG); [CPLUG LICENSE](https://github.com/Tremus/CPLUG/blob/master/LICENSE)
- **Web Audio Modules**:
  - API repo licence is MIT ("Copyright (c) 2015 Web Audio Modules (WAMs)"). — [webaudiomodules/api LICENSE](https://github.com/webaudiomodules/api/blob/master/LICENSE)
  - WAM began in 2015 and reached 2.0 in 2021. It is designed for host and plugin both running in the audio thread as AudioWorklets. These are older items (papers 2021–2022). — [AES e-library](https://aes2.org/publications/elibrary-page/?id=23110); [Zenodo record 2022](https://zenodo.org/record/6769098)
- **Oboe**:
  - Licence Apache-2.0. — [google/oboe LICENSE](https://github.com/google/oboe/blob/main/LICENSE)
  - "a C++ library … Compatible with API 16 onwards". It picks "OpenSL ES on API 16+ or AAudio on API 27+". — [google/oboe README](https://github.com/google/oboe)
- **AAP (Audio Plugins For Android)**:
  - MIT. — [aap-core LICENSE](https://github.com/atsushieno/aap-core/blob/main/LICENSE)
  - "Android lacks commonly used audio plugin format… AAP is more like AudioUnit v3 on iOS". It runs out of process: host and plugin are separate apps talking over Binder IPC (NdkBinder, Android 10+) and ashmem, with host–plugin messaging over "MIDI2 event messaging". It has JUCE, LV2 and DPF ports.
  - The README itself warns: "the README is either up to date, partially obsoleted, or sometimes … ahead of implementation. Do not trust it too much." The latest demo is dated 2026.5. — [aap-core README](https://github.com/atsushieno/aap-core)
- C/C++ to AudioWorklet is an established path through emscripten's "Wasm Audio Worklets" API. Chrome notes the render budget is about 3 ms at 44.1 kHz. — [Emscripten: Wasm Audio Worklets](https://emscripten.org/docs/api_reference/wasm_audio_worklets.html); [Chrome: Audio worklet design pattern](https://developer.chrome.com/blog/audio-worklet-design-pattern)
- JUCE, for comparison only: dual AGPLv3 / commercial licence. This rests on a third-party mirror of the LICENSE file, so it is UNVERIFIED against juce.com. — [mirror of JUCE LICENSE.md](https://git.efi.th-nuernberg.de/gitea/depperschmidch101180/main_crystalizereq/src/commit/51ec8e00cfde3c9f910af0eedf16d1ff8547ddc0/CrystalizerEQ/JUCE/LICENSE.md)

### Inferences
- **The lowest-friction shell that keeps Swift as the only real code is CPLUG-style C**: MIT/Unlicense, single files, and the shell is small enough to hand-write. It covers CLAP and VST3 without a framework.
- **DPF** is the strongest choice if Linux LV2 matters. **iPlug2** is the only one here that covers AAX and Web/WAM from one codebase, but it is a full C++ framework with UI. That is much more than "the shell only" and would pull C++ into the product.
- **Avoid nih-plug's VST3 export for closed source** while it uses GPLv3 `vst3-sys`, even though the upstream SDK is now MIT. It also adds Rust, a second non-Swift language.
- **Android**: Oboe is C++ and needs council approval. AAudio is a C NDK API that Swift could call through C interop without Oboe; the API-27+ AAudio threshold is taken from Oboe's README. AAP is MIT and conceptually the AUv3 of Android, but it is experimental and has a tiny host base. Ship a standalone Android app first and treat AAP as optional.

### Gaps
- No current WAM 2.0 spec or release page was reached (webaudiomodules.org was not fetched). Host adoption of WAM 2.0 in 2025–2026 is unknown.
- No AAudio primary doc was fetched. Android API levels come from Oboe's README only.
- Whether `vst3-sys` (Rust) has been relicensed since the VST3 SDK went MIT: its LICENSE and README returned 404 at `RustAudio/vst3-sys/master`, so this is UNVERIFIED.

## 4. Interop that keeps working everywhere: Ableton Link, MIDI 2.0 per OS, Web MIDI, OSC libraries

### Takeaway
**Link is NOT free for closed-source apps outside iOS.**
- The cross-platform Link source is **GPLv2+**, with a proprietary licence "on request" (link-devs@ableton.com, terms unpublished).
- The free, royalty-free **LinkKit licence covers iOS applications only**.

MIDI 2.0 status by platform:
- **Windows**: system-wide since **Windows MIDI Services GA (17 Feb 2026)**, Windows 11 24H2/25H2, MIT-licensed SDK.
- **Linux**: since ALSA in **kernel 6.5** (2023).
- **Android**: over USB since **Android 13**, over virtual/inter-app transports since **Android 15**.
- **Web**: **not at all**. Web MIDI is still MIDI 1.0 only, and Safari, including iOS, has no Web MIDI.

OSC is the most portable piece: an MIT Swift OSC library already targets Linux and Android.

### Cited Findings
- **Link**:
  - Cross-platform repo `LICENSE.md`: "GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later version… If you would like to incorporate Link into a proprietary software application, please contact <link-devs@ableton.com>." The README: "Ableton Link is dual licensed under GPLv2+ and a proprietary license." It builds for Windows (MSVC 17 2022), Mac (Xcode 16.2) and Linux (Clang 13 / GCC 10). — [Ableton/link LICENSE.md](https://github.com/Ableton/link/blob/master/LICENSE.md); [Ableton/link README](https://github.com/Ableton/link)
  - LinkKit, the iOS SDK, ships under "Ableton Link SDK License v2.0": "a non-exclusive, worldwide, royalty-free, non-transferable license … to develop **iOS applications** … and … to publish, sell or otherwise distribute such iOS applications". Restrictions include "(e) offer Link support as an in-app purchase" and following the UI guidelines. — [LinkKit LICENSE.md](https://github.com/Ableton/LinkKit/blob/master/LICENSE.md)
  - LinkKit README: custom builds depend on the GPL cross-platform Link, and "the GPL is not compatible with the iOS App Store". iOS 17+ needs the `com.apple.developer.multicast` entitlement. — [LinkKit README](https://github.com/Ableton/LinkKit)
- **Windows**:
  - Windows MIDI Services is GA; "completely rewriting decades of MIDI 1.0 code on Windows to both support MIDI 2.0 and make MIDI 1.0 amazing". Existing MIDI 1.0 apps improve "without needing any app updates". MIDI 2.0 apps use the new "Windows MIDI Services App SDK". Blog dated 2026-02-17. — [Windows Experience Blog](https://blogs.windows.com/windowsexperience/2026/02/17/making-music-with-midi-just-got-a-real-boost-in-windows-11/)
  - Officially only Windows 11 24H2 and 25H2. — [heise](https://heise.de/-11181074)
  - Repo licence MIT ("Copyright (c) Microsoft Corporation"). — [microsoft/MIDI LICENSE](https://github.com/microsoft/MIDI/blob/main/LICENSE)
- **Linux**: kernel 6.5 docs say the kernel handles the UMP transport and protocol encode/decode, MIDI-CI runs in user space, and access is through rawmidi plus the ALSA sequencer, with automatic MIDI 1.0 ⇄ 2.0 client conversion. "Only USB MIDI device supports the UMP" natively in 6.5. Older item (2023). — [kernel.org: MIDI 2.0 on Linux (v6.5)](https://docs.kernel.org/6.5/sound/designs/midi-2.0.html); [Phoronix](https://www.phoronix.com/news/MIDI-2.0-Support-Linux-6.5)
- **Android**: "Starting in Android 13, MIDI 2.0 support is added to the USB transport". MIDI 2.0 over virtual transports is supported "in Android 15 and higher". AMidi is the NDK C API. — [AOSP: MIDI](https://source.android.com/docs/core/audio/midi)
- **Web MIDI**:
  - The W3C Web MIDI issue on MIDI 2.0 shows no near-term plan for MIDI 2.0 semantics; the suggestion was to build it in JS on top of the 1.0 API. — [WebAudio/web-midi-api #211](https://github.com/WebAudio/web-midi-api/issues/211)
  - Can I Use: Chrome 43+, Edge 79+, Firefox 108+; Safari desktop and iOS not supported. — [caniuse: Web MIDI](https://caniuse.com/midi)
- **OSC**:
  - orchetect's Swift OSC toolkit (`swift-osc`, formerly OSCKit) is MIT and "written in Swift for Apple platforms, Linux, and Android". Its README matrix marks WASM/Windows as "planned or WIP". — [orchetect/OSCKit README](https://github.com/orchetect/OSCKit)
  - liblo (C) is LGPL-2.1. — [liblo COPYING](https://github.com/radarsat1/liblo)
  - SwiftNIO (portable Swift networking) is Apache-2.0. — [apple/swift-nio LICENSE](https://github.com/apple/swift-nio)

### Inferences
- **The current project rule's premise — "Ableton Link, which is free" — holds on iOS only.** For a closed-source Windows, Linux or Android build, Link means GPLv2+ (incompatible with a closed app) or an unpublished proprietary deal with Ableton. Ask link-devs@ableton.com **before** putting Link on a non-Apple roadmap.
- In a browser, Link is practically out of reach. Its peer discovery is LAN UDP multicast (LinkKit README), which browser pages cannot do. This is an inference; no primary source states it for browsers.
- MIDI 2.0 is now a real cross-OS baseline on Windows 11, Linux and Android. On the Web, Echoel would have to degrade to MIDI 1.0 and lose iOS Safari entirely.
- OSC/ADM-OSC is the most portable promise: a plain UDP protocol with MIT/Apache Swift building blocks on Linux and Android today. Windows and Wasm still need verification.

### Gaps
- Ableton's proprietary (non-iOS) Link terms and any fee are unpublished, so UNVERIFIED.
- The Windows MIDI Services App SDK's language bindings (C, WinRT) and whether Swift can consume them were not researched.
- Android MIDI 2.0 class names, UMP version (1.0 vs 1.1) and AMidi UMP coverage are UNVERIFIED. One forum claim says Android 13 implements only UMP 1.0.

## 5. What comparable cross-platform music apps did (feasibility evidence)

### Takeaway
The evidence shows mobile-first music apps **do** cross to other platforms, but always on a C/C++ (or JVM+C++) core, never on Swift. Korg Gadget runs on iOS, macOS, Switch and Meta Quest, and ships AU/VST/AAX/VST3/AUv3. Koala Sampler runs on iOS and Android. Bitwig runs on Linux, macOS and Windows, reportedly in C++ and Java. No Swift-core music app shipping on Windows, Linux or Android was found.

### Cited Findings
- **Korg Gadget**:
  - The Mac version adds a "Gadget Plug-in Collection" supporting AU, VST, AAX and NKS. — [Korg product page](https://www.korg.com/de/products/software/korg_gadget/index.php)
  - Gadget 3 (NAMM 2024) added VST3 and AUv3 and runs on macOS, iOS, Meta Quest 2/Pro and Nintendo Switch. — [MusicRadar](https://www.musicradar.com/news/korg-gadget-3-update)
  - The Switch version (April 2018) is a reduced standalone; it cannot output sound files such as mp3/wav/midi. Older item. — [Nintendo eShop listing](https://ec.nintendo.com/AU/en/titles/70010000001005)
- **Koala Sampler** (Elf Audio, Marek Bereza) runs on "your iOS or Android device". — [RouteNote](https://create.routenote.com/blog/koala-sampler-gains-new-mix-powers/); [Sound On Sound review](https://www.soundonsound.com/reviews/elf-audio-koala-sampler)
- **Bitwig Studio** is proprietary, runs on Linux, macOS and Windows, and is listed as written in C++ and Java. Wikipedia marks the language claim "citation needed". Bitwig co-created CLAP with u-he. — [Wikipedia: Bitwig Studio](https://en.wikipedia.org/wiki/Bitwig_Studio) (via search snippet; page not directly fetchable here)
- **Drambo** (BeepStreet): iOS only in every first-hand source found (launched 2020-04-02). An AppBrain listing claiming Google Play availability looks like a data error. — [Sonicstate 2020](https://www.sonicstate.com/news/2020/04/02/modular-ios-groovebox/); [AppBrain](https://www.appbrain.com/appstore/drambo/ios-1469365718)
- **FL Studio** (an Image-Line desktop DAW, which also has a mobile line) became a CLAP host in 2024. — [Image-Line](https://www.image-line.com/news/fl-studio-2024)

### Inferences
- A mobile-first instrument company reaching desktop plugin formats is proven (Korg). A Swift core doing it is unproven: this would be pioneering work, so budget a spike rather than promising a date.
- The common pattern is "native app per platform plus a shared DSP core plus thin format shells". That is the architecture §2 recommends, with Swift taking the place of C++ as the shared core.

### Gaps
- Tech stacks of Koala Sampler, n-Track Studio, Loopy Pro, the Moog apps and REAPER (WDL/SWELL) were not found in primary sources this round. No framework claims are made for them.
- No evidence was found of any Swift-based music app shipping on Windows, Linux or Android.

## 6. Ranked realistic routes (synthesis for "Apple first, then X, then Y")

### Takeaway
An honest order is:
1. **Apple** (iOS/iPadOS AUv3 → macOS AUv3/standalone → visionOS).
2. **Desktop CLAP + VST3 on macOS, then Linux, then Windows**, from the Swift core through a C ABI shell. Both formats are MIT. Run a spike first.
3. **Android standalone app** (official Swift SDK since 6.3; AAudio/Oboe; AAP later, optional).
4. **Web** last: Swift Wasm is official, but there is no Swift AudioWorklet precedent, no Safari Web MIDI and no MIDI 2.0.

AAX comes after all of these, if ever. Ableton Link off Apple is blocked on a licence conversation with Ableton.

### Cited Findings
| Rank | Route | Licence terms (sourced) | Maturity (sourced) | Effort / risk (inference unless sourced) |
|---|---|---|---|---|
| 0 | Apple (AUv3 on iOS/macOS, visionOS) | Apple SDK; LinkKit royalty-free for iOS apps ([LinkKit LICENSE](https://github.com/Ableton/LinkKit/blob/master/LICENSE.md)) | Shipping today (project baseline) | Lowest; Accelerate available ([Apple](https://developer.apple.com/documentation/accelerate)) |
| 1 | CLAP on macOS/Linux/Windows from Swift core via `@c` | CLAP MIT ([LICENSE](https://github.com/free-audio/clap/blob/main/LICENSE)); `@c` official in Swift 6.3 ([swift.org](https://www.swift.org/blog/swift-6.3-released/)) | Hosts: Bitwig, REAPER, FL Studio 2024 ([Image-Line](https://www.image-line.com/news/fl-studio-2024)), Studio One 7 (secondary) | Medium; no Swift-in-CLAP precedent (gap); Accelerate replacement needed; Swift runtime-in-host risk UNVERIFIED |
| 2 | VST3 alongside CLAP (clap-wrapper or hand C shell) | VST3 SDK MIT since VST 3.8, 2025-10-29 ([README](https://github.com/steinbergmedia/vst3sdk/blob/master/README.md)); clap-wrapper MIT ([LICENSE](https://github.com/free-audio/clap-wrapper/blob/main/LICENSE)) | VST3 is the format for Cubase/FL/Studio One ([Antares](https://www.antarestech.com/blog/vst3-au-aax-clap-plugin-formats-2026)); Cubase 15 has no CLAP ([MusicTech](https://musictech.com/news/music/cubase-15-everything-you-need-to-know/)) | Low extra once CLAP exists; clap-wrapper/VST3 SDK are CMake builds ([clap-wrapper](https://github.com/free-audio/clap-wrapper)) → rule conflict |
| 3 | LV2 (Linux) | ISC ([COPYING](https://github.com/lv2/lv2/blob/main/COPYING)); DPF ISC covers LV2+CLAP+VST3 ([DPF](https://github.com/DISTRHO/DPF)) | Mature on Linux (DPF formats list) | Optional; CLAP already reaches Bitwig/REAPER on Linux |
| 4 | Android standalone | Swift SDK official since Swift 6.3, 2026-03-24 ([swift.org](https://www.swift.org/blog/swift-6.3-released/)); Oboe Apache-2.0 ([LICENSE](https://github.com/google/oboe/blob/main/LICENSE)) | NDK r30, aarch64/x86_64 ([swift.org](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)); MIDI 2.0 USB A13 / virtual A15 ([AOSP](https://source.android.com/docs/core/audio/midi)) | Medium–high: new UI layer (no SwiftUI on Android — inference), JNI glue, camera rPPG re-implementation |
| 5 | Android plugin (AAP) | MIT ([LICENSE](https://github.com/atsushieno/aap-core/blob/main/LICENSE)) | Self-described as possibly obsolete docs ([README](https://github.com/atsushieno/aap-core)) | High risk, tiny host base |
| 6 | Web (Swift→Wasm + AudioWorklet, WAM 2.0) | WAM MIT ([LICENSE](https://github.com/webaudiomodules/api/blob/master/LICENSE)) | Swift Wasm official since 6.2 ([swift.org](https://www.swift.org/blog/swift-6.2-released/)); no Safari Web MIDI ([caniuse](https://caniuse.com/midi)); no MIDI 2.0 in Web MIDI ([W3C issue](https://github.com/WebAudio/web-midi-api/issues/211)) | High; no Swift AudioWorklet precedent found; C/C++ precedent via emscripten ([docs](https://emscripten.org/docs/api_reference/wasm_audio_worklets.html)) |
| 7 | AAX (Pro Tools) | Avid terms + PACE EDEN signing + NDA (secondary, UNVERIFIED: [HISE forum](https://forum.hise.audio/post/60655)) | clap-wrapper can project to AAX ([README](https://github.com/free-audio/clap-wrapper)) | Highest licence friction |
| — | Ableton Link off Apple | GPLv2+ or proprietary on request ([LICENSE.md](https://github.com/Ableton/link/blob/master/LICENSE.md)) | Builds on Win/Mac/Linux ([README](https://github.com/Ableton/link)) | Blocked until Ableton grants a proprietary licence for closed-source non-iOS builds |

### Inferences
- The roadmap sentence that is defensible today: **"Apple first. Then desktop plugins (CLAP + VST3, both MIT) on macOS, then Linux, then Windows, after a Swift-in-host spike. Then an Android standalone app. Web and AAX are not planned."** Each later step is gated on a measurable spike, not a date.
- Two project-rule frictions must reach the Council before step 1:
  1. **CMake**: the clap-wrapper and VST3 SDK build systems, avoidable with a hand-written C shell on the single-file VST3 C API.
  2. **Link** is not "free" outside iOS.
- The cheapest first step: build the Swift DSP core on **Linux** with Accelerate guarded out, expose 4–5 `@c` functions, and load it in REAPER or Bitwig through a ~900-line C CLAP shell (CPLUG's CLAP file is that size). This tests runtime-in-host, the portable DSP fallback and the C ABI in one go, with no signing.

### Gaps
- All effort figures are engineering judgement. No published benchmark of Swift-runtime plugin hosting exists in the sources found.
- Market-share data per DAW (which hosts users actually run on Windows and Linux) was not researched, so "widest reach" rests on format-support lists, not user counts.

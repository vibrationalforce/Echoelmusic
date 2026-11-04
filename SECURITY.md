# Security

Echoel runs on your device. It has no account, no server of its own and no analytics. It reaches
the network only where you turn that on, and nowhere else: the App Store (asked at launch whether
you bought Echoel Plugins, and when you open the store screen — an Echoel Audio Unit in another app
asks it too, when the app has not recorded an answer yet); Network MIDI, off until its toggle; the
live stream over RTMP or RTMPS, off until Go Live; the Connections page (OSC, ADM-OSC, Art-Net,
sACN on your local network), each off until switched on; and a Jam (MultipeerConnectivity), off
until you host or join one. A security problem is still possible — in the app, in the Audio Unit
extension, or in how a song file is read.

## Reporting

Please report privately through GitHub: **Security → Report a vulnerability** on this
repository. Do not open a public issue for it.

Include what you found, how to reproduce it and the app version (as TestFlight or the App Store shows it). A crafted
song file that crashes the app or escapes its `Media/` folder counts.

## Supported versions

Only the newest build is supported: the latest Echoel Studio build in TestFlight, and once it is
in the App Store, the latest App Store version. A fix ships as a new build; older builds are not
patched. A build is supported until the next one is out. The earlier Echoelmusic app (10.x, the
code under `Sources/`) is frozen and gets no security fixes.

## What happens next

- An acknowledgement within 7 days.
- A fix or a clear answer within 90 days; we agree a disclosure date with you.
- Credit in the release notes if you want it.

Research in good faith — on your own devices and your own data, without harming other users —
will never be met with legal action.

## Scope

In scope: the app and extension built from `EchoelStudio/`, the song format
(`docs/FORMAT.md`), the website in `docs/`. Out of scope: Apple's platforms and the App Store
itself, third-party Audio Units you load into Echoel.

## Software bill of materials (Echoel Studio)

What the app links that is not Echoel's own or Apple's (`EchoelStudio/project.yml`, licence texts in
About → Acknowledgments and in `THIRD_PARTY_NOTICES.md`):

| Component | Version | Licence | Where |
|---|---|---|---|
| HaishinKit.swift (products HaishinKit, RTMPHaishinKit) | 2.2.5, pinned exactly | BSD-3-Clause | app only, `App/Streaming/`; never the Audio Unit extension |
| Logboard (pulled in by HaishinKit) | 2.6.0 | BSD-3-Clause | app only |
| Atkinson Hyperlegible (font file, not code) | 1.006 | SIL Open Font License 1.1 | app and extension |

Nothing else is linked. SRT (libsrt, with OpenSSL inside it) was removed on 2026-11-04, so no
OpenSSL ships; encryption in transit is Apple's own (HTTPS for the store, TLS for RTMPS, the Jam's
MultipeerConnectivity session).

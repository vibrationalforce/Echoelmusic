# Security

Echoel runs on your device. It has no account, no server of its own and no analytics; the only
network use today is the App Store, which the app asks at launch whether you bought Echoel Plugins
and when you open the store screen (prices, buying, Restore Purchases) — an Echoel Audio Unit in
another app asks it too, when the app has not recorded an answer yet — and Network MIDI, which is
off until you turn it on. A security problem is still possible — in
the app, in the Audio Unit extension, or in how a song file is read.

## Reporting

Please report privately through GitHub: **Security → Report a vulnerability** on this
repository. Do not open a public issue for it.

Include what you found, how to reproduce it and the app version (as TestFlight or the App Store shows it). A crafted
song file that crashes the app or escapes its `Media/` folder counts.

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

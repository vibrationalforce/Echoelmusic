# Website presentation, inclusion, collaboration and wellbeing-language evidence for an independent music/multimedia tool (status 2026-10-19)

Method note (read first): from this sandbox only `developer.apple.com` and `raw.githubusercontent.com` could be fetched directly. EUR-Lex, W3C, WHO, ITU, PubMed, Cochrane, Google Search Central, gesetze-im-internet.de and all vendor sites failed DNS resolution. Every finding not from those two hosts comes from web-search result summaries that name the source URL. Each such finding is cited to that URL, but the page itself was not opened. Treat those as **secondary-verified** and re-check the primary text before quoting it in public copy. Items marked **UNVERIFIED** could not be tied to a specific source page.

## 1. Website integration patterns used by respected pro-audio/creative tools (compatibility, roadmaps, changelogs, open formats, betas, preset sharing, press kits; DE/EN static sites; SoftwareApplication structured data; accessibility statements)

### Takeaway
The respected tools publish facts as plain, versioned documents rather than marketing claims: dated changelogs grouped by version, a compatibility statement placed where users buy (store listing), a beta programme with stated eligibility, a developer-owned forum, plugin/patch manifests in a public Git repository, and an accessibility chapter that lists what does **not** work yet. None of the named vendors turned up a dated public roadmap. For a DE/EN static site, Google's rules are mechanical: identical hreflang sets on every language version, plus an `x-default`. Google's SoftwareApplication rich result also requires a rating or review property, which a site without reviews cannot truthfully supply.

### Cited Findings
**Beta / pre-release programmes**
- Ableton runs betas through its "Beta Test Community" on Centercode. The Live Beta FAQ says Live 12 and Live 11 have active programmes. Eligibility depends on the release type: major versions are open to Standard/Suite owners, minor and bugfix betas to all editions (Lite, Intro, Standard, Suite). Support staff cannot speed up admission. The entry page is ableton.com/en/beta — [Ableton Live Beta FAQ](https://help.ableton.com/hc/en-us/articles/115001663870).
- Live 12.3 went into public beta, and anyone with a Live 12 licence could sign up for free — [Resident Advisor](https://ra.co/news/83577).
- Bitwig publishes beta release notes as static HTML pages, one per beta build, on its downloads host. Each line is a terse change with a bug ID, e.g. "CLAP: Updated to version 1.1.9" and "CLAP: MPE was not working in a certain situation [34415]". These are 2023 pages (older item) — [Bitwig 5.1 Beta 6 notes](https://downloads.bitwig.com/5.1%20Beta%206/Release-Notes-5.1%20Beta%206.html), [Bitwig 5.1 Beta 9 notes](https://downloads.bitwig.com/5.1%20Beta%209/Release-Notes-5.1%20Beta%209.html).
- Loopy Pro: per forum posts, the developer is the owner, sysadmin and sole provider of the forum, and volunteer moderators run it day to day. A community-posted (not developer-signed) early-2025 comment says beta places for Loopy Pro 2.0 were offered in rounds — [Loopy Pro forum comment 1382944](https://forum.loopypro.com/discussion/comment/1382944/), [comment 1382473](https://forum.loopypro.com/discussion/comment/1382473/). No official Loopy Pro TestFlight page or changelog was found.

**Changelogs, open manifests, open file formats**
- VCV Rack keeps a `CHANGELOG.md` grouped by version and date, with sub-sections Core / Rack Pro / API. Entries cover plugin-ecosystem changes, e.g. a `minRackVersion` manifest property that stops Rack downloading an incompatible plugin, and a way for plugin packages to delete old presets by shipping a zero-byte file of the same name — [VCV Rack CHANGELOG (kx.studio mirror)](https://git.kx.studio/VCVRack/Rack/src/branch/v2/CHANGELOG.md). The repository carries a `LICENSE-GPLv3.txt` — [Rack repo listing (mirror)](https://git.kx.studio/VCVRack/Rack/src/commit/2b9efc1401be1267f849620fe2f7ee6cad42b166).
- The VCV plugin manifest is documented in the official manual. `plugin.json` sits at the plugin root, and its `slug` is required and must stay fixed after release "so that patch compatibility is not broken" — [VCV Manual: Manifest](https://vcvrack.com/manual/Manifest).
- The VCV Library is a public GitHub "database for VCV Rack plugins". Its README (fetched directly) requires submitted plugins to "follow the VCV Plugin Ethics Guidelines" and "not harm the user's computer or privacy". The update process is public: one GitHub issue per plugin titled with its slug, a version bump in `plugin.json`, and a comment with the exact commit hash, "not just … the name of a branch" — [VCVRack/library README](https://raw.githubusercontent.com/VCVRack/library/v2/README.md).
- There is no official public schema for the `.vcv` patch file. A community forum post and a third-party tool describe a Rack 2 `.vcv` as a zstd-compressed tar holding `patch.json` (Rack 1 used plain JSON). This is a single-developer observation, not a spec — [VCV Community forum](https://community.vcvrack.com/t/creating-vcv-rack-patch-files-from-software/24502).
- CLAP ("CLever Audio Plugin") is an open plugin ABI. Per its README (fetched directly), "a plugin binary compiled with CLAP 1.x can be loaded by any other CLAP 1.y". The licence file is MIT — [free-audio/clap README](https://raw.githubusercontent.com/free-audio/clap/main/README.md), [CLAP LICENSE](https://raw.githubusercontent.com/free-audio/clap/main/LICENSE). Bitwig's release notes treat it as a first-class format (links above). The claim that CLAP was announced in June 2022 together with u-he appeared only in a search summary: **UNVERIFIED**.

**Compatibility statements**
- AUM (Kymatica) states compatibility in its App Store listing: "Supports Audio Unit extensions, Inter-App Audio and Audiobus", plus Audiobus state saving. No official Kymatica manual or website page surfaced — [App Store: AUM](https://apps.apple.com/app/id1055636344).
- Steinberg Cubasis: no official compatibility table was found. Feature facts surface through release notes and press, e.g. AUv3 MIDI support arrived in 2.4 behind an in-app purchase (older item) — [CDM](https://cdm.link/newswires/steinberg-adds-auv3-midi-to-their-ios-daw-cubasis/). The Steinberg forum states that the Audio Unit format is iOS-only (not available in Cubasis for Android) — [Steinberg forum](https://forums.steinberg.net/t/no-midi-effects-in-cubasis-android/814627).
- Teenage Engineering's OP-1 manual PDF points readers to `teenage.engineering/guides/op-1` for the latest version (a living online manual) and to a registration page for firmware and warranty — [TE OP-1 manual PDF](https://assets.teenage.engineering/_img/69f248938d433104c4dd1846_original.pdf), [TE registration page](https://teenage.engineering/register/op-1-field).

**Accessibility documentation as a public pattern**
- Ableton documents accessibility in a manual chapter plus a Knowledge Base FAQ. The FAQ names the tested screen readers (VoiceOver on macOS; NVDA, Narrator, JAWS on Windows) and lists known gaps explicitly: the Wavetable modulation matrix, some advanced Operator parameters, browser tagging, automation editing, Clip View modulation, MPE, Max for Live and some third-party plug-ins — [Ableton Live 12 manual: Accessibility](https://ableton.com/en/live-manual/12/accessibility-options-in-live), [Ableton Accessibility FAQ](https://help.ableton.com/hc/en-us/articles/11762577169948).
- W3C WAI says an accessibility statement should contain at minimum (1) a commitment to accessibility for people with disabilities, (2) the standard applied (e.g. WCAG 2.2) and (3) contact information for people who hit problems. It should also be easy to find, e.g. linked from the footer — [W3C WAI: Developing an Accessibility Statement](https://w3.org/WAI/planning/statements). Secondary sources add known limitations, the assistive-technology combinations tested, and an expected response time — [ezud](https://ezud.com/accessibility-statement-what-to-include/) (secondary; the W3C "additional" list was truncated in search and is not confirmed).

**Community preset/patch sharing**
- Patchstorage is a free, community-driven library of patches for music and visual software (Audulus, VCV Rack, Pure Data, SuperCollider, etc.) — [CDM](https://cdm.link/patchstorage-is-a-friendly-site-packed-with-free-visual-and-music-patches/). The ZOIA community had uploaded more than 1,300 free presets there by January 2024 — [Empress Effects blog](https://Empresseffects.com/blogs/empress-blog/five-zoia-patches-we-love). iOS users treat it as a shared library; e.g. its Drambo section was reported as growing quickly — [Loopy Pro forum](https://forum.loopypro.com/discussion/comment/629863/).

**Multilingual static sites (DE/EN)**
- Google's hreflang guidance:
  - Each language version lists every variant, including itself, and the set must be identical on all versions.
  - `x-default` matches any language not listed and is recommended for language-selector or auto-redirecting pages.
  - A translated page is a duplicate only if its main content stays untranslated.
  - HTML `<link>`, sitemap and HTTP-header annotations are equivalent, and combining them adds nothing.
  - [Google Search Central: localized versions](https://developers.google.com/search/docs/specialty/international/localized-versions?authuser=4); [German version](https://developers.google.com/search/docs/advanced/crawling/localized-versions?hl=de).

**SoftwareApplication structured data**
- Google's required-properties table for software-app rich results includes `name`, `offers.price` (a free app uses price 0) and a rating/review property ("you must specify one of the following properties") — [Google Search Central (DE)](https://developers.google.com/search/docs/data-types/software-app?hl=de), [EN](https://developers.google.com/search/docs/appearance/structured-data/software-app?authuser=4). The exact options were cut off in the snippet. That they are `aggregateRating` or `review` is **UNVERIFIED** here.

### Inferences
- The common thread is "ship, then document": dated changelogs and compatibility statements, not forward promises. None of the named vendors surfaced a public dated roadmap. An existing roadmap page is therefore unusual in this peer group and should be visibly separated from the claims page (intent vs. shipped).
- Ableton's "what is not accessible yet" list is the closest peer model for an honest accessibility statement. It fits W3C's minimum (commitment, standard, contact) and adds credibility by naming gaps.
- VCV shows that an open, Git-hosted manifest plus a stable identifier rule (`slug` never changes) is what makes community sharing safe across versions. A preset-sharing scheme without a stable ID rule would break shared patches.
- A site without reviews can still publish valid schema.org `SoftwareApplication` markup. If Google requires a rating/review for the rich result (to be confirmed), the markup will not earn one, and adding ratings or reviews that do not exist would contradict "claim only what ships".
- None of these patterns needs tracking. All of them are static documents, RSS-able changelogs or external platforms (TestFlight, GitHub, a forum).

### Gaps
- No press-kit or media-asset page was found for Teenage Engineering. Moog's press page was not searched. Press-kit conventions remain open.
- No current (2026) Bitwig beta notes, Loopy Pro changelog or Kymatica website content was retrieved.
- Google's review/rating guideline text and its policy on self-serving reviews were not retrieved (the domain was unreachable).
- No examples were found of these vendors publishing a formal compatibility *matrix* (format × host × OS) on their own sites.

## 2. Accessibility law and standards: EAA/BFSG scope and the micro-enterprise exemption, WCAG 2.2 AA, EN 301 549, Apple Accessibility Nutrition Labels, accessible music-software examples

### Takeaway
The EAA has applied since 28 June 2025 (in Germany through the BFSG). A music app is not one of the listed products. It can be in scope as an **e-commerce service** if consumers can conclude a contract through it (e.g. in-app purchases); this is a cumulative, case-by-case test. The micro-enterprise exemption (<10 staff and ≤ €2 m turnover or balance sheet) covers **services only**, never products. EN 301 549 v4.1.1, which includes WCAG 2.2 in full, was published on 2 Sep 2026. It is not yet cited in the Official Journal, so it does not yet give presumption of conformity. Apple's Accessibility Nutrition Labels are voluntary for now, will become required (no date), and Apple tests them against "all common tasks". Accessible music software exists at pro level: Ableton Live 12 (screen readers, with documented gaps), REAPER + OSARA, and Logic with VoiceOver (community-reported).

### Cited Findings
**EAA / BFSG**
- Germany's BFSG transposes the EAA, and its requirements apply from 28 June 2025 — [Orrick (Jul 2025)](https://www.orrick.com/en/Insights/2025/07/Navigating-the-Accessibility-Improvement-Act-Germanys-Implementation), [Buse](https://buse.de/en/blog-en/compliance-en/the-accessibility-reinforcement-act-new-accessibility-requirements-from-28-06-2025/).
- The micro-enterprise definition is fewer than 10 staff and annual turnover or balance-sheet total ≤ €2 m. BFSG §3(3) exempts micro-enterprises that offer or provide **services**. The exemption does not extend to micro-enterprises that manufacture, import or distribute **products** in scope — [Koksal (EAA + BFSG)](https://koksal.av.tr/en/legislation/eu-accessibility-act-eaa-germanys-bfsg/), [Eye-Able](https://eye-able.com/blog/bfsg-who-is-affected).
- There is no general size exemption, and the BMAS application guidelines stress that "accessibility is the rule and exemptions remain the exception" — [Xictron](https://www.xictron.com/en/blog/accessibility-act-exemptions-microenterprises-2026/) (secondary summary of BMAS).
- The disproportionate-burden test is a separate mechanism, and the economic operator carries it out itself — [Orrick](https://www.orrick.com/en/Insights/2025/07/Navigating-the-Accessibility-Improvement-Act-Germanys-Implementation).
- Austria's BaFG differs: micro-enterprises that *exclusively* provide services are fully exempt — [sitebrunch (BaFG)](https://frontend.relaunch.sitebrunch.de/en/accessibility/laws/bafg).
- EAA Art. 3(30) defines "e-commerce services" as services provided at a distance, through websites and mobile device-based services, by electronic means, at the individual request of a consumer, with a view to concluding a consumer contract. All criteria are cumulative.
  - An app that only provides information without purchase functions "arguably falls outside" the definition.
  - An integrated purchase feature can bring the whole service into scope.
  - [Freshfields](https://technologyquotient.freshfields.com/post/102lu76/inclusivity-by-design-the-european-accessibility-act-as-a-new-imperative-for-e).
  - A broader reading covers any online sale of products or services through websites or apps — [RPC](https://www.rpclegal.com/thinking/consumer-brands-and-retail/the-european-accessibility-act-creating-a-more-inclusive-consumer-experience/).
- Primary text (Directive (EU) 2019/882 on EUR-Lex; BFSG on gesetze-im-internet.de): **not retrieved**. Every point above comes from law-firm or vendor summaries.

**Standards**
- EN 301 549 v4.1.1 includes the text of WCAG 2.2 in full — [Wikipedia: EN 301 549](https://en.wikipedia.org/wiki/EN_301_549). The ESOs adopted it on 24 Aug 2026 — [Davis Wright Tremaine (Sep 2026)](https://www.dwt.com/insights/2026/09/european-accessibility-act-ict-standards-update). It was published on 2 Sep 2026 and carries no presumption of conformity until cited in the OJEU, projected "around November 30, 2026" — [Deque](https://www.deque.com/blog/en-301-549-v4-1-1-is-final-what-changed-what-it-means-and-what-you-should-do/). The citation date is a vendor projection.
- WCAG 2.3.1 Three Flashes or Below Threshold (Level A, unchanged in WCAG 2.2): no more than three flashes in any one-second period, or flashes below the general and red flash thresholds.
  - Area test: a 341 × 256 px rectangle on a 1024 × 768 screen approximates a 10° visual field, and flashing must stay within 25 % of it.
  - A general flash is a pair of opposing changes in relative luminance of ≥ 10 % where the darker image is below 0.80.
  - A red flash is any transition to or from saturated red.
  - [W3C Understanding SC 2.3.1 (WCAG 2.2)](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html), [WCAG 2.1 version](https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold).
  - Older WCAG 2.0 material used a "20 cd/m²" definition. Check the current normative definitions before quoting thresholds.

**Apple Accessibility Nutrition Labels (fetched directly from App Store Connect Help)**
- Nine declarable features: VoiceOver, Voice Control, Larger Text (≥ 200 %), Dark Interface, Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion, Captions, Audio Descriptions.
- "Providing these labels will be voluntary to start", but "over time, you'll be required to share accessibility support details to submit new apps and app updates". No date is given.
- Labels show on devices running iOS/iPadOS/macOS/tvOS/visionOS/watchOS 26 or later.
- Criterion: "users should be able to complete all of the common tasks of your app using that feature". Common tasks include primary functionality plus "first launch experience, login, purchase, and settings". Assess each supported device. Guideline 2.3 (accurate metadata) applies, and App Review may contact developers whose labels are "intentionally misleading or harmful".
- Apple also says "Don't attempt to make a custom implementation of the functionality provided by core assistive technologies".
- [App Store Connect Help: Overview of Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels).
- Announced May 2025 — [Apple newsroom via BusinessWire](https://www.businesswire.com/news/home/20250513425545/en/Apple-unveils-powerful-accessibility-features-coming-later-this-year). No 2026 mandatory deadline was found.

**Accessible music-software examples**
- Ableton Live 12 is the first Live version with screen-reader support on macOS and Windows. Blind musician Andre Louis consulted on it — [Ableton manual](https://ableton.com/en/live-manual/12/accessibility-options-in-live), [MusicRadar](https://www.musicradar.com/news/ableton-live-accessibility-revolution). Known gaps are listed in section 1.
- REAPER + OSARA: OSARA "sits between a screen reader like NVDA and" REAPER, on Windows and Mac. The REAPER Accessibility Wiki is the hub for blind users — [REAPER Accessibility Wiki](https://reaperaccessibility.com/), [Perkins School for the Blind](https://www.perkins.org/resource/behind-the-scenes-of-accessible-open-source-software-nvda-and-osara/). An undated community fundraiser says MIDI editing access is still incomplete — [GoFundMe (undated)](https://gofundme.com/f/ciechimusica).
- Logic Pro + VoiceOver: AppleVis community members report it is usable without add-ons, including full mixing, mastering and Dolby Atmos mixing (2025 thread). Professional-studio use is unconfirmed — [AppleVis forum](https://applevis.com/forum/macos-mac-apps/has-any-blind-engineer-mixed-or-mastered-professionally-logic-pro-real-studio). No official Apple Logic/GarageBand VoiceOver documentation was retrieved.

### Inferences
- On the secondary reading, a solo-founder operation below both thresholds is a micro-enterprise. If its app or site is an *e-commerce service*, the BFSG §3(3) service exemption would apply. If it places a *product* in scope, it would not. Whether an App Store app with plugin in-app purchases makes the developer (rather than Apple) the e-commerce service provider was not answered by any source found.
- Even where the exemption applies, WCAG 2.2 AA / EN 301 549 v4.1.1 is the de-facto benchmark: the EAA's coming harmonised standard and Apple's labels both converge on the same feature set. The SC 2.3.1 flash rule is Level A, the floor of any conformance claim.
- Apple's "all common tasks, including first launch, purchase and settings" criterion means a label claim like "VoiceOver supported" is false if one primary task (e.g. a bio-source chooser) is not operable with VoiceOver. Under Guideline 2.3 this is a metadata-accuracy issue, so labels belong under "claim only what ships".

### Gaps
- Exact EUR-Lex wording of Art. 2, Art. 3(30) and Art. 4(5) and BFSG §§1–3 was not retrieved (domain unreachable). The product list (Art. 2(1)) was not verified.
- No authoritative guidance was found on whether in-app purchases inside a third-party app store put the app developer in scope as an e-commerce service provider.
- The OJEU citation of EN 301 549 v4.1.1 is projected, not confirmed.
- Whether Apple has announced a date for mandatory labels after May 2025 is unknown (none found).

## 3. Inclusion through vibration and light: Apple Music Haptics and Core Haptics, vibrotactile music projects, inclusive music organisations, accessible-instrument research

### Takeaway
Apple's **Music Haptics** (iOS 18) plays *pre-authored haptic tracks for known catalogue songs*, matched by ISRC. It cannot apply to live, generated music. An instrument's own output would need **Core Haptics** (custom patterns), which is a separate implementation and a separate claim. Apple also exposes the system **Dim Flashing Lights** setting to apps (iOS 16.4+), a direct hook for light safety. Vibrotactile wearables (Music: Not Impossible, Woojer, SubPac) are used at concerts with Deaf/HoH audiences, but the published evidence is field reports and company material, not peer-reviewed outcome data. Established inclusive-music organisations (Drake Music, Open Up Music, OHMI) and the NIME/ADMI research line give concrete design and partnership models.

### Cited Findings
**Apple platform (fetched directly from developer.apple.com)**
- Music Haptics: "Play haptic tracks along with known music tracks … This feature allows people who are deaf or hard of hearing to enjoy music through tactile feedback". The user enables it in Settings > Accessibility > Music Haptics. "If you play music in your app, you can support haptic feedback for known songs." — [Apple Developer: Music Haptics](https://developer.apple.com/documentation/mediaaccessibility/music-haptics).
- `MAMusicHapticsManager` (Media Accessibility framework, iOS/iPadOS 18.0+) reports whether Music Haptics is on, posts a notification when it changes, and reports "whether a haptic track is currently playing along with the Now Playing item" — [Apple Developer: MAMusicHapticsManager](https://developer.apple.com/documentation/mediaaccessibility/mamusichapticsmanager). `checkHapticTrackAvailability(forMedia matchingCode:)` "checks whether a haptic track is available for the song with the specified International Standard Recording Code (ISRC)" — [Apple Developer](https://developer.apple.com/documentation/mediaaccessibility/mamusichapticsmanager/checkhaptictrackavailabilityformedia(matchingcode:completionhandler:)).
- Consumer requirements: iPhone 12 or later (not iPhone SE 3rd gen), iOS 18 or later, and a network connection — [Apple Support: Music Haptics](https://support.apple.com/en-au/guide/iphone/iphff2ceeb16). In May 2025 Apple announced Music Haptics refinements (e.g. vocals-only haptics) — [heise](https://heise.de/-10386127). A search summary also reported that no third-party app supported Music Haptics as of November 2024; it could not be tied to a specific page (**UNVERIFIED**).
- Core Haptics: "Compose and play haptic patterns to customize your iOS app's haptic feedback". Patterns are built from transient and continuous haptic events, and a pattern can include custom audio — [Apple Developer: Core Haptics](https://developer.apple.com/documentation/corehaptics).
- Dim Flashing Lights: "allows the system to calculate, mitigate, and inform people about flashing lights in a piece of media". Apps can read `MADimFlashingLightsEnabled()` (iOS 16.4+) and observe `kMADimFlashingLightsChangedNotification`. An `MAFlashingLightsProcessor` type exists — [Apple Developer: Flashing lights](https://developer.apple.com/documentation/mediaaccessibility/flashing-lights), [MADimFlashingLightsEnabled()](https://developer.apple.com/documentation/mediaaccessibility/madimflashinglightsenabled()).

**Vibrotactile music projects**
- Music: Not Impossible (Not Impossible Labs with Avnet) debuted in September 2018 at a Life is Beautiful show in Las Vegas for about 200 concertgoers (older item).
  - Hardware: a vest, two wristlets and two anklets with 24 actuators in total. Different instruments map to body regions, e.g. kick drum to anklets and snare to wristlets — [VentureBeat](https://venturebeat.com/arvr/avnet-debuts-vibrating-wearables-that-let-concertgoers-feel-music).
  - The project page instead describes "8 distinct areas of vibration" (the sources conflict on the count) — [Not Impossible project page](https://www.notimpossible.com/projects/music-not-impossible).
  - Deaf singer-songwriter Mandy Harvey gave feedback during development — [DJ Mag](https://djmag.com/news/new-technology-allows-deaf-people-experience-live-music).
  - The vests have since been used at concerts in the UK, US, Brazil, Japan and Australia, including Lincoln Center outdoor performances — [Classic FM (2023)](https://www.classicfm.com/discover-music/live-music-deaf-audiences-vibrating-vests/).
- Woojer vests were field-tested at festivals with Deaf Rave: 141 responses, 72 from Deaf or hearing-impaired respondents. The journal paper was not yet published; the report is marked restricted — [Falmouth University report (2024)](https://repository.falmouth.ac.uk/5529/21/FURR%20LAAA2F%20Report%2004%2009%2024.docx).
- SubPac says it works with artists and non-profits in Deaf/HoH communities (company claim) — [Wikipedia: SubPac](https://en.wikipedia.org/wiki/SubPac_(company)). A KQED feature frames it as sensory substitution — [KQED](https://votersedge.kqed.org/futureofyou/219070/for-deaf-tactile-sound-system-takes-music-beyond-the-vibe).
- No peer-reviewed outcome study of these devices with Deaf/HoH listeners was found.

**Inclusive music organisations**
- Drake Music (UK): national arts charity, Arts Council England National Portfolio Organisation, Disabled-led, working from the Social Model of Disability. It has run accessible music technology for 20+ years and has been a charity since 1993. Its DMLab (since 2010) pairs disabled musicians with technologists to build new instruments (e.g. the Kellycaster guitar) — [Drake Music: history](https://www.drakemusic.org/about-us/history/), [British Council Music](https://music.britishcouncil.org/node/12644), [MIDI Association](https://midi.org/?p=4653).
- Open Up Music (UK): the Clarion can be played with any part of the body, including the eyes, on iPad or Windows. It works with eye-gaze trackers and motion sensors, and note shapes, size, position and colour can be configured. It is the first digital instrument recognised by ABRSM. Open Orchestras runs on it. Per a 2025 article it is now on sale in the UK — [Wikipedia: Clarion](https://en.wikipedia.org/wiki/Clarion_(accessible_musical_instrument)), [Open Up Music: Clarion](https://openupmusic.org/clarion), [Music Mark](https://www.musicmark.org.uk/news/the-clarion-an-award-winning-accessible-instrument/).
- OHMI Trust (UK, founded 2011): enables people with physical impairments to play the instruments they choose. Its competition has three categories (Playable, Concept, Enabling) and was biennial as of 2021. The current schedule is not confirmed (older items) — [Music Teacher magazine (2021)](https://www.musicteachermagazine.co.uk/news/article/one-handed-instrument-trust-celebrates-ten-years-of-inclusive-music-making), [Able Magazine (2018)](https://ablemagazine.co.uk/the-6th-annual-ohmi-competition-will-open-for-entries-between-1st-june-30th-june-2018/).

**Accessible-instrument research (NIME / ADMI)**
- Frid (2019) reviewed accessible digital musical instruments (ADMIs) in *Multimodal Technologies and Interaction*, building on NIME/SMC/ICMC proceedings. It identified control-interface types including tangible, gaze and brain–computer interfaces, and found most ADMIs targeted physical disabilities or children with health conditions (older item) — [Frid 2019, MTI (PDF)](https://mdpi-res.com/d_attachment/mti/mti-03-00057/article_deploy/mti-03-00057-v4.pdf).
- Davanzo & Avanzini (NIME 2020) propose a "dimension space" for evaluating ADMIs and note that systematic design analyses were scarce — [NIME 2020](https://nime.org/proc/nime2020_41/).
- Frid & Ilsar (NIME 2021) surveyed 118 electronic-music makers; about 10 % reported a disability or access requirement — [NIME 2021](https://nime.org/proc/nime21_28).
- The NIME community list circulated a 2026 call for an "Accessible Digital Music" special track at EAI ArtsIT 2026 — [NIME community list](https://groups.google.com/g/nime-community/c/to116VASFeg).

### Inferences
- Music Haptics keys on ISRC-identified catalogue recordings, so Echoel's real-time generated output has no haptic track to match. "Supports Apple Music Haptics" would be a false claim. "Plays its own haptic layer via Core Haptics" would only be true once built.
- `MADimFlashingLightsEnabled()` lets an app honour a system-wide user preference with an API Apple documents. That is verifiable and fits a 3 Hz flash ceiling. Whether to wire it is a product decision.
- The inclusive-music organisations work through co-design (DMLab) and configurable layouts (Clarion). The research literature favours evaluating ADMIs on explicit dimensions rather than general "accessible" labels.
- Vibrotactile access can honestly be described as an access/experience feature, e.g. "feel the music". Outcome language ("improves wellbeing") is unsupported, because no peer-reviewed outcome data was found.

### Gaps
- Peer-reviewed perception studies of phone-based (Taptic Engine) music haptics for Deaf/HoH users were not searched.
- The current OHMI competition dates and Drake Music's current programmes were not confirmed.
- The exact parameters of `MAFlashingLightsProcessor` (whether it processes arbitrary rendered frames or only media playback) were not read.

## 4. Collaboration and community models: open formats/protocols, community libraries, co-creation, German/EU funding programmes (without inventing eligibility)

### Takeaway
Open protocols and open manifests act as collaboration infrastructure, with explicit licences. Ableton Link is GPLv2+ dual-licensed, CLAP is MIT, and the VCV Library uses a public GitHub workflow with ethics and privacy rules. Community libraries such as Patchstorage show multi-app preset sharing without vendor lock-in. On funding, several German/EU programmes are open-ended in theme, but each has hard structural rules (Germany-based professionals, project/event format, own-funds shares, consortia, exclusions for recordings or purely audiovisual work). Most 2026 deadlines have already passed. The Prototype Fund's 2026 round focuses on data security and software infrastructure.

### Cited Findings
**Open protocols and formats as collaboration tools**
- Ableton Link: "Ableton Link is dual licensed under GPLv2+ and a proprietary license" (fetched directly). Proprietary use requires contacting Ableton — [Ableton/link README](https://raw.githubusercontent.com/Ableton/link/master/README.md), [GitHub Ableton/link](https://www.Github.com/Ableton/link).
- The GPL licence blocked inclusion in QLC+ because it is incompatible with QLC+'s Apache licence — [QLC+ forum](https://forum.qlcplus.org/viewtopic.php?p=63352).
- Pure Data's `abl_link~` object is BSD-licensed, and Link's desktop SDK has been public since 2016 (older item) — [CDM](https://cdm.link/2016/11/free-jazz-now-ableton-link-sync-works-pure-data/).
- CLAP: open plugin ABI under the MIT licence, with 1.x binary compatibility (see section 1) — [CLAP README](https://raw.githubusercontent.com/free-audio/clap/main/README.md).
- VCV Library: public GitHub database. Submissions must follow ethics guidelines and must "not harm the user's computer or privacy". Updates are pinned to exact commit hashes — [VCVRack/library README](https://raw.githubusercontent.com/VCVRack/library/v2/README.md).
- Patchstorage: free cross-app patch library (section 1) — [CDM](https://cdm.link/patchstorage-is-a-friendly-site-packed-with-free-visual-and-music-patches/).
- Co-design model: Drake Music's DMLab brings disabled musicians and technologists together to build instruments (section 3) — [Drake Music: history](https://www.drakemusic.org/about-us/history/).

**Funding — Germany / EU (facts as published; eligibility of any specific project NOT assessed)**
- Prototype Fund (DE), per a secondary source:
  - The current round is called "Software Sprint" and runs 1 Oct – 30 Nov 2026.
  - Up to €47,500 per individual and €95,000 per team (max. four people).
  - Focus: open-source solutions in **data security and software infrastructure**.
  - Applicants need German residence and must be self-employed/freelance or released by their employer. Companies, universities and associations cannot apply.
  - Results must be published as open source. Six months of funding, plus an optional four-month second stage.
  - [PNO Innovation (Aug 2026)](https://www.pnoinnovation.com/de/publikationen/open-source-auf-der-ueberholspur/); amount history — [t3n](https://t3n.de/news/open-source-wettbewerb-projekte-ministerium-47500-bmbf-1354230/).
  - The primary site prototypefund.de could not be reached: **verify before relying on this**.
- Kulturstiftung des Bundes, Allgemeine Projektförderung:
  - The jury meets twice a year. Deadlines are 31 July and 31 January; the next is **31 Jan 2027**, and late applications roll to the following round.
  - At least 20 % own and/or third-party funds are required.
  - It funds individual events or event series with visibility in Germany.
  - [Förderdatenbank des Bundes](https://www.foerderdatenbank.de/FDB/Content/DE/Foerderprogramm/Bund/KultStiftBund/1286_allgemeine-foerderrichtlinien.html), [KSB Förderrichtlinien (2024 PDF)](https://kulturstiftung-des-bundes.de/fileadmin/user_upload/downloads/20240711_Foerderrichtlinien_der_Kulturstiftung_des_Bundes.pdf).
  - Berlin's co-financing fund lists 31.01.2027 as the main-funder deadline, with its own deadline on 28.09.2026 (already passed) — [Berlin Kofinanzierungsfonds (Jul 2026)](https://www.berlin.de/sen/kultur/foerderung/foerderprogramme/kofinanzierungsfonds/20260720_hauptfoerderer_kofi-ii-2026.pdf).
  - A "Fonds Digital" programme was not found in 2026 results.
- Musikfonds (DE):
  - It funds current and experimental music production across genres, explicitly including electronic music, free improvisation and sound art.
  - Applicants must work professionally and be based in Germany, with a project focus and connection in Germany.
  - Main project-funding deadlines are 31 March and 30 September. Small projects can get up to €3,000 (total costs ≤ €10,000), from 2026 including public-space projects.
  - It cannot co-fund projects that are already supported by programmes of the federal culture commissioner or by institutions it names (Fonds Soziokultur among them).
  - [Musikfonds Förderregularien (02.03.2026)](https://www.musikfonds.de/sites/default/files/dokument/2026-03/Musikfonds_Foerderregularien_Stand_20260302.pdf), [Fördergrundsätze (08.01.2026)](https://www.musikfonds.de/sites/default/files/dokument/2026-01/Musikfonds%20Foerdergrundsaetze_Stand_20260108.pdf), [Merkblatt Kleinprojekte](https://www.musikfonds.de/sites/default/files/dokument/2026-04/2026_04_27_MF_Merkblatt_Antragstellung_3k.pdf).
- Goethe-Institut Internationaler Koproduktionsfonds (IKF):
  - It funds music, theatre, dance and performance coproductions between partners abroad and in Germany.
  - Applicants live and work **abroad**, plan in dialogue with German partners, and must contact their local Goethe-Institut.
  - It covers up to 75 % of costs (€15,000–30,000) for up to 15 months.
  - Excluded: purely commercial projects, commissions, plain guest performances or tours, pure residencies, **music recordings**, and operating costs.
  - The latest deadlines found (1 Apr 2026; 12 Oct 2026) have passed.
  - [Goethe-Institut Mexiko: IKF](https://www.goethe.de/ins/mx/de/kul/aus/fondo-internacional-.html), [Opportunities for Youth (Aug 2026)](https://opportunitiesforyouth.org/2026/08/29/international-coproduction-fund-ikf-2026-funding-opportunity-for-international-music-dance-and-theatre-projects/).
- Creative Europe Culture, European Cooperation Projects (CREA-CULT-2026-COOP):
  - The deadline was 5 May 2026 (closed). Budget about €60 m, roughly 150 projects.
  - Small-scale track: at least 3 entities from 3 eligible countries, max. 80 % of costs or €200,000.
  - Medium-scale track: at least 5 entities from 5 countries, max. 70 % or €1 m, up to 48 months.
  - Projects with exclusively audiovisual content, or consortia made up exclusively of audiovisual organisations, are not eligible.
  - [BEDA](https://beda.org/news/2026-creative-europe-call-for-european-cooperation-projects/), [Creative Europe Desk Greece](https://creative-europe.culture.gr/en/dimosieytike-i-nea-prosklisi-gia-ta-eyropaika-schedia-synergasias-cooperation-projects/), [Cyprus funding portal](https://www.fundingprogrammesportal.gov.cy/en/call/european-cooperation-projects-en-2026/). A 2027 call was not confirmed.

### Inferences
- In this peer group, a licence is part of the collaboration model, not an afterthought. Link's GPL demonstrably excluded one open-source project (QLC+), while MIT (CLAP) and BSD (`abl_link~`) carry no such restriction. Any "open format" claim should state its licence and its stable-ID rule, as VCV does.
- Most funders named here fund *projects or events* (Kulturstiftung, Musikfonds, IKF, Creative Europe), not *software products*. A grant pitch would have to be framed around an installation, performance or coproduction, or around open-source infrastructure (Prototype Fund). Whether a bio-reactive creative tool fits the Prototype Fund's 2026 "data security / software infrastructure" focus is doubtful on the published focus, and is unverified.
- No programme found is labelled "peace" specifically. The Goethe IKF (international coproduction) and Creative Europe (transnational cooperation) are the intercultural ones, and both require partners rather than a solo applicant.

### Gaps
- No primary page was reachable for the Prototype Fund, Kulturstiftung des Bundes, Creative Europe or the EU Funding & Tenders portal.
- Fonds Soziokultur deadlines, Initiative Musik, and any explicit peace or intercultural-dialogue funding line (e.g. ifa, Robert Bosch Stiftung, Allianz Kulturstiftung) were not researched.
- Co-creation models in installations (audience-as-performer patterns, consent and data handling in public bio-reactive pieces) were not researched.
- OSC/ADM-OSC as collaboration standards were not researched (outside this pass).

## 5. Evidence map for wellbeing language: what may and may not be said about sound, vibration, light and visuals (WHO/ITU safe listening, photosensitive epilepsy, music & stress, vibroacoustics, 40 Hz flicker, binaural beats, HRV biofeedback; HWG and EU MDR)

### Takeaway
The only statements that are safe as **facts** are safety statements: the WHO-ITU safe-listening limits, the WHO venue standard, the WCAG three-flash rule and photosensitive-epilepsy prevalence. Music-and-stress, music-and-sleep and HRV-biofeedback findings exist at meta-analytic or Cochrane level, but they describe structured *interventions*, not this product. They may be cited only as general research context, with the evidence level and a clear "Echoel makes no such claim". Vibroacoustic therapy (sparse evidence), 40 Hz gamma stimulation (pivotal trial unreported, investigational device) and binaural-beat "entrainment" (inconsistent evidence) must not be claimed. Legally, the German HWG bites only when advertising refers to disease, suffering or pathological complaints. Under MDCG 2019-11 rev.1 (June 2025), the *intended purpose stated in marketing* decides whether software is a medical device.

### Cited Findings
**A. Safe listening — [SAFE TO STATE AS A SAFETY FACT]**
- ITU-T H.870 "Guidelines for safe listening devices/systems" was approved in 2019, with version 2 approved on 16 Mar 2022 (WHO liaison) — [ITU work programme H.870](https://www.itu.int/ITU-T/workprog/wp_item.aspx?isn=17494), [WHO: Safe listening devices and systems, a WHO-ITU standard](https://www.who.int/publications-detail/safe-listening-devices-and-systems-a-who-itu-standard).
- Mode 1 (adults) is 80 dB(A) for 40 h/week; Mode 2 (children/sensitive users) is 75 dB(A) for 40 h/week. The standard recommends a weekly "sound allowance", warnings near the limit, and an automatic volume reduction if a warning is not acknowledged — [Hearing Review (Sep 2020)](https://hearingreview.com/hearing-loss/hearing-loss-prevention/risk-factors/standards-for-safe-listening-past-present-and-future), [Canadian Audiologist](https://canadianaudiologist.ca/safe-listening-standards/?output=pdf).
- WHO materials note there is no agreement on acceptable noise-induced hearing-loss risk for children — same sources (secondary). One secondary source states "80 dBA for 80 hours/week", which appears to be a typo.
- WHO Global Standard for Safe Listening Venues and Events (March 2022):
  - Limit: 100 dB LAeq,15 min.
  - Six features: the level limit, monitoring, venue acoustics and sound systems, hearing protection, quiet zones, and staff training and information.
  - First major implementation: Serendipity Arts Festival, Goa (Dec 2023).
  - [WHO feature story](https://www.who.int/news-room/feature-stories/detail/who-hearing-guidelines-implemented-at-major-arts-festival), [World Hearing Day infographic](https://worldhearingday.org/wp-content/uploads/2022/03/MLS_WHD_Infographic_WHO-LOGO_aw.pdf), [ProSoundWeb](https://www.prosoundweb.com/live-event-sound-levels-rising-above-the-insidious-undercurrent-of-aural-incapacitance/).
  - A "≤ 70 dB quiet zone" figure comes from a US professional statement, not confirmed as WHO's — [ENT Net](https://www.entnet.org/resource/mitigation-of-noise-induced-hearing-loss-at-music-venues/).
- A WHO-ITU safe-listening standard for video games and esports followed (2025; exact date unconfirmed) — [Hearing Review](https://hearingreview.com/hearing-loss/hearing-loss-prevention/music-entertainment/who-itu-release-safe-listening-standard-for-video-games-esports).

**B. Light and flicker safety — [SAFE TO STATE AS A SAFETY FACT]**
- WCAG 2.3.1: no more than three flashes in any one-second period, or below the general and red flash thresholds (Level A; details in section 2) — [W3C Understanding SC 2.3.1](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html).
- Photosensitive epilepsy affects about 3 % of people with epilepsy (UK Epilepsy Society 2025 factsheet; its 2023 edition said 5 %). Rates of 3–30 Hz are the most common triggers, some people react up to 60 Hz, and sensitivity below 3 Hz is uncommon — [Epilepsy Society factsheet (Apr 2025)](https://epilepsysociety.org.uk/sites/default/files/2025-04/PhotosensitiveepilepsyApril2025.pdf), [July 2023 edition](https://epilepsysociety.org.uk/sites/default/files/2023-07/PhotosensitiveepilepsyJuly2023.pdf).
- Epilepsy Action gives 3–5 % of people with epilepsy and about 1 in 4,000 people overall, with 10–25 Hz as the most likely trigger range — [Epilepsy Action](https://www.epilepsy.org.uk/?p=1833). An Epilepsy Foundation-based review (Epilepsia 2022) says visual stimuli can provoke seizures in up to 1 in 4,000 persons — [Visually sensitive seizures: updated review](https://profiles.wustl.edu/en/publications/visually-sensitive-seizures-an-updated-review-by-the-epilepsy-fou/).
- The Apple system setting Dim Flashing Lights exists and is readable by apps (section 3) — [Apple Developer](https://developer.apple.com/documentation/mediaaccessibility/flashing-lights).

**C. Music and stress — [MAY BE CITED AS RESEARCH, WITH CAVEAT]**
- de Witte et al. 2020 (*Health Psychology Review*): two multilevel meta-analyses of 104 RCTs, 327 effect sizes and 9,617 participants. Music interventions showed d = 0.380 for physiological and d = 0.545 for psychological stress-related outcomes; heart rate had the largest physiological effect (d = 0.456) (older item) — [PubMed 31167611](https://pubmed.ncbi.nlm.nih.gov/31167611/).
- de Witte et al. (online 2020 / print 2022): music *therapy* (therapist-led) for stress, 47 studies, d = 0.723 (95 % CI 0.51–0.94). The authors separate therapist-led "music therapy" from listening-based "music medicine" — [PubMed 33176590](https://pubmed.ncbi.nlm.nih.gov/33176590/).
- Caveat: these pool heterogeneous clinical and non-clinical interventions. They say nothing about a specific app.

**D. Music and sleep — [MAY BE CITED AS RESEARCH WITH CAVEAT; "treats insomnia" MUST NOT be claimed]**
- Cochrane review CD010459 (Jespersen et al., 2022 update; searches to 31 Dec 2021):
  - Moderate-certainty evidence that music listening improves *subjective* sleep quality in adults with insomnia.
  - Low certainty for objective measures (sleep-onset latency, total sleep time, efficiency).
  - Low or very-low certainty for anxiety and quality of life.
  - No included study reported adverse events.
  - [Cochrane summary](https://www.cochrane.org/CD010459/SLEEP_music-for-insomnia-adults), [Cochrane podcast](https://www.cochrane.org/podcasts/10.1002/14651858.CD010459.pub3).

**E. HRV biofeedback — [MAY BE CITED AS RESEARCH WITH CAVEAT]**
- Goessl, Curtiss & Hofmann 2017 (*Psychological Medicine*): 24 studies, 484 participants. Pre-post Hedges' g = 0.81 and g = 0.83 versus control on self-reported stress and anxiety. The authors call for more well-controlled trials (older item) — [Cambridge Core](https://www.cambridge.org/core/journals/psychological-medicine/article/effect-of-heart-rate-variability-biofeedback-training-on-stress-and-anxiety-a-metaanalysis/A839E9C968E54774DF5C8FB186764EF0), [OpenBU](https://open.bu.edu/handle/2144/26911).
- A 2025 meta-analysis of *remote* HRV biofeedback (18 studies, 1,352 participants) reports medium effects on depression and on HRV (different scope) — [Applied Psychophysiology and Biofeedback (2025)](https://link.springer.com/article/10.1007/s10484-025-09750-w).
- Caveat: the evidence is for structured training protocols. A music instrument that *reads* HRV is not an HRV-biofeedback training intervention.

**F. Vibroacoustic therapy — [MUST NOT BE CLAIMED; may be named only as an under-evidenced research area]**
- Kantor et al. 2022 (BMJ Open), a scoping review on VAT for pain in adults: 20 of 430 records included. Research "is too sparse to identify properties of VAT that are beneficial for pain management". Protocols were highly heterogeneous, with 40 Hz predominant, and the authors call for RCTs — [BMJ Open](https://bmjopen.bmj.com/content/12/4/e046591), [PubMed 35383053](https://pubmed.ncbi.nlm.nih.gov/35383053/).
- No systematic review grading VAT evidence overall was found.

**G. 40 Hz gamma sensory (light + sound) stimulation — [MUST NOT BE CLAIMED]**
- Cognito Therapeutics' HOPE pivotal trial of Spectris AD:
  - 670 participants at 70 US sites; randomised, double-blind, sham-controlled.
  - 12-month treatment phase plus a 12-month open-label extension; primary endpoint ADCS-ADL + MMSE composite in mild-to-moderate Alzheimer's.
  - Enrolment completed in July 2025. The device is "investigational and is not currently available for commercial use".
  - [BusinessWire (Jul 2025)](https://www.businesswire.com/news/home/20250701375054/en/Cognito-Therapeutics-Completes-Enrollment-in-HOPE-Pivotal-Study-of-Spectris-AD-Therapy-for-the-Treatment-of-Patients-with-Alzheimers-Disease).
- As of March 2026, topline data was "expected later this year", with commercialisation anticipated in 2027 — [HLTH (Mar 2026)](https://hlth.com/insights/news/cognito-therapeutics-raises-105m-series-c-led-by-morningside-ventures-to-advance-spectris-platform-for-alzheimer-s-2026-03-06).
- No HOPE results were found as of 19 Oct 2026. The earlier OVERTURE figures (e.g. a "76 % reduction in cognitive decline") are company-reported feasibility data — [Medical Design & Development](https://www.medicaldesigndevelopment.com/topics/devices/news/22366378/cognitos-headset-reduces-brain-atrophy-for-alzheimers-patients).
- Safety cross-reference: 40 Hz lies inside the 3–60 Hz photosensitive trigger range (B above), and a 40 Hz visual flicker would exceed the WCAG 2.3.1 three-flash limit.

**H. Binaural beats / "brainwave entrainment" — [MUST NOT BE CLAIMED]**
- Ingendoh, Posny & Heine 2023 (PLOS ONE), a systematic review of 14 studies on entrainment: 5 supported, 8 contradicted and 1 was mixed. Methods varied widely — [PMC10198548](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10198548/).
- Pooled outcome studies are mixed. A 2019 meta-analysis (22 studies) reported g = 0.45 across memory, attention, anxiety and analgesia (search summary; primary not opened, **UNVERIFIED** URL). A 2024 *Applied Sciences* review of 12 studies called anxiety/depression effects "promising" — [DOAJ record](https://doaj.org/article/953eee687e1245db925bcbebd4ac3276).

**I. German advertising law (HWG) — legal frame**
- HWG §1(1) No. 2 covers "other means, procedures, treatments and objects" only insofar as the advertising refers to the detection, elimination or alleviation of diseases, suffering, bodily injury or pathological complaints — [GSD article on HWG reform (PDF)](https://www.shiatsu-gsd.de/wp-content/uploads/gsd-article-pdfs/geldrosen_reform_des_heilmittelwerbegesetzes_no_74.pdf), [omsels.info: HWG scope](https://www.omsels.info/?p=4575).
- A practice source gives examples: "lindert Rückenschmerzen" is in scope, while "unterstützt den Stressabbau" names no disease and is outside the HWG — [iww.de](https://www.iww.de/pp/archiv/das-heilmittelwerbegesetz-gestaltung-von-werbeanzeigen-das-muessen-sie-inhaltlich-beachten-f34800). Where the boundary between health and disease lies is the contested point — [omsels.info](https://www.omsels.info/die-verbote-oder-was-darf-ich-nicht/2-heilmittelwerbegesetz/11-hwg-werbung-ausserhalb-der-fachkreise/nr-7-erweckung-von-angstgefuehlen).
- HWG §3 bans misleading advertising, notably attributing effects a procedure or means does not have. Claims must match the state of "gesicherte wissenschaftliche Erkenntnis", and the mere *risk* of misleading suffices — [gesetze-im-internet.de §3 HWG](https://www.gesetze-im-internet.de/heilmwerbg/__3.html), [lxgesetze §3 HWG](https://lxgesetze.de/hwg/3).
- Case law: KG Berlin, 3 Dec 2024, 5 U 9/24, held health advertising for osteopathy misleading because it was not scientifically secured to the required extent — [Rheinisches Ärzteblatt 04/2025 (PDF)](https://aekno.de/fileadmin/user_upload/RheinischesAerzteblatt/Ausgaben/2025/2025.04.025.pdf). OLG Celle, 3 Feb 2022, 13 U 75/21: health-related claims suggest a causal link between use and health — [RA Plutte](https://www.ra-plutte.de/gesundheitsbezogene-werbung/).
- No court decision about a wellness *app* specifically was found.

**J. EU MDR borderline for wellness software — legal frame**
- MDCG 2019-11 rev.1 was published on 17 Jun 2025. The intended purpose is the basis for qualification and classification, irrespective of platform. The revision clarifies borderline cases for wellness apps — [Emergo by UL](https://www.emergobyul.com/news/european-revision-primary-software-guidance-mdcg-2019-11-revision-1-small-changes-meaningful), [NSF](https://www.nsf.org/au/en/life-science-news/mdcg-2019-11-rev-1-important-updates-for-medical-device-software-mdsw-manufacturers).
- Products with potential medical benefit may be deliberately restricted to lifestyle or wellbeing if that purpose is "clear, consistent and traceable". A disclaimer cannot remove medical-device status where non-medical use is not readily possible — [Forvis Mazars Healthcare newsletter 3/2025](https://www.forvismazars.com/de/de/ueber-uns/aktuelles/presse-medien/newsletter/newsletter-healthcare/newsletter-healthcare-3-2025/klassifizierung-medizinischer-software).
- General wellness/lifestyle apps without medical claims are "usually not a medical device" — [OpenRegulatory explainer](https://openregulatory.com/mdcg/mdcg-2019-11) (commercial explainer with an inconsistent date stamp).
- Companion guidance MDCG 2025-4 covers the responsibilities of app-platform providers — [Osborne Clarke](https://www.osborneclarke.com/insights/eu-confirms-app-stores-and-developers-are-subject-medical-device-laws).

### Inferences
Classification table derived from the findings above (the classifications are mine; the sources are the findings):

| Statement type | Class | Basis |
|---|---|---|
| "Keep weekly listening below WHO-ITU H.870 limits (80 dB(A) / 40 h adults)"; "venues: WHO 100 dB LAeq,15 min" | SAFETY FACT | A |
| "Visuals are limited to ≤ 3 flashes per second (WCAG 2.3.1)"; "about 3 % of people with epilepsy are photosensitive; 3–30 Hz is the most common trigger range" | SAFETY FACT | B |
| "Bio data is for self-observation, not diagnosis" (existing project law) | SAFETY FACT (disclaimer) | — |
| "Meta-analyses of music interventions report small-to-moderate reductions in stress-related outcomes (de Witte 2020)", plus an explicit "Echoel is not such an intervention and makes no such claim" | RESEARCH, WITH CAVEAT | C |
| "A Cochrane review found moderate-certainty evidence that music listening improves subjective sleep quality in adults with insomnia" | RESEARCH, WITH CAVEAT (never transferred to the product) | D |
| "HRV-biofeedback training protocols show large self-reported stress effects in small trials (Goessl 2017)" | RESEARCH, WITH CAVEAT | E |
| Echoel "reduces stress / anxiety", "improves sleep", "treats insomnia / pain / depression" | MUST NOT CLAIM (disease reference → HWG §1/§3; intended purpose → MDR) | C–E, I, J |
| Vibroacoustic or vibration "therapy" effects | MUST NOT CLAIM | F |
| 40 Hz light/sound "for the brain", cognition, Alzheimer's | MUST NOT CLAIM (investigational, no pivotal result; also a flash-safety conflict) | G, B |
| "Brainwave entrainment", binaural-beat states, "healing frequencies" | MUST NOT CLAIM (inconsistent evidence; esoteric terms also banned by project law) | H |

- The HWG line runs at *disease*. Non-disease wording ("supports relaxation") is outside HWG per one practice source. It is still exposed to the general misleading-advertising rules (UWG §5, not researched here) and, if framed as a purpose, to MDR intended-purpose analysis. "Outside HWG" therefore does not mean "safe to claim".
- Under MDCG 2019-11 rev.1 a disclaimer does not cure a medical intended purpose, so a website that describes health outcomes would undercut an in-app "not a medical device" disclaimer. The marketing text *is* the intended-purpose evidence.
- The 40 Hz research line is the one most likely to be pitched to the project (light + sound + "brain"), and it conflicts directly with the 3 Hz flash ceiling. It is excluded on two grounds: no evidence, and safety.

### Gaps
- None of the WHO, ITU, Cochrane, PubMed or EUR-Lex primary pages could be opened. Figures come from search summaries citing those URLs. Re-verify every number before public use.
- No source was retrieved for UWG §5 / UCPD treatment of non-disease wellbeing claims, or for HWG §11 (e.g. testimonials, "Empfehlungen").
- No systematic review was found on music *made by the listener* (active music-making with an instrument) versus listening, which is the closer analogue to an instrument.
- No 2026 systematic review or Cochrane review of vibroacoustic therapy was found. Whether HOPE topline results were released between March and October 2026 is unknown (none found).
- MDR Annex XVI (non-medical products, e.g. brain-stimulation equipment) was not checked for relevance to light or sound stimulation products.

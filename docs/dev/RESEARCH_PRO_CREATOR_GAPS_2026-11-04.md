# Was die Marktführer 2026 haben und Echoel Studio nicht — Recherche vom 2026-11-04

Ich habe im Repo nur gelesen, nichts geändert. Jede Tatsache hat eine Quelle [n]. **ANNAHME** heißt: geschätzt, nicht belegt. Was die Plattform-Recherche vom selben Tag (`docs/dev/RESEARCH_PLATFORMS_XR_AI_REALTIME_2026-11-04.md`) schon klärt, wiederhole ich nicht: MCP, IAMF, CLAP/VST3, RAVE, Quantum.

**Gemessene Lücken im Repo** (Suche über `EchoelStudio/**/*.swift` mit Wortgrenzen):
- `import AppIntents` kommt nirgends vor.
- Kein ProRes, LUT, NDI, Ableton Link, DAWproject, OTIO, Atmos/ADM-BWF, keine Untertitel/Transkription, kein SoundAnalysis.
- Video-Export ist nur H.264 oder HEVC mit AAC in MP4 (`App/Media/VideoExport.swift:9`).
- Lautheits-Ziele gibt es schon: −14, −16, −23 LUFS und Peak −1 dBTP (`Core/Sources/EchoelCore/ExportLoudness.swift`).
- MIDI-Datei-Import gibt es (`Core/Sources/EchoelCore/MIDIFileImport.swift`).

## 1. Lückentabelle

Abkürzungen: Fit = passt zum Echoel-Gesetz (on-device, ehrlich, kein Song aus Prompt, keine Konten). Aufwand S/M/L.

| # | Fähigkeit | Wer hat es (Beleg) | Echoel | Fit | Aufwand | Wert |
|---|---|---|---|---|---|---|
| 1 | Stem-Trennung (Gesang/Drums/Bass/Rest) | Logic, braucht M1+ [1] · Live 12.3 über Music AI [2] · Cubase 15 Pro [3] · Koala [4] · FL 21.2 [5] | fehlt | ja, wenn on-device und die Lizenz sauber ist (§3) | L | sehr hoch |
| 2 | KI-Begleiter (Bass-, Keys-, Drum-Player) | Logic Session Players [1] | fehlt | **Konflikt:** keine generierten Noten. Erlaubt sind regelbasierte Generatoren wie Cubase Melodic Pattern Sequencer [3] oder Live Patterns/Sting [2] | M | mittel |
| 3 | Mastering-Assistent | Ozone 12 Master Assistant, Stem EQ, Unlimiter [6] · Resolve 20 AI Audio Assistant [7] · FL [5] | teilweise (Lautheits-Ziele) | ja, als messende DSP-Analyse mit erklärtem Vorschlag | M | hoch |
| 4 | Sättigung im Hardware-Stil | Logic ChromaGlow [1] | ANNAHME: teilweise (~18 Effekte) | ja | S | mittel |
| 5 | A/B-Zustände pro Gerät | Live 12.3 [2] | fehlt | ja | S | mittel |
| 6 | Clip-Aliase, Automations-Clips | Bitwig 6 [8] | fehlt | ja | M | mittel |
| 7 | Sampler: Onset-Slicing, Tonhöhen-Analyse, Granular-Modus | Bitwig 6.1 [8] | teilweise (Break-Slicer in Arbeit) | ja | M | hoch |
| 8 | Klangsuche in der Bibliothek | Live 12.3 + Splice „search with sound" [2] | fehlt | ja, nur für die lokale Bibliothek, ohne Splice-Konto | M | hoch |
| 9 | ADM-BWF-/Atmos-Export | Logic (Mac) [1] · Vertrieb verlangt 48 kHz/24 Bit, 8–128 Kanäle, höchstens 118 Objekte [9] | fehlt | ja (offener Standard) | M | hoch |
| 10 | Projektaustausch zwischen DAWs | DAWproject: Bitwig, Studio One, Cubase 14, Cubasis [10] | fehlt | ja (MIT) | M | sehr hoch |
| 11 | Export als Ableton Live Set | Koala [4] | fehlt | ja, aber das Format ist undokumentiert [11] | M | hoch |
| 12 | Timeline-Austausch mit Schnittprogrammen | Resolve liest AAF, XML, FCP XML, EDL, OTIO, DRT [12] | fehlt | ja | M | sehr hoch |
| 13 | ProRes und Video mit Alpha | Resolume DXV mit Alpha [13] · Profi-Schnitt-Standard (ANNAHME) | fehlt (nur MP4) | ja | S–M | hoch |
| 14 | Automatische Farbe / Farbangleich | Premiere wandelt Log/RAW automatisch nach SDR/HDR [14] · Core Image Auto-Enhance [15] | fehlt | ja (on-device) | M | hoch |
| 15 | Untertitel, Transkript, Übersetzung | CapCut [16] · Resolve Animated Subtitles [7] · Premiere in 27 Sprachen [14] · Descript Schnitt per Text [17] | fehlt | ja, mit SpeechAnalyzer (iOS 26) [18] | M | hoch |
| 16 | Schnitt auf den Beat | Resolve AI Detect Music Beats [7] · CapCut Beat Sync [16] | fehlt | ja, und es ist ein **Vorteil**: Echoel kennt sein Tempo exakt und braucht dafür kein Modell | S | hoch |
| 17 | Motiv-Maske / Freistellen | Resolve Magic Mask v2 [7] · Premiere Object Mask [19] · FCP iPad Scene Removal Mask [20] | fehlt | ja (Vision, on-device, ANNAHME) | M | mittel |
| 18 | Automatischer Bildausschnitt fürs Format | FCP iPad Auto-Crop [20] | fehlt | ja | M | mittel |
| 19 | Suche im eigenen Material nach Inhalt | Premiere Media Intelligence, „entirely on the device" [14] | fehlt | ja | M | mittel |
| 20 | Multicam-Wechsel | Resolve SmartSwitch [7] · FCP iPad mit 4 Winkeln [20] | fehlt | ja | L | niedrig bis mittel |
| 21 | Mapping, Edge-Blend, NDI, Syphon, SMPTE | Resolume [13] · TouchDesigner: DMX über POPs, ST2110 [21] | teilweise (Art-Net/sACN/OSC aus) | ja; NDI braucht ein proprietäres SDK (ANNAHME) | L | mittel |
| 22 | Fixture-Bibliothek, Cues, OS2L, Link | Lightkey: über 7000 Profile, Art-Net/sACN, MIDI Clock, Ableton Link [22] | teilweise | ja | M | hoch für Installationen |
| 23 | Ableton Link | Koala [4] · Lightkey [22] | fehlt | Council-Frage (C++, GPLv2 oder Lizenz) | M | hoch |
| 24 | Eigene Bedienoberflächen | Loopy Pro: Buttons, Dials, XY-Pads, Seiten [23] | fehlt | ja | M | hoch für Live |
| 25 | Siri, Kurzbefehle, Spotlight, Action-Taste | App Intents [24] · neue Siri mit iOS 26.4 im März 2026 [25] | fehlt | ja | S–M | hoch |
| — | Gen-Video, Stimmklon, Song aus Prompt | CapCut [16] · Resolve VoiceConvert [7] · Premiere Generative Extend [14] · Suno/Udio | — | **REJECT** (Produktgesetz; Rechtslage siehe unten) | — | — |
| — | Social-Cloud, Konten | BandLab | — | REJECT (keine Konten); das ersetzen Share-Sheet und Jam | — | — |

**Suno/Udio – Rechtslage**
- Oktober 2025: Universal Music Group hat seine Klage gegen Udio beigelegt und einen Lizenzvertrag geschlossen [26].
- November 2025: Warner Music hat sich mit Suno geeinigt [26].
- Sony klagt weiter gegen beide. Sammelklagen unabhängiger Künstler laufen noch. Ob das Training „Fair Use" ist, bleibt gerichtlich offen [26].
- Folge: kein Prompt-Song im Produkt. Das ist kein Geschmack, sondern ein rechtliches und ein Vertrauensrisiko.

**Cubase 16:** Ich habe keine Ankündigung gefunden. Der Stand ist Cubase 15 vom 5. November 2025 [3].

**Nicht vertieft:** Reaper, GarageBand, Drambo, AUM, MadMapper, grandMA und die Apps von Teenage Engineering. Zu ihnen steht hier keine Aussage.

## 2. Export-Wege in Profi-Pipelines

| Ziel | Format | Offen? | Empfehlung |
|---|---|---|---|
| **DaVinci Resolve** | **OTIO / OTIOZ** | Apache-2.0 [27]. Resolve importiert und exportiert OTIO, auch in der Gratis-Version [28] | **Zuerst bauen.** Schnitt, Clips und Medien-Verweise, als reiner Swift-Writer (das Schema ist JSON) |
| Resolve, Final Cut | FCPXML | Resolve importiert FCP XML [12]. Apple-dokumentiert, frei schreibbar (ANNAHME) | als Zweites |
| Resolve, Avid, alle | EDL (CMX 3600) | offen, trivial (ANNAHME) | Notlösung, S |
| Resolve | .drp / .drt | proprietär | nicht bauen |
| Avid, Pro Tools, Logic | AAF / OMF | Das AAF-SDK steht unter einer eigenen „AAF SDK Public Source License", Version 1.1.6 [29]. Schweres C++ (ANNAHME) | nein; stattdessen Stems mit Markern |
| Bitwig, Studio One, Cubase, Cubasis | **DAWproject** | MIT. ZIP mit XML; enthält Spuren, Arrangement- und Launcher-Clips, Fades, Warp, Automation, Plugin-Zustand [10] | **ja.** Das Echoel-Song-Format passt fast eins zu eins |
| Ableton Live | .als | gzip-XML, nur beobachtet, nicht spezifiziert [11]. Koala exportiert es trotzdem [4] | später, mit einem Golden-Test pro Live-Version |
| Logic | ADM BWF oder Stems | Logic importiert ADM BWF (ANNAHME). Stems gehen überall | Stems mit BWF-Marker/Cue-Chunk und Tempo im Dateinamen (ANNAHME: iXML/Cue) |
| Atmos-Vertrieb | ADM BWF (axml/chna) | Dolby-Profil öffentlich [30]; 48 kHz/24 Bit, 8–128 Kanäle, höchstens 118 Objekte [9] | ja, offline und deterministisch aus `SpatialScene` |
| Videoschnitt mit Alpha | ProRes 4444, HEVC mit Alpha | AVFoundation auf iOS (ANNAHME; die Apple-Seite war für mich gesperrt) | Field-Visuals als Ebene mit Alpha |
| MIDI 2.0 | MIDI Clip File (SMF2) | Spezifikation 2023 veröffentlicht, frei herunterladbar [31] | Export neben SMF 1, S–M |

## 3. KI, die zum Gesetz passt

- **Auto-Mix/Master-Assistent (on-device):** Er misst Lautheit, True Peak, Spektral-Neigung, Stereo-Breite und Maskierung zwischen Spuren. Daraus schlägt er EQ-, Kompressor- und Limiter-Werte vor, sichtbar als Zahlen und als ein Undo-Schritt. Das ist dieselbe Idee wie Ozone 12 Master Assistant mit wählbaren Modulen und Lautheits-Zielen [6]. Das Wort „KI" fällt nur, wenn wirklich ein Modell läuft. Sonst heißt es „Analyse".
- **Stem-Trennung:**
  - Bei den HTDemucs-Gewichten ist die Lizenz ungeklärt. Das Model-Card-Tag sagt MIT. Auf Hugging Face fragen mehrere Leute nach kommerzieller Nutzung in Apps, und der Maintainer hat nicht geantwortet [32][33].
  - Folge: nicht ausliefern, bis eine schriftliche Freigabe da ist. Alternativen: ein eigenes Modell auf lizenzierten Daten, oder Lizenzieren (z. B. Music AI, wie Ableton [2]). Beides ist Founder-Entscheidung.
- **Audio→MIDI:** Basic Pitch steht unter Apache-2.0 und liegt schon als CoreML-Modell vor [34]. **Passt sofort**, offline auf einem Hintergrund-Thread, das Ergebnis kommt als `Command`.
- **Auto-Farbe und Farbangleich zwischen Takes:**
  - Basis: Core Image Auto-Adjust (Enhance, Level, Crop) [15].
  - Dazu ein eigener Angleich über Statistik-Transfer im Lab-Raum auf Metal, eine Referenz-Aufnahme pro Szene. ANNAHME: ohne Modell, deterministisch, also ehrlich „Farbangleich", nicht „KI".
- **Smart Tagging und Suche:** SoundAnalysis erkennt eingebaut über 300 Klassen, on-device, seit iOS 15 [35]. Dazu kommen eigene Merkmale (BPM, Tonart, Helligkeit) für die lokale Bibliothek.
- **Untertitel und Liedtext:** SpeechAnalyzer (iOS 26). Im Test über 34 Minuten Material war es etwa 55 % schneller als Whisper Large-v3, bei gleicher Qualität [18].
- **Sprachsteuerung — App Intents statt eigenem Sprachmodell:**
  - App Intents machen Aktionen für Siri, Kurzbefehle, Spotlight, die Action-Taste und Widgets sichtbar [24]. Die Apple-Doku hat inzwischen einen eigenen Abschnitt „Siri AI Developer Preview" [24].
  - Die neue Siri kam mit iOS 26.4 im März 2026 und kann Aktionen in Fremd-Apps ausführen. Zum Start nutzten das noch wenige Apps [25]. Wer früh dabei ist, fällt auf.
  - **Eigenes Modell züchten:**
    - Apples Adapter-Training (LoRA) braucht einen Mac mit mindestens 32 GB, 100 bis 5000+ Beispiele und ein Entitlement. Jeder Adapter ist etwa 160 MB groß und gilt nur für genau eine Modellversion [36].
    - Vor allem: **Toolkit 26.0.0 ist laut Apple die letzte Version und nicht kompatibel mit OS 27** [36].
    - Ein eigenes LLM von Grund auf kostet Daten, GPU-Monate und Pflege und schlägt das Systemmodell auf dem iPhone nicht (ANNAHME).
  - **Empfehlung:** Den `CommandCatalog` einmal als App Intents und App Entities veröffentlichen. Der Foundation-Models-Assistent bleibt, mit Tool-Calling. Kein Adapter und kein eigenes LLM. Neu prüfen nach der WWDC 2027.

## 4. Top 25 in Wellen (höchstens 5 Teams parallel, eine Scheibe pro Team)

**Welle 1 — schnelle Gewinne, S**
1. App Intents für den Command-Katalog: „Spiel Szene 2", „Exportiere Stems", „Tempo 120", Kurzbefehle, Spotlight.
2. Timeline-Marker im Song-Format, mit Export als BWF-Cue und MIDI-Marker.
3. Video-Schnitt auf das Takt-Raster (Magnet auf Takt/Beat).
4. A/B-Zustände für jedes Gerät.
5. EDL-Export (CMX 3600) als erster Resolve-Weg.

**Welle 2 — Interop, M**
6. OTIO/OTIOZ-Export für Resolve [28].
7. DAWproject-Export, danach Import [10].
8. Export als ProRes 4444 und HEVC mit Alpha.
9. Untertitel mit SpeechAnalyzer, als Spur, Burn-in und SRT.
10. Audio→MIDI mit Basic Pitch [34].

**Welle 3 — Profi-Ausgabe, M**
11. ADM-BWF-Export für Atmos, deterministisch offline [9][30].
12. Mix/Master-Assistent mit Messwerten [6].
13. Farbangleich zwischen Takes plus Auto-Enhance [15].
14. Personen-/Motiv-Maske für Video-Ebenen (Vision, ANNAHME).
15. Lokale Klangsuche (SoundAnalysis [35] plus eigene Merkmale).

**Welle 4 — Ökosystem, M–L, teils Founder- oder Council-Entscheidung**
16. Stem-Trennung mit sauberer Lizenz (Founder: Lizenz oder eigenes Modell).
17. Ableton-Live-Set-Export mit Golden-Tests [11].
18. Ableton Link (Council: C++, Lizenz).
19. Fixture-Bibliothek plus Cue-Liste für Licht [22].
20. MTC/LTC-Timecode-Ausgang für Resolume und Licht [13].

**Welle 5 — Bühne und Tiefe, M–L**
21. Eigene Bedienoberflächen für Live [23].
22. Automatischer Bildausschnitt für 9:16/1:1 [20].
23. Clip-Aliase und Automations-Clips [8].
24. Sampler-Ausbau: Onset-Slicing, Tonhöhen-Analyse, Granular [8].
25. Export als MIDI 2.0 Clip File [31].

**Bewusst nicht dabei:** Song aus Prompt, Stimmklon, Gen-Video, Konten oder Cloud-Pflicht, Multicam (wenig Wert), eigenes LLM oder Adapter (siehe §3), NDI (proprietär; wieder ansehen, wenn Installationen es verlangen).

**Echoels eigener Vorsprung, den niemand in der Liste hat:** ein Tempo und eine Uhr für Ton, Video, Licht und Raum, alles on-device und offen (OSC, ADM-OSC, sACN). Die Wellen 1 bis 3 machen daraus einen sichtbaren Vorteil: Beat-genauer Schnitt, Marker überall und ein Resolve- und DAW-Export, der die Zeitachse eins zu eins mitnimmt.

## Quellen
1 https://www.macrumors.com/2025/11/04/apple-releases-logic-pro-ai-update/ · 2 https://www.musicradar.com/music-tech/stem-separation-splice-integration-ableton-is-playing-catch-up-with-live-12-3-but-its-best-new-features-are-the-ones-hidden-beyond-the-headlines · 3 https://www.attackmagazine.com/news/cubase-15-released-heres-whats-new/ · 4 https://apps.apple.com/gb/app/koala-sampler/id1449584007 · 5 https://www.image-line.com/fl-studio-news/fl-studio-2025-whats-new-2 · 6 https://www.attackmagazine.com/news/izotope-announces-ozone-12-with-new-stem-eq-bass-control-and-unlimiter/ · 7 https://www.provideocoalition.com/davinci-resolve-20-released/ · 8 https://synthanatomy.com/2026/03/bitwig-studio-6.html · 9 https://support.fuga.com/hc/en-us/articles/39292313383060-Dolby-Atmos-File-Requirements · 10 https://github.com/bitwig/dawproject · 11 https://www.nationalarchives.gov.uk/pronom/fmt/1463 · 12 https://www.steakunderwater.com/VFXPedia/__man/Resolve18-6/DaVinciResolve18_Manual_files/part1410.htm · 13 https://www.toolfarm.com/?p=7598 · 14 https://petapixel.com/2025/04/02/adobe-premiere-pro-update-adds-4k-generative-extend-new-search-panel-and-much-more · 15 https://developer.apple.com/documentation/coreimage/ciimageautoadjustmentoption.md · 16 https://freeacademy.ai/blog/capcut-ai-features-complete-guide-review-2026 · 17 https://www.descript.com/video-editing · 18 https://www.gigazine.net/gsc_news/en/20250619-apple-speech-analyzer · 19 https://www.smartprix.com/bytes/adobe-kicks-off-2026-with-new-ai-powered-features-for-premiere-pro/ · 20 https://www.provideocoalition.com/final-cut-pro-for-ipad-vs-mac-whats-the-difference/ · 21 https://interactiveimmersive.io/blog/touchdesigner-resources/2025-touchdesigner-experimental-new-features/ · 22 https://lightkeyapp.com/ · 23 https://www.loopypro.com · 24 https://developer.apple.com/documentation/appintents.md · 25 https://plainai.aguidetocloud.com/changes/apple-intelligence-siri-shipped/ · 26 https://plainai.aguidetocloud.com/changes/riaa-suno-udio-settlements/ · 27 https://awesome.ecosyste.ms/projects/github.com%2FAcademySoftwareFoundation%2FOpenTimelineIO · 28 https://github.com/PixarAnimationStudios/OpenTimelineIO/wiki/Tools-and-Projects-Using-OpenTimelineIO · 29 https://aaf.sourceforge.net/ · 30 https://developer.dolby.com/globalassets/documentation/technology/dolby_atmos_master_adm_profile_v1.0.pdf (nur verlinkt, nicht gelesen) · 31 https://musicradar.com/news/new-midi-2-specs · 32 https://huggingface.co/adefossez/HTDemucs/discussions/1 · 33 https://huggingface.co/adefossez/HTDemucs-ft/discussions/1 (nur Titel gesehen) · 34 https://pypi.org/project/basic-pitch · 35 https://swiftjectivec.com/Sound-Analysis-Framework-Built-In-Model/ · 36 https://developer.apple.com/apple-intelligence/foundation-models-adapter

**Was ich nicht abrufen konnte (nicht auf der Allowlist):** die iZotope-Produktseite, die Apple-Seiten zu AVVideoCodecType und zur Siri AI Developer Preview, und das Loopy-Pro-Wiki. Die betroffenen Aussagen sind deshalb über Sekundärquellen belegt oder als ANNAHME markiert.

**Für das Gedächtnis (alles aus dieser Websuche, nichts aus dem Nutzer-Gedächtnis):**
- Apples Adapter-Toolkit 26.0.0 ist die letzte Version und nicht kompatibel mit OS 27.
- Resolve importiert und exportiert OTIO auch in der Gratis-Version.
- DAWproject steht unter MIT und wird von Cubase 14, Studio One und Bitwig unterstützt.
- Die Lizenz der HTDemucs-Gewichte ist für kommerzielle Apps ungeklärt.

# Echoel Studio — Deep Developer Research (2026-11-04)

Alles hier ist nur gelesen, nichts geändert (Repo-Stand `/home/claude/wt-conductor`). Jede aktuelle Tatsache trägt eine Quelle [n] aus der Liste am Ende. **ANNAHME** heißt: geschätzt, nicht belegt. Grenzen: kein Wellness/Therapie/Medizin; „KI" nur dort, wo ein Modell wirklich läuft; nichts für Waffen oder Überwachung.

## 0. Ausgangslage im Repo
- Core (Foundation + Observation), DSP (Foundation, Accelerate optional) sowie Kernels und Engine (reines Swift + `Synchronization`) bauen und laufen unter Linux. Plattformgebunden ist nur `EchoelHost` (AVFoundation/AudioToolbox).
- Die Paket-Encoder für OSC, ADM-OSC, Art-Net und sACN liegen schon in Core (`Core/Sources/EchoelCore/ConnectionsPackets.swift` und `ConnectionsMessages.swift`). Nur `App/Connections/UDPSender.swift` hängt an Network.framework.
- Jam: `App/Jam/JamLink.swift` nutzt MultipeerConnectivity und die mach-Uhr. Die Uhr-Logik ist schon portabel (`Engine/JamSync.swift`, `ClockFollower.swift`, `PhaseLock.swift`).
- Assistent: `App/Agent/AgentSession.swift` nutzt Apples `FoundationModels` (`SystemLanguageModel`). Jede Aktion läuft durch `ProjectStore.perform`, eine Anfrage wird ein Undo-Schritt.
- Wasm-Spike (2026-11-01): DSP mit 302 von 302 Tests grün. Der Kern rendert 70- bis 140-mal schneller als Echtzeit und braucht höchstens 1,5 % eines 128er-Blocks. Größe: 18,8 MB gzip mit Foundation, 1,9 MB ohne, bei bitgleichem Klang.
- Folgerung: Die Arbeit liegt in den Adaptern pro Betriebssystem, nicht im Kern.

## 1. Cross-Platform mit einem Swift-Kern
**Stand 2026**
- Swift 6.3 (Ende März 2026) bringt das erste offizielle Android-SDK mit Kotlin/Java-Interop über swift-java / JNI Core [1][2]. App-Frameworks wie SwiftUI deckt es bewusst nicht ab; Runtime plus Foundation wiegen etwa 60 MB [3].
- Für WebAssembly gibt es offizielle Swift-SDKs auf swift.org [4][5]. Threads (`wasip1-threads`) fehlen im offiziellen Paket (Spike §2).
- Windows: Toolchain vorhanden. Für Echoel ungemessen (**ANNAHME**).
- Plugin-Formate:
  - VST3 steht seit SDK 3.8 (Oktober 2025) unter MIT [6][7].
  - Das ASIO-SDK ist jetzt GPLv3 [7].
  - CLAP steht unter MIT, v1.2.6 vom März 2025, laut Wikipedia „15 DAWs" [8].
  - Android hat kein AUv3-Gegenstück: Prozess-Isolation verhindert Plugin-Hosting, und Binder-Echtzeit-Prioritäten greifen für normale Apps nicht [9].
- MIDI 2.0:
  - Windows MIDI Services ist seit Februar 2026 allgemein verfügbar, mit Multi-Client und `usbmidi2.sys` [10][11].
  - Android: USB-MIDI 2.0 seit Version 13, virtuelle MIDI-2.0-Geräte seit 15 [9].
  - Linux: UMP im ALSA-Kernel [12].
  - Apple: kein BLE-MIDI 2.0 [9]. Safari: kein Web-MIDI (Spike).
- Audio-Backends:
  - Android: AAudio/Oboe. Pro-Audio verlangt höchstens 20 ms hin und zurück, Musiker brauchen etwa 10 ms; Puffer 96–512 Frames [13].
  - Linux: PipeWire mit JACK-API [14].
  - Windows: WASAPI shared mit 10 ms Standard, kleiner mit IAudioClient3 [15]; daneben ASIO.
  - Web: AudioWorklet mit festen 128 Frames (2,67 ms). Geteilte Ringpuffer brauchen SharedArrayBuffer plus COOP/COEP.
- Ableton Link: GPLv2 mit kommerzieller Lizenz-Option [16]. Es ist C++, also nach CLAUDE.md nur mit Council-Freigabe.

**Architektur.** Ports & Adapters:
- Der Kern bekommt neue Schnittstellen: AudioIO, MIDIIO, DatagramIO, ClockSource, ModelRuntime, SpatialSink.
- Eine C-ABI-Funktion `echoel_render(frames, L, R)` plus Parameter-Snapshot über einen SPSC-Puffer bedient alle Ziele.
- Der Render-Pfad wird Foundation-frei.
- Die Oberfläche ist pro Betriebssystem nativ (SwiftUI, Web, Compose; Plugin-GUI als Web-View, **ANNAHME**) und spricht nur `Command`s.
- C++ nur als dünne Hülle (Oboe-, CLAP- und VST3-Anbindung).

| Ziel | Aufwand | Latenz | Risiko |
|---|---|---|---|
| Web (Desktop-Chrome spielt) | M | 128 Frames + outputLatency, etwa 10–30 ms (**ANNAHME**) | Größe, kein Safari-MIDI, keine Threads |
| CLAP+VST3 Win/Linux/mac | M–L | Host-Puffer | Swift-Runtime im Plugin-Prozess ungemessen |
| Android | L | 10–20 ms hin und zurück [13] | Gerätestreuung, 60 MB [3], Oberfläche doppelt |
| Standalone Win/Linux | M | 2–6 ms (**ANNAHME**) | ASIO-Lizenz GPLv3 [7] |

## 2. XR / immersive Formate
**Stand 2026**
- visionOS: RealityKit hat Spatial Audio auf Entities und „Mixing spatial music" [17][18]. visionOS 26.4 hat die Spatial-Audio-Performance verbessert [19].
- WebXR in Safari ist seit visionOS 2 standardmäßig an, aber nur immersive-vr, ohne AR. Eingabe per Blick und Pinch über `transient-pointer` [20][21].
- Android XR: Galaxy XR ist erhältlich. Entwickelt wird mit Jetpack XR, OpenXR, Unity, Godot/Unreal oder WebXR; das SDK steht bei Developer Preview 4. Eine Spatial-Audio-API wird dort nicht genannt [22][23].
- Quest: OpenXR ist die Native-Schnittstelle [24]. Khronos treibt OpenXR als portablen Spatial-Computing-Standard [25].
- IAMF/Eclipsa: von der AOM, lizenzfrei, mit libiamf als Renderer. Nimmt ADM-BWF als Eingang. YouTube seit 2025, Samsung-TVs 2025; Chrome und Android waren angekündigt [26].

**XR-Modus zuerst als Ausgabe-Raum**
1. `SpatialScene` im Core (S–M); ADM-OSC ist nur ihre Live-Projektion.
2. ADM-BWF- und IAMF-Export, deterministisch offline gerendert (M).
3. WebXR-Viewer: ein Code für drei Headsets (M).
4. Native visionOS-App (L).
5. OpenXR nativ nur bei Bedarf (L).

Latenz: Kopfbewegung bis Klang unter etwa 20 ms (**ANNAHME**), also muss der Binaural-Renderer auf dem Headset laufen.

## 3. KI
**Stand 2026**
- Apple Foundation Models: on-device LLM seit iOS 26, mit Tool-Calling und Guided Generation, offline und ohne Kosten pro Aufruf [27][28].
- Android: Gemini Nano über die ML Kit GenAI Prompt API (Alpha), am besten auf Pixel 10 [29].
- Laufzeiten: ONNX Runtime, ExecuTorch, llama.cpp, MLX [30].
- MCP liegt seit 09.12.2025 bei der Agentic AI Foundation (Linux Foundation) [31].
- Musikmodelle:
  - Basic Pitch (Audio→MIDI) gibt es als npm-Paket [32]; Apache-2.0 ist **ANNAHME**.
  - Demucs: MIT ist **ANNAHME**.
  - RAVE-Modelle: CC-BY-NC-4.0, also nicht kommerziell; ein bezahltes Produkt braucht die Erlaubnis von IRCAM [33][34].

**Regeln**
- Nie auf dem Audio-Thread: Ergebnisse gehen als `Command` oder als Parameter-Snapshot zurück.
- On-device zuerst. Cloud nur als Opt-in mit eigenem Schlüssel des Nutzers.
- Körperwerte nie zu einer KI.

**Reihenfolge**
1. MCP-Server aus dem `CommandCatalog` (S–M, zuerst Desktop/Mac).
2. Audio→MIDI offline (M).
3. Quellentrennung offline, wenn die Lizenz passt (M–L).
4. Timbre-Transfer erst mit kommerzieller Lizenz oder eigenem Modell.
5. Kein „Song aus Prompt" (Neuplanung: keine generierten Noten).

## 4. Quantum Computing
- IBM rechnet ab 2026 mit „Quantum Advantage" in Chemie und Optimierung und plant einen fehlertoleranten Rechner für 2029, Zugriff per API [35][36].
- Für Echtzeit-Audio gibt es keine Rolle:
  - Ein Audio-Block hat 1–3 ms Budget, ein Cloud-QPU-Job braucht Sekunden (**ANNAHME**).
  - Es gibt keinen bekannten Quanten-Vorteil für FFT, Filter oder Synthese; das Laden der Daten frisst jeden Gewinn (**ANNAHME**).
  - Musik-QC ist ein Kunst- und Forschungsfeld (Miranda, ICMC 2025, Kobe-Plymouth) [37][38][39].
- „Quantum-inspirierte" Algorithmen laufen klassisch; ehrlich nennt man sie „Optimierung".
- Empfehlung: kein Produkt, keine Werbung. Höchstens ein Installationsexperiment, bei dem echte QPU-Messwerte offline als Seed dienen.

## 5. Realtime Ende zu Ende

| Glied | Wert |
|---|---|
| Puffer 64/128/256 Frames @ 48 kHz | 1,3 / 2,7 / 5,3 ms [13] |
| iOS hin und zurück | 5–10 ms (**ANNAHME**) |
| Android Pro-Audio | höchstens 20 ms, gebraucht etwa 10 ms [13] |
| Bluetooth Classic | etwa 100 ms; LE Audio LC3 20–30 ms; proprietär unter 3,5 ms [40] |
| DMX | 44 Hz, etwa 23 ms pro Bild; Art-Net-Sync drückt die Streuung zwischen Nodes auf einige 100 µs [41] |
| Glasfaser | etwa 5 µs/km (Physik) |
| Eng zusammen jammen | bis etwa 20 ms pro Richtung; unter 11,5 ms wird das Tempo leicht schneller [42][43] |
| JackTrip-Beiträge | Internet 4–100 ms, Ort 2–100 ms, Interface 5–>100 ms, WLAN 3–>100 ms [44] |

Folgerungen:
- Bluetooth ist kein Spielweg. Die App zeigt die gemessene Latenz offen an.
- Drei Jam-Klassen: Raum (Multipeer/LAN, plattformübergreifend über Link), Region (WebRTC/Opus, höchstens 20 ms), Welt (einen Takt versetzt).
- Licht wird vorausgeplant, mit der Audio-Hostzeit als Master und ArtSync/sACN-Sync.
- Messmethoden: Loopback mit Kreuzkorrelation, Fotodiode plus Mikrofon, RTT p50/p99 und `RenderWatchdog` p99. Jede Latenz-Aussage im Store braucht eine solche Messung.

## 6. Roadmap

| Horizont | Kern | Hüllen | Raum | KI | Netz |
|---|---|---|---|---|---|
| Jetzt | Schnittstellen, Render-Pfad ohne Foundation, `echoel_render` | iPhone/AUv3, Geräte-Session zuerst | `SpatialScene` | FoundationModels (läuft schon) | Latenz-Panel |
| 12 Monate | 32-Bit-Fixes, Golden-Audio über Plattformen (unter −130 dBFS) | Web, CLAP+VST3 | ADM-BWF/IAMF, WebXR | MCP, Audio→MIDI | Link, Ein-Takt-Jam |
| 3 Jahre | Objekt-/Binaural-Rendering im Kern | Android, Standalone | visionOS nativ, OpenXR | ONNX-Port, Gemini Nano | regionaler Jam, MIDI 2.0 Win/Android |
| 5 Jahre | offene Kern-Bibliothek | alle Betriebssysteme gleichrangig | Installationen auf einer Zeitachse | eigene, lizenzsaubere Modelle | verteilte Bühne |

**Nicht auf der Roadmap:** Quantum im Produkt, Cloud- oder Konto-Pflicht, KI auf dem Audio-Thread, ein zweiter DSP-Kern, globaler Echtzeit-Jam als Versprechen.

**Nächste drei Schritte**
1. Wächter-Test „Render-Pfad ohne Foundation" (S).
2. `echoel_render` plus ein Golden-Audio-Test über mehrere Plattformen (S–M).
3. Die erste Web-Scheibe nach der Geräte-Session (M). Danach entscheidest du zwischen CLAP/VST3 und MCP (als Frage in `docs/dev/FOUNDER_INBOX.md`).

## Quellen
1 https://9to5google.com/2026/03/28/swift-a-coding-language-developed-by-apple-now-offers-official-android-support/ · 2 https://www.thurrott.com/dev/334219/swift-6-3-brings-first-sdk-for-android · 3 https://skip.dev/blog/swift-63-android-support/ · 4 https://forums.swift.org/t/swift-sdks-for-webassembly-now-available-on-swift-org/80405 · 5 https://alternativeto.net/news/2025/9/swift-6-2-brings-easier-concurrency-improved-safety-webassembly-support-and-more · 6 https://sonicstate.com/news/2025/10/30/vst-3-now-available-under-mit-license · 7 https://forum.renoise.com/t/steinberg-vst3-asio-are-now-open-source/78840 · 8 https://en.wikipedia.org/wiki/CLever_Audio_Plug-in · 9 https://atsushieno.github.io/2025/10/07/droidkaigi.html · 10 https://www.theregister.com/2026/02/18/microsoft_makes_sweet_music_with/ · 11 https://blogs.windows.com/fr/windowsexperience/2026/02/17/making-music-with-midi-just-got-a-real-boost-in-windows-11/ · 12 https://tomoyo.sourceforge.net/cgi-bin/lxr/source/Documentation/sound/designs/midi-2.0.rst · 13 https://developer.android.com/ndk/guides/audio/audio-latency · 14 https://oneuptime.com/blog/post/2026-03-02-configure-pipewire-low-latency-audio-ubuntu/view · 15 https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/37468283/how-to-get-below-10ms-latency-using-wasapi-shared-mode · 16 https://cdm.link/ableton-opening-link-everyone-starting-today/ · 17 https://developer.apple.com/documentation/realitykit/mixing-spatial-music.md · 18 https://developer.apple.com/documentation/visionos/playing-spatial-audio-in-visionos.md · 19 https://9to5mac.com/guides/visionos-26-4/ · 20 https://www.uploadvr.com/visionos-2-apple-vision-pro-webxr/ · 21 https://roadtovr.com/visionos-2-webxr-support-vision-pro/ · 22 https://android-developers.googleblog.com/2026/06/what-is-new-android-xr.html · 23 https://developer.android.com/develop/xr · 24 https://developers.meta.com/horizon/documentation/native/android/mobile-openxr · 25 https://www.xrtoday.com/?p=58197 · 26 https://opensource.googleblog.com/2025/01/introducing-eclipsa-audio-immersive-audio-for-everyone.html · 27 https://www.macrumors.com/2025/06/09/foundation-models-framework/ · 28 https://9to5mac.com/2025/09/29/apple-intelligence-ios-26-models-developers/ · 29 https://android-developers.googleblog.com/2025/10/ml-kit-genai-prompt-api-alpha-release.html · 30 https://aman.ai/primers/ai/ml-runtimes/ · 31 https://agentic-ai.readthedocs.io/en/latest/Standards/agentic-ai-foundation/ · 32 https://npmjs.com/package/@spotify/basic-pitch · 33 https://huggingface.co/AEmotionStudio/rave-models · 34 https://arxiv.org/pdf/2111.05011.pdf · 35 https://www.constellationr.com/insights/news/ibm-sees-quantum-advantage-2026-fault-tolerant-quantum-2029 · 36 https://www.hpcwire.com/2025/06/10/ibm-sets-2029-target-for-fault-tolerant-quantum-computing/ · 37 https://icmc2025.sites.northeastern.edu/panel-sessions · 38 https://www.research.kobe-u.ac.jp/eng-nanoelectronics/files/Kobe-Plymouth_Quantum_Music_Workshop_Flyer_Eng.pdf · 39 https://qcshub.web.ox.ac.uk/node/2218801 · 40 https://audioxpress.com/article/wireless-audio-ultra-low-latency-audio-transmission-over-bluetooth-le-audio · 41 https://felusch.de/en/art-net-oder-sacn/ · 42 https://mediax.stanford.edu/research-projects/lat-chafe · 43 https://ccrma.stanford.edu/~cc/shtml/net-delayResearch.shtml · 44 https://support.jacktrip.com/how-to-optimize-latency-when-using-jacktrip

Die GitHub-Repos von Link, Demucs und RAVE durfte ich nicht abrufen (nicht auf der Allowlist). Ihre Lizenzangaben sind deshalb über Sekundärquellen belegt oder als ANNAHME markiert.

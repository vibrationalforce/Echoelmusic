# Symbolic Music Generation (MIDI) — State of the Art 2024–2026 and What Pro Tools Ship

Scope note: collected 2026-10-16. Several primary domains (arxiv.org, huggingface.co, apple.com, magenta.withgoogle.com, simedw.com) could not be fetched directly from this sandbox (DNS failure); claims about them come from search-result summaries of those pages and are marked where that matters. Labels used: **[SHIPPED]** commercial product, **[OPEN]** open model usable today, **[RESEARCH]** paper only / weights unclear.

## 1. Which models and approaches lead? (sizes, licenses, reported quality)

### Takeaway
The open symbolic field in 2024–2026 is mostly decoder-only transformers over MIDI-event or ABC tokens, from about 35M to about 1B parameters (MuPT goes up to 4.2B). The most useful one for a workstation is the Anticipatory Music Transformer, because it does infilling and accompaniment over fixed notes (128M–780M, code Apache-2.0, trained on Lakh MIDI). The newest trend is adapting small general LLMs (Llama 3.2 1B) to MIDI tokens (MIDI-LLM, Aria). Magenta RealTime and Lyria generate AUDIO, not MIDI, so they do not solve symbolic generation.

### Cited Findings
**Anticipatory Music Transformer (AMT), Stanford CRFM, 2023, [OPEN]:**
- It interleaves event tokens and control tokens ("anticipation"). For infilling, the controls are a subset of the events that stay fixed, and the model generates the rest around them. It is trained on the Lakh MIDI dataset. — [arXiv 2306.08620](https://arxiv.org/pdf/2306.08620); [CRFM blog](https://crfm.stanford.edu/2023/06/16/anticipatory-music-transformer.html)
- Reported quality: it matches standard autoregressive models on prompted generation and adds infilling, including accompaniment. Larger models reach significantly better perplexity. — [arXiv 2306.08620](https://arxiv.org/pdf/2306.08620)
- Sizes: Small is 128M parameters (`stanford-crfm/music-small-800k`, 800k steps on Lakh MIDI), Medium about 360M, Large about 780M (`music-large-800k`, slowest but best samples). All are decoder-only causal transformers with a 1024-token context, trained with Levanter. — [HF music-small-800k](https://huggingface.co/stanford-crfm/music-small-800k); [arXiv 2306.08620](https://arxiv.org/pdf/2306.08620)
- License: the code repository is Apache-2.0. No license for the weights was found. The repo also documents the accompaniment API: `extract_instruments` takes the melody, generation runs with it as `controls`, and `ops.combine` merges the parts. — [GitHub jthickstun/anticipation](https://github.com/jthickstun/anticipation)

**Text-conditioned symbolic models:**
- **text2midi** (AAAI 2025), [OPEN code]: 272M parameters. A frozen FLAN-T5 encoder reads the caption and conditions an autoregressive transformer decoder through cross-attention. Code is at github.com/AMAAI-Lab/Text2midi. A follow-up, Text2MIDI-InferAlign, adds reward shaping at inference time to improve text-MIDI alignment. — [AAAI proceedings](https://ojs.aaai.org/index.php/AAAI/article/view/34516); [Herremans lab page](https://dorienherremans.com/content/text2midi-aaai)
- **MIDI-LLM** (NeurIPS 2025 workshop; revised version listed for ISMIR 2026), [OPEN]: Llama 3.2 1B with a vocabulary extended by MIDI tokens and two-stage training. The data was about 1.69B tokens of text, 1.38B of MIDI and 1.71B of paired text-MIDI. It can be served with vLLM. Authors report better quality, better text control and faster inference than text2midi. The checkpoint is `slseanwu/MIDI-LLM_Llama-3.2-1B`, and the repo suggests a GPU with 16 GB or more VRAM. — [arXiv 2511.03942](https://arxiv.org/pdf/2511.03942); [NeurIPS 2025 page](https://neurips.cc/virtual/2025/123799)
- **MuseCoco** (Microsoft Research Asia, 2023 — older), [RESEARCH/OPEN code]: two stages, text to attributes (genre, mood, tempo, key …) and then attributes to music. The large version has 1.2B parameters. — [Microsoft Research](https://www.microsoft.com/en-us/research/?p=945393); [arXiv 2411.12641 (characterisation)](https://arxiv.org/pdf/2411.12641)

**Foundation / scale models:**
- **MuPT** (ICLR 2025): a family of decoder-only models trained on ABC notation, from 190M to 4.23B parameters, with 8192-token context. — [ICLR 2025 paper](https://proceedings.iclr.cc/paper_files/paper/2025/file/73f6f8897896f7bda86ea7d1ebc1dc4f-Paper-Conference.pdf)
- **NotaGen** (2025): an LLM-style training recipe (pretraining, fine-tuning, preference optimisation) for sheet-music/ABC generation. One search snippet gives 234M parameters for a pretrained configuration (12-layer event decoder plus 3-layer token decoder, 4096 context, hidden size 1024). Whether that is the final model size is unconfirmed. — [arXiv 2502.18008](https://arxiv.org/pdf/2502.18008)
- **Aria** (EleutherAI, ISMIR 2025), [OPEN]: Llama 3.2 1B architecture, trained on about 60k hours of MIDI transcribed from expressive solo-piano recordings. Base, generation and embedding checkpoints are released. Piano only. — [GitHub EleutherAI/aria](https://github.com/EleutherAI/aria); [HF loubb/aria-medium](https://huggingface.co/loubb/aria-medium); [arXiv 2506.23869](https://arxiv.org/pdf/2506.23869)
- **SkyTNT midi-model** (MIDI event transformer with a Python app) and **MIDI-GPT** (Metacreation Lab, GPT-2-style, controllable multitrack generation) are other open repos. — [SkyTNT/midi-model](https://github.com/SkyTNT/midi-model); [Metacreation-Lab/MIDI-GPT](https://github.com/Metacreation-Lab/MIDI-GPT)
- Other 2025–2026 research directions: Amadeus (autoregressive model with bidirectional attribute modelling) [arXiv 2508.20665](https://arxiv.org/pdf/2508.20665); efficient long-sequence diffusion for symbolic music [arXiv 2603.00576](https://arxiv.org/pdf/2603.00576); BEAT tokenisation by uniform temporal steps [arXiv 2604.19532](https://arxiv.org/pdf/2604.19532); a controlled comparison of supervised vs. preference-based adaptation of pretrained LLMs for symbolic music [arXiv 2601.22764](https://arxiv.org/pdf/2601.22764).

**Audio models (not symbolic — for contrast):**
- **Magenta RealTime** (Google, June 2025), [OPEN, AUDIO]:
  - About 800M parameters; the paper's results table lists 760M. Autoregressive transformer in a MusicLM-style chunked design, 48 kHz stereo output, trained on about 190k hours of mostly instrumental stock music. — [Simon Willison](https://simonwillison.net/2025/Jun/20/magenta-realtime/); [arXiv 2508.04651](https://arxiv.org/abs/2508.04651); [MarkTechPost](https://www.marktechpost.com/2025/06/22/google-researchers-release-magenta-realtime-an-open-weight-model-for-real-time-ai-music-generation/)
  - Speed: 2 s of audio are generated in 1.25 s on a free Colab TPU v2-8. Google's stated goal is to run on consumer hardware eventually. — same sources
  - License: code is Apache-2.0 and weights are CC-BY-4.0 according to Willison; Google's page says "permissive licenses with some additional bespoke terms". The sources conflict.
  - Related: it is the open "cousin" of Lyria RealTime (MusicFX DJ, the AI Studio API). A "Magenta RealTime 2 … on Mac" appears in a 2026-06-05 blog title, with no details found. — [pasqualepillitteri.it tag page](https://pasqualepillitteri.it/pt/news/tag/open+weights)

### Inferences
- For a 480-PPQ note timeline with an existing rule-based composer, AMT-style anticipation is the closest research fit. It conditions on fixed user or composer notes and fills spans, which is what "continue / infill / accompany" means in a DAW. The weights license still has to be checked before shipping.
- Text-to-MIDI models (text2midi, MIDI-LLM, MuseCoco) answer a different question ("describe a song") and are 272M–1.2B parameters, at or above the edge of comfortable on-device use.
- Most leading models train on Lakh MIDI or scraped MIDI/ABC. The training-data provenance is as much a product risk as the weights license.

### Gaps
- No weights license was confirmed for AMT, text2midi, Aria or MIDI-LLM (the Hugging Face model cards were unreachable from this sandbox).
- No 2024–2026 sources were found for Magenta's Music Transformer, Magenta Studio or MIDI-DDSP. These are older (2018–2022) and were not re-verified here.
- No details on "Magenta RealTime 2". Meta's work in this area (MusicGen) is audio, not symbolic; no Meta symbolic model was found.
- No head-to-head human-preference ranking across these models was found.

## 2. What professional tools actually ship

### Takeaway
Shipped DAW "AI players" condition on a chord track, a key and a style, and expose a few knobs (complexity/intensity). Apple's Session Players are the reference design. Ableton Live 12 and Bitwig 6 ship algorithmic, rule-based MIDI generators and transformations, not neural models. Third-party plugins (Scaler, Captain, Orb/LANDR Composer, Lemonaide) mostly mix theory engines with chord/melody libraries; Lemonaide is the clear ML-based MIDI seed generator.

### Cited Findings
**Apple Logic Pro 11 / Logic Pro for iPad 2, May 2024, [SHIPPED]:**
- Session Players add an AI Bass Player and Keyboard Player alongside Drummer. Apple says the bass player was "trained in collaboration with bassists" using AI and sampling technologies. There are eight Bass Players with complexity and intensity controls. — [Synthtopia](https://www.synthtopia.com/content/2024/05/07/free-logic-pro-update-brings-new-ai-powered-features/); [MusicTech](https://musictech.com/news/industry/apple-logic-pro-for-mac-11-logic-pro-for-ipad-2/); [Apple Newsroom (via search)](https://www.apple.com/newsroom/2024/05/logic-pro-takes-music-making-to-the-next-level-with-new-ai-features/)
- The Keyboard Player ranges from block chords to voicings with extended harmony and offers four styles. — [Apple Support (via search)](https://support.apple.com/en-lamr/guide/logicpro/lgcp70dd5af3/mac)
- Chord following:
  - Players follow either the global Chord track or chords stored on each Session Player region. You can enter custom chords or pick preset progressions.
  - Several players can follow the same Chord track and stay in harmonic sync.
  - With no chords at the playhead, players fall back to the tonic chord of the project key.
  — [Apple Support (via search)](https://support.apple.com/en-lamr/guide/logicpro/lgcp70dd5af3/mac); [Logic Studio Training](https://logicstudiotraining.com/session-players-logic-pro/); [Sound On Sound](https://www.soundonsound.com/techniques/logic-pro-session-players)

**Ableton Live 12, [SHIPPED]:**
- MIDI Tools are split into Transformations and Generators, in the Transform/Generate panels of Clip View, with Auto Apply on by default. Native tools cannot be edited; the Max for Live tools can.
- Users can build their own or install third-party tools, which go in User Library/MIDI Tools/Max Transformations and Max Generators.
- The MIDI Tools Pack (Philip Meyer, in Suite) adds 5 devices, 3 of them generators. It needs Live 12.1 or later, and MIDI Tools are not available on Push Standalone.
- These are algorithmic tools; no neural model is described.
— [Live 12 manual: MIDI Tools](https://www.ableton.com/en/live-manual/12/midi-tools/); [MIDI Tools pack](https://www.ableton.com/en/packs/midi-tools); [Live 12 features](https://ableton.com/en/live/all-new-features)

**Bitwig Studio 6 (2025), [SHIPPED]:**
- Note Operators (Chance, Repeats, Occurrence, Recurrence), project-wide key signatures, Snap/Quantize to Key, Spray Can and Step Input. No generative-AI note tool was found. — [Synthtopia](https://www.synthtopia.com/content/2025/08/27/bitwig-studio-6-beta-now-available-heres-whats-new/); [RouteNote](https://create.routenote.com/blog/bitwig-studio-6-is-out-now/)

**Plugins and services:**
- **Scaler 3** (Plugin Boutique), [SHIPPED]: analyses MIDI and audio to detect key and scale and suggests fitting chords. It has a chord-set library by mood, artist and genre, a chord-suggesting sequencer, and VST/AU hosting. — [Plugin Boutique](https://pluginboutique.com/products/14479-Scaler-3-Upgrade); [Pitch Innovations](https://pitchinnovations.com/blog/?p=2929)
- **Scaler Detector** (Oct 2025, $9, free for Scaler 3 owners), [SHIPPED]: detects chords from MIDI or audio and ranks scales. Users report it can misread complex progressions. — [SonicState](https://www.sonicstate.com/news/2025/10/23/key-and-chord-detection-plugin/); [Plugin Boutique](https://www.pluginboutique.com/products/15928-Scaler-Detector)
- **Orb Producer Suite 3**, [SHIPPED / discontinued]: now LANDR Composer; Orb plugins will no longer receive updates. — [LANDR](https://www.landr.com/plugins/producer-suite-3)
- **Captain Plugins Epic**: listed at $79–99 one-time, with MIDI export and a DAW plugin, and no ML claim. — [midiagent.com compare](https://www.midiagent.com/compare)
- **Lemonaide Seeds**, [SHIPPED, cloud ML]: billed as "ethical AI", generating chord and melody MIDI (and audio). It launched via BeatStars. One comparison table lists $9.99/month plus $4.99–9.99/month per artist model. — [MusicRadar](https://www.musicradar.com/news/seeds-by-lemonaide-ai-midi-generator); [midiagent.com](https://www.midiagent.com/compare)
- **BandLab SongStarter**, [SHIPPED, free, cloud]: generates royalty-free song ideas from a randomizer or a lyric/keyword prompt (50-character limit including emojis). Each roll gives three variations sharing a sound palette, with a day/sunset/night mood switch. Output is audio-level ideas exported as MP3/WAV or opened in BandLab's editor. One outlet says it was built with TensorFlow. — [BandLab Help](https://help.bandlab.com/hc/en-us/articles/24226593087001-What-is-SongStarter); [Gearnews](https://gearnews.com/introducing-bandlab-songstarter-a-source-for-that-creative-spark); [RouteNote](https://create.routenote.com/blog/what-is-bandlab-songstarter/)

### Inferences
- The professional pattern is chord track plus key plus style plus 2–3 continuous knobs (complexity/intensity), with deterministic fallback to the tonic. Echoelmusic's rule-based composer already has the inputs this needs (key, scale, genre). The missing pieces are a shared chord-track abstraction and per-part complexity/intensity controls, not a neural network.
- Even Ableton and Bitwig ship rules and probability, not models. "Generative MIDI" in pro DAWs in 2026 is still mostly algorithmic.

### Gaps
- Apple does not publish whether Session Players run a neural model at playback time or rearrange recorded performances (the "AI and sampling technologies" wording is ambiguous). Drummer's internals were not documented in what I found.
- Instachord, Splice (Create), and "Microsoft Muse" as a product were not researched. Microsoft's Muse (2025) is reported to be a game-world model, not music; this was not verified here.
- No current Captain Chords feature details were found.

## 3. Infilling, continuation and controllability

### Takeaway
Real constraint-following exists only where control is built into training: anticipation (fixed notes), attribute conditioning (MuseCoco, MIDI-GPT), and text conditioning (text2midi, MIDI-LLM). Most other models sample a continuation, and key/density adherence then depends on post-filtering or reward shaping.

### Cited Findings
- AMT conditions on arbitrary fixed note events (controls), which supports infilling and accompaniment of a given melody. — [arXiv 2306.08620](https://arxiv.org/pdf/2306.08620); [GitHub](https://github.com/jthickstun/anticipation)
- MuseCoco maps text to explicit attributes (genre, mood, tempo, key …) and generates music from those attributes. — [Microsoft Research](https://www.microsoft.com/en-us/research/?p=945393); [arXiv 2411.12641](https://arxiv.org/pdf/2411.12641)
- MIDI-GPT is described as built for "controllable, multitrack symbolic music generation". — [GitHub MIDI-GPT](https://github.com/Metacreation-Lab/MIDI-GPT)
- MIDI-RWKV (2025) is a small (about 35M) RWKV-7 model for personalizable long-context infilling, designed for co-creation on edge devices. — [arXiv 2506.13001](https://arxiv.org/pdf/2506.13001)
- Text2MIDI-InferAlign uses reward shaping at inference time to improve text adherence, which implies the base model's adherence is imperfect. — [Herremans lab](https://dorienherremans.com/content/text2midi-aaai)
- Logic's Session Players enforce harmony by construction: they follow a chord track and fall back to the tonic. — [Apple Support (via search)](https://support.apple.com/en-lamr/guide/logicpro/lgcp70dd5af3/mac)

### Inferences
- A practical hybrid: the rule-based composer owns key, scale, chords and form, and a small model proposes note content inside those constraints. Hard constraints can also be enforced by masking out-of-key pitch tokens at sampling time. This sampling-time masking is a standard technique, not cited above.

### Gaps
- No quantitative chord- or key-adherence numbers were collected per model.

## 4. On-device feasibility (iPhone / Apple silicon)

### Takeaway
Small symbolic models (35M–130M) are plausible on an iPhone. One 2026 hobby project runs a 125M-parameter piano-autocomplete transformer fully on device via Core ML with INT8 weights. No shipping iOS app with on-device neural symbolic generation was found. Models of 1B and up (MIDI-LLM, Aria) are GPU-class today.

### Cited Findings
- A 125M-parameter MIDI piano-autocomplete model was exported from PyTorch to Core ML with INT8 weight quantization and runs fully on device. First launch is slow while Core ML specialises the model to the hardware, and Core ML does not expose attention Q/K/V. Each note has five categorical fields, with timing quantized to fixed steps. — [SimEdw blog, 2026-08-20 (via search)](https://simedw.com/2026/08/20/midi-autocomplete/)
- MIDI-RWKV (about 35M) targets edge devices. — [arXiv 2506.13001](https://arxiv.org/pdf/2506.13001)
- A real-time accompaniment system for edge devices uses a GPT-2 architecture (JazzyGPT2 repo). — [Springer 2026](https://link.springer.com/chapter/10.1007/978-3-032-05748-8_44)
- The CoreML-Models zoo has Basic Pitch audio-to-MIDI (17K parameters, 272 KB, real time on iPhone on the Neural Engine). Its generation entries are audio (Stable Audio Open Small), not symbolic. — [GitHub john-rocky/CoreML-Models](https://github.com/john-rocky/CoreML-Models)
- TinyMusician reports an iOS app running a distilled, mixed-precision ONNX model; it appears to be audio generation. — [arXiv 2509.00914](https://arxiv.org/pdf/2509.00914)
- MIDI-LLM's repo suggests 16 GB or more of GPU VRAM. — [MIDI-LLM summary](https://www.emergentmind.com/topics/midi-llm)
- Magenta RealTime (audio, about 800M) currently runs on Colab TPUs; local consumer hardware is a stated goal. — [Simon Willison](https://simonwillison.net/2025/Jun/20/magenta-realtime/)

### Inferences
- Rough sizes (arithmetic, not measured): 128M parameters is about 128 MB in INT8 or about 64 MB in 4-bit. 1B parameters is about 1 GB in INT8. The small AMT or a MIDI-RWKV-class model fits an app budget; 1B models are heavy for an iPhone app download and memory budget.
- A Core ML model would be Echoelmusic's first ML runtime and first model asset. That does not break the zero-external-dependencies rule (Core ML is Apple's), but it is a founder/Council-level decision and the model must stay off the audio thread.

### Gaps
- No measured tokens/sec on iPhone or Apple silicon was found for any symbolic model (the blog page could not be fetched for exact numbers).
- No App Store app was confirmed to do on-device neural MIDI generation.

## 5. Evaluation and known failure modes

### Takeaway
Evaluation still mixes objective statistics (pitch, rhythm and harmony metrics, distribution distances such as Fréchet Music Distance) with listening tests. A 2025 survey stresses that objective metrics correlate weakly with human judgment and are not standardised. Specific numbers on repetition, drift and key-ignoring failures were not found in this pass.

### Cited Findings
- Kader & Karmaker (2025) survey audio and symbolic metrics. Limitations they name: weak correlation with human perception, cross-cultural bias, and lack of standardisation that hinders comparison across models. — [arXiv 2509.00051](https://arxiv.org/pdf/2509.00051)
- Older taxonomy (Ji et al. 2023): pitch-, rhythm- and harmony-related objective metrics. Tools: MusPy, Yang & Lerch's toolbox, and smg-metrics (25 metrics covering harmony, rhythm, polyphony and distributions). Fréchet Music Distance compares embedding distributions, FID-style. — [survey summary / smg-metrics](https://pypi.org/project/smg-metrics); [JiEtAl2023](https://acousticslab.org/RECA293/293Files/293Downloads/JiEtAl2023_DeepLearningMusicGeneration.pdf); [arXiv 2412.07948](https://arxiv.org/abs/2412.07948v2)
- A NeurIPS 2025 workshop study compares scale, data and metrics for piano transformers and tests how well metrics correlate with human listening. — [NeurIPS 2025](https://neurips.cc/virtual/2025/loc/san-diego/123778)
- AMT reports quality as perplexity plus human evaluation. — [arXiv 2306.08620](https://arxiv.org/pdf/2306.08620)
- Text adherence needed inference-time reward shaping (InferAlign). — [Herremans lab](https://dorienherremans.com/content/text2midi-aaai)
- A user-level failure in shipped detection tools: chord detection misreads complex progressions. — [Plugin Boutique](https://www.pluginboutique.com/products/15928-Scaler-Detector)

### Inferences
- For Echoelmusic, the cheap and meaningful checks are structural and testable in CI: in-key ratio against the chosen scale, note density per bar, no-repeat-n-gram rate, and chord-tone ratio on strong beats. These are the same style of structural pins the repo already uses (e.g. genre distinctness). Whether it sounds good stays a founder-ear check.

### Gaps
- No quantitative studies on repetition loops or long-range drift in 2024–2026 models were retrieved.

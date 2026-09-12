// GenrePatches.swift
// Echoel — the sound character behind each genre. The generative core writes the
// right notes; this gives them the right *timbre* so a take is usable starting
// material in its genre.
//
// LOCATION: this file lives in Sequencer/ (not DSP/) on purpose. The AUv3 target
// globs Sources/Echoelmusic/DSP, and this file depends on MusicStyle (Sequencer/)
// which the AUv3 target does NOT include — putting it in DSP/ breaks the AUv3
// compile ("cannot find type 'MusicStyle'"). The macOS SwiftPM build is one
// module so it would not catch that; the Xcode simulator build does.
//
// IMPORTANT: enum-valued params (noiseColor / spectralShape / envelopeCurve) are
// stored as their EchoelDDSP rawValues, which are Capitalized ("Dark", "Bell",
// "Pink", "Exponential", "Metallic", "Violet"). A lowercase string silently fails
// the enum lookup in SynthPatch.apply(to:) and the param is left unchanged — so
// these MUST match. `GenrePatchesTests` guards exactly that. The same applies to
// `timbre` — it must equal an `EchoelDDSP.InstrumentTimbre` rawValue exactly
// ("Violin", "Cello", "Clarinet", "Oboe", "Flute", "Trumpet") or the profile is
// silently ignored.
//
// Every SynthPatch is constructed in the declared argument order (id, name,
// attack, decay, sustain, release, envelopeCurve, harmonicity, harmonicLevel,
// brightness, noiseLevel, noiseColor, spectralShape, filterCutoff,
// filterResonance, lfoToFilterDepth, filterLFORate, filterLFODepth, reverbMix,
// reverbDecay, vibratoRate, vibratoDepth) — the Xcode iOS archive compiler
// rejects any other order even though macOS swift-build may not.
//
// SOUND CYCLE 1 (2026-07-02, "klingt nicht nach richtiger Musik"): the engine
// already ships real per-harmonic instrument spectra (EchoelDDSP.instrumentProfile
// — violin/cello/clarinet/oboe/flute/trumpet) that ONLY the acoustic factory
// patches used; NO genre tapped them, so every genre was the same clean sine
// stack. This cycle (a) routes the acoustic-leaning genres through those real
// instrument spectra (moderate blend so the genre character survives), (b) adds a
// UNISON stack (thicker/ensemble, the classic thin→wide lever) to the pad/lead
// genres, and (c) adds a small breath/air NOISE floor to acoustic + pad voices
// (real strings/reeds/flutes have one; leads stay clean so noise doesn't read as
// hiss). All pure data — no DSP or audio-thread changes.

import Foundation

public extension MusicStyle {

    /// The synth voice sound this genre is generated through. Applied to the
    /// polyphonic voice on Generate so the take sounds like its reference.
    var synthPatch: SynthPatch {
        // Sound-design philosophy (2026-06-12, "make it beautiful"): warm, clean,
        // spacious — built for production-ready loops, not harsh demos. Universal
        // rules: Natural/Dark spectral shapes (Metallic/Hollow sound digital),
        // brightness kept moderate, gentle filter resonance, generous reverb for
        // professional space, softer attacks so pads bloom instead of click. Each
        // genre keeps its character, cleaner. SOUND CYCLE 1 layers real instrument
        // spectra + unison width + a breath/air noise floor on top (see header).
        switch self {
        case .boomBapHipHop:
            // #1289 G6b — DUST KEYS. The "dusty top" the lineage names comes from the PATCH, not
            // from a chain filter: cutoff 1500 is the lowest of any synth patch this batch or the
            // last one added, brightness 0.22 and a Dark spectral shape. Doing it here rather than
            // with `filterEnabled` keeps `acidTechno` the only genre arm that enables the chain
            // filter — a claim three blocking guards now assert roster-wide.
            return patch("54", "Dust Keys",
                a: 0.010, d: 0.55, s: 0.34, r: 0.40,
                harm: 0.86, hl: 0.26, bright: 0.22, noise: 0.02, color: "Pink", shape: "Dark",
                cutoff: 1500, res: 0.10, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.14, revDecay: 1.10, vibRate: 0, vibDepth: 0,
                uni: 2, det: 6)
        case .electroFunk:
            // #1289 G6b — SNAP KEYS. The opposite envelope to the patch above it, deliberately:
            // a hard attack (0.002) and a SHORT decay into a low sustain, so each comp is a snap
            // that has finished before the next sixteenth. Brighter and higher-cut than Dust
            // Keys by a wide margin — the two share a scale and a voicing, so the timbre is
            // where a listener tells them apart.
            return patch("55", "Snap Keys",
                a: 0.002, d: 0.18, s: 0.14, r: 0.16,
                harm: 0.72, hl: 0.70, bright: 0.44, noise: 0.0, color: "White", shape: "Bright",
                cutoff: 3400, res: 0.26, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.10, revDecay: 0.90, vibRate: 0, vibDepth: 0,
                uni: 2, det: 5)
        case .rootsReggae:
            // #1289 G6b — ROOTS ORGAN. ⚠️ NOT "Skank Organ": `ska` (un-offered) already ships
            // that name, and the pre-batch check caught it — the third name collision in three
            // batches, which is why that check now runs before the arm is written.
            // A fast attack and a medium decay so the offbeat chop is a CHOP, plus the ensemble
            // unison an organ needs; the long tail is the delay's job, not the patch's.
            return patch("56", "Roots Organ",
                a: 0.008, d: 0.30, s: 0.42, r: 0.30,
                harm: 0.90, hl: 0.72, bright: 0.34, noise: 0.0, color: "Pink", shape: "Natural",
                cutoff: 2700, res: 0.14, lfoAmt: 0.05, lfoRate: 5.2, lfoDepth: 0.06,
                revMix: 0.18, revDecay: 1.30, vibRate: 5.2, vibDepth: 0.04,
                uni: 3, det: 10)
        case .blackMetal:
            // #1288 G6a — COLD STACK. A power chord wants to be a WALL, so this is the opposite
            // of the iron stab it stands beside: a slower attack (0.05) and a long release (1.6)
            // so consecutive chords bleed into one continuous plane. Harmonics high and
            // brightness high, but the spectral shape is Bright rather than Metallic — the cold
            // is in the MODE (see the case doc), and a metallic timbre on top of a raised-fourth
            // scale reads as digital rather than as glacial. Wide unison and heavy detune are
            // the closest this synth gets to a tremolo-picked wall.
            return patch("48", "Cold Stack",
                a: 0.05, d: 0.90, s: 0.72, r: 1.60,
                harm: 0.82, hl: 0.66, bright: 0.52, noise: 0.04, color: "White", shape: "Bright",
                cutoff: 3200, res: 0.18, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.24, revDecay: 3.00, vibRate: 0, vibDepth: 0,
                uni: 5, det: 16)
        case .modalJazz:
            // #1288 G6a — WARM COMP KEYS. A comped chord is struck and let go, so the envelope is
            // an electric-piano shape: quick but not hard, a long decay into a low sustain, and a
            // release just short of the swung eighth at 120 (0.25 s) so successive comps do not
            // smear. Low brightness with a Natural shape and rich low harmonics — the warmth is
            // in the spectrum, not in a filter sweep, and there is no LFO at all because a
            // vibrato on a comped chord is an organ, not a Rhodes.
            return patch("49", "Warm Comp Keys",
                a: 0.008, d: 0.70, s: 0.26, r: 0.22,
                harm: 0.88, hl: 0.30, bright: 0.30, noise: 0.0, color: "Pink", shape: "Natural",
                cutoff: 2000, res: 0.10, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.16, revDecay: 1.60, vibRate: 0, vibDepth: 0,
                uni: 3, det: 8)
        case .soulBallad:
            // #1288 G6a — WARM KEYS. The ballad relative of the comp patch above, and every
            // difference is deliberate rather than a tweak: a softer attack (0.02 vs 0.008), a
            // HIGHER sustain (0.48 vs 0.26) and a release more than twice as long, because a
            // maj7 at 72 BPM is held, not struck. Slight vibrato — the one place in this batch
            // where an LFO belongs, since a soul keyboard part does breathe.
            return patch("50", "Warm Keys",
                a: 0.02, d: 0.80, s: 0.48, r: 0.55,
                harm: 0.90, hl: 0.28, bright: 0.28, noise: 0.0, color: "Pink", shape: "Natural",
                cutoff: 1900, res: 0.08, lfoAmt: 0.06, lfoRate: 4.6, lfoDepth: 0.05,
                revMix: 0.24, revDecay: 2.20, vibRate: 4.6, vibDepth: 0.04,
                uni: 3, det: 9)
        case .industrialTechno:
            // #1286 G5b — IRON. A hard, near-instant attack and a short decay so the cluster
            // reads as a HIT, not a pad; low sustain, short release, so nothing rings into the
            // next one. Brightness 0.38 with a hard spectral shape and a whisper of white noise
            // is where the metal comes from — the harmony is already harsh, so the timbre does
            // not need to distort on top of it. Mono-ish unison: width would blur a cluster.
            return patch("42", "Iron Stab",
                a: 0.002, d: 0.30, s: 0.18, r: 0.24,
                harm: 0.64, hl: 0.62, bright: 0.38, noise: 0.06, color: "White", shape: "Bright",
                cutoff: 2600, res: 0.30, lfoAmt: 0.08, lfoRate: 0.8, lfoDepth: 0.10,
                revMix: 0.10, revDecay: 1.20, vibRate: 0, vibDepth: 0,
                uni: 2, det: 7)
        case .afroHouse:
            // #1286 G5b — the WARM offbeat chord. Fast but not hard (0.006 against the iron
            // patch's 0.002), a middling sustain and a release long enough that consecutive
            // offbeats overlap into the roll — that overlap IS the groove, and shortening it
            // would turn the vamp back into stabs. Round harmonics, dark-ish shape, wide-ish
            // unison for the body a house chord needs.
            return patch("43", "Warm Skank",
                a: 0.006, d: 0.45, s: 0.42, r: 0.38,
                harm: 0.90, hl: 0.58, bright: 0.28, noise: 0.01, color: "Pink", shape: "Natural",
                cutoff: 1800, res: 0.16, lfoAmt: 0.06, lfoRate: 0.30, lfoDepth: 0.12,
                revMix: 0.14, revDecay: 1.80, vibRate: 0, vibDepth: 0,
                uni: 3, det: 11)
        case .darkPsyTrance:
            // #1286 G5b — the ARP's own voice, and the one field that matters is the release:
            // short enough that consecutive steps are separate events at 148 BPM, long enough
            // that the figure reads as a line. Brighter than the iron stab and than every bass
            // patch, because an arp must be HEARD rather than felt; a shallow fast filter LFO
            // gives the repeated figure the movement a fixed timbre would not have.
            return patch("44", "Dark Arp",
                a: 0.002, d: 0.22, s: 0.16, r: 0.16,
                harm: 0.78, hl: 0.54, bright: 0.42, noise: 0.01, color: "Pink", shape: "Bright",
                cutoff: 3000, res: 0.34, lfoAmt: 0.18, lfoRate: 1.60, lfoDepth: 0.22,
                revMix: 0.12, revDecay: 1.40, vibRate: 0, vibDepth: 0,
                uni: 2, det: 9)
        case .glacialField:
            // #1285 G5 — AIR, not a note. A very slow swell (under `deepDrone`'s 1.8 s, which
            // keeps that patch's "slowest attack of any genre patch" true) into a long, high,
            // barely-moving bed. Bright where the drone is dark — 0.46 against 0.10 — because
            // the two stillest genres must not read as one patch at two registers. Wide unison
            // with a heavy detune so the cluster's beating is stereo as well as spectral; the
            // vibrato is OFF, since anything periodic would be the movement this genre refuses.
            return patch("40", "Glacier Pad",
                a: 1.600, d: 7.00, s: 0.90, r: 7.00,
                harm: 0.72, hl: 0.55, bright: 0.46, noise: 0.04, color: "White", shape: "Bright",
                cutoff: 4200, res: 0.08, lfoAmt: 0.10, lfoRate: 0.04, lfoDepth: 0.18,
                revMix: 0.58, revDecay: 9.00, vibRate: 0, vibDepth: 0,
                uni: 3, det: 12)
        case .slowBloom:
            // #1285 G5 — the OPENING. A slow attack with a LONG decay to a middling sustain, so
            // each onset keeps arriving after it has landed rather than sitting flat; the long
            // release overlaps consecutive onsets into the widening stack the profile writes.
            // Softer and rounder than `Glacier Pad` (harmonics 0.84 against 0.72, brightness
            // 0.34 against 0.46) so the shelf's two residents are told apart by timbre as well
            // as by motion. No vibrato: the movement is the envelope.
            return patch("41", "Bloom Pad",
                a: 1.400, d: 5.00, s: 0.62, r: 6.50,
                harm: 0.84, hl: 0.68, bright: 0.34, noise: 0.02, color: "Pink", shape: "Natural",
                cutoff: 3100, res: 0.12, lfoAmt: 0.16, lfoRate: 0.06, lfoDepth: 0.24,
                revMix: 0.52, revDecay: 8.00, vibRate: 0, vibDepth: 0,
                uni: 2, det: 8)
        case .dubTechno:
            return patch("D1", "Dub Chord",
                a: 0.06, d: 0.9, s: 0.45, r: 3.8,
                harm: 0.93, hl: 0.72, bright: 0.16, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 720, res: 0.10, lfoAmt: 0.18, lfoRate: 0.12, lfoDepth: 0.30,
                revMix: 0.58, revDecay: 5.5, vibRate: 0, vibDepth: 0,
                uni: 2, det: 8)                                  // subtle width on the dub stab
        case .acidTechno:
            // #254 — the squelch is RESONANCE, not brightness: a moderate cutoff with the
            // highest filter resonance of any genre patch, a near-instant attack and a short
            // decay so each sequence step plucks and closes. Brightness stays low (0.18) so it
            // reads acid, not harsh — the founder's "einige Sounds stechen kalt aus dem mix
            // raus" law forbids buying character with top end. Mono-ish (no unison) because a
            // 303 is one oscillator; width would smear the sequence.
            return patch("EC", "Acid Squelch",
                a: 0.002, d: 0.28, s: 0.10, r: 0.35,
                harm: 0.88, hl: 0.66, bright: 0.18, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 900, res: 0.46, lfoAmt: 0.30, lfoRate: 0.9, lfoDepth: 0.42,
                revMix: 0.22, revDecay: 1.4, vibRate: 0, vibDepth: 0)
        case .deepHouse:
            // #254 — a warm electric-piano-ish chord bed: soft attack so the offbeat chord
            // blooms instead of clicking, long-ish release so it overlaps its own skank, wide
            // unison for the lush 7th, generous reverb. The deliberate opposite of the acid
            // patch above (slow/wide/warm vs instant/mono/resonant).
            return patch("ED", "House Chord",
                a: 0.05, d: 1.1, s: 0.62, r: 2.6,
                harm: 0.94, hl: 0.80, bright: 0.30, noise: 0.01, color: "Pink", shape: "Natural",
                cutoff: 2200, res: 0.09, lfoAmt: 0.10, lfoRate: 0.14, lfoDepth: 0.22,
                revMix: 0.54, revDecay: 3.4, vibRate: 0, vibDepth: 0,
                uni: 3, det: 11)
        case .upliftingTrance:
            // #254 batch 3 — a PLUCKED SUS STAB, not a pad: fast attack with a short decay and a
            // long-ish release so each on-beat stab plucks and then rings into the next. The cut
            // comes from `brightness` 0.52 (which ties the roster maximum), NOT from the spectral
            // shape: ⚠️ the first version of this patch passed `shape: "Bright"` (= "Boosted
            // highs") while its own comment cited the founder's "einige Sounds stechen kalt aus
            // dem Mix raus" law — it would have been the only "Bright" among 31 genre patches and
            // it contradicts this file's own universal rule ("Natural/Dark spectral shapes").
            // "Natural" keeps the top end honest and the cut survives. Unison + detune is the one
            // place a supersaw-ish width belongs; the sus voicing has no third to smear.
            return patch("F0", "Trance Pluck",
                a: 0.004, d: 0.22, s: 0.28, r: 0.55,
                harm: 0.72, hl: 0.52, bright: 0.52, noise: 0.0, color: "White", shape: "Natural",
                cutoff: 3600, res: 0.24, lfoAmt: 0.14, lfoRate: 0.35, lfoDepth: 0.20,
                revMix: 0.30, revDecay: 2.6, vibRate: 0, vibDepth: 0,
                uni: 3, det: 12)
        case .techHouse:
            // #254 batch 3 — a DRY REEDY SHELL: the shortest release of any genre patch here so
            // the stab stops before the next one lands (that gap IS the groove), a mid cutoff and
            // almost no reverb in the patch itself — the space, such as it is, comes from the FX
            // preset's tight damped room. Darker than the trance pluck above (0.34) so the two
            // never read as the same stab at a different tempo.
            return patch("F1", "House Shell",
                a: 0.003, d: 0.16, s: 0.12, r: 0.18,
                harm: 0.80, hl: 0.58, bright: 0.34, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 2400, res: 0.30, lfoAmt: 0.10, lfoRate: 1.2, lfoDepth: 0.16,
                revMix: 0.10, revDecay: 0.9, vibRate: 0, vibDepth: 0)
        case .minimalTechno:
            // #254 batch 4 — A CLICK WITH WEIGHT. Short everywhere so the dyad punctuates rather
            // than sounds, low brightness (0.24) because minimal techno is defined by what is not
            // there, and a low cutoff with moderate resonance so the fifth reads as body. Almost no
            // patch reverb: the FX preset's dry 0.36 room is the whole space this genre gets.
            // Deliberately DARKER than the house shell above (0.34) — the two are neighbours in
            // tempo and both stab, so brightness is one of the few axes left to tell them apart.
            return patch("F2", "Minimal Stab",
                a: 0.002, d: 0.12, s: 0.10, r: 0.14,
                harm: 0.62, hl: 0.70, bright: 0.24, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 1900, res: 0.34, lfoAmt: 0.06, lfoRate: 0.8, lfoDepth: 0.10,
                revMix: 0.06, revDecay: 0.7, vibRate: 0, vibDepth: 0)
        case .deepTech:
            // #983 S3 — A DARK SHELL. Brightness 0.28 sits between the house shell (0.34) and the
            // minimal stab (0.24) — the three are tempo neighbours and all stab, so brightness is
            // the axis that tells them apart. Short but not clicky: a hair more decay and release
            // than tech house so the third-less shell has a body to read as "deep", a lower cutoff
            // for the same reason, and a slow shallow filter movement so the stab breathes across
            // a bar. Little patch reverb — the FX preset's dry 0.40 room is the space.
            return patch("F7", "Deep Shell",
                a: 0.004, d: 0.22, s: 0.16, r: 0.20,
                harm: 0.78, hl: 0.56, bright: 0.28, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 2100, res: 0.28, lfoAmt: 0.12, lfoRate: 0.9, lfoDepth: 0.14,
                revMix: 0.12, revDecay: 1.1, vibRate: 0, vibDepth: 0)
        case .darkMinimal:
            // #983 S4 — A FLÄCHE WITH AN EDGE. The darkest PAD patch of the stabbing family
            // (brightness 0.18, under minimal's 0.24), with a slower attack than any of its
            // neighbours (0.030 — the wide fifth swells into the beat instead of clicking) and a
            // long sustain so the stab is a held block, not a tick. Low cutoff with moderate
            // resonance for the edge, a slow deep filter LFO so the block moves across the bar,
            // and almost no patch reverb — the FX preset's 0.38 room is the space.
            return patch("F9", "Dark Edge",
                a: 0.030, d: 0.40, s: 0.55, r: 0.30,
                harm: 0.70, hl: 0.60, bright: 0.18, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 1400, res: 0.30, lfoAmt: 0.10, lfoRate: 0.3, lfoDepth: 0.18,
                revMix: 0.10, revDecay: 1.4, vibRate: 0, vibDepth: 0)
        case .psyProgHouse:
            // #983 S5 — A PLUCK WITH A TAIL. Instant attack, a pluck decay, and the LONGEST release
            // of the stabbing family (0.60 — the trance pluck is 0.55) so each stab hangs into the
            // ping-pong echo instead of stopping dead. Brightness 0.44 sits between the house shell
            // (0.34) and the trance pluck (0.52, roster maximum); a high cutoff with real resonance
            // for the plucky front edge, and a slow filter LFO so a bar of stabs breathes.
            // ⛔ "Psy Pluck" is psytrance's name (DB) — GenrePatchesTests pins name uniqueness.
            return patch("FB", "Prog Pluck",
                a: 0.002, d: 0.26, s: 0.18, r: 0.60,
                harm: 0.74, hl: 0.54, bright: 0.44, noise: 0.0, color: "White", shape: "Natural",
                cutoff: 3200, res: 0.36, lfoAmt: 0.12, lfoRate: 0.3, lfoDepth: 0.18,
                revMix: 0.16, revDecay: 1.6, vibRate: 0, vibDepth: 0)
        case .detroitTechno:
            // #254 batch 4 — A WARM CHORD, not a stab: a slower attack than any other genre in this
            // family so the ninth chord SWELLS into the comp, a long-ish release so the syncopation
            // leaves a tail, and high sustain because the chord is the subject. Rich low harmonics
            // with a mid-high cutoff so the 9th on top stays audible without turning cold — the
            // founder's "einige Sounds stechen kalt aus dem Mix raus" law is the reason the
            // brightness stops at 0.44 and the shape stays Natural rather than Bright.
            // Unison gives the string-machine width the genre lives on; the FX chorus adds the rest.
            return patch("F3", "Detroit Keys",
                a: 0.018, d: 0.30, s: 0.46, r: 0.62,
                harm: 0.88, hl: 0.66, bright: 0.44, noise: 0.0, color: "White", shape: "Natural",
                cutoff: 3100, res: 0.18, lfoAmt: 0.12, lfoRate: 0.5, lfoDepth: 0.18,
                revMix: 0.22, revDecay: 1.8, vibRate: 0, vibDepth: 0,
                uni: 3, det: 9)
        case .deepDrone:
            // #254 batch 2 — a BED, not a note: the slowest attack of any genre patch so the
            // drone swells rather than starts, the longest release so it never fully stops, and
            // a high sustain because there is nothing else to hear. Rich low harmonics (harm 0.98,
            // hl 0.85) with the LOWEST brightness in the roster — the founder's "einige Sounds
            // stechen kalt aus dem mix raus" law matters most here, where the whole character is
            // warmth. Wide unison for a drone that fills the room without moving.
            return patch("EE", "Drone Bed",
                a: 1.8, d: 6.0, s: 0.88, r: 7.5,
                harm: 0.98, hl: 0.85, bright: 0.10, noise: 0.02, color: "Pink", shape: "Dark",
                cutoff: 620, res: 0.06, lfoAmt: 0.14, lfoRate: 0.05, lfoDepth: 0.26,
                revMix: 0.62, revDecay: 8.5, vibRate: 0, vibDepth: 0,
                uni: 4, det: 6)
        case .ambientPulse:
            // #254 batch 2 — the counterpart: each sequence step must have an ATTACK to be heard
            // as motion, so a near-instant onset and a short-ish decay, but a long release so the
            // steps overlap into the pad the drone genre holds outright. This is the same
            // instant/short shape as the acid patch and the opposite intent — the difference is
            // brightness (0.26 vs 0.18 with a much higher cutoff) and resonance (0.10 vs 0.46):
            // acid squelches, this one rings.
            return patch("EF", "Pulse Bell",
                a: 0.01, d: 0.9, s: 0.25, r: 2.2,
                harm: 0.92, hl: 0.72, bright: 0.26, noise: 0.01, color: "Pink", shape: "Natural",
                cutoff: 3000, res: 0.10, lfoAmt: 0.12, lfoRate: 0.09, lfoDepth: 0.24,
                revMix: 0.50, revDecay: 4.2, vibRate: 0, vibDepth: 0,
                uni: 2, det: 7)
        case .trap:
            return patch("D2", "Trap Keys",
                a: 0.01, d: 1.0, s: 0.30, r: 2.4,
                harm: 0.90, hl: 0.74, bright: 0.42, noise: 0.0, color: "Pink", shape: "Natural",
                cutoff: 3200, res: 0.10, lfoAmt: 0.08, lfoRate: 0.18, lfoDepth: 0.18,
                revMix: 0.52, revDecay: 3.6, vibRate: 4, vibDepth: 0.07)  // kept tight (trap = mono-ish keys)
        case .vaporwave:
            return patch("D4", "Vapor Pad",
                a: 0.8, d: 1.6, s: 0.88, r: 4.5,
                harm: 0.92, hl: 0.80, bright: 0.26, noise: 0.01, color: "Pink", shape: "Natural",
                cutoff: 1500, res: 0.08, lfoAmt: 0.14, lfoRate: 0.08, lfoDepth: 0.30,
                revMix: 0.62, revDecay: 5.5, vibRate: 0, vibDepth: 0,
                uni: 3, det: 12)                                 // lush wide pad
        case .eighties:
            return patch("D5", "Neon Keys",
                a: 0.04, d: 0.6, s: 0.78, r: 2.2,
                harm: 0.93, hl: 0.78, bright: 0.48, noise: 0.0, color: "Pink", shape: "Natural",
                cutoff: 3200, res: 0.12, lfoAmt: 0.10, lfoRate: 0.22, lfoDepth: 0.18,
                revMix: 0.48, revDecay: 3.2, vibRate: 4.5, vibDepth: 0.08,
                uni: 2, det: 10)
        case .disco:
            return patch("D6", "Velvet Strings",
                a: 0.10, d: 0.8, s: 0.72, r: 2.0,
                harm: 0.92, hl: 0.80, bright: 0.46, noise: 0.015, color: "Pink", shape: "Natural",
                cutoff: 3050, res: 0.12, lfoAmt: 0.10, lfoRate: 0.24, lfoDepth: 0.26,
                revMix: 0.46, revDecay: 3.0, vibRate: 5, vibDepth: 0.07,
                uni: 3, det: 15)   // lush wide shimmer — the bright-warm ensemble pole (ultrascan step 1)
        case .synthwave:
            return patch("D7", "Neon Lead",
                a: 0.02, d: 0.5, s: 0.72, r: 1.8,
                harm: 0.94, hl: 0.78, bright: 0.48, noise: 0.0, color: "Pink", shape: "Natural",  // warmth pass 2
                cutoff: 3300, res: 0.16, lfoAmt: 0.18, lfoRate: 0.18, lfoDepth: 0.28,
                revMix: 0.44, revDecay: 3.4, vibRate: 4.5, vibDepth: 0.10,
                uni: 2, det: 11)
        case .earlySynth:
            return patch("D8", "Berlin Seq",
                a: 0.02, d: 0.5, s: 0.55, r: 1.6,
                harm: 0.92, hl: 0.76, bright: 0.40, noise: 0.0, color: "Pink", shape: "Natural",
                cutoff: 2200, res: 0.18, lfoAmt: 0.30, lfoRate: 0.45, lfoDepth: 0.45,
                revMix: 0.46, revDecay: 3.6, vibRate: 0, vibDepth: 0,
                uni: 2, det: 8)
        case .futuristic:
            return patch("D9", "Crystal Air",
                a: 0.10, d: 1.0, s: 0.70, r: 3.2,
                harm: 0.88, hl: 0.78, bright: 0.48, noise: 0.01, color: "Pink", shape: "Natural",  // warmth pass 2
                cutoff: 3200, res: 0.10, lfoAmt: 0.12, lfoRate: 0.12, lfoDepth: 0.22,
                revMix: 0.58, revDecay: 4.8, vibRate: 0, vibDepth: 0,
                uni: 2, det: 10)
        case .sciFi:
            return patch("DA", "Nebula",
                a: 0.5, d: 1.4, s: 0.78, r: 4.0,
                harm: 0.86, hl: 0.80, bright: 0.34, noise: 0.01, color: "Pink", shape: "Dark",
                cutoff: 1900, res: 0.12, lfoAmt: 0.22, lfoRate: 0.10, lfoDepth: 0.40,
                revMix: 0.62, revDecay: 6.0, vibRate: 0, vibDepth: 0,
                uni: 3, det: 14)                                 // widest — deep-space pad
        case .psytrance:
            return patch("DB", "Psy Pluck",
                a: 0.015, d: 0.4, s: 0.55, r: 1.0,
                harm: 0.94, hl: 0.78, bright: 0.48, noise: 0.0, color: "Pink", shape: "Natural",  // warmth pass 2
                cutoff: 3200, res: 0.16, lfoAmt: 0.26, lfoRate: 0.55, lfoDepth: 0.45,
                revMix: 0.40, revDecay: 2.6, vibRate: 0, vibDepth: 0,
                uni: 2, det: 8)
        case .stillMeditation:
            return patch("DC", "Deep Drone",
                a: 1.4, d: 1.8, s: 0.92, r: 6.0,
                harm: 0.90, hl: 0.84, bright: 0.18, noise: 0.008, color: "Pink", shape: "Dark",
                cutoff: 950, res: 0.06, lfoAmt: 0.10, lfoRate: 0.05, lfoDepth: 0.35,
                revMix: 0.66, revDecay: 7.0, vibRate: 0, vibDepth: 0,
                uni: 2, det: 8)
        case .classical:
            return patch("E1", "Chamber Strings",
                a: 0.35, d: 1.0, s: 0.80, r: 3.2,
                harm: 0.90, hl: 0.82, bright: 0.31, noise: 0.02, color: "Pink", shape: "Natural",
                cutoff: 2450, res: 0.08, lfoAmt: 0.06, lfoRate: 0.10, lfoDepth: 0.15,
                revMix: 0.52, revDecay: 4.0, vibRate: 5, vibDepth: 0.10,
                uni: 4, det: 16)   // slow orchestral bloom, widest section — the strings pole (ultrascan step 1)
        case .jazz:
            return patch("E2", "Warm Rhodes",
                a: 0.02, d: 0.9, s: 0.60, r: 1.8,
                harm: 0.90, hl: 0.78, bright: 0.33, noise: 0.0, color: "Pink", shape: "Natural",
                cutoff: 2250, res: 0.10, lfoAmt: 0.08, lfoRate: 0.20, lfoDepth: 0.20,
                revMix: 0.40, revDecay: 2.6, vibRate: 4, vibDepth: 0.06,
                uni: 2, det: 6)   // dark, round Rhodes — the mellow-keys pole (ultrascan step 1)
        case .klezmer:
            return patch("E3", "Clarinet Reed",
                a: 0.04, d: 0.5, s: 0.70, r: 1.4,
                harm: 0.92, hl: 0.80, bright: 0.38, noise: 0.02, color: "Pink", shape: "Natural",  // warmth pass 2
                cutoff: 2600, res: 0.12, lfoAmt: 0.10, lfoRate: 0.25, lfoDepth: 0.20,
                revMix: 0.38, revDecay: 2.4, vibRate: 6.2, vibDepth: 0.15)   // solo woody reed, most expressive vibrato, no unison (ultrascan step 1)
        case .oriental:
            return patch("E4", "Reed Strings",
                a: 0.08, d: 0.8, s: 0.72, r: 2.2,
                harm: 0.90, hl: 0.80, bright: 0.44, noise: 0.02, color: "Pink", shape: "Natural",
                cutoff: 2650, res: 0.12, lfoAmt: 0.10, lfoRate: 0.30, lfoDepth: 0.25,
                revMix: 0.46, revDecay: 3.2, vibRate: 6, vibDepth: 0.14,
                uni: 2, det: 9)   // reedy waver — expressive vibrato + faster movement (ultrascan step 1)
        case .punk:
            return patch("E5", "Buzz Saw",
                a: 0.010, d: 0.3, s: 0.60, r: 0.6,   // softer attack (was 0.005) — no cold stab
                harm: 0.95, hl: 0.80, bright: 0.52, noise: 0.0, color: "Pink", shape: "Natural",
                cutoff: 3400, res: 0.22, lfoAmt: 0.05, lfoRate: 0.20, lfoDepth: 0.10,
                revMix: 0.22, revDecay: 1.2, vibRate: 0, vibDepth: 0,
                uni: 2, det: 10)                                 // wide buzzsaw
        case .rocknroll:
            return patch("E6", "Twang",
                a: 0.012, d: 0.4, s: 0.50, r: 0.9,
                harm: 0.93, hl: 0.78, bright: 0.48, noise: 0.0, color: "Pink", shape: "Natural",  // warmth pass 2
                cutoff: 3200, res: 0.18, lfoAmt: 0.06, lfoRate: 0.20, lfoDepth: 0.12,
                revMix: 0.30, revDecay: 1.6, vibRate: 0, vibDepth: 0,
                uni: 2, det: 8)
        case .rock:
            return patch("E7", "Driven Lead",
                a: 0.012, d: 0.4, s: 0.60, r: 1.0,
                harm: 0.94, hl: 0.80, bright: 0.48, noise: 0.0, color: "Pink", shape: "Natural",  // warmth pass 2
                cutoff: 3300, res: 0.20, lfoAmt: 0.06, lfoRate: 0.20, lfoDepth: 0.12,
                revMix: 0.30, revDecay: 1.8, vibRate: 0, vibDepth: 0,
                uni: 2, det: 9)
        case .ska:
            return patch("E8", "Skank Organ",
                a: 0.012, d: 0.25, s: 0.40, r: 0.5,
                harm: 0.92, hl: 0.78, bright: 0.46, noise: 0.0, color: "Pink", shape: "Natural",  // warmth pass 2
                cutoff: 3100, res: 0.16, lfoAmt: 0.06, lfoRate: 0.20, lfoDepth: 0.12,
                revMix: 0.28, revDecay: 1.4, vibRate: 0, vibDepth: 0,
                uni: 2, det: 8)                                  // organ needs ensemble body
        case .rocksteady:
            return patch("E9", "Warm Organ",
                a: 0.02, d: 0.5, s: 0.78, r: 1.4,
                harm: 0.90, hl: 0.80, bright: 0.30, noise: 0.0, color: "Pink", shape: "Natural",
                cutoff: 2050, res: 0.10, lfoAmt: 0.12, lfoRate: 0.30, lfoDepth: 0.22,
                revMix: 0.36, revDecay: 2.2, vibRate: 0, vibDepth: 0,
                uni: 2, det: 8)   // dark drawbar organ, flat sustain + rotary LFO, no vibrato (ultrascan step 1)
        case .heavyMetal:
            return patch("EA", "Metal Rig",
                a: 0.010, d: 0.4, s: 0.55, r: 0.8,   // softer attack (was 0.004) — tame the stab
                harm: 0.95, hl: 0.82, bright: 0.50, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 3000, res: 0.18, lfoAmt: 0.06, lfoRate: 0.20, lfoDepth: 0.12,
                revMix: 0.26, revDecay: 1.6, vibRate: 0, vibDepth: 0,
                uni: 2, det: 9)                                  // wide detuned guitar wall
        case .doom:
            return patch("EB", "Doom Wall",
                a: 0.02, d: 1.2, s: 0.70, r: 3.0,
                harm: 0.90, hl: 0.84, bright: 0.28, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 1400, res: 0.18, lfoAmt: 0.10, lfoRate: 0.08, lfoDepth: 0.30,
                revMix: 0.50, revDecay: 4.5, vibRate: 0, vibDepth: 0,
                uni: 2, det: 10)
        case .selfObservation:
            return patch("D3", "Calm Pad",
                a: 1.0, d: 1.3, s: 0.88, r: 4.2,
                harm: 0.92, hl: 0.80, bright: 0.22, noise: 0.01, color: "Pink", shape: "Natural",
                cutoff: 1300, res: 0.07, lfoAmt: 0.12, lfoRate: 0.08, lfoDepth: 0.30,
                revMix: 0.58, revDecay: 5.5, vibRate: 0, vibDepth: 0,
                uni: 2, det: 8)
        case .drift:
            // G2 airy Fläche: floats a register above Deep Drone / Calm Pad — a touch
            // brighter top (0.30) + a wider unison shimmer (3/12) + a very slow, deep
            // filter drift (rate 0.06, depth 0.42) and the biggest space of the three,
            // so it reads weightless rather than dark. Distinct timbre from both
            // sibling Flächen (guarded by GenrePatchesTests uniqueness).
            return patch("DD", "Drift Pad",
                a: 1.6, d: 1.8, s: 0.90, r: 6.5,
                harm: 0.91, hl: 0.82, bright: 0.30, noise: 0.012, color: "Pink", shape: "Natural",
                cutoff: 1650, res: 0.06, lfoAmt: 0.14, lfoRate: 0.06, lfoDepth: 0.42,
                revMix: 0.64, revDecay: 7.5, vibRate: 0, vibDepth: 0,
                uni: 3, det: 12)
        case .contemplation:
            // G2 grounded Fläche: the DARK, LOW pole of the ambient family — the
            // slowest bloom, lowest cutoff and darkest spectral shape of the three,
            // with the longest reverb tail. Sits under Deep Drone / Calm Pad / Drift
            // so the family spans airy→grounded. Distinct timbre (name + id unique).
            return patch("DE", "Still Pad",
                a: 1.8, d: 2.0, s: 0.92, r: 7.0,
                harm: 0.90, hl: 0.83, bright: 0.16, noise: 0.01, color: "Pink", shape: "Dark",
                cutoff: 1050, res: 0.05, lfoAmt: 0.10, lfoRate: 0.05, lfoDepth: 0.32,
                revMix: 0.62, revDecay: 8.0, vibRate: 0, vibDepth: 0,
                uni: 2, det: 7)
        }
    }

    /// Builds a SynthPatch in the strict declared argument order. The short
    /// `suffix` becomes a stable UUID so a genre's patch identity survives
    /// relaunch (and is distinct per genre).
    ///
    /// `timbre`/`tblend` route the voice through a built-in instrument spectrum
    /// (EchoelDDSP.InstrumentTimbre rawValue; "" = pure synth). `uni`/`det` stack
    /// detuned unison voices for ensemble width (nil = single voice). All default
    /// to "off" so an un-enriched genre is byte-identical to before this cycle.
    /// #983 S2 — the genre's BASS timbre, played by the dedicated bass voice
    /// (`EchoelmusicApp.bassVoice` via `PianoRollModel.applyBassPatch`). `nil` = the genre has no
    /// bass instrument of its own and its `.bass` notes keep playing through the pad voice an
    /// octave down, exactly as before S2.
    ///
    /// THE INVARIANT, pinned by `TheBassRoleHasItsOwnVoiceTests`: a genre has a bass patch IF AND
    /// ONLY IF it has a `bassGrammar`. A figure without a bass instrument is a pad playing a
    /// bassline; an instrument without a figure is a new timbre on the old walk — either half
    /// alone is the "richtig gute Bass-Loops" ask done by halves. Every bass patch is DARKER,
    /// SHORTER and LOWER-CUT than its genre's pad patch, dry (the Bass bus insert and the sub carry
    /// the space), and MONO (`uni: 1` is honoured verbatim by `PolySynthVoice.apply`; a detuned
    /// unison on a bass smears the fundamental). Values sit on the Sound-panel grid
    /// (`SoundRowsCanReachTheShippedPatchesTests`) so a founder edit never rounds them.
    var bassPatch: SynthPatch? {
        switch self {
        case .boomBapHipHop:
            // #1289 G6b — the FOURTH owner of `sparseSub`. Long and soft where the techno subs on
            // that figure are short and hard: a boom-bap sub is felt for the whole bar. Cutoff
            // 580, deliberately ABOVE "Minimal Sub"'s 520 so that patch keeps its "lowest cutoff,
            // darkest in the file" claim — third of the four subs on this figure by cutoff, and
            // the darkest of them by brightness (0.12 against 0.14/0.15/0.18) and by harmonic
            // level (0.24 against 0.36/0.40/0.44).
            // ⛔ This line first said "darker than every other patch on this figure" without
            // naming an axis, which is false on the axis a reader assumes: Minimal Sub (520) and
            // Dark Sub (560) both cut lower. A darkness claim needs its axis, or it is the
            // roster-wide superlative #1287 keeps retracting.
            return patch("57", "Dust Sub",
                a: 0.008, d: 0.45, s: 0.64, r: 0.18,
                harm: 0.92, hl: 0.24, bright: 0.12, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 580, res: 0.08, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .electroFunk:
            // #1289 G6b — the FIFTH `drivingEighths` owner. At 118 BPM an eighth is 0.254 s and
            // the envelope finishes well inside it, but every stage still sits ABOVE "Psy Bass"
            // (0.004/0.17/0.10 against 0.002/0.14/0.08) so that patch keeps the shortest-envelope
            // claim its own arm makes — measured before writing, because #1288's first draft of
            // "Cold Sub" broke exactly this and nothing would have gone red.
            return patch("58", "Snap Sub",
                a: 0.004, d: 0.17, s: 0.22, r: 0.10,
                harm: 0.80, hl: 0.52, bright: 0.26, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 940, res: 0.24, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .rootsReggae:
            // #1289 G6b — the FOURTH `offbeatEighths` owner, and the roundest of them: at 76 BPM
            // there is time for a slow attack and a long decay, which is what makes a reggae bass
            // read as PLAYED rather than programmed. No resonance at all.
            return patch("59", "Roll Sub",
                a: 0.012, d: 0.50, s: 0.72, r: 0.22,
                harm: 0.94, hl: 0.22, bright: 0.10, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 700, res: 0.06, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .blackMetal:
            // #1288 G6a — the THIRD owner of `drivingEighths` (after `techHouse` and `deepTech`),
            // on its own voice: figure shared, voice never. At 180 BPM an eighth is 0.167 s, and
            // 0.003 + 0.15 + 0.085 fits inside it, so every note re-articulates — and the cutoff is the HIGHEST of any
            // bass patch in this file (1180) on purpose: under a power chord the sub has to be
            // heard as a line, not felt as weight.
            // ⛔ TWO drafting errors here, both caught by measuring the arms rather than reading
            // them. The cutoff was 1100, which TIES "Psy Bass" — and a tie is the shape a
            // "highest" sentence breaks on without anything going red (#1287). And the envelope
            // was 0.002/0.12/0.30/0.07, SHORTER than "Psy Bass" on decay and release, which would
            // have taken that patch's "shortest envelope of every bass patch here" — a claim
            // quoted one arm away and pinned by nothing. Both stages now sit strictly between
            // Psy Bass and "Void Sub", so the ordering that was there survives.
            return patch("51", "Cold Sub",
                a: 0.003, d: 0.15, s: 0.30, r: 0.085,
                harm: 0.86, hl: 0.50, bright: 0.30, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 1180, res: 0.20, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .modalJazz:
            // #1288 G6a — the FOURTH `drivingEighths` owner, and the opposite end of that figure
            // from "Cold Sub": an upright-leaning walk wants LENGTH, so decay and sustain are
            // long and the release lets one note lean into the next. Darkest cutoff of the three
            // patches this batch adds (540), no resonance at all.
            // ⛔ Drafted at 420, which would have TAKEN "Minimal Sub"'s "lowest cutoff, darkest
            // in the file" — a claim carried by that patch and quoted in two neighbouring arms,
            // pinned only PAIRWISE by `GenreDarkMinimalTests`, so a roster-wide break would not
            // have reddened anything. 540 keeps it, and keeps Minimal Sub's 520 un-tied.
            return patch("52", "Walk Sub",
                a: 0.010, d: 0.60, s: 0.70, r: 0.20,
                harm: 0.92, hl: 0.26, bright: 0.12, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 540, res: 0.06, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .soulBallad:
            // #1288 G6a — the THIRD owner of `offbeatEighths` (after `deepHouse` and
            // `afroHouse`). Rounder and softer than either: at 72 BPM the offbeat has a whole
            // half-beat to itself, so the attack can be slow enough to read as fingered.
            //
            // ⚠️ NOT named "Round Sub" as the design sheet drafted — `afroHouse` (#1286) already
            // ships that name, and the pre-batch check caught it. Same class as "Dark Sub" one
            // batch earlier; the preset list is keyed by id and READ by name.
            return patch("53", "Velvet Sub",
                a: 0.014, d: 0.58, s: 0.66, r: 0.24,
                harm: 0.90, hl: 0.24, bright: 0.14, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 620, res: 0.08, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .industrialTechno:
            // #1286 G5b — shares `minimalTechno`'s `sparseSub` FIGURE, so the patch is where the
            // two differ: a higher cutoff than "Minimal Sub" (600 vs 520, which keeps that
            // patch's "lowest cutoff, darkest in the file" claim true) and more harmonic content,
            // so the held root has iron in it rather than only weight. Dry and mono like every
            // bass patch here.
            return patch("45", "Iron Sub",
                a: 0.004, d: 0.40, s: 0.55, r: 0.12,
                harm: 0.94, hl: 0.44, bright: 0.18, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 600, res: 0.22, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .afroHouse:
            // #1286 G5b — shares `deepHouse`'s `offbeatEighths` figure. Rounder and longer than
            // the four-on-floor subs because the bass answers the chord here instead of anchoring
            // under it: more decay and sustain, a softer cutoff, no resonance to bite with.
            return patch("46", "Round Sub",
                a: 0.006, d: 0.52, s: 0.62, r: 0.16,
                harm: 0.90, hl: 0.48, bright: 0.16, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 680, res: 0.14, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .darkPsyTrance:
            // #1286 G5b — the SECOND owner of `rollingSixteenths`, on its own patch, which is the
            // whole shape of that figure's licence: share the figure, never the voice. Every
            // envelope stage sits a hair ABOVE "Psy Bass" (0.003/0.16/0.12/0.09 against
            // 0.002/0.14/0.10/0.08) so that patch keeps its "shortest envelope of every bass
            // patch here" claim, and darker and lower-cut than it so the two rolls are told apart
            // by weight: psy-prog's roll is a LINE, this one is the floor.
            //
            // ⚠️ NOT named "Dark Sub" as the design sheet drafted — `darkMinimal` already ships a
            // patch under that name, and two patches with one name is the kind of collision that
            // reads as a duplicate rather than as a choice.
            return patch("47", "Void Sub",
                a: 0.003, d: 0.16, s: 0.12, r: 0.09,
                harm: 0.88, hl: 0.42, bright: 0.22, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 880, res: 0.28, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .deepHouse:
            // A round, short sub-pluck under the offbeat chord: fast-but-not-clicky attack, a
            // decay that lets the "&" bloom for an 8th, a low cutoff so it reads as weight not
            // tone, and a tail short enough to leave the downbeat hole EMPTY (S1's whole point).
            return patch("F4", "House Sub",
                a: 0.006, d: 0.34, s: 0.30, r: 0.16,
                harm: 0.90, hl: 0.40, bright: 0.18, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 640, res: 0.20, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .techHouse:
            // The rolling 8th-note tech bass: the shortest release of the three so every hit is
            // its own event, a touch more resonance and a mid-low cutoff for the growl, plus a
            // slow, shallow filter wobble so a bar of 8ths does not read as a metronome.
            return patch("F5", "Tech Bass",
                a: 0.003, d: 0.20, s: 0.18, r: 0.10,
                harm: 0.84, hl: 0.52, bright: 0.26, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 900, res: 0.28, lfoAmt: 0.08, lfoRate: 0.5, lfoDepth: 0.10,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .minimalTechno:
            // The held dark sub: a softer attack (the root is held half a bar, it does not need
            // a click), high sustain, the lowest cutoff and the darkest patch in the file —
            // minimal is defined by what is absent, on the bass most of all.
            return patch("F6", "Minimal Sub",
                a: 0.012, d: 0.60, s: 0.62, r: 0.12,
                harm: 0.94, hl: 0.36, bright: 0.14, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 520, res: 0.16, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .deepTech:
            // #983 S3 — the driven 8th-note deep-tech bass: rounder than the tech bass (a touch
            // more decay and sustain, a lower cutoff so it reads as weight under the third-less
            // shell) with a slow shallow filter wobble so a bar of 8ths breathes; the release is
            // the shortest thing in the patch so every hit stays its own event.
            return patch("F8", "Deep Bass",
                a: 0.003, d: 0.24, s: 0.24, r: 0.11,
                harm: 0.88, hl: 0.46, bright: 0.20, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 760, res: 0.24, lfoAmt: 0.06, lfoRate: 0.4, lfoDepth: 0.08,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .darkMinimal:
            // #983 S4 — the held dark sub under the wide fifth: shares minimal's `sparseSub`
            // figure, so the patch is where the two differ — a touch more harmonic content and a
            // slightly higher cutoff than "Minimal Sub" (560 vs 520; that patch keeps its "lowest
            // cutoff, darkest in the file" claim), a shorter release so the late fifth reads as an
            // event, dry and mono like every bass patch here.
            return patch("FA", "Dark Sub",
                a: 0.010, d: 0.50, s: 0.60, r: 0.14,
                harm: 0.92, hl: 0.40, bright: 0.15, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 560, res: 0.18, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        case .psyProgHouse:
            // #983 S5 — the rolling-16th psy bass: the SHORTEST envelope of every bass patch here
            // (three hits per beat at 132 must each be their own event), a mid-low cutoff with
            // enough resonance to growl, brighter than the house/tech/deep subs because the roll
            // is meant to be HEARD as a line, not felt as weight — still darker, shorter and
            // lower-cut than its pad, dry and mono like the rest.
            return patch("FC", "Psy Bass",
                a: 0.002, d: 0.14, s: 0.10, r: 0.08,
                harm: 0.86, hl: 0.50, bright: 0.30, noise: 0.0, color: "Pink", shape: "Dark",
                cutoff: 1100, res: 0.32, lfoAmt: 0.0, lfoRate: 0.0, lfoDepth: 0.0,
                revMix: 0.0, revDecay: 0.5, vibRate: 0, vibDepth: 0,
                uni: 1, det: 0)
        default:
            return nil
        }
    }

    private func patch(_ suffix: String, _ name: String,
                       a: Float, d: Float, s: Float, r: Float,
                       harm: Float, hl: Float, bright: Float, noise: Float,
                       color: String, shape: String,
                       cutoff: Float, res: Float, lfoAmt: Float, lfoRate: Float, lfoDepth: Float,
                       revMix: Float, revDecay: Float, vibRate: Float, vibDepth: Float,
                       timbre: String = "", tblend: Float = 0,
                       uni: Int? = nil, det: Float? = nil) -> SynthPatch {
        // Gentle default voicing: lift the per-genre brightness/upper-partial body only
        // ADAPTIVELY (×(1-bright)/×(1-hl)) so a dull genre reads less dull on device while
        // an already-bright genre is barely touched. Coefficients TRIMMED 2026-07-07
        // (founder: "einige Sounds stechen kalt aus dem mix raus vermeide das") from
        // 0.12/0.06 — the earlier "brighter/livelier" lift pushed the top end forward and
        // made some voices read cold; the smaller lift keeps life without the glassy edge.
        let liftedBright = min(1, bright + 0.05 * (1 - bright))
        let liftedHL     = min(1, hl + 0.03 * (1 - hl))
        return SynthPatch(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(suffix)") ?? UUID(),
            name: name,
            attack: a, decay: d, sustain: s, release: r,
            envelopeCurve: "Exponential",
            harmonicity: harm, harmonicLevel: liftedHL, brightness: liftedBright,
            noiseLevel: noise, noiseColor: color, spectralShape: shape,
            filterCutoff: cutoff, filterResonance: res, lfoToFilterDepth: lfoAmt,
            filterLFORate: lfoRate, filterLFODepth: lfoDepth,
            reverbMix: revMix, reverbDecay: revDecay,
            vibratoRate: vibRate, vibratoDepth: vibDepth,
            timbreProfile: timbre, timbreBlend: tblend,
            unisonVoices: uni, unisonDetuneCents: det
        )
    }
}

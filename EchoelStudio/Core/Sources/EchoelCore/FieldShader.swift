import Foundation

/// The Metal Shading Language source of the app's GPU pictures, kept here as plain text so the
/// gate can compile it: the app compiles each at RUNTIME (`makeLibrary(source:)`; it ships no
/// `.metal` file), so a syntax error passes every build and only shows on the device as a flat
/// picture. `FieldShaderTests` compiles both on the macOS runner's GPU and builds each pipeline
/// from the entry points named here. Text only — Core knows nothing of Metal.
///
/// Each source mirrors a Swift uniforms struct in the app BY BYTE LAYOUT (`MetalFieldRenderer`,
/// `FieldLayerPass`): a field is only ever appended at the end, in both places, in one commit.
public enum FieldShader {
    /// One program: its source and the two functions the renderer looks up in it.
    public struct Program: Sendable {
        public let source: String
        public let vertexFunction: String
        public let fragmentFunction: String
    }

    /// The Field window (W3): the rings, the Chladni plate and the four looks, one fragment for all.
    public static let field = Program(source: fieldSource, vertexFunction: "field_vertex",
                                      fragmentFunction: "field_fragment")
    /// The Field laid over a video frame (W15).
    public static let layer = Program(source: layerSource, vertexFunction: "layer_vertex",
                                      fragmentFunction: "layer_fragment")
    /// Every program the app compiles, for the gate.
    public static let all: [Program] = [field, layer]

    /// Where the closed spectral circle leaves the pure spectrum: log2(780/640) and log2(780/420),
    /// written as literals from the numbers so the shader cannot drift from them.
    private static let redEdgeLiteral = String(format: "%.9f", Foundation.log2(780.0 / 640.0))
    private static let violetEdgeLiteral = String(format: "%.9f", Foundation.log2(780.0 / 420.0))

    private static let fieldSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VOut { float4 pos [[position]]; float2 uv; };
    struct Uniforms { float aspect; float beatPhase; float fieldPhase; float pulsePhase;
                      float beatLight; float centreLight; float levelLight; float coherence;
                      float breath; float toneHz; float density; float hasPulse; float hasCoherence;
                      float ringsK; float ringsCoherence; };
    struct Chladni { float4 fromM; float4 fromN; float4 fromW; float4 toM; float4 toN; float4 toW;
                     float active; float mix; float light; float grains; };
    // The looks (FieldLookMotion): which two patterns (FieldPattern.shaderIndex), how much of the
    // second, the dish's solve, the moiré's gratings, the water's and the film's ripple spacing,
    // the film's phase, the looks' phase in turns and the aurora's rays. All zero draws the rings
    // alone, as every pass bound before the looks existed.
    struct Look { float primary; float partner; float blend;
                  float dishK; float dishStrength; float dishHex;
                  float moireK1; float moireK2; float moirePhase; float rippleK; float filmPhase; float turns;
                  float auroraRays; float fold; float foldDark; };
    // The weave (BarWeave.words): how far the newest row has come in, its light (flash-guarded on
    // the CPU), two spare words, then each row on screen, newest first, as its low and high 32
    // bits. All zero is an empty, dark weave.
    struct Weave { float scroll; float light; float spare1; float spare2; uint rows[\(2 * BarWeave.history)]; };

    // Wavelength (nm) -> linear sRGB through the CIE 1931 colour-matching functions (the
    // Wyman/Sloan/Shirley 2013 analytic fit) -> XYZ -> linear sRGB (D65).
    float cieLobe(float x, float mu, float s1, float s2) {
        float t = (x - mu) * (x < mu ? 1.0 / s1 : 1.0 / s2);
        return exp(-0.5 * t * t);
    }
    float3 wavelengthToRGB(float wl) {
        float X = 1.056 * cieLobe(wl, 599.8, 37.9, 31.0)
                + 0.362 * cieLobe(wl, 442.0, 16.0, 26.7)
                - 0.065 * cieLobe(wl, 501.1, 20.4, 26.2);
        float Y = 0.821 * cieLobe(wl, 568.8, 46.9, 40.5)
                + 0.286 * cieLobe(wl, 530.9, 16.3, 31.1);
        float Z = 1.217 * cieLobe(wl, 437.0, 11.8, 36.0)
                + 0.681 * cieLobe(wl, 459.0, 26.0, 13.8);
        X = max(0.0, X); Y = max(0.0, Y); Z = max(0.0, Z);
        float3 c = float3( 3.2406 * X - 1.5372 * Y - 0.4986 * Z,
                          -0.9689 * X + 1.8758 * Y + 0.0415 * Z,
                           0.0557 * X - 0.2040 * Y + 1.0570 * Z);
        // Desaturate towards neutral by the most negative channel, not a per-channel clip, so the
        // deep red and violet bands keep their hue instead of collapsing to one flat colour.
        float w = min(0.0, min(c.r, min(c.g, c.b)));
        c -= w;
        float m = max(c.r, max(c.g, c.b));
        if (m > 1.0) c /= m;
        return clamp(c, 0.0, 1.0);
    }

    // The tone, transposed by whole octaves into visible light, on the CLOSED spectral circle:
    // the visible band is barely one octave, and where the eye's response fades (deep red,
    // violet) the circle closes along the CIE purple line, so no pitch is ever dark or black.
    float3 toneColour(float toneHz) {
        float f = max(toneHz, 1.0);
        float p = log2(2.99792458e17 / 780.0 / f);
        float t = ceil(p) - p;
        if (t >= 1.0) t -= 1.0;
        float tRed = \(redEdgeLiteral);
        float tViolet = \(violetEdgeLiteral);
        if (t >= tRed && t <= tViolet) {
            return wavelengthToRGB(780.0 / exp2(t));
        }
        float seam = tRed + 1.0 - tViolet;
        float s = (t < tRed) ? (tRed - t) / seam : (tRed + 1.0 - t) / seam;
        float3 red = wavelengthToRGB(640.0);
        float3 violet = wavelengthToRGB(420.0);
        float3 c = mix(red, violet, s);
        float m = max(c.r, max(c.g, c.b));
        float target = mix(max(red.r, max(red.g, red.b)), max(violet.r, max(violet.g, violet.b)), s);
        if (m > 1e-6) c *= target / m;
        return clamp(c, 0.0, 1.0);
    }

    // Two-beam interference: two radial wave trains, the second detuned by coherence, superposed;
    // the visible field is their intensity (amplitude squared), so the fringes are crisp. The
    // fringe spacing follows the tone (k proportional to f, non-dispersive) around the ring dial.
    // Squaring doubles the temporal rate, so the phase is damped by FieldPulse.foldDamping first:
    // 2 x 0.5 x the 2.5 Hz ceiling lands under WCAG's three flashes a second.
    float fieldRings(float d, float k, float phase, float coh) {
        float p = phase * \(FieldPulse.foldDampingLiteral);
        float w1 = sin(d * k - p);
        float detune = mix(1.6, 1.02, coh);
        float w2 = sin(d * k * detune - p * 0.5);
        float interf = (w1 + w2) * 0.5;
        float intensity = interf * interf;
        return pow(intensity, mix(1.0, 2.6, coh));
    }

    float echoelHash(float2 p) {
        return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
    }

    // A full-screen triangle from the vertex id: no vertex buffer.
    vertex VOut field_vertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        VOut o;
        o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
        o.uv = p;
        return o;
    }

    // The key's tonic as light, warmed like daylight, fuller with coherence, and lifted to a
    // luminance floor only as far as the gamut allows (never a hue rotation). Both patterns use it.
    float3 fieldColour(constant Uniforms& u) {
        float coh = clamp(u.coherence, 0.0, 1.0);
        float3 col = toneColour(u.toneHz);
        float l = dot(col, float3(0.2126, 0.7152, 0.0722));
        float3 warm = float3(1.0, 0.92, 0.80);
        col = mix(float3(l) * warm, col, 0.97);
        col = mix(col, warm, 0.05);
        col = mix(col, col * 1.15 + 0.05, coh);
        float lum = dot(col, float3(0.2126, 0.7152, 0.0722));
        float peak = max(max(col.r, max(col.g, col.b)), 1e-4);
        float lift = max(min(0.35 / max(lum, 0.04), 1.0 / peak), 1.0);
        return col * ((lum < 0.35) ? lift : 1.0);
    }

    // One square-plate mode on the unit square (EchoelCore ChladniPlate.shape): for m != n the
    // degenerate pair superposed, for m == n the single product.
    float plateShape(float m, float n, float2 p) {
        float mx = cos(m * M_PI_F * p.x);
        float ny = cos(n * M_PI_F * p.y);
        if (m == n) return mx * ny;
        float nx = cos(n * M_PI_F * p.x);
        float my = cos(m * M_PI_F * p.y);
        return 0.5 * (mx * ny - nx * my);
    }
    float plateDisplacement(float4 m, float4 n, float4 w, float2 p) {
        float s = 0.0;
        for (int i = 0; i < 4; i++) {
            if (w[i] > 0.0) s += w[i] * plateShape(m[i], n[i], p);
        }
        return s;
    }

    // The Chladni plate: a square plate centred in the frame, one sand grain per cell of a
    // grains x grains grid at a jittered place, present with the probability of sand where it
    // lies (EchoelCore ChladniPlate.sand: 1 on a nodal line) — so the grains gather on the lines
    // that do not move. Lit by the plate's flash-guarded light; the plate never goes dead black.
    float3 chladniColour(VOut in, constant Uniforms& u, constant Chladni& c) {
        float2 xy = float2(in.uv.x * u.aspect, in.uv.y);
        float side = min(u.aspect, 1.0) * 0.92;
        float2 p = (xy - float2(0.5 * u.aspect, 0.5)) / side + 0.5;
        if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
            return float3(0.0);
        }
        float3 col = fieldColour(u);
        float g = max(c.grains, 16.0);
        float2 cell = floor(p * g);
        float2 jitter = 0.2 + 0.6 * float2(echoelHash(cell), echoelHash(cell + 17.31));
        float2 grain = (cell + jitter) / g;
        float a = plateDisplacement(c.fromM, c.fromN, c.fromW, grain);
        float b = plateDisplacement(c.toM, c.toN, c.toW, grain);
        float t = mix(a, b, clamp(c.mix, 0.0, 1.0)) / \(ChladniPlate.sandWidthLiteral);
        float sand = exp(-t * t);
        float present = step(echoelHash(cell + 41.7), sand);
        float r = length(p * g - cell - jitter);
        float speck = present * smoothstep(0.42, 0.22, r);
        float ambient = \(FieldPulse.ambientLiteral);
        float energy = clamp(c.light, 0.0, 1.0) * speck;
        return col * (ambient + (1.0 - ambient) * energy);
    }

    float3 ringsColour(VOut in, constant Uniforms& u, float turns) {
        // Aspect-correct radial distance from the centre: circles stay circles on a tall phone.
        float2 uv = in.uv;
        uv.x *= u.aspect;
        float2 c = float2(0.5 * u.aspect, 0.5);
        float d = distance(uv, c);
        // The rings read their own coherence and wavenumber, each rate-limited (FieldMotion).
        float coh = clamp(u.ringsCoherence, 0.0, 1.0);
        float spread = 0.85 + 0.35 * clamp(u.breath, 0.0, 1.0);
        // The field moves with the song's bar (its phase is capped on the CPU); the vignette's
        // edge is always past the screen's corner, so the picture never closes to a black centre.
        float phase = turns * 6.2831853;
        float vEdge = 0.9 + 0.5 * spread;
        float vignette = smoothstep(vEdge, 0.0, d);
        float field = fieldRings(d, clamp(u.ringsK, 4.0, 120.0), phase, coh);
        // The beat: one thin ring grows through each beat; its light passed the flash guard.
        float ringRadius = (0.12 + 0.40 * clamp(u.beatPhase, 0.0, 1.0)) * spread;
        float ringT = (d - ringRadius) / 0.012;
        float ring = exp(-ringT * ringT) * \(FieldPulse.beatRingGain) * clamp(u.beatLight, 0.0, 1.0);
        // The body: the centre blooms with the pulse (or the level when no body is measured) and
        // each heartbeat widens and brightens it; the brightening stays under the general-flash
        // threshold (FieldPulse.bloomSwing), so only the field's rate counts as flashing.
        float beat = (0.5 - 0.5 * cos(u.pulsePhase * 6.2831853)) * clamp(u.hasPulse, 0.0, 1.0);
        float restGlow = \(FieldPulse.restGlowFloorLiteral) + \(FieldPulse.restGlowSpanLiteral) * clamp(u.centreLight, 0.0, 1.0);
        float beatGain = 0.80 + \(FieldPulse.bloomSwingLiteral) * beat;
        float bloomEdge = (0.34 + 0.18 * beat) * spread;
        float bloom = restGlow * beatGain * smoothstep(bloomEdge, 0.0, d);
        // Coherence, where it is measured, widens a quiet halo; absent, there is none.
        float haloRadius = (0.30 + 0.15 * coh) * spread;
        float haloT = (d - haloRadius) / 0.010;
        float halo = exp(-haloT * haloT) * \(FieldPulse.haloGain) * clamp(u.hasCoherence, 0.0, 1.0);
        float energy = clamp(field * vignette * (0.35 + 0.65 * clamp(u.levelLight, 0.0, 1.0)) + bloom + ring + halo, 0.0, 1.0);
        // The colour: the key's tonic as light (fieldColour, shared with the plate).
        float3 col = fieldColour(u);
        float ambient = \(FieldPulse.ambientLiteral);
        return col * (ambient + (1.0 - ambient) * energy);
    }

    // The earlier app's looks (EchoelCore FieldLook mirrors each on the CPU, where the flash law is
    // measured). Each returns a scalar field 0 ... 1 on the aspect-correct coordinate p, +y up.
    float fieldDish(float2 p, float k, float strength, float hex, float phase, float coh) {
        float sq = 0.5 * (cos(p.x * k) + cos(p.y * k));
        float d2 = -0.5 * p.x + 0.8660254 * p.y;
        float d3 = -0.5 * p.x - 0.8660254 * p.y;
        float hx = (cos(p.x * k) + cos(d2 * k) + cos(d3 * k)) * 0.3333;
        float h = mix(sq, hx, hex);
        float breathe = 0.85 + 0.15 * sin(phase * \(FieldLook.dishPhaseRate));
        float lens = clamp(0.88 * strength * breathe, 0.0, 0.88);
        float caustic = (1.0 - lens) / (1.0 - lens * h);
        float net = pow(clamp(caustic, 0.0, 1.0), mix(1.5, 3.0, coh));
        float mirror = 0.55 + 0.30 * exp(-dot(p, p) * 2.5);
        return clamp(mix(mirror, net, clamp(strength, 0.0, 1.0)), 0.0, 1.0);
    }
    float fieldWater(float2 p, float k, float phase, float coh, float breath) {
        float t = phase * \(FieldLook.waterPhaseRate);
        float scale = clamp(k, \(FieldLook.rippleKRange.lowerBound), \(FieldLook.rippleKRange.upperBound));
        float w = sin(p.x * scale + t) * cos(p.y * (scale * 0.818) - t * 0.7);
        w += sin(length(p) * (scale * 1.545) - t * 1.1);
        w += sin((p.x + p.y) * (scale * 0.727) + t * 0.5);
        float net = clamp(0.5 + mix(0.12, 0.24, breath) * w, 0.0, 1.0);
        return pow(net, mix(3.0, 6.0, coh));
    }
    float auroraChapman(float x) {
        float e = exp(-clamp(x, -6.0, 40.0));
        return exp(clamp(1.0 - x - e, -30.0, 0.0));
    }
    float fieldAurora(float2 p, float rays, float phase, float coh, float breath) {
        float t = phase * \(FieldLook.auroraPhaseRate);
        float wave = sin(p.x * 2.2 + t) * 0.35 + sin(p.x * 4.7 - t * 0.6) * 0.15;
        float H = mix(0.30, 0.14, clamp(coh, 0.0, 1.0));
        float curtain = auroraChapman((p.y - wave) / H);
        float wave2 = sin(p.x * 3.1 - t * 0.8) * 0.30;
        float curtain2 = auroraChapman((p.y + 0.4 - wave2) / (H * 1.35));
        float ray = 0.72 + 0.28 * cos(p.x * clamp(rays, \(FieldLook.auroraRayRange.lowerBound), \(FieldLook.auroraRayRange.upperBound)) * 6.2831853);
        float swell = 0.80 + 0.20 * clamp(breath, 0.0, 1.0);
        return clamp((curtain + curtain2 * 0.6) * ray * swell, 0.0, 1.0);
    }
    float fieldDepth(float2 p, float phase, float coh, float breath, float k, float strength) {
        float cxx = -0.5 * cos(p.x * k);
        float cyy = -0.5 * cos(p.y * k);
        float breathe = 0.85 + 0.15 * sin(phase * \(FieldLook.depthPhaseRate));
        float sink = mix(0.8, 1.2, clamp(breath, 0.0, 1.0));
        float phi = \(FieldLook.depthFocusNumber) * clamp(strength, 0.0, 1.0) * breathe * sink;
        float cap = \(FieldLook.depthIntensityCeiling);
        float3 ratio = float3(\(FieldLook.depthFocusRatios[0]), \(FieldLook.depthFocusRatios[1]), \(FieldLook.depthFocusRatios[2]));
        float3 weight = float3(\(FieldLook.depthWeights[0]), \(FieldLook.depthWeights[1]), \(FieldLook.depthWeights[2]));
        float lit = 0.0;
        for (int i = 0; i < 3; i++) {
            float f = phi * ratio[i];
            float det = (1.0 + f * cxx) * (1.0 + f * cyy);
            lit += weight[i] * min(1.0 / max(abs(det), 1.0 / cap), cap);
        }
        float net = clamp(lit / (weight.x + weight.y + weight.z) / \(FieldLook.depthFullBright), 0.0, 1.0);
        return pow(net, mix(1.0, 1.6, coh));
    }

    // One of the four looks in the frame, lit like the rings: framed by the same vignette, brighter
    // with the (flash-guarded) level, coloured by the key's tone.
    float3 lookFieldColour(float look, VOut in, constant Uniforms& u, constant Look& l, float turns) {
        float2 uv = in.uv;
        uv.x *= u.aspect;
        float d = distance(uv, float2(0.5 * u.aspect, 0.5));
        float2 p = float2((in.uv.x - 0.5) * 2.0 * u.aspect, (in.uv.y - 0.5) * 2.0);
        float coh = clamp(u.coherence, 0.0, 1.0);
        float breath = clamp(u.breath, 0.0, 1.0);
        float phase = turns * 6.2831853;
        float field;
        if (look < 2.5) field = fieldDish(p, l.dishK, l.dishStrength, l.dishHex, phase, coh);
        else if (look < 3.5) field = fieldWater(p, l.rippleK, phase, coh, breath);
        else if (look < 4.5) field = fieldAurora(p, l.auroraRays, phase, coh, breath);
        else field = fieldDepth(p, phase, coh, breath, l.dishK, l.dishStrength);
        float spread = 0.85 + 0.35 * breath;
        float vignette = smoothstep(0.9 + 0.5 * spread, 0.0, d);
        float energy = clamp(field * vignette * (0.35 + 0.65 * clamp(u.levelLight, 0.0, 1.0)), 0.0, 1.0);
        float ambient = \(FieldPulse.ambientLiteral);
        return fieldColour(u) * (ambient + (1.0 - ambient) * energy);
    }

    // The moiré (FieldLook.moire): two thin gratings, the second tilted and drifting at the
    // tuning's beat (capped on the CPU). Not scaled by the level: it shows the tuning, not the sound.
    float moireLine(float coordinate, float k, float shift) {
        float t = coordinate * k / 6.2831853 - shift;
        float f = fract(t);
        float distance = min(f, 1.0 - f);
        return 1.0 - smoothstep(0.0, \(FieldLook.moireLineWidth), distance);
    }
    float3 moireColour(VOut in, constant Uniforms& u, constant Look& l) {
        float2 uv = in.uv;
        uv.x *= u.aspect;
        float d = distance(uv, float2(0.5 * u.aspect, 0.5));
        float2 p = float2((in.uv.x - 0.5) * 2.0 * u.aspect, (in.uv.y - 0.5) * 2.0);
        float tilted = p.x * cos(\(FieldLook.moireTilt)) + p.y * sin(\(FieldLook.moireTilt));
        float lines = clamp(2.0 * \(FieldLook.moireGain) * max(moireLine(p.x, l.moireK1, 0.0),
                                                                 moireLine(tilted, l.moireK2, l.moirePhase)), 0.0, 1.0);
        float vignette = smoothstep(1.6, 0.0, d);
        float energy = clamp(lines * vignette, 0.0, 1.0);
        float ambient = \(FieldPulse.ambientLiteral);
        return fieldColour(u) * (ambient + (1.0 - ambient) * energy);
    }

    // The weave (BarWeave.light, exactly): square cells across the width, the newest row sliding
    // in from the bottom and lit as far as it has come, the history fading at its top.
    float3 weaveColour(VOut in, constant Uniforms& u, constant Weave& w) {
        float side = u.aspect > 0.0 ? u.aspect : 1.0;
        float x = clamp(in.uv.x, 0.0, 1.0) * \(Double(BarWeave.width));
        float rowsUp = clamp(in.uv.y, 0.0, 1.0) * \(Double(BarWeave.width)) / side;
        float offset = w.scroll - rowsUp;
        float back = -floor(offset);
        float energy = 0.0;
        if (back >= 0.0 && back < \(Double(BarWeave.history))) {
            int index = int(back);
            int cell = min(int(x), \(BarWeave.width - 1));
            uint word = cell < 32 ? w.rows[2 * index] : w.rows[2 * index + 1];
            if (((word >> uint(cell & 31)) & 1u) != 0u) {
                float fy = offset - floor(offset);
                float fx = x - floor(x);
                float edge = max(abs(fx - 0.5), abs(fy - 0.5));
                float shape = 1.0 - smoothstep(0.3, 0.5, edge);
                float fade = index == 0 ? w.scroll : 1.0;
                float top = 1.0 - smoothstep(\(Double(BarWeave.history - 8)), \(Double(BarWeave.history)), rowsUp);
                float drive = 0.35 + 0.65 * clamp(u.levelLight, 0.0, 1.0);
                energy = clamp(shape * fade * top * drive * clamp(w.light, 0.0, 1.0), 0.0, 1.0);
            }
        }
        float ambient = \(FieldPulse.ambientLiteral);
        return fieldColour(u) * (ambient + (1.0 - ambient) * energy);
    }

    // The thin film (FieldLook.filmThickness and filmColour, exactly): its own colours, from the
    // interference of the light its two faces reflect, lit by the level and the vignette.
    float3 filmColour(VOut in, constant Uniforms& u, constant Look& l) {
        float2 p = float2((in.uv.x - 0.5) * 2.0 * u.aspect, (in.uv.y - 0.5) * 2.0);
        float level = clamp(u.levelLight, 0.0, 1.0);
        float t = l.filmPhase * 6.2831853;
        float drained = smoothstep(1.2, -1.2, p.y);
        float d = \(FieldLook.filmThinnest) + (\(FieldLook.filmThickest - FieldLook.filmThinnest)) * drained * drained;
        d += \(FieldLook.filmSwirlDepth) * (0.6 * sin(1.7 * p.x + 0.9 * p.y + t) + 0.4 * sin(2.3 * p.y - 1.3 * p.x - t));
        d += \(FieldLook.filmRippleDepth) * level * sin(l.rippleK * length(p) - t);
        d = max(d, 0.0);
        float3 sum = float3(0.0);
        float3 white = float3(0.0);
        for (int i = 0; i < \(FieldLook.filmWavelengthCount); i++) {
            float wl = \(FieldLook.filmFirstWavelength) + float(i) * \(FieldLook.filmWavelengthStep);
            float3 s = wavelengthToRGB(wl);
            float r = sin(6.2831853 * \(FieldLook.filmIndex) * d / wl);
            sum += s * (r * r);
            white += s;
        }
        float3 film = clamp(sum / max(white, float3(1e-6)) * \(FieldLook.filmGain), 0.0, 1.0);
        float2 uv = in.uv;
        uv.x *= u.aspect;
        float vignette = smoothstep(1.6, 0.0, distance(uv, float2(0.5 * u.aspect, 0.5)));
        float energy = clamp(vignette * (0.35 + 0.65 * level), 0.0, 1.0);
        float ambient = \(FieldPulse.ambientLiteral);
        return film * (ambient + (1.0 - ambient) * energy);
    }

    float3 lookColour(float look, VOut in, constant Uniforms& u, constant Chladni& c, constant Look& l,
                      constant Weave& w, float turns) {
        if (look < 0.5) return ringsColour(in, u, turns);
        if (look > 7.5 && look < 8.5) return filmColour(in, u, l);
        if (look < 1.5) return chladniColour(in, u, c);
        if (look > 5.5 && look < 6.5) return moireColour(in, u, l);
        if (look > 6.5 && look < 7.5) return weaveColour(in, u, w);
        return lookFieldColour(look, in, u, l, turns);
    }

    // Not read through the kaleidoscope (FieldFold.folds): the plate (1) and the weave (7).
    bool unfolded(float look) {
        return abs(look - 1.0) < 0.5 || abs(look - 7.0) < 0.5;
    }

    // The Field: one look, or two blended (the second's share flash-guarded on the CPU).
    fragment float4 field_fragment(VOut in [[stage_in]], constant Uniforms& u [[buffer(0)]],
                                   constant Chladni& plate [[buffer(1)]], constant Look& look [[buffer(2)]],
                                   constant Weave& weave [[buffer(3)]]) {
        // Counted on across the song phase's wraps (FieldLookMotion.Shown.turns): fract() of it
        // here would jump every look that turns at a fraction of it, at every wrap.
        float turns = look.turns;
        // The kaleidoscope (FieldFold.fold, exactly): every look but the plate and the weave reads its point
        // folded into the first half-wedge from straight up; its count's change fades the picture.
        VOut folded = in;
        float segments = floor(look.fold + 0.5);
        if (segments > 1.5 && u.aspect > 0.0) {
            float2 q = float2((in.uv.x - 0.5) * u.aspect, in.uv.y - 0.5);
            float r = length(q);
            float wedge = 6.2831853 / segments;
            float angle = atan2(q.x, q.y);
            angle -= wedge * floor(angle / wedge);
            if (angle > wedge * 0.5) angle = wedge - angle;
            folded.uv = clamp(float2(0.5 + r * sin(angle) / u.aspect, 0.5 + r * cos(angle)), 0.0, 1.0);
        }
        VOut primaryIn = unfolded(look.primary) ? in : folded;
        float3 col = lookColour(look.primary, primaryIn, u, plate, look, weave, turns);
        float share = clamp(look.blend, 0.0, 1.0);
        if (share > \(FieldLookMotion.blendThreshold) && abs(look.partner - look.primary) > 0.5) {
            VOut partnerIn = unfolded(look.partner) ? in : folded;
            col = mix(col, lookColour(look.partner, partnerIn, u, plate, look, weave, turns), share);
        }
        col *= 1.0 - clamp(look.foldDark, 0.0, 1.0);
        col += (echoelHash(in.uv * 1000.0) - 0.5) / 255.0;
        return float4(clamp(col, 0.0, 1.0), 1.0);
    }
    """

    private static let layerSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct LayerOut { float4 pos [[position]]; };
    struct Layer { float a; float b; float c; float d; float tx; float ty;
                   float sourceWidth; float sourceHeight; float hasPicture;
                   float video; float field; float product; };

    // A full-screen triangle from the vertex id: no vertex buffer.
    vertex LayerOut layer_vertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        LayerOut o;
        o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
        return o;
    }

    fragment float4 layer_fragment(LayerOut in [[stage_in]],
                                   constant Layer& u [[buffer(0)]],
                                   texture2d<float> picture [[texture(0)]],
                                   texture2d<float> field [[texture(1)]]) {
        constexpr sampler smooth(filter::linear, address::clamp_to_edge);
        // Pixel coordinates, origin top left: AVFoundation's placement works in the same space.
        float2 p = in.pos.xy;
        float2 s = float2(u.a * p.x + u.c * p.y + u.tx, u.b * p.x + u.d * p.y + u.ty);
        float3 v = float3(0.0);
        if (u.hasPicture > 0.5 && s.x >= 0.0 && s.y >= 0.0 && s.x < u.sourceWidth && s.y < u.sourceHeight) {
            v = picture.sample(smooth, s / float2(u.sourceWidth, u.sourceHeight)).rgb;
        }
        float3 f = field.read(uint2(p)).rgb;
        float3 o = v * u.video + f * u.field + v * f * u.product;
        return float4(clamp(o, 0.0, 1.0), 1.0);
    }
    """
}

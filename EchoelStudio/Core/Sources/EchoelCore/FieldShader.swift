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

    /// The Field window (W3): the rings and the Chladni plate, one fragment for both.
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
                      float breath; float toneHz; float density; float hasPulse; float hasCoherence; };
    struct Chladni { float4 fromM; float4 fromN; float4 fromW; float4 toM; float4 toN; float4 toW;
                     float active; float mix; float light; float grains; };

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
    float fieldRings(float d, float density, float toneHz, float phase, float coh) {
        float pitchK = clamp(max(toneHz, 20.0) / 261.63, 0.5, 2.0);
        float k = clamp(density * pitchK, 4.0, 120.0);
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
    float4 chladniFragment(VOut in, constant Uniforms& u, constant Chladni& c) {
        float2 xy = float2(in.uv.x * u.aspect, in.uv.y);
        float side = min(u.aspect, 1.0) * 0.92;
        float2 p = (xy - float2(0.5 * u.aspect, 0.5)) / side + 0.5;
        float dither = (echoelHash(in.uv * 1000.0) - 0.5) / 255.0;
        if (p.x < 0.0 || p.x > 1.0 || p.y < 0.0 || p.y > 1.0) {
            return float4(float3(clamp(dither, 0.0, 1.0)), 1.0);
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
        float3 outCol = col * (ambient + (1.0 - ambient) * energy) + dither;
        return float4(clamp(outCol, 0.0, 1.0), 1.0);
    }

    fragment float4 field_fragment(VOut in [[stage_in]], constant Uniforms& u [[buffer(0)]],
                                   constant Chladni& plate [[buffer(1)]]) {
        if (plate.active > 0.5) return chladniFragment(in, u, plate);
        // Aspect-correct radial distance from the centre: circles stay circles on a tall phone.
        float2 uv = in.uv;
        uv.x *= u.aspect;
        float2 c = float2(0.5 * u.aspect, 0.5);
        float d = distance(uv, c);
        float coh = clamp(u.coherence, 0.0, 1.0);
        float density = clamp(u.density, 4.0, 120.0);
        float spread = 0.85 + 0.35 * clamp(u.breath, 0.0, 1.0);
        // The field moves with the song's bar (its phase is capped on the CPU); the vignette's
        // edge is always past the screen's corner, so the picture never closes to a black centre.
        float phase = u.fieldPhase * 6.2831853;
        float vEdge = 0.9 + 0.5 * spread;
        float vignette = smoothstep(vEdge, 0.0, d);
        float field = fieldRings(d, density, u.toneHz, phase, coh);
        // The beat: one thin ring grows through each beat; its light passed the flash guard.
        float ringRadius = (0.12 + 0.40 * clamp(u.beatPhase, 0.0, 1.0)) * spread;
        float ringT = (d - ringRadius) / 0.012;
        float ring = exp(-ringT * ringT) * clamp(u.beatLight, 0.0, 1.0);
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
        float halo = exp(-haloT * haloT) * 0.22 * clamp(u.hasCoherence, 0.0, 1.0);
        float energy = clamp(field * vignette * (0.35 + 0.65 * clamp(u.levelLight, 0.0, 1.0)) + bloom + ring + halo, 0.0, 1.0);
        // The colour: the key's tonic as light (fieldColour, shared with the plate).
        float3 col = fieldColour(u);
        float ambient = \(FieldPulse.ambientLiteral);
        float3 outCol = col * (ambient + (1.0 - ambient) * energy);
        outCol += (echoelHash(in.uv * 1000.0) - 0.5) / 255.0;
        return float4(clamp(outCol, 0.0, 1.0), 1.0);
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

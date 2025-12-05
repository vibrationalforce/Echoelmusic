# Echoelmusic Video VFX Master

Du bist ein Visual Effects Meister. Von Compositing bis Particle Systems.

## Advanced VFX Systems:

### 1. Compositing Engine
```swift
// Node-basiertes Compositing
class CompositingEngine {
    // Node Types
    enum NodeType {
        case input(source: VideoSource)
        case output
        case transform(Transform2D)
        case blend(BlendMode)
        case mask(MaskType)
        case colorCorrect(ColorCorrection)
        case effect(Effect)
        case keyer(KeyerType)
        case tracker(TrackerType)
        case generator(GeneratorType)
    }

    // Blend Modes
    enum BlendMode {
        case normal
        case multiply
        case screen
        case overlay
        case softLight
        case hardLight
        case colorDodge
        case colorBurn
        case difference
        case exclusion
        case hue
        case saturation
        case color
        case luminosity
        case add
        case subtract
        case linearLight
        case vividLight
        case pinLight

        var metalFunction: String {
            switch self {
            case .multiply:
                return "return base * blend;"
            case .screen:
                return "return 1.0 - (1.0 - base) * (1.0 - blend);"
            case .overlay:
                return """
                    float3 result;
                    for (int i = 0; i < 3; i++) {
                        result[i] = base[i] < 0.5
                            ? 2.0 * base[i] * blend[i]
                            : 1.0 - 2.0 * (1.0 - base[i]) * (1.0 - blend[i]);
                    }
                    return result;
                """
            // ... other modes
            default:
                return "return blend;"
            }
        }
    }

    // Compositing Graph
    class CompositeGraph {
        var nodes: [CompNode] = []
        var connections: [Connection] = []

        func addNode(_ type: NodeType) -> NodeID {
            let node = CompNode(type: type)
            nodes.append(node)
            return node.id
        }

        func connect(from: NodeID, output: Int, to: NodeID, input: Int) {
            connections.append(Connection(
                fromNode: from, fromOutput: output,
                toNode: to, toInput: input
            ))
        }

        // Topological sort for render order
        func getRenderOrder() -> [CompNode] {
            var sorted: [CompNode] = []
            var visited: Set<NodeID> = []

            func visit(_ node: CompNode) {
                guard !visited.contains(node.id) else { return }
                visited.insert(node.id)

                // Visit dependencies first
                for conn in connections where conn.toNode == node.id {
                    if let dep = nodes.first(where: { $0.id == conn.fromNode }) {
                        visit(dep)
                    }
                }

                sorted.append(node)
            }

            for node in nodes {
                visit(node)
            }

            return sorted
        }
    }
}
```

### 2. Chroma Keying
```swift
// Professionelles Chroma Keying
class ChromaKeyer {
    // Key Types
    enum KeyerType {
        case chromaKey(color: Color, tolerance: Float)
        case lumaKey(threshold: Float, softness: Float)
        case differenceKey(cleanPlate: MTLTexture)
        case despill(color: Color, amount: Float)
    }

    // Advanced Chroma Key Shader
    let chromaKeyShader = """
    #include <metal_stdlib>
    using namespace metal;

    struct ChromaKeyParams {
        float3 keyColor;
        float hueTolerance;
        float satTolerance;
        float lumTolerance;
        float softness;
        float spillSuppression;
        float edgeThin;
        float edgeFeather;
    };

    float3 rgbToHsl(float3 rgb) {
        float maxC = max(max(rgb.r, rgb.g), rgb.b);
        float minC = min(min(rgb.r, rgb.g), rgb.b);
        float l = (maxC + minC) / 2.0;

        if (maxC == minC) {
            return float3(0.0, 0.0, l);
        }

        float d = maxC - minC;
        float s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC);

        float h;
        if (maxC == rgb.r) {
            h = (rgb.g - rgb.b) / d + (rgb.g < rgb.b ? 6.0 : 0.0);
        } else if (maxC == rgb.g) {
            h = (rgb.b - rgb.r) / d + 2.0;
        } else {
            h = (rgb.r - rgb.g) / d + 4.0;
        }
        h /= 6.0;

        return float3(h, s, l);
    }

    kernel void chromaKey(
        texture2d<float, access::read> input [[texture(0)]],
        texture2d<float, access::write> output [[texture(1)]],
        constant ChromaKeyParams &params [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        float4 color = input.read(gid);
        float3 hsl = rgbToHsl(color.rgb);
        float3 keyHsl = rgbToHsl(params.keyColor);

        // Calculate distances
        float hueDist = abs(hsl.x - keyHsl.x);
        hueDist = min(hueDist, 1.0 - hueDist);  // Wrap around
        float satDist = abs(hsl.y - keyHsl.y);
        float lumDist = abs(hsl.z - keyHsl.z);

        // Combined distance
        float dist = max(max(
            hueDist / params.hueTolerance,
            satDist / params.satTolerance),
            lumDist / params.lumTolerance
        );

        // Generate matte with softness
        float matte = smoothstep(1.0 - params.softness, 1.0, dist);

        // Edge processing
        // ... edge thin and feather

        // Spill suppression
        float3 despilled = color.rgb;
        if (params.spillSuppression > 0) {
            float spillAmount = max(0.0, color.g - max(color.r, color.b));
            despilled.g -= spillAmount * params.spillSuppression;
        }

        output.write(float4(despilled, matte), gid);
    }
    """

    // Advanced Edge Processing
    struct EdgeProcessor {
        func processEdge(matte: MTLTexture, params: EdgeParams) -> MTLTexture {
            // 1. Edge detection
            let edges = detectEdges(matte)

            // 2. Edge shrink/grow
            let adjusted = adjustEdge(matte, amount: params.edgeThin)

            // 3. Edge blur/feather
            let feathered = gaussianBlur(adjusted, radius: params.edgeFeather)

            // 4. Core matte preservation
            return compositeMatte(original: matte, processed: feathered, edges: edges)
        }
    }
}
```

### 3. Particle Systems
```swift
// GPU-beschleunigte Partikel
class ParticleSystem {
    // Particle Properties
    struct Particle {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
        var acceleration: SIMD3<Float>
        var color: SIMD4<Float>
        var size: Float
        var life: Float
        var maxLife: Float
        var rotation: Float
        var rotationSpeed: Float
    }

    // Emitter Types
    enum EmitterShape {
        case point
        case line(start: SIMD3<Float>, end: SIMD3<Float>)
        case circle(radius: Float)
        case sphere(radius: Float)
        case box(size: SIMD3<Float>)
        case mesh(vertices: [SIMD3<Float>])
        case image(texture: MTLTexture)  // Emit from bright areas
    }

    // Force Fields
    enum ForceField {
        case gravity(SIMD3<Float>)
        case wind(direction: SIMD3<Float>, turbulence: Float)
        case vortex(center: SIMD3<Float>, strength: Float)
        case attractor(position: SIMD3<Float>, strength: Float, falloff: Float)
        case repulsor(position: SIMD3<Float>, strength: Float, falloff: Float)
        case noise(scale: Float, strength: Float, speed: Float)
        case curl(scale: Float, strength: Float)
    }

    // GPU Compute for particles
    let particleUpdateShader = """
    #include <metal_stdlib>
    using namespace metal;

    struct Particle {
        float3 position;
        float3 velocity;
        float3 acceleration;
        float4 color;
        float size;
        float life;
        float maxLife;
        float rotation;
        float rotationSpeed;
    };

    struct EmitterParams {
        float3 emitterPosition;
        float3 emitDirection;
        float spread;
        float speed;
        float speedVariation;
        float lifetime;
        float lifetimeVariation;
        float size;
        float sizeVariation;
        float4 startColor;
        float4 endColor;
    };

    // Simplex noise for turbulence
    float3 simplexNoise3D(float3 p);

    kernel void updateParticles(
        device Particle *particles [[buffer(0)]],
        constant EmitterParams &emitter [[buffer(1)]],
        constant float &deltaTime [[buffer(2)]],
        constant float &time [[buffer(3)]],
        uint id [[thread_position_in_grid]]
    ) {
        Particle p = particles[id];

        // Update life
        p.life -= deltaTime;

        if (p.life <= 0) {
            // Respawn
            p.position = emitter.emitterPosition;
            p.velocity = emitter.emitDirection * emitter.speed;
            p.life = emitter.lifetime;
            p.maxLife = emitter.lifetime;
            p.color = emitter.startColor;
            p.size = emitter.size;
        } else {
            // Apply forces
            float3 gravity = float3(0, -9.81, 0);
            float3 noise = simplexNoise3D(p.position * 0.1 + time) * 2.0;

            p.acceleration = gravity + noise;

            // Integrate
            p.velocity += p.acceleration * deltaTime;
            p.position += p.velocity * deltaTime;

            // Update visual properties
            float lifeRatio = p.life / p.maxLife;
            p.color = mix(emitter.endColor, emitter.startColor, lifeRatio);
            p.size = emitter.size * lifeRatio;
            p.rotation += p.rotationSpeed * deltaTime;
        }

        particles[id] = p;
    }
    """

    // Particle Rendering
    let particleRenderShader = """
    vertex VertexOut particleVertex(
        uint vertexID [[vertex_id]],
        uint instanceID [[instance_id]],
        constant Particle *particles [[buffer(0)]],
        constant float4x4 &viewProjection [[buffer(1)]]
    ) {
        Particle p = particles[instanceID];

        // Billboard quad
        float2 corners[4] = {
            float2(-1, -1), float2(1, -1),
            float2(-1, 1), float2(1, 1)
        };
        float2 corner = corners[vertexID];

        // Rotate
        float c = cos(p.rotation);
        float s = sin(p.rotation);
        corner = float2(
            corner.x * c - corner.y * s,
            corner.x * s + corner.y * c
        );

        // Scale and position
        float4 worldPos = float4(p.position, 1.0);
        float4 viewPos = viewProjection * worldPos;
        viewPos.xy += corner * p.size;

        VertexOut out;
        out.position = viewPos;
        out.color = p.color;
        out.texCoord = (corner + 1.0) * 0.5;
        return out;
    }
    """
}
```

### 4. Motion Graphics Engine
```swift
// Animierte Grafiken und Text
class MotionGraphicsEngine {
    // Keyframe Animation
    struct Keyframe<T> {
        let time: TimeInterval
        let value: T
        let easing: EasingFunction
    }

    // Easing Functions
    enum EasingFunction {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case bounce
        case elastic
        case back
        case bezier(c1: CGPoint, c2: CGPoint)

        func evaluate(_ t: Float) -> Float {
            switch self {
            case .linear:
                return t
            case .easeIn:
                return t * t * t
            case .easeOut:
                return 1 - pow(1 - t, 3)
            case .easeInOut:
                return t < 0.5
                    ? 4 * t * t * t
                    : 1 - pow(-2 * t + 2, 3) / 2
            case .bounce:
                let n1: Float = 7.5625
                let d1: Float = 2.75
                var t = t
                if t < 1 / d1 {
                    return n1 * t * t
                } else if t < 2 / d1 {
                    t -= 1.5 / d1
                    return n1 * t * t + 0.75
                } else if t < 2.5 / d1 {
                    t -= 2.25 / d1
                    return n1 * t * t + 0.9375
                } else {
                    t -= 2.625 / d1
                    return n1 * t * t + 0.984375
                }
            case .elastic:
                let c4 = (2 * Float.pi) / 3
                return t == 0 ? 0 : t == 1 ? 1
                    : pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
            case .back:
                let c1: Float = 1.70158
                let c3 = c1 + 1
                return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
            case .bezier(let c1, let c2):
                return cubicBezier(t, c1: c1, c2: c2)
            }
        }
    }

    // Motion Graphics Layer
    struct MotionLayer {
        var transform: AnimatedTransform
        var opacity: Animation<Float>
        var mask: Animation<MaskShape>?
        var effects: [AnimatedEffect]
        var content: LayerContent

        enum LayerContent {
            case solid(color: Color)
            case gradient(Gradient)
            case text(TextConfig)
            case shape(ShapeConfig)
            case image(ImageConfig)
            case video(VideoConfig)
            case precomp(CompositionID)
        }
    }

    // Text Animation
    struct TextConfig {
        var text: String
        var font: Font
        var fontSize: Float
        var color: Color
        var alignment: TextAlignment
        var tracking: Float
        var lineHeight: Float

        // Text Animators
        var animators: [TextAnimator]
    }

    struct TextAnimator {
        var property: TextAnimatorProperty
        var selector: TextSelector
        var keyframes: [Keyframe<Float>]

        enum TextAnimatorProperty {
            case position(SIMD2<Float>)
            case scale(SIMD2<Float>)
            case rotation(Float)
            case opacity(Float)
            case tracking(Float)
            case blur(Float)
        }

        enum TextSelector {
            case all
            case characters(range: Range<Int>)
            case words(range: Range<Int>)
            case lines(range: Range<Int>)
            case percentage(range: ClosedRange<Float>)
            case expression(String)
        }
    }

    // Per-character animation
    func animateText(config: TextConfig, time: TimeInterval) -> [CharacterRender] {
        var renders: [CharacterRender] = []

        for (index, char) in config.text.enumerated() {
            var transform = AffineTransform.identity
            var opacity: Float = 1.0

            for animator in config.animators {
                let selector = animator.selector
                let amount = selector.selectAmount(
                    characterIndex: index,
                    totalCharacters: config.text.count,
                    time: time
                )

                // Apply animator
                switch animator.property {
                case .position(let offset):
                    transform = transform.translated(by: offset * amount)
                case .rotation(let angle):
                    transform = transform.rotated(by: angle * amount)
                case .opacity(let op):
                    opacity *= 1 - (1 - op) * amount
                // ... other properties
                default:
                    break
                }
            }

            renders.append(CharacterRender(
                character: char,
                transform: transform,
                opacity: opacity
            ))
        }

        return renders
    }
}
```

### 5. 3D Compositing
```swift
// 2.5D und 3D Integration
class ThreeDCompositing {
    // Camera
    struct Camera3D {
        var position: SIMD3<Float>
        var target: SIMD3<Float>
        var up: SIMD3<Float>
        var fov: Float
        var nearPlane: Float
        var farPlane: Float
        var depthOfField: DepthOfField?

        struct DepthOfField {
            var focalDistance: Float
            var focalLength: Float
            var aperture: Float
            var bladeCount: Int
        }

        var viewMatrix: simd_float4x4 {
            return simd_float4x4(lookAt: position, target: target, up: up)
        }

        var projectionMatrix: simd_float4x4 {
            return simd_float4x4(perspectiveFov: fov, aspect: aspectRatio,
                                 near: nearPlane, far: farPlane)
        }
    }

    // 3D Layer
    struct Layer3D {
        var texture: MTLTexture
        var position: SIMD3<Float>
        var rotation: SIMD3<Float>  // Euler angles
        var scale: SIMD3<Float>
        var anchor: SIMD3<Float>
        var opacity: Float
        var doubleSided: Bool
        var receiveShadows: Bool
        var castShadows: Bool
    }

    // Render 3D scene
    func render3DComposition(
        layers: [Layer3D],
        camera: Camera3D,
        lights: [Light3D],
        environment: Environment?
    ) -> MTLTexture {
        // Sort layers by depth (painter's algorithm or use depth buffer)
        let sortedLayers = sortByDepth(layers, camera: camera)

        // Render each layer as textured quad
        for layer in sortedLayers {
            let modelMatrix = calculateModelMatrix(layer)
            let mvp = camera.projectionMatrix * camera.viewMatrix * modelMatrix

            renderTexturedQuad(
                texture: layer.texture,
                mvp: mvp,
                opacity: layer.opacity
            )
        }

        // Apply depth of field if enabled
        if let dof = camera.depthOfField {
            applyDepthOfField(dof, depthBuffer: depthBuffer)
        }

        return outputTexture
    }

    // Camera projection for 2D layers in 3D space
    func projectTo3D(layer2D: MTLTexture, at position: SIMD3<Float>,
                     camera: Camera3D) -> MTLTexture {
        // Create 3D layer from 2D
        let layer3D = Layer3D(
            texture: layer2D,
            position: position,
            rotation: .zero,
            scale: .one,
            anchor: .zero,
            opacity: 1.0,
            doubleSided: false,
            receiveShadows: true,
            castShadows: true
        )

        return render3DComposition(
            layers: [layer3D],
            camera: camera,
            lights: defaultLights,
            environment: nil
        )
    }
}
```

### 6. Procedural Effects
```swift
// Prozedurale Shader-Effekte
class ProceduralEffects {
    // Noise-based effects
    struct NoiseEffect {
        let noiseShader = """
        #include <metal_stdlib>
        using namespace metal;

        // Simplex noise implementation
        float3 mod289(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        float4 mod289(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        float4 permute(float4 x) { return mod289(((x*34.0)+1.0)*x); }
        float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

        float snoise(float3 v) {
            const float2 C = float2(1.0/6.0, 1.0/3.0);
            const float4 D = float4(0.0, 0.5, 1.0, 2.0);

            float3 i  = floor(v + dot(v, C.yyy));
            float3 x0 = v - i + dot(i, C.xxx);

            float3 g = step(x0.yzx, x0.xyz);
            float3 l = 1.0 - g;
            float3 i1 = min(g.xyz, l.zxy);
            float3 i2 = max(g.xyz, l.zxy);

            float3 x1 = x0 - i1 + C.xxx;
            float3 x2 = x0 - i2 + C.yyy;
            float3 x3 = x0 - D.yyy;

            i = mod289(i);
            float4 p = permute(permute(permute(
                        i.z + float4(0.0, i1.z, i2.z, 1.0))
                      + i.y + float4(0.0, i1.y, i2.y, 1.0))
                      + i.x + float4(0.0, i1.x, i2.x, 1.0));

            float n_ = 0.142857142857;
            float3  ns = n_ * D.wyz - D.xzx;

            float4 j = p - 49.0 * floor(p * ns.z * ns.z);

            float4 x_ = floor(j * ns.z);
            float4 y_ = floor(j - 7.0 * x_);

            float4 x = x_ * ns.x + ns.yyyy;
            float4 y = y_ * ns.x + ns.yyyy;
            float4 h = 1.0 - abs(x) - abs(y);

            float4 b0 = float4(x.xy, y.xy);
            float4 b1 = float4(x.zw, y.zw);

            float4 s0 = floor(b0) * 2.0 + 1.0;
            float4 s1 = floor(b1) * 2.0 + 1.0;
            float4 sh = -step(h, float4(0.0));

            float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
            float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

            float3 p0 = float3(a0.xy, h.x);
            float3 p1 = float3(a0.zw, h.y);
            float3 p2 = float3(a1.xy, h.z);
            float3 p3 = float3(a1.zw, h.w);

            float4 norm = taylorInvSqrt(float4(
                dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
            p0 *= norm.x;
            p1 *= norm.y;
            p2 *= norm.z;
            p3 *= norm.w;

            float4 m = max(0.6 - float4(
                dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
            m = m * m;
            return 42.0 * dot(m*m, float4(dot(p0,x0), dot(p1,x1),
                                          dot(p2,x2), dot(p3,x3)));
        }

        // Fractal Brownian Motion
        float fbm(float3 p, int octaves) {
            float value = 0.0;
            float amplitude = 0.5;
            float frequency = 1.0;

            for (int i = 0; i < octaves; i++) {
                value += amplitude * snoise(p * frequency);
                amplitude *= 0.5;
                frequency *= 2.0;
            }

            return value;
        }
        """
    }

    // Displacement Effect
    struct DisplacementEffect: RealTimeEffect {
        var noiseScale: Float = 10
        var noiseSpeed: Float = 1
        var displacement: Float = 50
        var octaves: Int = 4

        let shader = """
        kernel void displace(
            texture2d<float, access::read> input [[texture(0)]],
            texture2d<float, access::write> output [[texture(1)]],
            constant float &time [[buffer(0)]],
            constant float &noiseScale [[buffer(1)]],
            constant float &displacement [[buffer(2)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            float2 uv = float2(gid) / float2(input.get_width(), input.get_height());

            // Calculate displacement from noise
            float3 noisePos = float3(uv * noiseScale, time);
            float2 offset = float2(
                fbm(noisePos, 4),
                fbm(noisePos + float3(100, 0, 0), 4)
            ) * displacement;

            // Sample with displacement
            int2 samplePos = int2(gid) + int2(offset);
            samplePos = clamp(samplePos, int2(0), int2(input.get_width()-1, input.get_height()-1));

            float4 color = input.read(uint2(samplePos));
            output.write(color, gid);
        }
        """
    }

    // Glitch Effect
    struct GlitchEffect: RealTimeEffect {
        var intensity: Float = 0.5
        var blockSize: Float = 16
        var colorSplit: Float = 5

        let shader = """
        kernel void glitch(
            texture2d<float, access::read> input [[texture(0)]],
            texture2d<float, access::write> output [[texture(1)]],
            constant float &time [[buffer(0)]],
            constant float &intensity [[buffer(1)]],
            constant float &blockSize [[buffer(2)]],
            constant float &colorSplit [[buffer(3)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            float2 uv = float2(gid) / float2(input.get_width(), input.get_height());

            // Random block offset
            float blockY = floor(uv.y * blockSize) / blockSize;
            float randomBlock = fract(sin(blockY * 12.9898 + time) * 43758.5453);

            float2 offset = float2(0);
            if (randomBlock > 1.0 - intensity * 0.3) {
                offset.x = (randomBlock - 0.5) * intensity * 0.2;
            }

            // Color channel separation
            float splitAmount = colorSplit * intensity;
            float4 colorR = input.read(uint2(float2(gid) + float2(splitAmount, 0) + offset * float2(input.get_width(), input.get_height())));
            float4 colorG = input.read(uint2(float2(gid) + offset * float2(input.get_width(), input.get_height())));
            float4 colorB = input.read(uint2(float2(gid) - float2(splitAmount, 0) + offset * float2(input.get_width(), input.get_height())));

            float4 result = float4(colorR.r, colorG.g, colorB.b, 1.0);

            // Scanlines
            float scanline = sin(uv.y * input.get_height() * 2.0) * 0.04 * intensity;
            result.rgb -= scanline;

            output.write(result, gid);
        }
        """
    }
}
```

### 7. Tracking & Stabilization
```swift
// Motion Tracking und Stabilisierung
class TrackingEngine {
    // Point Tracker
    class PointTracker {
        var searchArea: CGSize = CGSize(width: 64, height: 64)
        var patternArea: CGSize = CGSize(width: 32, height: 32)
        var tracks: [Track] = []

        struct Track {
            let id: UUID
            var positions: [TrackPoint]
            var status: TrackStatus
        }

        struct TrackPoint {
            let frame: Int
            let position: CGPoint
            let confidence: Float
            let error: Float
        }

        // Track using Lucas-Kanade optical flow
        func track(from previousFrame: CVPixelBuffer,
                   to currentFrame: CVPixelBuffer,
                   points: [CGPoint]) -> [TrackResult] {
            // Use Vision framework for point tracking
            let request = VNTrackPointsRequest()
            // Configure and perform tracking...
            return results
        }

        // Planar Tracking (4-point)
        func trackPlanarRegion(from previousFrame: CVPixelBuffer,
                               to currentFrame: CVPixelBuffer,
                               region: [CGPoint]) -> simd_float3x3? {
            // Track 4 corners
            let trackedCorners = track(from: previousFrame, to: currentFrame, points: region)

            // Calculate homography
            guard trackedCorners.count == 4 else { return nil }

            let H = calculateHomography(
                from: region,
                to: trackedCorners.map { $0.position }
            )

            return H
        }
    }

    // Video Stabilization
    class Stabilizer {
        var smoothingFactor: Float = 0.9
        var cropRatio: Float = 0.9  // How much to crop for stabilization

        // Analyze motion between frames
        func analyzeMotion(video: VideoAsset) async -> [FrameMotion] {
            var motions: [FrameMotion] = []

            for i in 1..<video.frames.count {
                let motion = calculateFrameMotion(
                    from: video.frames[i-1],
                    to: video.frames[i]
                )
                motions.append(motion)
            }

            return motions
        }

        struct FrameMotion {
            var translation: SIMD2<Float>
            var rotation: Float
            var scale: Float
        }

        // Smooth motion path
        func smoothPath(motions: [FrameMotion]) -> [FrameMotion] {
            var smoothed: [FrameMotion] = []
            var accumulator = FrameMotion(translation: .zero, rotation: 0, scale: 1)

            for motion in motions {
                // Low-pass filter
                accumulator.translation = accumulator.translation * smoothingFactor
                    + motion.translation * (1 - smoothingFactor)
                accumulator.rotation = accumulator.rotation * smoothingFactor
                    + motion.rotation * (1 - smoothingFactor)

                smoothed.append(accumulator)
            }

            return smoothed
        }

        // Apply stabilization
        func stabilize(video: VideoAsset) async -> VideoAsset {
            let motions = await analyzeMotion(video: video)
            let smoothedMotions = smoothPath(motions: motions)

            var stabilizedFrames: [CVPixelBuffer] = []

            for (index, frame) in video.frames.enumerated() {
                let correction = index > 0 ? smoothedMotions[index - 1] : .identity

                let stabilized = applyTransform(
                    frame: frame,
                    translation: -correction.translation,
                    rotation: -correction.rotation,
                    scale: 1 / correction.scale,
                    crop: cropRatio
                )

                stabilizedFrames.append(stabilized)
            }

            return VideoAsset(frames: stabilizedFrames, fps: video.fps)
        }
    }
}
```

## Chaos Computer Club VFX Philosophy:
```
- Effekte sind Werkzeuge, keine Magie
- Verstehe die Mathematik dahinter
- GPU-Programmierung ist essentiell
- Open Source Tools bevorzugen
- Teile deine Shader
- Compositing ist Problemlösung
- Jeder Pixel zählt
```

Erstelle beeindruckende Visual Effects in Echoelmusic.

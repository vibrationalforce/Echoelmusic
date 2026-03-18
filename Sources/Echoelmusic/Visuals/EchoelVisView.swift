#if canImport(Metal) && canImport(SwiftUI)
//
//  EchoelVisView.swift
//  Echoelmusic — Bio-Reactive Visual Display
//
//  SwiftUI view that hosts the Metal-backed EchoelVisEngine.
//  Renders bio-reactive visuals at up to 120fps via CAMetalLayer.
//

import SwiftUI
import Metal
import MetalKit

// MARK: - Metal Layer View (UIKit bridge)

#if canImport(UIKit)
import UIKit

/// UIView wrapper that owns a CAMetalLayer for EchoelVisEngine rendering
private final class MetalVisLayerView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        metalLayer.contentsScale = UITraitCollection.current.displayScale
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}

/// UIViewRepresentable bridge for SwiftUI
private struct MetalVisRepresentable: UIViewRepresentable {
    let engine: EchoelVisEngine

    func makeUIView(context: Context) -> MetalVisLayerView {
        let view = MetalVisLayerView()
        view.metalLayer.device = engine.metalDevice
        engine.metalLayer = view.metalLayer
        return view
    }

    func updateUIView(_ uiView: MetalVisLayerView, context: Context) {
        uiView.metalLayer.drawableSize = uiView.bounds.size.applying(
            CGAffineTransform(scaleX: uiView.contentScaleFactor, y: uiView.contentScaleFactor)
        )
    }
}
#endif

// MARK: - EchoelVisView

/// Bio-reactive visual display panel
///
/// Shows real-time visuals driven by bio-signals (coherence, HRV, heart rate, breath).
/// 10 visual modes selectable via picker. Metal 120fps rendering.
public struct EchoelVisView: View {
    @Bindable private var vis = EchoelVisEngine.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                Circle()
                    .fill(vis.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(vis.isRunning ? "\(Int(vis.currentFPS)) fps" : "Stopped")
                    .font(EchoelBrandFont.data())
                Spacer()
                Text(vis.currentMode.rawValue)
                    .font(EchoelBrandFont.label())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, EchoelSpacing.md)
            .padding(.vertical, EchoelSpacing.sm)

            // Metal rendering surface
            #if canImport(UIKit)
            MetalVisRepresentable(engine: vis)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: EchoelRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.md)
                        .stroke(EchoelBrand.border, lineWidth: 1)
                )
                .padding(.horizontal, EchoelSpacing.md)
            #else
            // Fallback for non-UIKit platforms
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay(
                    Text("Metal visuals require iOS/iPadOS")
                        .font(EchoelBrandFont.caption())
                        .foregroundStyle(.secondary)
                )
                .clipShape(RoundedRectangle(cornerRadius: EchoelRadius.md))
                .padding(.horizontal, EchoelSpacing.md)
            #endif

            // Controls
            VStack(spacing: EchoelSpacing.sm) {
                // Mode picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EchoelSpacing.xs) {
                        ForEach(VisualMode.allCases, id: \.self) { mode in
                            Button(action: { vis.setMode(mode) }) {
                                Text(mode.rawValue)
                                    .font(EchoelBrandFont.dataSmall())
                                    .padding(.horizontal, EchoelSpacing.sm)
                                    .padding(.vertical, EchoelSpacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                            .fill(vis.currentMode == mode
                                                  ? EchoelBrand.accent.opacity(0.2)
                                                  : EchoelBrand.bgElevated)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                                    .stroke(vis.currentMode == mode
                                                            ? EchoelBrand.accent
                                                            : EchoelBrand.border, lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, EchoelSpacing.md)
                }

                // Bio state + controls row
                HStack(spacing: EchoelSpacing.md) {
                    // Bio indicator
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coherence")
                            .font(EchoelBrandFont.dataSmall())
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", vis.bioState.coherence * 100))
                            .font(EchoelBrandFont.data())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("HR")
                            .font(EchoelBrandFont.dataSmall())
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f", vis.bioState.heartRate))
                            .font(EchoelBrandFont.data())
                    }

                    Spacer()

                    Toggle("Bio", isOn: $vis.bioReactiveEnabled)
                        .font(EchoelBrandFont.dataSmall())
                        .toggleStyle(.switch)
                        .labelsHidden()

                    // Start/Stop
                    Button(action: {
                        if vis.isRunning { vis.stop() } else { vis.start() }
                    }) {
                        Image(systemName: vis.isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 16))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                    .fill(vis.isRunning
                                          ? EchoelBrand.coral.opacity(0.2)
                                          : EchoelBrand.emerald.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                            .stroke(vis.isRunning
                                                    ? EchoelBrand.coral
                                                    : EchoelBrand.emerald, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, EchoelSpacing.md)
            }
            .padding(.vertical, EchoelSpacing.sm)
        }
    }
}

#endif

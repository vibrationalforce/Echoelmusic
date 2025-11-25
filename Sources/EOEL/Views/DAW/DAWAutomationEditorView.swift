//
//  DAWAutomationEditorView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  AUTOMATION EDITOR - Draw automation curves
//

import SwiftUI

struct DAWAutomationEditorView: View {
    @StateObject private var automation = DAWAutomationSystem.shared
    @Binding var selectedTrack: UUID?

    @State private var selectedParameter: String?
    @State private var zoomLevel: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Parameter selector
            HStack {
                Text("Automation Parameter:")
                    .font(.headline)

                Picker("", selection: $selectedParameter) {
                    Text("Volume").tag("volume" as String?)
                    Text("Pan").tag("pan" as String?)
                    Text("Send 1").tag("send1" as String?)
                    Text("Plugin Parameter").tag("plugin" as String?)
                }

                Spacer()

                // Automation mode
                Picker("Mode", selection: .constant(0)) {
                    Text("Read").tag(0)
                    Text("Write").tag(1)
                    Text("Touch").tag(2)
                    Text("Latch").tag(3)
                }
                .pickerStyle(.menu)
            }
            .padding()

            Divider()

            // Automation curve editor
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Grid background
                    Canvas { context, size in
                        // Horizontal lines (value grid)
                        for i in 0...10 {
                            let y = size.height * CGFloat(i) / 10
                            context.stroke(
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: size.width, y: y))
                                },
                                with: .color(.gray.opacity(0.2)),
                                lineWidth: 1
                            )
                        }

                        // Vertical lines (time grid)
                        let timeInterval: CGFloat = 50
                        var x: CGFloat = 0
                        while x < size.width {
                            context.stroke(
                                Path { path in
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: size.height))
                                },
                                with: .color(.gray.opacity(0.2)),
                                lineWidth: 1
                            )
                            x += timeInterval
                        }
                    }

                    // Automation curve
                    if let parameter = selectedParameter {
                        AutomationCurve(parameter: parameter)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Select a parameter to edit automation")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

            Divider()

            // Tools
            HStack {
                Button(action: {}) {
                    Label("Draw", systemImage: "pencil")
                }

                Button(action: {}) {
                    Label("Line", systemImage: "line.diagonal")
                }

                Button(action: {}) {
                    Label("Curve", systemImage: "wave.3.right")
                }

                Spacer()

                Button(action: {}) {
                    Text("Clear All")
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
    }
}

struct AutomationCurve: View {
    let parameter: String

    @State private var points: [CGPoint] = [
        CGPoint(x: 0, y: 0.5),
        CGPoint(x: 100, y: 0.3),
        CGPoint(x: 200, y: 0.7),
        CGPoint(x: 300, y: 0.5)
    ]

    var body: some View {
        Canvas { context, size in
            // Draw curve path
            let path = Path { path in
                guard !points.isEmpty else { return }

                let firstPoint = CGPoint(
                    x: points[0].x,
                    y: size.height * (1.0 - points[0].y)
                )
                path.move(to: firstPoint)

                for point in points.dropFirst() {
                    let scaledPoint = CGPoint(
                        x: point.x,
                        y: size.height * (1.0 - point.y)
                    )
                    path.addLine(to: scaledPoint)
                }
            }

            context.stroke(
                path,
                with: .color(.accentColor),
                lineWidth: 2
            )

            // Draw control points
            for point in points {
                let scaledPoint = CGPoint(
                    x: point.x,
                    y: size.height * (1.0 - point.y)
                )

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: scaledPoint.x - 4,
                        y: scaledPoint.y - 4,
                        width: 8,
                        height: 8
                    )),
                    with: .color(.accentColor)
                )
            }
        }
    }
}

#if DEBUG
struct DAWAutomationEditorView_Previews: PreviewProvider {
    static var previews: some View {
        DAWAutomationEditorView(selectedTrack: .constant(UUID()))
            .frame(width: 1200, height: 400)
    }
}
#endif

//
//  DAWScoreView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  SCORE VIEW - Musical notation editor
//

import SwiftUI

struct DAWScoreView: View {
    @Binding var selectedTrack: UUID?

    var body: some View {
        VStack {
            Text("Score View - Musical Notation")
                .font(.title2)

            Spacer()

            // Staff lines placeholder
            VStack(spacing: 40) {
                StaffView()
                StaffView()
                StaffView()
            }
            .padding()

            Spacer()

            Text("Musical notation editor coming soon")
                .foregroundColor(.secondary)
        }
    }
}

struct StaffView: View {
    let lineSpacing: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            // Draw 5 staff lines
            for i in 0..<5 {
                let y = CGFloat(i) * lineSpacing
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.black),
                    lineWidth: 1
                )
            }

            // Draw clef symbol placeholder
            context.draw(
                Text("𝄞")
                    .font(.system(size: 60)),
                at: CGPoint(x: 30, y: lineSpacing * 2)
            )
        }
        .frame(height: lineSpacing * 4)
    }
}

#if DEBUG
struct DAWScoreView_Previews: PreviewProvider {
    static var previews: some View {
        DAWScoreView(selectedTrack: .constant(UUID()))
            .frame(width: 1200, height: 700)
    }
}
#endif

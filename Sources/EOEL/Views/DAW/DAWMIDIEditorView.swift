//
//  DAWMIDIEditorView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  MIDI EDITOR - Piano roll editor
//

import SwiftUI

struct DAWMIDIEditorView: View {
    @Binding var selectedTrack: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MIDI Editor (Piano Roll)")
                    .font(.headline)

                Spacer()

                Button("Grid: 1/16") {}
                Button("Snap: On") {}
                Button("Quantize") {}
            }
            .padding()

            Divider()

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Piano keys
                    PianoKeysView()
                        .frame(width: 80)

                    // Piano roll grid
                    PianoRollGrid()
                }
            }
        }
    }
}

struct PianoKeysView: View {
    let octaves = 7
    let noteHeight: CGFloat = 15

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach((0..<(octaves * 12)).reversed(), id: \.self) { note in
                    PianoKey(note: note)
                        .frame(height: noteHeight)
                }
            }
        }
        .background(Color.gray.opacity(0.05))
    }
}

struct PianoKey: View {
    let note: Int

    private var isBlackKey: Bool {
        let semitone = note % 12
        return [1, 3, 6, 8, 10].contains(semitone)
    }

    private var noteName: String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = note / 12
        return "\(names[note % 12])\(octave)"
    }

    var body: some View {
        HStack(spacing: 0) {
            if isBlackKey {
                Color.black
                    .frame(width: 60)
            } else {
                Color.white
                    .overlay(
                        Text(noteName)
                            .font(.caption2)
                            .foregroundColor(.black)
                            .padding(.leading, 4),
                        alignment: .leading
                    )
            }
        }
        .border(Color.gray.opacity(0.3), width: 0.5)
    }
}

struct PianoRollGrid: View {
    let noteHeight: CGFloat = 15
    let octaves = 7

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            Canvas { context, size in
                let totalNotes = octaves * 12

                // Horizontal lines (notes)
                for i in 0...totalNotes {
                    let y = CGFloat(i) * noteHeight
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        },
                        with: .color(.gray.opacity(0.2)),
                        lineWidth: 0.5
                    )
                }

                // Vertical lines (beats)
                let beatWidth: CGFloat = 50
                var x: CGFloat = 0
                while x < size.width {
                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        },
                        with: .color(.gray.opacity(0.2)),
                        lineWidth: 0.5
                    )
                    x += beatWidth
                }
            }
            .frame(width: 2000, height: CGFloat(octaves * 12) * noteHeight)
        }
        .background(Color.white)
    }
}

#if DEBUG
struct DAWMIDIEditorView_Previews: PreviewProvider {
    static var previews: some View {
        DAWMIDIEditorView(selectedTrack: .constant(UUID()))
            .frame(width: 1200, height: 600)
    }
}
#endif

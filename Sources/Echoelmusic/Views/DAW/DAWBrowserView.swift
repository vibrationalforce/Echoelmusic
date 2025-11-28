//
//  DAWBrowserView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  FILE BROWSER - Audio files, loops, samples, presets
//

import SwiftUI

struct DAWBrowserView: View {
    @Binding var selectedTrack: UUID?
    @Binding var showBrowser: Bool

    @State private var selectedCategory: Category = .audio
    @State private var searchText: String = ""

    enum Category: String, CaseIterable {
        case audio = "Audio Files"
        case loops = "Loops"
        case samples = "Samples"
        case presets = "Presets"
        case effects = "Effects"
        case instruments = "Instruments"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Browser")
                    .font(.headline)

                Spacer()

                Button(action: { showBrowser = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search...", text: $searchText)
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)

            // Category picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(Category.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.menu)
            .padding()

            Divider()

            // Content list
            List {
                Section(header: Text(selectedCategory.rawValue)) {
                    ForEach(0..<10, id: \.self) { index in
                        HStack {
                            Image(systemName: iconForCategory(selectedCategory))
                                .foregroundColor(.accentColor)

                            Text("Item \(index + 1)")

                            Spacer()

                            Image(systemName: "waveform")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("Add to Track") {}
                            Button("Preview") {}
                            Button("Show in Finder") {}
                        }
                    }
                }
            }
        }
        .background(Color.gray.opacity(0.05))
    }

    private func iconForCategory(_ category: Category) -> String {
        switch category {
        case .audio: return "waveform"
        case .loops: return "repeat"
        case .samples: return "music.note"
        case .presets: return "slider.horizontal.3"
        case .effects: return "wand.and.stars"
        case .instruments: return "music.note.house"
        }
    }
}

#if DEBUG
struct DAWBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        DAWBrowserView(
            selectedTrack: .constant(nil),
            showBrowser: .constant(true)
        )
        .frame(width: 250, height: 600)
    }
}
#endif

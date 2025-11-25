//
//  DAWTrackInspectorView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  TRACK INSPECTOR - Track settings and properties
//

import SwiftUI

struct DAWTrackInspectorView: View {
    @StateObject private var multiTrack = DAWMultiTrack.shared
    @Binding var selectedTrack: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            if let trackId = selectedTrack,
               let track = multiTrack.tracks.first(where: { $0.id == trackId }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Track Info
                        Section {
                            Text("TRACK INFO")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("Track Name", text: .constant(track.name))
                                .textFieldStyle(.roundedBorder)

                            ColorPicker("Track Color", selection: .constant(Color(track.color)))
                        }

                        Divider()

                        // Audio Settings
                        Section {
                            Text("AUDIO")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text("Input")
                                Spacer()
                                Picker("", selection: .constant(0)) {
                                    Text("Input 1").tag(0)
                                    Text("Input 2").tag(1)
                                }
                            }

                            HStack {
                                Text("Output")
                                Spacer()
                                Picker("", selection: .constant(0)) {
                                    Text("Master").tag(0)
                                    Text("Bus 1").tag(1)
                                }
                            }

                            HStack {
                                Text("Monitor")
                                Spacer()
                                Toggle("", isOn: .constant(false))
                            }
                        }

                        Divider()

                        // Recording Settings
                        Section {
                            Text("RECORDING")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text("Record Mode")
                                Spacer()
                                Picker("", selection: .constant(0)) {
                                    Text("Replace").tag(0)
                                    Text("Overdub").tag(1)
                                    Text("Loop").tag(2)
                                }
                            }

                            HStack {
                                Text("Count-in")
                                Spacer()
                                Picker("", selection: .constant(2)) {
                                    Text("Off").tag(0)
                                    Text("1 Bar").tag(1)
                                    Text("2 Bars").tag(2)
                                }
                            }
                        }

                        Divider()

                        // Track Settings
                        Section {
                            Text("SETTINGS")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Toggle("Freeze Track", isOn: .constant(false))
                            Toggle("Auto-Fade", isOn: .constant(true))
                            Toggle("Elastic Audio", isOn: .constant(false))
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Select a track to view properties")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.gray.opacity(0.05))
    }
}

#if DEBUG
struct DAWTrackInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        DAWTrackInspectorView(selectedTrack: .constant(UUID()))
            .frame(width: 300, height: 600)
    }
}
#endif

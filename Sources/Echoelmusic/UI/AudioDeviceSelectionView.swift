import SwiftUI

/// Audio device selection view
/// Allows users to choose input/output devices (built-in, USB, Bluetooth)
public struct AudioDeviceSelectionView: View {

    @StateObject private var usbAudioManager = USBAudioDeviceManager()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            List {
                // USB Status Section
                if usbAudioManager.hasUSBDevice {
                    Section {
                        HStack {
                            Image(systemName: "cable.connector")
                                .foregroundColor(.green)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("USB Audio Device Connected")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text(usbStatusText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Circle()
                                .fill(usbStatusColor)
                                .frame(width: 12, height: 12)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Input Devices Section
                Section(header: Text("Input Device (Microphone)")) {
                    ForEach(usbAudioManager.availableDevices.filter { $0.isInput }) { device in
                        DeviceRow(
                            device: device,
                            isSelected: device.id == usbAudioManager.currentInputDevice?.id,
                            action: {
                                usbAudioManager.selectInputDevice(device)
                            }
                        )
                    }

                    if usbAudioManager.availableDevices.filter({ $0.isInput }).isEmpty {
                        Text("No input devices available")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                // Output Devices Section
                Section(header: Text("Output Device (Speakers/Headphones)")) {
                    ForEach(usbAudioManager.availableDevices.filter { $0.isOutput }) { device in
                        DeviceRow(
                            device: device,
                            isSelected: device.id == usbAudioManager.currentOutputDevice?.id,
                            action: {
                                usbAudioManager.selectOutputDevice(device)
                            }
                        )
                    }

                    if usbAudioManager.availableDevices.filter({ $0.isOutput }).isEmpty {
                        Text("No output devices available")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                // Technical Info Section
                Section(header: Text("Technical Information")) {
                    HStack {
                        Text("Sample Rate")
                        Spacer()
                        Text("\(Int(usbAudioManager.currentInputDevice?.sampleRate ?? 0)) Hz")
                            .foregroundColor(.secondary)
                    }

                    if let inputDevice = usbAudioManager.currentInputDevice {
                        HStack {
                            Text("Input Channels")
                            Spacer()
                            Text("\(inputDevice.channelCount)")
                                .foregroundColor(.secondary)
                        }
                    }

                    if let outputDevice = usbAudioManager.currentOutputDevice {
                        HStack {
                            Text("Output Channels")
                            Spacer()
                            Text("\(outputDevice.channelCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Help Section
                Section(header: Text("USB Audio Support")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Echoelmusic supports:")
                            .font(.subheadline.bold())

                        BulletPoint(text: "USB Audio Class 1.0 & 2.0")
                        BulletPoint(text: "Professional audio interfaces")
                        BulletPoint(text: "USB microphones")
                        BulletPoint(text: "USB-C headphones")
                        BulletPoint(text: "Lightning audio adapters")

                        Text("Connect a USB audio device to see it here. Hot-plug supported!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Audio Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        usbAudioManager.scanAvailableDevices()
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var usbStatusText: String {
        switch usbAudioManager.usbDeviceState {
        case .connectedAndActive:
            return "Active and in use"
        case .connectedButInactive:
            return "Connected but not selected"
        case .notConnected:
            return "Not connected"
        }
    }

    private var usbStatusColor: Color {
        switch usbAudioManager.usbDeviceState {
        case .connectedAndActive:
            return .green
        case .connectedButInactive:
            return .orange
        case .notConnected:
            return .red
        }
    }
}

/// Individual device row
struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Device icon
                Image(systemName: deviceIcon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 30)

                // Device info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.name)
                            .font(.body)
                            .foregroundColor(.primary)

                        if device.isUSB {
                            Image(systemName: "cable.connector")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("\(Int(device.sampleRate / 1000)) kHz")
                        Text("•")
                        Text("\(device.channelCount) ch")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var deviceIcon: String {
        if device.isUSB {
            return device.isInput ? "mic.fill" : "speaker.wave.3.fill"
        }

        switch device.type {
        case .builtInMicrophone:
            return "iphone.radiowaves.left.and.right"
        case .builtInSpeaker:
            return "speaker.wave.2.fill"
        case .headphones:
            return "headphones"
        case .usbAudio:
            return device.isInput ? "mic.fill" : "hifispeaker.fill"
        case .bluetooth:
            return "airpodspro"
        case .other:
            return "waveform"
        }
    }
}

/// Bullet point helper view
struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }
}

#Preview {
    AudioDeviceSelectionView()
}

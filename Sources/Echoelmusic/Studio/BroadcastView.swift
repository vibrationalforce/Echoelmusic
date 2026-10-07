#if canImport(SwiftUI)
import SwiftUI

// BroadcastView.swift
// Echoel — configure and run the phone-native broadcast (RTMP / RTMPS). Pairs with
// `BroadcastPublisher`, the stream's ONE lifecycle owner: Go Live and Stop on this page are the
// only things that start or end a stream (Broadcast B1 — the Patchbay route no longer does).
//
// What the page must say, because a stream leaves the room: WHERE the sound comes from (the
// master mix, after the master chain), WHERE the picture comes from (the Echoelmusic visual —
// never the camera, which stays with the pulse), what state the connection is in, and when the
// engine is not in this build. It never shows the stream key and never claims "live" before
// the server accepted the publish.

@MainActor
struct BroadcastView: View {

    @Environment(BroadcastPublisher.self) private var broadcast
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(\.dismiss) private var dismiss
    var embedded = false

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
                    .navigationTitle("Broadcast")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                    }
            }
        }
    }

    private var content: some View {
        @Bindable var broadcast = broadcast
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Send the master mix and the visual to a streaming server.")
                    .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)

                if !broadcast.engineAvailable {
                    Text("Streaming engine not installed in this build. Destination settings are saved and will work once it ships.")
                        .font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

                sourceRow(title: "Sound",
                          detail: "The master mix — what the speakers play, after the master chain.")
                sourceRow(title: "Picture",
                          detail: "The Echoelmusic visual, 1280 × 720 at 30 fps. The camera is not used.")
                Text("Preview: keep the visual window open — the stream sends what it draws. With no visual on screen the stream sends black and says so here.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)

                field("Server address", text: $broadcast.url,
                      placeholder: "rtmps://a.rtmp.youtube.com/live2")
                Text("Starts with rtmp:// or rtmps:// (rtmps is encrypted). SRT is not in this build.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                secureField("Stream key", text: $broadcast.streamKey)
                Text("The key stays on this phone, in the Keychain. It is never shown in a status line.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)

                if !broadcast.statusMessage.isEmpty {
                    Text(broadcast.statusMessage)
                        .font(EchoelTheme.font(13)).foregroundStyle(EchoelTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text("Stream status: \(broadcast.statusMessage)"))
                }
                if broadcast.isLive {
                    Text(broadcast.pictureState.sentence)
                        .font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    if broadcast.silencedSeconds > 0 {
                        Text("Sound dropouts so far: \(broadcast.silencedSeconds, specifier: "%.1f") s — the stream fell behind the mix and filled the gap with silence.")
                            .font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // The loudness of the mix before going live. ⛔ THE LABEL SAID "Output
                // loudness" until #316 — the meter sits at the master chain's INPUT, so on a
                // page about what leaves the device that word was the most misleading one
                // available. The grid itself now names its measurement point.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Loudness").font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    MasterLoudnessGrid()
                    // ⛔ Was "Most platforms target ≈ −14 LUFS integrated, true peak ≤ −1
                    // dBTP." — on the one page about what leaves the device, printed under a
                    // meter that measures the chain's input. #316 removed the machine's
                    // verdict; leaving this would have asked the reader to make the same one
                    // by eye. ⚠️ The STREAM itself is taken after the chain (B1) — the sentence
                    // is about the meter, not about what is sent.
                    Text("These numbers are the mix before the master chain, not the delivered stream.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    broadcast.isLive ? broadcast.stop() : broadcast.start()
                } label: {
                    Text(broadcast.isLive ? "Stop" : "Go Live")
                        .font(EchoelTheme.font(15, .semibold))
                        .foregroundStyle(EchoelTheme.onPrimary)
                        .frame(maxWidth: .infinity).frame(minHeight: 48)
                        // Restructure F6b: "live" is the RECORDING red, never `danger` — the two
                        // tokens share a value today and are kept apart on purpose (EchoelTheme:
                        // an error-red retune must not repaint a live/recording indicator). The
                        // same grammar as the take's record button (`RecordTakeControls`).
                        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                            .fill(broadcast.isLive ? EchoelTheme.recording : EchoelTheme.text))
                }
                .buttonStyle(.plain)
                // Stop is ALWAYS reachable; Go Live needs an address and a key.
                .disabled(!broadcast.isLive && !broadcast.isConfigured)
                .accessibilityHint(Text(broadcast.isLive
                                        ? "Ends the stream."
                                        : "Starts sending to the server. Nothing is sent before you press it."))

                // ⛔ A "turn broadcast on from the patchbay" tip stood here and was FALSE
                // (brand audit 2026-08-28): the patchbay is a pure dataflow surface —
                // `hasEnabledRoute(fromSource:)` has no production caller (BLE-3 lesson,
                // SignalRouter.swift), so connecting a route starts nothing.
            }
            .padding(EchoelTheme.spaceL)
        }
        .background(EchoelTheme.bg)
        .onAppear {
            #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
            broadcast.attach(ring: audioEngine.retroCapture)
            #endif
        }
    }

    private func sourceRow(title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
            Text(detail).font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
            Text(label).font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            TextField(placeholder, text: text)
                .font(EchoelTheme.font(15)).foregroundStyle(EchoelTheme.text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(10)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
                .accessibilityLabel(Text(label))
        }
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
            Text(label).font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            SecureField("•••••••••••", text: text)
                .font(EchoelTheme.font(15)).foregroundStyle(EchoelTheme.text)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(10)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).strokeBorder(EchoelTheme.border, lineWidth: 1))
                .accessibilityLabel(Text(label))
        }
    }
}
#endif

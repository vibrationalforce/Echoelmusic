//
//  FaceChannelsRow.swift
//  Echoelmusic — Studio
//
//  #1258 — the three face channels as NUMBERS (science-first: the number, not a knob), with
//  the neutral-hold calibration beside them. Mounted in `bioPanel` under the source chooser.
//
//  A LEAF ON PURPOSE (10.76.41/50): `FaceExpressionBioPublisher` writes `smile/browRaise/
//  jawOpen` at 10 Hz. Reading them here, in a `View` of its own, rebuilds this row and
//  nothing else; read in `EchoelStudioView.bioPanel` they would rebuild the menu host and
//  tear down any open Picker ten times a second.
//
//  Renders NOTHING unless the face source is live, calibrating, or reporting an error —
//  on a pulse take the panel keeps its shape. Wording: expression as a CONTROL value,
//  never a feeling (EU AI Act framing in the publisher's header).
//

import SwiftUI

struct FaceChannelsRow: View {
    @Environment(FaceExpressionBioPublisher.self) private var face

    var body: some View {
        if face.isPublishing || face.isCalibrating || face.lastError != nil {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    channel("Smile", face.smile)
                    channel("Brow", face.browRaise)
                    channel("Jaw", face.jawOpen)
                    Spacer(minLength: 8)
                    calibrateControl
                }
                if face.isCalibrating {
                    Text("Hold a still face — three seconds.")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                } else if let error = face.lastError {
                    Text("Face input stopped: \(error)")
                        .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func channel(_ label: String, _ value: Float) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(EchoelTheme.font(10)).foregroundStyle(EchoelTheme.dim)
            Text(EchoelDecimalText.string(value, decimals: 2))
                .font(EchoelTheme.font(13, .semibold)).monospacedDigit()
                .foregroundStyle(EchoelTheme.text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(EchoelDecimalText.string(value, decimals: 2))
    }

    private var calibrateControl: some View {
        Button {
            face.calibrate()
        } label: {
            Text(face.hasCalibration ? "Recalibrate" : "Calibrate")
                .font(EchoelTheme.font(12, .semibold))
                .foregroundStyle(EchoelTheme.text)
                .padding(.horizontal, 12).frame(minHeight: 34)
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(EchoelTheme.borderStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!face.isPublishing || face.isCalibrating)
        .accessibilityHint("Hold a still face for three seconds; the channels then start from your neutral")
    }
}

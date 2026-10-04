//
//  BroadcastSession.swift
//  Echoelmusic — Stream
//
//  The broadcast's STATE and the rules around it, as pure values: which phase the stream is
//  in, what the person reads for each phase, which destinations are acceptable, how long to
//  wait before a reconnect, and how an engine error is scrubbed of the stream key before it
//  is shown or logged. No network, no AVFoundation — `BroadcastPublisher` drives these, and
//  `TheBroadcastStateSpeaksPlainlyTests` drives them without a server.
//
//  ⚠️ "LIVE" MEANS THE SERVER ACCEPTED THE PUBLISH, NOTHING MORE. It is entered on the
//  engine's publish-start answer. Whether a viewer can decode sound and picture is a third,
//  separate fact that only a receiver can report (`docs/dev/BROADCAST_HAISHINKIT_FINISH.md`
//  §4 keeps the three apart: compiles · server accepts · receiver plays).
//

import Foundation

/// Where the broadcast is. Exactly one at a time; `BroadcastPublisher.phase` owns it.
enum BroadcastPhase: Equatable, Sendable {
    case idle
    case connecting
    case live
    /// The connection dropped while live; `attempt` counts from 1.
    case reconnecting(attempt: Int)
    case stopping
    case failed(BroadcastFailure)

    /// True while sound and picture may be sent.
    var isSending: Bool { self == .live }

    /// True from "Go Live" until the stream has ended or failed — the button reads "Stop".
    var isActive: Bool {
        switch self {
        case .connecting, .live, .reconnecting, .stopping: return true
        case .idle, .failed: return false
        }
    }
}

/// Why a broadcast is not running. Each case has ONE sentence (`BroadcastStatusWords`).
enum BroadcastFailure: Equatable, Sendable {
    case engineMissing
    case notConfigured
    /// No master ring attached — nothing to send as sound.
    case noSound
    case invalidURL
    case unsupportedScheme
    case connectFailed
    case publishRejected
    case retriesExhausted
}

/// The one place a destination URL is judged. RTMP and RTMPS only — that is what the linked
/// engine speaks (HaishinKit `RTMPConnection.supportedProtocols`); SRT is not in this build.
enum BroadcastDestination {

    static let schemes: Set<String> = ["rtmp", "rtmps"]

    static func validate(_ raw: String) -> BroadcastFailure? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .notConfigured }
        guard !trimmed.contains(where: { $0.isWhitespace }),
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased() else { return .invalidURL }
        guard schemes.contains(scheme) else { return .unsupportedScheme }
        guard let host = components.host, !host.isEmpty else { return .invalidURL }
        return nil
    }

    /// True when the URL encrypts the connection (RTMPS / TLS).
    static func isEncrypted(_ raw: String) -> Bool {
        URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))?
            .scheme?.lowercased() == "rtmps"
    }
}

/// How long to wait before reconnect attempt `n`, and when to give up. Bounded on purpose: a
/// stream that cannot come back must END and say so, never retry forever while the person
/// believes they are live.
enum BroadcastReconnectPolicy {
    static let maxAttempts = 5
    static let firstDelaySeconds: Double = 1
    static let maxDelaySeconds: Double = 16

    /// 1, 2, 4, 8, 16 s. Attempt numbers outside 1…maxAttempts return nil (= give up).
    static func delaySeconds(attempt: Int) -> Double? {
        guard attempt >= 1, attempt <= maxAttempts else { return nil }
        let d = firstDelaySeconds * pow(2, Double(attempt - 1))
        return Swift.min(d, maxDelaySeconds)
    }
}

/// What the person reads. One sentence per phase, no jargon, never a fake "live".
enum BroadcastStatusWords {

    static func text(for phase: BroadcastPhase, encrypted: Bool) -> String {
        switch phase {
        case .idle:
            return ""
        case .connecting:
            return "Connecting to the server…"
        case .live:
            return encrypted
                ? "Sending sound and picture (encrypted). The server accepted the stream."
                : "Sending sound and picture. The server accepted the stream."
        case .reconnecting(let attempt):
            return "Connection lost. Trying again (\(attempt) of \(BroadcastReconnectPolicy.maxAttempts))…"
        case .stopping:
            return "Stopping…"
        case .failed(let failure):
            return text(for: failure)
        }
    }

    static func text(for failure: BroadcastFailure) -> String {
        switch failure {
        case .engineMissing:
            return "Streaming engine not installed in this build."
        case .notConfigured:
            return "Add a server address and a stream key first."
        case .noSound:
            return "The sound engine is not running yet. Start the instrument, then go live."
        case .invalidURL:
            return "The server address is not a valid URL."
        case .unsupportedScheme:
            return "Use an address that starts with rtmp:// or rtmps://."
        case .connectFailed:
            return "Could not reach the server. Check the address and your network."
        case .publishRejected:
            return "The server refused the stream. Check the stream key."
        case .retriesExhausted:
            return "The connection did not come back. The stream has ended."
        }
    }
}

/// Removes the stream key from any text before it is shown or logged — an engine's error
/// description can echo the URL or the publish name it was given.
enum BroadcastRedaction {
    static let mask = "•••"

    static func scrub(_ text: String, secret: String) -> String {
        let s = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count >= 4 else { return text }   // a 1–3 character "key" would mask ordinary words
        return text.replacingOccurrences(of: s, with: mask)
    }
}

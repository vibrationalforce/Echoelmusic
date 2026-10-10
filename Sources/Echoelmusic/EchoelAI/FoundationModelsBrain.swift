// FoundationModelsBrain.swift
// Echoel — EchoelAI N3, Tier 1: Apple Foundation Models (iOS 26+). The
// system's on-device ~3B model; no weights in our process, offline, private.
//
// Encapsulation law (ADR): every FoundationModels symbol lives behind
// `#if canImport(FoundationModels)` + `#available(iOS 26.0, *)` — the
// deployment floor stays iOS 18 and every target (app, AUv3, Linux CI)
// keeps building. On any other path `isAvailable` is false and `respond`
// throws `.unavailable`; nothing crashes, nothing links.
//
// Error mapping (GMMW AI-3): by TYPE, never by text — guardrail violation →
// `.refused`, exceeded context window → `.contextOverflow`, anything else →
// `.unknown(<error type name>)`. The payload never carries the error's
// description or the prompt: both can echo user text into a log.
// Availability is asked of `OnDeviceModelGate.status`, the one reader.

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Tier-1 backend over the system language model. Stateless (each call makes
/// a fresh session — session persistence is a later cycle), hence Sendable.
public struct FoundationModelsBrain: BrainBackend {

    public init() {}

    public var isAvailable: Bool {
        get async {
            OnDeviceModelGate.status == .available
        }
    }

    public func respond(to prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            guard OnDeviceModelGate.status == .available else {
                throw EchoelAIError.unavailable
            }
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                return response.content
            } catch let generation as LanguageModelSession.GenerationError {
                if case .guardrailViolation = generation {
                    throw EchoelAIError.refused   // safety layer said no
                }
                if case .exceededContextWindowSize = generation {
                    throw EchoelAIError.contextOverflow
                }
                throw EchoelAIError.unknown(String(reflecting: type(of: generation)))
            } catch {
                throw EchoelAIError.unknown(String(reflecting: type(of: error)))
            }
        }
        #endif
        throw EchoelAIError.unavailable
    }
}

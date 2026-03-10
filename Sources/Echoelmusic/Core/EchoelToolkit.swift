//
//  EchoelToolkit.swift
//  Echoelmusic — EchoelToolkit Central Reference
//
//  Defines the 12 EchoelTools and 3 product editions.
//  VisualMode lives in EchoelVisEngine.swift.
//  AITask lives in EchoelAIEngine.swift.
//

import Foundation

// MARK: - Echoel Tool

/// The 12 unified EchoelTools
public enum EchoelTool: String, CaseIterable, Codable, Sendable {
    case synth  = "EchoelSynth"   // DDSP, 12 bio-mappings, spectral morphing
    case mix    = "EchoelMix"     // Console, metering, BPM sync, multi-track
    case fx     = "EchoelFX"      // 20+ effects, Neve/SSL emulation
    case seq    = "EchoelSeq"     // Step sequencer, patterns, automation
    case midi   = "EchoelMIDI"    // MIDI 2.0, MPE, touch instruments
    case bio    = "EchoelBio"     // HRV, HR, breathing, ARKit, EEG
    case vis    = "EchoelVis"     // 10 modes incl. Generative & AR Worlds
    case vid    = "EchoelVid"     // Capture, edit, stream, ProRes
    case lux    = "EchoelLux"     // DMX 512, Art-Net, lasers, smart home
    case stage  = "EchoelStage"   // External displays, projection, AirPlay
    case net    = "EchoelNet"     // Ableton Link, Dante, cloud sync
    case ai     = "EchoelAI"      // CoreML, LLM, stem sep, Music Theory, AR History
}

// MARK: - Edition

/// 3 product editions targeting different audiences
public enum EchoelEdition: String, CaseIterable, Codable, Sendable {
    case creativeSuite      = "Creative Suite"
    case researchEdition    = "Research Edition"
    case bioReactiveSDK     = "Bio-Reactive Audio SDK"

    /// Target audience description
    public var audience: String {
        switch self {
        case .creativeSuite:   return "Musicians, filmmakers, performers, installation artists"
        case .researchEdition: return "Universities, Fraunhofer, clinical researchers"
        case .bioReactiveSDK:  return "Game developers (Unity, Unreal)"
        }
    }
}

// MARK: - Audience Persona

/// 8 audience personas
public enum AudiencePersona: String, CaseIterable, Codable, Sendable {
    case musiciansProducers    = "Musicians & Producers"
    case djsPerformers         = "DJs & Performers"
    case filmmakersArtists     = "Filmmakers & Artists"
    case installationsStaging  = "Installations & Staging"
    case therapistsCoaches     = "Therapists & Coaches"
    case educationResearch     = "Education & Research"
    case gameDevelopers        = "Game Developers"
    case accessibility         = "Accessibility"
}

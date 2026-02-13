// HealthKitManager.swift
// Echoelmusic - Backward-Compatibility Wrapper
//
// Thin wrapper around UnifiedHealthKitEngine for views still using HealthKitManager.
// All logic lives in UnifiedHealthKitEngine. This file only bridges the old API.

import Foundation
import SwiftUI
import Combine

/// Backward-compatible wrapper around UnifiedHealthKitEngine.
/// Views using `@EnvironmentObject var healthKitManager: HealthKitManager` continue to work.
@MainActor
class HealthKitManager: ObservableObject {

    private let engine = UnifiedHealthKitEngine.shared

    // MARK: - Published Properties (forwarded from UnifiedHealthKitEngine)

    @Published var heartRate: Double = 70.0
    @Published var hrvRMSSD: Double = 0.0
    @Published var hrvCoherence: Double = 0.0
    @Published var breathingRate: Double = 12.0
    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?

    enum AuthorizationState {
        case unknown, notDetermined, authorized, denied, unavailable

        var canRetry: Bool {
            switch self {
            case .notDetermined, .unknown: return true
            case .denied, .authorized, .unavailable: return false
            }
        }

        var shouldShowSettingsLink: Bool {
            self == .denied
        }
    }

    @Published var authorizationState: AuthorizationState = .unknown

    // MARK: - Initialization

    init() {
        engine.$heartRate.assign(to: &$heartRate)
        engine.$hrvSDNN.assign(to: &$hrvRMSSD)
        engine.$coherence.map { $0 * 100.0 }.assign(to: &$hrvCoherence)
        engine.$breathingRate.assign(to: &$breathingRate)
        engine.$isAuthorized.assign(to: &$isAuthorized)
        engine.$errorMessage.assign(to: &$errorMessage)

        engine.$authState
            .map { state -> AuthorizationState in
                switch state {
                case .authorized: return .authorized
                case .denied: return .denied
                case .notDetermined: return .notDetermined
                case .unavailable: return .unavailable
                case .unknown: return .unknown
                }
            }
            .assign(to: &$authorizationState)
    }

    // MARK: - Forwarded Methods

    func requestAuthorization() async throws {
        try await engine.requestAuthorization()
    }

    func startMonitoring() {
        engine.startStreaming()
    }

    func stopMonitoring() {
        engine.stopStreaming()
    }

    func openHealthSettings() {
        #if os(iOS)
        if let url = URL(string: "x-apple-health://") {
            Task { @MainActor in
                #if canImport(UIKit)
                await UIApplication.shared.open(url)
                #endif
            }
        }
        #endif
    }
}

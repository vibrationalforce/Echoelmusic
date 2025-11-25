//
//  DeepLinkHandler.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Deep linking and URL scheme handling
//

import Foundation
import UIKit

@MainActor
final class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

    @Published var pendingAction: DeepLinkAction?

    // MARK: - Deep Link Actions

    enum DeepLinkAction: Equatable {
        case record
        case openProject(id: String?)
        case newProject(name: String?)
        case eoelWork
        case applyEffect(String)
        case enableFaceControl
        case openSettings
        case subscription
        case export(format: String?)
    }

    // MARK: - URL Handling

    func handle(url: URL) {
        guard url.scheme == "eoel" else { return }

        let action = parseURL(url)
        executeAction(action)
    }

    private func parseURL(_ url: URL) -> DeepLinkAction {
        let host = url.host ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems

        switch host {
        case "record":
            return .record

        case "open-project":
            let projectID = queryItems?.first(where: { $0.name == "id" })?.value
            return .openProject(id: projectID)

        case "new-project":
            let name = queryItems?.first(where: { $0.name == "name" })?.value
            return .newProject(name: name)

        case "eoelwork":
            return .eoelWork

        case "apply-effect":
            let effect = queryItems?.first(where: { $0.name == "effect" })?.value ?? "reverb"
            return .applyEffect(effect)

        case "face-control":
            return .enableFaceControl

        case "settings":
            return .openSettings

        case "subscription":
            return .subscription

        case "export":
            let format = queryItems?.first(where: { $0.name == "format" })?.value
            return .export(format: format)

        default:
            return .openProject(id: nil) // Default to opening last project
        }
    }

    private func executeAction(_ action: DeepLinkAction) {
        // Store action for the view to handle
        pendingAction = action

        // Also post notification for legacy handlers
        NotificationCenter.default.post(
            name: .deepLinkReceived,
            object: nil,
            userInfo: ["action": action]
        )

        // Log analytics
        let signal = TelemetryDeck.Signal("deep_link_opened", parameters: [
            "action": String(describing: action)
        ])
        TelemetryDeck.send(signal)
    }

    // MARK: - Universal Links

    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        // Handle https://eoel.app/* URLs
        guard url.host == "eoel.app" else { return false }

        let path = url.pathComponents.dropFirst() // Remove leading "/"

        if path.isEmpty {
            // Homepage - no action
            return false
        }

        switch path.first {
        case "record":
            executeAction(.record)
        case "eoelwork":
            executeAction(.eoelWork)
        case "project":
            if path.count > 1 {
                executeAction(.openProject(id: String(path[1])))
            }
        case "subscription":
            executeAction(.subscription)
        default:
            return false
        }

        return true
    }

    // MARK: - Handoff

    func continueUserActivity(_ userActivity: NSUserActivity) -> Bool {
        switch userActivity.activityType {
        case "app.eoel.recording":
            executeAction(.record)
            return true

        case "app.eoel.project":
            if let projectID = userActivity.userInfo?["projectID"] as? String {
                executeAction(.openProject(id: projectID))
                return true
            }

        case "app.eoel.eoelwork":
            executeAction(.eoelWork)
            return true

        default:
            return handleUniversalLink(userActivity)
        }

        return false
    }

    // MARK: - Clear Pending Action

    func clearPendingAction() {
        pendingAction = nil
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let deepLinkReceived = Notification.Name("deepLinkReceived")
}

// MARK: - URL Builder

extension DeepLinkHandler {
    /// Build deep link URLs for sharing or widgets
    static func buildURL(for action: DeepLinkAction) -> URL {
        var components = URLComponents()
        components.scheme = "eoel"

        switch action {
        case .record:
            components.host = "record"

        case .openProject(let id):
            components.host = "open-project"
            if let id = id {
                components.queryItems = [URLQueryItem(name: "id", value: id)]
            }

        case .newProject(let name):
            components.host = "new-project"
            if let name = name {
                components.queryItems = [URLQueryItem(name: "name", value: name)]
            }

        case .eoelWork:
            components.host = "eoelwork"

        case .applyEffect(let effect):
            components.host = "apply-effect"
            components.queryItems = [URLQueryItem(name: "effect", value: effect)]

        case .enableFaceControl:
            components.host = "face-control"

        case .openSettings:
            components.host = "settings"

        case .subscription:
            components.host = "subscription"

        case .export(let format):
            components.host = "export"
            if let format = format {
                components.queryItems = [URLQueryItem(name: "format", value: format)]
            }
        }

        return components.url ?? URL(string: "eoel://")!
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct DeepLinkHandlerView: ViewModifier {
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: deepLinkHandler.pendingAction) { oldValue, newValue in
                if let action = newValue {
                    handleAction(action)
                    deepLinkHandler.clearPendingAction()
                }
            }
            .onOpenURL { url in
                deepLinkHandler.handle(url: url)
            }
    }

    private func handleAction(_ action: DeepLinkHandler.DeepLinkAction) {
        // Handle the action in your app's navigation
        // This will depend on your app's architecture

        // Example:
        // switch action {
        // case .record:
        //     navigationCoordinator.navigateTo(.recording)
        // case .openProject(let id):
        //     if let id = id {
        //         projectManager.openProject(id: id)
        //     }
        // case .eoelWork:
        //     navigationCoordinator.navigateTo(.eoelWork)
        // ...
        // }
    }
}

extension View {
    func handleDeepLinks() -> some View {
        modifier(DeepLinkHandlerView())
    }
}

// MARK: - Usage Examples

/*
 1. In your main App struct:

 @main
 struct EOELApp: App {
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .handleDeepLinks()
         }
     }
 }

 2. Build URLs for widgets or sharing:

 let recordURL = DeepLinkHandler.buildURL(for: .record)
 // eoel://record

 let projectURL = DeepLinkHandler.buildURL(for: .openProject(id: "123"))
 // eoel://open-project?id=123

 3. Handle in SceneDelegate (for UIKit apps):

 func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
     guard let url = URLContexts.first?.url else { return }
     DeepLinkHandler.shared.handle(url: url)
 }

 func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
     _ = DeepLinkHandler.shared.continueUserActivity(userActivity)
 }
 */

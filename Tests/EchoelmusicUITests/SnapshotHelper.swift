//
//  SnapshotHelper.swift
//  Echoelmusic — Fastlane Snapshot Integration
//
//  Auto-generated helper for fastlane snapshot.
//  This file bridges XCUITest with fastlane's screenshot capture.
//

import Foundation
import XCTest

var deviceLanguage = ""
var locale = ""

func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
    Snapshot.setupSnapshot(app, waitForAnimations: waitForAnimations)
}

func snapshot(_ name: String, waitForLoadingIndicator: Bool = true) {
    if waitForLoadingIndicator {
        sleep(1)
    }
    Snapshot.snapshot(name)
}

enum Snapshot {
    static var app: XCUIApplication?
    static var waitForAnimations = true
    static var cacheDirectory: URL?

    static func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
        Snapshot.app = app
        Snapshot.waitForAnimations = waitForAnimations

        // Read language from environment (set by fastlane)
        if let lang = app.launchEnvironment["FASTLANE_SNAPSHOT_LANGUAGES"] {
            deviceLanguage = lang
        }

        app.launchArguments += ["FASTLANE_SNAPSHOT"]
    }

    static func snapshot(_ name: String) {
        guard let app = Snapshot.app else {
            XCTFail("Snapshot not set up — call setupSnapshot() first")
            return
        }

        if waitForAnimations {
            sleep(1)
        }

        // Use XCUIScreen API for screenshot capture
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways

        // Save to fastlane output directory if available
        if let outputDir = ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"] {
            let url = URL(fileURLWithPath: outputDir)
                .appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }

        // Add as test attachment (Xcode results bundle)
        XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
            activity.add(attachment)
        }
    }
}
